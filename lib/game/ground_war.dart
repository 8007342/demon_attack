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

/// Where a ground object stands on screen. THE single projection from the
/// logical ground position (band [side], [across] the band, depth [z],
/// authored width in texels) to the screen: every unit, ally and wreck reads
/// its `x`, `y`, `scale` and `width` through it, and nothing else computes
/// ground screen positions. A visual terrain layer (heightfield, valleys)
/// can wrap this one function; gameplay stays on logical depth and lane.
typedef GroundPlace = ({double x, double y, double scale, double width});

abstract final class GroundPlacement {
  static GroundPlace place(
    int side,
    double across,
    double z,
    double widthTexels,
  ) {
    final scale = GroundCamera.texel(z) * GroundTuning.unitScale;
    final width = widthTexels * scale;
    return (
      x: GroundCamera.bandX(side, across, width),
      y: GroundCamera.yOf(z),
      scale: scale,
      width: width,
    );
  }

  // --- ground war v4: full-width placement at screen x [x] (the unit
  // manoeuvres across the whole ground plane, not only its side band).
  static GroundPlace placeAt(
    double x,
    double z,
    double widthTexels, {
    double scale = 1,
  }) {
    final s = GroundCamera.texel(z) * GroundTuning.unitScale * scale;
    return (x: x, y: GroundCamera.yOf(z), scale: s, width: widthTexels * s);
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
  static const allyWidthTexels = 26.0;

  // Firing.
  static const telegraph = 1.1; // launcher raise (first half) + glow

  /// How far ahead of a launch the radio is warned (`groundFirePrep`), so
  /// its full missile warning ends on the launch. The warning is predicted
  /// from the reload and the approach to fire range; firing itself is
  /// unchanged (reload 3.2 s + tell 1.1 s).
  static const firePrep = 1.4;

  /// Seconds of warning before the launch (prep + the visible tell).
  static const fireLead = firePrep + telegraph;
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

  // Allies: a convoy holding station in the near ground band (about the
  // ship's depth, z 199), advancing up the plane only to attack.
  static const allyHp = 8;
  static const allyLead = 110.0; // legacy pairing offset (tests, renders)
  static const allyHoldZ = 250.0; // station of the first ally on a side
  static const allyHoldStep = 38.0; // the second ally sits a little further
  static const allyStandoff = 300.0; // engaged: this far short of its foe
  static const allyMaxAdvanceZ = 620.0; // never further up the plane
  static const allyAdvanceSpeed = 150.0; // texels/s toward the foe
  static const allyFallBackSpeed = 90.0; // texels/s back to station
  static const allyRollInZ = 150.0; // reinforcements roll in from below
  static const alliesPerSide = 2;
  static const allyRecoil = .14;
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

  /// Ground targets: a long ballistic arc that climbs away from the ship,
  /// arcs out and dives into the perspective ground plane. Flight seconds
  /// = base + perDepth x (target depth - ship depth) / 1000.
  static const homingGroundBase = .95, homingGroundPerDepth = .55;
  static const homingGroundMax = 1.75;
  static const homingGroundClimb = 150.0; // climb above the launch point
  static const homingGroundApex = 95.0; // apex above the ground contact

  /// Depth of the ship's own plane on the ground (y = shipY).
  static double get shipZ => GroundCamera.zOf(ArcadeModel.shipY);

  static double homingGroundFlight(double z) =>
      (homingGroundBase + homingGroundPerDepth * math.max(0, z - shipZ) / 1000)
          .clamp(homingGroundBase, homingGroundMax);

  // Breakthrough visibility.
  /// Sector 2: units the allies stop only this close to the fire line.
  static const nearMissMarginZ = 22.0;
  static const nearMissChance = .55;

  /// Sectors 3-4: if nothing has broken through this many combat seconds
  /// into the level, the next arrival is unescorted and out of homing lock
  /// until it reaches fire range (a guaranteed, telegraphed breakthrough).
  static const guaranteeAfter = 9.0;

  /// `groundBreakthroughWarning` this many seconds before fire range.
  static const warningLead = 3.0;

  // Drops. Homing missiles matter when a breakthrough looms: a high chance
  // per kill while a demon unit threatens to (or did) reach fire range, a
  // short pity timer and an airdrop fallback. Otherwise they are an ordinary
  // pickup every [ordinaryDropEvery] kills (at 20, 60, 100, ...), the same
  // cadence as each module in the eight-kill rotation.
  static double threatDropChance(Difficulty d) => switch (d) {
    Difficulty.easy => .3,
    Difficulty.normal => .25,
    Difficulty.hard => .2,
  };

  /// Seconds of breakthrough threat without homing before a drop is due.
  static double pityTime(Difficulty d) => switch (d) {
    Difficulty.easy => 3,
    Difficulty.normal => 4,
    Difficulty.hard => 5,
  };

  /// After the pity time, the fleet air-drops one if no kill delivers it.
  static const pityAirdrop = 3.0;
  static const ordinaryDropEvery = 40;

  /// Depth from which a threatened pair calls for help.
  static const callZ = 1000.0;

  /// Allied fire interval: 0.69 s at full strength, about 1.1 s at 0.2.
  static double allyFireEvery(double strength) => .9 / (.7 + .6 * strength);

  /// Demon fire interval at its ally (before the hostile rate).
  static double demonFireEvery(double pressure) =>
      demonTracerEvery / (.8 + .6 * pressure);
}

/// The ground front of one sector: a time-based schedule, independent of
/// how fast the air waves are cleared, modulated by [GroundWar.pressure] and
/// [GroundWar.alliedStrength].
class GroundFront {
  const GroundFront({
    required this.presence,
    required this.interval,
    required this.firstDelay,
    required this.demonHp,
    required this.breakthroughs,
    required this.baseStrength,
    required this.basePressure,
    required this.shots,
    this.skirmish = SkirmishFront.none,
  });
  static const none = GroundFront(
    presence: 0,
    interval: 0,
    firstDelay: 0,
    demonHp: 1,
    breakthroughs: false,
    baseStrength: 1,
    basePressure: 0,
    shots: 0,
  );

