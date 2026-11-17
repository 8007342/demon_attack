// --- crosswind: the wind (openspec/changes/crosswind design §1-§3).
//
// Pure Dart (no dart:ui): which levels of a seeded run are windy, and the
// seeded wind field itself: a lateral push whose direction swings every few
// seconds, with gusts, and an occasional along-screen component that can
// speed a shot up by one step of the hostile speed grid. Unlike the rain,
// the wind is gameplay: `ArcadeModel` (model_wind.dart) samples the field
// every step and drifts every projectile, the player's and the demons'.
//
// Fairness (design §3): every change of the field is planned at least
// [WindField.lead] seconds ahead, and [WindField.forecast] reads the field
// that far in the future, so the windsock and the cloud streaks turn
// before the shots bend.
library;

import 'dart:math' as math;

/// The named strengths. [crosswind] is the bonus level's (never drawn by
/// [WindPlan] for a regular level).
enum WindTier { breeze, gale, crosswind }

/// One level's wind. Times are combat seconds into the level
/// (`ArcadeModel.levelClock`).
class WindSpec {
  const WindSpec({
    required this.tier,
    required this.seed,
    this.startAt = 0,
    this.rampIn = 0,
    this.stopAt = double.infinity,
    this.rampOut = 6,
  });

  final WindTier tier;

  /// The field's own seed (direction swings, gusts, holds).
  final int seed;

  /// When the wind rises and over how many seconds; when it starts to die
  /// away (infinity: it blows to the level's end) and over how long.
  final double startAt, rampIn, stopAt, rampOut;

  bool get stops => stopAt.isFinite;

  /// The drift (u/s) a projectile settles to at full lateral strength.
  double get peakDrift => WindField.peakDrift[tier]!;

  /// The share (0-1) of the tier's strength in force at [t].
  double amountAt(double t) {
    double ramp(double x, double len) =>
        len <= 0 ? (x >= 0 ? 1 : 0) : _smooth((x / len).clamp(0.0, 1.0));
    final on = ramp(t - startAt, rampIn);
    final off = stops ? 1 - ramp(t - stopAt, rampOut) : 1.0;
    return on * off;
  }

  @override
  String toString() =>
      'WindSpec(${tier.name}, ${startAt.toStringAsFixed(0)}s'
      '${stops ? '-${stopAt.toStringAsFixed(0)}s' : '-end'})';

  static double _smooth(double x) => x * x * (3 - 2 * x);
}

/// One planned change of the wind: from [at] it swings over [ramp]
/// seconds to [lateral] (signed, + blows to the right) and [along]
/// (signed, + blows down the screen toward the ship).
class WindShift {
  const WindShift(this.at, this.ramp, this.lateral, this.along, this.gust);
  final double at, ramp, lateral, along;

  /// A gust: a short, strong surge that falls back to the previous wind.
  final bool gust;

  /// When its telegraph begins.
  double get tellAt => at - WindField.lead;
}

/// What the wind does at one instant.
class WindSample {
  const WindSample(this.lateral, this.along, this.amount);

  /// Signed strength across the screen (-1..1, + to the right) and along
  /// it (-1..1, + down the screen), already scaled by [amount].
  final double lateral, along;

  /// The level's share of the tier in force (0: calm).
  final double amount;

  static const calm = WindSample(0, 0, 0);
}

/// The seeded wind of one level: a fixed list of [WindShift]s, drawn once
/// from [WindSpec.seed] up to [horizon] seconds (at most [maxShifts]), so
/// every sample is a pure function of the time.
class WindField {
  WindField(this.spec) : shifts = _plan(spec);

  final WindSpec spec;
  final List<WindShift> shifts;

  /// Seconds between a shift's telegraph and the moment it begins to push:
  /// the windsock and the streaks turn this far ahead of the shots.
  static const lead = 1.5;

  /// Planned length of a level's wind; past it the last wind holds.
  static const horizon = 900.0;
  static const maxShifts = 400;

  /// The drift a shot settles to at full lateral strength (u/s), and the
  /// time constant of that settling (s): a shot is carried by the air, so
  /// its sideways speed never exceeds the wind's.
  static const peakDrift = {
    WindTier.breeze: 34.0,
    WindTier.gale: 52.0,
    WindTier.crosswind: 66.0,
  };
  static const settle = .55;

  /// Along-screen strength at or above which a shot fired with the wind
  /// at its back flies one hostile-grid step (15 u/s) faster.
  static const tailwind = .5;

  /// The wobble on top of the planned wind (share of full strength).
  static const flutter = .06;

  /// Hold (s) between shifts, by tier: the crosswind swings more often.
  static ({double lo, double hi}) holdOf(WindTier t) => switch (t) {
    WindTier.breeze => (lo: 4.5, hi: 8.0),
    WindTier.gale => (lo: 3.5, hi: 6.5),
    WindTier.crosswind => (lo: 2.6, hi: 5.0),
  };

