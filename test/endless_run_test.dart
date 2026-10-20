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
  for (final d in List<Demon>.of(m.demons)) {
    while (m.demons.contains(d)) {
      m.hitDemon(d);
    }
  }
  m.update(1 / 60);
}

void main() {
  test(
    'one run loops twice with retained stats and stronger bounded populations',
    () {
      final m = ArcadeModel()..start();
      m.lives = 2;
      final startingWaves = m.wavesPerLevel;
      var previousScore = 0;
      var previousMaxHp = 1;
      for (var run = 0; run < 2; run++) {
        while (m.level < 5) {
          until(m, RunMode.playing);
          expect(m.demons.length, lessThanOrEqualTo(24));
          expect(m.demons.every((d) => d.homeY < 260), isTrue);
          defeatRoster(m);
        }
        until(m, RunMode.playing);
        final boss = m.boss!;
        expect(boss.shieldMax, 72 + run * 18);
        expect(boss.coreMax, 24 + run * 10);
        m.collect(Power.rapid);
        while (boss.shield > 0) {
          m.hitBoss(boss.x);
        }
        boss.door = 1;
        while (m.boss != null) {
          m.hitBoss(boss.x);
        }
        expect(m.mode, RunMode.victory);
        expect(m.score, greaterThan(previousScore));
        previousScore = m.score;
        final kills = m.kills;
        until(m, RunMode.travel);
        until(m, RunMode.transition);
        expect(m.cycle, run + 1);
        expect(m.level, 1);
        expect(m.wave, 1);
        expect(m.wavesPerLevel, startingWaves + run + 1);
        expect(m.lives, 2);
        expect(m.score, previousScore);
        expect(m.kills, kills);
        expect(m.hasPower(Power.rapid), isTrue);
        expect(m.timeLeft(Power.rapid), 9);
        expect(m.demons.any((d) => d.elite), isTrue);
        final maxHp = m.demons
            .map((d) => d.maxHp)
            .reduce((a, b) => a > b ? a : b);
        expect(maxHp, greaterThan(previousMaxHp));
        previousMaxHp = maxHp;
        expect(m.demons.map((d) => d.kind).toSet().length, 4);
      }
    },
  );
  test(
    'interwave and final salvage allow protected piloting and pickup collection',
    () {
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
    },
  );
  test(
    'late cycles cap waves density health and speed while elites attack',
    () {
      final m = ArcadeModel()..start();
      m.cycle = 100;
      until(m, RunMode.playing);
      defeatRoster(m);
      until(m, RunMode.playing);
      expect(m.wavesPerLevel, 6);
      expect(m.demons.length, lessThanOrEqualTo(24));
      expect(m.speed, 1.8);
      expect(m.demons.every((d) => d.maxHp <= 7), isTrue);
      expect(m.demons.any((d) => d.maxHp == 7), isTrue);
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
