/// Level and mission transition interludes: one primary card per transition,
/// alternating a silent illustrated tip with a full-size radio card that
/// plays a line from the recorded comms bank. Pure Dart, seeded, testable.
/// See openspec/changes/fluid-transitions.
library;

import 'dart:math';

import '../comms/comms_bank.dart';
import '../comms/comms_types.dart';
import 'difficulty.dart';
import 'hints.dart';

enum InterludeKind { tip, radio }

/// What a radio card says: the next mission, crew banter, a joke or a brood
/// taunt.
enum RadioCategory { briefing, banter, joke, taunt }

/// Seconds a player needs to read [text]: a moment to find the card, then
/// about 240 words a minute.
double readSeconds(String text) {
  final words = text.trim().isEmpty
      ? 0
      : text.trim().split(RegExp(r'\s+')).length;
  return InterludeTiming.orient + words / InterludeTiming.wordsPerSecond;
}

abstract final class InterludeTiming {
  /// A fade is one beat of the 120 BPM score.
  static const fade = .5;
  static const orient = 1.2;
  static const wordsPerSecond = 4.0;

  /// Subtitles stay readable this long after the clip.
  static const hold = .8;

  /// How long a radio card waits for the squad channel before it plays its
  /// own line.
  static const adoptWait = 1.2;

  /// The shortest window worth a card at all.
  static const minWindow = 3.0;
}

/// A radio line from the bank, with the trigger it belongs to.
class RadioPick {
  const RadioPick(this.spec, this.line, this.category);
  final CommsTriggerSpec spec;
  final CommsLine line;
  final RadioCategory category;

  /// Spoken subtitle, or the brood's translated gloss.
  String get text => line.text ?? line.gloss ?? '';

  /// Time the card needs: the clip and its hold, or the reading time.
  double get needs =>
      max(line.duration + InterludeTiming.hold, readSeconds(text));
}

/// One planned interlude.
class InterludePlan {
  InterludePlan.tip(this.tip, {required this.window, required this.showDetail})
    : kind = InterludeKind.tip,
      radio = null;
  InterludePlan.radio(this.radio, {required this.window})
    : kind = InterludeKind.radio,
      tip = null,
      showDetail = false;

  final InterludeKind kind;
  final TacticalHint? tip;
  final RadioPick? radio;

  /// Seconds the card may be up: never more than the transition allows.
  final double window;

  /// Tips show their detail sentence only when the window lets it be read.
  final bool showDetail;

  String get id => tip?.id ?? radio!.line.id;

  /// The words on the card.
  String get text => tip != null
      ? showDetail
            ? '${tip!.title} ${tip!.detail}'
            : tip!.title
      : radio!.text;

  /// Seconds the card needs to be read (and, for radio, heard).
  double get needs => tip != null ? readSeconds(text) : radio!.needs;
}

/// Context of the transition the card plays in.
class InterludeContext {
  const InterludeContext({
    required this.difficulty,
    required this.level,
    required this.route,
    required this.window,
    this.crew = const {},
    this.flawless = false,
    this.struggling = false,
    this.nextIsCarrier = false,
  });

  final Difficulty difficulty;

  /// The sector and route the player is heading into.
  final int level, route;

  /// Seconds the transition gives the card (fades included).
  final double window;

  /// This run's radio crew (lineup members); empty: anyone.
  final Set<String> crew;

  /// The last sector was flown without losing a ship.
  final bool flawless;

  /// Lives are low or ships were lost: the crew sounds warmer.
  final bool struggling;
  final bool nextIsCarrier;
}

/// Plans the interludes of one run: the opening is a tip (the first tactical
/// briefing), then tips and radio cards alternate. Items are seeded and the
/// same item never shows twice in a row; a card is only planned when its text
/// can be read inside the window.
class InterludePlanner {
  InterludePlanner({int? seed})
    : seed = seed ?? DateTime.now().microsecondsSinceEpoch & 0x3fffffff {
    _random = Random(this.seed);
    hints = HintDeck(random: Random(this.seed ^ 0x5bd1e995));
  }

  final int seed;
  late final Random _random;
  late final HintDeck hints;
  InterludeKind? lastKind;
  String? lastId;
  final _recent = <String>[];
  int count = 0;

  /// Lines a radio card was given by the squad channel instead of its own
  /// pick still count as shown.
  void shown(String id) {
    lastId = id;
    _recent
      ..remove(id)
      ..add(id);
    if (_recent.length > 8) _recent.removeAt(0);
  }

  InterludePlan? plan(InterludeContext c) {
    if (c.window < InterludeTiming.minWindow) return null;
    final want = lastKind == null
        ? InterludeKind.tip
        : lastKind == InterludeKind.tip
        ? InterludeKind.radio
        : InterludeKind.tip;
    InterludePlan? result;
    if (want == InterludeKind.radio) result = _radio(c);
    result ??= _tip(c);
    if (result == null) return null;
    lastKind = result.kind;
    count++;
    shown(result.id);
    return result;
  }

