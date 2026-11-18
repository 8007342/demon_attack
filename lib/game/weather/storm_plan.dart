// --- weather-everywhere: the regular sectors' lightning storms
// (openspec/changes/weather-everywhere design §1-§2).
//
// Pure Dart (no dart:ui). A storm is the heavy end of the rain: only a
// level that rains at least at the `rain` tier can storm, and the storm
// strikes only while that rain is heavy. Which levels storm comes from the
// run seed, the route and the sector alone (its own salt, so the rain's,
// the wind's and the bonus plan's odds never shift). An unseeded run (the
// tests, the calibrated campaign) never storms.
//
// What a bolt does is lightning-rework's (`lib/game/lightning.dart`: the
// stun, the zap, the rank dodges); when and where it strikes is the
// Stormfront `StormCell`, here with a slower, gentler tuning
// ([StormPlan.regular]). How it looks, and its flash limits, are
// `storm_layer.dart`'s.
library;

import 'dart:math' as math;

import '../bonus/levels/storm_cell.dart';
import 'rain_plan.dart';

/// One level's lightning storm. Times are combat seconds into the level
/// (`ArcadeModel.levelClock`).
class StormSpec {
  const StormSpec({required this.rain, required this.seed});

  /// The level's rain: the storm strikes only while it is heavy.
  final RainSpec rain;

  /// The `StormCell`'s seed (where and when the bolts fall).
  final int seed;

  /// The rain's planned intensity (no gusts) at or above which bolts may
  /// fall: the middle of the `rain` tier.
  static const heavy = .4;

  /// Whether bolts may fall at [t]: the rain is heavy enough.
  bool activeAt(double t) => rain.intensityAt(t, gusts: false) >= heavy;

  @override
  String toString() => 'StormSpec(${rain.tier.name}, seed $seed)';
}

/// Draws a seeded run's storms, level by level (like `RainPlan`).
abstract final class StormPlan {
  /// Keeps the storm's stream apart from the rain's, the wind's and the
  /// bonus plan's.
  static const salt = 0x424F4C54; // 'BOLT'

  /// The share of `rain`-tier and `downpour`-tier levels that storm.
  /// With the rain plan's odds (one level in four rains; 40 % of those at
  /// the `rain` tier, 20 % a downpour) a level storms with probability
  /// 0.25 × (0.4 × 0.9 + 0.2 × 1.0) = 0.14: rarer than rain (0.25), a
  /// little rarer than wind (0.2). Drizzle never storms.
  static const rainChance = .9, downpourChance = 1.0;

  /// The expected share of eligible levels that storm (the tests' target).
  static const expected =
      RainPlan.chance * (.4 * rainChance + .2 * downpourChance);

  /// The storm of sector [sector] on route [route] of run [runSeed]; null
  /// when there is none. Like the wind, the run's very first sector is
  /// always calm (the player learns the gun first); bonus levels and the
  /// carrier's sector never storm (they never rain either).
  static StormSpec? forLevel(
    int? runSeed, {
    required int route,
    required int sector,
    bool bonus = false,
  }) {
    if (runSeed == null || bonus) return null;
    if (route == 0 && sector == 1) return null;
    final rain = RainPlan.forLevel(
      runSeed,
      route: route,
      sector: sector,
      bonus: bonus,
    );
    if (rain == null || rain.tier == RainTier.drizzle) return null;
    final r = math.Random(
      ((runSeed ^ salt) + route * 1031 + sector * 163) & 0x3fffffff,
    );
    // Every number every time.
    final fires = r.nextDouble();
    final seed = r.nextInt(1 << 30);
    final chance = rain.tier == RainTier.downpour ? downpourChance : rainChance;
    if (fires >= chance) return null;
    return StormSpec(rain: rain, seed: seed);
  }

  /// A storm on a level that rains [rain] (the tools', the gallery's and
  /// the tests' forced storm).
  static StormSpec force(RainSpec rain, int seed) =>
      StormSpec(rain: rain, seed: seed & 0x3fffffff);

  /// A regular storm's schedule: much rarer bolts than Stormfront's
  /// (6.5-10 s after a bolt, against 3.3-4.7), never forked, at least
  /// 1.25 s of tell, under half of them drawn to the ship. The gaps are
  /// divided by the hostile rate (Easy's storm is slower).
  static const regular = StormTuning(
    first: 6,
    gapMin: 6.5,
    gapMax: 10,
    tell: 1.25,
    shipShare: .45,
    forkChance: 0,
  );
}
