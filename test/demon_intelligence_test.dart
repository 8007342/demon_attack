// demon-intelligence tasks 3.3 and 4.4: intelligence tiers, planner
// scheduling, thread dives and pincers (design §4-§5).
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

  test('a hunter survives a straight shot column that kills a drone at the same spot', () {
    // A straight column of shots: a drone jinks one and meets the next.
    int survivors(bool elite) {
      var alive = 0;
      var frames = 0;
      for (var seed = 0; seed < 10; seed++) {
        final m = ArcadeModel(seed: seed)..startAt(sector: 2, route: 1);
        m
          ..mode = RunMode.playing
          ..invulnerable = 1000
          ..perspective = false
          ..swarmPatterns = false;
        m.demons.clear();
        m.shots.clear();
        final d = settled(180, 140, kind: 0, hp: 1, elite: elite);
        m.demons.addAll([d, settled(20, 40, hp: 999)..attackLeft = 1000]);
        // The ship tracks it: its auto-fire is a column of straight shots,
        // one every 0.23 s (88 u apart).
        m.shipX = m.targetX = 180;
        for (var f = 0; f < 150 && m.demons.contains(d); f++) {
          m.moveTo(d.x);
          m.update(dt);
          frames++;
        }
        if (m.demons.contains(d)) alive++;
      }
      // ignore: avoid_print
      print('${elite ? 'hunter' : 'drone'}: $alive / 10 alive, $frames frames');
      return frames;
    }

    final hunters = survivors(true), drones = survivors(false);
    expect(hunters, greaterThan(drones * 1.2));
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
}
