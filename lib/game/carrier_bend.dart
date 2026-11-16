import 'dart:math' as math;
import 'dart:ui' as ui;

import 'carrier_script.dart';

/// carrier-v3 §2: one stored view (45°, yaw 0), bent at runtime. The bend
/// fakes a heading lean ψ, a bank φ and a pitch change θ of a few degrees
/// as an analytic displacement of a textured triangle mesh (the terrain's
/// technique), pivoted on the hangar deck so the hit windows never move.
///
/// Pure maths. carrier-render-engine §2: the painter composes the hull
/// into one texture and warps one mesh with this displacement
/// (`carrier_compose.dart`); there is no per-layer lag, so the hull turns
/// as one rigid body.
class CarrierBend {
  CarrierBend({this.limits = const CarrierBendLimits()});

  CarrierBendLimits limits;

  /// The bend in radians (after the springs, before the buffet).
  double lean = 0, bank = 0, pitch = 0;
  double _leanV = 0, _bankV = 0, _pitchV = 0;

  /// Buffet noise on bank and pitch (radians).
  double buffetBank = 0, buffetPitch = 0;
  double _clock = 0;

  /// Springs (critically damped): ω per parameter (design §2.3).
  static const leanOmega = 1.4, bankOmega = 1.8, pitchOmega = 1.2;

  static const deg = math.pi / 180;

  /// The view's pitch p₀ and the deck pivot Q (the core window).
  static const p0 = 45 * deg;
  static const qx = 0.0, qy = 25.0;

  /// The deck lock w(r) = smoothstep(lockInner, lockOuter, |P − Q|).
  static const lockInner = 40.0, lockOuter = 160.0;

  /// Until the re-render, the height-parallax terms are capped (§2.5).
  static const parallaxCap = 4.0;

  /// A held pose (radians: lean, bank, pitch) for review strips; null in
  /// the game.
  (double, double, double)? pose;

  /// Total bend (springs + buffet) used by the mesh.
  double get psi => lean;
  double get phi => bank + buffetBank;
  double get theta => pitch + buffetPitch;

  void reset() {
    lean = bank = pitch = _leanV = _bankV = _pitchV = 0;
    buffetBank = buffetPitch = 0;
  }

  /// One step. [vx], [ax]: the hull's horizontal velocity and acceleration
  /// normalised to its maxima (−1..1); [glide] its vertical glide velocity
  /// normalised (−1..1); [takeoff] the take-off pulse 0..1 (nose up to
  /// [CarrierBendLimits.takeoffPitch]); [buffet] the buffet's strength 0..1
  /// (climb × speed). [reduced]: no bend at all (drawn rigid).
  void update(
    double dt, {
    required double vx,
    required double ax,
    double glide = 0,
    double takeoff = 0,
    double buffet = 0,
    bool reduced = false,
  }) {
    _clock += dt;
    if (reduced) {
      reset();
      return;
    }
    final hold = pose;
    if (hold != null) {
      lean = hold.$1;
      bank = hold.$2;
      pitch = hold.$3;
      buffetBank = buffetPitch = 0;
      return;
    }
    final l = limits;
    final leanT = l.leanMax * deg * vx.clamp(-1.0, 1.0);
    final bankT = l.bankMax * deg * ax.clamp(-1.0, 1.0);
    final pitchT = takeoff > 0
        ? l.takeoffPitch * deg * takeoff.clamp(0.0, 1.0)
        : l.pitchMax * deg * glide.clamp(-1.0, 1.0);
    final sl = _spring(lean, _leanV, leanT, leanOmega, dt);
    final sb = _spring(bank, _bankV, bankT, bankOmega, dt);
    final sp = _spring(pitch, _pitchV, pitchT, pitchOmega, dt);
    lean = sl.$1;
    _leanV = sl.$2;
    bank = sb.$1;
    _bankV = sb.$2;
    pitch = sp.$1;
    _pitchV = sp.$2;
    lean = lean.clamp(-l.leanMax * deg, l.leanMax * deg);
    bank = bank.clamp(-l.bankMax * deg, l.bankMax * deg);
    final pm = math.max(l.pitchMax, l.takeoffPitch) * deg;
    pitch = pitch.clamp(-pm, pm);
    // A slow, low buffet: smooth noise at 1.5–3 Hz (two detuned sines per
    // axis), never on the hull's centre (the deck lock holds it).
    final b = l.buffet * deg * buffet.clamp(0.0, 1.0);
    final t = _clock;
    buffetBank =
        b *
        (.6 * math.sin(t * 2 * math.pi * 1.7) +
            .4 * math.sin(t * 2 * math.pi * 2.9 + 1.3));
    buffetPitch =
        b *
        (.6 * math.sin(t * 2 * math.pi * 1.5 + .7) +
            .4 * math.sin(t * 2 * math.pi * 2.6 + 2.1));
  }

  static (double, double) _spring(
    double x,
    double v,
    double target,
    double w,
    double dt,
  ) {
    // Sub-stepped semi-implicit Euler: stable at any frame time.
    final n = (dt / (1 / 120)).ceil().clamp(1, 8);
    final h = dt / n;
    for (var i = 0; i < n; i++) {
      final a = w * w * (target - x) - 2 * w * v;
      v += a * h;
      x += v * h;
    }
    return (x, v);
  }

  /// The displacement of hull-local point ([x], [y]) at height [h] for
  /// bend ([psi], [phi], [theta]) (radians), deck lock applied (design
  /// §2.2). Returns (dx, dy).
  static (double, double) displacement(
    double x,
    double y,
    double h,
    double psi,
    double phi,
    double theta, {
    double cap = parallaxCap,
  }) {
    final rx = x - qx, ry = y - qy;
    final r = math.sqrt(rx * rx + ry * ry);
    final w = _smooth(lockInner, lockOuter, r);
    if (w <= 0) return (0, 0);
    const sp = 0.7071067811865476, cp = 0.7071067811865476;
    // lean: a rotation in the hull's plane, projected, with height parallax.
    final leanPar = (-psi * h * cp / sp).clamp(-cap, cap);
    var dx = -psi * ry / sp + leanPar;
    var dy = psi * rx * sp;
    // bank: one flank drops, the other lifts; tall modules tip sideways;
    // the near side is slightly larger.
    dx += (-h * phi).clamp(-cap, cap) + x * (x * phi / 600);
    dy += -x * phi * cp;
    // pitch: a Mode-7 row scale plus height parallax.
    final s1 = math.sin(p0 + theta), c1 = math.cos(p0 + theta);
    dy += ry * (s1 / sp - 1) - (h * (c1 - cp)).clamp(-cap, cap);
    return (w * dx, w * dy);
  }

  /// Where hull-local point ([x], [y]) at height [h] is drawn under this
  /// bend.
  ui.Offset displace(double x, double y, {double h = 0}) {
    final (dx, dy) = displacement(x, y, h, psi, phi, theta);
    return ui.Offset(x + dx, y + dy);
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Height per module mount until the re-render (design §2.2): bow 0,
  /// ventral −20, lateral 10, dorsal 60. The carapace is the hull's
  /// reference plane (0).
  static double heightOf(String module) {
    final slot = module.split('.').first;
    return switch (slot) {
      'carapace' || 'prow' || 'barrier' || 'bow' => 0,
      'tendril' => -20,
      'wing' || 'maw' => 10,
      _ => 60, // spines, emitter, blister, sac, crown
    };
  }

  /// Whether a module is a wing, arm or sail (the vortex trails' tips).
  static bool lags(String module) {
    final slot = module.split('.').first;
    return slot == 'wing' || slot == 'emitter' || slot == 'tendril';
  }
}
