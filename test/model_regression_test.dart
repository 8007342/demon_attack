import 'package:flutter_test/flutter_test.dart';
import 'package:demon_attack/game/model.dart';

void advance(ArcadeModel model, double seconds) {
  for (var frame = 0; frame < (seconds * 60).ceil(); frame++) {
    model.update(1 / 60);
  }
}

void main() {
  test('a shot that destroys the boss safely enters victory and restarts level one', () {
    final model = ArcadeModel()..start();
    model.level = 5;
    model.mode = RunMode.playing;
    model.demons.clear();
    final boss = Carrier(0)..shield = 0;
    boss.core = 1;
    model.boss = boss;
    model.levelClock = .6;
    final x = boss.forecastX(1 / 60, model.speed);
    final y = boss.y;
    model.shots.add(Shot(x, y + 10, 0, 0));
    expect(() => model.update(1 / 60), returnsNormally);
    expect(model.mode, RunMode.victory);
    expect(model.boss, isNull);
    expect(model.score, 5000);
    advance(model, 10.3);
    expect(model.level, 1);
    expect(model.cycle, 1);
    expect(model.mode, RunMode.transition);
    expect(model.demons, isNotEmpty);
  });

  test(
    'same-level wave entrance clears shots and retains uncollected pickups',
    () {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      model.flocksSpawned = model.flocksPlanned;
      model.pickups.add(Pickup(20, 100, Power.spread));
      model.shots.add(Shot(20, 200, 0, 20, hostile: true));
      model.update(1 / 60);
      expect(model.level, 1);
      expect(model.wave, 2);
      expect(model.mode, RunMode.transition);
      expect(model.shots, isEmpty);
      expect(model.pickups.single.power, Power.spread);
    },
  );

  test('last life ends the run without progressing an empty wave', () {
    final model = ArcadeModel()..start();
    model.mode = RunMode.playing;
    model.invulnerable = 0;
    model.lives = 1;
    model.demons.clear();
    model.shots.add(Shot(model.shipX, ArcadeModel.shipY, 0, 0, hostile: true));
    model.update(.1);
    expect(model.mode, RunMode.gameOver);
    expect(model.lives, 0);
    expect(model.level, 1);
    final clock = model.clock;
    model.update(10);
    expect(model.clock, clock);
  });

  test('closed door protects core after shield breaks, then open central door takes damage', () {
    final model = ArcadeModel()..start();
    model.mode = RunMode.playing;
    final boss = Carrier(0);
    model.boss = boss;
    final core = boss.core;
    for (var hit = 0; hit < boss.shieldMax; hit++) {
      expect(model.hitBoss(boss.x + 70), isTrue);
    }
    expect(boss.shield, 0);
    expect(boss.core, core);
    boss.door = 0;
    expect(model.hitBoss(boss.x), isFalse);
    boss.door = 1;
    expect(model.hitBoss(boss.x + 20), isFalse);
    expect(model.hitBoss(boss.x), isTrue);
    expect(boss.core, core - 1);
  });
}
