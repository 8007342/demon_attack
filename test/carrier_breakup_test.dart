import 'dart:math' as math;

import 'package:demon_attack/game/carrier_breakup.dart';
import 'package:flutter_test/flutter_test.dart';

/// carrier-hatches Part B: components, the release rule and the bodies.
void main() {
  // A spine row: seven tapered spikes standing on a keel line, 1.2 px/unit.
  (List<int>, int, int) spines() {
    const w = 240, h = 120;
    final m = List<int>.filled(w * h, 0);
    for (var k = 0; k < 7; k++) {
      final cx = 20 + k * 32;
      for (var y = 10; y < 110; y++) {
        final half = ((110 - y) / 100 * 9).round();
        for (var x = cx - half; x <= cx + half; x++) {
          m[y * w + x] = 1;
        }
      }
    }
    return (m, w, h);
  }

  test('components: every removed cell in exactly one, spikes apart', () {
    final (m, w, h) = spines();
    final pieces = extractComponents(
      removed: m,
      w: w,
      h: h,
      ppu: 1.2,
      left: -100,
      top: -400,
      root: (0, -310),
    );
    expect(pieces, hasLength(7), reason: 'one per spike');
    final seen = <int>{};
    for (final p in pieces) {
      for (final c in p.cells) {
        expect(seen.add(c), isTrue, reason: 'cell $c twice');
      }
      // Root at the base (down-screen), tip up-screen.
      expect(p.component.ay, lessThan(0));
      expect(p.fragmentOf, hasLength(p.cells.length));
    }
    expect(pieces.length, lessThanOrEqualTo(48));
  });

  test('a wide plate splits; the count is capped at 48', () {
    const w = 600, h = 400;
    final m = List<int>.filled(w * h, 1);
    final pieces = extractComponents(
      removed: m,
      w: w,
      h: h,
      ppu: 1,
      left: 0,
      top: 0,
    );
    expect(pieces.length, greaterThan(1));
    expect(pieces.length, lessThanOrEqualTo(48));
  });

  test(
    'release rule: ≤ max(2, 25 %) per 0.25 s and ≥ 1.2 s per transition',
    () {
      for (final n in [1, 2, 3, 6, 7, 12, 30, 48]) {
        final order = [for (var i = 0; i < n; i++) i];
        final t = breakupSchedule(order, seed: n);
        expect(breakupRateOk(t), isTrue, reason: 'n $n: $t');
        if (n > 1) expect(t.reduce(math.max), greaterThanOrEqualTo(1.2 - 1e-9));
        // Released in the given order.
        for (var i = 1; i < n; i++) {
          expect(t[i], greaterThanOrEqualTo(t[i - 1]));
        }
      }
      // A whole layer at once breaks the rule.
      expect(breakupRateOk(List.filled(8, 0.0)), isFalse);
    },
  );

  test('continuity: a body starts at its pivot with v + ω × r', () {
    const c = BreakupComponent(
      id: 0,
      px: 50,
      py: -200,
      ax: 0,
      ay: -1,
      length: 30,
    );
    final b = BreakupPhysics.release(
      c,
      t: 1,
      wx: 230,
      wy: 5,
      hx: 180,
      hy: 205,
      hvx: 40,
      hw: .1,
      rng: math.Random(1),
    );
    final (x, y, _, s, a) = b.pose(1);
    expect((x, y), (230.0, 5.0));
    expect((s, a), (1.0, 1.0));
    // v + ω × r: vx = 40 − ω·ry (ry = −200) plus the kick's jitter (±4).
    expect(b.vx0, closeTo(40 + .1 * 200, 4.01));
    // Fragments: 2 (m), inheriting the parent's motion.
    final f = BreakupPhysics.fragments(b, c, rng: math.Random(2));
    expect(f, hasLength(2));
    final (vx, _) = b.velocity(f.first.t0);
    expect(f.first.vx0, closeTo(vx, 30));
    // It sinks, shrinks and is gone within its life.
    final (_, y1, _, s1, _) = b.pose(1 + b.life * .9);
    expect(y1, greaterThan(y));
    expect(s1, lessThan(1));
    expect(b.done(1 + b.life), isTrue);
  });

  test('reduced motion: no tear, spin or fragments; kicks at 40 %', () {
    const c = BreakupComponent(
      id: 0,
      px: 50,
      py: -200,
      ax: 1,
      ay: 0,
      length: 80,
    );
    final b = BreakupPhysics.release(
      c,
      t: 0,
      wx: 0,
      wy: 0,
      hx: 0,
      hy: 0,
      rng: math.Random(3),
      reduced: true,
    );
    expect(b.w0, 0);
    expect(b.tear, 0);
    expect(b.split, lessThan(0));
    expect(b.vx0, lessThanOrEqualTo(16 * .4 + 4.01));
  });

  test('order: outer first, the hit side first', () {
    const cs = [
      BreakupComponent(id: 0, px: 10, py: 0, ax: 0, ay: -1, length: 10),
      BreakupComponent(id: 1, px: 200, py: 0, ax: 0, ay: -1, length: 10),
      BreakupComponent(id: 2, px: -150, py: 0, ax: 0, ay: -1, length: 10),
    ];
    expect(breakupOrder(cs), [1, 2, 0]);
    expect(breakupOrder(cs, side: -1).first, 2);
  });
}
