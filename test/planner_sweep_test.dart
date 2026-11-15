// demon-intelligence task 2.4: the planner weight sweep, a test-only
// harness over 2 000 synthetic multi-shot states plus the teacher's
// held-out parity set. Off by default (a few seconds); run with
//   flutter test --dart-define=PLANNER_SWEEP=true test/planner_sweep_test.dart
// It writes .cache/planner-sweep.md. The default run checks the weights
// the design note records (design.md §3, "Weight tuning").
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/game/demon_planner.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demon_planner_test.dart' show at, parityConfig, teacherClearance, up;

class Synthetic {
  Synthetic(this.state, this.shots);
  final PlanState state;
  final List<Shot> shots;
}

/// 2 000 seeded states: 1-6 player shots below a creature, a third of them
/// angled, a quarter with no threat at all.
List<Synthetic> synthetic() {
  final r = math.Random(2026);
  return [
    for (var i = 0; i < 2000; i++)
      () {
        final x = 30 + r.nextDouble() * 300, y = 60 + r.nextDouble() * 200;
        final k = 1 + r.nextInt(6);
        final safe = r.nextDouble() < .25;
        return Synthetic(at(x, y, crowd: r.nextDouble() * 2 - 1), [
          for (var j = 0; j < k; j++)
            up(
              x + (safe ? 1 : 0) * 80 + (r.nextDouble() * 2 - 1) * 50,
              y + 30 + r.nextDouble() * 320,
              vx: r.nextDouble() < .33 ? (r.nextDouble() * 2 - 1) * 90 : 0,
            ),
        ]);
      }(),
  ];
}

class Score {
  double parity = 0, survival = 0, calm = 0;
  double get total => parity + survival + .5 * calm;
}

/// Whether manoeuvre [a] meets a shot (true positions, hit half width 16).
bool hits(Synthetic s, Manoeuvre a, PlannerConfig cfg) {
  final (raw, dy) = DemonPlanner.displacement(a, s.state, cfg);
  final dx = (s.state.x + raw).clamp(20.0, 340.0) - s.state.x;
  return DemonPlanner.danger(
        s.state.x,
        s.state.y,
        dx / cfg.duration,
        dy / cfg.duration,
        cfg.duration,
        s.shots,
        radius: 16,
        delay: 0,
        foresight: cfg.foresight,
      ) >
      0;
}

Score evaluate(
  PlannerWeights w,
  List<List<double>> fixtures,
  List<Synthetic> states,
) {
  final p = DemonPlanner(1);
  final score = Score();
  final t1 = PlannerConfig(
    candidates: parityConfig.candidates,
    delay: 0,
    foresight: parityConfig.foresight,
    temperature: 0,
    margin: parityConfig.margin,
    side: parityConfig.side,
    yScale: parityConfig.yScale,
    weights: w,
  );
  var n = 0, agree = 0;
  for (final v in fixtures) {
    final label = v[10].toInt();
    if (label == 3) continue;
    if (![0, 1, 2].any((a) => teacherClearance(v, a) >= 24)) continue;
    n++;
    final c = p.choose(at(v[0], v[1], crowd: v[7]), t1, [
      up(v[2], v[3], vx: v[4]),
    ]);
    if (c.index == label) agree++;
  }
  score.parity = agree / n;
  final t2 = PlannerConfig(
    candidates: PlannerConfig.hunterEvade,
    delay: 0,
    foresight: .55,
    temperature: 0,
    weights: w,
  );
  var escapable = 0, survived = 0, quiet = 0, held = 0;
  for (final s in states) {
    final c = p.choose(s.state, t2, s.shots);
    final threatened = hits(s, Manoeuvre.hold, t2);
    if (!threatened) {
      quiet++;
      if (c == Manoeuvre.hold) held++;
      continue;
    }
    if (!t2.candidates.any((a) => !hits(s, a, t2))) continue;
    escapable++;
    if (!hits(s, c, t2)) survived++;
  }
  score.survival = survived / escapable;
  score.calm = held / quiet;
  return score;
}

List<List<double>> fixtures() {
  final data = jsonDecode(
    File('test/fixtures/policy_heldout.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return [
    for (final r in (data['rows'] as List).cast<List<dynamic>>())
      [for (final x in r) (x as num).toDouble()],
  ];
}

void main() {
  const sweep = bool.fromEnvironment('PLANNER_SWEEP');
  test('chosen planner weights (design.md §3)', () {
    final s = evaluate(const PlannerWeights(), fixtures(), synthetic());
    // ignore: avoid_print
    print(
      'default weights: parity ${(s.parity * 100).toStringAsFixed(1)} %, '
      'survival ${(s.survival * 100).toStringAsFixed(1)} %, '
      'calm ${(s.calm * 100).toStringAsFixed(1)} %',
    );
    expect(s.parity, greaterThanOrEqualTo(.95));
    expect(s.survival, greaterThanOrEqualTo(.85));
    expect(s.calm, greaterThanOrEqualTo(.85));
  });

  test('weight sweep', () {
    final fx = fixtures(), states = synthetic();
    final rows = <(PlannerWeights, Score)>[];
    for (final danger in [1.0, 3.0, 5.0, 8.0, 12.0]) {
      for (final wall in [.5, 1.0]) {
        for (final crowd in [.1, .2, .4]) {
          for (final leash in [.25, .5, 1.0]) {
            {
              final w = PlannerWeights(
                danger: danger,
                wall: wall,
                crowd: crowd,
                leash: leash,
              );
              rows.add((w, evaluate(w, fx, states)));
            }
          }
        }
      }
    }
    rows.sort((a, b) => b.$2.total.compareTo(a.$2.total));
    final b = StringBuffer()
      ..writeln(
        '| danger | wall | crowd | leash | parity | survival | calm | score |',
      )
      ..writeln('|---:|---:|---:|---:|---:|---:|---:|---:|');
    for (final (w, s) in rows.take(20)) {
      b.writeln(
        '| ${w.danger} | ${w.wall} | ${w.crowd} | ${w.leash} | '
        '${(s.parity * 100).toStringAsFixed(1)} % | '
        '${(s.survival * 100).toStringAsFixed(1)} % | '
        '${(s.calm * 100).toStringAsFixed(1)} % | ${s.total.toStringAsFixed(3)} |',
      );
    }
    Directory('.cache').createSync(recursive: true);
    File('.cache/planner-sweep.md').writeAsStringSync(b.toString());
  }, skip: sweep ? null : 'set PLANNER_SWEEP=true to run');
}
