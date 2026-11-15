part of 'model.dart';

// --- bonus levels (openspec/changes/bonus-levels, lib/game/bonus/)
//
// Every hook the model has for bonus levels, bonus-only powerups and run
// modifiers. With [BonusRun.plan] == [BonusPlan.none] (a run started
// without a run seed) each hook returns its input untouched and draws
// nothing: the calibrated campaign is unchanged, draw for draw. Nothing
// here uses [ArcadeModel.random].

/// The bonus state of one run.
class BonusRun {
  /// The run seed the plan was drawn from; null: no plan.
  int? seed;
  BonusPlan plan = BonusPlan.none;

  /// The bonus level being played, or null in a regular sector.
  BonusLevelDef? level;

  /// The powerup rules in force (run modifier, then the level's on top).
  PowerRules rules = PowerRules.none;

  /// In-level draws (crates, chance rules); reseeded at every level start.
  math.Random rng = math.Random(0);

  /// Seconds left per active bonus power id.
  final Map<String, double> timers = {};

  // Per-level counters.
  int cratesDropped = 0, cratesOpened = 0, shipsLost = 0;

  /// Points this level added beyond ordinary kill points.
  int extra = 0;

  /// The clear award of the level just finished (0 until its last kill).
  int award = 0;
  double crateLeft = 0;
  bool startAnnounced = false, modifierAnnounced = false;

  /// The level's own rule of play (bonus_mechanic.dart), one per visit.
  BonusMechanic? mechanic;

  void resetLevel() {
    cratesDropped = cratesOpened = shipsLost = 0;
    extra = award = 0;
    crateLeft = 0;
    startAnnounced = false;
    mechanic = null;
  }
}

extension ArcadeBonus on ArcadeModel {
  int? get runSeed => bonusRun.seed;
  BonusPlan get bonusPlan => bonusRun.plan;

  /// The bonus level being played (null in a regular sector).
  BonusLevelDef? get bonus => bonusRun.level;

  /// The bonus level the transition is flying to, if any.
  BonusLevelDef? get bonusAhead => level == 5 && cycle >= ArcadeModel.finalRoute
      ? null
      : bonusRun.plan.at(flowDestinationRoute, flowDestination);

  PowerRules get powerRules => bonusRun.rules;
  Map<String, double> get bonusPowerTimers => bonusRun.timers;
  bool hasBonusPower(String id) => (bonusRun.timers[id] ?? 0) > 0;

  /// Active bonus powers, in catalogue order.
  Iterable<BonusPowerDef> get activeBonusPowers =>
      bonusPowers.where((p) => hasBonusPower(p.id));

  // --- run and level lifecycle

  void _bonusStartRun(int? runSeed, {BonusTuning? tuning}) {
    bonusRun
      ..seed = runSeed
      ..plan = runSeed == null
          ? BonusPlan.none
          : BonusPlan.forRun(runSeed, tuning: tuning ?? bonusTuning)
      ..level = null
      ..rules = PowerRules.none
      ..modifierAnnounced = false
      ..timers.clear()
      ..resetLevel();
  }

  /// Forces [level] at the current route and sector and/or [modifier] on
  /// the run (console and tests); the rest of the plan is kept.
  void _bonusForce(BonusLevelDef? level, {RunModifierDef? modifier}) {
    final plan = bonusRun.plan;
    bonusRun
      ..seed ??= seed
      ..plan = BonusPlan([
        for (final s in plan.slots)
          if (level == null || s.route != cycle || s.sector != this.level) s,
        if (level != null) BonusSlot(cycle, this.level, level),
      ], modifier ?? plan.modifier);
  }

  void _bonusBeginLevel() {
    final run = bonusRun;
    run.resetLevel();
    final plan = run.plan;
    run.level = boss == null && level != 5 ? plan.at(cycle, level) : null;
    final outer = plan.modifier?.rules ?? PowerRules.none;
    run.rules = outer.merge(run.level?.rules ?? PowerRules.none);
    if (!identical(plan, BonusPlan.none)) {
      run.rng = BonusPlan.levelRng(run.seed ?? seed, cycle, level);
    }
    run.crateLeft = run.level?.crates.first ?? 0;
    // --- bonus mechanic: a fresh one per visit, on the level's own seed.
    run.mechanic = run.level?.mechanic?.call(
      BonusMechanicContext(
        seed: BonusPlan.levelSeed(run.seed ?? seed, cycle, level),
        route: cycle,
        sector: level,
        difficulty: difficulty,
      ),
    );
    // A bonus power never leaves its level.
    if (run.level == null) run.timers.clear();
  }

  // --- waves

