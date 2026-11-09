part of 'model.dart';

// ===========================================================================
// Ground war: demon ground forces, their ground-to-air missiles, allied
// ground units, and the player's homing-missile power-up.
//
// Pure fixed-step simulation, like the rest of the model. Ground objects
// live on the flyover's perspective ground plane: their depth `z` (texels
// ahead of the camera) maps to the screen with [GroundCamera], the same
// projection `FlyoverBackground` uses for landmarks and creatures. Design and
// tunables: openspec/changes/add-ground-forces-homing/design.md.
// ===========================================================================

/// The flyover camera, shared with `FlyoverBackground` (kept equal by test).
abstract final class GroundCamera {
  static const horizon = 172.0;
  static const g = 520 - horizon;
  static const z0 = g / 2;

  /// Screen y of the ground at depth [z].
  static double yOf(double z) => horizon + g * z0 / z;

  /// Depth of the ground at screen row [y] (> horizon).
  static double zOf(double y) => g * z0 / (y - horizon);

  /// Arena units per sprite texel at depth [z] (as landmarks and creatures).
  static double texel(double z) => 2 * z0 / z;

  /// The central firing lane; ground units stay in the side bands.
  static const laneLeft = 96.0, laneRight = 264.0;

  /// Screen centre x of something [width] wide at [across] (0 outer edge,
  /// 1 lane edge) in the band on [side] (0 left, 1 right).
  static double bandX(int side, double across, double width) {
    const pad = 6.0;
    final room = math.max(0.0, laneLeft - pad - width);
    final left = pad + across.clamp(0.0, 1.0) * room + width / 2;
    return side == 0 ? left : ArcadeModel.width - left;
  }
}

/// Every ground-war tunable in one place (seconds, texels, arena units).
abstract final class GroundTuning {
  // Approach along the ground (texels of depth per second, x hostileRate).
  static const spawnZ = 1400.0; // y ~ 215: small and fogged at the horizon
  static const sightZ = 1150.0; // y ~ 225: "ground forces sighted"
  static const approachSpeed = 105.0;
  static const fireZ = 400.0; // y ~ 323: near ground; may fire from here on
  static const lastFireZ = 205.0; // y ~ 467: never fires from beside the ship
  static const creepSpeed = 30.0; // while in range
  static const leaveZ = 120.0; // y ~ 677: well below the screen

  /// Sprite scale relative to the landmarks' texel size.
  static const unitScale = 1.25;
  static const unitWidthTexels = 28.0;
  static const allyWidthTexels = 20.0;

  // Firing.
  static const telegraph = 1.1; // launcher raise (first half) + glow
  static const fireFlash = .28;
  static const cooldown = 3.2;
  static const maxMissilesInFlight = 3;

  // Ground-to-air missiles: a fixed path to the player's x sampled at launch.
  static const missileFlight = 1.7; // seconds to reach the ship plane / rate
  static const missileArc = 64.0; // pop-up height (arena units)
  static const missileMinSize = 8.0, missileMaxSize = 36.0;

  /// Progress from which the missile is in the ship's plane and can collide.
  static const missilePlaneT = .9;

  /// Hit radius as a fraction of the missile's drawn width (warhead body).
  static const missileHitRatio = .4;
  static const shipHalfWidth = 9.0, shipHalfHeight = 10.0;

  // Allies.
  static const allyHp = 8;
  static const allyLead = 110.0; // texels closer to the camera than its foe
  static const demonTracerEvery = 1.3; // damages the ally (x hostileRate)
  static const allyTracerEvery = .9; // cosmetic

  // Homing missiles.
  static const salvoSize = 3;
  static const homingAirDamage = 3;
  static const homingGap = .18; // after the previous missile hits
  static const homingFirstDelay = .12;
  static const homingMaxAge = 3.0;
  static const homingTurnRate = 9.0; // rad/s
  static const homingBoost = .1; // straight climb before steering

  // Drops. Chance per ordinary kill while demon ground units are alive.
  static double dropChance(Difficulty d) => switch (d) {
    Difficulty.easy => .14,
    Difficulty.normal => .12,
    Difficulty.hard => .07,
  };

  /// Seconds of ground pressure without homing before a drop is guaranteed.
  static double pityTime(Difficulty d) => switch (d) {
    Difficulty.easy => 5,
    Difficulty.normal => 6,
    Difficulty.hard => 8,
  };

  /// After the pity time, the fleet air-drops one if no kill delivers it.
  static const pityAirdrop = 4.0;

