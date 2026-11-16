import 'dart:math' as math;

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
            expect(m.demons.every((d) => d.homeY <= 284), isTrue);
            expect(
              m.demons.where((d) => d.isLarge).length,
              lessThanOrEqualTo(1),
            );
            if (route == 0) {
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
    expect(growth(normal), 4);
    expect(growth(hard), 4);
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
        expect(m.collectHeart(HeartPart.bottomLeft), isTrue);
      }
      expect(m.heartSlots, [1, 1, 1]);
      expect(m.collectHeart(HeartPart.bottomLeft), isFalse);
      expect(m.heartSlots, [1, 1, 1]);
      m.collectHeart(HeartPart.bottomRight);
      expect(m.heartSlots, [3, 1, 1]);
      m.collectHeart(HeartPart.topLeft);
      expect(m.heartSlots, [7, 1, 1]);
      expect(m.lives, 3);
      m.collectHeart(HeartPart.topRight);
      expect(m.heartSlots, [0, 1, 1]);
      expect(m.lives, 4);
      expect(m.takeEvents().where((e) => e == 'extraLife').length, 1);
      m.collectHeart(HeartPart.bottomLeft);
      expect(m.heartSlots, [1, 1, 1]);
      m.start(difficulty: Difficulty.hard);
      expect(m.collectHeart(HeartPart.bottomLeft), isFalse);
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
        expect(m.pickups.length, 625);
      }
      expect(const DifficultyPolicy(Difficulty.easy).heartDropChance, .012);
      expect(const DifficultyPolicy(Difficulty.normal).heartDropChance, .008);
      expect(drops[0], inInclusiveRange(35, 90));
      expect(drops[0], greaterThan(drops[1]));
      expect(drops[1], inInclusiveRange(20, 65));
      expect(drops[2], 0);
    },
  );

  test(
    'heart pickups collect during salvage and clear with the next sector',
    () {
      final m = ArcadeModel()..start();
      m.mode = RunMode.salvage;
      m.heartPickups.add(
        HeartPickup(m.shipX, ArcadeModel.shipY - 4, HeartPart.topLeft),
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
        // A beat of divePrep (radio warning) comes before the dive tell.
        expect(d.divePrep, greaterThan(0));
        expect(d.telegraph, 0);
        advance(m, ArcadeModel.divePrepBeat + 1 / 60);
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
        for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
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

  test('sentinels wait for the swarm, enter protected, and hover above it', () {
    final m = ArcadeModel();
    expect(
      m.restoreCheckpoint({'routeIndex': 1, 'sector': 2, 'wave': 4}),
      isTrue,
    );
    final sentinel = m.demons.singleWhere((d) => d.isLarge);
    final swarm = m.demons.where((d) => !d.isLarge).toList();
    expect(sentinel.entranceProgress, 0);
    expect(sentinel.y, -48);
    advance(m, 1);
    expect(sentinel.entranceProgress, 0);
    expect(sentinel.y, -48);
    while (!m.combat) {
      m.update(1 / 60);
    }
    m.invulnerable = 100;
    sentinel.attackLeft = .01;
    m.moveTo(18);
    advance(m, .3);
    m.hitDemon(sentinel);
    expect(sentinel.hp, sentinel.maxHp);
    expect(sentinel.entranceProgress, 0);
    // Crowded ordinary arrivals may defer the dedicated escort until its
    // bounded admission budget has room. It remains a fresh separate event.
    for (var frame = 0; frame < 600 && !m.escortSpawned; frame++) {
      if (frame % 30 == 0) {
        final victim = m.demons
            .where((d) => !d.isLarge && !d.entering)
            .firstOrNull;
        if (victim != null) m.hitDemon(victim, damage: 1000);
      }
      m.update(1 / 60);
    }
    advance(m, 1.5);
    expect(m.flocksSpawned, greaterThanOrEqualTo(1));
    expect(m.escortSpawned, isTrue);
    expect(sentinel.entranceProgress, inExclusiveRange(0, 1));
    expect(sentinel.telegraph, 0);
    expect(sentinel.dive, 0);
    expect(sentinel.attackLeft, .01);
    m.hitDemon(sentinel);
    expect(sentinel.hp, sentinel.maxHp);
    m.pause();
    final entrance = sentinel.entranceProgress;
    advance(m, 1);
    expect(sentinel.entranceProgress, entrance);
    m.resume();
    // continuous-swarm: a foreshadowed sentinel rises through the fog
    // bands over sentinelRiseSeconds instead of the old 1.8 s.
    advance(m, 1.6 + (sentinel.entranceDuration - 1.8));
    expect(sentinel.entranceProgress, 1);
    expect(sentinel.telegraph + sentinel.divePrep, greaterThan(0));
    expect(sentinel.y + 32, lessThan(swarm.first.homeY - 28));
    expect(
      m.shots.where((s) => s.hostile && s.y < 90),
      isEmpty,
      reason: 'sentinel volleys follow the visible warning',
    );
    // The tell (and its sampled target) follows the divePrep beat.
    for (var i = 0; i < 60 && sentinel.telegraph <= 0; i++) {
      m.update(1 / 60);
    }
    final target = sentinel.targetX;
    m.moveTo(330);
    advance(m, 1);
    expect(sentinel.targetX, target);
    expect(sentinel.dive, greaterThan(0));
    final y = sentinel.y;
    advance(m, .1);
    expect(sentinel.y - y, greaterThan(28));
    final hp = sentinel.hp;
    sentinel.y = ArcadeModel.height + 19;
    m.update(1 / 60);
    expect(sentinel.dive, 0);
    expect(sentinel.y, sentinel.homeY);
    expect(sentinel.hp, hp);
    expect(sentinel.homeY, 44);
  });

  test('every mode reserves a separate upper lane on rare later waves', () {
    for (final difficulty in Difficulty.values) {
      var eligible = 0;
      var total = 0;
      for (var route = 1; route < 5; route++) {
        for (var sector = 1; sector <= 4; sector++) {
          final waves = 3 + (sector - 1) ~/ 2 + route.clamp(0, 3);
          for (var wave = 1; wave <= waves; wave++) {
            final m = ArcadeModel()
              ..restoreCheckpoint({
                'difficulty': difficulty.name,
                'routeIndex': route,
                'sector': sector,
                'wave': wave,
              });
            total++;
            final large = m.demons.where((d) => d.isLarge).toList();
            if (large.isEmpty) continue;
            eligible++;
            expect(large, hasLength(1));
            expect(wave, greaterThanOrEqualTo(3));
            expect(large.single.homeY, 44);
            expect(
              m.demons.where((d) => !d.isLarge).every((d) => d.homeY >= 124),
              isTrue,
            );
          }
        }
      }
      expect(eligible, greaterThan(0));
      expect(eligible, lessThan(total / 2));
    }
  });

  test(
    'heart assembly preserves real slots, pauses, and resets on restart',
    () {
      final m = ArcadeModel()..start();
      m.mode = RunMode.playing;
      m.collectHeart(HeartPart.topLeft);
      m.collectHeart(HeartPart.bottomLeft);
      m.collectHeart(HeartPart.bottomRight);
      m.collectHeart(HeartPart.topRight);
      expect(m.lastCompletedHeartSlot, 0);
      expect(m.heartAssemblyLeft, .85);
      expect(m.heartSlots, [0, 0, 0]);
      expect(m.lives, 4);
      m.collectHeart(HeartPart.bottomRight);
      expect(m.heartSlots, [2, 0, 0]);
      advance(m, .2);
      final remaining = m.heartAssemblyLeft;
      expect(remaining, lessThan(.85));
      m.pause();
      advance(m, 1);
      expect(m.heartAssemblyLeft, remaining);
      m.resume();
      advance(m, 1);
      expect(m.heartAssemblyLeft, 0);
      m.restoreCheckpoint(m.checkpoint());
      expect(m.lastCompletedHeartSlot, isNull);
      expect(m.heartAssemblyLeft, 0);
      m.start();
      expect(m.heartSlots, [0, 0, 0]);
    },
  );

  // demon-intelligence (design §6) replaced the 0.9 s tell and the
  // straight 600 u/s line with the rally-lock-rush sentinel rush; these
  // fixtures follow it (test/sentinel_rush_test.dart covers the rest).
  test('rush eligibility is one seeded birth draw, limited to sentinels', () {
    final counts = <int>[];
    for (final difficulty in Difficulty.values) {
      var eligible = 0;
      for (var seed = 0; seed < 200; seed++) {
        final snapshot = {
          'difficulty': difficulty.name,
          'routeIndex': 1,
          'sector': 2,
          'wave': 4,
        };
        final m = ArcadeModel(seed: seed)..restoreCheckpoint(snapshot);
        final repeat = ArcadeModel(seed: seed)..restoreCheckpoint(snapshot);
        final d = m.demons.singleWhere((d) => d.isLarge);
        expect(d.rushRoll, repeat.demons.singleWhere((d) => d.isLarge).rushRoll);
        if (m.rushEligible(d)) eligible++;
        expect(
          m.demons.where((d) => !d.isLarge).any(m.rushEligible),
          isFalse,
        );
      }
      counts.add(eligible);
    }
    // 0.20 / 0.35 / 0.45 (+ skill 0.3 x 0.10) of 200.
    expect(counts[0], inInclusiveRange(30, 75));
    expect(counts[1], inInclusiveRange(55, 105));
    expect(counts[2], inInclusiveRange(75, 125));
    expect(counts[0], lessThan(counts[1]));
    expect(counts[1], lessThan(counts[2]));
  });

  test('the rush rallies, locks its aim once, then charges at the forecast', () {
    final m = ArcadeModel()..start();
    m.mode = RunMode.playing;
    m.invulnerable = 0;
    m.demons.clear();
    final d = Demon(
      90,
      90,
      2,
      16,
      0,
      archetype: EnemyArchetype.armoredSentinel,
      lastStandEligible: true,
    );
    m.demons.addAll([d, Demon(20, 70, 0, 1000, 0)]);
    d.hp = 6;
    d.entranceProgress = 0;
    m.hitDemon(d);
    expect(d.hp, 6);
    expect(d.lastStand, isFalse);
    d.entranceProgress = 1;
    m.hitDemon(d);
    expect(d.lastStand, isFalse);
    m.hitDemon(d);
    expect(d.hp, 4);
    expect(d.lastStand, isTrue);
    expect(d.rushPhase, RushPhase.rally);
    expect(d.rushShield, 4, reason: 'Normal route 0: 4 + 0');
    expect(d.rushing, isFalse);
    m.hitDemon(d);
    expect(d.hp, 4, reason: 'the rush shield holds the hull');
    expect(d.rushShield, 3);
    advance(m, .3);
    expect(d.y, lessThan(90));
    expect(d.x, 90);
    expect(
      d.lastStandTellProgress,
      closeTo(.3 / RushTuning.tell(Difficulty.normal), .02),
    );
    final clock = d.rushClock;
    m.pause();
    advance(m, 1);
    expect(d.rushClock, clock);
    m.resume();
    advance(m, RushTuning.rally - .3 + .05);
    expect(d.rushPhase, RushPhase.lock);
    final aim = d.targetX;
    advance(m, .3);
    expect(d.targetX, aim, reason: 'the aim is sampled once, at the lock');
    advance(m, RushTuning.lock(Difficulty.normal) - .3);
    expect(d.rushing, isTrue);
    advance(m, .25);
    final speed = math.sqrt(d.rushVx * d.rushVx + d.rushVy * d.rushVy);
    expect(speed, closeTo(780, 1), reason: 'Normal top speed');
    final x = d.x, y = d.y;
    m.pause();
    advance(m, .5);
    expect((d.x, d.y), (x, y));
    m.resume();
    // Two passes on Normal, then the sacrifice: no reward either time.
    m.moveTo(330);
    for (var i = 0; i < 300 && m.demons.contains(d); i++) {
      m.update(1 / 60);
      m.shots.removeWhere((s) => !s.hostile); // nothing shoots it down
    }
    expect(m.demons, isNot(contains(d)));
    expect(m.kills, 0);
    expect(m.score, 0);
    expect(m.pickups, isEmpty);
    expect(m.heartPickups, isEmpty);
    expect(m.blasts.where((b) => b.isLarge), hasLength(1));
    m.hitDemon(d);
    expect(m.kills, 0);
  });

  test('Easy slows the rush tell by ten percent and never homes', () {
    for (final difficulty in Difficulty.values) {
      final m = ArcadeModel()..start(difficulty: difficulty);
      m.mode = RunMode.playing;
      m.demons.clear();
      final d = Demon(
        90,
        90,
        2,
        8,
        0,
        archetype: EnemyArchetype.shieldSentinel,
        lastStandEligible: true,
      )..hp = 3;
      m.demons.addAll([d, Demon(20, 70, 0, 1000, 0)]);
      m.hitDemon(d);
      expect(d.lastStand, isTrue);
      final rate = m.policy.hostileRate;
      final tell = RushTuning.tell(difficulty) / rate;
      expect(tell, greaterThanOrEqualTo(1 - 1e-9), reason: 'at least 1 s');
      advance(m, tell - 2 / 60);
      expect(d.rushing, isFalse, reason: '$difficulty');
      advance(m, 3 / 60);
      expect(d.rushing, isTrue);
      final heading = d.rushHeading;
      m.moveTo(difficulty == Difficulty.easy ? 18 : 342);
      advance(m, .3);
      if (difficulty == Difficulty.easy) {
        expect(d.rushHeading, heading, reason: 'Easy: no homing');
      }
      final speed = math.sqrt(d.rushVx * d.rushVx + d.rushVy * d.rushVy);
      expect(speed, closeTo(m.policy.rushSpeed * rate, 1));
    }
  });

  test('rush impact respects lives, invulnerability and shield without rewards', () {
    for (final protection in ['none', 'invulnerable', 'shield', 'lastLife']) {
      final m = ArcadeModel()..start();
      m.mode = RunMode.playing;
      m.invulnerable = protection == 'invulnerable' ? 10 : 0;
      m.lives = protection == 'lastLife' ? 1 : 3;
      m.kills = 7;
      if (protection == 'shield') m.collect(Power.shield);
      m.demons.clear();
      final d =
          Demon(
              m.shipX,
              ArcadeModel.shipY,
              2,
              8,
              0,
              archetype: EnemyArchetype.shieldSentinel,
              lastStandEligible: true,
            )
            ..lastStand = true
            ..rushPhase = RushPhase.rush
            ..rushPass = 1
            ..rushing = true;
      m.demons.addAll([d, Demon(20, 70, 0, 1000, 0)]);
      m.update(1 / 60);
      final lifeLost = protection == 'none' || protection == 'lastLife';
      // A lost life ends the rush (the sacrifice); a shield or protection
      // ends only this pass's contact.
      expect(m.demons.contains(d), !lifeLost);
      if (!lifeLost) expect(d.rushContact, isTrue);
      expect(
        m.lives,
        protection == 'lastLife'
            ? 0
            : protection == 'none'
            ? 2
            : 3,
      );
      expect(m.hasPower(Power.shield), isFalse);
      if (protection == 'lastLife') expect(m.mode, RunMode.gameOver);
      expect(m.kills, 7);
      expect(m.score, 0);
      expect(m.pickups, isEmpty);
      expect(m.heartPickups, isEmpty);
      expect(m.blasts.where((b) => b.isLarge), hasLength(lifeLost ? 1 : 0));
      if (lifeLost) {
        m.hitDemon(d);
        expect(m.kills, 7);
      }
    }
  });

  test('base-gun hits break the rush shield, then one more kills normally', () {
    for (final rushing in [false, true]) {
      final m = ArcadeModel()..start(difficulty: Difficulty.hard);
      m.mode = RunMode.playing;
      m.kills = 7;
      final d = Demon(
        90,
        90,
        2,
        8,
        0,
        archetype: EnemyArchetype.shieldSentinel,
        lastStandEligible: true,
      )..hp = 3;
      m.demons.clear();
      m.demons.addAll([d, Demon(20, 70, 0, 1000, 0)]);
      m.hitDemon(d);
      expect(d.lastStand, isTrue);
      expect(d.hp, 2);
      if (rushing) d.rushPhase = RushPhase.rush;
      final shield = d.rushShield;
      expect(shield, 5, reason: 'Hard route 0: 5 + 0');
      for (var i = 0; i < shield; i++) {
        m.hitDemon(d);
      }
      expect(d.rushShield, 0);
      expect(d.hp, 2);
      // The bonus and the stagger only when it breaks mid-rush.
      expect(m.score, rushing ? 400 : 0);
      expect(d.rushStagger, rushing ? RushTuning.stagger : 0);
      m.hitDemon(d);
      m.shots.add(Shot(d.x, d.y, 0, 0));
      m.update(1 / 60);
      expect(m.demons, isNot(contains(d)));
      expect(m.kills, 8);
      expect(m.score, (rushing ? 400 : 0) + 600);
      expect(m.pickups, hasLength(1));
      expect(m.blasts.where((b) => b.isLarge), hasLength(1));
    }
  });

  test(
    'ineligible low-health sentinels keep their ordinary reusable dives',
    () {
      final m = ArcadeModel()..start();
      m.mode = RunMode.playing;
      final d = Demon(90, 44, 2, 8, 0, archetype: EnemyArchetype.shieldSentinel)
        ..hp = 2;
      m.demons.add(d);
      m.hitDemon(d);
      expect(d.lastStand, isFalse);
      expect(d.divePrep, ArcadeModel.divePrepBeat);
      d.divePrep = 0;
      d.telegraph = 0;
      d.dive = .1;
      d.y = ArcadeModel.height + 19;
      m.update(1 / 60);
      expect(m.demons, contains(d));
      expect(d.dive, 0);
      expect(d.y, 44);
      expect(d.hp, 1);
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
        {'sector': 5, 'wave': 3}, // route 1: loom 1, carrier 2
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
      // boss-grandeur: tour 2's carrier is wave 3, after two loom waves.
      expect(
        m.restoreCheckpoint({'cycle': 1, 'level': 5, 'wave': 3}),
        isTrue,
      );
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
        'wave': ArcadeModel.wavesFor(sector: 5, route: 3),
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