  int _bonusRoster(int calibrated) =>
      bonus?.waves.roster(calibrated) ?? calibrated;
  int _bonusReinforcements(int calibrated) =>
      bonus?.waves.reinforcements(calibrated) ?? calibrated;
  bool get _bonusNoSentinels => !(bonus?.waves.sentinels ?? true);
  bool get _bonusNoElites => !(bonus?.waves.elites ?? true);
  int _bonusKind(int kind) {
    final cap = bonus?.waves.maxKind;
    return cap == null ? kind : math.min(kind, cap);
  }

  // --- powerups

  /// The power a kill drop ([crate] false) or a supply crate of
  /// [candidate] becomes under the rules in force; null: nothing drops.
  Power? _bonusDrop(Power candidate, {bool crate = false}) {
    final rules = bonusRun.rules;
    if (rules.isNone) return candidate;
    if (!crate && !rules.killDrops) return null;
    return rules.resolve(candidate, bonusRun.rng.nextDouble);
  }

  /// Collects a bonus-only powerup: its timer, its granted regular powers.
  void collectBonus(BonusPowerDef def) {
    bonusRun.timers[def.id] = def.seconds;
    for (final p in def.grants) {
      final allowed = _bonusDrop(p, crate: true);
      if (allowed != null) collect(allowed);
    }
    events.add('powerup');
    _queueGameEvent(GameEventNames.bonusPickup, {'variant': def.id});
  }

  double get _bonusFireScale {
    var k = 1.0;
    for (final p in activeBonusPowers) {
      k *= p.fireScale;
    }
    return k;
  }

  double get _bonusScoreScale {
    var k = 1.0;
    for (final p in activeBonusPowers) {
      k *= p.scoreScale;
    }
    return k;
  }

  // --- scoring

  /// Kill points inside a bonus level: × the level's scale and the active
  /// bonus powers'; what that adds counts against the level's cap.
  int _bonusKillPoints(int points) {
    final def = bonus;
    if (def == null) return points;
    final k = def.scoring.pointsScale * _bonusScoreScale;
    if (k == 1) return points;
    final scaled = (points * k).round();
    return scaled <= points ? scaled : points + _bonusCapped(scaled - points);
  }

  /// What the roster of the regular sector at this place would pay in kill
  /// points (its opening rosters at face value; reinforcements, sentinels
  /// and dive bonuses are left out, so a real clear pays somewhat more).
  /// A bonus level's awards and cap are shares of it, so the level is
  /// worth about the sector it replaces on every route and difficulty.
  int get sectorPar {
    if (level == 5) return 0;
    final kinds = cycle > 0 ? const [0, 1, 2, 3] : [level - 1];
    var mean = 0.0;
    for (final k in kinds) {
      final hp = policy.ordinaryHealth(route: cycle, kind: k, elite: false);
      mean += (100 + k * 75 + (hp - 1) * 50) / kinds.length;
    }
    var creatures = 0;
    final waves = ArcadeModel.wavesFor(sector: level, route: cycle);
    for (var w = 1; w <= waves; w++) {
      creatures += policy.rosterCount(sector: level, wave: w, route: cycle);
    }
    return (creatures * mean * (cycle + 1) * policy.enemyPoints).round();
  }

  /// [points] of bonus score, as far as the level's cap still allows.
  int _bonusCapped(int points) {
    final def = bonus;
    if (def == null || points <= 0) return 0;
    final s = def.scoring;
    final cap = s.cap * (cycle + 1) + (s.capPar * sectorPar).round();
    final granted = cap <= 0
        ? points
        : math.min(points, math.max(0, cap - bonusRun.extra));
    bonusRun.extra += granted;
    return granted;
  }

  void _bonusCrateOpened(SupplyCrate crate) {
    final def = bonus;
    if (def == null) return;
    bonusRun.cratesOpened++;
    final points = _bonusCapped(
      (def.crates.points * (cycle + 1) * _bonusScoreScale).round(),
    );
    score += points;
    _queueGameEvent(GameEventNames.bonusCrate, {
      'variant': def.id,
      'points': points,
      'opened': bonusRun.cratesOpened,
    });
  }

  /// The bookkeeping of an opened crate, for tests of the score cap.
  void bonusCrateOpenedForTest(SupplyCrate crate) => _bonusCrateOpened(crate);

