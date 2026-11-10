import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Before/after difficulty of the swarm perspective (plan/perspective.md).
///
/// The same deterministic, non-prescient pilot plays sectors 1, 3 and 5
/// (the carrier) with the perspective off (flat legacy sizes, hitboxes and
/// entrances) and on, over several seeds. It re-plans every 0.12 s: it aims
/// at the demon nearest its own x with a lead for the shot's flight, and
/// sidesteps hostile shots, divers (using their visible contact size) and
/// ground missiles. Lives are real (hits count) but refunded, so every run
/// reaches the end of its sector. Pooled over seeds: hit rate, active time
/// to clear and lives lost must stay within ~10% of the flat game.
class _Pilot {
  _Pilot(this.replan, this.margin);

  /// Re-planning interval (s) and the shot clearance it keeps (units).
  final double replan, margin;
  double planX = 180, think = 0;

  bool _danger(ArcadeModel m, double x) {
    for (final s in m.shots) {
      if (!s.hostile || s.vy <= 0) continue;
      final t = (ArcadeModel.shipY - s.y) / s.vy;
      if (t < -.03 || t > .6) continue;
      final sx = s.x + s.vx * m.policy.hostileRate * t;
      if ((sx - x).abs() < margin) return true;
    }
    for (final d in m.demons) {
      if (d.entering || !(d.dive > 0 || d.rushing)) continue;
      if (d.y < 300 || d.y > ArcadeModel.shipY + 24) continue;
      if ((d.x - x).abs() < d.contactHalf + 6) return true;
    }
    for (final g in m.ground.missiles) {
      if (g.spent || g.t > 1.1) continue;
      if ((g.targetX - x).abs() < 30) return true;
    }
    return false;
  }

  void steer(ArcadeModel m, double dt) {
    think -= dt;
    if (think <= 0) {
      think = replan;
      var aim = m.shipX;
      final boss = m.boss;
      Demon? target;
      var best = double.infinity;
      for (final d in m.demons) {
        if (d.entering) continue;
        final score = (d.x - m.shipX).abs() - d.y * .1;
        if (score < best) {
          best = score;
          target = d;
        }
      }
      if (target != null) {
        final lead = ((ArcadeModel.shipY - target.y) / 390).clamp(0.0, 1.0);
        aim = target.x + target.vx * lead * .8;
      } else if (boss != null) {
        aim = boss.forecastX((ArcadeModel.shipY - boss.y) / 390, m.speed);
      }
      aim = aim.clamp(18.0, ArcadeModel.width - 18);
      if (_danger(m, aim)) {
        for (final step in [24.0, -24.0, 48.0, -48.0, 72.0, -72.0, 96.0]) {
          final x = (aim + step).clamp(18.0, ArcadeModel.width - 18);
          if (!_danger(m, x)) {
            aim = x;
            break;
          }
        }
      }
      planX = aim;
    }
    m.moveTo(planX);
  }
}

class _Result {
  int shots = 0, hits = 0, livesLost = 0, activeMs = 0, runs = 0;
  int contacts = 0;
  final perRunLives = <int>[];

  /// Variance of the mean lives lost per run (sample variance / n).
  double get livesVarianceOfMean {
    final n = perRunLives.length;
    if (n < 2) return 0;
    final mean = perRunLives.reduce((a, b) => a + b) / n;
    var sum = 0.0;
    for (final v in perRunLives) {
      sum += (v - mean) * (v - mean);
    }
    return sum / (n - 1) / n;
  }

  double get hitRate => hits / math.max(1, shots);
  double get seconds => activeMs / 1000 / math.max(1, runs);
  double get lives => livesLost / math.max(1, runs);
  void add(_Result o) {
    shots += o.shots;
    hits += o.hits;
    livesLost += o.livesLost;
    contacts += o.contacts;
    perRunLives.add(o.livesLost);
    activeMs += o.activeMs;
    runs += o.runs;
  }
}

