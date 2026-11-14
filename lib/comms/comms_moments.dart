/// More chatter at the big moments (comms-middle-ground): wave starts,
/// reinforcements, sentinel escorts, carrier phases and level transitions
/// rank as useful lines, and a few moments without a trigger of their own
/// reuse recorded clips from the 574-clip bank. Nothing here needs new
/// audio; lines still to be recorded are listed in
/// `art/comms/pending-lines-2026-11-14.json` and are not used at runtime.
library;

import '../game/game_events.dart';
import 'comms_bank.dart';
import 'comms_types.dart';

/// Events whose lines rank as useful (a shorter rest, a little budget
/// overdraft): the build-up beats of a wave, and the transitions.
const commsMomentEvents = {
  GameEventNames.sectorStart,
  GameEventNames.waveStart,
  GameEventNames.reinforcements,
  GameEventNames.reinforcementsArrived,
  GameEventNames.sentinelIncoming,
  GameEventNames.bossArrival,
  GameEventNames.bossPhase,
  GameEventNames.carrierHatchOpen,
  GameEventNames.bossDefeated,
  GameEventNames.levelClear,
  GameEventNames.salvage,
  GameEventNames.incoming,
};

/// Moments that announce the same thing share one cooldown: the next wave
/// seen on the horizon (`incoming`) and its arrival (`waveStart`).
const commsSharedCooldown = {
  GameEventNames.incoming: GameEventNames.waveStart,
  GameEventNames.waveStart: GameEventNames.incoming,
};

/// Events voiced by another event's trigger: the same moment observed twice
/// (the music director's `reinforcementsArrived` and the model's
/// `reinforcements`) shares one line, because the director never queues a
/// trigger that is already waiting or on air.
const commsEventAliases = {
  GameEventNames.reinforcementsArrived: GameEventNames.reinforcements,
};

CommsLine _line(
  Map<String, CommsTriggerSpec> bank,
  String trigger,
  String id,
) => bank[trigger]!.lines.firstWhere((l) => l.id == id);

/// Retuned bank triggers: moments that went too quiet after comms-pacing.
final _humanTuning = <String, CommsTriggerSpec>{
  // A new wave forming up: said more often (was 55 %, one per 24 s).
  'waveStart': commsHumanTriggers['waveStart']!.copyWith(
    chance: .85,
    cooldown: 16,
    ttl: 6,
  ),
  // Reinforcements wait a little longer for the channel.
  'reinforcements': commsHumanTriggers['reinforcements']!.copyWith(
    cooldown: 10,
    ttl: 5,
  ),
  'sentinelIncoming': commsHumanTriggers['sentinelIncoming']!.copyWith(ttl: 5),
  // The salvage sweep between waves (was 50 %, one per 60 s).
  'salvage': commsHumanTriggers['salvage']!.copyWith(
    chance: .85,
    cooldown: 30,
    ttl: 4,
  ),
  'bossPhase': commsHumanTriggers['bossPhase']!.copyWith(ttl: 4.5),
};

final _demonTuning = <String, CommsTriggerSpec>{
  'waveStart': commsDemonTriggers['waveStart']!.copyWith(
    chance: .8,
    cooldown: 16,
  ),
  'reinforcements': commsDemonTriggers['reinforcements']!.copyWith(
    cooldown: 12,
    ttl: 4,
  ),
};

/// Moments without a trigger in the generated bank, built from its clips.
final _humanMoments = <String, CommsTriggerSpec>{
  // The carrier's hatch opens: its core is exposed.
  GameEventNames.carrierHatchOpen: CommsTriggerSpec(
    name: GameEventNames.carrierHatchOpen,
    priority: 7,
    cooldown: 20,
    ttl: 3,
    mood: CommsMood.happy,
    lines: [
      _line(commsHumanTriggers, 'bossPhase', 'bossPhase.h2'),
      _line(commsHumanTriggers, 'bossPhase', 'bossPhase.h0'),
    ],
  ),
  // Wave pressure: the next wave appears on the horizon (model `incoming`).
  // The scope / forming-up calls of waveStart fit a sighting; the arrival
  // lines ("Here comes round two!") stay with waveStart itself.
  GameEventNames.incoming: CommsTriggerSpec(
    name: GameEventNames.incoming,
    priority: 4,
    cooldown: 16,
    ttl: 5,
    lines: [
      _line(commsHumanTriggers, 'waveStart', 'waveStart.h0'),
      _line(commsHumanTriggers, 'waveStart', 'waveStart.h2'),
      _line(commsHumanTriggers, 'waveStart', 'waveStart.h4'),
    ],
  ),
};

final _demonMoments = <String, CommsTriggerSpec>{
  GameEventNames.carrierHatchOpen: CommsTriggerSpec(
    name: GameEventNames.carrierHatchOpen,
    priority: 5,
    cooldown: 20,
    ttl: 3,
    delay: .3,
    lines: [_line(commsDemonTriggers, 'bossPhase', 'bossPhase.d2')],
  ),
};

/// The human bank the director uses: the generated triggers with the
/// moment tuning and the reused-clip moments.
Map<String, CommsTriggerSpec> commsHumanBank(
  Map<String, CommsTriggerSpec> base,
) => {...base, ..._humanTuning, ..._humanMoments};

Map<String, CommsTriggerSpec> commsDemonBank(
  Map<String, CommsTriggerSpec> base,
) => {...base, ..._demonTuning, ..._demonMoments};
