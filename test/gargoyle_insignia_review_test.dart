@Tags(['review'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/insignia_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// gargoyle-insignia review frames (openspec/changes/gargoyle-insignia,
/// design §5): one dense phone formation in the real scene with the real
/// atlases, painted twice:
///
/// - `dense-new-*.png`: with the shipped insignia atlas;
/// - `dense-bare-*.png` plus `dense-marks.json`: without the overlay, and
///   every mark the painter placed (key, arena rect; shield cells too), so
///   tools/alien_insignia can seat the retired alien-insignia glyphs at the
///   same anchors for the old-against-new sheet (`go run . gargoyle`).
///
/// Each at phone 360 × 780 (1:1) and as a 2x close-up of the arena band
/// [40, 240). Frames go to `$GARGOYLE_INSIGNIA_DIR` (default
/// .cache/gargoyle-insignia-review).
const _dir = String.fromEnvironment(
  'GARGOYLE_INSIGNIA_DIR',
  defaultValue: '.cache/gargoyle-insignia-review',
);

/// The phone frame's arena offset: 360 × 520 at scale 1, centred in 780.
const _arenaTop = 130.0;
const _bandTop = 40.0;

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel m) async {
  final scene = DemonScene(m, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(
      'assets/images/sector-${i + 1}.webp',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.webp');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  await scene.atmosphere.load();
  scene.environment = 1;
  return scene;
}

Demon _flier(
  double x,
  double y,
  int kind,
  int maxHp, {
  int? hp,
  bool elite = false,
  double seed = 0,
}) {
  final d = Demon(x, y, kind, maxHp, seed, elite: elite);
  if (hp != null) d.hp = hp;
  return d;
}

Future<void> _png(ui.Image image, String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
}

/// The phone frame and the 2x close-up of the band.
Future<void> _shots(DemonScene scene, String name) async {
  final r = ui.PictureRecorder();
  final c = ui.Canvas(r);
  c.drawRect(
    const Rect.fromLTWH(0, 0, 360, 780),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(c, Vector2(360, 780));
  final p = r.endRecording();
  final phone = await p.toImage(360, 780);
  p.dispose();
  final zr = ui.PictureRecorder();
  final zc = ui.Canvas(zr)
    ..scale(2)
    ..translate(0, -(_arenaTop + _bandTop));
  scene.paintArena(zc, Vector2(360, 780));
  final zp = zr.endRecording();
  final zoom = await zp.toImage(720, 400);
  zp.dispose();
  await _png(phone, '$_dir/dense-$name-360x780.png');
  await _png(zoom, '$_dir/dense-$name-zoom.png');
  phone.dispose();
  zoom.dispose();
}

void main() {
  testWidgets('gargoyle-insignia dense formation', (tester) async {
    await tester.runAsync(() async {
      final m = ArcadeModel(seed: 11)..startAt(sector: 2, route: 1);
      m
        ..mode = RunMode.playing
        ..invulnerable = 0
        ..clock = 3;
      m.demons.clear();
      m.incoming.clear();
      m.shots.clear();
      final scene = await _scene(m);
      // A mid-wave swarm, about 40 units apart: every rank, two angry, one
      // in its dive tell, an armoured sentinel, and two packed pairs where
      // the lower-rank glyph yields.
      m.demons.addAll([
        _flier(40, 120, 0, 1, seed: 1), // drone
        _flier(85, 112, 2, 2, seed: 2), // skirmisher
        _flier(130, 124, 1, 4, seed: 3), // veteran
        _flier(230, 124, 3, 3, seed: 4), // skirmisher
        _flier(275, 112, 0, 3, elite: true, seed: 5), // hunter
        _flier(320, 120, 1, 2, seed: 6), // drone
        _flier(50, 170, 3, 5, seed: 7), // veteran
        _flier(95, 178, 0, 2, seed: 8), // drone
        _flier(140, 168, 2, 3, hp: 1, seed: 9), // skirmisher, angry
        _flier(185, 176, 3, 4, elite: true, seed: 10), // hunter
        _flier(230, 168, 1, 3, seed: 11), // skirmisher
        _flier(275, 176, 2, 5, hp: 1, seed: 12), // veteran, angry
        _flier(320, 168, 0, 3, seed: 13)..telegraph = .5, // skirmisher, tell
        _flier(70, 222, 1, 4, elite: true, seed: 14), // hunter
        _flier(118, 226, 0, 1, seed: 15), // drone
        _flier(162, 220, 2, 4, seed: 16), // veteran
        // Packed pairs: the lower rank yields.
        _flier(250, 224, 3, 5, seed: 17), // veteran
        _flier(258, 214, 2, 2, seed: 18), // skirmisher (yields)
        _flier(310, 226, 1, 3, elite: true, seed: 19), // hunter
        _flier(316, 216, 0, 4, seed: 20), // veteran (yields)
        Demon(
          185,
          70,
          1,
          12,
          0,
          archetype: EnemyArchetype.armoredSentinel,
          shieldMax: 4,
          armorMax: 4,
        ),
      ]);
      for (var t = 0.0; t < .2 - 1e-9; t += 1 / 60) {
        for (final d in m.demons) {
          d.nearness = 1;
        }
        scene.creatures.update(m, 1 / 60);
      }

      // With the shipped glyphs.
      scene.insignia.image = await _decode(
        'assets/images/${InsigniaAtlas.file}',
      );
      await _shots(scene, 'new');
      final marks = [
        for (final k in scene.insignia.lastMarks)
          {
            'key': k.key,
            'rank': k.rank?.name ?? 'cell',
            'l': k.rect.left,
            't': k.rect.top,
            'w': k.rect.width,
            'h': k.rect.height,
            'a': k.alpha,
          },
      ];
      expect(marks, isNotEmpty);

      // Without glyphs, and where they were placed.
      scene.insignia.image = null;
      await _shots(scene, 'bare');
      await File('$_dir/dense-marks.json').writeAsString(
        const JsonEncoder.withIndent(' ').convert({
          'arenaTop': _arenaTop,
          'bandTop': _bandTop,
          'unitsPerGlyphPx': 1.35,
          'marks': marks,
        }),
      );
    });
  });
}
