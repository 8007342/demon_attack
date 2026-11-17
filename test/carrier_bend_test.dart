import 'dart:math' as math;
import 'dart:ui';

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_painter.dart';
import 'package:demon_attack/game/carrier_compose.dart';
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
          final (dx, dy) = CarrierBend.displacement(
            a.$1,
            a.$2,
            h,
            psi,
            phi,
            theta,
          );
          expect(
            math.sqrt(dx * dx + dy * dy),
            lessThanOrEqualTo(3),
            reason: 'anchor $a at ($psi, $phi, $theta)',
          );
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

  test(
    'the composed warp mesh: vertex and triangle counts (mobile budget)',
    () {
      for (final key in [
        'carrier1-thorn',
        'carrier1-lattice',
        'carrier5-thorn',
      ]) {
        final hull = BossHeroAtlas.hulls[key]!;
        final layers = compositeLayersOf(hull);
        final f = hull.frame;
        final frame = Rect.fromLTRB(f.$1, f.$2, f.$3, f.$4);
        final heights = CarrierHeightGrid.fromLayers(frame, layers);
        var vertices = 0, triangles = 0, us = 0.0, layerArea = 0.0;
        var cellArea = 0.0;
        for (final front in [false, true]) {
          final pass = [
            for (final (i, l) in layers.indexed)
              if (frontOf(hull, i) == front) l,
          ];
          var rect = pass.first.placed;
          for (final l in pass.skip(1)) {
            rect = rect.expandToInclude(l.placed);
          }
          final mesh = CarrierWarpMesh(
            rect,
            2,
            heights: heights,
            keep: (cell) => pass.any((l) => l.placed.overlaps(cell)),
          );
          final b = CarrierBend()..update(1, vx: 1, ax: 1, glide: 1, buffet: 1);
          final sw = Stopwatch()..start();
          for (var i = 0; i < 100; i++) {
            mesh.rebuild(null);
            mesh.rebuild(b);
          }
          sw.stop();
          us += sw.elapsedMicroseconds / 200;
          // Overdraw: the per-layer rects drawn before against the one
          // composed surface's cells now.
          for (final l in pass) {
            layerArea += l.placed.width * l.placed.height;
          }
          cellArea += mesh.triangleCount / 2 * 400;
          vertices += mesh.vertexCount;
          triangles += mesh.triangleCount;
        }
        // ignore: avoid_print
        print(
          'CARRIER_MESH $key vertices=$vertices triangles=$triangles '
          'calls=2 rebuild_us=${us.toStringAsFixed(1)} '
          'layer_overdraw=${(layerArea / cellArea).toStringAsFixed(2)}',
        );
        expect(vertices, lessThan(4000));
        expect(triangles, lessThan(7000));
      }
    },
  );
}

/// The S0 composite layers of [hull] in draw order (both passes).
List<CarrierCompositeLayer> compositeLayersOf(BossHeroHull hull) {
  final v = hull.views['p45_y+00']!;
  return [
    for (final m in hull.modules)
      if (_s0(v, m.id) case (final s, final flip))
        CarrierCompositeLayer(
          page: s.page,
          src: Rect.fromLTWH(
            s.x.toDouble(),
            s.y.toDouble(),
            s.w.toDouble(),
            s.h.toDouble(),
          ),
          dst: Rect.fromLTWH(s.dx, s.dy, s.w / s.ppu, s.h / s.ppu),
          flip: flip,
          height: CarrierBend.heightOf(m.module),
        ),
  ];
}

/// Whether the [i]th S0 layer of [hull] is in the front (prow) pass.
bool frontOf(BossHeroHull hull, int i) {
  final v = hull.views['p45_y+00']!;
  final drawn = [
    for (final m in hull.modules)
      if (_s0(v, m.id) != null) m,
  ];
  return BossPainter.isFront(drawn[i]);
}

(BossHeroSprite, bool)? _s0(BossHeroView v, String id) {
  var list = v.layers[id];
  var flip = false;
  if (list == null && id.endsWith('L')) {
    list = v.layers['${id.substring(0, id.length - 1)}R'];
    flip = true;
  }
  final s = list?.first;
  return s == null ? null : (s, flip);
}
