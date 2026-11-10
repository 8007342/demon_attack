import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gameplay round 3: the life-loss sequence (explosion, regroup, respawn),
/// divePrep, ground war v2 (homing arcs to the ground, convoy allies, L2 near
/// misses, the guaranteed L3 breakthrough) and the console start.

const dt = 1 / 60;

ArcadeModel playing({Difficulty difficulty = Difficulty.normal, int sector = 1, int route = 0}) {
  final m = ArcadeModel(seed: 7)
    ..startAt(difficulty: difficulty, sector: sector, route: route);
  while (!m.combat) {
    m.update(dt);
  }
  m.takeGameEvents();
  m.takeEvents();
  return m;
}

/// Steps [seconds] and returns the structured event names seen, with the
/// model clock at which each arrived.
List<(String, double)> run(ArcadeModel m, double seconds, {void Function()? each}) {
  final out = <(String, double)>[];
  for (var i = 0; i < (seconds * 60).round(); i++) {
    each?.call();
    m.update(dt);
    for (final e in m.takeGameEvents()) {
      out.add((e.name, m.clock));
    }
  }
  return out;
}

void main() {
  group('life-loss sequence', () {
    test('explosion, regroup and respawn run on the documented timing', () {
      final m = playing(sector: 2);
      m.invulnerable = 0;
      final score = m.score, lives = m.lives;
      final t0 = m.clock;
      m.hitPlayer();
      expect(m.lives, lives - 1);
      expect(m.lifeLossPhase, LifeLossPhase.exploding);
      expect(m.shipAway, isTrue);
      expect(m.shipDebris, isNotEmpty);
      final first = m.takeGameEvents().map((e) => e.name);
      expect(first, contains(GameEventNames.playerDestroyed));
      final seen = run(m, 3.2);
      double at(String name) => seen.firstWhere((e) => e.$1 == name).$2 - t0;
      expect(at(GameEventNames.regroupStart),
          closeTo(LifeLossTuning.explode, 2 * dt));
      expect(at(GameEventNames.playerRespawn),
          closeTo(LifeLossTuning.away, 2 * dt));
      expect(LifeLossTuning.regroup, inInclusiveRange(1.5, 2.0));
      expect(seen.where((e) => e.$1 == GameEventNames.playerRespawn).length, 1);
      expect(m.lifeLossPhase, LifeLossPhase.none);
      expect(m.lives, lives - 1, reason: 'one life per hit');
      expect(m.score, greaterThanOrEqualTo(score));
      expect(m.mode, RunMode.playing);
    });

    test('the event names other agents subscribe to are exact', () {
      expect(GameEventNames.playerDestroyed, 'playerDestroyed');
      expect(GameEventNames.regroupStart, 'regroupStart');
      expect(GameEventNames.playerRespawn, 'playerRespawn');
      expect(GameEventNames.divePrep, 'divePrep');
      expect(GameEventNames.groundNearMiss, 'groundNearMiss');
      expect(GameEventNames.all, containsAll(GameEventNames.lifeLoss));
    });

    test('hostile shots drain, the swarm regroups, nothing can hit', () {
      final m = playing(sector: 3, route: 1);
      // Hostile fire everywhere, one diving demon and a missile in flight.
      for (var i = 0; i < 12; i++) {
        m.shots.add(Shot(30.0 + i * 25, 200.0 + i * 20, 0, 60, hostile: true));
      }
      final diver = m.demons.firstWhere((d) => !d.isLarge && !d.entering);
      diver
        ..dive = .3
        ..y = 380;
      m.invulnerable = 0;
      m.hitPlayer();
      final lives = m.lives;
      run(m, LifeLossTuning.explode + dt);
      expect(m.regrouping, isTrue);
      expect(diver.dive, 0, reason: 'dives pull out to regroup');
      run(m, LifeLossTuning.drainWindow + 2 * dt);
      expect(m.shots.where((s) => s.hostile && s.y <= ArcadeModel.height), isEmpty);
      expect(m.shotFizzles, isNotEmpty);
      // During the rest of the regroup: no new fire, no hits.
      var hostile = 0;
      run(m, LifeLossTuning.regroup - LifeLossTuning.drainWindow - 6 * dt, each: () {
        hostile += m.shots.where((s) => s.hostile).length;
        m.shots.add(Shot(m.shipX, ArcadeModel.shipY, 0, 0, hostile: true));
        m.hitPlayer();
      });
      expect(m.lives, lives, reason: 'nothing can hit the player');
      expect(m.demons.every((d) => d.dive == 0 && d.telegraph <= 0 || d.lastStand), isTrue);
      // The test itself injected one shot per frame; the swarm fired none.
      expect(hostile, lessThanOrEqualTo((LifeLossTuning.regroup * 60).round()));
    });

    test('the reserve flies up from the bottom with 2 s of blinking protection', () {
      final m = playing(sector: 2);
      m.invulnerable = 0;
      m.hitPlayer();
      run(m, LifeLossTuning.away + dt);
      expect(m.lifeLossPhase, LifeLossPhase.emerging);
      expect(m.shipDrawY, greaterThan(ArcadeModel.shipY + 10));
      expect(m.invulnerable, closeTo(LifeLossTuning.protection, 2 * dt));
      expect(m.canPilot, isTrue);
      run(m, LifeLossTuning.emerge);
      expect(m.shipDrawY, ArcadeModel.shipY);
      expect(m.lifeLossPhase, LifeLossPhase.none);
      // Still protected, then vulnerable again.
      final lives = m.lives;
      m.hitPlayer();
      expect(m.lives, lives);
      run(m, LifeLossTuning.protection - LifeLossTuning.emerge + 2 * dt);
      expect(m.invulnerable, 0);
      m.hitPlayer();
      expect(m.lives, lives - 1);
    });

    test('the loadout survives and its timers freeze while the ship is away', () {
      final m = playing(sector: 2);
      m.collect(Power.powerful);
      m.collect(Power.spread);
      final left = m.timeLeft(Power.powerful);
      m.invulnerable = 0;
      m.hitPlayer();
      run(m, LifeLossTuning.away - dt);
      expect(m.timeLeft(Power.powerful), closeTo(left - dt, 3 * dt));
      expect(m.hasPower(Power.spread), isTrue);
    });

    test('the final life still goes straight to the defeat celebration', () {
      final m = playing(sector: 2);
      m.lives = 1;
      m.invulnerable = 0;
      m.hitPlayer();
      expect(m.mode, RunMode.gameOver);
      expect(m.lifeLossPhase, LifeLossPhase.none);
      final e = m.takeGameEvents().firstWhere((e) => e.name == GameEventNames.playerDestroyed);
      expect(e.data['final'], isTrue);
    });
  });

  test('divePrep fires a beat before every dive tell', () {
    final m = playing(sector: 3, route: 1);
    final preps = <Demon, double>{};
    var tells = 0, early = 0;
    final telling = <Demon>{};
    for (var i = 0; i < 60 * 40; i++) {
      m.invulnerable = 2;
      m.shots.removeWhere((s) => !s.hostile); // keep the wave alive
      m.update(dt);
      for (final e in m.takeGameEvents()) {
        if (e.name != GameEventNames.divePrep) continue;
        final d = m.demons.where((d) => d.divePrep > 0 && !preps.containsKey(d));
        for (final x in d) {
          preps[x] = m.clock;
        }
      }
      for (final d in m.demons) {
        if (d.telegraph > 0 && !d.lastStand && telling.add(d)) {
          tells++;
          final at = preps.remove(d);
          if (at != null && m.clock - at >= ArcadeModel.divePrepBeat * .9) early++;
        }
        if (d.telegraph <= 0 && d.dive == 0) telling.remove(d);
      }
    }
    expect(tells, greaterThan(5));
    expect(early, tells);
  });

  group('ground war v2', () {
    GroundUnit stage(ArcadeModel m, double z) {
      m.ground
        ..units.clear()
        ..allies.clear()
        ..front = GroundFront.none;
      final u = GroundUnit(900, 2, 0, .4, z, hp: 99);
      m.ground.units.add(u);
      return u;
    }

    test('homing to the ground flies a long perspective arc; air stays fast', () {
      for (final z in [400.0, 900.0, 1300.0]) {
        final m = playing(sector: 3);
        m.demons.clear();
        final u = stage(m, z);
        m.collectHoming();
        var launched = -1.0, minY = 999.0, minPerspective = 1.0;
        var destroyedAt = -1.0;
        for (var i = 0; i < 300 && destroyedAt < 0; i++) {
          m.invulnerable = 2;
          m.update(dt);
          final h = m.ground.homing;
          if (h != null) {
            if (launched < 0) launched = m.clock;
            minY = h.y < minY ? h.y : minY;
            minPerspective = h.perspective < minPerspective ? h.perspective : minPerspective;
          }
          if (u.destroyed) destroyedAt = m.clock;
        }
        final flight = destroyedAt - launched;
        expect(flight, closeTo(GroundTuning.homingGroundFlight(u.z), .15), reason: 'z $z');
        expect(flight, greaterThan(.9));
        expect(flight, lessThan(1.9));
        expect(minY, lessThan(ArcadeModel.shipY - 120), reason: 'climbs away');
        expect(minPerspective, lessThan(.75), reason: 'shrinks with distance');
      }
      // Air: direct and fast.
      final m = playing(sector: 3);
      m.ground.units.clear();
      m.demons
        ..clear()
        ..add(Demon(180, 200, 0, 1, 0));
      m.collectHoming();
      var launched = -1.0, hit = -1.0;
      for (var i = 0; i < 120 && hit < 0; i++) {
        m.invulnerable = 2;
        m.update(dt);
        if (m.ground.homing != null && launched < 0) launched = m.clock;
        if (m.demons.isEmpty) hit = m.clock;
      }
      expect(hit - launched, lessThan(.7));
    });

    test('allies hold station near the ship and never scroll away', () {
      final m = playing(sector: 1);
      var minZ = 9999.0, maxZ = 0.0, alive = 99;
      run(m, 90, each: () {
        m.invulnerable = 2;
        m.shots.removeWhere((s) => !s.hostile);
        var n = 0;
        for (final a in m.ground.allies) {
          if (a.totalled) continue;
          n++;
          if (a.z > GroundTuning.allyRollInZ + 20) {
            minZ = a.z < minZ ? a.z : minZ;
          }
          maxZ = a.z > maxZ ? a.z : maxZ;
        }
        alive = n < alive ? n : alive;
      });
      expect(alive, greaterThanOrEqualTo(2), reason: 'a convoy on both sides');
      expect(minZ, greaterThanOrEqualTo(GroundTuning.allyHoldZ - 1));
      expect(maxZ, lessThanOrEqualTo(GroundTuning.allyMaxAdvanceZ + 1));
      expect(maxZ, greaterThan(GroundTuning.allyHoldZ + 60), reason: 'advances to attack');
      for (final a in m.ground.allies) {
        expect(a.x + a.width / 2 <= GroundCamera.laneLeft || a.x - a.width / 2 >= GroundCamera.laneRight, isTrue);
      }
    });

    for (final difficulty in Difficulty.values) {
      test('${difficulty.name}: L2 near misses, and no ground fire in L1-L2', () {
        for (final sector in [1, 2]) {
          final m = playing(difficulty: difficulty, sector: sector);
          final seen = run(m, 150, each: () {
            m.invulnerable = 2;
            m.shots.removeWhere((s) => !s.hostile);
          });
          final g = m.ground;
          expect(g.missilesLaunched, 0);
          expect(g.breakthroughs, 0);
          expect(seen.map((e) => e.$1), isNot(contains(GameEventNames.groundMissileLaunch)));
          if (sector == 2) {
            expect(g.nearMissesBySector[1], greaterThan(0));
            expect(seen.map((e) => e.$1), contains(GameEventNames.groundNearMiss));
          } else {
            expect(g.nearMissesBySector[0], 0);
          }
        }
      });

      test('${difficulty.name}: L3 guarantees a telegraphed breakthrough', () {
        for (final route in [0, 2]) {
          final m = playing(difficulty: difficulty, sector: 3, route: route);
          final seen = <String>[];
          for (var i = 0; i < 60 * 45 && m.ground.breakthroughsBySector[2] == 0; i++) {
            m.invulnerable = 2;
            m.shots.removeWhere((s) => !s.hostile);
            m.ground.pickups.clear(); // a pilot that never helps
            m.update(dt);
            seen.addAll(m.takeGameEvents().map((e) => e.name));
          }
          expect(m.ground.breakthroughsBySector[2], greaterThanOrEqualTo(1),
              reason: 'route $route');
          final warn = seen.indexOf(GameEventNames.groundBreakthroughWarning);
          final call = seen.indexOf(GameEventNames.allyUnderAttack);
          final broke = seen.indexOf(GameEventNames.groundBreakthrough);
          expect(call, isNonNegative);
          expect(warn, inExclusiveRange(call, broke));
        }
      });
    }
  });

  group('console start', () {
    test('startAt begins at 0 points with the earlier routes won', () {
      final m = ArcadeModel()..startAt(difficulty: Difficulty.hard, sector: 4, route: 3);
      expect(m.score, 0);
      expect(m.level, 4);
      expect(m.cycle, 3);
      expect(m.medals, 3);
      expect(m.lives, m.policy.startingLives);
      expect(m.difficulty, Difficulty.hard);
    });

    test('a sentinel wave spawns a sentinel; route 0 has none', () {
      for (final d in Difficulty.values) {
        expect(ArcadeModel.sentinelWave(difficulty: d, sector: 2, route: 0), isNull);
        final wave = ArcadeModel.sentinelWave(difficulty: d, sector: 2, route: 1)!;
        final m = ArcadeModel()..startAt(difficulty: d, sector: 2, route: 1, wave: wave);
        expect(m.wave, wave);
        expect(m.demons.any((x) => x.isLarge), isTrue, reason: d.name);
      }
    });

    test('the boss jump meets the carrier of that run', () {
      final m = ArcadeModel()..startAt(sector: 5, route: 2);
      expect(m.boss, isNotNull);
      expect(m.cycle, 2);
      expect(m.score, 0);
    });
  });
}
