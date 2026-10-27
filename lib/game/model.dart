import 'dart:math' as math;

import 'difficulty.dart';
import 'swarm_policy.dart';
export 'difficulty.dart';
export 'swarm_policy.dart';

enum RunMode {
  title,
  playing,
  paused,
  transition,
  salvage,
  levelClear,
  travel,
  victory,
  gameOver,
  completed,
}

enum Power { spread, rapid, shield, powerful, large }

enum HeartPart {
  bottomLeft,
  bottomRight,
  topLeft,
  topRight;

  int get mask => 1 << index;
}

enum ShotKind { ordinary, sentinel, powerful, large }

enum EnemyArchetype { ordinary, shieldSentinel, armoredSentinel }

class HeartPickup {
  HeartPickup(this.x, this.y, this.part);
  double x, y;
  final HeartPart part;
}

class Demon {
  Demon(
    this.x,
    this.y,
    this.kind,
    this.maxHp,
    this.seed, {
    this.elite = false,
    this.isEscort = false,
    this.archetype = EnemyArchetype.ordinary,
    this.lastStandEligible = false,
    this.shieldMax = 0,
    this.armorMax = 0,
  }) : hp = maxHp,
       shield = shieldMax,
       armor = armorMax,
       homeX = x,
       homeY = y;
  double x, y, homeX, homeY;
  double vx = 0, vy = 0, bank = 0;
  int diveShield = 0, diveShieldMax = 0;
  final int kind, maxHp;
  final bool elite, isEscort;
  final EnemyArchetype archetype;
  bool get isLarge => archetype != EnemyArchetype.ordinary;
  int get moltStage => maxHp - hp;
  final int shieldMax, armorMax;
  int shield, armor;
  double attackLeft = 2.4, volleyLeft = 1.5;
  double evadeLeft = 0, evadeCooldown = 0, evadeOffset = 0;
  double get evadeTimer => evadeLeft;
  set evadeTimer(double value) => evadeLeft = value;
  double get defenseFraction =>
      (shield + armor) / math.max(1, shieldMax + armorMax);
  // Spawned sentinels arrive after the small flock has settled. Hand-created
  // demons start present, matching ordinary demons and checkpoint test fixtures.
  double entranceProgress = 1;
  double entranceElapsed = 0;
  bool get entering => entranceProgress < 1;
  bool waitingForEscort = false;
  double entranceDelay = .35, entranceDuration = 1.8, entranceStartY = -48;
  final bool lastStandEligible;
  bool lastStand = false, rushing = false;
  double get lastStandTellProgress =>
      lastStand ? (1 - telegraph / .9).clamp(0, 1) : 0;
  double rushVx = 0, rushVy = 0;
  double _lastStandX = 0, _lastStandY = 0;
  final double seed;
  int hp;
  double dive = 0, targetX = 0, flash = 0, telegraph = 0;
  bool get angry => hp == 1 && maxHp > 1;
}

class Shot {
  Shot(
    this.x,
    this.y,
    this.vx,
    this.vy, {
    this.hostile = false,
    this.kind = ShotKind.ordinary,
    this.damage = 1,
    this.blastRadius = 0,
  });
  double x, y;
  final double vx, vy;
  final bool hostile;
  final ShotKind kind;
  final int damage;
  final double blastRadius;
}

class Pickup {
  Pickup(this.x, this.y, this.power);
  double x, y;
  final Power power;
}

class Blast {
  Blast(
    this.x,
    this.y, {
    this.big = false,
    this.archetype = EnemyArchetype.ordinary,
    this.blastRadius = 0,
  });
  final double x, y;
  final bool big;
  final double blastRadius;
  final EnemyArchetype archetype;
  bool get isLarge => archetype != EnemyArchetype.ordinary;
  double age = 0;
}

class SupplyCrate {
  SupplyCrate(this.x, this.y, this.power, {this.maxHp = 3}) : hp = maxHp;
  double x, y;
  final Power power;
  final int maxHp;
  int hp;
  double vy = 28.0;
  double swingTime = 0.0;
  double hitFlash = 0.0;
  bool get destroyed => hp <= 0;
}

class FallingPart {
  FallingPart(
    this.x,
    this.y,
    this.power, {
    this.vx = 0.0,
    this.vy = -18.0,
    this.vRot = 3.5,
  });
  double x, y, vx, vy;
  final Power power;
  double rotation = 0.0;
  final double vRot;
  double age = 0.0;
}

class Carrier {
  Carrier(
    int cycle, {
    Difficulty difficulty = Difficulty.normal,
    this.startingDirection = 1,
    this.startingPhase = 0,
  }) : shieldMax = DifficultyPolicy(difficulty).bossShieldForRoute(cycle),
       coreMax = DifficultyPolicy(difficulty).bossCoreForRoute(cycle),
       formCount = math.min(4, 2 + cycle) {
    shield = shieldMax;
    core = coreMax;
    motionPhase = startingPhase;
    x = forecastX(0, 1);
    horizontalVelocity = startingDirection.toDouble();
  }
  static const double sideHatchOffset = 46.0;
  final int startingDirection;
  final double startingPhase;
  double motionPhase = 0, horizontalVelocity = 0;
  double get forceFieldHalfWidth => 110;
  double get forceFieldDepth => 43 + 32 * shield / shieldMax;
  double forceFieldSurfaceY(double worldX) {
    final offset = ((worldX - x) / forceFieldHalfWidth).clamp(-1.0, 1.0);
    return y + 12 + (forceFieldDepth - 12) * math.sqrt(1 - offset * offset);
  }

  double get rage => (1 - (shield + core) / (shieldMax + coreMax)).clamp(0, 1);
  double get movementRate => 1 + rage * .9;
  int get direction => horizontalVelocity < 0 ? -1 : 1;
  double forecastX(double seconds, double speed) {
    final phase =
        motionPhase + seconds * .7 * speed * movementRate * startingDirection;
    return (180 +
            math.sin(phase) * (80 + rage * 10) +
            math.sin(phase * 2 + startingPhase) * rage * 8)
        .clamp(82, 278);
  }

  final int shieldMax, coreMax, formCount;
  late int shield, core;
  double x = 180, y = 205;
  int get phase =>
      ((1 - core / coreMax) * formCount).floor().clamp(0, formCount - 1);
  double door = 0;
  double sideDoorLeft = 0;
  double sideDoorRight = 0;
  bool get sideHatchesLocked => phase >= formCount - 1;
}

/// Pure fixed-step simulation; renderers and input never change its clock.
class ArcadeModel {
  ArcadeModel({int seed = 1982}) : random = math.Random(seed);
  static const width = 360.0, height = 520.0, shipY = 477.0;
  final math.Random random;
  RunMode mode = RunMode.title;
  RunMode _beforePause = RunMode.playing;
  final List<Demon> demons = [];
  final List<Shot> shots = [];
  final List<Pickup> pickups = [];
  final List<Blast> blasts = [];
  final List<SupplyCrate> supplyCrates = [];
  final List<FallingPart> fallingParts = [];
  double crateSpawnTimer = 0.0;
  final List<String> events = [];
  Carrier? boss;
  Carrier? wreckBoss;
  Difficulty difficulty = Difficulty.normal;
  DifficultyPolicy get policy => DifficultyPolicy(difficulty);
  int medals = 0;
  double _activeMilliseconds = 0;
  int get activeMilliseconds => _activeMilliseconds.round();
  int? get remainingLives => mode == RunMode.completed ? lives : null;
  final List<int> heartSlots = [0, 0, 0];
  int? lastCompletedHeartSlot;
  double heartAssemblyLeft = 0;
  final List<HeartPickup> heartPickups = [];
  int lives = 3, score = 0, level = 1, cycle = 0, kills = 0, wave = 1;
  int? clearedLevel;
  static const maxActiveDemons = 61;
  int flocksPlanned = 0, flocksSpawned = 0;
  int get flocksRemaining => flocksPlanned - flocksSpawned;
  double _reinforcementLeft = 0, _reinforcementCooldown = 0, _escortLeft = 0;
  int _reinforcementCasualties = 0;
  int _ordinaryBirthOrdinal = 0, _eliteBirths = 0, _waveRoster = 0;
  bool escortSpawned = false;
  bool _spawnedFromCheckpoint = false;
  int get plannedEscortSize => policy.escortSize(route: cycle, sector: level);
  double shipX = 180, targetX = 180, clock = 0, levelClock = 0;
  double shipVx = 0, shipBank = 0, shipThrust = 0;
  double steering = 0, aimAngle = 0;
  double touchSensitivity = 1.0;
  bool tiltEnabled = false;
  bool _steeringActive = false;
  static const List<double> interimAnglesDeg = [
    -24,
    -18,
    -12,
    -6,
    0,
    6,
    12,
    18,
    24,
  ];
  double get interimAimAngleDeg {
    if (shipVx.abs() <= 15 && steering.abs() < 0.05) return 0;
    final deg = aimAngle * 180 / math.pi;
    return ((deg / 6.0).round() * 6.0).clamp(-24.0, 24.0);
  }

