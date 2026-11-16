/// bonus-briefing: the "URGENT MISSION!" radio card that opens a bonus
/// level (openspec/changes/bonus-levels, design "Urgent-mission card").
///
/// The transition into a bonus level fills its radio slot with a short
/// scripted back-and-forth instead of one line: the invite (the level's
/// entry call), a dare from a squadmate and the brood's retort. The card
/// shows the level's name, its rule in one or two lines, the run modifier
/// in play and the chatter as it is spoken; the dock hides those turns
/// while the card is up. Pure Dart, driven by the comms clock, so the
/// timing is testable without widgets.
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
    this.crew = const {},
    int seed = 0,
  }) : _random = math.Random(seed);

  /// The bonus level ahead and the sector it replaces.
  final BonusLevelDef level;
  final int sector;

  /// The run modifier in play, if any (shown as the card's run rule).
  final RunModifierDef? modifier;

  /// The slot's own pick: the level's entry call.
  final CommsLine invite;
  final CommsTriggerSpec inviteSpec;

  /// This run's radio crew; empty: anyone.
  final Set<String> crew;
  final math.Random _random;

  /// Fade in and out (none with reduced motion).
  static const fade = .25;

  /// The card may stay this long into the level's first combat seconds
  /// (the swarm is still settling); then it goes, whatever is left.
  static const combatGrace = 1.2;

  /// The hush the card asks for while it is up (ended when it closes).
  static const hushFor = 60.0;

  /// Title of the card.
  static const title = 'URGENT MISSION!';

  /// The scripted turns once offered, in order.
  List<CommsMessage> turns = const [];
  bool _offered = false;
  double? openedAt, closedAt, _combatAt;

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

  /// Seconds the brief (and the run rule) need to be read once the card is
  /// up: about 15 characters a second, between 3 and 7 seconds.
  double get readFor {
    final chars = brief.length + (rule?.length ?? 0);
    return (1.5 + chars / 15).clamp(3.0, 7.0);
  }

  /// The brief has been up long enough and every turn has been read.
  bool read(CommsDirector director, double now) {
    final opened = openedAt;
    if (opened == null) return true;
    return now - opened >= readFor && _done(director, now);
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
        !read(director, now);
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

  /// One-line brief of the level's rule (the card's description).
  String get brief => level.brief;

  /// The run modifier's rule, if one is in play.
  String? get rule {
    final m = modifier;
    if (m == null || m.brief.isEmpty) return null;
    return m.brief;
  }

  /// The script: the invite, a squadmate's dare (another speaker) and the
  /// brood's retort (an officer of the destination sector first, then a
  /// minion). The level's own `bonusDare.<id>` lines win over `bonusDare`.
  /// Composed once per card, so planning and playing agree.
  List<(CommsLine, CommsTriggerSpec)> script() => _script ??= _compose();
  List<(CommsLine, CommsTriggerSpec)>? _script;

  /// Seconds the whole script needs on the channel (each turn and the grace
  /// gap after it) plus the last turn's reading hold.
  double needs({double gap = .4}) {
    var total = 0.0;
    for (final (line, _) in script()) {
      total += line.duration + gap;
    }
    return total + CommsMessage.readingTime(script().last.$1) * .5;
  }

  List<(CommsLine, CommsTriggerSpec)> _compose() {
    final parts = <(CommsLine, CommsTriggerSpec)>[(invite, inviteSpec)];
    final human =
        commsHumanTriggers['bonusDare.${level.id}'] ??
        commsHumanTriggers['bonusDare'];
    if (human != null) {
      final dare = _pick(human.lines, [
        (l) => l.speaker != invite.speaker && crew.contains(l.speaker),
        (l) => l.speaker != invite.speaker,
      ]);
      if (dare != null) parts.add((dare, human));
    }
    final demon =
        commsDemonTriggers['bonusDare.${level.id}'] ??
        commsDemonTriggers['bonusDare'];
    if (demon != null) {
      final officers = commsDemonSectors[sector] ?? const <String>[];
      final retort = _pick(demon.lines, [
        (l) => officers.contains(l.speaker),
        (l) => commsMinions.contains(l.speaker),
        (_) => true,
      ]);
      if (retort != null) parts.add((retort, demon));
    }
    return parts;
  }

  CommsLine? _pick(List<CommsLine> lines, List<bool Function(CommsLine)> by) {
    for (final test in by) {
      final pool = [
        for (final l in lines)
          if (test(l) && commsCast[l.speaker] != null) l,
      ];
      if (pool.isNotEmpty) return pool[_random.nextInt(pool.length)];
    }
    return null;
  }

  /// Queues the script on [director] and opens the card. [ttl]: how long
  /// the first turn may wait for the channel. False when nothing queued
  /// (the card then stays shut and the radio carries on as usual).
  bool offer(CommsDirector director, {required double now, double ttl = 6}) {
    if (_offered) return turns.isNotEmpty;
    _offered = true;
    turns = director.offerScript(script(), at: now, ttl: ttl);
    if (turns.isEmpty) return false;
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
    final ending =
        (flying && flightLeft <= 0) ||
        (!flying && (!combat || combatFor >= combatGrace));
    if (dismissed || ending || _done(director, now)) close(director, now);
  }

  /// Every turn has been read, or the ones left can no longer play.
  bool _done(CommsDirector director, double now) {
    for (final m in turns) {
      if (m.started) {
        if (now < m.endsAt) return false;
        continue;
      }
      // Queued (or reserved as the next turn): still to come. A turn that
      // is neither has expired, and so has everything after it.
      return !director.queue.contains(m);
    }
    return true;
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
