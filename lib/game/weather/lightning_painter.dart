// --- lightning-rework: what a bolt leaves on the brood and on the ship
// (openspec/changes/lightning-rework, design §4 "Presentation").
//
// Procedural pixel strokes only, no atlas: the stun's crackle and tumble,
// the lightning-rod armour and its charge glow, the ship's static before a
// bolt and its zap after one. Every shape is a pure function of the model,
// the clock and the creature's seed (no state, no randomness per frame).
//
// Colour (plan/style-guide.md, docs/styleguide/alien-troops.md §4): the
// lightning is Stormfront's white core and pale violet halo; the rods are
// the brood's own dark iron with bone tips (the insignia's bone), never
// cyan or teal, which belong to friendly technology. The shoulder rods
// stay clear of the head anchor, where the rank glyph sits.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../model.dart';

/// The rod armour's candidate shapes (the review sheet compares them;
/// [LightningPainter.pick] is the pick, plan/render-runs/lightning-rework.md).
enum RodStyle { shoulders, crest, crown }

abstract final class LightningPainter {
  static const core = Color(0xFFFFFFFF);
  static const halo = Color(0xFFCFC4FF);
  static const iron = Color(0xFF2E2A33);
  static const ironLight = Color(0xFF5A5262);
  static const bone = Color(0xFFE9DFC8);
  static const _tell = Color(0xFFFFB45A);

  /// The pick: two rods rising off the shoulders (they frame the rank glyph
  /// instead of covering it, and read as a pair of spikes at 0.5x).
  static const pick = RodStyle.shoulders;

  /// The style drawn (the review sheet compares the candidates).
  static RodStyle rodStyle = pick;

  /// A stunned creature's roll (radians): a quick wobble while it falls,
  /// settling as it climbs back (none with reduced motion).
  static double tumble(Demon d, double time, {bool reduced = false}) {
    if (!d.stunned || reduced) return 0;
    final falling = d.stunFall > 0;
    final amp = falling ? .55 : .22 * (d.stun / LightningTuning.maxStun);
    return amp * math.sin(time * (falling ? 23 : 11) + d.seed * 3);
  }

  /// Whether the ship is hidden this frame: it flickers for the first half
  /// of its zap (never with reduced motion).
  static bool shipFlickerOff(ArcadeModel m) =>
      !m.reducedMotion &&
      m.shipShock > LightningTuning.shipShock / 2 &&
      (m.visualClock * 20).floor().isOdd;

  /// A creature's lightning gear and state, drawn in its own transform
  /// around [pos] at scale 1 (40-unit body; [large]: the 128-unit
  /// sentinel cell). [alpha]: its gear reveal through the fog.
  static void creature(
    Canvas c,
    Demon d,
    Offset pos,
    double time, {
    bool reduced = false,
    double alpha = 1,
    RodStyle? style,
  }) {
    if (alpha <= 0) return;
    final large = d.isLarge;
    if (d.lightningRods) {
      rods(
        c,
        pos,
        style ?? rodStyle,

        large: large,
        charge: _charge(d),
        alpha: alpha,
        time: time,
        reduced: reduced,
        seed: d.seed,
      );
    }
    if (d.stunned) {
      stunSparks(
        c,
        pos,
        d.seed,
        time,
        large: large,
        reduced: reduced,
        alpha: alpha,
        strength: _stunStrength(d),
      );
    }
  }

  static double _charge(Demon d) =>
      (d.charged / LightningTuning.charge).clamp(0.0, 1.0);

  static double _stunStrength(Demon d) => d.stunFall > 0
      ? 1
      : (d.stun / LightningTuning.maxStun * 1.6).clamp(.35, 1.0);

