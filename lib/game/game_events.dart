/// One typed, read-only event vocabulary over the simulation, shared by every
/// presentation layer (squad comms, the music bridge, future HUD cues).
///
/// The model keeps emitting its plain string events (`model.events`); the page
/// takes them once per frame and hands them to [GameEventObserver.observe],
/// which forwards each one unchanged as a [GameEvent] of the same name and
/// adds derived events read from the model's public state (a new sentinel, a
/// shield pickup in the air, the shield running out, ...). It never writes to
/// the model.
///
/// Any string event the model gains later (for example the ground-forces
/// events `groundForceSighted`, `groundForceInRange`, `homingPickup`,
/// `allyUnderAttack`, `allySaved`, `allyRetreated`) passes through by name, so
/// listeners plug in without touching this file. A raw event may carry a
/// payload after a colon (`allyUnderAttack:2,140`); it is exposed as
/// [GameEvent.payload].
library;

import 'dart:async';

import 'model.dart';

class GameEvent {
  const GameEvent(this.name, {this.clock = 0, this.variant, this.payload});

  /// Raw model event names pass through unchanged; derived names are in
  /// [GameEvents].
  final String name;

  /// Model clock when observed.
  final double clock;

  /// Optional refinement a listener may key on, e.g. the sector of
  /// `sectorStart` ('3') or the power of `weaponPickup` ('spread').
  final String? variant;

  /// Text after the first ':' of a raw event, if any.
  final String? payload;

  @override
  String toString() =>
      'GameEvent($name${variant == null ? '' : '.$variant'}'
      '${payload == null ? '' : ':$payload'})';
}

/// Names of derived events. Raw model names (level, boss, wave, hit, life,
/// powerup, reinforcements, escort, salvage, levelclear, victory, defeat, ...)
/// are forwarded as they are.
abstract final class GameEvents {
  static const sectorStart = 'sectorStart';
  static const waveStart = 'waveStart';
  static const reinforcements = 'reinforcements';
  static const sentinelIncoming = 'sentinelIncoming';
  static const sentinelDive = 'sentinelDive';
  static const diveWarning = 'diveWarning';
  static const eliteSighted = 'eliteSighted';
  static const shieldSpotted = 'shieldSpotted';
  static const shieldCollected = 'shieldCollected';
  static const shieldExpiring = 'shieldExpiring';
  static const shieldBroken = 'shieldBroken';
  static const weaponPickup = 'weaponPickup';
  static const lifeLost = 'lifeLost';
  static const lowLives = 'lowLives';
  static const extraLife = 'extraLife';
  static const salvage = 'salvage';
  static const levelClear = 'levelClear';
  static const bossArrival = 'bossArrival';
  static const bossPhase = 'bossPhase';
  static const bossDefeated = 'bossDefeated';
  static const defeat = 'defeat';
  // Ground forces and homing missiles (emitted by the model on their branch).
  static const groundForceSighted = 'groundForceSighted';
  static const groundForceInRange = 'groundForceInRange';
  static const homingPickup = 'homingPickup';
  static const allyUnderAttack = 'allyUnderAttack';
  static const allySaved = 'allySaved';

  /// An allied unit is knocked out and heads back to base (allies never
  /// die). The raw name `allyLost` is accepted as an alias.
  static const allyRetreated = 'allyRetreated';

  /// Celebrations when the whole allied fleet survives: no ship and no ground
  /// unit lost in the sector, in the tour up to its carrier victory, or in
  /// the whole run (only for runs observed from their start).
  static const flawlessSector = 'flawlessSector';
  static const flawlessVictory = 'flawlessVictory';
  static const flawlessRun = 'flawlessRun';

  /// Raw model names renamed into the vocabulary above.
  static const aliases = {
    'wave': waveStart,
    'escort': sentinelIncoming,
    'levelclear': levelClear,
    'extraLife': extraLife,
    'allyLost': allyRetreated,
  };
}

/// Losses of the allied fleet (player ships and ground units).
class FleetTally {
  int sector = 0, tour = 0, run = 0;

  /// False after a checkpoint restore: earlier losses are unknown.
  bool wholeRun = true;
  void lose() {
    sector++;
    tour++;
    run++;
  }
}

class GameEventObserver {
  GameEventObserver(this.model);
  final ArcadeModel model;
  final _controller = StreamController<GameEvent>.broadcast(sync: true);

