// The talk mouths sit exactly on each portrait's own lips, in both atlases
// and at every size the game draws them: the 128 px desktop panel at 2x,
// the 48 px phone atlas at 1x, the phone toast at half size and the
// full-size transmission at 3x.
//
// With --dart-define=COMMS_RENDER=/abs/dir it also writes a contact sheet
// of every character's talk frames at every size (mouth-alignment.png) for
// review.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_portraits.dart';
import 'package:demon_attack/comms/comms_types.dart';
import 'package:demon_attack/comms/comms_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const renderDir = String.fromEnvironment('COMMS_RENDER');

/// Talk frames, closed to wide, then the rounded and the teeth shapes.
const talk = [
  CommsFrame.talkA,
  CommsFrame.talkB,
  CommsFrame.talkC,
  CommsFrame.talkWide,
  CommsFrame.talkD,
  CommsFrame.talkEe,
];

class _Px {
  _Px(this.bytes, this.width);
  final Uint8List bytes;
  final int width;
  int at(int x, int y) {
    final i = (y * width + x) * 4;
    return bytes[i] << 24 |
        bytes[i + 1] << 16 |
        bytes[i + 2] << 8 |
        bytes[i + 3];
  }
}

Future<(ui.Image, _Px)> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (image, _Px(data!.buffer.asUint8List(), image.width));
}

Future<_Px> _pixels(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Px(data!.buffer.asUint8List(), image.width);
}

/// Bounding box [x0, y0, x1, y1) and count of pixels that differ between
/// two cells, or null when none do.
(List<int>, int)? _changed(_Px px, int ax, int bx, int y0, int cell) {
  var x0 = cell, y0b = cell, x1 = -1, y1 = -1, n = 0;
  for (var y = 0; y < cell; y++) {
    for (var x = 0; x < cell; x++) {
      if (px.at(ax + x, y0 + y) != px.at(bx + x, y0 + y)) {
        n++;
        if (x < x0) x0 = x;
        if (y < y0b) y0b = y;
        if (x > x1) x1 = x;
        if (y > y1) y1 = y;
      }
    }
  }
  return n == 0 ? null : ([x0, y0b, x1 + 1, y1 + 1], n);
}

/// A 128-grid box on the small grid, grown by the area filter's footprint
/// (tools/comms_portraits.py small_box).
List<int> _smallBox(List<int> b, int g, int s) {
  final k = g / s;
  return [
    (b[0] / k).floor() - 1,
    (b[1] / k).floor() - 1,
    (b[2] / k).ceil() + 1,
    (b[3] / k).ceil() + 1,
  ];
}

