import 'dart:ui' as ui;

import 'package:demon_attack/main.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flame paints visible stars at phone dimensions', (tester) async {
    final sky = QuietSky();
    sky.onGameResize(Vector2(390, 844));
    await sky.onLoad();
    final recorder = ui.PictureRecorder();
    sky.render(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    final pixels = await tester.runAsync(() async {
      final image = await picture.toImage(390, 844);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!;
    });
    picture.dispose();
    var visiblePixels = 0;
    for (var offset = 0; offset < pixels!.lengthInBytes; offset += 4) {
      // Count bright opaque star pixels, excluding the dark sky and glow.
      if (pixels.getUint8(offset) >= 70 &&
          pixels.getUint8(offset + 1) >= 85 &&
          pixels.getUint8(offset + 3) >= 200) {
        visiblePixels++;
      }
    }
    expect(visiblePixels, greaterThan(150));
  });
}
