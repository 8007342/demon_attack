import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Atmosphere-and-swarms review frames (openspec/changes/atmosphere-and-
/// swarms): a wave holding in the fog, a flock mid-arrival, the settled
/// formation, the sentinel's silhouette two and one waves ahead, and the
/// reduced tier, at phone portrait under .cache/atmosphere-review/ (or
/// ATMOSPHERE_REVIEW_DIR). Set ATMOSPHERE_REVIEW_SHADER=0 to force tiles.
final _outDir =
    Platform.environment['ATMOSPHERE_REVIEW_DIR'] ??
    '.cache/atmosphere-review';
final _shader = Platform.environment['ATMOSPHERE_REVIEW_SHADER'] != '0';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> _capture(DemonScene scene, String name, {bool x3 = false}) async {
  final ratio = x3 ? 3.0 : 1.0;
  const w = 360.0, h = 780.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(ratio);
  scene.paintArena(canvas, Vector2(w, h));
  final picture = recorder.endRecording();
  final image = await picture.toImage((w * ratio).round(), (h * ratio).round());
  final file = File('$_outDir/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
  picture.dispose();
}

void _run(ArcadeModel model, DemonScene scene, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    model.invulnerable = 5;
    model.update(1 / 60);
    scene.creatures.update(model, 1 / 60);
    scene.sectors.flyover.distance += 26 / 60;
    scene.syncAtmosphere(1 / 60);
    model.takeEvents();
    model.shots.removeWhere((s) => !s.hostile);
  }
}

Future<DemonScene> _scene(ArcadeModel model, int sector) async {
  final scene = DemonScene(model, () {});
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.png');
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(
      'assets/images/sector-${i + 1}.png',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = true;
  await scene.atmosphere.load(shader: _shader);
  scene.environment = sector - 1.0;
  return scene;
}

void main() {
  testWidgets('atmosphere review frames', (tester) async {
    await tester.runAsync(() async {
      // 1. A wave arriving as a flock, then settled.
      final model = ArcadeModel(seed: 1982)..startAt(sector: 2, wave: 2);
      final scene = await _scene(model, 2);
      // ignore: avoid_print
      print('fog shader: ${scene.atmosphere.usesShader}');
      _run(model, scene, .25);
      await _capture(scene, '1-arrival-early');
      _run(model, scene, .3);
      await _capture(scene, '2-arrival-mid', x3: true);
      final shaderOn = scene.atmosphere.shaderEnabled;
      scene.atmosphere.shaderEnabled = false;
      await _capture(scene, '2b-arrival-mid-tiles', x3: true);
      scene.atmosphere.shaderEnabled = shaderOn;
      _run(model, scene, 3);
      await _capture(scene, '3-settled');

      // 2. Wave pressure: thin the wave so the next one holds in the fog.
      model.flocksSpawned = model.flocksPlanned;
      while (model.demons.length > 2) {
        model.demons.removeLast();
      }
      _run(model, scene, 2.5);
      expect(model.incoming, isNotEmpty);
      await _capture(scene, '4-holding-in-fog', x3: true);
      scene.atmosphere.shaderEnabled = false;
      await _capture(scene, '4b-holding-in-fog-tiles');
      scene.atmosphere.shaderEnabled = shaderOn;
      _run(model, scene, 3);
      await _capture(scene, '5-holding-later');

      // 3. Sentinel foreshadowing on a later route.
      final route = ArcadeModel(seed: 7);
      route.startAt(sector: 2, route: 1);
      int? sentinelWave;
      for (var w = 1; w <= route.wavesPerLevel; w++) {
        if (route.sentinelFor(w) != null) sentinelWave ??= w;
      }
      expect(sentinelWave, isNotNull);
      final first = (sentinelWave! - 2).clamp(1, 99);
      final m2 = ArcadeModel(seed: 7)
        ..startAt(sector: 2, route: 1, wave: first);
      final s2 = await _scene(m2, 2);
      _run(m2, s2, 4);
      expect(m2.foreshadow, isNotNull);
      await _capture(s2, '6-foreshadow-early', x3: true);
      final m3 = ArcadeModel(seed: 7)
        ..startAt(sector: 2, route: 1, wave: sentinelWave - 1);
      final s3 = await _scene(m3, 2);
      _run(m3, s3, 6);
      await _capture(s3, '7-foreshadow-near', x3: true);
      final m4 = ArcadeModel(seed: 7)
        ..startAt(sector: 2, route: 1, wave: sentinelWave);
      final s4 = await _scene(m4, 2);
      _run(m4, s4, 3.4);
      await _capture(s4, '8-sentinel-escort');
      _run(m4, s4, 1.1);
      await _capture(s4, '9-sentinel-arriving');

      // 4. Reduced atmosphere: horizon band and ground fog only.
      scene.atmosphere.quality = AtmosphereQuality.reduced;
      await _capture(scene, '10-reduced');
    });
  });
}
