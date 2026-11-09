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
  m.invulnerable = 0;
  return m;
}

GroundUnit unit(ArcadeModel m, double z, {int side = 0, int shots = 2}) {
  final u = GroundUnit(m.ground.nextId++, m.level - 1, side, .5, z,
      shotsLeft: shots);
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

  group('introduction pacing', () {
    GroundPlan plan(Difficulty d, int route, int sector, int wave) => GroundPlan.of(d,
        route: route,
        sector: sector,
        wave: wave,
        wavesPerLevel: 3 + ((sector - 1) ~/ 2) + (route < 3 ? route : 3));

    test('first Krybor: one unit, only in the final wave; none on Easy', () {
      for (var wave = 1; wave < 3; wave++) {
        expect(plan(Difficulty.normal, 0, 1, wave).budget, 0);
      }
      expect(plan(Difficulty.normal, 0, 1, 3).budget, 1);
      expect(plan(Difficulty.hard, 0, 1, 3).budget, 1);
      expect(plan(Difficulty.normal, 0, 1, 3).firstDelay, greaterThan(5));
      for (var wave = 1; wave <= 3; wave++) {
        expect(plan(Difficulty.easy, 0, 1, wave).budget, 0);
      }
    });

    test('a gentle ramp through sector 4 and none over the carrier', () {
      for (final d in Difficulty.values) {
        var last = 0;
        for (var sector = 1; sector <= 4; sector++) {
          final total = [
            for (var w = 1; w <= 4; w++) plan(d, 0, sector, w).budget,
          ].reduce((a, b) => a + b);
          expect(total, greaterThanOrEqualTo(last), reason: '$d sector $sector');
          last = total;
          final p = plan(d, 0, sector, 2);
          expect(p.maxActive, lessThanOrEqualTo(2));
        }
        expect(plan(d, 0, 5, 1).budget, 0);
        expect(plan(d, 4, 5, 1).budget, 0);
      }
      // Sector 2 opens with no units; they join from its second wave.
      expect(plan(Difficulty.normal, 0, 2, 1).budget, 0);
      expect(plan(Difficulty.normal, 0, 2, 2).budget, 1);
    });

    test('difficulty orders the budgets Easy <= Normal <= Hard', () {
      for (var route = 0; route < 5; route++) {
        for (var sector = 1; sector <= 4; sector++) {
          for (var wave = 1; wave <= 7; wave++) {
            final e = plan(Difficulty.easy, route, sector, wave),
                n = plan(Difficulty.normal, route, sector, wave),
                h = plan(Difficulty.hard, route, sector, wave);
            expect(e.budget, lessThanOrEqualTo(n.budget));
            expect(n.budget, lessThanOrEqualTo(h.budget));
            expect(e.maxActive, lessThanOrEqualTo(h.maxActive));
            expect(e.shots, lessThanOrEqualTo(n.shots));
          }
        }
      }
    });

    test('a real first-Krybor run fields its single unit in the final wave', () {
      final m = ArcadeModel(seed: 1982)..start();
      final spawnWaves = <int>[];
      var seen = 0;
      for (var f = 0; f < 60 * 400 && m.level == 1; f++) {
        if (m.combat) {
          m.invulnerable = 2;
          if (m.demons.isNotEmpty) m.moveTo(m.demons.first.x);
        }
        m.update(1 / 60);
        if (m.ground.unitsSpawned > seen) {
          seen = m.ground.unitsSpawned;
          spawnWaves.add(m.wave);
        }
      }
      expect(spawnWaves, [3]);
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

  group('drop guarantee', () {
    void kill(ArcadeModel m) {
      final d = Demon(150, 200, 0, 1, 0);
      m.demons.add(d);
      m.hitDemon(d);
    }

    test('no homing drops while no ground units are alive (sectors 1-4)', () {
      final m = arena();
      for (var i = 0; i < 60; i++) {
        kill(m);
      }
      expect(m.ground.pickups, isEmpty);
    });

    test('the pity timer guarantees one within seconds of ground pressure', () {
      for (final d in Difficulty.values) {
        final m = arena(difficulty: d);
        unit(m, 1300);
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

    test('a pickup arrives before a fresh unit reaches firing range', () {
      for (final d in Difficulty.values) {
        final m = arena(difficulty: d);
        final u = unit(m, GroundTuning.spawnZ);
        var killsMade = 0;
        // A modest kill stream: one kill every 1.5 s.
        for (var f = 0; f < 60 * 20 && m.ground.pickups.isEmpty; f++) {
          if (f % 90 == 0) {
            kill(m);
            killsMade++;
          }
          m.update(1 / 60);
        }
        expect(m.ground.pickups, isNotEmpty, reason: '$d');
        final secondsToRange = (u.z - GroundTuning.fireZ) /
            (GroundTuning.approachSpeed * m.policy.hostileRate);
        expect(secondsToRange, greaterThan(0), reason: '$d after $killsMade kills');
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
      for (var i = 0; i < 40; i++) {
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
      run(m, 1);
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
