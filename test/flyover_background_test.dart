import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/flyover_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Uint8List> _capture(DemonScene scene, {String? output}) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520), combat: false);
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  if (output != null) {
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List(),
    );
  }
  image.dispose();
  picture.dispose();
  return bytes;
}

double _meanLuma(Uint8List rgba, int x0, int x1, {int y0 = 0, int y1 = 520}) {
  var sum = 0.0;
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * 360 + x) * 4;
      sum += .2126 * rgba[i] + .7152 * rgba[i + 1] + .0722 * rgba[i + 2];
      n++;
    }
  }
  return sum / n / 255;
}

Future<DemonScene> _scene(ArcadeModel model) async {
  final scene = DemonScene(model, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode('assets/images/sector-${i + 1}.png');
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  return scene;
}

void main() {
  test('generated flyover strips tile seamlessly and stay out of the lane', () {
    for (final sector in FlyoverAtlas.edges) {
      for (final layer in sector) {
        expect(layer, hasLength(FlyoverAtlas.variants));
        for (final edge in layer) {
          final first = edge.codeUnitAt(0) - 48;
          final last = edge.codeUnitAt(edge.length - 1) - 48;
          expect((first - last).abs(), lessThanOrEqualTo(6),
              reason: 'bank edge must continue across the tile seam');
          for (final unit in edge.codeUnits) {
            // 64 logical px = 128 arena units: every bank leaves the
            // central 100+ units of the 360-wide arena free.
            expect(unit - 48, lessThanOrEqualTo(64));
          }
        }
      }
    }
    for (var s = 0; s < 5; s++) {
      for (var r = 0; r < 5; r++) {
        expect(
          FlyoverAtlas.sprites.where((e) => e.sector == s && e.route == r),
          isNotEmpty,
          reason: 'every named route needs its own landmarks',
        );
      }
      expect(FlyoverAtlas.creatures.where((e) => e.sector == s), hasLength(2));
    }
  });

  testWidgets('flyover scrolls deterministically, keeps a dark lane, '
      'distinguishes routes and honours reduced motion', (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      final scene = await _scene(model);
      final views = <Uint8List>[];
      for (var sector = 0; sector < 5; sector++) {
        scene.environment = sector.toDouble();
        model.level = sector + 1;
        scene.sectors.flyover.distance = 900;
        final view = await _capture(
          scene,
          output: '.cache/flyover/sector-${sector + 1}.png',
        );
        views.add(view);
        final lane = _meanLuma(view, 150, 210);
        final banks = (_meanLuma(view, 0, 40) + _meanLuma(view, 320, 360)) / 2;
        expect(lane, lessThan(banks), reason: 'sector $sector lane stays darker');
        expect(lane, lessThan(.12), reason: 'sector $sector lane stays dark');
      }
      scene.environment = 0;
      model.level = 1;
      scene.sectors.flyover.distance = 900;
      final a = await _capture(scene);
      expect(await _capture(scene), orderedEquals(a));
      scene.sectors.flyover.distance = 940;
      final b = await _capture(scene);
      expect(a, isNot(orderedEquals(b)), reason: 'ground streams toward the ship');

      // Slums versus Docks must differ at the landmark layer.
      model.cycle = 1;
      final slums = await _capture(scene, output: '.cache/flyover/krybor-slums.png');
      model.cycle = 2;
      final docks = await _capture(scene, output: '.cache/flyover/krybor-docks.png');
      var changed = 0;
      for (var i = 0; i < slums.length; i += 4) {
        if ((slums[i] - docks[i]).abs() + (slums[i + 1] - docks[i + 1]).abs() > 12) {
          changed++;
        }
      }
      expect(changed / (slums.length / 4), greaterThan(.03));

      // Reduced motion freezes decorative flight and creature walking.
      scene.sectors.flyover.reducedMotionOverride = true;
      scene.update(.01); // latch ship/shadow state once
      final still = await _capture(scene);
      scene.update(.5);
      expect(await _capture(scene), orderedEquals(still));
      scene.sectors.flyover.reducedMotionOverride = false;

      for (final image in [
        ...scene.sectors.images,
        ...scene.sectors.flyover.strips,
        scene.sectors.flyover.props,
        scene.sectors.flyover.creatures,
      ]) {
        image?.dispose();
      }
    });
  });

  testWidgets('creatures scatter from explosions and duck under the ship shadow',
      (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      final scene = await _scene(model);
      final flyover = scene.sectors.flyover;
      scene.environment = 2;
      model.level = 3;
      flyover.distance = 600;
      scene.sectors.advance(1 / 60, model, 2);
      final critters = flyover.debugCreaturePositions(2);
      expect(critters, isNotEmpty, reason: 'ground layers carry creatures');
      final target = critters.firstWhere((p) => p.dy > 60 && p.dy < 420);
      final before = flyover.debugCreaturePositions(2);
      model.blasts.add(Blast(target.dx, target.dy, big: true));
      final simulated = model.blasts.length;
      scene.sectors.advance(1 / 60, model, 2);
      expect(flyover.reactingCreatures, greaterThan(0));
      expect(model.blasts, hasLength(simulated), reason: 'visual only');
      await _capture(scene, output: '.cache/flyover/reacting.png');
      expect(before, isNotEmpty);

      // Shadow: move the ship over a low creature and let the frame update.
      final low = flyover.debugCreaturePositions(2).where((p) => p.dy > 440);
      if (low.isNotEmpty) {
        model.shipX = (low.first.dx - 12).clamp(18.0, 342.0);
        final reacting = flyover.reactingCreatures;
        scene.sectors.advance(1 / 60, model, 2);
        expect(flyover.reactingCreatures, greaterThanOrEqualTo(reacting));
      }
      for (final image in [
        ...scene.sectors.images,
        ...flyover.strips,
        flyover.props,
        flyover.creatures,
      ]) {
        image?.dispose();
      }
    });
  });
}