  /// Level 5: one homing drop every this many kills (offset by half).
  static const carrierDropEvery = 20;
}

/// The introduction ramp: how many ground units a wave may field.
class GroundPlan {
  const GroundPlan({
    required this.budget,
    required this.maxActive,
    required this.interval,
    required this.firstDelay,
    required this.shots,
    required this.allyEvery,
  });
  static const none = GroundPlan(
    budget: 0,
    maxActive: 0,
    interval: 0,
    firstDelay: 0,
    shots: 0,
    allyEvery: 0,
  );

  /// Units this wave, at most [maxActive] at once, [interval] apart after
  /// [firstDelay] seconds of combat (both x 1/hostileRate).
  final int budget, maxActive;
  final double interval, firstDelay;

  /// Missiles each unit may fire.
  final int shots;

  /// Every [allyEvery]-th unit arrives already engaged with an ally (0: none).
  final int allyEvery;

  /// Effective ramp step: sector, plus later routes, minus one on Easy.
  static int step(Difficulty d, int route, int sector) =>
      sector + math.min<int>(route, 3) - (d == Difficulty.easy ? 1 : 0);

  static GroundPlan of(
    Difficulty d, {
    required int route,
    required int sector,
    required int wave,
    required int wavesPerLevel,
  }) {
    if (sector < 1 || sector > 4 || const bool.fromEnvironment("GROUND_WAR_DISABLED")) return none;
    final s = step(d, route, sector);
    final density = DifficultyPolicy(d).density;
    final shots = d == Difficulty.easy ? 1 : 2;
    int scaled(int n) => math.max(1, (n * density).round());
    switch (s) {
      case <= 0:
        return none;
      case 1:
        // A single unit, late: the final wave, after its swarm settles.
        if (wave < wavesPerLevel) return none;
        return GroundPlan(
          budget: 1,
          maxActive: 1,
          interval: 99,
          firstDelay: 7,
          shots: 1,
          allyEvery: 1,
        );
      case 2:
        if (wave < 2) return none;
        return GroundPlan(
          budget: 1,
          maxActive: 1,
          interval: 14,
          firstDelay: 5,
          shots: shots,
          allyEvery: 2,
        );
      case 3:
        return GroundPlan(
          budget: scaled(2),
          maxActive: d == Difficulty.easy ? 1 : 2,
          interval: 11,
          firstDelay: 4,
          shots: shots,
          allyEvery: 2,
        );
      case 4:
        return GroundPlan(
          budget: scaled(3),
          maxActive: 2,
          interval: 9,
          firstDelay: 3.5,
          shots: shots,
          allyEvery: 2,
        );
      case 5:
        return GroundPlan(
          budget: scaled(3),
          maxActive: d == Difficulty.hard ? 3 : 2,
          interval: 8,
          firstDelay: 3,
          shots: shots,
          allyEvery: 2,
        );
      default:
        return GroundPlan(
          budget: scaled(4),
          maxActive: d == Difficulty.easy ? 2 : 3,
          interval: 7,
          firstDelay: 3,
          shots: shots,
          allyEvery: 2,
        );
    }
  }
}

/// A demon ground unit (rocket buggy, missile crawler, artillery beast or
/// launch tower, by sector). Player shots fly over it; only homing missiles
/// destroy it.
class GroundUnit {
  GroundUnit(
    this.id,
    this.sector,
    this.side,
    this.across,
    this.z, {
    this.shotsLeft = 2,
  });
  final int id, sector, side;
  final double across;
  double z;
  int shotsLeft;
  double telegraph = 0, cooldown = 0, fireFlash = 0, tracerLeft = .6;
  bool destroyed = false, sighted = false, announcedInRange = false;
  double wreckAge = 0;
  GroundAlly? ally;

  double get scale => GroundCamera.texel(z) * GroundTuning.unitScale;
  double get width => GroundTuning.unitWidthTexels * scale;
  double get x => GroundCamera.bandX(side, across, width);

  /// Ground contact (the sprite's bottom row).
  double get y => GroundCamera.yOf(z);

  /// Where a homing missile aims and a launch leaves from.
  double get bodyY => y - 9 * scale;
  bool get alive => !destroyed;
  bool get inRange =>
      alive && z <= GroundTuning.fireZ && z >= GroundTuning.lastFireZ;
  bool get telegraphing => telegraph > 0;

  /// 0 at the start of the tell, 1 at launch.
  double get telegraphProgress => telegraphing
      ? (1 - telegraph / GroundTuning.telegraph).clamp(0.0, 1.0)
      : 0;

