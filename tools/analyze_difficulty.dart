// Run: dart tools/analyze_difficulty.dart /tmp/difficulty-before
// Audits real generated entities, not a second implementation of balance rules.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';

Map<String, Object?> actor(Demon d) => {
  'kind': d.kind,
  'large': d.isLarge,
  'elite': d.elite,
  'escort': d.isEscort,
  'hp': d.maxHp,
  'shield': d.shieldMax,
  'armor': d.armorMax,
  'homeX': d.homeX,
  'homeY': d.homeY,
};
int shots(Map<String, Object?> d, int damage) => [
  'hp',
  'shield',
  'armor',
].fold<int>(0, (n, key) => n + ((d[key] as int) / damage).ceil());
Map<String, Object?> group(
  String name,
  Iterable<Demon> demons,
  double seconds,
) {
  final actors = demons.map(actor).toList();
  final ordinary = actors.where((d) => d['large'] == false).toList();
  return {
    'name': name,
    'activeSeconds': seconds,
    'count': actors.length,
    'ordinaryHpMin': ordinary.isEmpty
        ? null
        : ordinary.map((d) => d['hp'] as int).reduce(math.min),
    'ordinaryHpMax': ordinary.isEmpty
        ? null
        : ordinary.map((d) => d['hp'] as int).reduce(math.max),
    'elites': ordinary.where((d) => d['elite'] == true).length,
    'standardShots': actors.fold<int>(0, (n, d) => n + shots(d, 1)),
    'powerfulShots': actors.fold<int>(0, (n, d) => n + shots(d, 2)),
    'actors': actors,
  };
}

Map<String, Object?> audit(Difficulty mode, int route, int sector, int wave) {
  final m = ArcadeModel(seed: 1982)
    ..restoreCheckpoint({
      'difficulty': mode.name,
      'routeIndex': route,
      'sector': sector,
      'wave': wave,
    });
  m.mode = RunMode.playing;
  m.invulnerable = 100000;
  final groups = <Map<String, Object?>>[group('initial', m.demons, 0)];
  final seen = m.demons.toSet();
  final needsEscort = m.demons.any((d) => d.isLarge);
  var peak = m.demons.length, lastArrival = 0, peakShots = 0;
  var finished = false;
  for (var frame = 0; frame < 7200; frame++) {
    peak = math.max(peak, m.demons.length);
    peakShots = math.max(
      peakShots,
      m.demons.fold<int>(0, (n, d) => n + d.hp + d.shield + d.armor),
    );
    if (m.flocksRemaining == 0 && (!needsEscort || m.escortSpawned)) {
      finished = true;
      break;
    }
    // Let waves fill naturally. If admission stalls, make controlled casualties
    // until the next real arrival; never remove a waiting sentinel by hand.
    if (frame - lastArrival > 210 && frame % 6 == 0) {
      final victim = m.demons
          .where((d) => !d.isLarge && !d.entering)
          .firstOrNull;
      if (victim != null) {
        while (m.demons.contains(victim)) {
          m.hitDemon(victim, damage: 100000);
        }
      }
    }
    m.update(1 / 60);
    m.shots.removeWhere((s) => !s.hostile);
    final fresh = m.demons.where((d) => !seen.contains(d)).toList();
    if (fresh.isNotEmpty) {
      final ordinary = fresh.where((d) => !d.isEscort).toList();
      final escort = fresh.where((d) => d.isEscort).toList();
      if (ordinary.isNotEmpty) {
        groups.add(
          group('flock_${m.flocksSpawned}', ordinary, (frame + 1) / 60),
        );
      }
      if (escort.isNotEmpty) {
        groups.add(group('escort', escort, (frame + 1) / 60));
      }
      seen.addAll(fresh);
      lastArrival = frame;
    }
  }
  if (!finished) {
    throw StateError('Admission failed: ${mode.name} $route/$sector/$wave');
  }
  final total = groups.fold<int>(0, (n, g) => n + (g['standardShots'] as int));
  final powerful = groups.fold<int>(
    0,
    (n, g) => n + (g['powerfulShots'] as int),
  );
  return {
    'mode': mode.name,
    'route': route,
    'sector': sector,
    'wave': wave,
    'groups': groups,
    'count': groups.fold<int>(0, (n, g) => n + (g['count'] as int)),
    'standardShots': total,
    'powerfulShots': powerful,
    'initialStandardShots': groups.first['standardShots'],
    'waveToInitialBudgetRatio': total / (groups.first['standardShots'] as int),
    'observedPeakActive': peak,
    'observedPeakLiveDefense': peakShots,
  };
}

