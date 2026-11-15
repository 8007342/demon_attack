import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ground atmosphere art (openspec change ground-forces-rework, tasks
/// 6.1/6.2/6.4 CP6; plan/ground-atmosphere.md): the atlas contract, its
/// stepped alpha and seams, the runtime hook in [Atmosphere] and the CP6
/// review sheet. The generator's own determinism lives in
/// tools/ground_atmosphere (go test).

const _review = String.fromEnvironment(
  'GROUND_ATMOSPHERE_REVIEW_DIR',
  defaultValue: '.cache/ground-atmosphere-review',
);

/// Set to art/contact/ground-atmosphere-contact.png to refresh the CP6 sheet.
const _contact = String.fromEnvironment('GROUND_ATMOSPHERE_CONTACT');

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

typedef _Px = ({Uint8List rgba, int width, int height});

Future<_Px> _pixels(ui.Image img) async {
  final b = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  return (rgba: b.buffer.asUint8List(), width: img.width, height: img.height);
}

int _alpha(_Px p, int x, int y) => p.rgba[(y * p.width + x) * 4 + 3];

const _bands = ['horizonFog', 'lowCloud', 'midMistA', 'midMistB', 'dustVeil'];
const _bandMax = {
  'horizonFog': .8,
  'lowCloud': .8,
  'midMistA': .6,
  'midMistB': .6,
  'dustVeil': .4,
};

Future<_Px> _render(void Function(ui.Canvas c) draw, {int w = 360, int h = 520}) async {
  final r = ui.PictureRecorder();
  draw(ui.Canvas(r));
  final pic = r.endRecording();
  final img = await pic.toImage(w, h);
  final px = await _pixels(img);
  img.dispose();
  pic.dispose();
  return px;
}

int _covered(_Px p, {int x0 = 0, int x1 = 360, int y0 = 0, int y1 = 520}) {
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      if (_alpha(p, x, y) > 0) n++;
    }
  }
  return n;
}

double _luma(int argb) =>
    (.2126 * ((argb >> 16) & 255) + .7152 * ((argb >> 8) & 255) + .0722 * (argb & 255)) / 255;

double _chroma(int argb) {
  final c = [(argb >> 16) & 255, (argb >> 8) & 255, argb & 255];
  return (c.reduce((a, b) => a > b ? a : b) - c.reduce((a, b) => a < b ? a : b)) / 255;
}