  static const double defeatDuration = 5.8;
  double defeatTimer = 0;
  double cameraPanY = 0;
  bool get defeatActive => mode == RunMode.gameOver && defeatTimer > 0;
  double get defeatProgress => defeatDuration <= 0
      ? 1.0
      : (1.0 - defeatTimer / defeatDuration).clamp(0.0, 1.0);
  double get visualClock =>
      defeatActive ? clock + (defeatDuration - defeatTimer) : clock;
  double invulnerable = 0, transitionLeft = 0;
  static const storyReadingTime = 1 / 3;
  static const arrivalHintDuration = 4.5;
  double transitionDuration = arrivalHintDuration;
  static const powerDuration = 9.0;
  final Map<Power, double> powerTimers = {};
  Iterable<Power> get activePowers => Power.values.where(hasPower);
  bool hasPower(Power value) => timeLeft(value) > 0;
  double timeLeft(Power value) => powerTimers[value] ?? 0;
  bool get hasOffensivePower =>
      hasPower(Power.powerful) ||
      hasPower(Power.large) ||
      hasPower(Power.rapid) ||
      hasPower(Power.spread);
  double _fire = 0, _enemyFire = 1.5, _dive = 3, _flock = 0, _accumulator = 0;
  double get speed => (1 + math.min(cycle, 4) * .04) * policy.hostileRate;
  bool get combat => mode == RunMode.playing;
  bool get canPilot =>
      combat ||
      mode == RunMode.salvage ||
      (mode == RunMode.transition && wave > 1);
  bool get isBoss => boss != null;
  int get wavesPerLevel =>
      level == 5 ? 1 : 3 + ((level - 1) ~/ 2) + math.min(cycle, 3);
  int get nextLevel => level == 5 ? 1 : level + 1;
  RunMode get presentationMode => mode == RunMode.paused ? _beforePause : mode;
  bool get cinematic => [
    RunMode.transition,
    RunMode.salvage,
    RunMode.levelClear,
    RunMode.travel,
    RunMode.victory,
  ].contains(presentationMode);
  bool get waveTransition => presentationMode == RunMode.transition && wave > 1;
  double get transitionProgress =>
      (1 - transitionLeft / transitionDuration).clamp(0, 1);
  String get nextLevelName => const [
    'KRYBOR',
    'RINGFALL',
    'EMBER MOON',
    'THE HOLLOW',
    'THE CARRIER',
  ][nextLevel - 1];
  String get levelName => const [
    'KRYBOR',
    'RINGFALL',
    'EMBER MOON',
    'THE HOLLOW',
    'THE CARRIER',
  ][level - 1];
  String get banner => switch (presentationMode) {
    RunMode.victory => 'CARRIER DESTROYED',
    RunMode.salvage => 'COLLECT SALVAGE',
    RunMode.levelClear => '$levelName SECURED',
    RunMode.travel => 'APPROACHING $nextLevelName',
    _ =>
      waveTransition
          ? 'WAVE $wave / $wavesPerLevel'
          : 'LEVEL ${level.toString().padLeft(2, '0')} · $levelName',
  };

  void start({Difficulty difficulty = Difficulty.normal}) {
    this.difficulty = difficulty;
    lives = policy.startingLives;
    medals = 0;
    _activeMilliseconds = 0;
    heartSlots.fillRange(0, 3, 0);
    lastCompletedHeartSlot = null;
    heartAssemblyLeft = 0;
    heartPickups.clear();
    wreckBoss = null;
    score = 0;
    level = 1;
    cycle = 0;
    kills = 0;
    wave = 1;
    clearedLevel = null;
    shipX = targetX = 180;
    shipVx = shipBank = shipThrust = 0;
    steering = aimAngle = 0;
    _steeringActive = false;
    defeatTimer = cameraPanY = 0;
    clock = 0;
    powerTimers.clear();
    supplyCrates.clear();
    fallingParts.clear();
    crateSpawnTimer = 0.0;
    invulnerable = 2;
    _accumulator = 0;
    events.clear();
    _beginLevel();
  }

  /// Compact entrance snapshot. Call when consuming the `checkpoint` event.
  Map<String, dynamic> checkpoint() => {
    'schemaVersion': 2,
    'heartParts': 4,
    'difficulty': difficulty.name,
    'routeIndex': cycle,
    'sector': level,
    'wave': wave,
    'score': score,
    'lives': lives,
    'medals': medals,
    'kills': kills,
    'heartSlots': List<int>.of(heartSlots),
    'activeMilliseconds': activeMilliseconds,
  };

  /// Restores a fresh wave, validating before changing this model.
  /// Unknown optional fields and schema versions are deliberately tolerated.
  bool restoreCheckpoint(Map<String, dynamic> data) {
    int? integer(Object? value, int fallback, int min, int max) {
      if (value == null) return fallback;
      return value is int && value >= min && value <= max ? value : null;
    }

    final rawDifficulty = data['difficulty'];
    final restoredDifficulty = rawDifficulty == null
        ? Difficulty.normal
        : Difficulty.values.where((d) => d.name == rawDifficulty).firstOrNull;
    if (restoredDifficulty == null) return false;
    final route = integer(
      data['routeIndex'] ?? data['cycle'] ?? data['route'],
      0,
      0,
      4,
    );
    final sector = integer(data['sector'] ?? data['level'], 1, 1, 5);
    if (route == null || sector == null) return false;
    final maxWave = sector == 5
        ? 1
        : 3 + ((sector - 1) ~/ 2) + math.min(route, 3);
    final restoredWave = integer(data['wave'], 1, 1, maxWave.toInt());
    final restoredLives = integer(
      data['lives'],
      DifficultyPolicy(restoredDifficulty).startingLives,
      1,
      1000000,
    );
    final restoredScore = integer(data['score'], 0, 0, 9007199254740991);
    final restoredMedals = integer(data['medals'], 0, 0, 4);
    final restoredKills = integer(data['kills'], 0, 0, 9007199254740991);
    final restoredTime = integer(
      data['activeMilliseconds'],
      0,
      0,
      9007199254740991,
    );
    final heartParts = data['heartParts'];
    if (heartParts != null && (heartParts is! int || heartParts != 4)) {
      return false;
    }
    final fourParts = heartParts == 4;
    final rawHearts = data['heartSlots'];
    final restoredHearts = <int>[0, 0, 0];
    if (rawHearts != null) {
      if (rawHearts is! List || rawHearts.length != 3) return false;
      for (var i = 0; i < 3; i++) {
        final mask = integer(rawHearts[i], 0, 0, fourParts ? 14 : 6);
        if (mask == null || rawHearts[i] == null) return false;
        restoredHearts[i] = fourParts
            ? mask
            : (mask & 3) | ((mask & 4) != 0 ? 12 : 0);
      }
    }
    if (restoredWave == null ||
        restoredLives == null ||
        restoredScore == null ||
        restoredMedals == null ||
        restoredKills == null ||
        restoredTime == null) {
      return false;
    }
    // A recorded medal always belongs to an already completed route.
    if (restoredMedals > route) return false;
    difficulty = restoredDifficulty;
    cycle = route;
    level = sector;
    wave = restoredWave;
    lives = restoredLives;
    score = restoredScore;
    medals = restoredMedals;
    kills = restoredKills;
    _activeMilliseconds = restoredTime.toDouble();
    heartSlots.setAll(0, restoredHearts);
    lastCompletedHeartSlot = null;
    heartAssemblyLeft = 0;
    heartPickups.clear();
    powerTimers.clear();
    supplyCrates.clear();
    fallingParts.clear();
    crateSpawnTimer = 0.0;
    pickups.clear();
    blasts.clear();
    events.clear();
    clearedLevel = null;
    wreckBoss = null;
    shipX = targetX = 180;
    shipVx = shipBank = shipThrust = 0;
    steering = aimAngle = 0;
    _steeringActive = false;
    defeatTimer = cameraPanY = 0;
    clock = levelClock = _accumulator = 0;
    invulnerable = 2;
    boss = level == 5 ? _newCarrier() : null;
    _spawnWave(fromCheckpoint: true);
    events.add(boss == null ? 'level' : 'boss');
    return true;
  }

  Carrier _newCarrier() => Carrier(
    cycle,
    difficulty: difficulty,
    startingDirection: random.nextBool() ? 1 : -1,
    startingPhase: random.nextDouble() * math.pi * 2,
  );

  void _beginLevel() {
    wave = 1;
    clearedLevel = null;
    wreckBoss = null;
    boss = level == 5 ? _newCarrier() : null;
    levelClock = 0;
    pickups.clear();
    heartPickups.clear();
    blasts.clear();
    supplyCrates.clear();
    fallingParts.clear();
    crateSpawnTimer = 0.0;
    _spawnWave();
    events.add(boss == null ? 'level' : 'boss');
  }