  /// Every observed event, raw and derived, in order.
  Stream<GameEvent> get stream => _controller.stream;

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

  /// [freshRun] false (a restored checkpoint) disables `flawlessRun`.
  void reset({bool freshRun = true}) {
    tally = FleetTally()..wholeRun = freshRun;
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

  /// Converts this frame's raw model events (already taken from the model)
  /// plus state changes into [GameEvent]s, publishes them on [stream] and
  /// returns them.
  List<GameEvent> observe(List<String> raw) {
    final out = <GameEvent>[];
    final clock = model.clock;
    void emit(String name, {String? variant, String? payload}) => out.add(
      GameEvent(name, clock: clock, variant: variant, payload: payload),
    );
    final shieldBefore = _powerLeft[Power.shield] ?? 0;
    for (final entry in raw) {
      final colon = entry.indexOf(':');
      final name = colon < 0 ? entry : entry.substring(0, colon);
      final payload = colon < 0 ? null : entry.substring(colon + 1);
      emit(GameEvents.aliases[name] ?? name, payload: payload);
      switch (name) {
        case 'level':
          _sectorStart(emit);
        case 'boss':
          final boss = model.boss;
          if (boss != null && !identical(boss, _boss)) {
            _boss = boss;
            _sectorStart(emit);
            emit(GameEvents.bossArrival);
          } else if (boss != null) {
            emit(GameEvents.bossPhase, variant: '${boss.phase}');
          }
        case 'allyLost' || 'allyRetreated':
          tally.lose();
        case 'levelclear':
          if (tally.sector == 0) emit(GameEvents.flawlessSector);
        case 'victory':
          if (tally.tour == 0) emit(GameEvents.flawlessVictory);
          tally.tour = 0;
          _boss = null;
        case 'completed':
          if (tally.run == 0 && tally.wholeRun) emit(GameEvents.flawlessRun);
        case 'life':
          tally.lose();
          emit(GameEvents.lifeLost);
          if (model.lives == 1) emit(GameEvents.lowLives);
        case 'hit':
          if (shieldBefore > .15 && !model.hasPower(Power.shield)) {
            emit(GameEvents.shieldBroken);
            _powerLeft.remove(Power.shield);
          }
        case 'wave':
          _clearWave();
      }
    }
    if (model.combat) _observeCombat(emit);
    _observePowers(emit);
    for (final event in out) {
      _controller.add(event);
    }
    return out;
  }

  void _sectorStart(
    void Function(String, {String? variant, String? payload}) emit,
  ) {
    // The model emits `level` (or `boss` in the carrier sector) exactly once
    // per sector entrance, including a restored checkpoint.
    _clearWave();
    tally.sector = 0;
    emit(GameEvents.sectorStart, variant: '${model.level}');
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
          emit(GameEvents.sentinelIncoming);
        }
        final telling = d.telegraph > 0 || d.rushing;
        if (telling && _telegraphing.add(d)) emit(GameEvents.sentinelDive);
        if (!telling && d.dive <= 0) _telegraphing.remove(d);
        continue;
      }
      if (d.elite && !d.entering && _seenElite.add(d)) {
        emit(GameEvents.eliteSighted);
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
      emit(GameEvents.diveWarning);
    } else if (_diveStarts.isEmpty) {
      _diveRunAnnounced = false;
    }
    _seenLarge.removeWhere((d) => !model.demons.contains(d));
    _seenElite.removeWhere((d) => !model.demons.contains(d));
    _telegraphing.removeWhere((d) => !model.demons.contains(d));
    _diving.removeWhere((d) => !model.demons.contains(d));
    for (final p in model.pickups) {
      if (_seenPickups.add(p) && p.power == Power.shield) {
        emit(GameEvents.shieldSpotted);
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
          emit(GameEvents.shieldCollected);
        } else {
          emit(GameEvents.weaponPickup, variant: power.name);
        }
      } else if (power == Power.shield &&
          before >= shieldWarningSeconds &&
          now < shieldWarningSeconds &&
          now > 0) {
        emit(GameEvents.shieldExpiring);
      }
      if (now > 0) {
        _powerLeft[power] = now;
      } else {
        _powerLeft.remove(power);
      }
    }
  }

  void dispose() => _controller.close();
}
