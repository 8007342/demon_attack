/// bonus-briefing: the "URGENT MISSION!" radio card that opens a bonus
/// level (openspec/changes/bonus-levels, design "Urgent-mission card").
///
/// bonus-briefing-clarity (openspec/changes/bonus-briefing-clarity): the
/// card shows the level's name, its goal line, its how-to line, the run
/// modifier in play and ONE radio line (the level's `bonusCall.<id>`, a
/// single sentence in a squadmate's voice) as it is spoken; the dock hides
/// that line while the card is up. The card's life is its own: it opens at
/// the transition's radio slot whatever the channel is doing, stays up for
/// at least [BonusBriefing.readFor] unless the player taps, and the radio
/// never closes it (the operator, round 6: "the overlapping of the radio
/// chatter closed the box before I was able to read it"). Pure Dart,
/// driven by the comms clock, so the timing is testable without widgets.
///
/// Audio and text stay honest: the card's lines come from triggers marked
/// `"pending": "text"` in `art/comms/lines.json`. Until they are recorded
/// (tillandsias#1103) they are silent written lines ([CommsLine.silent]):
/// the card shows their own words and nothing borrowed is heard. Once
/// recorded they are voiced with no code change.
library;

import 'dart:math' as math;

import '../game/bonus/bonus_types.dart';
import 'comms_bank.dart';
import 'comms_director.dart';
import 'comms_types.dart';

class BonusBriefing {
  BonusBriefing({
    required this.level,
    required this.sector,
    required this.invite,
    required this.inviteSpec,
    this.modifier,
  });

  /// The bonus level ahead and the sector it replaces.
  final BonusLevelDef level;
  final int sector;

  /// The run modifier in play, if any (shown as the card's run rule).
  final RunModifierDef? modifier;

  /// The slot's own pick: the level's entry call. It marks the slot as a
  /// bonus briefing; the card speaks [call] instead, and this line only
  /// when the level has no call of its own.
  final CommsLine invite;
  final CommsTriggerSpec inviteSpec;

  /// Fade in and out (none with reduced motion).
  static const fade = .25;

  /// The card may stay this long into the level's first combat seconds
  /// (the swarm is still settling); then it goes, whatever is left.
  static const combatGrace = 1.2;

  /// The hush the card asks for while it is up (ended when it closes).
  static const hushFor = 60.0;

  /// Title of the card.
  static const title = 'URGENT MISSION!';

  /// The card's radio turn once offered (one line; empty when it could not
  /// queue, and the card is up all the same).
  List<CommsMessage> turns = const [];
  bool _offered = false;
  double? openedAt, closedAt, _combatAt;

  /// bonus-briefing-clarity: the shortest time the card stays up unless
  /// the player taps, Space or Enter (a first-time reader, a kid too).
  static const minRead = 4.0;

  /// The longest reading time asked for (the hold stays short).
  static const maxRead = 8.0;

  /// The player dismissed the card (tap, Space or Enter).
  bool dismissed = false;

  // --- mission-medals: the card holds the level's start until it has been
  // read or tapped (the operator: "instructions … went too fast").

  /// The longest the card may hold the level's start, whatever is left.
  static const maxHold = 15.0;

  /// Seconds of flight left when the hold begins (the Descent's end: the
  /// ship is in place and nothing fires yet).
  static const holdLead = .25;

  /// When the current hold began (null: not holding now).
  double? heldAt;

  /// The card is holding the level's start (it shows its tap prompt).
  bool get holding => heldAt != null && open;

  double _heldFor = 0;

  /// Seconds the goal, the how-to line and the run rule need once the
  /// card is up: about 18 characters a second after a 1.5 s glance,
  /// between [minRead] and [maxRead].
  double get readFor {
    final chars = brief.length + how.length + (rule?.length ?? 0);
    return (1.5 + chars / 18).clamp(minRead, maxRead);
  }

  /// The card has been up for [readFor]. Only time counts: the radio's
  /// progress never shortens (or ends) the read.
  bool read(double now) {
    final opened = openedAt;
    if (opened == null) return true;
    return now - opened >= readFor;
  }

  /// Whether the game should hold the level's start at [now] (asked every
  /// frame; [flying] and [flightLeft] as in [update]). Holds only at the
  /// flight's very end, only while open and unread, at most [maxHold].
  bool holds(
    CommsDirector director,
    double now, {
    required bool flying,
    required double flightLeft,
  }) {
    final want =
        open &&
        flying &&
        flightLeft <= holdLead &&
        _heldFor < maxHold &&
        !read(now);
    if (!want) {
      if (heldAt != null) _heldFor += now - heldAt!;
      heldAt = null;
      return false;
    }
    heldAt ??= now;
    if (_heldFor + now - heldAt! >= maxHold) {
      _heldFor = maxHold;
      heldAt = null;
      return false;
    }
    return true;
  }