  /// The level's last kill: the clear award, then the ordinary Rout.
  void _bonusClear() {
    final def = bonus;
    if (def == null) return;
    final flawless = bonusRun.shipsLost == 0;
    final s = def.scoring;
    final award = _bonusCapped(
      (s.clearBonus + (flawless ? s.flawlessBonus : 0)) * (cycle + 1) +
          ((s.clearPar + (flawless ? s.flawlessPar : 0)) * sectorPar).round(),
    );
    score += award;
    bonusRun.award = award;
    // Crates still in the air burst open: their pickups fall through the
    // salvage window (no crate points).
    for (final crate in supplyCrates) {
      blasts.add(Blast(crate.x, crate.y, big: true));
      pickups.add(Pickup(crate.x, crate.y, crate.power, bonus: crate.bonus));
    }
    supplyCrates.clear();
    _queueGameEvent(GameEventNames.bonusCleared, {
      'variant': def.id,
      'award': award,
      'flawless': flawless,
      'crates': bonusRun.cratesOpened,
    });
  }

  // --- bonus mechanic (bonus_mechanic.dart): what a level's own rule of
  // play may do beyond the model's public surface.

  /// The live mechanic of the bonus level being played (its painter and
  /// the tests read it); null in a regular sector or a data-only level.
  BonusMechanic? get bonusMechanic => bonusRun.mechanic;

  /// Queues a structured game event for the radio and the music.
  void bonusEvent(String name, [Map<String, Object?> data = const {}]) =>
      _queueGameEvent(name, data);

  /// Adds [points] of bonus score as far as the level's cap allows;
  /// returns what was granted.
  int bonusAward(int points) {
    final granted = _bonusCapped(points);
    score += granted;
    return granted;
  }

  /// A step outside combat: the mechanic finishes what is on screen.
  void _bonusIdle(double dt) => bonusRun.mechanic?.idle(this, dt);

  // --- per-step (combat only)

  void _bonusStep(double dt) {
    final run = bonusRun;
    if (identical(run.plan, BonusPlan.none)) return;
    final modifier = run.plan.modifier;
    if (modifier != null && !run.modifierAnnounced) {
      run.modifierAnnounced = true;
      _queueGameEvent(GameEventNames.runModifier, {'variant': modifier.id});
    }
    final def = run.level;
    if (def == null) return;
    if (!run.startAnnounced) {
      run.startAnnounced = true;
      _queueGameEvent(GameEventNames.bonusStart, {'variant': def.id});
    }
    run.mechanic?.step(this, dt); // --- bonus mechanic
    if (shipAway) return;
    run.timers.updateAll((_, left) => math.max(0, left - dt));
    run.timers.removeWhere((_, left) => left <= 0);
    _bonusMagnet(dt);
    _bonusCrates(def, dt);
  }

  void _bonusCrates(BonusLevelDef def, double dt) {
    final crates = def.crates;
    final run = bonusRun;
    if (!crates.active) return;
    if (crates.total > 0 && run.cratesDropped >= crates.total) return;
    run.crateLeft -= dt;
    if (run.crateLeft > 0 || supplyCrates.length >= crates.max) return;
    run.crateLeft = crates.every;
    final rng = run.rng;
    // Fixed draws per crate: x, bonus roll, bonus index, power index.
    final x = 40.0 + rng.nextDouble() * (ArcadeModel.width - 80);
    final bonusRoll = rng.nextDouble(), bi = rng.nextDouble();
    final pi = rng.nextDouble();
    BonusPowerDef? special;
    if (crates.bonusPowers.isNotEmpty &&
        (crates.powers.isEmpty || bonusRoll < crates.bonusPowerChance)) {
      special = bonusPowerById(
        crates.bonusPowers[(bi * crates.bonusPowers.length).floor() %
            crates.bonusPowers.length],
      );
    }
    Power? power;
    if (special == null && crates.powers.isNotEmpty) {
      power = _bonusDrop(
        crates.powers[(pi * crates.powers.length).floor() %
            crates.powers.length],
        crate: true,
      );
    }
    if (special == null && power == null) return;
    run.cratesDropped++;
    supplyCrates.add(
      SupplyCrate(x, -20, power ?? Power.shield, bonus: special),
    );
  }

  void _bonusMagnet(double dt) {
    var reach = 0.0;
    for (final p in activeBonusPowers) {
      reach = math.max(reach, p.magnet);
    }
    if (reach <= 0) return;
    (double, double) pull(double x, double y) {
      final dx = shipX - x, dy = ArcadeModel.shipY - y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > reach || d < 1) return (x, y);
      final step = math.min(d, 260 * dt);
      return (x + dx / d * step, y + dy / d * step);
    }

    for (final p in pickups) {
      final (x, y) = pull(p.x, p.y);
      p
        ..x = x
        ..y = y;
    }
    for (final p in heartPickups) {
      final (x, y) = pull(p.x, p.y);
      p
        ..x = x
        ..y = y;
    }
  }
}