  /// Higher is more urgent for homing missiles: about to fire, then in
  /// range and reloaded soonest, then closest.
  double get threat =>
      (telegraphing ? 4000 - telegraph * 100 : 0) +
      (inRange && shotsLeft > 0 ? 2000 - cooldown * 100 : 0) +
      (GroundTuning.spawnZ - z);
}

/// An allied human ground unit fighting a demon unit. Ambient: it never
/// collides with the player or blocks shots.
///
/// Allies never die: when overwhelmed an ally is *totalled*. It sparks,
/// smokes and limps off toward the screen edge, or (every other crew) its
/// crew ejects in a pod that flies away; then it leaves.
class GroundAlly {
  GroundAlly(this.id, this.sector, this.side, this.across, this.z, this.hp);
  final int id, sector, side;
  double across;
  double z;
  int hp;
  double fireLeft = .3, flash = 0;
  bool totalled = false, saved = false, announced = false;

  /// Seconds since it was totalled (limp / pod animation clock).
  double retreatAge = 0;

  /// Totalled crews with an odd id bail out in an escape pod.
  bool get ejects => id.isOdd;

  /// Escape pod offset from the ally (arena units) while it flies off.
  (double, double) get podOffset {
    final t = retreatAge;
    return ((side == 0 ? -1 : 1) * 30 * t * t, -24 * t - 60 * t * t);
  }

  GroundUnit? attacker;

  double get scale => GroundCamera.texel(z) * GroundTuning.unitScale;
  double get width => GroundTuning.allyWidthTexels * scale;
  double get x => GroundCamera.bandX(side, across, width);
  double get y => GroundCamera.yOf(z);
  double get bodyY => y - 6 * scale;
  bool get alive => !totalled;

  /// Engaged allies are the ones asking for help.
  bool get underAttack => alive && (attacker?.alive ?? false);
}

/// Short-lived skirmish fire between a demon unit and an ally (visual; the
/// demon's tracer is what wears the ally down).
class GroundTracer {
  GroundTracer(this.fromX, this.fromY, this.toX, this.toY, {this.friendly = false});
  final double fromX, fromY, toX, toY;
  final bool friendly;
  double age = 0;
  static const life = .22;
}

/// A ground-to-air missile on a fixed path toward the player's x sampled at
/// launch. It grows as it rises and approaches, and can collide only once it
/// reaches the ship's plane, with a hitbox matching its drawn size there.
class GroundMissile {
  GroundMissile(this.x0, this.y0, this.targetX, this.duration, this.sector);
  final double x0, y0, targetX, duration;
  final int sector;
  double get targetY => ArcadeModel.shipY;
  double age = 0;
  bool spent = false;

  double get t => age / duration;
  double get x => xAt(t);
  double get y => yAt(t);

  double xAt(double t) => x0 + (targetX - x0) * t;
  double yAt(double t) {
    if (t <= 1) {
      return y0 + (targetY - y0) * t - GroundTuning.missileArc * math.sin(math.pi * t);
    }
    // Past the plane it keeps its final heading (no tracking).
    final vy = (targetY - y0) + GroundTuning.missileArc * math.pi;
    return targetY + vy * (t - 1);
  }

  /// Drawn width (arena units): small at launch, full size at the ship.
  double get size {
    final u = math.min(t, 1.2);
    return GroundTuning.missileMinSize +
        (GroundTuning.missileMaxSize - GroundTuning.missileMinSize) * u * u;
  }

  bool get armed => t >= GroundTuning.missilePlaneT;
  double get hitRadius => size * GroundTuning.missileHitRatio;

  /// Screen-space heading (radians, 0 = straight down), for the sprite.
  double get heading {
    final a = math.min(t, 1.0), b = a + .02;
    return math.atan2(-(xAt(b) - xAt(a)), yAt(b) - yAt(a));
  }

  bool hits(double shipX) =>
      armed &&
      (x - shipX).abs() < GroundTuning.shipHalfWidth + hitRadius &&
      (y - ArcadeModel.shipY).abs() < GroundTuning.shipHalfHeight + hitRadius;
}

enum HomingTargetKind { ground, sentinel, demon, carrierCore, carrierShield }

/// One homing missile from the player's rack.
class HomingMissile {
  HomingMissile(this.x, this.y, this.vx, this.vy, this.side);
  double x, y, vx, vy;
  final int side;
  double age = 0;
  Object? target;
  HomingTargetKind? kind;
  double get heading => math.atan2(vx, -vy);
}