  void _spawnWave({bool fromCheckpoint = false}) {
    _spawnedFromCheckpoint = fromCheckpoint;
    demons.clear();
    shots.clear();
    _fire = 0;
    _enemyFire = 1.7;
    _dive = 3;
    _flock = 2;
    flocksSpawned = 0;
    flocksPlanned = boss == null
        ? policy.reinforcementFlocks(route: cycle, sector: level)
        : 0;
    _reinforcementLeft = 4.5;
    _reinforcementCooldown = .6;
    _reinforcementCasualties = 0;
    _ordinaryBirthOrdinal = 0;
    _eliteBirths = 0;
    _waveRoster = 0;
    _escortLeft = 2.6;
    escortSpawned = false;
    if (boss == null) {
      final count = policy.rosterCount(sector: level, wave: wave, route: cycle);
      _waveRoster = count;
      final rows = (count / 6).ceil();
      final spacing = rows <= 4 ? 48.0 : 160.0 / (rows - 1);
      final specialEligible =
          cycle >= 1 &&
          ((wave == wavesPerLevel &&
                  level >= 2 &&
                  (difficulty != Difficulty.easy || level.isEven)) ||
              (difficulty != Difficulty.easy &&
                  wave >= 3 &&
                  (wave + level + cycle).isEven));
      for (var i = 0; i < count; i++) {
        final archetype = specialEligible && i == count - 1
            ? (cycle >= 2 && difficulty != Difficulty.easy
                  ? EnemyArchetype.armoredSentinel
                  : EnemyArchetype.shieldSentinel)
            : EnemyArchetype.ordinary;
        final large = archetype != EnemyArchetype.ordinary;
        final profile = large ? null : _ordinaryProfile();
        final kind = profile?.$1 ?? (i + wave + level) % 4;
        final elite = profile?.$3 ?? false;
        final hp =
            profile?.$2 ??
            (archetype == EnemyArchetype.armoredSentinel ? 12 : 9) +
                math.min(cycle, 4) * 2;
        final demon = Demon(
          large ? width / 2 : 38 + (i % 6) * 56.0,
          large
              ? 44
              : (specialEligible
                    ? 124 + (i ~/ 6) * 32.0
                    : 70 + (i ~/ 6) * spacing),
          kind,
          hp.toInt(),
          i * 1.7 + wave * .6,
          elite: elite,
          archetype: archetype,
          shieldMax: large ? 3 + cycle : 0,
          armorMax: large
              ? (archetype == EnemyArchetype.armoredSentinel ? 4 : 2) +
                    cycle ~/ 2
              : 0,
          lastStandEligible:
              large &&
              random.nextDouble() < (difficulty == Difficulty.easy ? .15 : .25),
        );
        if (large) {
          demon.entranceProgress = 0;
          demon.waitingForEscort = true;
          demon.y = -48;
        } else if (wave == 1) {
          // The arrival hint owns the whole introduction. The initial swarm
          // glides down during the second half of the opening transition and
          // settles into formation as combat begins.
          demon.entranceProgress = 0;
          demon.entranceDelay = (i % 6) * .045 + (i ~/ 6) * .08;
          demon.entranceDuration = fromCheckpoint ? 1.0 : 1.25;
          demon.entranceStartY = -48 - (i ~/ 6) * 20.0;
          demon.y = demon.entranceStartY;
        } else if (!fromCheckpoint) {
          demon.entranceProgress = 0;
          demon.entranceDelay = (i % 6) * .035 + (i ~/ 6) * .06;
          demon.entranceDuration = .85;
          demon.entranceStartY = -40 - (i ~/ 6) * 16.0;
          demon.y = demon.entranceStartY;
        }
        demons.add(demon);
      }
    }
    if (boss == null) _updateDemons(0);
    _enterPhase(
      RunMode.transition,
      wave > 1 ? 1.4 + storyReadingTime : arrivalHintDuration,
    );
    events.add('checkpoint');
  }

  (int, int, bool) _ordinaryProfile() {
    final index = _ordinaryBirthOrdinal++;
    final kind = cycle > 0
        ? (index + wave + level) % 4
        : wave > 1 && index % 4 == 0
        ? math.max(0, level - 2)
        : level - 1;
    final elite =
        (index + 1) % 10 == 0 &&
        _eliteBirths < policy.eliteBudget(route: cycle);
    if (elite) _eliteBirths++;
    return (
      kind,
      policy.ordinaryHealth(route: cycle, kind: kind, elite: elite),
      elite,
    );
  }

  void _updateReinforcements(double dt) {
    if (boss != null) return;
    final sentinel = demons
        .where((d) => d.isLarge && d.waitingForEscort)
        .firstOrNull;
    _escortLeft -= dt * policy.hostileRate;
    if (sentinel != null && _escortLeft <= 0) {
      if (_spawnReinforcementGroup(plannedEscortSize, escort: true)) {
        escortSpawned = true;
        sentinel.waitingForEscort = false;
        sentinel.entranceDelay = 1.15;
        events.add('escort');
      }
    }
    if (flocksRemaining <= 0) return;
    _reinforcementLeft -= dt * policy.hostileRate;
    _reinforcementCooldown -= dt * policy.hostileRate;
    final casualtiesNeeded = 1 + flocksSpawned;
    final empty = demons.every((d) => d.isLarge && d.waitingForEscort);
    if (!empty &&
        (_reinforcementCooldown > 0 ||
            (_reinforcementCasualties < casualtiesNeeded &&
                _reinforcementLeft > 0))) {
      return;
    }
    final count = policy.reinforcementSize(route: cycle, flock: flocksSpawned);
    // Ordinary arrivals must leave capacity for the sentinel's own new escort.
    final reserve = sentinel != null && sentinel.waitingForEscort
        ? plannedEscortSize
        : 0;
    if (demons.length + count + reserve > maxActiveDemons) return;
    if (!_spawnReinforcementGroup(count, escort: false)) return;
    flocksSpawned++;
    _reinforcementCasualties = 0;
    _reinforcementCooldown = 1.2;
    _reinforcementLeft = 4.5;
    events.add('reinforcements');
  }

  bool _spawnReinforcementGroup(int count, {required bool escort}) {
    if (demons.length + count > maxActiveDemons) return false;
    final ordinaryCount = demons.where((d) => !d.isLarge).length;
    final allowance = escort
        ? plannedEscortSize
        : policy.reinforcementSize(
            route: cycle,
            flock: math.max(0, flocksPlanned - 1),
          );
    if (ordinaryCount + count > _waveRoster + allowance) return false;
    final sentinel = demons.where((d) => d.isLarge).firstOrNull;
    final top = sentinel != null ? 124.0 : 70.0;
    final slots = <(double, double)>[];
    for (var row = 0; row < 11 && slots.length < count; row++) {
      for (var col = 0; col < 6 && slots.length < count; col++) {
        final x = 38 + col * 56.0, y = top + row * 32;
        if (y > 412) break;
        if (demons.any(
          (d) =>
              !d.isLarge &&
              (d.homeX - x).abs() < 28 &&
              (d.homeY - y).abs() < 26,
        )) {
          continue;
        }
        slots.add((x, y));
      }
    }
    if (slots.length < count) return false;
    for (var i = 0; i < count; i++) {
      final profile = _ordinaryProfile();
      final d =
          Demon(
              slots[i].$1,
              slots[i].$2,
              profile.$1,
              profile.$2,
              random.nextDouble() * 8,
              elite: profile.$3,
              isEscort: escort,
            )
            ..entranceProgress = 0
            ..entranceDelay = 0
            ..entranceDuration = .8
            ..entranceStartY = -32 - i * 8.0;
      d.y = d.entranceStartY;
      demons.add(d);
    }
    return true;
  }

  void _enterPhase(RunMode phase, double duration) {
    mode = phase;
    transitionDuration = duration;
    transitionLeft = duration;
  }

  void _completeWave() {
    shots.clear();
    if (wave < wavesPerLevel) {
      wave++;
      _spawnWave();
      events.add('wave');
    } else {
      clearedLevel = level;
      _enterPhase(RunMode.salvage, 2);
      events.add('salvage');
    }
  }

  void moveTo(double x) => targetX = x.clamp(18, width - 18);
  void moveBy(double dx) {
    moveTo(targetX + dx);
    steering = (dx / 28.0).clamp(-1.0, 1.0);
    _steeringActive = false;
  }

  void steerBy(double delta, {bool analog = true}) {
    final scaled = delta * touchSensitivity;
    moveTo(targetX + scaled);
    final raw = (scaled / (analog ? 20.0 : 14.0)).clamp(-1.0, 1.0);
    steering = (steering * 0.3 + raw * 0.7).clamp(-1.0, 1.0);
    _steeringActive = false;
  }

  void setSteering(double value) {
    steering = value.clamp(-1.0, 1.0);
    _steeringActive = steering.abs() > 0.02;
  }

  void pause() {
    if (mode == RunMode.paused) return;
    if (mode == RunMode.playing || cinematic) {
      _beforePause = mode;
      mode = RunMode.paused;
      events.add('pause');
    }
  }

  void resume() {
    if (mode == RunMode.paused) {
      mode = _beforePause;
      events.add('resume');
    }
  }

  List<String> takeEvents() {
    final result = List<String>.of(events);
    events.clear();
    return result;
  }

  void update(double dt) {
    if (mode == RunMode.paused ||
        mode == RunMode.title ||
        mode == RunMode.completed ||
        (mode == RunMode.gameOver && defeatTimer <= 0)) {
      return;
    }
    _accumulator += dt.clamp(0, .1);
    while (_accumulator >= 1 / 60) {
      _step(1 / 60);
      _accumulator -= 1 / 60;
    }
  }

