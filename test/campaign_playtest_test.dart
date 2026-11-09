import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deterministic pilot that uses the real movement, automatic fire, collision,
/// shield and door rules. Protection guarantees coverage of the complete campaign;
/// this checks sustained simulation pressure, not a human player's survival rate.
/// Ground-war reactions, kept identical to tools/profile_difficulty.dart:
/// head for a falling homing pickup, and never stand in the danger band of
/// a ground missile's fixed path.
double groundAwareX(ArcadeModel model, double x) {
  final pickup = model.ground.pickups.firstOrNull;
  if (pickup != null && pickup.y > 250) x = pickup.x;
  const danger =
      GroundTuning.shipHalfWidth +
      GroundTuning.missileMaxSize * GroundTuning.missileHitRatio +
      16;
  for (final m in model.ground.missiles) {
    if (m.spent || m.t > 1.1) continue;
    if ((x - m.targetX).abs() >= danger) continue;
    final sides = [
      m.targetX - danger - 4,
      m.targetX + danger + 4,
    ].where((v) => v >= 18 && v <= ArcadeModel.width - 18);
    x = sides.reduce(
      (a, b) => (a - model.shipX).abs() <= (b - model.shipX).abs() ? a : b,
    );
  }
  return x;
}

void steer(ArcadeModel model, {bool react = true}) {
  var x = model.shipX;
  final boss = model.boss;
  if (boss != null) {
    final flight = (ArcadeModel.shipY - boss.y) / 390;
    x = boss.forecastX(flight, model.speed);
  } else if (model.demons.isNotEmpty) {
    final d = model.demons.first;
    final flight = (ArcadeModel.shipY - d.y) / 390;
    final time = model.levelClock + flight;
    x = d.isLarge
        ? d.x
        : d.dive > 0
        ? d.targetX + (d.x - d.targetX) * math.exp(-1.8 * flight)
        : d.homeX +
              math.sin(time * (.9 + d.kind * .12) * model.speed + d.seed) * 29 +
              math.sin(time * .44 * model.policy.hostileRate) * 13;
  }
  model.moveTo(react ? groundAwareX(model, x) : x);
}

void main() {
  for (final difficulty in Difficulty.values) {
    test('continuous ${difficulty.name} campaign completes using real shots', () {
      final model = ArcadeModel(seed: 1982)..start(difficulty: difficulty);
      var entrances = 0;
      var bossVictories = 0;
      var completions = 0;
      var maxHostileShots = 0;
      var maxLarge = 0;
      final visitedRoutes = <int>{};
      for (
        var frame = 0;
        frame < 900000 && model.mode != RunMode.completed;
        frame++
      ) {
        if (model.combat) {
          model.invulnerable = 2;
          steer(model);
          visitedRoutes.add(model.cycle);
        }
        model.update(1 / 60);
        for (final event in model.takeEvents()) {
          if (event == 'checkpoint') entrances++;
          if (event == 'bossDefeated') bossVictories++;
          if (event == 'completed') completions++;
        }
        maxHostileShots = math.max(
          maxHostileShots,
          model.shots.where((s) => s.hostile).length,
        );
        maxLarge = math.max(
          maxLarge,
          model.demons.where((d) => d.isLarge).length,
        );
      }
      expect(
        model.mode,
        RunMode.completed,
        reason:
            'route=${model.cycle} level=${model.level} wave=${model.wave} kills=${model.kills} demons=${model.demons.length} flocks=${model.flocksRemaining} escort=${model.escortSpawned} boss=${model.boss?.core}',
      );
      expect(visitedRoutes, {0, 1, 2, 3, 4});
      expect(entrances, 111); // 106 ordinary waves and five carriers.
      expect(bossVictories, 5);
      expect(completions, 1);
      expect(model.medals, 5);
      expect(
        model.remainingLives,
        greaterThanOrEqualTo(model.policy.startingLives + 5),
      );
      expect(model.kills, greaterThan(1500));
      expect(model.activeMilliseconds, greaterThan(1000000));
      expect(maxLarge, 1);
      expect(maxHostileShots, lessThanOrEqualTo(120));
      // The ground war: units fought, the autopilot sidestepped nearly every
      // missile and used the homing pickups it was given.
      final g = model.ground;
      expect(g.unitsSpawned, greaterThan(100));
      expect(g.missilesLaunched, greaterThan(10));
      expect(g.missileImpacts, lessThanOrEqualTo(g.missilesLaunched * .12));
      expect(g.homingCollected, greaterThan(50));
      expect(g.homingHits, greaterThan(g.homingCollected * 2));
      expect(g.unitsDestroyed, greaterThan(g.unitsSpawned * .75));
      expect(g.alliesSaved, greaterThan(g.alliesRetreated));
    });
  }
}
