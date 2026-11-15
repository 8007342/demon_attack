// Calibration loop of continuous-swarm (tasks 3.6, 5.4): the protected
// real-shot campaign pilot over several seeds, so a per-sector comparison
// is not one seed's noise. Off by default (about 40 s); run with
//   flutter test --dart-define=SWARM_CALIBRATION=<tag> \
//     test/swarm_calibration_test.dart
// It writes .cache/swarm-calibration-<tag>.json and a Markdown table.
import 'dart:convert';
import 'dart:io';

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'campaign_playtest_test.dart' show steer;
import 'support/average_pilot.dart';
import 'support/swarm_metrics.dart';

const seeds = [1982, 7, 21, 42, 99, 314, 2718, 5150];

void main() {
  const define = String.fromEnvironment('SWARM_CALIBRATION');
  final tag = define.isNotEmpty
      ? define
      : Platform.environment['SWARM_CALIBRATION'];
  test('campaign pilot over ${seeds.length} seeds', () {
    final rows = <WaveMetrics>[];
    // demon-intelligence task 7.1: tiers, dives, rushes, skill ("expert").
    final intel = IntelMetrics();
    for (final difficulty in Difficulty.values) {
      for (final seed in seeds) {
        final model = ArcadeModel(seed: seed)..start(difficulty: difficulty);
        final metrics = SwarmMetrics();
        for (
          var frame = 0;
          frame < 900000 && model.mode != RunMode.completed;
          frame++
        ) {
          if (model.combat) {
            model.invulnerable = 2;
            steer(model, oracle: false);
          }
          model.update(1 / 60);
          metrics.observe(model, 1 / 60, model.takeEvents());
          intel.observe(model, 1 / 60);
          intel.observeEvents(model.takeGameEvents(), model);
        }
        expect(model.mode, RunMode.completed, reason: '$difficulty $seed');
        rows.addAll(metrics.rows);
      }
    }
    final all = SwarmMetrics()..rows.addAll(rows);
    final summary = [
      for (final s in all.summary())
        {
          'mode': s.mode,
          'sector': s.sector,
          'waves': s.waves,
          'clear': s.meanClear,
          'wall': s.meanWall,
          'hit': s.hitRatio,
          'aimed': s.aimedRatio,
          'peakActive': s.peakActive,
          'peakHostile': s.peakHostile,
        },
    ];
    final fits = {
      for (final m in ['easy', 'normal', 'hard']) m: all.fitEfficiency(m),
    };
    Directory('.cache').createSync(recursive: true);
    File('.cache/swarm-calibration-$tag.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'seeds': seeds,
        'summary': summary,
        'efficiency': fits,
        'intel': intel.toJson(),
      }),
    );
    File('.cache/swarm-calibration-$tag.md').writeAsStringSync(all.markdown());
  }, skip: tag == null ? 'set SWARM_CALIBRATION=<tag> to run' : null);

  // Task 5.5: the Average pilot (not invulnerable) per sector; lives lost
  // are reported, never asserted (the W4 baseline). demon-intelligence
  // task 7.2: all eight seeds (four were too noisy for a +0.3 bound), and
  // the intel metrics of this pilot ("average").
  test('average pilot: lives lost per sector', () {
    final b = StringBuffer()
      ..writeln(
        '| Mode | Route | Sector | Lives lost (mean of seeds) | Cleared |',
      )
      ..writeln('|---|---:|---:|---:|---:|');
    final intel = IntelMetrics();
    for (final difficulty in Difficulty.values) {
      for (final route in [0, 1, 2]) {
        for (var sector = 1; sector <= 4; sector++) {
          var lost = 0, cleared = 0;
          for (final seed in seeds) {
            final m = ArcadeModel(seed: seed)
              ..startAt(difficulty: difficulty, sector: sector, route: route);
            m.lives = 99;
            final pilot = AveragePilot(seed: seed);
            for (var f = 0; f < 60 * 900 && m.level == sector; f++) {
              if (m.mode == RunMode.salvage) {
                cleared++;
                break;
              }
              if (m.combat) pilot.steer(m, 1 / 60);
              m.update(1 / 60);
              m.takeEvents();
              intel.observe(m, 1 / 60);
              intel.observeEvents(m.takeGameEvents(), m);
            }
            lost += 99 - m.lives;
          }
          b.writeln(
            '| ${difficulty.name} | $route | $sector | '
            '${(lost / seeds.length).toStringAsFixed(2)} | '
            '$cleared/${seeds.length} |',
          );
        }
      }
    }
    Directory('.cache').createSync(recursive: true);
    File('.cache/swarm-average-$tag.md').writeAsStringSync(b.toString());
    File('.cache/swarm-average-$tag.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(intel.toJson()),
    );
  }, skip: tag == null ? 'set SWARM_CALIBRATION=<tag> to run' : null);
}
