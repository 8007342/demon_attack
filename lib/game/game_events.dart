/// One place where gameplay moments leave the simulation for presentation
/// layers: the adaptive music bridge (`// --- music event hook`) and the
/// squad comms video call.
///
/// Two sources feed the same vocabulary and the same dispatcher:
/// - the model queues structured [GameEvent]s (`ArcadeModel.takeGameEvents`:
///   ground war, homing missiles, allies, fleet intact); the app drains them
///   each tick and calls [dispatchGameEvent];
/// - [GameEventObserver] turns the model's plain string events plus changes
///   in its public state into derived events (sector start, sentinel dive,
///   shield expiring, ...) and dispatches them too. It never writes to the
///   model.
///
/// Nothing is registered by default, so dispatching is always safe (a no-op).
/// Subscribe once, e.g. in main.dart:
/// ```dart
/// GameEvents.listen((e) => musicBridge.event(e.name, e.data));
/// ```
library;

import 'dart:math' as math;

import 'model.dart';

/// Stable event names.
abstract final class GameEventNames {
  // --- Ground war and homing missiles (queued by the model).

  /// A demon ground unit first becomes visible near the horizon.
  /// Commander hook: "Ground forces ahead!".
  static const groundForceSighted = 'groundForceSighted';

  /// A demon ground unit reaches the near ground where it may fire.
  static const groundForceInRange = 'groundForceInRange';

  /// A demon ground unit launches a ground-to-air missile.
  static const groundMissileLaunch = 'groundMissileLaunch';

  /// A demon ground unit commits to a shot at the player: it launches in
  /// `fireIn` seconds ([GroundTuning.fireLead]: a beat, then the visible
  /// tell). The radio's missile warning is end-aligned to the launch.
  static const groundFirePrep = 'groundFirePrep';

  /// The player picks up the homing-missile power-up.
  /// Commander hook: "Homing missiles armed!".
  static const homingPickup = 'homingPickup';

  /// One homing missile leaves the rack (data: target kind).
  static const homingLaunch = 'homingLaunch';

  /// A homing missile strikes its target (data: target kind, killed).
  static const homingHit = 'homingHit';

  /// A demon ground unit is destroyed.
  static const groundUnitDestroyed = 'groundUnitDestroyed';

  /// Allies call for help: a demon unit is predicted to break through to
  /// fire range (its ally is out-gunned, or it is unescorted: data
  /// `unescorted`, `secondsToBreakthrough`, x, y). Sectors 3-4 only.
  /// Commander hook: "Pick up some homing missiles!" /
  /// "Please shoot these enemies!".
  static const allyUnderAttack = 'allyUnderAttack';

  /// An ally's attacker was destroyed while the ally still stood.
  static const allySaved = 'allySaved';

  /// An overwhelmed ally is totalled and limps off (or its crew ejects:
  /// data `ejected`). Allies never die. Commander hook: "I'm totalled,
  /// going back to base!".
  static const allyRetreated = 'allyRetreated';

  /// Deprecated alias of [allyRetreated] (same string).
  static const allyLost = allyRetreated;

  /// A demon ground unit reached fire range alive (it will now telegraph
  /// and fire at the player). Preceded by `allyUnderAttack` for that unit.
  static const groundBreakthrough = 'groundBreakthrough';

  /// The ground pressure meter crossed a tenth (data `level`, 0-1); for
  /// music intensity. Also readable as `ArcadeModel.ground.pressure`.
  static const groundPressure = 'groundPressure';

  /// The whole fleet held: no ally retreated and no wingmate was lost.
  /// Data `scope`: 'level' (at sector clear) or 'campaign' (at victory).
  static const fleetIntact = 'fleetIntact';

  // --- Life-loss sequence and dive warnings (queued by the model).

  /// The player ship explodes (data x, y, `lives` left, `final`: the last
  /// life, which goes to the defeat celebration instead of a regroup).
  static const playerDestroyed = 'playerDestroyed';

  /// The explosion gives way to the regroup pause (data `duration`,
  /// `shotsDrained`, `missilesDrained`, `lives`): hostile shots fizzle out,
  /// the swarm reforms, nothing can hit the player. Demons celebrate on air.
  static const regroupStart = 'regroupStart';

  /// The reserve ship starts flying in from the bottom edge (data x, y,
  /// `lives`, `protection` seconds of blinking protection). Play resumes;
  /// the squad's new-life chatter plays during it, without blocking.
  static const playerRespawn = 'playerRespawn';

  /// A demon is about to start a dive tell: fires [ArcadeModel.divePrepBeat]
  /// seconds (data `lead`) before the telegraph, so the demons can radio
  /// first (data x, y, `sentinel`, `elite`).
  static const divePrep = 'divePrep';

  /// Sectors 1-2 drama: the allies stop a demon unit just short of fire
  /// range (data x, y, `marginZ`: texels short of the fire line). The unit
  /// never fires. Commander hook: "That was close!".
  static const groundNearMiss = 'groundNearMiss';

  /// A breakthrough is guaranteed / imminent: the unit is past the allies'
  /// reach and will reach fire range in `secondsToBreakthrough` (data x, y).
  /// Fires once per breakthrough, about 3 s ahead, after `allyUnderAttack`.
  static const groundBreakthroughWarning = 'groundBreakthroughWarning';

  static const lifeLoss = [playerDestroyed, regroupStart, playerRespawn];

  // --- continuous swarm (openspec/changes/continuous-swarm design §6.1).
  // Swarm calls carry `eta`: seconds (wall clock) until the creatures they
  // announce become targetable, so the radio can end its call on it.

