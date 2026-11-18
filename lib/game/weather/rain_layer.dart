// --- dynamic-weather: the rain layer (openspec/changes/dynamic-weather §2-§5).
//
// Draws a regular level's rain over the backdrop and under everything that
// plays: the light dims a little, the horizon haze thickens, a faint sheen
// lies on the ground, then far streaks, splashes on the ground and near
// streaks. Nothing is drawn over the creatures, the ship or any shot.
//
// Reuses Stormfront's rain (lib/game/bonus/levels/stormfront_painter.dart):
// its colour and its stateless streak field, where each streak is a pure
// function of its index and the clock, so nothing is allocated per drop
// and a rising intensity adds streaks without reshuffling the rest. Unlike
// Stormfront it is batched: each pass is one `drawRawPoints` call. No
// lightning, no flash, no thunder.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../model.dart';
import 'rain_plan.dart';

/// Stable audio-event names for the future music and SFX engine. Data:
/// `tier` ('drizzle' | 'rain' | 'downpour'), `intensity` (0-1, two places),
/// `wind` (slant), `sector`; `rainIntensity` also carries `from`.
abstract final class RainEvents {
  static const start = GameEventNames.rainStart;
  static const stop = GameEventNames.rainStop;
  static const intensity = GameEventNames.rainIntensity;
  static const all = GameEventNames.weather;
}

class RainLayer {
  RainLayer({void Function(GameEvent event)? emit})
    : emit = emit ?? dispatchGameEvent;

  /// Where the audio events go (tests capture them).
  void Function(GameEvent event) emit;

  /// Stormfront's rain colour (StormPainter._rain).
  static const color = Color(0xFFB9C6E8);

  /// The heaviest rain's budget (phone and web): far streaks, near
  /// streaks and splashes (three segments each).
  static const farMax = 200, nearMax = 80, splashMax = 64;

  /// Seconds the drawn rain takes to swing all the way (0 to 1): any
  /// change, including a level's end, is soft.
  static const slew = 3.0;

  /// Reduced motion: half the drops, at about a third of the speed, shorter,
  /// with no splashes and no gusts.
  static const reducedCount = .5, reducedSpeed = .35, reducedLength = .6;

  /// --- phone-performance §4: the quality tier's share of the drops and
  /// splashes (1 at the full tier; the batches stay one draw call each).
  double budget = 1;

  /// The intensity drawn now (0-1), the wind, and the presentation clock.
  double amount = 0, wind = 0, time = 0;
  bool reduced = false;

  /// The current level's plan (null: dry).
  RainSpec? spec;

  /// Forces a plan on every level (review harnesses; null: the run's).
  RainSpec? override;
  int _sector = 0;
  bool _raining = false;
  RainTier? _tier;

  /// Counts drawn in the last frame (perf reporting and tests).
  int lastFar = 0, lastNear = 0, lastSplashes = 0;

  /// The last events sent (tests, diagnostics).
  final List<GameEvent> log = [];

  /// Reads the model (never writes it): the level's plan and clock.
  void advance(double dt, ArcadeModel model, {required bool reduced}) {
    this.reduced = reduced;
    _sector = model.level;
    spec =
        override ??
        // --- weather-everywhere: a storm's rain (the plan's own, or a
        // forced storm's in the tools and the gallery).
        model.weatherRun.storm?.rain ??
        RainPlan.forLevel(
          model.runSeed,
          route: model.cycle,
          sector: model.level,
          bonus: model.bonus != null,
        );
    final mode = model.mode;
    final live =
        mode != RunMode.title &&
        mode != RunMode.travel &&
        mode != RunMode.victory &&
        mode != RunMode.completed;
    final s = spec;
    final target = s == null || !live
        ? 0.0
        : s.intensityAt(model.levelClock, gusts: !reduced);
    advanceTo(dt, target, wind: s?.wind ?? wind);
  }

  /// Moves the drawn rain toward [target] (also the review harness's
  /// entry point) and sends the audio events.
  void advanceTo(double dt, double target, {double? wind}) {
    time += dt;
    if (wind != null) this.wind = wind;
    final step = dt / slew;
    amount = target > amount
        ? math.min(target, amount + step)
        : math.max(target, amount - step);
    _events();
  }

