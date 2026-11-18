import 'dart:math' as math;

import 'bonus/bonus_catalog.dart';
import 'bonus/bonus_plan.dart';
import 'bonus/bonus_types.dart';
import 'boss_grammar.dart';
import 'carrier_gates.dart';
import 'carrier_hatches.dart';
import 'carrier_script.dart';
import 'demon_planner.dart';
import 'difficulty.dart';
import 'flock.dart';
import 'flow_director.dart';
import 'game_events.dart';
import 'ground_blocks_atlas.dart';
import 'ground_blocks_cast.dart';
import 'perspective.dart';
import 'pilot_model.dart';
import 'skill_meter.dart';
import 'swarm_patterns.dart';
import 'swarm_policy.dart';
import 'swarm_stream.dart';
import 'weather/wind_field.dart'; // --- crosswind
export 'carrier_hatches.dart'
    show CarrierChapter, CarrierHatch, CarrierHatches, HatchState;
export 'bonus/bonus_catalog.dart';
export 'bonus/bonus_plan.dart';
export 'bonus/bonus_types.dart';
export 'demon_planner.dart' show DemonTier, Manoeuvre;
export 'difficulty.dart';
export 'game_events.dart';
export 'flow_director.dart';
export 'perspective.dart';
export 'pilot_model.dart';
export 'skill_meter.dart';
export 'swarm_policy.dart';
export 'swarm_patterns.dart' show Squad, SquadState;
export 'swarm_stream.dart' show SwarmState, SwarmGate, SwarmGateGeometry;
export 'weather/wind_field.dart'; // --- crosswind

// --- ground war (demon ground forces, allies, homing missiles) ---
part 'ground_war.dart';
part 'ground_war_v4.dart'; // --- ground war v4

// --- life-loss sequence (explosion, regroup, re-emergence) ---
part 'life_loss.dart';

// --- cinematic flow (one transition clock, the pursued flock, skip) ---
part 'model_flow.dart';

// --- bonus levels, bonus-only powerups and run modifiers ---
part 'model_bonus.dart';

// --- the sentinel final rush (demon-intelligence design §6) ---
part 'sentinel_rush.dart';

// --- crosswind: the wind that drifts every shot ---
part 'model_wind.dart';

// --- lightning-rework: stuns, the ship's zap, rank dodges and rod armour ---
part 'lightning.dart';

// --- spear-bearers: the buckler-and-spear hunter, its dive throw ---
part 'spear_bearers.dart';

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

// --- spear-bearers: `spear` is a bearer's thrown spear (hostile).
enum ShotKind { ordinary, sentinel, powerful, large, spear }

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
    this.rushRoll = 1,
    this.shieldMax = 0,
    this.armorMax = 0,
  }) : hp = maxHp,
       shield = shieldMax,
       armor = armorMax,
       homeX = x,
       homeY = y;
  double x, y, homeX, homeY;
  double vx = 0, vy = 0, bank = 0;

  /// --- crosswind: how far the wind has pushed it sideways (units). The
  /// flight code steers in still air; the push rides on top of it.
  double windOffset = 0;
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

  /// demon-intelligence: a hunter's climb (negative: up), the model clock
  /// of its next planner decision (-1: not yet staggered) and its last
  /// planned manoeuvre (hysteresis).
  double evadeLift = 0, planAt = -1;
  Manoeuvre lastPlan = Manoeuvre.hold;

  /// A hunter's thread dive (design §5): today's straight dive line x,
  /// the weave offset from it, its lateral velocity and the chosen one.
  double threadLine = 0, threadOffset = 0, threadVx = 0, threadTarget = 0;

  /// Pincer side of the next tell (-1 left of the forecast, 1 right).
  int pincer = 0;
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

  /// Progress (0..1) through the rush tell: rally then lock.
  double get lastStandTellProgress {
    if (!lastStand) return 0;
    final double p = switch (rushPhase) {
      RushPhase.rally => rushClock / rushTell,
      RushPhase.lock => (RushTuning.rally + rushClock) / rushTell,
      RushPhase.rush => 1,
      _ => 0,
    };
    return p.clamp(0.0, 1.0);
  }

  // --- the sentinel final rush (sentinel_rush.dart) ---
  /// The birth roll (one draw of the run's random): eligible when under
  /// the difficulty's rush chance (+ up to 0.10 with skill).
  double rushRoll;
  RushPhase rushPhase = RushPhase.none;

  /// Pass (1-based), rush shield, phase clock (hostile-rate s), the tell
  /// length (rally + lock), stagger left, heading (rad from straight
  /// down) and whether this pass touched the ship.
  int rushPass = 0, rushShield = 0, rushShieldMax = 0;
  double rushClock = 0, rushTell = 1.1, rushStagger = 0, rushHeading = 0;
  double rushHeading0 = 0;
  bool rushContact = false;
  double rushVx = 0, rushVy = 0;
  double _lastStandX = 0, _lastStandY = 0;
  final double seed;
  int hp;
  double dive = 0, targetX = 0, flash = 0, telegraph = 0;

  /// Seconds left of the beat before a dive tell (`divePrep` fired).
  double divePrep = 0;

  // --- lightning-rework (lightning.dart): a bolt's stun (seconds left,
  // the fall still to go, its fall speed and where it was struck), the
  // lightning-rod armour and its charge, and the rank dodge (an x offset on
  // the formation target and the offset it is easing toward).
  double stun = 0, stunFall = 0, stunVy = 0, stunFromY = 0;
  bool lightningRods = false;
  double charged = 0;
  double boltDodge = 0, boltDodgeGoal = 0;
  bool get stunned => stun > 0;

  // --- spear-bearers (spear_bearers.dart): the buckler and spear (null:
  // not a bearer).
  SpearKit? spear;
  bool _prepLead = false;
  bool get angry => hp == 1 && maxHp > 1;

  // --- perspective (lib/game/perspective.dart) ---
  /// Virtual nearness z0/z on the flyover camera; 0 until first placed.
  double nearness = 0;

  /// Quantised size factor: of the 40-unit sprite, or of the sentinel's
  /// 128-unit cell. Drawn size, hitbox and muzzle all use it.
  double scale = 1;

  /// This entrance flies in from the horizon (wave and reinforcement
  /// arrivals) rather than dropping in from above (re-entry after a dive).
  bool arrivesFromDistance = false;

  // --- atmosphere-and-swarms (flock.dart): presentation of the entrance.
  /// Wingbeat rate factor (flock constant, ±10 %).
  double wingRate = 1;

  /// Height above its flight sheet while arriving (screen units, shadows).
  double altitude = 0;

  /// Where a distant arrival sets out from, if not the default horizon
  /// point (a foreshadowed sentinel leaves from its silhouette).
  double? entryX, entryY, entryN, entryScale;

  // --- carrier-v3 §4: launched from a carrier gate.
  /// Seconds until it leaves its gate (parked, undrawn and untargetable
  /// until then); 0 when not waiting on a gate.
  double gateWait = 0;

  /// Where a flat (non-perspective) entrance starts across: the gate it
  /// left (null: straight down from its home column).
  double? entranceStartX;

  // --- continuous swarm (swarm_stream.dart, swarm_patterns.dart) ---
  /// Where this creature is in the swarm's life, published with [nearness]
  /// and [altitude] for the fog (fog-restoration decides how to veil it).
  SwarmState swarmState = SwarmState.present;

  /// Its skein (-1: none, a stray such as a hand-built fixture) and the
  /// gate its swoop leaves from.
  int skein = -1;
  SwarmGate? gate;

  /// Reserve point (world X, Z, lift) and its Lévy drift in the deep fog.
  double reserveX = 0, reserveZ = 0, reserveLift = 0;
  LevyDrift? drift;

  /// Seconds its entrance holds where it is (a cohort's lull at the front).
  double entranceHold = 0;

  /// Shot hitbox half extents, set with [scale] by the depth pass; the
  /// flat legacy box until then.
  late double hitHalfWidth = isLarge ? 27.0 : 16.0;
  late double hitHalfHeight = isLarge ? 18.0 : 14.0;
  double get muzzleDy => (isLarge ? 14.0 : 12.0) * scale;
  double get contactHalf => 10 + 11 * scale; // ship 10 + demon body 11
}

/// The giant silhouette of a coming sentinel (design §5, research §10): a
/// Gerono figure-eight with depth, far behind the fog, nearer and larger
/// each wave. No hitbox, no fire, no effect on the encounter.
class SentinelForeshadow {
  SentinelForeshadow(this.archetype, this.stage) : growth = stage;
  EnemyArchetype archetype;

  // --- sentinel-shadow-align: its shadow is cast from this silhouette
  // (x, nearness) at this altitude, the rising sentinel's starting one.
  static const shadowAltitude = 120.0;

  /// Target growth (0 two waves ahead, .5 one wave ahead, 1 arriving) and
  /// the eased value shown.
  double stage, growth;
  double clock = 0, opacity = 0;

  /// Screen position, nearness, quantised size factor of the 128-unit
  /// sentinel cell, and bank (-1..1).
  double x = 180, y = 110, nearness = .08, scale = .45, bank = 0;

  /// Period of one figure-eight (s).
  static const period = 10.0;

  bool get visible => opacity > 0;

  /// Seconds the silhouette takes to fade in through the fog.
  static const fadeIn = 3.0;

  /// Places the silhouette on its path at [clock]. World-anchored
  /// (fog-restoration): the ship's position plays no part.
  void place() {
    final g = growth.clamp(0.0, 1.0);
    final tau = clock * 2 * math.pi / period;
    // Linger at the lobe ends.
    final tp = tau + .15 * math.sin(2 * tau);
    final a = 96 + 24 * g;
    final nc = .08 + .2 * g;
    nearness = nc + .03 * math.sin(tp);
    x = 180 + a * math.cos(tp);
    // Low in the sky, its lower half in the horizon band: a darker patch
    // of the fog, partly cut by it (research §5).
    y = 150 - 14 * g + a / 2 * math.sin(2 * tp) * .22;
    final raw = (.7 + .25 * g) * (nearness / nc);
    scale = (raw * 16).round() / 16;
    // Bank by the lateral velocity (curvature sign).
    final dtp = 1 + .3 * math.cos(2 * tau);
    bank = (-math.sin(tp) * dtp).clamp(-1.0, 1.0);
  }
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

  /// Regroup drain: seconds until this hostile shot fizzles (life loss).
  double? fizzleIn;

  /// Seconds since it was fired (demon-intelligence: the planner's
  /// perception delay ignores younger shots).
  double age = 0;

  /// --- crosswind: the wind's share of its velocity (u/s): the sideways
  /// drift it has picked up, and a tailwind's one grid step along its
  /// track (set at the muzzle).
  double windVx = 0, windVy = 0;
}

class Pickup {
  Pickup(this.x, this.y, this.power, {this.bonus});
  double x, y;
  final Power power;

  /// --- bonus levels: a bonus-only powerup (then [power] is unused).
  final BonusPowerDef? bonus;
}

/// playtest-fixes-3: a player hit glancing off a berserk sentinel (its
/// transformation, or its rush shield against the bare gun): a spark at
/// the impact, presentation only.
class Deflect {
  Deflect(this.x, this.y, this.cx, this.cy);

  /// The impact and the sentinel's centre (the spark flies away from it).
  final double x, y, cx, cy;
  double age = 0;
  static const life = .28;
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
  SupplyCrate(this.x, this.y, this.power, {this.maxHp = 3, this.bonus})
    : hp = maxHp;
  double x, y;
  final Power power;

  /// --- bonus levels: a bonus-only powerup (then [power] is unused).
  final BonusPowerDef? bonus;
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
  }) : shieldMax = _hatchPool(
         DifficultyPolicy(difficulty).bossShieldForRoute(cycle),
         cycle,
         difficulty.index,
       ),
       coreMax = math.max(
         1,
         (DifficultyPolicy(difficulty).bossCoreForRoute(cycle) *
                 CarrierHatches.coreShares[difficulty.index])
             .round(),
       ),
       formCount = math.min(4, 2 + cycle) {
    // --- carrier-hatches (design §A3): the old shield's HP redistributed
    // into the upper hatches; [shield] is the sum of what stands.
    final list = CarrierHatches.forTour(cycle);
    final (field, hull) = CarrierHatches.hpOf(
      DifficultyPolicy(difficulty).bossShieldForRoute(cycle),
      list.length,
      difficulty: difficulty.index,
    );
    hatches = [
      for (final h in list) HatchState(h, fieldMax: field, hullMax: hull),
    ];
    shield = shieldMax;
    core = coreMax;
    motionPhase = startingPhase;
    x = forecastX(0, 1);
    horizontalVelocity = startingDirection.toDouble();
  }
  static const double sideHatchOffset = 46.0;

  // --- carrier-hatches (design §A2–§A5): the three chapters.
  late final List<HatchState> hatches;
  CarrierChapter chapter = CarrierChapter.hatches;

  /// The fight's first `bossHatchTier` has been queued.
  bool announced = false;

  /// Seconds into the transformation (0 outside it).
  double transformT = 0;

  static int _hatchPool(int shield, int cycle, int difficulty) {
    final n = CarrierHatches.forTour(cycle).length;
    final (f, h) = CarrierHatches.hpOf(shield, n, difficulty: difficulty);
    return n * (f + h);
  }

  /// The vulnerable (and launching) upper tier: the topmost with a hatch
  /// standing; null when every upper hatch is destroyed.
  int? get vulnerableTier {
    int? t;
    for (final h in hatches) {
      if (h.destroyed) continue;
      if (t == null || h.hatch.tier < t) t = h.hatch.tier;
    }
    return t;
  }

  /// The hatches of the vulnerable tier still standing.
  Iterable<HatchState> get vulnerableHatches {
    final t = vulnerableTier;
    return hatches.where((h) => !h.destroyed && h.hatch.tier == t);
  }

  int get upperTiers => hatches.isEmpty ? 0 : hatches.last.hatch.tier + 1;
  int get hatchesLeft => hatches.where((h) => !h.destroyed).length;

  /// Every upper hatch destroyed and its break-up done.
  bool get hatchesDown => hatches.every((h) => h.down);

  /// The lateral glide's phase-rate factor of this chapter.
  double get glideFactor => switch (chapter) {
    CarrierChapter.hatches => CarrierHatches.hatchGlide,
    CarrierChapter.transform => CarrierHatches.transformGlide,
    CarrierChapter.core => CarrierHatches.coreGlide,
  };

  /// The core can be damaged (the core chapter only).
  bool get coreOpen => chapter == CarrierChapter.core;
  final int startingDirection;
  final double startingPhase;
  double motionPhase = 0, horizontalVelocity = 0;
  // --- boss-grandeur: the Rise (design §1) and the glide (§5) ---
  /// Rise progress 0..1: the carrier emerges from under the fog over
  /// [riseSeconds]; it has no hitbox and fires nothing until it is fully
  /// out (the fight-ready rule).
  double emerge = 1;

  /// carrier-v3: the Close (D 1.35 → 1) takes 4 s (was the 5 s Rise).
  static const riseSeconds = 4.0;
  bool get fightReady => emerge >= 1;

  /// The level clock when it became fight-ready: door and fan cycles run
  /// on the seconds since (as they ran on the level clock when the carrier
  /// arrived ready).
  double readyAt = 0;

  /// The vertical glide phase φ (gameplay hook b): y = 205 + 16·sin φ.
  double glidePhase = 0;
  static const fightRow = 205.0, glideAmplitude = 16.0, glideRate = .35;
  double get glide => math.sin(glidePhase);

  /// Seeded pick of this carrier's visual module set (operator R8.6:
  /// per-run variety; presentation only, never read by the simulation).
  int variant = 0;

  /// Lit hex shield cells (alien-insignia: 12 on the carrier).
  static int shieldCells(int shield, int shieldMax) =>
      shieldMax <= 0 ? 0 : (12 * shield / shieldMax).ceil().clamp(0, 12);

  /// Armour steps: two per form (a plate lost, then the form's module),
  /// counted from core damage; [armourSteps] is the collapse.
  int get armourSteps => 2 * formCount;
  int get armourStep =>
      ((1 - core / coreMax) * armourSteps).floor().clamp(0, armourSteps);
  // --- end boss-grandeur

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
        motionPhase +
        seconds * .7 * speed * movementRate * glideFactor * startingDirection;
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
  // --- carrier-hatches §A5: the side hatches are sealed for good (the core
  // door is the only target).
  bool get sideHatchesLocked => true;
}

/// Pure fixed-step simulation; renderers and input never change its clock.
class ArcadeModel {
  ArcadeModel({this.seed = 1982})
    : random = math.Random(seed),
      flock = SwarmFlock(seed: seed),
      stream = SwarmStream(seed: seed);

  /// The run seed (presentation streams such as the easter eggs derive
  /// from it; the simulation uses [random]).
  final int seed;
  static const width = 360.0, height = 520.0, shipY = 477.0;
  final math.Random random;
  RunMode mode = RunMode.title;
  RunMode _beforePause = RunMode.playing;
  final List<Demon> demons = [];
  final List<Shot> shots = [];
  final List<Pickup> pickups = [];
  final List<Blast> blasts = [];

  /// playtest-fixes-3: hits glancing off a berserk sentinel this moment.
  final List<Deflect> deflects = [];
  final List<SupplyCrate> supplyCrates = [];
  final List<FallingPart> fallingParts = [];
  double crateSpawnTimer = 0.0;
  final List<String> events = [];

  // --- demon intelligence (demon-intelligence design §2): the forecast
  // of the player that hunters and the sentinel rush aim at.
  final PilotModel pilot = PilotModel();

  /// The tiers' brains (design §3-§4); false restores the pre-W4 swarm
  /// (a fixture and calibration flag). Route 0 is unchanged either way.
  bool intelligence = true;
  bool get _intel => intelligence && cycle >= 1;

  // --- bonus levels (model_bonus.dart): the run's plan, the level being
  // played and the bonus powers. Empty unless the run has a run seed.
  final BonusRun bonusRun = BonusRun();

  /// --- crosswind: the level's wind (model_wind.dart).
  final WindRun windRun = WindRun();

  /// --- spear-bearers: the run's bearers (the next birth, fallen bucklers).
  final SpearRun spearRun = SpearRun();

  /// The odds a seeded run's plan is drawn with.
  BonusTuning bonusTuning = BonusTuning.standard;

  /// The energy planner (its own PRNG: never draws from [random]).
  late final DemonPlanner planner = DemonPlanner(seed);
  final PlanState _plan = PlanState();

  /// Planner decisions are 10 Hz per creature, staggered by seed, at most
  /// [maxPlanDecisions] per frame (the rest wait their turn).
  static const planRate = 10.0, maxPlanDecisions = 6;
  int planDecisionsThisFrame = 0;

  static DemonTier tierOf(Demon d) => d.isLarge
      ? DemonTier.sentinel
      : d.elite
      ? DemonTier.hunter
      : (d.kind >= 2 || d.maxHp >= 3)
      ? DemonTier.skirmisher
      : DemonTier.drone;

  /// The skill level hunters react to (design §7): derived from these
  /// counters only (never score, power-ups or time survived).
  final SkillMeter skill = SkillMeter();
  double get skillLevel => _intel ? skill.level : 0;
  int shotsFired = 0, shotsHit = 0, nearMisses = 0;

  /// The brood remarks once per sector when the skill level rises through
  /// [adaptingAt].
  static const adaptingAt = .65;
  bool _adaptedThisSector = false;
  double _lastSkill = SkillMeter.initial;

  void _resetSkill() {
    skill
      ..cap = policy.skillCap
      ..reset();
    shotsFired = shotsHit = nearMisses = 0;
    _lastSkill = skill.level;
  }

  void _observeSkill(double dt) {
    skill.observe(
      dt,
      shotsFired: shotsFired,
      shotsHit: shotsHit,
      nearMisses: nearMisses,
    );
    final s = skill.level;
    if (_intel &&
        !_adaptedThisSector &&
        _lastSkill < adaptingAt &&
        s >= adaptingAt) {
      _adaptedThisSector = true;
      _queueGameEvent(GameEventNames.broodAdapting, {'skill': s});
    }
    _lastSkill = s;
  }

  // --- ground war state (see ground_war.dart) ---
  final GroundWar ground = GroundWar();

  /// Structured events queued outside the ground war (life loss, dives).
  final List<GameEvent> _gameEvents = [];

  void _queueGameEvent(String name, [Map<String, Object?> data = const {}]) =>
      _gameEvents.add(GameEvent(name, {'sector': level, ...data}));

  /// Drains the named gameplay events for music/comms hooks.
  List<GameEvent> takeGameEvents() {
    final result = [..._gameEvents, ...ground.events];
    _gameEvents.clear();
    ground.events.clear();
    return result;
  }

