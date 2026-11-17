// --- bonus levels (openspec/changes/bonus-levels, plan/bonus-levels-interface.md)
//
// The data a bonus level, a bonus-only powerup and a run modifier are made
// of. Pure Dart: no Flutter, no model state. Everything here is `const`
// data; the model's hooks live in `lib/game/model_bonus.dart`.
import 'dart:math' as math;

import '../model.dart' show Power;
import 'bonus_challenge.dart';
import 'bonus_mechanic.dart';

export 'bonus_challenge.dart';
export 'bonus_mechanic.dart';

/// With probability [chance] a power drop becomes [power].
class PowerChance {
  const PowerChance(this.power, this.chance);
  final Power power;
  final double chance;
}

/// Which powers may drop. Applies to kill drops and supply crates.
class PowerRules {
  const PowerRules({
    this.banned = const {},
    this.only,
    this.chances = const [],
    this.killDrops = true,
  });

  /// Powers that never drop.
  final Set<Power> banned;

  /// Every drop becomes this power (wins over [banned] and [chances]).
  final Power? only;

  /// Per drop, in list order: with `chance` the drop becomes `power`.
  final List<PowerChance> chances;

  /// False: kills drop no powers (crates still do).
  final bool killDrops;

  static const none = PowerRules();

  bool get isNone =>
      banned.isEmpty && only == null && chances.isEmpty && killDrops;

  /// This rule set (a run modifier) with [inner] (a level's) on top: bans
  /// add up, the inner `only` wins, chances run outer then inner.
  PowerRules merge(PowerRules inner) {
    if (inner.isNone) return this;
    if (isNone) return inner;
    return PowerRules(
      banned: {...banned, ...inner.banned},
      // --- crosswind: a level that bans the run's `only` power wins
      // (Crosswind under Spread Only: the drops fall back to the cycle).
      only: inner.only ?? (inner.banned.contains(only) ? null : only),
      chances: [...chances, ...inner.chances],
      killDrops: killDrops && inner.killDrops,
    );
  }

  /// The power a drop of [candidate] becomes, or null for no drop. [roll]
  /// supplies uniform draws for [chances] (one per entry, always drawn, so
  /// the stream does not depend on earlier outcomes). With [isNone] the
  /// candidate comes back untouched and nothing is drawn.
  Power? resolve(Power candidate, double Function() roll) {
    if (isNone) return candidate;
    var power = candidate;
    for (final c in chances) {
      if (roll() < c.chance) power = c.power;
    }
    final o = only;
    if (o != null) return o;
    if (!banned.contains(power)) return power;
    // The next allowed power in the regular cycle (no draw).
    for (var i = 1; i < Power.values.length; i++) {
      final next = Power.values[(power.index + i) % Power.values.length];
      if (!banned.contains(next)) return next;
    }
    return null;
  }
}

/// A run-wide rule, rolled once per run.
class RunModifierDef {
  const RunModifierDef({
    required this.id,
    required this.chance,
    required this.rules,
    this.brief = '',
    this.label = '',
  });

  /// camelCase; the radio trigger is `runModifier.<id>`.
  final String id;

  /// bonus-balance: the run record's tag on the end-of-run screen and the
  /// scoreboard, upper case ('': the id, spelled out).
  final String label;

  /// bonus-briefing: the rule in a few words, shown on a bonus level's
  /// urgent-mission card while the modifier is in play ('': not shown).
  final String brief;

  /// Probability per run. At most one modifier fires per run: the first
  /// hit in catalogue order.
  final double chance;
  final PowerRules rules;
}

/// A powerup that exists only inside bonus levels: a sum of primitives.
class BonusPowerDef {
  const BonusPowerDef({
    required this.id,
    required this.label,
    required this.badge,
    required this.tint,
    this.twin = false,
    this.seconds = 9,
    this.scoreScale = 1,
    this.magnet = 0,
    this.grants = const [],
    this.fireScale = 1,
  });

  /// camelCase; the radio variant is `bonusPickup.<id>`.
  final String id;

  /// Name for the console, the review studio and semantics (never drawn
  /// over the play area).
  final String label;

  /// Column in combat.png's pickup row: 0 spread, 1 rapid, 2 shield,
  /// 3 heart, 4 powerful, 5 large.
  final int badge;

  /// ARGB the badge is multiplied by, so it never reads as the regular one.
  final int tint;

  /// Draw the badge as an overlapping pair.
  final bool twin;

  /// Its own timer; freezes outside combat like the regular powers.
  final double seconds;

  /// Kill and crate points × this while active.
  final double scoreScale;

  /// Falling pickups and heart pieces within this many units fly to the
  /// ship (0: off).
  final double magnet;

  /// Regular powers collected with it (the usual exclusions apply).
  final List<Power> grants;

  /// Player fire interval × this (below 1 is faster).
  final double fireScale;
}

/// The level's waves, as changes to the replaced sector's calibrated ones.
class BonusWaves {
  const BonusWaves({
    this.count,
    this.rosterScale = 1,
    this.reinforcementScale = 1,
    this.sentinels = true,
    this.elites = true,
    this.maxKind,
  });

  /// Waves in the level; null (the default): the replaced sector's own
  /// number (3 to 7), so the level lasts about as long as the sector
  /// (bonus-balance). Regular sectors have 3 to 7.
  final int? count;

