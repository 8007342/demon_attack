import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:flutter_test/flutter_test.dart';

/// boss-grandeur §7: the composable boss grammar.
void main() {
  test('tour assemblies: 5 / 8 / 11 / 14 / 17 modules, extent ×1.0 → ×1.6', () {
    for (var t = 0; t < 5; t++) {
      final a = BossGrammar.tour(t);
      expect(a.count, BossGrammar.counts[t], reason: 'tour ${t + 1}');
      expect(a.extent, BossGrammar.extents[t]);
      expect(a.hull, BossGrammar.hulls[t]);
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
  });

  test('the frigate assembly matches its packed view set', () {
    final a = BossGrammar.tour(0);
    final hero = BossHeroAtlas.hulls['frigate'];
    if (hero == null) return; // not packed in this checkout
    expect(
      a.modules.map((m) => m.id).toSet(),
      hero.modules.map((m) => m.id).toSet(),
    );
    // The same detach order: the tower first, then the engines.
    final order = {for (final m in hero.modules) m.id: m.detach};
    for (final m in a.modules) {
      expect(m.detachOrder, order[m.id], reason: m.id);
    }
  });

  test('seeded assembly beyond tour 5: deterministic, within budgets', () {
    for (var route = 5; route < 12; route++) {
      for (final seed in [1, 1982, 42]) {
        final a = BossGrammar.assemble(route: route, seed: seed);
        final b = BossGrammar.assemble(route: route, seed: seed);
        expect([for (final m in a.modules) m.id], [for (final m in b.modules) m.id]);
        expect(a.count, lessThanOrEqualTo(BossGrammar.maxModules));
        expect(a.symmetric, isTrue);
        expect(BossGrammar.withinBudgets(a), isTrue);
        expect(a.count, greaterThanOrEqualTo(17));
      }
    }
    final variants = {
      for (var s = 0; s < 20; s++)
        BossGrammar.assemble(route: 6, seed: s).modules.map((m) => m.id).join(','),
    };
    expect(variants.length, greaterThan(3), reason: 'later runs vary');
  });

  test('module sets per run are a seeded pick (R8.6), visual only', () {
    final picks = {
      for (var v = 0; v < 40; v++) BossGrammar.forRun(route: 2, variant: v, sets: 3).set,
    };
    expect(picks, {0, 1, 2});
    expect(BossGrammar.forRun(route: 2, variant: 7, sets: 1).set, 0);
    expect(BossGrammar.forRun(route: 2, variant: 7, sets: 3).count, 11);
  });

  test('every assembly shares the simulation geometry; gameplay modules only '
      'dress existing turrets and bays', () {
    for (var route = 0; route < 9; route++) {
      final a = BossGrammar.forRun(route: route, variant: route * 13);
      // The bow (functional windows) is always there, never detaches, and
      // nothing else is mounted on it.
      final bows = a.modules.where((m) => m.slot == BossSlot.bow).toList();
      expect(bows, hasLength(1));
      expect(bows.single.detachOrder, isNull);
      expect(a.modules.where((m) => m.slot == BossSlot.spine).single.detachOrder,
          isNull);
      for (final m in a.modules) {
        expect(
          m.spec.play == BossModulePlay.none ||
              (m.spec.play == BossModulePlay.turret &&
                  (m.slot == BossSlot.bow || m.slot == BossSlot.turret)) ||
              (m.spec.play == BossModulePlay.bay && m.slot == BossSlot.bayPod),
          isTrue,
        );
      }
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