  // --- lightning-rework state (see lightning.dart): the ship's lightning
  // grace and its zap (seconds left, what the last zap stripped), and the
  // stunned creatures shot down this step (a storm's mechanic drains it).
  double lightningGrace = 0, shipShock = 0;
  List<Power> shockLost = const [];
  int shipZaps = 0;
  final List<Demon> stunKills = [];

  // --- life-loss sequence state (see life_loss.dart) ---
  LifeLossPhase lifeLossPhase = LifeLossPhase.none;
  double lifeLossLeft = 0, lifeLossX = 180;
  final List<ShipDebris> shipDebris = [];
  final List<ShotFizzle> shotFizzles = [];

  /// The ship is away: exploding or the swarm regrouping.
  bool get shipAway => holdHostileFire;

  /// Seconds since the ship was destroyed (while the sequence runs).
  double get lifeLossElapsed => switch (lifeLossPhase) {
    LifeLossPhase.none => 0,
    LifeLossPhase.exploding => LifeLossTuning.explode - lifeLossLeft,
    LifeLossPhase.regrouping => LifeLossTuning.away - lifeLossLeft,
    LifeLossPhase.emerging =>
      LifeLossTuning.away + LifeLossTuning.emerge - lifeLossLeft,
  };

  /// Regroup pause in progress (shots draining, the swarm reforming).
  bool get regrouping => lifeLossPhase == LifeLossPhase.regrouping;

  /// 0 at the start of the fly-in, 1 on the ship line.
  double get emergeProgress => lifeLossPhase == LifeLossPhase.emerging
      ? (1 - lifeLossLeft / LifeLossTuning.emerge).clamp(0.0, 1.0)
      : 1.0;

  /// Where the ship is drawn: below the edge while away, flying in after.
  double get shipDrawY {
    if (shipAway) return LifeLossTuning.emergeFromY;
    final u = emergeProgress;
    final ease = 1 - (1 - u) * (1 - u) * (1 - u);
    return LifeLossTuning.emergeFromY +
        (shipY - LifeLossTuning.emergeFromY) * ease;
  }

  void _resetLifeLoss() {
    lifeLossPhase = LifeLossPhase.none;
    lifeLossLeft = 0;
    shipDebris.clear();
    shotFizzles.clear();
    _gameEvents.clear();
  }

  // --- divePrep: a beat of radio warning before every dive tell ---
  static const divePrepBeat = .5;

  /// Seconds of dive tell (telegraph) before [d] leaves the formation.
  static double diveTellFor(Demon d) => d.isLarge
      ? .9
      : d.elite
      ? .55
      : .7;

  void _prepDive(Demon d, {bool lead = false}) {
    d.divePrep = divePrepBeat;
    d._prepLead = lead;
    final rate = policy.hostileRate;
    _queueGameEvent(GameEventNames.divePrep, {
      'x': d.x,
      'y': d.y,
      'lead': divePrepBeat,
      // Seconds until the dive itself starts (the beat plus the tell, at
      // this difficulty's pace): the radio ends its dive call on it.
      'diveIn': (divePrepBeat + diveTellFor(d)) / (rate > 0 ? rate : 1),
      'sentinel': d.isLarge,
      'elite': d.elite,
      // --- fang-and-wings-comms: species, toughness (the rank) and the
      // seconds until the tell, for the dive war cries (dive_cry.dart).
      'kind': d.kind,
      'maxHp': d.maxHp,
      'tellIn': divePrepBeat / (rate > 0 ? rate : 1),
    });
  }

  void _startDiveTell(Demon d) {
    d.divePrep = 0;
    d.telegraph = diveTellFor(d);
    d.targetX = d._prepLead
        ? (shipX + shipVx * 0.22).clamp(24.0, width - 24.0)
        : shipX;
    // --- demon intelligence: a hunter aims at the forecast from skill
    // 0.4 (and always in a pincer, either side of it). Fixed from here.
    if (_intel &&
        d.elite &&
        !d.isLarge &&
        (d.pincer != 0 || skillLevel >= .4)) {
      final rate = policy.hostileRate > 0 ? policy.hostileRate : 1;
      final tau = _diveEta(d) - divePrepBeat / rate;
      d.targetX = (pilot.aim(tau) + d.pincer * pincerSpread).clamp(
        24.0,
        width - 24.0,
      );
    }
    d.pincer = 0;
  }

  /// Pincer aims sit this far either side of the forecast (design §5).
  static const pincerSpread = 34.0;

  /// At skill ≥ 0.5, with probability 0.35 (s − 0.5) / 0.5 (the planner's
  /// PRNG), a second ready hunter joins [d]'s dive.
  Demon? _pincerPartner(Demon d, List<Demon> ready) {
    if (!_intel || !d.elite || d.isLarge) return null;
    final s = skillLevel;
    if (s < .5) return null;
    final partner = ready
        .where((o) => o.elite && !o.isLarge && !identical(o, d))
        .firstOrNull;
    if (partner == null) return null;
    return planner.roll() < .35 * (s - .5) / .5 ? partner : null;
  }

  /// The thread dive (design §5): today's straight line toward the fixed
  /// aim, plus a weave from it chosen at 10 Hz from {−110, 0, +110} ·
  /// tempo against the player's shots, |offset| ≤ 60, ≤ 900 u/s².
  void _threadDive(Demon d, double dt, double fall) {
    final k = policy.hostileRate * 2.1;
    d.threadLine += (d.targetX - d.threadLine) * dt * k;
    if (_planDue(d)) {
      final cfg = PlannerConfig.hunter(skillLevel);
      d.threadTarget = DemonPlanner.threadLateral(
        x: d.x,
        y: d.y,
        vy: fall,
        lineAhead:
            d.threadLine + (d.targetX - d.threadLine) * (1 - math.exp(-k * .3)),
        lateral: threadLateral * policy.swarmTempo(route: cycle),
        radius: d.hitHalfWidth + 3,
        delay: cfg.delay,
        foresight: cfg.foresight,
        shots: shots,
        current: d.threadTarget,
      );
    }
    d.threadVx += (d.threadTarget - d.threadVx).clamp(
      -threadAccel * dt,
      threadAccel * dt,
    );
    var off = d.threadOffset + d.threadVx * dt;
    if (off.abs() > threadReach) {
      off = off.sign * threadReach;
      d.threadVx = 0;
    }
    d.threadOffset = off;
    d.x = (d.threadLine + off).clamp(18.0, width - 18.0);
  }

  /// Thread-dive bounds: lateral speed (u/s, × tempo), acceleration
  /// (u/s²) and the reach from the straight line (u).
  static const threadLateral = 110.0, threadAccel = 900.0, threadReach = 60.0;

  Carrier? boss;
  Carrier? wreckBoss;

  // --- boss-grandeur: the loom (design §1, gameplay hook a) ---
  /// The boss level's own PRNG stream (`seed ^ 0xB055`): the glide phase.
  late final math.Random bossRandom = math.Random(seed ^ 0xB055);

  /// Ordinary waves that open the boss level while the carrier looms under
  /// the fog: one on the first tour, two from the second.
  ///
  /// carrier-v3 §4.3: these are the carrier's launch waves, two on tours
  /// 1–3 and three from tour 4 (the script's `launchWaves`).
  static int loomWavesFor(int route) =>
      CarrierScript.authored(route).launchWaves;
  int get loomWaves => loomWavesFor(cycle);

  /// The loom's cap: after it the carrier closes regardless (carrier-v3:
  /// 90 s, was 75). fire-rate-tune: 120 s, the old 90 s scaled with the
  /// volley interval (90 × 0.30 / 0.23 ≈ 117), so tour 5's third launch
  /// wave still comes before the carrier closes.
  static const loomCap = 120.0;

  // --- carrier-v3: the approach and the gates (design §4–§5) ---
  /// This tour's carrier script (seeded presentation for a seeded run).
  CarrierScript get carrierScript {
    final key = (runSeed, cycle);
    if (_scriptKey != key || _carrierScript == null) {
      _scriptKey = key;
      _carrierScript = CarrierScript.forRun(runSeed, cycle);
    }
    return _carrierScript!;
  }

  CarrierScript? _carrierScript;
  (int?, int)? _scriptKey;

  /// The approach distance factor D (scale on screen 1/D); 0 outside the
  /// boss level's approach and close. [approachClock]: its seconds.
  double approachD = 0, approachClock = 0;
  int _approachStep = -1;
  double _stepFrom = 0, _stepT = 0;

  /// D when the Close began (presentation eases from it to 1).
  double closeFromD = 1.35;

  /// The carrier's gates (approach launches and the fight's flocks).
  CarrierLaunches? launches;

  /// Where the approaching carrier is (arena units, presentation and the
  /// gates' projection).
  ({double x, double y}) get approachAt =>
      CarrierApproachScript.placement(math.max(1, approachD), approachClock);

  /// Where gate [g] is on screen during the approach.
  ({double x, double y}) gateOnApproach(CarrierGate g) {
    final at = approachAt, d = math.max(1.0, approachD);
    return (x: at.x + g.x / d, y: at.y + g.y / d);
  }

  /// Where gate [g] of fighting carrier [b] is (hull-local plus centre).
  static ({double x, double y}) gateOnCarrier(Carrier b, CarrierGate g) =>
      (x: b.x + g.x, y: b.y + g.y);

  CarrierLaunches _launchesFor() {
    final sc = carrierScript;
    return CarrierLaunches(
      gates: sc.gates,
      order: sc.gateOrder,
      seed: seed,
      timing: CarrierVolleyTiming(
        telegraph: sc.volley.telegraph,
        open: sc.volley.open,
        interval: sc.volley.interval,
        close: sc.volley.close,
        maxOpen: sc.volley.maxOpen,
      ),
    );
  }

  void _resetApproach() {
    approachD = 0;
    approachClock = 0;
    _approachStep = -1;
    _stepT = 0;
    launches = null;
    _fightGate = null;
    _fieldImpacts.clear();
  }

  /// Steps the approach (combat seconds): D eases to the step of the
  /// launch waves cleared so far over 3 s, then creeps toward the next.
  void _updateApproach(double dt) {
    final a = carrierScript.approach;
    if (looming) {
      launches ??= _launchesFor();
      final step = (wave - 1).clamp(0, a.distances.length - 2);
      if (_approachStep < 0) {
        _approachStep = step;
        approachD = a.d0;
        _stepFrom = a.d0;
        _stepT = a.stepSeconds;
        _queueGameEvent(GameEventNames.bossApproach, {
          ..._carrierEventData,
          'step': 0,
          'distance': approachD,
        });
      } else if (step != _approachStep) {
        _approachStep = step;
        _stepFrom = approachD;
        _stepT = 0;
        _queueGameEvent(GameEventNames.bossApproach, {
          ..._carrierEventData,
          'step': step,
          'distance': a.distances[step],
        });
      }
      approachClock += dt;
      final target = a.distances[step];
      final next = a.distances[step + 1];
      if (_stepT < a.stepSeconds) {
        _stepT += dt;
        final u = (_stepT / a.stepSeconds).clamp(0.0, 1.0);
        approachD = _stepFrom + (target - _stepFrom) * u * u * (3 - 2 * u);
      } else {
        approachD = math.max(next, approachD - a.creep * dt);
      }
    } else if (boss != null && !boss!.fightReady) {
      // The Close: D eases from where it was to 1 (the hittable threshold).
      final e = boss!.emerge.clamp(0.0, 1.0);
      final k = e * e * (3 - 2 * e);
      approachD = closeFromD + (1 - closeFromD) * k;
      approachClock += dt;
    }
    final l = launches;
    if (l != null) {
      l.step(dt);
      for (final e in l.takeEvents()) {
        _queueGateEvent(e);
      }
    }
  }

  Map<String, Object?> get _carrierEventData {
    final a = BossGrammar.forRun(route: cycle, variant: bossVariant);
    return {
      'route': cycle,
      'tour': cycle + 1,
      'set': a.setName,
      'variant': bossVariant,
    };
  }

  // --- hatch-emergence: the presentation's read of the next fight flock.
  /// The fight's minion cap by route (6, 8, then 10).
  static int fightMinionCap(int cycle) =>
      cycle == 0 ? 6 : (cycle == 1 ? 8 : 10);

  /// How many creatures the fight's next hatch flock would hold if it left
  /// now (0–3): the lurkers a held hatch shows. Read only.
  int get hatchFlockPreview =>
      (fightMinionCap(cycle) - demons.length).clamp(0, 3);

  void _queueGateEvent(GateEvent e) {
    final g = e.run.gate;
    // --- carrier-hatches §A8: the volley lifecycle on the hatches.
    final tier = g is CarrierHatch
        ? (g.isCore ? (boss?.upperTiers ?? 0) + 1 : g.tier + 1)
        : 0;
    final data = {
      ..._carrierEventData,
      'hatch': g.id,
      'tier': tier,
      'shootable': true,
    };
    switch (e.kind) {
      case GateState.telegraph:
        _queueGameEvent(GameEventNames.bossHatchTelegraph, {
          ...data,
          'slot': g.slot,
          'side': g.side,
          'kind': g.kind.name,
        });
      case GateState.opening:
        _queueGameEvent(GameEventNames.bossHatchOpen, data);
      case GateState.launching:
        _queueGameEvent(GameEventNames.bossLaunch, {
          ...data,
          'count': e.count,
          'kind': e.run.tier,
        });
      case GateState.closed:
        _queueGameEvent(GameEventNames.bossHatchClose, data);
      case GateState.closing:
        break;
    }
  }

  /// The approach's launch waves come out of the carrier's gates (design
  /// §4.3): [group] enters from the next gate of the round-robin, projected
  /// through D, each member parked until its turn in the volley.
  void _gateLaunch(List<Demon> group) {
    final l = launches;
    if (l == null || approachD <= 0) return;
    final members = [
      for (final d in group)
        if (d.arrivesFromDistance && !d.isLarge && d.gateWait <= 0) d,
    ];
    if (members.isEmpty) return;
    // carrier-hatches: the approach launches from the upper hatches.
    final run = l.pick(
      (g) => gateOnApproach(g).x,
      eligible: (g) => g is CarrierHatch && !g.isCore,
    );
    if (run == null) return;
    final delays = l.volley(run, members.length, tier: members.first.kind);
    final at = gateOnApproach(run.gate);
    // Out of a deep gate: the far fog's nearness, nearer as D falls.
    final n = (.12 + .08 * ((4.5 - approachD) / 3.5)).clamp(.12, .2);
    for (final (i, d) in members.indexed) {
      d
        ..entryX = at.x
        ..entryY = at.y
        ..entryN = n
        ..gateWait = delays[i];
    }
  }

  /// The approach's live creatures are all parked in gates (the power
  /// timers hold, as they do while the carrier closes).
  /// The power timers' rate while [_gateHeld].
  static const gateHoldRate = .5;

  bool get _gateHeld {
    if (!looming || launches == null) return false;
    var parked = false;
    for (final d in demons) {
      if (d.isLarge || d.swarmState == SwarmState.reserve) continue;
      if (d.gateWait <= 0) return false;
      parked = true;
    }
    return parked;
  }

  // --- console boss launcher (operator C2, round 3b): debug only.
  /// A /console run fast-forwards the carrier's decay: every
  /// [consoleDecaySeconds] of its fight, one step (shield to half, shield
  /// down, then each armour step and form change, then the collapse),
  /// through the real hit path so every decay event is queued. Only a
  /// console run (never ranked) sets it; [start] clears it.
  bool consoleDecay = false;
  static const consoleDecaySeconds = 2.5;
  double _consoleDecayLeft = consoleDecaySeconds;

  void _consoleDecayStep(double dt) {
    final b = hittableBoss;
    if (b == null) return;
    _consoleDecayLeft -= dt;
    if (_consoleDecayLeft > 0) return;
    _consoleDecayLeft = consoleDecaySeconds;
    consoleDecayNow();
  }

  /// One decay step now (the console's fast-forward; tests).
  void consoleDecayNow() {
    final b = hittableBoss;
    if (b == null || ranked) return;
    // --- carrier-hatches: one step destroys the vulnerable tier.
    if (b.chapter == CarrierChapter.hatches) {
      for (final h in b.vulnerableHatches.toList()) {
        _damageHatch(b, h, h.hp);
        if (!h.destroyed) _damageHatch(b, h, h.hp);
      }
      return;
    }
    if (b.chapter == CarrierChapter.transform) return;
    if (b.shield * 2 > b.shieldMax) {
      hitBoss(b.x, damage: b.shield - b.shieldMax ~/ 2);
    } else if (b.shield > 0) {
      hitBoss(b.x, damage: b.shield);
    } else {
      final next = b.armourStep + 1;
      final target = (b.coreMax * (1 - next / b.armourSteps)).floor();
      b.door = 1; // the core is open for the step
      hitBoss(b.x, damage: math.max(1, b.core - target));
    }
  }

  /// The fight's flock gate (design §4.4): chosen and telegraphing ahead
  /// of the flock timer, so the spawn moments do not move.
  GateRun? _fightGate;

  // --- carrier-hatches (design §A2–§A8): chapters, hatch hits, hints.
  /// Core-door launches, and how many of them waited for the door
  /// (calibration: the hold's share of delayed arrivals, §A11).
  int coreLaunches = 0, coreHolds = 0;

  /// A shield zeroed from outside the hit path (fixtures, saved states):
  /// the hatches are gone and the core is exposed at once, no events.
  static void syncChapter(Carrier b) {
    if (b.chapter != CarrierChapter.hatches || b.shield > 0) return;
    if (b.hatches.every((h) => h.destroyed)) return; // the real path
    for (final h in b.hatches) {
      h
        ..field = 0
        ..hull = 0
        ..fallen = CarrierHatches.fallSeconds;
    }
    b.chapter = CarrierChapter.core;
  }

  /// Upper hatches still to fall before the transformation: their break-up
  /// time is mirrored here ([CarrierHatches.fallSeconds]).
  void _updateHatchChapters(Carrier b, double dt) {
    syncChapter(b);
    // The fight's first section, then the first hint (2 s in).
    if (!b.announced) {
      b.announced = true;
      if (b.chapter == CarrierChapter.hatches) {
        _hatchTierEvent(b, from: 0);
        _hintHatchesAt = levelClock + 2;
      }
    }
    for (final h in b.hatches) {
      if (h.destroyed && !h.down) h.fallen += dt;
    }
    switch (b.chapter) {
      case CarrierChapter.hatches:
        if (b.hatchesDown) {
          b
            ..chapter = CarrierChapter.transform
            ..transformT = 0;
          launches?.closeAll();
          _fightGate = null;
          final data = _decayData(b);
          _queueGameEvent(GameEventNames.bossShieldDown, data);
          _queueGameEvent(GameEventNames.bossTransform, {
            ..._carrierEventData,
            'stage': 'start',
            'seconds': CarrierHatches.transformSeconds,
          });
          events.add('boss');
        }
      case CarrierChapter.transform:
        b.transformT += dt;
        if (b.transformT >= CarrierHatches.transformSeconds) {
          b.chapter = CarrierChapter.core;
          _queueGameEvent(GameEventNames.bossTransform, {
            ..._carrierEventData,
            'stage': 'end',
            'seconds': CarrierHatches.transformSeconds,
          });
          _queueGameEvent(GameEventNames.bossCoreExposed, _decayData(b));
          _hatchTierEvent(b, from: b.upperTiers);
          _hint(GameEventNames.bossHintTiming, force: true);
        }
      case CarrierChapter.core:
        break;
    }
    _hintClock(b);
  }

  /// The fall and the transformation at once (the direct-damage API).
  void _instantTransform(Carrier b) {
    for (final h in b.hatches) {
      h.fallen = math.max(h.fallen, CarrierHatches.fallSeconds);
    }
    _updateHatchChapters(b, 0); // → transform (shieldDown, transform start)
    b.transformT = CarrierHatches.transformSeconds;
    _updateHatchChapters(b, 0); // → core (transform end, core exposed)
  }

  Map<String, Object?> _decayData(Carrier b) {
    final a = BossGrammar.forRun(route: cycle, variant: b.variant);
    return {'route': cycle, 'variant': b.variant, 'set': a.setName};
  }

  /// `bossHatchTier`: the vulnerable tier is now [Carrier.vulnerableTier]
  /// (or the core door), from tier [from] (1-based; 0 at the start).
  void _hatchTierEvent(Carrier b, {required int from}) {
    final tiers = b.upperTiers + 1;
    final t = b.chapter == CarrierChapter.core
        ? tiers
        : (b.vulnerableTier ?? b.upperTiers - 1) + 1;
    if (t == from) return;
    _queueGameEvent(GameEventNames.bossHatchTier, {
      ..._carrierEventData,
      'tier': t,
      'tiers': tiers,
      'depth': tiers <= 1 ? 1.0 : (t - 1) / (tiers - 1),
      'shootable': true,
      'from': from,
    });
  }

