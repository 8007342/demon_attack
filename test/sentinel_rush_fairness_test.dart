// demon-intelligence task 5.6: the rush fairness guards (design §6.4),
// over 200 seeds × difficulty × routes 1-4.
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

const dt = 1 / 60;

/// Passes hit and flown by a [dodger] (moves away from the locked aim at
/// lock end) or a stationary ship at the aim.
(int, int) flyRushes(Difficulty difficulty, int route, {required bool dodger}) {
  var hit = 0, passes = 0;
  for (var seed = 0; seed < 200; seed++) {
    final rng = math.Random(seed * 31 + route);
    final m = ArcadeModel(seed: seed)
      ..startAt(difficulty: difficulty, sector: 2, route: route);
    m
      ..mode = RunMode.playing
      ..invulnerable = 0
      ..lives = 99;
    m.demons.clear();
    m.shots.clear();
    final d =
        Demon(
            70 + rng.nextDouble() * 220,
            44,
            2,
            12,
            0,
            archetype: EnemyArchetype.shieldSentinel,
            lastStandEligible: true,
          )
          ..hp =
              4 // one hit from the threshold
          ..volleyLeft = 1e9
          ..attackLeft = 1e9;
    m.demons.add(d);
    var x = 40 + rng.nextDouble() * 280;
    m.shipX = m.targetX = x;
    // A settled history: the pilot model has watched it sit still.
    for (var f = 0; f < 90; f++) {
      m.moveTo(x);
      m.update(dt);
      m.shots.clear(); // nothing but the rush
    }
    m.hitDemon(d);
    var lives = m.lives;
    var phase = d.rushPhase;
    for (var f = 0; f < 60 * 20 && m.demons.contains(d); f++) {
      if (d.rushPhase != phase) {
        if (d.rushPhase == RushPhase.rush) {
          passes++;
          if (dodger) {
            // Away from the locked aim, to the roomier side (≥ 162 u).
            x = d.targetX >= 180 ? 18.0 : 342.0;
          } else {
            x = d.targetX; // sits where it was aimed at
            m.shipX = m.targetX = x;
            m.shipVx = 0;
          }
        }
        if (d.rushPhase == RushPhase.rally && !dodger) x = m.shipX;
        phase = d.rushPhase;
      }
      if (!dodger) m.invulnerable = 0;
      m.moveTo(x);
      m.update(dt);
      m.shots.clear(); // nothing but the rush
      if (m.lives < lives) {
        hit++;
        lives = m.lives;
        break; // a lost life ends the rush (sacrifice)
      }
      // While the ship is away (a hit), nothing else counts.
      if (m.shipAway) break;
    }
  }
  return (hit, passes);
}

void main() {
  for (final difficulty in Difficulty.values) {
    test('${difficulty.name}: a dodging ship escapes ≥ 99 % of passes', () {
      for (var route = 1; route <= 4; route++) {
        final (hit, passes) = flyRushes(difficulty, route, dodger: true);
        // ignore: avoid_print
        print('${difficulty.name} route $route dodger: $hit hit of $passes');
        expect(1 - hit / passes, greaterThanOrEqualTo(.99));
      }
    });

    test('${difficulty.name}: a stationary ship is hit ≥ 90 % of passes', () {
      for (var route = 1; route <= 4; route++) {
        final (hit, passes) = flyRushes(difficulty, route, dodger: false);
        // ignore: avoid_print
        print(
          '${difficulty.name} route $route stationary: $hit hit of $passes',
        );
        expect(hit / passes, greaterThanOrEqualTo(.9));
      }
    });

    test('${difficulty.name}: corridor — homing reach < dodge reach', () {
      final p = DifficultyPolicy(difficulty);
      final rate = p.hostileRate;
      final (window, total, seconds) = RushKinematics.worstCase(
        y0: 44 - RushTuning.rise,
        vmax: p.rushSpeed * rate,
        turnRate: p.rushTurnRate * math.pi / 180 * rate,
        rate: rate,
        cap: RushTuning.homingCap(difficulty) * math.pi / 180,
      );
      final dodge = RushKinematics.dodge(seconds);
      // ignore: avoid_print
      print(
        '${difficulty.name}: homing ${window.toStringAsFixed(1)} u in its '
        'window (${total.toStringAsFixed(1)} u at the ship row) vs dodge '
        '${dodge.toStringAsFixed(1)} u in ${seconds.toStringAsFixed(3)} s',
      );
      // Design §6.4: the homing window's lateral reach is less than the
      // dodge reach (360 u/s × the time left − the ship's half width).
      expect(window, lessThan(dodge - 10));
      // And as built (it plunges straight past the commit line): the
      // whole lateral reach stays inside the smallest dodge room (the
      // roomier side, ≥ 162 u) less the widest contact (10 + 11 × 1.25).
      expect(total, lessThan(162 - (10 + 11 * 1.25)));
    });
  }
}