/// The homing power-up: three missiles fired in sequence, each launched
/// after the previous one hits.
class HomingSalvo {
  int remaining = 0;
  HomingMissile? active;
  double gap = 0;
  int launched = 0;

  /// Rack pips: missiles still on the ship.
  int get loaded => remaining;
  bool get busy => remaining > 0 || active != null;
}

class HomingPickup {
  HomingPickup(this.x, this.y);
  double x, y;
}

/// All ground-war state, owned by [ArcadeModel.ground].
class GroundWar {
  final List<GroundUnit> units = [];
  final List<GroundAlly> allies = [];
  final List<GroundMissile> missiles = [];
  final List<GroundTracer> tracers = [];
  final List<HomingPickup> pickups = [];
  final HomingSalvo salvo = HomingSalvo();
  final List<GameEvent> events = [];
  GroundPlan plan = GroundPlan.none;
  int spawnedThisWave = 0, nextId = 0, ordinal = 0;
  double spawnLeft = 0;

  /// Seconds of ground pressure without homing (pity timer).
  double pressure = 0;

  // Run statistics (tests, profiler, an "allies held" tally).
  int unitsSpawned = 0, unitsDestroyed = 0, missilesLaunched = 0;
  int missileImpacts = 0, homingCollected = 0, homingHits = 0;
  int alliesSaved = 0, alliesRetreated = 0;
  int alliesSavedThisLevel = 0, alliesRetreatedThisLevel = 0;

  /// Allies that fought (were engaged) this level / this run.
  int alliesEngagedThisLevel = 0, alliesEngaged = 0;

  /// Squad wingmates lost (no wingmates exist yet; a hook for the comms /
  /// squad feature to increment). Counts against "whole fleet intact".
  int wingmatesLost = 0, wingmatesLostThisLevel = 0;

  /// True while no ally has retreated and no wingmate was lost this run.
  bool get fleetIntactRun => alliesRetreated == 0 && wingmatesLost == 0;

  /// The same for the current level.
  bool get fleetIntactLevel =>
      alliesRetreatedThisLevel == 0 && wingmatesLostThisLevel == 0;

  Iterable<GroundUnit> get liveUnits => units.where((u) => u.alive);
  HomingMissile? get homing => salvo.active;

  void clearField() {
    units.clear();
    allies.clear();
    missiles.clear();
    tracers.clear();
    pickups.clear();
    salvo
      ..remaining = 0
      ..active = null
      ..gap = 0;
    pressure = 0;
    spawnedThisWave = 0;
    plan = GroundPlan.none;
  }

  void resetRun() {
    clearField();
    events.clear();
    nextId = ordinal = 0;
    unitsSpawned = unitsDestroyed = missilesLaunched = 0;
    missileImpacts = homingCollected = homingHits = 0;
    alliesSaved = alliesRetreated = alliesEngaged = 0;
    alliesSavedThisLevel = alliesRetreatedThisLevel = alliesEngagedThisLevel = 0;
    wingmatesLost = wingmatesLostThisLevel = 0;
  }
}

extension GroundWarSimulation on ArcadeModel {
  void _groundEvent(String name, [Map<String, Object?> data = const {}]) =>
      ground.events.add(GameEvent(name, {'sector': level, ...data}));

  /// New level (or restored entrance): nothing carries over.
  void _groundBeginLevel() {
    ground.clearField();
    ground.alliesSavedThisLevel = ground.alliesRetreatedThisLevel = 0;
    ground.alliesEngagedThisLevel = ground.wingmatesLostThisLevel = 0;
  }

  /// Wave entrance: plan this wave's ground units. In-flight hostile
  /// missiles never cross a wave boundary.
  void _groundBeginWave() {
    ground.missiles.clear();
    ground.spawnedThisWave = 0;
    ground.plan = GroundPlan.of(
      difficulty,
      route: cycle,
      sector: level,
      wave: wave,
      wavesPerLevel: wavesPerLevel,
    );
    ground.spawnLeft = ground.plan.firstDelay;
  }

  /// Bonus for a level whose allies all held (positive only).
  static const fleetIntactBonus = 500;

  /// Salvage over, sector secured: report whether the whole fleet held.
  void _groundLevelCleared() {
    final g = ground;
    final intact = g.fleetIntactLevel;
    if (intact && g.alliesEngagedThisLevel > 0) {
      score += fleetIntactBonus * (cycle + 1);
    }
    if (intact) {
      _groundEvent(GameEventNames.fleetIntact, {
        'scope': 'level',
        'alliesEngaged': g.alliesEngagedThisLevel,
        'alliesSaved': g.alliesSavedThisLevel,
      });
    }
    g.clearField();
  }

