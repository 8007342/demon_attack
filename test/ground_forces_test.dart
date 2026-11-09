import 'package:demon_attack/game/flyover_background.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A quiet arena: one parked placeholder keeps the wave open, nothing
/// spawns on its own, and nothing hostile flies.
ArcadeModel arena({int level = 2, Difficulty difficulty = Difficulty.normal}) {
  final m = ArcadeModel(seed: 3)..start(difficulty: difficulty);
  m.level = level;
  m.mode = RunMode.playing;
  m.demons
    ..clear()
    ..add(
      Demon(180, 60, 0, 1, 0)
        ..entranceProgress = 0
        ..waitingForEscort = true,
    );
  m.shots.clear();
  m.flocksPlanned = m.flocksSpawned;
  m.ground.clearField();
  // A quiet front that never schedules arrivals but allows breakthroughs,
  // so each test stages exactly the units it needs.
  m.ground.front = const GroundFront(
    presence: 0,
    interval: 0,
    firstDelay: 0,
    demonHp: 99,
    breakthroughs: true,
    baseStrength: 1,
    basePressure: 0,
    shots: 2,
  );
  m.invulnerable = 0;
  return m;
}

/// A real run, flown by a simple pilot that kills air demons at [killEvery]
/// seconds (fast or slow players) while protected; returns per-sector stats.
ArcadeModel campaign(
  Difficulty d, {
  double killEvery = .5,
  int untilLevel = 5,
  int route = 0,
}) {
  final m = ArcadeModel(seed: 1982)..start(difficulty: d);
  var next = 0.0;
  for (var f = 0; f < 60 * 60 * 30; f++) {
    if (m.level >= untilLevel && m.cycle >= route) break;
    if (m.combat) {
      m.invulnerable = 2;
      if (m.levelClock >= next) {
        next = m.levelClock + killEvery;
        final target = m.demons.where((x) => !x.entering).firstOrNull;
        if (target != null) m.hitDemon(target, damage: 99);
      }
    } else {
      next = 0;
    }
    m.update(1 / 60);
  }
  return m;
}

GroundUnit unit(
  ArcadeModel m,
  double z, {
  int side = 0,
  int shots = 2,
  int hp = 99,
}) {
  final u = GroundUnit(m.ground.nextId++, m.level - 1, side, .5, z,
      shotsLeft: shots, hp: hp);
  m.ground.units.add(u);
  return u;
}

void run(ArcadeModel m, double seconds, {void Function()? each}) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    each?.call();
    m.update(1 / 60);
  }
}

List<String> gameEvents(ArcadeModel m) =>
    m.takeGameEvents().map((e) => e.name).toList();

