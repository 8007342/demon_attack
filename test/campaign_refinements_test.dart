import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void advance(ArcadeModel m, double seconds) {
  for (var frame = 0; frame < (seconds * 60).ceil(); frame++) {
    m.update(1 / 60);
  }
}

ArcadeModel arena() => ArcadeModel()
  ..start()
  ..mode = RunMode.playing
  ..invulnerable = 1000
  ..demons.clear();

void main() {
  test('a shield hit grants pickup grace while expiration alone does not', () {
    final m = arena()..invulnerable = 0;
    m.demons.add(Demon(20, 70, 0, 100, 0));
    m.collect(Power.shield);
    m.powerTimers[Power.shield] = .1;
    m.shots.add(Shot(m.shipX, ArcadeModel.shipY, 0, 0, hostile: true));
    m.update(1 / 60);
    expect(m.lives, 3);
    expect(m.hasPower(Power.shield), isFalse);
    expect(m.invulnerable, 1);
    m.pickups.addAll([
      Pickup(m.shipX, ArcadeModel.shipY - 2, Power.shield),
      Pickup(m.shipX, ArcadeModel.shipY - 2, Power.powerful),
    ]);
    m.shots.addAll(
      List.generate(
        3,
        (_) => Shot(m.shipX, ArcadeModel.shipY, 0, 0, hostile: true),
      ),
    );
    m.update(1 / 60);
    expect(m.pickups, isEmpty);
    expect(m.hasPower(Power.shield), isTrue);
    expect(m.hasPower(Power.powerful), isTrue);
    expect(m.lives, 3);
    expect(m.invulnerable, lessThan(1));
    advance(m, .5);
    m.shots.add(Shot(m.shipX, ArcadeModel.shipY, 0, 0, hostile: true));
    m.update(1 / 60);
    expect(m.hasPower(Power.shield), isTrue);
    expect(m.lives, 3);
    advance(m, .5);
    expect(m.invulnerable, 0);
    m.shots.add(Shot(m.shipX, ArcadeModel.shipY, 0, 0, hostile: true));
    m.update(1 / 60);
    expect(m.hasPower(Power.shield), isFalse);
    expect(m.lives, 3);
    expect(m.invulnerable, 1);

    final expired = arena()..invulnerable = 0;
    expired.demons.add(Demon(20, 70, 0, 100, 0));
    expired.collect(Power.shield);
    expired.powerTimers[Power.shield] = .01;
    expired.update(1 / 60);
    expect(expired.hasPower(Power.shield), isFalse);
    expect(expired.invulnerable, 0);
    expired.shots.add(
      Shot(expired.shipX, ArcadeModel.shipY, 0, 0, hostile: true),
    );
    expired.update(1 / 60);
    expect(expired.lives, 2);
  });

  test('quarter hearts migrate legacy top once and validate atomically', () {
    final m = ArcadeModel();
    expect(
      m.restoreCheckpoint({
        'schemaVersion': 900,
        'heartSlots': [1, 3, 4],
      }),
      isTrue,
    );
    expect(m.heartSlots, [1, 3, 12]);
    final saved = m.checkpoint();
    expect(saved['schemaVersion'], 2);
    expect(saved['heartParts'], 4);
    for (var i = 0; i < 3; i++) {
      expect(m.restoreCheckpoint(saved), isTrue);
      expect(m.checkpoint(), saved);
    }
    expect(
      m.restoreCheckpoint({
        'heartParts': 4,
        'heartSlots': [7, 8, 14],
      }),
      isTrue,
    );
    final before = m.checkpoint();
    for (final bad in [
      {
        'heartParts': 4,
        'heartSlots': [15, 0, 0],
      },
      {
        'heartParts': 4,
        'heartSlots': [-1, 0, 0],
      },
      {
        'heartParts': 4,
        'heartSlots': [null, 0, 0],
      },
      {
        'heartParts': 4,
        'heartSlots': [1.0, 0, 0],
      },
      {
        'heartParts': 4,
        'heartSlots': [16, 0, 0],
      },
      {'heartParts': 4.0},
      {'heartParts': 3},
      {
        'heartSlots': [7, 0, 0],
      },
    ]) {
      expect(m.restoreCheckpoint(bad), isFalse, reason: '$bad');
      expect(m.checkpoint(), before);
    }
  });

  test('all four quarters are necessary regardless of pickup order', () {
    for (final first in HeartPart.values) {
      final m = ArcadeModel()..start();
      final order = [first, ...HeartPart.values.where((p) => p != first)];
      for (final part in order.take(3)) {
        m.collectHeart(part);
      }
      expect(m.lives, 3);
      m.collectHeart(order.last);
      expect(m.lives, 4);
      expect(m.heartSlots, [0, 0, 0]);
      expect(m.takeEvents().where((e) => e == 'extraLife'), hasLength(1));
    }
  });

  test(
    'eight-kill pickups cycle all five weapons and survive checkpoint restore',
    () {
      final m = arena();
      for (var kill = 1; kill <= 40; kill++) {
        final d = Demon(20, 70, 0, 1, 0);
        m.demons.add(d);
        m.hitDemon(d);
        expect(m.pickups.length, kill ~/ 8);
      }
      expect(m.pickups.map((p) => p.power), Power.values);
      final saved = m.checkpoint();
      m.restoreCheckpoint(saved);
      m.mode = RunMode.playing;
      for (var i = 0; i < 8; i++) {
        final d = Demon(20, 70, 0, 1, 0);
        m.demons.add(d);
        m.hitDemon(d);
      }
      expect(m.pickups.single.power, Power.spread);
      expect(m.kills, 48);
    },
  );

  test(
    'weapon alternatives replace only their group and keep separate timers',
    () {
      final m = arena();
      m.demons.add(Demon(20, 70, 0, 100, 0));
      m.collect(Power.spread);
      m.collect(Power.rapid);
      m.collect(Power.shield);
      advance(m, .5);
      final shield = m.timeLeft(Power.shield);
      m.collect(Power.powerful);
      expect(m.activePowers.toSet(), {
        Power.spread,
        Power.powerful,
        Power.shield,
      });
      expect(m.timeLeft(Power.powerful), 9);
      expect(m.timeLeft(Power.shield), shield);
      m.collect(Power.large);
      expect(m.activePowers.toSet(), {
        Power.large,
        Power.powerful,
        Power.shield,
      });
      m.collect(Power.powerful);
      expect(m.timeLeft(Power.large), 9);
      m.collect(Power.rapid);
      m.collect(Power.spread);
      expect(m.activePowers.toSet(), {Power.spread, Power.rapid, Power.shield});
      expect(m.timeLeft(Power.shield), shield);
    },
  );

  test(
    'powerful fires damage two at normal cadence and combines with large',
    () {
      final regular = arena(), powerful = arena(), rapid = arena();
      for (final m in [regular, powerful, rapid]) {
        m.demons.add(Demon(20, 70, 0, 100, 0));
      }
      powerful.collect(Power.powerful);
      powerful.collect(Power.large);
      rapid.collect(Power.rapid);
      for (final m in [regular, powerful, rapid]) {
        advance(m, .7);
      }
      final count = regular.shots.where((s) => !s.hostile).length;
      final powerfulShots = powerful.shots.where((s) => !s.hostile);
      expect(powerfulShots, hasLength(count));
      expect(rapid.shots.where((s) => !s.hostile).length, greaterThan(count));
      expect(
        powerfulShots.every(
          (s) =>
              s.damage == 2 && s.kind == ShotKind.large && s.blastRadius == 30,
        ),
        isTrue,
      );
      final spread = arena()
        ..collect(Power.powerful)
        ..collect(Power.spread);
      spread.demons.add(Demon(20, 70, 0, 100, 0));
      spread.update(1 / 60);
      expect(spread.shots.where((s) => !s.hostile), hasLength(3));
      expect(
        spread.shots.every((s) => s.kind == ShotKind.powerful && s.damage == 2),
        isTrue,
      );
    },
  );

  test(
    'real powerful shots consume actual sentinel shields then armor then hull',
    () {
      final m = arena();
      final d = Demon(
        100,
        100,
        2,
        11,
        0,
        archetype: EnemyArchetype.shieldSentinel,
        shieldMax: 4,
        armorMax: 2,
      );
      m.demons.add(d);
      for (var hit = 0; hit < 4; hit++) {
        m.shots.add(Shot(d.x, d.y, 0, 0, kind: ShotKind.powerful, damage: 2));
        m.update(1 / 60);
        expect(d.shield, math.max(0, 4 - (hit + 1) * 2));
        expect(d.hp, hit < 3 ? 11 : 9);
      }
      expect(d.armor, 0);
      expect(m.kills, 0);
    },
  );

  test('large powerful blast hits each nearby demon once and gives one reward per kill', () {
    final m = arena()..kills = 7;
    final first = Demon(100, 200, 0, 2, 0);
    final second = Demon(124, 200, 0, 2, 0);
    final distant = Demon(200, 200, 0, 5, 0);
    m.demons.addAll([first, second, distant]);
    m.shots.add(
      Shot(100, 200, 0, 0, kind: ShotKind.large, damage: 2, blastRadius: 30),
    );
    m.update(1 / 60);
    expect(m.demons, [distant]);
    expect(distant.hp, 5);
    expect(m.kills, 9);
    expect(m.score, 300);
    expect(m.pickups, hasLength(1));
    expect(m.blasts.where((b) => b.blastRadius == 30), hasLength(1));
    m.update(1 / 60);
    expect(m.kills, 9);
    expect(m.pickups, hasLength(1));
  });

  test('large powerful bolts widen only the open carrier aperture', () {
    for (final state in ['shield', 'closed', 'open']) {
      final m = arena();
      final b = Carrier(0);
      m.boss = b;
      if (state != 'shield') b.shield = 0;
      m.levelClock = state == 'closed' ? 0 : .6;
      final shield = b.shield, core = b.core;
      m.shots.add(
        Shot(
          b.forecastX(1 / 60, m.speed) + 25,
          b.y + 15,
          0,
          0,
          kind: ShotKind.large,
          damage: 2,
          blastRadius: 30,
        ),
      );
      m.update(1 / 60);
      expect(b.shield, state == 'shield' ? shield - 2 : 0);
      expect(b.core, state == 'open' ? core - 2 : core);
      expect(m.blasts.where((b) => b.blastRadius == 30), hasLength(1));
    }
    final m = arena();
    final b = Carrier(0)
      ..shield = 1
      ..door = 1;
    m.boss = b;
    m.hitBoss(b.x, damage: 2, blastRadius: 30);
    expect(b.shield, 0);
    expect(b.core, b.coreMax);
    b.core = 1;
    m.hitBoss(b.x, damage: 2, blastRadius: 30);
    final score = m.score;
    expect(m.hitBoss(b.x, damage: 2, blastRadius: 30), isFalse);
    expect(m.score, score);
    expect(m.medals, 1);
  });

  test('finite ordinary reinforcements appear without a sentinel and reset on resume', () {
    for (final difficulty in Difficulty.values) {
      final m = ArcadeModel()
        ..restoreCheckpoint({
          'difficulty': difficulty.name,
          'routeIndex': 4,
          'sector': 1,
          'wave': 1,
        });
      final saved = m.checkpoint();
      final planned = m.flocksPlanned;
      expect(planned, inInclusiveRange(2, 4));
      expect(m.demons.any((d) => d.isLarge), isFalse);
      m.mode = RunMode.playing;
      m.invulnerable = 1000;
      m.takeEvents();
      var arrivals = 0;
      for (var frame = 0; frame < 2400 && m.combat; frame++) {
        expect(m.demons.length, lessThanOrEqualTo(ArcadeModel.maxActiveDemons));
        for (final d in List<Demon>.of(m.demons)) {
          if (!d.entering) m.hitDemon(d, damage: 1000);
        }
        m.update(1 / 60);
        arrivals += m.takeEvents().where((e) => e == 'reinforcements').length;
      }
      expect(m.mode, RunMode.transition);
      expect(m.wave, 2);
      expect(arrivals, planned);
      m.restoreCheckpoint(saved);
      expect(m.flocksSpawned, 0);
      expect(m.flocksPlanned, planned);
      expect(m.wave, 1);
      expect(m.mode, RunMode.transition);
    }
  });

  test('fresh tough escorts settle before the delayed shielded sentinel', () {
    final m = ArcadeModel()
      ..restoreCheckpoint({'routeIndex': 1, 'sector': 2, 'wave': 4});
    final sentinel = m.demons.singleWhere((d) => d.isLarge);
    final initial = m.demons.toSet();
    expect(sentinel.shieldMax, greaterThanOrEqualTo(4));
    expect(sentinel.armorMax, greaterThanOrEqualTo(2));
    expect(
      sentinel.maxHp,
      greaterThan(
        m.demons.where((d) => !d.isLarge).map((d) => d.maxHp).reduce(math.max),
      ),
    );
    m.mode = RunMode.playing;
    m.invulnerable = 1000;
    advance(m, 3.3);
    final escorts = m.demons.where((d) => !initial.contains(d)).toList();
    expect(escorts, hasLength(6));
    expect(escorts.every((d) => d.elite && d.entering), isTrue);
    expect(sentinel.entranceProgress, 0);
    advance(m, .8);
    expect(escorts.every((d) => !d.entering), isTrue);
    expect(sentinel.entranceProgress, 0);
    advance(m, 2.2);
    expect(sentinel.entering, isFalse);
    expect(sentinel.y, lessThan(50));
    expect(m.demons.where((d) => d.isLarge), hasLength(1));
  });

  test(
    'sentinels evade incoming shots smoothly and shoot distinct fast bolts',
    () {
      final m = arena();
      final d =
          Demon(
              180,
              44,
              2,
              11,
              0,
              archetype: EnemyArchetype.shieldSentinel,
              shieldMax: 4,
              armorMax: 2,
            )
            ..attackLeft = 100
            ..volleyLeft = .01;
      m.demons.add(d);
      m.shots.add(Shot(d.x, 200, 0, -390));
      m.update(1 / 60);
      expect(d.evadeLeft, greaterThan(0));
      expect((d.x - 180).abs(), lessThanOrEqualTo(1.5));
      final bolt = m.shots.singleWhere((s) => s.kind == ShotKind.sentinel);
      expect(bolt.hostile, isTrue);
      expect(bolt.vy, greaterThan(200));
      final x = d.x, cooldown = d.evadeCooldown;
      m.pause();
      advance(m, 1);
      expect(d.x, x);
      expect(d.evadeCooldown, cooldown);
      m.resume();
      for (var i = 0; i < 30; i++) {
        final previous = d.x;
        m.update(1 / 60);
        expect((d.x - previous).abs(), lessThanOrEqualTo(1.500001));
        expect(d.y, inInclusiveRange(39, 49));
      }
    },
  );

  test('carrier encounters seed varied directions and damage accelerates bounded motion', () {
    final directions = <int>{}, phases = <double>{};
    for (var seed = 0; seed < 20; seed++) {
      final a = ArcadeModel(seed: seed)..restoreCheckpoint({'sector': 5});
      final b = ArcadeModel(seed: seed)..restoreCheckpoint({'sector': 5});
      expect(a.boss!.startingDirection, b.boss!.startingDirection);
      expect(a.boss!.startingPhase, b.boss!.startingPhase);
      directions.add(a.boss!.startingDirection);
      phases.add(a.boss!.startingPhase);
    }
    expect(directions, {-1, 1});
    expect(phases.length, greaterThan(10));
    final m = ArcadeModel()..restoreCheckpoint({'sector': 5});
    m.mode = RunMode.playing;
    m.invulnerable = 1000;
    final b = m.boss!;
    expect(b.rage, 0);
    expect(b.movementRate, 1);
    b.shield = 0;
    b.core = 5;
    expect(b.rage, greaterThan(.9));
    expect(b.movementRate, greaterThan(1.8));
    final motion = b.motionPhase;
    advance(m, 1 / 60);
    expect(
      (b.motionPhase - motion).abs(),
      closeTo(.7 * m.speed * b.movementRate / 60, .0001),
    );
    for (var i = 0; i < 180; i++) {
      m.update(1 / 60);
      expect(b.x, inInclusiveRange(82, 278));
      expect(b.y, inInclusiveRange(187, 223));
    }
    final paused = b.motionPhase;
    m.pause();
    advance(m, 1);
    expect(b.motionPhase, paused);
    expect(m.flocksPlanned, 0);
    expect(m.flocksSpawned, 0);
  });
}