  /// Demon units kept alive at once (one more under high pressure).
  final int presence;

  /// Seconds between arrivals at pressure 0.5 (shorter as pressure rises),
  /// and the combat seconds into the level before the first one.
  final double interval, firstDelay;

  /// Allied hits a demon unit can take.
  final int demonHp;

  /// False: allies always stop demon units before fire range (sectors 1-2).
  final bool breakthroughs;

  /// Where allied strength and pressure start and settle back to.
  final double baseStrength, basePressure;

  /// Missiles a broken-through unit may fire.
  final int shots;

  // --- ground war v4: the skirmish layer of this sector (ground_war_v4.dart).
  final SkirmishFront skirmish;

  bool get active => presence > 0;

  GroundFront withSkirmish(SkirmishFront s) => GroundFront(
    presence: presence,
    interval: interval,
    firstDelay: firstDelay,
    demonHp: demonHp,
    breakthroughs: breakthroughs,
    baseStrength: baseStrength,
    basePressure: basePressure,
    shots: shots,
    skirmish: s,
  );

  static GroundFront of(Difficulty d, {required int route, required int sector}) =>
      _threat(d, route: route, sector: sector).withSkirmish(
        SkirmishFront.of(d, route: route, sector: sector),
      );

  static GroundFront _threat(Difficulty d, {required int route, required int sector}) {
    if (sector < 1 ||
        sector > 4 ||
        const bool.fromEnvironment('GROUND_WAR_DISABLED')) {
      return none;
    }
    final di = d.index; // easy 0, normal 1, hard 2
    final r = math.min<int>(route, 3);
    final shots = d == Difficulty.easy ? 1 : 2;
    return switch (sector) {
      // Ambient almost from the start of Krybor: allies win every skirmish.
      1 => GroundFront(
        presence: 1,
        interval: 6,
        firstDelay: const [6.0, 6.0, 5.0][di],
        demonHp: 2,
        breakthroughs: false,
        baseStrength: 1,
        basePressure: .1,
        shots: shots,
      ),
      2 => GroundFront(
        presence: 2,
        interval: 6,
        firstDelay: 3,
        demonHp: 3,
        breakthroughs: false,
        baseStrength: .95,
        basePressure: .2,
        shots: shots,
      ),
      // Occasional breakthroughs: unescorted or out-gunned units get through.
      3 => GroundFront(
        presence: 2,
        interval: 8,
        firstDelay: 4,
        demonHp: 4 + math.min<int>(di, 1) + r,
        breakthroughs: true,
        baseStrength: const [.86, .76, .71][di] - .03 * r,
        basePressure: .35,
        shots: shots,
      ),
      // Regular breakthroughs unless the player helps.
      _ => GroundFront(
        presence: 2,
        interval: 8,
        firstDelay: 3,
        demonHp: 6 + math.min<int>(di, 1) + r,
        breakthroughs: true,
        baseStrength: const [.72, .62, .58][di] - .03 * r,
        basePressure: .5,
        shots: shots,
      ),
    };
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
    this.hp = 1,
  });
  final int id, sector, side;
  final double across;
  double z;
  int shotsLeft;

  /// Allied hits left before the unit is destroyed.
  int hp;

  /// It reached fire range alive (`groundBreakthrough`).
  bool brokeThrough = false;

  /// It is predicted to reach fire range: its ally is out-gunned or absent.
  bool threatening = false, calledForHelp = false;
  bool destroyedByAllies = false;

  /// Sector 2 drama: its ally stops it just short of fire range.
  bool nearMiss = false;

  /// Sectors 3-4: the level's guaranteed breakthrough (no ally; homing
  /// cannot lock on until it reaches fire range).
  bool guaranteed = false, warned = false;
  double telegraph = 0, cooldown = 0, fireFlash = 0, tracerLeft = .6;

  /// Whether the radio has been warned of this unit's next launch.
  bool fireWarned = false;
  bool destroyed = false, sighted = false, announcedInRange = false;
  double wreckAge = 0;
  GroundAlly? ally;

  // --- ground war v4: mixed forces, skirmishes, full-width manoeuvre.
  GroundForce force = GroundForce.vehicle;

  /// Ambient skirmish unit (ground_war_v4.dart): never fires at the player.
  bool skirmish = false;

  /// Screen x across the whole ground plane (null: legacy band placement),
  /// lateral velocity, route goal and seconds to the next route choice.
  double? lx;
  double vx = 0, goalX = 180, retarget = 0;

  /// Skirmish hold line (depth), seconds alive and seconds idle at it.
  double holdZ = 0, life = 0, idle = 0;

  /// +1 facing screen right, -1 left (the sprite mirrors).
  int facing = 1;
  int maxHp = 1;

  /// Seconds since the last allied hit (a trooper falls), -1 never.
  double lastHit = -1;

  bool get mirrored => lx == null ? side == 1 : facing < 0;

  GroundPlace get place => lx == null
      ? GroundPlacement.place(side, across, z, GroundTuning.unitWidthTexels)
      : GroundPlacement.placeAt(lx!, z, GroundV4Tuning.width(force));
  double get scale => place.scale;
  double get width => place.width;
  // --- terrain: the relief pose, when the flyover provides one.
  GroundPose? pose;
  double get x => pose?.x ?? place.x;

