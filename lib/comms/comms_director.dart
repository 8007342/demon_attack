/// Pacing and casting for squad comms: which line plays, who says it, when,
/// and on which of the four video-call slots. Pure Dart, driven by explicit
/// timestamps so tests are exact.
///
/// One radio channel: lines play one after another with a short natural gap
/// and are never cut, except by a truly gameplay-critical warning
/// ([CommsTriggerSpec.urgent]). Two-party exchanges reserve the channel for
/// both turns. The brood gets a fair share of airtime (a share target and a
/// starvation timer). The regroup celebration may overlap for about a second.
library;

import 'dart:math' as math;

import '../game/game_events.dart';
import 'comms_bank.dart';
import 'comms_lineup.dart';
import 'comms_mouth.dart';
import 'comms_types.dart';

class CommsMessage {
  CommsMessage({
    required this.trigger,
    required this.line,
    required this.character,
    required this.priority,
    required this.queuedAt,
    required this.readyAt,
    required this.expiresAt,
    required this.sequence,
  });
  final CommsTriggerSpec trigger;
  final CommsLine line;
  final CommsCharacter character;
  final int priority;
  final double queuedAt;
  double readyAt, expiresAt;
  final int sequence;
  double startedAt = double.nan;
  int slot = -1;
  bool interrupted = false;

  /// The other side's answer in a two-party exchange.
  CommsMessage? reply;

  /// This message answers an exchange (it holds the reserved channel).
  bool isReply = false;
  bool get isDemon => character.isDemon;
  bool get critical => priority >= CommsTriggerSpec.criticalPriority;
  bool get urgent => trigger.urgent;
  bool get overlap => trigger.overlap;
  bool get transmission => trigger.transmission;
  bool get started => !startedAt.isNaN;

  /// Subtitles stay up a little after the clip ends.
  static const hold = .55;
  double get endsAt => startedAt + line.duration + hold;
  double get speechEndsAt => startedAt + line.duration;
  double age(double now) => started ? now - startedAt : 0;
  bool speaking(double now) =>
      started && now - startedAt < line.duration && !interrupted;

  /// Portrait frame for this message at [now] (see [CommsFrame]): the
  /// smoothed lip-sync of [CommsMouth].
  int frame(double now) {
    final t = now - startedAt;
    if (!started || t < 0 || t >= line.duration || interrupted) {
      return CommsFrame.idle;
    }
    return CommsMouth.of(line).frameAt(t);
  }

  @override
  String toString() => 'CommsMessage(${line.id} @$slot p$priority)';
}

enum CommsSlotState { empty, connecting, live, disconnecting }

class CommsSlot {
  CommsSlot(this.index);
  final int index;

  /// Slots 0-1 are the left column, 2-3 the right one.
  bool get left => index < 2;
  String? occupant, leaving;

  /// Expression held after the occupant's last line.
  CommsMood mood = CommsMood.stern;
  double moodUntil = -100;
  double since = -100, lastSpoke = -100;
  static const connectTime = .35, disconnectTime = .3;

  CommsSlotState state(double now) {
    if (occupant == null) {
      return leaving != null && now - since < disconnectTime
          ? CommsSlotState.disconnecting
          : CommsSlotState.empty;
    }
    return now - since < connectTime
        ? CommsSlotState.connecting
        : CommsSlotState.live;
  }

  /// 0..1 through the current connect or disconnect transition.
  double transition(double now) =>
      ((now - since) / (occupant == null ? disconnectTime : connectTime))
          .clamp(0, 1)
          .toDouble();
}

class CommsDirector {
  CommsDirector({
    math.Random? random,
    this.maxQueued = 6,
    this.lineGap = .35,
    this.demonShare = .3,
    this.starveAfter = 20,
    this.overlapCap = 3,
    Map<String, CommsTriggerSpec>? human,
    Map<String, CommsTriggerSpec>? demon,
    Map<String, CommsCharacter>? cast,
    Map<int, Map<CommsSide, List<String>>>? roster,
    Set<String>? reserve,
    this.anchor = commsAnchor,
    this.groupGap = commsGroupGap,
    this.onStart,
    this.onStop,
  }) : random = random ?? math.Random(1982),
       human = human ?? commsHumanTriggers,
       demon = demon ?? commsDemonTriggers,
       cast = cast ?? commsCast,
       roster = roster ?? CommsLineup.pick(1982).roster,
       reserve = reserve ?? CommsLineup.pick(1982).members;