  /// The rod armour: dark iron shafts with bone tips; [charge] (0-1) lights
  /// the tips white-violet and arcs between them.
  static void rods(
    Canvas c,
    Offset pos,
    RodStyle style, {
    bool large = false,
    double charge = 0,
    double alpha = 1,
    double time = 0,
    bool reduced = false,
    double seed = 0,
  }) {
    final k = large ? 2.1 : 1.0;
    // Shafts as (base, tip) pairs in body units around the body centre.
    final shafts = switch (style) {
      RodStyle.shoulders => [
        (const Offset(-8, -4), const Offset(-11, -19)),
        (const Offset(8, -4), const Offset(11, -19)),
      ],
      RodStyle.crest => [(const Offset(0, -9), const Offset(0, -25))],
      RodStyle.crown => [
        (const Offset(-6, -7), const Offset(-10, -19)),
        (const Offset(0, -9), const Offset(0, -22)),
        (const Offset(6, -7), const Offset(10, -19)),
      ],
    };
    Offset at(Offset o) => pos + o * k;
    final shaft = Paint()
      ..isAntiAlias = false
      ..strokeWidth = 2 * k
      ..color = iron.withValues(alpha: alpha);
    final edge = Paint()
      ..isAntiAlias = false
      ..strokeWidth = 1 * k
      ..color = ironLight.withValues(alpha: alpha);
    if (charge > 0) {
      // The charge: a halo round the body, pulsing (steady when reduced).
      final pulse = reduced ? 1.0 : .75 + .25 * math.sin(time * 14 + seed);
      final r = 22.0 * k;
      c.drawCircle(
        pos,
        r,
        Paint()
          ..shader = Gradient.radial(pos, r, [
            halo.withValues(alpha: .38 * charge * pulse * alpha),
            halo.withValues(alpha: 0),
          ]),
      );
    }
    for (final (base, tip) in shafts) {
      c
        ..drawLine(at(base), at(tip), shaft)
        ..drawLine(
          at(base) + Offset(1 * k, 0),
          at(tip) + Offset(1 * k, 0),
          edge,
        );
      // Two collar bands on each shaft (the brood's riveted iron).
      for (final f in const [.35, .7]) {
        final p = at(Offset.lerp(base, tip, f)!);
        c.drawRect(
          Rect.fromCenter(center: p, width: 4 * k, height: 1.4 * k),
          Paint()..color = ironLight.withValues(alpha: alpha),
        );
      }
      // The tip: a bone bead, white-violet and bigger when charged.
      final t = at(tip);
      if (charge > 0) {
        c.drawCircle(
          t,
          (3.5 + 2 * charge) * k,
          Paint()..color = halo.withValues(alpha: .5 * charge * alpha),
        );
      }
      c.drawRect(
        Rect.fromCenter(center: t, width: 3 * k, height: 3 * k),
        Paint()
          ..color = Color.lerp(bone, core, charge)!.withValues(alpha: alpha),
      );
    }
    if (charge > .05 && shafts.length > 1) {
      // An arc jumps between the tips (re-forks 10 times a second).
      final frame = reduced ? 0 : (time * 10).floor();
      for (var i = 0; i + 1 < shafts.length; i++) {
        final a = at(shafts[i].$2), b = at(shafts[i + 1].$2);
        final arc = _arc(
          a,
          b,
          (seed * 977).round() ^ frame * 0x9e37 ^ i,
          sag: -5 * k,
          sway: 2.5 * k,
        );
        c.drawPath(
          arc,
          Paint()
            ..isAntiAlias = false
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 * k
            ..color = core.withValues(alpha: (.5 + .5 * charge) * alpha),
        );
      }
    }
  }

  /// The stun's crackle: four short arcs crawling over the body (steady
  /// with reduced motion), white-violet, [strength] 0-1.
  static void stunSparks(
    Canvas c,
    Offset pos,
    double seed,
    double time, {
    bool large = false,
    bool reduced = false,
    double alpha = 1,
    double strength = 1,
  }) {
    final k = large ? 2.0 : 1.0;
    final frame = reduced ? 0 : (time * 14).floor();
    final r = 13.0 * k;
    final glow = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * k
      ..color = halo.withValues(alpha: .35 * strength * alpha);
    final line = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * k
      ..color = core.withValues(alpha: .9 * strength * alpha);
    for (var i = 0; i < 4; i++) {
      final a0 =
          i * math.pi / 2 + _hash((seed * 131).round() + frame * 7 + i) * 1.4;
      final a = pos + Offset(math.cos(a0), math.sin(a0)) * r;
      final b = pos + Offset(math.cos(a0 + .9), math.sin(a0 + .9)) * (r * .8);
      final arc = _arc(
        a,
        b,
        (seed * 53).round() ^ frame * 31 ^ i * 0x51ed,
        sag: 3 * k,
        sway: 2 * k,
      );
      c
        ..drawPath(arc, glow)
        ..drawPath(arc, line);
    }
  }

