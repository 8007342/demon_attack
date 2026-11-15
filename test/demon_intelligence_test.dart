// demon-intelligence tasks 3.3 and 4.4: intelligence tiers, planner
// scheduling, thread dives and pincers (design §4-§5).
import 'package:demon_attack/game/demon_planner.dart' show PlannerConfig;
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

const dt = 1 / 60;

/// A route-1 Normal arena with nothing in it (no stream, no arrivals).
ArcadeModel arena({int route = 1, int sector = 2}) {
  final m = ArcadeModel()..startAt(sector: sector, route: route);
  m
    ..mode = RunMode.playing
    ..invulnerable = 1000
    ..perspective = false
    ..swarmPatterns = false;
  m.demons.clear();
  m.shots.clear();
  return m;
}

Demon settled(
  double x,
  double y, {
  int kind = 0,
  int hp = 1,
  bool elite = false,
}) => Demon(x, y, kind, hp, 0, elite: elite)
  ..entranceProgress = 1
  ..attackLeft = 1000
  ..evadeCooldown = 0;

void main() {
  skillEffects();
  test('tier classification', () {
    expect(ArcadeModel.tierOf(Demon(0, 0, 0, 1, 0)), DemonTier.drone);
    expect(ArcadeModel.tierOf(Demon(0, 0, 1, 2, 0)), DemonTier.drone);
    expect(ArcadeModel.tierOf(Demon(0, 0, 2, 1, 0)), DemonTier.skirmisher);
    expect(ArcadeModel.tierOf(Demon(0, 0, 0, 3, 0)), DemonTier.skirmisher);
    expect(
      ArcadeModel.tierOf(Demon(0, 0, 0, 2, 0, elite: true)),
      DemonTier.hunter,
    );
    expect(
      ArcadeModel.tierOf(
        Demon(0, 0, 0, 9, 0, archetype: EnemyArchetype.shieldSentinel),
      ),
      DemonTier.sentinel,
    );
  });

  test('route 0 is bit-identical with and without the intelligence', () {
    for (final difficulty in Difficulty.values) {
      final a = ArcadeModel(seed: 5)
        ..startAt(difficulty: difficulty, sector: 3);
      final b = ArcadeModel(seed: 5)
        ..startAt(difficulty: difficulty, sector: 3)
        ..intelligence = false;
      for (var f = 0; f < 60 * 40; f++) {
        for (final m in [a, b]) {
          m.invulnerable = 2;
          final d = m.demons.where((d) => !d.entering).firstOrNull;
          if (d != null) m.moveTo(d.x);
          m.update(dt);
          m.takeEvents();
        }
      }
      expect(a.kills, b.kills, reason: '$difficulty');
      expect(a.score, b.score);
      expect([for (final d in a.demons) d.x], [for (final d in b.demons) d.x]);
      expect(a.random.nextDouble(), b.random.nextDouble());
    }
  });

  test('drones decide exactly as before on route 1', () {
    // Drones only: the same scene with and without the intelligence.
    List<double> run(bool on) {
      final m = arena()..intelligence = on;
      m.demons.addAll([
        for (var i = 0; i < 6; i++) settled(60.0 + i * 48, 120 + (i % 2) * 30),
      ]);
      final xs = <double>[];
      for (var f = 0; f < 240; f++) {
        if (f % 9 == 0) m.shots.add(Shot(60.0 + (f * 7) % 240, 470, 0, -390));
        m.update(dt);
        xs.addAll([for (final d in m.demons) d.x]);
      }
      return xs;
    }

    expect(run(true), run(false));
  });

  test('a hunter dodges what a drone cannot: a second shot 1.4 s on', () {
    // Two straight shots at the creature 1.4 s apart. A drone jinks the
    // first and is back in the column on its 2.4 s cooldown for the
    // second; a hunter plans both, at any skill.
    int survivors(bool elite, {double skill = .3}) {
      var alive = 0;
      for (var seed = 0; seed < 10; seed++) {
        final m = ArcadeModel(seed: seed)..startAt(sector: 2, route: 1);
        m
          ..mode = RunMode.playing
          ..invulnerable = 1000
          ..perspective = false
          ..swarmPatterns = false;
        m.demons.clear();
        m.shots.clear();
        m.shipX = m.targetX = 340; // its own fire stays clear
        final d = settled(180, 140, kind: 0, hp: 1, elite: elite);
        m.demons.addAll([d, settled(20, 40, hp: 999)]);
        for (var f = 0; f < 150 && m.demons.contains(d); f++) {
          if (f == 0 || f == 84) {
            m.shots.add(Shot(d.x, ArcadeModel.shipY - 13, 0, -390));
          }
          m.moveTo(340);
          m.skill.level = skill;
          m.update(dt);
          m.shots.removeWhere((s) => !s.hostile && s.x > 300);
        }
        if (m.demons.contains(d)) alive++;
      }
      return alive;
    }

    final drones = survivors(false);
    final novice = survivors(true, skill: 0),
        sharp = survivors(true, skill: .8);
    // ignore: avoid_print
    print('alive of 10: drones $drones, hunters s0 $novice, s0.8 $sharp');
    expect(sharp, greaterThanOrEqualTo(8));
    expect(novice, greaterThanOrEqualTo(8));
    expect(drones, lessThanOrEqualTo(3));
  });

  test('one drone/skirmisher and one hunter evade at a time', () {
    final m = ArcadeModel(seed: 21)
      ..startAt(difficulty: Difficulty.hard, sector: 3, route: 2);
    var hunterEvades = 0, smallEvades = 0;
    final seen = <Demon>{};
    for (var f = 0; f < 60 * 120; f++) {
      if (m.combat) {
        m.invulnerable = 2;
        final d = m.demons.where((d) => !d.entering).firstOrNull;
        if (d != null) m.moveTo(d.x);
      }
      m.update(dt);
      m.takeEvents();
      final small = m.demons.where(
        (d) => !d.isLarge && !d.elite && d.evadeLeft > 0,
      );
      final hunters = m.demons.where((d) => d.elite && d.evadeLeft > 0);
      expect(small.length, lessThanOrEqualTo(1));
      expect(hunters.length, lessThanOrEqualTo(1));
      for (final d in [...small, ...hunters]) {
        if (seen.add(d)) d.elite ? hunterEvades++ : smallEvades++;
      }
      seen.removeWhere((d) => d.evadeLeft <= 0);
    }
    expect(smallEvades, greaterThan(0));
    expect(hunterEvades, greaterThan(0));
  });

  test(
    'planner decisions are capped at six per frame, ten per second each',
    () {
      final m = arena(route: 2, sector: 3);
      m.demons.addAll([
        for (var i = 0; i < 12; i++)
          settled(30.0 + i * 27, 130 + (i % 3) * 25, hp: 2, elite: true),
      ]);
      var last = m.planner.decisions, peak = 0;
      for (var f = 0; f < 180; f++) {
        m.shots.add(Shot(30.0 + (f * 13) % 300, 470, 0, -390)..age = .5);
        m.update(dt);
        final now = m.planner.decisions;
        peak = now - last > peak ? now - last : peak;
        last = now;
        expect(m.planDecisionsThisFrame, lessThanOrEqualTo(6));
      }
      expect(peak, lessThanOrEqualTo(6));
      expect(m.planner.decisions, lessThanOrEqualTo(12 * 10 * 3 + 12));
    },
  );

  test('a thread dive passes between two shots 88 u apart', () {
    // Shot pairs a fire interval apart (0.23 s at 385 u/s ≈ 88 u) dead on
    // a hunter's straight dive line: the straight diver meets them.
    (int, double) dive(bool thread) {
      final m = arena()..intelligence = thread;
      m.shipX = m.targetX = 340; // its own auto-fire stays clear
      final d = settled(180, 150, kind: 1, hp: 3, elite: true)
        ..dive = .001
        ..threadLine = 180
        ..targetX = 180;
      m.demons.addAll([d, settled(20, 40, hp: 999)]);
      m.shots.addAll([
        Shot(180, 430, 0, -385)..age = .5,
        Shot(180, 518, 0, -385)..age = .27,
      ]);
      final hits = m.shotsHit;
      var arrival = double.nan;
      for (var f = 0; f < 120 && m.demons.contains(d); f++) {
        m.moveTo(340);
        m.update(dt);
        if (arrival.isNaN && d.y >= ArcadeModel.shipY - 30) arrival = d.x;
        if (d.dive == 0) break;
      }
      return (m.shotsHit - hits, arrival);
    }

    final (straightHits, _) = dive(false);
    final (threadHits, arrival) = dive(true);
    expect(straightHits, 2);
    expect(threadHits, 0);
    expect(arrival, closeTo(180, 12), reason: 'it still arrives at its aim');
  });

  test(
    'a dive aim never moves after the tell; the dive cap holds (Hard, 10 min)',
    () {
      final m = ArcadeModel(seed: 314)
        ..startAt(difficulty: Difficulty.hard, sector: 3, route: 2);
      final aims = <Demon, double>{};
      var dives = 0;
      for (var f = 0; f < 60 * 600; f++) {
        if (m.combat) {
          m.invulnerable = 2;
          m.skill.level = 1; // the sharpest hunters, pincers included
          final d = m.demons.where((d) => !d.entering).firstOrNull;
          if (d != null) m.moveTo(d.x + (f % 120 < 60 ? 30 : -30));
        }
        m.update(dt);
        m.takeEvents();
        m.takeGameEvents();
        final active = m.demons
            .where(
              (d) =>
                  !d.isLarge &&
                  (d.dive > 0 || d.telegraph > 0 || d.divePrep > 0),
            )
            .length;
        final cap = m.level <= 2 && m.cycle == 0 ? 1 : 3;
        expect(active, lessThanOrEqualTo(cap), reason: 'frame $f');
        for (final d in m.demons) {
          if (!d.elite) continue;
          if (d.telegraph > 0 || d.dive > 0) {
            final aim = aims.putIfAbsent(d, () {
              dives++;
              return d.targetX;
            });
            expect(d.targetX, aim, reason: 'the aim is fixed from the tell');
          } else if (d.divePrep <= 0) {
            aims.remove(d);
          }
        }
      }
      expect(dives, greaterThan(10));
    },
  );

  test('pincer: two tells either side of the forecast', () {
    final m = arena(route: 2, sector: 3);
    m.shipX = m.targetX = 180;
    final a = settled(120, 140, kind: 1, hp: 3, elite: true);
    final b = settled(240, 140, kind: 1, hp: 3, elite: true);
    m.demons.addAll([a, b]);
    List<double>? pair;
    for (var f = 0; f < 60 * 120 && pair == null; f++) {
      m.skill.level = 1;
      m.moveTo(180);
      m.update(dt);
      m.shots.removeWhere((s) => !s.hostile);
      if (a.telegraph > 0 && b.telegraph > 0) pair = [a.targetX, b.targetX];
      if (a.dive > 0 || b.dive > 0) {
        // Not a pincer: reset both and wait for the next pick.
        for (final d in [a, b]) {
          d
            ..dive = 0
            ..telegraph = 0
            ..divePrep = 0
            ..x = d.homeX
            ..y = d.homeY;
        }
      }
    }
    expect(pair, isNotNull, reason: 'a pincer within two minutes at s 1');
    final mu = m.pilot.aim(1);
    pair!.sort();
    expect(pair[0], closeTo(mu - 34, 1));
    expect(pair[1], closeTo(mu + 34, 1));
  });
}

void skillEffects() {
  test('skill sharpens hunters: delay, foresight, temperature, cooldown', () {
    final novice = PlannerConfig.hunter(0), sharp = PlannerConfig.hunter(1);
    expect(novice.delay, closeTo(.30, 1e-9));
    expect(sharp.delay, closeTo(.12, 1e-9));
    expect(sharp.foresight, greaterThan(novice.foresight));
    expect(sharp.temperature, lessThan(novice.temperature));
    expect(
      PlannerConfig.hunterCooldown(1),
      lessThan(PlannerConfig.hunterCooldown(0)),
    );
  });
}
