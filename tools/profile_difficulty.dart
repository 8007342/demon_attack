// dart run tools/profile_difficulty.dart /tmp/calibration-pilot.json
// A protected deterministic pilot measures workload, not human survival or fun.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';

void steer(ArcadeModel model) {
  final boss = model.boss;
  if (boss != null) {
    final flight = (ArcadeModel.shipY - boss.y) / 390;
    model.moveTo(boss.forecastX(flight, model.speed));
  } else if (model.demons.isNotEmpty) {
    final d = model.demons.first;
    final flight = (ArcadeModel.shipY - d.y) / 390;
    final time = model.levelClock + flight;
    final x = d.isLarge
        ? d.x
        : d.dive > 0
        ? d.targetX + (d.x - d.targetX) * math.exp(-1.8 * flight)
        : d.homeX +
              math.sin(time * (.9 + d.kind * .12) * model.speed + d.seed) * 29 +
              math.sin(time * .44 * model.policy.hostileRate) * 13;
    model.moveTo(x);
  }
}

void main(List<String> args) {
  final results = <Map<String, Object?>>[];
  for (final difficulty in Difficulty.values) {
    final m = ArcadeModel(seed: 1982)..start(difficulty: difficulty);
    final waves = <Map<String, Object?>>[];
    Map<String, Object?>? current;
    var startMs = 0, peakActive = 0, peakBullets = 0, peakElites = 0;
    var completed = false;
    void finishWave() {
      if (current != null) {
        current['activeMilliseconds'] = m.activeMilliseconds - startMs;
        waves.add(current);
      }
    }

    for (var frame = 0; frame < 900000; frame++) {
      for (final event in m.takeEvents()) {
        if (event == 'checkpoint') {
          finishWave();
          startMs = m.activeMilliseconds;
          current = {
            'route': m.cycle,
            'sector': m.level,
            'wave': m.wave,
            'entryPowers': m.activePowers.map((p) => p.name).toList(),
            'poweredFrames': 0,
            'largeFrames': 0,
            'volleys': 0,
          };
        } else if (event == 'shot' && current != null) {
          current['volleys'] = (current['volleys'] as int) + 1;
        }
      }
      if (m.mode == RunMode.completed) {
        finishWave();
        completed = true;
        break;
      }
      if (m.combat) {
        if (current != null) {
          if (m.activePowers.isNotEmpty) {
            current['poweredFrames'] = (current['poweredFrames'] as int) + 1;
          }
          if (m.hasPower(Power.large)) {
            current['largeFrames'] = (current['largeFrames'] as int) + 1;
          }
        }
        m.invulnerable = 2;
        steer(m);
        peakActive = math.max(peakActive, m.demons.length);
        peakElites = math.max(
          peakElites,
          m.demons.where((d) => !d.isLarge && d.elite).length,
        );
        peakBullets = math.max(
          peakBullets,
          m.shots.where((s) => s.hostile).length,
        );
      }
      m.update(1 / 60);
    }
    if (!completed) {
      throw StateError('${difficulty.name} campaign failed to complete');
    }
    final ordinary = waves.where((w) => w['sector'] != 5).toList();
    final times = ordinary.map((w) => w['activeMilliseconds'] as int).toList()
      ..sort();
    results.add({
      'mode': difficulty.name,
      'completed': completed,
      'medals': m.medals,
      'activeMilliseconds': m.activeMilliseconds,
      'kills': m.kills,
      'medianOrdinaryMilliseconds': times[times.length ~/ 2],
      'p95OrdinaryMilliseconds': times[((times.length - 1) * .95).round()],
      'peakActive': peakActive,
      'peakHostileBullets': peakBullets,
      'peakOrdinaryElites': peakElites,
      'waves': waves,
    });
  }
  final report = {
    'seed': 1982,
    'method': 'Protected real-projectile pilot; fixed steering; no human survival inference. Includes organic power pickups. Cinematic time excluded.',
    'modes': results,
  };
  final output = args.isEmpty ? '/tmp/calibration-pilot.json' : args.first;
  File(output)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  for (final result in results) {
    stdout.writeln(
      '${result['mode']}: ${result['activeMilliseconds']}ms, median wave ${result['medianOrdinaryMilliseconds']}ms, p95 ${result['p95OrdinaryMilliseconds']}ms, peak ${result['peakActive']} enemies/${result['peakHostileBullets']} bullets',
    );
  }
}
