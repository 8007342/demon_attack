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
    this.open = '',
    this.vis = '',
    this.signature = false,
    this.emotion,
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

  /// Portrait frame per 1/15 s of the clip, as the character code 48 +
  /// [CommsFrame] index ('0' idle, '2'-'5' talk, '7' grunt/roar, '<' wide,
  /// '=' ee), measured from the clip's loudness envelope and visemes.
  final String mouth;

  /// Mouth openness per 1/15 s, '0'-'9' (smoothed loudness envelope); the
  /// lip-sync prefers it over [mouth] when present.
  final String open;

  /// Viseme estimate per 1/15 s from the clean voice's spectrum: '-' plain,
  /// 'o' rounded (o/u/w), 'e' spread or teeth (ee, s, sh, f).
  final String vis;

  /// Delivery the voice was rendered with (excited, urgent, panicked, ...).
  final String? emotion;

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
    this.group,
    this.urgent = false,
    this.exchange,
    this.overlap = false,
    this.transmission = false,
  });
  final String name;

  /// 0-10; [criticalPriority] and above is gameplay-critical.
  final int priority;
  final double cooldown, ttl, chance, delay;
  final List<CommsLine> lines;
  final CommsMood mood;

  /// Extra lines from other crew members after the first (celebrations).
  final int chain;

  /// Rate-limit family (e.g. `ground`): one line per family per its gap, so
  /// ground-war narration never drowns out the air callouts.
  final String? group;

  /// The only lines that may cut one already playing: true gameplay-critical
  /// warnings (a sentinel's dive, the shield running out, a breakthrough).
  final bool urgent;

  /// A two-party exchange: [CommsSide.demon] or [CommsSide.fleet] speaks
  /// first, the other side answers right after, and the channel is reserved
  /// for both turns. Null: the two parts queue independently.
  final CommsSide? exchange;

  /// May overlap other voices (the regroup celebration), staggered.
  final bool overlap;

  /// Shown as a full-size transmission in place of a transition on phones.
  final bool transmission;
  static const criticalPriority = 8;
  bool get critical => priority >= criticalPriority;

  /// The same trigger with some fields replaced (comms tuning overrides of
  /// the generated bank, see `comms_moments.dart`).
  CommsTriggerSpec copyWith({
    String? name,
    int? priority,
    double? cooldown,
    double? ttl,
    double? chance,
    double? delay,
    List<CommsLine>? lines,
    CommsMood? mood,
    String? group,
    bool? urgent,
  }) => CommsTriggerSpec(
    name: name ?? this.name,
    priority: priority ?? this.priority,
    cooldown: cooldown ?? this.cooldown,
    ttl: ttl ?? this.ttl,
    chance: chance ?? this.chance,
    delay: delay ?? this.delay,
    lines: lines ?? this.lines,
    mood: mood ?? this.mood,
    chain: chain,
    group: group ?? this.group,
    urgent: urgent ?? this.urgent,
    exchange: exchange,
    overlap: overlap,
    transmission: transmission,
  );
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

  /// Talk shapes added in v4: the widest opening and a teeth-showing 'ee'.
  static const talkWide = 12, talkEe = 13;
  static const count = 14;

  /// The talk shapes, closed to wide (openness levels 0-4).
  static const byLevel = [idle, talkA, talkB, talkC, talkWide];
}
