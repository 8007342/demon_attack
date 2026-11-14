import 'dart:math' as math;

/// Pseudo-3D depth for the airborne swarm (design: plan/perspective.md).
///
/// The flyover ground is drawn by one camera: a ground point at forward
/// distance z appears at y = horizon + groundSpan * n with scale n = z0 / z
/// (`FlyoverBackground`). Demons fly over that ground, so each carries the
/// same *nearness* n: 1 is the bottom of the screen plane, small values sit
/// near the horizon. Their drawn size, hitbox, muzzle offset and ground
/// shadow all derive from n, and the simulation (model.dart) owns n so what
/// the player sees is what the player hits. Pure functions only.
abstract final class Perspective {
  /// The flyover's horizon line and the ground span below it (arena units);
  /// kept equal to `FlyoverBackground.horizon` / its 520 - horizon span.
  static const horizonY = 172.0;
  static const groundSpan = 348.0;

  /// The swarm flies on an inclined flight sheet: nearness rises linearly
  /// with screen y from [nearTop] at y = [topY] to the ship's own ground
  /// plane ([nearShip], the ground's nearness at the ship, y = 477).
  static const topY = 40.0, shipY = 477.0;
  static const nearTop = .62, nearShip = .876;

  /// Arrivals start this far away, just above the horizon.
  static const nearFar = .30;
  static const arrivalY = horizonY - 18;

  /// Breathing: a depth swing in phase with the formation's vertical bob
  /// (sinking = toward the camera = larger) plus a slow per-demon wander.
  static const breathe = .035, wander = .02;

  /// Extra nearness while diving at the player, eased in by the smoothing.
  static const diveBoost = .08;

  /// Nearness follows its target with this rate (1/s) outside entrances.
  static const followRate = 5.0;

  /// Size factor of an ordinary gargoyle relative to the 40-unit legacy
  /// sprite: gain * n, in 0.1 steps (4-unit sprite steps), 0.5-1.6. At
  /// 1.6 the 64-px cell is drawn at exactly one arena unit per pixel.
  static const smallGain = 1.8, smallStep = .1, smallMin = .5, smallMax = 1.5;

  /// Sentinels keep their 128-unit cell at their hover (n ~ 0.62) and scale
  /// proportionally in 1/16 steps (8-unit steps), 0.75-1.375.
  static const largeRef = .622, largeStep = 1 / 16;
  static const largeMin = .75, largeMax = 1.25;

  /// Shot hitbox half extents at scale 1. Ordinary: the measured opaque
  /// silhouette of the flight frames (44 x 31 of 64 px, 27.5 x 19.5 of the
  /// 40-unit sprite, wing tips included), so the box hugs what is drawn.
  /// Sentinels keep their body box (wing membranes excluded) in proportion.
  static const smallHitHalf = (13.0, 10.0);
  static const largeHitHalf = (27.0, 18.0);

  /// Nearness of the flight sheet at screen [y].
  static double nearnessAtY(double y) =>
      nearTop +
      (nearShip - nearTop) * (y.clamp(-80.0, 560.0) - topY) / (shipY - topY);

  /// The nearness a demon at screen [y] settles toward. [phase] is the
  /// argument of its formation bob, [wanderPhase] a slow per-demon phase.
  static double targetNearness(
    double y, {
    double phase = 0,
    double wanderPhase = 0,
    bool diving = false,
  }) =>
      nearnessAtY(y) +
      breathe * math.sin(phase) +
      wander * math.sin(wanderPhase) +
      (diving ? diveBoost : 0);

  /// Arrival from the distance: entrance progress [s] (eased) moves depth
  /// linearly (z, i.e. 1/n), so the demon creeps out of the haze and rushes
  /// the last stretch. Returns the nearness and the screen-space fraction
  /// travelled (screen offset from the vanishing point grows with n).
  static (double, double) approach(double s, double nearForm) {
    final n = 1 / (1 / nearFar + (1 / nearForm - 1 / nearFar) * s);
    final u = nearForm <= nearFar
        ? 1.0
        : ((n - nearFar) / (nearForm - nearFar)).clamp(0.0, 1.0);
    return (n, u);
  }

  /// Where an arrival heading for [homeX] first appears: close to the
  /// vanishing point, spread a little toward its own side.
  static double arrivalX(double homeX) => 180 + (homeX - 180) * .38;

  /// ... and stacked by its formation row so rows do not overlap far away.
  static double arrivalYFor(double homeY) => arrivalY + (homeY - 150) * .12;

  /// Quantised size factor for nearness [n].
  static double scaleOf(double n, {bool large = false, bool angry = false}) {
    if (large) {
      final raw = n / largeRef;
      return ((raw / largeStep).round() * largeStep).clamp(largeMin, largeMax);
    }
    final raw = n * smallGain * (angry ? 1.1 : 1);
    return ((raw / smallStep).round() * smallStep).clamp(smallMin, smallMax);
  }

  /// Screen y of the flyover ground directly beneath a demon of nearness n.
  static double groundY(double n) => horizonY + groundSpan * n;

  /// Distance haze 0-1: arrivals emerge veiled, formation demons are clear.
  static double haze(double n) => ((.56 - n) / .26).clamp(0.0, 1.0);

  /// Opacity of a creature at nearness [n]: the farthest arrivals are faint
  /// shapes in the weather and gain substance as they close in.
  static double fade(double n) => ((n - .24) / .2).clamp(.3, 1.0);
}
