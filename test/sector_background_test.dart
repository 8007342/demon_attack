import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
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

Future<Uint8List> _capture(
  DemonScene scene, {
  String? output,
  bool combat = true,
}) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520), combat: combat);
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  if (output != null) {
    final file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List(),
    );
  }
  image.dispose();
  picture.dispose();
  return bytes;
}

int _hash(Uint8List bytes) {
  var hash = 2166136261;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 16777619) & 0xffffffff;
  }
  return hash;
}

double _differentPixelFraction(Uint8List a, Uint8List b) {
  var changed = 0;
  for (var i = 0; i < a.length; i += 4) {
    final distance =
        (a[i] - b[i]).abs() +
        (a[i + 1] - b[i + 1]).abs() +
        (a[i + 2] - b[i + 2]).abs();
    if (distance > 12) changed++;
  }
  return changed / (a.length ~/ 4);
}

void main() {
  testWidgets(
    'sector worlds are distinct, animate and preserve cinematic handoffs',
    (tester) async {
      await tester.runAsync(() async {
        final model = ArcadeModel()..start();
        final scene = DemonScene(model, () {});
        scene.atlas = await _decode('assets/images/combat.png');
        scene.sky = await _decode('assets/images/cosmic-sky.png');
        for (var i = 0; i < 5; i++) {
          scene.sectors.images[i] = await _decode(
            'assets/images/sector-${i + 1}.png',
          );
        }
        try {
          final frames = <Uint8List>[];
          for (var level = 1; level <= 5; level++) {
            model.level = level;
            model.mode = RunMode.playing;
            model.invulnerable = 0;
            model.clock = 2;
            model.demons.clear();
            model.shots.clear();
            model.boss = level == 5 ? Carrier(0) : null;
            for (var i = 0; i < 6; i++) {
              model.demons.add(
                Demon(
                  45 + i % 3 * 125.0,
                  80 + i ~/ 3 * 70.0,
                  (level - 1).clamp(0, 3),
                  level > 2 ? 3 : 1,
                  i.toDouble(),
                  elite: i == 0,
                ),
              );
            }
            model.shots.addAll([
              Shot(180, 370, 0, -420),
              Shot(80, 290, 0, 160, hostile: true),
              Shot(290, 410, 0, 160, hostile: true),
            ]);
            scene.environment = (level - 1).toDouble();
            frames.add(
              await _capture(
                scene,
                output: '.cache/sectors/sector-$level-play.png',
              ),
            );
          }
          expect(frames.map(_hash).toSet(), hasLength(5));
          for (var a = 0; a < 5; a++) {
            for (var b = a + 1; b < 5; b++) {
              expect(
                _differentPixelFraction(frames[a], frames[b]),
                greaterThan(.18),
                reason:
                    'Sectors ${a + 1} and ${b + 1} must change substantial scenery',
              );
            }
          }
          final before = await _capture(scene, combat: false);
          scene.update(.1);
          final moving = await _capture(scene, combat: false);
          expect(
            _hash(before),
            isNot(_hash(moving)),
            reason: 'Independent orbitals and stars animate',
          );
          model.pause();
          scene.update(.1);
          expect(await _capture(scene, combat: false), orderedEquals(moving));
          model.resume();
          model.mode = RunMode.levelClear;
          model.transitionDuration = 4;
          model.transitionLeft = 0;
          final clearEnd = await _capture(scene);
          model.mode = RunMode.travel;
          model.transitionLeft = 4;
          expect(await _capture(scene), orderedEquals(clearEnd));
          model.transitionLeft = 0;
          final travelEnd = await _capture(scene);
          model.mode = RunMode.transition;
          model.wave = 1;
          model.transitionDuration = 2.3;
          model.transitionLeft = 2.3;
          expect(await _capture(scene), orderedEquals(travelEnd));
          var boundaryLight = 0;
          for (var i = 0; i < clearEnd.length; i += 4) {
            boundaryLight += clearEnd[i] + clearEnd[i + 1] + clearEnd[i + 2];
          }
          expect(
            boundaryLight,
            0,
            reason: 'Boundary cuts remain fully black over all new scenery',
          );
        } finally {
          scene.atlas!.dispose();
          scene.sky!.dispose();
          for (final image in scene.sectors.images) {
            image?.dispose();
          }
        }
      });
    },
  );
}
