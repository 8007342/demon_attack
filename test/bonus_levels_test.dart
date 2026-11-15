import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/game/interlude.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show clearWave, reach;

/// The bonus-levels framework (openspec/changes/bonus-levels): selection,
/// run modifiers, the radio slot, persistence and the safety rule that a
/// run without a plan is the calibrated campaign.

/// Seconds of a scripted pilot (a slow weave, auto-fire): what the run
/// looked like once a second.
List<String> _trace(ArcadeModel m, int seconds) {
  final out = <String>[];
  for (var f = 0; f < seconds * 60; f++) {
    m.moveTo(180 + 120 * ((f ~/ 90).isEven ? 1 : -1) * ((f % 90) / 90));
    m.update(1 / 60);
    m.takeEvents();
    m.takeGameEvents();
    if (f % 60 == 59) {
      out.add(
        '${m.mode.name} L${m.level} W${m.wave} s${m.score} k${m.kills} '
        'l${m.lives} d${m.demons.length} p${m.pickups.length} '
        '${m.activePowers.map((p) => p.name).join('+')} '
        'x${m.shipX.toStringAsFixed(2)}',
      );
    }
  }
  return out;
}

/// The first seed from [from] whose standard plan satisfies [test].
int _seedWhere(bool Function(BonusPlan) test, {int from = 1}) {
  for (var s = from; s < from + 5000; s++) {
    if (test(BonusPlan.forRun(s))) return s;
  }
  fail('no such seed');
}

