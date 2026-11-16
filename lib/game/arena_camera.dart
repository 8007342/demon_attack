import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'model.dart' show ArcadeModel, GroundCamera;

/// boss-grandeur §3–§4: the arena camera of the boss fight. Pure Dart, no
/// Flutter widgets: the scene applies [gameplayMatrix] to the gameplay layer
/// and [backgroundMatrix] to the background (sky, terrain, ground units).
///
/// - **Zoom** `screen = pivot + Z·(arena − pivot)`, pivot `(180, shipY)`,
///   `Z ∈ [minZoom, 1]`, rate-limited to [maxRate] per second with an eased
///   approach. Hitboxes are arena units: the simulation never sees Z. Touch
///   maps through [toArena] / [deltaToArena].
/// - **Follow** (background only): a lateral pan [fx] and a horizon shift
///   [fy] with parallax weights 0.3 at the horizon rising to 1.0 at the near
///   ground (an affine skew), so the ground far below shifts with the boss.
/// - **Altitude** A ≥ 1 (presentation only): the camera's height over the
///   ground scales by A. For the flat ground this is exactly a vertical
///   stretch about the horizon (a ground point at depth z projects at
///   `horizon + A·(y₁ − horizon)`), so at any screen row the ground is 1/A
///   the size and scrolls at 1/A the speed: "the ground falls farther away".
///
/// Reduced motion: no dynamic zoom and no follow; one static framing
/// ([reducedZoom]) eased in at the Climb and out at the Collapse.
class ArenaCamera {
  static const pivotX = 180.0, pivotY = ArcadeModel.shipY;

  /// The smallest zoom (design §3.1: the readability floors hold here; if
  /// the operator finds it too small, raise it to 0.9).
  static const minZoom = .86;
  static const reducedZoom = .94;

  /// boss-carrier-wire (boss-hero-assets §8.3): a v2 carrier is too big for
  /// that band, so its fight runs at Z ∈ [[carrierMinZoom], [carrierMaxZoom]]
  /// with the same pivot, rate limit and holds, and a static framing of
  /// [carrierReducedZoom] under reduced motion. At 0.70 the creature and
  /// ship floors are draw-size floors ([floorScale]).
  static const carrierMinZoom = .70, carrierMaxZoom = .86;
  static const carrierReducedZoom = .78;

  /// Phone floors in CSS px of the 360-wide arena (design §3.1).
  static const creatureFloor = 34.0, shipFloor = 36.0, bulletFloor = 3.0;

  /// Zoom rate limit (per second) and the static framing's ramp.
  static const maxRate = .05, reducedRate = .06;

  /// Follow: lateral pan and horizon shift at full strength (units).
  static const followPan = 24.0, followHorizon = 20.0;

  /// Follow parallax weights: horizon and near ground.
  static const horizonWeight = .3, nearWeight = 1.0;

  /// Follow lerp time (s): about 95 % of the way in this time.
  static const followSeconds = .8;

  /// Background overscan at full follow strength (the pan never uncovers
  /// the arena's edge).
  static const overscan = .16; // 180·(k − 1) ≥ 24·k

  double zoom = 1;
  double fx = 0, fy = 0;
  double altitude = 1;

  /// Follow strength 0..1 (eases in with the climb).
  double followStrength = 0;

  /// The zoom the camera is easing toward (tests, review).
  double target = 1;

  bool get identity =>
      zoom == 1 && fx == 0 && fy == 0 && altitude == 1 && followStrength == 0;

  void reset() {
    zoom = target = altitude = 1;
    fx = fy = followStrength = 0;
  }

  /// The target zoom: `Z* = 1 − 0.06·range − 0.05·swerve − 0.03·(A − 1)/0.6`,
  /// clamped to [[minZoom], 1]. [range] is the boss's horizontal travel span
  /// over the last 3 s (0..1), [swerve] its |yaw| view index (0 or 1).
  ///
  /// A [carrier] maps the same terms onto its own band: it engages at
  /// [carrierMaxZoom] and the full range, swerve and climb take it to
  /// [carrierMinZoom].
  static double targetZoom({
    required double range,
    required double swerve,
    required double altitude,
    bool carrier = false,
  }) {
    final out =
        .06 * range.clamp(0.0, 1.0) +
        .05 * swerve.clamp(0.0, 1.0) +
        .03 * ((altitude - 1) / .6).clamp(0.0, 1.0);
    if (!carrier) return (1 - out).clamp(minZoom, 1.0);
    const k = (carrierMaxZoom - carrierMinZoom) / .14;
    return (carrierMaxZoom - k * out).clamp(carrierMinZoom, carrierMaxZoom);
  }

  /// Whether the camera is in the carrier band (set by [stepZoom]).
  bool carrier = false;

  /// The smallest zoom the current band allows.
  double get floorZoom => carrier ? carrierMinZoom : minZoom;

  /// The draw-size factor that keeps a sprite of [size] arena units at
  /// least [floor] screen units (CSS px of the 360-wide arena) under the
  /// current zoom: 1 down to the zoom where the floor binds. Drawing only;
  /// hitboxes stay arena units.
  double floorScale(double size, double floor) =>
      math.max(1.0, floor / (size * zoom));

