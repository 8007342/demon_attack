import 'dart:math' as math;
import 'dart:ui';

/// dive-shield-thinning: the diving shield as ONE continuous asset that thins
/// in place (openspec/changes/dive-shield-thinning, design §2 and §5).
///
/// The shape is playtest-fixes-3's thermal crescent (its span, nose drop,
/// tapering thickness, colour bands and ember tips: the form the operator
/// approved), drawn whole, in the creature's own transform, so it scales and
/// moves exactly with the body. Its span and leading edge never change: as
/// points are spent only its THICKNESS falls, one equal step per point, to
/// [DiveShield.floor] of full on the last point, never to nothing (the
/// carrier field's principle, carrier-render-engine §4: it stays where it
/// is and wears thin).
///
/// Every colour band is a polygon of the same crescent function (shared
/// leading edge, shared thickness profile), so there are no segments,
/// notches or parts that move apart. The flame lick on the trailing edge is
/// a fixed profile, never an animation of the shape.
class DiveShieldSpec {
  const DiveShieldSpec({
    required this.span,
    required this.nose,
    required this.lead,
    required this.thick,
    required this.lick,
    required this.palette,
  });

  /// Half span, nose drop, leading edge below the centre at the tips,
  /// thickness at the nose and the trailing flame lick (local units).
  final double span, nose, lead, thick, lick;

  /// Heat palette, outer envelope to the white-hot nose (4 colours).
  final List<Color> palette;

  /// The same spec for a body drawn [k] times larger (the angry gargoyle).
  DiveShieldSpec scaled(double k) => DiveShieldSpec(
    span: span * k,
    nose: nose * k,
    lead: lead * k,
    thick: thick * k,
    lick: lick * k,
    palette: palette,
  );
}

abstract final class DiveShield {
  /// The last point's share of the full thickness: worn, never gone.
  static const double floor = .4;

  /// Thermal palette (outer envelope to the white-hot nose) and the rush's
  /// crimson-to-black one (main spec: dive shields are thermal).
  static const thermal = [
    Color(0xFFDD2C00),
    Color(0xFFFF6D00),
    Color(0xFFFFC23A),
    Color(0xFFFFF6CC),
  ];
  static const crimson = [
    Color(0xFF1A0508),
    Color(0xFF8E1020),
    Color(0xFFFF3B3B),
    Color(0xFFFFC2B0),
  ];

  // playtest-fixes-3's sizes (half span / nose / lead / thickness / lick),
  // the form the operator approved on 2026-11-17.
  static const small = DiveShieldSpec(
    span: 16,
    nose: 5.5,
    lead: 7.5,
    thick: 6,
    lick: 2.5,
    palette: thermal,
  );
  static const medium = DiveShieldSpec(
    span: 24,
    nose: 7.5,
    lead: 5.5,
    thick: 7.5,
    lick: 3.5,
    palette: thermal,
  );
  static const sentinel = DiveShieldSpec(
    span: 52,
    nose: 15,
    lead: 3,
    thick: 10,
    lick: 5,
    palette: thermal,
  );

  /// The sentinel's rush shield: the super-strong one, the thickest.
  static const rush = DiveShieldSpec(
    span: 64,
    nose: 18,
    lead: 2,
    thick: 13,
    lick: 6,
    palette: crimson,
  );

  /// Share of the thickness each band keeps (outer first) and its alpha.
  static const bands = [(1.0, .78), (.7, .9), (.42, .95), (.2, 1.0)];

  /// The share of full thickness with [points] of [max] left: 1 whole, one
  /// equal step less per spent point, [floor] on the last; 0 when broken.
  static double wear(int points, int max) {
    if (points <= 0 || max <= 0) return 0;
    if (max == 1) return 1;
    final f = (points.clamp(1, max) - 1) / (max - 1);
    return floor + (1 - floor) * f;
  }

  /// The leading edge (y below the centre) at u in [-1, 1]: never changes.
  static double leadAt(DiveShieldSpec s, double u) =>
      s.lead + s.nose * (1 - u * u);

  /// The full thickness at u (body and flame lick), tapering to the tips.
  static double thickAt(DiveShieldSpec s, double u) {
    final q = math.max(0.0, 1 - u * u);
    return s.thick * math.pow(q, .55) + .6 + s.lick * .55 * (1 - .45 * u * u);
  }

  /// Draws the shield about [centre] (local units, under the creature's
  /// transform). [points] / [max] set the thickness; [flash] (0-1) whitens
  /// it for a hit (a broken shield flashes out at the floor thickness);
  /// [clock] drives the tip embers and the last point's flicker (none with
  /// [calm]); [opacity] fades it.
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
    double seed = 0,
  }) {
    var w = wear(points, max);
    if (w <= 0 && flash <= 0) return;
    if (w <= 0) w = floor;
    final last = max > 1 && points == 1;
    final flick = last && !calm ? .82 + .18 * math.sin(clock * 11) : 1.0;
    final a = opacity.clamp(0.0, 1.0) * flick;
    if (a <= .01) return;
    // Heat: the envelope dims a little as the shield wears.
    final heat = max <= 1 ? 1.0 : (points.clamp(1, max) - 1) / (max - 1);
    const steps = 36;
    Path band(double share) {
      final p = Path();
      for (var i = 0; i <= steps; i++) {
        final u = -1 + 2 * i / steps;
        final x = centre.dx + u * s.span;
        final y = centre.dy + leadAt(s, u) + .5 * share;
        i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
      }
      for (var i = steps; i >= 0; i--) {
        final u = -1 + 2 * i / steps;
        final x = centre.dx + u * s.span;
        p.lineTo(x, centre.dy + leadAt(s, u) - thickAt(s, u) * w * share);
      }
      return p..close();
    }

    final paint = Paint()..isAntiAlias = true;
    final pal = s.palette;
    for (var k = 0; k < bands.length; k++) {
      final (share, alpha) = bands[k];
      paint.color = pal[k].withValues(
        alpha: alpha * (k == 0 ? .6 + .4 * heat : 1) * a,
      );
      c.drawPath(band(share), paint);
    }
    if (flash > 0) {
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: flash * a);
      c.drawPath(band(1), paint);
    }
    if (calm) return;
    // Embers shed from the two tips, attached to them and rising.
    const tipU = .96;
    for (final side in const [-1.0, 1.0]) {
      final tip = Offset(
        centre.dx + side * tipU * s.span,
        centre.dy + leadAt(s, tipU) - thickAt(s, tipU) * w,
      );
      for (var e = 0; e < 3; e++) {
        final age = ((clock * 2.2 + e / 3 + seed * .1) % 1.0);
        final r = (1.4 - age) * s.thick * .14 * (.6 + .4 * w);
        paint.color = Color.lerp(
          pal[2],
          pal[0],
          age,
        )!.withValues(alpha: (1 - age) * .85 * a);
        c.drawCircle(
          tip.translate(side * age * s.thick * .35, -age * s.thick * 1.6),
          math.max(.5, r),
          paint,
        );
      }
    }
  }
}
