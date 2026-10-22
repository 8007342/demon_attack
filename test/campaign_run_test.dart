import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(ArcadeModel m, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    m.update(1 / 60);
  }
}

void until(ArcadeModel m, RunMode mode) {
  for (var i = 0; i < 1200 && m.mode != mode; i++) {
    m.update(1 / 60);
  }
  expect(m.mode, mode);
}

void defeatRoster(ArcadeModel m) {
  final wave = m.wave;
  for (var frame = 0; frame < 2400 && m.combat && m.wave == wave; frame++) {
    for (final d in List<Demon>.of(m.demons)) {
      if (d.entering) continue;
      while (m.demons.contains(d)) {
        m.hitDemon(d);
      }
    }
    m.update(1 / 60);
  }
  expect(m.combat, isFalse, reason: 'all finite flocks must clear the wave');
}

void main() {
  for (final difficulty in Difficulty.values) {
    test(
      'five complete routes in ${difficulty.name} end with five rewards',
      () {
        final m = ArcadeModel(seed: 1982)..start(difficulty: difficulty);
        var previousScore = 0;
        var totalWaves = 0;
        for (var route = 0; route < 5; route++) {
          expect(m.cycle, route);
          while (m.level < 5) {
            until(m, RunMode.playing);
            if (m.level == 5) break;
            totalWaves++;
            expect(m.demons.length, lessThanOrEqualTo(36));
            expect(m.demons.every((d) => d.homeY <= 284), isTrue);
            expect(
              m.demons.where((d) => d.isLarge).length,
              lessThanOrEqualTo(1),
            );
            // Exercise actual attacks and motion before clearing each roster.
            m.invulnerable = 100;
            advance(m, 4);
            expect(
              m.shots.where((s) => s.hostile).length,
              lessThanOrEqualTo(120),
            );
            defeatRoster(m);
          }
          until(m, RunMode.playing);
          final boss = m.boss!;
          expect(boss.shieldMax, m.policy.bossHealth(72 + route * 18));
          expect(boss.coreMax, m.policy.bossHealth(24 + route * 10));
          m.invulnerable = 100;
          advance(m, 4);
          expect(
            m.shots.where((s) => s.hostile).length,
            lessThanOrEqualTo(120),
          );
          m.collect(Power.rapid);
          final lives = m.lives;
          while (boss.shield > 0) {
            m.hitBoss(boss.x);
          }
          boss.door = 1;
          while (m.boss != null) {
            m.hitBoss(boss.x);
          }
          expect(m.mode, RunMode.victory);
          expect(m.lives, lives + 1);
          expect(m.medals, route + 1);
          expect(m.wreckBoss, same(boss));
          expect(m.score, greaterThan(previousScore));
          previousScore = m.score;
          final kills = m.kills;
          final time = m.activeMilliseconds;
          m.pause();
          advance(m, 1);
          m.resume();
          expect(m.lives, lives + 1);
          expect(m.hitBoss(boss.x), isFalse);
          expect(m.activeMilliseconds, time);
          if (route < 4) {
            until(m, RunMode.travel);
            until(m, RunMode.transition);
            expect(m.level, 1);
            expect(m.wave, 1);
            expect(m.score, previousScore);
            expect(m.kills, kills);
            expect(m.timeLeft(Power.rapid), 9);
            expect(m.activeMilliseconds, time);
          } else {
            until(m, RunMode.completed);
            expect(m.remainingLives, lives + 1);
            expect(m.cycle, 4);
            expect(m.medals, 5);
            expect(m.takeEvents().where((e) => e == 'completed').length, 1);
            advance(m, 30);
            expect(m.mode, RunMode.completed);
            expect(m.activeMilliseconds, time);
            expect(m.lives, lives + 1);
          }
        }
        expect(totalWaves, 106);
      },
    );
  }
  test('interwave and final salvage allow protected piloting and pickup collection', () {
    final m = ArcadeModel()..start();
    until(m, RunMode.playing);
    defeatRoster(m);
    expect(m.mode, RunMode.transition);
    expect(m.canPilot, isTrue);
    m.pickups.clear();
    m.pickups.add(Pickup(250, 445, Power.spread));
    m.moveTo(250);
    advance(m, .4);
    expect(m.shipX, 250);
    expect(m.hasPower(Power.spread), isTrue);
    final duration = m.timeLeft(Power.spread);
    advance(m, .3);
    expect(m.timeLeft(Power.spread), duration);
    until(m, RunMode.playing);
    while (m.wave < m.wavesPerLevel) {
      defeatRoster(m);
      until(m, RunMode.playing);
    }
    defeatRoster(m);
    expect(m.mode, RunMode.salvage);
    m.pickups.clear();
    m.pickups.add(Pickup(150, 220, Power.shield));
    m.moveTo(150);
    m.invulnerable = 0;
    m.hitPlayer();
    expect(m.lives, 3);
    advance(m, 1.7);
    expect(m.mode, RunMode.salvage);
    expect(m.hasPower(Power.shield), isTrue);
    expect(m.shots, isEmpty);
    final progress = m.transitionProgress;
    m.pause();
    expect(m.canPilot, isFalse);
    final ship = m.shipX;
    m.moveTo(300);
    advance(m, 3);
    expect(m.shipX, ship);
    expect(m.transitionProgress, progress);
    m.resume();
    until(m, RunMode.levelClear);
    expect(m.pickups, isEmpty);
  });
  test(
    'final route caps waves density health and speed while elites attack',
    () {
      final m = ArcadeModel()..start();
      m.cycle = 4;
      until(m, RunMode.playing);
      defeatRoster(m);
      until(m, RunMode.playing);
      expect(m.wavesPerLevel, 6);
      expect(m.demons.length, lessThanOrEqualTo(30));
      expect(m.speed, 1.16);
      expect(m.demons.every((d) => d.maxHp <= 5), isTrue);
      expect(m.demons.any((d) => d.maxHp == 4), isTrue);
      final elite = m.demons.firstWhere((d) => d.elite);
      elite.attackLeft = .01;
      m.shots.clear();
      m.update(1 / 60);
      expect(m.shots.where((s) => s.hostile).length, greaterThanOrEqualTo(3));
      expect(elite.telegraph, greaterThanOrEqualTo(.55 - 1 / 60));
      final sampled = elite.targetX;
      m.moveTo(300);
      advance(m, .2);
      expect(elite.targetX, sampled);
      m.hitDemon(elite);
      expect(elite.moltStage, 1);
      m.shots.addAll(
        List.generate(120, (i) => Shot(20, 10, 0, 0, hostile: true)),
      );
      elite.attackLeft = .01;
      final count = m.shots.where((s) => s.hostile).length;
      m.update(1 / 60);
      expect(m.shots.where((s) => s.hostile).length, lessThanOrEqualTo(count));
    },
  );
}