void main() {
  late ui.Image atlas;
  late _Px px;

  setUpAll(() async {
    atlas = await _decode('assets/images/${GroundAtmosphereAtlas.file}');
    px = await _pixels(atlas);
  });

  group('atlas', () {
    test('has the interface-note size and every slot for every sector', () {
      expect(atlas.width, GroundAtmosphereAtlas.width);
      expect(atlas.height, GroundAtmosphereAtlas.height);
      expect(GroundAtmosphereAtlas.sectors.length, 5);
      final bounds = Rect.fromLTWH(0, 0, atlas.width * 1.0, atlas.height * 1.0);
      for (var s = 0; s < 5; s++) {
        for (final id in _bands) {
          final r = GroundAtmosphereArt.bandRect(id, s);
          expect(r.width, 512, reason: id);
          expect(bounds.contains(r.topLeft) && bounds.contains(r.bottomRight - const Offset(1, 1)),
              isTrue, reason: '$id/$s outside the atlas');
          final n = _covered(px,
              x0: r.left.toInt(), x1: r.right.toInt(), y0: r.top.toInt(), y1: r.bottom.toInt());
          expect(n, greaterThan(r.width * r.height * .05), reason: '$id/$s is (nearly) empty');
        }
      }
      for (final (frames, rect) in [
        (GroundAtmosphereAtlas.cloudShadowFrames, GroundAtmosphereAtlas.cloudShadow),
        (GroundAtmosphereAtlas.smokeDriftFrames, GroundAtmosphereAtlas.smokeDrift),
        (GroundAtmosphereAtlas.smokeWallFrames, GroundAtmosphereAtlas.smokeWall),
      ]) {
        for (var f = 0; f < frames; f++) {
          final r = rect(f);
          expect(bounds.contains(r.bottomRight - const Offset(1, 1)), isTrue);
          expect(_covered(px, x0: r.left.toInt(), x1: r.right.toInt(),
              y0: r.top.toInt(), y1: r.bottom.toInt()), greaterThan(0), reason: '$r empty');
        }
      }
      // Sizes from the interface note.
      expect(GroundAtmosphereAtlas.horizonFog(0).height, 48);
      expect(GroundAtmosphereAtlas.lowCloud(0).height, 40);
      expect(GroundAtmosphereAtlas.midMistA(0).height, 24);
      expect(GroundAtmosphereAtlas.midMistB(0).height, 24);
      expect(GroundAtmosphereAtlas.dustVeil(0).height, 16);
      expect(GroundAtmosphereAtlas.cloudShadow(3).size, const Size(128, 40));
      expect(GroundAtmosphereAtlas.smokeDrift(5).size, const Size(48, 32));
      expect(GroundAtmosphereAtlas.smokeWall(2).size, const Size(96, 40));
      expect(GroundAtmosphereAtlas.height, 872);
      // Every layer the runtime places is in the table.
      expect({for (final l in GroundAtmosphereAtlas.layers) l.id},
          {..._bands, 'cloudShadow'});
    });

    test('alpha is stepped: transparent or 0.2/0.4/0.6/0.8, capped per band', () {
      const steps = {0, 51, 102, 153, 204};
      for (var y = 0; y < px.height; y++) {
        for (var x = 0; x < px.width; x++) {
          final a = _alpha(px, x, y);
          if (!steps.contains(a)) fail('alpha $a at ($x, $y)');
        }
      }
      for (var s = 0; s < 5; s++) {
        for (final id in _bands) {
          final r = GroundAtmosphereArt.bandRect(id, s);
          var mx = 0;
          for (var y = r.top.toInt(); y < r.bottom; y++) {
            for (var x = 0; x < 512; x++) {
              final a = _alpha(px, x, y);
              if (a > mx) mx = a;
            }
          }
          expect(mx, lessThanOrEqualTo((_bandMax[id]! * 255).round()), reason: '$id/$s');
        }
      }
      expect(GroundAtmosphereAtlas.alphaSteps, [.2, .4, .6, .8]);
    });

    test('tiled bands wrap at 512 with no seam', () {
      for (var s = 0; s < 5; s++) {
        for (final id in _bands) {
          final r = GroundAtmosphereArt.bandRect(id, s);
          int diff(int xa, int xb) {
            var d = 0;
            for (var y = r.top.toInt(); y < r.bottom; y++) {
              d += (_alpha(px, xa, y) - _alpha(px, xb, y)).abs();
            }
            return d;
          }

          var worst = 0;
          for (var x = 0; x < 511; x++) {
            final d = diff(x, x + 1);
            if (d > worst) worst = d;
          }
          expect(diff(511, 0), lessThanOrEqualTo(worst), reason: '$id/$s seam');
        }
      }
    });

    test('mist banks leave at least 40% of the columns clear', () {
      for (var s = 0; s < 5; s++) {
        for (final id in ['midMistA', 'midMistB']) {
          final r = GroundAtmosphereArt.bandRect(id, s);
          var empty = 0;
          for (var x = 0; x < 512; x++) {
            var any = false;
            for (var y = r.top.toInt(); y < r.bottom && !any; y++) {
              any = _alpha(px, x, y) > 0;
            }
            if (!any) empty++;
          }
          expect(empty / 512, greaterThanOrEqualTo(.4), reason: '$id/$s');
        }
      }
    });

    test('sector tints stay in the luma and chroma caps', () {
      for (var s = 0; s < 5; s++) {
        final t = GroundAtmosphereAtlas.fogTint[s];
        expect(_luma(t), inInclusiveRange(.10, .22), reason: 'fog $s');
        expect(_chroma(t), lessThanOrEqualTo(.12), reason: 'fog $s');
        expect(_luma(GroundAtmosphereAtlas.fogLit[s]), lessThanOrEqualTo(.40));
        expect(_luma(GroundAtmosphereAtlas.smokeTint[s]), lessThanOrEqualTo(.40));
      }
      // Every fog pixel is one of its sector's three tints (no stray
      // signal colours), every shared sprite pixel is smoke or shadow ink.
      for (var s = 0; s < 5; s++) {
        final allowed = {
          GroundAtmosphereAtlas.fogTint[s] & 0xFFFFFF,
          GroundAtmosphereAtlas.fogLit[s] & 0xFFFFFF,
          GroundAtmosphereAtlas.fogDark[s] & 0xFFFFFF,
        };
        for (var y = s * GroundAtmosphereAtlas.sectorRows;
            y < (s + 1) * GroundAtmosphereAtlas.sectorRows;
            y++) {
          for (var x = 0; x < 512; x++) {
            final k = (y * px.width + x) * 4;
            if (px.rgba[k + 3] == 0) continue;
            final rgb = px.rgba[k] << 16 | px.rgba[k + 1] << 8 | px.rgba[k + 2];
            // The engine decodes premultiplied: allow its rounding at low alpha.
            bool near(int a) => [16, 8, 0].every(
                (sh) => (((a >> sh) & 255) - ((rgb >> sh) & 255)).abs() <= 4);
            if (!allowed.any(near)) fail('sector $s pixel ($x, $y) #${rgb.toRadixString(16)}');
          }
        }
      }
    });

    test('density curve: clear at z 700, 0.82 in the murk, threats capped', () {
      expect(GroundAtmosphereAtlas.fogMix(600), 0);
      expect(GroundAtmosphereAtlas.fogMix(700), 0);
      expect(GroundAtmosphereAtlas.fogMix(1025), closeTo(.41, .001));
      expect(GroundAtmosphereAtlas.fogMix(1400), closeTo(.82, 1e-9));
      expect(GroundAtmosphereAtlas.fogMix(1400, threat: true), .45);
    });
  });

  group('runtime', () {
    Atmosphere atmo({AtmosphereQuality q = AtmosphereQuality.full}) => Atmosphere()
      ..groundArt = GroundAtmosphereArt(atlas)
      ..quality = q
      ..environment = 2
      ..tide = 1;

    void paintAll(Atmosphere a, ui.Canvas c) {
      for (final (_, l) in a.groundLayers) {
        a.paintGroundLayer(c, l);
      }
      for (final slot in FogSlot.values.where(Atmosphere.artSlots.contains)) {
        a.paint(c, slot);
      }
    }

    test('the art takes the horizon band and far banks; fallback without it', () async {
      final a = atmo();
      final bankA = await _render((c) => a.paint(c, FogSlot.farBankA));
      expect(_covered(bankA), 0, reason: 'bank A is drawn in the ground sort');
      final horizon = await _render((c) => a.paint(c, FogSlot.horizonBand));
      expect(_covered(horizon), greaterThan(0));
      expect(_covered(horizon, y1: 140) + _covered(horizon, y0: 180), 0,
          reason: 'the low cloud deck sits in rows 140-180');
      final plain = Atmosphere()..environment = 2;
      final fallback = await _render((c) => plain.paint(c, FogSlot.farBankA));
      expect(_covered(fallback), greaterThan(1000), reason: 'fBm fallback');
      expect(plain.groundLayers, isEmpty);
    });

    test('ground layers are depth-sorted at the note\'s slots', () {
      final layers = {for (final (z, l) in atmo().groundLayers) l.id: z};
      expect(layers, {
        'horizonFog': 1150,
        'cloudShadow': 1149,
        'midMistA': 1050,
        'midMistB': 850,
        'dustVeil': double.negativeInfinity,
      });
    });

    test('every pixel stays inside the bands; lane cap holds', () async {
      for (final env in [0.0, 2.5, 4.0]) {
        final a = atmo()
          ..environment = env
          ..time = 37
          ..shipX = 40;
        final p = await _render((c) => paintAll(a, c));
        expect(_covered(p, y0: 260), 0, reason: 'nothing below the mid ground');
        var worst = 0;
        for (var y = GroundAtmosphereAtlas.laneTop.toInt(); y < 520; y++) {
          for (var x = 96; x < 264; x++) {
            final v = _alpha(p, x, y);
            if (v > worst) worst = v;
          }
        }
        expect(worst / 255, lessThanOrEqualTo(GroundAtmosphereAtlas.laneCap));
      }
    });

    test('reduced atmosphere keeps the horizon fog and the mist banks', () async {
      final a = atmo(q: AtmosphereQuality.reduced);
      expect({for (final (_, l) in a.groundLayers) l.id},
          {'horizonFog', 'midMistA', 'midMistB'});
      final horizon = await _render((c) => a.paint(c, FogSlot.horizonBand));
      expect(_covered(horizon), 0, reason: 'no low cloud in the reduced tier');
    });

    test('reduced motion stops the drift; parallax still follows the ship', () async {
      Future<Uint8List> frame(Atmosphere a) async => (await _render((c) => paintAll(a, c))).rgba;
      final still = atmo()..reducedMotion = true;
      still.advance(.5, distance: 0, x: 180);
      final f1 = await frame(still);
      still.advance(3, distance: 100, x: 180);
      expect(await frame(still), f1, reason: 'reduced motion: layers stay');
      still.advance(0, distance: 100, x: 60);
      expect(await frame(still), isNot(f1), reason: 'parallax follows the ship');
      final moving = atmo()..advance(.5, distance: 0, x: 180);
      final m1 = await frame(moving);
      moving.advance(3, distance: 100, x: 180);
      expect(await frame(moving), isNot(m1), reason: 'drift');
    });

    test('dust veil rises with the tide', () {
      final a = atmo();
      a.tide = .3;
      expect(a.dustOpacity, 0);
      a.tide = 1;
      expect(a.dustOpacity, 1);
    });

    test('presentation only: the art does not change the simulation', () async {
      String run(bool art) {
        final m = ArcadeModel(seed: 77)..startAt(sector: 3);
        final scene = DemonScene(m, () {});
        if (art) scene.atmosphere.groundArt = GroundAtmosphereArt(atlas);
        for (var f = 0; f < 60 * 30; f++) {
          if (m.combat) m.invulnerable = 2;
          scene.syncAtmosphere(1 / 60);
          m.update(1 / 60);
          if (f % 20 == 0) {
            final r = ui.PictureRecorder();
            scene.paintArena(ui.Canvas(r), Vector2(360, 780));
            r.endRecording().dispose();
          }
        }
        return [
          m.score, m.level, m.wave, m.shipX.toStringAsFixed(3),
          m.ground.units.length,
          for (final u in m.ground.units) '${u.z.toStringAsFixed(3)}:${u.destroyed}',
          m.demons.length,
        ].join('|');
      }

      expect(run(true), run(false));
    });
  });

  testWidgets('CP6 review sheet: every layer per sector, then over each sector', (tester) async {
    await tester.runAsync(() async {
      final paintings = [
        for (var i = 1; i <= 5; i++) await _decode('assets/images/sector-$i.png'),
      ];
      // Section A: per sector, the five bands at x2 over the sector's own
      // horizon (left) and the shared sprites tinted for the sector (right).
      const sheetW = 1860, blockH = 320;
      final frames = <ui.Image>[];
      final plain = <ui.Image>[];
      for (var sector = 1; sector <= 5; sector++) {
        for (final art in [true, false]) {
          final img = await _sectorFrame(sector, art ? atlas : null);
          (art ? frames : plain).add(img);
          final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
          final file = File('$_review/l$sector-${art ? 'art' : 'fallback'}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
        }
      }
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      final sheetH = 5 * blockH + 20 + 780 + 20 + 780;
      c.drawRect(Rect.fromLTWH(0, 0, sheetW * 1.0, sheetH * 1.0),
          Paint()..color = const Color(0xFF101218));
      final nearest = Paint()..filterQuality = FilterQuality.none;
      for (var s = 0; s < 5; s++) {
        final top = s * blockH + 8.0;
        final p = paintings[s];
        // The painting's horizon band, darkened as the flyover bake does.
        c.drawImageRect(
          p,
          Rect.fromLTWH(0, p.height * .5, p.width * 1.0, p.height * .3),
          Rect.fromLTWH(8, top, 1024, blockH - 16.0),
          Paint()
            ..filterQuality = FilterQuality.medium
            ..colorFilter = const ColorFilter.mode(Color(0x80060914), BlendMode.srcATop),
        );
        var y = top + 4;
        for (final id in _bands) {
          final r = GroundAtmosphereArt.bandRect(id, s);
          c.drawImageRect(atlas, r, Rect.fromLTWH(8, y, 1024, r.height * 2), nearest);
          y += r.height * 2 + 4;
        }
        final x0 = 1048.0;
        c.drawRect(Rect.fromLTWH(x0, top, sheetW - x0 - 8, blockH - 16.0),
            Paint()..color = const Color(0xFF5A6070));
        for (var i = 0; i < GroundAtmosphereAtlas.cloudShadowFrames; i++) {
          final r = GroundAtmosphereAtlas.cloudShadow(i);
          c.drawImageRect(atlas, r, Rect.fromLTWH(x0 + 8 + i * 200.0, top + 8, 192, 60),
              Paint()
                ..filterQuality = FilterQuality.none
                ..color = Color.fromRGBO(255, 255, 255, GroundAtmosphereAtlas.layer('cloudShadow').opacity * 3));
        }
        final tint = Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = ColorFilter.mode(
              Color(GroundAtmosphereAtlas.smokeTint[s]).withValues(alpha: .5), BlendMode.srcATop);
        for (var f = 0; f < GroundAtmosphereAtlas.smokeDriftFrames; f++) {
          c.drawImageRect(atlas, GroundAtmosphereAtlas.smokeDrift(f),
              Rect.fromLTWH(x0 + 8 + f * 130.0, top + 84, 96, 64), tint);
        }
        for (var f = 0; f < GroundAtmosphereAtlas.smokeWallFrames; f++) {
          c.drawImageRect(atlas, GroundAtmosphereAtlas.smokeWall(f),
              Rect.fromLTWH(x0 + 8 + f * 260.0, top + 164, 192, 80), tint);
        }
        // Fog tint swatches: lit, tint, dark, smoke.
        for (final (i, col) in [
          GroundAtmosphereAtlas.fogLit[s],
          GroundAtmosphereAtlas.fogTint[s],
          GroundAtmosphereAtlas.fogDark[s],
          GroundAtmosphereAtlas.smokeTint[s],
        ].indexed) {
          c.drawRect(Rect.fromLTWH(x0 + 8 + i * 48.0, top + 256, 40, 40), Paint()..color = Color(col));
        }
      }
      // Section B: each sector at 360 x 780 with units at z 1400/1100/850/600;
      // section C: the same frames on the fBm fallback, for comparison.
      for (final (row, list) in [(0, frames), (1, plain)]) {
        for (var s = 0; s < 5; s++) {
          c.drawImage(list[s], Offset(12 + s * 370.0, 5 * blockH + 20.0 + row * 800), Paint());
        }
      }
      final pic = rec.endRecording();
      final sheet = await pic.toImage(sheetW, sheetH);
      final bytes = (await sheet.toByteData(format: ui.ImageByteFormat.png))!;
      final out = File(_contact.isNotEmpty ? _contact : '$_review/ground-atmosphere-contact.png');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes.buffer.asUint8List());
    });
  });
}

