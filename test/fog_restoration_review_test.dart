@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fog-restoration review frames (openspec/changes/fog-restoration): per
/// sector, in phone portrait with every in-game atlas loaded (ground
/// atmosphere art, silhouette sheet, ground blocks), (a) the next wave
/// holding in the fog while the sentinel's silhouette circles behind it and
/// (b) the sentinel flying in through the layers. Frames go to
/// `$FOG_REVIEW_DIR/$FOG_REVIEW_TAG/` (default .cache/fog-restoration-review
/// and `after`). When both `before/` and `after/` exist the contact sheet is
/// written to `$FOG_CONTACT` (default art/contact/fog-restoration.png):
/// rows are sectors, columns before/after of (a), then before/after of (b).
const _dir = String.fromEnvironment(
  'FOG_REVIEW_DIR',
  defaultValue: '.cache/fog-restoration-review',
);
const _tag = String.fromEnvironment('FOG_REVIEW_TAG', defaultValue: 'after');
const _contact = String.fromEnvironment(
  'FOG_CONTACT',
  defaultValue: 'art/contact/fog-restoration.png',
);
const _sectors = [2, 3, 4];
const _shots = ['foreshadow-incoming', 'sentinel-arriving'];

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel m, int sector) async {
  final scene = DemonScene(m, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(
      'assets/images/sector-${i + 1}.png',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.png');
  scene.silhouetteAtlas = await _decode(
    'assets/images/${SentinelSilhouetteAtlas.file}',
  );
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.groundForces
    ..image = await _decode('assets/images/${GroundAtlas.file}')
    ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}')
    ..blocks.install(sector - 1, {
      for (final f in GroundBlocksLayer.files(sector - 1))
        f.substring('ground-blocks/'.length): await _decode(
          'assets/images/$f',
        ),
    });
  await scene.atmosphere.load();
  scene.atmosphere.groundArt = GroundAtmosphereArt(
    await _decode('assets/images/${GroundAtmosphereAtlas.file}'),
  );
  scene.environment = sector - 1.0;
  return scene;
}

void _run(ArcadeModel m, DemonScene scene, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    m.invulnerable = 5;
    scene.sectors.advance(1 / 60, m, scene.environment);
    m.update(1 / 60);
    scene.creatures.update(m, 1 / 60);
    scene.syncAtmosphere(1 / 60);
    m.takeEvents();
    m.shots.removeWhere((s) => !s.hostile);
  }
}

/// Ground units at the far, mid and near depths, so the frame shows the
/// fog over the ground as well as the air.
void _cast(ArcadeModel m, int sector) {
  m.ground.units
    ..clear()
    ..addAll([
      for (final (i, z) in [1400.0, 1100.0, 850.0, 600.0].indexed)
        for (final side in [0, 1])
          GroundUnit(
            100 + i * 2 + side,
            sector,
            side,
            .25 + .5 * ((i + side) % 2),
            z,
          )..force = GroundForce.vehicle,
    ]);
}

Future<void> _capture(DemonScene scene, String name) async {
  const w = 360.0, h = 780.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(canvas, Vector2(w, h));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.round(), h.round());
  final file = File('$_dir/$_tag/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
  picture.dispose();
  // A 2x close-up of the fog's depth (arena rows 40-340) for inspection.
  final zr = ui.PictureRecorder();
  final zc = ui.Canvas(zr)
    ..scale(2)
    ..translate(0, -170);
  scene.paintArena(zc, Vector2(w, h));
  final zp = zr.endRecording();
  final zi = await zp.toImage(720, 600);
  await File('$_dir/$_tag/zoom-$name.png').writeAsBytes(
    (await zi.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List(),
  );
  zi.dispose();
  zp.dispose();
}

int _sentinelWave(int sector) {
  final m = ArcadeModel(seed: 7)..startAt(sector: sector, route: 1);
  for (var w = 2; w <= m.wavesPerLevel; w++) {
    if (m.sentinelFor(w) != null) return w;
  }
  throw StateError('no sentinel wave in sector $sector');
}

void main() {
  testWidgets('fog restoration review frames', (tester) async {
    await tester.runAsync(() async {
      for (final sector in _sectors) {
        final sw = _sentinelWave(sector);
        // (a) The wave before the sentinel's, thinned so the next wave holds
        // in the fog while the silhouette circles behind it.
        final m = ArcadeModel(seed: 7)
          ..startAt(sector: sector, route: 1, wave: sw - 1);
        final scene = await _scene(m, sector);
        _run(m, scene, 4);
        m.flocksSpawned = m.flocksPlanned;
        while (m.demons.length > 2) {
          m.demons.removeLast();
        }
        _run(m, scene, 3.2);
        _cast(m, sector);
        m.shipX = m.targetX = 130;
        _run(m, scene, 1 / 60);
        expect(m.incoming, isNotEmpty, reason: 'sector $sector');
        expect(m.foreshadow?.visible, isTrue, reason: 'sector $sector');
        await _capture(scene, 's$sector-${_shots[0]}');
        // The same frame on the tile path (shader throttled) and in the
        // reduced tier, for inspection (not on the sheet).
        scene.atmosphere.shaderEnabled = false;
        await _capture(scene, 's$sector-tiles');
        scene.atmosphere.quality = AtmosphereQuality.reduced;
        await _capture(scene, 's$sector-reduced');
        scene.atmosphere
          ..quality = AtmosphereQuality.full
          ..shaderEnabled = true;

        // (b) The sentinel's wave: it sets out from its silhouette and comes
        // in through the layers.
        final m2 = ArcadeModel(seed: 7)
          ..startAt(sector: sector, route: 1, wave: sw);
        final s2 = await _scene(m2, sector);
        _run(m2, s2, 3);
        for (var i = 0; i < 80; i++) {
          final s = m2.demons.where((d) => d.isLarge).firstOrNull;
          if (s != null && s.entranceProgress > .3) break;
          _run(m2, s2, .1);
        }
        _cast(m2, sector);
        m2.shipX = m2.targetX = 230;
        _run(m2, s2, 1 / 60);
        await _capture(s2, 's$sector-${_shots[1]}');
      }

      // Contact sheet when both sides exist.
      final before = Directory('$_dir/before'), after = Directory('$_dir/after');
      if (!before.existsSync() || !after.existsSync()) return;
      const cw = 360.0, ch = 780.0, gap = 12.0, head = 10.0;
      final cols = _shots.length * 2;
      final sheetW = gap + cols * (cw + gap);
      final sheetH = gap + _sectors.length * (ch + head + gap);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, sheetW, sheetH),
        Paint()..color = const Color(0xFF101218),
      );
      for (final (row, sector) in _sectors.indexed) {
        for (final (k, shot) in _shots.indexed) {
          for (final (j, side) in ['before', 'after'].indexed) {
            final f = File('$_dir/$side/s$sector-$shot.png');
            if (!f.existsSync()) continue;
            final img = await _decode(f.path);
            final x = gap + (k * 2 + j) * (cw + gap);
            final y = gap + row * (ch + head + gap);
            // Header bar: red = before, green = after.
            c.drawRect(
              Rect.fromLTWH(x, y, cw, head - 3),
              Paint()
                ..color = side == 'before'
                    ? const Color(0xFFB0413E)
                    : const Color(0xFF3FA36B),
            );
            c.drawImage(img, Offset(x, y + head), Paint());
          }
        }
      }
      final pic = rec.endRecording();
      final sheet = await pic.toImage(sheetW.round(), sheetH.round());
      final out = File(_contact);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(
        (await sheet.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
    });
  });
}