  /// The hull-local y the next fight flock leaves from.
  double _launchTierY(Carrier b) {
    if (b.chapter == CarrierChapter.core) return CarrierHatches.core.y;
    final v = b.vulnerableHatches;
    return v.isEmpty ? CarrierHatches.core.y : v.first.hatch.y;
  }

  /// Whether gate [g] launches now: a standing hatch of the vulnerable
  /// tier, or the core door in the core chapter.
  bool _launchesFrom(Carrier b, CarrierGate g) {
    if (g is! CarrierHatch) return false;
    if (b.chapter == CarrierChapter.core) return g.isCore;
    if (g.isCore) return false;
    final t = b.vulnerableTier;
    return t != null &&
        g.tier == t &&
        b.hatches.any((h) => h.hatch.id == g.id && !h.destroyed);
  }

  /// The core door's opening (the unchanged cycle) at fight clock [c].
  static double coreDoorAt(Carrier b, double c, int cycle) =>
      ((math.sin(c * (1.55 + b.phase * .22)) - (cycle == 0 ? 0.0 : .1)) * 2)
          .clamp(0.0, 1.0);

  /// Seconds until the core door is open (≥ 0.6) from fight clock [c], at
  /// most one period (§A5); 0 when it is open now.
  double _coreDoorWait(Carrier b, double c) {
    final period = 2 * math.pi / (1.55 + b.phase * .22);
    for (var t = 0.0; t <= period; t += 1 / 60) {
      if (coreDoorAt(b, c + t, cycle) >= CarrierHatches.coreOpenAt) return t;
    }
    return period;
  }

  /// Damages hatch [h] of carrier [b] (its field first). Returns true.
  bool _damageHatch(Carrier b, HatchState h, int damage) {
    if (h.destroyed || damage <= 0) return false;
    final tierBefore = b.vulnerableTier;
    final halfBefore = b.hatchesLeft * 2 > b.hatches.length;
    final data = {
      ..._carrierEventData,
      'hatch': h.hatch.id,
      'tier': h.hatch.tier + 1,
      'side': h.hatch.side,
    };
    if (h.field > 0) {
      h.field = math.max(0, h.field - damage);
      if (h.field == 0) {
        _queueGameEvent(GameEventNames.bossHatchFieldDown, data);
      }
    } else {
      h.hull = math.max(0, h.hull - damage);
      if (h.hull == 0) {
        h.fallen = 0;
        _queueGameEvent(GameEventNames.bossHatchDrop, {
          ...data,
          'cause': 'shot',
          'left': b.hatchesLeft,
        });
        blasts.add(Blast(b.x + h.hatch.x, b.y + h.hatch.y, big: true));
        if (halfBefore && b.hatchesLeft * 2 <= b.hatches.length) {
          _queueGameEvent(GameEventNames.bossShieldFailing, _decayData(b));
        }
        final t = b.vulnerableTier;
        if (t != null && t != tierBefore) {
          _hatchTierEvent(b, from: (tierBefore ?? 0) + 1);
        }
      }
    }
    b.shield = b.hatches.fold(0, (a, x) => a + x.hp);
    events.add('hit');
    blasts.add(Blast(b.x + h.hatch.x, b.y + h.hatch.y));
    return true;
  }

  /// A player shot against the hatch chapter (design §A3): crossing the
  /// vulnerable tier's row this frame, it strikes a hatch's field or hull
  /// within its radius, or sparks off the armour. Returns whether the shot
  /// was stopped.
  bool _hatchShot(Carrier b, Shot s) {
    final v = b.vulnerableHatches.toList();
    if (v.isEmpty) return false;
    final row = b.y + v.first.hatch.y;
    final previousY = s.y - s.vy / 60;
    if (!(s.y <= row && previousY >= row)) return false;
    final blast = s.blastRadius > 0 ? 5.0 : 0.0;
    for (final h in v) {
      final r =
          (h.field > 0 ? CarrierHatches.fieldRadius : CarrierHatches.hullRadius) +
          blast;
      if ((s.x - (b.x + h.hatch.x)).abs() <= r) {
        s.y = row;
        if (s.blastRadius > 0) _explodeShot(s, hitCarrier: false);
        _damageHatch(b, h, s.damage);
        return true;
      }
    }
    if ((s.x - b.x).abs() <= CarrierHatches.armourHalfWidth) {
      deflects.add(Deflect(s.x, row, b.x, row - 30));
      _armourMisses.add(levelClock);
      return true;
    }
    return false;
  }

  /// Hits hatch [i] directly (tests, the /console fast decay).
  bool hitHatch(int i, {int damage = 1}) {
    final b = hittableBoss;
    if (b == null || !combat || b.chapter != CarrierChapter.hatches) {
      return false;
    }
    final h = b.hatches[i];
    if (h.destroyed || h.hatch.tier != b.vulnerableTier) return false;
    return _damageHatch(b, h, damage);
  }

  // Hints (§A7): shot patterns and cooldowns, on the level clock.
  final List<double> _armourMisses = [], _closedDoorHits = [], _trailing = [];
  final Map<String, double> _hintAt = {};
  double? _hintHatchesAt;
  static const _hintCooldown = {
    GameEventNames.bossHintHatches: 20.0,
    GameEventNames.bossHintTiming: 20.0,
    GameEventNames.bossHintLead: 25.0,
  };

  /// Whether the lead hint has played this fight (the lead pip shows on
  /// Easy and Normal after it, §A5).
  bool leadHinted = false;

  /// The lead pip shows (Easy and Normal, after the first lead hint, in
  /// the core chapter); never on Hard.
  bool get leadPipShown =>
      leadHinted &&
      difficulty != Difficulty.hard &&
      boss?.chapter == CarrierChapter.core;

  /// Where a shot fired now meets the core door's row: the door's forecast
  /// x when the shot arrives, on that row (arena units).
  ({double dx, double dy}) leadPipAt(Carrier b) {
    final row = b.y + CarrierHatches.core.y;
    final flight = (shipY - row) / shotSpeed;
    return (dx: b.forecastX(flight, speed), dy: row);
  }

  void _hint(String name, {bool force = false}) {
    final last = _hintAt[name];
    if (!force && last != null && levelClock - last < _hintCooldown[name]!) {
      return;
    }
    _hintAt[name] = levelClock;
    if (name == GameEventNames.bossHintLead) leadHinted = true;
    _queueGameEvent(name, {..._carrierEventData, 'hint': name});
  }

  void _hintClock(Carrier b) {
    final now = levelClock;
    final at = _hintHatchesAt;
    if (at != null && now >= at) {
      _hintHatchesAt = null;
      _hint(GameEventNames.bossHintHatches, force: true);
    }
    if (b.chapter == CarrierChapter.transform) return;
    _armourMisses.removeWhere((t) => t < now - 4);
    _closedDoorHits.removeWhere((t) => t < now - 3);
    _trailing.removeWhere((t) => t < now - 4);
    if (_armourMisses.length >= 6) {
      _armourMisses.clear();
      _hint(GameEventNames.bossHintHatches);
    }
    if (_closedDoorHits.length >= 4) {
      _closedDoorHits.clear();
      _hint(GameEventNames.bossHintTiming);
    }
    if (_trailing.length >= 3) {
      _trailing.clear();
      _hint(GameEventNames.bossHintLead);
    }
  }

  /// Field impacts in the last second (`bossFieldImpact`: at most 4/s).
  final List<double> _fieldImpacts = [];

  /// Queues a presentation event (the director's take-off, climb peak,
  /// surges): it goes into the game event queue and never changes the
  /// simulation.
  void queuePresentationEvent(String name, [Map<String, Object?> data = const {}]) =>
      _queueGameEvent(name, {..._carrierEventData, ...data});

  /// Combat seconds of the current loom (0 outside it).
  double loomClock = 0;

  /// The boss level's ordinary loom waves are under way (no carrier yet).
  bool get looming =>
      level == 5 && boss == null && wave < wavesPerLevel && clearedLevel == null;

  /// The wave that brings the carrier: the boss level's last.
  bool get _bossWave => level == 5 && wave >= wavesPerLevel;

  /// The carrier rises out of the fog (presentation reads it).
  bool get bossRising => boss != null && !boss!.fightReady;

  /// The carrier when it can be hit and targeted (fully emerged).
  Carrier? get hittableBoss {
    final b = boss;
    return b != null && b.fightReady ? b : null;
  }
  // --- end boss-grandeur

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

  /// The zero-based route of the campaign's last carrier (five in all).
  static const finalRoute = 4;

  /// Whether the carrier on screen (or just destroyed) is the campaign's
  /// last: sector 5 of the fifth route. Only its victory earns the ending.
  bool get finalBoss => level == 5 && cycle >= finalRoute;

  /// False for a /console run: it starts with one life at 0 points and never
  /// reaches the top-10 board, the saved checkpoint or the unlock history.
  bool ranked = true;
  static const maxActiveDemons = 61;

  /// Pseudo-3D swarm depth (plan/perspective.md). False restores the flat
  /// legacy sizes, hitboxes and entrances; kept for calibration tests.
  bool perspective = true;
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

  // --- cinematic flow (model_flow.dart, flow_director.dart) ---
  /// The transition's one clock; presentation reads its envelopes.
  final flow = FlowDirector();

  /// Reduced motion (accessibility): the same beats, shorter, no tilt.
  bool reducedMotion = false;

  /// Seconds a scheduled message slot asks Pursuit to grow (0-2; set by the
  /// presenter before travel starts, rounded up to whole beats).
  double slotExtra = 0;

  /// Screen direction the pursued flock flies (-1 left, 1 right).
  int flowDirection = 1;

  /// Sectors this run has entered (transition-ascent: a sector change into
  /// one of them is a revisit, answered by a front-line call). Presentation
  /// only; a resumed or later-route run counts every sector as visited.
  final Set<int> visitedSectors = {};

  /// The cosmetic flock of the transition (never in [demons]).
  final List<FlowMember> flowFlock = [];
  double _flowBase = 0;
  bool _skipPending = false;

  /// Skip a sector transition (tap, Space, Enter): the Descent starts on
  /// the next frame, or when the pickup grace ends. False: nothing to skip.
  bool skipTransition() => _skipTransition();

  /// A skip is waiting for the end of the Rout.
  bool get skipPending => _skipPending;

  /// Ends the current (non-carrier) sector at once, as its last kill would:
  /// the Rout, Pursuit and Descent follow (console and tests).
  void endSector() {
    if (boss != null || !combat) return;
    wave = wavesPerLevel;
    demons.clear();
    incoming.clear();
    _completeWave();
  }

  // --- end cinematic flow
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

  // --- fire-rate-tune: the player's cadence and shot speeds, and the
  // anti-strobe grid (openspec/changes/fire-rate-tune/design.md).
  /// The model's fixed step (s).
  static const fixedStep = 1 / 60;

  /// Volley interval in whole model steps: 18 = 0.30 s (was 0.23 s, 13.8
  /// steps, which fired 13- and 14-step gaps in a repeating pattern).
  static const fireSteps = 18;

  /// Rapid's volley interval: 8 steps = 0.133 s (was 0.105 s, 6.3 steps).
  static const rapidFireSteps = 8;

  /// A power drops on every this many kills: 5 on route 0 (was 8), 8 after.
  /// Route 0's 1-2 HP creatures gain nothing from the lighter sentinels
  /// and dive shields, so the slower gun made the opening 4-13 % harder for
  /// the Average pilot; powers a little sooner put it back (design §5.1).
  static const routeZeroDropEvery = 5, dropEvery = 8;
  int get killDropEvery => cycle == 0 ? routeZeroDropEvery : dropEvery;

  /// Primary shot speed (u/s): 8 u per model step, a whole number, so the
  /// scene's whole-unit rounding never alternates step lengths (was 390).
  static const shotSpeed = 480.0;

  /// Spread's angled pair (u/s of climb): 7 u per step (was 370), one
  /// unit a step behind the primary, as before (390 / 370).
  static const spreadShotSpeed = 420.0;

  /// Hostile climb speeds snap to this grid (u/s): 0.25 u per 60 Hz step,
  /// so the rounded step length never beats below 15 Hz at 60 or 30 fps.
  static const hostileSpeedGrid = 15.0;

  /// Seconds between volleys now ([fireSteps] or [rapidFireSteps], scaled
  /// by any bonus fire power, in whole steps).
  double get fireInterval =>
      math.max(
        1,
        ((hasPower(Power.rapid) ? rapidFireSteps : fireSteps) *
                _bonusFireScale)
            .round(),
      ) *
      fixedStep;

  /// [vy] on the hostile speed grid.
  static double hostileVy(double vy) =>
      (vy / hostileSpeedGrid).roundToDouble() * hostileSpeedGrid;


  /// Left wing muzzle of each wing module, in logical px from the ship centre
  /// (the right muzzle mirrors it). The scene replaces these with the
  /// `wing_muzzles` packed into ship-weapons.json for the shipped art.
  final Map<Power, ({double x, double y})> wingMuzzles = {
    Power.rapid: (x: -15.5, y: -10.0),
    Power.powerful: (x: -17.0, y: -8.0),
  };

  /// Side the next wing-cannon shot leaves from: -1 left, 1 right.
  int wingSide = -1;

  /// Seconds of recoil left on the [left, right] wing cannon after a shot.
  final List<double> wingRecoil = [0, 0];
  static const wingRecoilDuration = 0.09;

  /// Seconds of muzzle flash left on the nose after a single-shooter shot.
  double noseFlash = 0;

  /// The wing module whose cannons own the primary shot. Any wing powerup
  /// (powerful first, then rapid) fits the wing cannons; they then fire
  /// alternately whatever nose module is active. Spread still adds its angled
  /// pair from the nose, and large still enlarges every primary shot.
  Power? get wingGun {
    if (hasPower(Power.powerful)) return Power.powerful;
    if (hasPower(Power.rapid)) return Power.rapid;
    return null;
  }

  double get speed => (1 + math.min(cycle, 4) * .04) * policy.hostileRate;
  bool get combat => mode == RunMode.playing;
  bool get canPilot =>
      (combat && !shipAway) ||
      mode == RunMode.salvage ||
      (mode == RunMode.transition && wave > 1);
  bool get isBoss => boss != null;
  int get wavesPerLevel =>
      bonusRun.level?.waves.count ?? wavesFor(sector: level, route: cycle);
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

  /// [runSeed] draws the run's bonus plan (a bonus level, a run modifier);
  /// without one the run is the calibrated campaign.
  void start({Difficulty difficulty = Difficulty.normal, int? runSeed}) {
    this.difficulty = difficulty;
    consoleDecay = false; // --- console boss launcher (C2)
    _bonusStartRun(runSeed); // --- bonus levels
    visitedSectors.clear(); // --- transition ascent
    _resetSkill(); // --- demon intelligence
    ranked = true;
    lives = policy.startingLives;
    medals = 0;
    _activeMilliseconds = 0;
    heartSlots.fillRange(0, 3, 0);
    lastCompletedHeartSlot = null;
    heartAssemblyLeft = 0;
    heartPickups.clear();
    wreckBoss = null;
    _bossCollapsing = false;
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
    _resetLifeLoss();
    _flowEnd(); // --- cinematic flow
    ground.resetRun(); // --- ground war
    _beginLevel();
  }

  // --- console start (the /console route) ---

  /// The last wave of [sector] on [route] (zero-based). The carrier's
  /// sector: its loom waves, then the carrier's own wave (boss-grandeur).
  static int wavesFor({required int sector, required int route}) =>
      sector == 5
      ? loomWavesFor(route) + 1
      : 3 + ((sector - 1) ~/ 2) + math.min(route, 3);

  /// First wave of [sector] on [route] where a sentinel can appear, or null
  /// (route 0, or Easy sectors without one). Sentinels need a prior boss
  /// victory: [startAt] grants the medals of every earlier route.
  static int? sentinelWave({
    required Difficulty difficulty,
    required int sector,
    required int route,
  }) {
    if (route < 1 || sector < 1 || sector > 4) return null;
    final last = wavesFor(sector: sector, route: route);
    for (var w = 1; w <= last; w++) {
      final eligible =
          (w == last &&
              sector >= 2 &&
              (difficulty != Difficulty.easy || sector.isEven)) ||
          (difficulty != Difficulty.easy &&
              w >= 3 &&
              (w + sector + route).isEven);
      if (eligible) return w;
    }
    return null;
  }

  /// A fresh run that begins at [sector] 1-5 of [route] 0-4 (optionally at
  /// [wave]; sector 5 defaults to the carrier's own wave, after its loom
  /// waves, so a jump to sector 5 meets the carrier): 0 points, normal scoring. Earlier routes count as won
  /// (medals = route), which satisfies the sentinel prerequisite.
  ///
  /// A [console] run starts with exactly one life and is not [ranked];
  /// otherwise the difficulty's starting lives apply.
  void startAt({
    Difficulty difficulty = Difficulty.normal,
    int sector = 1,
    int route = 0,
    int? wave,
    bool console = false,
    int? runSeed,
    String? bonus,
    String? modifier,
  }) {
    start(difficulty: difficulty, runSeed: runSeed);
    if (console) {
      ranked = false;
      lives = 1;
    }
    cycle = route.clamp(0, 4);
    level = sector.clamp(1, 5);
    medals = cycle;
    score = 0;
    kills = 0;
    events.clear();
    ground.resetRun();
    // --- bonus levels: the console may make this sector a bonus level.
    // [modifier] likewise puts the run under a run modifier.
    final forced = bonus == null ? null : bonusLevelById(bonus);
    final rule = modifier == null ? null : runModifierById(modifier);
    if ((forced != null && level != 5) || rule != null) {
      _bonusForce(level == 5 ? null : forced, modifier: rule);
    }
    _beginLevel();
    final target = (wave ?? (level == 5 ? wavesPerLevel : 1)).clamp(
      1,
      wavesPerLevel,
    );
    if (target > 1) {
      events.clear();
      this.wave = target;
      boss = _bossWave ? _newCarrier() : null; // boss-grandeur: after the loom
      _spawnWave();
      events.add(boss == null ? 'level' : 'boss');
    }
  }

