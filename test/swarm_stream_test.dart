// The continuous swarm's scheduler (lib/game/swarm_stream.dart,
// openspec/changes/continuous-swarm design §2).
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/swarm_stream.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _grid(int n) => [for (var i = 0; i < n; i++) 38 + (i % 6) * 56.0];

void main() {
  test('the roster split keeps every member once, in roster order', () {
    for (var n = 1; n <= 28; n++) {
      final split = SwarmStream.splitRoster(_grid(n));
      expect(split.length, SwarmStream.skeinCount(n));
      final all = [for (final s in split) ...s]..sort();
      expect(all, List<int>.generate(n, (i) => i), reason: 'n=$n');
      for (final s in split) {
        expect(s, List.of(s)..sort(), reason: 'order inside a skein');
        if (n >= 3) {
          expect(s.length, inInclusiveRange(3, 6), reason: 'n=$n');
        }
      }
    }
  });

  test('skeins are column bands: no column straddles two skeins badly', () {
    final hx = _grid(24);
    final split = SwarmStream.splitRoster(hx);
    for (var a = 0; a + 1 < split.length; a++) {
      final maxA = split[a].map((i) => hx[i]).reduce(math.max);
      final minB = split[a + 1].map((i) => hx[i]).reduce(math.min);
      expect(maxA, lessThanOrEqualTo(minB));
    }
  });

  test('groups of 4-7 fly as one or two skeins', () {
    for (var n = 4; n <= 7; n++) {
      final split = SwarmStream.splitGroup(n);
      expect(split.length, n <= 6 ? 1 : 2);
      expect([for (final s in split) ...s], List<int>.generate(n, (i) => i));
    }
  });

  test('gaps shrink while few are alive, never below half the base', () {
    for (final d in Difficulty.values) {
      final g = DifficultyPolicy(d).skeinGap;
      expect(SwarmStream.skeinGap(g, live: 20, roster: 20), g);
      final low = SwarmStream.skeinGap(g, live: 2, roster: 20);
      expect(low, lessThan(g));
      expect(low, closeTo(.5 * g, 1e-9));
      for (var live = 0; live <= 30; live++) {
        expect(
          SwarmStream.skeinGap(g, live: live, roster: 20),
          inInclusiveRange(.5 * g, g),
        );
      }
    }
  });

  test('q is clamped to [paceFloor, 1]', () {
    for (final d in Difficulty.values) {
      final floor = DifficultyPolicy(d).paceFloor;
      expect(SwarmStream.pace(1, 100, floor), floor);
      expect(SwarmStream.pace(500, 100, floor), 1);
      expect(
        SwarmStream.pace(70, 100, floor),
        closeTo(math.max(.7, floor), 1e-9),
      );
    }
    // The spec's example: a Normal clear in half the expected time.
    expect(
      SwarmStream.pace(10, 20, DifficultyPolicy(Difficulty.normal).paceFloor),
      .55,
    );
  });

  test('a lost life resets q to 1 for the next cohort', () {
    final s = SwarmStream()..startCohort();
    s.cohortClock = 1;
    expect(s.paceNext(cohortHp: 60, floor: .55), .55);
    s
      ..startCohort()
      ..cohortClock = 1
      ..lifeLost();
    expect(s.paceNext(cohortHp: 60, floor: .55), 1);
    s.startCohort();
    expect(s.relaxed, isFalse);
  });

  test('the lull is max(0.8, 1.4 q)', () {
    expect(SwarmStream.lull(1), 1.4);
    expect(SwarmStream.lull(.5), .8);
  });

  test('same seed, same plan; another seed differs', () {
    List<SwarmGate> plan(int seed) => SwarmStream.gates(
      12,
      SwarmStream(seed: seed).rngFor(sector: 2, route: 1, wave: 3, salt: 4),
    );
    expect(plan(5), plan(5));
    expect(plan(5), isNot(plan(6)));
    // Consecutive skeins alternate sides (centre aside).
    final g = plan(5).where((x) => x.side != 0).toList();
    var alternations = 0;
    for (var i = 1; i < g.length; i++) {
      if (g[i].side != g[i - 1].side) alternations++;
    }
    expect(alternations, greaterThanOrEqualTo(g.length ~/ 2));
  });

  test('Lévy drift stays leashed and is seeded', () {
    final a = LevyDrift(math.Random(3)), b = LevyDrift(math.Random(3));
    for (var i = 0; i < 600; i++) {
      a.update(1 / 60);
      b.update(1 / 60);
      expect(a.x.abs(), lessThanOrEqualTo(90));
      expect(a.z.abs(), lessThanOrEqualTo(60));
    }
    expect((a.x, a.z), (b.x, b.z));
  });

  test('the stream never draws from the model random', () {
    final m = ArcadeModel(seed: 11);
    final probe = ArcadeModel(seed: 11);
    final s = SwarmStream(seed: 11);
    final rng = s.rngFor(sector: 1, route: 0, wave: 2);
    SwarmStream.gates(8, rng);
    s.preload(_grid(14), rng);
    expect(m.random.nextDouble(), probe.random.nextDouble());
  });

  test('W5b hooks return plans', () {
    final s = SwarmStream();
    expect(s.drain(pendingSkeins: 2).pendingSkeins, 2);
    expect(s.drained, isTrue);
    expect(s.rout(-3).direction, -1);
    expect(
      s.preload(_grid(10), math.Random(1)).skeins.length,
      SwarmStream.skeinCount(10),
    );
  });
}
