import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'scene has a moving visible starfield before images finish loading',
    (tester) async {
      final scene = DemonScene(ArcadeModel(), () {});
      scene.onGameResize(Vector2(360, 520));
      Future<ByteData> pixels() async {
        final recorder = ui.PictureRecorder();
        scene.render(ui.Canvas(recorder));
        final picture = recorder.endRecording();
        final result = await tester.runAsync(() async {
          final image = await picture.toImage(360, 520);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          return data!;
        });
        picture.dispose();
        return result!;
      }

      final first = await pixels();
      var visibleStars = 0;
      // Exclude the planet and horizon; bright tiny pixels here are stars.
      for (var y = 0; y < 380; y++) {
        for (var x = 0; x < 180; x++) {
          final offset = (y * 360 + x) * 4;
          if (first.getUint8(offset) > 60 &&
              first.getUint8(offset + 1) > 90 &&
              first.getUint8(offset + 3) > 200) {
            visibleStars++;
          }
        }
      }
      expect(visibleStars, greaterThan(20));
      scene.update(2);
      final later = await pixels();
      var changed = 0;
      for (var offset = 0; offset < first.lengthInBytes; offset += 4) {
        if (first.getUint32(offset) != later.getUint32(offset)) changed++;
      }
      expect(changed, greaterThan(100));
    },
  );
}
