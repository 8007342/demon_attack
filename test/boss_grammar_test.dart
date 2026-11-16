import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:flutter_test/flutter_test.dart';

/// boss-grandeur §7 on the v2 Thornwake carriers (boss-carrier-wire).
void main() {
  test('tour assemblies: 9 / 13 / 17 / 21 / 24 modules, extent ×1.00 → ×1.32', () {
    for (var t = 0; t < 5; t++) {
      final a = BossGrammar.tour(t);
      expect(a.count, BossGrammar.counts[t], reason: 'tour ${t + 1}');
      expect(a.extent, BossGrammar.extents[t]);
      expect(a.hull, BossGrammar.baked[t].first);
      expect(a.symmetric, isTrue);
      expect(BossGrammar.withinBudgets(a), isTrue, reason: 'tour ${t + 1}');
      expect(a.modules.map((m) => m.id).toSet(), hasLength(a.count),
          reason: 'unique ids');
      if (t > 0) {
        final prev = BossGrammar.tour(t - 1);
        expect(a.area, greaterThan(prev.area), reason: 'larger each tour');
        expect(a.ornaments.length, greaterThan(prev.ornaments.length),
            reason: 'more guns, spikes and barriers (R8.4)');
      }
    }
    expect(
      [for (final m in BossGrammar.tour(0).modules) m.id],
      ['carapace', 'prow', 'wingL', 'wingR', 'spines', 'emitterL', 'emitterR',
        'blisterL', 'blisterR'],
    );
  });

  test('every packed hull matches its grammar assembly (ids, detach ranks)', () {
    expect(BossHeroAtlas.hulls, isNotEmpty);
    for (final h in BossHeroAtlas.hulls.values) {
      final t = BossGrammar.baked.indexWhere((c) => c.contains(h.key));
      expect(t, greaterThanOrEqualTo(0), reason: '${h.key} is a baked hull');
      expect(h.replaces, BossGrammar.classes[t], reason: h.key);
      final a = BossGrammar.tour(t, set: BossGrammar.baked[t].indexOf(h.key));
      expect(a.hull, h.key);
      expect(h.set, a.setName);
      expect(
        a.modules.map((m) => m.id).toSet(),
        h.modules.map((m) => m.id).toSet(),
        reason: h.key,
      );
      final order = {for (final m in h.modules) m.id: m.detach};
      for (final m in a.modules) {
        expect(m.detachOrder, order[m.id], reason: '${h.key} ${m.id}');
      }
      for (final m in h.modules) {
        final slot = m.module.split('.').first;
        final set = m.module.split('.').last;
        expect(a.modules.firstWhere((x) => x.id == m.id).slot.name, slot);
        expect(a.modules.firstWhere((x) => x.id == m.id).set, set,
            reason: '${h.key} ${m.id}');
      }
    }
    // All three tour-1 set combinations are in the game.
    for (final k in BossGrammar.baked[0]) {
      expect(BossHeroAtlas.hulls, contains(k));
    }
  });

  test('seeded assembly beyond tour 5: deterministic, within budgets', () {
    for (var route = 5; route < 12; route++) {
      for (final seed in [1, 1982, 42]) {
        final a = BossGrammar.assemble(route: route, seed: seed);
        final b = BossGrammar.assemble(route: route, seed: seed);
        expect([for (final m in a.modules) m.id], [for (final m in b.modules) m.id]);
        expect(a.hull, b.hull);
        expect(a.tour, route);
        expect(a.count, lessThanOrEqualTo(BossGrammar.maxModules));
        expect(a.symmetric, isTrue);
        expect(BossGrammar.withinBudgets(a), isTrue);
        expect(a.count, greaterThanOrEqualTo(17));
      }
    }
    final hulls = {
      for (var s = 0; s < 20; s++) BossGrammar.assemble(route: 6, seed: s).hull,
    };
    expect(hulls.length, greaterThanOrEqualTo(3), reason: 'later runs vary');
  });

  test('set combinations per run: a seeded pick (R8.6), visual only', () {
    final picks = {
      for (var v = 0; v < 40; v++) BossGrammar.forRun(route: 0, variant: v).hull,
    };
    expect(picks, BossGrammar.baked[0].toSet());
    // From the run seed: deterministic, and an unseeded run is variant 0
    // (the calibrated campaign draws the first combination).
    expect(BossGrammar.variantFor(null, 0), 0);
    expect(BossGrammar.forRun(route: 0, variant: 0).hull, 'carrier1-thorn');
    expect(BossGrammar.variantFor(12345, 0), BossGrammar.variantFor(12345, 0));
    final seeded = {
      for (var s = 1; s < 60; s++)
        BossGrammar.forRun(route: 0, variant: BossGrammar.variantFor(s, 0)).hull,
    };
    expect(seeded, BossGrammar.baked[0].toSet(), reason: 'every set occurs');
    // A combination that is not packed is never picked while one is.
    expect(
      BossGrammar.forRun(route: 0, variant: 1, packed: {'carrier1-shroud'}).hull,
      'carrier1-shroud',
    );
    expect(BossGrammar.forRun(route: 2, variant: 7).count, 17);
  });

  test('every assembly shares the simulation geometry; only the prow dresses '
      'the turrets and bays', () {
    for (var route = 0; route < 9; route++) {
      final a = BossGrammar.forRun(route: route, variant: route * 13);
      // The prow (functional windows) is always there, never detaches, and
      // the carapace sinks last (no detach rank).
      final prows = a.modules.where((m) => m.slot == BossSlot.prow).toList();
      expect(prows, hasLength(1));
      expect(prows.single.detachOrder, isNull);
      expect(prows.single.spec.core, isTrue, reason: 'core texel class');
      expect(a.modules.where((m) => m.slot == BossSlot.carapace).single.detachOrder,
          isNull);
      for (final m in a.modules) {
        expect(
          m.spec.play == BossModulePlay.none || m.slot == BossSlot.prow,
          isTrue,
          reason: m.id,
        );
      }
      // Each form change tears away the next rank, in order.
      expect(a.slotAtForm(1), BossSlot.spines);
      expect(a.ranks.first, 1);
    }
    // The windows themselves are the carrier's, identical for all hulls.
    expect(BossAtlas.coreWindow, (x: 0.0, y: 25.0, w: 32.0, h: 22.0));
    expect(BossAtlas.solidBody, (halfWidth: 78.0, top: -25.0, bottom: 43.0));
  });


  test('packed view sets: anchors within 3 units, ≤ 16 MB per hull', () {
    for (final h in BossHeroAtlas.hulls.values) {
      expect(h.residentBytes, lessThanOrEqualTo(16 << 20), reason: h.key);
      expect(h.views, hasLength(6), reason: '${h.key}: 3 pitches × yaw 0/+12');
      for (final v in h.views.values) {
        final core = v.anchors['core']!;
        expect((core.$1 - BossAtlas.coreWindow.x).abs(), lessThanOrEqualTo(3));
        expect((core.$2 - BossAtlas.coreWindow.y).abs(), lessThanOrEqualTo(3));
        for (final (k, sx) in [('bayL', -1.0), ('bayR', 1.0)]) {
          final p = v.anchors[k]!;
          expect((p.$1 - sx * BossAtlas.bayWindow.x).abs(), lessThanOrEqualTo(3),
              reason: '${h.key} p${v.pitch} y${v.yaw} $k');
          expect((p.$2 - BossAtlas.bayWindow.y).abs(), lessThanOrEqualTo(3));
        }
      }
    }
  });
}