  void _events() {
    if (!_raining && amount >= RainPlan.wet) {
      _raining = true;
      _tier = RainTier.of(amount);
      _send(RainEvents.start, {});
    } else if (_raining && amount < RainPlan.wet * .5) {
      _raining = false;
      _tier = null;
      _send(RainEvents.stop, {});
    } else if (_raining) {
      // A little hysteresis so a gust on a boundary does not chatter.
      final up = RainTier.of(amount - .04), down = RainTier.of(amount + .04);
      final from = _tier!;
      final now = up != null && up.index > from.index
          ? up
          : down != null && down.index < from.index
          ? down
          : from;
      if (now != from) {
        _tier = now;
        _send(RainEvents.intensity, {'from': from.name});
      }
    }
  }

  void _send(String name, Map<String, Object?> extra) {
    final e = GameEvent(name, {
      'tier': (_tier ?? RainTier.of(amount) ?? RainTier.drizzle).name,
      'intensity': (amount * 100).round() / 100,
      'wind': (wind * 100).round() / 100,
      'sector': _sector,
      ...extra,
    });
    log.add(e);
    if (log.length > 32) log.removeAt(0);
    emit(e);
  }

  /// Forget the drawn rain (a new run).
  void reset() {
    amount = 0;
    _raining = false;
    _tier = null;
    spec = null;
  }

  // --- painting ------------------------------------------------------------

  final _far = Float32List(farMax * 4);
  final _near = Float32List(nearMax * 4);
  final _splashYoung = Float32List(splashMax * 12);
  final _splashOld = Float32List(splashMax * 12);

  static final _streak = Paint()
    ..isAntiAlias = false
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.butt;

