import 'dart:math' as math;
import 'dart:ui';

/// dive-shield-thinning: the diving shield as ONE continuous asset that thins
/// in place (openspec/changes/dive-shield-thinning, design §2).
///
/// A shield is one thick arc about the creature's centre, drawn in the
/// creature's own transform (scale, roll, bank), so it scales and moves
/// exactly with the body. Its angular width ([halfAngle]) and its centre
/// line ([DiveShieldSpec.mid]) never change: as points are spent only its
/// THICKNESS falls, one step per point, down to a hairline on the last one
/// (the carrier field's principle, carrier-render-engine §4: the membrane
/// stays where it is and wears thin). Its glow and heat cool with it.
///
/// Every layer (glow, body, core, the white-hot leading edge) is a stroke of
/// the same arc, so there are no segments, notches or loose parts.
class DiveShieldSpec {
  const DiveShieldSpec({
    required this.coverHalfWidth,
    required this.clearance,
    required this.full,
    required this.palette,
    this.margin = 1.5,
    this.gap = 2,
  });

  /// The silhouette the shield covers, in local units about the creature's
  /// centre, over every pose the shield is drawn with: its widest
  /// half-width, and the farthest point from the centre within 70° of
  /// straight down (the arc's range and then some).
  final double coverHalfWidth, clearance;

  /// Thickness with every point up (local units).
  final double full;

  /// How far the arc's ends reach past [coverHalfWidth], and the space
  /// between [clearance] and the full shield's inner edge.
  final double margin, gap;

  /// Heat palette, outer glow to the white-hot edge (4 colours).
  final List<Color> palette;

  /// The fixed centre line the shield thins about (it never moves): far
  /// enough that its ends reach past the widest pose and its inner edge,
  /// at full thickness, clears the body below.
  double get mid => math.max(
    (coverHalfWidth + margin) / math.sin(DiveShield.halfAngle),
    clearance + gap + full / 2,
  );

  /// The full shield's inner edge.
  double get inner => mid - full / 2;

  /// The same spec for a body drawn [k] times larger (the angry gargoyle).
  DiveShieldSpec scaled(double k) => DiveShieldSpec(
    coverHalfWidth: coverHalfWidth * k,
    clearance: clearance * k,
    full: full * k,
    palette: palette,
    margin: margin * k,
    gap: gap * k,
  );
}

abstract final class DiveShield {
  /// Half the shield's angular width, measured from straight down: the
  /// same at every shield level, every scale and for every species.
  static const double halfAngle = 62 * math.pi / 180;

  /// The last point's thickness (local units): a bright hairline.
  static const double hairline = 1.25;

  /// Thermal palette (outer glow to the white-hot edge) and the rush's
  /// crimson one (main spec: dive shields are thermal, never cyan).
  static const thermal = [
    Color(0xFFDD2C00),
    Color(0xFFFF6D00),
    Color(0xFFFFC23A),
    Color(0xFFFFF6CC),
  ];
  static const crimson = [
    Color(0xFF5A0A14),
    Color(0xFFB0122A),
    Color(0xFFFF3B3B),
    Color(0xFFFFD6C8),
  ];

  // Silhouettes measured from the committed atlases (opaque px, alpha >
  // 96; test/dive_shield_thinning_test.dart re-measures them): combat.png's
  // dive cells (row base+7, cols 20-31, every species) reach ±25 px and
  // 15.8 px from the centre within 70° of straight down, in a 64 px cell
  // drawn 40 units wide (44 angry); sentinel-effects.png's dive cells (rows
  // 8-9, cols 4-7) ±29 and 37.6, its berserk cells (rows 6-7, every
  // column: the rally poses and the reeling tumble) ±49 and 22.4, at 1 unit
  // per px.

  /// One-point and two-or-three-point ordinary divers (body 40 units wide;
  /// [DiveShieldSpec.scaled] by 44 / 40 when angry).
  static const small = DiveShieldSpec(
    coverHalfWidth: 25 * 40 / 64,
    clearance: 15.9 * 40 / 64,
    full: 5,
    palette: thermal,
  );
  static const medium = DiveShieldSpec(
    coverHalfWidth: 25 * 40 / 64,
    clearance: 15.9 * 40 / 64,
    full: 8,
    palette: thermal,
  );

  /// The sentinel's dive shield.
  static const sentinel = DiveShieldSpec(
    coverHalfWidth: 29,
    clearance: 37.7,
    full: 11,
    palette: thermal,
  );