  /// Campaign complete: the run-wide flawless result.
  void _groundCampaignComplete() {
    if (!ground.fleetIntactRun) return;
    _groundEvent(GameEventNames.fleetIntact, {
      'scope': 'campaign',
      'alliesEngaged': ground.alliesEngaged,
      'alliesSaved': ground.alliesSaved,
    });
  }

  /// Final wave cleared: units roll on behind the salvage, missiles end.
  void _groundEndLevel() {
    ground.missiles.clear();
    ground.salvo.active = null;
  }

  void _updateGround(double dt) {
    final rate = policy.hostileRate;
    _spawnGroundUnits(dt * rate);
    final speedNear = GroundTuning.creepSpeed * rate * dt;
    final speedFar = GroundTuning.approachSpeed * rate * dt;
    for (final u in ground.units) {
      if (u.destroyed) {
        u.wreckAge += dt;
        u.z -= speedNear; // the wreck rolls toward the camera with the ground
        continue;
      }
      u.z -= u.z > GroundTuning.fireZ ? speedFar : speedNear;
      u.fireFlash = math.max(0, u.fireFlash - dt);
      if (!u.sighted && u.z <= GroundTuning.sightZ) {
        u.sighted = true;
        _groundEvent(GameEventNames.groundForceSighted, {'x': u.x, 'y': u.y});
      }
      if (u.inRange && !u.announcedInRange) {
        u.announcedInRange = true;
        _groundEvent(GameEventNames.groundForceInRange, {'x': u.x, 'y': u.y});
      }
      _updateGroundFire(u, dt * rate);
    }
    _updateAllies(dt);
    for (final t in ground.tracers) {
      t.age += dt;
    }
    ground.tracers.removeWhere((t) => t.age > GroundTracer.life);
    ground.units.removeWhere(
      (u) => u.z < GroundTuning.leaveZ || (u.destroyed && u.wreckAge > 6),
    );
    _updateGroundMissiles(dt);
    _updateHomingSalvo(dt);
    _updateGroundPressure(dt);
  }

  void _spawnGroundUnits(double dt) {
    final plan = ground.plan;
    if (plan.budget <= ground.spawnedThisWave) return;
    if (ground.liveUnits.length >= plan.maxActive) return;
    ground.spawnLeft -= dt;
    if (ground.spawnLeft > 0) return;
    ground.spawnLeft = plan.interval;
    ground.spawnedThisWave++;
    ground.unitsSpawned++;
    final ordinal = ground.ordinal++;
    final side = (ordinal + level + cycle).isEven ? 0 : 1;
    final across = .15 + random.nextDouble() * .6;
    final unit = GroundUnit(
      ground.nextId++,
      level - 1,
      side,
      across,
      GroundTuning.spawnZ,
      shotsLeft: plan.shots,
    )..cooldown = .4;
    ground.units.add(unit);
    if (plan.allyEvery > 0 && ordinal % plan.allyEvery == 0) {
      final ally = GroundAlly(
        ground.nextId++,
        level - 1,
        side,
        across < .5 ? across + .35 : across - .35,
        unit.z - GroundTuning.allyLead,
        GroundTuning.allyHp,
      )..attacker = unit;
      unit.ally = ally;
      ground.allies.add(ally);
    }
  }

  void _updateGroundFire(GroundUnit u, double dt) {
    if (u.telegraph > 0) {
      u.telegraph -= dt;
      if (u.telegraph <= 0) {
        u.telegraph = 0;
        _launchGroundMissile(u);
      }
      return;
    }
    u.cooldown = math.max(0, u.cooldown - dt);
    if (u.inRange &&
        u.shotsLeft > 0 &&
        u.cooldown <= 0 &&
        ground.missiles.where((m) => !m.spent).length <
            GroundTuning.maxMissilesInFlight &&
        // One tell at a time keeps every launch readable.
        !ground.units.any((o) => o.telegraphing)) {
      u.telegraph = GroundTuning.telegraph;
    }
  }

  void _launchGroundMissile(GroundUnit u) {
    // The player's position is sampled once, here; the path never tracks.
    final m = GroundMissile(
      u.x + (u.side == 0 ? 1 : -1) * u.width * .2,
      u.bodyY - 4 * u.scale,
      shipX,
      GroundTuning.missileFlight / policy.hostileRate,
      u.sector,
    );
    ground.missiles.add(m);
    ground.missilesLaunched++;
    u.shotsLeft--;
    u.cooldown = GroundTuning.cooldown;
    u.fireFlash = GroundTuning.fireFlash;
    events.add('missileLaunch');
    _groundEvent(GameEventNames.groundMissileLaunch, {
      'x': m.x0,
      'y': m.y0,
      'targetX': m.targetX,
    });
  }

