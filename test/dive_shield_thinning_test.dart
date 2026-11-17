// dive-shield-thinning (openspec/changes/dive-shield-thinning): every diving
// shield is one continuous arc of constant angular width, wide enough to
// cover the whole gargoyle at every zoom, that loses only thickness as its
// points are spent, down to a hairline.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/dive_shield.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each spec with the largest point count it is drawn with: 3 for ordinary
/// divers (elites), 4 + cycle ÷ 2 for a sentinel's dive shield and
/// 10 + cycle ÷ 2 for the rush shield (cycles up to 8 checked).
final _specs = <(String, DiveShieldSpec, int)>[
  ('small', DiveShield.small, 1),
  ('medium', DiveShield.medium, 3),
  ('angry medium', DiveShield.medium.scaled(44 / 40), 3),
  ('sentinel', DiveShield.sentinel, 8),
  ('rush', DiveShield.rush, 14),
];

const _zooms = [.45, .8, 1.0, 1.25, 1.6];

/// Renders [paint] into a [size] × [size] RGBA buffer (transparent ground);
/// the image is disposed before returning.
Future<Uint8List> _render(int size, void Function(ui.Canvas) paint) async {
  final rec = ui.PictureRecorder();
  paint(ui.Canvas(rec));
  final pic = rec.endRecording();
  final img = await pic.toImage(size, size);
  pic.dispose();
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  return data!.buffer.asUint8List();
}

/// The shield alone, centred in a [size] buffer, at [zoom].
Future<Uint8List> _shield(
  int size,
  DiveShieldSpec s,
  int points,
  int max,
  double zoom,
) => _render(size, (c) {
  final o = Offset(size / 2, size / 2);
  c
    ..translate(o.dx, o.dy)
    ..scale(zoom)
    ..translate(-o.dx, -o.dy);
  DiveShield.paint(c, o, s, points: points, max: max, calm: true);
});

/// Number of 8-connected components of pixels with alpha over [cut].
int _components(Uint8List px, int size, {int cut = 24}) {
  final seen = Uint8List(size * size);
  var n = 0;
  final stack = <int>[];
  for (var i = 0; i < size * size; i++) {
    if (seen[i] == 1 || px[i * 4 + 3] <= cut) continue;
    n++;
    seen[i] = 1;
    stack.add(i);
    // Bounded: every pixel enters the stack at most once.
    while (stack.isNotEmpty) {
      final k = stack.removeLast();
      final x = k % size, y = k ~/ size;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= size || ny >= size) continue;
          final j = ny * size + nx;
          if (seen[j] == 1 || px[j * 4 + 3] <= cut) continue;
          seen[j] = 1;
          stack.add(j);
        }
      }
    }
  }
  return n;
}

/// Horizontal extent (px from the buffer's centre) of pixels over [cut].
(double, double) _xExtent(Uint8List px, int size, {int cut = 128}) {
  var lo = double.infinity, hi = -double.infinity;
  for (var i = 0; i < size * size; i++) {
    if (px[i * 4 + 3] <= cut) continue;
    final x = (i % size) + .5 - size / 2;
    lo = math.min(lo, x);
    hi = math.max(hi, x);
  }
  return (lo, hi);
}

/// Angular extent (radians from straight down) of the pixels on the
/// shield's centre line (within a pixel of radius [mid] px).
(double, double) _angles(Uint8List px, int size, double mid, {int cut = 128}) {
  var lo = double.infinity, hi = -double.infinity;
  for (var i = 0; i < size * size; i++) {
    if (px[i * 4 + 3] <= cut) continue;
    final x = (i % size) + .5 - size / 2, y = (i ~/ size) + .5 - size / 2;
    if ((math.sqrt(x * x + y * y) - mid).abs() > 1) continue;
    final a = math.atan2(x, y); // 0 straight down, + to the right
    lo = math.min(lo, a);
    hi = math.max(hi, a);
  }
  return (lo, hi);
}

