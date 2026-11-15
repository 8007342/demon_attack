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
import 'support/swarm_metrics.dart';

const seeds = [1982, 7, 21, 42, 99, 314, 2718, 5150];

void main() {
  const define = String.fromEnvironment('SWARM_CALIBRATION');
  final tag = define.isNotEmpty
      ? define
      : Platform.environment['SWARM_CALIBRATION'];
  test('campaign pilot over ${seeds.length} seeds', () {
    final rows = <WaveMetrics>[];
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
      const JsonEncoder.withIndent(' ')
          .convert({'seeds': seeds, 'summary': summary, 'efficiency': fits}),
    );
    File('.cache/swarm-calibration-$tag.md').writeAsStringSync(all.markdown());
  }, skip: tag == null ? 'set SWARM_CALIBRATION=<tag> to run' : null);
}
