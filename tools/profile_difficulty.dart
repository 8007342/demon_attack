// dart run tools/profile_difficulty.dart /tmp/calibration-pilot.json [--naive]
// A protected deterministic pilot measures workload, not human survival or fun.
// The default pilot sidesteps ground missiles and collects homing pickups;
// --naive ignores both, to measure how much the ground war threatens a pilot
// who never reacts to it.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';

/// Ground-war reactions, kept identical to test/campaign_playtest_test.dart:
/// head for a falling homing pickup, and never stand in the danger band of
/// a ground missile's fixed path.
double groundAwareX(ArcadeModel model, double x, {double reaction = 0}) {
  final pickup = model.ground.pickups.firstOrNull;
  if (pickup != null && pickup.y > 250) x = pickup.x;
  const danger =
      GroundTuning.shipHalfWidth +
      GroundTuning.missileMaxSize * GroundTuning.missileHitRatio +
      16;
  for (final m in model.ground.missiles) {
    if (m.spent || m.t > 1.1 || m.age < reaction) continue;
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

void steer(ArcadeModel model, {bool react = true, double reaction = 0}) {
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
  model.moveTo(react ? groundAwareX(model, x, reaction: reaction) : x);
}

void main(List<String> args) {
  final react = !args.contains('--naive');
  // --reaction=S: the pilot notices a missile only S seconds after launch.
  final reaction = double.parse(
    args.where((a) => a.startsWith('--reaction=')).firstOrNull?.split('=').last ??
        '0',
  );
  args = args.where((a) => !a.startsWith('--')).toList();
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
        steer(m, react: react, reaction: reaction);
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
      'ground': {
        'unitsSpawned': m.ground.unitsSpawned,
        'unitsDestroyed': m.ground.unitsDestroyed,
        'missilesLaunched': m.ground.missilesLaunched,
        'missileImpacts': m.ground.missileImpacts,
        'homingCollected': m.ground.homingCollected,
        'homingHits': m.ground.homingHits,
        'alliesSaved': m.ground.alliesSaved,
        'alliesRetreated': m.ground.alliesRetreated,
        'fleetIntactRun': m.ground.fleetIntactRun,
      },
      'waves': waves,
    });
  }
  final report = {
    'seed': 1982,
    'method': 'Protected real-projectile pilot; fixed steering; no human survival inference. Includes organic power pickups. Cinematic time excluded.',
    'pilot': react
        ? 'dodges ground missiles (reaction ${reaction}s), collects homing'
        : 'naive (ignores the ground war)',
    'modes': results,
  };
  final output = args.isEmpty ? '/tmp/calibration-pilot.json' : args.first;
  File(output)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  for (final result in results) {
    stdout.writeln(
      '${result['mode']}: ${result['activeMilliseconds']}ms, median wave ${result['medianOrdinaryMilliseconds']}ms, p95 ${result['p95OrdinaryMilliseconds']}ms, peak ${result['peakActive']} enemies/${result['peakHostileBullets']} bullets, ground ${jsonEncode(result['ground'])}',
    );
  }
}
