import 'package:demon_attack/game/carrier_gates.dart';
import 'package:demon_attack/game/carrier_script.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-v3 task 1.4: the per-tour script, its seeded variation and the
/// limits beyond tour 5.
void main() {
  test('authored tours 1–5 follow the design tables', () {
    final zooms = [.70, .68, .66, .64, .62];
    // carrier-hatches: the upper hatches (4, 4, 6, 6, 8) and the core door.
    final gates = [5, 5, 7, 7, 9];
    for (var r = 0; r < 5; r++) {
      final s = CarrierScript.authored(r);
      expect(s.launchWaves, r <= 2 ? 2 : 3);
      expect(s.camera.minZoom, closeTo(zooms[r], 1e-9));
      expect(s.camera.maxAltitude, closeTo(1.6 + .05 * r, 1e-9));
      expect(s.gates, hasLength(gates[r]));
      expect(s.approach.distances.length, s.launchWaves + 1);
      expect(s.approach.distances.last, 1.35);
      expect(s.approach.cap, 90);
      expect(s.volley.telegraph, greaterThanOrEqualTo(1));
      expect(s.gateOrder.toSet(), {for (var i = 0; i < gates[r]; i++) i});
    }
    expect(CarrierScript.authored(0).approach.d0, 4);
    expect(CarrierScript.authored(1).approach.d0, 4.5);
    expect(CarrierScript.authored(4).approach.d0, 5);
  });

  test('an unseeded run uses the authored script', () {
    final a = CarrierScript.forRun(null, 2), b = CarrierScript.authored(2);
    expect(a.seeded, isFalse);
    expect(a.gateOrder, b.gateOrder);
    expect(a.cues.streakDensity, b.cues.streakDensity);
  });

  test('the same seed gives the same script; gameplay numbers stay authored',
      () {
    for (final seed in [1, 7, 1982, 424242]) {
      for (var r = 0; r < 5; r++) {
        final a = CarrierScript.forRun(seed, r), b = CarrierScript.forRun(seed, r);
        expect(a.gateOrder, b.gateOrder);
        expect(a.cues.firstSurge, b.cues.firstSurge);
        expect(a.cues.intensity, b.cues.intensity);
        final base = CarrierScript.authored(r);
        expect(a.launchWaves, base.launchWaves);
        expect(a.approach.distances, base.approach.distances);
        expect(a.gates.map((g) => g.id), base.gates.map((g) => g.id));
        expect(a.camera.minZoom, base.camera.minZoom);
        expect(a.cues.intensity, inInclusiveRange(.9, 1.1));
        expect(a.cues.firstSurge, inInclusiveRange(12, 20));
      }
    }
    final orders = {
      for (var s = 1; s < 40; s++) CarrierScript.forRun(s, 4).gateOrder.join(','),
    };
    expect(orders.length, greaterThan(5), reason: 'seeded variety');
  });

  test('beyond tour 5: seeded within tour 5 limits', () {
    final t5 = CarrierScript.authored(4);
    for (var seed = 1; seed < 60; seed++) {
      for (final r in [5, 6, 9]) {
        final s = CarrierScript.forRun(seed, r);
        expect(s.camera.minZoom, greaterThanOrEqualTo(.62 - 1e-9));
        expect(s.bend.leanMax, lessThanOrEqualTo(t5.bend.leanMax));
        expect(s.bend.bankMax, lessThanOrEqualTo(t5.bend.bankMax));
        expect(s.bend.pitchMax, lessThanOrEqualTo(t5.bend.pitchMax));
        expect(s.gates, hasLength(9)); // carrier-hatches: tour 5's hatches
        expect(s.launchWaves, 3);
      }
    }
  });

  test('field regions: from the outer arms inward, the prow last', () {
    const f = CarrierFieldStyle();
    expect(f.regionOrder.toSet(), CarrierRegion.values.toSet());
    expect(f.regionOrder.last, CarrierRegion.prow);
    // Half the shield (6 cells) left: the arms and wings are dark.
    final lit = f.litRegions(6);
    expect(lit, contains(CarrierRegion.prow));
    expect(lit, isNot(contains(CarrierRegion.wingTipL)));
    expect(lit, isNot(contains(CarrierRegion.prongOuterR)));
    expect(f.litRegions(12), CarrierRegion.values.toSet());
    expect(f.litRegions(0), isEmpty);
    expect(f.regionOfCell(0), CarrierRegion.prow);
  });

  test('gates: authored order crosses sides so the deck bays never pair', () {
    final g = CarrierGates.forTour(0);
    final order = CarrierGates.alternating(g).map((i) => g[i].id).toList();
    expect(order, ['bayL', 'prongR', 'bayR', 'prongL']);
  });
}