  void _step(double dt) {
    if (mode == RunMode.completed) return;
    if (mode == RunMode.gameOver) {
      if (defeatTimer <= 0) return;
      defeatTimer = math.max(0, defeatTimer - dt);
      for (final b in blasts) {
        b.age += dt;
      }
      blasts.removeWhere((b) => b.age > (b.isLarge ? 1.4 : .75));
      _updateDefeatCelebration(dt);
      if (defeatTimer <= 0) {
        events.add('gameover');
      }
      return;
    }
    clock += dt;
    for (final b in blasts) {
      b.age += dt;
    }
    blasts.removeWhere((b) => b.age > (b.isLarge ? 1.4 : .55));
    if (canPilot) {
      heartAssemblyLeft = math.max(0, heartAssemblyLeft - dt);
      if (_steeringActive && steering.abs() > 0.02) {
        targetX = (targetX + steering * 290 * touchSensitivity * dt).clamp(
          18.0,
          width - 18.0,
        );
      } else {
        final decay = 6.5 * dt;
        if (steering.abs() <= decay) {
          steering = 0;
        } else {
          steering -= steering.sign * decay;
        }
      }
      final oldShipX = shipX;
      final delta = targetX - shipX;
      final desiredVx = (delta / math.max(dt, 1 / 120)).clamp(-360.0, 360.0);
      if (delta.abs() < 0.75 && shipVx.abs() < 18) {
        shipX = targetX;
        shipVx = 0;
        shipThrust = 0;
      } else {
        final reversing =
            shipVx != 0 && desiredVx != 0 && shipVx.sign != desiredVx.sign;
        final braking = reversing || desiredVx.abs() < shipVx.abs();
        final rate = braking ? 3200.0 : 2600.0;
        final dv = (desiredVx - shipVx).clamp(-rate * dt, rate * dt);
        shipVx = (shipVx + dv).clamp(-360.0, 360.0);
        final nextX = shipX + shipVx * dt;
        if ((delta > 0 && nextX >= targetX) ||
            (delta < 0 && nextX <= targetX)) {
          shipX = targetX;
          shipVx = dt > 0
              ? ((shipX - oldShipX) / dt).clamp(-360.0, 360.0)
              : 0;
        } else {
          shipX = nextX.clamp(18.0, width - 18.0);
          if (shipX <= 18.0 || shipX >= width - 18.0) {
            shipVx = 0;
          }
        }
        shipThrust = ((desiredVx - shipVx).abs() / 360.0).clamp(0.0, 1.0);
      }
      shipBank =
          (shipBank +
                  ((shipVx / 330.0).clamp(-1.0, 1.0) - shipBank) *
                      (1 - math.exp(-16 * dt)))
              .clamp(-1.0, 1.0);
      if (shipVx.abs() <= 15 && steering.abs() < 0.05) {
        aimAngle = 0;
      } else {
        final rawAngle = (steering * 0.28 + (shipVx / 360.0) * 0.18).clamp(
          -0.42,
          0.42,
        );
        final rawDeg = rawAngle * 180.0 / math.pi;
        final snappedDeg = ((rawDeg / 6.0).round() * 6.0).clamp(-24.0, 24.0);
        final snappedRad = (snappedDeg * math.pi / 180.0).clamp(-0.42, 0.42);
        aimAngle = (snappedRad * 0.7 + rawAngle * 0.3).clamp(-0.42, 0.42);
      }
      _updatePickups(dt, mode == RunMode.salvage ? 144 : 64);
    } else {
      shipVx = 0;
      shipThrust = 0;
      steering = 0;
      _steeringActive = false;
      aimAngle *= math.exp(-12 * dt);
      if (aimAngle.abs() < 0.001) aimAngle = 0;
      shipBank *= math.exp(-12 * dt);
      if (shipBank.abs() < 0.001) shipBank = 0;
    }
    if (cinematic) {
      if (mode == RunMode.transition) {
        if (wave > 1) {
          _advanceWaveEntrance(dt);
        } else if (!_spawnedFromCheckpoint && transitionProgress >= 0.45) {
          _advanceWaveEntrance(dt * 0.36);
        }
      }
      transitionLeft = math.max(0, transitionLeft - dt);
      if (transitionLeft <= 0) {
        if (mode == RunMode.salvage) {
          pickups.clear();
          heartPickups.clear();
          _enterPhase(RunMode.levelClear, 4 + storyReadingTime);
          events.add('levelclear');
        } else if (mode == RunMode.victory && cycle >= 4) {
          mode = RunMode.completed;
          events.add('completed');
        } else if (mode == RunMode.levelClear || mode == RunMode.victory) {
          _enterPhase(RunMode.travel, 4 + storyReadingTime);
          events.add('travel');
        } else if (mode == RunMode.travel) {
          if (level == 5) cycle++;
          level = nextLevel;
          shipX = targetX = 180;
          shipVx = shipBank = shipThrust = 0;
          steering = aimAngle = 0;
          _steeringActive = false;
          _beginLevel();
        } else {
          mode = RunMode.playing;
        }
      }
      return;
    }
    if (!combat) return;
    _activeMilliseconds += dt * 1000;
    levelClock += dt;
    invulnerable = math.max(0, invulnerable - dt);
    for (final value in Power.values) {
      if (powerTimers.containsKey(value)) {
        powerTimers[value] = math.max(0, powerTimers[value]! - dt);
      }
    }
    powerTimers.removeWhere((power, remaining) {
      if (remaining <= 0) {
        if (power != Power.shield) {
          final side =
              power == Power.rapid ? (random.nextBool() ? 1.0 : -1.0) : 0.0;
          fallingParts.add(
            FallingPart(
              shipX + side * 14.0,
              ArcadeModel.shipY + 4,
              power,
              vx: (random.nextDouble() - 0.5) * 40.0 + side * 20.0,
              vy: -25.0 - random.nextDouble() * 15.0,
              vRot: (random.nextBool() ? 1.0 : -1.0) *
                  (3.0 + random.nextDouble() * 3.0),
            ),
          );
        }
        return true;
      }
      return false;
    });

    for (final part in fallingParts) {
      part.vy += 160.0 * dt;
      part.x += part.vx * dt;
      part.y += part.vy * dt;
      part.rotation += part.vRot * dt;
      part.age += dt;
    }
    fallingParts.removeWhere((p) => p.y > height + 20 || p.age > 2.5);

    for (final crate in supplyCrates) {
      crate.y += crate.vy * dt;
      crate.swingTime += dt;
      crate.hitFlash = math.max(0, crate.hitFlash - dt);
    }
    supplyCrates.removeWhere((c) => c.y > ArcadeModel.shipY + 30);
    _fire -= dt;
    if (_fire <= 0) {
      _fire += hasPower(Power.rapid) ? .105 : .23;
      final powerful = hasPower(Power.powerful), large = hasPower(Power.large);
      final double slingVx;
      if (shipVx.abs() <= 15 && steering.abs() < 0.05) {
        slingVx = 0.0;
      } else if (steering.abs() >= 0.05) {
        slingVx = (math.sin(aimAngle) * 340.0 + shipVx * 0.08).clamp(
          -145.0,
          145.0,
        );
      } else {
        slingVx = (shipVx * 0.16).clamp(-58.0, 58.0);
      }
      Shot playerShot(double x, double y, double vx, double vy) => Shot(
        x,
        y,
        vx,
        vy,
        kind: large
            ? ShotKind.large
            : powerful
            ? ShotKind.powerful
            : ShotKind.ordinary,
        damage: policy.weaponDamage(powerful: powerful),
        blastRadius: large ? policy.largeBlastRadius : 0,
      );
      shots.add(
        playerShot(shipX + shipBank * 3, shipY - 13, slingVx, -390),
      );
      if (hasPower(Power.spread)) {
        shots.addAll([
          playerShot(shipX - 5, shipY - 8, -90 + slingVx * 0.85, -370),
          playerShot(shipX + 5, shipY - 8, 90 + slingVx * 0.85, -370),
        ]);
      }
      events.add('shot');
    }
    _updateReinforcements(dt);
    _updateDemons(dt);
    _updateBoss(dt);
    for (final s in shots) {
      s.x += s.vx * dt * (s.hostile ? policy.hostileRate : 1);
      s.y += s.vy * dt;
    }
    _collisions();
    shots.removeWhere(
      (s) => s.y < -10 || s.y > height + 10 || s.x < -10 || s.x > width + 10,
    );
    if (combat && demons.isEmpty && boss == null && flocksRemaining == 0) {
      _completeWave();
    }
  }

  void _updatePickups(double dt, double fallSpeed) {
    for (final p in pickups) {
      p.y += fallSpeed * dt;
      if ((p.x - shipX).abs() < 22 && (p.y - shipY).abs() < 23) {
        collect(p.power);
        p.y = height + 20;
      }
    }
    pickups.removeWhere((p) => p.y > height + 10);
    for (final p in heartPickups) {
      p.y += fallSpeed * dt;
      if ((p.x - shipX).abs() < 22 && (p.y - shipY).abs() < 23) {
        collectHeart(p.part);
        p.y = height + 20;
      }
    }
    heartPickups.removeWhere((p) => p.y > height + 10);
  }

  void _hostile(Shot shot) {
    if (shots.where((s) => s.hostile).length < 120) shots.add(shot);
  }

  double _smootherstep(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * c * (c * (c * 6 - 15) + 10);
  }

  void _igniteDiveShield(Demon d) {
    if (demons.any((o) => o.isLarge && o.waitingForEscort)) return;
    if (d.isLarge) {
      d.diveShieldMax = 4 + (cycle ~/ 2);
    } else if (d.elite || d.kind >= 2 || d.maxHp >= 3) {
      d.diveShieldMax = d.elite ? 3 : 2;
    } else {
      d.diveShieldMax = 1;
    }
    d.diveShield = d.diveShieldMax;
  }

  (double, double) _boidsOffset(Demon d) {
    if (d.isLarge || demons.any((o) => o.isLarge && o.waitingForEscort)) {
      return (0, 0);
    }
    var sepX = 0.0, sepY = 0.0;
    var cohX = 0.0, cohY = 0.0;
    var cohCount = 0;
    for (final other in demons) {
      if (identical(other, d) ||
          other.isLarge ||
          other.entering ||
          other.dive > 0 ||
          other.lastStand) {
        continue;
      }
      final dx = d.x - other.x;
      final dy = d.y - other.y;
      final distSq = dx * dx + dy * dy;
      if (distSq <= 0.0001 || distSq >= 68 * 68) continue;
      final dist = math.sqrt(distSq);
      if (dist < 36) {
        sepX += (dx / dist) * (36 - dist) * 0.35;
        sepY += (dy / dist) * (36 - dist) * 0.20;
      }
      cohX += other.x - d.x;
      cohY += other.y - d.y;
      cohCount++;
    }
    if (cohCount > 0) {
      sepX += (cohX / cohCount) * 0.025;
      sepY += (cohY / cohCount) * 0.02;
    }
    final staggerX = math.sin(d.seed * 3.1) * 3.5;
    final staggerY = math.cos(d.seed * 2.3) * 2.5;
    return (
      (sepX + staggerX).clamp(-8.0, 8.0),
      (sepY + staggerY).clamp(-6.0, 6.0),
    );
  }

