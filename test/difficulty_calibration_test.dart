import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tools/analyze_difficulty.dart' as audit;

void main() {
  test(
    'accepted health tiers are identical across modes and cannot exceed five',
    () {
      const tiers = [
        [1, 2],
        [1, 2],
        [2, 3],
        [2, 3],
        [3, 4],
      ];
      for (final difficulty in Difficulty.values) {
        final policy = DifficultyPolicy(difficulty);
        for (var route = 0; route < tiers.length; route++) {
          for (var kind = 0; kind < 4; kind++) {
            expect(
              policy.ordinaryHealth(route: route, kind: kind, elite: false),
              tiers[route][kind ~/ 2],
            );
            expect(
              policy.ordinaryHealth(route: route, kind: kind, elite: true),
              tiers[route][kind ~/ 2] + 1,
            );
          }
        }
        expect(policy.ordinaryHealth(route: 999, kind: 999, elite: true), 5);
      }
    },
  );

  test('all 318 generated waves obey shared health and whole-wave budgets', () {
    final budgets = <String, List<int>>{};
    var checked = 0;
    for (final difficulty in Difficulty.values) {
      final policy = DifficultyPolicy(difficulty);
      for (var route = 0; route < 5; route++) {
        for (var sector = 1; sector <= 4; sector++) {
          final waves = 3 + (sector - 1) ~/ 2 + math.min(route, 3);
          for (var wave = 1; wave <= waves; wave++) {
            final result = audit.audit(difficulty, route, sector, wave);
            final context = '${difficulty.name} $route/$sector/$wave';
            final groups = result['groups'] as List<Map<String, Object?>>;
            final actors = groups
                .expand((g) => g['actors'] as List<Map<String, Object?>>)
                .toList();
            final ordinary = actors.where((d) => d['large'] == false).toList();
            final elites = ordinary.where((d) => d['elite'] == true).length;
            expect(
              elites,
              math.min(ordinary.length ~/ 10, policy.eliteBudget(route: route)),
              reason: context,
            );
            for (final d in ordinary) {
              expect(
                d['hp'],
                policy.ordinaryHealth(
                  route: route,
                  kind: d['kind'] as int,
                  elite: d['elite'] as bool,
                ),
                reason: context,
              );
              expect(d['hp'], inInclusiveRange(1, 5), reason: context);
              expect(d['shield'], 0);
              expect(d['armor'], 0);
            }
            final initial =
                groups.first['actors'] as List<Map<String, Object?>>;
            final roster = policy.rosterCount(
              sector: sector,
              wave: wave,
              route: route,
            );
            expect(initial, hasLength(roster), reason: context);
            final flocks = groups
                .where((g) => (g['name'] as String).startsWith('flock_'))
                .toList();
            expect(
              flocks,
              hasLength(
                policy.reinforcementFlocks(route: route, sector: sector),
              ),
              reason: context,
            );
            for (var i = 0; i < flocks.length; i++) {
              expect(
                flocks[i]['count'],
                policy.reinforcementSize(route: route, flock: i),
                reason: context,
              );
            }
            final sentinels = actors.where((d) => d['large'] == true).length;
            expect(sentinels, lessThanOrEqualTo(1));
            final escorts = groups.where((g) => g['name'] == 'escort').toList();
            expect(escorts, hasLength(sentinels), reason: context);
            if (escorts.isNotEmpty) {
              expect(
                escorts.single['count'],
                policy.escortSize(route: route, sector: sector),
              );
              for (final flock in flocks) {
                expect(
                  escorts.single['count'] as int,
                  greaterThan(flock['count'] as int),
                );
              }
            }
            expect(
              result['count'],
              lessThanOrEqualTo([39, 52, 59][difficulty.index]),
              reason: context,
            );
            expect(
              result['observedPeakActive'],
              lessThanOrEqualTo(ArcadeModel.maxActiveDemons),
              reason: context,
            );
            final admission =
                roster +
                math.max(
                  policy.reinforcementSize(route: route, flock: 1),
                  sentinels == 0
                      ? 0
                      : policy.escortSize(route: route, sector: sector),
                ) +
                sentinels;
            expect(
              result['observedPeakActive'],
              lessThanOrEqualTo(admission),
              reason: context,
            );
            // Accepted whole-wave pressure ceiling: arrivals cannot multiply the
            // opening defense budget beyond 2.5, including dedicated escorts.
            expect(
              result['waveToInitialBudgetRatio'],
              lessThanOrEqualTo(2.5),
              reason: context,
            );
            expect(
              result['powerfulShots'],
              lessThanOrEqualTo(result['standardShots'] as int),
            );
            budgets
                .putIfAbsent('$route/$sector/$wave', () => [])
                .add(result['standardShots'] as int);
            checked++;
          }
        }
      }
    }
    expect(checked, 318);
    for (final entry in budgets.entries) {
      expect(
        entry.value[0],
        lessThanOrEqualTo(entry.value[1]),
        reason: entry.key,
      );
      expect(
        entry.value[1],
        lessThanOrEqualTo(entry.value[2]),
        reason: entry.key,
      );
    }
  });

  test(
    'actual fired shots retain integer hit breakpoints and mode area coverage',
    () {
      for (final difficulty in Difficulty.values) {
        for (final powerful in [false, true]) {
          for (final large in [false, true]) {
            final m = ArcadeModel()
              ..restoreCheckpoint({'difficulty': difficulty.name, 'wave': 2});
            m.mode = RunMode.playing;
            m.invulnerable = 1000;
            m.demons.clear();
            m.demons.add(Demon(300, 60, 0, 1000, 0));
            if (powerful) m.collect(Power.powerful);
            if (large) m.collect(Power.large);
            m.update(1 / 60);
            final fired = m.shots.firstWhere((s) => !s.hostile);
            expect(fired.damage, powerful ? 2 : 1);
            expect(
              fired.blastRadius,
              large ? [32.0, 30.0, 28.0][difficulty.index] : 0,
            );
            expect(
              fired.kind,
              large
                  ? ShotKind.large
                  : powerful
                  ? ShotKind.powerful
                  : ShotKind.ordinary,
            );
            m.shots.clear();
            for (var hp = 1; hp <= 5; hp++) {
              final target = Demon(100, 220, 0, hp, 0);
              m.demons.add(target);
              final killsBefore = m.kills;
              final needed = (hp / fired.damage).ceil();
              for (var hit = 0; hit < needed; hit++) {
                m.shots.add(
                  Shot(
                    target.x,
                    target.y,
                    0,
                    0,
                    kind: fired.kind,
                    damage: fired.damage,
                    blastRadius: fired.blastRadius,
                  ),
                );
                m.update(1 / 60);
                expect(m.demons.contains(target), hit + 1 < needed);
                m.shots.clear();
              }
              expect(m.kills, killsBefore + 1);
            }
          }
        }
      }
    },
  );
}