  /// The next wave's first skeins rise out of the fog while this wave's
  /// stragglers still fight (data `wave`, `eta` = the approach length,
  /// `q` its pacing factor, `skeins`). Comms reuses the next-wave lines.
  static const cohortSighted = 'cohortSighted';

  /// The approaching wave became the current one (data `wave`, `forced`:
  /// it closed in beside the stragglers, `lull`: seconds it held at the
  /// fog front). Replaces the old interwave transition's banner moment.
  static const cohortMerged = 'cohortMerged';

  /// Leftover hostile shots dissolve at a merge (data `count`).
  static const shotsFizzle = 'shotsFizzle';

  static const swarm = [cohortSighted, cohortMerged, shotsFizzle];

  // --- terrain: what the convoy sees below (queued by the flyover's
  // TerrainRadio, lib/game/terrain_field.dart; visual only, rate-limited).
  // Data: `sector` (1-5), `side` ('left' | 'right' | 'both'), x, y.

  /// A notable feature approaches (about 30 s out). Data `kind`: ridge,
  /// valley, canyon, mesa, forest, crystalField or ruins. At most one per
  /// 12 s and one per kind per 30 s. "Rough terrain ahead!"
  static const terrainAhead = 'terrainAhead';

  /// An allied unit crawls up a steep slope. At most one per 15 s.
  static const convoyClimbing = 'convoyClimbing';

  /// An allied unit pushes through vegetation or debris (data `kind`:
  /// tree, crystal, brush, stalk, debris; `species`). At most one per 12 s.
  /// "Clearing the tree line!"
  static const convoyClearingVegetation = 'convoyClearingVegetation';

  /// Rare and short: an allied unit stalls on a very steep wall for a
  /// second. At most one per 45 s.
  static const convoyStuck = 'convoyStuck';

  static const terrain = [
    terrainAhead,
    convoyClimbing,
    convoyClearingVegetation,
    convoyStuck,
  ];

  // --- ground war v4 ---------------------------------------------------------
  // The skirmish layer (lib/game/ground_war_v4.dart): frequent ambient
  // fights between mixed demon forces and the convoy that never threaten the
  // player. Queued by the model; each is rate-limited in the model
  // (GroundV4Tuning.eventGap) except groundTide. Data always has `sector`;
  // `force` / `allyForce` are 'vehicle', 'infantry', 'rockets' or
  // 'heavyTank'.

  /// A convoy ally starts a skirmish (x, y, force, allyForce). At most one
  /// per 6 s. "Contact, left flank!"
  static const groundSkirmish = 'groundSkirmish';

  /// Foot soldiers on either side are in the fight (x, y, force,
  /// allyForce). At most one per 12 s. "Infantry engaged!"
  static const infantryEngaged = 'infantryEngaged';

  /// The convoy (or its artillery: `by` 'artillery') wins a skirmish (x, y,
  /// force, by). At most one per 7 s. "Target down, moving up."
  static const skirmishWon = 'skirmishWon';

  /// A battered ally falls back to its escort slot for field repairs (it is
  /// never totalled by a skirmish) (x, y, force). At most one per 10 s.
  /// "Falling back to repair!"
  static const allyFallingBack = 'allyFallingBack';

  /// A demon heavy tank enters the field (x, y). At most one per 20 s.
  /// "Heavy armour on the horizon!"
  static const heavyArmorSighted = 'heavyArmorSighted';

  /// The ground battle's ebb and flow turns (data `state`: 'surge' or
  /// 'lull'); about twice per 34 s tide cycle. Music / commander hook.
  static const groundTide = 'groundTide';

  static const groundWarV4 = [
    groundSkirmish,
    infantryEngaged,
    skirmishWon,
    allyFallingBack,
    heavyArmorSighted,
    groundTide,
  ];
  // --- end ground war v4 -----------------------------------------------------

  // --- music event hook: events derived read-only from the simulation by
  // MusicDirector (lib/game/music_director.dart) once per frame. Any
  // presentation layer may listen; MusicBridge turns them into music.

  /// The adaptive-music intensity for the current level changed
  /// (data `tier`: 1 calm .. 4 peril).
  static const musicIntensity = 'musicIntensity';

  /// A demon starts its dive tell (telegraph).
  static const diveTell = 'diveTell';

  /// A sentinel starts its last stand.
  static const lastStandTell = 'lastStandTell';

  /// The carrier's central hatch opens (its core is exposed).
  static const carrierHatchOpen = 'carrierHatchOpen';

  /// A reinforcement flock arrives.
  static const reinforcementsArrived = 'reinforcementsArrived';

  static const music = [
    musicIntensity,
    diveTell,
    lastStandTell,
    carrierHatchOpen,
    reinforcementsArrived,
  ];

  // --- dynamic-weather: a regular level's rain (lib/game/weather/), for
  // the future music and SFX engine. Visual only, sent by the scene's rain
  // layer through dispatchGameEvent. Data: `tier` ('drizzle' | 'rain' |
  // 'downpour'), `intensity` (0-1), `wind` (slant), `sector`.

  /// Rain begins (softly, from nothing).
  static const rainStart = 'rainStart';

  /// The rain has died away.
  static const rainStop = 'rainStop';

  /// The rain crossed into another tier (data `from`: the previous tier).
  static const rainIntensity = 'rainIntensity';

  // --- crosswind: the wind (lib/game/weather/wind_field.dart). Gameplay:
  // queued by the model (model_wind.dart). Data: `tier` ('breeze' | 'gale'
  // | 'crosswind'), `sector`, `side` (where it blows to).

