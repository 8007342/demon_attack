// dive-shield-thinning (openspec/changes/dive-shield-thinning): every diving
// shield is one continuous crescent (playtest-fixes-3's form and size) of
// constant span, covering the whole gargoyle at every zoom, that loses only
// thickness as its points are spent, to 40 % of full on the last point.
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

/// The width the shield spans at its tips (local units, both sides).
double _bodyHalf(String name) => switch (name) {
  'angry medium' => 25 * 44 / 64,
  'sentinel' => 29,
  'rush' => 49,
  _ => 25 * 40 / 64,
};

void main() {
  group('thinning, not narrowing', () {
    test('thickness falls strictly with every spent point, to the floor', () {
      for (final (name, _, top) in _specs) {
        for (var max = 1; max <= top; max++) {
          var last = 0.0;
          for (var p = 1; p <= max; p++) {
            final w = DiveShield.wear(p, max);
            expect(w, greaterThan(last), reason: '$name $p/$max');
            last = w;
          }
          expect(DiveShield.wear(max, max), 1);
          expect(DiveShield.wear(0, max), 0);
          expect(
            DiveShield.wear(1, max),
            greaterThanOrEqualTo(DiveShield.floor),
          );
        }
      }
      expect(DiveShield.floor, inInclusiveRange(.35, .45));
    });

    test('the rush shield is the thickest', () {
      for (final (name, s, _) in _specs) {
        if (s == DiveShield.rush) continue;
        expect(DiveShield.rush.thick, greaterThan(s.thick), reason: name);
      }
    });

    test('the leading edge never depends on the points', () {
      for (final (_, s, _) in _specs) {
        for (var i = 0; i <= 20; i++) {
          final u = -1 + i / 10;
          // Only the trailing side is scaled by the wear.
          expect(DiveShield.leadAt(s, u), s.lead + s.nose * (1 - u * u));
          expect(DiveShield.thickAt(s, u), greaterThan(0));
        }
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
      expect(DemonScene.diveShieldSpec(small), DiveShield.small);
      expect(DemonScene.diveShieldSpec(medium), DiveShield.medium);
      expect(DemonScene.diveShieldSpec(sentinel), DiveShield.sentinel);
      medium.hp = 1; // angry: one hit point left of several
      expect(
        DemonScene.diveShieldSpec(medium).span,
        closeTo(DiveShield.medium.span * 44 / 40, 1e-9),
      );
    });
  });

  testWidgets('the spans cover every silhouette measured from the atlases', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final combat = await _decode('assets/images/combat.png');
      final cb = (await combat.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var hw = 0.0;
      for (var kind = 0; kind < 4; kind++) {
        for (var col = 20; col < 32; col++) {
          final b = _cellBounds(cb, combat.width, col, kind * 9 + 7, 64, 64);
          hw = math.max(hw, b.hw);
        }
      }
      combat.dispose();
      expect(_bodyHalf('small'), greaterThanOrEqualTo(hw * 40 / 64));
      final fx = await _decode('assets/images/sentinel-effects.png');
      final fb = (await fx.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      double span(List<int> rows, List<int> cols) {
        var w = 0.0;
        for (final row in rows) {
          for (final c in cols) {
            w = math.max(w, _cellBounds(fb, fx.width, c, row, 128, 64).hw);
          }
        }
        return w;
      }

      final dive = span([8, 9], [4, 5, 6, 7]);
      final berserk = span([6, 7], [0, 1, 2, 3, 4, 5, 6, 7]);
      fx.dispose();
      expect(_bodyHalf('sentinel'), greaterThanOrEqualTo(dive));
      expect(_bodyHalf('rush'), greaterThanOrEqualTo(berserk));
      for (final (name, s, _) in _specs) {
        expect(s.span, greaterThanOrEqualTo(_bodyHalf(name)), reason: name);
      }
    });
  });

  testWidgets('constant span, covering the body at every zoom and level', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final (name, s, top) in _specs) {
        for (final z in _zooms) {
          final size = (2 * (s.span + 4) * z).ceil() + 8;
          final full = _xExtent(await _shield(size, s, top, top, z), size);
          for (var p = 1; p <= top; p++) {
            final px = await _shield(size, s, p, top, z);
            final (xl, xr) = _xExtent(px, size, cut: 60);
            expect(xl, closeTo(full.$1, 1.5), reason: '$name $p/$top ×$z');
            expect(xr, closeTo(full.$2, 1.5), reason: '$name $p/$top ×$z');
            final body = _bodyHalf(name) * z;
            expect(xl, lessThanOrEqualTo(-body + 1), reason: '$name ×$z');
            expect(xr, greaterThanOrEqualTo(body - 1), reason: '$name ×$z');
          }
        }
      }
    });
  });

  testWidgets('the drawn thickness falls with every point, never below the '
      'floor', (tester) async {
    await tester.runAsync(() async {
      for (final (name, s, top) in _specs) {
        if (top < 2) continue;
        const z = 1.6;
        final size = (2 * (s.span + 4) * z).ceil() + 8;
        final full = _noseRun(
          await _shield(size, s, top, top, z),
          size,
          cut: 60,
        );
        var last = full + 1;
        for (var p = top; p >= 1; p--) {
          final run = _noseRun(
            await _shield(size, s, p, top, z),
            size,
            cut: 60,
          );
          expect(run, lessThanOrEqualTo(last), reason: '$name $p/$top');
          last = run;
        }
        expect(last, lessThan(full), reason: '$name: visibly worn');
        expect(
          last,
          greaterThanOrEqualTo((full * DiveShield.floor).floor() - 1),
          reason: '$name: the last point keeps the floor',
        );
      }
    });
  });

  testWidgets('one connected shape, no gaps, at every level and zoom', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final (name, s, top) in _specs) {
        for (final z in _zooms) {
          final size = (2 * (s.span + 4) * z).ceil() + 8;
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
