import 'package:demon_attack/game/game_events.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ArcadeModel model;
  late GameEventObserver observer;
  List<String> names(List<GameEvent> events) => [
    for (final e in events)
      e.variant == null ? e.name : '${e.name}.${e.variant}',
  ];
  List<String> step([List<String>? raw]) =>
      names(observer.observe(raw ?? model.takeEvents()));

  setUp(() {
    model = ArcadeModel()..start();
    observer = GameEventObserver(model);
  });

  test('sector entrance, raw pass-through and aliases', () {
    final first = step();
    expect(first, containsAll(['level', 'sectorStart.1', 'checkpoint']));
    expect(step(['wave', 'reinforcements', 'levelclear', 'extraLife']), [
      'waveStart',
      'reinforcements',
      'levelClear',
      'flawlessSector',
      'extraLife',
    ]);
  });

  test('unknown events pass through by name with their payload', () {
    final seen = <GameEvent>[];
    observer.stream.listen(seen.add);
    final events = observer.observe(['allyUnderAttack:2,140', 'homingPickup']);
    expect(events.map((e) => e.name), ['allyUnderAttack', 'homingPickup']);
    expect(events.first.payload, '2,140');
    expect(seen.map((e) => e.name), ['allyUnderAttack', 'homingPickup']);
  });

  test('shield: spotted, collected, expiring and broken', () {
    step();
    model.mode = RunMode.playing;
    model.pickups.add(Pickup(120, 200, Power.shield));
    expect(step(), contains('shieldSpotted'));
    expect(step(), isNot(contains('shieldSpotted')));
    model.collect(Power.shield);
    expect(step(), containsAll(['powerup', 'shieldCollected']));
    model.powerTimers[Power.shield] = 2.6;
    expect(step(), isEmpty);
    model.powerTimers[Power.shield] = 2.4;
    expect(step(), ['shieldExpiring']);
    model.invulnerable = 0;
    model.hitPlayer();
    expect(step(), containsAll(['hit', 'shieldBroken']));
  });

  test('weapon pickups carry their power, lives lost and low lives', () {
    step();
    model.mode = RunMode.playing;
    model.collect(Power.spread);
    expect(step(), contains('weaponPickup.spread'));
    model.lives = 2;
    model.invulnerable = 0;
    model.hitPlayer();
    expect(step(), containsAll(['life', 'lifeLost', 'lowLives']));
  });

  test('sentinel arrival and dive, ordinary attack runs, elites', () {
    step();
    model.mode = RunMode.playing;
    model.demons.clear();
    final sentinel = Demon(
      180,
      80,
      0,
      9,
      1,
      archetype: EnemyArchetype.shieldSentinel,
    );
    model.demons.add(sentinel);
    expect(step(), contains('sentinelIncoming'));
    sentinel.telegraph = .9;
    expect(step(), ['sentinelDive']);
    expect(step(), isEmpty, reason: 'one warning per tell');
    final a = Demon(100, 120, 0, 1, 2), b = Demon(200, 120, 0, 1, 3);
    final elite = Demon(150, 100, 1, 3, 4, elite: true);
    model.demons.addAll([a, b, elite]);
    expect(step(), contains('eliteSighted'));
    a.dive = .1;
    expect(step(), isNot(contains('diveWarning')));
    b.dive = .1;
    expect(step(), ['diveWarning']);
  });

  test('carrier arrival and phases', () {
    step();
    model.level = 5;
    model.boss = Carrier(0);
    expect(
      step(['boss']),
      containsAll(['boss', 'sectorStart.5', 'bossArrival']),
    );
    expect(step(['boss']), contains('bossPhase.${model.boss!.phase}'));
    expect(step(['victory', 'bossDefeated']), [
      'victory',
      'flawlessVictory',
      'bossDefeated',
    ]);
  });

  test('observing never changes the simulation', () {
    step();
    model.mode = RunMode.playing;
    for (var i = 0; i < 240; i++) {
      model.update(1 / 60);
      final before = model.checkpoint().toString();
      final demons = model.demons.length, shots = model.shots.length;
      final clock = model.clock;
      step();
      expect(model.checkpoint().toString(), before);
      expect(model.demons.length, demons);
      expect(model.shots.length, shots);
      expect(model.clock, clock);
    }
  });
}