  static List<WindShift> _plan(WindSpec spec) {
    final r = math.Random(spec.seed & 0x3fffffff);
    final hold = holdOf(spec.tier);
    final out = <WindShift>[];
    var t = 0.0;
    var lateral = r.nextBool() ? .7 : -.7;
    var along = 0.0;
    // The opening wind: in force from the start, no telegraph needed (the
    // level's own ramp brings it in).
    out.add(WindShift(-WindField.lead - 1, 0, lateral, along, false));
    while (t < horizon && out.length < maxShifts) {
      // Every draw every time, so the stream never depends on an outcome.
      final holdU = r.nextDouble(), flipU = r.nextDouble();
      final magU = r.nextDouble(), alongU = r.nextDouble();
      final alongMagU = r.nextDouble(), gustU = r.nextDouble();
      final rampU = r.nextDouble();
      t += hold.lo + (hold.hi - hold.lo) * holdU;
      final gust = gustU < (spec.tier == WindTier.crosswind ? .3 : .2);
      final ramp = gust ? .5 : 1.2 + 1.2 * rampU;
      // The direction swings: more often than not to the other side.
      final side = flipU < .6 ? -lateral.sign : lateral.sign;
      final mag = gust ? 1.0 : .45 + .45 * magU;
      final nextAlong = alongU < .35
          ? (alongU < .175 ? -1 : 1) * (.45 + .55 * alongMagU)
          : 0.0;
      out.add(WindShift(t, ramp, side * mag, nextAlong, gust));
      if (gust) {
        // The surge falls back to a wind of the same side, a little later.
        final back = 1.2 + .6 * rampU;
        out.add(WindShift(t + back, 1.0, side * (.5 + .3 * magU), 0, false));
        t += back;
      }
      lateral = out.last.lateral;
      along = out.last.along;
    }
    return List.unmodifiable(out);
  }

  /// The shift in force at [t] (the last whose start has come).
  int _index(double t) {
    var lo = 0, hi = shifts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (shifts[mid].at <= t) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The wind at [t] combat seconds. [flutter] adds the small wobble
  /// (off with reduced motion only in the drawing; the model keeps it).
  WindSample at(double t) {
    final amount = spec.amountAt(t);
    if (amount <= 0) return WindSample.calm;
    final i = _index(t);
    final s = shifts[i];
    final prev = i > 0 ? shifts[i - 1] : s;
    final k = s.ramp <= 0
        ? 1.0
        : WindSpec._smooth(((t - s.at) / s.ramp).clamp(0.0, 1.0));
    var lateral = prev.lateral + (s.lateral - prev.lateral) * k;
    final along = prev.along + (s.along - prev.along) * k;
    lateral +=
        WindField.flutter *
        math.sin(t * 1.7 + spec.seed % 7) *
        math.sin(t * .63);
    return WindSample(
      (lateral * amount).clamp(-1.0, 1.0),
      (along * amount).clamp(-1.0, 1.0),
      amount,
    );
  }

  /// The wind [lead] seconds ahead: what the windsock and the streaks
  /// show, so the player sees every change before it pushes.
  WindSample forecast(double t) => at(t + lead);

  /// Shifts whose telegraph begins in (from, to]: the gust calls.
  Iterable<WindShift> tellsBetween(double from, double to) sync* {
    for (final s in shifts) {
      if (s.tellAt > to) break;
      if (s.tellAt > from && s.at >= 0) yield s;
    }
  }
}

/// Draws a seeded run's wind, level by level (like `RainPlan`).
abstract final class WindPlan {
  /// Keeps the wind's stream apart from the rain's and the bonus plan's.
  static const salt = 0x57494E44; // 'WIND'

  /// About one eligible level in five is windy: "sometimes".
  static const chance = .2;

  /// Sectors that may be windy. The carrier's (5) stays calm.
  static const sectors = {1, 2, 3, 4};

  /// The wind of sector [sector] on route [route] of run [runSeed]; null
  /// when calm. An unseeded run (tests, the calibrated campaign) is calm,
  /// a bonus level has its own (the caller passes [bonus]), and the very
  /// first sector of a run is always calm (the player learns the gun
  /// first).
  static WindSpec? forLevel(
    int? runSeed, {
    required int route,
    required int sector,
    bool bonus = false,
    bool always = false,
  }) {
    if (runSeed == null || bonus || !sectors.contains(sector)) return null;
    if (route == 0 && sector == 1) return null;
    final r = math.Random(
      ((runSeed ^ salt) + route * 1013 + sector * 157) & 0x3fffffff,
    );
    final fires = r.nextDouble() < chance;
    final tierU = r.nextDouble(), startU = r.nextDouble();
    final startT = r.nextDouble(), stopU = r.nextDouble();
    final stopT = r.nextDouble(), rampU = r.nextDouble();
    final seed = r.nextInt(1 << 30);
    // [always]: the calibration tools' "windy" level (the same draws,
    // ignoring the chance).
    if (!fires && !always) return null;
    return draw(
      seed,
      tier: tierU < .55 ? WindTier.breeze : WindTier.gale,
      fromStart: startU < .5,
      startT: startT,
      stops: stopU < .4,
      stopT: stopT,
      rampU: rampU,
    );
  }

  /// A spec from uniform draws (also the tools' forced wind).
  static WindSpec draw(
    int seed, {
    required WindTier tier,
    bool fromStart = true,
    double startT = 0,
    bool stops = false,
    double stopT = 0,
    double rampU = 0,
  }) {
    final startAt = fromStart ? 0.0 : 10 + 30 * startT;
    return WindSpec(
      tier: tier,
      seed: seed,
      startAt: startAt,
      rampIn: fromStart ? 0 : 4 + 4 * rampU,
      stopAt: stops ? startAt + 40 + 40 * stopT : double.infinity,
      rampOut: 5 + 3 * rampU,
    );
  }

  /// The bonus level's wind: the crosswind tier from the start, all level.
  static WindSpec bonusLevel(int levelSeed) =>
      WindSpec(tier: WindTier.crosswind, seed: (levelSeed ^ salt) & 0x3fffffff);
}
