import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/game/bonus/levels/storm_cell.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/sprite_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// lightning-rework (openspec/changes/lightning-rework): a bolt stuns the
/// brood and zaps the ship, ranks dodge, rod armour charges. Every loop
/// here is bounded by a frame guard.

ArcadeModel _regular({int sector = 3, int route = 0}) {
  final m = ArcadeModel(seed: 1982)..startAt(sector: sector, route: route);
  reach(m, RunMode.playing);
  // Until the wave has arrived (protected meanwhile).
  for (var f = 0; f < 900 && !m.demons.any((d) => !d.entering); f++) {
    m.invulnerable = 5;
    m.update(1 / 60);
  }
  m.invulnerable = 0;
  return m;
}

ArcadeModel _storm({int route = 0, Difficulty d = Difficulty.normal}) {
  final m = ArcadeModel(seed: 1982)
    ..startAt(sector: 3, route: route, bonus: 'stormfront', difficulty: d);
  reach(m, RunMode.playing);
  return m;
}

StormfrontMechanic _mech(ArcadeModel m) =>
    m.bonusMechanic! as StormfrontMechanic;

/// A present creature (not entering), the first in list order.
Demon _present(ArcadeModel m) => m.demons.firstWhere((d) => !d.entering);

/// Keeps every hostile thing off the ship for one step.
void _quiet(ArcadeModel m) {
  m.shots.removeWhere((s) => s.hostile);
  m.ground.missiles.clear();
  for (final d in m.demons) {
    d
      ..dive = 0
      ..telegraph = 0
      ..divePrep = 0;
  }
}

