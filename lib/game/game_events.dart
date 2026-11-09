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
    groundBreakthrough,
    groundPressure,
  ];

  /// [groundPressure] crossing [GameEventObserver.pressureRising] /
  /// [GameEventObserver.pressureHigh] upward (each re-arms once the pressure
  /// falls back below [GameEventObserver.pressureCalm]).
  static const groundPressureRising = 'groundPressureRising';
  static const groundPressureHigh = 'groundPressureHigh';

  // --- Derived by GameEventObserver (data `variant`, `payload`, `clock`).

  /// A sector entrance (variant: sector 1-5).
  static const sectorStart = 'sectorStart';
  static const waveStart = 'waveStart';
  static const reinforcements = 'reinforcements';
  static const sentinelIncoming = 'sentinelIncoming';
  static const sentinelDive = 'sentinelDive';

  /// Two or more ordinary dives within [GameEventObserver.diveWindow].
  static const diveWarning = 'diveWarning';
  static const eliteSighted = 'eliteSighted';

  /// A shield pickup is in the air.
  static const shieldSpotted = 'shieldSpotted';
  static const shieldCollected = 'shieldCollected';

  /// The shield crosses [GameEventObserver.shieldWarningSeconds] left.
  static const shieldExpiring = 'shieldExpiring';

  /// A hit consumed the shield.
  static const shieldBroken = 'shieldBroken';

  /// A weapon module was fitted (variant: the power's name).
  static const weaponPickup = 'weaponPickup';

  /// A player ship is totalled (the pilot ejects; the reserve launches).
  static const lifeLost = 'lifeLost';
  static const lowLives = 'lowLives';
  static const extraLife = 'extraLife';
  static const salvage = 'salvage';
  static const levelClear = 'levelClear';
  static const bossArrival = 'bossArrival';

  /// A carrier form change or its field breaking (variant: phase).
  static const bossPhase = 'bossPhase';
  static const bossDefeated = 'bossDefeated';
  static const defeat = 'defeat';

  /// Celebrations: [fleetIntact] with no player ship lost either, per
  /// sector, per tour (at the carrier victory) and for the whole run (only
  /// for runs observed from their start).
  static const flawlessSector = 'flawlessSector';
  static const flawlessVictory = 'flawlessVictory';
  static const flawlessRun = 'flawlessRun';

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
  String? get variant => data['variant']?.toString();

  /// Text after the first ':' of a raw string event, if any.
  String? get payload => data['payload']?.toString();

  /// Model clock when observed (derived events).
  double get clock => (data['clock'] as num?)?.toDouble() ?? 0;

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

  /// [freshRun] false (a restored checkpoint) disables `flawlessRun`.
  void reset({bool freshRun = true}) {
    tally = FleetTally()..wholeRun = freshRun;
    _pressureBand = 0;
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

  GameEvent _event(String name, {String? variant, String? payload}) =>
      GameEvent(name, {
        'clock': model.clock,
        'variant': ?variant,
        'payload': ?payload,
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
    void emit(String name, {String? variant, String? payload}) =>
        out.add(_event(name, variant: variant, payload: payload));
    final shieldBefore = _powerLeft[Power.shield] ?? 0;
    for (final entry in raw) {
      final colon = entry.indexOf(':');
      final name = colon < 0 ? entry : entry.substring(0, colon);
      final payload = colon < 0 ? null : entry.substring(colon + 1);
      if (!GameEventNames.unforwarded.contains(name)) {
        emit(GameEventNames.aliases[name] ?? name, payload: payload);
      }
      switch (name) {
        case 'level':
          _sectorStart(emit);
        case 'boss':
          final boss = model.boss;
          if (boss != null && !identical(boss, _boss)) {
            _boss = boss;
            _sectorStart(emit);
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
      }
    }
    if (model.combat) _observeCombat(emit);
    _observePowers(emit);
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
        if (level < pressureCalm) _pressureBand = 0;
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

  void _sectorStart(
    void Function(String, {String? variant, String? payload}) emit,
  ) {
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

  void _observeCombat(
    void Function(String, {String? variant, String? payload}) emit,
  ) {
    final clock = model.clock;
    for (final d in model.demons) {
      if (d.isLarge) {
        if (_seenLarge.add(d) && !d.waitingForEscort) {
          emit(GameEventNames.sentinelIncoming);
        }
        final telling = d.telegraph > 0 || d.rushing;
        if (telling && _telegraphing.add(d)) {
          emit(GameEventNames.sentinelDive);
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
      emit(GameEventNames.diveWarning);
    } else if (_diveStarts.isEmpty) {
      _diveRunAnnounced = false;
    }
    _seenLarge.removeWhere((d) => !model.demons.contains(d));
    _seenElite.removeWhere((d) => !model.demons.contains(d));
    _telegraphing.removeWhere((d) => !model.demons.contains(d));
    _diving.removeWhere((d) => !model.demons.contains(d));
    for (final p in model.pickups) {
      if (_seenPickups.add(p) && p.power == Power.shield) {
        emit(GameEventNames.shieldSpotted);
      }
    }
    _seenPickups.removeWhere((p) => !model.pickups.contains(p));
  }

  void _observePowers(
    void Function(String, {String? variant, String? payload}) emit,
  ) {
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