  /// Ground contact (the sprite's bottom row).
  double get y => pose?.y ?? place.y;

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

  /// Higher is more urgent for homing missiles: broken through, then
  /// threatening to, then about to fire, in range and reloaded soonest,
  /// then closest.
  double get threat => skirmish
      ? -10000 + (GroundTuning.spawnZ - z)
      : (brokeThrough ? 8000 : 0) +
      (threatening ? 6000 : 0) +
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

  /// Depth velocity (texels/s): > 0 advancing toward the horizon, < 0
  /// falling back, 0 holding station. Seconds of recoil after a shot.
  double vz = 0, recoil = 0;

  /// Its station in the near ground band (convoy slot).
  double holdZ = GroundTuning.allyHoldZ;

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

  // --- ground war v4: mixed convoy, full-width escort, field repairs.
  GroundForce force = GroundForce.vehicle;
  double? lx;
  double vx = 0;

  /// Escort slot; a battered ally falls back to it and repairs.
  int slot = 0;
  bool fallingBack = false;
  double repair = 0;

  GroundPlace get place => lx == null
      ? GroundPlacement.place(side, across, z, GroundTuning.allyWidthTexels)
      : GroundPlacement.placeAt(lx!, z, GroundV4Tuning.width(force, ally: true),
          scale: GroundV4Tuning.allyScale);
  double get scale => place.scale;
  double get width => place.width;
  // --- terrain: the relief pose, when the flyover provides one.
  GroundPose? pose;
  double get x => pose?.x ?? place.x;
  double get y => pose?.y ?? place.y;
  double get bodyY => y - 6 * scale;
  bool get alive => !totalled;

  /// Engaged allies are the ones asking for help.
  bool get underAttack => alive && (attacker?.alive ?? false);
}

/// Short-lived skirmish fire between a demon unit and an ally (visual; the
/// demon's tracer is what wears the ally down).
class GroundTracer {
  GroundTracer(this.fromX, this.fromY, this.toX, this.toY,
      {this.friendly = false, this.kind = bolt});
  final double fromX, fromY, toX, toY;
  final bool friendly;
  double age = 0;
  static const life = .22;

  // --- ground war v4: weapon kinds (small arms, rockets, tank shells).
  static const bolt = 0, smallArms = 1, rocket = 2, shell = 3;
  final int kind;
  double get duration => switch (kind) {
    smallArms => .14,
    rocket => .6,
    shell => .3,
    _ => life,
  };
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

/// A smoke puff left by a homing missile; [size] is the perspective scale
/// where it was laid (1 at the ship's depth). Visual only.
class HomingPuff {
  HomingPuff(this.x, this.y, this.size);
  final double x, y, size;
  double age = 0;
  static const life = .55;
}

/// One homing missile from the player's rack.
///
/// Air targets: fast, direct steering. Ground targets: a long ballistic
/// arc ([groundFlight] seconds) that climbs away from the ship, arcs out and
/// dives into the perspective ground plane, shrinking with distance
/// ([depth], [perspective]) and impacting at the unit's ground position.
class HomingMissile {
  HomingMissile(this.x, this.y, this.vx, this.vy, this.side);
  double x, y, vx, vy;
  final int side;
  double age = 0;
  Object? target;
  HomingTargetKind? kind;
  double get heading => math.atan2(vx, -vy);

  /// Ground flight: total seconds (null for air flight) and elapsed.
  double? groundFlight;
  double groundAge = 0;

  /// Where the current ground arc started (screen).
  double x0 = 0, y0 = 0;

  /// Perceived depth on the ground plane (texels), for the size.
  double depth = 0;
  double _puffClock = 0;
  final List<HomingPuff> trail = [];

  bool get toGround => groundFlight != null;

  /// 0 at launch, 1 at impact (ground flight only).
  double get groundProgress => toGround
      ? (groundAge / groundFlight!).clamp(0.0, 1.0)
      : 0;

  /// Drawn scale relative to the ship's depth: 1 at launch, smaller as the
  /// missile flies into the distance.
  double get perspective => toGround
      ? (GroundCamera.texel(depth) / GroundCamera.texel(GroundTuning.shipZ))
            .clamp(.18, 1.0)
      : 1.0;
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

// --- terrain ---------------------------------------------------------------
// The flyover's relief (lib/game/terrain_field.dart) may place ground objects
// on its hills and valleys. Visual and positional only: the fire range gate,
// breakthroughs and collisions read z, side and across, never a pose.

/// Where the relief puts a ground object: screen ground contact, the slope
/// along its travel (> 0 uphill toward the camera) and a visual pace.
class GroundPose {
  const GroundPose(this.x, this.y, {this.climb = 0, this.pace = 1});
  final double x, y, climb, pace;
}

/// Installed by the scene as [GroundWar.relief]; null keeps flat ground.
abstract interface class GroundRelief {
  GroundPose place(int side, double across, double width, double z,
      {bool ally = false});

  // --- ground war v4: full-width placement and route costs.
  GroundPose placeAt(double x, double z);

  /// Displayed terrain height (texels) at screen [x] and depth [z].
  double heightAt(double x, double z);
}
// --- end terrain -------------------------------------------------------------

/// All ground-war state, owned by [ArcadeModel.ground].
class GroundWar {
  // --- terrain: optional relief (visual and positional only).
  GroundRelief? relief;