String compactSummary(List<Map<String, Object?>> waves, String label) {
  final out = StringBuffer('# Difficulty calibration: $label\n\n');
  out.writeln(
    'Seed 1982; 318 actual generated ordinary-wave entrances across three modes and five routes. Every initial roster, finite reinforcement and dedicated escort is counted once. Controlled casualties unblock admission; this is a defense-budget audit, not a player skill or clear-time estimate.\n',
  );
  out.writeln(
    'Reproduce current data: `dart tools/analyze_difficulty.dart /tmp/difficulty-current`. The command writes per-wave JSON/Markdown plus a compact summary. Historical baseline uses commit `12cde0b`; current formulas are documented in [difficulty-calibration.md](difficulty-calibration.md).\n',
  );
  out.writeln(
    '| Mode | Route | Waves | Enemy count range | Standard hit range | Powerful hit range | Peak active | Max elite births | Max whole/opening defense |',
  );
  out.writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (final mode in Difficulty.values) {
    for (var route = 0; route < 5; route++) {
      final rows = waves
          .where((w) => w['mode'] == mode.name && w['route'] == route)
          .toList();
      String range(String key) {
        final values = rows.map((w) => w[key] as int);
        return '${values.reduce(math.min)}–${values.reduce(math.max)}';
      }

      final peak = rows
          .map((w) => w['observedPeakActive'] as int)
          .reduce(math.max);
      final elites = rows
          .map(
            (w) => (w['groups'] as List).fold<int>(
              0,
              (n, g) => n + (g['elites'] as int),
            ),
          )
          .reduce(math.max);
      final ratio = rows
          .map((w) => w['waveToInitialBudgetRatio'] as num)
          .reduce(math.max);
      out.writeln(
        '| ${mode.name} | ${route + 1} | ${rows.length} | ${range('count')} | ${range('standardShots')} | ${range('powerfulShots')} | $peak | $elites | ${ratio.toStringAsFixed(2)} |',
      );
    }
  }
  out.writeln(
    '\nStandard hits sum actual hull, shield and armor. Powerful hits round each defense layer separately at two damage per hit. Large preserves damage per target: with zero overlap it has the Standard budget; Powerful + Large has the Powerful budget. With perfect simultaneous overlap, an individual arrival group needs at least the largest per-enemy layered hit budget; that is a theoretical coverage bound, not measured throughput. Spread and Large cannot stack, and Rapid and Powerful cannot stack. Current Large radii are Easy 32, Normal 30, Hard 28.',
  );
  return out.toString();
}

void main(List<String> args) {
  if (args.firstOrNull == '--summarize') {
    final decoded =
        jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
    final waves = (decoded['waves'] as List)
        .map((w) => Map<String, Object?>.from(w as Map))
        .toList();
    File(args[2]).writeAsStringSync(compactSummary(waves, args[3]));
    return;
  }
  final prefix = args.isEmpty ? '/tmp/demon-difficulty-audit' : args.first;
  final waves = <Map<String, Object?>>[];
  for (final mode in Difficulty.values) {
    for (var route = 0; route < 5; route++) {
      for (var sector = 1; sector <= 4; sector++) {
        final count = 3 + (sector - 1) ~/ 2 + math.min(route, 3);
        for (var wave = 1; wave <= count; wave++) {
          waves.add(audit(mode, route, sector, wave));
        }
      }
    }
  }
  final output = {
    'seed': 1982,
    'waveCount': waves.length,
    'method': 'Actual spawned entities; hold live rosters, then controlled casualties unblock finite arrivals. No aim, accuracy, travel-time or survival estimate.',
    'waves': waves,
  };
  File('$prefix.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  final md = StringBuffer('# Actual generated difficulty audit\n\n');
  md.writeln(
    'Seed1982; ${waves.length} wave entrances. Budgets count each actual hull/shield/armor layer; Powerful rounds each layer up separately.\n',
  );
  md.writeln(
    '| Mode | Route | Sector | Wave | Enemies | Standard shots | Powerful shots | Initial shots | Whole/initial | Peak active |',
  );
  md.writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (final w in waves) {
    md.writeln(
      '| ${w['mode']} | ${(w['route'] as int) + 1} | ${w['sector']} | ${w['wave']} | ${w['count']} | ${w['standardShots']} | ${w['powerfulShots']} | ${w['initialStandardShots']} | ${(w['waveToInitialBudgetRatio'] as double).toStringAsFixed(2)} | ${w['observedPeakActive']} |',
    );
  }
  File('$prefix.md').writeAsStringSync(md.toString());
  File('$prefix-summary.md')
      .writeAsStringSync(compactSummary(waves, 'current formulas'));
  stdout.writeln(
    'Captured ${waves.length} waves to $prefix.json and $prefix.md',
  );
  for (final mode in Difficulty.values) {
    final subset = waves.where((w) => w['mode'] == mode.name).toList();
    final first = subset.first;
    final largest = subset.reduce(
      (a, b) =>
          (a['standardShots'] as int) > (b['standardShots'] as int) ? a : b,
    );
    stdout.writeln(
      '${mode.name}: first wave=${first['standardShots']} shots/${first['count']} enemies; peak wave=${largest['standardShots']} shots/${largest['count']} enemies at route${(largest['route'] as int) + 1}/sector${largest['sector']}/wave${largest['wave']}',
    );
  }
}
