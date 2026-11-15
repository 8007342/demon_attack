import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/flyover_atlas.dart';
import 'package:demon_attack/game/ground_wildlife_atlas.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asset contract for the easter-egg wildlife sheet (ground-forces-rework
/// task 6.3, tools/ground_wildlife) and the sentinel foreshadow silhouettes
/// (atmosphere-and-swarms task 5.1, tools/sentinel_silhouettes).

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

typedef _Px = ({Uint8List rgba, int width});

Future<_Px> _pixels(ui.Image img) async {
  final b = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return (rgba: b.buffer.asUint8List(), width: img.width);
}

/// Opaque texels of [r] as (r, g, b, a) records.
Iterable<(int, int, int, int)> _cell(_Px px, ui.Rect r) sync* {
  for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
    for (var x = r.left.toInt(); x < r.right.toInt(); x++) {
      final i = (y * px.width + x) * 4;
      if (px.rgba[i + 3] == 0) continue;
      yield (px.rgba[i], px.rgba[i + 1], px.rgba[i + 2], px.rgba[i + 3]);
    }
  }
}

double _luma(int r, int g, int b) => (.2126 * r + .7152 * g + .0722 * b) / 255;

void main() {
  group('ground wildlife', () {
    late ui.Image image;
    late _Px px;
    setUpAll(() async {
      image = await _decode('assets/images/${GroundWildlifeAtlas.file}');
      px = await _pixels(image);
    });

    test('sheet matches its generated metadata', () {
      expect(image.width, GroundWildlifeAtlas.width);
      expect(image.height, GroundWildlifeAtlas.height);
      expect(GroundWildlifeAtlas.flockSpecies, hasLength(5));
      expect(GroundWildlifeAtlas.critterIds, hasLength(10));
      // Every leap row belongs to a flyover critter that exists.
      final ids = {for (final c in FlyoverAtlas.creatures) c.id};
      expect(ids.containsAll(GroundWildlifeAtlas.critterIds), isTrue);
    });

    test('every flock and leap cell is drawn, binary alpha', () {
      for (var s = 0; s < 5; s++) {
        for (final right in [false, true]) {
          for (var flap = 0; flap < 2; flap++) {
            final texels = _cell(
              px,
              GroundWildlifeAtlas.flock(s, flap, right: right),
            ).toList();
            expect(
              texels.length,
              greaterThan(12),
              reason: 'flock $s flap $flap right $right',
            );
            expect(texels.every((t) => t.$4 == 255), isTrue);
          }
        }
      }
      for (var i = 0; i < GroundWildlifeAtlas.critterIds.length; i++) {
        for (final leaping in [false, true]) {
          for (final mirrored in [false, true]) {
            final r = GroundWildlifeAtlas.leap(
              i,
              leaping: leaping,
              mirrored: mirrored,
            );
            final texels = _cell(px, r).toList();
            expect(
              texels.length,
              greaterThan(20),
              reason: '${GroundWildlifeAtlas.critterIds[i]} $leaping',
            );
            expect(texels.every((t) => t.$4 == 255), isTrue);
          }
        }
      }
    });

    test('below the signal colours (easter-egg rule 3)', () {
      final all = _cell(
        px,
        ui.Rect.fromLTWH(0, 0, image.width * 1.0, image.height * 1.0),
      ).toList();
      for (final (r, g, b, _) in all) {
        expect(_luma(r, g, b), lessThanOrEqualTo(.345));
        // Never ally cyan: a cool, bright texel.
        final cyan = g > 1.3 * r && b > 1.3 * r && (g > b ? g : b) - r > 51;
        expect(
          cyan && _luma(r, g, b) > .2,
          isFalse,
          reason: "cyan texel ($r, $g, $b)",
        );
      }
      // Flock flyers are never warm (never read as a target).
      final flock = _cell(
        px,
        ui.Rect.fromLTWH(
          0,
          0,
          image.width * 1.0,
          GroundWildlifeAtlas.critterTop * 1.0,
        ),
      ).toList();
      for (final (r, g, b, _) in flock) {
        expect(
          r > 1.35 * g && r > 1.2 * b && _luma(r, g, b) > .12,
          isFalse,
          reason: 'warm flock texel ($r, $g, $b)',
        );
      }
    });
  });

  group('sentinel silhouettes', () {
    test('8 banking frames x 2 blur levels per species', () async {
      final image = await _decode(
        'assets/images/${SentinelSilhouetteAtlas.file}',
      );
      expect(
        image.width,
        SentinelSilhouetteAtlas.frames * SentinelSilhouetteAtlas.cellW,
      );
      expect(image.height, 4 * SentinelSilhouetteAtlas.cellH);
      expect(
        SentinelSilhouetteAtlas.bankDeg,
        hasLength(SentinelSilhouetteAtlas.frames),
      );
      final px = await _pixels(image);
      for (var s = 0; s < 2; s++) {
        for (var f = 0; f < SentinelSilhouetteAtlas.frames; f++) {
          final sharp = _cell(
            px,
            SentinelSilhouetteAtlas.cell(s, f, 0),
          ).toList();
          final soft = _cell(
            px,
            SentinelSilhouetteAtlas.cell(s, f, 1),
          ).toList();
          expect(sharp.length, greaterThan(400), reason: 'species $s $f');
          // The far level is softer: more partly transparent texels.
          int partial(List<(int, int, int, int)> t) =>
              t.where((e) => e.$4 < 255).length;
          expect(partial(soft), greaterThan(partial(sharp)));
          // A dark shape only: the runtime tints it.
          expect(sharp.every((t) => _luma(t.$1, t.$2, t.$3) < .06), isTrue);
        }
      }
    });

    test('frame lookup covers the bank range symmetrically', () {
      expect(SentinelSilhouetteAtlas.frameFor(-1), 0);
      expect(
        SentinelSilhouetteAtlas.frameFor(1),
        SentinelSilhouetteAtlas.frames - 1,
      );
      expect(
        SentinelSilhouetteAtlas.frameFor(-.05) +
            SentinelSilhouetteAtlas.frameFor(.05),
        SentinelSilhouetteAtlas.frames - 1,
      );
      expect(
        SentinelSilhouetteAtlas.bankDeg.first,
        -SentinelSilhouetteAtlas.bankDeg.last,
      );
    });
  });
}