  /// × the sector's roster (at least 3 creatures).
  final double rosterScale;

  /// × the sector's finite reinforcement groups (rounded).
  final double reinforcementScale;

  /// False: no sentinel, no elite in this level.
  final bool sentinels, elites;

  /// Caps the species (0-3); null keeps the sector's own.
  final int? maxKind;

  int roster(int calibrated) => rosterScale == 1
      ? calibrated
      : math.max(3, (calibrated * rosterScale).round());
  int reinforcements(int calibrated) => reinforcementScale == 1
      ? calibrated
      : (calibrated * reinforcementScale).round();
}

/// Parachute supply crates during the level (the carrier fight's crate:
/// three hits, then its pickup falls).
class BonusCrates {
  const BonusCrates({
    this.every = 0,
    this.first = 2,
    this.max = 2,
    this.total = 0,
    this.points = 0,
    this.powers = const [],
    this.bonusPowers = const [],
    this.bonusPowerChance = .25,
  });

  /// Seconds between drops (0: no crates) and before the first.
  final double every, first;

  /// On screen at once; in the whole level (0: unlimited).
  final int max, total;

  /// Per crate opened, × (route + 1).
  final int points;

  /// Drawn uniformly, then filtered by the [PowerRules] in force.
  final List<Power> powers;

  /// Ids from the catalogue; a crate carries one with [bonusPowerChance].
  final List<String> bonusPowers;
  final double bonusPowerChance;

  bool get active => every > 0 && (powers.isNotEmpty || bonusPowers.isNotEmpty);
}

/// What the level adds to the score.
class BonusScoring {
  const BonusScoring({
    this.pointsScale = 1,
    this.clearBonus = 0,
    this.flawlessBonus = 0,
    this.cap = 0,
    this.clearPar = 0,
    this.flawlessPar = 0,
    this.capPar = 0,
  });

  /// Kill points × this inside the level.
  final double pointsScale;

  /// On the level's last kill, × (route + 1).
  final int clearBonus;

  /// Added to it when no ship was lost in the level, × (route + 1).
  final int flawlessBonus;

  /// The most the level may add beyond ordinary kill points, × (route + 1).
  /// The cap in force is this plus [capPar] of the sector's par; both 0:
  /// no cap.
  final int cap;

  /// The same three as shares of the replaced sector's par score
  /// (`ArcadeModel.sectorPar`: what its rosters pay in kill points on this
  /// route and difficulty). Prefer these: a bonus level then stays worth
  /// about the sector it replaces wherever the plan puts it.
  final double clearPar, flawlessPar, capPar;
}

/// Presentation only: a colour grade over the sector's own backdrop.
class BonusLook {
  const BonusLook({
    this.tint = 0x00000000,
    this.strength = 0,
    this.glow = 0x00000000,
    this.fog = 0,
    this.cue,
  });

  /// ARGB wash over the world (under creatures, ship, shots and HUD).
  final int tint;

  /// 0-1: how much of the wash shows.
  final double strength;

  /// ARGB light at the horizon (a low sun, a storm glow); alpha 0: none.
  final int glow;

  /// Extra haze 0-.5 over the far ground.
  final double fog;

  /// Its own music cue, once one exists (the sector's cue plays until then).
  final String? cue;
}

/// One bonus level: the content that replaces a regular sector's.
class BonusLevelDef {
  const BonusLevelDef({
    required this.id,
    required this.label,
    required this.weight,
    this.sectors = const {2, 3, 4},
    this.minRoute = 0,
    this.maxRoute = 4,
    this.waves = const BonusWaves(),
    this.rules = PowerRules.none,
    this.crates = const BonusCrates(),
    this.scoring = const BonusScoring(),
    this.look = const BonusLook(),
    this.mechanic,
    this.brief = '',
    this.how = '',
    this.wind = false,
    this.challenge,
  });

  /// --- crosswind: the level blows the crosswind tier of the wind
  /// (lib/game/weather/wind_field.dart) from its start to its end.
  final bool wind;

  /// camelCase; the radio triggers key on it.
  final String id;

  /// Name for the console, the review studio and the title line of the
  /// urgent-mission card (bonus-briefing); never drawn over the play area.
  final String label;

  /// bonus-briefing: the level's goal, shown on its urgent-mission card
  /// ('': the card shows none). bonus-briefing-clarity: one short line a
  /// first-time player (a kid too) gets at a glance.
  final String brief;

  /// bonus-briefing-clarity: how to do it, in one short line under the
  /// goal (what to shoot, where to fly); '': none.
  final String how;

  /// Relative odds among the levels eligible for the drawn slot.
  final double weight;

  /// Sectors (2-4) and routes (0-4) it may replace.
  final Set<int> sectors;
  final int minRoute, maxRoute;
  final BonusWaves waves;
  final PowerRules rules;
  final BonusCrates crates;
  final BonusScoring scoring;
  final BonusLook look;

  /// The level's own rule of play, when data is not enough (a constructor
  /// tear-off); null: none. See `bonus_mechanic.dart`.
  final BonusMechanicFactory? mechanic;

  // --- bonus challenges: the level's perfect-run condition, paying a 1UP
  // (bonus_challenge.dart); null: none.
  final BonusChallengeDef? challenge;

  bool fits(int route, int sector) =>
      sectors.contains(sector) && route >= minRoute && route <= maxRoute;
}
