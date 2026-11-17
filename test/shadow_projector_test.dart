// terrain-shadows task 1.2 (design §5): the pure projector on synthetic
// surfaces and on the real TerrainView.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:demon_attack/game/shadow_projector.dart';
import 'package:demon_attack/game/terrain_field.dart';
import 'package:flutter_test/flutter_test.dart';

/// A ridge running across the screen at flat-ground y [at], [height] arena
/// units high (no occlusion: the stretch is what is measured).
class _Ridge implements ShadowSurface {
  const _Ridge(this.at, this.height, this.width);
  final double at, height, width;
  @override
  double shadowLift(double x, double flatY) {
    final u = (flatY - at) / width;
    return height * math.exp(-u * u);
  }

  @override
  (double, bool) shadowDrape(double x, double flatY) =>
      (flatY - shadowLift(x, flatY), false);
}

/// A mesa whose crest at flat y [crest] hides all ground beyond it, up to
/// [far] (the ground further still shows again over its top).
class _Mesa implements ShadowSurface {
  const _Mesa(this.crest, this.far);
  final double crest, far;
  @override
  double shadowLift(double x, double flatY) => 0;
  @override
  (double, bool) shadowDrape(double x, double flatY) =>
      flatY < crest && flatY > far ? (crest - 10, true) : (flatY, false);
}

({Float32List pos, Float32List tex, Uint16List idx, int n}) _drape(
  ShadowSurface s,
  Offset flat, {
  double w = 60,
  double h = 26,
}) {
  final pos = Float32List(ShadowProjector.vertices * 2);
  final tex = Float32List(ShadowProjector.vertices * 2);
  final idx = Uint16List(ShadowProjector.cells * 6);
  final n = ShadowProjector.drape(
    s,
    flat,
    w,
    h,
    const Rect.fromLTWH(64, 128, 64, 64),
    pos,
    tex,
    idx,
    0,
    0,
  );
  return (pos: pos, tex: tex, idx: idx, n: n);
}

/// The legacy centre (scene.dart before terrain-shadows).
Offset _legacy(double x, double gy, double h, double az) {
  final off = h * math.tan(32 * math.pi / 180) * .22;
  return Offset(x + off * math.cos(az), gy + off * .25 + off * math.sin(az));
}