  /// Over the backdrop and the bonus grade, under the ground units, the
  /// fog layers, the creatures, the ship and the shots. [headroom]: the
  /// band above the arena (playtest-fixes-3); the rain fills it.
  /// [haze]: the sector's fog colour. [perspective]: the ground starts at
  /// the horizon (else in the arena's lower quarter).
  void paint(
    Canvas c, {
    double headroom = 0,
    Color haze = const Color(0xFFB4BED2),
    bool perspective = true,
  }) {
    lastFar = lastNear = lastSplashes = 0;
    final k = amount;
    if (k < RainPlan.wet) return;
    final top = -headroom;
    final full = Rect.fromLTRB(0, top, 360, 520);
    final ground = perspective ? Perspective.horizonY + 12 : 390.0;
    // The light dims a little (under the play: it only adds contrast).
    c.drawRect(full, Paint()..color = Color.fromRGBO(8, 11, 20, .17 * k));
    // The fog thickens at the horizon.
    final h = perspective ? Perspective.horizonY : 300.0;
    c.drawRect(
      Rect.fromLTRB(0, h - 70, 360, h + 80),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, h - 70),
          Offset(0, h + 80),
          [
            haze.withValues(alpha: 0),
            haze.withValues(alpha: .13 * k),
            haze.withValues(alpha: 0),
          ],
          const [0, .45, 1],
        ),
    );
    // Wet sheen: a faint lift of the ground's mid-distance.
    c.drawRect(
      Rect.fromLTRB(0, ground, 360, 520),
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = Gradient.linear(
          Offset(0, ground),
          const Offset(0, 520),
          [
            const Color(0x00C8D4EC),
            Color.fromRGBO(200, 212, 236, .06 * k),
            const Color(0x00C8D4EC),
          ],
          const [0, .35, 1],
        ),
    );
    final count = (reduced ? reducedCount : 1.0) * budget;
    final speed = reduced ? reducedSpeed : 1.0;
    final length = reduced ? reducedLength : 1.0;
    final w = reduced ? wind * .6 : wind;
    // Far: short, slow, faint (parallax by speed, length and alpha).
    lastFar = _streaks(
      _far,
      n: (farMax * k * count).round(),
      salt: 0,
      top: top,
      speedLo: 230 * speed,
      speedHi: 340 * speed,
      lenLo: 4 * length,
      lenHi: 8 * length,
      wind: w * .8,
    );
    _draw(c, _far, lastFar, .13 + .11 * k);
    if (!reduced) {
      lastSplashes = _splashes(
        (splashMax * k * budget).round(),
        ground: ground,
        perspective: perspective,
      );
      _draw(c, _splashYoung, _youngCount * 3, .2 + .14 * k);
      _draw(c, _splashOld, _oldCount * 3, .1 + .08 * k);
    }
    // Near: long, fast, a little brighter (never over the play).
    lastNear = _streaks(
      _near,
      n: (nearMax * k * count).round(),
      salt: 977,
      top: top,
      speedLo: 560 * speed,
      speedHi: 780 * speed,
      lenLo: 11 * length,
      lenHi: 20 * length,
      wind: w * 1.2,
    );
    _draw(c, _near, lastNear, .2 + .14 * k);
  }

  /// One batch: [segments] line segments of [pts] in one draw call.
  void _draw(Canvas c, Float32List pts, int segments, double alpha) {
    if (segments <= 0) return;
    _streak.color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
    c.drawRawPoints(
      PointMode.lines,
      Float32List.sublistView(pts, 0, segments * 4),
      _streak,
    );
  }

  /// Fills [out] with [n] streaks; each is a pure function of its index
  /// and the clock (Stormfront's field: lane, speed and length hashed from
  /// the index). Returns the count.
  int _streaks(
    Float32List out, {
    required int n,
    required int salt,
    required double top,
    required double speedLo,
    required double speedHi,
    required double lenLo,
    required double lenHi,
    required double wind,
  }) {
    n = math.min(n, out.length ~/ 4);
    final span = 520 - top + 40;
    for (var i = 0; i < n; i++) {
      final j = i + salt;
      final lane = hash(j * 7 + 3);
      final v = speedLo + (speedHi - speedLo) * hash(j * 13 + 1);
      final len = lenLo + (lenHi - lenLo) * hash(j * 5 + 2);
      final fall = (time * v + lane * span) % span;
      final y = top - 20 + fall;
      // Wrap across a 400-unit strip so a slant never empties a corner.
      final x = (hash(j * 11 + 7) * 400 + fall * wind) % 400 - 20;
      out[i * 4] = x.roundToDouble();
      out[i * 4 + 1] = y.roundToDouble();
      out[i * 4 + 2] = (x + len * wind).roundToDouble();
      out[i * 4 + 3] = (y + len).roundToDouble();
    }
    return n;
  }

  /// Splashes on the ground: a crown of two flecks and a widening ripple,
  /// smaller toward the horizon. Each lives a fixed cycle at a fresh hashed
  /// spot and shows for its first half. Young and old halves go to two
  /// batches (brighter, dimmer). Returns the count drawn.
  int _splashes(int n, {required double ground, required bool perspective}) {
    var young = 0, old = 0;
    n = math.min(n, splashMax);
    for (var i = 0; i < n; i++) {
      final period = .42 + .3 * hash(i * 17 + 5);
      final t = time / period + hash(i * 23 + 9);
      final cycle = t.floor();
      final age = t - cycle;
      if (age >= .5) continue;
      final a = age / .5;
      final seed = (i * 131 + cycle * 7919) & 0x3fffffff;
      final x = 6 + 348 * hash(seed);
      final depth = math.pow(hash(seed + 1), .7).toDouble();
      final y = (ground + (520 - ground) * depth).roundToDouble();
      final s = perspective ? .5 + 1.1 * depth : 1.0;
      final out = a < .5 ? _splashYoung : _splashOld;
      final o = (a < .5 ? young++ : old++) * 12;
      final spread = (1.5 + 3.5 * a) * s, rise = (3 - 2 * a) * s;
      final ripple = (2 + 5 * a) * s;
      out
        ..[o] = (x - s).roundToDouble()
        ..[o + 1] = y
        ..[o + 2] = (x - spread).roundToDouble()
        ..[o + 3] = (y - rise).roundToDouble()
        ..[o + 4] = (x + s).roundToDouble()
        ..[o + 5] = y
        ..[o + 6] = (x + spread).roundToDouble()
        ..[o + 7] = (y - rise).roundToDouble()
        ..[o + 8] = (x - ripple).roundToDouble()
        ..[o + 9] = y + 1
        ..[o + 10] = (x + ripple).roundToDouble()
        ..[o + 11] = y + 1;
    }
    _youngCount = young;
    _oldCount = old;
    return young + old;
  }

  int _youngCount = 0, _oldCount = 0;

  /// A 0-1 hash of [n] that stays exact on the web (no product above
  /// 2^53): a Wang-style mix with a small multiplier.
  static double hash(int n) {
    const mask = 0x3fffffff;
    var h = n & mask;
    h = (h ^ 61) ^ (h >> 16);
    h = (h + (h << 3)) & mask;
    h ^= h >> 4;
    h = (h * 0x27d5) & mask;
    h ^= h >> 15;
    h = (h * 0x1b3) & mask;
    h ^= h >> 13;
    return (h & 0xffff) / 0xffff;
  }
}