_Result _play({
  required bool perspective,
  required int sector,
  required int route,
  required int seed,
  required _Pilot pilot,
}) {
  final m = ArcadeModel(seed: seed)..perspective = perspective;
  m.startAt(sector: sector, route: route);
  final r = _Result()..runs = 1;
  final seen = <Shot>{};
  var done = false;
  for (var frame = 0; frame < 60 * 60 * 12 && !done; frame++) {
    if (m.combat) pilot.steer(m, 1 / 60);
    final before = [
      for (final s in m.shots)
        if (!s.hostile) s,
    ];
    final lastY = {for (final s in before) s: s.y};
    m.update(1 / 60);
    final now = m.shots.toSet();
    for (final s in before) {
      // A friendly shot that vanished inside the arena struck something.
      if (!now.contains(s) && lastY[s]! > 8) r.hits++;
    }
    for (final s in m.shots) {
      if (!s.hostile && seen.add(s)) r.shots++;
    }
    seen.removeWhere((s) => !now.contains(s));
    for (final e in m.takeEvents()) {
      if (e == 'life') {
        r.livesLost++;
        m.lives++;
        if (m.demons.any(
          (d) =>
              (d.x - m.shipX).abs() < d.contactHalf + 4 &&
              (d.y - ArcadeModel.shipY).abs() < d.contactHalf + 4,
        )) {
          r.contacts++;
        }
      }
      if (e == 'levelclear' || e == 'bossDefeated') done = true;
    }
    if (m.mode == RunMode.gameOver) break;
  }
  expect(done, isTrue, reason: 'sector $sector route $route seed $seed');
  r.activeMs = m.activeMilliseconds;
  return r;
}

void main() {
  final seeds = [for (var i = 0; i < 96; i++) 1982 + 7919 * i];
  // Two pilot temperaments, pooled, so one pilot's quirks cannot pass
  // for a difficulty change: sharp (0.12 s, 15 units), sluggish (0.2 s,
  // 12 units).
  const pilots = [(.12, 15.0), (.2, 12.0)];
  final table = StringBuffer(
    '| Sector | Route | Mode | Hit rate | Clear s | Lives lost/run | of which contact |\n'
    '|---|---:|---|---:|---:|---:|---:|\n',
  );
  // ignore: avoid_print
  tearDownAll(() => print(table));
  for (final (sector, route) in [
    (1, 0),
    (3, 0),
    (5, 0),
    (1, 1),
    (3, 1),
    (5, 1),
  ]) {
    test('perspective keeps sector $sector route $route difficulty', () {
      final flat = _Result(), depth = _Result();
      for (final (replan, margin) in pilots) {
        for (final seed in seeds) {
          for (final (r, on) in [(flat, false), (depth, true)]) {
            r.add(
              _play(
                perspective: on,
                sector: sector,
                route: route,
                seed: seed,
                pilot: _Pilot(replan, margin),
              ),
            );
          }
        }
      }
      for (final (name, r) in [('flat', flat), ('depth', depth)]) {
        table.writeln(
          '| $sector | $route | $name | ${(r.hitRate * 100).toStringAsFixed(1)}% '
          '| ${r.seconds.toStringAsFixed(1)} | ${r.lives.toStringAsFixed(2)} '
          '| ${(r.contacts / r.runs).toStringAsFixed(2)} |',
        );
      }
      expect(depth.hitRate / flat.hitRate, inInclusiveRange(.9, 1.1));
      expect(depth.seconds / flat.seconds, inInclusiveRange(.9, 1.1));
      // Lives lost are small, overdispersed counts (one loss sets up the
      // next): within 10% of the flat rate, or within two standard errors
      // of the measured run-to-run spread where 10% is finer than these
      // runs can resolve.
      final noise =
          2 * math.sqrt(flat.livesVarianceOfMean + depth.livesVarianceOfMean);
      table.writeln(
        '| | | 2 SE of the lives difference: ${noise.toStringAsFixed(2)} | | | | |',
      );
      expect(
        (depth.lives - flat.lives).abs(),
        lessThanOrEqualTo(math.max(flat.lives * .1, noise)),
      );
    });
  }
}