/// One sector in play at 360 x 780 with ground units at the CP6 depths.
Future<ui.Image> _sectorFrame(int sector, ui.Image? art) async {
  final m = ArcadeModel(seed: 1982)..startAt(sector: sector);
  final scene = DemonScene(m, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode('assets/images/sector-${i + 1}.png');
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.groundForces
    ..image = await _decode('assets/images/${GroundAtlas.file}')
    ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}')
    ..blocks.install(sector - 1, {
      for (final f in GroundBlocksLayer.files(sector - 1))
        f.substring('ground-blocks/'.length): await _decode('assets/images/$f'),
    });
  await scene.atmosphere.load(shader: false);
  if (art != null) scene.atmosphere.groundArt = GroundAtmosphereArt(art);
  scene.environment = sector - 1.0;
  for (var f = 0; f < 60 * 14; f++) {
    if (m.combat) m.invulnerable = 2;
    scene.sectors.advance(1 / 60, m, scene.environment);
    scene.syncAtmosphere(1 / 60);
    m.update(1 / 60);
  }
  // The CP6 cast: a pair of demon vehicles (one each side) at each depth,
  // squads at 850; the convoy's allies stay where the run put them.
  m.ground.units
    ..clear()
    ..addAll([
      for (final (i, z) in [1400.0, 1100.0, 850.0, 600.0].indexed)
        for (final side in [0, 1])
          GroundUnit(100 + i * 2 + side, sector, side, .25 + .5 * ((i + side) % 2), z)
            ..force = i == 2 && side == 1 ? GroundForce.infantry : GroundForce.vehicle,
    ]);
  scene.atmosphere.tide = .9;
  final r = ui.PictureRecorder();
  final c = ui.Canvas(r);
  c.drawRect(const Rect.fromLTWH(0, 0, 360, 780), Paint()..color = const Color(0xFF000000));
  scene.paintArena(c, Vector2(360, 780));
  final pic = r.endRecording();
  final img = await pic.toImage(360, 780);
  pic.dispose();
  return img;
}
