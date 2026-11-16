// demon-intelligence task 5.5: the sentinel final rush (design §6).
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter_test/flutter_test.dart';

const dt = 1 / 60;

/// A route-[route] arena holding one eligible sentinel at [hp] of 12.
(ArcadeModel, Demon) arena(
  Difficulty difficulty, {
  int route = 1,
  int hp = 3,
  int seed = 1,
}) {
  final m = ArcadeModel(seed: seed)
    ..startAt(difficulty: difficulty, sector: 2, route: route);
  m
    ..mode = RunMode.playing
    ..invulnerable = 0
    ..lives = 99;
  m.demons.clear();
  m.shots.clear();
  final d = Demon(
    180,
    44,
    2,
    12,
    0,
    archetype: EnemyArchetype.shieldSentinel,
    lastStandEligible: true,
  )..hp = hp;
  m.demons.add(d);
  return (m, d);
}

/// Steps without player fire (nothing shoots the sentinel down).
void run(ArcadeModel m, double seconds, {void Function()? each}) {
  for (var t = 0.0; t < seconds - 1e-9; t += dt) {
    each?.call();
    m.update(dt);
    m.shots.removeWhere((s) => !s.hostile);
  }
}

void main() {
  test('rush chance by difficulty over 2000 births; one draw, as before', () {
    for (final (difficulty, base) in [
      // playtest-fixes-3: a little more often (was .20 / .35 / .45).
      (Difficulty.easy, .28),
      (Difficulty.normal, .45),
      (Difficulty.hard, .50),
    ]) {
      var eligible = 0;
      for (var seed = 0; seed < 2000; seed++) {
        final m = ArcadeModel(seed: seed)
          ..restoreCheckpoint({
            'difficulty': difficulty.name,
            'routeIndex': 1,
            'sector': 2,
            'wave': 4,
          });
        if (m.rushEligible(m.demons.singleWhere((d) => d.isLarge))) {
          eligible++;
        }
      }
      // Route 1 starts at skill 0.3: + 0.03.
      expect(eligible / 2000, closeTo(base + .03, .03), reason: '$difficulty');
    }
    // The birth roll is the single draw the old boolean used: the run's
    // random sequence after the roster is unchanged (pre-W4 value).
    for (final difficulty in Difficulty.values) {
      final m = ArcadeModel(seed: 7)
        ..restoreCheckpoint({
          'difficulty': difficulty.name,
          'routeIndex': 1,
          'sector': 2,
          'wave': 4,
        });
      expect(m.random.nextDouble(), 0.7314634084349075);
    }
  });

  test('the alone trigger: escort gone, no ordinary creature, below half', () {
    final (m, d) = arena(Difficulty.normal, hp: 6);
    m.escortSpawned = true;
    m.demons.add(Demon(40, 90, 0, 1, 0)); // its escort, still flying
    run(m, .2);
    expect(d.lastStand, isFalse, reason: 'its escort is still alive');
    m.demons.removeWhere((o) => !o.isLarge);
    run(m, .1);
    expect(d.lastStand, isTrue);
    final (m2, d2) = arena(Difficulty.normal, hp: 7);
    m2.escortSpawned = true;
    run(m2, .2);
    expect(d2.lastStand, isFalse, reason: 'above half hull');
  });

  test('the rush shield: powered hits break it, stagger and bonus', () {
    // playtest-fixes-3: the super diving shield of a Normal route-1
    // sentinel (8 points): the bare gun deflects, Powerful breaks it in
    // three hits (2 + 1 breaker each).
    final (m, d) = arena(Difficulty.normal);
    m.hitDemon(d);
    expect(d.lastStand, isTrue);
    expect(d.rushShieldMax, 8);
    final hull = d.hp, shield = d.shield, armor = d.armor;
    run(m, RushTuning.tell(Difficulty.normal) + .05);
    expect(d.rushing, isTrue);
    m.hitDemon(d);
    expect(d.rushShield, 8, reason: 'the bare gun deflects');
    m.powerTimers[Power.powerful] = 9;
    for (var i = 0; i < 2; i++) {
      m.hitDemon(d, damage: 2);
    }
    expect((d.hp, d.shield, d.armor), (hull, shield, armor));
    final score = m.score;
    final events = <String>[];
    m.hitDemon(d, damage: 2);
    m.powerTimers.clear();
    events.addAll(m.takeGameEvents().map((e) => e.name));
    expect(d.rushShield, 0);
    expect(events, contains(GameEventNames.rushShieldBroken));
    expect(m.score - score, 150 * 2, reason: '150 · (cycle + 1)');
    expect(d.rushStagger, RushTuning.stagger);
    final fast = m.policy.rushSpeed;
    m.update(dt);
    final v = (d.rushVx * d.rushVx + d.rushVy * d.rushVy);
    expect(v, lessThan(fast * fast * .4 * .4 + 1), reason: 'it reels');
    m.hitDemon(d);
    expect(d.hp, hull - 1, reason: 'the hull takes damage again');
  });

  test('passes per difficulty, then the sacrifice', () {
    for (final (difficulty, passes) in [
      (Difficulty.easy, 1),
      (Difficulty.normal, 2),
      (Difficulty.hard, 3),
    ]) {
      final (m, d) = arena(difficulty);
      m.shipX = m.targetX = 340;
      m.hitDemon(d);
      var tells = 0, again = 0, fogFrames = 0;
      for (var f = 0; f < 60 * 20 && m.demons.contains(d); f++) {
        // Protected: a touch ends only that pass's contact.
        m.invulnerable = 10;
        m.moveTo((f ~/ 50).isEven ? 30 : 330);
        m.update(dt);
        m.shots.removeWhere((s) => !s.hostile);
        for (final e in m.takeGameEvents()) {
          if (e.name == GameEventNames.sentinelRushTell) tells++;
          if (e.name == GameEventNames.sentinelRushAgain) again++;
        }
        if (d.rushPhase == RushPhase.recover && d.entering) fogFrames++;
      }
      expect(m.demons, isNot(contains(d)), reason: '$difficulty sacrificed');
      expect(tells, passes, reason: '$difficulty');
      expect(again, passes - 1);
      // Untargetable (entering) for the whole 1.2 s come-around.
      expect(
        fogFrames,
        closeTo((passes - 1) * RushTuning.recover / m.policy.hostileRate * 60, 3),
      );
      expect(m.kills, 0);
    }
  });

  test('the tell is at least 1.0 s real; the radio warning ends on the rush', () {
    for (final difficulty in Difficulty.values) {
      final (m, d) = arena(difficulty);
      m.hitDemon(d);
      final tell = m
          .takeGameEvents()
          .firstWhere((e) => e.name == GameEventNames.sentinelRushTell);
      var t = 0.0;
      while (!d.rushing) {
        m.update(dt);
        t += dt;
      }
      expect(t, greaterThanOrEqualTo(1.0 - dt));
      expect(((tell.data['rushIn'] as double) - t).abs(), lessThan(.3));
    }
  });

  test('shake: at most 2 px, none with reduced motion', () {
    final (m, d) = arena(Difficulty.hard);
    final scene = DemonScene(m, () {});
    scene.sectors.flyover.reducedMotionOverride = false;
    m.hitDemon(d);
    var peak = 0.0;
    for (var f = 0; f < 120; f++) {
      m.update(dt);
      final (sx, sy) = scene.rushShake();
      peak = [peak, sx.abs(), sy.abs()].reduce((a, b) => a > b ? a : b);
    }
    expect(peak, greaterThan(0));
    expect(peak, lessThanOrEqualTo(2));
    final (m2, d2) = arena(Difficulty.hard);
    final calm = DemonScene(m2, () {});
    calm.sectors.flyover.reducedMotionOverride = true;
    m2.hitDemon(d2);
    for (var f = 0; f < 120; f++) {
      m2.update(dt);
      expect(calm.rushShake(), (0.0, 0.0));
    }
  });
}

