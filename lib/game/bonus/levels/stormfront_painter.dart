/// Draws the storm of bonus level #2 (Stormfront): rain, the tells and the
/// bolts. Procedural pixel lines only, no atlas (the level reuses the
/// sector's backdrop and creatures; the dark grade is the level's
/// `BonusLook`). Everything is a pure function of the [StormCell], the
/// presentation clock and each strike's shape seed.
///
/// Colour: the tell is warm amber (the project's hazard-marker colour); the
/// bolt is white with a pale violet-white halo. Never cyan or teal, which
/// belong to friendly technology (plan/style-guide.md).
library;

import 'dart:math' as math;
import 'dart:ui';

import 'storm_cell.dart';

/// --- weather-everywhere: how bright a storm may get (design §3). Every
/// storm keeps WCAG 2.3.1's general-flash limits: a bolt is one flash (a
/// fork lands in the same instant), bolts are seconds apart, the tell's
/// marker blinks at most [StormPainter.maxBlinkHz], and every change over
/// a large area stays under a 10 % relative-luminance step.
class StormLook {
  const StormLook({
    required this.maxFlash,
    required this.skyGlow,
    this.rain = false,
    this.branches = true,
  });

  /// Strongest whole-screen white wash a bolt may cause.
  final double maxFlash;

  /// Peak alpha of the bolt's glow in the cloud (a 260 × 130 oval).
  final double skyGlow;

  /// The level's own rain streaks (Stormfront; a regular sector has the
  /// rain layer).
  final bool rain;

  /// The two side branches of a bolt (off on the LITE tier).
  final bool branches;

  /// Bonus level #2 (its flash was already faint).
  // weather-everywhere: its cloud glow .34 -> .2, under a 10 % luminance
  // step over any backdrop (.34 made 15 % at its centre).
  static const stormfront = StormLook(maxFlash: .10, skyGlow: .2, rain: true);

  /// A regular sector's storm: fainter (it may come to any sector).
  static const regular = StormLook(maxFlash: .06, skyGlow: .18);

  StormLook lite() => StormLook(
    maxFlash: maxFlash,
    skyGlow: skyGlow,
    rain: rain,
    branches: false,
  );
}

class StormPainter {
  const StormPainter();

  static const _tell = Color(0xFFFFB45A);
  static const _tellHot = Color(0xFFFFE9B0);
  static const _core = Color(0xFFFFFFFF);
  static const _halo = Color(0xFFCFC4FF);
  static const _rain = Color(0xFFB9C6E8);

  /// Strongest whole-screen flash a bolt may cause (spec: faint).
  static const maxFlash = .10;

  /// --- weather-everywhere: the tell's marker blinks from 1.5 Hz to at
  /// most this (it was up to 5.7 Hz): never more than three flashes a
  /// second, the WCAG 2.3.1 limit (dynamic-weather research S4).
  static const maxBlinkHz = 3.0;

  /// The marker's blink rate at tell progress [p] (Hz).
  static double blinkHz(double p) => maxBlinkHz / 2 * (1 + p.clamp(0.0, 1.0));

  /// Whether the marker of [s] is lit (steady with [reduced]). The phase
  /// is integrated from the tell's start, so the rate is exactly
  /// [blinkHz] (a phase of time × rate would run far faster late in a
  /// level).
  static bool markerOn(StormStrike s, {bool reduced = false}) {
    if (reduced) return true;
    final e = s.tellTotal * s.tellProgress;
    final rise = maxBlinkHz / 2 / math.max(s.tellTotal, 1e-6);
    final cycles = maxBlinkHz / 2 * e + rise * e * e / 2;
    return math.sin(cycles * 2 * math.pi) > -.2;
  }

  /// The row the ship flies on and the bottom of the arena.
  static const _shipRow = 477.0, _floor = 520.0;

