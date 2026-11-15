// Fighting patterns (lib/game/swarm_patterns.dart, openspec/changes/
// continuous-swarm design §4, task 5.3).
import 'dart:math' as math;

import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

Squad _squad(
  SquadState state, {
  int id = 1,
  int members = 5,
  double x = 180,
  double y = 120,
  int seed = 3,
}) {
  final s = Squad(
    id,
    math.Random(seed),
    stationX: x,
    stationY: y,
    state: state,
  );
  for (var i = 0; i < members; i++) {
    s.add(i, i);
  }
  return s;
}

/// Peak and mean lateral speed (u/s) of the members' targets in [state].
(double, double) _lateral(SquadState state, {int seed = 3}) {
  final s = _squad(state, seed: seed)..dwellLeft = 1e9;
  const dt = 1 / 60;
  final prev = <int, double>{};
  var peak = 0.0, sum = 0.0, n = 0;
  for (var f = 0; f < 60 * 30; f++) {
    s.update(dt, tempo: 1, flying: const [0, 1, 2, 3, 4]);
    for (var i = 0; i < 5; i++) {
      final x = s.target(i)!.$1;
      final p = prev[i];
      if (p != null && f > 60) {
        final v = ((x - p) / dt).abs();
        peak = math.max(peak, v);
        sum += v;
        n++;
      }
      prev[i] = x;
    }
  }
  return (peak, sum / n);
}

