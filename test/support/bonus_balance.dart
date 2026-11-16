// bonus-balance: a bonus level measured against the regular sector it
// replaces, with the calibration pilots (plan/calibration-current.md,
// "Bonus balance"). Pure model simulation, 60 Hz.
//
// - Expert: the protected real-shot campaign pilot (`steer(oracle: false)`),
//   invulnerable. Duration is combat seconds from the level's start to its
//   last kill; enemies are its kills (it clears every creature); score is
//   what it banked; the possible score adds what the level's award cap
//   still allowed beyond its kill points.
// - Average: `AveragePilot` with 99 lives; difficulty is the lives it lost
//   before the sector's last kill.
import 'package:demon_attack/game/model.dart';

import '../campaign_playtest_test.dart' show steer;
import 'average_pilot.dart';

class BalanceCell {
  BalanceCell(this.difficulty, this.route, this.sector, this.level);
  final Difficulty difficulty;
  final int route, sector;

  /// The bonus level's id; null: the regular sector.
  final String? level;
  int runs = 0, averageRuns = 0;
  double combat = 0, kills = 0, score = 0, possible = 0, lives = 0, par = 0;

  double get meanCombat => combat / runs;
  double get meanKills => kills / runs;
  double get meanScore => score / runs;
  double get meanPossible => possible / runs;
  double get meanLives => lives / averageRuns;
  double get meanPar => par / runs;
}

/// The expert's run of one sector (or bonus level) on one seed.
void measureExpert(BalanceCell cell, int seed) {
  final m = ArcadeModel(seed: seed)
    ..startAt(
      difficulty: cell.difficulty,
      sector: cell.sector,
      route: cell.route,
      runSeed: cell.level == null ? null : seed,
      bonus: cell.level,
    );
  var combat = 0.0;
  for (var f = 0; f < 60 * 900 && m.mode != RunMode.salvage; f++) {
    if (m.combat) {
      m.invulnerable = 2;
      steer(m, oracle: false);
      chaseCrate(m);
      combat += 1 / 60;
    }
    m.update(1 / 60);
    m.takeEvents();
    m.takeGameEvents();
  }
  cell
    ..runs += 1
    ..combat += combat
    ..kills += m.kills
    ..par += m.sectorPar
    ..score += m.score
    ..possible += m.score - m.bonusRun.extra + m.bonusCap;
}

/// Both pilots play a crate level's twist as a player would: while a
/// supply crate hangs in range above the ship with no creature between,
/// they line up under it.
void chaseCrate(ArcadeModel m) {
  SupplyCrate? best;
  for (final c in m.supplyCrates) {
    if (c.y < 30 || c.y > ArcadeModel.shipY - 120) continue;
    if (m.demons.any((d) => (d.x - c.x).abs() < 26 && d.y > c.y)) continue;
    if (best == null || (c.x - m.shipX).abs() < (best.x - m.shipX).abs()) {
      best = c;
    }
  }
  if (best != null) m.moveTo(best.x);
}

/// The Average pilot's lives lost in one sector (or bonus level).
void measureAverage(BalanceCell cell, int seed) {
  final m = ArcadeModel(seed: seed)
    ..startAt(
      difficulty: cell.difficulty,
      sector: cell.sector,
      route: cell.route,
      runSeed: cell.level == null ? null : seed,
      bonus: cell.level,
    );
  m.lives = 99;
  final pilot = AveragePilot(seed: seed);
  for (var f = 0; f < 60 * 900 && m.mode != RunMode.salvage; f++) {
    if (m.combat) {
      pilot.steer(m, 1 / 60);
      chaseCrate(m);
    }
    m.update(1 / 60);
    m.takeEvents();
    m.takeGameEvents();
  }
  cell
    ..averageRuns += 1
    ..lives += 99 - m.lives;
}

/// Every cell of [levels] (null: the regular sector) on [routes] and
/// sectors 2-4 (where a bonus level may sit), per difficulty.
List<BalanceCell> measureBalance({
  required List<String?> levels,
  List<int> routes = const [0, 1],
  List<int> seeds = const [1982, 7, 21, 42],
  List<Difficulty> difficulties = Difficulty.values,
}) {
  final cells = <BalanceCell>[];
  for (final d in difficulties) {
    for (final route in routes) {
      for (final sector in [2, 3, 4]) {
        for (final level in levels) {
          final cell = BalanceCell(d, route, sector, level);
          for (final seed in seeds) {
            measureExpert(cell, seed);
            measureAverage(cell, seed);
          }
          cells.add(cell);
        }
      }
    }
  }
  return cells;
}

/// Pooled ratio of a bonus level's [metric] over the regular sectors' on
/// the same cells (sum over sum), optionally for one difficulty.
double pooledRatio(
  List<BalanceCell> cells,
  String level,
  double Function(BalanceCell) metric, {
  Difficulty? difficulty,
}) {
  var bonus = 0.0, regular = 0.0;
  for (final c in cells) {
    if (difficulty != null && c.difficulty != difficulty) continue;
    if (c.level == level) bonus += metric(c);
    if (c.level == null) regular += metric(c);
  }
  return regular == 0 ? double.nan : bonus / regular;
}

String balanceMarkdown(List<BalanceCell> cells, List<String> levels) {
  final b = StringBuffer()
    ..writeln(
      '| Mode | Route | Sector | Level | Combat s | Enemies | Score | '
      'Possible | Lives lost (avg pilot) | Score / par |',
    )
    ..writeln('|---|---:|---:|---|---:|---:|---:|---:|---:|---:|');
  for (final c in cells) {
    b.writeln(
      '| ${c.difficulty.name} | ${c.route} | ${c.sector} | '
      '${c.level ?? 'regular'} | ${c.meanCombat.toStringAsFixed(1)} | '
      '${c.meanKills.toStringAsFixed(1)} | ${c.meanScore.round()} | '
      '${c.meanPossible.round()} | ${c.meanLives.toStringAsFixed(2)} | '
      '${(c.meanScore / c.meanPar).toStringAsFixed(2)} |',
    );
  }
  b
    ..writeln()
    ..writeln(
      '| Level | Mode | Duration | Enemies | Score | Possible | Lives lost |',
    )
    ..writeln('|---|---|---:|---:|---:|---:|---:|');
  String pct(double r) =>
      '${r >= 1 ? '+' : ''}${((r - 1) * 100).toStringAsFixed(1)} %';
  for (final level in levels) {
    for (final d in [...Difficulty.values, null]) {
      double r(double Function(BalanceCell) f) =>
          pooledRatio(cells, level, f, difficulty: d);
      b.writeln(
        '| $level | ${d?.name ?? '**pooled**'} | ${pct(r((c) => c.meanCombat))} | '
        '${pct(r((c) => c.meanKills))} | ${pct(r((c) => c.meanScore))} | '
        '${pct(r((c) => c.meanPossible))} | ${pct(r((c) => c.meanLives))} |',
      );
    }
  }
  return b.toString();
}
