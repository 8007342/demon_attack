/// Glue between the shared [GameEvent] stream, the [CommsDirector] and the
/// voice player. Owns the comms clock, which stops while the game is paused.
library;

import 'dart:convert';

import '../game/game_events.dart';
import '../services/audio.dart';
import '../services/comms_audio.dart';
import '../services/run_storage.dart';
import 'comms_bank.dart';
import 'comms_director.dart';
import 'comms_lineup.dart';
import 'comms_types.dart';

class SquadComms {
  SquadComms({
    CommsDirector? director,
    this.playAudio = true,
    this.lineupSeed,
    this.wallClock,
  }) : director = director ?? CommsDirector() {
    this.director
      ..onStart = _start
      ..onStop = _stop;
  }
  final CommsDirector director;
  final bool playAudio;

  /// Fixed lineup seed (tests); null seeds each run from the clock.
  final int? lineupSeed;
  final _watch = Stopwatch()..start();

  /// Seconds of wall time (tests inject a controllable clock).
  final double Function()? wallClock;
  double _lastWall = 0, clock = 0;
  bool voiceOn = true;
  CommsLineup? lineup;

  static const lineupKey = 'demonAttack.commsLineup';

  double get now => clock;

  /// Seeds this run's crew. A resumed run keeps its saved lineup; a new run
  /// draws a fresh one that avoids the previous run's lineup.
  CommsLineup startRun(LocalStore store, {bool resume = false, int? seed}) {
    CommsLineup? previous;
    try {
      final raw = store.read(lineupKey);
      previous = raw == null ? null : CommsLineup.fromJson(jsonDecode(raw));
    } catch (_) {
      previous = null;
    }
    final next = resume && previous != null
        ? previous
        : CommsLineup.pick(
            seed ??
                lineupSeed ??
                ((previous?.seed ?? 1982) * 31 +
                        DateTime.now().millisecondsSinceEpoch) &
                    0x3fffffff,
            previous: previous,
          );
    try {
      store.write(lineupKey, jsonEncode(next.toJson()));
    } catch (_) {
      // Denied storage only means the next run may repeat this lineup.
    }
    useLineup(next);
    return next;
  }

  void useLineup(CommsLineup value) {
    lineup = value;
    director.setLineup(value);
  }

  void _start(CommsMessage m) {
    if (playAudio && voiceOn) commsPlay(m.line.id, m.priority, m.isDemon);
  }

  void _stop(CommsMessage m) {
    if (playAudio) commsStop(m.line.id);
  }

  void setVoice(bool on) {
    voiceOn = on;
    if (playAudio) commsVolume(on ? 1 : 0);
  }

  final _pending = <GameEvent>[];
  void Function()? _detach;

  /// Subscribes to the shared dispatcher; events are buffered until [tick].
  void attach() {
    _detach ??= GameEvents.listen(_pending.add);
  }

  void detach() {
    _detach?.call();
    _detach = null;
  }

  /// Feeds the buffered (and [events]) and advances the clock unless
  /// [paused].
  ///
  /// [combat] arms the brood's starvation timer.
  void tick({
    List<GameEvent> events = const [],
    required bool paused,
    bool combat = false,
  }) {
    final wall = wallClock?.call() ?? _watch.elapsedMicroseconds / 1e6;
    final dt = (wall - _lastWall).clamp(0.0, .1);
    _lastWall = wall;
    advance(dt, paused: paused);
    final batch = [..._pending, ...events];
    _pending.clear();
    // The life-loss sequence: if the model doesn't (yet) emit regroupStart /
    // playerRespawn, they follow a lost ship; real events are deduplicated
    // by the triggers' cooldowns.
    final due = _synthetic.where((e) => e.$1 <= clock).toList();
    _synthetic.removeWhere((e) => e.$1 <= clock);
    batch.addAll(due.map((e) => e.$2));
    for (final event in [...batch]) {
      if (event.name == GameEventNames.lifeLost ||
          event.name == GameEventNames.playerDestroyed) {
        batch.add(const GameEvent(GameEventNames.regroupStart));
        _synthetic.removeWhere(
          (e) => e.$2.name == GameEventNames.playerRespawn,
        );
        _synthetic.add((
          clock + respawnDelay,
          const GameEvent(GameEventNames.playerRespawn),
        ));
      } else if (event.name == GameEventNames.playerRespawn) {
        _synthetic.removeWhere(
          (e) => e.$2.name == GameEventNames.playerRespawn,
        );
      }
    }
    for (final event in batch) {
      // Kill reports are the allies' own chatter; homing kills stay quiet.
      if (event.name == GameEventNames.groundUnitDestroyed &&
          (event.data['by'] ?? 'allies') != 'allies') {
        continue;
      }
      if (event.name == GameEventNames.sectorStart) _prefetch(event.variant);
      // Fleet intact: a short fanfare stinger under the celebration lines.
      if (playAudio &&
          (event.name == GameEventNames.flawlessVictory ||
              event.name == GameEventNames.flawlessRun)) {
        audioSfx('extraLife');
      }
      director.handle(event, clock);
    }
    director.update(clock, combat: combat && !paused);
  }

  /// Seconds after a lost ship when the reserve is assumed launched (if the
  /// model emits no `playerRespawn`).
  static const respawnDelay = 2.8;
  final _synthetic = <(double, GameEvent)>[];

  /// Advances the comms clock by [dt] seconds (tests drive this directly).
  void advance(double dt, {required bool paused}) {
    if (!paused) clock += dt;
  }

  void _prefetch(String? sector) {
    if (!playAudio) return;
    final s = int.tryParse(sector ?? '') ?? 1;
    final crew = {
      for (final ids in (director.roster[s] ?? const {}).values) ...ids,
    };
    final ids = <String>[
      for (final bank in [commsHumanTriggers, commsDemonTriggers])
        for (final CommsTriggerSpec spec in bank.values)
          for (final line in spec.lines)
            if (crew.contains(line.speaker)) line.id,
    ];
    commsPrefetch(ids);
  }

  void reset() {
    _pending.clear();
    _synthetic.clear();
    director.reset();
    if (playAudio) commsStopAll();
  }
}