  /// Advances the zoom toward [want]. [hold]: a threat the player must read
  /// (dive tell, rush lock, ground-missile warning): the zoom never moves
  /// out and eases back toward 1. [reduced]: [want] is the static framing,
  /// ramped at [reducedRate], never dynamic.
  /// [carrier]: the carrier band ([carrierMinZoom]); a hold eases back
  /// toward [carrierMaxZoom] (the engage framing), not 1.
  void stepZoom(
    double dt,
    double want, {
    bool hold = false,
    bool reduced = false,
    bool carrier = false,
  }) {
    this.carrier = carrier;
    if (reduced) {
      final framing = carrier ? carrierReducedZoom : reducedZoom;
      target = want <= framing ? framing : 1;
      final d = target - zoom;
      zoom += d.clamp(-reducedRate * dt, reducedRate * dt);
      return;
    }
    final lo = floorZoom;
    target = want.clamp(lo, 1.0);
    final top = carrier ? carrierMaxZoom : 1.0;
    if (hold) {
      target = math.max(
        target,
        math.min(math.max(top, zoom), zoom + maxRate * dt),
      );
    }
    final d = target - zoom;
    // Eased: full rate far from the target, slowing within 0.02 of it.
    final ease = (d.abs() / .02).clamp(.15, 1.0);
    final step = maxRate * ease * dt;
    zoom = (zoom + d.clamp(-step, step)).clamp(lo, 1.0);
  }

  /// Advances the follow toward the boss at [bossX] and glide phase
  /// [glide] (−1..1), at [strength] (0..1; 0 under reduced motion).
  void stepFollow(
    double dt, {
    required double bossX,
    required double glide,
    required double strength,
  }) {
    final k = 1 - math.exp(-dt * 3 / followSeconds);
    followStrength += (strength.clamp(0.0, 1.0) - followStrength) * k;
    final wantX = followPan * ((bossX - 180) / 100).clamp(-1.0, 1.0);
    final wantY = followHorizon * glide.clamp(-1.0, 1.0);
    fx += (wantX - fx) * k;
    fy += (wantY - fy) * k;
  }

  /// Arena point to screen point (arena units of the unzoomed frame).
  Offset toScreen(Offset p) =>
      Offset(pivotX + zoom * (p.dx - pivotX), pivotY + zoom * (p.dy - pivotY));

  /// Screen point to arena point (the inverse of [toScreen]).
  Offset toArena(Offset s) =>
      Offset(pivotX + (s.dx - pivotX) / zoom, pivotY + (s.dy - pivotY) / zoom);

  /// A screen-space drag to arena units (the ship follows the finger).
  double deltaToArena(double dx) => dx / zoom;

  /// The gameplay layer's transform (column-major 4×4 for Canvas.transform).
  Float64List get gameplayMatrix {
    final z = zoom;
    return Float64List.fromList([
      z, 0, 0, 0, //
      0, z, 0, 0,
      0, 0, 1, 0,
      pivotX * (1 - z), pivotY * (1 - z), 0, 1,
    ]);
  }

  /// The background's transform: altitude stretch about the horizon, then
  /// the follow skew, then the horizontal overscan about the centre.
  Float64List get backgroundMatrix {
    const h = GroundCamera.horizon, span = 520 - h;
    final s = followStrength;
    final px = fx * s, py = fy * s;
    // Follow: x' = x + px·(w0 + w1·(y − h)/span), y' = y + py·(same weight)
    // with w0 = horizon weight, w1 = near − horizon weight.
    const w0 = horizonWeight, w1 = nearWeight - horizonWeight;
    // Altitude: y1 = h + A·(y − h).
    final a = altitude;
    // Compose: y1 = a·y + h(1 − a); weight(y1) = w0 + w1·(y1 − h)/span
    //   = w0 + w1·a·(y − h)/span.
    // x' = kx·(x + px·weight − 180) + 180
    // y' = y1 + py·weight
    final kx = 1 + overscan * s;
    final dwdy = w1 * a / span; // d weight / d y
    final w0y = w0 - dwdy * h; // weight at y = 0
    // x' = kx·x + kx·px·(w0y + dwdy·y) + 180(1 − kx)
    // y' = a·y + h(1 − a) + py·(w0y + dwdy·y)
    final xx = kx, xy = kx * px * dwdy, xt = kx * px * w0y + 180 * (1 - kx);
    final yy = a + py * dwdy, yt = h * (1 - a) + py * w0y;
    return Float64List.fromList([
      xx, 0, 0, 0, //
      xy, yy, 0, 0,
      0, 0, 1, 0,
      xt, yt, 0, 1,
    ]);
  }

  /// Where a background point is drawn (tests, review).
  Offset backgroundPoint(Offset p) {
    final m = backgroundMatrix;
    return Offset(
      m[0] * p.dx + m[4] * p.dy + m[12],
      m[1] * p.dx + m[5] * p.dy + m[13],
    );
  }
}
