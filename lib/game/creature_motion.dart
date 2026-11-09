import 'dart:math' as math;

import 'model.dart';

/// Presentation-only flight state of one ordinary creature: which way it is
/// banking, where it is in its wing stroke and whether it is gliding.
///
/// Velocity is measured here from successive rendered positions (the
/// simulation is never read for anything but `x`, `y` and `seed`, and never
/// written), smoothed, and turned into discrete states with hysteresis so
/// the frame choice does not flicker. See plan/sprite-atlas.md
/// ("Frame selection").
class CreatureMotion {
  CreatureMotion(double seed) : phase = (seed * 0.37) % 1.0;

  /// -1 banking/moving left, 0 neutral 3/4 hover, 1 banking/moving right.
  int dir = 0;

  /// Wing-stroke phase in [0, 1): downstroke first, then upstroke.
  double phase;

  /// Wings held spread while sinking.
  bool gliding = false;
  double glideClock = 0;

  /// Smoothed velocity in arena units per second.
  double vx = 0, vy = 0;
  double? _lastX, _lastY;
  double _dirHold = 0, _glideHold = 0;

  /// Thresholds (arena units / s) and minimum hold times (s).
  static const double turnEnter = 55, turnExit = 24;
  static const double glideEnter = 70, glideExit = 32;
  static const double minHold = 0.14;
  static const double smoothing = 12;

  /// Strokes per second at rest: one full stroke every 0.5 s.
  static const double strokeRate = 2;

  /// Share of the stroke spent in the downstroke for climbing, level and
  /// sinking flight: climbing drives down harder, sinking lingers in the
  /// folded upstroke.
  static const double climbShare = 0.62, levelShare = 0.5, sinkShare = 0.38;

  void update(double x, double y, double dt) {
    if (dt <= 0) return;
    final lx = _lastX, ly = _lastY;
    _lastX = x;
    _lastY = y;
    if (lx == null || ly == null) return;
    // Teleports (formation resets, respawns) are not motion.
    if ((x - lx).abs() > 60 || (y - ly).abs() > 60) return;
    final k = 1 - math.exp(-smoothing * dt);
    vx += ((x - lx) / dt - vx) * k;
    vy += ((y - ly) / dt - vy) * k;

    _dirHold = math.max(0, _dirHold - dt);
    if (_dirHold == 0) {
      final next = switch (dir) {
        0 when vx <= -turnEnter => -1,
        0 when vx >= turnEnter => 1,
        -1 when vx >= turnEnter => 1,
        1 when vx <= -turnEnter => -1,
        -1 when vx > -turnExit => 0,
        1 when vx < turnExit => 0,
        _ => dir,
      };
      if (next != dir) {
        dir = next;
        _dirHold = minHold;
      }
    }

    _glideHold = math.max(0, _glideHold - dt);
    if (_glideHold == 0) {
      final next = gliding ? vy > glideExit : vy > glideEnter;
      if (next != gliding) {
        gliding = next;
        _glideHold = minHold * 2;
        glideClock = 0;
      }
    }
    if (gliding) {
      glideClock += dt;
    } else {
      final rate = vy < -30 ? strokeRate * 1.3 : strokeRate;
      phase = (phase + rate * dt) % 1.0;
    }
  }

  /// Flight frame 0-9: 0-3 downstroke, 4-7 upstroke, 8-9 glide.
  int get frame {
    if (gliding) return 8 + (glideClock * 2.5).floor() % 2;
    final share = vy < -30
        ? climbShare
        : vy > 25
        ? sinkShare
        : levelShare;
    if (phase < share) return (phase / share * 4).floor().clamp(0, 3);
    return 4 + ((phase - share) / (1 - share) * 4).floor().clamp(0, 3);
  }
}

/// Tracks [CreatureMotion] per live ordinary demon, keyed by identity.
class CreatureMotionTracker {
  final _state = Expando<CreatureMotion>('creatureMotion');

  CreatureMotion? of(Demon d) => _state[d];

  /// The state for [d], created on first use.
  CreatureMotion track(Demon d) => _state[d] ??= CreatureMotion(d.seed);

  void update(ArcadeModel model, double dt) {
    for (final d in model.demons) {
      if (d.isLarge) continue;
      track(d).update(d.x, d.y, dt);
    }
  }
}
