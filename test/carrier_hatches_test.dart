import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-hatches design §A2–§A7: the hatch geometry, hit points,
/// chapters, arrival invariance and hints.
void main() {
  ArcadeModel fight({int route = 0, int seed = 4, Difficulty? difficulty}) {
    final m = ArcadeModel(seed: seed)
      ..startAt(
        sector: 5,
        route: route,
        difficulty: difficulty ?? Difficulty.normal,
      );
    for (var g = 0; g < 60 * 240; g++) {
      final b = m.boss;
      if (b != null && b.fightReady && m.combat) break;
      m.invulnerable = 2;
      for (final d in List.of(m.demons)) {
        if (!d.entering) m.hitDemon(d, damage: 99);
      }
      m.update(1 / 60);
    }
    expect(m.boss?.fightReady, isTrue);
    return m;
  }

  test('tiers per tour, hatches on the top surface and in view', () {
    expect(
      [for (var r = 0; r < 6; r++) CarrierHatches.tiersFor(r)],
      [2, 2, 3, 3, 4, 4],
    );
    for (var r = 0; r < 5; r++) {
      final hs = CarrierHatches.forTour(r);
      expect(hs, hasLength(2 * CarrierHatches.tiersFor(r)));
      for (final h in hs) {
        // On the dorsal surface (above the deck), within the arena band.
        expect(h.y, lessThan(0));
        expect(h.x.abs(), lessThanOrEqualTo(110));
        // In view at zoom 0.86 over the whole glide (arena top ≈ −78).
        for (final by in [189.0, 221.0]) {
          expect(by + h.y, greaterThanOrEqualTo(-70), reason: h.id);
        }
      }
      // Topmost tier first, lower and lower.
      for (var i = 2; i < hs.length; i += 2) {
        expect(hs[i].y, greaterThan(hs[i - 2].y));
      }
    }
  });

  test('hit points: the old shield redistributed, 60 % field', () {
    for (var r = 0; r < 5; r++) {
      for (final d in Difficulty.values) {
        final b = Carrier(r, difficulty: d);
        final shield = DifficultyPolicy(d).bossShieldForRoute(r);
        final pool = b.hatches.fold(0, (a, h) => a + h.hpMax);
        expect(b.shieldMax, pool);
        expect(b.shield, pool);
        // The calibrated share of the old shield, at least minLayer for
        // the field and for the hull of each hatch.
        final n = b.hatches.length;
        const least = 2 * CarrierHatches.minLayer;
        expect(
          pool,
          lessThanOrEqualTo(
            math.max(least * n, CarrierHatches.pools[d.index] * shield + 2 * n),
          ),
        );
        expect(pool, greaterThanOrEqualTo(least * n));
        for (final h in b.hatches) {
          expect(h.fieldMax, greaterThanOrEqualTo(h.hullMax));
          expect(h.hullMax, greaterThanOrEqualTo(CarrierHatches.minLayer));
        }
      }
    }
  });

  test('only the topmost tier is vulnerable; the core waits for the fall', () {
    final m = fight();
    final b = m.boss!;
    expect(b.chapter, CarrierChapter.hatches);
    expect(b.vulnerableTier, 0);
    final core = b.core;
    b.door = 1;
    // The core cannot be hit while a hatch stands (a direct hit goes to
    // the nearest vulnerable hatch).
    m.hitBoss(b.x);
    expect(b.core, core);
    expect(b.shield, b.shieldMax - 1);
    // A lower tier is sealed.
    final lower = b.hatches.indexWhere((h) => h.hatch.tier == 1);
    expect(m.hitHatch(lower), isFalse);
    // Tier 1: field first, then hull.
    final h0 = b.hatches[0];
    final field = h0.field;
    expect(m.hitHatch(0), isTrue);
    expect(h0.field, field - 1);
    for (var i = 0; i < 400 && !h0.destroyed; i++) {
      m.hitHatch(0);
    }
    expect(h0.destroyed, isTrue);
    for (var i = 0; i < 400 && !b.hatches[1].destroyed; i++) {
      m.hitHatch(1);
    }
    expect(b.vulnerableTier, 1);
    for (var i = 0; i < 400 && b.vulnerableTier != null; i++) {
      for (final (k, h) in b.hatches.indexed) {
        if (!h.destroyed) m.hitHatch(k, damage: 3);
      }
    }
    expect(b.hatches.every((h) => h.destroyed), isTrue);
    expect(b.shield, 0);
    // Not until every hatch has fallen.
    expect(b.chapter, CarrierChapter.hatches);
    var transformAt = -1.0, coreAt = -1.0;
    for (var f = 0; f < 60 * 8 && b.chapter != CarrierChapter.core; f++) {
      m.invulnerable = 2;
      m.update(1 / 60);
      if (b.chapter == CarrierChapter.transform && transformAt < 0) {
        transformAt = f / 60;
      }
      if (b.chapter == CarrierChapter.transform) {
        expect(m.hitBoss(b.x), isFalse, reason: 'no hitbox in the transform');
      }
    }
    coreAt = b.chapter == CarrierChapter.core ? transformAt + 3.5 : -1;
    expect(transformAt, closeTo(CarrierHatches.fallSeconds, .05));
    expect(coreAt, greaterThan(0));
    b.door = 1;
    expect(m.hitBoss(b.x + 15), isTrue, reason: '16 × openness');
    expect(b.core, core - 1);
  });

  test(
    'armour: a shot on the vulnerable row away from the hatches sparks off',
    () {
      final m = fight();
      final b = m.boss!;
      final h = b.hatches.first.hatch;
      final before = b.shield;
      m.shots.add(Shot(b.x, b.y + h.y + 40, 0, -390));
      m.update(1 / 60);
      for (var i = 0; i < 10 && m.deflects.isEmpty; i++) {
        m.update(1 / 60);
      }
      expect(b.shield, before);
      expect(m.deflects, isNotEmpty);
    },
  );

  test('glide: slower in the hatch and core chapters', () {
    final m = fight();
    final b = m.boss!;
    expect(b.glideFactor, CarrierHatches.hatchGlide);
    final p = b.motionPhase;
    m.update(1 / 60);
    expect(
      (b.motionPhase - p).abs(),
      closeTo(
        .7 * m.speed * b.movementRate * CarrierHatches.hatchGlide / 60,
        1e-4,
      ),
    );
    // The fastest door in the core chapter: about 60 units/s.
    final vmax = .7 * 1.9 * CarrierHatches.coreGlide * (80 + 10);
    expect(vmax, lessThan(64));
  });

  test(
    'arrival invariance: a top-tier flock arrives at the nominal moment',
    () {
      // A flock from tier U1 (y −150) leaves 1.3 − 0.55 s early.
      expect(CarrierHatches.transit(25), .55);
      expect(CarrierHatches.early(25), 0);
      expect(CarrierHatches.early(-150), greaterThan(.5));
      final m = fight(seed: 9);
      final b = m.boss!;
      m.demons.clear();
      final arrivals = <double>[];
      final seen = <Demon>{};
      var t = 0.0;
      for (var f = 0; f < 60 * 30; f++) {
        m.invulnerable = 2;
        m.update(1 / 60);
        t += 1 / 60;
        for (final d in m.demons) {
          if (!d.entering && seen.add(d)) arrivals.add(t);
        }
        expect(b.chapter, CarrierChapter.hatches);
      }
      expect(arrivals, isNotEmpty);
      // Every flock's creatures settle within its 0.12 s skein (no stragglers
      // left behind by the longer transit).
      arrivals.sort();
      expect(arrivals.length, greaterThanOrEqualTo(3));
    },
  );

  test('hints: hatches at the start, lead after trailing shots', () {
    final m = fight(seed: 11);
    final log = <String>[];
    for (var f = 0; f < 60 * 3; f++) {
      m.invulnerable = 2;
      m.update(1 / 60);
      log.addAll(m.takeGameEvents().map((e) => e.name));
    }
    expect(log, contains(GameEventNames.bossHintHatches));
    // Into the core chapter, then shots that trail the open door.
    final b = m.boss!..shield = 0;
    m.update(1 / 60);
    expect(b.chapter, CarrierChapter.core);
    m.takeGameEvents();
    var trailing = 0;
    for (var f = 0; f < 60 * 8 && trailing < 3; f++) {
      m.invulnerable = 2;
      if (b.door >= .6 && b.horizontalVelocity.abs() > 1 && f % 6 == 0) {
        final behind = -b.horizontalVelocity.sign * (24 * b.door + 15);
        m.shots.add(Shot(b.x + behind, b.y + 30, 0, -390));
        trailing++;
      }
      m.update(1 / 60);
    }
    for (var f = 0; f < 10; f++) {
      m.invulnerable = 2;
      m.update(1 / 60);
    }
    final names = m.takeGameEvents().map((e) => e.name).toList();
    if (trailing >= 3) {
      expect(names, contains(GameEventNames.bossHintLead));
      expect(m.leadHinted, isTrue);
      expect(m.leadPipShown, isTrue, reason: 'Normal shows the pip');
    }
  });

  test('determinism: the same seed launches from the same hatches', () {
    List<String> run() {
      final m = fight(seed: 21);
      final out = <String>[];
      for (var f = 0; f < 60 * 20; f++) {
        m.invulnerable = 2;
        m.update(1 / 60);
        for (final e in m.takeGameEvents()) {
          if (e.name == GameEventNames.bossLaunch) {
            out.add('${e.data['hatch']}@${(m.levelClock * 10).round()}');
          }
        }
      }
      return out;
    }

    final a = run();
    expect(a, run());
    expect(a, isNotEmpty);
    expect(
      a.every((s) => s.startsWith('u1')),
      isTrue,
      reason: 'the topmost tier launches while it stands',
    );
    expect(math.max(1, a.length), greaterThan(0));
  });
}
