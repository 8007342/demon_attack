// cinematic-flow task 1.2: the director's plans obey the continuity rules.
import 'package:demon_attack/game/flow_director.dart';
import 'package:flutter_test/flutter_test.dart';

List<FlowPlan> _plans({required bool reduced}) => [
  for (final extra in const [0.0, .7, 2.0, 5.0]) ...[
    FlowPlan.sectorChange(reduced: reduced, extra: extra),
    FlowPlan.sectorChange(reduced: reduced, extra: extra, boss: true),
    FlowPlan.sectorChange(reduced: reduced, extra: extra, victory: true),
  ],
  FlowPlan.campaignOutro(reduced: reduced),
  FlowPlan.gameOverOutro(reduced: reduced),
  FlowPlan.attract(reduced: reduced),
];

void main() {
  test('bump eases in and out and is a step when a == b', () {
    expect(bump(0, 1, 2, 3, -1), 0);
    expect(bump(0, 1, 2, 3, 1.5), 1);
    expect(bump(0, 1, 2, 3, 3), 0);
    expect(bump(1, 1, 5, 6, .99), 0);
    expect(bump(1, 1, 5, 6, 1), 1);
  });

  test('every envelope stays in [0, 1] and is continuous', () {
    for (final reduced in [false, true]) {
      for (final plan in _plans(reduced: reduced)) {
        for (final beat in plan.beats) {
          var last = beat.at(0);
          const step = 1 / 240;
          for (var s = step; s <= plan.seconds; s += step) {
            final v = beat.at(s);
            expect(
              v,
              inInclusiveRange(0, 1),
              reason: '${plan.kind} ${beat.id}',
            );
            // A beat that is not an instant (the hit) never jumps.
            if (beat.b > beat.a) {
              expect(
                (v - last).abs(),
                lessThan(.05),
                reason: '${plan.kind} ${beat.id} at $s',
              );
            }
            last = v;
          }
        }
      }
    }
  });

  test('every swap lies inside cloud >= 0.85', () {
    for (final reduced in [false, true]) {
      for (final plan in _plans(reduced: reduced)) {
        final swap = plan.beat('swap');
        if (swap == null) continue;
        for (var s = swap.a; s <= plan.seconds; s += 1 / 120) {
          final changing = swap.at(s) > 0 && swap.at(s) < 1;
          if (!changing) continue;
          expect(
            plan.envAt('cloud', s),
            greaterThanOrEqualTo(.85),
            reason: '${plan.kind} reduced=$reduced at $s',
          );
        }
        // The level change (the Descent's start) is under the cloud too.
        expect(plan.envAt('cloud', plan.descentAt), greaterThanOrEqualTo(.85));
      }
    }
  });

  test('the radio slot never starts by the swap; no title beat', () {
    for (final reduced in [false, true]) {
      for (final plan in _plans(reduced: reduced)) {
        // playtest-fixes: transitions speak only by radio, no title text.
        expect(plan.beat('title'), isNull, reason: '${plan.kind}');
        final slot = plan.beat('slot');
        if (slot == null) continue;
        expect(
          (slot.a - plan.swapAt!).abs(),
          greaterThanOrEqualTo(FlowPlan.seamGuard),
          reason: '${plan.kind} reduced=$reduced',
        );
        expect(slot.d, lessThanOrEqualTo(plan.descentAt));
      }
    }
  });

  test('reduced plans keep the full plans\' beat ids, without motion', () {
    final full = _plans(reduced: false), reduced = _plans(reduced: true);
    for (var i = 0; i < full.length; i++) {
      expect(reduced[i].ids, full[i].ids, reason: '${full[i].kind}');
      for (final id in const ['climb', 'tilt', 'spin', 'drift']) {
        final b = reduced[i].beat(id);
        if (b != null) expect(b.gain, 0, reason: '${full[i].kind} $id');
      }
    }
    // Reduced Pursuit is at most 3.5 s (without a slot's extension).
    expect(FlowPlan.sectorChange(reduced: true).pursuitSeconds, 3.5);
    expect(FlowPlan.sectorChange().pursuitSeconds, 6.0);
  });

  test('Pursuit is a whole number of beats', () {
    for (final reduced in [false, true]) {
      for (final extra in [0.0, .1, .5, .74, 1.3, 2.0, 9.0]) {
        for (final victory in [false, true]) {
          final p = FlowPlan.sectorChange(
            reduced: reduced,
            extra: extra,
            victory: victory,
          ).pursuitSeconds;
          expect((p / flowBeat) % 1, 0, reason: 'extra $extra → $p');
          expect(
            p,
            lessThanOrEqualTo(
              (victory ? 0 : FlowPlan.clearFor(reduced)) +
                  FlowPlan.travelFor(reduced) +
                  FlowPlan.maxExtra,
            ),
          );
        }
      }
    }
  });

  test('a sector change is shorter than the old card chain', () {
    // Old: salvage 2 + 4⅓ + 4⅓ + arrival 4.5 = 15.17 s.
    expect(FlowPlan.sectorChange().seconds, closeTo(12.5, 1e-9));
    expect(FlowPlan.sectorChange(reduced: true).seconds, closeTo(8.5, 1e-9));
  });

  test('skip jumps to the Descent; attract loops', () {
    final d = FlowDirector()..start(FlowPlan.sectorChange());
    d.at(3);
    expect(d.env('climb'), greaterThan(0));
    d.skipToDescent();
    expect(d.seconds, d.plan.descentAt);
    expect(d.env('cloud'), greaterThanOrEqualTo(.85));
    final a = FlowDirector()..start(FlowPlan.attract());
    a.advance(FlowPlan.attractSeconds + 1);
    expect(a.seconds, closeTo(1, 1e-9));
  });
}
