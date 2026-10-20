import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

ArcadeModel playing() => ArcadeModel()
  ..start()
  ..mode = RunMode.playing;
void advance(ArcadeModel m, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    m.update(1 / 60);
  }
}

void main() {
  test('spread and rapid combine in every rapid volley', () {
    final m = playing();
    m.collect(Power.spread);
    m.collect(Power.rapid);
    m.collect(Power.shield);
    m.update(1 / 60);
    expect(m.shots.where((s) => !s.hostile).length, 3);
    expect(m.shots.map((s) => s.vx).toSet(), {0.0, -90.0, 90.0});
    advance(m, .1);
    expect(m.shots.where((s) => !s.hostile).length, 6);
    expect(m.activePowers, containsAll(Power.values));
  });
  test(
    'collection refreshes only its type and expiry leaves other effects',
    () {
      final m = playing()..invulnerable = 100;
      m.collect(Power.spread);
      advance(m, 1);
      final spread = m.timeLeft(Power.spread);
      m.collect(Power.rapid);
      expect(m.timeLeft(Power.spread), spread);
      expect(m.timeLeft(Power.rapid), 9);
      advance(m, .5);
      final rapid = m.timeLeft(Power.rapid);
      m.collect(Power.spread);
      expect(m.timeLeft(Power.spread), 9);
      expect(m.timeLeft(Power.rapid), rapid);
      m.collect(Power.shield);
      m.powerTimers[Power.spread] = .01;
      m.update(1 / 60);
      expect(m.hasPower(Power.spread), isFalse);
      expect(m.hasPower(Power.rapid), isTrue);
      expect(m.hasPower(Power.shield), isTrue);
      expect(m.timeLeft(Power.rapid), closeTo(rapid - 1 / 60, .0001));
    },
  );
  test('a shield hit consumes only shield and preserves offensive timers', () {
    final m = playing()..invulnerable = 0;
    for (final p in Power.values) {
      m.collect(p);
    }
    m.hitPlayer();
    expect(m.lives, 3);
    expect(m.hasPower(Power.shield), isFalse);
    expect(m.timeLeft(Power.spread), 9);
    expect(m.timeLeft(Power.rapid), 9);
    m.hitPlayer();
    expect(m.lives, 3);
    m.invulnerable = 0;
    m.hitPlayer();
    expect(m.lives, 2);
    expect(m.activePowers.toSet(), {Power.spread, Power.rapid});
  });
  test(
    'all timers survive recovery pause and a carrier loop; Start clears them',
    () {
      final m = playing();
      for (final p in Power.values) {
        m.collect(p);
      }
      m.wave = 2;
      m.mode = RunMode.transition;
      m.transitionLeft = 1.4;
      advance(m, .3);
      expect(m.powerTimers.values, everyElement(9.0));
      m.pause();
      advance(m, .5);
      expect(m.powerTimers.values, everyElement(9.0));
      m.resume();
      m.mode = RunMode.salvage;
      m.transitionLeft = 2;
      advance(m, .3);
      expect(m.powerTimers.values, everyElement(9.0));
      m.level = 5;
      m.mode = RunMode.playing;
      m.boss = Carrier(0)
        ..shield = 0
        ..core = 1
        ..door = 1;
      m.hitBoss(m.boss!.x);
      advance(m, 9.6);
      expect(m.cycle, 1);
      expect(m.level, 1);
      expect(m.activePowers.length, 3);
      expect(m.powerTimers.values, everyElement(9.0));
      m.start();
      expect(m.activePowers, isEmpty);
      expect(m.powerTimers, isEmpty);
    },
  );
}