void main() {
  test('targets stay inside the arena margins and above shipY - 130', () {
    for (final state in [
      SquadState.mill,
      SquadState.ribbon,
      SquadState.sweep,
    ]) {
      for (final (x, y) in [(20.0, 60.0), (340.0, 340.0), (180.0, 400.0)]) {
        final s = _squad(state, x: x, y: y)..dwellLeft = 1e9;
        for (var f = 0; f < 60 * 20; f++) {
          s.update(1 / 60, tempo: 1.2, flying: const [0, 1, 2, 3, 4]);
          for (var i = 0; i < 5; i++) {
            final (tx, ty) = s.target(i)!;
            expect(tx, inInclusiveRange(20, 340));
            expect(ty, lessThanOrEqualTo(ArcadeModel.shipY - 130));
          }
        }
      }
    }
  });

  test('each state flies at its design lateral speed', () {
    // Design §4: mill R·w 24-62, ribbon 30-60, sweep peak 40-75 (u/s),
    // checked over several seeds with a margin for the ribbon's warp and
    // the sweep's smootherstep peak.
    for (final seed in [1, 2, 3, 4, 5]) {
      final (millPeak, millMean) = _lateral(SquadState.mill, seed: seed);
      expect(millPeak, inInclusiveRange(20, 66), reason: 'mill $seed');
      expect(millMean, greaterThan(12));
      final (ribbonPeak, ribbonMean) = _lateral(SquadState.ribbon, seed: seed);
      expect(ribbonPeak, inInclusiveRange(30, 90), reason: 'ribbon $seed');
      expect(ribbonMean, greaterThan(15));
      final (sweepPeak, sweepMean) = _lateral(SquadState.sweep, seed: seed);
      expect(sweepPeak, inInclusiveRange(35, 95), reason: 'sweep $seed');
      expect(sweepMean, greaterThan(15));
    }
  });

  test('switches only between neighbouring states, after 7-12 s', () {
    final s = _squad(SquadState.mill);
    var last = s.state;
    var since = 0.0;
    var switches = 0;
    for (var f = 0; f < 60 * 300; f++) {
      s.update(1 / 60, tempo: 1, flying: const [0, 1, 2, 3, 4]);
      since += 1 / 60;
      if (s.state != last) {
        switches++;
        expect(
          {last, s.state},
          anyOf(
            {SquadState.mill, SquadState.ribbon},
            {SquadState.ribbon, SquadState.sweep},
          ),
        );
        expect(since, greaterThanOrEqualTo(7 - 1e-6));
        expect(since, lessThanOrEqualTo(12 + 1.2 + 1 / 30));
        since = 0;
        last = s.state;
      }
    }
    expect(switches, greaterThan(15));
  });

  test('the crossfade has no snap', () {
    for (final seed in [1, 2, 3]) {
      final s = _squad(SquadState.mill, seed: seed);
      final prev = <int, (double, double)>{};
      var maxStep = 0.0;
      for (var f = 0; f < 60 * 60; f++) {
        s.update(1 / 60, tempo: 1.2, flying: const [0, 1, 2, 3, 4]);
        for (var i = 0; i < 5; i++) {
          final t = s.target(i)!;
          final p = prev[i];
          if (p != null) {
            maxStep = math.max(
              maxStep,
              math.sqrt(math.pow(t.$1 - p.$1, 2) + math.pow(t.$2 - p.$2, 2)),
            );
          }
          prev[i] = t;
        }
      }
      // Under 5 units per frame: the 1.2 s smootherstep glides between
      // states (members themselves are capped at 140 · tempo u/s by the
      // model's steering), never a jump.
      expect(maxStep, lessThan(5), reason: 'seed $seed');
    }
  });

  test('the vacuole closes in 0.6 s', () {
    final s = _squad(SquadState.mill, members: 6)..dwellLeft = 1e9;
    s.update(1 / 60, tempo: 1, flying: const [0, 1, 2, 3, 4, 5]);
    // Member 2 is lost: the others re-index over five.
    const left = [0, 1, 3, 4, 5];
    for (var f = 0; f < 36; f++) {
      s.update(1 / 60, tempo: 1, flying: left);
    }
    for (var i = 0; i < left.length; i++) {
      final f = s.slots[left[i]]!.fraction;
      var d = (f - i / left.length).abs();
      d = math.min(d, 1 - d);
      expect(d, lessThan(.02), reason: 'member ${left[i]}');
    }
  });

  test('hover fallback places a stray exactly by the legacy formula', () {
    final m = ArcadeModel(seed: 5)..startAt(difficulty: Difficulty.normal);
    m.mode = RunMode.playing;
    m.demons.clear();
    m.flocksSpawned = m.flocksPlanned;
    final d = Demon(140, 118, 1, 2, 2.5);
    m.demons.add(d);
    m.update(1 / 60);
    expect(m.patterned(d), isFalse, reason: 'a stray has no squad');
    final t = m.levelClock;
    final expectX =
        (d.homeX +
                math.sin(t * (.9 + d.kind * .12) * m.speed + d.seed) * 29 +
                math.sin(t * .44 * m.policy.hostileRate) * 13 +
                (math.sin(d.seed * 3.1) * 3.5).clamp(-8.0, 8.0))
            .clamp(20.0, 340.0);
    final expectY =
        d.homeY +
        math.sin(t * 1.7 * m.speed + d.seed) * 14 +
        (math.cos(d.seed * 2.3) * 2.5).clamp(-6.0, 6.0);
    expect(d.x, closeTo(expectX, 1e-9));
    expect(d.y, closeTo(expectY, 1e-9));
  });

  test('onboarding and the flag keep the hover', () {
    final easy = ArcadeModel(seed: 5)..startAt(difficulty: Difficulty.easy);
    expect(easy.demons.where((d) => !d.isLarge).any(easy.patterned), isFalse);
    final normal = ArcadeModel(seed: 5)..startAt(difficulty: Difficulty.normal);
    expect(
      normal.demons.where((d) => !d.isLarge).any(normal.patterned),
      isTrue,
    );
    normal.swarmPatterns = false;
    expect(normal.demons.any(normal.patterned), isFalse);
  });

  test('61 members step in under 0.2 ms (median of 200)', () {
    final squads = [
      for (var s = 0; s < 11; s++)
        _squad(
          SquadState.values[s % 3],
          id: s,
          members: s == 10 ? 1 : 6,
          seed: s,
        ),
    ];
    final times = <int>[];
    final sw = Stopwatch();
    for (var r = 0; r < 260; r++) {
      sw
        ..reset()
        ..start();
      for (final s in squads) {
        final members = s.slots.keys.toList();
        s.update(1 / 60, tempo: 1, flying: members);
        for (final m in members) {
          s.target(m);
          s.altitude(m, 100);
        }
      }
      sw.stop();
      if (r >= 60) times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    expect(times[times.length ~/ 2], lessThan(200));
  });
}
