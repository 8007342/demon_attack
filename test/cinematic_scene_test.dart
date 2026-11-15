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
  final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
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

/// Share of pixels that change by more than 48 levels in any channel.
double changed(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if ((a[i] - b[i]).abs() > 48 ||
        (a[i + 1] - b[i + 1]).abs() > 48 ||
        (a[i + 2] - b[i + 2]).abs() > 48) {
      n++;
    }
  }
  return n / (a.length / 4);
}

void main() {
  // cinematic-flow: the cutscene is one clock (lib/game/flow_director.dart).
  // Frames animate, pause keeps the exact frame, and the phase handoffs are
  // continuous: no black fade hides a camera cut any more.
  testWidgets(
    'cutscene frames animate and pause retains exact rendered composition',
    (tester) async {
      final model = ArcadeModel(seed: 3)..start();
      for (var i = 0; i < 600 && model.mode != RunMode.playing; i++) {
        model.update(1 / 60);
      }
      model.endSector();
      final scene = DemonScene(model, () {});
      void step() {
        scene.advancePresentation(1 / 60);
        model.update(1 / 60);
      }

      void until(RunMode mode) {
        for (var i = 0; i < 900 && model.mode != mode; i++) {
          step();
        }
        expect(model.mode, mode);
      }

      await tester.runAsync(() async {
        scene.atlas = await decode('assets/images/combat.png');
        scene.sky = await decode('assets/images/cosmic-sky.png');
        await scene.atmosphere.load();
        until(RunMode.levelClear);
        final early = await capture(
          scene,
          output: '.cache/cinematics/demon-clear-early.png',
        );
        for (var i = 0; i < 70; i++) {
          step();
        }
        final late = await capture(
          scene,
          output: '.cache/cinematics/demon-clear-late.png',
        );
        expect(early, isNot(orderedEquals(late)));
        // The last frame of level clear and the first of travel.
        for (var i = 0; i < 900 && model.transitionLeft > .05; i++) {
          step();
        }
        var departureEnd = await capture(scene);
        while (model.mode == RunMode.levelClear) {
          departureEnd = await capture(scene);
          step();
        }
        expect(model.mode, RunMode.travel);
        final travelStart = await capture(scene);
        expect(
          changed(departureEnd, travelStart),
          lessThan(.05),
          reason: 'level clear flows into travel without a cut',
        );
        for (var i = 0; i < 100; i++) {
          step();
        }
        final travel = await capture(
          scene,
          output: '.cache/cinematics/demon-travel-mid.png',
        );
        model.pause();
        scene.update(.1);
        final paused = await capture(scene);
        expect(paused, orderedEquals(travel));
        model.resume();
        // Travel into the next sector's arrival happens inside the cloud.
        for (var i = 0; i < 900 && model.transitionLeft > .05; i++) {
          step();
        }
        var travelEnd = await capture(scene);
        while (model.mode == RunMode.travel) {
          travelEnd = await capture(scene);
          step();
        }
        expect(model.mode, RunMode.transition);
        expect(model.level, 2);
        expect(
          changed(travelEnd, await capture(scene)),
          lessThan(.05),
          reason: 'travel flows into the arrival under the cloud',
        );
        for (var i = 0; i < 120; i++) {
          step();
        }
        await capture(scene, output: '.cache/cinematics/demon-arrival.png');
        scene.atlas!.dispose();
        scene.sky!.dispose();
      });
    },
  );
}
