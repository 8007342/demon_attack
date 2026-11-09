import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Timing harness for the background: Dart-side recording cost per frame and
/// CPU (Skia raster) cost of one phone-sized frame (3x the 360x520 arena).
/// Prints numbers; asserts only a generous ceiling so a pathological
/// regression fails CI.
void main() {
  testWidgets('flyover background frame cost', (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      final scene = DemonScene(model, () {});
      for (var i = 0; i < 5; i++) {
        scene.sectors.images[i] =
            await _decode('assets/images/sector-${i + 1}.png');
      }
      await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
      scene.sectors.flyover.reducedMotionOverride = false;
      final size = Vector2(1080, 1560);
      Future<(double, double)> run(double environment) async {
        scene.environment = environment;
        for (var i = 0; i < 30; i++) {
          scene.sectors.advance(1 / 60, model, environment);
          final r = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(r), size, combat: false);
          r.endRecording().dispose();
        }
        final record = Stopwatch()..start();
        for (var i = 0; i < 300; i++) {
          scene.sectors.advance(1 / 60, model, environment);
          final r = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(r), size, combat: false);
          r.endRecording().dispose();
        }
        final recordUs = record.elapsedMicroseconds / 300;
        final r = ui.PictureRecorder();
        scene.paintArena(ui.Canvas(r), size, combat: false);
        final pic = r.endRecording();
        (await pic.toImage(1080, 1560)).dispose();
        final raster = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          (await pic.toImage(1080, 1560)).dispose();
        }
        pic.dispose();
        return (recordUs, raster.elapsedMicroseconds / 20);
      }

      final steady = await run(2);
      final travel = await run(2.5);
      // ignore: avoid_print
      print('flyover steady: record ${steady.$1.round()} us, '
          'raster ${steady.$2.round()} us; crossfade: record '
          '${travel.$1.round()} us, raster ${travel.$2.round()} us');
      expect(steady.$2, lessThan(200000));
    });
  });
}