  bool get offered => _offered;

  /// The card is up (not closing).
  bool get open => openedAt != null && closedAt == null;

  /// The card is drawn at [now] (open or fading out).
  bool visible(double now) =>
      openedAt != null && (closedAt == null || now < closedAt! + fade);

  /// 0-1 at [now]: the fade in and out; with [reduce] it is 1 or 0.
  double opacity(double now, {bool reduce = false}) {
    final opened = openedAt;
    if (opened == null) return 0;
    final closed = closedAt;
    if (reduce) return closed == null ? 1 : 0;
    final fadeIn = ((now - opened) / fade).clamp(0.0, 1.0);
    final fadeOut = closed == null
        ? 1.0
        : (1 - (now - closed) / fade).clamp(0.0, 1.0);
    return math.min(fadeIn, fadeOut);
  }

  /// The turns the dock leaves to the card while it is drawn.
  Set<CommsMessage> hiddenAt(double now) =>
      visible(now) ? {...turns} : const {};

  /// The turns started so far (what the card's chatter shows).
  List<CommsMessage> spoken() => [
    for (final m in turns)
      if (m.started) m,
  ];

  /// The latest turn on the card (its portrait is the card's).
  CommsMessage? current() => spoken().lastOrNull;

  /// The level's goal line (the card's headline).
  String get brief => level.brief;

  /// The level's how-to line, under the goal.
  String get how => level.how;

  /// The run modifier's rule, if one is in play.
  String? get rule {
    final m = modifier;
    if (m == null || m.brief.isEmpty) return null;
    return m.brief;
  }

  /// The card's one radio line: the level's `bonusCall.<id>` (a single
  /// sentence, not a copy of the card's text), else the slot's invite.
  (CommsLine, CommsTriggerSpec) get call {
    final spec = commsHumanTriggers['bonusCall.${level.id}'];
    final line = spec?.lines.firstOrNull;
    if (spec == null || line == null || commsCast[line.speaker] == null) {
      return (invite, inviteSpec);
    }
    return (line, spec);
  }

  /// The script: exactly one turn, [call].
  List<(CommsLine, CommsTriggerSpec)> script() => [call];

  /// Seconds the slot should give the card: its line on the channel (and
  /// the grace gap and half its reading hold), or its reading time if
  /// longer.
  double needs({double gap = .4}) {
    final (line, _) = call;
    final talk = line.duration + gap + CommsMessage.readingTime(line) * .5;
    return math.max(talk, readFor);
  }

  /// Opens the card and queues its line on [director]. [ttl]: how long
  /// the line may wait for the channel. The card opens even when the line
  /// cannot queue: the words on the card are the instructions, the radio
  /// only keeps the flow. Always true once offered.
  bool offer(CommsDirector director, {required double now, double ttl = 6}) {
    if (_offered) return true;
    _offered = true;
    turns = director.offerScript(script(), at: now, ttl: ttl);
    openedAt = now;
    // The card is the transition's radio: the rest of the squad waits (a
    // line on air finishes, an exchange on screen gets its answer).
    director.hush(hushFor, at: now);
    return true;
  }

  /// Every frame. [flying]: the transition into the level is still on;
  /// [flightLeft]: seconds until it ends (its Descent's last frame);
  /// [combat]: the level's fight has begun.
  void update(
    CommsDirector director,
    double now, {
    required bool flying,
    required double flightLeft,
    required bool combat,
  }) {
    if (!open) return;
    if (combat && !flying) _combatAt ??= now;
    final combatFor = _combatAt == null ? 0.0 : now - _combatAt!;
    // bonus-briefing-clarity: the radio has no say. The card goes when the
    // player dismisses it, when the fight has run [combatGrace] (the hold
    // has already given it its reading time), or when its transition is
    // over and it has been read.
    final fought = combatFor >= combatGrace;
    final over = !flying || flightLeft <= 0;
    if (dismissed || fought || (over && read(now))) close(director, now);
  }

  /// The player's skip: the card closes; a turn on air finishes in the
  /// dock and the rest of the script is withdrawn.
  void dismiss(CommsDirector director, double now) {
    if (!open) return;
    dismissed = true;
    close(director, now);
  }

  /// Closes the card and withdraws every turn that has not started (a
  /// line on air is never cut; it finishes as an ordinary dock toast).
  void close(CommsDirector director, double now) {
    if (!open) return;
    closedAt = now;
    for (final m in turns.reversed) {
      if (!m.started) director.withdraw(m);
    }
    director.hush(0);
  }
}
