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
  final wave = model.wave;
  for (
    var frame = 0;
    frame < 2400 && model.combat && model.wave == wave;
    frame++
  ) {
    for (final demon in List<Demon>.of(model.demons)) {
      if (demon.entering) continue;
      while (model.demons.contains(demon)) {
        model.hitDemon(demon);
      }
    }
    model.update(1 / 60);
  }
  expect(model.combat, isFalse);
}

void main() {
  test('the first swarm flies in only after the arrival hint disappears', () {
    for (final difficulty in Difficulty.values) {
      final model = ArcadeModel()
        ..restoreCheckpoint({
          'difficulty': difficulty.name,
          'routeIndex': 4,
          'sector': 4,
        });
      final initial = List<Demon>.of(model.demons);
      expect(
        initial.every(
          (d) => d.entering && d.entranceProgress == 0 && d.y < -30,
        ),
        isTrue,
      );
      tick(model, ArcadeModel.arrivalHintDuration - .2);
      expect(model.mode, RunMode.transition);
      expect(
        initial.every(
          (d) => d.entranceProgress == 0 && d.y == d.entranceStartY,
        ),
        isTrue,
      );
      model.pause();
      tick(model, 2);
      expect(initial.every((d) => d.entranceProgress == 0), isTrue);
      model.resume();
      reach(model, RunMode.playing);
      expect(initial.every((d) => d.entranceProgress == 0), isTrue);
      tick(model, .5);
      expect(
        initial.any((d) => d.entranceProgress > 0 && d.entranceProgress < 1),
        isTrue,
      );
      expect(model.shots.where((s) => s.hostile), isEmpty);
      final progress = initial.first.entranceProgress;
      model.pause();
      tick(model, 1);
      model.resume();
      expect(initial.first.entranceProgress, progress);
      tick(model, 1.2);
      expect(initial.every((d) => !d.entering), isTrue);
    }
    final interwave = ArcadeModel()
      ..restoreCheckpoint({'sector': 2, 'wave': 2});
    expect(interwave.demons.every((d) => !d.entering), isTrue);
    final carrier = ArcadeModel()..restoreCheckpoint({'sector': 5});
    expect(carrier.boss, isNotNull);
    expect(carrier.demons, isEmpty);
    expect(carrier.mode, RunMode.transition);
  });

  test('story phases add reading time and salvage stays two seconds', () {
    final m = ArcadeModel()..start();
    expect(m.transitionDuration, ArcadeModel.arrivalHintDuration);
    reach(m, RunMode.playing);
    clearWave(m);
    expect(m.transitionDuration, closeTo(1.4 + 1 / 3, .0001));
    while (m.wave < m.wavesPerLevel) {
      reach(m, RunMode.playing);
      clearWave(m);
    }
    reach(m, RunMode.playing);
    clearWave(m);
    expect(m.mode, RunMode.salvage);
    expect(m.transitionDuration, 2);
    reach(m, RunMode.levelClear);
    expect(m.transitionDuration, closeTo(4 + 1 / 3, .0001));
    reach(m, RunMode.travel);
    expect(m.transitionDuration, closeTo(4 + 1 / 3, .0001));
    m.restoreCheckpoint({'sector': 5});
    reach(m, RunMode.playing);
    final boss = m.boss!..shield = 0;
    boss
      ..core = 1
      ..door = 1;
    m.hitBoss(boss.x);
    expect(m.transitionDuration, closeTo(5.5 + 1 / 3, .0001));
  });

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
        expect(model.hasPower(Power.rapid), isTrue);
        expect(model.timeLeft(Power.rapid), 9);
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
      expect(model.lives, 3);
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
      expect(model.lives, 3);
      expect(model.speed, greaterThan(1));
      expect(model.hasPower(Power.spread), isTrue);
      expect(model.timeLeft(Power.spread), 9);
    },
  );
}