/// Opaque run (px) straight below the centre: the thickness at the nose.
int _noseRun(Uint8List px, int size, {int cut = 128}) {
  final x = size ~/ 2;
  var run = 0;
  for (var y = size ~/ 2; y < size; y++) {
    if (px[(y * size + x) * 4 + 3] > cut) run++;
  }
  return run;
}

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// An atlas cell's opaque pixels (alpha > 96, px corners from the cell's
/// centre): the widest half-width, and the farthest reach within 70° of
/// straight down.
({double hw, double reach}) _cellBounds(
  ByteData rgba,
  int width,
  int col,
  int row,
  int cw,
  int ch,
) {
  var hw = 0.0, reach = 0.0;
  const range = 70 * math.pi / 180;
  for (var y = row * ch; y < (row + 1) * ch; y++) {
    for (var x = col * cw; x < (col + 1) * cw; x++) {
      if (rgba.getUint8((y * width + x) * 4 + 3) <= 96) continue;
      for (final (ox, oy) in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
        final dx = x + ox - col * cw - cw / 2, dy = y + oy - row * ch - ch / 2;
        hw = math.max(hw, dx.abs());
        if (math.atan2(dx.abs(), dy) <= range) {
          reach = math.max(reach, math.sqrt(dx * dx + dy * dy));
        }
      }
    }
  }
  return (hw: hw, reach: reach);
}

