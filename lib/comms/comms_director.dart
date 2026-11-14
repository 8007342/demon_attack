/// Pacing and casting for squad comms: which line plays, who says it, when,
/// and on which of the four video-call slots. Pure Dart, driven by explicit
/// timestamps so tests are exact.
///
/// One radio channel with real silence between transmissions
/// ([CommsPacing]): an airtime budget and a jittered rest pace the chatter,
/// useful calls and recommendations win over flavour, and a playing line is
/// never cut: it finishes, then a grace gap ([CommsPacing.grace]) follows.
/// Dive calls and ground-fire warnings are scheduled from their lead events
/// so they END on the dive or the launch, and nothing starts that would
/// still be speaking when a known timed call is due (lookahead). Lines
/// about the fight below are gated by what is true there
/// ([CommsGroundPicture]). Two-party exchanges reserve the channel for both
/// turns. The brood gets a fair share of
/// airtime (a share target and a starvation timer). The regroup
/// celebration chorus may overlap itself, never another line.
library;

import 'dart:math' as math;

import '../game/game_events.dart';
import 'comms_bank.dart';
import 'comms_context.dart';
import 'comms_lineup.dart';
import 'comms_moments.dart';
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

  /// Always false since comms-middle-ground (no line cuts another); kept
  /// for the views and the simulation, which still check it.
  bool interrupted = false;

  /// A timed call that could not end on time because the channel was busy:
  /// it plays its shortest variant right after the grace gap (must-play
  /// warnings, and urgent dive calls that still start before the dive).
  bool late = false;

  /// A linked exchange's opening line stays on screen until its answer can
  /// be read ([CommsDirector] sets it when the answer starts).
  double keepUntil = double.negativeInfinity;

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

  /// Reading time of a subtitle from its start: [readBase] plus
  /// [readPerChar] per character of the text (or the SIGINT gloss), at
  /// most [readCap].
  static const readBase = .9, readPerChar = .055, readCap = 7.0;
  static double readingTime(CommsLine line) {
    final text = line.isGrunt ? (line.gloss ?? '') : (line.text ?? '');
    return math.min(readCap, readBase + readPerChar * text.length);
  }

  /// On screen from the start until the later of the clip's end plus its
  /// [hold] and the reading time (and, for an exchange's opening line,
  /// until its answer is readable).
  double get endsAt => math.max(
    startedAt + math.max(line.duration + hold, readingTime(line)),
    keepUntil,
  );
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
    double? lineGap,
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
       lineGap = lineGap ?? pacing.grace,
       human =
           human ??
           commsHumanBank({...commsHintTriggers, ...commsHumanTriggers}),
       demon = demon ?? commsDemonBank(commsDemonTriggers),
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

  /// The grace gap after every line before the next may start (and between
  /// an exchange's turns); [CommsPacing.grace] unless given.
  final double lineGap;

  /// What is true about the fight below (gates air-cover and ground lines).
  final ground = CommsGroundPicture();

  /// The event being handled (line gates read its data).
  GameEvent? _event;

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

  /// Forecast ground launches (`groundFireForecast`) whose warning is not
  /// queued yet: the channel stays clear for it ([CommsPacing.fireReserve]).
  final List<double> expectedFire = [];

  /// The music director's intensity tier (0 unknown, 1 calm .. 4 peril).
  int tier = 0;

  /// The reply an exchange has reserved the channel for.
  CommsMessage? _reserved;

  /// Seconds of speech started per side, and the last demon start.
  double humanAirtime = 0, demonAirtime = 0;
  double _lastDemon = 0;

  /// Lines started, for diagnostics and tests.
  final List<String> history = [];

  /// Lines cut short: always empty since comms-middle-ground (no line cuts
  /// another); kept for tests and diagnostics.
  final List<String> interruptedLines = [];

  /// Ground launches whose warning was already on air (a salvo shares one).
  int coveredLaunches = 0;

  /// Must-play warnings that could not end by their launch because the
  /// channel was busy (they play their shortest variant after the grace
  /// gap), and urgent dive calls started late for the same reason.
  int lateWarnings = 0, lateDiveCalls = 0;

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
    expectedFire.clear();
    hushUntil = double.negativeInfinity;
    tier = 0;
    ground.reset();
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
    final scale = pacing.tierDuty.isEmpty
        ? 1.0
        : pacing.tierDuty[tier.clamp(0, pacing.tierDuty.length - 1)];
    _budget = pacing.duty.isInfinite
        ? pacing.burst
        : math.min(pacing.burst, _budget + dt * pacing.duty * scale);
  }

  double? _num(Object? v) => v is num ? v.toDouble() : null;

  /// Queues the lines for [event]: the human line and the demon part,
  /// either independently or as a two-party exchange.
  void handle(GameEvent event, double at) {
    now = math.max(now, at);
    _refill();
    _retire();
    note(event, at);
    final alias = commsEventAliases[event.name];
    if (alias != null) event = GameEvent(alias, event.data);
    if (event.name == GameEventNames.sectorStart && event.variant != null) {
      setSector(int.tryParse(event.variant!) ?? sector, at);
    }
    _event = event;
    try {
      _handle(event, at);
    } finally {
      _event = null;
    }
  }

  /// Until when the radio is hushed (see [hush]).
  double hushUntil = double.negativeInfinity;
  bool get hushed => now < hushUntil;

  /// Holds flavour, useful, recommendation and briefing lines for [seconds]
  /// from [at] (default now), e.g. during a silent tip interlude: they stay
  /// queued and may still start up to [CommsPacing.flavourTtl] after the
  /// hush ends (or by their own expiry, if later). Must-play ground-fire
  /// warnings and urgent warnings still play. A later hush extends an
  /// earlier one; [seconds] 0 or less ends it.
  void hush(double seconds, {double? at}) {
    final from = at ?? now;
    hushUntil = seconds <= 0
        ? double.negativeInfinity
        : math.max(hushUntil, from + seconds);
  }

  /// [hush] taking a [Duration].
  void hushFor(Duration duration, {double? at}) =>
      hush(duration.inMicroseconds / 1e6, at: at);

  /// Queues one chosen bank [line] (e.g. the transition's radio card)
  /// through the normal pacing: it plays once the channel is free, after
  /// the grace gap, as a useful line that may wait up to [ttl] seconds.
  /// [spec] is the trigger the line belongs to (looked up in the banks when
  /// omitted). Cooldowns and chance do not apply. Returns the queued
  /// message, or null when the speaker is not in the cast.
  CommsMessage? offer(
    CommsLine line, {
    CommsTriggerSpec? spec,
    double? at,
    double ttl = 6,
  }) {
    final when = math.max(now, at ?? now);
    now = when;
    final trigger =
        spec ??
        [
          ...human.values,
          ...demon.values,
        ].where((s) => s.lines.any((l) => l.id == line.id)).firstOrNull ??
        CommsTriggerSpec(
          name: 'offer',
          priority: 5,
          cooldown: 0,
          ttl: ttl,
          lines: [line],
        );
    final m = _build(
      trigger,
      line,
      when,
      0,
      kind: CommsClass.useful,
      ready: when,
      expires: when + ttl,
    );
    if (m == null) return null;
    queue.add(m);
    _sortQueue();
    _trimQueue();
    return queue.contains(m) ? m : null;
  }

  /// Records what [event] says about the fight below without voicing it
  /// (also called for events the glue filters out, such as homing kills).
  void note(GameEvent event, double at) => ground.note(event, at);

  void _handle(GameEvent event, double at) {
    if (event.name == GameEventNames.musicIntensity) {
      final t = event.data['tier'];
      if (t is num) tier = t.toInt();
      return;
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
      case GameEventNames.groundFireForecast:
        final fireIn = _num(event.data['fireIn']);
        if (fireIn != null && fireIn > 0) expectedFire.add(at + fireIn);
        return true;
      case GameEventNames.groundFirePrep:
        final fireIn = _num(event.data['fireIn']);
        final spec = human[GameEventNames.groundMissileLaunch];
        if (fireIn != null) {
          // The forecast came true: the warning itself now holds the slot.
          final launch = at + fireIn;
          final i = expectedFire.indexWhere((l) => (l - launch).abs() < 1.2);
          if (i >= 0) expectedFire.removeAt(i);
        }
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
        commsMomentEvents.contains(spec.name.split('.').first) ||
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
    // Moments that announce the same thing share a cooldown.
    final shared = commsSharedCooldown[name];
    if (shared != null) _lastFired[key.replaceFirst(name, shared)] = at;
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
    // Urgent warnings no longer cut in; they wait for the line on air.
    if (kind == CommsClass.urgent && endBy == null) {
      ttl = math.max(ttl, pacing.urgentTtl);
    }
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
    // The grace gap after the line that just finished.
    var earliest = math.max(at, _speechEnd + lineGap);
    for (final m in _committed) {
      if (blocks(m)) earliest = math.max(earliest, m.plannedEnd + lineGap);
    }
    return earliest;
  }

  /// A dive call (or brood battle cry) whose speech ends within
  /// [CommsPacing.diveTolerance] of [endBy]. Dropped when no line fits
  /// before the dive or the channel is promised elsewhere. Nothing is cut:
  /// an urgent call (the sentinel's dive) that cannot end on time plays its
  /// shortest variant right after the grace gap, as long as it still starts
  /// before the dive.
  CommsMessage? _offerTimed(
    CommsTriggerSpec spec,
    double at,
    double endBy, {
    required bool demon,
  }) {
    final kind = _classOf(spec, null, timed: true, demon: demon);
    final tol = pacing.diveTolerance;
    final earliest = _earliest(at, (_) => true);
    double startOf(CommsLine l) => math.max(earliest, endBy - l.duration);
    bool fits(CommsLine l) {
      final start = startOf(l);
      final end = start + l.duration;
      if (end > endBy + tol || end < endBy - tol) return false;
      if (kind != CommsClass.urgent && _hitsFireReserve(start, end + lineGap)) {
        return false;
      }
      if (kind == CommsClass.flavour) {
        if (start < _quietUntil || _budget < l.duration) return false;
      } else if (kind != CommsClass.urgent &&
          _budget < l.duration - pacing.debt) {
        return false;
      }
      return true;
    }

    var late = false;
    if (!spec.lines.any(fits)) {
      // Busy channel: an urgent call still goes out, shortest variant
      // first, if it starts before the dive does.
      if (kind != CommsClass.urgent || earliest > endBy + 1e-9) return null;
      late = true;
    }
    if (!_admit(spec.name, spec, at, demon)) return null;
    CommsLine? line;
    if (late) {
      line = _shortest(spec);
    } else {
      line = _pickLine(spec, demon: demon, fits: fits);
    }
    if (line == null) return null;
    final start = late ? earliest : startOf(line);
    final m = _build(
      spec,
      line,
      at,
      0,
      kind: kind,
      endBy: endBy,
      ready: start,
      expires: late ? endBy : endBy + tol - line.duration,
    );
    if (m == null) return null;
    m.late = late;
    if (late) lateDiveCalls++;
    queue.add(m);
    _sortQueue();
    return m;
  }

  /// The shortest line of [spec] that the cast and the gates allow.
  CommsLine? _shortest(CommsTriggerSpec spec) {
    final allowed = [
      for (final l in spec.lines)
        if (cast.containsKey(l.speaker) && ground.allows(spec, l, _event, now))
          l,
    ]..sort((a, b) => a.duration.compareTo(b.duration));
    return allowed.firstOrNull;
  }

  /// A must-play ground-fire warning: its full clip ends at the launch
  /// [endBy] or at most [CommsPacing.warningWindow] before it. A warning
  /// already ending within [CommsPacing.warningCover] before the launch
  /// covers it (a salvo shares one call). Nothing is cut: it waits for the
  /// line in progress plus the grace gap. Queued calls that have not started
  /// (dive calls, an exchange's answer) wait behind it or drop. When the
  /// line in progress ends too late, the shortest variant plays right after
  /// the grace gap and ends late ([lateWarnings]); a warning is never
  /// dropped.
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
    // Only speech already on air and earlier warnings hold the channel.
    final earliest = _earliest(at, (m) => m.mustPlay || m.started);
    double startOf(CommsLine l) => math.max(earliest, endBy - l.duration);
    bool fits(CommsLine l) =>
        startOf(l) + l.duration <= endBy + 1e-6 &&
        startOf(l) + l.duration >= endBy - pacing.warningWindow;
    var line = _pickLine(spec, demon: false, fits: fits);
    var late = false;
    if (line == null) {
      // The line on air ends too late: the shortest warning, right after
      // the grace gap.
      line = _shortest(spec);
      late = true;
    }
    if (line == null) return;
    _lastFired['h:${spec.name}'] = at;
    final start = late ? earliest : startOf(line);
    final end = start + line.duration;
    // Timed calls that have not started and would overlap it give way.
    queue.removeWhere(
      (o) =>
          o.timed &&
          !o.mustPlay &&
          o.plannedStart < end + lineGap &&
          o.plannedEnd + lineGap > start,
    );
    final m = _build(
      spec,
      line,
      at,
      0,
      kind: CommsClass.mustPlay,
      endBy: endBy,
      // A frame early, so a 60 Hz tick never starts it after its deadline.
      ready: math.max(at, start - warningLead),
      expires: double.infinity,
    );
    if (m == null) return;
    m.late = late;
    if (late) lateWarnings++;
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
        ground.allows(spec, l, _event, now) &&
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
    expectedFire.removeWhere((l) => l < now);
    queue.removeWhere((m) {
      // Lines held by a hush get a short wait after it ends.
      final held = !m.timed && m.queuedAt < hushUntil
          ? hushUntil + pacing.flavourTtl
          : double.negativeInfinity;
      final stale = now > math.max(m.expiresAt, held) + 1e-9;
      if (stale && identical(m, _reserved)) _reserved = null;
      return stale;
    });
  }

  /// The line speaking on the channel now (a chorus voice counts).
  CommsMessage? get _onAir =>
      active.where((m) => !m.interrupted && now < m.speechEndsAt).firstOrNull;

  /// The channel is silent: may [m] start now under the pacing? Every line
  /// waits for the grace gap after the last one ends.
  bool _gateOpen(CommsMessage m) {
    final grace = now >= _speechEnd + lineGap - 1e-9;
    if (identical(m, _reserved)) return grace;
    final d = m.line.duration;
    switch (m.kind) {
      case CommsClass.mustPlay:
        // Ready a frame early so a 60 Hz tick never starts it late.
        return now >= _speechEnd + lineGap - warningLead;
      case CommsClass.urgent:
        return grace;
      case CommsClass.hint:
        // Rare (one per [CommsPacing.hintCooldown]) and the point of the
        // radio: the pickup is falling now, so only the grace gap, and
        // never held back by the budget.
        return grace;
      case CommsClass.useful:
        if (m.timed) return grace; // its budget was checked when queued
        return grace && now >= _usefulQuietUntil && _budget >= d - pacing.debt;
      case CommsClass.flavour:
        if (m.timed) return grace;
        return grace && now >= _quietUntil && _budget >= d;
    }
  }

  /// Lookahead: [m] (and an exchange's answer after it) would end, plus the
  /// grace gap, before every timed call still waiting for its slot.
  bool _clearOfTimed(CommsMessage m) {
    if (m.mustPlay) return true;
    var end = now + m.line.duration + lineGap;
    final reply = m.reply;
    if (reply != null) end += reply.line.duration + lineGap;
    if (m.timed) {
      // A timed call only yields to a promised must-play warning.
      return !queue.any(
        (o) => o.mustPlay && !identical(o, m) && o.readyAt < end,
      );
    }
    if (_hitsFireReserve(now, end)) return false;
    return !queue.any(
      (o) =>
          o.timed &&
          !identical(o, m) &&
          o.readyAt < end &&
          (o.mustPlay || o.urgent || !m.urgent),
    );
  }

  /// Speech from [start] to [end] would still be on air within
  /// [CommsPacing.fireReserve] of a forecast ground launch.
  bool _hitsFireReserve(double start, double end) =>
      expectedFire.any((l) => end > l - pacing.fireReserve + 1e-9 && start < l);

  /// Readable subtitles: flavour lines queue while a linked exchange is on
  /// screen (until its answer has been read), and an exchange only opens
  /// when the rest of the dock will be clear by the time its answer starts.
  /// Useful and timed calls, warnings and recommendations never wait for
  /// the screen; the views stack them below the exchange.
  bool _screenFree(CommsMessage m) {
    if (m.timed ||
        m.urgent ||
        m.kind == CommsClass.hint ||
        m.isReply ||
        identical(m, _reserved)) {
      return true;
    }
    if (m.kind == CommsClass.flavour &&
        (_reserved != null || active.any((a) => a.isReply && now < a.endsAt))) {
      return false;
    }
    final reply = m.reply;
    if (reply != null) {
      final answerAt = now + m.line.duration + lineGap;
      if (active.any((a) => a.endsAt > answerAt + 1e-9)) return false;
    }
    return true;
  }

  /// Advances to [at]: retires, sequences and starts messages. [combat]
  /// enables the brood's starvation timer.
  void update(double at, {bool combat = false}) {
    now = math.max(now, at);
    _refill();
    _retire();
    if (combat &&
        !hushed &&
        now - _lastDemon > starveAfter &&
        !queue.any((m) => m.isDemon) &&
        _onAir == null) {
      handle(const GameEvent(starvationTrigger), now);
    }
    _sortQueue();
    // The regroup chorus: its voices start on their own stagger, up to the
    // voice cap, but only over each other.
    for (final m in [...queue]) {
      if (!m.overlap || now < m.readyAt || hushed) continue;
      final air = active.where((a) => !a.interrupted && now < a.speechEndsAt);
      if (air.any((a) => a.trigger.name != m.trigger.name || !a.overlap)) {
        continue;
      }
      if (air.length >= overlapCap) break;
      if (air.isEmpty && (!_clearOfTimed(m) || !_graceOver)) continue;
      queue.remove(m);
      _start(m);
    }
    // The channel: one line at a time, by rank, after the pacing's rest.
    // Nothing is ever cut: a line waits for the one on air to finish.
    if (_onAir == null) {
      for (final m in [...queue]) {
        if (m.overlap || now < m.readyAt) continue;
        // A hush holds everything but the warnings.
        if (hushed && !m.urgent) continue;
        if (_reserved != null && !identical(m, _reserved) && !m.urgent) {
          continue;
        }
        if (!_gateOpen(m) || !_clearOfTimed(m) || !_screenFree(m)) continue;
        queue.remove(m);
        _start(m);
        break;
      }
    }
    for (final slot in slots) {
      if (slot.leaving != null &&
          now - slot.since >= CommsSlot.disconnectTime) {
        slot.leaving = null;
      }
    }
  }

  bool get _graceOver => now >= _speechEnd + lineGap - 1e-9;

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
    // The opening line of an exchange stays up until its answer is read.
    final opening = m.inReplyTo;
    if (opening != null) {
      opening.keepUntil = math.max(opening.keepUntil, m.endsAt);
    }
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
