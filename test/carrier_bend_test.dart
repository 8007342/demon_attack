import 'dart:math' as math;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/carrier_bend.dart';
import 'package:demon_attack/game/carrier_script.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-v3 task 3.1: the analytic bend keeps the deck rigid (core, bays
/// and turret pivots within ±3 units at every combination of maxima), its
/// largest displacement stays near 30 units, and the mesh stays cheap.
void main() {
  const deg = math.pi / 180;
  const l = CarrierBendLimits();
  final combos = [
    for (final a in [-1, 0, 1])
      for (final b in [-1, 0, 1])
        for (final c in [-1, 0, 1])
          (a * l.leanMax * deg, b * l.bankMax * deg, c * l.takeoffPitch * deg),
  ];

  test('anchor invariance: the hit windows stay within ±3 units', () {
    final anchors =
        BossHeroAtlas.hulls['carrier1-thorn']!.views['p45_y+00']!.anchors;
    expect(anchors.keys, containsAll(['core', 'bayL', 'bayR', 'turretL']));
    for (final (psi, phi, theta) in combos) {
      for (final h in [0.0, 60.0]) {
        for (final a in anchors.values) {
          final (dx, dy) =
              CarrierBend.displacement(a.$1, a.$2, h, psi, phi, theta);
          expect(math.sqrt(dx * dx + dy * dy), lessThanOrEqualTo(3),
              reason: 'anchor $a at ($psi, $phi, $theta)');
        }
      }
    }
  });

  test('the far hull swings, about 30 units at the top edge, no more', () {
    var top = 0.0;
    for (final (psi, phi, theta) in combos) {
      for (final x in [-360.0, 0.0, 360.0]) {
        final (dx, dy) = CarrierBend.displacement(x, -430, 60, psi, phi, theta);
        top = math.max(top, math.sqrt(dx * dx + dy * dy));
      }
    }
    expect(top, greaterThan(20));
    expect(top, lessThan(60));
  });

  test('springs: critically damped, no overshoot, within the limits', () {
    final b = CarrierBend();
    var peak = 0.0;
    for (var i = 0; i < 60 * 8; i++) {
      b.update(1 / 60, vx: 1, ax: 0);
      peak = math.max(peak, b.lean);
    }
    expect(b.lean, closeTo(l.leanMax * deg, .02 * deg));
    expect(peak, lessThanOrEqualTo(l.leanMax * deg + 1e-9));
    // Reversal passes through upright gradually.
    var steps = 0;
    for (var i = 0; i < 60 * 8 && b.lean > 0; i++) {
      b.update(1 / 60, vx: -1, ax: 0);
      steps++;
    }
    expect(steps, greaterThan(30), reason: 'no snap through upright');
    b.update(1 / 60, vx: 1, ax: 1, reduced: true);
    expect(b.lean, 0);
  });

  test('the tour-1 mesh: vertex and triangle counts (mobile budget)', () {
    for (final key in ['carrier1-thorn', 'carrier1-lattice', 'carrier5-thorn']) {
      final hull = BossHeroAtlas.hulls[key]!;
      final v = hull.views['p45_y+00']!;
      final layers = <CarrierMeshLayer>[];
      for (final m in hull.modules) {
        var list = v.layers[m.id];
        var flip = false;
        if (list == null && m.id.endsWith('L')) {
          list = v.layers['${m.id.substring(0, m.id.length - 1)}R'];
          flip = true;
        }
        final s = list?.first;
        if (s == null) continue;
        final k = s.ppu;
        layers.add(CarrierMeshLayer(
          page: s.page,
          left: s.dx,
          top: s.dy,
          right: s.dx + s.w / k,
          bottom: s.dy + s.h / k,
          u0: s.x.toDouble(),
          v0: s.y.toDouble(),
          u1: (s.x + s.w).toDouble(),
          v1: (s.y + s.h).toDouble(),
          flip: flip,
          height: CarrierBend.heightOf(m.module),
          lag: CarrierBend.lags(m.module),
        ));
      }
      final mesh = CarrierMesh(layers);
      final b = CarrierBend()..update(1, vx: 1, ax: 1, glide: 1, buffet: 1);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        mesh.rebuild(null);
        mesh.rebuild(b);
      }
      sw.stop();
      // ignore: avoid_print
      print('CARRIER_MESH $key vertices=${mesh.vertexCount} '
          'triangles=${mesh.triangleCount} pages=${mesh.pages.length} '
          'rebuild_us=${(sw.elapsedMicroseconds / 200).toStringAsFixed(1)}');
      expect(mesh.vertexCount, lessThan(6000));
      expect(mesh.triangleCount, lessThan(10000));
    }
  });
}