  final List<GroundUnit> units = [];
  final List<GroundAlly> allies = [];
  final List<GroundMissile> missiles = [];
  final List<GroundTracer> tracers = [];
  final List<HomingPickup> pickups = [];

  /// Smoke left by finished homing missiles (fades out).
  final List<HomingPuff> homingSmoke = [];
  final HomingSalvo salvo = HomingSalvo();
  final List<GameEvent> events = [];
  GroundFront front = GroundFront.none;

  // --- ground war v4: the skirmish layer and its tallies.
  final GroundSkirmish skirmish = GroundSkirmish();

  /// Ally-foe engagements begun on screen (threat and skirmish), this run.
  int engagements = 0;
  int nextId = 0, ordinal = 0;
  double spawnLeft = 0;

  /// Seconds of breakthrough threat without homing (pity timer).
  double pityClock = 0;

  /// The ground pressure meter, 0 (quiet) to 1 (front collapsing): live and
  /// threatening demon units, breakthroughs and level progress push it up;
  /// allied strength above the sector's base pulls it down. It shortens the
  /// arrival interval and speeds the demons' fire. Music: `groundPressure`.
  double pressure = 0;
  int _pressureStep = -1;

  /// Allied strength, 0.2-1: the chance a demon unit is met by an ally and
  /// how fast allies fire. Player help (homing kills, saves) and allied wins
  /// raise it; retreats and breakthroughs lower it; it settles toward the
  /// sector's base.
  double alliedStrength = 1;

  // Run statistics (tests, profiler, an "allies held" tally).
  int unitsSpawned = 0, unitsDestroyed = 0, missilesLaunched = 0;
  int missileImpacts = 0, homingCollected = 0, homingHits = 0;
  int unitsKilledByAllies = 0, breakthroughs = 0;

  /// Per sector index 0-4: breakthroughs and missile hits on the ship
  /// (counted even while invulnerable: "would-be hits").
  final List<int> breakthroughsBySector = List.filled(5, 0);
  final List<int> impactsBySector = List.filled(5, 0);
  /// Sector 2 near misses (per sector index) and this level's breakthrough
  /// guarantee (sectors 3-4).
  final List<int> nearMissesBySector = List.filled(5, 0);
  bool levelBrokeThrough = false, guaranteeSpawned = false;
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
    homingSmoke.clear();
    salvo
      ..remaining = 0
      ..active = null
      ..gap = 0;
    pityClock = 0;
    levelBrokeThrough = guaranteeSpawned = false;
  }

  void resetRun() {
    clearField();
    events.clear();
    nextId = ordinal = 0;
    unitsSpawned = unitsDestroyed = missilesLaunched = 0;
    missileImpacts = homingCollected = homingHits = 0;
    unitsKilledByAllies = breakthroughs = 0;
    breakthroughsBySector.fillRange(0, 5, 0);
    impactsBySector.fillRange(0, 5, 0);
    nearMissesBySector.fillRange(0, 5, 0);
    alliesSaved = alliesRetreated = alliesEngaged = 0;
    alliesSavedThisLevel = alliesRetreatedThisLevel = alliesEngagedThisLevel = 0;
    wingmatesLost = wingmatesLostThisLevel = 0;
    engagements = 0;
    skirmish
      ..reset()
      ..spawned = 0
      ..killedByAllies = 0
      ..killedByHoming = 0
      ..artillery = 0
      ..fallBacks = 0;
  }
}

extension GroundWarSimulation on ArcadeModel {
  void _groundEvent(String name, [Map<String, Object?> data = const {}]) =>
      ground.events.add(GameEvent(name, {'sector': level, ...data}));

  /// New level (or restored entrance): nothing carries over.
  void _groundBeginLevel() {
    ground.clearField();
    final front = GroundFront.of(difficulty, route: cycle, sector: level);
    ground
      ..front = front
      ..spawnLeft = front.firstDelay
      ..alliedStrength = front.baseStrength
      ..pressure = front.basePressure
      .._pressureStep = -1;
    ground.alliesSavedThisLevel = ground.alliesRetreatedThisLevel = 0;
    ground.alliesEngagedThisLevel = ground.wingmatesLostThisLevel = 0;
    _v4BeginLevel();
    if (front.active || front.skirmish.active) {
      // The convoy: one ally per side already on station under our cover.
      for (final side in const [0, 1]) {
        _newConvoyAlly(side, rollIn: false);
      }
    }
  }

  /// A convoy ally on [side]: on station, or rolling in from below.
  GroundAlly _newConvoyAlly(int side, {bool rollIn = true}) {
    // --- ground war v4: escort slots across the width around the ship.
    if (ground.front.skirmish.active) return _v4NewConvoyAlly(rollIn: rollIn);
    final g = ground;
    final slot = g.allies.where((a) => a.alive && a.side == side).length;
    final hold = GroundTuning.allyHoldZ +
        GroundTuning.allyHoldStep * math.min(slot, GroundTuning.alliesPerSide);
    final ally = GroundAlly(
      g.nextId++,
      level - 1,
      side,
      slot.isEven ? .3 : .72,
      rollIn ? GroundTuning.allyRollInZ : hold + (side == 0 ? 0 : 14),
      GroundTuning.allyHp,
    )..holdZ = hold + (side == 0 ? 0 : 14);
    g.allies.add(ally);
    return ally;
  }