  /// The wind rises.
  static const windStart = 'windStart';

  /// The wind has died away.
  static const windStop = 'windStop';

  /// A big swing or a gust is coming: the telegraph, [WindField.lead]
  /// seconds before it pushes (data `from`, `to`: 'left' | 'right';
  /// `gust`; `strength` 0-1; `endIn`). The music's `gust` stinger.
  static const windGust = 'windGust';

  static const weather = [
    rainStart,
    rainStop,
    rainIntensity,
    windStart,
    windStop,
    windGust,
  ];

  static const all = [
    groundForceSighted,
    groundForceInRange,
    groundMissileLaunch,
    groundFirePrep,
    homingPickup,
    homingLaunch,
    homingHit,
    groundUnitDestroyed,
    allyUnderAttack,
    allySaved,
    allyRetreated,
    fleetIntact,
    groundBreakthrough,
    groundPressure,
    groundNearMiss,
    groundBreakthroughWarning,
    playerDestroyed,
    regroupStart,
    playerRespawn,
    divePrep,
    terrainAhead,
    convoyClimbing,
    convoyClearingVegetation,
    convoyStuck,
    ...groundWarV4, // --- ground war v4
    ...swarm, // --- continuous swarm
    ...rush, // --- demon intelligence: the sentinel rush
  ];

  // --- Comms-specific derived events.

  /// Several demons fell within [GameEventObserver.routWindow].
  static const demonRout = 'demonRout';

  /// The ground pressure fell back below [GameEventObserver.pressureCalm]
  /// after rising.
  static const groundPressureEased = 'groundPressureEased';

  /// A new wave: the brood taunts first (a two-party exchange).
  static const broodTaunt = 'broodTaunt';

  /// Ambient brood radio the comms director raises when the demons have
  /// been quiet too long.
  static const broodChatter = 'broodChatter';

  // --- demon intelligence (openspec/changes/demon-intelligence §7-§8).

  /// The skill level rose through ArcadeModel.adaptingAt (once per
  /// sector): the brood remarks that it adapts. Data .
  static const broodAdapting = 'broodAdapting';

  /// A sentinel's rush rally begins (data `rushIn`: real seconds until it
  /// charges, `pass`): the squad's urgent warning ends on it.
  static const sentinelRushTell = 'sentinelRushTell';

  /// It locks on (data `aim`, `rushIn`): the brood's war cry.
  static const sentinelRush = 'sentinelRush';

  /// A missed pass comes around through the fog (data `pass`, `rushIn`).
  static const sentinelRushAgain = 'sentinelRushAgain';

  /// Its rush shield broke (data `midRush`: the bonus and stagger).
  static const rushShieldBroken = 'rushShieldBroken';

  /// A pass missed the ship: squad relief, brood frustration.
  static const rushSurvived = 'rushSurvived';
  static const sentinelRushMissed = 'sentinelRushMissed';

  static const rush = [
    sentinelRushTell,
    sentinelRush,
    sentinelRushAgain,
    rushShieldBroken,
    rushSurvived,
    sentinelRushMissed,
    broodAdapting,
  ];

  // --- bonus levels (openspec/changes/bonus-levels design §5). Each
  // carries `variant`: the bonus level's id (the power's for bonusPickup,
  // the modifier's for runModifier), so `bonusStart.supplyRun` wins over
  // `bonusStart` in the line bank.

  /// The run has a run modifier (once, on the run's first combat frame).
  static const runModifier = 'runModifier';

  /// A bonus level's first wave begins combat.
  static const bonusStart = 'bonusStart';

  /// A bonus level's supply crate is shot open (data `points`, `opened`).
  static const bonusCrate = 'bonusCrate';

  /// A bonus-only powerup is collected.
  static const bonusPickup = 'bonusPickup';

  /// A bonus level's last kill (data `award`, `flawless`, `crates`).
  static const bonusCleared = 'bonusCleared';

  /// bonus-briefing: a bonus level's second wave begins combat (the
  /// squad's mid-level banter and the brood's retort).
  static const bonusMidway = 'bonusMidway';

  /// mission-medals: a bonus level's crate fell past the ship unopened
  /// (the squad's banter; Supply Run's cue tracker queues it).
  static const bonusCrateMissed = 'bonusCrateMissed';

  // --- bonus level #2, Stormfront (specs/bonus-level-stormfront). The raw
  // string events `stormTell` and `stormBolt` (every tell, every bolt) are
  // forwarded under the same names with no data, for the sound and the
  // music.

  /// A lightning tell began on the unprotected ship (data `x`, `endIn`:
  /// real seconds until the bolt; the squad's warning ends on it).
  static const stormStrike = 'stormStrike';

  /// A bolt that was drawn to the ship stunned creatures and missed it
  /// (data `x`, `stunned`; variant `stun`): the squad's "pick them off"
  /// (lightning-rework: bolts stun, they no longer kill; the bait bonus is
  /// paid as each stunned creature is shot down).

  static const stormBait = 'stormBait';

  // --- crosswind: the bonus level's kites (data `kites`: popped so far,
  // `escaped`, `total`, `x`).

  /// A kite was shot down.
  static const kitePopped = 'kitePopped';

  /// A kite rode the wind off the screen.
  static const kiteEscaped = 'kiteEscaped';

  // --- lightning-rework (lib/game/lightning.dart): what a bolt does,
  // whatever storm throws it. Raw string events for the sound: `stormStun`
  // (a bolt stunned creatures), `shipZapped`, `demonCharged`.

