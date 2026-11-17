// terrain-shadows task 4.1: the shadow pass keeps its budgets (at most
// three blur layers, at most four draw calls per layer) and the reduced
// tier stays byte-identical to the flat pass from before the change.
//
// The fixture test/fixtures/shadow-flat-reduced.png was rendered by the
// pre-change shadow pass. If the creature atlas itself changes, regenerate
// it on a revision whose flat path is known good:
//   flutter test --dart-define=UPDATE_SHADOW_FIXTURE=true \
//     test/terrain_shadows_scene_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/shadow_projector.dart';
import 'package:flutter_test/flutter_test.dart';

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
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.environment = 2;
  return scene;
}

void _run(ArcadeModel m, DemonScene scene, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    m.invulnerable = 5;
    m.update(1 / 60);
    scene.creatures.update(m, 1 / 60);
    scene.sectors.flyover.advance(1 / 60, m, scene.environment);
    m.shots.removeWhere((s) => !s.hostile);
  }
}

Future<Uint8List> _shadowPass(DemonScene scene) async {
  final rec = ui.PictureRecorder();
  scene.paintShadowPass(ui.Canvas(rec));
  final pic = rec.endRecording();
  final img = await pic.toImage(360, 560);
  pic.dispose();
  final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  testWidgets('reduced tier: the flat shadow pass is byte-identical', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = ArcadeModel(seed: 4)
        ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
      final scene = await _scene(m);
      _run(m, scene, 6);
      m.foreshadow = null; // a legacy frame: no lurking shadow, no boss
      scene.atmosphere.quality = AtmosphereQuality.reduced;
      final raw = await _shadowPass(scene);
      expect(scene.shadowLayers, 1);
      expect(scene.shadowCount, greaterThan(10));
      const path = 'test/fixtures/shadow-flat-reduced.png';
      if (const bool.fromEnvironment('UPDATE_SHADOW_FIXTURE')) {
        final img = await ui.ImmutableBuffer.fromUint8List(raw);
        final desc = ui.ImageDescriptor.raw(
          img,
          width: 360,
          height: 560,
          pixelFormat: ui.PixelFormat.rgba8888,
        );
        final codec = await desc.instantiateCodec();
        final frame = await codec.getNextFrame();
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        File(path).writeAsBytesSync(png!.buffer.asUint8List());
        return;
      }
      final fixture = await _decode(path);
      final want = (await fixture.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var diff = 0;
      for (var i = 0; i < raw.length; i++) {
        if (raw[i] != want[i]) diff++;
      }
      expect(diff, 0, reason: 'reduced-tier shadow pass changed');
    });
  });
  testWidgets('draped: <= 3 layers, <= 4 draw calls per layer, same casters', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = ArcadeModel(seed: 4)
        ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
      final scene = await _scene(m);
      var differs = 0;
      for (var i = 0; i < 12; i++) {
        _run(m, scene, .5);
        scene.shadowModeOverride = ShadowMode.flat;
        final flat = await _shadowPass(scene);
        final flatCount = scene.shadowCount;
        scene.shadowModeOverride = null;
        final draped = await _shadowPass(scene);
        expect(scene.shadowMode, ShadowMode.draped);
        expect(scene.shadowLayers, lessThanOrEqualTo(3));
        expect(scene.shadowDrawCallsPerBucket, lessThanOrEqualTo(4));
        expect(scene.shadowCount, flatCount);
        var d = 0;
        for (var k = 0; k < flat.length; k += 4) {
          if (flat[k + 3] != draped[k + 3]) d++;
        }
        if (d > 50) differs++;
      }
      // The relief moves shadows off the flat plane on most frames.
      expect(differs, greaterThan(3));
    });
  });
}
