import 'dart:math' as math;
import 'dart:ui';

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_director.dart';
import 'package:demon_attack/game/carrier_bend.dart';
import 'package:demon_attack/game/carrier_compose.dart';
import 'package:demon_attack/game/carrier_field.dart';
import 'package:demon_attack/game/carrier_wreck.dart';
import 'package:demon_attack/game/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'carrier_bend_test.dart' show compositeLayersOf;

/// carrier-render-engine: the compose-then-warp mesh is one continuous
/// surface, the collapse is one hierarchy with shared momentum, and the
/// field thins in place (design §5, tests).
void main() {
  const deg = math.pi / 180;
  final hull = BossHeroAtlas.hulls['carrier1-thorn']!;
  final f = hull.frame;
  final frame = Rect.fromLTRB(f.$1, f.$2, f.$3, f.$4);
  final layers = compositeLayersOf(hull);
  final heights = CarrierHeightGrid.fromLayers(frame, layers);
  CarrierWarpMesh meshOf() => CarrierWarpMesh(
    frame,
    2,
    heights: heights,
    keep: (cell) => layers.any((l) => l.placed.overlaps(cell)),
  );

  group('compose, then warp', () {
    test('one surface: every interior edge is shared by two triangles', () {
      final m = meshOf();
      final edges = <(int, int), int>{};
      for (var t = 0; t < m.indices.length; t += 3) {
        for (var k = 0; k < 3; k++) {
          final a = m.indices[t + k], b = m.indices[t + (k + 1) % 3];
          final e = a < b ? (a, b) : (b, a);
          edges[e] = (edges[e] ?? 0) + 1;
        }
      }
      // No edge is used by more than two triangles, and the vertices are
      // shared: far fewer vertices than 3 per triangle.
      expect(edges.values.every((n) => n <= 2), isTrue);
      expect(m.vertexCount, lessThan(m.triangleCount));
    });

    test('rigid: neighbouring nodes move alike (no tear, no layer drift)', () {
      final m = meshOf();
      final b = CarrierBend()..pose = (3 * deg, 2.5 * deg, 3 * deg);
      b.update(1 / 60, vx: 0, ax: 0);
      m.rebuild(b);
      var worst = 0.0;
      for (var t = 0; t < m.indices.length; t += 3) {
        for (var k = 0; k < 3; k++) {
          final a = m.indices[t + k], c = m.indices[t + (k + 1) % 3];
          final dax = m.positions[2 * a] - m.rest[2 * a];
          final day = m.positions[2 * a + 1] - m.rest[2 * a + 1];
          final dcx = m.positions[2 * c] - m.rest[2 * c];
          final dcy = m.positions[2 * c + 1] - m.rest[2 * c + 1];
          worst = math.max(
            worst,
            math.sqrt((dax - dcx) * (dax - dcx) + (day - dcy) * (day - dcy)),
          );
        }
      }
      // Across one 20-unit cell (≤ 28 on the diagonal) the displacement
      // changes by a few units at the limits (the analytic turn's own
      // gradient at the far hull): a smooth field, no step anywhere.
      expect(worst, lessThan(6));
    });

    test('the deck stays put; rig points ride the same field', () {
      final m = meshOf();
      final b = CarrierBend()..pose = (3 * deg, -2.5 * deg, 2 * deg);
      b.update(1 / 60, vx: 0, ax: 0);
      m.rebuild(b);
      for (var i = 0; i < m.vertexCount; i++) {
        final x = m.rest[2 * i], y = m.rest[2 * i + 1];
        final (dx, dy) = CarrierBend.displacement(
          x,
          y,
          heights.at(x, y),
          b.psi,
          b.phi,
          b.theta,
        );
        expect(m.positions[2 * i], closeTo(x + dx, 1e-3));
        expect(m.positions[2 * i + 1], closeTo(y + dy, 1e-3));
        if ((x - 0).abs() + (y - 25).abs() < 30) {
          expect(math.sqrt(dx * dx + dy * dy), lessThan(1));
        }
      }
    });

    test('the height field has no steps for the parallax to tear along', () {
      var jump = 0.0;
      for (var j = 0; j + 1 < heights.ny; j++) {
        for (var i = 0; i + 1 < heights.nx; i++) {
          final h0 = heights.h[j * heights.nx + i];
          jump = math.max(jump, (h0 - heights.h[j * heights.nx + i + 1]).abs());
          jump = math.max(
            jump,
            (h0 - heights.h[(j + 1) * heights.nx + i]).abs(),
          );
        }
      }
      expect(jump, lessThan(30), reason: 'a dorsal 60 → 0 step is blurred');
    });
  });

  group('the cohesive collapse', () {
    CarrierFracture fracture() {
      final seeds = <FractureSeed>[
        for (final l in layers)
          (
            l.placed.center.dx,
            l.placed.center.dy,
            CarrierFracture.sectionOf(l.placed.center.dx, l.placed.center.dy),
          ),
      ];
      return CarrierFracture.build(
        left: frame.left,
        top: frame.top,
        right: frame.right,
        bottom: frame.bottom,
        seeds: seeds,
        keep: (l, t, r, b) =>
            layers.any((x) => x.placed.overlaps(Rect.fromLTRB(l, t, r, b))),
      );
    }

    CarrierCollapse collapse({bool reduced = false}) {
      final k = CarrierCollapse(
        x: 180,
        y: 205,
        vx: 30,
        direction: 1,
        seed: 7,
        reduced: reduced,
      );
      k.attach(fracture());
      return k;
    }

    test('a hierarchy: hull, sections, chunks; the deck never breaks off', () {
      final k = collapse();
      final f = k.fracture!;
      expect(k.bodies.first.level, 0);
      expect(
        k.bodies.where((b) => b.level == 1).length,
        inInclusiveRange(2, 3),
      );
      expect(k.bodies.where((b) => b.level == 2), isNotEmpty);
      for (final b in k.bodies.skip(1)) {
        expect(b.release, greaterThanOrEqualTo(k.bodies[b.parent].release));
        expect(k.bodies[b.parent].level, lessThan(b.level));
      }
      for (var i = 0; i < f.chunks; i++) {
        if (f.chunkDeck[i] == 1) expect(k.bodies[f.chunkBody[i]].level, 0);
      }
      expect(f.triangles, greaterThan(500));
    });

    test('attached until release, continuous at it (shared momentum)', () {
      final k = collapse();
      for (final (i, b) in k.bodies.indexed.skip(1)) {
        final before = k.world(i, b.cx + 40, b.cy - 30, b.release - 1e-4);
        final parent = k.world(
          b.parent,
          b.cx + 40,
          b.cy - 30,
          b.release - 1e-4,
        );
        expect(before.$1, closeTo(parent.$1, 1e-6));
        expect(before.$2, closeTo(parent.$2, 1e-6));
        final after = k.world(i, b.cx + 40, b.cy - 30, b.release + 1e-4);
        expect((after.$1 - before.$1).abs(), lessThan(.05));
        expect((after.$2 - before.$2).abs(), lessThan(.05));
        // Its velocity is the parent's at its pivot plus a small kick.
        final (pv, ph) = (
          k.world(b.parent, b.cx, b.cy, b.release + .01),
          k.world(b.parent, b.cx, b.cy, b.release - .01),
        );
        final pvx = (pv.$1 - ph.$1) / .02, pvy = (pv.$2 - ph.$2) / .02;
        final (cv, ch) = (
          k.world(i, b.cx, b.cy, b.release + .02),
          k.world(i, b.cx, b.cy, b.release + .0),
        );
        final cvx = (cv.$1 - ch.$1) / .02, cvy = (cv.$2 - ch.$2) / .02;
        final kick = math.sqrt(
          (cvx - pvx) * (cvx - pvx) + (cvy - pvy) * (cvy - pvy),
        );
        expect(kick, lessThan(20), reason: 'body $i kicks gently');
      }
    });

    test('slow and massive: it stays one structure as it sinks', () {
      final k = collapse();
      final f = k.fracture!;
      final t = k.script.duration - k.script.fade;
      var spread = 0.0;
      for (var i = 0; i < f.chunks; i++) {
        final b = f.chunkBody[i];
        final (x, y) = k.world(b, f.chunkX[i], f.chunkY[i], t);
        final (rx, ry) = k.world(0, f.chunkX[i], f.chunkY[i], t);
        spread = math.max(
          spread,
          math.sqrt((x - rx) * (x - rx) + (y - ry) * (y - ry)),
        );
      }
      // Every chunk is within ~120 units of where the intact hull would
      // carry it: the breakup reads as one wreck, not scattered parts.
      expect(spread, lessThan(120));
      expect(spread, greaterThan(15));
      // The list is slow: under 10° by the time the cloud takes it.
      expect(k.pose(0, t).a.abs(), lessThan(10 * deg));
      // The pieces recede together.
      expect(k.scaleAt(k.script.duration), closeTo(1 - k.script.sink, 1e-9));
    });

    test('runs headless and ends; reduced motion does not spin', () {
      final h = CarrierCollapse(x: 180, y: 205, vx: 0, direction: -1, seed: 1);
      for (var i = 0; i < 60 * 8 && !h.done; i++) {
        h.step(1 / 60);
      }
      expect(h.done, isTrue);
      final r = collapse(reduced: true);
      expect(r.pose(0, 5).a, 0);
      for (var i = 0; i < 60 * 8; i++) {
        r.step(1 / 60);
      }
      expect(r.puffs, isEmpty);
      final k = collapse();
      for (var i = 0; i < 60 * 4; i++) {
        k.step(1 / 60);
      }
      expect(k.puffs.length, inInclusiveRange(1, CarrierCollapse.maxPuffs));
      expect(k.blasts.length, lessThanOrEqualTo(CarrierCollapse.maxBlasts));
    });

    test('the director: a v2 carrier falls as one collapse', () {
      final m = ArcadeModel(seed: 4)..startAt(sector: 5, route: 0);
      m.mode = RunMode.playing;
      final d = BossDirector(seed: 4);
      final b = m.boss!;
      final modules = [for (final mod in hull.modules) (mod.id, mod.detach)];
      void step(int n) {
        for (var i = 0; i < n; i++) {
          m.invulnerable = 2;
          m.update(1 / 60);
          d.update(m, 1 / 60, carrier: true, modules: modules);
        }
      }

      step(10);
      b.shield = 0;
      for (var g = 0; g < 100000 && m.boss != null; g++) {
        b.door = 1;
        m.hitBoss(b.x, damage: 50);
        step(1);
      }
      step(2);
      expect(d.phase, BossPhase.collapse);
      final k = d.collapse!;
      expect(d.wrecks.where((w) => !w.plate), isEmpty);
      step(60 * 8);
      expect(k.done, isTrue);
    });
  });

  group('the field thins in place', () {
    test('wear falls with the shield; gaps open only as it wears', () {
      var last = 2.0;
      for (var s = 1.0; s >= 0; s -= .05) {
        final w = CarrierFieldPainter.wear(s);
        expect(w, lessThanOrEqualTo(last));
        last = w;
      }
      expect(CarrierFieldPainter.wear(1), closeTo(1, 1e-9));
      expect(CarrierFieldPainter.wear(0), greaterThan(0));
      expect(CarrierFieldPainter.dropout(1), 0);
      expect(CarrierFieldPainter.dropout(.75), 0);
      expect(CarrierFieldPainter.dropout(.25), inInclusiveRange(.25, .45));
      expect(CarrierFieldPainter.dropout(0), lessThanOrEqualTo(.6));
    });

    test('the membrane keeps one offset at every shield level', () {
      expect(CarrierFieldMap.levels, contains(CarrierFieldPainter.offset));
    });
  });
}