  /// Seconds between two catchphrases from the same speaker, and the most a
  /// run hears in total, so they stay fun.
  static const signatureGap = 90.0, signaturesPerRun = 8;

  /// How long a face holds the trigger's mood after a line.
  static const moodHold = 1.6;

  /// How long the fleet-intact celebration banner stays up.
  static const celebration = 7.0;

  /// Overlapping (regroup) voices start this far apart.
  static const overlapStagger = .3;

  /// The trigger the director raises itself when the brood has been quiet
  /// for [starveAfter] seconds of combat.
  static const starvationTrigger = GameEventNames.broodChatter;

  final math.Random random;
  final int maxQueued;

  /// Natural pause between two lines on the channel.
  final double lineGap;

  /// Target share of airtime (seconds of speech) for the brood.
  final double demonShare;

  /// Seconds of combat without a demon line before the brood chimes in.
  final double starveAfter;

  /// Voices at once while overlapping lines (the regroup celebration) play.
  final int overlapCap;
  final Map<String, CommsTriggerSpec> human, demon;
  final Map<String, CommsCharacter> cast;
  Map<int, Map<CommsSide, List<String>>> roster;

  /// Everyone on this run's lineup: they may patch into a sector they are
  /// not assigned to when nobody on the call has a line.
  Set<String> reserve;
  final String anchor;

  /// Seconds between two lines of one [CommsTriggerSpec.group].
  final Map<String, double> groupGap;
  final _groupFired = <String, double>{};
  void Function(CommsMessage)? onStart, onStop;

  /// This run's crew (see [CommsLineup]).
  void setLineup(CommsLineup lineup) {
    roster = lineup.roster;
    reserve = lineup.members;
  }

  final _signatureAt = <String, double>{};
  int _signatures = 0;

  /// Until when the fleet-intact banner shows.
  double celebrateUntil = -1;
  bool celebrating(double at) => at < celebrateUntil;

  final slots = List.generate(4, CommsSlot.new);
  final List<CommsMessage> active = [], queue = [];
  final _lastFired = <String, double>{};
  final _lastVariant = <String, int>{};
  final _speakerUsed = <String, double>{};
  int sector = 1, _sequence = 0;
  double now = 0;

  /// When the channel's current speech ends (lines start [lineGap] later).
  double _speechEnd = -100;

  /// The reply an exchange has reserved the channel for.
  CommsMessage? _reserved;

  /// Seconds of speech started per side, and the last demon start.
  double humanAirtime = 0, demonAirtime = 0;
  double _lastDemon = 0;

  /// Lines started, for diagnostics and tests.
  final List<String> history = [];

  /// Lines cut short (only by urgent warnings).
  final List<String> interruptedLines = [];

  double get demonShareNow {
    final total = humanAirtime + demonAirtime;
    return total <= 0 ? 0 : demonAirtime / total;
  }

  List<String> get sectorCast => [
    for (final ids in (roster[sector] ?? const {}).values) ...ids,
  ];

  /// The transmission currently on air, if any.
  CommsMessage? get transmission =>
      active.where((m) => m.transmission && !m.isDemon).firstOrNull;

  /// New sector: everyone on the call hangs up; the new crew connects as
  /// they speak.
  void setSector(int value, double at) {
    now = math.max(now, at);
    if (value == sector && slots.any((s) => s.occupant != null)) return;
    sector = value;
    for (final slot in slots) {
      if (slot.occupant == null) continue;
      if (active.any((m) => m.slot == slot.index)) continue;
      _hangUp(slot, at);
    }
  }

  void reset() {
    for (final m in active) {
      onStop?.call(m);
    }
    active.clear();
    queue.clear();
    _lastFired.clear();
    _speakerUsed.clear();
    _signatureAt.clear();
    _groupFired.clear();
    _signatures = 0;
    celebrateUntil = -1;
    _reserved = null;
    _speechEnd = -100;
    humanAirtime = demonAirtime = 0;
    _lastDemon = now;
    for (final slot in slots) {
      slot
        ..occupant = null
        ..leaving = null
        ..since = -100
        ..lastSpoke = -100;
    }
  }