void main() {
  test('flat ground: every hit equals the legacy centre (<= 0.01 u)', () {
    final r = math.Random(7);
    const flat = FlatShadowSurface();
    for (var i = 0; i < 500; i++) {
      final x = r.nextDouble() * 360;
      final gy = 180 + r.nextDouble() * 350;
      final h = r.nextDouble() * 300;
      final az = (r.nextDouble() * 2 - 1) * 4 * math.pi / 180;
      final hit = ShadowProjector.hit(
        flat,
        Offset(x, gy),
        h,
        ShadowProjector.flyerDir(az),
      );
      final want = _legacy(x, gy, h, az);
      expect((hit.center - want).distance, lessThan(.01));
      expect(hit.lift, 0);
    }
    // The ship: lateral offset only, at h 40.
    final ship = ShadowProjector.hit(
      flat,
      const Offset(186, 501),
      40,
      ShadowProjector.shipDir,
    );
    expect(ship.center.dy, 501);
    expect(
      ship.center.dx,
      closeTo(186 + 40 * math.tan(32 * math.pi / 180) * .22, 1e-9),
    );
  });

  test('flat ground: the drape is the legacy squashed quad', () {
    final d = _drape(const FlatShadowSurface(), const Offset(100, 400));
    expect(d.n, ShadowProjector.cells * 6);
    // Corners at centre ± w/2, ± h/2.
    expect(d.pos[0], closeTo(70, 1e-4));
    expect(d.pos[1], closeTo(387, 1e-4));
    const last = (ShadowProjector.vertices - 1) * 2;
    expect(d.pos[last], closeTo(130, 1e-4));
    expect(d.pos[last + 1], closeTo(413, 1e-4));
    expect(d.tex[0], 64);
    expect(d.tex[last + 1], 192);
  });

  test(
    'a 30-unit ridge: the shadow lies on it and stretches toward the camera',
    () {
      const ridge = _Ridge(360, 30, 22);
      const base = Offset(180, 355);
      const h = 60.0;
      final dir = ShadowProjector.flyerDir(0);
      final hit = ShadowProjector.hit(ridge, base, h, dir);
      // The ray lands earlier on the raised ground (shorter offset) ...
      final flat = ShadowProjector.hit(const FlatShadowSurface(), base, h, dir);
      expect(hit.lift, greaterThan(10));
      expect(hit.flat.dy, lessThan(flat.flat.dy));
      // ... and the centre sits on the ridge's visible surface.
      expect(
        hit.center.dy,
        closeTo(hit.flat.dy - ridge.shadowLift(0, hit.flat.dy), 1e-6),
      );
      expect(hit.center.dy, lessThan(flat.center.dy - 10));
      // Fixed point: the lift at the hit is the lift the ray was shortened by.
      final again = ShadowProjector.flatCenter(base, h - hit.lift, dir);
      expect((again - hit.flat).distance, lessThan(.5));
      // On the slope facing away from the sun (it faces the camera, y > the
      // ridge line) the rows spread; on the far slope they compress.
      double span(Offset at) {
        final d = _drape(ridge, at, h: 30);
        return d.pos[(ShadowProjector.vertices - 1) * 2 + 1] - d.pos[1];
      }

      expect(span(const Offset(180, 378)), greaterThan(30 * 1.2));
      expect(span(const Offset(180, 342)), lessThan(30 * .8));
      expect(span(const Offset(180, 470)), closeTo(30, .01));
    },
  );

  test('crest occlusion: a shadow behind a nearer mesa is not drawn', () {
    const mesa = _Mesa(320, 220);
    expect(_drape(mesa, const Offset(180, 260)).n, 0);
    // Straddling the crest: only the visible cells remain.
    final part = _drape(mesa, const Offset(180, 310), h: 40);
    expect(part.n, greaterThan(0));
    expect(part.n, lessThan(ShadowProjector.cells * 6));
    for (var i = 0; i < part.n; i++) {
      expect(part.pos[part.idx[i] * 2 + 1], greaterThanOrEqualTo(309));
    }
  });

  test('the real terrain: hidden ground drops whole cells', () {
    final view = TerrainView();
    var found = false;
    for (var k = 0; k < 25 && !found; k++) {
      view
        ..configure(k % 5, k ~/ 5)
        ..cam = 0;
      for (var cam = 0.0; cam < 6000 && !found; cam += 40) {
        view.cam = cam;
        for (var x = 0.0; x <= 360 && !found; x += 15) {
          for (var y = 200.0; y < 400 && !found; y += 2) {
            final (_, a) = view.shadowDrape(x, y);
            final (_, b) = view.shadowDrape(x, y - 6);
            final (_, c) = view.shadowDrape(x + 4, y);
            final (_, d) = view.shadowDrape(x + 4, y - 6);
            if (a && b && c && d) {
              final dr = _drape(view, Offset(x + 2, y - 3), w: 4, h: 6);
              expect(dr.n, 0);
              found = true;
            }
          }
        }
      }
    }
    expect(found, isTrue, reason: 'Hollow terrain has hidden ground');
  });

  test('morph: the hit point moves continuously across mix 0 -> 1', () {
    final view = TerrainView()..cam = 900;
    final casters = [
      for (var x = 20.0; x < 360; x += 40)
        for (final gy in [260.0, 330.0, 420.0, 500.0]) Offset(x, gy),
    ];
    final dir = ShadowProjector.flyerDir(0);
    List<Offset> hits() => [
      for (final c in casters) ShadowProjector.hit(view, c, 120, dir).center,
    ];
    for (final (a, b) in const [(1, 2), (2, 3), (3, 4)]) {
      view.configure(a, 0, far: b, mix: 0);
      var last = hits();
      var moved = 0.0;
      for (var f = 1; f <= 60; f++) {
        view.configure(a, 0, far: b, mix: f / 60);
        final now = hits();
        for (var i = 0; i < now.length; i++) {
          final step = (now[i] - last[i]).distance;
          expect(step, lessThanOrEqualTo(2), reason: 'sector $a->$b f $f');
          moved = math.max(moved, (now[i] - hits()[i]).distance);
        }
        last = now;
      }
      expect(moved, 0); // deterministic per frame
    }
    // The morph does move the shadows: the end differs from the start.
    view.configure(1, 0, far: 2, mix: 0);
    final start = hits();
    view.configure(1, 0, far: 2, mix: 1);
    final end = hits();
    var total = 0.0;
    for (var i = 0; i < start.length; i++) {
      total += (end[i] - start[i]).distance;
    }
    expect(total, greaterThan(5));
  });
}
