import 'package:demon_attack/game/insignia_rank.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/sprite_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools/insignia_share.dart' as share;

/// A seed whose elite-grunt roll is (or is not) under the pick, from a
/// bounded search.
double seedWhere(bool picked) {
  for (var i = 0; i < 200; i++) {
    final s = i * .25;
    final d = Demon(0, 0, 2, 2, s);
    if ((InsigniaRanks.roll(d) < 1 / InsigniaRanks.eliteGruntOneIn) == picked) {
      return s;
    }
  }
  throw StateError('no seed');
}

/// insignia-ranks (openspec/changes/insignia-ranks): the mark is rarer
/// than the rank; most of a wave wears nothing and the fang is kept for the
/// higher ranks.
void main() {
  final pick = seedWhere(true), skip = seedWhere(false);
  Demon demon(
    int kind,
    int maxHp,
    double seed, {
    bool elite = false,
    bool escort = false,
    EnemyArchetype archetype = EnemyArchetype.ordinary,
  }) => Demon(
    0,
    0,
    kind,
    maxHp,
    seed,
    elite: elite,
    isEscort: escort,
    archetype: archetype,
  );

  group('the mark per rank (design §2)', () {
    final table = <(String, Demon, RankMark)>[
      ('drone', demon(0, 1, pick), RankMark.none),
      ('drone, species 1', demon(1, 2, pick), RankMark.none),
      ('veteran by hit points, species 1', demon(1, 4, pick), RankMark.none),
      ('skirmisher, not picked', demon(2, 2, skip), RankMark.none),
      ('veteran, not picked', demon(3, 4, skip), RankMark.none),
      ('skirmisher, picked', demon(2, 2, pick), RankMark.winglet),
      ('veteran, picked', demon(3, 4, pick), RankMark.winglet),
      ('escort, picked', demon(3, 2, pick, escort: true), RankMark.crownlet),
      ('escort, not picked', demon(3, 2, skip, escort: true), RankMark.none),
      ('hunter', demon(0, 2, skip, elite: true), RankMark.fangWings),
      ('hunter, picked', demon(3, 3, pick, elite: true), RankMark.fangWings),
      (
        'shield sentinel',
        demon(0, 9, skip, archetype: EnemyArchetype.shieldSentinel),
        RankMark.wingCrown,
      ),
      (
        'armoured sentinel',
        demon(1, 12, pick, archetype: EnemyArchetype.armoredSentinel),
        RankMark.wingCrown,
      ),
    ];
    for (final (name, d, mark) in table) {
      test('$name -> ${mark.name}', () {
        expect(InsigniaRanks.markOf(d), mark);
      });
    }

    test('only hunters and sentinels wear a fang', () {
      for (final (_, d, mark) in table) {
        final rank = CombatAtlas.rankOf(d);
        expect(
          InsigniaRanks.hasFang(mark),
          rank == AlienRank.hunter || rank == AlienRank.sentinel,
        );
      }
    });

    test('a marked grunt is never below the skirmisher rank', () {
      for (final (_, d, mark) in table) {
        if (mark == RankMark.none) continue;
        expect(CombatAtlas.rankOf(d), isNot(AlienRank.drone));
      }
    });

    test('a pure read: damage and anger never change the mark', () {
      final d = demon(2, 3, pick);
      final before = InsigniaRanks.markOf(d);
      d.hp = 1;
      expect(InsigniaRanks.markOf(d), before);
    });

    test('a roster\'s seeds pick evenly (the Weyl roll)', () {
      // Roster seeds step by 1.7: any 10 consecutive creatures hold 1-3
      // picks at one in five, never a clump.
      for (var w = 1; w <= 8; w++) {
        for (var start = 0; start < 30; start++) {
          var n = 0;
          for (var i = start; i < start + 10; i++) {
            final d = demon(2, 2, i * 1.7 + w * .6);
            if (InsigniaRanks.eliteGrunt(d)) n++;
          }
          expect(n, inInclusiveRange(1, 3), reason: 'wave $w from $start');
        }
      }
    });
  });

  group('the marked share (design §3)', () {
    test('Normal, every tour: most of a wave wears no mark', () {
      // Bounded: 106 waves of at most 7200 frames each.
      final rows = <share.WaveShare>[];
      for (var route = 0; route < 5; route++) {
        for (var sector = 1; sector <= 4; sector++) {
          final waves = ArcadeModel.wavesFor(sector: sector, route: route);
          for (var wave = 1; wave <= waves; wave++) {
            rows.add(share.measure(Difficulty.normal, route, sector, wave));
          }
        }
      }
      for (var route = 0; route < 5; route++) {
        final r = rows.where((w) => w.route == route && w.samples > 0);
        double mean(double Function(share.WaveShare) f) =>
            r.fold<double>(0, (a, w) => a + f(w)) / r.length;
        expect(mean((w) => w.meanMarked), lessThanOrEqualTo(.20));
        expect(mean((w) => w.meanFang), lessThanOrEqualTo(.10));
        // Before: half the swarm or more wore a fang mark.
        expect(mean((w) => w.meanOld), greaterThan(.5));
      }
      for (final w in rows.where((w) => w.samples > 0)) {
        final at = 'tour ${w.route + 1} sector ${w.sector} wave ${w.wave}';
        expect(w.meanMarked, lessThanOrEqualTo(1 / 3), reason: at);
        expect(w.meanFang, lessThanOrEqualTo(.125), reason: at);
      }
    });
  });
}