void main() {
  group('a stunned creature', () {
    test('falls a little, never dies, and climbs back within its bounds', () {
      final m = _regular();
      final d = _present(m);
      final kills = m.kills, hp = d.hp, count = m.demons.length;
      final y0 = d.y;
      final hit = m.strikeLightning(d.x, 4);
      expect(hit.stunned, contains(d));
      expect(d.stunned, isTrue);
      expect(m.takeEvents(), contains('stormStun'));
      var deepest = d.y, frames = 0;
      for (; frames < 600 && d.stunned; frames++) {
        m.invulnerable = 5;
        _quiet(m);
        m.update(1 / 60);
        deepest = math.max(deepest, d.y);
        expect(
          d.y,
          lessThanOrEqualTo(
            ArcadeModel.shipY - LightningTuning.floorAboveShip + .01,
          ),
        );
      }
      expect(d.stunned, isFalse, reason: 'it recovers');
      // At most the fall's cap below where it was struck.
      expect(deepest - y0, greaterThan(8));
      expect(deepest - y0, lessThanOrEqualTo(LightningTuning.maxDrop + .01));
      // The whole stun: at least the fall and the shortest climb, at most
      // the cap.
      expect(
        frames / 60,
        inInclusiveRange(
          LightningTuning.fall + LightningTuning.minRecover - .05,
          LightningTuning.maxStun + .02,
        ),
      );
      expect(m.kills, kills);
      expect(d.hp, hp);
      expect(m.demons.length, count);
      expect(m.demons, contains(d));
    });

    test('cannot fire, dive or keep its tell while stunned', () {
      final m = _regular(sector: 4, route: 1);
      final d = _present(m)..telegraph = .5;
      m.strikeLightning(d.x, 4);
      expect(d.telegraph, 0);
      for (var f = 0; f < 50 && d.stunned; f++) {
        m.invulnerable = 5;
        m.update(1 / 60);
        expect(d.dive, 0);
        expect(d.telegraph, 0);
        expect(d.divePrep, 0);
      }
    });

    test('shot down while stunned it scores its ordinary points', () {
      final a = _regular(), b = _regular();
      final da = _present(a), db = _present(b);
      expect(da.seed, db.seed);
      a.strikeLightning(da.x, 4);
      final sa = a.score, sb = b.score;
      for (var g = 0; g < 100 && a.demons.contains(da); g++) {
        a.hitDemon(da);
      }
      for (var g = 0; g < 100 && b.demons.contains(db); g++) {
        b.hitDemon(db);
      }
      expect(a.score - sa, b.score - sb);
      expect(a.stunKills, contains(da));
    });

    test('its shield and armour are down', () {
      final m = _regular();
      final d = _present(m);
      final sentinel = Demon(
        d.x,
        d.y,
        0,
        3,
        4.2,
        archetype: EnemyArchetype.armoredSentinel,
        shieldMax: 2,
        armorMax: 2,
      );
      m.demons.add(sentinel);
      m.strikeLightning(sentinel.x, 2);
      expect(sentinel.stunned, isTrue);
      m.hitDemon(sentinel);
      expect(sentinel.hp, 2, reason: 'straight to the body');
      expect(sentinel.shield, 2);
      expect(sentinel.armor, 2);
    });

    test('a sentinel sags less than a small creature', () {
      final m = _regular();
      final small = _present(m);
      final big = Demon(
        small.x + 80,
        small.y,
        0,
        5,
        3.3,
        archetype: EnemyArchetype.shieldSentinel,
      );
      m.demons.add(big);
      final y0 = small.y, b0 = big.y;
      m.strikeLightning(small.x, 2);
      m.strikeLightning(big.x, 2);
      var deepS = y0, deepB = b0;
      for (var f = 0; f < 120 && (small.stunned || big.stunned); f++) {
        m.invulnerable = 5;
        _quiet(m);
        m.update(1 / 60);
        deepS = math.max(deepS, small.y);
        deepB = math.max(deepB, big.y);
      }
      expect(deepB - b0, lessThanOrEqualTo(LightningTuning.largeDrop + 6));
      expect(deepS - y0, greaterThan(deepB - b0));
    });
  });

  group('the ship', () {
    test('a zap strips every shield and power-up and never a life', () {
      final m = _regular();
      m
        ..collect(Power.spread)
        ..collect(Power.rapid)
        ..collect(Power.shield)
        ..collectBonus(bonusPowers.first);
      m.takeGameEvents();
      final lives = m.lives, parts = m.fallingParts.length;
      expect(m.zapShip(), isTrue);
      expect(m.lives, lives);
      expect(m.activePowers, isEmpty);
      expect(m.activeBonusPowers, isEmpty);
      expect(m.shipAway, isFalse);
      expect(m.lifeLossPhase, LifeLossPhase.none);
      // The two modules are blown off the hull, up and apart.
      expect(m.fallingParts.length, parts + 2);
      expect(m.fallingParts.last.vy, lessThan(0));
      expect(
        m.shockLost,
        containsAll([Power.spread, Power.rapid, Power.shield]),
      );
      expect(m.shipShock, LightningTuning.shipShock);
      expect(m.takeEvents(), contains('shipZapped'));
      final e = m.takeGameEvents().singleWhere(
        (e) => e.name == GameEventNames.lightningShipHit,
      );
      expect(e.variant, 'powers');
      expect(e.data['lost'], 4);
      expect(e.data['shield'], isTrue);
      // A zap with nothing to lose still never costs a life.
      for (var f = 0; f < 200 && m.lightningGrace > 0; f++) {
        m.update(1 / 60);
      }
      expect(m.zapShip(), isTrue);
      expect(m.lives, lives);
      expect(
        m
            .takeGameEvents()
            .singleWhere((e) => e.name == GameEventNames.lightningShipHit)
            .variant,
        'clean',
      );
    });

    test('the grace window: one bolt cannot chain-hit', () {
      final m = _regular();
      expect(m.zapShip(), isTrue);
      m.collect(Power.powerful);
      // A fork in the same instant, and every bolt within the grace.
      expect(m.zapShip(), isFalse);
      var frames = 0;
      for (; frames < 600 && m.lightningGrace > 0; frames++) {
        m.invulnerable = 0;
        _quiet(m);
        m.update(1 / 60);
        if (m.lightningGrace > 0) {
          expect(m.zapShip(), isFalse);
          expect(m.hasPower(Power.powerful), isTrue);
        }
      }
      expect(frames / 60, closeTo(LightningTuning.shipGrace, .05));
      expect(m.zapShip(), isTrue);
      expect(m.hasPower(Power.powerful), isFalse);
    });

    test('protection and the ship being away ignore a bolt', () {
      final m = _regular()..collect(Power.spread);
      m.invulnerable = 1;
      expect(m.zapShip(), isFalse);
      expect(m.hasPower(Power.spread), isTrue);
      m.invulnerable = 0;
      m.hitPlayer();
      expect(m.shipAway, isTrue);
      expect(m.zapShip(), isFalse);
    });

    test(
      'in Stormfront: standing still under a tell is a zap, not a death',
      () {
        final m = _storm();
        final cell = _mech(m).cell;
        StormStrike? s;
        for (var f = 0; f < 3600 && s == null; f++) {
          m.invulnerable = 5;
          m.update(1 / 60);
          for (final t in cell.strikes) {
            if (t.telling && t.aim == StrikeAim.ship) s = t;
          }
        }
        expect(s, isNotNull);
        final lives = m.lives;
        for (var f = 0; f < 300 && s!.telling; f++) {
          m
            ..shipX = s.x
            ..targetX = s.x
            ..invulnerable = 0;
          m.powerTimers[Power.shield] = 9;
          m.powerTimers[Power.spread] = 9;
          _quiet(m);
          m.update(1 / 60);
        }
        expect(s!.hitShip, isTrue);
        expect(m.lives, lives);
        expect(m.activePowers, isEmpty);
        expect(_mech(m).shipHits, 1);
      },
    );
  });

  group('rank', () {
    test('the rank ladder is the insignia\'s', () {
      final m = _regular(sector: 4, route: 2);
      for (final d in m.demons) {
        expect(lightningRank(d), CombatAtlas.rankOf(d).index);
      }
    });

    test('dodge chances grow with rank and route', () {
      for (var route = 0; route <= 4; route++) {
        expect(lightningDodgeChance(0, route), 0);
        for (var r = 1; r <= 4; r++) {
          expect(
            lightningDodgeChance(r, route),
            greaterThan(lightningDodgeChance(r - 1, route)),
          );
          if (route > 0) {
            expect(
              lightningDodgeChance(r, route),
              greaterThanOrEqualTo(lightningDodgeChance(r, route - 1)),
            );
          }
        }
      }
    });

    test('avoidance is monotonic: a higher rank dodges every bolt a lower '
        'one would, and the dodgers clear the column', () {
      Demon make(int rank, double x, double seed) => switch (rank) {
        0 => Demon(x, 120, 0, 1, seed),
        1 => Demon(x, 120, 2, 2, seed),
        2 => Demon(x, 120, 2, 4, seed),
        3 => Demon(x, 120, 1, 2, seed, elite: true),
        _ => Demon(
          x,
          120,
          0,
          5,
          seed,
          archetype: EnemyArchetype.shieldSentinel,
        ),
      };
      final dodged = List.filled(5, 0);
      final sets = List.generate(5, (_) => <int>{});
      const trials = 60;
      for (var rank = 0; rank <= 4; rank++) {
        for (var i = 0; i < trials; i++) {
          final m = _regular(sector: 4, route: 1);
          m.demons.clear();
          final d = make(rank, 180, 1.37 * i + .2);
          m.demons.add(d);
          expect(lightningRank(d), rank);
          const tell = 1.15, column = 34.0;
          final x = d.x;
          var t = 0.0;
          for (var f = 0; f < 200 && t < tell; f++) {
            m.invulnerable = 5;
            _quiet(m);
            m.dodgeLightning([
              (index: i, x: x, column: column, progress: t / tell),
            ]);
            m.update(1 / 60);
            t += 1 / 60;
          }
          final decided =
              lightningRoll(d, i) < lightningDodgeChance(rank, m.cycle);
          final hit = m.strikeLightning(x, column);
          final escaped = hit.stunned.isEmpty;
          if (decided) {
            // Every creature that decided to dodge made it out in time.
            expect(
              escaped,
              isTrue,
              reason:
                  'rank $rank trial $i: x ${d.x.toStringAsFixed(1)} '
                  'dodge ${d.boltDodge.toStringAsFixed(1)} from $x',
            );

            dodged[rank]++;
            sets[rank].add(i);
          }
        }
      }
      expect(dodged[0], 0);
      for (var r = 1; r <= 4; r++) {
        expect(
          dodged[r],
          greaterThanOrEqualTo(dodged[r - 1]),
          reason: '$dodged',
        );
        expect(sets[r].containsAll(sets[r - 1]), isTrue, reason: 'rank $r');
      }
      expect(dodged[3] / trials, greaterThan(.5));
      expect(dodged[4], greaterThan(dodged[1]));
    });
  });

  group('lightning-rod armour', () {
    test('appears on sentinels from tour 2 and hunters from tour 3', () {
      final drone = Demon(0, 0, 0, 1, 1);
      final hunter = Demon(0, 0, 1, 2, 1, elite: true);
      final sentinel = Demon(
        0,
        0,
        0,
        5,
        1,
        archetype: EnemyArchetype.shieldSentinel,
      );
      expect(lightningRodArmour(sentinel, 0), isFalse);
      expect(lightningRodArmour(sentinel, 1), isTrue);
      expect(lightningRodArmour(hunter, 1), isFalse);
      expect(lightningRodArmour(hunter, 2), isTrue);
      for (var r = 0; r <= 4; r++) {
        expect(lightningRodArmour(drone, r), isFalse);
      }
      // Stormfront fits it on what it sees.
      final m = _storm(route: 2);
      m.update(1 / 60);
      for (final d in m.demons) {
        expect(d.lightningRods, lightningRodArmour(d, 2));
      }
    });

    test('empowers instead of stunning, from a wider reach', () {
      final m = _regular(sector: 4, route: 2);
      final d = _present(m)..lightningRods = true;
      m.takeGameEvents();
      // Outside the column, inside the rods' reach.
      final hit = m.strikeLightning(d.x + 50, 34);
      expect(hit.charged, [d]);
      expect(hit.stunned, isNot(contains(d)));
      expect(d.stunned, isFalse);
      expect(d.charged, LightningTuning.charge);
      expect(m.takeEvents(), contains('demonCharged'));
      expect(
        m.takeGameEvents().map((e) => e.name),
        contains(GameEventNames.lightningCharged),
      );
    });

    test('a charged creature fires faster', () {
      double spent(bool charged) {
        final m = _regular(sector: 4, route: 2);
        final d = Demon(180, 120, 1, 2, 7.7, elite: true)..attackLeft = 50;
        m.demons
          ..clear()
          ..add(d);
        if (charged) d.charged = 3;
        m.invulnerable = 5;
        m.update(1 / 60);
        return 50 - d.attackLeft;
      }

      expect(
        spent(true) / spent(false),
        closeTo(LightningTuning.chargedRate, .01),
      );
    });

    test('a rod-armoured creature is drawn toward a tell', () {
      final m = _regular(sector: 4, route: 2);
      final d = Demon(180, 120, 1, 2, 2.5, elite: true)..lightningRods = true;
      m.demons
        ..clear()
        ..add(d);
      for (var f = 0; f < 40; f++) {
        m.invulnerable = 5;
        _quiet(m);
        m.dodgeLightning([(index: 0, x: 240, column: 34, progress: .5)]);
        m.update(1 / 60);
      }
      expect(d.boltDodge, greaterThan(30));
    });
  });

  group('Stormfront', () {
    test('a baited bolt stuns; shooting them while they fall pays the bait '
        'bonus and drops the rod', () {
      final m = _storm();
      final cell = _mech(m).cell;
      m
        ..shipX = 120
        ..targetX = 120;
      StormStrike? s;
      for (var f = 0; f < 3600 && s == null; f++) {
        m.invulnerable = 5;
        m.update(1 / 60);
        for (final t in cell.strikes) {
          if (t.telling && t.aim == StrikeAim.ship) s = t;
        }
      }
      final present = m.demons.where((d) => !d.entering).toList();
      final victims = present.take(2).toList();
      final events = <GameEvent>[];
      final kills = m.kills;
      for (var f = 0; f < 300 && s!.telling; f++) {
        for (final (i, v) in victims.indexed) {
          v
            ..x = s.x + (i - .5) * 12
            ..hp = 1;
        }
        for (final o in present.skip(2)) {
          o.x = s.x < 180 ? 340 : 20;
        }
        m
          ..shipX = 300
          ..targetX = 300
          ..invulnerable = 0;
        m.shots.clear();
        _quiet(m);
        m.update(1 / 60);
        events.addAll(m.takeGameEvents());
      }
      expect(s!.landed, isTrue);
      expect(s.hitShip, isFalse);
      expect(s.stunned, greaterThanOrEqualTo(2));
      expect(m.kills, kills, reason: 'lightning no longer kills');
      expect(victims.every((v) => v.stunned), isTrue);
      final bait = events.firstWhere((e) => e.name == GameEventNames.stormBait);
      expect(bait.variant, 'stun');
      // Shot down while they fall.
      final extra = m.bonusRun.extra;
      for (final v in victims) {
        m.hitDemon(v);
      }
      m.update(1 / 60);
      expect(m.kills, kills + 2);
      expect(
        m.bonusRun.extra - extra,
        2 * StormfrontMechanic.baitPoints * (m.cycle + 1),
      );
      expect(_mech(m).baitKills, 2);
      expect(m.pickups.where((p) => p.bonus == lightningRod).length, 1);
    });

    test('the first warning on the ship is "Avoid lightning!"', () {
      final m = _storm();
      final warnings = <GameEvent>[];
      for (var f = 0; f < 60 * 40 && warnings.length < 2; f++) {
        m.invulnerable = 5;
        m.update(1 / 60);
        warnings.addAll(
          m.takeGameEvents().where((e) => e.name == GameEventNames.stormStrike),
        );
      }
      expect(warnings, hasLength(2));
      expect(warnings[0].variant, 'avoid');
      expect(warnings[1].variant, isNull);
      expect(warnings[0].data['endIn'], greaterThanOrEqualTo(1.0));
    });

    test('its briefing says the new goal', () {
      expect(stormfront.brief, contains('Lure the lightning'));
      expect(stormfront.how, contains('fall'));
      expect(
        commsHumanTriggers['bonusCall.stormfront']!.lines.single.text,
        contains('while they fall'),
      );
    });
  });

  group('radio', () {
    test('every lightning moment has its own written lines', () {
      for (final name in [
        'stormStrike.avoid',
        'stormBait.stun',
        GameEventNames.lightningStun,
        GameEventNames.lightningShipHit,
        '${GameEventNames.lightningShipHit}.powers',
        '${GameEventNames.lightningShipHit}.clean',
        GameEventNames.lightningCharged,
      ]) {
        final spec = commsHumanTriggers[name];
        expect(spec, isNotNull, reason: name);
        for (final line in spec!.lines) {
          expect(line.silent, isTrue, reason: '${line.id}: its own words');
          expect(line.text!.length, lessThan(70), reason: 'one line');
        }
      }
      expect(
        commsHumanTriggers['stormStrike.avoid']!.lines.every(
          (l) => l.text!.startsWith('Avoid lightning'),
        ),
        isTrue,
      );
      expect(
        commsHumanTriggers['${GameEventNames.lightningShipHit}.powers']!.lines
            .map((l) => l.text),
        contains("You're fine, only the power-ups are gone."),
      );
      expect(
        commsHumanTriggers['${GameEventNames.lightningShipHit}.clean']!.lines
            .map((l) => l.text),
        contains("You're fine, the ship can take it."),
      );
      for (final name in [
        'stormBait.stun',
        GameEventNames.lightningStun,
        GameEventNames.lightningShipHit,
        GameEventNames.lightningCharged,
      ]) {
        expect(commsDemonTriggers[name]?.lines, isNotEmpty, reason: name);
      }
    });

    for (final (name, variant) in [
      (GameEventNames.lightningShipHit, 'powers'),
      (GameEventNames.lightningShipHit, 'clean'),
      (GameEventNames.lightningCharged, null),
      (GameEventNames.stormBait, 'stun'),
    ]) {
      test('$name${variant == null ? '' : '.$variant'} speaks at its moment, '
          'once per cooldown', () {
        final started = <CommsMessage>[];
        final d = CommsDirector(random: math.Random(3))..onStart = started.add;
        d.setSector(3, 0);
        final data = {'variant': ?variant, 'sector': 3};
        // Three of them two seconds apart: inside the trigger's cooldown.
        for (var t = 0.0; t < 9; t += 1 / 60) {
          for (final at in const [1.0, 3.0, 5.0]) {
            if ((t - at).abs() < 1 / 120) d.handle(GameEvent(name, data), t);
          }
          d.update(t, combat: true);
        }
        final human = started.where((m) => !m.isDemon).toList();
        expect(human, hasLength(1), reason: name);
        final want = variant == null ? name : '$name.$variant';
        expect(human.single.trigger.name, want);
        expect(human.single.startedAt, lessThan(2.5));
      });
    }

    test('the tell warning ends on the bolt and is rate-limited', () {
      final started = <CommsMessage>[];
      final d = CommsDirector(random: math.Random(5))..onStart = started.add;
      d.setSector(3, 0);
      for (var t = 0.0; t < 9; t += 1 / 60) {
        for (final at in const [1.0, 4.0]) {
          if ((t - at).abs() < 1 / 120) {
            d.handle(
              GameEvent(GameEventNames.stormStrike, {
                'variant': 'avoid',
                'endIn': 1.15,
                'sector': 3,
              }),
              t,
            );
          }
        }
        d.update(t, combat: true);
      }
      final calls = started.where((m) => !m.isDemon).toList();
      expect(calls, hasLength(1));
      expect(calls.single.trigger.name, 'stormStrike.avoid');
      expect(calls.single.endBy, closeTo(2.15, .02));
    });
  });
}
