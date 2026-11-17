import 'package:demon_attack/game/carrier_gates.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-v3 task 2.1: the gate state machine and its volleys.
void main() {
  CarrierLaunches launches({int seed = 1, int route = 0}) {
    final g = CarrierGates.forTour(route);
    return CarrierLaunches(
      gates: g,
      order: CarrierGates.alternating(g),
      seed: seed,
    );
  }

  test('a volley: telegraph 1.2 s, open 0.5 s, one per 0.12 s, close 0.8 s',
      () {
    final l = launches();
    final run = l.pick((g) => 180 + g.x)!;
    final delays = l.volley(run, 4);
    expect(delays.first, closeTo(1.7, 1e-9));
    expect(delays[3] - delays[0], closeTo(.36, 1e-9));
    final log = <(GateState, double)>[];
    var t = 0.0;
    var launchedAt = <double>[];
    var last = 0;
    while (t < 5) {
      l.step(1 / 120);
      t += 1 / 120;
      for (final e in l.takeEvents()) {
        log.add((e.kind, t));
      }
      if (run.launched > last) {
        launchedAt.add(t);
        last = run.launched;
      }
    }
    expect(log.map((e) => e.$1), [
      GateState.telegraph,
      GateState.opening,
      GateState.launching,
      GateState.closed,
    ]);
    expect(log[1].$2, closeTo(1.2, .01));
    expect(launchedAt.first, greaterThanOrEqualTo(1.0 + .5));
    expect(launchedAt.first, closeTo(1.7, .02));
    expect(launchedAt.last - launchedAt.first, closeTo(.36, .02));
    expect(log[3].$2, closeTo(1.7 + .36 + .8, .03));
  });

  test('determinism: same seed, same gates and times', () {
    List<String> run(int seed) {
      final l = launches(seed: seed, route: 4);
      final out = <String>[];
      for (var k = 0; k < 30; k++) {
        final r = l.pick((g) => 180 + g.x / 3);
        if (r != null) out.add('${r.gate.id}:${l.volley(r, 3).first.toStringAsFixed(3)}');
        for (var i = 0; i < 40; i++) {
          l.step(1 / 60);
        }
      }
      return out;
    }

    expect(run(5), run(5));
    expect(run(5), isNot(run(6)));
  });

  test('off-arena gates never launch; at most two open', () {
    final l = launches(route: 4);
    for (var k = 0; k < 40; k++) {
      final r = l.pick((g) => 180 + g.x); // ±176 and ±262 fall outside
      if (r != null) {
        final x = 180 + r.gate.x;
        expect(x, inInclusiveRange(16, 344));
        l.volley(r, 2);
      }
      expect(l.openCount, lessThanOrEqualTo(2));
      for (var i = 0; i < 20; i++) {
        l.step(1 / 60);
      }
    }
  });

  test('a held gate waits open until released', () {
    final l = launches();
    final r = l.pick((g) => 180 + g.x)!;
    l.volley(r, 0, hold: true);
    for (var i = 0; i < 60 * 4; i++) {
      l.step(1 / 60);
    }
    expect(r.state, GateState.opening);
    r.queued = 3;
    l.release(r);
    for (var i = 0; i < 60 * 3; i++) {
      l.step(1 / 60);
    }
    expect(r.state, GateState.closed);
  });
}