  void _updateGroundMissiles(double dt) {
    for (final m in ground.missiles) {
      final before = m.t;
      m.age += dt;
      if (before < .45 && m.t >= .45) events.add('missileIncoming');
      if (!m.spent && m.hits(shipX)) {
        m.spent = true;
        ground.missileImpacts++;
        blasts.add(Blast(m.x, m.y, big: true));
        hitPlayer();
        if (!combat) return;
      }
    }
    ground.missiles.removeWhere((m) => m.spent || m.y > ArcadeModel.height + 40 || m.t > 2.2);
  }

  void _updateAllies(double dt) {
    final rate = policy.hostileRate;
    for (final a in ground.allies) {
      if (a.totalled) {
        // Limping off: drift to the outer edge while the ground rolls by.
        a.retreatAge += dt;
        a.across = math.max(-1.2, a.across - .45 * dt);
        a.z -= GroundTuning.creepSpeed * rate * dt;
        continue;
      }
      a.flash = math.max(0, a.flash - dt);
      final foe = a.attacker;
      if (foe != null && foe.alive) {
        // A running battle: the pair advances together.
        a.z = foe.z - GroundTuning.allyLead;
        if (!a.announced && foe.z <= GroundTuning.sightZ) {
          a.announced = true;
          ground.alliesEngaged++;
          ground.alliesEngagedThisLevel++;
          _groundEvent(GameEventNames.allyUnderAttack, {'x': a.x, 'y': a.y});
        }
        foe.tracerLeft -= dt * rate;
        if (foe.tracerLeft <= 0 && a.announced) {
          foe.tracerLeft = GroundTuning.demonTracerEvery;
          ground.tracers.add(GroundTracer(foe.x, foe.bodyY, a.x, a.bodyY));
          a.hp--;
          a.flash = .15;
          if (a.hp <= 0) {
            a.totalled = true;
            ground.alliesRetreated++;
            ground.alliesRetreatedThisLevel++;
            _groundEvent(GameEventNames.allyRetreated, {
              'x': a.x,
              'y': a.y,
              'ejected': a.ejects,
            });
            continue;
          }
        }
        a.fireLeft -= dt;
        if (a.fireLeft <= 0 && a.announced) {
          a.fireLeft = GroundTuning.allyTracerEvery;
          ground.tracers.add(
            GroundTracer(a.x, a.bodyY, foe.x, foe.bodyY, friendly: true),
          );
        }
      } else {
        a.z -= GroundTuning.approachSpeed * rate * dt;
      }
    }
    ground.allies.removeWhere(
      (a) =>
          a.z < GroundTuning.leaveZ ||
          (a.totalled && (a.retreatAge > 3.5 || a.x < -40 || a.x > ArcadeModel.width + 40)),
    );
  }

  void _destroyGroundUnit(GroundUnit u) {
    if (u.destroyed) return;
    u.destroyed = true;
    u.telegraph = 0;
    ground.unitsDestroyed++;
    score += ((400 + 100 * u.sector) * (cycle + 1) * policy.enemyPoints).round();
    blasts.add(Blast(u.x, u.bodyY, big: true));
    events.add('groundExplosion');
    _groundEvent(GameEventNames.groundUnitDestroyed, {'x': u.x, 'y': u.y});
    final ally = u.ally;
    if (ally != null && ally.alive && ally.announced) {
      // Positive only: a bonus and a tally, never a penalty.
      ally.saved = true;
      ground.alliesSaved++;
      ground.alliesSavedThisLevel++;
      score += 250 * (cycle + 1);
      _groundEvent(GameEventNames.allySaved, {'x': ally.x, 'y': ally.y});
    }
  }

  // -------------------------------------------------------------------------
  // Homing missiles
  // -------------------------------------------------------------------------

  /// Collects the homing power-up: (re)arms a three-missile salvo. It
  /// combines with every other module and the shield.
  void collectHoming() {
    final salvo = ground.salvo;
    if (!salvo.busy) salvo.gap = GroundTuning.homingFirstDelay;
    salvo.remaining = GroundTuning.salvoSize;
    ground.homingCollected++;
    ground.pressure = 0;
    events.add('powerup');
    _groundEvent(GameEventNames.homingPickup);
  }