void main() {
  test('the camera is the flyover camera', () {
    expect(GroundCamera.horizon, FlyoverBackground.horizon);
    expect(GroundCamera.laneLeft, FlyoverBackground.laneLeft);
    expect(GroundCamera.laneRight, FlyoverBackground.laneRight);
    expect(GroundCamera.yOf(GroundCamera.z0), closeTo(520, 1e-9));
    // Small near the horizon, growing toward the ship.
    expect(GroundCamera.texel(GroundTuning.spawnZ),
        lessThan(GroundCamera.texel(GroundTuning.fireZ) / 3));
    expect(GroundCamera.yOf(GroundTuning.spawnZ), lessThan(220));
    expect(GroundCamera.yOf(GroundTuning.fireZ), greaterThan(300));
  });

  test('ground units stay in the side bands, out of the firing lane', () {
    for (final z in [GroundTuning.spawnZ, 800.0, GroundTuning.fireZ, GroundTuning.lastFireZ]) {
      for (final side in [0, 1]) {
        for (final across in [0.0, .5, 1.0]) {
          final u = GroundUnit(0, 0, side, across, z);
          final left = u.x - u.width / 2, right = u.x + u.width / 2;
          expect(right <= GroundCamera.laneLeft || left >= GroundCamera.laneRight, isTrue,
              reason: 'z=$z side=$side across=$across [$left, $right]');
        }
      }
    }
  });

  group('the ground front', () {
    test('ground activity starts early in Krybor on every difficulty', () {
      for (final d in Difficulty.values) {
        final f = GroundFront.of(d, route: 0, sector: 1);
        expect(f.active, isTrue, reason: '$d');
        expect(f.firstDelay, inInclusiveRange(4, 8));
        expect(f.breakthroughs, isFalse);
        expect(GroundFront.of(d, route: 0, sector: 2).breakthroughs, isFalse);
        expect(GroundFront.of(d, route: 0, sector: 3).breakthroughs, isTrue);
        expect(GroundFront.of(d, route: 4, sector: 5).active, isFalse);
      }
      final m = ArcadeModel(seed: 1982)..start(difficulty: Difficulty.easy);
      var firstAt = -1.0;
      for (var f = 0; f < 60 * 120 && firstAt < 0; f++) {
        if (m.combat) m.invulnerable = 2;
        m.update(1 / 60);
        if (m.ground.unitsSpawned > 0) firstAt = m.levelClock;
      }
      expect(firstAt, inInclusiveRange(4, 8));
      expect(m.level, 1);
    });

    test('later sectors are tougher and less escorted, ordered by difficulty', () {
      for (var route = 0; route < 5; route++) {
        for (final sector in [3, 4]) {
          final e = GroundFront.of(Difficulty.easy, route: route, sector: sector),
              n = GroundFront.of(Difficulty.normal, route: route, sector: sector),
              h = GroundFront.of(Difficulty.hard, route: route, sector: sector);
          expect(e.demonHp, lessThan(n.demonHp));
          expect(n.demonHp, lessThanOrEqualTo(h.demonHp));
          expect(e.baseStrength, greaterThan(n.baseStrength));
          expect(n.baseStrength, greaterThan(h.baseStrength));
          expect(e.presence, lessThanOrEqualTo(h.presence));
          expect(e.baseStrength, greaterThan(h.baseStrength));
        }
        final three = GroundFront.of(Difficulty.normal, route: route, sector: 3),
            four = GroundFront.of(Difficulty.normal, route: route, sector: 4);
        expect(four.demonHp, greaterThan(three.demonHp));
        expect(four.baseStrength, lessThan(three.baseStrength));
      }
    });

    for (final d in Difficulty.values) {
      test('${d.name}: allies win every skirmish in sectors 1-2; nothing reaches fire range', () {
        final m = campaign(d, untilLevel: 3, killEvery: 1);
        final g = m.ground;
        expect(g.unitsSpawned, greaterThanOrEqualTo(3), reason: 'the ground is alive');
        // Only allies (and the odd ordinary homing pickup) destroy them.
        expect(g.unitsKilledByAllies, greaterThanOrEqualTo(g.unitsDestroyed - g.homingHits));
        // Every finished skirmish was won (up to two are still under way).
        expect(g.unitsKilledByAllies + g.homingHits,
            greaterThanOrEqualTo(g.unitsSpawned - 2),
            reason: 'allies won ${g.unitsKilledByAllies} of ${g.unitsSpawned}');
        expect(g.unitsKilledByAllies, greaterThanOrEqualTo(2));
        expect(g.breakthroughsBySector[0] + g.breakthroughsBySector[1], 0);
        expect(g.missilesLaunched, 0);
        expect(g.alliesRetreated, 0);
        final names = m.takeGameEvents().map((e) => e.name).toSet();
        expect(names, contains(GameEventNames.groundForceSighted));
        expect(names, contains(GameEventNames.groundUnitDestroyed));
        expect(names, isNot(contains(GameEventNames.groundBreakthrough)));
        expect(names, isNot(contains(GameEventNames.allyUnderAttack)));
      });
    }

    test('the schedule runs on combat time, not air-wave speed', () {
      List<double> arrivals(double killEvery) {
        final m = ArcadeModel(seed: 1982)..start();
        final at = <double>[];
        var next = 0.0, seen = 0;
        for (var f = 0; f < 60 * 400 && m.level == 1; f++) {
          if (m.combat) {
            m.invulnerable = 2;
            if (m.levelClock >= next) {
              next = m.levelClock + killEvery;
              final t = m.demons.where((x) => !x.entering).firstOrNull;
              if (t != null) m.hitDemon(t, damage: 99);
            }
          }
          m.update(1 / 60);
          if (m.ground.unitsSpawned > seen) {
            seen = m.ground.unitsSpawned;
            at.add(m.levelClock);
          }
        }
        return at;
      }

      final fast = arrivals(.5), slow = arrivals(1.6);
      expect(fast.length, greaterThanOrEqualTo(2), reason: 'a fast player still sees activity');
      expect(slow.length, greaterThan(fast.length), reason: 'more combat time, more of the war');
      // Same arrival times for the stretch both players fought.
      final n = fast.length;
      for (var i = 0; i < n; i++) {
        expect(slow[i], closeTo(fast[i], 1.0), reason: 'arrival $i');
      }
      // A slow player is never swamped: arrivals stay paced by time.
      for (var i = 1; i < slow.length; i++) {
        expect(slow[i] - slow[i - 1], greaterThan(4));
      }
    });

    test('later sectors: unchecked pressure breaks through, with a call for help first', () {
      final m = arena(level: 4);
      m.ground.front = GroundFront.of(Difficulty.normal, route: 0, sector: 4);
      m.ground.alliedStrength = m.ground.front.baseStrength;
      m.invulnerable = 100;
      final u = unit(m, GroundTuning.spawnZ, hp: 7);
      run(m, 12);
      expect(u.brokeThrough, isTrue);
      final names = gameEvents(m);
      final call = names.indexOf(GameEventNames.allyUnderAttack);
      final breakthrough = names.indexOf(GameEventNames.groundBreakthrough);
      expect(call, isNonNegative);
      expect(breakthrough, greaterThan(call));
      expect(names, contains(GameEventNames.groundForceInRange));
      expect(m.ground.missilesLaunched, greaterThan(0));
    });

    test('a well-escorted unit is stopped by its ally; strong allies push ahead', () {
      final m = arena(level: 3);
      m.ground.front = GroundFront.of(Difficulty.normal, route: 0, sector: 3);
      m.ground.alliedStrength = 1;
      final u = unit(m, GroundTuning.spawnZ, hp: 4);
      final a = GroundAlly(m.ground.nextId++, u.sector, u.side, .2,
          u.z - GroundTuning.allyLead, GroundTuning.allyHp)
        ..attacker = u;
      u.ally = a;
      m.ground.allies.add(a);
      run(m, 12);
      expect(u.destroyedByAllies, isTrue);
      expect(u.brokeThrough, isFalse);
      expect(m.ground.alliedStrength, greaterThan(.95));
    });

    test('the pressure meter rises with unchecked units and reports itself', () {
      final m = arena(level: 4);
      m.ground.front = GroundFront.of(Difficulty.normal, route: 0, sector: 4);
      m.ground.pressure = m.ground.front.basePressure;
      m.invulnerable = 100;
      for (var i = 0; i < 3; i++) {
        unit(m, 700 + i * 200, side: i % 2);
      }
      final before = m.ground.pressure;
      run(m, 6);
      expect(m.ground.pressure, greaterThan(before));
      expect(m.ground.pressure, inInclusiveRange(0, 1));
      final levels = m
          .takeGameEvents()
          .where((e) => e.name == GameEventNames.groundPressure)
          .map((e) => e.data['level'] as double)
          .toList();
      expect(levels, isNotEmpty);
      expect(levels.every((v) => v >= 0 && v <= 1), isTrue);
    });
  });

  group('fire range gate', () {
    test('units approach without firing, then telegraph only on the near ground', () {
      final m = arena();
      m.invulnerable = 100;
      final u = unit(m, GroundTuning.spawnZ);
      var telegraphedAtZ = 0.0;
      run(m, 20, each: () {
        if (u.telegraphing && telegraphedAtZ == 0) telegraphedAtZ = u.z;
      });
      expect(telegraphedAtZ, lessThanOrEqualTo(GroundTuning.fireZ));
      expect(telegraphedAtZ, greaterThanOrEqualTo(GroundTuning.lastFireZ));
      expect(m.ground.missilesLaunched, greaterThan(0));
    });

    test('a far unit never telegraphs; the launch follows the full tell', () {
      final m = arena();
      m.invulnerable = 100;
      final far = unit(m, 5000); // never reaches range in this test
      run(m, 3);
      expect(far.telegraphing, isFalse);
      expect(m.ground.missilesLaunched, 0);
      final near = unit(m, GroundTuning.fireZ - 1)..cooldown = 0;
      m.update(1 / 60);
      expect(near.telegraphing, isTrue);
      run(m, GroundTuning.telegraph * .9);
      expect(m.ground.missiles, isEmpty, reason: 'still telegraphing');
      run(m, GroundTuning.telegraph * .2);
      expect(m.ground.missiles, hasLength(1));
      expect(gameEvents(m), contains(GameEventNames.groundMissileLaunch));
    });

    test('never fires from beside the ship, and respects its shot budget', () {
      final m = arena();
      m.invulnerable = 100;
      final low = unit(m, GroundTuning.lastFireZ - 1)..cooldown = 0;
      run(m, 2);
      expect(low.telegraphing, isFalse);
      expect(m.ground.missilesLaunched, 0);
      m.ground.units.clear();
      unit(m, GroundTuning.fireZ, shots: 1).cooldown = 0;
      run(m, 8);
      expect(m.ground.missilesLaunched, 1);
    });
  });

  group('ground missiles', () {
    test('fixed path to the x sampled at launch; no tracking', () {
      final m = arena();
      m.invulnerable = 100;
      m.shipX = m.targetX = 120;
      unit(m, GroundTuning.fireZ - 1).cooldown = 0;
      run(m, GroundTuning.telegraph + .05);
      final missile = m.ground.missiles.single;
      expect(missile.targetX, 120);
      m.moveTo(300);
      run(m, .5);
      expect(missile.targetX, 120);
      expect(missile.xAt(1), closeTo(120, 1e-9));
      expect(missile.yAt(1), closeTo(ArcadeModel.shipY, 1e-9));
    });

    test('grows toward the ship and is harmless before the ship plane', () {
      final missile = GroundMissile(60, 330, 180, 1.7, 0);
      var last = 0.0;
      for (var t = 0.0; t <= 1; t += .1) {
        missile.age = t * 1.7;
        expect(missile.size, greaterThanOrEqualTo(last));
        last = missile.size;
        if (t < GroundTuning.missilePlaneT - 1e-9) {
          // Even if the ship sat right on the missile it could not collide.
          expect(missile.hits(missile.x), isFalse, reason: 't=$t');
        }
      }
      expect(last, closeTo(GroundTuning.missileMaxSize, 1e-6));
      missile.age = 1.7;
      expect(missile.hits(180), isTrue);
    });

    test('the hitbox matches the drawn warhead at the plane', () {
      final missile = GroundMissile(60, 330, 180, 1.7, 0)..age = 1.7;
      final reach = GroundTuning.shipHalfWidth + missile.hitRadius;
      expect(missile.hitRadius, closeTo(missile.size * GroundTuning.missileHitRatio, 1e-9));
      expect(missile.hitRadius, lessThan(missile.size / 2));
      expect(missile.hits(180 + reach - .5), isTrue);
      expect(missile.hits(180 + reach + .5), isFalse);
      expect(missile.hits(180 - reach - .5), isFalse);
    });

    test('a hit costs a life like a hostile shot, unless the shield absorbs it', () {
      final m = arena();
      final lives = m.lives;
      m.ground.missiles.add(GroundMissile(60, 330, m.shipX, 1.7, 1)..age = 1.6);
      run(m, .2);
      expect(m.lives, lives - 1);
      expect(m.ground.missileImpacts, 1);

      final s = arena()..collect(Power.shield);
      final shieldLives = s.lives;
      s.ground.missiles.add(GroundMissile(60, 330, s.shipX, 1.7, 1)..age = 1.6);
      run(s, .2);
      expect(s.lives, shieldLives);
      expect(s.hasPower(Power.shield), isFalse);
    });

    test('a sidestep of one hitbox makes it miss', () {
      final m = arena();
      final lives = m.lives;
      m.ground.missiles.add(GroundMissile(60, 330, 180, 1.7, 1));
      m.shipX = m.targetX = 180 + 40;
      run(m, 2.5);
      expect(m.lives, lives);
      expect(m.ground.missileImpacts, 0);
    });

    test('player shots fly over ground units', () {
      final m = arena();
      final u = unit(m, GroundTuning.fireZ + 100);
      m.shots.add(Shot(u.x, u.bodyY + 6, 0, -390, damage: 2));
      run(m, .3);
      expect(u.alive, isTrue);
    });
  });

  group('homing missiles', () {
    test('targets ground first, the unit closest to firing', () {
      final m = arena();
      m.demons.add(Demon(180, 200, 3, 3, 0)); // a gold demon in the air
      final far = unit(m, 1200);
      final near = unit(m, 600);
      expect(m.pickHomingTarget()!.$1, near);
      final ready = unit(m, 1000)..telegraph = .5;
      expect(m.pickHomingTarget()!.$1, ready);
      expect(far.alive && near.alive, isTrue);
      m.ground.units.clear();
      expect(m.pickHomingTarget()!.$2, HomingTargetKind.demon);
    });

    test('air order: open carrier core > sentinel > elite > gold > coral > violet > teal', () {
      final m = arena();
      final teal = Demon(40, 150, 0, 1, 0);
      final violet = Demon(80, 150, 1, 1, 0);
      final coral = Demon(120, 150, 2, 2, 0);
      final gold = Demon(160, 150, 3, 2, 0);
      final elite = Demon(200, 150, 0, 2, 0, elite: true);
      final sentinel = Demon(240, 100, 0, 9, 0,
          archetype: EnemyArchetype.shieldSentinel, shieldMax: 3);
      final order = [sentinel, elite, gold, coral, violet, teal];
      m.demons.addAll(order.reversed);
      for (final expected in order) {
        expect(m.pickHomingTarget()!.$1, expected);
        m.demons.remove(expected);
      }
      final b = Carrier(0)..shield = 0..door = 1;
      m.boss = b;
      m.demons.add(sentinel);
      expect(m.pickHomingTarget(), (b, HomingTargetKind.carrierCore));
      b.door = 0;
      expect(m.pickHomingTarget()!.$1, sentinel, reason: 'closed core ranks last');
      m.demons.remove(sentinel);
      b.shield = 5;
      expect(m.pickHomingTarget(), (b, HomingTargetKind.carrierShield));
    });

    test('three missiles in sequence, each after the previous one hits', () {
      final m = arena();
      for (var i = 0; i < 3; i++) {
        unit(m, 700 + i * 150, side: i % 2);
      }
      m.collectHoming();
      expect(gameEvents(m), contains(GameEventNames.homingPickup));
      var maxActive = 0, launches = 0;
      HomingMissile? previous;
      run(m, 6, each: () {
        final h = m.ground.homing;
        if (h != null && !identical(h, previous)) {
          launches++;
          // A new missile only once the previous one has struck.
          expect(m.ground.homingHits, launches - 1);
          previous = h;
        }
        maxActive = maxActive < (h == null ? 0 : 1) ? 1 : maxActive;
      });
      expect(launches, 3);
      expect(m.ground.homingHits, 3);
      expect(m.ground.liveUnits, isEmpty);
      expect(m.ground.salvo.busy, isFalse);
      final names = gameEvents(m);
      expect(names.where((n) => n == GameEventNames.homingLaunch), hasLength(3));
      expect(names.where((n) => n == GameEventNames.groundUnitDestroyed), hasLength(3));
    });

    test('holds the salvo while nothing is targetable', () {
      final m = arena();
      m.collectHoming();
      run(m, 2);
      expect(m.ground.salvo.remaining, 3);
      expect(m.ground.homing, isNull);
      unit(m, 800);
      run(m, 3);
      expect(m.ground.salvo.remaining, lessThan(3));
    });

    test('damage: one per ground unit, three normal hits against air', () {
      final m = arena();
      final u = unit(m, 600);
      m.ground.salvo.active = HomingMissile(u.x, u.bodyY + 4, 0, -300, -1)
        ..target = u
        ..kind = HomingTargetKind.ground;
      m.update(1 / 60);
      expect(u.alive, isFalse);

      final weak = Demon(100, 150, 2, 3, 0), strong = Demon(200, 150, 3, 4, 0);
      m.demons.addAll([weak, strong]);
      m.hitDemon(weak, damage: GroundTuning.homingAirDamage, homing: true);
      m.hitDemon(strong, damage: GroundTuning.homingAirDamage, homing: true);
      expect(m.demons.contains(weak), isFalse, reason: '3 HP dies');
      expect(strong.hp, 1);

      final sentinel = Demon(180, 100, 0, 11, 0,
          archetype: EnemyArchetype.armoredSentinel, shieldMax: 4, armorMax: 2);
      m.demons.add(sentinel);
      m.hitDemon(sentinel, damage: GroundTuning.homingAirDamage, homing: true);
      expect(sentinel.shield, 1, reason: 'a dent, not a kill');
      expect(sentinel.hp, 11);

      final b = Carrier(0);
      m.boss = b;
      m.ground.salvo.active = HomingMissile(b.x, b.forceFieldSurfaceY(b.x) + 5, 0, -300, 1)
        ..target = b
        ..kind = HomingTargetKind.carrierShield;
      m.update(1 / 60);
      expect(b.shield, b.shieldMax - 3);
      // A full salvo is at most 9 of the carrier's core; through a closed
      // hatch it is only a dent.
      b
        ..shield = 0
        ..door = 0
        ..sideDoorLeft = 0
        ..sideDoorRight = 0;
      final core = b.core;
      m.ground.salvo.active = HomingMissile(b.x, b.y + 22, 0, -300, 1)
        ..target = b
        ..kind = HomingTargetKind.carrierCore;
      m.levelClock = 0; // keep the doors shut this step
      m.update(1 / 60);
      expect(b.core, core);
    });

    test('a homing hit breaks a sentinel dive shield without other modules', () {
      final m = arena();
      final s = Demon(180, 200, 0, 11, 0, archetype: EnemyArchetype.shieldSentinel)
        ..dive = .5
        ..diveShieldMax = 4
        ..diveShield = 4;
      m.demons.add(s);
      m.hitDemon(s, damage: 1);
      expect(s.diveShield, 4, reason: 'unpowered shots deflect');
      m.hitDemon(s, damage: GroundTuning.homingAirDamage, homing: true);
      expect(s.diveShield, 1);
    });

    test('combines with modules and the shield, and survives a life loss', () {
      final m = arena()
        ..collect(Power.powerful)
        ..collect(Power.shield)
        ..collectHoming();
      expect(m.hasPower(Power.powerful) && m.hasPower(Power.shield), isTrue);
      m.hitPlayer();
      m.invulnerable = 0;
      m.hitPlayer();
      expect(m.ground.salvo.remaining, 3);
    });
  });

  group('homing drops', () {
    void kill(ArcadeModel m) {
      final d = Demon(150, 200, 0, 1, 0);
      m.demons.add(d);
      m.hitDemon(d);
    }

    test('without a breakthrough threat they are an ordinary pickup', () {
      final m = arena();
      unit(m, 600).ally = GroundAlly(99, 1, 0, .2, 500, 8); // escorted, safe
      m.ground.front = GroundFront.of(Difficulty.normal, route: 0, sector: 2);
      var drops = <int>[];
      for (var i = 0; i < 80; i++) {
        kill(m);
        if (m.ground.pickups.isNotEmpty) {
          drops.add(m.kills);
          m.ground.pickups.clear();
        }
      }
      expect(drops, [20, 60]);
    });

    test('a looming breakthrough makes them urgent: pity within seconds', () {
      for (final d in Difficulty.values) {
        final m = arena(difficulty: d);
        unit(m, 1300); // unescorted: it will break through
        m.update(1 / 60);
        expect(m.groundBreakthroughThreat, isTrue);
        run(m, GroundTuning.pityTime(d) + .1);
        kill(m);
        expect(m.ground.pickups, hasLength(1), reason: '$d');
      }
    });

    test('without kills, the fleet airdrops one', () {
      final m = arena();
      unit(m, 5000);
      run(m, GroundTuning.pityTime(m.difficulty) + GroundTuning.pityAirdrop + .1);
      expect(m.ground.pickups, hasLength(1));
      final p = m.ground.pickups.single;
      expect(p.x, inInclusiveRange(GroundCamera.laneLeft, GroundCamera.laneRight));
    });

    test('a pickup arrives before a threatening unit reaches fire range', () {
      for (final d in Difficulty.values) {
        final m = arena(difficulty: d);
        final u = unit(m, GroundTuning.spawnZ);
        for (var f = 0; f < 60 * 20 && m.ground.pickups.isEmpty; f++) {
          if (f % 90 == 0) kill(m);
          m.update(1 / 60);
        }
        expect(m.ground.pickups, isNotEmpty, reason: '$d');
        expect(u.brokeThrough, isFalse, reason: '$d: in time to help');
      }
    });

    test('collecting it arms the salvo; no second drop while armed', () {
      final m = arena();
      unit(m, 1300);
      run(m, GroundTuning.pityTime(m.difficulty) + .1);
      kill(m);
      final p = m.ground.pickups.single;
      m.shipX = m.targetX = p.x;
      p.y = ArcadeModel.shipY - 5;
      m.update(1 / 60);
      expect(m.ground.salvo.busy, isTrue);
      expect(m.ground.homingCollected, 1);
      for (var i = 0; i < 40; i++) {
        kill(m);
      }
      expect(m.ground.pickups, isEmpty);
    });

    test('an ordinary power-up over the carrier too', () {
      final m = arena(level: 5);
      var drops = 0;
      for (var i = 0; i < 80; i++) {
        kill(m);
        if (m.ground.pickups.isNotEmpty) {
          drops++;
          m.ground.pickups.clear();
        }
      }
      expect(drops, 2);
    });
  });

  group('allies', () {
    GroundAlly engaged(ArcadeModel m, GroundUnit foe) {
      final a = GroundAlly(m.ground.nextId++, foe.sector, foe.side, .2,
          foe.z - GroundTuning.allyLead, GroundTuning.allyHp)
        ..attacker = foe;
      foe.ally = a;
      m.ground.allies.add(a);
      return a;
    }

    test('never collide with the player or stop shots', () {
      final m = arena();
      final a = engaged(m, unit(m, 600));
      m.shipX = m.targetX = a.x;
      m.shots.add(Shot(a.x, a.bodyY + 4, 0, -390));
      final lives = m.lives;
      run(m, .3);
      expect(m.lives, lives);
      expect(m.shots.where((s) => !s.hostile), isNotEmpty);
    });

    test('overwhelmed allies are totalled and retreat; they never die', () {
      final m = arena();
      final a = engaged(m, unit(m, 1100));
      run(m, 1.5);
      expect(gameEvents(m), contains(GameEventNames.allyUnderAttack));
      run(m, GroundTuning.demonTracerEvery * (GroundTuning.allyHp + 1));
      expect(a.totalled, isTrue);
      expect(gameEvents(m), contains(GameEventNames.allyRetreated));
      expect(GameEventNames.allyLost, GameEventNames.allyRetreated);
      expect(m.ground.alliesRetreated, 1);
      expect(m.ground.fleetIntactRun, isFalse);
      run(m, 4);
      expect(m.ground.allies.contains(a), isFalse, reason: 'it leaves');
    });

    test('killing the attacker saves the ally: bonus only, never a penalty', () {
      final m = arena();
      final foe = unit(m, 1100);
      final a = engaged(m, foe);
      run(m, 1);
      final score = m.score;
      m.ground.salvo.active = HomingMissile(foe.x, foe.bodyY + 4, 0, -300, -1)
        ..target = foe
        ..kind = HomingTargetKind.ground;
      m.update(1 / 60);
      expect(a.saved, isTrue);
      expect(gameEvents(m), contains(GameEventNames.allySaved));
      expect(m.score, greaterThan(score));
      final lives = m.lives;
      run(m, 10);
      expect(a.totalled, isFalse);
      expect(m.lives, lives);
    });

    test('fleetIntact at level clear when no ally retreated', () {
      final m = arena(level: 1);
      final a = engaged(m, unit(m, 1100));
      run(m, 1);
      _destroy(m, a.attacker!);
      m.takeGameEvents();
      final score = m.score;
      m.demons.clear(); // final-wave clear -> salvage -> level clear
      m.wave = m.wavesPerLevel;
      run(m, 3);
      final intact = m.takeGameEvents().where((e) => e.name == GameEventNames.fleetIntact);
      expect(intact.single.data['scope'], 'level');
      expect(m.score, greaterThan(score));
    });

    test('no fleetIntact for a level where an ally retreated', () {
      final m = arena(level: 1);
      engaged(m, unit(m, 1100));
      run(m, GroundTuning.demonTracerEvery * (GroundTuning.allyHp + 2));
      m.takeGameEvents();
      m.demons.clear();
      m.wave = m.wavesPerLevel;
      run(m, 3);
      expect(gameEvents(m), isNot(contains(GameEventNames.fleetIntact)));
    });
  });

  test('event names are the documented contract', () {
    expect(GameEventNames.all, containsAll([
      'groundForceSighted',
      'groundForceInRange',
      'groundMissileLaunch',
      'homingPickup',
      'homingLaunch',
      'homingHit',
      'groundUnitDestroyed',
      'allyUnderAttack',
      'allySaved',
      'allyRetreated',
      'fleetIntact',
      'groundBreakthrough',
      'groundPressure',
    ]));
    final m = arena();
    unit(m, GroundTuning.sightZ + 5);
    run(m, 1);
    final e = m.takeGameEvents().firstWhere((e) => e.name == GameEventNames.groundForceSighted);
    expect(e.data['sector'], m.level);
    expect(e.data['x'], isA<double>());
    var calls = 0;
    final stop = GameEvents.listen((_) => calls++);
    final stopBroken = GameEvents.listen((_) => throw StateError('broken'));
    dispatchGameEvent(e);
    expect(calls, 1);
    stop();
    stopBroken();
    expect(GameEvents.listenerCount, 0);
  });
}

void _destroy(ArcadeModel m, GroundUnit u) {
  m.ground.salvo.active = HomingMissile(u.x, u.bodyY + 4, 0, -300, -1)
    ..target = u
    ..kind = HomingTargetKind.ground;
  m.update(1 / 60);
}
