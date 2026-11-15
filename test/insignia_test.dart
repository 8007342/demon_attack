import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/sprite_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

/// alien-insignia (openspec/changes/alien-insignia, design §7): the rank
/// ladder from game data, head anchors, glyph contrast, fixed size under
/// zoom, the overlap rule and the reveal gate.
void main() {
  group('rankOf (design §1)', () {
    Demon demon(
      int kind,
      int maxHp, {
      bool elite = false,
      EnemyArchetype archetype = EnemyArchetype.ordinary,
    }) => Demon(0, 0, kind, maxHp, 0, elite: elite, archetype: archetype);

    final table = <(Demon, AlienRank)>[
      (demon(0, 1), AlienRank.drone),
      (demon(1, 2), AlienRank.drone),
      (demon(2, 1), AlienRank.skirmisher),
      (demon(3, 2), AlienRank.skirmisher),
      (demon(0, 3), AlienRank.skirmisher),
      (demon(1, 4), AlienRank.veteran),
      (demon(2, 5), AlienRank.veteran),
      (demon(0, 1, elite: true), AlienRank.hunter),
      (demon(3, 5, elite: true), AlienRank.hunter),
      (
        demon(0, 9, archetype: EnemyArchetype.shieldSentinel),
        AlienRank.sentinel,
      ),
      (
        demon(1, 12, archetype: EnemyArchetype.armoredSentinel),
        AlienRank.sentinel,
      ),
    ];
    for (final (d, rank) in table) {
      test('kind ${d.kind} maxHp ${d.maxHp} elite ${d.elite} '
          '${d.archetype.name} -> ${rank.name}', () {
        expect(CombatAtlas.rankOf(d), rank);
      });
    }

    test('is a pure read: damage never changes the rank', () {
      final d = demon(2, 4);
      final before = CombatAtlas.rankOf(d);
      d.hp = 1;
      expect(CombatAtlas.rankOf(d), before);
      expect(d.maxHp, 4);
    });
  });

  group('head anchors (design §3)', () {
    test('every flight, flash and action cell has a skull top above the '
        'centre, near the cell middle', () {
      for (var k = 0; k < 4; k++) {
        final b = CombatAtlas.base(k);
        for (var r = 0; r < 5; r++) {
          for (var col = 0; col < 30; col++) {
            final a = CombatAtlas.headAnchor(b + r, col);
            expect(a.dx.abs(), lessThan(8), reason: 'k$k r$r c$col');
            expect(a.dy, inInclusiveRange(-16, -6), reason: 'k$k r$r c$col');
          }
        }
        for (final col in [0, 3, 4, 8, 20, 29, 30, 31]) {
          final a = CombatAtlas.headAnchor(b + 7, col);
          expect(a.dy, inInclusiveRange(-16, -4), reason: 'action c$col');
        }
      }
    });

    test('the anchor follows the flap lift and leans into banks', () {
      final b = CombatAtlas.base(0);
      // Neutral flap frames 0 (lift 0) and 2 (lift -2): the head rises.
      final level = CombatAtlas.headAnchor(b, 10);
      final up = CombatAtlas.headAnchor(b, 12);
      expect(up.dy, level.dy - 2);
      // Banking left / right shifts the head to that side.
      expect(CombatAtlas.headAnchor(b, 8).dx, lessThan(level.dx));
      expect(CombatAtlas.headAnchor(b, 28).dx, greaterThan(level.dx));
    });

    test('cells without a head fall back to the species value plus lift', () {
      final death = CombatAtlas.headAnchor(CombatAtlas.deathRow(2), 14);
      expect(death, Offset(0, CombatAtlas.neutralHeadTop[2] - 32.0));
      final lifted = CombatAtlas.headAnchor(
        CombatAtlas.eliteRow(1),
        3,
        lift: -2,
      );
      expect(lifted.dy, CombatAtlas.neutralHeadTop[1] - 32.0 - 2);
    });
  });
}
