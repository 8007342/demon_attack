/// Data types of the squad comms line bank. The constants themselves are
/// generated into `comms_bank.dart` by `tools/comms_pipeline.py dart` from
/// `art/comms/cast.json`, `art/comms/lines.json` and the clip manifest.
library;

enum CommsSide { fleet, ground, demon }

/// Face held after a line ends (and the expression of its emphasis).
enum CommsMood { stern, happy, worried }

class CommsCharacter {
  const CommsCharacter({
    required this.id,
    required this.side,
    required this.name,
    required this.rank,
    required this.callsign,
    required this.accent,
  });
  final String id;
  final CommsSide side;
  final String name, rank, callsign;

  /// Frame accent colour (ARGB).
  final int accent;
  bool get isDemon => side == CommsSide.demon;
}

class CommsLine {
  const CommsLine({
    required this.id,
    required this.speaker,
    required this.duration,
    this.text,
    this.grunt,
    this.gloss,
    this.mouth = '',
    this.signature = false,
  });

  /// Clip id, also the audio file stem under web/audio/comms/.
  final String id;
  final String speaker;

  /// Spoken subtitle (human lines).
  final String? text;

  /// Vocal gesture of a demon grunt: order, rally, gloat, alarm, roar, snarl.
  final String? grunt;

  /// Fleet signal-intelligence reading of a grunt, shown under its glyphs.
  final String? gloss;

  /// Clip length in seconds.
  final double duration;

  /// Portrait frame per 1/15 s of the clip ('0' idle, '2'-'5' talk, '6'
  /// shout, '7' grunt/roar), measured from the clip's loudness envelope.
  final String mouth;

  /// A catchphrase or pun: the director rations these so they stay fun.
  final bool signature;
  bool get isGrunt => grunt != null;
}

class CommsTriggerSpec {
  const CommsTriggerSpec({
    required this.name,
    required this.priority,
    required this.cooldown,
    required this.ttl,
    required this.lines,
    this.chance = 1,
    this.delay = 0,
    this.mood = CommsMood.stern,
    this.chain = 0,
  });
  final String name;

  /// 0-10; [criticalPriority] and above is gameplay-critical.
  final int priority;
  final double cooldown, ttl, chance, delay;
  final List<CommsLine> lines;
  final CommsMood mood;

  /// Extra lines from other crew members after the first (celebrations).
  final int chain;
  static const criticalPriority = 8;
  bool get critical => priority >= criticalPriority;
}

/// Portrait frame indices in each atlas row.
abstract final class CommsFrame {
  static const idle = 0, blink = 1, talkA = 2, talkB = 3, talkC = 4;
  static const talkD = 5, shout = 6;

  /// Demons: the roar of a grunt. Humans: alarm.
  static const grunt = 7;

  /// Humans: smile. Demons: smug gloat.
  static const happy = 8;

  /// Humans: worried. Demons: alarmed snarl.
  static const worried = 9;
  static const tiltLeft = 10, tiltRight = 11;
  static const count = 12;
}