void main() {
  group('selection', () {
    test('the same run seed gives the same plan', () {
      for (var s = 0; s < 200; s++) {
        expect(BonusPlan.forRun(s).toString(), BonusPlan.forRun(s).toString());
      }
    });

    test('about once per run, early, never the opening or a carrier', () {
      const n = 4000;
      var runs = 0;
      final routes = List.filled(5, 0);
      for (var s = 0; s < n; s++) {
        final plan = BonusPlan.forRun(s * 7919 + 3);
        expect(plan.slots.length, lessThanOrEqualTo(1));
        for (final slot in plan.slots) {
          runs++;
          routes[slot.route]++;
          expect(slot.sector, inInclusiveRange(2, 4));
          expect(slot.route, inInclusiveRange(0, 3));
          expect(slot.level.fits(slot.route, slot.sector), isTrue);
        }
      }
      expect(runs / n, closeTo(BonusTuning.standard.runChance, .03));
      // Weighted toward the first tours (5 : 3 : 1 : 1).
      expect(routes[0] / runs, closeTo(.5, .04));
      expect(routes[1] / runs, closeTo(.3, .04));
      expect(routes[4], 0);
    });

    test('the odds are tunable; off means never', () {
      for (var s = 0; s < 300; s++) {
        expect(
          identical(
            BonusPlan.forRun(s, tuning: BonusTuning.off),
            BonusPlan.none,
          ),
          isTrue,
        );
        final always = BonusPlan.forRun(
          s,
          tuning: const BonusTuning(runChance: 1, maxPerRun: 2),
        );
        expect(always.slots.length, 2);
        expect(always.slots[0].route, isNot(always.slots[1].route));
      }
    });

    test('a level appended to the catalogue keeps old seeds\' slots', () {
      const extra = BonusLevelDef(id: 'extra', label: 'EXTRA', weight: 1);
      for (var s = 0; s < 300; s++) {
        final a = BonusPlan.forRun(s);
        final b = BonusPlan.forRun(s, levels: const [...bonusLevels, extra]);
        expect(b.slots.length, a.slots.length);
        for (var i = 0; i < a.slots.length; i++) {
          expect(b.slots[i].route, a.slots[i].route);
          expect(b.slots[i].sector, a.slots[i].sector);
        }
        expect(b.modifier?.id, a.modifier?.id);
      }
    });

    test('run modifiers fire at their own chance, at most one per run', () {
      const n = 6000;
      final seen = <String, int>{};
      for (var s = 0; s < n; s++) {
        final m = BonusPlan.forRun(s * 104729 + 11).modifier;
        if (m != null) seen[m.id] = (seen[m.id] ?? 0) + 1;
      }
      expect(seen.keys.toSet(), {for (final m in runModifiers) m.id});
      expect(seen['noShield']! / n, closeTo(.05, .012));
      expect(seen['spreadOnly']! / n, closeTo(.03 * .95, .012));
    });

    test('catalogue ids are unique and crates name known powers', () {
      expect({for (final l in bonusLevels) l.id}.length, bonusLevels.length);
      expect({for (final p in bonusPowers) p.id}.length, bonusPowers.length);
      for (final l in bonusLevels) {
        expect(l.sectors.every((s) => s >= 1 && s <= 4), isTrue);
        expect(l.waves.count, inInclusiveRange(1, 7));
        for (final id in l.crates.bonusPowers) {
          expect(bonusPowerById(id), isNotNull, reason: '${l.id}: $id');
        }
      }
    });
  });

  group('power rules', () {
    double never() => fail('no draw expected');

    test('no rules: the drop is untouched and nothing is drawn', () {
      for (final p in Power.values) {
        expect(PowerRules.none.resolve(p, never), p);
      }
    });

    test('a ban moves to the next allowed power; all banned drops nothing', () {
      const rules = PowerRules(banned: {Power.shield, Power.powerful});
      expect(rules.resolve(Power.shield, never), Power.large);
      expect(rules.resolve(Power.spread, never), Power.spread);
      expect(
        PowerRules(banned: Power.values.toSet()).resolve(Power.rapid, never),
        isNull,
      );
    });

    test('only-X turns every drop into X', () {
      const rules = PowerRules(only: Power.spread, banned: {Power.spread});
      for (final p in Power.values) {
        expect(rules.resolve(p, never), Power.spread);
      }
    });

    test('a chance rule converts about its share of drops', () {
      const rules = PowerRules(chances: [PowerChance(Power.large, .35)]);
      final rng = BonusPlan.levelRng(5, 0, 2);
      var large = 0;
      for (var i = 0; i < 4000; i++) {
        if (rules.resolve(Power.rapid, rng.nextDouble) == Power.large) large++;
      }
      expect(large / 4000, closeTo(.35, .03));
    });

    test('a level\'s rules sit on top of the run modifier\'s', () {
      const outer = PowerRules(banned: {Power.shield}, only: Power.rapid);
      const inner = PowerRules(banned: {Power.large}, killDrops: false);
      final merged = outer.merge(inner);
      expect(merged.banned, {Power.shield, Power.large});
      expect(merged.only, Power.rapid);
      expect(merged.killDrops, isFalse);
      expect(
        outer.merge(const PowerRules(only: Power.spread)).only,
        Power.spread,
      );
      expect(identical(outer.merge(PowerRules.none), outer), isTrue);
    });
  });

  group('safety', () {
    test('a run without a run seed has no plan', () {
      final m = ArcadeModel()..start();
      expect(identical(m.bonusPlan, BonusPlan.none), isTrue);
      expect(m.bonus, isNull);
      expect(m.powerRules.isNone, isTrue);
      expect(m.checkpoint().containsKey('runSeed'), isFalse);
    });

    test('a seeded run whose plan is empty plays the calibrated campaign', () {
      final seed = _seedWhere((p) => identical(p, BonusPlan.none));
      final plain = ArcadeModel()..start();
      final seeded = ArcadeModel()..start(runSeed: seed);
      expect(_trace(seeded, 150), _trace(plain, 150));
    });

    test('a seeded run is the calibrated campaign until its bonus level', () {
      // A bonus level in sector 3 or 4 of route 0 and no modifier: all of
      // sectors 1 and 2 must match the unseeded run, draw for draw.
      final seed = _seedWhere(
        (p) =>
            p.modifier == null &&
            p.slots.length == 1 &&
            p.slots[0].route == 0 &&
            p.slots[0].sector >= 3,
      );
      final plain = ArcadeModel()..start();
      final seeded = ArcadeModel()..start(runSeed: seed);
      final a = _trace(plain, 150), b = _trace(seeded, 150);
      final sector1or2 = [
        for (var i = 0; i < a.length; i++)
          if (a[i].contains(' L1 ') || a[i].contains(' L2 ')) i,
      ];
      expect(sector1or2.length, greaterThan(60));
      for (final i in sector1or2) {
        expect(b[i], a[i], reason: 'second $i');
      }
    });

    test('same seed, same run: a bonus run is deterministic', () {
      final seed = _seedWhere(
        (p) => p.slots.isNotEmpty && p.slots[0].route == 0,
      );
      List<String> run() {
        final m = ArcadeModel()..start(runSeed: seed);
        // Jump to the slot: same seed, same forced position.
        final slot = m.bonusPlan.slots[0];
        m.startAt(sector: slot.sector, route: slot.route, runSeed: seed);
        expect(m.bonus, isNotNull);
        return _trace(m, 90);
      }

      expect(run(), run());
    });

    test('a run modifier never touches the simulation\'s own PRNG', () {
      final seed = _seedWhere(
        (p) => p.modifier?.id == 'heavyOrdnance' && p.slots.isEmpty,
      );
      final plain = ArcadeModel()..start();
      final seeded = ArcadeModel()..start(runSeed: seed);
      for (var f = 0; f < 60 * 60; f++) {
        plain.update(1 / 60);
        seeded.update(1 / 60);
      }
      // Drops may differ; the swarm and the dice do not.
      expect(seeded.demons.length, plain.demons.length);
      expect(seeded.random.nextDouble(), plain.random.nextDouble());
    });
  });

  group('run modifiers in play', () {
    ArcadeModel withModifier(String id) =>
        ArcadeModel()..startAt(sector: 1, modifier: id);

    test('no-shield runs never drop a shield', () {
      final m = withModifier('noShield');
      reach(m, RunMode.playing);
      final seen = <Power>{};
      for (var i = 0; i < 12 && m.combat; i++) {
        clearWave(m);
        seen.addAll(m.pickups.map((p) => p.power));
        if (!m.combat) break;
      }
      expect(seen, isNotEmpty);
      expect(seen, isNot(contains(Power.shield)));
    });

    test('only-spread runs drop spread alone', () {
      final m = withModifier('spreadOnly');
      reach(m, RunMode.playing);
      final seen = <Power>{};
      for (var i = 0; i < 12 && m.combat; i++) {
        clearWave(m);
        seen.addAll(m.pickups.map((p) => p.power));
      }
      expect(seen, {Power.spread});
    });

    test('the modifier is announced once, by event', () {
      final m = withModifier('noShield');
      reach(m, RunMode.playing);
      final names = <String>[];
      for (var f = 0; f < 120; f++) {
        m.update(1 / 60);
        names.addAll([
          for (final e in m.takeGameEvents())
            if (e.name == GameEventNames.runModifier) '${e.name}.${e.variant}',
        ]);
      }
      expect(names, ['runModifier.noShield']);
    });
  });

  group('radio', () {
    InterludeContext ctx({String? bonus, bool revisit = true}) =>
        InterludeContext(
          difficulty: Difficulty.normal,
          level: 3,
          route: 1,
          window: 9,
          revisit: revisit,
          bonus: bonus,
        );

    test('the transition into a bonus level carries its entry call', () {
      for (var seed = 0; seed < 30; seed++) {
        final plan = InterludePlanner(seed: seed)
            .planRadio(ctx(bonus: 'supplyRun'));
        expect(plan!.radio!.spec.name, 'bonusEntry.supplyRun');
        expect(plan.radio!.category, RadioCategory.bonusEntry);
      }
    });

    test('a level without its own lines gets the general entry call', () {
      final plan = InterludePlanner(seed: 1).planRadio(ctx(bonus: 'unknown'));
      expect(plan!.radio!.spec.name, 'bonusEntry');
    });

    test('without a bonus level the slot is exactly as before', () {
      for (var seed = 0; seed < 30; seed++) {
        final a = InterludePlanner(seed: seed).planRadio(ctx());
        expect(a!.radio!.spec.name, startsWith('frontCall'));
      }
      expect(RadioCategory.drawn, isNot(contains(RadioCategory.bonusEntry)));
    });

    test('every bonus line borrows a recorded clip or is a written line', () {
      final bonus = [
        for (final e in commsHumanTriggers.entries)
          if (e.key.startsWith('bonus') || e.key.startsWith('runModifier'))
            e.value,
      ];
      expect(bonus.length, greaterThanOrEqualTo(10));
      for (final spec in bonus) {
        for (final line in spec.lines) {
          // Pending the voice batch (tillandsias#1103): a borrowed clip,
          // or (bonus-briefing) a silent written line with its own words.
          if (line.silent) {
            expect(line.clip, line.id, reason: line.id);
          } else {
            expect(line.clip, isNot(line.id), reason: line.id);
          }
          expect(line.text, isNotEmpty, reason: line.id);
        }
      }
      for (final l in bonusLevels) {
        expect(commsHumanTriggers, contains('bonusEntry.${l.id}'));
      }
      for (final m in runModifiers) {
        expect(commsHumanTriggers, contains('runModifier.${m.id}'));
      }
    });
  });

  group('persistence', () {
    test('a checkpoint carries the run seed and restores the plan', () {
      final seed = _seedWhere(
        (p) => p.slots.isNotEmpty && p.slots[0].route == 0,
      );
      final m = ArcadeModel()..start(runSeed: seed);
      final slot = m.bonusPlan.slots[0];
      m.startAt(sector: slot.sector, route: slot.route, runSeed: seed);
      final saved = m.checkpoint();
      expect(saved['runSeed'], seed);
      final restored = ArcadeModel();
      expect(restored.restoreCheckpoint(saved), isTrue);
      expect(restored.bonus?.id, slot.level.id);
      expect(restored.wavesPerLevel, slot.level.waves.count);
      expect(restored.bonusPlan.toString(), m.bonusPlan.toString());
    });

    test('an older checkpoint restores a run without a plan', () {
      final m = ArcadeModel();
      expect(
        m.restoreCheckpoint({
          'difficulty': 'normal',
          'routeIndex': 1,
          'sector': 3,
          'wave': 4,
        }),
        isTrue,
      );
      expect(identical(m.bonusPlan, BonusPlan.none), isTrue);
      expect(m.bonus, isNull);
      expect(m.wave, 4);
    });
  });
}