  /// Rank of an air target (higher first): sentinel > elite > gold > coral
  /// > violet > teal.
  static int airRank(Demon d) => d.isLarge ? 6 : (d.elite ? 5 : 1 + d.kind.clamp(0, 3));

  bool _carrierCoreOpen(Carrier b) =>
      b.shield == 0 &&
      (b.door >= .6 ||
          (!b.sideHatchesLocked && (b.sideDoorLeft >= .55 || b.sideDoorRight >= .55)));

  /// Picks the next homing target, or null. Ground units always come first
  /// (most threatening first); otherwise the highest-ranking air target:
  /// carrier core while vulnerable > sentinel > elite > gold > coral >
  /// violet > teal, then the carrier (shield or closed core) last.
  (Object, HomingTargetKind)? pickHomingTarget() {
    GroundUnit? bestGround;
    for (final u in ground.units) {
      if (!u.alive || u.y > ArcadeModel.height - 8) continue;
      if (bestGround == null || u.threat > bestGround.threat) bestGround = u;
    }
    if (bestGround != null) return (bestGround, HomingTargetKind.ground);
    final b = boss;
    if (b != null && _carrierCoreOpen(b)) return (b, HomingTargetKind.carrierCore);
    Demon? bestAir;
    for (final d in demons) {
      if (d.entering || d.y < 0 || d.y > ArcadeModel.shipY - 20) continue;
      if (bestAir == null) {
        bestAir = d;
        continue;
      }
      final r = airRank(d), br = airRank(bestAir);
      if (r > br || (r == br && d.y > bestAir.y)) bestAir = d;
    }
    if (bestAir != null) {
      return (
        bestAir,
        bestAir.isLarge ? HomingTargetKind.sentinel : HomingTargetKind.demon,
      );
    }
    if (b != null) {
      return (
        b,
        b.shield > 0 ? HomingTargetKind.carrierShield : HomingTargetKind.carrierCore,
      );
    }
    return null;
  }

  bool _homingTargetValid(HomingMissile h) => switch (h.target) {
    final GroundUnit u => u.alive && u.z >= GroundTuning.leaveZ,
    final Demon d => demons.contains(d) && !d.entering,
    final Carrier c => identical(c, boss),
    _ => false,
  };

  (double, double) homingAim(HomingMissile h) => switch (h.target) {
    final GroundUnit u => (u.x, u.bodyY),
    final Demon d => (d.x, d.y),
    final Carrier c when h.kind == HomingTargetKind.carrierShield => (
      c.x,
      c.forceFieldSurfaceY(c.x),
    ),
    final Carrier c => (c.x, c.y + 18),
    _ => (h.x, -100),
  };

  void _updateHomingSalvo(double dt) {
    final salvo = ground.salvo;
    var h = salvo.active;
    if (h == null) {
      if (salvo.remaining <= 0) return;
      salvo.gap -= dt;
      if (salvo.gap > 0) return;
      final pick = pickHomingTarget();
      if (pick == null) return; // hold the salvo until something appears
      final side = salvo.launched.isEven ? -1 : 1;
      h = HomingMissile(shipX + side * 11.0, ArcadeModel.shipY - 4, side * 50.0, -230, side)
        ..target = pick.$1
        ..kind = pick.$2;
      salvo
        ..active = h
        ..remaining -= 1
        ..launched += 1;
      events.add('homingLock');
      _groundEvent(GameEventNames.homingLaunch, {'target': pick.$2.name});
      return;
    }
    h.age += dt;
    if (!_homingTargetValid(h)) {
      final pick = pickHomingTarget();
      h.target = pick?.$1;
      h.kind = pick?.$2;
    }
    final speed = math.min(480.0, 230 + h.age * 700);
    if (h.target != null && h.age > GroundTuning.homingBoost) {
      final (tx, ty) = homingAim(h);
      final want = math.atan2(tx - h.x, -(ty - h.y));
      var turn = want - h.heading;
      while (turn > math.pi) {
        turn -= 2 * math.pi;
      }
      while (turn < -math.pi) {
        turn += 2 * math.pi;
      }
      final maxTurn = GroundTuning.homingTurnRate * dt;
      final heading = h.heading + turn.clamp(-maxTurn, maxTurn);
      h.vx = math.sin(heading) * speed;
      h.vy = -math.cos(heading) * speed;
    } else {
      final heading = h.heading;
      h.vx = math.sin(heading) * speed;
      h.vy = -math.cos(heading) * speed;
    }
    h.x += h.vx * dt;
    h.y += h.vy * dt;
    if (h.target != null) {
      final (tx, ty) = homingAim(h);
      final reach = switch (h.kind) {
        HomingTargetKind.ground => 8 + (h.target as GroundUnit).width * .3,
        HomingTargetKind.carrierCore || HomingTargetKind.carrierShield => 22.0,
        HomingTargetKind.sentinel => 22.0,
        _ => 16.0,
      };
      final dx = tx - h.x, dy = ty - h.y;
      if (dx * dx + dy * dy <= reach * reach) {
        _homingImpact(h);
        salvo
          ..active = null
          ..gap = GroundTuning.homingGap;
        return;
      }
    }
    if (h.age > GroundTuning.homingMaxAge ||
        h.y < -40 ||
        h.y > ArcadeModel.height + 40 ||
        h.x < -40 ||
        h.x > ArcadeModel.width + 40) {
      salvo
        ..active = null
        ..gap = GroundTuning.homingGap;
    }
  }