  /// The ally that meets a new demon unit on [side]: an idle convoy ally,
  /// or a reinforcement rolling in from below the screen.
  GroundAlly _assignAlly(GroundUnit unit) {
    GroundAlly? idle;
    for (final a in ground.allies) {
      if (!a.alive || a.side != unit.side) continue;
      if (a.attacker?.alive ?? false) continue;
      if (idle == null || a.holdZ < idle.holdZ) idle = a;
    }
    final ally = idle ?? _newConvoyAlly(unit.side);
    ally
      ..attacker = unit
      ..hp = GroundTuning.allyHp // field repairs between skirmishes
      ..announced = false
      ..saved = false
      ..fireLeft = .3;
    unit.ally = ally;
    return ally;
  }

  /// Wave entrance: in-flight hostile missiles never cross a wave boundary.
  /// The ground front itself ignores air waves (time-based schedule).
  void _groundBeginWave() {
    ground.missiles.clear();
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
      if (u.skirmish) continue; // --- ground war v4 (_v4Update)
      u.z -= u.z > GroundTuning.fireZ ? speedFar : speedNear;
      u.fireFlash = math.max(0, u.fireFlash - dt);
      if (!ground.front.breakthroughs &&
          u.z <=
              GroundTuning.fireZ +
                  (u.nearMiss ? GroundTuning.nearMissMarginZ : 80)) {
        // Sectors 1-2: the allies always finish a unit before fire range;
        // in sector 2 some only just short of it (a near miss).
        if (u.nearMiss) {
          ground.nearMissesBySector[(level - 1).clamp(0, 4)]++;
          _groundEvent(GameEventNames.groundNearMiss, {
            'x': u.x,
            'y': u.y,
            'marginZ': double.parse(
              (u.z - GroundTuning.fireZ).toStringAsFixed(1),
            ),
          });
        }
        _destroyGroundUnit(u, byAllies: true);
        continue;
      }
      if (!u.brokeThrough && u.z <= GroundTuning.fireZ) {
        u.brokeThrough = true;
        u.threatening = false;
        ground.levelBrokeThrough = true;
        ground.breakthroughs++;
        ground.breakthroughsBySector[(level - 1).clamp(0, 4)]++;
        _adjustStrength(-.02);
        _groundEvent(GameEventNames.groundBreakthrough, {'x': u.x, 'y': u.y});
      }
      _predictBreakthrough(u);
      if (u.threatening && !u.warned) {
        final toFire = (u.z - GroundTuning.fireZ) /
            (GroundTuning.approachSpeed * rate);
        if (toFire <= GroundTuning.warningLead) {
          u.warned = true;
          _groundEvent(GameEventNames.groundBreakthroughWarning, {
            'x': u.x,
            'y': u.y,
            'secondsToBreakthrough': toFire,
            'guaranteed': u.guaranteed,
          });
        }
      }
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
    _v4Update(dt); // --- ground war v4: skirmishes and manoeuvre
    _updateAllies(dt);
    for (final t in ground.tracers) {
      t.age += dt;
    }
    ground.tracers.removeWhere((t) => t.age > t.duration);
    ground.units.removeWhere(
      (u) => u.z < GroundTuning.leaveZ || (u.destroyed && u.wreckAge > 6),
    );
    _updateGroundMissiles(dt);
    _updateHomingSalvo(dt);
    _updatePressureMeter(dt);
    _updateHomingPity(dt);
    _placeGroundOnTerrain();
  }

  // --- terrain: refresh every ground object's relief pose once per step.
  void _placeGroundOnTerrain() {
    final relief = ground.relief;
    for (final u in ground.units) {
      final lx = u.lx;
      u.pose = lx != null
          ? relief?.placeAt(lx, u.z)
          : relief?.place(u.side, u.across, u.width, u.z);
    }
    for (final a in ground.allies) {
      final lx = a.lx;
      a.pose = lx != null
          ? relief?.placeAt(lx, a.z)
          : relief?.place(a.side, a.across, a.width, a.z, ally: true);
    }
  }

  void _adjustStrength(double delta) =>
      ground.alliedStrength = (ground.alliedStrength + delta).clamp(.2, 1.0);

  double get _allyFireEvery =>
      GroundTuning.allyFireEvery(ground.alliedStrength);
  double get _demonFireEvery =>
      GroundTuning.demonFireEvery(ground.pressure) / policy.hostileRate;

  /// Will [u] reach fire range alive? If so its ally (or, unescorted, the
  /// nearest allies) call for help once: `allyUnderAttack`.
  void _predictBreakthrough(GroundUnit u) {
    if (!ground.front.breakthroughs || u.brokeThrough || u.destroyed) {
      u.threatening = false;
      return;
    }
    final toFire = (u.z - GroundTuning.fireZ) /
        (GroundTuning.approachSpeed * policy.hostileRate);
    final ally = u.ally;
    if (ally == null || !ally.alive) {
      u.threatening = true;
    } else {
      final kill = u.hp * _allyFireEvery;
      final survive = ally.hp * _demonFireEvery;
      u.threatening = kill > toFire || survive < kill;
    }
    if (u.threatening && !u.calledForHelp && u.z <= GroundTuning.callZ) {
      u.calledForHelp = true;
      final a = (ally != null && ally.alive) ? ally : null;
      _groundEvent(GameEventNames.allyUnderAttack, {
        'x': a?.x ?? u.x,
        'y': a?.y ?? u.y,
        'unescorted': a == null,
        'secondsToBreakthrough': toFire,
      });
    }
  }

