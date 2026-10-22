import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void play(ArcadeModel m) {
  m.start();
  m.mode = RunMode.playing;
}

void main() {
  test('three lives, one hit, invulnerability and game over', () {
    final m = ArcadeModel();
    play(m);
    expect(m.lives, 3);
    m.invulnerable = 0;
    m.hitPlayer();
    m.hitPlayer();
    expect(m.lives, 2);
    m.invulnerable = 0;
    m.hitPlayer();
    m.invulnerable = 0;
    m.hitPlayer();
    expect(m.mode, RunMode.gameOver);
  });
  test('touch targets stay in arena; pause freezes timers and position', () {
    final m = ArcadeModel();
    play(m);
    m.moveTo(-100);
    expect(m.targetX, 18);
    m.moveTo(999);
    expect(m.targetX, 342);
    m.pause();
    m.update(.1);
    expect(m.clock, 0);
    expect(m.shipX, 180);
    m.resume();
    m.update(.1);
    expect(m.shipX, greaterThan(180));
  });
  test('armor transforms to angry final stage and rewards stronger kills', () {
    final m = ArcadeModel();
    play(m);
    final d = Demon(100, 100, 2, 3, 0);
    m.demons.add(d);
    m.hitDemon(d);
    expect(d.hp, 2);
    m.hitDemon(d);
    expect(d.angry, true);
    expect(d.telegraph, greaterThan(0));
    m.hitDemon(d);
    expect(m.demons.contains(d), false);
    expect(m.score, 350);
  });
  test('powers expire and shield absorbs one hit', () {
    final m = ArcadeModel();
    play(m);
    m.invulnerable = 0;
    m.collect(Power.shield);
    m.hitPlayer();
    expect(m.lives, 3);
    expect(m.activePowers, isEmpty);
    m.collect(Power.rapid);
    m.powerTimers[Power.rapid] = .01;
    m.update(.02);
    expect(m.activePowers, isEmpty);
  });
  test('boss shield and door gate core damage; victory loops with retained lives and score', () {
    final m = ArcadeModel();
    play(m);
    m.level = 5;
    m.boss = Carrier(0);
    final b = m.boss!;
    final core = b.core;
    m.hitBoss(b.x);
    expect(b.shield, b.shieldMax - 1);
    expect(b.core, core);
    b.shield = 0;
    b.door = 0;
    expect(m.hitBoss(b.x), false);
    b.door = 1;
    expect(m.hitBoss(b.x + 30), false);
    b.core = 1;
    expect(m.hitBoss(b.x), true);
    expect(m.mode, RunMode.victory);
    expect(m.score, 5000);
    for (var i = 0; i < 110; i++) {
      m.update(.1);
    }
    expect(m.cycle, 1);
    expect(m.level, 1);
    expect(m.lives, 4);
    expect(m.medals, 1);
    expect(m.score, 5000);
    expect(m.speed, 1.04);
    expect(m.demons.first.maxHp, greaterThan(1));
    expect(m.wavesPerLevel, greaterThan(3));
    expect(m.demons.map((d) => d.kind).toSet().length, greaterThan(1));
    expect(Carrier(2).formCount, 4);
  });
  test('fixed step is stable for equivalent frame time and auto fires', () {
    final a = ArcadeModel(), b = ArcadeModel();
    play(a);
    play(b);
    for (var i = 0; i < 60; i++) {
      a.update(1 / 60);
    }
    for (var i = 0; i < 30; i++) {
      b.update(1 / 30);
    }
    expect(a.shots.length, b.shots.length);
    expect(a.clock, closeTo(b.clock, 1e-9));
    expect(a.shots, isNotEmpty);
  });
}