  /// A bolt stunned creatures (data `x`, `stunned`): the brood's yelps and
  /// the squad's "pick them off". Stormfront's baited bolts say
  /// [stormBait] instead (variant `stun`).
  static const lightningStun = 'lightningStun';

  /// A bolt met the ship and stripped it (data `x`, `lost`: shields and
  /// powers stripped, `shield`; variant `powers`, or `clean` when it had
  /// nothing to lose). Never a life: the squad reassures the pilot.
  static const lightningShipHit = 'lightningShipHit';

  /// Rod-armoured creatures drank a bolt (data `x`, `charged`).
  static const lightningCharged = 'lightningCharged';

  static const lightning = [lightningStun, lightningShipHit, lightningCharged];

  // --- bonus challenges (openspec/changes/bonus-challenges). `variant`:
  // the level's id; data `challenge` (its id). The raw `bonusOneUp` is the
  // 1UP's sound (lib/main.dart).

  /// A level's perfect-run condition broke (data `by`: the note that broke
  /// it; '' when it fell short at the clear).
  static const bonusChallengeFailed = 'bonusChallengeFailed';

  /// A level's perfect-run condition held to the clear: its 1UP was paid
  /// (data `lives`: the lives after it).
  static const bonusChallengeEarned = 'bonusChallengeEarned';

  static const bonus = [
    runModifier,
    bonusStart,
    bonusCrate,
    bonusPickup,
    bonusCleared,
    bonusMidway,
    bonusCrateMissed,
    stormStrike,
    stormBait,
    kitePopped,
    kiteEscaped,
    bonusChallengeFailed,
    bonusChallengeEarned,
  ];

  /// A full-size transmission: the fleet's mission briefing on travel
  /// (variant: the next sector) or a junior-pilot moment on a new wave.
  static const transmissionMission = 'transmissionMission';
  static const transmissionJunior = 'transmissionJunior';

  /// [groundPressure] crossing [GameEventObserver.pressureRising] /
  /// [GameEventObserver.pressureHigh] upward (each re-arms once the pressure
  /// falls back below [GameEventObserver.pressureCalm]).
  static const groundPressureRising = 'groundPressureRising';
  static const groundPressureHigh = 'groundPressureHigh';

  /// The fight below changed (comms-middle-ground): data `engaged` (live
  /// demon ground units), `threats` (units predicted to break through or
  /// through), `over` (the ship flies within [GameEventObserver.coverReach]
  /// of a foe, with hysteresis) and `shipX`. Emitted only when one of
  /// `engaged > 0`, `threats > 0` or `over` changes, so radio lines about
  /// air cover and the ground battle can match the gameplay below.
  static const groundPicture = 'groundPicture';

  /// A ground unit is expected to fire at the player in `fireIn` seconds
  /// (at most [GameEventObserver.fireForecast]; data x): the same
  /// prediction the model uses for [groundFirePrep], read earlier and soft
  /// (a launch may slip or never come). Once per shot. The radio keeps the
  /// channel clear for the coming must-play warning (comms-middle-ground).
  static const groundFireForecast = 'groundFireForecast';

  // --- Derived by GameEventObserver (data `variant`, `payload`, `clock`).

  /// A sector entrance (variant: sector 1-5).
  static const sectorStart = 'sectorStart';
  static const waveStart = 'waveStart';

  /// The model's raw `incoming` (wave pressure), forwarded by name: the
  /// next wave appears on the horizon while this one is down to its last
  /// few.
  static const incoming = 'incoming';
  static const reinforcements = 'reinforcements';
  static const sentinelIncoming = 'sentinelIncoming';
  static const sentinelDive = 'sentinelDive';

  /// Two or more ordinary dives within [GameEventObserver.diveWindow].
  static const diveWarning = 'diveWarning';
  static const eliteSighted = 'eliteSighted';

  /// A shield pickup is in the air.
  static const shieldSpotted = 'shieldSpotted';

  /// A weapon power-up is falling while the ship has no weapon power
  /// (variant: the power's name; data `hint` true): the squad recommends it.
  static const powerupSpotted = 'powerupSpotted';
  static const shieldCollected = 'shieldCollected';

  /// The shield crosses [GameEventObserver.shieldWarningSeconds] left.
  static const shieldExpiring = 'shieldExpiring';

  /// A hit consumed the shield.
  static const shieldBroken = 'shieldBroken';

  /// A weapon module was fitted (variant: the power's name).
  static const weaponPickup = 'weaponPickup';

  /// A player ship is totalled (the pilot ejects; the reserve launches).
  static const lifeLost = 'lifeLost';

  // --- music event hook: the life-loss moment uses [playerDestroyed],
  // [regroupStart] and [playerRespawn], declared with the life-loss sequence
  // above (music: hit stinger + drop, demonic gloat, heroic re-entry accent).
  static const lowLives = 'lowLives';
  static const extraLife = 'extraLife';
  static const salvage = 'salvage';
  static const levelClear = 'levelClear';
  static const bossArrival = 'bossArrival';

  /// A carrier form change or its field breaking (variant: phase).
  static const bossPhase = 'bossPhase';
  static const bossDefeated = 'bossDefeated';

  // --- boss-grandeur (operator R8.5): the carrier's decay, one event per
  // step, for the dynamic music engine and comms. Data: `route`, `variant`
  // (the run's module set), plus the step's own field.

  /// The carrier flies in over the ship (the boss arrival's Descent;
  /// published by the music director).
  static const bossOverflight = 'bossOverflight';

  /// The carrier finished its loom and rises out of the fog (carrier-v3:
  /// its wave starts at the Close).
  static const bossRise = 'bossRise';