  void _updatePressureMeter(double dt) {
    final g = ground, f = g.front;
    if (!f.active) return;
    var live = 0, threat = 0, broken = 0;
    for (final u in g.units) {
      if (!u.alive || u.skirmish) continue;
      live++;
      if (u.threatening) threat++;
      if (u.brokeThrough) broken++;
    }
    final progress = (levelClock / (wavesPerLevel * 20.0)).clamp(0.0, 1.0);
    var target = f.basePressure +
        .05 * math.min(cycle, 3) +
        .08 * live +
        .12 * threat +
        .1 * broken +
        .12 * progress -
        .6 * (g.alliedStrength - f.baseStrength);
    if (!f.breakthroughs) target = math.min(target, .45);
    target = target.clamp(0.0, 1.0);
    g.pressure += (target - g.pressure) * math.min(1.0, dt * .7);
    // Allied strength drifts back toward the sector's base.
    g.alliedStrength += (f.baseStrength - g.alliedStrength) * dt * .02;
    final step = (g.pressure * 10).floor().clamp(0, 10);
    if (step != g._pressureStep) {
      g._pressureStep = step;
      _groundEvent(GameEventNames.groundPressure, {
        'level': double.parse(g.pressure.toStringAsFixed(2)),
      });
    }
  }

  void _spawnGroundUnits(double dt) {
    final g = ground, f = g.front;
    if (!f.active) return;
    g.spawnLeft -= dt;
    if (g.spawnLeft > 0) return;
    final cap = f.presence + (g.pressure > .75 ? 1 : 0);
    if (g.liveUnits.where((u) => !u.skirmish).length >= cap) return;
    // One breakthrough at a time: the front holds new arrivals while a
    // broken-through unit can still fire, so slower players aren't swamped.
    if (g.units.any((u) => u.alive && u.brokeThrough && u.shotsLeft > 0)) return;
    g.spawnLeft = f.interval / (.7 + .6 * g.pressure);
    g.unitsSpawned++;
    final ordinal = g.ordinal++;
    final side = (ordinal + level + cycle).isEven ? 0 : 1;
    final across = .15 + random.nextDouble() * .6;
    final unit = GroundUnit(
      g.nextId++,
      level - 1,
      side,
      across,
      GroundTuning.spawnZ,
      shotsLeft: f.shots,
      hp: f.demonHp,
    )..cooldown = .4;
    // --- ground war v4: it enters at its band but manoeuvres across the
    // whole plane (positional only: the rules read z).
    if (f.skirmish.active) {
      final x = GroundCamera.bandX(side, across, unit.width);
      unit
        ..lx = x
        ..goalX = x
        ..retarget = 1
        ..facing = side == 0 ? 1 : -1;
    }
    g.units.add(unit);
    // The level's guaranteed breakthrough (sectors 3-4): if nothing has
    // got through yet, this arrival is unescorted and out of homing lock
    // until it reaches fire range. Telegraphed by `allyUnderAttack`
    // (unescorted) and `groundBreakthroughWarning`.
    if (f.breakthroughs &&
        !g.levelBrokeThrough &&
        !g.guaranteeSpawned &&
        levelClock >= GroundTuning.guaranteeAfter) {
      g.guaranteeSpawned = true;
      unit.guaranteed = true;
      return;
    }
    // Sector 2: some skirmishes end only just short of the fire line.
    if (!f.breakthroughs &&
        level == 2 &&
        random.nextDouble() < GroundTuning.nearMissChance) {
      unit.nearMiss = true;
    }
    // Without breakthroughs every unit meets an ally; later, the allies are
    // stretched as thin as their strength.
    if (!f.breakthroughs || random.nextDouble() < g.alliedStrength) {
      _assignAlly(unit);
    }
  }

  void _updateGroundFire(GroundUnit u, double dt) {
    if (shipAway) {
      // The regroup holds ground fire too (life-loss sequence).
      u.telegraph = 0;
      u.fireWarned = false;
      return;
    }
    if (u.telegraph > 0) {
      u.telegraph -= dt;
      if (u.telegraph <= 0) {
        u.telegraph = 0;
        _launchGroundMissile(u);
      }
      return;
    }
    u.cooldown = math.max(0, u.cooldown - dt);
    // Warn the radio ahead of the next launch so the full clip ends on it.
    // Predicted from the reload and the approach (both in hostile-rate
    // time, like dt here); a launch that slips (missile cap, another tell)
    // just lands a little after its warning.
    if (!u.fireWarned &&
        u.alive &&
        u.shotsLeft > 0 &&
        u.z >= GroundTuning.lastFireZ) {
      final toRange = u.z > GroundTuning.fireZ
          ? (u.z - GroundTuning.fireZ) / GroundTuning.approachSpeed
          : 0.0;
      final fireIn = (math.max(u.cooldown, toRange) + GroundTuning.telegraph) /
          policy.hostileRate;
      if (fireIn <= GroundTuning.fireLead) {
        u.fireWarned = true;
        _groundEvent(GameEventNames.groundFirePrep, {
          'x': u.x,
          'y': u.y,
          'fireIn': fireIn,
        });
      }
    }
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
    u.fireWarned = false;
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
        ground.impactsBySector[(level - 1).clamp(0, 4)]++;
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
      a.recoil = math.max(0, a.recoil - dt);
      if (a.totalled) {
        // Limping off: drift to the outer edge and drop back down the plane.
        a.retreatAge += dt;
        a.vz = -GroundTuning.creepSpeed * rate;
        a.across = math.max(-1.2, a.across - .45 * dt);
        a.z += a.vz * dt;
        continue;
      }
      a.flash = math.max(0, a.flash - dt);
      final foe = a.attacker;
      final engaged = foe != null && foe.alive;
      // Station keeping: hold in the near band beside the ship; advance up
      // the plane only to meet the foe, then fall back to escort position.
      final want = engaged
          ? (foe.z -
                    (foe.skirmish
                        ? GroundV4Tuning.standoff
                        : GroundTuning.allyStandoff))
                .clamp(
              a.holdZ,
              GroundTuning.allyMaxAdvanceZ,
            )
          : a.holdZ;
      final dz = want - a.z;
      final speed = dz > 0
          ? GroundTuning.allyAdvanceSpeed
          : GroundTuning.allyFallBackSpeed;
      final step = dz.clamp(-speed * dt, speed * dt);
      a.z += step;
      a.vz = dz.abs() < .5 ? 0 : step / math.max(dt, 1e-6);
      if (!engaged) continue;
      if (foe.skirmish) {
        _v4AllyFight(a, foe, dt); // --- ground war v4
        continue;
      }
      if (!a.announced && foe.z <= GroundTuning.sightZ) {
        a.announced = true;
        ground.alliesEngaged++;
        ground.alliesEngagedThisLevel++;
        ground.engagements++;
      }
      foe.tracerLeft -= dt * rate;
      if (foe.tracerLeft <= 0 && a.announced) {
        foe.tracerLeft = _demonFireEvery * rate;
        ground.tracers.add(GroundTracer(foe.x, foe.bodyY, a.x, a.bodyY));
        a.hp--;
        a.flash = .15;
        if (a.hp <= 0) {
          a.totalled = true;
          ground.alliesRetreated++;
          ground.alliesRetreatedThisLevel++;
          _adjustStrength(-.08);
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
        a.fireLeft = _allyFireEvery;
        a.recoil = GroundTuning.allyRecoil;
        ground.tracers.add(
          GroundTracer(a.x, a.bodyY, foe.x, foe.bodyY, friendly: true),
        );
        foe.hp--;
        if (foe.hp <= 0) {
          if (foe.nearMiss &&
              foe.z > GroundTuning.fireZ + GroundTuning.nearMissMarginZ) {
            // A near miss: it limps on, smoking, to just short of the line.
            foe.hp = 1;
          } else {
            // The allies win this skirmish on their own.
            _destroyGroundUnit(foe, byAllies: true);
          }
        }
      }
    }
    ground.allies.removeWhere(
      (a) =>
          a.totalled &&
          (a.retreatAge > 3.5 ||
              a.z < GroundTuning.leaveZ ||
              a.x < -40 ||
              a.x > ArcadeModel.width + 40),
    );
  }

