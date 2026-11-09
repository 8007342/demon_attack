/// One place where gameplay moments leave the simulation for presentation
/// layers that live on other branches: the adaptive music bridge
/// (`// --- music event hook`) and the commander "video call" panel.
///
/// The model queues [GameEvent]s (`ArcadeModel.takeGameEvents`); the app
/// drains them each tick and calls [dispatchGameEvent]. Nothing is
/// registered by default, so dispatching is always safe (a no-op).
///
/// Wire a consumer once, e.g. in main.dart:
/// ```dart
/// GameEvents.listen((e) => musicBridge.event(e.name, e.data));
/// GameEvents.listen((e) => comms.callout(e));
/// ```
library;

/// Names of the ground-war and homing events (stable strings).
abstract final class GameEventNames {
  /// A demon ground unit first becomes visible near the horizon.
  /// Commander hook: "Ground forces ahead!".
  static const groundForceSighted = 'groundForceSighted';

  /// A demon ground unit reaches the near ground where it may fire.
  static const groundForceInRange = 'groundForceInRange';

  /// A demon ground unit launches a ground-to-air missile.
  static const groundMissileLaunch = 'groundMissileLaunch';

  /// The player picks up the homing-missile power-up.
  /// Commander hook: "Homing missiles armed!".
  static const homingPickup = 'homingPickup';

  /// One homing missile leaves the rack (data: target kind).
  static const homingLaunch = 'homingLaunch';

  /// A homing missile strikes its target (data: target kind, killed).
  static const homingHit = 'homingHit';

  /// A demon ground unit is destroyed.
  static const groundUnitDestroyed = 'groundUnitDestroyed';

  /// An allied ground unit comes under fire (data: sector, x, y).
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

  /// The whole fleet held: no ally retreated and no wingmate was lost.
  /// Data `scope`: 'level' (at sector clear) or 'campaign' (at victory).
  static const fleetIntact = 'fleetIntact';

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

  static const all = [
    groundForceSighted,
    groundForceInRange,
    groundMissileLaunch,
    homingPickup,
    homingLaunch,
    homingHit,
    groundUnitDestroyed,
    allyUnderAttack,
    allySaved,
    allyRetreated,
    fleetIntact,
  ];
}

/// A named gameplay moment with a small JSON-safe payload
/// (`sector`, `x`, `y`, `target`, ...).
class GameEvent {
  const GameEvent(this.name, [this.data = const {}]);
  final String name;
  final Map<String, Object?> data;

  @override
  String toString() => 'GameEvent($name, $data)';
}

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