  CommsTriggerSpec? _spec(Map<String, CommsTriggerSpec> bank, GameEvent e) =>
      (e.variant == null ? null : bank['${e.name}.${e.variant}']) ??
      bank[e.name];

  /// Queues the lines for [event]: the human line and the demon part,
  /// either independently or as a two-party exchange.
  void handle(GameEvent event, double at) {
    now = math.max(now, at);
    _retire();
    if (event.name == GameEventNames.sectorStart && event.variant != null) {
      setSector(int.tryParse(event.variant!) ?? sector, at);
    }
    final h = _spec(human, event);
    final d = _spec(demon, event);
    final exchange = h?.exchange ?? d?.exchange;
    if (exchange != null && h != null && d != null) {
      final demonFirst = exchange == CommsSide.demon;
      final first = _offer(
        event.name,
        demonFirst ? d : h,
        at,
        demon: demonFirst,
      );
      if (first != null) {
        final answer = _make(
          event.name,
          demonFirst ? h : d,
          at,
          demon: !demonFirst,
        );
        if (answer != null) {
          answer.isReply = true;
          first.reply = answer;
        }
      } else {
        _offer(event.name, demonFirst ? h : d, at, demon: !demonFirst);
      }
      return;
    }
    if (h != null) _offer(event.name, h, at, demon: false);
    if (d != null) _offer(event.name, d, at, demon: true);
  }

  /// Checks cooldown, group gap, chance and duplicates; records the firing.
  bool _admit(String name, CommsTriggerSpec spec, double at, bool demon) {
    final key = '${demon ? 'd' : 'h'}:$name';
    final last = _lastFired[key];
    if (last != null && at - last < spec.cooldown) return false;
    final group = spec.group;
    if (group != null && !spec.urgent) {
      final lastGroup = _groupFired[group];
      if (lastGroup != null && at - lastGroup < (groupGap[group] ?? 0)) {
        return false;
      }
    }
    if (spec.chance < 1 && random.nextDouble() >= spec.chance) {
      _lastFired[key] = at;
      return false;
    }
    if ([
      ...queue,
      ...active,
    ].any((m) => m.trigger.name == spec.name && m.isDemon == demon)) {
      return false;
    }
    _lastFired[key] = at;
    if (group != null && !demon) _groupFired[group] = at;
    return true;
  }

  CommsMessage? _build(
    CommsTriggerSpec spec,
    CommsLine line,
    double at,
    int i,
  ) {
    final character = cast[line.speaker];
    if (character == null) return null;
    _speakerUsed[line.speaker] = at;
    if (line.signature) {
      _signatureAt[line.speaker] = at;
      _signatures++;
    }
    final ready = at + spec.delay + i * (spec.overlap ? overlapStagger : .01);
    return CommsMessage(
      trigger: spec,
      line: line,
      character: character,
      priority: spec.priority,
      queuedAt: at,
      readyAt: ready,
      // Chained lines wait their turn behind each other.
      expiresAt: ready + spec.ttl + (spec.overlap ? 0 : i * 6),
      sequence: _sequence++,
    );
  }

  /// An exchange reply: admitted and picked now, queued when its turn comes.
  CommsMessage? _make(
    String name,
    CommsTriggerSpec spec,
    double at, {
    required bool demon,
  }) {
    if (!_admit(name, spec, at, demon)) return null;
    final line = _pickLine(spec, demon: demon);
    return line == null ? null : _build(spec, line, at, 0);
  }

  /// Queues [spec]'s line (and its chain); returns the first message.
  CommsMessage? _offer(
    String name,
    CommsTriggerSpec spec,
    double at, {
    required bool demon,
  }) {
    if (!_admit(name, spec, at, demon)) return null;
    final used = <String>{};
    CommsMessage? first;
    for (var i = 0; i <= spec.chain; i++) {
      final line = _pickLine(spec, demon: demon, exclude: used);
      if (line == null) break;
      used.add(line.speaker);
      final m = _build(spec, line, at, i);
      if (m == null) break;
      first ??= m;
      queue.add(m);
    }
    if (spec.name.startsWith('flawless')) {
      celebrateUntil = math.max(celebrateUntil, at + celebration);
    }
    _sortQueue();
    while (queue.length > maxQueued) {
      queue.removeLast();
    }
    return queue.contains(first) ? first : null;
  }