  void _destroyGroundUnit(GroundUnit u, {bool byAllies = false}) {
    if (u.destroyed) return;
    if (u.skirmish) return _v4Destroy(u, byAllies: byAllies);
    u.destroyed = true;
    u.destroyedByAllies = byAllies;
    u.telegraph = 0;
    u.threatening = false;
    ground.unitsDestroyed++;
    if (byAllies) {
      ground.unitsKilledByAllies++;
      _adjustStrength(.03);
    } else {
      score += ((400 + 100 * u.sector) * (cycle + 1) * policy.enemyPoints).round();
      _adjustStrength(.08); // the player's help pushes the allies ahead
    }
    // The explosion, shock ring, debris and scorch are drawn on the ground
    // plane by GroundPainter (perspective-scaled), not as an air blast.
    events.add('groundExplosion');
    _groundEvent(GameEventNames.groundUnitDestroyed, {
      'x': u.x,
      'y': u.y,
      'by': byAllies ? 'allies' : 'homing',
      'brokeThrough': u.brokeThrough,
    });
    final ally = u.ally;
    if (!byAllies && ally != null && ally.alive && ally.announced) {
      // Positive only: a bonus and a tally, never a penalty.
      ally.saved = true;
      ground.alliesSaved++;
      ground.alliesSavedThisLevel++;
      _adjustStrength(.04);
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
    ground.pityClock = 0;
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
      // The guaranteed breakthrough is out of lock until it gets through.
      if (u.guaranteed && !u.brokeThrough) continue;
      // --- ground war v4: skirmish units never threaten the ship and are
      // not homing targets: the salvo stays for threats and the air war
      // (so the skirmish layer cannot change either).
      if (u.skirmish) continue;
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

  /// Points the missile's ground arc at its (ground) target from where it
  /// is now: a long climb away from the ship, out and down into the plane.
  void _beginGroundFlight(
    HomingMissile h,
    GroundUnit u, {
    double fraction = 1,
  }) {
    h
      ..x0 = h.x
      ..y0 = h.y
      ..groundAge = 0
      ..groundFlight = GroundTuning.homingGroundFlight(u.z) * fraction
      ..depth = h.depth == 0 ? GroundTuning.shipZ : h.depth;
  }

  /// Screen point and depth on the ground arc at progress [p] toward [u]:
  /// a cubic curve from the launch point, up and away (climb), out over the
  /// unit's band (apex) and down onto its ground contact.
  (double, double, double) groundArcAt(
    HomingMissile h,
    GroundUnit u,
    double p,
  ) {
    final tx = u.x, ty = u.y - 2 * u.scale;
    final outward = u.side == 0 ? -1.0 : 1.0;
    final p1x = h.x0 + h.side * 34;
    final p1y = h.y0 - GroundTuning.homingGroundClimb;
    final p2x = tx + outward * 26;
    final p2y = math.min(ty - GroundTuning.homingGroundApex, p1y + 30);
    final q = 1 - p;
    final a = q * q * q, b = 3 * q * q * p, c = 3 * q * p * p, d = p * p * p;
    final x = a * h.x0 + b * p1x + c * p2x + d * tx;
    final y = a * h.y0 + b * p1y + c * p2y + d * ty;
    final startZ = GroundTuning.shipZ;
    final ease = p * p * (3 - 2 * p);
    return (x, y, startZ + (u.z - startZ) * ease);
  }

  void _homingPuffs(HomingMissile h, double dt) {
    for (final puff in h.trail) {
      puff.age += dt;
    }
    h.trail.removeWhere((puff) => puff.age > HomingPuff.life);
    h._puffClock -= dt;
    if (h._puffClock <= 0) {
      h._puffClock = .016;
      h.trail.add(HomingPuff(h.x, h.y, h.perspective));
    }
  }

  void _endHoming(HomingSalvo salvo) {
    final h = salvo.active;
    if (h != null && h.trail.isNotEmpty) {
      ground.homingSmoke.addAll(h.trail);
    }
    salvo
      ..active = null
      ..gap = GroundTuning.homingGap;
  }

  void _updateHomingSalvo(double dt) {
    final salvo = ground.salvo;
    for (final puff in ground.homingSmoke) {
      puff.age += dt;
    }
    ground.homingSmoke.removeWhere((puff) => puff.age > HomingPuff.life);
    var h = salvo.active;
    if (h == null) {
      if (salvo.remaining <= 0) return;
      if (shipAway) return; // the rack waits for the reserve ship
      salvo.gap -= dt;
      if (salvo.gap > 0) return;
      final pick = pickHomingTarget();
      if (pick == null) return; // hold the salvo until something appears
      final side = salvo.launched.isEven ? -1 : 1;
      h = HomingMissile(
        shipX + side * 11.0,
        ArcadeModel.shipY - 4,
        side * 50.0,
        -230,
        side,
      )
        ..target = pick.$1
        ..kind = pick.$2;
      if (pick.$1 case final GroundUnit u) _beginGroundFlight(h, u);
      salvo
        ..active = h
        ..remaining -= 1
        ..launched += 1;
      events.add('homingLock');
      _groundEvent(GameEventNames.homingLaunch, {
        'target': pick.$2.name,
        if (h.toGround) 'flight': h.groundFlight,
      });
      return;
    }
    h.age += dt;
    _homingPuffs(h, dt);
    if (!_homingTargetValid(h)) {
      final pick = pickHomingTarget();
      h.target = pick?.$1;
      h.kind = pick?.$2;
      if (pick?.$1 case final GroundUnit u) {
        // Re-aim the dive at the next ground unit from here.
        _beginGroundFlight(h, u, fraction: .7);
      } else if (h.toGround) {
        h.groundFlight = null; // back to fast air steering
      }
    }
    if (h.target case final GroundUnit u when h.toGround) {
      h.groundAge += dt;
      final p = h.groundProgress;
      final (x, y, z) = groundArcAt(h, u, p);
      final (nx, ny, _) = groundArcAt(h, u, math.min(1.0, p + .02));
      final dx = nx - x, dy = ny - y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 1e-6) {
        h.vx = dx / len * 300;
        h.vy = dy / len * 300;
      }
      h
        ..x = x
        ..y = y
        ..depth = z;
      if (p >= 1) {
        _homingImpact(h);
        _endHoming(salvo);
      }
      return;
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
        HomingTargetKind.carrierCore || HomingTargetKind.carrierShield => 22.0,
        HomingTargetKind.sentinel => 22.0,
        _ => 16.0,
      };
      final dx = tx - h.x, dy = ty - h.y;
      if (dx * dx + dy * dy <= reach * reach) {
        _homingImpact(h);
        _endHoming(salvo);
        return;
      }
    }
    if (h.age > GroundTuning.homingMaxAge ||
        h.y < -40 ||
        h.y > ArcadeModel.height + 40 ||
        h.x < -40 ||
        h.x > ArcadeModel.width + 40) {
      _endHoming(salvo);
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
  // Drops: homing missiles are urgent when a breakthrough looms (high chance
  // per kill, pity timer, airdrop) and an ordinary pickup otherwise.
  // -------------------------------------------------------------------------

  bool get _homingAvailable =>
      ground.pickups.isNotEmpty || ground.salvo.busy;

  /// A demon unit is threatening to break through, or has and can still fire.
  bool get groundBreakthroughThreat => ground.units.any(
    (u) => u.alive && (u.threatening || (u.brokeThrough && u.shotsLeft > 0)),
  );

  void _updateHomingPity(double dt) {
    if (_homingAvailable || !groundBreakthroughThreat) {
      ground.pityClock = 0;
      return;
    }
    ground.pityClock += dt;
    if (ground.pityClock >=
        GroundTuning.pityTime(difficulty) + GroundTuning.pityAirdrop) {
      // No kill delivered it: the fleet air-drops one into the firing lane.
      _dropHoming(110 + random.nextDouble() * 140, 150);
    }
  }

  /// Called for every ordinary kill (after the existing drop rules).
  void _groundDropOnKill(Demon d) {
    if (_homingAvailable) return;
    if (groundBreakthroughThreat) {
      final pityDue = ground.pityClock >= GroundTuning.pityTime(difficulty);
      if (pityDue ||
          random.nextDouble() < GroundTuning.threatDropChance(difficulty)) {
        _dropHoming(d.x, d.y);
      }
      return;
    }
    if (kills % GroundTuning.ordinaryDropEvery ==
        GroundTuning.ordinaryDropEvery ~/ 2) {
      _dropHoming(d.x, d.y);
    }
  }

  void _dropHoming(double x, double y) {
    // Offset from a same-kill power pickup so both stay readable.
    final clash = pickups.any((p) => (p.x - x).abs() < 20 && (p.y - y).abs() < 20);
    ground.pickups.add(HomingPickup((x + (clash ? 24 : 0)).clamp(20, ArcadeModel.width - 20), y));
    ground.pityClock = 0;
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