  /// Under the creatures, over the backdrop: rain and the bolt's glow in
  /// the cloud. [time]: presentation seconds. Nothing with [reduced].
  void paintSky(
    Canvas canvas,
    StormCell cell, {
    required double time,
    bool reduced = false,
    StormLook look = StormLook.stormfront,
    bool noFlash = false,
  }) {
    if (reduced) return;
    if (look.rain) _paintRain(canvas, time);
    if (noFlash) return;
    for (final s in cell.strikes) {
      if (!s.landed) continue;
      final k = (s.glowLeft / cell.tuning.glow).clamp(0.0, 1.0);
      // A soft glow high in the cloud where the bolt came from.
      final glow = Rect.fromCenter(
        center: Offset(s.x, 24),
        width: 260,
        height: 130,
      );
      canvas.drawOval(
        glow,
        Paint()
          ..shader = Gradient.radial(glow.center, 130, [
            _halo.withValues(alpha: look.skyGlow * k * k),
            _halo.withValues(alpha: 0),
          ]),
      );
    }
  }

  void _paintRain(Canvas canvas, double time) {
    final paint = Paint()
      ..isAntiAlias = false
      ..strokeWidth = 1
      ..color = _rain.withValues(alpha: .16);
    // 44 streaks; each is a pure function of its index and the clock.
    for (var i = 0; i < 44; i++) {
      final lane = _hash(i * 7 + 3);
      final speed = 520 + 240 * _hash(i * 13 + 1);
      final len = 9 + 9 * _hash(i * 5 + 2);
      final y = ((time * speed + lane * 900) % (_floor + 40)) - 20;
      final x = (lane * 430 - 20) - y * .22 + 60;
      canvas.drawLine(
        Offset(x.roundToDouble(), y.roundToDouble()),
        Offset((x - len * .22).roundToDouble(), (y + len).roundToDouble()),
        paint,
      );
    }
  }

  /// Over the creatures and the ship: tells, bolts and the faint flash.
  void paintStrikes(
    Canvas canvas,
    StormCell cell, {
    required double time,
    bool reduced = false,
    StormLook look = StormLook.stormfront,
  }) {
    for (final s in cell.strikes) {
      if (s.telling) {
        _paintTell(canvas, s, cell.tuning, time, reduced);
      } else if (s.landed) {
        _paintBolt(canvas, s, cell.tuning, reduced, look.branches);
      }
    }
  }

  /// The whole-screen flash of the bolts on screen, 0-[maxFlash] (0 with
  /// reduced motion).
  static double flashOf(
    StormCell cell, {
    bool reduced = false,
    StormLook look = StormLook.stormfront,
  }) {
    if (reduced) return 0;
    var f = 0.0;
    for (final s in cell.strikes) {
      if (!s.landed) continue;
      // Only the first 0.12 s of the afterglow, decaying.
      final age = cell.tuning.glow - s.glowLeft;
      f = math.max(f, look.maxFlash * (1 - age / .12).clamp(0.0, 1.0));
    }
    return f;
  }

  void _paintTell(
    Canvas canvas,
    StormStrike s,
    StormTuning tuning,
    double time,
    bool reduced,
  ) {
    final p = s.tellProgress;
    // The column that will catch creatures: a faint band that brightens.
    canvas.drawRect(
      Rect.fromLTRB(s.x - s.column, 0, s.x + s.column, _floor),
      Paint()..color = _tell.withValues(alpha: .035 + .05 * p),
    );
    // The leader: a thin jagged line reaching down as the tell runs. It
    // re-forks twelve times a second (steady with reduced motion).
    final frame = reduced ? 0 : (time * 12).floor();
    final reach = 24 + (_shipRow - 60) * p;
    final leader = _jag(s.x, 0, reach, s.shape ^ (frame * 0x9e37), 9, 16);
    canvas.drawPath(
      leader,
      Paint()
        ..isAntiAlias = false
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _tellHot.withValues(alpha: .35 + .45 * p),
    );
    // The marker on the ship's row: a stepped bracket as wide as the core
    // that hits the ship, blinking faster toward the bolt.
    // weather-everywhere: at most 3 Hz (was sin(time × (10 + 26 p))).
    final blink = markerOn(s, reduced: reduced) ? 1.0 : .35;
    final mark = Paint()
      ..isAntiAlias = false
      ..color = _tell.withValues(alpha: (.55 + .45 * p) * blink);
    final c = tuning.core;
    final y = _shipRow + 14;
    canvas
      ..drawRect(Rect.fromLTWH(s.x - c, y, c * 2, 2), mark)
      ..drawRect(Rect.fromLTWH(s.x - c, y - 5, 2, 5), mark)
      ..drawRect(Rect.fromLTWH(s.x + c - 2, y - 5, 2, 5), mark);
    // Closing ticks: they slide in to the core as the bolt nears.
    final gap = c + 22 * (1 - p);
    canvas
      ..drawRect(Rect.fromLTWH(s.x - gap - 4, y - 12, 4, 2), mark)
      ..drawRect(Rect.fromLTWH(s.x + gap, y - 12, 4, 2), mark);
  }