void main() {
  group('thinning, not narrowing', () {
    test('thickness falls strictly with every spent point', () {
      for (final (name, s, top) in _specs) {
        for (var max = 1; max <= top; max++) {
          var last = 0.0;
          for (var p = 1; p <= max; p++) {
            final th = DiveShield.thickness(s, p, max);
            expect(th, greaterThan(last), reason: '$name $p/$max');
            last = th;
          }
          expect(DiveShield.thickness(s, max, max), s.full);
          expect(DiveShield.thickness(s, 0, max), 0);
          if (max > 1) {
            expect(DiveShield.thickness(s, 1, max), DiveShield.hairline);
          }
        }
      }
    });

    test('the rush shield is the thickest', () {
      for (final (name, s, _) in _specs) {
        if (s == DiveShield.rush) continue;
        expect(DiveShield.rush.full, greaterThan(s.full), reason: name);
      }
    });

    test('the arc reaches past the body and clears it below', () {
      // One constant angular width; the centre line is fixed by the spec
      // (the shield thins about it, the carrier field's principle).
      expect(DiveShield.halfAngle, closeTo(62 * math.pi / 180, 1e-12));
      for (final (name, s, _) in _specs) {
        expect(
          s.mid * math.sin(DiveShield.halfAngle),
          greaterThan(s.coverHalfWidth),
          reason: name,
        );
        expect(s.inner, greaterThan(s.clearance), reason: name);
      }
    });

    test('every diver picks a spec that grows with its body', () {
      final small = Demon(0, 0, 0, 1, 0)..diveShieldMax = 1;
      final medium = Demon(0, 0, 2, 3, 0)..diveShieldMax = 2;
      final sentinel = Demon(
        0,
        0,
        0,
        9,
        0,
        archetype: EnemyArchetype.shieldSentinel,
      )..diveShieldMax = 4;
      expect(DemonScene.diveShieldSpec(small).full, DiveShield.small.full);
      expect(DemonScene.diveShieldSpec(medium).full, DiveShield.medium.full);
      expect(DemonScene.diveShieldSpec(sentinel), DiveShield.sentinel);
      medium.hp = 1; // angry: one hit point left of several
      expect(
        DemonScene.diveShieldSpec(medium).mid,
        closeTo(DiveShield.medium.mid * 44 / 40, 1e-9),
      );
    });
  });

  testWidgets('the specs cover every silhouette measured from the atlases', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Ordinary divers: combat.png, 64 px cells drawn 40 units wide.
      final combat = await _decode('assets/images/combat.png');
      final cb = (await combat.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var hw = 0.0, reach = 0.0;
      for (var kind = 0; kind < 4; kind++) {
        for (var col = 20; col < 32; col++) {
          final b = _cellBounds(cb, combat.width, col, kind * 9 + 7, 64, 64);
          hw = math.max(hw, b.hw);
          reach = math.max(reach, b.reach);
        }
      }
      combat.dispose();
      for (final s in [DiveShield.small, DiveShield.medium]) {
        expect(s.coverHalfWidth, greaterThanOrEqualTo(hw * 40 / 64));
        expect(s.clearance, greaterThanOrEqualTo(reach * 40 / 64));
      }
      // Sentinels: sentinel-effects.png, 128 × 64 cells at 1 unit per px.
      final fx = await _decode('assets/images/sentinel-effects.png');
      final fb = (await fx.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      ({double hw, double reach}) span(List<int> rows, List<int> cols) {
        var w = 0.0, r = 0.0;
        for (final row in rows) {
          for (final c in cols) {
            final x = _cellBounds(fb, fx.width, c, row, 128, 64);
            w = math.max(w, x.hw);
            r = math.max(r, x.reach);
          }
        }
        return (hw: w, reach: r);
      }

      final dive = span([8, 9], [4, 5, 6, 7]);
      final berserk = span([6, 7], [0, 1, 2, 3, 4, 5, 6, 7]);
      fx.dispose();
      expect(DiveShield.sentinel.coverHalfWidth, greaterThanOrEqualTo(dive.hw));
      expect(DiveShield.sentinel.clearance, greaterThanOrEqualTo(dive.reach));
      expect(DiveShield.rush.coverHalfWidth, greaterThanOrEqualTo(berserk.hw));
      expect(DiveShield.rush.clearance, greaterThanOrEqualTo(berserk.reach));
    });
  });

  testWidgets('constant angular width, covering the body at every zoom', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final (name, s, top) in _specs) {
        for (final z in _zooms) {
          final size = (2 * (s.mid + s.full * 2) * z).ceil() + 8;
          final mid = s.mid * z;
          final want = DiveShield.halfAngle;
          // Allow a pixel of rasterisation at the centre line's ends.
          final tol = 1.5 / mid;
          final maxes = {1, top};
          for (final max in maxes) {
            for (var p = 1; p <= max; p++) {
              final px = await _shield(size, s, p, max, z);
              final (lo, hi) = _angles(px, size, mid, cut: 60);
              expect(lo, closeTo(-want, tol), reason: '$name $p/$max ×$z');
              expect(hi, closeTo(want, tol), reason: '$name $p/$max ×$z');
              final (xl, xr) = _xExtent(px, size, cut: 60);
              final body = s.coverHalfWidth * z;
              expect(xl, lessThan(-body), reason: '$name $p/$max ×$z');
              expect(xr, greaterThan(body), reason: '$name $p/$max ×$z');
            }
          }
        }
      }
    });
  });

  testWidgets('the drawn thickness falls with every spent point', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final (name, s, top) in _specs) {
        if (top < 2) continue;
        const z = 1.6;
        final size = (2 * (s.mid + s.full * 2) * z).ceil() + 8;
        var last = 1 << 30;
        for (var p = top; p >= 1; p--) {
          final run = _noseRun(await _shield(size, s, p, top, z), size);
          expect(run, lessThanOrEqualTo(last), reason: '$name $p/$top');
          expect(run, greaterThan(0), reason: '$name $p/$top: still drawn');
          last = run;
        }
        final full = _noseRun(await _shield(size, s, top, top, z), size);
        expect(full, greaterThan(last * 3), reason: '$name: visibly thinner');
      }
    });
  });

  testWidgets('one connected shape, no gaps, at every level and zoom', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final (name, s, top) in _specs) {
        for (final z in _zooms) {
          final size = (2 * (s.mid + s.full * 2) * z).ceil() + 8;
          for (var p = 1; p <= top; p++) {
            final px = await _shield(size, s, p, top, z);
            expect(
              _components(px, size),
              1,
              reason: '$name $p/$top at ×$z is one shape',
            );
          }
        }
      }
    });
  });
}
