/// Pacing and casting for squad comms: which line plays, who says it, when,
/// and on which of the four video-call slots. Pure Dart, driven by explicit
/// timestamps so tests are exact.
///
/// One radio channel with real silence between transmissions
/// ([CommsPacing]): an airtime budget and a jittered rest pace the chatter,
/// useful calls and recommendations win over flavour, and a playing line is
/// never cut, except by a truly gameplay-critical warning
/// ([CommsTriggerSpec.urgent]) or a must-play ground-fire warning cutting
/// flavour. Dive calls and ground-fire warnings are scheduled from their
/// lead events so they END on the dive or the launch. Two-party exchanges
/// reserve the channel for both turns. The brood gets a fair share of
/// airtime (a share target and a starvation timer). The regroup
/// celebration chorus may overlap itself, never another line.
library;

import 'dart:math' as math;

import '../game/game_events.dart';
import 'comms_bank.dart';
import 'comms_lineup.dart';
import 'comms_mouth.dart';
import 'comms_pacing.dart';
import 'comms_types.dart';

export 'comms_pacing.dart' show CommsClass, CommsPacing;

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
    this.kind = CommsClass.flavour,
    this.endBy,
  });
  final CommsTriggerSpec trigger;
  final CommsLine line;
  final CommsCharacter character;
  final int priority;
  final double queuedAt;
  double readyAt, expiresAt;
  final int sequence;

  /// What the line is for: decides its rest, budget and who may cut whom.
  CommsClass kind;

  /// A timed call (dive or ground fire): when its speech should end.
  final double? endBy;
  double startedAt = double.nan;
  int slot = -1;
  bool interrupted = false;

  /// A recommendation said again after a warning cut it.
  bool retried = false;

  /// The other side's answer in a two-party exchange.
  CommsMessage? reply;

  /// Opening line retained beside this answer in the compact radio dock.
  CommsMessage? inReplyTo;

  /// This message answers an exchange (it holds the reserved channel).
  bool isReply = false;
  bool get isDemon => character.isDemon;
  bool get critical => priority >= CommsTriggerSpec.criticalPriority;
  bool get urgent => kind.index >= CommsClass.urgent.index;
  bool get mustPlay => kind == CommsClass.mustPlay;
  bool get timed => endBy != null;

  /// The regroup chorus: voices of one trigger, staggered (a timed call
  /// never overlaps).
  bool get overlap => trigger.overlap && !timed;
  bool get transmission => trigger.transmission;
  bool get started => !startedAt.isNaN;

  /// Subtitles stay up this long after the clip ends so they can be read;
  /// the brood's translation trails its glyphs, so it stays a little longer.
  static const textHold = 2.6, demonTextHold = 3.2;
  double get hold => isDemon ? demonTextHold : textHold;
  double get endsAt => startedAt + line.duration + hold;
  double get speechEndsAt => startedAt + line.duration;

  /// Planned speech window (queued messages: from [readyAt]).
  double get plannedStart => started ? startedAt : readyAt;
  double get plannedEnd => plannedStart + line.duration;
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

  /// The lip-sync cross-fade at [now]: the previous shape, the current one
  /// and how far the fade into it has come (see [CommsMouth.blendAt]).
  (int from, int to, double amount) mouthBlend(double now) {
    final t = now - startedAt;
    if (!started || t < 0 || t >= line.duration || interrupted) {
      return (CommsFrame.idle, CommsFrame.idle, 1);
    }
    return CommsMouth.of(line).blendAt(t);
  }

  @override
  String toString() =>
      'CommsMessage(${line.id} @$slot p$priority ${kind.name})';
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
    math.Random? jitter,
    this.pacing = const CommsPacing(),
    this.maxQueued = 6,
    this.lineGap = .35,
    this.demonShare = .4,
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
       jitter = jitter ?? math.Random(1983),
       human = human ?? {...commsHintTriggers, ...commsHumanTriggers},
       demon = demon ?? commsDemonTriggers,
       cast = cast ?? commsCast,
       roster = roster ?? CommsLineup.pick(1982).roster,
       reserve = reserve ?? CommsLineup.pick(1982).members {
    _budget = pacing.burst;
  }

  /// Seconds between two catchphrases from the same speaker, and the most a
  /// run hears in total, so they stay fun.
  static const signatureGap = 90.0, signaturesPerRun = 8;

  /// How long a face holds the trigger's mood after a line.
  static const moodHold = 1.6;

  /// How long the fleet-intact celebration banner stays up.
  static const celebration = 7.0;

  /// A must-play warning becomes ready this much before its exact start.
  static const warningLead = 1 / 30;

  /// Overlapping (regroup) voices start this far apart.
  static const overlapStagger = .3;

  /// The trigger the director raises itself when the brood has been quiet
  /// for [starveAfter] seconds of combat.
  static const starvationTrigger = GameEventNames.broodChatter;

  final math.Random random;

  /// Seeded noise for the rests between lines (tests stay deterministic).
  final math.Random jitter;
  final CommsPacing pacing;
  final int maxQueued;

  /// Natural pause between two lines on the channel (and an exchange's
  /// turns).
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

  /// When the channel's current speech ends.
  double _speechEnd = -100;

  /// The earliest a flavour / a useful line may start (the jittered rest
  /// after the last line).
  double _quietUntil = -100, _usefulQuietUntil = -100;

  /// Seconds of paced speech the channel may still spend, and when it was
  /// last refilled.
  double _budget = 0, _budgetAt = 0;
  double get budget => _budget;

  /// When the last ordinary dive call was queued.
  double _lastDiveCall = -1e9;

  /// The reply an exchange has reserved the channel for.
  CommsMessage? _reserved;

  /// Seconds of speech started per side, and the last demon start.
  double humanAirtime = 0, demonAirtime = 0;
  double _lastDemon = 0;

  /// Lines started, for diagnostics and tests.
  final List<String> history = [];

  /// Lines cut short (only by urgent or must-play warnings).
  final List<String> interruptedLines = [];

  /// Ground launches whose warning was already on air (a salvo shares one).
  int coveredLaunches = 0;

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
    _speechEnd = _quietUntil = _usefulQuietUntil = -100;
    _budget = pacing.burst;
    _budgetAt = now;
    _lastDiveCall = -1e9;
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

  void _refill() {
    final dt = now - _budgetAt;
    _budgetAt = now;
    if (dt <= 0) return;
    _budget = pacing.duty.isInfinite
        ? pacing.burst
        : math.min(pacing.burst, _budget + dt * pacing.duty);
  }

  double? _num(Object? v) => v is num ? v.toDouble() : null;

  /// Queues the lines for [event]: the human line and the demon part,
  /// either independently or as a two-party exchange.
  void handle(GameEvent event, double at) {
    now = math.max(now, at);
    _refill();
    _retire();
    if (event.name == GameEventNames.sectorStart && event.variant != null) {
      setSector(int.tryParse(event.variant!) ?? sector, at);
    }
    if (pacing.timed && _handleTimed(event, at)) return;
    final hint = event.data['hint'] == true;
    final h = _spec(human, event);
    final d = hint ? null : _spec(demon, event);
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
          answer
            ..isReply = true
            ..kind = first.kind;
          first.reply = answer;
        }
      } else {
        _offer(event.name, demonFirst ? h : d, at, demon: !demonFirst);
      }
      return;
    }
    if (h != null) _offer(event.name, h, at, demon: false, hint: hint);
    if (d != null) _offer(event.name, d, at, demon: true);
  }

  /// Dive calls and ground-fire warnings, scheduled from their lead events.
  /// Returns true when [event] was handled here.
  bool _handleTimed(GameEvent event, double at) {
    switch (event.name) {
      case GameEventNames.groundFirePrep:
        final fireIn = _num(event.data['fireIn']);
        final spec = human[GameEventNames.groundMissileLaunch];
        if (fireIn != null && spec != null) {
          _offerWarning(spec, at, at + fireIn);
        }
        return true;
      case GameEventNames.groundMissileLaunch:
        // Observed at the launch: the warning was scheduled from the prep.
        return true;
      case GameEventNames.divePrep:
        final diveIn = _num(event.data['diveIn']);
        if (diveIn == null) return false;
        final endBy = at + diveIn;
        CommsMessage? call;
        if (event.data['sentinel'] == true) {
          final spec = human[GameEventNames.sentinelDive];
          if (spec != null) call = _offerTimed(spec, at, endBy, demon: false);
        } else if (now - _lastDiveCall >= pacing.diveGap) {
          final spec = human[GameEventNames.diveWarning];
          if (spec != null) call = _offerTimed(spec, at, endBy, demon: false);
        }
        if (call != null) {
          _lastDiveCall = now;
          return true;
        }
        // Otherwise a brood battle cry, if the pacing allows it.
        final cry = demon[GameEventNames.divePrep];
        if (cry != null) _offerTimed(cry, at, endBy, demon: true);
        return true;
      case GameEventNames.diveWarning || GameEventNames.sentinelDive:
        final diveIn = _num(event.data['diveIn']);
        if (diveIn == null) return false;
        final spec = _spec(human, event);
        if (spec != null) {
          _offerTimed(spec, at, at + diveIn, demon: false);
        }
        return true;
    }
    return false;
  }

  /// The class of a line from [spec].
  CommsClass _classOf(
    CommsTriggerSpec spec,
    CommsLine? line, {
    bool hint = false,
    bool timed = false,
    bool demon = false,
  }) {
    if (spec.urgent) return CommsClass.urgent;
    if (hint) return CommsClass.hint;
    if (timed && !demon) return CommsClass.useful;
    if (spec.critical ||
        spec.name.startsWith(GameEventNames.transmissionMission) ||
        (line != null && commsIsClue(line))) {
      return CommsClass.useful;
    }
    return CommsClass.flavour;
  }

  /// Checks cooldown, group gap, chance and duplicates; records the firing.
  bool _admit(
    String name,
    CommsTriggerSpec spec,
    double at,
    bool demon, {
    bool hint = false,
  }) {
    final key = '${hint ? 'hint' : (demon ? 'd' : 'h')}:$name';
    final last = _lastFired[key];
    final cooldown = hint ? pacing.hintCooldown : spec.cooldown;
    if (last != null && at - last < cooldown) return false;
    final group = spec.group;
    if (group != null && !spec.urgent && !hint) {
      final lastGroup = _groupFired[group];
      if (lastGroup != null && at - lastGroup < (groupGap[group] ?? 0)) {
        return false;
      }
    }
    if (!hint && spec.chance < 1 && random.nextDouble() >= spec.chance) {
      _lastFired[key] = at;
      return false;
    }
    if ([
      ...queue,
      ...active.where((m) => m.speaking(now)),
    ].any((m) => m.trigger.name == spec.name && m.isDemon == demon)) {
      return false;
    }
    _lastFired[key] = at;
    if (group != null && !demon && !hint) _groupFired[group] = at;
    return true;
  }

  CommsMessage? _build(
    CommsTriggerSpec spec,
    CommsLine line,
    double at,
    int i, {
    CommsClass kind = CommsClass.flavour,
    double? endBy,
    double? ready,
    double? expires,
  }) {
    final character = cast[line.speaker];
    if (character == null) return null;
    _speakerUsed[line.speaker] = at;
    if (line.signature) {
      _signatureAt[line.speaker] = at;
      _signatures++;
    }
    final readyAt =
        ready ?? at + spec.delay + i * (spec.overlap ? overlapStagger : .01);
    var ttl = spec.ttl;
    if (kind == CommsClass.hint) ttl = math.max(ttl, pacing.hintTtl);
    if (kind == CommsClass.flavour) ttl = math.min(ttl, pacing.flavourTtl);
    return CommsMessage(
      trigger: spec,
      line: line,
      character: character,
      priority: spec.priority,
      queuedAt: at,
      readyAt: readyAt,
      // Chained lines wait their turn behind each other.
      expiresAt: expires ?? readyAt + ttl + (spec.overlap ? 0 : i * 6),
      sequence: _sequence++,
      kind: kind,
      endBy: endBy,
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
    bool hint = false,
  }) {
    if (!_admit(name, spec, at, demon, hint: hint)) return null;
    final used = <String>{};
    CommsMessage? first;
    for (var i = 0; i <= spec.chain; i++) {
      final line = _pickLine(spec, demon: demon, exclude: used);
      if (line == null) break;
      used.add(line.speaker);
      final kind = _classOf(spec, line, hint: hint, demon: demon);
      final m = _build(spec, line, at, i, kind: kind);
      if (m == null) break;
      first ??= m;
      queue.add(m);
    }
    if (spec.name.startsWith('flawless')) {
      celebrateUntil = math.max(celebrateUntil, at + celebration);
    }
    _sortQueue();
    _trimQueue();
    return queue.contains(first) ? first : null;
  }

  /// Flavour never stacks: at most [CommsPacing.flavourQueue] wait (the best
  /// ranked), and the queue holds at most [maxQueued].
  void _trimQueue() {
    final flavour = [
      for (final m in queue)
        if (m.kind == CommsClass.flavour &&
            !m.overlap &&
            !identical(m, _reserved))
          m,
    ];
    for (final m in flavour.skip(pacing.flavourQueue)) {
      queue.remove(m);
    }
    while (queue.length > maxQueued) {
      final victim = queue.lastWhere(
        (m) => !m.mustPlay && !identical(m, _reserved),
        orElse: () => queue.last,
      );
      queue.remove(victim);
    }
  }

  /// Speech windows the channel has promised: what is speaking and the
  /// timed calls waiting for their slot.
  Iterable<CommsMessage> get _committed => [
    ...active.where((m) => m.speaking(now)),
    ...queue.where((m) => m.timed || identical(m, _reserved)),
  ];

  /// When a call queued at [at] may start: after everything committed to
  /// the channel that [blocks] it, plus the natural gap.
  double _earliest(double at, bool Function(CommsMessage) blocks) {
    var earliest = at;
    for (final m in _committed) {
      if (blocks(m)) earliest = math.max(earliest, m.plannedEnd + lineGap);
    }
    return earliest;
  }

  /// A dive call (or brood battle cry) whose speech ends within
  /// [CommsPacing.diveTolerance] of [endBy]. Dropped when no line fits
  /// before the dive or the channel is promised elsewhere. An urgent call
  /// cuts a line in progress only when it cannot fit after it.
  CommsMessage? _offerTimed(
    CommsTriggerSpec spec,
    double at,
    double endBy, {
    required bool demon,
  }) {
    final kind = _classOf(spec, null, timed: true, demon: demon);
    final tol = pacing.diveTolerance;
    var earliest = _earliest(at, (_) => true);
    double startOf(CommsLine l) => math.max(earliest, endBy - l.duration);
    bool fits(CommsLine l) {
      final start = startOf(l);
      final end = start + l.duration;
      if (end > endBy + tol || end < endBy - tol) return false;
      if (kind == CommsClass.flavour) {
        if (start < _quietUntil || _budget < l.duration) return false;
      } else if (kind != CommsClass.urgent &&
          _budget < l.duration - pacing.debt) {
        return false;
      }
      return true;
    }

    if (!spec.lines.any(fits) && kind == CommsClass.urgent) {
      earliest = _earliest(at, (m) => !_mayCut(kind, m));
    }
    if (!spec.lines.any(fits)) return null;
    if (!_admit(spec.name, spec, at, demon)) return null;
    final line = _pickLine(spec, demon: demon, fits: fits);
    if (line == null) return null;
    final start = startOf(line);
    final m = _build(
      spec,
      line,
      at,
      0,
      kind: kind,
      endBy: endBy,
      ready: start,
      expires: endBy + tol - line.duration,
    );
    if (m == null) return null;
    queue.add(m);
    _sortQueue();
    return m;
  }

  /// A must-play ground-fire warning: its full clip ends at the launch
  /// [endBy] or at most [CommsPacing.warningWindow] before it. A warning
  /// already ending within [CommsPacing.warningCover] before the launch
  /// covers it (a salvo shares one call). It waits for a line in progress
  /// when it still fits after it; otherwise that line yields (only another
  /// must-play warning holds the channel against it).
  void _offerWarning(CommsTriggerSpec spec, double at, double endBy) {
    final warnings = [
      ...active.where((m) => m.mustPlay && !m.interrupted),
      ...queue.where((m) => m.mustPlay),
    ];
    if (warnings.any(
      (m) =>
          m.plannedEnd <= endBy + 1e-6 &&
          m.plannedEnd >= endBy - pacing.warningCover,
    )) {
      coveredLaunches++;
      return;
    }
    var earliest = _earliest(at, (_) => true);
    double startOf(CommsLine l) => math.max(earliest, endBy - l.duration);
    bool fits(CommsLine l) =>
        startOf(l) + l.duration <= endBy + 1e-6 &&
        startOf(l) + l.duration >= endBy - pacing.warningWindow;
    if (!spec.lines.any(fits)) {
      earliest = _earliest(at, (m) => m.mustPlay);
    }
    var line = _pickLine(spec, demon: false, fits: fits);
    // Never silent: with no line fitting the window, the longest one that
    // still ends before the launch.
    if (line == null) {
      final early =
          spec.lines
              .where((l) => startOf(l) + l.duration <= endBy + 1e-6)
              .toList()
            ..sort((a, b) => b.duration.compareTo(a.duration));
      line = early.firstOrNull;
    }
    if (line == null) return;
    _lastFired['h:${spec.name}'] = at;
    final start = startOf(line);
    final m = _build(
      spec,
      line,
      at,
      0,
      kind: CommsClass.mustPlay,
      endBy: endBy,
      // A frame early, so a 60 Hz tick never starts it after its deadline.
      ready: math.max(at, start - warningLead),
      expires: endBy - line.duration,
    );
    if (m == null) return;
    queue.add(m);
    _sortQueue();
    _trimQueue();
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
    bool Function(CommsLine)? fits,
  }) {
    bool allowed(CommsLine l) =>
        !exclude.contains(l.speaker) &&
        (fits == null || fits(l)) &&
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
    if (pool.isEmpty && (spec.chain == 0 || fits != null)) {
      pool = where((_) => true);
    }
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

  /// Queue order: must-play and urgent first, then recommendations, then
  /// useful calls, then priority with the brood's fairness boost, then age.
  /// The boost never lifts a flavour line past a useful one.
  double _rank(CommsMessage m) {
    switch (m.kind) {
      case CommsClass.mustPlay:
        return 200.0 + m.priority;
      case CommsClass.urgent:
        return 100.0 + m.priority;
      case CommsClass.hint:
        return 60.0 + m.priority;
      case CommsClass.useful:
        return 40.0 + m.priority;
      case CommsClass.flavour:
        break;
    }
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
      final stale = now > m.expiresAt + 1e-9;
      if (stale && identical(m, _reserved)) _reserved = null;
      return stale;
    });
  }

  /// The line speaking on the channel now (a chorus voice counts).
  CommsMessage? get _onAir =>
      active.where((m) => !m.interrupted && now < m.speechEndsAt).firstOrNull;

  /// [kind] may cut [current]: urgent warnings cut anything but urgent and
  /// must-play lines; a must-play warning cuts anything but itself.
  static bool _mayCut(CommsClass kind, CommsMessage current) {
    if (current.mustPlay) return false;
    if (kind == CommsClass.mustPlay) return true;
    if (current.kind == CommsClass.hint && current.retried) return false;
    return kind == CommsClass.urgent && !current.urgent;
  }

  /// The channel is silent: may [m] start now under the pacing?
  bool _gateOpen(CommsMessage m) {
    if (identical(m, _reserved)) return now >= _speechEnd + lineGap - 1e-9;
    final d = m.line.duration;
    switch (m.kind) {
      case CommsClass.mustPlay || CommsClass.urgent:
        return m.timed || now >= _speechEnd + lineGap - 1e-9;
      case CommsClass.hint:
        // Rare (one per [CommsPacing.hintCooldown]) and the point of the
        // radio: the pickup is falling now, so only the natural gap, and
        // never held back by the budget.
        return now >= _speechEnd + lineGap - 1e-9;
      case CommsClass.useful:
        if (m.timed) return true; // its budget was checked when queued
        return now >= math.max(_usefulQuietUntil, _speechEnd + lineGap) &&
            _budget >= d - pacing.debt;
      case CommsClass.flavour:
        if (m.timed) return true;
        return now >= math.max(_quietUntil, _speechEnd + lineGap) &&
            _budget >= d;
    }
  }

  /// [m] would end before every timed call still waiting for its slot.
  bool _clearOfTimed(CommsMessage m) {
    if (m.mustPlay) return true;
    final end = now + m.line.duration + lineGap;
    if (m.timed) {
      // A timed call only yields to a promised must-play warning.
      return !queue.any(
        (o) => o.mustPlay && !identical(o, m) && o.readyAt < end,
      );
    }
    return !queue.any(
      (o) =>
          o.timed &&
          !identical(o, m) &&
          o.readyAt < end &&
          (o.mustPlay || !m.urgent),
    );
  }

  /// Advances to [at]: retires, sequences and starts messages. [combat]
  /// enables the brood's starvation timer.
  void update(double at, {bool combat = false}) {
    now = math.max(now, at);
    _refill();
    _retire();
    if (combat &&
        now - _lastDemon > starveAfter &&
        !queue.any((m) => m.isDemon) &&
        _onAir == null) {
      handle(const GameEvent(starvationTrigger), now);
    }
    _sortQueue();
    // The regroup chorus: its voices start on their own stagger, up to the
    // voice cap, but only over each other.
    for (final m in [...queue]) {
      if (!m.overlap || now < m.readyAt) continue;
      final air = active.where((a) => !a.interrupted && now < a.speechEndsAt);
      if (air.any((a) => a.trigger.name != m.trigger.name || !a.overlap)) {
        continue;
      }
      if (air.length >= overlapCap) break;
      if (air.isEmpty && !_clearOfTimed(m)) continue;
      queue.remove(m);
      _start(m);
    }
    // The channel: one line at a time, by rank, after the pacing's rest.
    for (final m in [...queue]) {
      if (m.overlap || now < m.readyAt) continue;
      if (_reserved != null && !identical(m, _reserved) && !m.urgent) {
        continue;
      }
      final current = _onAir;
      if (current != null) {
        if (!_mayCut(m.kind, current)) continue;
        if (!_clearOfTimed(m)) continue;
        // Every voice on air yields (a chorus has several).
        final air = active.where((a) => !a.interrupted && now < a.speechEndsAt);
        if (air.any((a) => !_mayCut(m.kind, a))) continue;
        for (final a in [...air]) {
          _interrupt(a);
        }
      } else {
        if (!_gateOpen(m) || !_clearOfTimed(m)) continue;
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
    // Must-play warnings are outside the airtime budget.
    if (!m.mustPlay) _budget -= m.line.duration;
    final end = m.speechEndsAt;
    _speechEnd = math.max(_speechEnd, end);
    final rest = pacing.rest + jitter.nextDouble() * pacing.restJitter;
    final usefulRest =
        pacing.usefulRest + jitter.nextDouble() * pacing.usefulRestJitter;
    _quietUntil = math.max(_quietUntil, end + math.max(rest, lineGap));
    _usefulQuietUntil = math.max(
      _usefulQuietUntil,
      end + math.max(usefulRest, lineGap),
    );
    if (identical(m, _reserved)) _reserved = null;
    final reply = m.reply;
    if (reply != null) {
      // The answer follows right after this line; nothing else may start
      // in between.
      reply
        ..inReplyTo = m
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
    _speechEnd = now;
    final reply = m.reply;
    if (reply != null) {
      queue.remove(reply);
      if (identical(_reserved, reply)) _reserved = null;
    }
    onStop?.call(m);
    // A recommendation cut by a warning is said again right after it, in
    // its shortest form, and no urgent call cuts it twice.
    if (m.kind == CommsClass.hint) {
      final shortest = m.trigger.lines.reduce(
        (a, b) => a.duration <= b.duration ? a : b,
      );
      final again = _build(
        m.trigger,
        shortest,
        now,
        0,
        kind: CommsClass.hint,
        ready: now,
        expires: now + 2 * pacing.hintTtl,
      );
      if (again != null) queue.add(again..retried = true);
    }
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
