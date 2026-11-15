// demon-intelligence tasks 2.2-2.4: the energy planner (design §3).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/game/demon_planner.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

Shot up(double x, double y, {double vx = 0, double age = 1}) =>
    Shot(x, y, vx, -385)..age = age;

PlanState at(double x, double y, {double crowd = 0}) => PlanState()
  ..x = x
  ..y = y
  ..leashX = x
  ..crowd = crowd;

/// The T1 config in the teacher's geometry: no perception delay (the
/// teacher sees the shot where it is), its 24-u clearance (half width 16
/// + 8), its 26-u evade span and its 0.85 vertical distance scale.
const parityConfig = PlannerConfig(
  candidates: [Manoeuvre.hold, Manoeuvre.sideL, Manoeuvre.sideR],
  delay: 0,
  foresight: .32,
  temperature: 0,
  margin: 8,
  side: 26,
  yScale: .85,
);

/// The teacher's own clearance of an action (scripts/train-policy.mjs
/// evaluateTeacherUtility): the minimum scaled distance to the shot over
/// its eased 0.32 s path.
double teacherClearance(List<double> v, int action) {
  final dx = action == 0 ? 0.0 : (action == 1 ? -26.0 : 26.0);
  var best = double.infinity;
  for (var i = 1; i <= 10; i++) {
    final p = i / 10, t = p * .32, ease = p * p * (3 - 2 * p);
    final cx = (v[0] + dx * ease).clamp(20.0, 340.0);
    final sx = v[2] + v[4] * t, sy = v[3] - 385 * t;
    final d = math.sqrt(
      (cx - sx) * (cx - sx) + (v[1] - sy) * (v[1] - sy) * .85 * .85,
    );
    best = math.min(best, d);
  }
  return best;
}

void main() {
  unitTests();
  test('teacher parity on the held-out fixtures', () {
    final data = jsonDecode(
      File('test/fixtures/policy_heldout.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final rows = (data['rows'] as List).cast<List<dynamic>>();
    expect(rows, hasLength(4000));
    final planner = DemonPlanner(1);
    var agree = 0, total = 0, avoidable = 0, agreeAvoidable = 0;
    final confusion = List.generate(3, (_) => List.filled(3, 0));
    for (final r in rows) {
      final v = [for (final x in r) (x as num).toDouble()];
      final label = v[10].toInt();
      if (label == 3) continue; // dive_commit: no thread candidate in T1
      final choice = planner.choose(at(v[0], v[1], crowd: v[7]), parityConfig, [
        up(v[2], v[3], vx: v[4]),
      ]);
      total++;
      confusion[label][choice.index]++;
      if (choice.index == label) agree++;
      // A state some action escapes, in the teacher's own metric.
      if ([0, 1, 2].any((a) => teacherClearance(v, a) >= 24)) {
        avoidable++;
        if (choice.index == label) agreeAvoidable++;
      }
    }
    final rate = agree / total, escapable = agreeAvoidable / avoidable;
    // ignore: avoid_print
    print(
      'parity ${(rate * 100).toStringAsFixed(1)} % of $total '
      '(escapable states ${(escapable * 100).toStringAsFixed(2)} % of '
      '$avoidable); confusion (teacher rows, planner columns) $confusion',
    );
    // In states no action escapes, the teacher minimises penetration and
    // the planner maximises the time to contact (design.md §3, parity).
    expect(escapable, greaterThanOrEqualTo(.95));
    expect(rate, greaterThanOrEqualTo(.9));
  });
}

/// The hunter config at skill 0.5 without sampling.
final hunter = PlannerConfig(
  candidates: PlannerConfig.hunterEvade,
  delay: 0,
  foresight: .55,
  temperature: 0,
);

void unitTests() {
  test('a shot dead ahead is dodged away from the wall side', () {
    final p = DemonPlanner(3);
    for (final cfg in [PlannerConfig.skirmisher, hunter]) {
      final left = p.choose(at(40, 120), cfg, [up(40, 210)]);
      expect([Manoeuvre.sideR, Manoeuvre.wideR], contains(left));
      final right = p.choose(at(322, 120), cfg, [up(322, 210)]);
      expect([Manoeuvre.sideL, Manoeuvre.wideL], contains(right));
    }
    // Mid-arena with crowding on the right: it goes left.
    final crowded = p.choose(at(180, 120, crowd: 1), hunter, [up(182, 210)]);
    expect([Manoeuvre.sideL, Manoeuvre.wideL], contains(crowded));
  });

  test('two shots bracketing the creature: hold', () {
    final p = DemonPlanner(4);
    expect(
      p.choose(at(180, 120), hunter, [up(156, 200), up(204, 200)]),
      Manoeuvre.hold,
    );
    expect(
      p.choose(at(180, 120), PlannerConfig.skirmisher, [
        up(156, 200),
        up(204, 200),
      ]),
      Manoeuvre.hold,
    );
  });

  test('walls are respected and safe states hold', () {
    final p = DemonPlanner(5);
    for (var x = 24.0; x <= 336; x += 8) {
      final c = p.choose(at(x, 140), hunter, const []);
      expect(c, Manoeuvre.hold, reason: 'x $x with no shots');
    }
    p.choose(at(30, 140), hunter, [up(36, 230)]);
    expect(
      p.energies[Manoeuvre.wideL.index],
      greaterThan(p.energies[Manoeuvre.wideR.index]),
    );
  });

  test('T → 0 is argmin; sampling uses the planner PRNG only', () {
    final shots = [up(176, 220), up(150, 300, vx: 40), up(215, 260)];
    final cold = DemonPlanner(6);
    final c = cold.choose(at(180, 130), hunter, shots);
    var low = double.infinity;
    Manoeuvre? arg;
    for (final a in hunter.candidates) {
      if (cold.energies[a.index] < low) {
        low = cold.energies[a.index];
        arg = a;
      }
    }
    expect(c, arg);
    final warm = PlannerConfig(
      candidates: PlannerConfig.hunterEvade,
      delay: 0,
      foresight: .55,
      temperature: 1e-7,
    );
    expect(DemonPlanner(99).choose(at(180, 130), warm, shots), arg);
  });

  test('the same seed makes the same choices', () {
    final hot = PlannerConfig.hunter(0);
    List<Manoeuvre> run(int seed) {
      final p = DemonPlanner(seed);
      return [
        for (var i = 0; i < 200; i++)
          p.choose(at(60 + i % 240, 140), hot, [
            up(60 + i % 240 + (i % 5 - 2) * 9, 230, age: .5),
          ]),
      ];
    }

    expect(run(1982), run(1982));
    expect(run(1982), isNot(run(7)));
  });

  test('6 decisions x 24 shots run in < 0.3 ms (VM median)', () {
    final rng = math.Random(11);
    final shots = [
      for (var i = 0; i < 24; i++)
        up(20 + rng.nextDouble() * 320, 150 + rng.nextDouble() * 330),
    ];
    final p = DemonPlanner(2);
    final cfg = PlannerConfig.hunter(.5, dive: true);
    final states = [for (var i = 0; i < 6; i++) at(40 + i * 50.0, 120)];
    final times = <int>[];
    for (var r = 0; r < 400; r++) {
      final sw = Stopwatch()..start();
      for (final s in states) {
        p.choose(s, cfg, shots);
      }
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    final median = times[times.length ~/ 2];
    // ignore: avoid_print
    print('planner: 6 x 24 in $median µs (median)');
    expect(median, lessThan(300));
  });
}