  InterludePlan? _tip(InterludeContext c) {
    // The deck already avoids repeats within a round; it is asked again
    // only in the rare case it hands back the card just shown.
    var hint = hints.next(
      difficulty: c.difficulty,
      level: c.level,
      route: c.route,
    );
    if (hint.id == lastId) {
      hint = hints.next(
        difficulty: c.difficulty,
        level: c.level,
        route: c.route,
      );
    }
    final room = c.window - InterludeTiming.fade;
    final full = readSeconds('${hint.title} ${hint.detail}') <= room;
    if (!full && readSeconds(hint.title) > room) return null;
    return InterludePlan.tip(hint, window: c.window, showDetail: full);
  }

  InterludePlan? _radio(InterludeContext c) {
    final room =
        c.window - InterludeTiming.fade * 2 - InterludeTiming.adoptWait;
    final order = _categories(c);
    for (final category in order) {
      final pool = [
        for (final pick in radioPool(category, level: c.level, crew: c.crew))
          if (pick.needs <= room && !_recent.contains(pick.line.id)) pick,
      ];
      if (pool.isEmpty) continue;
      final suited = _prefer(pool, c);
      return InterludePlan.radio(
        suited[_random.nextInt(suited.length)],
        window: c.window,
      );
    }
    return null;
  }

  /// Categories in the order to try: a seeded draw weighted by the moment,
  /// then the rest as fallbacks.
  List<RadioCategory> _categories(InterludeContext c) {
    final weights = <RadioCategory, double>{
      RadioCategory.briefing: c.nextIsCarrier ? 6 : 3,
      RadioCategory.banter: c.struggling ? 3 : 2,
      RadioCategory.joke: c.flawless ? 3 : 2,
      RadioCategory.taunt: c.struggling ? 1 : 2,
    };
    final order = <RadioCategory>[];
    while (weights.isNotEmpty) {
      final total = weights.values.fold(0.0, (a, b) => a + b);
      var roll = _random.nextDouble() * total;
      var chosen = weights.keys.last;
      for (final entry in weights.entries) {
        roll -= entry.value;
        if (roll <= 0) {
          chosen = entry.key;
          break;
        }
      }
      order.add(chosen);
      weights.remove(chosen);
    }
    return order;
  }

  /// Lines whose delivery suits the moment, when there are any.
  List<RadioPick> _prefer(List<RadioPick> pool, InterludeContext c) {
    final moods = c.flawless
        ? const {'excited', 'triumphant', 'teasing'}
        : c.struggling
        ? const {'warm', 'calm'}
        : const <String>{};
    if (moods.isEmpty) return pool;
    final fit = [
      for (final p in pool)
        if (moods.contains(p.line.emotion)) p,
    ];
    return fit.isEmpty ? pool : fit;
  }
}

/// Recorded lines suited to a transition, from the 574-clip bank. Human lines
/// keep to [crew] (this run's lineup) when it has any; brood lines to the
/// officers of [level].
List<RadioPick> radioPool(
  RadioCategory category, {
  required int level,
  Set<String> crew = const {},
}) {
  final picks = <RadioPick>[];
  void add(
    Map<String, CommsTriggerSpec> bank,
    String trigger, [
    bool Function(CommsLine)? keep,
  ]) {
    final spec = bank[trigger];
    if (spec == null) return;
    for (final line in spec.lines) {
      if (keep == null || keep(line)) {
        picks.add(RadioPick(spec, line, category));
      }
    }
  }

  bool joke(CommsLine l) => l.signature || l.emotion == 'teasing';
  switch (category) {
    case RadioCategory.briefing:
      add(commsHumanTriggers, 'transmissionMission.$level');
      add(commsHumanTriggers, 'sectorStart.$level');
      add(commsHumanTriggers, 'transmissionMission');
    case RadioCategory.banter:
      add(commsHumanTriggers, 'transmissionJunior', (l) => !joke(l));
      add(commsHumanTriggers, 'sectorStart', (l) => !joke(l));
    case RadioCategory.joke:
      add(commsHumanTriggers, 'transmissionJunior', joke);
      add(commsHumanTriggers, 'sectorStart', joke);
      add(commsHumanTriggers, 'broodTaunt', joke);
    case RadioCategory.taunt:
      add(commsDemonTriggers, 'broodTaunt');
      add(commsDemonTriggers, 'levelClear');
  }
  final officers = commsDemonSectors[level.clamp(1, 5)] ?? const [];
  final cast = [
    for (final p in picks)
      if (commsCast[p.line.speaker]?.isDemon ?? false
          ? officers.contains(p.line.speaker)
          : crew.isEmpty || crew.contains(p.line.speaker))
        p,
  ];
  return cast.isEmpty ? picks : cast;
}