  // --- end console start

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
    if (bonusRun.seed != null) 'runSeed': bonusRun.seed, // --- bonus levels
    // --- bonus challenges: the levels whose 1UP this run won.
    if (bonusRun.oneUps.isNotEmpty) 'bonusOneUps': [...bonusRun.oneUps],
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
    // --- bonus levels: the plan is a pure function of the saved run seed.
    final rawSeed = data['runSeed'];
    final restoredSeed = rawSeed is int ? rawSeed : null;
    final restoredPlan = restoredSeed == null
        ? BonusPlan.none
        : BonusPlan.forRun(restoredSeed, tuning: bonusTuning);
    // boss-grandeur: the carrier's sector has its loom waves before it.
    final maxWave = sector == 5
        ? wavesFor(sector: sector, route: route)
        : restoredPlan.at(route, sector)?.waves.count ??
              wavesFor(sector: sector, route: route);
    // A sector-5 checkpoint without a wave is the carrier (boss-grandeur:
    // after its loom waves), as before the loom existed.
    final restoredWave = integer(
      data['wave'],
      sector == 5 ? maxWave : 1,
      1,
      maxWave.toInt(),
    );
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
    _resetSkill(); // --- demon intelligence: a restored run starts at 0.3
    ranked = true;
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
    _resetLifeLoss();
    loomClock = 0;
    boss = _bossWave ? _newCarrier() : null;
    _bonusStartRun(restoredSeed); // --- bonus levels
    _bonusRestoreOneUps(data['bonusOneUps']); // --- bonus challenges
    _bonusBeginLevel();
    _windBeginLevel(); // --- crosswind
    _groundBeginLevel(); // --- ground war
    _spawnWave(fromCheckpoint: true);
    events.add(boss == null ? 'level' : 'boss');
    return true;
  }

  /// boss-grandeur (operator R8.5), on the styleguide's vocabulary
  /// (`docs/styleguide/alien-capital-ships.md` §6, boss-carrier-wire):
  /// every step of the carrier's decay goes into the game event queue for
  /// the dynamic music engine and comms, in the fixed order shield → armour
  /// → modules → collapse, once per step and per module:
  /// - `bossShieldCellLost` (cell, remaining; and `cellsLeft`) per hex cell;
  /// - `bossShieldFailing` once, at shield ≤ 50 % (S1);
  /// - `bossShieldDown` once, at shield 0 (S2);
  /// - `bossArmourShed` (slot) at the odd armour steps: the plates of the
  ///   module next in the detach order peel off;
  /// - `bossModuleLost` (slot, set, rank, form) per form change (S3);
  /// - `bossCoreExposed` on the last form;
  /// - `bossCollapseStart`, then `bossWreckFalls` (slot, rank, delay) for
  ///   every module left in detach order (the carapace last), at core 0;
  ///   `bossCollapseEnd` when the victory rout ends.
  /// The slots come from the run's assembly (boss_grammar, visual only):
  /// the simulation never reads them.
  void _bossDecayEvents(
    Carrier b, {
    int? cellsBefore,
    int? shieldBefore,
    int? armourBefore,
    int? formBefore,
  }) {
    final a = BossGrammar.forRun(route: cycle, variant: b.variant);
    final data = {'route': cycle, 'variant': b.variant, 'set': a.setName};
    if (cellsBefore != null) {
      final cells = Carrier.shieldCells(b.shield, b.shieldMax);
      for (var c = cellsBefore - 1; c >= cells; c--) {
        _queueGameEvent(GameEventNames.bossShieldCellLost, {
          ...data,
          'cell': c,
          'remaining': c,
          'cellsLeft': c,
          // carrier-v3 §3.2: the field region this cell guarded.
          'region': carrierScript.field.regionOfCell(c).name,
        });
      }
      if (shieldBefore != null &&
          shieldBefore * 2 > b.shieldMax &&
          b.shield * 2 <= b.shieldMax) {
        _queueGameEvent(GameEventNames.bossShieldFailing, data);
      }
      if (b.shield == 0) {
        _queueGameEvent(GameEventNames.bossShieldDown, data);
      }
    }
    final ranks = a.ranks;
    if (armourBefore != null && b.armourStep > armourBefore) {
      for (var s = armourBefore + 1; s <= b.armourStep; s++) {
        if (s >= b.armourSteps) break; // the last step is the collapse
        if (s.isEven) continue; // even steps are form changes (modules)
        // Plates shed from the module that tears away next (form s ~/ 2 + 1).
        final form = s ~/ 2 + 1;
        _queueGameEvent(GameEventNames.bossArmourShed, {
          ...data,
          'plate': s,
          'slot': (a.slotAtForm(form) ?? BossSlot.carapace).name,
        });
      }
    }
    if (formBefore != null && b.phase > formBefore) {
      for (var f = formBefore + 1; f <= b.phase; f++) {
        final slot = a.slotAtForm(f);
        _queueGameEvent(GameEventNames.bossModuleLost, {
          ...data,
          'form': f,
          'detachOrder': f,
          'rank': f <= ranks.length ? ranks[f - 1] : f,
          'slot': slot?.name,
          'set': slot == null ? a.setName : _slotSet(a, slot),
        });
        // carrier-hatches §A4: `bossCoreExposed` is the transformation's
        // end now, not the last form.
      }
    }
    if (b.core <= 0) {
      _queueGameEvent(GameEventNames.bossCollapseStart, data);
      // What is left falls in detach order, the carapace last (the
      // director's collapse timing: 0.25 s apart, the last after 0.9 s).
      final gone = b.phase;
      final left = [
        for (final r in ranks.skip(gone)) a.ofRank(r).first.slot,
        BossSlot.prow,
        BossSlot.carapace,
      ];
      for (final (i, slot) in left.indexed) {
        _queueGameEvent(GameEventNames.bossWreckFalls, {
          ...data,
          'slot': slot.name,
          'rank': i + gone + 1,
          'delay': slot == BossSlot.carapace ? .9 : i * .25,
        });
      }
      _bossCollapsing = true;
    }
  }

  static String _slotSet(BossAssembly a, BossSlot slot) =>
      a.modules.firstWhere((m) => m.slot == slot).set;

  /// A collapse is under way (its end is queued when the rout ends).
  bool _bossCollapsing = false;

  void _bossCollapseEnd() {
    if (!_bossCollapsing) return;
    _bossCollapsing = false;
    final b = wreckBoss;
    _queueGameEvent(GameEventNames.bossCollapseEnd, {
      'route': cycle,
      if (b != null) 'variant': b.variant,
    });
  }

  /// The run's visual set pick for the current route (boss_grammar): from
  /// the run seed, so a run's carriers are deterministic; an unseeded run
  /// (tests, the calibrated campaign) always draws the first combination.
  int get bossVariant => BossGrammar.variantFor(runSeed, cycle);

  Carrier _newCarrier() {
    _resetHints(); // --- carrier-hatches
    return _buildCarrier();
  }

  void _resetHints() {
    leadHinted = false;
    _hintAt.clear();
    _armourMisses.clear();
    _closedDoorHits.clear();
    _trailing.clear();
    _hintHatchesAt = null;
  }

  Carrier _buildCarrier() => Carrier(
    cycle,
    difficulty: difficulty,
    startingDirection: random.nextBool() ? 1 : -1,
    startingPhase: random.nextDouble() * math.pi * 2,
  )
    ..glidePhase = bossRandom.nextDouble() * math.pi * 2
    // The boss stream keeps its draw (the glide of later carriers must not
    // move), but the module set comes from the run seed.
    ..variant = (bossRandom.nextInt(1 << 16), bossVariant).$2;

  /// boss-grandeur: the last loom wave is cleared (or the loom's cap ran
  /// out): the carrier's wave starts and it rises from under the fog. What
  /// is left of the loom wave falls where it is (the R1 rule: nothing stays
  /// in the fog), and nothing waits in the reserve.
  void _beginRise() {
    for (final d in demons) {
      if (d.swarmState != SwarmState.reserve &&
          !(d.entering && d.entranceProgress <= 0)) {
        d.hp = 0;
        blasts.add(Blast(d.x, d.y));
      }
    }
    demons.clear();
    incoming.clear();
    _pendingSkeins.clear();
    _reserveGroups.clear();
    stream.drain();
    wave = wavesPerLevel;
    loomClock = 0;
    levelClock = 0; // the carrier's wave is timed from its own start
    // carrier-v3: the Close starts from where the approach is.
    closeFromD = approachD > 1 ? approachD : carrierScript.approach.closeFrom;
    approachD = closeFromD;
    launches?.closeAll();
    _fightGate = null;
    boss = _newCarrier()..emerge = 0;
    _spawnWave(continuous: true);
    events.add('boss');
    _queueGameEvent(GameEventNames.bossRise, {'route': cycle});
  }

  void _beginLevel() {
    visitedSectors.add(level); // --- transition ascent
    wave = 1;
    pilot.reset(shipX); // --- demon intelligence
    _adaptedThisSector = false;
    clearedLevel = null;
    wreckBoss = null;
    loomClock = 0;
    _resetApproach(); // --- carrier-v3
    boss = _bossWave ? _newCarrier() : null;
    _bonusBeginLevel(); // --- bonus levels
    _windBeginLevel(); // --- crosswind
    levelClock = 0;
    pickups.clear();
    heartPickups.clear();
    blasts.clear();
    supplyCrates.clear();
    fallingParts.clear();
    crateSpawnTimer = 0.0;
    _groundBeginLevel(); // --- ground war
    _spawnWave();
    events.add(boss == null ? 'level' : 'boss');
  }

  /// Starts wave [wave]. [continuous]: the next wave of a sector whose
  /// stragglers fell before any of it was sighted; it streams in from the
  /// fog while combat goes on (no transition phase, continuous-swarm).
  void _spawnWave({bool fromCheckpoint = false, bool continuous = false}) {
    _spawnedFromCheckpoint = fromCheckpoint;
    demons.clear();
    if (continuous) {
      _fizzleHostileShots();
    } else {
      shots.clear();
      _fire = 0;
      wingSide = -1;
      wingRecoil[0] = wingRecoil[1] = 0;
      noseFlash = 0;
    }
    incoming.clear(); // --- continuous swarm
    _pendingSkeins.clear();
    _squads.clear();
    _squadMembers.clear();
    _resetWaveEnemies();
    _groundBeginWave(); // --- ground war
    flock.clear(); // --- atmosphere-and-swarms
    stream.startCohort();
    if (boss == null) {
      final (roster, count) = _buildRoster(
        wave,
        fromCheckpoint: fromCheckpoint,
      );
      _waveRoster = count;
      demons.addAll(roster);
      _releaseRoster(roster, wave, streamed: continuous);
      _bornGroupsIntoReserve();
    } else {
      _reserveGroups.clear();
    }
    if (boss == null) _updateDemons(0);
    if (!continuous) {
      _enterPhase(
        RunMode.transition,
        wave > 1 ? 1.4 + storyReadingTime : arrivalHintDuration,
      );
    }
    events.add('checkpoint');
  }

  /// Enemy-side per-wave state: fire and dive clocks, the finite
  /// reinforcement plan, the wave-wide birth budget and the escort.
  void _resetWaveEnemies() {
    _enemyFire = 1.7;
    _dive = 3;
    _flock = 2;
    flocksSpawned = 0;
    flocksPlanned = boss == null
        ? _bonusReinforcements(
            policy.reinforcementFlocks(route: cycle, sector: level),
          )
        : 0;
    if (_easySecondLaunch(wave)) {
      flocksPlanned = (flocksPlanned * CarrierScript.easySecondWave).floor();
    }
    _reinforcementLeft = 4.5;
    _reinforcementCooldown = .6;
    _reinforcementCasualties = 0;
    _ordinaryBirthOrdinal = 0;
    _eliteBirths = 0;
    _waveRoster = 0;
    _escortLeft = 2.6;
    escortSpawned = false;
  }

  /// The opening roster of wave [forWave] and its size. Births count
  /// against the wave-wide ordinal and elite budget, so call it with those
  /// counters belonging to [forWave].
  /// carrier-v3 tune: [forWave] is Easy's second launch wave (shorter
  /// roster and fewer reinforcement flocks, [CarrierScript.easySecondWave]).
  bool _easySecondLaunch(int forWave) =>
      level == 5 &&
      forWave == 2 &&
      forWave <= loomWaves &&
      difficulty == Difficulty.easy;

  (List<Demon>, int) _buildRoster(int forWave, {bool fromCheckpoint = false}) {
    final roster = <Demon>[];
    var count = _bonusRoster(
      policy.rosterCount(sector: level, wave: forWave, route: cycle),
    );
    // carrier-v3 tune: Easy's second launch wave is shorter (the boss
    // level's clear-time gate; plan/calibration-current.md).
    if (_easySecondLaunch(forWave)) {
      count = math.max(4, (count * CarrierScript.easySecondWave).round());
    }
    final rows = (count / 6).ceil();
    final spacing = rows <= 4 ? 48.0 : 160.0 / (rows - 1);
    final special = sentinelFor(forWave);
    final specialEligible = special != null;
    for (var i = 0; i < count; i++) {
      final archetype = specialEligible && i == count - 1
          ? special
          : EnemyArchetype.ordinary;
      final large = archetype != EnemyArchetype.ordinary;
      final profile = large ? null : _ordinaryProfile(forWave);
      final kind = profile?.$1 ?? (i + forWave + level) % 4;
      final elite = profile?.$3 ?? false;
      final hp =
          profile?.$2 ??
          policy.sentinelHull(
            route: cycle,
            armored: archetype == EnemyArchetype.armoredSentinel,
          ); // --- fire-rate-tune
      final demon = _spearUp(Demon( // --- spear-bearers
        large ? width / 2 : 38 + (i % 6) * 56.0,
        large
            ? 44
            : (specialEligible
                  ? 124 + (i ~/ 6) * 32.0
                  : 70 + (i ~/ 6) * spacing),
        kind,
        hp.toInt(),
        i * 1.7 + forWave * .6,
        elite: elite,
        archetype: archetype,
        shieldMax: large ? 3 + cycle : 0,
        armorMax: large
            ? (archetype == EnemyArchetype.armoredSentinel ? 4 : 2) + cycle ~/ 2
            : 0,
        // One draw, as before (the random sequence is unchanged): the
        // rush chance is decided against it when the rush would trigger.
        rushRoll: large ? random.nextDouble() : 1,
      ));
      if (large) {
        demon.entranceProgress = 0;
        demon.waitingForEscort = true;
        demon.y = -48;
        // Foreshadowed: it flies in out of the fog, from its silhouette.
        demon.arrivesFromDistance = true;
      } else if (forWave == 1) {
        // The arrival hint owns the whole introduction. The initial swarm
        // glides down during the second half of the opening transition and
        // settles into formation as combat begins.
        demon.entranceProgress = 0;
        demon.entranceDelay = (i % 6) * .045 + (i ~/ 6) * .08;
        demon.entranceDuration = fromCheckpoint ? 1.0 : 1.25;
        demon.entranceStartY = -48 - (i ~/ 6) * 20.0;
        demon.arrivesFromDistance = true;
        demon.y = demon.entranceStartY;
      } else if (!fromCheckpoint) {
        demon.entranceProgress = 0;
        demon.entranceDelay = (i % 6) * .035 + (i ~/ 6) * .06;
        demon.entranceDuration = .85;
        demon.entranceStartY = -40 - (i ~/ 6) * 16.0;
        demon.arrivesFromDistance = true;
        demon.y = demon.entranceStartY;
      }
      roster.add(demon);
    }
    return (roster, count);
  }

  // --- continuous swarm ----------------------------------------------------
  // (openspec/changes/continuous-swarm design §1-§2; generalises the old
  // wave pressure.) A wave stays the accounting unit: its roster, finite
  // groups, escort and elite budget are exactly as calibrated
  // (plan/difficulty-calibration.md). It reaches the screen as a stream of
  // skeins out of the fog, and when it is down to its last few (all
  // reinforcements in, no sentinel), the next wave's first skeins rise out
  // of the fog while the stragglers still fight. There is no transition
  // phase between the waves of a sector: an early finish holds the next
  // wave at the fog front for a short lull (the release beat), a lingering
  // player meets it in the fight. Timing accelerates with a fast clear
  // (q, capped per difficulty, relaxed after a lost life), content never.

  /// The skein scheduler (own PRNG: never draws from [random]).
  final SwarmStream stream;

  /// The next wave (cohort c + 1) while it approaches: a read-only view
  /// for the scene. Its first skeins fly a slow hold path toward the fog
  /// front; the rest wait in reserve until it merges.
  final List<Demon> incoming = [];

  /// Seconds (hostile rate) before [incoming] joins the fight, and the full
  /// approach length A = incomingSeconds · q.
  double incomingLeft = 0, incomingTotal = 0;
  int _incomingRoster = 0, _incomingOrdinal = 0, _incomingElites = 0;

  /// How far (entrance progress) an approaching wave creeps while it holds.
  static const incomingHold = .6;

  /// Approach order of the incoming cohort's approaching skeins (skein id
  /// to index) and their count: their approaches start staggered over the
  /// first half of the clock, so the cohort rises out of the fog skein by
  /// skein instead of as one block.
  final Map<int, int> _incomingOrder = {};
  int _incomingApproach = 1;

  /// How far [d] of the incoming cohort has crept toward the fog front.
  double _holdOf(Demon d) {
    final i = _incomingOrder[d.skein] ?? 0;
    final start = .5 * i / math.max(1, _incomingApproach);
    final local = ((incomingProgress - start) / (1 - start)).clamp(0.0, 1.0);
    return incomingHold * _smootherstep(local);
  }

  /// Screen position and nearness of [d]'s reserve point with its drift.
  (double, double, double) _reservePoint(Demon d) {
    final drift = d.drift;
    final z = d.reserveZ + (drift?.z ?? 0);
    final n = SwarmFlock.nearOf(z).clamp(.08, .22);
    final x = d.reserveX + (drift?.x ?? 0);
    return (
      (180 + x * n).clamp(24.0, width - 24.0),
      Perspective.horizonY - d.reserveLift * (n / .2),
      n,
    );
  }

  /// Entrance length when the approaching wave finally closes in.
  static const incomingCloseIn = 1.1;

  /// A released skein's swoop out of the fog (s, hostile clock).
  static const swoopSeconds = 1.6;

  /// A diver's swoop back from a deep gate (s at hostile rate 1).
  static const reentrySeconds = 1.1;

  /// At most this many reserve members are drawn (further skeins show
  /// their leaders only; design §2.1).
  static const reserveDrawn = 18;

  /// 0 when the next wave appears, 1 when it arrives.
  double get incomingProgress => incomingTotal <= 0
      ? 0
      : (1 - incomingLeft / incomingTotal).clamp(0.0, 1.0);

  /// Reinforcement groups of the current wave, born at its start and
  /// waiting as veiled shapes in the deep fog until admitted (in order).
  final List<List<Demon>> _reserveGroups = [];

  /// Roster skeins of the current wave not yet released: in [demons]
  /// (counted as today's whole roster is), parked in the reserve.
  final List<List<Demon>> _pendingSkeins = [];
  int _skeinIds = 0;

  /// Total ordinary HP of the current wave (roster + groups), for q.
  int _cohortHp = 0;
  int _streamLives = -1;

  /// Everything waiting in the deep fog: untargetable, silent, no gear.
  Iterable<Demon> get swarmReserve sync* {
    for (final g in _reserveGroups) {
      yield* g;
    }
    for (final s in _pendingSkeins) {
      yield* s;
    }
    for (final d in incoming) {
      if (d.swarmState == SwarmState.reserve) yield d;
    }
  }

  /// The sector's final wave (or its carrier) is under way: no cohort will
  /// be sighted after it, so the fog stages nothing (playtest-fixes). What
  /// this wave still holds back (its later roster skeins, its reinforcement
  /// groups) waits unseen and leaves the fog only when it is admitted.
  bool get finalWave =>
      boss != null ||
      // boss-grandeur: nothing comes out of the fog after the last loom wave.
      (level == 5 && wave >= wavesPerLevel - 1) ||
      wave >= wavesPerLevel;

  /// What the fog shows waiting: the drawn reserve plus the incoming
  /// cohort's approaching skeins (both empty during [finalWave]).
  Iterable<Demon> get fogStaged sync* {
    yield* drawnReserve;
    for (final d in incoming) {
      if (d.swarmState != SwarmState.reserve) yield d;
    }
  }

  /// The reserve members the scene draws: whole skeins up to
  /// [reserveDrawn] members, then one leader per further skein. None during
  /// the [finalWave]: nothing more comes out of the fog after it. None while
  /// a transition plays either (playtest R1): the Descent shows the new
  /// sector's first cohort coming out of the cloud and nothing waiting
  /// behind it; the reserve is sighted once the fight is on.
  List<Demon> get drawnReserve {
    if (finalWave || flow.active) return const [];
    // carrier-v3: the approach's reserve waits inside the carrier.
    if (looming) return const [];
    final out = <Demon>[];
    final seen = <int>{};
    for (final d in swarmReserve) {
      if (out.length < reserveDrawn || seen.add(d.skein)) {
        seen.add(d.skein);
        out.add(d);
      }
    }
    return out;
  }

  bool get _pressureEligible =>
      combat &&
      boss == null &&
      wave < wavesPerLevel &&
      !(level == 5 && wave >= wavesPerLevel - 1) && // boss-grandeur: Rise
      incoming.isEmpty &&
      flocksRemaining == 0 &&
      lifeLossPhase == LifeLossPhase.none &&
      // One sentinel at a time: the next wave (which may bring its own)
      // waits until this wave's sentinel has fallen.
      !demons.any((d) => d.isLarge);

  /// Splits the ordinary members of [roster] into skeins (column bands of
  /// 3-6) with seeded gates on alternating sides.
  List<List<Demon>> _skeinsOf(List<Demon> roster, int forWave, {int salt = 0}) {
    final members = [
      for (final d in roster)
        if (!d.isLarge) d,
    ];
    final split = SwarmStream.splitRoster([for (final d in members) d.homeX]);
    final rng = stream.rngFor(
      sector: level,
      route: cycle,
      wave: forWave,
      salt: salt,
    );
    final gates = SwarmStream.gates(split.length, rng);
    final out = <List<Demon>>[];
    for (var s = 0; s < split.length; s++) {
      final id = _skeinIds++;
      final skein = [for (final i in split[s]) members[i]];
      for (final d in skein) {
        d
          ..skein = id
          ..gate = gates[s];
      }
      _placeReserve(skein, gates[s], s, rng);
      out.add(skein);
    }
    return out;
  }

  /// Gives [skein] its reserve point in the deep fog (under the far banks,
  /// n 0.10-0.20, on its gate's side) and each member a Lévy drift.
  void _placeReserve(
    List<Demon> skein,
    SwarmGate gate,
    int index,
    math.Random rng,
  ) {
    final n = .1 + .1 * rng.nextDouble();
    final cx =
        gate.side * (40 + 70 * rng.nextDouble()) + 30 * (rng.nextDouble() - .5);
    final cz = SwarmFlock.worldZ(n);
    final lift = 6 + 26 * rng.nextDouble();
    for (var i = 0; i < skein.length; i++) {
      final d = skein[i];
      d
        ..reserveX = cx / n * .5 + (i - skein.length / 2) * 34
        ..reserveZ = cz + (i.isEven ? -1 : 1) * 40.0 * (i ~/ 2)
        ..reserveLift = lift + (i % 3) * 5
        ..drift = LevyDrift(math.Random(rng.nextInt(1 << 30)));
    }
  }

  /// Draws the reserve where it waits (presentation for the fog: nearness,
  /// a little altitude, position); stepped at the model rate.
  void _updateReserve(double dt) {
    for (final d in swarmReserve) {
      d.drift?.update(dt);
      final (x, y, n) = _reservePoint(d);
      d
        ..nearness = n
        ..x = x
        ..y = y
        ..altitude = 0
        ..scale = Perspective.scaleOf(n, angry: d.angry);
    }
  }

  /// The roster of a fresh wave: wave 1, a checkpoint or a sector start
  /// keeps its entrance (every skein released, its own stagger); a
  /// [streamed] wave releases its first skein now, the rest by the gap.
  void _releaseRoster(
    List<Demon> roster,
    int forWave, {
    required bool streamed,
  }) {
    final skeins = _skeinsOf(roster, forWave);
    for (var s = 0; s < skeins.length; s++) {
      final skein = skeins[s];
      if (!streamed) {
        for (final d in skein) {
          d.swarmState = d.entering
              ? SwarmState.approaching
              : SwarmState.present;
        }
        _formSquad(skein);
        _launchFlock(skein, forWave, gate: skein.first.gate);
      } else if (s == 0) {
        _releaseSkein(skein, forWave);
      } else {
        _park(skein);
        _pendingSkeins.add(skein);
      }
    }
    stream.releaseLeft = policy.skeinGap;
  }

  void _park(List<Demon> skein) {
    for (final d in skein) {
      d
        ..swarmState = SwarmState.reserve
        ..entranceProgress = 0
        ..entranceElapsed = 0
        ..entranceHold = 0
        ..arrivesFromDistance = true;
    }
  }

  /// A skein leaves the reserve and swoops into the fight from where it
  /// waited; untargetable until it lands.
  void _releaseSkein(
    List<Demon> skein,
    int forWave, {
    double duration = swoopSeconds,
  }) {
    _updateReserve(0);
    for (var i = 0; i < skein.length; i++) {
      final d = skein[i];
      final n = d.nearness > 0 ? d.nearness : (d.gate?.nearness ?? .2);
      d
        ..swarmState = SwarmState.approaching
        ..arrivesFromDistance = true
        ..entranceProgress = 0
        ..entranceElapsed = 0
        ..entranceHold = 0
        ..entranceDelay = i * .07
        ..entranceDuration = duration
        ..entryX = d.x
        ..entryY = d.y
        ..entryN = n
        ..drift = null;
    }
    _formSquad(skein);
    _launchFlock(skein, forWave, gate: skein.first.gate);
  }

  /// Reinforcement groups of the current wave are born into the reserve at
  /// its start, in admission order, so they are visible in the fog. Their
  /// births use the wave's ordinal and elite budget (after the roster).
  void _bornGroupsIntoReserve() {
    _reserveGroups.clear();
    var hp = 0;
    for (final d in demons) {
      if (!d.isLarge) hp += d.maxHp;
    }
    if (boss == null) {
      final rng = stream.rngFor(
        sector: level,
        route: cycle,
        wave: wave,
        salt: 101,
      );
      for (var f = 0; f < flocksPlanned; f++) {
        final count = policy.reinforcementSize(route: cycle, flock: f);
        final group = <Demon>[];
        for (var i = 0; i < count; i++) {
          final profile = _ordinaryProfile();
          group.add(
            _spearUp(
              Demon(
                width / 2,
                Perspective.horizonY,
                profile.$1,
                profile.$2,
                rng.nextDouble() * 8,
                elite: profile.$3,
              ),
            ), // --- spear-bearers
          );
          hp += profile.$2;
        }
        // One or two skeins per group, each with its own reserve point.
        final parts = SwarmStream.splitGroup(count);
        final gates = SwarmStream.gates(parts.length, rng);
        for (var p = 0; p < parts.length; p++) {
          final skein = [for (final i in parts[p]) group[i]];
          final id = _skeinIds++;
          for (final d in skein) {
            d
              ..skein = id
              ..gate = gates[p];
          }
          _park(skein);
          _placeReserve(skein, gates[p], f * 2 + p, rng);
        }
        _reserveGroups.add(group);
      }
    }
    _cohortHp = hp;
    _updateReserve(0);
  }

  /// Leftover hostile shots dissolve at a merge (0.25 s), never cleared
  /// silently; pickups keep falling.
  void _fizzleHostileShots() {
    final hostile = [
      for (final s in shots)
        if (s.hostile && s.fizzleIn == null) s,
    ];
    for (var i = 0; i < hostile.length; i++) {
      hostile[i].fizzleIn = .25 * (i + 1) / hostile.length;
    }
    if (hostile.isNotEmpty) {
      events.add('shotsFizzle');
      _queueGameEvent(GameEventNames.shotsFizzle, {'count': hostile.length});
    }
  }

  void _updateFizzles(double dt) {
    if (lifeLossPhase != LifeLossPhase.none) return; // its own drain
    for (final s in shots) {
      final f = s.fizzleIn;
      if (!s.hostile || f == null) continue;
      s.fizzleIn = f - dt;
      if (s.fizzleIn! <= 0) {
        shotFizzles.add(
          ShotFizzle(s.x, s.y, sentinel: s.kind == ShotKind.sentinel),
        );
        s.y = height + 40;
      }
    }
  }

  /// The stream inside a wave: releases roster skeins by the gap, keeps the
  /// rubber band's clock and the reserve drifting.
  void _updateStream(double dt) {
    stream.cohortClock += dt;
    _updateSquads(dt);
    if (_streamLives >= 0 && lives < _streamLives) stream.lifeLost();
    _streamLives = lives;
    _updateFizzles(dt);
    if (_pendingSkeins.isNotEmpty &&
        !stream.drained &&
        lifeLossPhase == LifeLossPhase.none) {
      stream.releaseLeft -= dt * policy.hostileRate;
      var live = 0;
      var flying = false;
      for (final d in demons) {
        if (d.isLarge) continue;
        if (!d.entering) {
          live++;
        } else if (d.swarmState == SwarmState.approaching) {
          flying = true;
        }
      }
      if (stream.releaseLeft <= 0 || (live == 0 && !flying)) {
        _releaseSkein(_pendingSkeins.removeAt(0), wave);
        stream.releaseLeft = SwarmStream.skeinGap(
          policy.skeinGap,
          live: live,
          roster: _waveRoster,
        );
      }
    }
    _updateReserve(dt);
  }

  /// Publishes each creature's swarm state from the simulation (the fog and
  /// the shadows read it; W4 and W5b build on it).
  void _publishSwarmStates() {
    for (final d in demons) {
      if (d.isLarge) {
        d.swarmState = d.waitingForEscort
            ? SwarmState.reserve
            : d.entering
            ? SwarmState.approaching
            : (d.dive > 0 || d.rushing)
            ? SwarmState.diving
            : SwarmState.present;
        continue;
      }
      if (d.swarmState == SwarmState.reserve) continue;
      if (d.entering) {
        if (d.swarmState != SwarmState.reentering) {
          d.swarmState = SwarmState.approaching;
        }
      } else if (d.dive > 0 || d.rushing) {
        d
          ..swarmState = SwarmState.diving
          ..altitude = _altitudeOf(d);
      } else {
        d.altitude = _altitudeOf(d);
        if (d.swarmState != SwarmState.present) {
          d
            ..entryX = null
            ..entryY = null
            ..entryN = null;
        }
        d.swarmState = SwarmState.present;
      }
    }
  }

  /// Occupancy guard (design §2.3): flying and present ordinary members
  /// never exceed the wave's roster plus its largest group (or escort).
  int get swarmOccupancy =>
      demons
          .where((d) => !d.isLarge && d.swarmState != SwarmState.reserve)
          .length +
      incoming
          .where((d) => !d.isLarge && d.swarmState == SwarmState.approaching)
          .length;

  int get swarmOccupancyBound {
    if (boss != null) return maxActiveDemons; // the carrier's own minion cap
    final group = policy.reinforcementSize(
      route: cycle,
      flock: math.max(0, flocksPlanned - 1),
    );
    final escort = demons.any((d) => d.isEscort || d.isLarge)
        ? plannedEscortSize
        : 0;
    return math.max(_waveRoster, _incomingRoster) + math.max(group, escort);
  }

  void _updateIncoming(double dt) {
    if (incoming.isEmpty) {
      if (!_pressureEligible) return;
      final live = demons.length;
      if (live == 0 || live > policy.pressureThreshold) return;
      _prepareIncoming();
      return;
    }
    // A lost life pauses the clock: pressure, never an ambush on respawn.
    if (lifeLossPhase == LifeLossPhase.none && combat) {
      incomingLeft -= dt * policy.hostileRate;
    }
    for (final d in incoming) {
      if (d.isLarge || d.swarmState == SwarmState.reserve) continue;
      if (d.gateWait > 0) {
        d.gateWait = math.max(0, d.gateWait - dt); // carrier-v3: in its gate
        d.entranceProgress = 0;
        continue;
      }
      final p = _holdOf(d);
      final (tx, ty) = _targetFormationPosition(d);
      d.entranceProgress = p;
      _placeEntering(d, _smootherstep(p), tx, ty, 0, holding: true);
    }
    if (incomingLeft <= 0) _mergeCohort(forced: true);
  }

  /// The next cohort is sighted: its roster is born (with exactly its own
  /// ordinal and elite budget), its first half of skeins start a slow
  /// approach, the rest wait in reserve; the approach takes A = T · q.
  void _prepareIncoming() {
    final ordinal = _ordinaryBirthOrdinal, elites = _eliteBirths;
    _ordinaryBirthOrdinal = 0;
    _eliteBirths = 0;
    final (roster, count) = _buildRoster(wave + 1);
    _incomingRoster = count;
    _incomingOrdinal = _ordinaryBirthOrdinal;
    _incomingElites = _eliteBirths;
    _ordinaryBirthOrdinal = ordinal;
    _eliteBirths = elites;
    final skeins = _skeinsOf(roster, wave + 1);
    // carrier-v3 tune: Easy's second launch wave leaves in one go (fewer
    // volleys): every skein sets out from the gates now, none waits.
    final approach = _easySecondLaunch(wave + 1)
        ? skeins.length
        : (skeins.length / 2).ceil();
    _incomingOrder.clear();
    _incomingApproach = approach;
    for (var s = 0; s < skeins.length; s++) {
      if (s < approach) {
        _incomingOrder[skeins[s].first.skein] = s;
        for (final d in skeins[s]) {
          final (x, y, n) = _reservePoint(d);
          d
            ..entryX = x
            ..entryY = y
            ..entryN = n
            ..swarmState = SwarmState.approaching
            ..entranceProgress = 0
            ..entranceElapsed = 0
            ..arrivesFromDistance = true;
        }
        _formSquad(skeins[s]);
        _launchFlock(skeins[s], wave + 1, gate: skeins[s].first.gate);
      } else {
        _park(skeins[s]);
      }
    }
    incoming.addAll(roster);
    skill.cohortCleared(
      expected: SwarmStream.expectedClear(_cohortHp),
      actual: stream.cohortClock,
    ); // --- demon intelligence
    final q = stream.paceNext(cohortHp: _cohortHp, floor: policy.paceFloor);
    incomingTotal = incomingLeft = policy.incomingSeconds * q;
    events.add('incoming');
    _queueGameEvent(GameEventNames.cohortSighted, {
      'wave': wave + 1,
      'eta': incomingTotal / policy.hostileRate,
      'q': q,
      'skeins': skeins.length,
    });
  }

  /// The approaching cohort becomes the current wave. [forced]: it reached
  /// the fight before the stragglers fell, so it simply closes in beside
  /// them. Otherwise it holds a lull at the fog front, then closes in:
  /// no transition phase; leftover hostile shots dissolve.
  void _mergeCohort({required bool forced}) {
    final lull = forced ? 0.0 : SwarmStream.lull(stream.q);
    wave++;
    _resetWaveEnemies();
    _waveRoster = _incomingRoster;
    _ordinaryBirthOrdinal = _incomingOrdinal;
    _eliteBirths = _incomingElites;
    stream.startCohort();
    final pending = <int, List<Demon>>{};
    for (final d in incoming) {
      demons.add(d);
      if (d.isLarge) continue;
      if (d.swarmState == SwarmState.reserve) {
        (pending[d.skein] ??= []).add(d);
        continue;
      }
      // Resume the approach from where it held, over the close-in.
      final p = _holdOf(d);
      // The rest of the approach takes the close-in (from the fog front).
      d.entranceDuration = incomingCloseIn / math.max(.3, 1 - p);
      d.entranceElapsed = d.entranceDelay + p * d.entranceDuration;
      d.entranceProgress = p;
      d.entranceHold = lull;
    }
    _pendingSkeins
      ..clear()
      ..addAll(pending.values);
    stream.releaseLeft = lull + policy.skeinGap;
    incoming.clear();
    incomingLeft = incomingTotal = 0;
    if (!forced) {
      _fizzleHostileShots();
      _groundBeginWave(); // --- ground war
    }
    _bornGroupsIntoReserve();
    events.add('wave');
    events.add('checkpoint');
    _queueGameEvent(GameEventNames.cohortMerged, {
      'wave': wave,
      'forced': forced,
      'lull': lull,
    });
  }

  /// A diver that left the bottom of the arena rejoins the swarm out of the
  /// fog (design §6.2): from the deep gate on its side, a short swoop back
  /// to its squad; untargetable and silent until it lands.
  void _beginReentry(Demon d) {
    final gate = d.x < width / 2 ? SwarmGate.deepLeft : SwarmGate.deepRight;
    final y = Perspective.horizonY - 6;
    d
      ..swarmState = SwarmState.reentering
      ..gate = gate
      ..arrivesFromDistance = true
      ..entryX = gate.screenX
      ..entryY = y
      ..entryN = gate.nearness
      ..entranceProgress = 0
      ..entranceDuration = reentrySeconds / policy.hostileRate
      ..entranceDelay = 0
      ..entranceElapsed = 0
      ..entranceHold = 0
      ..x = gate.screenX
      ..y = y
      ..nearness = gate.nearness;
    _launchFlock([d], wave, gate: gate);
  }
  // --- fighting patterns (swarm_patterns.dart, design §4) ------------------

  /// Squads fly collective swarm states while they fight. False keeps the
  /// legacy hover for every creature (a debug and fixture flag).
  bool swarmPatterns = true;
  final Map<int, Squad> _squads = {};
  final Map<int, List<Demon>> _squadMembers = {};

  /// Present ordinary members this frame (separation) and each squad's
  /// mean velocity (alignment).
  final List<Demon> _present = [];
  final Map<int, (double, double)> _squadVelocity = {};

  /// Onboarding keeps the old hover: Easy, route 0, sector 1, waves 1-2.
  bool get _onboarding =>
      difficulty == Difficulty.easy && cycle == 0 && level == 1 && wave <= 2;

  Squad? squadOf(Demon d) => _squads[d.skein];
  Iterable<Squad> get squads => _squads.values;

  /// Whether [d] flies a squad pattern (else the legacy hover).
  bool patterned(Demon d) {
    if (!swarmPatterns || d.isLarge) return false;
    final s = _squads[d.skein];
    return s != null && s.patterned;
  }

  /// The squad's lateral velocity (u/s) for [d], for the creature motion's
  /// squad heading rule (design §7); 0 without a pattern.
  double squadVx(Demon d) {
    if (!patterned(d)) return 0;
    return _squadVelocity[d.skein]?.$1 ?? 0;
  }

  /// A skein becomes a squad as it is released: station = the mean of its
  /// members' home slots; a seeded first state (cloud for an escort, hover
  /// during onboarding).
  void _formSquad(List<Demon> skein) {
    if (skein.isEmpty) return;
    final id = skein.first.skein;
    if (id < 0 || _squads.containsKey(id)) return;
    var sx = 0.0, sy = 0.0;
    for (final d in skein) {
      sx += d.homeX;
      sy += d.homeY;
    }
    final rng = stream.rngFor(
      sector: level,
      route: cycle,
      wave: wave,
      salt: 5000 + id,
    );
    final first = SquadState.values[rng.nextInt(3)];
    final sq = Squad(
      id,
      rng,
      stationX: sx / skein.length,
      stationY: sy / skein.length,
      state: _onboarding
          ? SquadState.hover
          : skein.first.isEscort
          ? SquadState.cloud
          : first,
    );
    for (var i = 0; i < skein.length; i++) {
      sq.add(skein[i], i);
    }
    _squads[id] = sq;
    _squadMembers[id] = List.of(skein);
  }

  void _updateSquads(double dt) {
    final alive = {...demons, ...incoming};
    final tempo = policy.swarmTempo(route: cycle);
    _present
      ..clear()
      ..addAll(
        demons.where(
          (d) => !d.isLarge && !d.entering && d.dive == 0 && !d.rushing,
        ),
      );
    _squadVelocity.clear();
    final gone = <int>[];
    _squads.forEach((id, sq) {
      final members = _squadMembers[id]!
        ..removeWhere((d) => !alive.contains(d));
      if (members.isEmpty) {
        gone.add(id);
        return;
      }
      sq.slots.removeWhere((m, _) => !alive.contains(m));
      sq.update(
        dt,
        tempo: tempo,
        flying: members.where(
          (d) =>
              d.dive == 0 && !d.rushing && d.swarmState != SwarmState.reserve,
        ),
      );
      var vx = 0.0, vy = 0.0, k = 0;
      for (final d in members) {
        if (d.entering || d.dive > 0) continue;
        vx += d.vx;
        vy += d.vy;
        k++;
      }
      _squadVelocity[id] = k == 0 ? (sq.anchorVx, 0.0) : (vx / k, vy / k);
    });
    for (final id in gone) {
      _squads.remove(id);
      _squadMembers.remove(id);
    }
  }

  (double, double)? _patternTarget(Demon d) {
    if (!patterned(d)) return null;
    final sq = _squads[d.skein]!;
    Demon? sentinel;
    if (sq.state == SquadState.cloud || sq.previous == SquadState.cloud) {
      sentinel = demons.where((o) => o.isLarge && !o.entering).firstOrNull;
    }
    final t = sq.target(
      d,
      centreX: sentinel?.x,
      centreY: sentinel == null ? null : sentinel.y + 34,
    );
    final slot = sq.slots[d];
    if (t == null || slot == null) return null;
    // A tell holds its place so it reads cleanly.
    if (d.divePrep > 0 || d.telegraph > 0) return slot.held ??= t;
    slot.held = null;
    return t;
  }

  /// Critically damped spring to the pattern target (omega 6 / s), k = 7
  /// separation against every present ordinary member (radius 30),
  /// alignment within the squad (0.6), speed cap 140 · tempo.
  void _steerToPattern(Demon d, double tx, double ty, double dt) {
    const w = 6.0, sepR = 34.0, sepK = 1500.0;
    var ax = w * w * (tx - d.x) - 2 * w * d.vx;
    var ay = w * w * (ty - d.y) - 2 * w * d.vy;
    final near = <(double, double, double)>[];
    for (final o in _present) {
      if (identical(o, d)) continue;
      final dx = d.x - o.x, dy = d.y - o.y;
      final d2 = dx * dx + dy * dy;
      if (d2 >= sepR * sepR || d2 < 1e-6) continue;
      near.add((d2, dx, dy));
    }
    if (near.length > 7) {
      near.sort((a, b) => a.$1.compareTo(b.$1));
      near.removeRange(7, near.length);
    }
    for (final (d2, dx, dy) in near) {
      final dist = math.sqrt(d2);
      final push = (sepR - dist) / sepR * sepK;
      ax += dx / dist * push;
      ay += dy / dist * push * .6;
    }
    final mean = _squadVelocity[d.skein];
    if (mean != null) {
      ax += .6 * w * (mean.$1 - d.vx);
      ay += .6 * w * (mean.$2 - d.vy);
    }
    var vx = d.vx + ax * dt, vy = d.vy + ay * dt;
    final cap = 140 * policy.swarmTempo(route: cycle);
    final sp = math.sqrt(vx * vx + vy * vy);
    if (sp > cap) {
      vx *= cap / sp;
      vy *= cap / sp;
    }
    d.x = (d.x + vx * dt).clamp(18.0, width - 18.0);
    d.y += vy * dt;
  }

  /// The published altitude of a fighting or diving creature (shadows).
  double _altitudeOf(Demon d) {
    final fight = SwarmFlock.fightAltitude(d.homeY);
    if (d.dive > 0 || d.rushing) {
      final span = math.max(40.0, shipY - d.homeY);
      return fight * ((shipY - d.y) / span).clamp(0.0, 1.0);
    }
    return squadOf(d)?.altitude(d, fight) ?? fight;
  }
  // --- end continuous swarm

  (int, int, bool) _ordinaryProfile([int? forWave]) {
    final w = forWave ?? wave;
    final index = _ordinaryBirthOrdinal++;
    final kind = _bonusKind(
      cycle > 0
          ? (index + w + level) % 4
          : w > 1 && index % 4 == 0
          ? math.max(0, level - 2)
          : level - 1,
    );
    final elite =
        (index + 1) % 10 == 0 &&
        !_bonusNoElites &&
        _eliteBirths < policy.eliteBudget(route: cycle);
    if (elite) _eliteBirths++;
    spearRun.next = _spearFor(elite, w); // --- spear-bearers
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
        // --- continuous swarm: a foreshadowed sentinel rises through every
        // fog band from its silhouette (design §6.3).
        if (sentinel.entryN != null) {
          sentinel.entranceDuration = sentinelRiseSeconds;
        }
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
    // --- continuous swarm: an ordinary group was born into the reserve at
    // the wave's start; admission flips it from waiting to swooping in.
    final waiting = escort ? null : _reserveGroups.firstOrNull;
    if (waiting != null && waiting.length == count) {
      _reserveGroups.removeAt(0);
      _updateReserve(0);
      final bySkein = <int, List<Demon>>{};
      for (var i = 0; i < count; i++) {
        final d = waiting[i]
          ..homeX = slots[i].$1
          ..homeY = slots[i].$2;
        (bySkein[d.skein] ??= []).add(d);
        demons.add(d);
      }
      for (final skein in bySkein.values) {
        _releaseSkein(skein, wave);
      }
      return true;
    }
    final group = <Demon>[];
    for (var i = 0; i < count; i++) {
      final profile = _ordinaryProfile();
      final d =
          _spearUp(
              Demon(
                slots[i].$1,
                slots[i].$2,
                profile.$1,
                profile.$2,
                random.nextDouble() * 8,
                elite: profile.$3,
                isEscort: escort,
              ),
            ) // --- spear-bearers
            ..entranceProgress = 0
            ..entranceDelay = 0
            ..entranceDuration = .8
            ..entranceStartY = -32 - i * 8.0
            ..arrivesFromDistance = true;
      d.y = d.entranceStartY;
      demons.add(d);
      group.add(d);
    }
    // --- atmosphere-and-swarms: the group flies in as a flock; a sentinel's
    // escort pours out of its silhouette as an insect swarm.
    final f = foreshadow;
    final id = _skeinIds++;
    for (final d in group) {
      d
        ..skein = id
        ..swarmState = SwarmState.approaching;
    }
    _formSquad(group);
    _launchFlock(
      group,
      wave,
      style: escort ? FlockStyle.insect : FlockStyle.squadrons,
      origin: escort && f != null && f.visible ? f : null,
    );
    return true;
  }

  void _enterPhase(RunMode phase, double duration) {
    // A wave, salvage or victory scene that starts mid-sequence (a shot
    // already in flight finished the fight) ends it: the reserve is back.
    if (lifeLossPhase != LifeLossPhase.none) {
      lifeLossPhase = LifeLossPhase.none;
      lifeLossLeft = 0;
      invulnerable = LifeLossTuning.protection;
      shipX = targetX = width / 2;
    }
    mode = phase;
    transitionDuration = duration;
    transitionLeft = duration;
  }

  void _completeWave() {
    if (lifeLossPhase == LifeLossPhase.emerging) {
      lifeLossPhase = LifeLossPhase.none;
    }
    // --- continuous swarm: no transition phase between waves of a sector.
    if (level == 5 && boss == null && wave == wavesPerLevel - 1) {
      _beginRise(); // --- boss-grandeur: the last loom wave is cleared
    } else if (wave < wavesPerLevel && incoming.isNotEmpty) {
      _mergeCohort(forced: false);
    } else if (wave < wavesPerLevel) {
      wave++;
      _spawnWave(continuous: true);
      events.add('wave');
      _queueGameEvent(GameEventNames.cohortMerged, {
        'wave': wave,
        'forced': false,
        'lull': 0.0,
      });
    } else {
      shots.clear();
      clearedLevel = level;
      _bonusClear(); // --- bonus levels: the clear award
      _groundEndLevel(); // --- ground war
      _enterPhase(RunMode.salvage, FlowPlan.routSeconds);
      _flowBegin(victory: false); // --- cinematic flow
      _flowRout(const []); // every fighter fell: the fog stays empty
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

  // --- phone-performance: render-side shot interpolation (shot_layer.dart).
  /// Wall time banked toward the next fixed 1/60 s step (0 ≤ x < 1/60 s).
  double get stepRemainder => _accumulator;

  void update(double dt) {
    if (mode == RunMode.paused ||
        mode == RunMode.title ||
        mode == RunMode.completed ||
        (mode == RunMode.gameOver && defeatTimer <= 0)) {
      return;
    }
    // --- fire-rate-tune: the epsilon keeps a whole step's frame time from
    // missing its step by float drift (design §3.3; the vsync snap itself
    // is the scene's, phone-performance `snapFrameDelta`).
    _accumulator += dt.clamp(0, .1);
    while (_accumulator >= fixedStep - 1e-9) {
      _step(fixedStep);
      _accumulator = math.max(0, _accumulator - fixedStep);
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
      _flowStep(); // --- cinematic flow
      _updateDefeatCelebration(dt);
      if (defeatTimer <= 0) {
        _flowEnd();
        events.add('gameover');
      }
      return;
    }
    clock += dt;
    _updateForeshadow(dt); // --- atmosphere-and-swarms (presentation)
    for (final f in deflects) {
      f.age += dt;
    }
    deflects.removeWhere((f) => f.age > Deflect.life);
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
          shipVx = dt > 0 ? ((shipX - oldShipX) / dt).clamp(-360.0, 360.0) : 0;
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
      // Spent modules are debris, not loot: they keep tumbling off screen
      // through salvage, level clear and travel instead of freezing.
      _updateFallingParts(dt);
      _updateReserve(dt); // --- continuous swarm: the reserve keeps drifting
      if (mode == RunMode.transition) _updateSquads(dt);
      if (mode == RunMode.transition) {
        if (wave > 1) {
          _advanceWaveEntrance(dt);
        } else if (!_spawnedFromCheckpoint && transitionProgress >= 0.45) {
          _advanceWaveEntrance(dt * 0.36);
        }
      }
      transitionLeft = math.max(0, transitionLeft - dt);
      // --- cinematic flow: the ship eases to the centre while it climbs
      // (never a pop at the level change), and the director reads the
      // phase clock.
      if (mode == RunMode.levelClear ||
          mode == RunMode.travel ||
          mode == RunMode.victory) {
        shipX += (width / 2 - shipX) * (1 - math.exp(-1.5 * dt));
        targetX = shipX;
      }
      _flowStep();
      _bonusIdle(dt); // --- bonus levels: a mechanic winds down
      if (transitionLeft <= 0) {
        if (mode == RunMode.salvage) {
          pickups.clear();
          heartPickups.clear();
          _groundLevelCleared(); // --- ground war
          final clear = FlowPlan.clearFor(flow.plan.reduced);
          _enterPhase(RunMode.levelClear, clear);
          _flowBase = FlowPlan.routSeconds;
          events.add('levelclear');
          if (_skipPending) _finishTravel();
        } else if (mode == RunMode.victory && finalBoss) {
          _bossCollapseEnd(); // --- boss-carrier-wire: the decay events
          mode = RunMode.completed;
          events.add('completed');
          _groundCampaignComplete(); // --- ground war
          _flowEnd();
        } else if (mode == RunMode.levelClear || mode == RunMode.victory) {
          if (mode == RunMode.victory) _bossCollapseEnd(); // --- boss-carrier-wire
          _flowBase += transitionDuration;
          _flowReplan();
          _enterPhase(
            RunMode.travel,
            FlowPlan.travelFor(flow.plan.reduced, extra: slotExtra),
          );
          events.add('travel');
        } else if (mode == RunMode.travel) {
          _finishTravel();
        } else {
          mode = RunMode.playing;
          if (flow.active) _flowEnd();
        }
      }
      return;
    }
    if (!combat) return;
    _activeMilliseconds += dt * 1000;
    levelClock += dt;
    _updateLifeLoss(dt); // --- life-loss sequence
    if (!shipAway) {
      pilot.observe(shipX, shipVx, dt); // --- demon intelligence
      _observeSkill(dt);
    }
    invulnerable = math.max(0, invulnerable - dt);
    _lightningStep(dt); // --- lightning-rework: grace, zap, charge timers
    // Module timers freeze while the ship is away: the loadout survives.
    // boss-grandeur: and while the carrier rises (a held beat, as the
    // transition into a carrier sector held them before the loom).
    // carrier-v3: and at half rate while everything the approach has in
    // play waits inside the carrier's gates (nothing to shoot; tuned on the
    // boss endurance gate, plan/calibration-current.md "Carrier v3").
    final powerDt = _gateHeld ? dt * gateHoldRate : dt;
    for (final value in shipAway || bossRising ? const <Power>[] : Power.values) {
      if (powerTimers.containsKey(value)) {
        powerTimers[value] = math.max(0, powerTimers[value]! - powerDt);
      }
    }
    powerTimers.removeWhere((power, remaining) {
      if (remaining <= 0) {
        if (power != Power.shield) {
          final side = power == Power.rapid
              ? (random.nextBool() ? 1.0 : -1.0)
              : 0.0;
          fallingParts.add(
            FallingPart(
              shipX + side * 14.0,
              ArcadeModel.shipY + 4,
              power,
              vx: (random.nextDouble() - 0.5) * 40.0 + side * 20.0,
              vy: -25.0 - random.nextDouble() * 15.0,
              vRot:
                  (random.nextBool() ? 1.0 : -1.0) *
                  (3.0 + random.nextDouble() * 3.0),
            ),
          );
        }
        return true;
      }
      return false;
    });

    _updateFallingParts(dt);
    _bonusStep(dt); // --- bonus levels: crates, bonus power timers

    for (final crate in supplyCrates) {
      crate.y += crate.vy * dt;
      crate.swingTime += dt;
      crate.hitFlash = math.max(0, crate.hitFlash - dt);
    }
    supplyCrates.removeWhere((c) => c.y > ArcadeModel.shipY + 30);
    if (!shipAway) _fire -= dt;
    wingRecoil[0] = math.max(0, wingRecoil[0] - dt);
    wingRecoil[1] = math.max(0, wingRecoil[1] - dt);
    noseFlash = math.max(0, noseFlash - dt);
    // --- fire-rate-tune: whole-step volley intervals (the epsilon keeps
    // float drift from making one gap a step longer and the next shorter;
    // an overdue timer, as after a reset to 0, does not shorten the next).
    if (_fire <= 1e-9) {
      final fired = shots.length;
      _fire = math.max(0.0, _fire) + fireInterval;
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
      final wing = wingGun;
      if (wing != null) {
        // Wing cannons alternate the primary shot: left, right, left, ...
        final muzzle = wingMuzzles[wing]!;
        shots.add(
          playerShot(
            shipX + wingSide * muzzle.x.abs() + shipBank * 3,
            shipY + muzzle.y,
            slingVx,
            -shotSpeed,
          ),
        );
        wingRecoil[wingSide < 0 ? 0 : 1] = wingRecoilDuration;
        wingSide = -wingSide;
      } else {
        shots.add(
          playerShot(shipX + shipBank * 3, shipY - 13, slingVx, -shotSpeed),
        );
        noseFlash = wingRecoilDuration;
      }
      if (hasPower(Power.spread)) {
        shots.addAll([
          playerShot(
            shipX - 5,
            shipY - 8,
            -90 + slingVx * 0.85,
            -spreadShotSpeed,
          ),
          playerShot(
            shipX + 5,
            shipY - 8,
            90 + slingVx * 0.85,
            -spreadShotSpeed,
          ),
        ]);
      }
      shotsFired += shots.length - fired; // --- demon intelligence
      events.add('shot');
    }
    if (!shipAway) _updateReinforcements(dt);
    _updateStream(dt); // --- continuous swarm: skein releases, reserve
    _windUnpush(); // --- crosswind: fly in still air
    _updateDemons(dt);
    _windPush(dt); // --- crosswind: then the wind's push on top
    _updateIncoming(dt); // --- continuous swarm (after formation targets move)
    _advanceFlock(dt); // --- atmosphere-and-swarms: arrivals drawn as a flock
    _publishSwarmStates(); // --- continuous swarm
    assert(
      swarmOccupancy <= swarmOccupancyBound,
      'continuous swarm occupancy $swarmOccupancy > $swarmOccupancyBound',
    );
    _updateBoss(dt);
    if (consoleDecay && !ranked && combat) _consoleDecayStep(dt); // --- C2
    _updateGround(dt); // --- ground war
    if (!combat) return;
    // --- boss-grandeur: the loom's cap.
    if (looming) {
      loomClock += dt;
      if (loomClock >= loomCap && !shipAway) _beginRise();
    }
    if (level == 5) _updateApproach(dt); // --- carrier-v3
    _windStep(); // --- crosswind: the field now, its calls
    for (final s in shots) {
      _windShot(s, dt); // --- crosswind: the drift
      s.x += s.vx * dt * (s.hostile ? policy.hostileRate : 1) + s.windVx * dt;
      s.y += (s.vy + s.windVy) * dt;
      s.age += dt;
    }
    _collisions();
    shots.removeWhere(
      (s) => s.y < -10 || s.y > height + 10 || s.x < -10 || s.x > width + 10,
    );
    if (combat &&
        !shipAway &&
        demons.isEmpty &&
        boss == null &&
        flocksRemaining == 0) {
      _completeWave();
    }
  }

  void _updateFallingParts(double dt) {
    for (final part in fallingParts) {
      part.vy += 160.0 * dt;
      part.x += part.vx * dt;
      part.y += part.vy * dt;
      part.rotation += part.vRot * dt;
      part.age += dt;
    }
    fallingParts.removeWhere((p) => p.y > height + 20 || p.age > 2.5);
  }

  void _updatePickups(double dt, double fallSpeed) {
    for (final p in pickups) {
      p.y += fallSpeed * dt;
      if ((p.x - shipX).abs() < 22 && (p.y - shipY).abs() < 23) {
        final special = p.bonus; // --- bonus levels
        special != null ? collectBonus(special) : collect(p.power);
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
    _updateHomingPickups(dt, fallSpeed); // --- ground war
  }

  void _hostile(Shot shot) {
    if (shipAway) return; // the regroup holds all hostile fire
    if (shots.where((s) => s.hostile).length >= 120) return;
    // --- fire-rate-tune: the climb speed on the anti-strobe grid.
    shots.add(
      Shot(
        shot.x,
        shot.y,
        shot.vx + _windLead(shot.y, hostileVy(shot.vy)), // --- crosswind
        hostileVy(shot.vy),
        hostile: true,
        kind: shot.kind,
        damage: shot.damage,
        blastRadius: shot.blastRadius,
      ),
    );
  }

  double _smootherstep(double t) {
    final c = t.clamp(0.0, 1.0);
    return c * c * c * (c * (c * 6 - 15) + 10);
  }

  void _igniteDiveShield(Demon d) {
    if (demons.any((o) => o.isLarge && o.waitingForEscort)) return;
    if (_spearIgnite(d)) return; // --- spear-bearers: the buckler instead
    // --- fire-rate-tune: one point less for a sentinel (was 4 + route ÷ 2)
    // and an elite (was 3); the heavier species' 2 is now 1, as the
    // light ones', so the slower gun still stops a diver (design §5).
    if (d.isLarge) {
      d.diveShieldMax = 3 + (cycle ~/ 2);
    } else {
      d.diveShieldMax = d.elite ? 2 : 1;
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
    // An arrival's own slot track, not where the flock draws it.
    final (selfX, selfY) = flock.slotTrack(d) ?? (d.x, d.y);
    for (final other in demons) {
      if (identical(other, d) ||
          other.isLarge ||
          other.entering ||
          other.dive > 0 ||
          other.lastStand) {
        continue;
      }
      final dx = selfX - other.x;
      final dy = selfY - other.y;
      final distSq = dx * dx + dy * dy;
      if (distSq <= 0.0001 || distSq >= 68 * 68) continue;
      final dist = math.sqrt(distSq);
      if (dist < 36) {
        sepX += (dx / dist) * (36 - dist) * 0.35;
        sepY += (dy / dist) * (36 - dist) * 0.20;
      }
      cohX += other.x - selfX;
      cohY += other.y - selfY;
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
                  d.evadeOffset +
                  d.boltDodge) // --- lightning-rework: the rank dodge
              .clamp(62.0, width - 62.0);
      final nextY = d.homeY + math.sin(levelClock * .65 * speed + d.seed) * 5;
      return (nextX, nextY);
    }
    final evadeX = d.evadeOffset * (d.evadeLeft / 0.32).clamp(0.0, 1.0);
    final evadeY = d.evadeLift == 0
        ? 0.0
        : d.evadeLift * (d.evadeLeft / 0.32).clamp(0.0, 1.0);
    // --- continuous swarm: squad members fly their pattern target, plus
    // the gated evade and the telegraph crest; strays and onboarding hover.
    final pattern = _patternTarget(d);
    if (pattern != null) {
      var (px, py) = pattern;
      px += evadeX + d.boltDodge; // --- lightning-rework: the rank dodge
      py += evadeY;
      if (d.telegraph > 0) {
        final totalTell = d.elite ? 0.55 : 0.7;
        final progress = (d.telegraph / totalTell).clamp(0.0, 1.0);
        py -= 8.0 * math.sin((1 - progress) * math.pi);
      }
      return (px.clamp(20.0, width - 20.0), py);
    }
    final (boidsX, boidsY) = _boidsOffset(d);
    final targetFormX =
        (d.homeX +
                math.sin(levelClock * (.9 + d.kind * .12) * speed + d.seed) *
                    29 +
                math.sin(levelClock * .44 * policy.hostileRate) * 13 +
                boidsX +
                evadeX +
                d.boltDodge) // --- lightning-rework: the rank dodge
            .clamp(20.0, width - 20.0);
    var targetFormY =
        d.homeY +
        math.sin(levelClock * 1.7 * speed + d.seed) * 14 +
        boidsY +
        evadeY;
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
    d.bank = (d.bank + (targetBank - d.bank) * (1 - math.exp(-14 * dt))).clamp(
      -1.0,
      1.0,
    );
  }

  void _advanceWaveEntrance(double dt) {
    for (final d in demons) {
      if (!d.entering ||
          d.waitingForEscort ||
          d.swarmState == SwarmState.reserve) {
        continue;
      }
      if (d.gateWait > 0) {
        // carrier-v3: parked in its gate until its turn in the volley.
        d.gateWait = math.max(0, d.gateWait - dt);
        continue;
      }
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
      _placeEntering(d, s, targetFormX, targetFormY, arcX);
      _updateDemonKinematics(d, prevX, prevY, dt);
    }
    _advanceFlock(dt);
    _updatePerspective(dt);
  }

  // --- atmosphere-and-swarms: flock arrivals and sentinel foreshadowing ---

  /// The arrival flock (flock.dart): where entering creatures are drawn.
  final SwarmFlock flock;

  /// Arrivals fly in as a flock (presentation only; false = the plain
  /// depth approach, for the parity test).
  bool flockArrivals = true;

  /// The sentinel wave [forWave] of this sector brings, if any (the roster
  /// rule, deterministic: no random draws).
  EnemyArchetype? sentinelFor(int forWave) {
    if (boss != null || level == 5 || forWave < 1 || forWave > wavesPerLevel) {
      return null;
    }
    if (_bonusNoSentinels) return null; // --- bonus levels
    final eligible =
        cycle >= 1 &&
        ((forWave == wavesPerLevel &&
                level >= 2 &&
                (difficulty != Difficulty.easy || level.isEven)) ||
            (difficulty != Difficulty.easy &&
                forWave >= 3 &&
                (forWave + level + cycle).isEven));
    if (!eligible) return null;
    return cycle >= 2 && difficulty != Difficulty.easy
        ? EnemyArchetype.armoredSentinel
        : EnemyArchetype.shieldSentinel;
  }

  void _launchFlock(
    List<Demon> group,
    int forWave, {
    FlockStyle style = FlockStyle.squadrons,
    SentinelForeshadow? origin,
    SwarmGate? gate,
  }) {
    // carrier-v3: the approach's waves leave the carrier's gates.
    if (looming && level == 5) _gateLaunch(group);
    if (!perspective || !flockArrivals) return;
    flock.launch(
      [
        for (final d in group)
          if (d.arrivesFromDistance && !d.isLarge) d,
      ],
      sector: level,
      route: cycle,
      wave: forWave,
      style: style,
      originX: origin?.x,
      originY: origin?.y,
      originN: origin?.nearness,
      gate: gate,
    );
  }

  /// Steps the flock on the entrance clock and draws its creatures there;
  /// the drawn size follows the drawn depth.
  void _advanceFlock(double dt) {
    if (!perspective || !flockArrivals) return;
    for (final a in flock.advance(dt)) {
      final d = a.demon;
      _updateDemonKinematics(d, a.prevX, a.prevY, dt);
      d.scale = Perspective.scaleOf(d.nearness, angry: d.angry);
    }
  }

  /// The sentinel's silhouette circling far behind the fog, one or two
  /// waves ahead of it (pure presentation; null when none is due).
  SentinelForeshadow? foreshadow;


  void _updateForeshadow(double dt) {
    final f = foreshadow;
    // What is due: the sentinel of this wave still waiting for its escort
    // (stage 1), or one coming next wave (.5) or the wave after (0).
    double? stage;
    EnemyArchetype? kind;
    Demon? waiting;
    if (perspective && boss == null && mode != RunMode.title) {
      for (final d in demons) {
        if (d.isLarge && d.entering && d.entranceProgress <= 0) waiting = d;
      }
      final present = demons.any(
        (d) => d.isLarge && !(d.entering && d.entranceProgress <= 0),
      );
      if (waiting != null) {
        stage = 1;
        kind = waiting.archetype;
      } else if (!present) {
        final next = sentinelFor(wave + 1);
        final after = sentinelFor(wave + 2);
        if (next != null) {
          stage = .5;
          kind = next;
        } else if (after != null) {
          stage = 0;
          kind = after;
        }
      }
      // No silhouette through a level's end or a transition (playtest
      // R1): the Descent shows the new sector's first cohort only; a
      // sentinel due later fades in once the fight is on.
      if (mode == RunMode.salvage ||
          mode == RunMode.levelClear ||
          mode == RunMode.travel ||
          flow.active) {
        stage = null;
      }
    }
    if (demons.any(
      (d) => d.isLarge && d.entryScale != null && d.entranceProgress > 0,
    )) {
      // Handed over: the sentinel itself carries the silhouette now.
      foreshadow = null;
      return;
    }
    if (stage == null || kind == null) {
      if (f == null) return;
      f.opacity = math.max(0, f.opacity - dt / .8);
      f.clock += dt;
      f.place();
      if (f.opacity <= 0) foreshadow = null;
      return;
    }
    final g = foreshadow ??= SentinelForeshadow(kind, stage);
    g
      ..archetype = kind
      ..stage = stage
      ..clock += dt
      ..opacity = math.min(1, g.opacity + dt / SentinelForeshadow.fadeIn);
    final rate = stage >= 1 ? 1.2 : 2.5;
    g.growth += (stage - g.growth) * (1 - math.exp(-dt / rate));
    g.place();
    if (waiting != null) {
      // The sentinel sets out from where its silhouette is now.
      waiting
        ..entryX = g.x
        ..entryY = g.y
        ..entryN = g.nearness
        ..entryScale = g.scale;
    }
  }

  // --- perspective (lib/game/perspective.dart, plan/perspective.md) ---
  /// Entrance placement: the flat legacy drop from above, or, for arrivals
  /// with [Demon.arrivesFromDistance], a flight out of the horizon haze
  /// whose depth moves linearly so it grows as it approaches its slot.
  void _placeEntering(
    Demon d,
    double s,
    double tx,
    double ty,
    double arcX, {
    bool holding = false,
  }) {
    if (perspective && d.arrivesFromDistance) {
      var (n, u) = Perspective.approach(
        s,
        _targetNearness(d, ty),
        from: d.entryN,
      );
      final from = d.entryN;
      if (d.isLarge && from != null) {
        // --- continuous swarm: the sentinel's rise path in depth.
        final to = _targetNearness(d, ty);
        n = sentinelRiseNearness(d.entranceProgress, from, to);
        u = to <= from ? 1.0 : ((n - from) / (to - from)).clamp(0.0, 1.0);
      }
      final x0 = d.entryX ?? Perspective.arrivalX(d.homeX);
      final y0 = d.entryY ?? Perspective.arrivalYFor(d.homeY);
      d.nearness = n;
      d.x = (x0 + (tx - x0) * u + arcX * .6).clamp(18.0, width - 18.0);
      d.y = y0 + (ty - y0) * u;
      // The flock decides where the creature is drawn until it settles.
      if (flockArrivals && !d.isLarge) {
        flock.reference(
          d,
          sector: level,
          route: cycle,
          wave: wave,
          holding: holding,
        );
      }
      return;
    }
    final x0 = d.entranceStartX ?? d.homeX; // carrier-v3: from a gate
    d.x = (x0 + arcX + (tx - x0) * s).clamp(18.0, width - 18.0);
    d.y = d.entranceStartY + (ty - d.entranceStartY) * s;
  }

  /// The nearness [d] settles toward at screen [y]: the flight sheet, a
  /// breath in phase with its formation bob, a slow wander, a dive boost.
  double _targetNearness(Demon d, double y) => Perspective.targetNearness(
    y,
    phase: levelClock * (d.isLarge ? .65 : 1.7) * speed + d.seed,
    wanderPhase: levelClock * .53 + d.seed * 2.3,
    diving: d.dive > 0 || d.rushing,
  );

  /// Depth pass after movement: eases each demon's nearness toward its
  /// target (entering arrivals are placed exactly) and quantises its scale.
  void _updatePerspective(double dt) {
    for (final d in demons) {
      if (!perspective) {
        d.scale = 1;
        d.hitHalfWidth = d.isLarge ? 27.0 : 16.0;
        d.hitHalfHeight = d.isLarge ? 18.0 : 14.0;
        continue;
      }
      final placed = d.entering && d.arrivesFromDistance;
      if (!placed) {
        var target = _targetNearness(d, d.y);
        if (d.lastStand && !d.rushing) {
          // --- sentinel rush: the rally pulls back in depth.
          target -=
              RushTuning.pullBack *
              (d.lastStandTellProgress * d.rushTell / RushTuning.rally).clamp(
                0.0,
                1.0,
              );
        }
        d.nearness = dt <= 0 || d.nearness == 0
            ? target
            : d.nearness +
                  (target - d.nearness) *
                      (1 - math.exp(-Perspective.followRate * dt));
      }
      d.scale = Perspective.scaleOf(
        d.nearness,
        large: d.isLarge,
        angry: d.angry,
      );
      if (d.rushing) {
        // --- sentinel rush: it grows to the 1.25 cap as it closes in.
        final k = ((d.y - d._lastStandY) / (shipY - d._lastStandY)).clamp(
          0.0,
          1.0,
        );
        d.scale = ((d.scale + (1.25 - d.scale) * k) * 16).round() / 16;
      }
      final from = d.entryScale;
      if (from != null && d.entering && d.isLarge) {
        // A foreshadowed sentinel keeps its silhouette's size as it flies
        // in, growing into its own (presentation: it cannot be hit yet).
        final s = _smootherstep(d.entranceProgress);
        d.scale = ((from + (d.scale - from) * s) * 16).round() / 16;
      }
      final (halfW, halfH) = d.isLarge
          ? Perspective.largeHitHalf
          : Perspective.smallHitHalf;
      d.hitHalfWidth = halfW * d.scale;
      d.hitHalfHeight = halfH * d.scale;
    }
  }

  int get _maxConcurrentSmallDives => difficulty == Difficulty.easy
      ? (level <= 2 ? 1 : 2)
      : (level <= 2 && cycle == 0
            ? 1
            : (difficulty == Difficulty.hard ? 3 : 2));

  void _updateDemons(double dt) {
    planDecisionsThisFrame = 0; // --- demon intelligence
    _spearFrame(dt); // --- spear-bearers: fallen bucklers tumble
    if (!shipAway) _dive -= dt * policy.hostileRate;
    var activeSmallDives = demons
        .where(
          (d) =>
              !d.isLarge && (d.dive > 0 || d.telegraph > 0 || d.divePrep > 0),
        )
        .length;
    final maxSmallDives = _maxConcurrentSmallDives;
    final readyDivers = demons
        .where(
          (d) =>
              !d.entering &&
              !d.lastStand &&
              !d.stunned && // --- lightning-rework
              d.dive == 0 &&
              d.telegraph <= 0 &&
              d.divePrep <= 0 &&
              (d.isLarge || activeSmallDives < maxSmallDives),
        )
        .toList();
    if (!shipAway && _dive <= 0 && readyDivers.isNotEmpty) {
      final d = readyDivers[random.nextInt(readyDivers.length)];
      if (level >= 2 || cycle > 0) {
        _prepDive(d);
        if (!d.isLarge) activeSmallDives++;
        // --- demon intelligence: a pincer by a second ready hunter.
        final partner = _pincerPartner(d, readyDivers);
        if (partner != null && activeSmallDives < maxSmallDives) {
          d.pincer = -1;
          partner.pincer = 1;
          _prepDive(partner);
          activeSmallDives++;
        }
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
        if (d.swarmState == SwarmState.reserve) continue; // in the fog
        if (d.entranceHold > 0) {
          // The lull: the cohort holds at the fog front (continuous swarm).
          d.entranceHold = math.max(0, d.entranceHold - dt);
        } else {
          d.entranceElapsed += dt;
        }
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
        _placeEntering(
          d,
          s,
          targetFormX,
          targetFormY,
          arcX,
          holding: d.entranceHold > 0,
        );
        _updateDemonKinematics(d, prevX, prevY, dt);
        continue;
      }
      _spearStep(d, dt); // --- spear-bearers: the wind-up and the throw
      if (_regroupDemon(d, prevX, prevY, dt)) continue; // --- life loss
      if (_stunnedDemon(d, prevX, prevY, dt)) continue; // --- lightning-rework
      if (d.divePrep > 0 && dt > 0) {
        d.divePrep -= dt * policy.hostileRate;
        if (d.divePrep <= 0) _startDiveTell(d);
      }
      if (d.isLarge && !d.lastStand && dt > 0) _maybeRush(d); // alone
      if (d.lastStand) {
        // --- the sentinel final rush (sentinel_rush.dart)
        if (dt > 0 && !_updateRush(d, dt)) continue;
        _updateDemonKinematics(d, prevX, prevY, dt);
        continue;
      }
      if (d.isLarge && d.dive == 0 && d.telegraph <= 0) {
        // --- lightning-rework: a charged rod-armoured creature fires faster.
        d.volleyLeft -= dt * policy.hostileRate * _chargeRate(d);
        if (d.volleyLeft <= 0) {
          final aim = ((shipX - d.x) * .35).clamp(-85.0, 85.0);
          _hostile(
            Shot(
              d.x,
              d.y + d.muzzleDy,
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
        d.attackLeft -= dt * policy.hostileRate * _chargeRate(d);
        if (d.attackLeft <= 0) {
          final aim = ((shipX - d.x) * .3).clamp(-70.0, 70.0);
          // --- spear-bearers: a bearer's weapon is its spear, never the
          // hunter's triple spread (it replaces a hunter's pressure).
          if (!d.isLarge && d.spear == null) {
            for (final offset in [-32.0, 0.0, 32.0]) {
              _hostile(
                Shot(
                  d.x,
                  d.y + d.muzzleDy,
                  aim + offset,
                  130 * speed,
                  hostile: true,
                ),
              );
            }
          }
          if (d.dive == 0 &&
              d.telegraph <= 0 &&
              d.divePrep <= 0 &&
              (d.isLarge || activeSmallDives < maxSmallDives)) {
            _prepDive(d);
            if (!d.isLarge) activeSmallDives++;
          }
          d.attackLeft = math.max(2.0, 4 - math.min(cycle, 5) * .3);
        }
      }
      if (d.telegraph > 0) {
        d.telegraph -= dt * policy.hostileRate;
        if (d.telegraph <= 0) {
          d.dive = .001;
          d.threadLine = d.x; // --- demon intelligence (thread dive)
          d.threadOffset = d.threadVx = d.threadTarget = 0;
          _igniteDiveShield(d);
          if (d.isLarge) {
            final aim = ((d.targetX - d.x) * .3).clamp(-70.0, 70.0);
            for (final offset in [-32.0, 0.0, 32.0]) {
              _hostile(
                Shot(
                  d.x,
                  d.y + 12 * d.scale,
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
        if (_intel && d.elite && !d.isLarge) {
          _threadDive(
            d,
            dt,
            (115 + d.kind * 16) *
                speed *
                (d.angry ? 1.3 : 1) *
                1.15 *
                shatteredSlow,
          );
        } else {
          d.x +=
              (d.targetX - d.x) *
              dt *
              policy.hostileRate *
              (d.isLarge ? 3.4 : (d.elite ? 2.1 : 1.8));
        }
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
          } else if (perspective) {
            _beginReentry(d); // --- continuous swarm: back out of the fog
          } else {
            d.entranceStartY = -36;
            d.arrivesFromDistance = false; // loops back in from above
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
        } else if (patterned(d)) {
          // --- continuous swarm: the squad's pattern, flown (design §4).
          _steerToPattern(d, targetFormX, targetFormY, dt);
          _updateDemonKinematics(d, prevX, prevY, dt);
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
    final shooters = demons
        .where((d) => !d.isLarge && !d.entering && !d.stunned)
        .toList(); // --- lightning-rework: a stunned creature cannot fire
    if (_enemyFire <= 0 && shooters.isNotEmpty) {
      final d = shooters[random.nextInt(shooters.length)];
      final aim = ((shipX - d.x) * .22).clamp(-65.0, 65.0);
      _hostile(
        Shot(
          d.x,
          d.y + d.muzzleDy,
          aim,
          (100 + level * 13) * speed,
          hostile: true,
        ),
      );
      _enemyFire = math.max(.45, 1.8 - level * .18 - cycle * .05);
    }
    _updatePerspective(dt);
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
      if (d.evadeLift != 0) {
        d.evadeLift += (-d.evadeLift).clamp(-90 * dt, 90 * dt);
      }
    }
    if ((level < 2 && cycle == 0) ||
        d.telegraph > 0 ||
        d.divePrep > 0 ||
        d.evadeCooldown > 0) {
      return false;
    }
    // One drone/skirmisher evader at a time; hunters have their own slot.
    if (demons.any(
      (o) =>
          !o.isLarge &&
          !identical(o, d) &&
          o.evadeLeft > 0 &&
          (!_intel || o.elite == d.elite),
    )) {
      return false;
    }
    if (demons.any((o) => o.isLarge && o.waitingForEscort)) {
      return false;
    }
    if (_intel && d.elite) {
      return _evadeHunter(d, activeSmallDives, maxSmallDives);
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
      tierFactor: d.elite
          ? 1.0
          : ((d.kind >= 2 || d.maxHp >= 3) ? 0.35 : -0.75),
    );
    final cooldown = difficulty == Difficulty.easy
        ? 3.2
        : (difficulty == Difficulty.normal ? 2.4 : 1.8);
    if (action == 'evade_left' || action == 'evade_right') {
      var dir = action == 'evade_left' ? -1.0 : 1.0;
      if (d.x < 44) dir = 1.0;
      if (d.x > width - 44) dir = -1.0;
      if (_vetoed(d, dir)) return false; // --- demon intelligence (T1)
      d.evadeOffset = dir * 24.0;
      d.evadeLeft = 0.32;
      d.evadeCooldown = cooldown;
      return false;
    }
    if (action == 'dive_commit' && activeSmallDives < maxSmallDives) {
      _prepDive(d, lead: true);
      d.evadeCooldown = cooldown;
      return true;
    }
    final projectedX = nearestShot.x + nearestShot.vx * bestArrival;
    // A sidestep clears the demon's own (perspective-scaled) hitbox.
    if ((projectedX - d.x).abs() < d.hitHalfWidth + 2) {
      var dir = projectedX <= d.x ? 1.0 : -1.0;
      if (d.x < 44) dir = 1.0;
      if (d.x > width - 44) dir = -1.0;
      if (_vetoed(d, dir)) return false; // --- demon intelligence (T1)
      d.evadeOffset = dir * 22.0 * d.scale;
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
    if (_intel) {
      _evadeSentinel(d);
      return;
    }
    for (final shot in shots) {
      if (shot.hostile || shot.vy >= 0) continue;
      final arrival = (d.y - shot.y) / shot.vy;
      final projectedX = shot.x + shot.vx * arrival;
      if (arrival < 0 ||
          arrival > .55 ||
          (projectedX - d.x).abs() > 38 * d.scale) {
        continue;
      }
      var direction = projectedX < d.x ? 1 : -1;
      if (d.x < 110) direction = 1;
      if (d.x > width - 110) direction = -1;
      d.evadeOffset = direction * 54.0 * d.scale;
      d.evadeLeft = .6;
      d.evadeCooldown = 1.4;
      break;
    }
  }

  // --- demon intelligence: tiers (openspec/changes/demon-intelligence
  // design §3-§4). T0 drones keep the SwarmPolicy evade above unchanged;
  // T1 skirmishers add the planner veto; T2 hunters and T3 sentinels run
  // the planner at 10 Hz. Route 0 never gets here (`_intel`).

  /// Whether [d]'s 10 Hz decision is due and the frame still has room:
  /// staggered by its seed; a due creature over the cap waits a frame.
  bool _planDue(Demon d) {
    if (d.planAt < 0) {
      d.planAt = clock + (d.seed * .618 % 1).abs() / planRate;
    }
    if (clock + 1e-9 < d.planAt) return false;
    if (planDecisionsThisFrame >= maxPlanDecisions) return false;
    planDecisionsThisFrame++;
    d.planAt = math.max(d.planAt + 1 / planRate, clock + .5 / planRate);
    return true;
  }

  PlanState _planFor(Demon d) {
    var left = 0, right = 0;
    for (final o in demons) {
      if (identical(o, d) || o.isLarge || o.entering) continue;
      final dx = o.x - d.x, dy = o.y - d.y;
      if (dx * dx + dy * dy <= 72 * 72) {
        if (dx < 0) {
          left++;
        } else {
          right++;
        }
      }
    }
    final evadeX = d.evadeOffset * (d.evadeLeft / .32).clamp(0.0, 1.0);
    return _plan
      ..x = d.x
      ..y = d.y
      ..vx = d.vx
      ..vy = d.vy
      ..scale = d.scale
      ..halfWidth = d.hitHalfWidth
      ..crowd = ((right - left) / 4.0).clamp(-1.0, 1.0)
      ..leashX = d.isLarge ? d.x : _targetFormationPosition(d).$1 - evadeX
      ..last = d.lastPlan;
  }

  /// T1: the SwarmPolicy proposal (a sidestep toward [dir]) is vetoed
  /// when it runs into more danger than holding (another shot).
  bool _vetoed(Demon d, double dir) {
    if (!_intel || tierOf(d) != DemonTier.skirmisher) return false;
    const cfg = PlannerConfig.skirmisher;
    final s = _planFor(d);
    final hold = DemonPlanner.dangerOf(Manoeuvre.hold, s, cfg, shots);
    final side = DemonPlanner.dangerOf(
      dir < 0 ? Manoeuvre.sideL : Manoeuvre.sideR,
      s,
      cfg,
      shots,
    );
    return side > hold;
  }

  /// T2: the full planner (the thread candidate is a dive commit while a
  /// dive slot is free). Returns true when it commits a dive.
  bool _evadeHunter(Demon d, int activeSmallDives, int maxSmallDives) {
    if (!_planDue(d)) return false;
    final skill = skillLevel;
    final s = _planFor(d);
    if (DemonPlanner.dangerOf(
          Manoeuvre.hold,
          s,
          PlannerConfig.hunter(skill),
          shots,
        ) <=
        0) {
      d.lastPlan = Manoeuvre.hold;
      return false;
    }
    final threat = DemonPlanner.lastContact;
    // The dive commit is a candidate only while a slot is free and the
    // ship is likely under the dive (teacher: interceptErr < 68).
    s.aimX = (shipX + shipVx * .22).clamp(24.0, width - 24.0);
    final (threadDx, _) = DemonPlanner.displacement(
      Manoeuvre.thread,
      s,
      PlannerConfig.hunter(skill),
    );
    s.aimP = pilot.pHit(d.x + threadDx, _diveEta(d), d.contactHalf + 36);
    final cfg = PlannerConfig.hunter(
      skill,
      dive: activeSmallDives < maxSmallDives && !shipAway && s.aimP >= .25,
    );
    final a = planner.choose(s, cfg, shots);
    d.lastPlan = a;
    switch (a) {
      case Manoeuvre.hold:
        return false;
      case Manoeuvre.thread:
        _prepDive(d, lead: true);
        d.evadeCooldown = PlannerConfig.hunterCooldown(skill);
        return true;
      default:
        final (dx, dy) = DemonPlanner.displacement(a, s, cfg);
        d.evadeOffset = dx;
        d.evadeLift = dy;
        // Held out of the shot's path until it has passed, then eased back
        // (the planner plans the move and the stay; today's jink fades
        // over 0.32 s at once).
        d.evadeLeft = .32 + threat.clamp(.1, 1.2) + hunterHold;
        d.evadeCooldown = PlannerConfig.hunterCooldown(skill);
        return false;
    }
  }

  /// Seconds a hunter holds its sidestep after the threat's contact time.
  static const hunterHold = .15;

  /// Seconds (real) from a dive tell starting now until [d] reaches the
  /// ship row on today's dive.
  double _diveEta(Demon d) {
    final rate = policy.hostileRate > 0 ? policy.hostileRate : 1;
    final vy =
        (d.isLarge ? 300 : (115 + d.kind * 16)) *
        speed *
        (d.angry ? 1.3 : 1) *
        (d.elite ? 1.15 : 1);
    return (divePrepBeat + diveTellFor(d)) / rate +
        math.max(0, shipY - d.y) / vy;
  }

  /// T3: planner-backed sentinel sidestep with today's 54-u span, 0.6 s
  /// and 1.4 s cooldown.
  void _evadeSentinel(Demon d) {
    if (!_planDue(d)) return;
    const cfg = PlannerConfig.sentinel;
    final s = _planFor(d);
    if (DemonPlanner.dangerOf(Manoeuvre.hold, s, cfg, shots) <= 0) {
      d.lastPlan = Manoeuvre.hold;
      return;
    }
    final a = planner.choose(s, cfg, shots);
    d.lastPlan = a;
    if (a == Manoeuvre.hold) return;
    final (dx, _) = DemonPlanner.displacement(a, s, cfg);
    d.evadeOffset = dx;
    d.evadeLeft = .6;
    d.evadeCooldown = 1.4;
  }
  // --- end demon intelligence tiers

  void _updateBoss(double dt) {
    final b = boss;
    if (b == null) return;
    if (!b.fightReady) {
      // --- boss-grandeur: the Rise. It holds its station under the fog;
      // no motion, doors, minions or fire until it is fully out.
      if (combat) {
        b.emerge = math.min(1.0, b.emerge + dt / Carrier.riseSeconds);
        if (b.fightReady) {
          b.readyAt = levelClock;
          // carrier-v3 §5.2–§5.4: the hittable threshold, then the take-off.
          approachD = 1;
          final sc = carrierScript;
          _queueGameEvent(GameEventNames.bossInRange, {
            ..._carrierEventData,
            'distance': 1,
          });
          _queueGameEvent(GameEventNames.bossTakeoff, {
            ..._carrierEventData,
            'minZoom': sc.camera.minZoom,
            'altitude': sc.camera.maxAltitude,
          });
        }
      }
      b.y = Carrier.fightRow + Carrier.glideAmplitude * b.glide;
      return;
    }
    final clock = levelClock - b.readyAt;
    final oldX = b.x;
    _updateHatchChapters(b, dt); // --- carrier-hatches
    b.motionPhase +=
        dt * .7 * speed * b.movementRate * b.glideFactor * b.startingDirection;
    b.x = b.forecastX(0, speed);
    b.horizontalVelocity = dt > 0 ? (b.x - oldX) / dt : b.horizontalVelocity;
    // --- boss-grandeur (hook b): the bounded vertical glide.
    b.glidePhase += dt * Carrier.glideRate * b.movementRate;
    b.y = Carrier.fightRow + Carrier.glideAmplitude * b.glide;
    b.door =
        ((math.sin(clock * (1.55 + b.phase * .22)) -
                    (cycle == 0 ? 0.0 : .1)) *
                2)
            .clamp(0, 1);
    if (b.sideHatchesLocked) {
      b.sideDoorLeft = 0;
      b.sideDoorRight = 0;
    } else {
      final sideBonus = cycle <= 1 ? 0.15 : 0.0;
      final sideRamp = ((clock - 0.65) / 0.35).clamp(0.0, 1.0);
      b.sideDoorLeft =
          (((math.sin(clock * (1.45 + b.phase * .2) + 1.9) + sideBonus) *
                  2)
              .clamp(0.0, 1.0) *
          sideRamp);
      b.sideDoorRight =
          (((math.sin(clock * (1.45 + b.phase * .2) + 4.1) + sideBonus) *
                  2)
              .clamp(0.0, 1.0) *
          sideRamp);
    }
    // --- carrier-hatches §A4: the transformation holds the timers and the
    // fire (creatures already out keep fighting).
    if (b.chapter == CarrierChapter.transform) return;
    _flock -= dt * policy.hostileRate;
    final maxMinions = fightMinionCap(cycle);
    // carrier-v3 §4.4, carrier-hatches §A6: the flock's hatch telegraphs
    // and opens ahead of the timer, and a flock from a high tier leaves
    // earlier by its longer transit, so each creature still arrives at
    // today's moment (arrival invariance); only the origins change.
    final l = launches ??= _launchesFor();
    final tierY = _launchTierY(b);
    final early = CarrierHatches.early(tierY);
    final lead = l.timing.telegraph + l.timing.open + early;
    if (_fightGate == null && _flock / policy.hostileRate <= lead) {
      _fightGate = l.pick(
        (g) => gateOnCarrier(b, g).x,
        eligible: (g) => _launchesFrom(b, g),
      );
      final r = _fightGate;
      if (r != null) l.volley(r, 0, tier: math.min(3, cycle + 1), hold: true);
    }
    if (_flock / policy.hostileRate <= early && demons.length < maxMinions) {
      final flockSize = math.min(3, maxMinions - demons.length);
      final gate = _fightGate;
      _fightGate = null;
      final from = gate == null ? null : gateOnCarrier(b, gate.gate);
      if (gate != null) {
        gate.queued += flockSize;
        l.release(gate);
      }
      final transit = gate == null
          ? .55
          : CarrierHatches.transit(gate.gate.y);
      // §A5: a core-door flock waits in the door until it opens.
      final hold = gate != null && gate.gate.y == CarrierHatches.core.y
          ? _coreDoorWait(b, clock)
          : 0.0;
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
              ..entranceDuration = transit
              ..gateWait = hold
              ..entranceStartY = from == null ? b.y + 36 : from.y
              ..entranceStartX = from?.x;
        d.y = d.entranceStartY;
        demons.add(d);
      }
      if (gate != null && gate.gate.y == CarrierHatches.core.y) {
        coreLaunches++;
        if (hold > 0) coreHolds++;
      }
      _flock =
          math.max(2.4, 5.6 - b.phase * 0.45 - cycle * 0.25) /
              policy.hostileRate +
          early * policy.hostileRate;
    }
    // Fan attacks force positioning without tracking a player after launch.
    final fanRate =
        (0.85 + math.min(cycle, 3) * 0.08) *
        policy.hostileRate *
        CarrierHatches.fanShares[difficulty.index]; // --- carrier-hatches
    if ((clock * fanRate).floor() != ((clock - dt) * fanRate).floor()) {
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
        // --- bonus levels: a run modifier may change or withhold it.
        final allowed = _bonusDrop(power, crate: true);
        if (allowed != null) {
          supplyCrates.add(SupplyCrate(spawnX, -20.0, allowed));
        }
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
        } else if (!shipAway &&
            s.vy > 0 &&
            s.y >= shipY &&
            s.y - s.vy / 60 < shipY &&
            (s.x - shipX).abs() < 26) {
          nearMisses++; // --- demon intelligence: a dodge (skill meter)
        }
        continue;
      }
      // --- carrier-hatches §A3: the hatch chapter's rows.
      final hatchCarrier = hittableBoss;
      if (hatchCarrier != null) syncChapter(hatchCarrier);
      if (hatchCarrier != null &&
          hatchCarrier.chapter == CarrierChapter.hatches) {
        if (_hatchShot(hatchCarrier, s)) {
          s.y = height + 20;
          shotsHit++;
          continue;
        }
      }
      final shieldedCarrier = hittableBoss;
      if (shieldedCarrier != null &&
          shieldedCarrier.chapter == CarrierChapter.core &&
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
          shotsHit++;
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
          shotsHit++;
          if (crate.destroyed) {
            supplyCrates.remove(crate);
            blasts.add(Blast(crate.x, crate.y, big: true));
            pickups.add(
              Pickup(crate.x, crate.y, crate.power, bonus: crate.bonus),
            );
            _bonusCrateOpened(crate); // --- bonus levels
            // --- mission-medals: a bonus crate pops with its own sound
            // (the 'salvage' jingle and radio meant "wave clear").
            events.add(bonus == null ? 'salvage' : 'crateOpen');
          }
          break;
        }
      }
      if (hit) continue;
      for (final d in List<Demon>.of(demons)) {
        if (!d.entering &&
            (s.x - d.x).abs() < d.hitHalfWidth + (s.blastRadius > 0 ? 5 : 0) &&
            (s.y - d.y).abs() < d.hitHalfHeight + (s.blastRadius > 0 ? 5 : 0)) {
          if (s.blastRadius > 0) {
            _explodeShot(s);
          } else {
            hitDemon(d, damage: s.damage, atX: s.x, atY: s.y);
          }
          hit = true;
          break;
        }
      }
      final b = hittableBoss;
      if (!hit &&
          b != null &&
          b.chapter == CarrierChapter.core &&
          b.shield == 0 &&
          (s.x - b.x).abs() < 78 + (s.blastRadius > 0 ? 5 : 0) &&
          s.y < b.y + 43 + (s.blastRadius > 0 ? 5 : 0) &&
          s.y > b.y - 25 - (s.blastRadius > 0 ? 5 : 0)) {
        _coreShotPattern(b, s); // --- carrier-hatches §A7 hints
        if (s.blastRadius > 0) {
          _explodeShot(s);
        } else {
          hitBoss(s.x, damage: s.damage);
        }
        hit = true;
      }
      if (hit) {
        s.y = height + 20;
        shotsHit++;
      }
    }
    for (final d in List<Demon>.of(demons)) {
      if (!d.entering &&
          (d.x - shipX).abs() < d.contactHalf &&
          (d.y - shipY).abs() < d.contactHalf) {
        if (d.rushing) {
          _rushContact(d); // --- sentinel rush
        } else {
          hitPlayer();
        }
      }
    }
  }

  /// carrier-hatches §A7: a shot meeting the hull band at the core door
  /// on a closed door, or on the open door's trailing side (aimed where it
  /// was), feeds the timing and lead hints.
  void _coreShotPattern(Carrier b, Shot s) {
    final dx = s.x - b.x;
    if (b.door < CarrierHatches.coreOpenAt) {
      if (dx.abs() <= 20) _closedDoorHits.add(levelClock);
      return;
    }
    final window = CarrierHatches.coreWindow * b.door;
    final v = b.horizontalVelocity;
    if (dx.abs() > window && dx.abs() <= window + 40 && dx * v < 0) {
      _trailing.add(levelClock);
    }
  }

  void _explodeShot(Shot shot, {bool hitCarrier = true}) {
    blasts.add(Blast(shot.x, shot.y, blastRadius: shot.blastRadius));
    for (final d in List<Demon>.of(demons)) {
      final radius = shot.blastRadius + 14 * d.scale;
      final dx = shot.x - d.x, dy = shot.y - d.y;
      if (dx * dx + dy * dy <= radius * radius) {
        hitDemon(d, damage: shot.damage, atX: shot.x, atY: shot.y);
      }
    }
    final b = hittableBoss;
    if (b == null || !hitCarrier) return;
    // --- carrier-hatches: a blast on a vulnerable hatch.
    if (b.chapter == CarrierChapter.hatches) {
      for (final h in b.vulnerableHatches) {
        final dx = shot.x - (b.x + h.hatch.x), dy = shot.y - (b.y + h.hatch.y);
        final r = shot.blastRadius + CarrierHatches.fieldRadius;
        if (dx * dx + dy * dy <= r * r) _damageHatch(b, h, shot.damage);
      }
      return;
    }
    if (b.chapter != CarrierChapter.core) return;
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

  /// [homing]: a homing missile's heavy hit, which can break a sentinel's
  /// dive shield like an offensive module.
  ///
  /// [atX], [atY]: where the hit landed (a deflect spark is drawn there).
  void hitDemon(
    Demon d, {
    int damage = 1,
    bool homing = false,
    double? atX,
    double? atY,
  }) {
    if (!combat || damage <= 0 || d.entering || !demons.contains(d)) return;
    d.flash = .12;
    // --- sentinel rush: the berserk transformation and the rush shield.
    if (_rushShieldHit(d, damage, homing: homing, atX: atX, atY: atY)) return;
    // --- spear-bearers: a diving bearer's buckler takes it from the front.
    if (_bucklerHit(d, damage, homing: homing, atY: atY)) return;
    if (d.dive > 0 && d.diveShieldMax == 0) {
      _igniteDiveShield(d);
    }
    if (d.dive > 0 && d.diveShield > 0) {
      if (d.isLarge) {
        if (!hasOffensivePower && !homing) {
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
    // --- lightning-rework: a stunned creature's shield and armour are down.
    if (d.shield > 0 && !d.stunned) {
      d.shield = math.max(0, d.shield - damage);
      events.add('hit');
      return;
    }
    if (d.armor > 0 && !d.stunned) {
      d.armor = math.max(0, d.armor - damage);
      events.add('hit');
      return;
    }
    d.hp -= damage;
    if (d.hp <= 0) {
      final wasDiving = d.dive > 0;
      demons.remove(d);
      if (d.stunned) stunKills.add(d); // --- lightning-rework
      if (boss == null) _reinforcementCasualties++;
      kills++;
      final basePoints = _killBase(d);
      score += _bonusKillPoints((basePoints * (wasDiving ? 1.5 : 1.0)).round());
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
      if (kills % killDropEvery == 0 || (d.isLarge && wasDiving)) {
        // --- bonus levels: the rules in force may change or withhold it.
        final power = _bonusDrop(
          Power.values[(math.max(1, kills ~/ killDropEvery) - 1) %
              Power.values.length],
        );
        if (power != null) pickups.add(Pickup(d.x, d.y, power));
      }
      _groundDropOnKill(d); // --- ground war
    } else {
      events.add('hit');
      if (d.isLarge && !d.lastStand) _maybeRush(d); // --- sentinel rush
      if (d.lastStand) {
        // The rush has begun: nothing else interrupts it.
      } else if (!d.lastStand &&
          !shipAway &&
          d.angry &&
          d.dive == 0 &&
          d.telegraph <= 0 &&
          d.divePrep <= 0 &&
          (d.isLarge ||
              demons
                      .where(
                        (o) =>
                            !o.isLarge &&
                            (o.dive > 0 || o.telegraph > 0 || o.divePrep > 0),
                      )
                      .length <
                  _maxConcurrentSmallDives)) {
        _prepDive(d);
      }
    }
  }

  /// A creature's kill value before any dive bonus or bonus-level scale.
  double _killBase(Demon d) =>
      (100 + d.kind * 75 + (d.maxHp - 1) * 50) *
      (cycle + 1) *
      policy.enemyPoints;

  /// Shield can be hit across its width. Core needs an exposed central or side hatch.
  bool hitBoss(double shotX, {int damage = 1, double blastRadius = 0}) {
    final b = hittableBoss;
    if (b == null || !combat || damage <= 0) return false;
    syncChapter(b);
    // --- carrier-hatches §A3: in the hatch chapter, player shots reach the
    // hatches through [_hatchShot] (the collision rows), never through
    // here: this is the direct-damage API of fixtures and review harnesses.
    // It damages the vulnerable hatch nearest [shotX]; the last one's fall
    // and the transformation are then skipped (their events still queue),
    // so a fixture can go on into the core without advancing time.
    if (b.chapter == CarrierChapter.hatches) {
      HatchState? near;
      for (final h in b.vulnerableHatches) {
        if (near == null ||
            (shotX - (b.x + h.hatch.x)).abs() <
                (shotX - (b.x + near.hatch.x)).abs()) {
          near = h;
        }
      }
      if (near == null) return false;
      final hit = _damageHatch(b, near, damage);
      if (b.hatches.every((h) => h.destroyed)) _instantTransform(b);
      return hit;
    }
    if (b.chapter == CarrierChapter.transform) return false;
    if (b.shield > 0) {
      final impactY = b.forceFieldSurfaceY(shotX);
      final cellsBefore = Carrier.shieldCells(b.shield, b.shieldMax);
      final shieldBefore = b.shield;
      b.shield = math.max(0, b.shield - damage);
      events.add('hit');
      blasts.add(Blast(shotX, impactY));
      // carrier-v3 §10: field impacts, at most 4 per second.
      _fieldImpacts.removeWhere((t) => t <= levelClock - 1);
      if (_fieldImpacts.length < 4) {
        _fieldImpacts.add(levelClock);
        _queueGameEvent(GameEventNames.bossFieldImpact, {
          ..._carrierEventData,
          'region': CarrierRegion.at(shotX - b.x, impactY - b.y).name,
          'x': shotX,
        });
      }
      _bossDecayEvents(b, cellsBefore: cellsBefore, shieldBefore: shieldBefore);
      if (b.shield == 0) events.add('boss');
      return true;
    }
    // --- carrier-hatches §A5: the core door, wider (the only opening).
    final centerHit =
        b.door >= CarrierHatches.coreOpenAt &&
        (shotX - b.x).abs() <=
            CarrierHatches.coreWindow * b.door + blastRadius;
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
    final armourBefore = b.armourStep;
    b.core = math.max(0, b.core - damage);
    events.add('hit');
    _bossDecayEvents(b, armourBefore: armourBefore, formBefore: old);
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
      // --- cinematic flow (playtest R1): the minions that were fighting
      // die with the carrier, where they are (the scene bursts them); none
      // flees into the fog, so nothing is left in it after a boss fight.
      for (final d in demons) {
        if (d.swarmState != SwarmState.reserve &&
            !(d.entering && d.entranceProgress <= 0)) {
          d.hp = 0;
        }
      }
      demons.clear();
      shots.clear();
      pickups.clear();
      heartPickups.clear();
      ground.clearField(); // --- ground war
      clearedLevel = level;
      _enterPhase(RunMode.victory, FlowPlan.victorySeconds);
      _flowBegin(victory: true); // --- cinematic flow
      _flowRout(const []); // its minions fell with it: the fog stays empty
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
    if (!combat || invulnerable > 0 || lifeLossPhase != LifeLossPhase.none) {
      return;
    }
    if (hasPower(Power.shield)) {
      powerTimers.remove(Power.shield);
      invulnerable = 1;
      events.add('hit');
      _bonusShipHit(lost: false); // --- bonus challenges
      return;
    }
    lives--;
    bonusRun.shipsLost++; // --- bonus levels
    _bonusShipHit(lost: true); // --- bonus challenges
    pilot.reset(shipX); // --- demon intelligence
    skill.lifeLost();
    _lastSkill = skill.level;
    shipVx = shipBank = shipThrust = 0;
    steering = aimAngle = 0;
    _steeringActive = false;
    invulnerable = 2.5;
    blasts.add(Blast(shipX, shipY));
    events.add('life');
    _queueGameEvent(GameEventNames.playerDestroyed, {
      'x': shipX,
      'y': shipY,
      'lives': lives,
      'final': lives <= 0,
    });
    if (lives > 0) _beginLifeLoss(); // --- life-loss sequence
    if (lives <= 0) {
      mode = RunMode.gameOver;
      defeatTimer = defeatDuration;
      cameraPanY = 0;
      // --- cinematic flow: the swarm wins and mills over the wreck.
      flow.start(FlowPlan.gameOverOutro(reduced: reducedMotion));
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
        final orbitAngle = t * 2.2 + pairIndex * (math.pi * 2 / pairCount);
        anchorX = b.x + math.cos(orbitAngle) * 115.0;
        anchorY = b.y + math.sin(orbitAngle) * 58.0;
      } else {
        final flockPhase = t * 2.4 + pairIndex * (math.pi * 2 / pairCount);
        anchorX = 180.0 + math.sin(flockPhase) * 105.0;
        anchorY = 220.0 + math.sin(flockPhase * 2) * 55.0;
      }

      // High-five clap oscillation: pairs approach to touch wingtips then bounce apart
      final clapPhase = (t * 4.0 + pairIndex * 1.4) % (math.pi * 2);
      final separation = (math.cos(clapPhase) * 0.5 + 0.5) * 26.0 + 4.0;
      var targetX = anchorX + (isSecond ? separation * 0.5 : -separation * 0.5);
      var targetY =
          anchorY +
          (isSecond ? math.sin(t * 5.0) * 2.5 : -math.sin(t * 5.0) * 2.5);
      // --- cinematic flow (design §4.2): the celebration gathers into a
      // slow torus over the wreck (omega 0.5), then breaks upward with the
      // pan. Reduced motion: a still ring.
      final mill = flow.env('mill');
      if (mill > 0 || flow.env('break') > 0) {
        final a =
            i / smalls.length * 2 * math.pi + flow.env('spin') * elapsed * .5;
        final r = 64 + (i % 3) * 10.0;
        final mx = shipX.clamp(90.0, width - 90) + math.cos(a) * r;
        final my = shipY - 120 + math.sin(a) * r * .38;
        targetX += (mx - targetX) * mill;
        targetY += (my - targetY) * mill;
        targetY -= 260 * flow.env('break') * (1 + (i % 4) * .15);
      }

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
      d.rushPhase = RushPhase.none;
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