  void _homingImpact(HomingMissile h) {
    ground.homingHits++;
    var killed = false;
    switch (h.target) {
      case final GroundUnit u:
        _destroyGroundUnit(u);
        killed = true;
      case final Demon d:
        hitDemon(d, damage: GroundTuning.homingAirDamage, homing: true);
        killed = !demons.contains(d);
        blasts.add(Blast(h.x, h.y));
      case final Carrier c:
        if (c.shield > 0) {
          hitBoss(c.x, damage: GroundTuning.homingAirDamage);
        } else {
          // The missile seeks an open hatch; a closed hull only takes a dent.
          final hatchX = c.door >= .6
              ? c.x
              : (!c.sideHatchesLocked && c.sideDoorLeft >= .55)
              ? c.x - Carrier.sideHatchOffset
              : (!c.sideHatchesLocked && c.sideDoorRight >= .55)
              ? c.x + Carrier.sideHatchOffset
              : null;
          if (hatchX == null || !hitBoss(hatchX, damage: GroundTuning.homingAirDamage)) {
            blasts.add(Blast(h.x, h.y));
            events.add('hit');
          }
        }
    }
    _groundEvent(GameEventNames.homingHit, {
      'target': h.kind?.name,
      'killed': killed,
      'x': h.x,
      'y': h.y,
    });
  }

  // -------------------------------------------------------------------------
  // Drops: rising chance while ground units live, a pity timer and an
  // airdrop fallback; level 5 keeps a plain kill-count drop.
  // -------------------------------------------------------------------------

  bool get _homingAvailable =>
      ground.pickups.isNotEmpty || ground.salvo.busy;

  void _updateGroundPressure(double dt) {
    if (ground.liveUnits.isEmpty || _homingAvailable) {
      if (_homingAvailable) ground.pressure = 0;
      return;
    }
    ground.pressure += dt;
    final pity = GroundTuning.pityTime(difficulty);
    if (ground.pressure >= pity + GroundTuning.pityAirdrop) {
      // No kill delivered it: the fleet air-drops one into the firing lane.
      _dropHoming(110 + random.nextDouble() * 140, 150);
    }
  }

  /// Called for every ordinary kill (after the existing drop rules).
  void _groundDropOnKill(Demon d) {
    if (_homingAvailable) return;
    if (level == 5) {
      if (kills % GroundTuning.carrierDropEvery ==
          GroundTuning.carrierDropEvery ~/ 2) {
        _dropHoming(d.x, d.y);
      }
      return;
    }
    final live = ground.liveUnits.length;
    if (live == 0) return;
    final pityDue = ground.pressure >= GroundTuning.pityTime(difficulty);
    final chance = GroundTuning.dropChance(difficulty) + .04 * (live - 1);
    if (pityDue || random.nextDouble() < chance) _dropHoming(d.x, d.y);
  }

  void _dropHoming(double x, double y) {
    // Offset from a same-kill power pickup so both stay readable.
    final clash = pickups.any((p) => (p.x - x).abs() < 20 && (p.y - y).abs() < 20);
    ground.pickups.add(HomingPickup((x + (clash ? 24 : 0)).clamp(20, ArcadeModel.width - 20), y));
    ground.pressure = 0;
  }

  void _updateHomingPickups(double dt, double fallSpeed) {
    for (final p in ground.pickups) {
      p.y += fallSpeed * dt;
      if ((p.x - shipX).abs() < 22 && (p.y - ArcadeModel.shipY).abs() < 23) {
        collectHoming();
        p.y = ArcadeModel.height + 20;
      }
    }
    ground.pickups.removeWhere((p) => p.y > ArcadeModel.height + 10);
  }
}