  /// Over the fight: the ship's static while it sits in a told core, and
  /// its zap. [tells]: the told columns with their tell progress (0-1);
  /// [shipCore]: the half-width that zaps the ship.
  static void ship(
    Canvas c,
    ArcadeModel m,
    double time, {
    Iterable<({double x, double progress})> tells = const [],
    double shipCore = 13,
    Offset? at,
  }) {
    final reduced = m.reducedMotion;
    final p = at ?? Offset(m.shipX, m.shipDrawY);
    if (!m.shipAway && m.shipShock <= 0) {
      for (final t in tells) {
        if ((m.shipX - t.x).abs() >= shipCore || t.progress < .45) continue;
        // Static on the hull: amber sparks that thicken toward the bolt.
        final n = (2 + 5 * t.progress).floor();
        final frame = reduced ? 0 : (time * 16).floor();
        final spark = Paint()
          ..isAntiAlias = false
          ..color = _tell.withValues(alpha: .5 + .5 * t.progress);
        for (var i = 0; i < n; i++) {
          final h = _hash(frame * 13 + i * 7);
          final h2 = _hash(frame * 29 + i * 11 + 3);
          c.drawRect(
            Rect.fromLTWH(
              (p.dx - 15 + 30 * h).roundToDouble(),
              (p.dy - 12 + 22 * h2).roundToDouble(),
              2,
              2,
            ),
            spark,
          );
        }
      }
    }
    if (m.shipShock <= 0) return;
    final k = (m.shipShock / LightningTuning.shipShock).clamp(0.0, 1.0);
    // A white-violet burst on the hull, fading.
    final r = 34.0 - 10 * k;
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = Gradient.radial(
          p,
          r,
          [
            core.withValues(alpha: .55 * k * k),
            halo.withValues(alpha: .3 * k),
            halo.withValues(alpha: 0),
          ],
          [0, .45, 1],
        ),
    );
    // Arcs crawling over the hull.
    final frame = reduced ? 0 : (time * 18).floor();
    final line = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = core.withValues(alpha: k);
    for (var i = 0; i < 3; i++) {
      final a0 = _hash(frame * 5 + i * 17) * math.pi * 2;
      final a = p + Offset(math.cos(a0) * 18, math.sin(a0) * 11);
      final b = p + Offset(math.cos(a0 + 2.2) * 16, math.sin(a0 + 2.2) * 10);
      c.drawPath(_arc(a, b, frame * 97 + i, sag: 4, sway: 3), line);
    }
    // A stripped shield bursts: its ring breaks into eight shards flying
    // out.
    if (m.shockLost.contains(Power.shield)) {
      final grow = 1 - k;
      final ring = Paint()
        ..isAntiAlias = false
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = halo.withValues(alpha: .9 * k);
      final rr = 22 + 26 * grow;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + .2;
        c.drawArc(Rect.fromCircle(center: p, radius: rr), a, .45, false, ring);
      }
    }
  }

  /// A jagged arc from [a] to [b]: three kinks, bowed by [sag] and jittered
  /// by up to [sway], snapped to whole units.
  static Path _arc(
    Offset a,
    Offset b,
    int seed, {
    double sag = 0,
    double sway = 2,
  }) {
    final d = b - a;
    final len = d.distance;
    final n = len < 1 ? Offset.zero : Offset(-d.dy / len, d.dx / len);
    final path = Path()..moveTo(a.dx.roundToDouble(), a.dy.roundToDouble());
    for (var i = 1; i <= 3; i++) {
      final f = i / 4;
      final bow = math.sin(f * math.pi) * sag;
      final j = (_hash(seed * 7 + i) * 2 - 1) * sway;
      final q = a + d * f + n * (bow + j);
      path.lineTo(q.dx.roundToDouble(), q.dy.roundToDouble());
    }
    path.lineTo(b.dx.roundToDouble(), b.dy.roundToDouble());
    return path;
  }

  static double _hash(int n) {
    var h = (n & 0xffffff) * 0x45d9f & 0x7fffffff;
    h = ((h >> 13) ^ h) * 0x119d & 0x7fffffff;
    return ((h >> 7) & 0xffff) / 0xffff;
  }
}
