import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Uint8List> capture(DemonScene scene, {String? output}) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520));
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final pixels = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  if (output != null) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  }
  image.dispose();
  picture.dispose();
  return pixels;
}

void main() {
  testWidgets(
    'cutscene frames animate and pause retains exact rendered composition',
    (tester) async {
      final model = ArcadeModel()..start();
      model.demons.clear();
      model.mode = RunMode.levelClear;
      model.transitionDuration = 4;
      model.transitionLeft = 3.4;
      final scene = DemonScene(model, () {});
      await tester.runAsync(() async {
        scene.atlas = await decode('assets/images/combat.png');
        scene.sky = await decode('assets/images/cosmic-sky.png');
        final early = await capture(
          scene,
          output: '.cache/cinematics/demon-clear-early.png',
        );
        model.transitionLeft = 1.4;
        final late = await capture(
          scene,
          output: '.cache/cinematics/demon-clear-late.png',
        );
        expect(early, isNot(orderedEquals(late)));
        model.mode = RunMode.travel;
        model.transitionLeft = 1.8;
        final travel = await capture(
          scene,
          output: '.cache/cinematics/demon-travel-mid.png',
        );
        expect(travel, isNot(orderedEquals(late)));
        model.pause();
        scene.update(.1);
        final paused = await capture(scene);
        expect(paused, orderedEquals(travel));
        model.resume();
        model.mode = RunMode.levelClear;
        model.transitionLeft = 0;
        final departureEnd = await capture(scene);
        model.mode = RunMode.travel;
        model.transitionDuration = 4;
        model.transitionLeft = 4;
        final travelStart = await capture(scene);
        expect(
          travelStart,
          orderedEquals(departureEnd),
          reason: 'The black fade must hide the camera handoff',
        );
        model.transitionLeft = 0;
        final travelEnd = await capture(scene);
        model.mode = RunMode.transition;
        model.transitionDuration = 2.3;
        model.transitionLeft = 2.3;
        expect(
          await capture(scene),
          orderedEquals(travelEnd),
          reason: 'Travel fades continuously into arrival',
        );
        model.transitionLeft = 1.1;
        await capture(scene, output: '.cache/cinematics/demon-arrival.png');
        scene.atlas!.dispose();
        scene.sky!.dispose();
      });
    },
  );
}
