import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// Bonus level #1, Supply Run (openspec/changes/bonus-levels design §6).

ArcadeModel _supplyRun({int sector = 2, int route = 0}) {
  final m = ArcadeModel()
    ..startAt(sector: sector, route: route, bonus: 'supplyRun');
  reach(m, RunMode.playing);
  return m;
}

/// Steps combat with the ship safe and the swarm held off, [seconds] long.
void _idle(ArcadeModel m, double seconds) {
  for (var f = 0; f < seconds * 60 && m.combat; f++) {
    m.invulnerable = 5;
    m.update(1 / 60);
  }
}

/// Shoots [crate] open through the ordinary shot collision.

void main() {
  test('it replaces the sector with two thin scavenger waves', () {
    final regular = ArcadeModel()..startAt(sector: 2);
    final m = _supplyRun();
    expect(m.bonus?.id, 'supplyRun');
    expect(m.level, 2);
    expect(m.wavesPerLevel, 2);
    expect(regular.wavesPerLevel, greaterThan(2));
    expect(m.demons.length, lessThan(regular.demons.length));
    expect(m.demons.length, greaterThanOrEqualTo(3));
    expect(m.demons.every((d) => !d.isLarge && !d.elite), isTrue);
    expect(m.demons.every((d) => d.kind <= 1), isTrue);
    // Later routes too: no sentinel, no elite, whatever the wave.
    final late = _supplyRun(sector: 4, route: 3);
    for (var w = 1; w <= late.wavesPerLevel; w++) {
      expect(late.sentinelFor(w), isNull);
    }
    expect(late.demons.every((d) => !d.isLarge && !d.elite), isTrue);
  });

  test('kills drop no powers here; the crates carry them', () {
    final m = _supplyRun();
    m.bonusRun.crateLeft = 1e9; // no crate: only kills could drop
    for (var f = 0; f < 2400 && m.kills < 16 && m.combat; f++) {
      for (final d in List<Demon>.of(m.demons)) {
        if (d.entering) continue;
        while (m.demons.contains(d)) {
          m.hitDemon(d);
        }
        expect(m.pickups, isEmpty);
      }
      m.invulnerable = 5;
      m.update(1 / 60);
    }
    expect(m.kills, greaterThanOrEqualTo(8));
    expect(m.pickups, isEmpty);
  });

  test('crates come down on a clock, bounded on screen and in total', () {
    final m = _supplyRun();
    final crates = m.bonus!.crates;
    var most = 0;
    for (var f = 0; f < 60 * 60 && m.combat; f++) {
      m.invulnerable = 5;
      m.moveTo(18); // out of the way: nothing is opened
      m.update(1 / 60);
      most = most < m.supplyCrates.length ? m.supplyCrates.length : most;
    }
    expect(most, inInclusiveRange(2, crates.max));
    expect(m.bonusRun.cratesDropped, lessThanOrEqualTo(crates.total));
    expect(m.bonusRun.cratesDropped, greaterThanOrEqualTo(5));
  });

  test('a crate takes three hits, pays its points and drops its pickup', () {
    final m = _supplyRun();
    m.moveTo(18); // off to the side until the first crate is in the air
    _idle(m, 2.5);
    expect(m.supplyCrates, isNotEmpty);
    final crate = m.supplyCrates.first;
    final before = m.score, kills = m.kills;
    final events = <String>[];
    _openAndListen(m, crate, events);
    expect(m.bonusRun.cratesOpened, 1);
    expect(events, contains('bonusCrate.supplyRun'));
    // Crate points beyond whatever kills happened meanwhile.
    final killPoints = m.kills - kills;
    expect(m.score - before, greaterThanOrEqualTo(150));
    expect(killPoints, greaterThanOrEqualTo(0));
    expect(
      m.pickups.any((p) => (p.x - crate.x).abs() < 1) ||
          m.activePowers.isNotEmpty ||
          m.activeBonusPowers.isNotEmpty,
      isTrue,
    );
  });

  test('the two bonus powers come out of crates, in this level only', () {
    final m = _supplyRun();
    final seen = <String>{};
    for (var f = 0; f < 90 * 60 && m.combat; f++) {
      m.invulnerable = 5;
      m.moveTo(18);
      m.update(1 / 60);
      seen.addAll([
        for (final c in m.supplyCrates)
          if (c.bonus != null) c.bonus!.id,
      ]);
    }
    expect(seen, isNotEmpty);
    expect(seen.difference({'salvageMagnet', 'doubleScore'}), isEmpty);
  });

  test('double score doubles kill points while it lasts', () {
    final m = _supplyRun();
    m.bonusRun.crateLeft = 1e9;
    m.moveTo(18);
    _idle(m, 1.5);
    final d = m.demons.firstWhere((d) => !d.entering && d.dive == 0);
    final base = (100 + d.kind * 75 + (d.maxHp - 1) * 50).round();
    m.collectBonus(doubleScore);
    expect(m.hasBonusPower('doubleScore'), isTrue);
    final before = m.score;
    while (m.demons.contains(d)) {
      m.hitDemon(d);
    }
    expect(m.score - before, base * 2);
    _idle(m, doubleScore.seconds + .2);
    expect(m.hasBonusPower('doubleScore'), isFalse);
  });

  test('the salvage magnet pulls falling pickups to the ship', () {
    final m = _supplyRun();
    m.moveTo(60);
    _idle(m, .5);
    m.collectBonus(salvageMagnet);
    final p = Pickup(160, ArcadeModel.shipY - 80, Power.rapid);
    m.pickups.add(p);
    _idle(m, 1.2);
    expect(m.hasPower(Power.rapid), isTrue, reason: 'pulled in and collected');
  });

  test('the level\'s extra score is capped', () {
    final m = _supplyRun();
    final cap = (m.bonus!.scoring.capPar * m.sectorPar).round();
    expect(cap, greaterThan(0));
    m.collectBonus(doubleScore);
    for (var i = 0; i < 60; i++) {
      final c = SupplyCrate(100, 100, Power.spread);
      m.supplyCrates.add(c);
      c.hp = 0;
      m.supplyCrates.remove(c);
      // The collision's own bookkeeping, as model.dart does it.
      m.bonusCrateOpenedForTest(c);
    }
    expect(m.bonusRun.extra, cap);
  });

  test('the last kill pays the clear award and leaves by the fog', () {
    final m = _supplyRun();
    final events = <String>[];
    for (var w = 0; w < 2 && m.combat; w++) {
      final wave = m.wave;
      for (var f = 0; f < 2400 && m.combat && m.wave == wave; f++) {
        m.invulnerable = 5;
        for (final d in List<Demon>.of(m.demons)) {
          if (d.entering) continue;
          while (m.demons.contains(d)) {
            m.hitDemon(d);
          }
        }
        m.update(1 / 60);
        events.addAll([
          for (final e in m.takeGameEvents())
            if (GameEventNames.bonus.contains(e.name)) '${e.name}.${e.variant}',
        ]);
      }
    }
    expect(m.mode, RunMode.salvage);
    expect(events.first, 'bonusStart.supplyRun');
    expect(events.last, 'bonusCleared.supplyRun');
    // No ship lost: the clear and flawless shares of the sector's par.
    expect(m.bonusRun.award, (1.3 * m.sectorPar).round());
    expect(m.supplyCrates, isEmpty, reason: 'leftover crates burst open');
    // The ordinary sector change follows: Rout, Pursuit, Descent.
    expect(m.flow.kind, FlowKind.sectorChange);
    expect(m.bonusAhead, isNull);
    reach(m, RunMode.levelClear);
    reach(m, RunMode.travel);
    reach(m, RunMode.transition);
    expect(m.level, 3);
    expect(m.bonus, isNull);
    expect(m.wavesPerLevel, greaterThan(2));
    expect(m.bonusPowerTimers, isEmpty);
    expect(m.powerRules.isNone, isTrue);
  });

  test('a lost ship forfeits the flawless share only', () {
    final m = _supplyRun();
    m.invulnerable = 0;
    m.hitPlayer();
    expect(m.bonusRun.shipsLost, 1);
    for (var f = 0; f < 600 && !m.combat || m.shipAway; f++) {
      m.update(1 / 60);
    }
    for (var w = 0; w < 2 && m.mode != RunMode.salvage; w++) {
      final wave = m.wave;
      for (var f = 0; f < 3000 && m.combat && m.wave == wave; f++) {
        m.invulnerable = 5;
        for (final d in List<Demon>.of(m.demons)) {
          if (d.entering) continue;
          while (m.demons.contains(d)) {
            m.hitDemon(d);
          }
        }
        m.update(1 / 60);
      }
    }
    expect(m.mode, RunMode.salvage);
    expect(m.bonusRun.award, m.sectorPar);
  });

  test('the transition before it knows a bonus level is ahead', () {
    final m = ArcadeModel()..startAt(sector: 2);
    // Sector 3 becomes the bonus level of this run.
    m.bonusRun.plan = BonusPlan.forced(supplyRun, route: 0, sector: 3);
    reach(m, RunMode.playing);
    expect(m.bonus, isNull);
    m.endSector();
    expect(m.bonusAhead?.id, 'supplyRun');
    reach(m, RunMode.transition);
    expect(m.level, 3);
    expect(m.bonus?.id, 'supplyRun');
  });
}

void _openAndListen(ArcadeModel m, SupplyCrate crate, List<String> events) {
  for (var f = 0; f < 240 && m.supplyCrates.contains(crate); f++) {
    m.invulnerable = 5;
    m.moveTo(crate.x);
    m.update(1 / 60);
    events.addAll([
      for (final e in m.takeGameEvents()) '${e.name}.${e.variant}',
    ]);
  }
  expect(m.supplyCrates.contains(crate), isFalse, reason: 'crate not opened');
}
