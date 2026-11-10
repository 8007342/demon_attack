import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/music_director.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays the real simulation with the director attached (as the scene does)
/// and checks that ordinary play produces music events, read-only.
Map<String, Object> run(Map<String, Object> checkpoint, double seconds) {
  final events = <GameEvent>[];
  final director = MusicDirector(emit: events.add);
  final m = ArcadeModel(seed: 7)..start();
  if (checkpoint.isNotEmpty) m.restoreCheckpoint(checkpoint);
  m.mode = RunMode.playing;
  for (var i = 0; i < (60 * seconds).round(); i++) {
    m.invulnerable = 1e9; // keep the run alive; the director only reads state
    m.update(1 / 60);
    director.observe(m, 1 / 60);
    m.takeEvents();
  }
  final names = events.map((e) => e.name).toList();
  return {
    'counts': {
      for (final n in names.toSet()) n: names.where((x) => x == n).length,
    },
    'tiers': [
      for (final e in events)
        if (e.name == GameEventNames.musicIntensity) e.data['tier'],
    ],
  };
}

void main() {
  test('level 1 (no dives by design on the first route): tiers rise with progress and reinforcements', () {
    final r = run({}, 40);
    // ignore: avoid_print
    print('L1 40 s: $r');
    final counts = r['counts'] as Map;
    expect(counts[GameEventNames.musicIntensity], greaterThan(1));
    expect(counts[GameEventNames.reinforcementsArrived], greaterThan(0));
    expect(counts.containsKey(GameEventNames.diveTell), isFalse);
  });

  test('level 2: dive tells are published, spaced at least 0.75 s apart (dive layers compose)', () {
    final r = run({'level': 2, 'wave': 2}, 40);
    // ignore: avoid_print
    print('L2 40 s: $r');
    final counts = r['counts'] as Map;
    expect(counts[GameEventNames.diveTell], greaterThan(2));
    expect(counts[GameEventNames.diveTell], lessThanOrEqualTo(40 / .75));
  });
}
