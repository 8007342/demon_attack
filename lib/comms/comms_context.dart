/// What the squad radio knows about the fight below, so lines about air
/// cover and the ground battle only play when they are true.
///
/// Fed by every [GameEvent] the director sees (ground-war events, the
/// observer's `groundPicture` state changes, homing kills). Pure Dart and
/// clocked by the caller, like the director. See
/// openspec/changes/comms-middle-ground.
library;

import '../game/game_events.dart';
import 'comms_types.dart';

/// A condition a line's words assume about the fight below.
enum CommsGate {
  /// Demon ground units are on the field and fighting the convoy.
  groundEngaged,

  /// An ally called for help (`allyUnderAttack`) in the last
  /// [CommsGroundPicture.attackedWindow] seconds.
  allyAttacked,

  /// The ship flies over the ground battle (within reach of a foe).
  overFight,

  /// The ground war is part of this sector at all.
  groundActive,

  /// The player's homing missiles saved an ally or killed a ground unit in
  /// the last [CommsGroundPicture.helpedWindow] seconds.
  playerHelped,

  /// The event credits the convoy's artillery (`by` 'artillery').
  artillery,

  /// The event happened on the left / right half of the arena.
  leftFlank,
  rightFlank,

  /// The event's demon force / the convoy's force is infantry.
  foeInfantry,
  allyInfantry,
}

/// Lines (by clip id) whose text assumes something about the fight below.
/// Audited from the bank's ground- and cover-related triggers: the trigger
/// event itself is true when it fires, so only words that go beyond it are
/// gated.
const commsLineGates = <String, Set<CommsGate>>{
  // "Air wing has our backs." / "They're right under you." ...
  'groundForceSighted.h8': {CommsGate.overFight},
  'groundForceInRange.h2': {CommsGate.overFight},
  'groundForceInRange.h3': {CommsGate.overFight},
  'groundForceInRange.h4': {CommsGate.overFight},
  // Calls for help outside allyUnderAttack itself.
  'groundPressureHigh.h0': {CommsGate.allyAttacked},
  'groundPressureHigh.h1': {CommsGate.allyAttacked},
  'groundPressureHigh.h3': {CommsGate.allyAttacked},
  'groundPressureHigh.h4': {CommsGate.allyAttacked},
  'groundTide.surge.h2': {CommsGate.allyAttacked},
  'groundTide.surge.h4': {CommsGate.allyAttacked},
  'convoyStuck.h1': {CommsGate.groundEngaged},
  'convoyStuck.h3': {CommsGate.groundEngaged},
  'convoyClimbing.h3': {CommsGate.groundEngaged},
  'homingPickup.h4': {CommsGate.groundEngaged},
  // "Thanks to you." / "Thanks for the thunder!"
  'groundPressureEased.h3': {CommsGate.playerHelped},
  'skirmishWon.h4': {CommsGate.artillery},
  // Which flank, and whose boots.
  'groundSkirmish.h0': {CommsGate.leftFlank},
  'groundSkirmish.h5': {CommsGate.rightFlank},
  'infantryEngaged.h2': {CommsGate.allyInfantry},
  'infantryEngaged.h4': {CommsGate.foeInfantry},
  'infantryEngaged.h5': {CommsGate.allyInfantry},
  // Ground crews answering the brood, and the brood asking about the convoy.
  'broodTaunt.h10': {CommsGate.groundActive},
  'broodTaunt.h11': {CommsGate.groundActive},
  'demonRout.d3': {CommsGate.groundActive},
  'demonRout.d7': {CommsGate.groundActive},
};

/// Whole triggers that only make sense while the ground fight is on.
const commsTriggerGates = <String, Set<CommsGate>>{
  'groundPressureRising': {CommsGate.groundEngaged},
  'groundPressureHigh': {CommsGate.groundEngaged},
  'groundTide.surge': {CommsGate.groundEngaged},
};

class CommsGroundPicture {
  /// Seconds a ground-fight event counts as "the ground is engaged" when no
  /// observer picture is available.
  static const engagedWindow = 8.0;

  /// Seconds an `allyUnderAttack` call stays true.
  static const attackedWindow = 10.0;

  /// Seconds the player's homing help is remembered.
  static const helpedWindow = 15.0;

