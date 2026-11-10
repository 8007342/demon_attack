import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ground war v4 review frames from live simulation: every sector at a phone
/// portrait size (360x780) and a wide size (1280x720), PNGs in
/// GROUND_V4_REVIEW_DIR (default .cache/ground-v4-review). Also measures the
/// Dart-side recording cost of a combat frame with a busy ground war.
const _out = String.fromEnvironment(
  'GROUND_V4_REVIEW_DIR',
  defaultValue: '.cache/ground-v4-review',
);

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel model) async {
  final scene = DemonScene(model, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode('assets/images/sector-${i + 1}.png');
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.groundForces.image = await _decode('assets/images/${GroundAtlas.file}');
  scene.groundForces.troops =
      await _decode('assets/images/${GroundTroopsAtlas.file}');
  return scene;
}

Future<void> _png(DemonScene scene, int w, int h, String name) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  scene.paintArena(canvas, Vector2(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

/// Flies [sector] for [seconds] of combat with a protected pilot.
Future<(ArcadeModel, DemonScene)> _fly(int sector, double seconds) async {
  final m = ArcadeModel(seed: 1982)..startAt(sector: sector);
  final scene = await _scene(m);
  scene.environment = sector - 1.0;
  var next = 0.0;
  for (var f = 0; f < (seconds * 60).round(); f++) {
    if (m.combat) {
      m.invulnerable = 2;
      if (m.levelClock >= next) {
        next = m.levelClock + 2.6;
        final t = m.demons.where((x) => !x.entering).firstOrNull;
        if (t != null) m.hitDemon(t, damage: 99);
      }
      // Wander so the convoy follows the ship across the width.
      m.shipX = m.targetX = 180 + 120 * ((f / 600) % 2 < 1 ? 1 : -1) *
          (((f / 600) % 1) - .5).abs();
    }
    scene.sectors.advance(1 / 60, m, scene.environment);
    m.update(1 / 60);
    // After the warm-up, stop on a busy moment: several skirmishes under
    // way on the near ground, with fire in the air.
    if (f > seconds * 30 &&
        m.ground.tracers.isNotEmpty &&
        m.ground.units.where((u) => u.alive && u.z < 800).length >= 2) {
      break;
    }
  }
  return (m, scene);
}

void main() {
  testWidgets('ground war v4 review frames and frame cost', (tester) async {
    await tester.runAsync(() async {
      final perf = <String>[];
      for (var sector = 1; sector <= 5; sector++) {
        final (m, scene) = await _fly(sector, sector == 5 ? 30 : 38);
        final g = m.ground;
        final live = g.units.where((u) => u.alive).length;
        // ignore: avoid_print
        print('L$sector: live units $live, allies ${g.allies.length}, '
            'tracers ${g.tracers.length}, forces '
            '${g.units.where((u) => u.alive).map((u) => '${u.force.name}@${u.x.round()},${u.y.round()} z${u.z.round()}${u.skirmish ? "s" : ""}').toList()}');
        await _png(scene, 360, 780, 'l$sector-portrait');
        await _png(scene, 1280, 720, 'l$sector-wide');
        // Recording cost of a busy combat frame at phone resolution.
        for (var i = 0; i < 20; i++) {
          final r = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(r), Vector2(1080, 2340));
          r.endRecording().dispose();
        }
        final sw = Stopwatch()..start();
        for (var i = 0; i < 120; i++) {
          scene.sectors.advance(1 / 60, m, scene.environment);
          m.update(1 / 60);
          final r = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(r), Vector2(1080, 2340));
          r.endRecording().dispose();
        }
        final us = sw.elapsedMicroseconds / 120;
        perf.add('L$sector ${us.round()} us');
        expect(us, lessThan(16000), reason: 'record + update well under a frame');
      }
      // ignore: avoid_print
      print('frame record+update cost: ${perf.join(', ')}');
    });
  });
}