  // --- carrier-v3 §10: the intro and the launches, for the future epic
  // and doom-metal score. Every one carries `route`, `tour` and `set`.

  /// The approach starts (step 0) and each step closer (`step`,
  /// `distance`).
  static const bossApproach = 'bossApproach';

  // carrier-hatches §A8: the volley lifecycle on the hatches (carrier-v3's
  // `bossGate*` names are retired, never emitted beside these).

  /// A hatch's telegraph starts (`hatch`, `tier`, `side`, `kind`, `slot`).
  static const bossHatchTelegraph = 'bossHatchTelegraph';

  /// Its doors open (`hatch`, `tier`).
  static const bossHatchOpen = 'bossHatchOpen';

  /// A volley leaves (`hatch`, `count`, `tier`).
  static const bossLaunch = 'bossLaunch';

  /// Its doors close (`hatch`, `tier`).
  static const bossHatchClose = 'bossHatchClose';

  /// A hatch's own field breaks (`hatch`, `tier`, `side`).
  static const bossHatchFieldDown = 'bossHatchFieldDown';

  /// A hatch is destroyed (`hatch`, `tier`, `side`, `cause`, `left`).
  static const bossHatchDrop = 'bossHatchDrop';

  /// The vulnerable tier changes: a section of the fight's song (`tier`,
  /// `tiers`, `depth` 0..1, `shootable`, `from`).
  static const bossHatchTier = 'bossHatchTier';

  /// The transformation (`stage`: start or end; `seconds`).
  static const bossTransform = 'bossTransform';

  /// The radio hints (`hint`): written lines until they are recorded.
  static const bossHintHatches = 'bossHintHatches';
  static const bossHintTiming = 'bossHintTiming';
  static const bossHintLead = 'bossHintLead';

  /// The hittable threshold, D = 1 (`distance`).
  static const bossInRange = 'bossInRange';

  /// The take-off beat (`minZoom`, `altitude`).
  static const bossTakeoff = 'bossTakeoff';

  /// The climb reaches 98 % of its altitude (`altitude`; presentation).
  static const bossClimbPeak = 'bossClimbPeak';

  /// A shot stopped by the field (`region`, `x`), at most 4 per second.
  static const bossFieldImpact = 'bossFieldImpact';

  /// A speed surge starts (`intensity`; presentation).
  static const bossSpeedSurge = 'bossSpeedSurge';

  /// The hull bursts through a cloud bank (presentation).
  static const bossCloudPunch = 'bossCloudPunch';

  /// The intro's events in their order of first appearance.
  static const carrierIntro = [
    bossApproach,
    bossHatchTelegraph,
    bossHatchOpen,
    bossLaunch,
    bossHatchClose,
    bossInRange,
    bossTakeoff,
    bossClimbPeak,
    bossFieldImpact,
    bossSpeedSurge,
    bossCloudPunch,
  ];

  // boss-carrier-wire: the names and data of the styleguide's decay
  // vocabulary (docs/styleguide/alien-capital-ships.md §6). Every step also
  // carries `set` (the run's set combination).

  /// One hex shield cell went dark (data `cell`, `remaining` and
  /// `cellsLeft`, 11 … 0).
  static const bossShieldCellLost = 'bossShieldCellLost';

  /// The shield fell to half (S1: the crystals flicker and dim).
  static const bossShieldFailing = 'bossShieldFailing';

  /// The force field is gone (after the last cell; S2).
  static const bossShieldDown = 'bossShieldDown';

  /// Armour plates peel off (data `slot`: the module next in the detach
  /// order; `plate`: the armour step).
  static const bossArmourShed = 'bossArmourShed';

  /// A module tore away at a form change (data `slot`, `set`, `rank`,
  /// `form`, `detachOrder`; S3).
  static const bossModuleLost = 'bossModuleLost';

  /// The transformation's end: the core door is exposed (carrier-hatches
  /// §A4; it was the last form).
  static const bossCoreExposed = 'bossCoreExposed';

  /// Core 0: the hull breaks into module wrecks (S4) …
  static const bossCollapseStart = 'bossCollapseStart';

  /// … each remaining module falls (data `slot`, `rank`, `delay` s), the
  /// carapace last …
  static const bossWreckFalls = 'bossWreckFalls';

  /// … and the victory rout that carried the fall is over.
  static const bossCollapseEnd = 'bossCollapseEnd';
  static const defeat = 'defeat';

  /// Celebrations: [fleetIntact] with no player ship lost either, per
  /// sector, per tour (at the carrier victory) and for the whole run (only
  /// for runs observed from their start).
  static const flawlessSector = 'flawlessSector';
  static const flawlessVictory = 'flawlessVictory';
  static const flawlessRun = 'flawlessRun';

  // --- audio round: power-up music layer (published by MusicDirector).

  /// The power-up state the music follows changed: data `active` (number of
  /// powers running), `falling` (a pickup is in the air) and `level`. The
  /// music adds the level's power layer while `active` > 0 and brightens
  /// while `falling`, both on the next bar line.
  static const musicPowerLayer = 'musicPowerLayer';
  // --- end audio round

  /// Raw model names renamed into this vocabulary.
  static const aliases = {
    'wave': waveStart,
    'escort': sentinelIncoming,
    'levelclear': levelClear,
    'allyLost': allyRetreated,
  };

  /// High-frequency raw events that are not forwarded.
  static const unforwarded = {'shot', 'hit', 'explosion'};
}