  /// Half the arena width: left / right flank.
  static const midX = 180.0;

  /// Events that show the ground battle is on.
  static const _fight = {
    GameEventNames.groundForceInRange,
    GameEventNames.allyUnderAttack,
    GameEventNames.groundBreakthrough,
    GameEventNames.groundBreakthroughWarning,
    GameEventNames.groundFirePrep,
    GameEventNames.groundMissileLaunch,
    GameEventNames.groundSkirmish,
    GameEventNames.infantryEngaged,
    GameEventNames.heavyArmorSighted,
    GameEventNames.allyFallingBack,
    GameEventNames.groundPressureRising,
    GameEventNames.groundPressureHigh,
  };

  static const _ground = {
    ..._fight,
    GameEventNames.groundForceSighted,
    GameEventNames.groundUnitDestroyed,
    GameEventNames.allySaved,
    GameEventNames.allyRetreated,
    GameEventNames.skirmishWon,
    GameEventNames.groundTide,
    GameEventNames.groundPressureEased,
    GameEventNames.groundPicture,
  };

  double _fightAt = -1e9, _attackedAt = -1e9, _helpedAt = -1e9;
  bool _groundActive = false;

  /// The observer's latest state (null: none seen this sector).
  int? engaged;
  bool over = false;

  void reset() {
    _fightAt = _attackedAt = _helpedAt = -1e9;
    _groundActive = false;
    engaged = null;
    over = false;
  }

  /// Records what [event] says about the fight at [at].
  void note(GameEvent event, double at) {
    final name = event.name;
    if (name == GameEventNames.sectorStart) {
      reset();
      return;
    }
    if (_ground.contains(name)) _groundActive = true;
    if (_fight.contains(name)) _fightAt = at;
    switch (name) {
      case GameEventNames.groundPicture:
        final n = event.data['engaged'];
        engaged = n is num ? n.toInt() : null;
        over = event.data['over'] == true;
      case GameEventNames.allyUnderAttack:
        _attackedAt = at;
      case GameEventNames.allySaved:
        _helpedAt = at;
      case GameEventNames.groundUnitDestroyed:
        if ((event.data['by'] ?? 'allies') != 'allies') _helpedAt = at;
      case GameEventNames.homingHit:
        if (event.data['killed'] == true) _helpedAt = at;
    }
  }

  bool groundEngaged(double now) {
    final n = engaged;
    if (n != null) return n > 0;
    return now - _fightAt <= engagedWindow;
  }

  /// Without an observer picture the convoy is assumed under the ship (it
  /// follows the ship's x) whenever the ground is engaged.
  bool overFight(double now) =>
      engaged == null ? groundEngaged(now) : (engaged! > 0 && over);

  bool allyAttacked(double now) =>
      now - _attackedAt <= attackedWindow && groundEngaged(now);

  bool holds(CommsGate gate, GameEvent? event, double now) {
    final data = event?.data ?? const {};
    double? x() => (data['x'] as num?)?.toDouble();
    switch (gate) {
      case CommsGate.groundEngaged:
        return groundEngaged(now);
      case CommsGate.allyAttacked:
        return allyAttacked(now);
      case CommsGate.overFight:
        return overFight(now);
      case CommsGate.groundActive:
        return _groundActive;
      case CommsGate.playerHelped:
        return now - _helpedAt <= helpedWindow;
      case CommsGate.artillery:
        return data['by'] == 'artillery';
      case CommsGate.leftFlank:
        return (x() ?? midX + 1) < midX;
      case CommsGate.rightFlank:
        return (x() ?? midX - 1) >= midX;
      case CommsGate.foeInfantry:
        return data['force'] == 'infantry';
      case CommsGate.allyInfantry:
        return data['allyForce'] == 'infantry';
    }
  }

  /// [line] of [spec] may be said now, for [event].
  bool allows(
    CommsTriggerSpec spec,
    CommsLine line,
    GameEvent? event,
    double now,
  ) {
    for (final gate in commsTriggerGates[spec.name] ?? const <CommsGate>{}) {
      if (!holds(gate, event, now)) return false;
    }
    for (final gate in commsLineGates[line.id] ?? const <CommsGate>{}) {
      if (!holds(gate, event, now)) return false;
    }
    return true;
  }
}
