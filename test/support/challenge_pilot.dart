// bonus-challenges: the earn rate of each level's perfect-run challenge
// (openspec/changes/bonus-challenges design §5; plan/calibration-current.md,
// "Bonus challenges"). Pure model simulation, 60 Hz, with two pilots:
//
// - Average: the calibration's `AveragePilot` (99 lives) plus `chaseCrate`,
//   exactly as the bonus-balance gate plays a level: it does not try for
//   the challenge.
// - Challenger: the same pilot trying for it, as a player who read the
//   badge would: 0.25 s after it sees one, it slides under falling cargo it
//   can still reach, lines up under a crate that is about to pass, and
//   steps out of a lightning tell's column. Still 70 % aim, no oracle.
//
// Every loop is bounded by a frame count.
import 'package:demon_attack/game/model.dart';

import 'average_pilot.dart';
import 'bonus_balance.dart' show chaseCrate;

class ChallengeCell {
  ChallengeCell(this.difficulty, this.route, this.sector, this.level);
  final Difficulty difficulty;
  final int route, sector;
  final String level;
  int runs = 0, earned = 0, cleared = 0;
  final Map<String, int> failedBy = {};

  double get rate => runs == 0 ? 0 : earned / runs;
}

/// Seconds a pilot needs before it reacts to something it sees.
const challengeReaction = .25;

/// One run of [cell] on [seed]; [challenger]: the pilot tries for it.
void measureChallenge(
  ChallengeCell cell,
  int seed, {
  required bool challenger,
}) {
  final m = ArcadeModel(seed: seed)
    ..startAt(
      difficulty: cell.difficulty,
      sector: cell.sector,
      route: cell.route,
      runSeed: seed,
      bonus: cell.level,
    );
  m.lives = 99;
  final pilot = AveragePilot(seed: seed);
  final seen = <Object, double>{};
  for (var f = 0; f < 60 * 900 && m.mode != RunMode.salvage; f++) {
    if (m.combat) {
      pilot.steer(m, 1 / 60);
      chaseCrate(m);
      if (challenger) _tryFor(m, seen);
    }
    m.update(1 / 60);
    m.takeEvents();
    m.takeGameEvents();
  }
  final c = m.bonusChallenge;
  cell.runs++;
  if (m.mode == RunMode.salvage) cell.cleared++;
  if (c != null && c.earned) cell.earned++;
  if (c != null && c.failed) {
    final by = c.failedBy ?? 'short';
    cell.failedBy[by] = (cell.failedBy[by] ?? 0) + 1;
  }
}

void _tryFor(ArcadeModel m, Map<Object, double> seen) {
  const dt = 1 / 60;
  // Age what is on screen; forget what left it.
  final now = <Object>{
    ...m.supplyCrates,
    ...m.pickups,
    if (m.bonusMechanic case final StormfrontMechanic s) ...s.cell.strikes,
  };
  seen.removeWhere((k, _) => !now.contains(k));
  for (final o in now) {
    seen[o] = (seen[o] ?? 0) + dt;
  }
  bool noticed(Object o) => (seen[o] ?? 0) >= challengeReaction;

  // 1. A crate about to pass the ship's row: get under it.
  SupplyCrate? low;
  for (final c in m.supplyCrates) {
    if (!noticed(c) || c.y < ArcadeModel.shipY - 220) continue;
    if (low == null || c.y > low.y) low = c;
  }
  if (low != null) m.moveTo(low.x);

  // 2. Falling cargo: the lowest one still above the catch box.
  Pickup? cargo;
  for (final p in m.pickups) {
    if (!noticed(p) || p.y > ArcadeModel.shipY + 20) continue;
    if (cargo == null || p.y > cargo.y) cargo = p;
  }
  if (cargo != null) m.moveTo(cargo.x);

  // 3. A lightning tell on the ship's column: step out of it, to the
  // roomier side, away from any fork.
  if (m.bonusMechanic case final StormfrontMechanic storm) {
    for (final s in storm.cell.strikes) {
      if (!s.telling || !noticed(s)) continue;
      // Clear of the bright band the tell draws (its column), not just
      // the lethal core.
      final reach = s.column + 8;
      if ((s.x - m.shipX).abs() > reach) continue;
      final forks = [
        for (final o in storm.cell.strikes)
          if (o.telling && !identical(o, s)) o.x,
      ];
      var side = m.shipX < 180 ? 1.0 : -1.0;
      if (forks.any((x) => (x - (s.x + side * 50)).abs() < 40)) side = -side;
      m.moveTo(s.x + side * 50);
      break;
    }
  }
}

/// Every cell of [levels] on [routes] and sectors 2-4, per difficulty.
List<ChallengeCell> measureChallenges({
  required List<String> levels,
  required bool challenger,
  List<int> routes = const [0, 1],
  List<int> seeds = const [1982, 7, 21, 42, 99, 314, 2718, 5150],
  List<Difficulty> difficulties = Difficulty.values,
}) {
  final cells = <ChallengeCell>[];
  for (final d in difficulties) {
    for (final route in routes) {
      for (final sector in [2, 3, 4]) {
        for (final level in levels) {
          final cell = ChallengeCell(d, route, sector, level);
          for (final seed in seeds) {
            measureChallenge(cell, seed, challenger: challenger);
          }
          cells.add(cell);
        }
      }
    }
  }
  return cells;
}

/// Pooled earn rate of [level] (optionally one difficulty).
double pooledRate(List<ChallengeCell> cells, String level, {Difficulty? d}) {
  var runs = 0, earned = 0;
  for (final c in cells) {
    if (c.level != level || (d != null && c.difficulty != d)) continue;
    runs += c.runs;
    earned += c.earned;
  }
  return runs == 0 ? 0 : earned / runs;
}

String challengeMarkdown(
  Map<String, List<ChallengeCell>> byPilot,
  List<String> levels,
) {
  final b = StringBuffer()
    ..writeln(
      '| Level | Pilot | Easy | Normal | Hard | **Pooled** | Failed by |',
    )
    ..writeln('|---|---|---:|---:|---:|---:|---|');
  String pct(double r) => '${(r * 100).toStringAsFixed(1)} %';
  for (final level in levels) {
    for (final MapEntry(key: pilot, value: cells) in byPilot.entries) {
      final by = <String, int>{};
      for (final c in cells.where((c) => c.level == level)) {
        c.failedBy.forEach((k, v) => by[k] = (by[k] ?? 0) + v);
      }
      b.writeln(
        '| $level | $pilot | '
        '${pct(pooledRate(cells, level, d: Difficulty.easy))} | '
        '${pct(pooledRate(cells, level, d: Difficulty.normal))} | '
        '${pct(pooledRate(cells, level, d: Difficulty.hard))} | '
        '**${pct(pooledRate(cells, level))}** | '
        '${by.entries.map((e) => '${e.key} ${e.value}').join(', ')} |',
      );
    }
  }
  return b.toString();
}