  (double, double) _targetFormationPosition(Demon d) {
    if (d.isLarge) {
      if (d.entering) return (d.homeX, d.homeY);
      final nextX =
          (d.homeX +
                  math.sin(levelClock * .4 * speed + d.seed) * 42 +
                  d.evadeOffset)
              .clamp(62.0, width - 62.0);
      final nextY = d.homeY + math.sin(levelClock * .65 * speed + d.seed) * 5;
      return (nextX, nextY);
    }
    final (boidsX, boidsY) = _boidsOffset(d);
    final evadeX = d.evadeOffset * (d.evadeLeft / 0.32).clamp(0.0, 1.0);
    final targetFormX =
        (d.homeX +
                math.sin(levelClock * (.9 + d.kind * .12) * speed + d.seed) *
                    29 +
                math.sin(levelClock * .44 * policy.hostileRate) * 13 +
                boidsX +
                evadeX)
            .clamp(20.0, width - 20.0);
    var targetFormY =
        d.homeY + math.sin(levelClock * 1.7 * speed + d.seed) * 14 + boidsY;
    if (d.telegraph > 0) {
      final totalTell = d.elite ? 0.55 : 0.7;
      final progress = (d.telegraph / totalTell).clamp(0.0, 1.0);
      targetFormY -= 8.0 * math.sin((1 - progress) * math.pi);
    }
    return (targetFormX, targetFormY);
  }

  void _updateDemonKinematics(Demon d, double prevX, double prevY, double dt) {
    if (dt <= 0) {
      d.vx = d.vy = d.bank = 0;
      return;
    }
    d.vx = (d.x - prevX) / dt;
    d.vy = (d.y - prevY) / dt;
    final refSpeed = d.isLarge ? 120.0 : (d.dive > 0 ? 180.0 : 95.0);
    final targetBank = (d.vx / refSpeed).clamp(-1.0, 1.0);
    d.bank =
        (d.bank + (targetBank - d.bank) * (1 - math.exp(-14 * dt))).clamp(
          -1.0,
          1.0,
        );
  }

  void _advanceWaveEntrance(double dt) {
    for (final d in demons) {
      if (!d.entering || d.waitingForEscort) continue;
      final prevX = d.x, prevY = d.y;
      d.entranceElapsed += dt;
      d.entranceProgress =
          ((d.entranceElapsed - d.entranceDelay) / d.entranceDuration).clamp(
            0.0,
            1.0,
          );
      final s = _smootherstep(d.entranceProgress);
      final (targetFormX, targetFormY) = _targetFormationPosition(d);
      final arcX =
          math.sin(math.pi * (1 - s)) *
          32 *
          (d.seed.floor().isEven ? 1 : -1) *
          (1 - s);
      d.x = (d.homeX + arcX + (targetFormX - d.homeX) * s).clamp(
        18.0,
        width - 18.0,
      );
      d.y = d.entranceStartY + (targetFormY - d.entranceStartY) * s;
      _updateDemonKinematics(d, prevX, prevY, dt);
    }
  }

  int get _maxConcurrentSmallDives => difficulty == Difficulty.easy
      ? (level <= 2 ? 1 : 2)
      : (level <= 2 && cycle == 0
            ? 1
            : (difficulty == Difficulty.hard ? 3 : 2));

  void _updateDemons(double dt) {
    _dive -= dt * policy.hostileRate;
    var activeSmallDives = demons
        .where((d) => !d.isLarge && (d.dive > 0 || d.telegraph > 0))
        .length;
    final maxSmallDives = _maxConcurrentSmallDives;
    final readyDivers = demons
        .where(
          (d) =>
              !d.entering &&
              !d.lastStand &&
              d.dive == 0 &&
              d.telegraph <= 0 &&
              (d.isLarge || activeSmallDives < maxSmallDives),
        )
        .toList();
    if (_dive <= 0 && readyDivers.isNotEmpty) {
      final d = readyDivers[random.nextInt(readyDivers.length)];
      if (level >= 2 || cycle > 0) {
        d.telegraph = d.isLarge
            ? .9
            : d.elite
            ? .55
            : .7;
        d.targetX = shipX;
        if (!d.isLarge) activeSmallDives++;
      }
      _dive = math.max(
        .8,
        (4.2 - level * .45 - math.min(cycle, 4) * .08) /
            (1 + math.min(cycle, 4) * .04),
      );
    }
    for (final d in List<Demon>.of(demons)) {
      final prevX = d.x, prevY = d.y;
      d.flash = math.max(0, d.flash - dt);
      if (d.entering) {
        if (d.waitingForEscort) {
          d.vx = d.vy = d.bank = 0;
          continue;
        }
        d.entranceElapsed += dt;
        d.entranceProgress =
            ((d.entranceElapsed - d.entranceDelay) / d.entranceDuration).clamp(
              0.0,
              1.0,
            );
        final s = _smootherstep(d.entranceProgress);
        final (targetFormX, targetFormY) = _targetFormationPosition(d);
        final arcX =
            math.sin(math.pi * (1 - s)) *
            32 *
            (d.seed.floor().isEven ? 1 : -1) *
            (1 - s);
        d.x = (d.homeX + arcX + (targetFormX - d.homeX) * s).clamp(
          18.0,
          width - 18.0,
        );
        d.y = d.entranceStartY + (targetFormY - d.entranceStartY) * s;
        _updateDemonKinematics(d, prevX, prevY, dt);
        continue;
      }
      if (d.lastStand) {
        if (!d.rushing) {
          d.telegraph = math.max(0, d.telegraph - dt * policy.hostileRate);
          final progress = d.lastStandTellProgress;
          d.x = d._lastStandX;
          d.y = d._lastStandY - 22 * progress * progress;
          if (d.telegraph <= 0) {
            d.rushing = true;
            final dx = d.targetX - d.x;
            final dy = shipY - d.y;
            final distance = math.max(.001, math.sqrt(dx * dx + dy * dy));
            d.rushVx = dx / distance * 600 * policy.hostileRate;
            d.rushVy = dy / distance * 600 * policy.hostileRate;
          }
        } else {
          d.x += d.rushVx * dt;
          d.y += d.rushVy * dt;
          if (d.x < -56 || d.x > width + 56 || d.y < -32 || d.y > height + 32) {
            _sacrifice(d);
            continue;
          }
        }
        _updateDemonKinematics(d, prevX, prevY, dt);
        continue;
      }
      if (d.isLarge && d.dive == 0 && d.telegraph <= 0) {
        d.volleyLeft -= dt * policy.hostileRate;
        if (d.volleyLeft <= 0) {
          final aim = ((shipX - d.x) * .35).clamp(-85.0, 85.0);
          _hostile(
            Shot(
              d.x,
              d.y + 14,
              aim,
              240 * speed,
              hostile: true,
              kind: ShotKind.sentinel,
            ),
          );
          d.volleyLeft = 1.65;
        }
      }
      if ((d.elite || d.isLarge) && dt > 0) {
        d.attackLeft -= dt * policy.hostileRate;
        if (d.attackLeft <= 0) {
          final aim = ((shipX - d.x) * .3).clamp(-70.0, 70.0);
          if (!d.isLarge) {
            for (final offset in [-32.0, 0.0, 32.0]) {
              _hostile(
                Shot(d.x, d.y + 12, aim + offset, 130 * speed, hostile: true),
              );
            }
          }
          if (d.dive == 0 &&
              d.telegraph <= 0 &&
              (d.isLarge || activeSmallDives < maxSmallDives)) {
            d.telegraph = d.isLarge ? .9 : .55;
            d.targetX = shipX;
            if (!d.isLarge) activeSmallDives++;
          }
          d.attackLeft = math.max(2.0, 4 - math.min(cycle, 5) * .3);
        }
      }
      if (d.telegraph > 0) {
        d.telegraph -= dt * policy.hostileRate;
        if (d.telegraph <= 0) {
          d.dive = .001;
          _igniteDiveShield(d);
          if (d.isLarge) {
            final aim = ((d.targetX - d.x) * .3).clamp(-70.0, 70.0);
            for (final offset in [-32.0, 0.0, 32.0]) {
              _hostile(
                Shot(
                  d.x,
                  d.y + 12,
                  aim + offset,
                  240 * speed,
                  hostile: true,
                  kind: ShotKind.sentinel,
                ),
              );
            }
          }
        }
      }
      if (d.dive > 0) {
        if (d.diveShieldMax == 0) {
          _igniteDiveShield(d);
        }
        final shatteredSlow =
            d.isLarge && d.diveShieldMax > 0 && d.diveShield == 0 ? 0.7 : 1.0;
        d.dive +=
            dt *
            speed *
            (d.angry ? 1.3 : 1) *
            (d.elite ? 1.15 : 1) *
            shatteredSlow;
        d.x +=
            (d.targetX - d.x) *
            dt *
            policy.hostileRate *
            (d.isLarge ? 3.4 : (d.elite ? 2.1 : 1.8));
        d.y +=
            (d.isLarge ? 300 : (115 + d.kind * 16)) *
            dt *
            speed *
            (d.angry ? 1.3 : 1) *
            (d.elite ? 1.15 : 1) *
            shatteredSlow;
        if (d.y > height + 20) {
          d.dive = 0;
          d.diveShield = 0;
          d.diveShieldMax = 0;
          d.vx = d.vy = d.bank = 0;
          if (d.isLarge) {
            d.y = d.homeY;
            d.x = d.homeX;
          } else {
            d.entranceStartY = -36;
            d.entranceProgress = 0;
            d.entranceDuration = 0.65;
            d.entranceDelay = 0;
            d.entranceElapsed = 0;
            d.y = d.entranceStartY;
          }
        } else {
          _updateDemonKinematics(d, prevX, prevY, dt);
        }
      } else {
        if (d.isLarge) {
          _evade(d, dt);
          final (nextX, nextY) = _targetFormationPosition(d);
          d.x += (nextX - d.x).clamp(
            -90 * dt * policy.hostileRate,
            90 * dt * policy.hostileRate,
          );
          d.y += (nextY - d.y).clamp(-20 * dt, 20 * dt);
          _updateDemonKinematics(d, prevX, prevY, dt);
          continue;
        }
        if (dt > 0) {
          if (_evadeSmall(d, dt, activeSmallDives, maxSmallDives)) {
            activeSmallDives++;
          }
        }
        final (targetFormX, targetFormY) = _targetFormationPosition(d);
        if (dt <= 0) {
          d.x = targetFormX;
          d.y = targetFormY;
          d.vx = d.vy = d.bank = 0;
        } else if (d.evadeLeft > 0 ||
            d.evadeOffset.abs() > 0.5 ||
            d.telegraph > 0) {
          d.x += (targetFormX - d.x).clamp(-220 * dt, 220 * dt);
          d.y += (targetFormY - d.y).clamp(-160 * dt, 160 * dt);
          _updateDemonKinematics(d, prevX, prevY, dt);
        } else {
          d.x = targetFormX;
          d.y = targetFormY;
          _updateDemonKinematics(d, prevX, prevY, dt);
        }
      }
    }
    _enemyFire -= dt * policy.hostileRate;
    final shooters = demons.where((d) => !d.isLarge && !d.entering).toList();
    if (_enemyFire <= 0 && shooters.isNotEmpty) {
      final d = shooters[random.nextInt(shooters.length)];
      final aim = ((shipX - d.x) * .22).clamp(-65.0, 65.0);
      _hostile(
        Shot(d.x, d.y + 12, aim, (100 + level * 13) * speed, hostile: true),
      );
      _enemyFire = math.max(.45, 1.8 - level * .18 - cycle * .05);
    }
  }

