import 'dart:ui' as ui;
import 'dart:io';

import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';

import 'package:demon_attack/game/campaign_story.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/widgets/medal.dart';
import 'package:demon_attack/widgets/heart_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> pixels(CustomPainter painter) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size(40, 40));
  final picture = recorder.endRecording();
  final image = await picture.toImage(40, 40);
  final data = await image.toByteData();
  final result = data!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return result;
}

void main() {
  test('the twenty-five named destinations connect without cycle labels', () {
    final names = <String>{};
    for (var route = 0; route < 5; route++) {
      for (var sector = 1; sector <= 5; sector++) {
        names.add(CampaignStory.name(sector, route));
        expect(
          CampaignStory.arrival(sector, route),
          contains(CampaignStory.name(sector, route)),
        );
        if (sector < 5 || route < 4) {
          expect(
            CampaignStory.travel(sector, route),
            contains(
              CampaignStory.name(
                sector == 5 ? 1 : sector + 1,
                sector == 5 ? route + 1 : route,
              ),
            ),
          );
        }
      }
    }
    expect(names.length, 25);
    expect(CampaignStory.travel(5, 4), contains('frontier is free'));
  });
  testWidgets(
    'boss health is visible through shield depletion and hull damage',
    (tester) async {
      await tester.runAsync(() async {
        final model = ArcadeModel()..start();
        model.mode = RunMode.playing;
        model.demons.clear();
        model.boss = Carrier(0);
        final scene = DemonScene(model, () {});
        final codec = await ui.instantiateImageCodec(
          await File('assets/images/combat.png').readAsBytes(),
        );
        scene.atlas = (await codec.getNextFrame()).image;
        codec.dispose();
        final images = <List<int>>[];
        for (var stage = 0; stage < 3; stage++) {
          final boss = model.boss!;
          boss.shield = stage == 0
              ? boss.shieldMax
              : stage == 1
              ? boss.shieldMax ~/ 3
              : 0;
          boss.core = stage == 2 ? 1 : boss.coreMax;
          final recorder = ui.PictureRecorder();
          scene.paintArena(Canvas(recorder), Vector2(360, 520));
          final picture = recorder.endRecording();
          final image = await picture.toImage(360, 520);
          images.add((await image.toByteData())!.buffer.asUint8List().toList());
          final file = File('.cache/cinematics/boss-health-$stage.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(
            (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
                .asUint8List(),
          );
          image.dispose();
          picture.dispose();
        }
        expect(images[0], isNot(orderedEquals(images[1])));
        expect(images[1], isNot(orderedEquals(images[2])));
        scene.atlas!.dispose();
      });
    },
  );
  testWidgets('medals distinguish difficulty, rank and missing awards', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final images = <String>{};
      for (final difficulty in Difficulty.values) {
        for (var ordinal = 0; ordinal < 5; ordinal++) {
          images.add(
            (await pixels(MedalPainter(difficulty, ordinal, true))).join(','),
          );
        }
      }
      expect(images.length, 15);
      expect(
        await pixels(const MedalPainter(Difficulty.normal, 0, false)),
        isNot(await pixels(const MedalPainter(Difficulty.normal, 0, true))),
      );
    });
  });
  testWidgets('heart pieces have distinct silhouettes and assemble a heart', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final empty = await pixels(const HeartPartPainter(0));
      final complete = await pixels(const HeartPartPainter(15));
      expect(complete, isNot(orderedEquals(empty)));
      final parts = <String>{};
      for (final mask in [1, 2, 4, 8]) {
        parts.add((await pixels(HeartPartPainter(mask))).join(','));
      }
      expect(parts.length, 4);
    });
  });
}
