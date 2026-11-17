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

  /// bonus-briefing: the mid-level banter (`bonusMidway`) was asked for.
  bool midwayAnnounced = false;

  /// The level's own rule of play (bonus_mechanic.dart), one per visit.
  BonusMechanic? mechanic;

  // --- bonus challenges: the level's perfect-run condition, one per
  // visit (bonus_challenge.dart), and the levels whose 1UP this run won
  // (run order; saved in the checkpoint, shown on the run record).
  BonusChallenge? challenge;
  final List<String> oneUps = [];

  void resetLevel() {
    cratesDropped = cratesOpened = shipsLost = 0;
    extra = award = 0;
    crateLeft = 0;
    startAnnounced = false;
    midwayAnnounced = false;
    mechanic = null;
    challenge = null;
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

  /// bonus-balance: the run's modifiers for its record, as ids: the bonus
  /// levels the run has reached (in run order), then the run modifier.
  /// A pure function of the plan and the run's place, so a restored run
  /// keeps them; a run without a plan has none.
  List<String> get runModifierIds {
    final plan = bonusRun.plan;
    final slots = [...plan.slots]
      ..sort((a, b) => (a.route * 10 + a.sector) - (b.route * 10 + b.sector));
    return [
      for (final s in slots)
        if (s.route < cycle || (s.route == cycle && s.sector <= level))
          // --- bonus challenges: a won 1UP turns the level's medal into
          // its perfect-run medal (`<id>OneUp`, runTagLabel).
          bonusRun.oneUps.contains(s.level.id)
              ? oneUpRecordId(s.level.id)
              : s.level.id,
      ?plan.modifier?.id,
    ];
  }

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
      ..oneUps.clear()
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
    // --- bonus challenges: a fresh condition per visit.
    final challenge = run.level?.challenge;
    run.challenge = challenge == null ? null : BonusChallenge(challenge);
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

  /// What the regular sector at this place pays in kill points at face
  /// value (bonus-balance): every wave's opening roster, its finite
  /// reinforcement groups, and on a sentinel wave the sentinel and its
  /// escort. Dive bonuses and dive shields are left out, so a real clear
  /// pays about 1.1-1.2 x par. A bonus level's awards and cap are shares
  /// of it, so the level is worth about the sector it replaces on every
  /// route and difficulty.
  int get sectorPar {
    if (level == 5) return 0;
    double face(int kind, int hp) => (100 + kind * 75 + (hp - 1) * 50) * 1.0;
    final kinds = cycle > 0 ? const [0, 1, 2, 3] : [level - 1];
    var mean = 0.0;
    for (final k in kinds) {
      final hp = policy.ordinaryHealth(route: cycle, kind: k, elite: false);
      mean += face(k, hp) / kinds.length;
    }
    var total = 0.0;
    final waves = ArcadeModel.wavesFor(sector: level, route: cycle);
    final flocks = policy.reinforcementFlocks(route: cycle, sector: level);
    for (var w = 1; w <= waves; w++) {
      final roster = policy.rosterCount(sector: level, wave: w, route: cycle);
      var creatures = roster;
      for (var f = 0; f < flocks; f++) {
        creatures += policy.reinforcementSize(route: cycle, flock: f);
      }
      final sentinel = regularSentinelWave(
        difficulty: difficulty,
        sector: level,
        route: cycle,
        wave: w,
      );
      if (sentinel) {
        creatures += policy.escortSize(route: cycle, sector: level) - 1;
        final armored = cycle >= 2 && difficulty != Difficulty.easy;
        total += face(
          (roster - 1 + w + level) % 4,
          policy.sentinelHull(route: cycle, armored: armored),
        );
      }
      total += creatures * mean;
    }
    return (total * (cycle + 1) * policy.enemyPoints).round();
  }

  /// The regular sector's sentinel rule (`sentinelFor` without a bonus
  /// level): wave [wave] of [sector] on [route] brings a sentinel. Kept
  /// equal to `sentinelFor` by test/bonus_balance_test.dart.
  static bool regularSentinelWave({
    required Difficulty difficulty,
    required int sector,
    required int route,
    required int wave,
  }) {
    if (sector < 1 || sector > 4 || route < 1) return false;
    final last = ArcadeModel.wavesFor(sector: sector, route: route);
    if (wave < 1 || wave > last) return false;
    return (wave == last &&
            sector >= 2 &&
            (difficulty != Difficulty.easy || sector.isEven)) ||
        (difficulty != Difficulty.easy &&
            wave >= 3 &&
            (wave + sector + route).isEven);
  }

  /// The most the bonus level being played may add beyond ordinary kill
  /// points (0: uncapped, or a regular sector).
  int get bonusCap {
    final s = bonus?.scoring;
    if (s == null) return 0;
    return s.cap * (cycle + 1) + (s.capPar * sectorPar).round();
  }

  /// [points] of bonus score, as far as the level's cap still allows.
  int _bonusCapped(int points) {
    final def = bonus;
    if (def == null || points <= 0) return 0;
    final cap = bonusCap;
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
    _bonusChallengeSettle(def); // --- bonus challenges: the 1UP first
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
      if (bonusRun.challenge case final c?) 'challenge': c.status.name,
    });
  }

  // --- bonus challenges (openspec/changes/bonus-challenges, design §API)

  /// The live challenge of the bonus level being played (the HUD pip and
  /// the tests read it); null in a regular sector or a level without one.
  BonusChallenge? get bonusChallenge => bonusRun.challenge;

  /// The levels whose 1UP this run has won, in run order.
  List<String> get bonusOneUps => List.unmodifiable(bonusRun.oneUps);

  /// Reports [name] to the level's challenge (a mechanic calls it the
  /// moment the thing happens). A note in its `failOn` fails it at once:
  /// the badge breaks and the squad's quip is queued. Ignored outside a
  /// bonus level, after the challenge has settled, and without one.
  void challengeNote(String name, [int count = 1]) {
    final c = bonusRun.challenge;
    final def = bonus;
    if (c == null || def == null) return;
    if (!c.note(name, at: clock, count: count)) return;
    _queueGameEvent(GameEventNames.bonusChallengeFailed, {
      'variant': def.id,
      'challenge': c.def.id,
      'by': name,
    });
    _queueGameEvent(_musicAccent, {'name': 'challenge-fail'});
  }

  /// bonus-music's stinger request (`MusicBridge.accentEvent` in
  /// music_director.dart, kept as a string: the model imports no audio).
  /// Unknown names fail soft.
  static const _musicAccent = 'musicAccent';

  /// The ship was hit inside a bonus level ([lost]: a ship, else a shield).
  void _bonusShipHit({required bool lost}) {
    challengeNote(ChallengeNotes.shipHit);
    if (lost) challengeNote(ChallengeNotes.shipLost);
  }

  /// The level's last kill settles its challenge: earned pays its lives
  /// through the extra-life path (the `bonusOneUp` sound, no heart card),
  /// once per visit.
  void _bonusChallengeSettle(BonusLevelDef def) {
    final c = bonusRun.challenge;
    if (c == null) return;
    if (!c.settle(at: clock)) {
      if (c.failed && c.failedBy == null) {
        _queueGameEvent(GameEventNames.bonusChallengeFailed, {
          'variant': def.id,
          'challenge': c.def.id,
          'by': '',
        });
      }
      return;
    }
    lives += c.def.lives;
    if (!bonusRun.oneUps.contains(def.id)) bonusRun.oneUps.add(def.id);
    events.add('bonusOneUp');
    _queueGameEvent(GameEventNames.bonusChallengeEarned, {
      'variant': def.id,
      'challenge': c.def.id,
      'lives': lives,
    });
    // The stop-time 1UP stinger (bonus-music: on the next bar line).
    _queueGameEvent(_musicAccent, {'name': 'oneup'});
  }

  /// Restores the won 1UPs of a checkpoint (unknown ids are kept: the
  /// record names them by their camelCase).
  void _bonusRestoreOneUps(Object? raw) {
    bonusRun.oneUps.clear();
    if (raw is! List) return;
    for (final id in raw) {
      if (id is String &&
          RegExp(r'^[a-z][A-Za-z0-9]{0,26}$').hasMatch(id) &&
          !bonusRun.oneUps.contains(id)) {
        bonusRun.oneUps.add(id);
      }
    }
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
    // --- bonus briefing: the second wave's first combat frame asks for
    // the level's mid-level banter (once per visit).
    if (!run.midwayAnnounced && wave >= 2) {
      run.midwayAnnounced = true;
      _queueGameEvent(GameEventNames.bonusMidway, {'variant': def.id});
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