  /// Rotating cast: lines whose speaker is on this sector's call, preferring
  /// someone who has not spoken lately and a variant not used last time.
  ///
  /// Fallbacks when nobody on this sector's call has a line: a teammate
  /// from this run's lineup patches in, then the Admiral, then any guest.
  CommsLine? _pickLine(
    CommsTriggerSpec spec, {
    required bool demon,
    Set<String> exclude = const {},
  }) {
    bool allowed(CommsLine l) =>
        !exclude.contains(l.speaker) &&
        (!l.signature ||
            (_signatures < signaturesPerRun &&
                now - (_signatureAt[l.speaker] ?? -1e9) >= signatureGap));
    List<int> where(bool Function(CommsLine) test) => [
      for (var i = 0; i < spec.lines.length; i++)
        if (allowed(spec.lines[i]) && test(spec.lines[i])) i,
    ];
    final onCall = sectorCast.toSet();
    var pool = where((l) => onCall.contains(l.speaker));
    if (pool.isEmpty && !demon) {
      pool = where((l) => reserve.contains(l.speaker));
    }
    if (pool.isEmpty && !demon) pool = where((l) => l.speaker == anchor);
    if (pool.isEmpty && spec.chain == 0) pool = where((_) => true);
    if (pool.isEmpty) return null;
    final busy = {
      for (final m in [...active, ...queue]) m.line.speaker,
    };
    final lastIndex = _lastVariant[spec.name + (demon ? '.d' : '.h')];
    double score(int i) {
      final speaker = spec.lines[i].speaker;
      var s = random.nextDouble();
      if (i == lastIndex) s += 3;
      if (busy.contains(speaker)) s += 2;
      final used = _speakerUsed[speaker];
      if (used != null) s += 1 / (1 + (now - used) / 6);
      return s;
    }

    final scored = {for (final i in pool) i: score(i)};
    final choice = pool.reduce((a, b) => scored[a]! <= scored[b]! ? a : b);
    _lastVariant[spec.name + (demon ? '.d' : '.h')] = choice;
    return spec.lines[choice];
  }

  /// Queue order: urgent first, then priority with the brood's fairness
  /// boost, then age. The boost never lifts a line past urgent warnings.
  double _rank(CommsMessage m) {
    if (m.urgent) return 100.0 + m.priority;
    var p = m.priority.toDouble();
    if (m.isDemon) {
      if (demonShareNow < demonShare) p += 1.5;
      if (now - _lastDemon > starveAfter) p += 2;
    }
    return p;
  }

  void _sortQueue() => queue.sort((a, b) {
    final r = _rank(b).compareTo(_rank(a));
    return r != 0 ? r : a.sequence.compareTo(b.sequence);
  });

  /// Drops finished messages and stale queued ones (a reserved reply only
  /// expires after its own time-to-live).
  void _retire() {
    for (final m in [...active]) {
      if (now >= m.endsAt) {
        active.remove(m);
        onStop?.call(m);
      }
    }
    queue.removeWhere((m) {
      final stale = now > m.expiresAt;
      if (stale && identical(m, _reserved)) _reserved = null;
      return stale;
    });
  }

  bool get _channelSpeaking =>
      active.any((m) => !m.overlap && !m.interrupted && now < m.speechEndsAt);