  bool _evadeSmall(
    Demon d,
    double dt,
    int activeSmallDives,
    int maxSmallDives,
  ) {
    d.evadeCooldown = math.max(0, d.evadeCooldown - dt);
    d.evadeLeft = math.max(0, d.evadeLeft - dt);
    if (d.evadeLeft <= 0) {
      d.evadeOffset += (-d.evadeOffset).clamp(-90 * dt, 90 * dt);
    }
    if ((level < 2 && cycle == 0) || d.telegraph > 0 || d.evadeCooldown > 0) {
      return false;
    }
    if (demons.any((o) => !o.isLarge && !identical(o, d) && o.evadeLeft > 0)) {
      return false;
    }
    if (demons.any((o) => o.isLarge && o.waitingForEscort)) {
      return false;
    }
    Shot? nearestShot;
    var bestArrival = 999.0;
    for (final shot in shots) {
      if (shot.hostile || shot.vy >= 0) continue;
      final arrival = (d.y - shot.y) / shot.vy;
      if (arrival < 0.06 || arrival > 0.34) continue;
      final projectedX = shot.x + shot.vx * arrival;
      if ((projectedX - d.x).abs() < 26 && arrival < bestArrival) {
        bestArrival = arrival;
        nearestShot = shot;
      }
    }
    if (nearestShot == null) return false;
    var leftNeighbors = 0, rightNeighbors = 0;
    for (final other in demons) {
      if (identical(other, d) || other.isLarge || other.entering) continue;
      final dx = other.x - d.x, dy = other.y - d.y;
      if (dx * dx + dy * dy <= 72 * 72) {
        if (dx < 0) {
          leftNeighbors++;
        } else {
          rightNeighbors++;
        }
      }
    }
    final action = SwarmPolicy.suggest(
      demonX: d.x,
      demonY: d.y,
      shotX: nearestShot.x,
      shotY: nearestShot.y,
      shotVx: nearestShot.vx,
      shipX: shipX,
      shipVx: shipVx,
      crowdBalance: ((rightNeighbors - leftNeighbors) / 4.0).clamp(-1.0, 1.0),
      healthRatio: d.hp / math.max(1, d.maxHp),
      tierFactor: d.elite ? 1.0 : ((d.kind >= 2 || d.maxHp >= 3) ? 0.35 : -0.75),
    );
    final cooldown = difficulty == Difficulty.easy
        ? 3.2
        : (difficulty == Difficulty.normal ? 2.4 : 1.8);
    if (action == 'evade_left' || action == 'evade_right') {
      var dir = action == 'evade_left' ? -1.0 : 1.0;
      if (d.x < 44) dir = 1.0;
      if (d.x > width - 44) dir = -1.0;
      d.evadeOffset = dir * 24.0;
      d.evadeLeft = 0.32;
      d.evadeCooldown = cooldown;
      return false;
    }
    if (action == 'dive_commit' && activeSmallDives < maxSmallDives) {
      d.telegraph = d.elite ? 0.55 : 0.7;
      d.targetX = (shipX + shipVx * 0.22).clamp(24.0, width - 24.0);
      d.evadeCooldown = cooldown;
      return true;
    }
    final projectedX = nearestShot.x + nearestShot.vx * bestArrival;
    if ((projectedX - d.x).abs() < 18) {
      var dir = projectedX <= d.x ? 1.0 : -1.0;
      if (d.x < 44) dir = 1.0;
      if (d.x > width - 44) dir = -1.0;
      d.evadeOffset = dir * 22.0;
      d.evadeLeft = 0.32;
      d.evadeCooldown = cooldown;
    }
    return false;
  }

  void _evade(Demon d, double dt) {
    d.evadeCooldown = math.max(0, d.evadeCooldown - dt);
    d.evadeLeft = math.max(0, d.evadeLeft - dt);
    if (d.telegraph > 0) return;
    if (d.evadeLeft <= 0) {
      d.evadeOffset += (-d.evadeOffset).clamp(-65 * dt, 65 * dt);
    }
    if (d.evadeCooldown > 0) return;
    for (final shot in shots) {
      if (shot.hostile || shot.vy >= 0) continue;
      final arrival = (d.y - shot.y) / shot.vy;
      final projectedX = shot.x + shot.vx * arrival;
      if (arrival < 0 || arrival > .55 || (projectedX - d.x).abs() > 38) {
        continue;
      }
      var direction = projectedX < d.x ? 1 : -1;
      if (d.x < 110) direction = 1;
      if (d.x > width - 110) direction = -1;
      d.evadeOffset = direction * 54.0;
      d.evadeLeft = .6;
      d.evadeCooldown = 1.4;
      break;
    }
  }

  void _updateBoss(double dt) {
    final b = boss;
    if (b == null) return;
    final oldX = b.x;
    b.motionPhase += dt * .7 * speed * b.movementRate * b.startingDirection;
    b.x = b.forecastX(0, speed);
    b.horizontalVelocity = dt > 0 ? (b.x - oldX) / dt : b.horizontalVelocity;
    b.y = 205 + math.sin(b.motionPhase * 1.28) * (12 + b.rage * 6);
    b.door =
        ((math.sin(levelClock * (1.55 + b.phase * .22)) -
                    (cycle == 0 ? 0.0 : .1)) *
                2)
            .clamp(0, 1);
    if (b.sideHatchesLocked) {
      b.sideDoorLeft = 0;
      b.sideDoorRight = 0;
    } else {
      final sideBonus = cycle <= 1 ? 0.15 : 0.0;
      final sideRamp = ((levelClock - 0.65) / 0.35).clamp(0.0, 1.0);
      b.sideDoorLeft =
          (((math.sin(levelClock * (1.45 + b.phase * .2) + 1.9) + sideBonus) *
                      2)
                  .clamp(0.0, 1.0) *
              sideRamp);
      b.sideDoorRight =
          (((math.sin(levelClock * (1.45 + b.phase * .2) + 4.1) + sideBonus) *
                      2)
                  .clamp(0.0, 1.0) *
              sideRamp);
    }
    _flock -= dt * policy.hostileRate;
    final maxMinions = cycle == 0 ? 6 : (cycle == 1 ? 8 : 10);
    if (_flock <= 0 && demons.length < maxMinions) {
      final flockSize = math.min(3, maxMinions - demons.length);
      for (var i = 0; i < flockSize; i++) {
        final d =
            Demon(
                (b.x + (i - 1) * 35).clamp(30, 330),
                b.y + 52,
                math.min(3, cycle + 1),
                1 + math.min(cycle, 2),
                random.nextDouble() * 8,
              )
              ..homeY = b.y + 70
              ..entranceProgress = 0
              ..entranceDelay = i * .06
              ..entranceDuration = .55
              ..entranceStartY = b.y + 36;
        d.y = d.entranceStartY;
        demons.add(d);
      }
      _flock =
          math.max(2.4, 5.6 - b.phase * 0.45 - cycle * 0.25) /
          policy.hostileRate;
    }
    // Fan attacks force positioning without tracking a player after launch.
    final fanRate = (0.85 + math.min(cycle, 3) * 0.08) * policy.hostileRate;
    if ((levelClock * fanRate).floor() !=
        ((levelClock - dt) * fanRate).floor()) {
      for (var i = -1; i <= 1; i++) {
        _hostile(
          Shot(
            b.x,
            b.y + 42,
            i * (40.0 + b.phase * 10),
            120 * speed,
            hostile: true,
          ),
        );
      }
    }

    // Fleet Supplies: progressive tactical drops after boss shield is depleted
    if (b.shield == 0 && combat) {
      crateSpawnTimer += dt;
      final struggle = lives <= 2;
      final spawnInterval = struggle ? 11.0 : 16.0;
      if (crateSpawnTimer >= spawnInterval && supplyCrates.length < 2) {
        crateSpawnTimer = 0.0;
        final roll = random.nextDouble();
        final power = roll < 0.70
            ? Power.large
            : (roll < 0.80
                ? Power.powerful
                : (roll < 0.90 ? Power.spread : Power.shield));
        final spawnX = 50.0 + random.nextDouble() * 260.0;
        supplyCrates.add(SupplyCrate(spawnX, -20.0, power));
      }
    }
  }