/// A named gameplay moment with a small JSON-safe payload
/// (`sector`, `x`, `y`, `target`, `variant`, ...).
class GameEvent {
  const GameEvent(this.name, [this.data = const {}]);
  final String name;
  final Map<String, Object?> data;

  /// Refinement a listener may key on, e.g. the sector of `sectorStart`
  /// ('3') or the power of `weaponPickup` ('spread').
  String? get variant => (data['variant'] ?? data['kind'])?.toString();

  /// Text after the first ':' of a raw string event, if any.
  String? get payload => data['payload']?.toString();

  /// Model clock when observed (derived events).
  double get clock => (data['clock'] as num?)?.toDouble() ?? 0;

  @override
  String toString() => 'GameEvent($name, $data)';
}

typedef _Emit = void Function(
  String name, {
  String? variant,
  String? payload,
  Map<String, Object?> data,
});

typedef GameEventListener = void Function(GameEvent event);

/// The single no-op-safe dispatcher.
abstract final class GameEvents {
  static final List<GameEventListener> _listeners = [];

  /// Registers [listener]; returns a function that removes it.
  static void Function() listen(GameEventListener listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  static int get listenerCount => _listeners.length;
}

/// Delivers [event] to every listener. A throwing listener never breaks the
/// game loop or the other listeners.
void dispatchGameEvent(GameEvent event) {
  for (final listener in List.of(GameEvents._listeners)) {
    try {
      listener(event);
    } catch (_) {
      // Presentation hooks must never affect play.
    }
  }
}

/// Losses of the allied fleet: player ships and ground units.
class FleetTally {
  int sector = 0, tour = 0, run = 0;

  /// Player ships lost in the sector / in the run (for [GameEventNames.
  /// fleetIntact], which already accounts for ground allies).
  int sectorShips = 0, runShips = 0;

  /// False after a checkpoint restore: earlier losses are unknown.
  bool wholeRun = true;
  void lose({bool ship = false}) {
    sector++;
    tour++;
    run++;
    if (ship) {
      sectorShips++;
      runShips++;
    }
  }
}

/// Derives presentation events from the model's string events and public
/// state, read-only.
class GameEventObserver {
  GameEventObserver(this.model, {this.dispatch = true});
  final ArcadeModel model;

  /// Publish derived events through [dispatchGameEvent] (tests may opt out).
  final bool dispatch;

  /// Shield seconds left at which `shieldExpiring` fires.
  static const shieldWarningSeconds = 2.5;

  /// Ordinary dives starting within this window count as one attack run.
  static const diveWindow = 1.2;

  final _seenLarge = <Demon>{}, _seenElite = <Demon>{};
  final _seenPickups = <Pickup>{};
  final _telegraphing = <Demon>{}, _diving = <Demon>{};
  final _diveStarts = <double>[];
  final _powerLeft = <Power, double>{};
  Carrier? _boss;
  bool _diveRunAnnounced = false;
  FleetTally tally = FleetTally();

  /// Ground pressure bands (hysteresis on the way down).
  static const pressureCalm = .3, pressureRising = .45, pressureHigh = .8;
  int _pressureBand = 0;

  /// The ship counts as over the ground battle within this many arena units
  /// of a live demon ground unit, and leaves it beyond [coverLeave].
  static const coverReach = 64.0, coverLeave = 90.0;
  bool _engaged = false, _threats = false, _over = false;

  /// Seconds ahead a ground shot is forecast (`groundFireForecast`).
  static const fireForecast = 5.0;
  final _forecast = <(int, int)>{};

  /// [routKills] demon kills within [routWindow] seconds read as a rout.
  static const routWindow = 3.0, routKills = 5, routGap = 8.0;
  final _killTimes = <double>[];
  int? _kills;
  double _lastRout = -100;

  void _observeKills(_Emit emit) {
    final kills = model.kills, clock = model.clock;
    final before = _kills;
    _kills = kills;
    if (before == null || kills <= before) {
      if (before != null && kills < before) _killTimes.clear();
      return;
    }
    for (var i = before; i < kills; i++) {
      _killTimes.add(clock);
    }
    _killTimes.removeWhere((t) => clock - t > routWindow);
    if (_killTimes.length >= routKills && clock - _lastRout > routGap) {
      _lastRout = clock;
      _killTimes.clear();
      emit(GameEventNames.demonRout);
    }
  }

  /// [freshRun] false (a restored checkpoint) disables `flawlessRun`.
  void reset({bool freshRun = true}) {
    tally = FleetTally()..wholeRun = freshRun;
    _killTimes.clear();
    _kills = null;
    _lastRout = -100;
    _pressureBand = 0;
    _engaged = _threats = _over = false;
    _forecast.clear();
    _seenLarge.clear();
    _seenElite.clear();
    _seenPickups.clear();
    _telegraphing.clear();
    _diving.clear();
    _diveStarts.clear();
    _powerLeft.clear();
    _boss = null;
    _diveRunAnnounced = false;
  }

  GameEvent _event(
    String name, {
    String? variant,
    String? payload,
    Map<String, Object?> data = const {},
  }) => GameEvent(name, {
    'clock': model.clock,
    'variant': ?variant,
    'payload': ?payload,
    ...data,
  });

  List<GameEvent> _publish(List<GameEvent> out) {
    if (dispatch) {
      for (final event in out) {
        dispatchGameEvent(event);
      }
    }
    return out;
  }