  /// Advances to [at]: retires, sequences and starts messages. [combat]
  /// enables the brood's starvation timer.
  void update(double at, {bool combat = false}) {
    now = math.max(now, at);
    _retire();
    if (combat &&
        now - _lastDemon > starveAfter &&
        !queue.any((m) => m.isDemon) &&
        !_channelSpeaking) {
      handle(const GameEvent(starvationTrigger), now);
    }
    _sortQueue();
    // Overlapping lines start on their own stagger, up to the voice cap.
    for (final m in [...queue]) {
      if (!m.overlap || now < m.readyAt) continue;
      if (active.where((a) => now < a.speechEndsAt).length >= overlapCap) {
        break;
      }
      queue.remove(m);
      _start(m);
    }
    // The channel: one line at a time, in order, after a natural gap.
    for (final m in [...queue]) {
      if (m.overlap || now < m.readyAt) continue;
      if (_reserved != null && !identical(m, _reserved) && !m.urgent) {
        continue;
      }
      if (_channelSpeaking) {
        final current = active.firstWhere(
          (a) => !a.overlap && !a.interrupted && now < a.speechEndsAt,
        );
        if (!m.urgent || current.urgent) break;
        _interrupt(current);
      } else if (now < _speechEnd + lineGap && !m.urgent) {
        break;
      }
      queue.remove(m);
      _start(m);
      break;
    }
    for (final slot in slots) {
      if (slot.leaving != null &&
          now - slot.since >= CommsSlot.disconnectTime) {
        slot.leaving = null;
      }
    }
  }

  void _start(CommsMessage m) {
    m.startedAt = now;
    m.slot = _assignSlot(m.character);
    slots[m.slot]
      ..mood = m.trigger.mood
      ..moodUntil = now + m.line.duration + moodHold;
    active.add(m);
    history.add(m.line.id);
    if (m.isDemon) {
      demonAirtime += m.line.duration;
      _lastDemon = now;
    } else {
      humanAirtime += m.line.duration;
    }
    if (!m.overlap) _speechEnd = m.speechEndsAt;
    if (identical(m, _reserved)) _reserved = null;
    final reply = m.reply;
    if (reply != null) {
      // The answer follows right after this line; nothing else may start
      // in between.
      reply
        ..readyAt = m.speechEndsAt + lineGap
        ..expiresAt = m.speechEndsAt + lineGap + reply.trigger.ttl;
      queue.add(reply);
      _reserved = reply;
    }
    onStart?.call(m);
  }

  void _interrupt(CommsMessage m) {
    m.interrupted = true;
    active.remove(m);
    interruptedLines.add(m.line.id);
    final reply = m.reply;
    if (reply != null) {
      queue.remove(reply);
      if (identical(_reserved, reply)) _reserved = null;
    }
    onStop?.call(m);
  }

  /// The air squad (Admiral, pilots) takes the left column; the right column
  /// is the ground link and the brood intercept. A speaker already on the
  /// call keeps their slot; otherwise an empty slot, else the occupant who
  /// has been quiet longest (and is not talking) hangs up.
  static bool prefersLeft(CommsCharacter who) => who.side == CommsSide.fleet;

  int _assignSlot(CommsCharacter who) {
    final existing = slots.where((s) => s.occupant == who.id).firstOrNull;
    final speakingSlots = {for (final m in active) m.slot};
    if (existing != null) {
      existing.lastSpoke = now;
      return existing.index;
    }
    final left = prefersLeft(who);
    final preferred = slots.where((s) => s.left == left).toList();
    final other = slots.where((s) => s.left != left).toList();
    CommsSlot? pick =
        preferred.where((s) => s.occupant == null).firstOrNull ??
        // Humans may borrow an empty slot in the other column; demons never
        // sit with the air squad.
        (who.isDemon
            ? null
            : other.where((s) => s.occupant == null).firstOrNull);
    if (pick == null) {
      final candidates =
          preferred.where((s) => !speakingSlots.contains(s.index)).toList()
            ..sort((a, b) => a.lastSpoke.compareTo(b.lastSpoke));
      // Someone borrowing this column yields it first.
      final borrowed = preferred
          .where(
            (s) =>
                !speakingSlots.contains(s.index) &&
                s.occupant != null &&
                prefersLeft(cast[s.occupant]!) != left,
          )
          .firstOrNull;
      pick = borrowed ?? candidates.firstOrNull ?? preferred.first;
    }
    if (pick.occupant != null) pick.leaving = pick.occupant;
    pick
      ..occupant = who.id
      ..since = now
      ..lastSpoke = now;
    return pick.index;
  }

  void _hangUp(CommsSlot slot, double at) {
    slot
      ..leaving = slot.occupant
      ..occupant = null
      ..since = at;
  }

  /// The message currently shown on [slot] (the newest one on it).
  CommsMessage? messageOn(int slot) =>
      active.where((m) => m.slot == slot).lastOrNull;
}