  void _collisions() {
    for (final s in List<Shot>.of(shots)) {
      if (!combat) break;
      if (s.y > height + 2) continue;
      if (s.hostile) {
        if ((s.x - shipX).abs() < 10 && (s.y - shipY).abs() < 12) {
          hitPlayer();
          s.y = height + 20;
        }
        continue;
      }
      final shieldedCarrier = boss;
      if (shieldedCarrier != null &&
          shieldedCarrier.shield > 0 &&
          (s.x - shieldedCarrier.x).abs() <=
              shieldedCarrier.forceFieldHalfWidth) {
        final surface = shieldedCarrier.forceFieldSurfaceY(s.x);
        final radius = s.blastRadius > 0 ? 5.0 : 2.0;
        final previousY = s.y - s.vy / 60;
        if (s.y <= surface + radius && previousY >= surface - radius) {
          s.y = surface;
          if (s.blastRadius > 0) _explodeShot(s, hitCarrier: false);
          hitBoss(s.x, damage: s.damage);
          s.y = height + 20;
          continue;
        }
      }
      var hit = false;
      for (final crate in List<SupplyCrate>.of(supplyCrates)) {
        if ((s.x - crate.x).abs() < 16 + (s.blastRadius > 0 ? 6 : 0) &&
            (s.y - crate.y).abs() < 16 + (s.blastRadius > 0 ? 6 : 0)) {
          crate.hp -= s.damage;
          crate.hitFlash = 0.16;
          events.add('hit');
          if (s.blastRadius > 0) {
            _explodeShot(s, hitCarrier: false);
          }
          s.y = height + 20;
          hit = true;
          if (crate.destroyed) {
            supplyCrates.remove(crate);
            blasts.add(Blast(crate.x, crate.y, big: true));
            pickups.add(Pickup(crate.x, crate.y, crate.power));
            events.add('salvage');
          }
          break;
        }
      }
      if (hit) continue;
      for (final d in List<Demon>.of(demons)) {
        if (!d.entering &&
            (s.x - d.x).abs() <
                (d.isLarge ? 27 : 16) + (s.blastRadius > 0 ? 5 : 0) &&
            (s.y - d.y).abs() <
                (d.isLarge ? 18 : 14) + (s.blastRadius > 0 ? 5 : 0)) {
          if (s.blastRadius > 0) {
            _explodeShot(s);
          } else {
            hitDemon(d, damage: s.damage);
          }
          hit = true;
          break;
        }
      }
      final b = boss;
      if (!hit &&
          b != null &&
          b.shield == 0 &&
          (s.x - b.x).abs() < 78 + (s.blastRadius > 0 ? 5 : 0) &&
          s.y < b.y + 43 + (s.blastRadius > 0 ? 5 : 0) &&
          s.y > b.y - 25 - (s.blastRadius > 0 ? 5 : 0)) {
        if (s.blastRadius > 0) {
          _explodeShot(s);
        } else {
          hitBoss(s.x, damage: s.damage);
        }
        hit = true;
      }
      if (hit) s.y = height + 20;
    }
    for (final d in List<Demon>.of(demons)) {
      if (!d.entering && (d.x - shipX).abs() < 21 && (d.y - shipY).abs() < 21) {
        hitPlayer();
        if (d.rushing) _sacrifice(d);
      }
    }
  }

  void _explodeShot(Shot shot, {bool hitCarrier = true}) {
    blasts.add(Blast(shot.x, shot.y, blastRadius: shot.blastRadius));
    final radius = shot.blastRadius + 14;
    for (final d in List<Demon>.of(demons)) {
      final dx = shot.x - d.x, dy = shot.y - d.y;
      if (dx * dx + dy * dy <= radius * radius) {
        hitDemon(d, damage: shot.damage);
      }
    }
    final b = boss;
    if (b == null || !hitCarrier) return;
    final touchesField =
        b.shield > 0 &&
        (shot.x - b.x).abs() <= b.forceFieldHalfWidth + shot.blastRadius &&
        (shot.y - b.forceFieldSurfaceY(shot.x)).abs() <= shot.blastRadius + 5;
    final touchesHull =
        b.shield == 0 &&
        (shot.x - b.x).abs() <= 78 + shot.blastRadius &&
        (shot.y - b.y).abs() <= 43 + shot.blastRadius;
    if (touchesField || touchesHull) {
      hitBoss(shot.x, damage: shot.damage, blastRadius: shot.blastRadius);
    }
  }

  // Self-sacrifice shares the large death visuals, but cannot produce rewards.
  void _sacrifice(Demon d) {
    if (!demons.remove(d)) return;
    if (boss == null) _reinforcementCasualties++;
    blasts.add(Blast(d.x, d.y, archetype: d.archetype));
    events.add('explosion');
  }

  void hitDemon(Demon d, {int damage = 1}) {
    if (!combat || damage <= 0 || d.entering || !demons.contains(d)) return;
    d.flash = .12;
    if (d.dive > 0 && d.diveShieldMax == 0) {
      _igniteDiveShield(d);
    }
    if (d.dive > 0 && d.diveShield > 0) {
      if (d.isLarge) {
        if (!hasOffensivePower) {
          d.flash = .12;
          events.add('hit');
          return;
        }
        final breakerDamage =
            damage +
            (hasPower(Power.powerful) ? 1 : 0) +
            (hasPower(Power.large) ? 1 : 0);
        d.diveShield = math.max(0, d.diveShield - breakerDamage);
        if (d.diveShield == 0) {
          score += (250 * (cycle + 1) * policy.enemyPoints).round();
          if (d.shield > 0) {
            d.shield--;
          } else if (d.armor > 0) {
            d.armor--;
          } else if (d.hp > 1) {
            d.hp--;
          }
        }
        events.add('hit');
        return;
      } else {
        if (damage > d.diveShield) {
          final overflow = damage - d.diveShield;
          d.diveShield = 0;
          score += (25 * policy.enemyPoints).round();
          damage = overflow;
        } else {
          d.diveShield -= damage;
          if (d.diveShield == 0) {
            score += (25 * policy.enemyPoints).round();
          }
          d.flash = .14;
          events.add('hit');
          return;
        }
      }
    }
    if (d.shield > 0) {
      d.shield = math.max(0, d.shield - damage);
      events.add('hit');
      return;
    }
    if (d.armor > 0) {
      d.armor = math.max(0, d.armor - damage);
      events.add('hit');
      return;
    }
    d.hp -= damage;
    if (d.hp <= 0) {
      final wasDiving = d.dive > 0;
      demons.remove(d);
      if (boss == null) _reinforcementCasualties++;
      kills++;
      final basePoints =
          (100 + d.kind * 75 + (d.maxHp - 1) * 50) *
          (cycle + 1) *
          policy.enemyPoints;
      score += (basePoints * (wasDiving ? 1.5 : 1.0)).round();
      blasts.add(Blast(d.x, d.y, archetype: d.archetype));
      events.add('explosion');
      if (policy.heartDropChance > 0 &&
          random.nextDouble() < policy.heartDropChance) {
        heartPickups.add(
          HeartPickup(
            d.x,
            d.y,
            HeartPart.values[random.nextInt(HeartPart.values.length)],
          ),
        );
      }
      if (kills % 8 == 0 || (d.isLarge && wasDiving)) {
        pickups.add(
          Pickup(
            d.x,
            d.y,
            Power.values[(math.max(1, kills ~/ 8) - 1) % Power.values.length],
          ),
        );
      }
    } else {
      events.add('hit');
      if (d.isLarge &&
          d.lastStandEligible &&
          !d.lastStand &&
          d.hp / d.maxHp <= .25) {
        d.lastStand = true;
        d.telegraph = .9;
        d.dive = 0;
        d.diveShield = 0;
        d.diveShieldMax = 0;
        d.targetX = shipX;
        d._lastStandX = d.x;
        d._lastStandY = d.y;
      } else if (!d.lastStand &&
          d.angry &&
          d.dive == 0 &&
          d.telegraph <= 0 &&
          (d.isLarge ||
              demons
                      .where(
                        (o) => !o.isLarge && (o.dive > 0 || o.telegraph > 0),
                      )
                      .length <
                  _maxConcurrentSmallDives)) {
        d.telegraph = d.isLarge
            ? .9
            : d.elite
            ? .55
            : .7;
        d.targetX = shipX;
      }
    }
  }