  /// Converts this frame's raw model string events (already taken from the
  /// model) plus state changes into [GameEvent]s, dispatches and returns
  /// them.
  List<GameEvent> observe(List<String> raw) {
    final out = <GameEvent>[];
    void emit(
      String name, {
      String? variant,
      String? payload,
      Map<String, Object?> data = const {},
    }) => out.add(_event(name, variant: variant, payload: payload, data: data));
    final shieldBefore = _powerLeft[Power.shield] ?? 0;
    for (final entry in raw) {
      final colon = entry.indexOf(':');
      final name = colon < 0 ? entry : entry.substring(0, colon);
      final payload = colon < 0 ? null : entry.substring(colon + 1);
      // continuous-swarm: the raw `incoming` is voiced through the model's
      // queued `cohortSighted` (it carries the eta), so it is not forwarded.
      if (!GameEventNames.unforwarded.contains(name) && name != 'incoming') {
        final eta = _etaOf(name);
        emit(
          GameEventNames.aliases[name] ?? name,
          payload: payload,
          data: eta == null ? const {} : {'eta': eta},
        );
      }
      switch (name) {
        case 'level':
          _sectorStart(emit);
        case 'boss':
          final boss = model.boss;
          if (boss != null && !identical(boss, _boss)) {
            _boss = boss;
            // boss-grandeur: after the loom waves the sector has started.
            if (model.wave == 1) _sectorStart(emit);
            emit(GameEventNames.bossArrival);
          } else if (boss != null) {
            emit(GameEventNames.bossPhase, variant: '${boss.phase}');
          }
        case 'allyLost' || 'allyRetreated':
          tally.lose();
        case 'victory':
          if (tally.tour == 0) emit(GameEventNames.flawlessVictory);
          tally.tour = 0;
          _boss = null;
        case 'life':
          tally.lose(ship: true);
          emit(GameEventNames.lifeLost);
          if (model.lives == 1) emit(GameEventNames.lowLives);
        case 'hit':
          if (shieldBefore > .15 && !model.hasPower(Power.shield)) {
            emit(GameEventNames.shieldBroken);
            _powerLeft.remove(Power.shield);
          }
        case 'wave':
          _clearWave();
          emit(GameEventNames.broodTaunt);
          emit(GameEventNames.transmissionJunior);
        case 'travel':
          emit(
            GameEventNames.transmissionMission,
            variant: '${model.nextLevel}',
          );
      }
    }
    _observeKills(emit);
    if (model.combat) _observeCombat(emit);
    _observePowers(emit);
    _observeGround(emit);
    return _publish(out);
  }

  /// Reads a structured event the model queued (subscribe with
  /// `GameEvents.listen(observer.onGameEvent)`): counts ally retreats and
  /// turns `fleetIntact` into the celebrations when no player ship was lost
  /// either. Returns (and dispatches) what it derives.
  List<GameEvent> onGameEvent(GameEvent event) {
    final out = <GameEvent>[];
    switch (event.name) {
      case GameEventNames.allyRetreated:
        tally.lose();
      case GameEventNames.groundPressure:
        final raw =
            event.data['level'] ??
            event.data['pressure'] ??
            event.data['value'];
        final level = raw is num ? raw.toDouble() : double.tryParse('$raw');
        if (level == null) break;
        if (level < pressureCalm && _pressureBand > 0) {
          _pressureBand = 0;
          out.add(_event(GameEventNames.groundPressureEased));
        }
        if (level >= pressureHigh && _pressureBand < 2) {
          _pressureBand = 2;
          out.add(_event(GameEventNames.groundPressureHigh));
        } else if (level >= pressureRising && _pressureBand < 1) {
          _pressureBand = 1;
          out.add(_event(GameEventNames.groundPressureRising));
        }
      case GameEventNames.fleetIntact:
        final scope = event.data['scope'];
        if (scope == 'campaign') {
          if (tally.runShips == 0 && tally.wholeRun) {
            out.add(_event(GameEventNames.flawlessRun));
          }
        } else if (tally.sectorShips == 0) {
          out.add(_event(GameEventNames.flawlessSector));
        }
    }
    return _publish(out);
  }

  /// Seconds (wall clock) until the creatures a swarm call announces
  /// become targetable (continuous-swarm design §6.1): a reinforcement
  /// skein's swoop, a sentinel's delay and rise; null for other events.
  double? _etaOf(String raw) {
    double left(Demon d) =>
        d.entranceDelay + d.entranceDuration - d.entranceElapsed;
    switch (raw) {
      case 'reinforcements':
        var eta = 0.0;
        for (final d in model.demons) {
          if (d.isLarge || d.isEscort || !d.entering) continue;
          if (d.swarmState != SwarmState.approaching) continue;
          if (d.entranceElapsed > 2 / 60) continue; // admitted just now
          eta = eta < left(d) ? left(d) : eta;
        }
        return eta > 0 ? eta : null;
      case 'escort':
        for (final d in model.demons) {
          if (d.isLarge && d.entering && !d.waitingForEscort) return left(d);
        }
        return null;
    }
    return null;
  }

  void _sectorStart(_Emit emit) {
    // The model emits `level` (or `boss` in the carrier sector) exactly once
    // per sector entrance, including a restored checkpoint.
    _clearWave();
    tally
      ..sector = 0
      ..sectorShips = 0;
    _pressureBand = 0;
    emit(GameEventNames.sectorStart, variant: '${model.level}');
  }

  void _clearWave() {
    _seenLarge.clear();
    _seenElite.clear();
    _telegraphing.clear();
    _diving.clear();
    _diveStarts.clear();
    _diveRunAnnounced = false;
  }

