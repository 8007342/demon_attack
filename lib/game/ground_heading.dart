import 'dart:math' as math;

import 'ground_blocks_atlas.dart';

/// The distinct screen directions of an authored heading (or layer angle)
/// set and its mirror, in order around the circle (plan/ground-unit-
/// animation.md §2). Angles are screen degrees of the nose: 0 up the plane,
/// 90 screen right, 180 toward the camera, negatives mirrored.
///
/// The ring lives in an unwrapped coordinate so the arc never crosses the
/// wrap: Fleet sets (all authored angles ≤ 90) span −90…90; Host sets span
/// 90…270, with 180 inside the arc and −90 written as 270.
class GroundHeadingRing {
  GroundHeadingRing(List<double> authored)
      : assert(authored.isNotEmpty),
        host = authored.last > 90 {
    final out = <({double u, int index, bool mirror})>[];
    for (var k = 0; k < authored.length; k++) {
      final a = authored[k];
      out.add((u: a, index: k, mirror: false));
      if (a != 0 && a != 180) out.add((u: unwrap(-a), index: k, mirror: true));
    }
    out.sort((a, b) => a.u.compareTo(b.u));
    steps = out;
  }

  /// Host sets unwrap negatives to 180…360.
  final bool host;

  /// Ring entries in increasing unwrapped angle: authored index and mirror.
  late final List<({double u, int index, bool mirror})> steps;

  int get length => steps.length;
  double get lo => steps.first.u;
  double get hi => steps.last.u;

  /// Signed screen angle (−180, 180] to the ring's unwrapped coordinate.
  double unwrap(double a) {
    var w = a % 360; // [0, 360)
    if (!host && w > 180) w -= 360;
    return w;
  }

  /// Unwrapped coordinate back to a signed screen angle (−180, 180].
  static double signed(double u) {
    var w = u % 360;
    if (w > 180) w -= 360;
    return w;
  }

  /// Clamps an unwrapped angle into the arc: to the nearer end by the
  /// angular distance, so a target behind the arc never flips sides.
  double clampArc(double u) {
    if (u >= lo && u <= hi) return u;
    double dist(double a, double b) {
      final d = (a - b).abs() % 360;
      return math.min(d, 360 - d);
    }

    return dist(u, lo) <= dist(u, hi) ? lo : hi;
  }

  /// The ring step nearest to an unwrapped angle.
  int nearest(double u) {
    var best = 0;
    for (var i = 1; i < steps.length; i++) {
      if ((steps[i].u - u).abs() < (steps[best].u - u).abs()) best = i;
    }
    return best;
  }
}

/// A presentation-only turn tracker (plan/ground-unit-animation.md §5),
/// modelled on `CreatureMotion`: smoothed velocity, a rate-limited
/// continuous heading, and a shown authored step that moves one step at a
/// time with hysteresis and a minimum hold. Deterministic for a given input
/// sequence; never touches simulation state or random streams.
class GroundHeading {
  GroundHeading(List<double> authored, GroundTurnClass turn,
      {bool layer = false, double? initial})
      : ring = GroundHeadingRing(authored),
        omega = layer ? turn.omegaArt : turn.omegaHull,
        minHold = turn.minHold {
    angle = ring.clampArc(ring.unwrap(initial ?? authored.last));
    step = ring.nearest(angle);
  }

  final GroundHeadingRing ring;

  /// Turn rate limit (degrees/s; 0 = this class has no such layer, follow
  /// instantly) and the minimum seconds between shown steps.
  final double omega, minHold;

  /// Hysteresis past a midpoint before a step (degrees).
  static const hysteresis = 3.0;

  /// Below this speed (texels/s) the velocity gives no direction.
  static const vMin = 4.0;

  /// Velocity smoothing rate (1/s).
  static const smoothing = 8.0;

  /// Continuous heading (unwrapped degrees) and the shown ring step.
  late double angle;
  late int step;
  double hold = 0;
  double _vx = 0, _vz = 0;
  bool _seeded = false;

  /// Authored index of the shown step and whether it is drawn mirrored.
  int get index => ring.steps[step].index;
  bool get mirror => ring.steps[step].mirror;

  /// The shown step as a signed screen angle.
  double get shown => GroundHeadingRing.signed(ring.steps[step].u);

  /// The continuous heading as a signed screen angle.
  double get signedAngle => GroundHeadingRing.signed(angle);

  /// Puts the tracker straight onto [a] (signed degrees), no turn played.
  void seed(double a) {
    angle = ring.clampArc(ring.unwrap(a));
    step = ring.nearest(angle);
    hold = 0;
    _seeded = true;
  }

  bool get seeded => _seeded;

  /// Screen angle of a velocity: lateral (texels/s, screen right) and depth
  /// (texels/s, up the plane).
  static double angleOf(double lateral, double depth) =>
      math.atan2(lateral, depth) * 180 / math.pi;

  /// Advances by [dt] seconds. [lateral] and [depth] are the raw velocity
  /// (texels/s); [face] is a signed angle to turn toward when not moving
  /// (a foe), and [target] overrides both (a turret's aim). Returns the
  /// step taken: +1 or −1 along the ring, 0 for none.
  int update(double dt,
      {double lateral = 0, double depth = 0, double? face, double? target}) {
    if (dt <= 0) return 0;
    final k = 1 - math.exp(-smoothing * dt);
    _vx += (lateral - _vx) * k;
    _vz += (depth - _vz) * k;
    double? want = target;
    if (want == null) {
      if (math.sqrt(_vx * _vx + _vz * _vz) >= vMin) {
        want = angleOf(_vx, _vz);
      } else {
        want = face;
      }
    }
    if (want != null) {
      final u = ring.clampArc(ring.unwrap(want));
      final d = u - angle;
      final lim = omega <= 0 ? double.infinity : omega * dt;
      angle += d.clamp(-lim, lim);
    }
    hold = math.max(0, hold - dt);
    if (hold > 0) return 0;
    final cur = ring.steps[step].u;
    if (step + 1 < ring.length) {
      final mid = (cur + ring.steps[step + 1].u) / 2;
      if (angle > mid + hysteresis) {
        step++;
        hold = minHold;
        return 1;
      }
    }
    if (step > 0) {
      final mid = (cur + ring.steps[step - 1].u) / 2;
      if (angle < mid - hysteresis) {
        step--;
        hold = minHold;
        return -1;
      }
    }
    return 0;
  }
}