  void _paintBolt(
    Canvas canvas,
    StormStrike s,
    StormTuning tuning,
    bool reduced,
    bool branches,
  ) {
    final k = (s.glowLeft / tuning.glow).clamp(0.0, 1.0);
    // A grounded bolt ends on the ship (the rod); any other reaches the
    // ground below the arena.
    final end = s.grounded ? _shipRow - 12 : _floor;
    final main = reduced
        ? (Path()
            ..moveTo(s.x, 0)
            ..lineTo(s.x, end))
        : _jag(s.x, 0, end, s.shape, 12, 22);
    Paint stroke(Color color, double width, double alpha) => Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter
      ..strokeWidth = width
      ..color = color.withValues(alpha: alpha);
    canvas
      ..drawPath(main, stroke(_halo, 9, .16 * k))
      ..drawPath(main, stroke(_halo, 5, .4 * k))
      ..drawPath(main, stroke(_core, 2, math.min(1, .25 + k)));
    if (!reduced && branches) {
      // Two short branches off the main channel.
      final r = math.Random(s.shape ^ 0x51ed);
      for (var b = 0; b < 2; b++) {
        final y0 = 70 + r.nextDouble() * 230;
        final side = r.nextBool() ? 1.0 : -1.0;
        final branch = _jag(
          s.x + side * 4,
          y0,
          y0 + 50 + r.nextDouble() * 40,
          s.shape ^ (b + 1) * 0x7f4a,
          10,
          14,
          drift: side * 11,
        );
        canvas
          ..drawPath(branch, stroke(_halo, 3, .3 * k))
          ..drawPath(branch, stroke(_core, 1, .8 * k));
      }
    }
    // Where it lands: a flat impact glow (on the ship when grounded).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s.x, s.grounded ? _shipRow : _floor - 6),
        width: s.column * 2 * (.6 + .4 * k),
        height: s.grounded ? 30 : 16,
      ),
      Paint()..color = _core.withValues(alpha: .34 * k),
    );
  }

  /// A stepped zigzag from ([x], [y0]) to ([x] + total drift, [y1]): pixel
  /// segments about [step] high, each up to [sway] to a side, snapped to
  /// whole units; it ends on its column.
  static Path _jag(
    double x,
    double y0,
    double y1,
    int seed,
    double sway,
    double step, {
    double drift = 0,
  }) {
    final r = math.Random(seed & 0x3fffffff);
    final path = Path()..moveTo(x.roundToDouble(), y0.roundToDouble());
    final n = math.max(1, ((y1 - y0) / step).round());
    for (var i = 1; i <= n; i++) {
      final y = y0 + (y1 - y0) * i / n;
      final target = x + drift * i;
      final nx = i == n && drift == 0
          ? x
          : target + (r.nextDouble() * 2 - 1) * sway;
      // A horizontal step, then the drop: lightning reads as pixel stairs.
      path
        ..lineTo(nx.roundToDouble(), (y - (y1 - y0) / n * .35).roundToDouble())
        ..lineTo(nx.roundToDouble(), y.roundToDouble());
    }
    return path;
  }

  static double _hash(int n) {
    var h = (n * 0x45d9f3b) & 0x7fffffff;
    h = ((h >> 13) ^ h) * 0x119de1f3 & 0x7fffffff;
    return ((h >> 11) & 0xffff) / 0xffff;
  }
}
