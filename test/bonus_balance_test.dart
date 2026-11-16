// bonus-balance gate (openspec/changes/bonus-balance): every bonus level in
// the catalogue against the regular sector it replaces, measured with the
// calibration pilots (test/support/bonus_balance.dart) on sectors 2-4 of
// routes 0 and 1 (where nine runs in ten meet their bonus level), three
// difficulties, eight seeds. The numbers are in plan/calibration-current.md
// ("Bonus balance"); `--dart-define=BONUS_BALANCE=<tag>` also writes the
// tables to .cache/bonus-balance-<tag>.md, and with BONUS_BALANCE_ROUTES=4
// adds routes 2 and 3 (report only, minutes).
import 'dart:io';

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/bonus_balance.dart';

const seeds = [1982, 7, 21, 42, 99, 314, 2718, 5150];

/// Pooled over every cell: within this share of the regular sectors.
const pooledBand = .15;

/// Per difficulty (duration, enemies, possible score).
const modeBand = .2;

void main() {
  test('the regular sentinel rule matches the model\'s', () {
    for (final d in Difficulty.values) {
      for (var route = 0; route <= 4; route++) {
        for (var sector = 1; sector <= 4; sector++) {
          final m = ArcadeModel()
            ..startAt(difficulty: d, sector: sector, route: route);
          for (var w = 1; w <= m.wavesPerLevel; w++) {
            expect(
              ArcadeBonus.regularSentinelWave(
                difficulty: d,
                sector: sector,
                route: route,
                wave: w,
              ),
              m.sentinelFor(w) != null,
              reason: '${d.name} r$route s$sector w$w',
            );
          }
        }
      }
    }
  });

  test('every bonus level is worth about the sector it replaces', () {
    const define = String.fromEnvironment('BONUS_BALANCE');
    const routes = int.fromEnvironment('BONUS_BALANCE_ROUTES', defaultValue: 2);
    final ids = [for (final l in bonusLevels) l.id];
    final cells = measureBalance(
      levels: [null, ...ids],
      seeds: seeds,
      routes: [for (var r = 0; r < routes; r++) r],
    );
    if (define.isNotEmpty) {
      Directory('.cache').createSync(recursive: true);
      File('.cache/bonus-balance-$define.md')
          .writeAsStringSync(balanceMarkdown(cells, ids));
    }
    final gated = [
      for (final c in cells)
        if (c.route <= 1) c,
    ];
    final metrics = <String, double Function(BalanceCell)>{
      'duration': (c) => c.meanCombat,
      'enemies': (c) => c.meanKills,
      'possible score': (c) => c.meanPossible,
      'difficulty (lives lost)': (c) => c.meanLives,
    };
    for (final id in ids) {
      for (final MapEntry(key: name, value: f) in metrics.entries) {
        final pooled = pooledRatio(gated, id, f);
        expect(
          pooled,
          inInclusiveRange(1 - pooledBand, 1 + pooledBand),
          reason: '$id $name pooled ${pooled.toStringAsFixed(3)}',
        );
        if (name.startsWith('difficulty')) continue; // noisy per mode
        for (final d in Difficulty.values) {
          final r = pooledRatio(gated, id, f, difficulty: d);
          expect(
            r,
            inInclusiveRange(1 - modeBand, 1 + modeBand),
            reason: '$id $name ${d.name} ${r.toStringAsFixed(3)}',
          );
        }
      }
      // No short bonus level anywhere (the three-second level): each cell
      // lasts at least 60 % of its sector and has 85 % of its enemies.
      for (final c in gated.where((c) => c.level == id)) {
        final regular = gated.firstWhere(
          (r) =>
              r.level == null &&
              r.difficulty == c.difficulty &&
              r.route == c.route &&
              r.sector == c.sector,
        );
        final where = '$id ${c.difficulty.name} r${c.route} s${c.sector}';
        expect(
          c.meanCombat,
          greaterThanOrEqualTo(.6 * regular.meanCombat),
          reason: '$where lasts ${c.meanCombat.toStringAsFixed(1)} s',
        );
        expect(c.meanKills, greaterThanOrEqualTo(.85 * regular.meanKills));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