  void _observeCombat(_Emit emit) {
    final clock = model.clock;
    for (final d in model.demons) {
      if (d.isLarge) {
        if (_seenLarge.add(d) && !d.waitingForEscort) {
          emit(GameEventNames.sentinelIncoming);
        }
        // The final rush has its own radio (sentinelRushTell, queued by
        // the model with its rushIn), so it is not a sentinel dive here.
        if (d.lastStand) continue;
        final telling = d.telegraph > 0 || d.rushing;
        if (telling && _telegraphing.add(d)) {
          // Seconds until it leaves the formation: the radio ends its
          // warning on the dive (0 once it is already rushing).
          final rate = model.policy.hostileRate;
          emit(
            GameEventNames.sentinelDive,
            data: {'diveIn': d.rushing ? 0.0 : d.telegraph / rate},
          );
        }
        if (!telling && d.dive <= 0) _telegraphing.remove(d);
        continue;
      }
      if (d.elite && !d.entering && _seenElite.add(d)) {
        emit(GameEventNames.eliteSighted);
      }
      if (d.dive > 0) {
        if (_diving.add(d)) _diveStarts.add(clock);
      } else {
        _diving.remove(d);
      }
    }
    _diveStarts.removeWhere((t) => clock - t > diveWindow);
    if (_diveStarts.length >= 2 && !_diveRunAnnounced) {
      _diveRunAnnounced = true;
      // Observed as the dives start: too late for a call that should end
      // on the dive, so the comms only use it when nothing announced the
      // run from `divePrep` (diveIn 0 lets them drop it).
      emit(GameEventNames.diveWarning, data: const {'diveIn': 0.0});
    } else if (_diveStarts.isEmpty) {
      _diveRunAnnounced = false;
    }
    _seenLarge.removeWhere((d) => !model.demons.contains(d));
    _seenElite.removeWhere((d) => !model.demons.contains(d));
    _telegraphing.removeWhere((d) => !model.demons.contains(d));
    _diving.removeWhere((d) => !model.demons.contains(d));
    for (final p in model.pickups) {
      if (!_seenPickups.add(p)) continue;
      // --- bonus levels: a bonus-only powerup is not the regular power
      // its `power` field holds (its own `bonusPickup` call speaks).
      if (p.bonus != null) continue;
      // `hint`: the ship lacks what is falling, so the squad recommends it
      // (these calls win over flavour chatter on the radio).
      if (p.power == Power.shield) {
        emit(
          GameEventNames.shieldSpotted,
          data: {'hint': !model.hasPower(Power.shield)},
        );
      } else if (!model.hasOffensivePower) {
        emit(
          GameEventNames.powerupSpotted,
          variant: p.power.name,
          data: const {'hint': true},
        );
      }
    }
    _seenPickups.removeWhere((p) => !model.pickups.contains(p));
  }

  /// The `groundPicture` state: what is fighting below, and whether the
  /// ship is over it. Read-only, emitted on change.
  void _observeGround(_Emit emit) {
    final foes = model.ground.liveUnits.toList();
    final engaged = model.combat && foes.isNotEmpty;
    if (engaged) _forecastFire(foes, emit);
    final threats = engaged && foes.any((u) => u.threatening || u.brokeThrough);
    var near = double.infinity;
    for (final u in foes) {
      final d = (u.x - model.shipX).abs();
      if (d < near) near = d;
    }
    final over = engaged && (_over ? near <= coverLeave : near <= coverReach);
    if (engaged == _engaged && threats == _threats && over == _over) return;
    _engaged = engaged;
    _threats = threats;
    _over = over;
    emit(
      GameEventNames.groundPicture,
      data: {
        'engaged': engaged ? foes.length : 0,
        'threats': foes.where((u) => u.threatening || u.brokeThrough).length,
        'over': over,
        'shipX': model.shipX,
      },
    );
  }

  /// The model's own launch prediction (see `_updateGroundFire`), read up
  /// to [fireForecast] seconds ahead: once per unit and shot.
  void _forecastFire(List<GroundUnit> foes, _Emit emit) {
    final rate = model.policy.hostileRate;
    _forecast.removeWhere((k) => !foes.any((u) => u.id == k.$1));
    for (final u in foes) {
      if (u.skirmish ||
          u.shotsLeft <= 0 ||
          u.telegraph > 0 ||
          u.fireWarned ||
          u.z < GroundTuning.lastFireZ) {
        continue;
      }
      final key = (u.id, u.shotsLeft);
      if (_forecast.contains(key)) continue;
      final toRange = u.z > GroundTuning.fireZ
          ? (u.z - GroundTuning.fireZ) / GroundTuning.approachSpeed
          : 0.0;
      final fireIn =
          (math.max(u.cooldown, toRange) + GroundTuning.telegraph) / rate;
      if (fireIn > fireForecast) continue;
      _forecast.add(key);
      emit(
        GameEventNames.groundFireForecast,
        data: {'fireIn': fireIn, 'x': u.x},
      );
    }
  }

  void _observePowers(_Emit emit) {
    for (final power in Power.values) {
      final before = _powerLeft[power] ?? 0;
      final now = model.timeLeft(power);
      if (now > before + .05) {
        if (power == Power.shield) {
          emit(GameEventNames.shieldCollected);
        } else {
          emit(GameEventNames.weaponPickup, variant: power.name);
        }
      } else if (power == Power.shield &&
          before >= shieldWarningSeconds &&
          now < shieldWarningSeconds &&
          now > 0) {
        emit(GameEventNames.shieldExpiring);
      }
      if (now > 0) {
        _powerLeft[power] = now;
      } else {
        _powerLeft.remove(power);
      }
    }
  }
}