  /// The sentinel's rush shield: the super-strong one, the thickest.
  static const rush = DiveShieldSpec(
    coverHalfWidth: 49,
    clearance: 22.4,
    full: 15,
    palette: crimson,
    margin: 2,
  );

  /// Thickness with [points] of [max] left: full when whole, one equal step
  /// thinner per spent point, a [hairline] on the last point; 0 when broken.
  static double thickness(DiveShieldSpec s, int points, int max) {
    if (points <= 0 || max <= 0) return 0;
    if (max == 1) return s.full;
    final f = (points.clamp(1, max) - 1) / (max - 1);
    return hairline + (s.full - hairline) * f;
  }

  /// The heat left (0 on the last point, 1 whole): drives the glow and the
  /// colour, which cool with the thickness.
  static double heat(int points, int max) {
    if (max <= 1) return points > 0 ? 1 : 0;
    return ((points.clamp(1, max) - 1) / (max - 1)).toDouble();
  }

  /// Draws the shield about [centre] (local units, under the creature's
  /// transform). [points] / [max] set the thickness; [flash] (0-1) whitens
  /// it for a hit; [clock] drives a shimmer that runs along the arc
  /// (colour only, never the shape; none with [calm]); [opacity] fades it.
  /// [form] (0-1) grows the thickness from a hairline while it forms.
  static void paint(
    Canvas c,
    Offset centre,
    DiveShieldSpec s, {
    required int points,
    required int max,
    double flash = 0,
    double clock = 0,
    bool calm = false,
    double opacity = 1,
    double form = 1,
    double seed = 0,
  }) {
    var th = thickness(s, points, max);
    if (th <= 0 && flash <= 0) return;
    // A breaking shield: the hairline flashes out where it was.
    if (th <= 0) th = hairline;
    th = hairline + (th - hairline) * form.clamp(0.0, 1.0);
    final h = heat(points, max);
    final last = max > 1 && points == 1;
    // The last point flickers (under 2 Hz, WCAG 2.3.1), like the
    // carrier's critical field.
    final flick = last && !calm ? .78 + .22 * math.sin(clock * 11) : 1.0;
    final a = opacity.clamp(0.0, 1.0) * flick;
    if (a <= .01) return;
    final p = s.palette;
    final rect = Rect.fromCircle(center: centre, radius: s.mid);
    const start = math.pi / 2 - halfAngle; // y down: pi / 2 is below
    const sweep = 2 * halfAngle;
    // Butt caps: the ends are radial cuts, so the angular width is exactly
    // [halfAngle] at every thickness (round caps would grow with it).
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;
    void arc(double width, Color color, {double radius = 0}) {
      paint
        ..strokeWidth = width
        ..color = color;
      c.drawArc(
        radius == 0 ? rect : Rect.fromCircle(center: centre, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }

    // 1. Glow: a halo whose reach and strength follow the thickness.
    arc(th + 2 + th * .7, p[0].withValues(alpha: (.12 + .2 * h) * a));
    // 2. Body: the shield's thickness, its colour cooling as it thins.
    arc(th, Color.lerp(p[0], p[1], .35 + .65 * h)!.withValues(alpha: .92 * a));
    // 3. Core: the inner heat band.
    if (th > 2.5) {
      arc(
        th * .55,
        Color.lerp(p[1], p[2], .3 + .7 * h)!.withValues(alpha: .95 * a),
      );
    }
    // 4. The white-hot leading edge, on the outer side (toward the dive).
    final edge = math.max(.9, th * .2);
    arc(
      edge,
      Color.lerp(p[2], p[3], .4 + .6 * h)!.withValues(alpha: a),
      radius: s.mid + (th - edge) / 2,
    );
    // A slow shimmer running along the arc: brightness only.
    if (!calm) {
      final u = ((clock * .9 + seed * .37) % 1.0);
      final at = start + sweep * u;
      final from = math.max(start, at - .18);
      final to = math.min(start + sweep, at + .18);
      paint
        ..strokeWidth = th
        ..color = p[3].withValues(alpha: .28 * a * math.sin(u * math.pi));
      if (to > from) c.drawArc(rect, from, to - from, false, paint);
    }
    if (flash > 0) {
      arc(th + 1.5, const Color(0xFFFFFFFF).withValues(alpha: flash * a));
    }
  }
}
