import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deterministic pilot that uses the real movement, automatic fire, collision,
/// shield and door rules. Protection guarantees coverage of the complete campaign;
/// this checks sustained simulation pressure, not a human player's survival rate.
void steer(ArcadeModel model) {
  final boss = model.boss;
  if (boss != null) {
    final flight = (ArcadeModel.shipY - boss.y) / 390;
    model.moveTo(boss.forecastX(flight, model.speed));
  } else if (model.demons.isNotEmpty) {
    final demon = model.demons.first;
    final flight = (ArcadeModel.shipY - demon.y) / 390;
    final time = model.levelClock + flight;
    final x = demon.isLarge
        ? demon.x
        : demon.dive > 0
        ? demon.targetX + (demon.x - demon.targetX) * math.exp(-1.8 * flight)
        : demon.homeX +
              math.sin(
                    time * (.9 + demon.kind * .12) * model.speed + demon.seed,
                  ) *
                  29 +
              math.sin(time * .44 * model.policy.hostileRate) * 13;
    model.moveTo(x);
  }
}

void main() {
  for (final difficulty in Difficulty.values) {
    test(
      'continuous ${difficulty.name} campaign completes using real shots',
      () {
        final model = ArcadeModel(seed: 1982)..start(difficulty: difficulty);
        var entrances = 0;
        var bossVictories = 0;
        var completions = 0;
        var maxHostileShots = 0;
        var maxLarge = 0;
        final visitedRoutes = <int>{};
        for (
          var frame = 0;
          frame < 540000 && model.mode != RunMode.completed;
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
        expect(model.mode, RunMode.completed);
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
      },
    );
  }
}