  /// Shield can be hit across its width. Core needs an exposed central or side hatch.
  bool hitBoss(double shotX, {int damage = 1, double blastRadius = 0}) {
    final b = boss;
    if (b == null || !combat || damage <= 0) return false;
    if (b.shield > 0) {
      final impactY = b.forceFieldSurfaceY(shotX);
      b.shield = math.max(0, b.shield - damage);
      events.add('hit');
      blasts.add(Blast(shotX, impactY));
      if (b.shield == 0) events.add('boss');
      return true;
    }
    final centerHit =
        b.door >= .60 && (shotX - b.x).abs() <= 12 * b.door + blastRadius;
    final leftHit =
        !b.sideHatchesLocked &&
        b.sideDoorLeft >= .55 &&
        (shotX - (b.x - Carrier.sideHatchOffset)).abs() <=
            11 * b.sideDoorLeft + blastRadius;
    final rightHit =
        !b.sideHatchesLocked &&
        b.sideDoorRight >= .55 &&
        (shotX - (b.x + Carrier.sideHatchOffset)).abs() <=
            11 * b.sideDoorRight + blastRadius;
    if (!centerHit && !leftHit && !rightHit) {
      return false;
    }
    final old = b.phase;
    b.core = math.max(0, b.core - damage);
    events.add('hit');
    final hitX = centerHit
        ? b.x
        : (leftHit
              ? b.x - Carrier.sideHatchOffset
              : b.x + Carrier.sideHatchOffset);
    blasts.add(Blast(hitX, b.y + 18));
    if (b.phase != old) events.add('boss');
    if (b.core <= 0) {
      score += 5000 * (cycle + 1);
      blasts.add(Blast(b.x, b.y, big: true));
      wreckBoss = b;
      boss = null;
      medals = cycle + 1;
      lives++;
      demons.clear();
      shots.clear();
      pickups.clear();
      heartPickups.clear();
      clearedLevel = level;
      _enterPhase(RunMode.victory, 5.5 + storyReadingTime);
      events.add('victory');
      events.add('bossDefeated');
    }
    return true;
  }

  /// Returns false for an excess duplicate or a Hard-mode pickup.
  bool collectHeart(HeartPart part) {
    if (difficulty == Difficulty.hard) return false;
    final slot = heartSlots.indexWhere((mask) => mask & part.mask == 0);
    if (slot < 0) return false;
    heartSlots[slot] |= part.mask;
    events.add('heart');
    if (heartSlots[slot] == 15) {
      heartSlots[slot] = 0;
      lastCompletedHeartSlot = slot;
      heartAssemblyLeft = .85;
      lives++;
      events.add('extraLife');
    }
    return true;
  }

  void collect(Power value) {
    final excluded = switch (value) {
      Power.spread => Power.large,
      Power.large => Power.spread,
      Power.rapid => Power.powerful,
      Power.powerful => Power.rapid,
      Power.shield => null,
    };
    if (excluded != null && powerTimers.containsKey(excluded)) {
      powerTimers.remove(excluded);
      fallingParts.add(
        FallingPart(
          shipX,
          ArcadeModel.shipY + 4,
          excluded,
          vx: (random.nextDouble() - 0.5) * 50.0,
          vy: -28.0,
          vRot: (random.nextBool() ? 1.0 : -1.0) * 4.5,
        ),
      );
    }
    powerTimers[value] = powerDuration;
    events.add('powerup');
  }

  void hitPlayer() {
    if (!combat || invulnerable > 0) return;
    if (hasPower(Power.shield)) {
      powerTimers.remove(Power.shield);
      invulnerable = 1;
      events.add('hit');
      return;
    }
    lives--;
    shipVx = shipBank = shipThrust = 0;
    steering = aimAngle = 0;
    _steeringActive = false;
    invulnerable = 2.5;
    blasts.add(Blast(shipX, shipY));
    events.add('life');
    if (lives <= 0) {
      mode = RunMode.gameOver;
      defeatTimer = defeatDuration;
      cameraPanY = 0;
      blasts.addAll([
        Blast(shipX, shipY, big: true),
        Blast(shipX - 14, shipY - 8)..age = -0.08,
        Blast(shipX + 14, shipY - 6)..age = -0.16,
        Blast(shipX - 10, shipY + 8)..age = -0.24,
        Blast(shipX + 12, shipY + 7)..age = -0.32,
      ]);
      events.add('defeat');
    }
  }

  void _updateDefeatCelebration(double dt) {
    final p = defeatProgress;
    final elapsed = defeatDuration - defeatTimer;
    final t = clock + elapsed;
    if (p < 0.16 &&
        (elapsed * 14).floor() != (math.max(0.0, elapsed - dt) * 14).floor()) {
      final angle = t * 7.3;
      blasts.add(
        Blast(shipX + math.cos(angle) * 18, shipY + math.sin(angle) * 10),
      );
    }
    for (final s in shots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    shots.removeWhere(
      (s) => s.y < -10 || s.y > height + 10 || s.x < -10 || s.x > width + 10,
    );

    // Reinforcements swarm in to join the celebration
    if (demons.length < 12) {
      for (var i = demons.length; i < 12; i++) {
        final enterX = i.isEven ? -16.0 : 376.0;
        final enterY = 35.0 + (i % 6) * 36.0;
        demons.add(
          Demon(enterX, enterY, i % 4, 2, i * 0.8)
            ..entranceProgress = 1
            ..waitingForEscort = false,
        );
      }
    }

    final b = boss;
    if (b != null) {
      final oldX = b.x;
      // Swaggering rhythmic boss victory dance:
      final targetBossX = 180.0 + math.sin(t * 2.5) * 38.0;
      // Syncopated double-bounce groove
      final targetBossY =
          175.0 - math.sin(t * 4.6).abs() * 16.0 + math.sin(t * 9.2) * 3.0;
      final blend = (dt * 4.2).clamp(0.0, 1.0);
      b.x += (targetBossX - b.x) * blend;
      b.y += (targetBossY - b.y) * blend;
      b.horizontalVelocity = dt > 0 ? (b.x - oldX) / dt : 0;
      // Teasing door animations: central mouth laughing and alternating side-door winks
      b.door = (math.sin(t * 5.6) * 0.5 + 0.5);
      b.sideDoorLeft = math.sin(t * 4.2) > 0.1 ? 1.0 : 0.0;
      b.sideDoorRight = math.sin(t * 4.2 + math.pi) > 0.1 ? 1.0 : 0.0;
    }

    // Creature Swarm: paired celebrating creatures flocking and high-fiving
    final smalls = demons.where((d) => !d.isLarge).toList();
    final pairCount = math.max(1, (smalls.length / 2).ceil());
    for (var i = 0; i < smalls.length; i++) {
      final d = smalls[i];
      d.entranceProgress = 1;
      d.dive = 0;
      d.diveShield = 0;
      final pairIndex = i ~/ 2;
      final isSecond = i % 2 == 1;

      final double anchorX, anchorY;
      if (b != null) {
        final orbitAngle =
            t * 2.2 + pairIndex * (math.pi * 2 / pairCount);
        anchorX = b.x + math.cos(orbitAngle) * 115.0;
        anchorY = b.y + math.sin(orbitAngle) * 58.0;
      } else {
        final flockPhase =
            t * 2.4 + pairIndex * (math.pi * 2 / pairCount);
        anchorX = 180.0 + math.sin(flockPhase) * 105.0;
        anchorY = 220.0 + math.sin(flockPhase * 2) * 55.0;
      }

      // High-five clap oscillation: pairs approach to touch wingtips then bounce apart
      final clapPhase = (t * 4.0 + pairIndex * 1.4) % (math.pi * 2);
      final separation = (math.cos(clapPhase) * 0.5 + 0.5) * 26.0 + 4.0;
      final targetX =
          anchorX + (isSecond ? separation * 0.5 : -separation * 0.5);
      final targetY = anchorY +
          (isSecond ? math.sin(t * 5.0) * 2.5 : -math.sin(t * 5.0) * 2.5);

      final prevX = d.x, prevY = d.y;
      final blend = (dt * 5.0).clamp(0.0, 1.0);
      d.x += (targetX - d.x) * blend;
      d.y += (targetY - d.y) * blend;
      _updateDemonKinematics(d, prevX, prevY, dt);
    }

    final larges = demons.where((d) => d.isLarge).toList();
    for (var i = 0; i < larges.length; i++) {
      final d = larges[i];
      d.waitingForEscort = false;
      d.entranceProgress = 1;
      d.dive = 0;
      d.diveShield = 0;
      d.lastStand = false;
      d.rushing = false;
      d.telegraph = 0.5;
      final spread = (i - (larges.length - 1) / 2.0) * 90.0;
      final ax = 180.0 + spread + math.sin(t * 2.4 + i) * 18.0;
      final ay = 155.0 + math.cos(t * 3.0 + i) * 8.0;
      final prevX = d.x, prevY = d.y;
      final blend = (dt * 3.8).clamp(0.0, 1.0);
      d.x += (ax - d.x) * blend;
      d.y += (ay - d.y) * blend;
      _updateDemonKinematics(d, prevX, prevY, dt);
    }

    if (p >= 0.74) {
      final u = ((p - 0.74) / 0.26).clamp(0.0, 1.0);
      final ease = u < 0.5
          ? 4 * u * u * u
          : 1 - math.pow(-2 * u + 2, 3).toDouble() / 2;
      cameraPanY = ease * 520.0;
    } else {
      cameraPanY = 0;
    }
  }
}
