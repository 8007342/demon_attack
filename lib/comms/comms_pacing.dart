/// How much the squad radio talks, and what gets through first.
///
/// The score is the star: the channel keeps real silence between
/// transmissions. A seeded airtime budget (a leaky bucket refilled at
/// [CommsPacing.duty] seconds of speech per second) and a jittered rest
/// after every line pace ordinary chatter; useful calls may overdraw the
/// budget a little and wait a shorter rest; the must-play ground-fire
/// warnings are outside the budget altogether. See
/// openspec/changes/comms-pacing.
library;

import 'comms_bank.dart';
import 'comms_types.dart';

/// What a message is for, lowest to highest precedence.
enum CommsClass {
  /// Colour and banter: paced hardest, dropped first, never stacked.
  flavour,

  /// Story clues, mission briefings, critical moments and the dive calls
  /// that end on the dive: a shorter rest and a little budget overdraft.
  useful,

  /// A shield or power-up recommendation while the ship lacks it.
  hint,

  /// Gameplay-critical warnings ([CommsTriggerSpec.urgent]): may cut any
  /// line except a must-play warning.
  urgent,

  /// Ground fire at the player: never dropped by the pacing, never cut,
  /// end-aligned to the launch, outside the airtime budget.
  mustPlay,
}

class CommsPacing {
  const CommsPacing({
    this.duty = .16,
    this.burst = 4,
    this.debt = 3,
    this.rest = 3,
    this.restJitter = 2.5,
    this.usefulRest = 1,
    this.usefulRestJitter = .8,
    this.flavourTtl = 2.5,
    this.flavourQueue = 2,
    this.hintCooldown = 12,
    this.hintTtl = 4,
    this.diveGap = 16,
    this.diveTolerance = .3,
    this.warningWindow = .8,
    this.warningCover = 2,
    this.timed = true,
  });

  /// The pre-pacing director: back-to-back lines a [CommsDirector.lineGap]
  /// apart, no budget, no stacking limit, untimed dive calls. Unit tests of
  /// sequencing and casting use it.
  static const legacy = CommsPacing(
    duty: double.infinity,
    rest: 0,
    restJitter: 0,
    usefulRest: 0,
    usefulRestJitter: 0,
    flavourTtl: double.infinity,
    flavourQueue: 1 << 20,
    timed: false,
  );

  /// Seconds of speech the budget earns per second (the long-run airtime
  /// of paced lines in busy combat), the most it can bank, and how far a
  /// useful or hint line may overdraw it.
  final double duty, burst, debt;

  /// Silence after a line before the next flavour line: [rest] plus up to
  /// [restJitter] of seeded noise. Useful lines wait [usefulRest] plus up to
  /// [usefulRestJitter].
  final double rest, restJitter, usefulRest, usefulRestJitter;

  /// A flavour line waits at most this long in the queue, and at most
  /// [flavourQueue] of them wait at once (the best one is kept).
  final double flavourTtl;
  final int flavourQueue;

  /// One recommendation per this many seconds, waiting at most [hintTtl].
  final double hintCooldown, hintTtl;

  /// Seconds between two ordinary dive calls.
  final double diveGap;

  /// A dive call ends within this many seconds of the dive start.
  final double diveTolerance;

  /// A ground-fire warning ends at the launch or at most [warningWindow]
  /// before it; one that ended within [warningCover] before a launch also
  /// covers it (a salvo shares its warning).
  final double warningWindow, warningCover;

  /// Dive calls and ground-fire warnings are scheduled from their lead
  /// events (`divePrep`, `groundFirePrep`) instead of played when observed.
  final bool timed;
}

/// Lines that hint at the ending (turns, supplies, sand, snacks, an
/// afternoon's play): they rank as useful rather than flavour.
final _clue = RegExp(
  r'\b(turns?|afternoon|sunshine|snacks?|sand|suppl(y|ies)|board|lunch|'
  r'burgers?|fries|sodas?)\b',
  caseSensitive: false,
);

bool commsIsClue(CommsLine line) =>
    _clue.hasMatch(line.text ?? '') || _clue.hasMatch(line.gloss ?? '');

CommsLine _bankLine(String trigger, String id) =>
    commsHumanTriggers[trigger]!.lines.firstWhere((l) => l.id == id);

/// Recommendations without a trigger of their own in the generated bank,
/// built from its general "grab it" lines.
final commsHintTriggers = <String, CommsTriggerSpec>{
  'powerupSpotted': CommsTriggerSpec(
    name: 'powerupSpotted',
    priority: 6,
    cooldown: 12,
    ttl: 4,
    mood: CommsMood.happy,
    lines: [
      _bankLine('salvage', 'salvage.h1'),
      _bankLine('salvage', 'salvage.h2'),
    ],
  ),
};
