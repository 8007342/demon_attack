/// Pacing and casting for squad comms: which line plays, who says it, when,
/// and on which of the four video-call slots. Pure Dart, driven by explicit
/// timestamps so tests are exact.
library;

import 'dart:math' as math;

import '../game/game_events.dart';
import 'comms_bank.dart';
import 'comms_lineup.dart';
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
  final double queuedAt, readyAt, expiresAt;
  final int sequence;
  double startedAt = double.nan;
  int slot = -1;
  bool interrupted = false;
  bool get isDemon => character.isDemon;
  bool get critical => priority >= CommsTriggerSpec.criticalPriority;
  bool get started => !startedAt.isNaN;

  /// Subtitles stay up a little after the clip ends.
  static const hold = .55;
  double get endsAt => startedAt + line.duration + hold;
  double age(double now) => started ? now - startedAt : 0;
  bool speaking(double now) =>
      started && now - startedAt < line.duration && !interrupted;

  /// Portrait frame for this message at [now] (see [CommsFrame]).
  int frame(double now) {
    final t = now - startedAt;
    if (!started || t < 0 || t >= line.duration || interrupted) {
      return CommsFrame.idle;
    }
    final index = (t * 15).floor();
    final mouth = line.mouth;
    if (mouth.isNotEmpty) {
      final code = mouth.codeUnitAt(math.min(index, mouth.length - 1)) - 48;
      return code.clamp(0, CommsFrame.count - 1);
    }
    if (isDemon) {
      // Grunts: open into the roar at the peak, then settle.
      final p = t / line.duration;
      return p < .12
          ? CommsFrame.talkB
          : p < .7
          ? CommsFrame.grunt
          : p < .85
          ? CommsFrame.talkC
          : CommsFrame.idle;
    }
    const cycle = [2, 3, 4, 3, 2, 0, 5, 3, 4, 2, 0, 3];
    return cycle[(index + sequence) % cycle.length];
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
    this.maxActive = 2,
    this.maxQueued = 4,
    this.humanGap = 1.0,
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

  final math.Random random;

  /// Messages on screen at once (one human voice and one demon voice).
  final int maxActive;
  final int maxQueued;

  /// Quiet seconds between two non-critical human lines.
  final double humanGap;
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
  double _humanQuietSince = -100, now = 0;

  /// Lines started, for diagnostics and tests.
  final List<String> history = [];

  List<String> get sectorCast => [
    for (final ids in (roster[sector] ?? const {}).values) ...ids,
  ];

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
    for (final slot in slots) {
      slot
        ..occupant = null
        ..leaving = null
        ..since = -100
        ..lastSpoke = -100;
    }
    _humanQuietSince = -100;
  }

  CommsTriggerSpec? _spec(Map<String, CommsTriggerSpec> bank, GameEvent e) =>
      (e.variant == null ? null : bank['${e.name}.${e.variant}']) ??
      bank[e.name];

  /// Queues the human line and the demon reaction for [event], if any.
  void handle(GameEvent event, double at) {
    now = math.max(now, at);
    _retire();
    if (event.name == GameEventNames.sectorStart && event.variant != null) {
      setSector(int.tryParse(event.variant!) ?? sector, at);
    }
    final h = _spec(human, event);
    if (h != null) _offer(event.name, h, at, demon: false);
    final d = _spec(demon, event);
    if (d != null) _offer(event.name, d, at, demon: true);
  }

  void _offer(
    String name,
    CommsTriggerSpec spec,
    double at, {
    required bool demon,
  }) {
    final key = '${demon ? 'd' : 'h'}:$name';
    final last = _lastFired[key];
    if (last != null && at - last < spec.cooldown) return;
    final group = spec.group;
    if (group != null && !spec.critical) {
      final gap = groupGap[group] ?? 0;
      final lastGroup = _groupFired[group];
      if (lastGroup != null && at - lastGroup < gap) return;
    }
    if (spec.chance < 1 && random.nextDouble() >= spec.chance) {
      _lastFired[key] = at;
      return;
    }
    if ([
      ...queue,
      ...active,
    ].any((m) => m.trigger.name == spec.name && m.isDemon == demon)) {
      return;
    }
    final used = <String>{};
    for (var i = 0; i <= spec.chain; i++) {
      final line = _pickLine(spec, demon: demon, exclude: used);
      if (line == null) break;
      final character = cast[line.speaker];
      if (character == null) break;
      used.add(line.speaker);
      _lastFired[key] = at;
      if (group != null && !demon) _groupFired[group] = at;
      _speakerUsed[line.speaker] = at;
      if (line.signature) {
        _signatureAt[line.speaker] = at;
        _signatures++;
      }
      // Chained celebration lines follow one another; each waits its turn.
      final ready = at + spec.delay + i * .01;
      queue.add(
        CommsMessage(
          trigger: spec,
          line: line,
          character: character,
          priority: spec.priority,
          queuedAt: at,
          readyAt: ready,
          expiresAt: ready + spec.ttl + i * 6,
          sequence: _sequence++,
        ),
      );
    }
    if (spec.name.startsWith('flawless')) {
      celebrateUntil = math.max(celebrateUntil, at + celebration);
    }
    _sortQueue();
    while (queue.length > maxQueued) {
      queue.removeLast();
    }
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

  void _sortQueue() => queue.sort(
    (a, b) => b.priority != a.priority
        ? b.priority.compareTo(a.priority)
        : a.sequence.compareTo(b.sequence),
  );

  /// Drops finished messages and stale queued ones.
  void _retire() {
    for (final m in [...active]) {
      if (now >= m.endsAt) {
        active.remove(m);
        if (!m.isDemon) _humanQuietSince = math.min(now, m.endsAt);
        onStop?.call(m);
      }
    }
    queue.removeWhere((m) => now > m.expiresAt);
  }

  /// Advances to [at]: finishes, expires, interrupts and starts messages.
  void update(double at) {
    now = math.max(now, at);
    _retire();
    for (final m in [...queue]) {
      if (now < m.readyAt) continue;
      if (_tryStart(m)) queue.remove(m);
    }
    for (final slot in slots) {
      if (slot.leaving != null &&
          now - slot.since >= CommsSlot.disconnectTime) {
        slot.leaving = null;
      }
    }
  }

  bool _tryStart(CommsMessage m) {
    final same = active.where((a) => a.isDemon == m.isDemon).toList();
    if (same.isNotEmpty) {
      final current = same.first;
      // Gameplay-critical warnings cut a lower, non-critical line short.
      if (!m.critical || current.critical || current.priority >= m.priority) {
        return false;
      }
      _interrupt(current);
    } else if (!m.isDemon && !m.critical && now - _humanQuietSince < humanGap) {
      return false;
    }
    if (active.length >= maxActive) {
      final lowest = active.reduce((a, b) => a.priority <= b.priority ? a : b);
      if (!m.critical || lowest.priority >= m.priority) return false;
      _interrupt(lowest);
    }
    m.startedAt = now;
    m.slot = _assignSlot(m.character);
    slots[m.slot]
      ..mood = m.trigger.mood
      ..moodUntil = now + m.line.duration + moodHold;
    active.add(m);
    history.add(m.line.id);
    onStart?.call(m);
    return true;
  }

  void _interrupt(CommsMessage m) {
    m.interrupted = true;
    active.remove(m);
    if (!m.isDemon) _humanQuietSince = now;
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

  /// The message currently shown on [slot], if any.
  CommsMessage? messageOn(int slot) =>
      active.where((m) => m.slot == slot).firstOrNull;
}
