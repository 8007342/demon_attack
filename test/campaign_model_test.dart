import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(ArcadeModel model, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    model.update(1 / 60);
  }
}

void main() {
  test('difficulty budgets stay ordered across every campaign wave', () {
    for (var route = 0; route < 5; route++) {
      for (var sector = 1; sector < 5; sector++) {
        final waves = 3 + ((sector - 1) ~/ 2) + route.clamp(0, 3);
        for (var wave = 1; wave <= waves; wave++) {
          final rosters = <int>[];
          for (final difficulty in Difficulty.values) {
            final m = ArcadeModel();
            expect(
              m.restoreCheckpoint({
                'difficulty': difficulty.name,
                'routeIndex': route,
                'sector': sector,
                'wave': wave,
              }),
              isTrue,
            );
            rosters.add(m.demons.length);
            expect(m.demons.length, lessThanOrEqualTo(36));
            expect(m.demons.every((d) => d.homeY <= 230), isTrue);
            expect(
              m.demons.where((d) => d.isLarge).length,
              lessThanOrEqualTo(1),
            );
            if (route == 0 && wave < waves) {
              expect(m.demons.any((d) => d.isLarge), isFalse);
            }
          }
          expect(rosters[0], lessThan(rosters[1]));
          expect(rosters[1], lessThan(rosters[2]));
        }
      }
    }
    final easy = const DifficultyPolicy(Difficulty.easy);
    final normal = const DifficultyPolicy(Difficulty.normal);
    final hard = const DifficultyPolicy(Difficulty.hard);
    int growth(DifficultyPolicy p) =>
        p.rosterCount(sector: 1, wave: 1, route: 4) -
        p.rosterCount(sector: 1, wave: 1, route: 0);
    expect(growth(easy), 4);
    expect(growth(normal), 12);
    expect(growth(hard), 16);
  });

  test(
    'Easy lowers hostile cadence and points while preserving player response',
    () {
      final models = [
        for (final d in Difficulty.values) ArcadeModel()..start(difficulty: d),
      ];
      expect(models.map((m) => m.lives), [5, 3, 3]);
      for (final m in models) {
        m.mode = RunMode.playing;
        m.demons.clear();
        m.demons.add(Demon(30, 70, 0, 100, 0));
        m.moveTo(300);
        advance(m, 1.8);
      }
      expect(models[0].shipX, models[1].shipX);
      expect(
        models[0].shots.where((s) => !s.hostile).length,
        models[1].shots.where((s) => !s.hostile).length,
      );
      expect(models[0].shots.where((s) => s.hostile), isEmpty);
      expect(models[1].shots.where((s) => s.hostile).length, 1);
      for (final m in models) {
        final d = Demon(20, 70, 0, 1, 0);
        m.demons.add(d);
        m.hitDemon(d);
      }
      expect(models.map((m) => m.score), [75, 100, 100]);
      for (var route = 0; route < 5; route++) {
        final normal = Carrier(route);
        final easy = Carrier(route, difficulty: Difficulty.easy);
        final hard = Carrier(route, difficulty: Difficulty.hard);
        expect(easy.shieldMax, (normal.shieldMax * .8).round());
        expect(easy.coreMax, (normal.coreMax * .8).round());
        expect(hard.shieldMax, normal.shieldMax);
        expect(hard.coreMax, normal.coreMax);
      }
    },
  );

  test(
    'heart duplicates overflow, complete once, and reuse the first free slot',
    () {
      final m = ArcadeModel()..start();
      for (var i = 0; i < 3; i++) {
        expect(m.collectHeart(HeartPart.left), isTrue);
      }
      expect(m.heartSlots, [1, 1, 1]);
      expect(m.collectHeart(HeartPart.left), isFalse);
      expect(m.heartSlots, [1, 1, 1]);
      m.collectHeart(HeartPart.right);
      expect(m.heartSlots, [3, 1, 1]);
      m.collectHeart(HeartPart.top);
      expect(m.heartSlots, [0, 1, 1]);
      expect(m.lives, 4);
      expect(m.takeEvents().where((e) => e == 'extraLife').length, 1);
      m.collectHeart(HeartPart.left);
      expect(m.heartSlots, [1, 1, 1]);
      m.start(difficulty: Difficulty.hard);
      expect(m.collectHeart(HeartPart.left), isFalse);
      expect(m.heartSlots, [0, 0, 0]);
    },
  );

  test(
    'seeded enemy kills produce rare independent drops, never hearts on Hard',
    () {
      final drops = <int>[];
      for (final difficulty in Difficulty.values) {
        final m = ArcadeModel(seed: 82)..start(difficulty: difficulty);
        m.mode = RunMode.playing;
        for (var i = 0; i < 5000; i++) {
          final d = Demon(20, 70, 0, 1, 0);
          m.demons.add(d);
          m.hitDemon(d);
        }
        drops.add(m.heartPickups.length);
        expect(m.pickups.length, 1000);
      }
      expect(drops[0], greaterThan(drops[1]));
      expect(drops[1], inInclusiveRange(80, 220));
      expect(drops[2], 0);
    },
  );

  test(
    'heart pickups collect during salvage and clear with the next sector',
    () {
      final m = ArcadeModel()..start();
      m.mode = RunMode.salvage;
      m.heartPickups.add(
        HeartPickup(m.shipX, ArcadeModel.shipY - 4, HeartPart.top),
      );
      advance(m, .1);
      expect(m.heartPickups, isEmpty);
      expect(m.heartSlots, [4, 0, 0]);
      expect(m.activeMilliseconds, 0);
    },
  );

  test(
    'large enemies telegraph, survive dives, and award one unique defeat',
    () {
      for (final archetype in [
        EnemyArchetype.shieldSentinel,
        EnemyArchetype.armoredSentinel,
      ]) {
        final m = ArcadeModel()..start();
        m.mode = RunMode.playing;
        m.invulnerable = 100;
        final d = Demon(30, 70, 2, 8, 0, archetype: archetype);
        m.demons.clear();
        m.demons.add(d);
        d.attackLeft = .01;
        advance(m, 1 / 60);
        expect(d.telegraph, greaterThan(.8));
        final target = d.targetX;
        m.moveTo(330);
        advance(m, .3);
        expect(d.targetX, target);
        d.dive = .1;
        d.y = ArcadeModel.height + 19;
        advance(m, 1 / 60);
        expect(d.dive, 0);
        expect(d.hp, 8);
        final kills = m.kills;
        while (m.demons.contains(d)) {
          m.hitDemon(d);
        }
        final score = m.score;
        m.hitDemon(d);
        expect(m.kills, kills + 1);
        expect(m.score, score);
        expect(m.blasts.where((b) => b.archetype == archetype).length, 1);
      }
    },
  );

  test('active time excludes every cinematic, pause and terminal state', () {
    final m = ArcadeModel()..start();
    advance(m, 1);
    expect(m.activeMilliseconds, 0);
    m.mode = RunMode.playing;
    advance(m, 1);
    expect(m.activeMilliseconds, 1000);
    m.pause();
    advance(m, 1);
    expect(m.activeMilliseconds, 1000);
    m.resume();
    for (final phase in [
      RunMode.salvage,
      RunMode.levelClear,
      RunMode.travel,
      RunMode.victory,
      RunMode.gameOver,
      RunMode.completed,
    ]) {
      m.mode = phase;
      m.transitionLeft = 3;
      advance(m, 1);
      expect(m.activeMilliseconds, 1000);
    }
  });

  test('checkpoint restores one consistent fresh boundary with no powers', () {
    final original = ArcadeModel();
    expect(
      original.restoreCheckpoint({
        'difficulty': 'easy',
        'routeIndex': 2,
        'sector': 3,
        'wave': 4,
        'score': 23456,
        'lives': 6,
        'medals': 2,
        'kills': 543,
        'heartSlots': [1, 3, 4],
        'activeMilliseconds': 123456,
      }),
      isTrue,
    );
    final checkpoint = original.checkpoint();
    final resumed = ArcadeModel()..start();
    resumed.collect(Power.spread);
    expect(resumed.restoreCheckpoint(checkpoint), isTrue);
    expect(resumed.checkpoint(), checkpoint);
    expect(resumed.activePowers, isEmpty);
    expect(resumed.shots, isEmpty);
    expect(resumed.pickups, isEmpty);
    expect(resumed.heartPickups, isEmpty);
    expect(resumed.mode, RunMode.transition);
    expect(resumed.demons, isNotEmpty);
    expect(resumed.takeEvents().where((e) => e == 'checkpoint').length, 1);
    resumed.mode = RunMode.playing;
    advance(resumed, 1);
    resumed.score += 100;
    expect(resumed.restoreCheckpoint(checkpoint), isTrue);
    expect(resumed.score, 23456);
    expect(resumed.activeMilliseconds, 123456);
  });

  test(
    'checkpoint defaults and future fields coexist, corruption is atomic',
    () {
      final m = ArcadeModel();
      expect(
        m.restoreCheckpoint({
          'score': 100,
          'wave': 2,
          'schemaVersion': 999,
          'future': true,
        }),
        isTrue,
      );
      expect(m.difficulty, Difficulty.normal);
      expect(m.cycle, 0);
      expect(m.level, 1);
      expect(m.wave, 2);
      expect(m.lives, 3);
      expect(m.medals, 0);
      expect(m.activeMilliseconds, 0);
      expect(m.heartSlots, [0, 0, 0]);
      final before = m.checkpoint();
      for (final invalid in [
        {'routeIndex': 5},
        {'routeIndex': 'unknown'},
        {'sector': 0},
        {'sector': 5, 'wave': 2},
        {'wave': -1},
        {'lives': 0},
        {'medals': 5},
        {'score': -1},
        {'activeMilliseconds': 'bad'},
        {
          'heartSlots': [7, 0, 0],
        },
        {'difficulty': 'impossible'},
      ]) {
        expect(m.restoreCheckpoint(invalid), isFalse, reason: '$invalid');
        expect(m.checkpoint(), before);
      }
      expect(m.restoreCheckpoint({'cycle': 1, 'level': 5}), isTrue);
      expect(m.boss, isNotNull);
      expect(m.medals, 0);
    },
  );

  test(
    'replaying a pre-victory boundary cannot accumulate duplicate rewards',
    () {
      final m = ArcadeModel();
      m.restoreCheckpoint({
        'routeIndex': 3,
        'sector': 5,
        'medals': 3,
        'lives': 2,
      });
      final beforeVictory = m.checkpoint();
      for (var replay = 0; replay < 3; replay++) {
        expect(m.restoreCheckpoint(beforeVictory), isTrue);
        m.mode = RunMode.playing;
        final boss = m.boss!..shield = 0;
        boss.core = 1;
        boss.door = 1;
        m.hitBoss(boss.x);
        expect(m.lives, 3);
        expect(m.medals, 4);
        expect(m.hitBoss(boss.x), isFalse);
        expect(m.takeEvents().where((e) => e == 'bossDefeated').length, 1);
      }
    },
  );
}
