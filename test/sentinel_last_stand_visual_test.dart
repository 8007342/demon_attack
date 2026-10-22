import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<List<int>> capture(DemonScene scene, String name) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520));
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final data = (await image.toByteData())!.buffer.asUint8List().toList();
  final file = File('.cache/pixel-review/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
  picture.dispose();
  return data;
}

void main() {
  testWidgets(
    'last stand has distinct raised-wing tell and folded-wing rush sprites',
    (tester) async {
      await tester.runAsync(() async {
        for (final heavy in [false, true]) {
          final model = ArcadeModel()..start();
          model.mode = RunMode.playing;
          model.demons.clear();
          final demon = Demon(
            180,
            58,
            1,
            8,
            0,
            archetype: heavy
                ? EnemyArchetype.armoredSentinel
                : EnemyArchetype.shieldSentinel,
            lastStandEligible: true,
          )..hp = 3;
          model.demons.add(demon);
          final scene = DemonScene(model, () {});
          scene.atlas = await decode('assets/images/combat.png');
          scene.effectsAtlas = await decode(
            'assets/images/sentinel-effects.png',
          );
          scene.sectors.images[0] = await decode('assets/images/sector-1.png');
          try {
            final idle = await capture(scene, 'last-stand-$heavy-idle');
            model.hitDemon(demon);
            expect(demon.lastStand, isTrue);
            for (var i = 0; i < 24; i++) {
              model.update(1 / 60);
            }
            final tell = await capture(scene, 'last-stand-$heavy-tell');
            expect(tell, isNot(orderedEquals(idle)));
            expect(
              demon.y,
              lessThan(58),
              reason: 'Tell movement lifts the creature before commitment',
            );
            while (!demon.rushing) {
              model.update(1 / 60);
            }
            final rush = await capture(scene, 'last-stand-$heavy-rush');
            expect(rush, isNot(orderedEquals(tell)));
            model.pause();
            scene.update(.1);
            expect(
              await capture(scene, 'last-stand-$heavy-paused'),
              orderedEquals(rush),
            );
          } finally {
            scene.atlas!.dispose();
            scene.effectsAtlas!.dispose();
            scene.sectors.images[0]!.dispose();
          }
        }
      });
    },
  );
}
