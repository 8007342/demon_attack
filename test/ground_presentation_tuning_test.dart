// Operator tuning of the ground's presentation (playtest 2026-11-15;
// openspec change ground-presentation-tuning).
import 'dart:math' as math;

import 'package:demon_attack/game/easter_eggs.dart';
import 'package:demon_attack/game/ground_blocks_atlas.dart';
import 'package:demon_attack/game/ground_blocks_cast.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_heading.dart';
import 'package:demon_attack/game/ground_painter.dart';
import 'package:demon_attack/game/ground_presentation.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pace', () {
    test('ground animation at half speed or slower; walkers slower still', () {
      expect(GroundPace.anim, lessThanOrEqualTo(.5));
      expect(GroundPace.turn, lessThanOrEqualTo(.5));
      expect(GroundPace.fx, lessThanOrEqualTo(.5));
      expect(GroundPace.egg, lessThanOrEqualTo(.5));
      expect(GroundPace.walker, lessThan(GroundPace.anim));
    });

    test('the legged units are the walkers', () {
      final walkers = {
        for (final u in GroundBlocks.units.values)
          if (GroundPace.isWalker(u)) u.id,
      };
      expect(walkers,
          {'stilt', 'kiln-ox', 'strider', 'belfry', 'chapterhouse'});
      for (final id in walkers) {
        expect(GroundPace.of(GroundBlocks.units[id]!), GroundPace.walker);
      }
      expect(GroundPace.of(GroundBlocks.units['lodestar']!), GroundPace.anim);
      expect(GroundPace.of(GroundBlocks.units['ashlar']!), GroundPace.anim);
    });

    test('a paced heavy turns 90° in twice the authored time', () {
      final u = GroundBlocks.units['lodestar']!;
      final turn = GroundBlocks.turn[u.unitClass]!;
      final h = GroundHeading(u.headings, turn,
          initial: 0, pace: GroundPace.turn);
      expect(h.minHold, closeTo(turn.minHold / GroundPace.turn, 1e-9));
      const dt = 1 / 60;
      final steps = <double>[];
      for (var t = 0.0; t < 6; t += dt) {
        if (h.update(dt, lateral: 40, depth: 0) != 0) steps.add(t);
      }
      expect(steps, hasLength(4));
      // Authored 1.0-1.4 s (ground-blocks-runtime): now 2.0-2.8 s.
      expect(steps.last, inInclusiveRange(2.0, 2.8));
    });
  });

  group('sizes', () {
    test('Fleet vehicles 0.5x, Host vehicles 1.3x, troopers 0.9x', () {
      final v = GroundUnit(1, 2, 0, 20, 600)..force = GroundForce.vehicle;
      final t = GroundUnit(2, 2, 0, 20, 600)..force = GroundForce.heavyTank;
      final i = GroundUnit(3, 2, 0, 20, 600)..force = GroundForce.infantry;
      final r = GroundUnit(4, 2, 0, 20, 600)..force = GroundForce.rockets;
      expect(GroundPainter.drawScale(v), closeTo(v.scale * 1.3, 1e-9));
      expect(GroundPainter.drawScale(t), closeTo(t.scale * 1.3, 1e-9));
      expect(GroundPainter.drawScale(i), closeTo(i.scale * .9, 1e-9));
      expect(GroundPainter.drawScale(r), closeTo(r.scale * .9, 1e-9));
      final a = GroundAlly(1, 2, 0, 20, 300, 3)..force = GroundForce.vehicle;
      final s = GroundAlly(2, 2, 0, 20, 300, 3)..force = GroundForce.infantry;
      expect(GroundPainter.allyDrawScale(a), closeTo(a.scale * .5, 1e-9));
      expect(GroundPainter.allyDrawScale(s), closeTo(s.scale * .9, 1e-9));
    });
  });

  group('squads', () {
    test('groups of 1-5, most often 2-4; rocket teams 1-3', () {
      for (final ally in [false, true]) {
        final count = List.filled(6, 0);
        const n = 6000;
        for (var id = 0; id < n; id++) {
          final k = GroundSquadLook.size(id, rockets: false, ally: ally);
          expect(k, inInclusiveRange(1, 5));
          count[k]++;
        }
        expect((count[2] + count[3] + count[4]) / n, greaterThan(.75));
        expect(count[1], greaterThan(0));
        expect(count[5], greaterThan(0));
        expect(count[3], greaterThan(count[1]));
        expect(count[3], greaterThan(count[5]));
        for (var id = 0; id < 600; id++) {
          expect(GroundSquadLook.size(id, rockets: true, ally: ally),
              inInclusiveRange(1, 3));
        }
      }
    });

    test('the drawn group falls in proportion to the squad hp', () {
      for (var n = 1; n <= 5; n++) {
        for (final maxHp in [2, 3, 4]) {
          expect(GroundSquadLook.standing(n, maxHp, maxHp), n);
          expect(GroundSquadLook.standing(n, 0, maxHp), 0);
          var prev = n;
          for (var hp = maxHp - 1; hp >= 1; hp--) {
            final k = GroundSquadLook.standing(n, hp, maxHp);
            expect(k, inInclusiveRange(1, prev), reason: '$n of $maxHp at $hp');
            expect(GroundSquadLook.fellLast(n, hp, maxHp), prev);
            prev = k;
          }
        }
      }
    });

    test('troopers keep their own place, gait and drift, as a group', () {
      const seed = 7 * 31 + GroundSquadLook.demonSalt;
      final gaits = {
        for (var k = 0; k < 5; k++) GroundSquadLook.gait(seed, k),
      };
      expect(gaits, hasLength(5), reason: 'every trooper on its own gait');
      for (final (rate, phase) in gaits) {
        expect(rate, inInclusiveRange(.85, 1.15));
        expect(phase, inInclusiveRange(0, 4));
      }
      for (var k = 0; k < 5; k++) {
        final (fx, fy) = GroundSquadLook.formation[k];
        var moved = 0.0;
        var last = GroundSquadLook.offset(seed, k, 0, heading: 0, march: 1);
        for (var t = 0.0; t < 30; t += .25) {
          final o = GroundSquadLook.offset(seed, k, t, heading: 0, march: 1);
          // Within a few texels of its slot: still one group.
          expect((o.$1 - fx).abs(), lessThan(9));
          expect((o.$2 - fy).abs(), lessThan(8));
          moved = math.max(moved, (o.$1 - last.$1).abs() + (o.$2 - last.$2).abs());
          // Slow drift: never a jump between quarter seconds.
          expect((o.$1 - last.$1).abs() + (o.$2 - last.$2).abs(), lessThan(1.5));
          last = o;
        }
        expect(moved, greaterThan(0));
        expect(GroundSquadLook.offset(seed, k, 3.3, heading: 45, march: .5),
            GroundSquadLook.offset(seed, k, 3.3, heading: 45, march: .5));
      }
    });

    test('troopers of a squad turn one by one, not in lock-step', () {
      final layer = GroundBlocksLayer();
      final unit = GroundBlocksCast.unitFor(GroundCastRole.allyRifle, 2)!;
      final track = GroundBlockTrack(Object(), GroundBlockCells(unit));
      const seed = 3 * 31 + GroundSquadLook.allySalt;
      final turnedAt = <int, double>{};
      var x = 180.0, z = 400.0;
      const dt = 1 / 60;
      for (var f = 0; f < 60 * 8; f++) {
        final t = f * dt;
        layer.begin(t);
        // March up the plane for 2 s, then swing to screen right.
        if (t < 2) {
          z += 30 * dt;
        } else {
          x += 30 * dt;
        }
        layer.observe(track, x, z);
        for (var k = 0; k < 4; k++) {
          final h = layer.memberHeading(track, k, seed);
          if (t > 2 && !turnedAt.containsKey(k) && h.shown >= 67.5) {
            turnedAt[k] = t;
          }
        }
        layer.end();
      }
      expect(turnedAt, hasLength(4), reason: 'every trooper turns');
      final times = turnedAt.values.toList()..sort();
      expect(times.last - times.first, greaterThan(.25),
          reason: 'they turn one after another: $turnedAt');
      expect(times.last - 2, lessThan(3), reason: 'still one group');
    });
  });

  test('easter-egg running times stretched for the half-speed motion', () {
    final r = EasterEggBudget.rules;
    expect(r[EasterEgg.dance]!.duration, 1.6 / GroundPace.egg);
    expect(r[EasterEgg.jig]!.duration, 1.0 / GroundPace.egg);
    expect(r[EasterEgg.jackpot]!.duration, 2.5 / GroundPace.egg);
    // The jackpot breakup fits inside the wreck's 6 s.
    expect(2.6 / GroundPace.egg, lessThan(6));
  });
}