void main() {
  final faces = jsonDecode(
    File('art/comms/portrait-faces.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('every character has measured lips inside its mouth box', () {
    for (final id in commsPortraitRows.keys) {
      expect(faces[id], isNotNull, reason: id);
      final lips = faces[id]['lips'] as Map<String, dynamic>;
      final mouth = (faces[id]['mouth'] as List).cast<int>();
      expect(
        lips['right'] - lips['left'],
        greaterThanOrEqualTo(12),
        reason: id,
      );
      expect(lips['left'], greaterThanOrEqualTo(mouth[0]), reason: id);
      expect(lips['right'], lessThan(mouth[2]), reason: id);
      expect(
        lips['seam'],
        inInclusiveRange(mouth[1], mouth[3] - 1),
        reason: id,
      );
    }
  });

  testWidgets(
    'talk frames change only the mouth, on the lips, in both atlases',
    (tester) async {
      final big = (await tester.runAsync(() => _decode(commsPortraitImage)))!;
      final small = (await tester.runAsync(
        () => _decode(commsPortraitSmallImage),
      ))!;
      expect(big.$1.width, commsPortraitCell * CommsFrame.count);
      expect(small.$1.width, commsPortraitSmallCell * CommsFrame.count);
      for (final MapEntry(key: id, value: row) in commsPortraitRows.entries) {
        final lips = faces[id]['lips'] as Map<String, dynamic>;
        final mouth = (faces[id]['mouth'] as List).cast<int>();
        final cx = (lips['left'] + lips['right'] + 1) / 2;
        final seam = (lips['seam'] as int) + .5;
        for (final (px, cell) in [
          (big.$2, commsPortraitCell),
          (small.$2, commsPortraitSmallCell),
        ]) {
          final k = cell / commsPortraitCell;
          final box = cell == commsPortraitCell
              ? mouth
              : _smallBox(mouth, commsPortraitCell, cell);
          final counts = <int>[];
          for (final f in talk) {
            final c = _changed(px, 0, f * cell, row * cell, cell);
            final label = '$id ${cell}px frame $f';
            expect(c, isNotNull, reason: '$label: no visible mouth shape');
            final (b, n) = c!;
            counts.add(n);
            // Only inside the mouth box.
            expect(b[0], greaterThanOrEqualTo(box[0]), reason: label);
            expect(b[1], greaterThanOrEqualTo(box[1]), reason: label);
            expect(b[2], lessThanOrEqualTo(box[2]), reason: label);
            expect(b[3], lessThanOrEqualTo(box[3]), reason: label);
            // Centred on the lips and opening at the lip seam: the upper lip
            // lifts a little, the jaw drops the rest.
            final tol = cell == commsPortraitCell ? 1.6 : 1.1;
            expect(
              ((b[0] + b[2]) / 2 - cx * k).abs(),
              lessThanOrEqualTo(tol + 1.5 * (1 - k)),
              reason: '$label centre ${(b[0] + b[2]) / 2} vs lips ${cx * k}',
            );
            expect(
              b[1],
              lessThanOrEqualTo((seam * k).ceil()),
              reason: '$label top',
            );
            expect(
              b[1],
              greaterThanOrEqualTo(((seam - 9) * k).floor() - 1),
              reason: '$label top',
            );
            expect(
              b[3],
              greaterThan((seam * k).floor()),
              reason: '$label bottom',
            );
          }
          // Intermediate shapes: slight < half < open < wide.
          if (cell == commsPortraitCell) {
            expect(counts[0], lessThan(counts[1]), reason: '$id slight < half');
            expect(counts[1], lessThan(counts[2]), reason: '$id half < open');
            expect(counts[2], lessThan(counts[3]), reason: '$id open < wide');
          }
        }
      }
    },
  );

  testWidgets('drawn at every size the mouth lands on the lips', (
    tester,
  ) async {
    await tester.runAsync(() => CommsPortraitAtlas.instance.load());
    expect(CommsPortraitAtlas.instance.large, isNotNull);
    // (label, side px, small atlas)
    const sizes = [
      ('desktop 2x', 256.0, false),
      ('phone 48', 48.0, true),
      ('toast 24', 24.0, true),
      ('transmission 3x', 384.0, false),
    ];
    final ids = commsPortraitRows.keys.toList();
    const pad = 4.0;
    final frames = [CommsFrame.idle, ...talk];
    final width = sizes
        .fold(0.0, (w, s) => w + frames.length * (s.$2 + pad))
        .ceil();
    final rowH = sizes.fold(0.0, (h, s) => s.$2 > h ? s.$2 : h) + pad;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), rowH * ids.length),
      Paint()..color = const Color(0xFF0B1424),
    );
    final cells = <(String, String, int, Rect)>[];
    for (var r = 0; r < ids.length; r++) {
      var x = 0.0;
      for (final (label, side, small) in sizes) {
        for (final f in frames) {
          final dst = Rect.fromLTWH(x, r * rowH, side, side);
          paintPortrait(canvas, dst, ids[r], f, small: small);
          cells.add((ids[r], label, f, dst));
          x += side + pad;
        }
      }
    }
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(
      () => picture.toImage(width, (rowH * ids.length).ceil()),
    ))!;
    final px = (await tester.runAsync(() => _pixels(image)))!;
    if (renderDir.isNotEmpty) {
      await tester.runAsync(() async {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$renderDir/mouth-alignment.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }
    for (final (id, label, f, dst) in cells) {
      if (f == CommsFrame.idle) continue;
      final idle = cells
          .firstWhere(
            (c) => c.$1 == id && c.$2 == label && c.$3 == CommsFrame.idle,
          )
          .$4;
      final side = dst.width.round();
      final c = _changed(
        px,
        idle.left.round(),
        dst.left.round(),
        dst.top.round(),
        side,
      );
      final why = '$id $label frame $f';
      expect(c, isNotNull, reason: '$why: mouth not visible');
      final lips = faces[id]['lips'] as Map<String, dynamic>;
      final mouth = (faces[id]['mouth'] as List).cast<int>();
      final s = side / commsPortraitCell;
      final cx = (lips['left'] + lips['right'] + 1) / 2 * s;
      final (b, _) = c!;
      expect(
        ((b[0] + b[2]) / 2 - cx).abs(),
        lessThanOrEqualTo(1.5 + 1.5 * s),
        reason: '$why centre ${(b[0] + b[2]) / 2} vs $cx',
      );
      // Inside the mouth box, allowing a pixel of filtering at small sizes.
      final slack = s < 1 ? 1.5 : 0.0;
      expect(b[0], greaterThanOrEqualTo(mouth[0] * s - slack - 1), reason: why);
      expect(b[1], greaterThanOrEqualTo(mouth[1] * s - slack - 1), reason: why);
      expect(b[2], lessThanOrEqualTo(mouth[2] * s + slack + 1), reason: why);
      expect(b[3], lessThanOrEqualTo(mouth[3] * s + slack + 1), reason: why);
    }
  });
}
