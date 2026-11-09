import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/music_director.dart';
import 'package:flutter_test/flutter_test.dart';

class Log {
  final tiers = <int>[];
  final accents = <String>[];
  late final director = MusicDirector(
    onIntensity: tiers.add,
    onAccent: accents.add,
  );
}

Demon demon({
  bool elite = false,
  EnemyArchetype archetype = EnemyArchetype.ordinary,
}) => Demon(100, 100, 1, 1, .5, elite: elite, archetype: archetype);

void main() {
  test(
    'wave progress, elites and sentinels raise the tier; calm steps down late',
    () {
      final log = Log();
      final m = ArcadeModel()..restoreCheckpoint({'level': 2, 'wave': 1});
      m.mode = RunMode.playing;
      m.demons
        ..clear()
        ..add(demon());
      m.flocksSpawned = 0;
      log.director.observe(m, 1 / 60);
      expect(log.tiers, [1], reason: 'first wave opens on tier 1');
      m.wave = m.wavesPerLevel;
      log.director.observe(m, 1 / 60);
      expect(log.tiers.last, 3, reason: 'the last wave of a level is tier 3');
      m.wave = 1;
      m.demons.add(demon(elite: true));
      log.director.observe(m, 1);
      expect(
        log.tiers.last,
        3,
        reason: 'a lower target waits before stepping down',
      );
      for (var i = 0; i < 5; i++) {
        log.director.observe(m, 1);
      }
      expect(log.tiers.last, 2, reason: 'an elite keeps at least tier 2');
      m.demons.add(demon(archetype: EnemyArchetype.shieldSentinel));
      log.director.observe(m, 1 / 60);
      expect(log.tiers.last, 3, reason: 'a sentinel raises to tier 3 at once');
      m.lives = 1;
      log.director.observe(m, 1 / 60);
      expect(log.tiers.last, 4, reason: 'low lives add a tier');
    },
  );

  test('tells and arrivals send accents once per onset; the director never writes the model', () {
    final log = Log();
    final m = ArcadeModel()..restoreCheckpoint({'level': 1, 'wave': 2});
    m.mode = RunMode.playing;
    final d = demon();
    m.demons
      ..clear()
      ..add(d);
    final checkpoint = m.checkpoint();
    log.director.observe(m, 1 / 60);
    d.telegraph = .3;
    log.director.observe(m, 1 / 60);
    log.director.observe(m, 1 / 60);
    expect(log.accents, ['dive'], reason: 'one accent per new dive tell');
    d.telegraph = 0;
    d.dive = .2;
    log.director.observe(m, 3);
    final s = demon(archetype: EnemyArchetype.armoredSentinel);
    m.demons.add(s);
    s.lastStand = true;
    s.telegraph = .5;
    log.director.observe(m, 1 / 60);
    expect(log.accents.last, 'laststand');
    expect(log.tiers.last, 4, reason: 'a last stand is peril');
    m.events.add('reinforcements');
    log.director.observe(m, 1 / 60);
    expect(log.accents.last, 'reinforce');
    m.events.clear();
    expect(
      m.checkpoint(),
      checkpoint,
      reason: 'read-only with respect to the simulation',
    );
  });

  test('carrier forms map to tiers; the central hatch accent is spaced', () {
    final log = Log();
    final m = ArcadeModel()..restoreCheckpoint({'level': 5, 'cycle': 2});
    m.mode = RunMode.playing;
    final b = m.boss!;
    expect(b.formCount, 4);
    log.director.observe(m, 1 / 60);
    expect(log.tiers.last, 1, reason: 'first of four forms with its shield up');
    b.shield = 0;
    log.director.observe(m, 1 / 60);
    expect(log.tiers.last, 2, reason: 'an exposed core lifts the music');
    b.core = 1;
    log.director.observe(m, 1 / 60);
    expect(b.phase, 3);
    expect(log.tiers.last, 4, reason: 'final form is tier 4');
    b.door = 1;
    log.director.observe(m, 1 / 60);
    b.door = 0;
    log.director.observe(m, 2);
    b.door = 1;
    log.director.observe(m, 1 / 60);
    expect(log.accents.where((a) => a == 'hatch'), hasLength(1));
    b.door = 0;
    log.director.observe(m, 6);
    b.door = 1;
    log.director.observe(m, 1 / 60);
    expect(log.accents.where((a) => a == 'hatch'), hasLength(2));
  });

  test('a fleetIntact event selects the bigger celebration in any mode', () {
    var fleet = 0;
    final director = MusicDirector(
      onIntensity: (_) {},
      onAccent: (_) {},
      onFleetIntact: () => fleet++,
    );
    final m = ArcadeModel()..restoreCheckpoint({'level': 2, 'wave': 1});
    m.mode = RunMode.salvage;
    director.observe(m, 1 / 60);
    expect(fleet, 0, reason: 'no event, normal celebration');
    m.events
      ..clear()
      ..addAll(['levelclear', 'fleetIntact']);
    director.observe(m, 1 / 60);
    expect(fleet, 1);
    expect(m.events, [
      'levelclear',
      'fleetIntact',
    ], reason: 'events are left for main.dart');
  });

  test(
    'a new level resets the director so the first playing frame cues its tier',
    () {
      final log = Log();
      final m = ArcadeModel()..restoreCheckpoint({'level': 3, 'wave': 1});
      m.mode = RunMode.playing;
      m.demons.clear();
      log.director.observe(m, 1 / 60);
      m.mode = RunMode.levelClear;
      log.director.observe(m, 1 / 60);
      m.level = 4;
      m.mode = RunMode.playing;
      log.director.observe(m, 1 / 60);
      expect(log.tiers, [1, 1]);
    },
  );
}
