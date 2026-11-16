import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/game/bonus/levels/storm_cell.dart';
import 'package:demon_attack/game/interlude.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// Bonus level #2, Stormfront (openspec/changes/bonus-levels,
/// specs/bonus-level-stormfront).

ArcadeModel _storm({
  int sector = 3,
  int route = 0,
  int seed = 1982,
  Difficulty difficulty = Difficulty.normal,
}) {
  final m = ArcadeModel(seed: seed)
    ..startAt(
      sector: sector,
      route: route,
      bonus: 'stormfront',
      difficulty: difficulty,
    );
  reach(m, RunMode.playing);
  return m;
}

StormfrontMechanic _mech(ArcadeModel m) =>
    m.bonusMechanic! as StormfrontMechanic;

/// Steps until a tell is running (the ship protected meanwhile).
StormStrike _untilTell(ArcadeModel m, {bool Function(StormStrike)? where}) {
  final cell = _mech(m).cell;
  for (var f = 0; f < 60 * 60 && m.combat; f++) {
    final tells = cell.strikes.where(
      (s) => s.telling && (where == null || where(s)),
    );
    if (tells.isNotEmpty) return tells.first;
    m.invulnerable = 5;
    m.update(1 / 60);
  }
  fail('no tell within a minute');
}

/// Parks the ship at [x] at once (as a pilot who was already there).
void _park(ArcadeModel m, double x) {
  m
    ..shipX = x
    ..targetX = x
    ..shipVx = 0;
}

/// Puts [n] present one-hit creatures on the column at [x], well above
/// the ship; every other creature is moved far aside.
List<Demon> _column(ArcadeModel m, double x, int n) {
  final present = m.demons.where((d) => !d.entering).toList();
  expect(present.length, greaterThanOrEqualTo(n));
  final out = <Demon>[];
  for (var i = 0; i < present.length; i++) {
    final d = present[i];
    if (i < n) {
      d
        ..x = x + (i - (n - 1) / 2) * 12
        ..hp = 1;
      out.add(d);
    } else {
      d.x = x < 180 ? 340 : 20;
    }
  }
  return out;
}

