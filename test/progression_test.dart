import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void tick(ArcadeModel model, double seconds) {
  for (var frame = 0; frame < (seconds * 60).ceil(); frame++) {
    model.update(1 / 60);
  }
}

void reach(ArcadeModel model, RunMode mode) {
  for (var frame = 0; frame < 1200 && model.mode != mode; frame++) {
    model.update(1 / 60);
  }
  expect(model.mode, mode, reason: 'progression must reach $mode within 20 s');
}

void clearWave(ArcadeModel model) {
  expect(model.mode, RunMode.playing);
  for (final demon in List<Demon>.of(model.demons)) {
    while (model.demons.contains(demon)) {
      model.hitDemon(demon);
    }
  }
  model.update(1 / 60);
}

void main() {
  test('only the last wave advances each level through clear and travel', () {
    final model = ArcadeModel()..start();
    for (var level = 1; level <= 4; level++) {
      final waveCount = level <= 2 ? 3 : 4;
      for (var wave = 1; wave <= waveCount; wave++) {
        reach(model, RunMode.playing);
        expect(model.level, level);
        expect(model.wave, wave);
        expect(model.demons.length, 6 + level * 2 + (wave - 1) * 2);
        model.takeEvents();
        clearWave(model);
        expect(model.level, level);
        if (wave < waveCount) {
          expect(model.mode, RunMode.transition);
          expect(model.wave, wave + 1);
          final events = model.takeEvents();
          expect(events, contains('wave'));
          expect(events, isNot(contains('victory')));
        } else {
          expect(model.mode, RunMode.salvage);
          reach(model, RunMode.levelClear);
          tick(model, 3.8);
          expect(model.mode, RunMode.levelClear);
          expect(model.level, level);
          reach(model, RunMode.travel);
          expect(model.level, level);
          tick(model, 3.8);
          expect(model.mode, RunMode.travel);
          reach(model, RunMode.transition);
          expect(model.level, level + 1);
        }
      }
    }
    expect(model.level, 5);
    expect(model.boss, isNotNull);
    reach(model, RunMode.playing);
    expect(model.isBoss, isTrue);
  });

  test(
    'cinematics freeze combat and powers; pause retains transition progress',
    () {
      final model = ArcadeModel()..start();
      for (final phase in [
        RunMode.transition,
        RunMode.levelClear,
        RunMode.travel,
        RunMode.victory,
      ]) {
        model.mode = phase;
        model.transitionDuration = 4;
        model.transitionLeft = 4;
        model.invulnerable = 0;
        model.collect(Power.rapid);
        final lives = model.lives;
        final score = model.score;
        model.hitPlayer();
        final protectedBoss = Carrier(0);
        model.boss = protectedBoss;
        expect(model.hitBoss(protectedBoss.x), isFalse);
        expect(protectedBoss.shield, protectedBoss.shieldMax);
        model.boss = null;
        tick(model, .5);
        expect(model.mode, phase);
        expect(model.lives, lives);
        expect(model.score, score);
        expect(model.power, Power.rapid);
        expect(model.powerLeft, 9);
        final progress = model.transitionProgress;
        expect(progress, greaterThan(0));
        final remaining = model.transitionLeft;
        expect(remaining, lessThan(4));
        model.pause();
        expect(model.mode, RunMode.paused);
        tick(model, 2);
        expect(model.transitionLeft, remaining);
        expect(model.transitionProgress, progress);
        model.resume();
        expect(model.mode, phase);
        tick(model, .5);
        expect(model.transitionLeft, lessThan(remaining));
        expect(model.transitionProgress, greaterThan(progress));
      }
    },
  );

  test(
    '72 shield hits precede gated core and victory travels to next cycle',
    () {
      final model = ArcadeModel()..start();
      model
        ..mode = RunMode.playing
        ..level = 5
        ..boss = Carrier(0)
        ..lives = 2
        ..score = 1234;
      model.collect(Power.spread);
      final boss = model.boss!;
      expect(boss.shield, 72);
      expect(boss.core, 24);
      for (var hit = 0; hit < 72; hit++) {
        expect(model.hitBoss(boss.x), isTrue);
        expect(boss.core, 24);
        expect(boss.shield, 71 - hit);
      }
      boss.door = 0;
      expect(model.hitBoss(boss.x), isFalse);
      boss.door = 1;
      expect(model.hitBoss(boss.x + 30), isFalse);
      for (var hit = 0; hit < 24; hit++) {
        expect(model.hitBoss(boss.x), isTrue);
      }
      expect(model.mode, RunMode.victory);
      expect(model.score, 6234);
      expect(model.lives, 2);
      expect(model.shots, isEmpty);
      expect(model.demons, isEmpty);
      model.hitPlayer();
      tick(model, 5.3);
      expect(model.mode, RunMode.victory);
      expect(model.cycle, 0);
      reach(model, RunMode.travel);
      expect(model.cycle, 0);
      tick(model, 3.8);
      expect(model.mode, RunMode.travel);
      reach(model, RunMode.transition);
      expect(model.cycle, 1);
      expect(model.level, 1);
      expect(model.wave, 1);
      expect(model.score, 6234);
      expect(model.lives, 2);
      expect(model.speed, greaterThan(1));
      expect(model.power, Power.spread);
      expect(model.powerLeft, 9);
    },
  );
}