void main() {
  test('it is in the catalogue, with its rod and its mechanic', () {
    expect(
      bonusLevels.map((l) => l.id),
      containsAll(['supplyRun', 'stormfront']),
    );
    // Appended after level #1: old seeds keep their slots (bonus_plan).
    expect(bonusLevels.indexOf(stormfront), greaterThan(0));
    expect(bonusPowerById('lightningRod'), same(lightningRod));
    expect(stormfront.mechanic, isNotNull);
    expect(stormfront.sectors, {2, 3, 4});
    expect(stormfront.scoring.capPar, greaterThan(0));
  });

  test('a seeded run can draw it, and the draw is stable', () {
    var seen = 0;
    for (var seed = 0; seed < 200; seed++) {
      final plan = BonusPlan.forRun(seed);
      expect(plan.toString(), BonusPlan.forRun(seed).toString());
      if (plan.slots.any((s) => s.level.id == 'stormfront')) seen++;
    }
    expect(seen, greaterThan(20));
  });

  // bonus-balance: the sector's own waves and sentinels, a tenth more
  // creatures in each opening roster (the storm kills some of them).
  test('it keeps the sector\'s waves, with a denser swarm', () {
    final regular = ArcadeModel()..startAt(sector: 3, route: 2);
    final m = _storm(route: 2);
    expect(m.bonus?.id, 'stormfront');
    expect(m.level, 3);
    expect(m.wavesPerLevel, regular.wavesPerLevel);
    for (var w = 1; w <= m.wavesPerLevel; w++) {
      expect(m.sentinelFor(w), regular.sentinelFor(w));
    }
    expect(m.demons.length, greaterThan(regular.demons.length));
    expect(
      m.demons.length,
      lessThanOrEqualTo((regular.demons.length * 1.15).ceil()),
    );
    expect(m.bonusMechanic, isA<StormfrontMechanic>());
    // A regular sector has no mechanic.
    expect(regular.bonusMechanic, isNull);
  });

  test('no tell begins before combat or while the ship is away', () {
    final m = ArcadeModel()..startAt(sector: 3, bonus: 'stormfront');
    final cell = _mech(m).cell;
    while (m.mode != RunMode.playing) {
      m.update(1 / 60);
      expect(cell.started, 0);
    }
    final s = _untilTell(m, where: (s) => s.aim == StrikeAim.ship);
    // The ship is lost mid-tell (some other hit): the tell fizzles.
    m.invulnerable = 0;
    m.hitPlayer();
    expect(m.shipAway, isTrue);
    final lives = m.lives;
    final started = cell.started;
    for (var f = 0; f < 600 && m.shipAway; f++) {
      m.update(1 / 60);
      expect(cell.strikes.where((s) => s.telling), isEmpty);
    }
    expect(s.landed, isFalse);
    expect(s.fizzled, isTrue);
    expect(cell.started, started);
    expect(m.lives, lives);
  });

  test('a baited bolt hits the creatures in its column and not the ship', () {
    final m = _storm();
    _park(m, 120);
    final s = _untilTell(m, where: (s) => s.aim == StrikeAim.ship);
    expect(s.x, closeTo(120, 1));
    final victims = _column(m, s.x, 2);
    final far = m.demons.where((d) => !victims.contains(d)).toList();
    // The pilot slides away; the column stays where the tell began.
    _park(m, 300);
    final lives = m.lives, kills = m.kills, score = m.score;
    final events = <GameEvent>[];
    for (var f = 0; f < 300 && s.telling; f++) {
      _column(m, s.x, 2); // hold them under the bolt
      _park(m, 300);
      m.invulnerable = 0;
      m.shots.clear(); // the bolt alone decides this
      m.update(1 / 60);
      events.addAll(m.takeGameEvents());
    }
    expect(s.landed, isTrue);
    expect(s.x, closeTo(120, 1));
    expect(s.kills, 2);
    expect(m.kills, kills + 2);
    expect(victims.every((d) => !m.demons.contains(d)), isTrue);
    expect(far.where(m.demons.contains).length, far.length);
    expect(m.lives, lives);
    expect(s.hitShip, isFalse);
    // Ordinary kill points, plus the bait bonus once per creature.
    final bait = events.firstWhere((e) => e.name == GameEventNames.stormBait);
    expect(bait.data['kills'], 2);
    expect(bait.data['award'], 2 * StormfrontMechanic.baitPoints);
    expect(m.score - score, greaterThan(2 * StormfrontMechanic.baitPoints));
    expect(m.bonusRun.extra, 2 * StormfrontMechanic.baitPoints);
    // The first baited kill of the wave drops the rod, once.
    expect(m.pickups.where((p) => p.bonus == lightningRod).length, 1);
    expect(_mech(m).rods, 1);
  });

  test('standing still under a tell costs an ordinary hit', () {
    final m = _storm();
    _park(m, 200);
    final s = _untilTell(m, where: (s) => s.aim == StrikeAim.ship);
    final lives = m.lives;
    for (var f = 0; f < 300 && s.telling; f++) {
      _park(m, s.x);
      m.invulnerable = 0;
      m.shots.clear();
      for (final d in m.demons) {
        d.x = s.x < 180 ? 340 : 20; // nothing else threatens the ship
      }
      m.update(1 / 60);
    }
    expect(s.landed, isTrue);
    expect(s.hitShip, isTrue);
    expect(m.lives, lives - 1);
  });

  test('the shield absorbs a bolt; protection ignores it', () {
    final m = _storm();
    _park(m, 200);
    var s = _untilTell(m, where: (s) => s.aim == StrikeAim.ship);
    m.collect(Power.shield);
    final lives = m.lives;
    for (var f = 0; f < 300 && s.telling; f++) {
      _park(m, s.x);
      m.invulnerable = 0;
      m.shots.clear();
      m.powerTimers[Power.shield] = 9;
      m.update(1 / 60);
    }
    expect(s.landed, isTrue);
    expect(m.lives, lives);
    expect(m.hasPower(Power.shield), isFalse);
    expect(s.hitShip, isTrue);
    // Blinking protection: the bolt passes through, nothing is lost.
    s = _untilTell(m, where: (s) => s.aim == StrikeAim.ship);
    for (var f = 0; f < 300 && s.telling; f++) {
      _park(m, s.x);
      m.invulnerable = 5;
      m.update(1 / 60);
    }
    expect(s.landed, isTrue);
    expect(s.hitShip, isFalse);
    expect(m.lives, lives);
  });

  test('a ship that moves when the tell begins always escapes', () {
    for (final difficulty in Difficulty.values) {
      for (final start in [18.0, 100.0, 180.0, 342.0]) {
        final m = _storm(route: 4, difficulty: difficulty, seed: 7);
        final lives = m.lives;
        var dodged = 0;
        for (var f = 0; f < 60 * 45 && m.combat && dodged < 4; f++) {
          final tells = _mech(m).cell.strikes.where((s) => s.telling).toList();
          if (tells.isEmpty) {
            m.moveTo(start);
          } else {
            // Away from every told column, toward the roomier side.
            final xs = tells.map((s) => s.x);
            final left = xs.reduce((a, b) => a < b ? a : b);
            final right = xs.reduce((a, b) => a > b ? a : b);
            m.moveTo(left - 18 > 342 - right ? left - 60 : right + 60);
          }
          final before = _mech(m).bolts;
          // Only the storm may hurt the ship in this test.
          m.shots.removeWhere((s) => s.hostile);
          for (final d in m.demons) {
            d
              ..dive = 0
              ..telegraph = 0
              ..divePrep = 0;
          }
          m.ground.missiles.clear();
          m.update(1 / 60);
          if (_mech(m).bolts > before) dodged++;
        }
        expect(dodged, 4, reason: '$difficulty from $start');
        expect(_mech(m).shipHits, 0, reason: '$difficulty from $start');
        expect(m.lives, lives, reason: '$difficulty from $start');
      }
    }
  });

  test('the rod grounds the ship and draws a wider bolt to it', () {
    final m = _storm();
    m.collectBonus(lightningRod);
    expect(m.hasBonusPower('lightningRod'), isTrue);
    _park(m, 150);
    final s = _untilTell(m);
    expect(s.aim, StrikeAim.ship);
    expect(s.rod, isTrue);
    expect(s.column, const StormTuning().rodColumn);
    final lives = m.lives;
    // A creature outside the ordinary column, inside the rod's.
    final wide = _column(m, s.x, 1).single..x = s.x + 45;
    for (var f = 0; f < 300 && s.telling; f++) {
      _park(m, s.x);
      wide
        ..x = s.x + 45
        ..hp = 1;
      m.invulnerable = 0;
      m.shots.clear();
      m.bonusPowerTimers['lightningRod'] = 9;
      m.update(1 / 60);
    }
    expect(s.landed, isTrue);
    expect(s.grounded, isTrue);
    expect(s.hitShip, isFalse);
    expect(m.lives, lives);
    expect(m.demons.contains(wide), isFalse);
    // No second rod while one is carried.
    expect(m.pickups.where((p) => p.bonus == lightningRod), isEmpty);
  });

  test('bait bonuses stay inside the level cap', () {
    final m = _storm();
    final cap = (stormfront.scoring.capPar * m.sectorPar).round();
    expect(cap, greaterThan(1000));
    expect(m.bonusAward(cap - 150), cap - 150);
    expect(m.bonusAward(500), 150);
    expect(m.bonusAward(500), 0);
    expect(m.bonusRun.extra, cap);
  });

  test('half the kill drops become shields', () {
    var shields = 0, drops = 0;
    for (var seed = 0; seed < 40; seed++) {
      final m = _storm(seed: seed);
      for (var f = 0; f < 2400 && m.kills < 8 && m.combat; f++) {
        for (final d in List<Demon>.of(m.demons)) {
          if (d.entering || m.kills >= 8) continue;
          for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
            m.hitDemon(d);
          }
        }
        m.invulnerable = 5;
        m.update(1 / 60);
      }
      for (final p in m.pickups.where((p) => p.bonus == null)) {
        drops++;
        if (p.power == Power.shield) shields++;
      }
    }
    expect(drops, greaterThanOrEqualTo(30));
    // The eighth kill's regular drop is spread: every shield is the rule.
    expect(shields / drops, inInclusiveRange(.3, .7));
  });

  test('one seed, one storm: the same run replays tell for tell', () {
    List<String> run(int seed) {
      final m = ArcadeModel(seed: seed)
        ..startAt(sector: 2, route: 1, bonus: 'stormfront', runSeed: 4242);
      final log = <String>[];
      var seen = 0;
      for (var f = 0; f < 60 * 40 && m.mode != RunMode.gameOver; f++) {
        m.moveTo(180 + 140 * ((f ~/ 70) % 3 - 1));
        m.invulnerable = 5;
        m.update(1 / 60);
        final mech = m.bonusMechanic;
        if (mech is! StormfrontMechanic) break;
        for (final s in mech.cell.strikes) {
          if (s.index < seen) continue;
          seen = s.index + 1;
          log.add('$f ${s.aim.name} ${s.x.toStringAsFixed(2)}');
        }
      }
      log.add('score ${m.score} kills ${m.kills}');
      return log;
    }

    final a = run(1982);
    expect(a.length, greaterThan(6));
    expect(run(1982), a);
  });

  test('the storm never draws from the simulation stream', () {
    // Two models on one seed, one of them with the storm switched off by
    // an endless gap: their simulation streams stay in step.
    final a = _storm(seed: 5), b = _storm(seed: 5);
    for (var f = 0; f < 60 * 12; f++) {
      for (final m in [a, b]) {
        m.invulnerable = 5;
        m.moveTo(18);
        // No kills, so the worlds stay comparable: shots and bolts are
        // removed before they land.
        m.shots.removeWhere((s) => !s.hostile);
      }
      for (final s in _mech(b).cell.strikes) {
        s.tellLeft = 9; // b's storm never lands
      }
      a.update(1 / 60);
      b.update(1 / 60);
      for (final s in _mech(a).cell.strikes.where((s) => s.telling)) {
        if (s.tellLeft < .05) s.fizzled = true; // a's bolts fizzle too
      }
    }
    expect(_mech(a).cell.started, greaterThan(_mech(b).cell.started));
    expect(a.random.nextInt(1 << 30), b.random.nextInt(1 << 30));
  });

  test('the level ends through the ordinary Rout; the storm winds down', () {
    final m = _storm();
    final events = <String>[];
    for (var f = 0; f < 60 * 120 && m.mode == RunMode.playing; f++) {
      for (final d in List<Demon>.of(m.demons)) {
        if (d.entering) continue;
        for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
          m.hitDemon(d);
        }
      }
      m.invulnerable = 5;
      m.update(1 / 60);
      events.addAll([
        for (final e in m.takeGameEvents())
          if (GameEventNames.bonus.contains(e.name))
            e.variant == null ? e.name : '${e.name}.${e.variant}',
      ]);
    }
    expect(m.mode, RunMode.salvage);
    expect(events.first, 'bonusStart.stormfront');
    expect(events, contains('bonusCleared.stormfront'));
    expect(m.flow.active, isTrue);
    final cell = _mech(m).cell;
    final started = cell.started;
    for (var f = 0; f < 60 * 3; f++) {
      m.update(1 / 60);
    }
    expect(cell.strikes, isEmpty);
    expect(cell.started, started);
    // The next sector is a regular one: no storm, no rod.
    reach(m, RunMode.playing);
    expect(m.level, 4);
    expect(m.bonus, isNull);
    expect(m.bonusMechanic, isNull);
    expect(m.hasBonusPower('lightningRod'), isFalse);
  });

  group('radio', () {
    test('every Stormfront moment has lines that play a recorded clip', () {
      final all = {
        for (final bank in [commsHumanTriggers, commsDemonTriggers])
          for (final spec in bank.values)
            for (final line in spec.lines) line.id: line,
      };
      // bonus-briefing: the entry call is the urgent-mission card's
      // written line (silent until recorded, its own words on the card).
      for (final line in commsHumanTriggers['bonusEntry.stormfront']!.lines) {
        expect(line.silent, isTrue, reason: line.id);
        expect(line.clip, line.id, reason: 'nothing borrowed');
      }
      for (final name in [
        'bonusStart.stormfront',
        GameEventNames.stormStrike,
        GameEventNames.stormBait,
        'bonusPickup.lightningRod',
        'bonusCleared.stormfront',
      ]) {
        final spec = commsHumanTriggers[name];
        expect(spec, isNotNull, reason: name);
        for (final line in spec!.lines) {
          // Pending the voice batch (tillandsias#1103): a borrowed clip.
          expect(line.clip, isNot(line.id), reason: line.id);
          expect(all[line.clip]!.clip, line.clip, reason: 'recorded');
        }
      }
      expect(commsDemonTriggers[GameEventNames.stormBait]!.lines, isNotEmpty);
    });

    test('the transition into the storm speaks its storm warning', () {
      for (var seed = 0; seed < 12; seed++) {
        final plan = InterludePlanner(seed: seed).planRadio(
          const InterludeContext(
            difficulty: Difficulty.normal,
            level: 3,
            route: 0,
            window: 8,
            bonus: 'stormfront',
          ),
        );
        expect(plan!.radio!.spec.name, 'bonusEntry.stormfront');
      }
    });

    test('a tell on the ship asks for a warning that ends on the bolt', () {
      final m = _storm();
      final events = <GameEvent>[];
      final raw = <String>[];
      _park(m, 100);
      for (var f = 0; f < 60 * 30 && m.combat; f++) {
        m.invulnerable = 5;
        m.update(1 / 60);
        events.addAll(m.takeGameEvents());
        raw.addAll(m.takeEvents());
        if (events.any((e) => e.name == GameEventNames.stormStrike) &&
            raw.contains('stormBolt')) {
          break;
        }
      }
      final call = events.firstWhere(
        (e) => e.name == GameEventNames.stormStrike,
      );
      expect(call.data['endIn'], greaterThanOrEqualTo(1.0));
      expect(raw, containsAllInOrder(['stormTell', 'stormBolt']));
    });
  });
}
