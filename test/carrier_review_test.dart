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

/// Renders the arena at [w] x [h] and writes `.cache/carrier-review/<name>.png`.
Future<Uint8List> _capture(
  DemonScene scene,
  String name, {
  int w = 360,
  int h = 520,
}) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final raw = (await image.toByteData())!.buffer.asUint8List();
  final file = File('.cache/carrier-review/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
  picture.dispose();
  return raw;
}

List<int> _crop(Uint8List image, int x, int y, int width, int height) => [
  for (var row = y; row < y + height; row++)
    ...image.sublist((row * 360 + x) * 4, (row * 360 + x + width) * 4),
];

/// A four-form carrier (route 3) showing form [form].
Carrier _carrier(int form, {bool shield = true, double door = 0}) {
  final b = Carrier(3)
    ..x = 180
    ..y = 205;
  b.core = (b.coreMax * (1 - (form + .5) / b.formCount)).round();
  b.shield = shield ? b.shieldMax : 0;
  b.door = door;
  b.sideDoorLeft = b.sideDoorRight = door;
  return b;
}

void main() {
  testWidgets('carrier atlas honours the war-ark contract', (tester) async {
    await tester.runAsync(() async {
      // plan/sprite-atlas.md: 4 x 11 cells of 368 x 240, stored 1x.
      final atlas = await _decode('assets/images/boss-carrier.png');
      expect(atlas.width, 4 * 368);
      expect(atlas.height, 11 * 240);
      final data = (await atlas.toByteData())!.buffer.asUint32List();
      final colours = <int>{};
      for (final pixel in data) {
        final alpha = (pixel >> 24) & 255;
        expect(alpha, isIn([0, 255]), reason: 'no antialiased edges');
        if (alpha == 255) colours.add(pixel);
      }
      expect(colours.length, lessThanOrEqualTo(160), reason: 'bounded ramps');
      String cell(int row, int col) => [
        for (var y = row * 240; y < (row + 1) * 240; y++)
          ...data.sublist(
            y * atlas.width + col * 368,
            y * atlas.width + col * 368 + 368,
          ),
      ].join(',');
      bool empty(int row, int col) =>
          cell(row, col).split(',').every((p) => p == '0');
      for (var row = 0; row < 11; row++) {
        for (var col = 0; col < 4; col++) {
          expect(empty(row, col), isFalse, reason: 'cell $row/$col');
        }
      }
      for (var form = 0; form < 4; form++) {
        final idle = {
          for (final r in [0, 7, 8, 9]) cell(r, form),
        };
        expect(idle, hasLength(4), reason: 'form $form: four idle frames');
      }
      expect({for (var c = 0; c < 4; c++) cell(4, c)}, hasLength(4));
      expect({for (var c = 0; c < 4; c++) cell(5, c)}, hasLength(4));
      atlas.dispose();
    });
  });

  testWidgets('carrier review frames: forms, jaws, damage, wreck, world', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      final scene = DemonScene(model, () {});
      scene.atlas = await _decode('assets/images/combat.png');
      scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
      scene.bossAtlas = await _decode('assets/images/boss-carrier.png');
      scene.ship.image = await _decode('assets/images/ship-weapons.png');
      scene.sky = await _decode('assets/images/cosmic-sky.png');
      await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
      scene.sectors.flyover.reducedMotionOverride = true;
      for (var i = 0; i < 5; i++) {
        scene.sectors.images[i] = await _decode(
          'assets/images/sector-${i + 1}.png',
        );
      }
      model.level = 5;
      scene.environment = 4;
      model.mode = RunMode.playing;
      model.invulnerable = 0;
      model.demons.clear();
      model.shots.clear();
      model.clock = 2;

      // Each form, shield up with the jaws sealed, then jaws and vents open.
      for (var form = 0; form < 4; form++) {
        model.boss = _carrier(form);
        await _capture(scene, 'form-$form-shield');
        model.boss = _carrier(form, shield: false, door: 1);
        await _capture(scene, 'form-$form-open');
      }

      // Jaw cycle on the first form: openness 0, 1/3, 2/3, 1.
      for (var k = 0; k < 4; k++) {
        model.boss = _carrier(0, shield: false, door: k / 3);
        await _capture(scene, 'jaw-$k');
      }

      // Idle life: four frames half a second apart differ on the hull.
      final idle = <Uint8List>[];
      for (var f = 0; f < 4; f++) {
        model.boss = _carrier(0);
        model.clock = 2 + f * .5;
        idle.add(await _capture(scene, 'idle-$f'));
      }
      expect(
        _crop(idle[0], 90, 140, 180, 60),
        isNot(_crop(idle[2], 90, 140, 180, 60)),
        reason: 'wing sails breathe and eyes pulse between idle frames',
      );
      model.clock = 2;

      // Damage escalation: cracks, broken chunks, gaping fissures, fire.
      for (final (i, fraction) in [1.0, .8, .6, .35, .12].indexed) {
        final b = Carrier(0)
          ..x = 180
          ..y = 205;
        b.shield = 0;
        b.core = (b.coreMax * fraction).round().clamp(1, b.coreMax);
        model.boss = b;
        await _capture(scene, 'damage-$i');
      }

      // Falling wreck of each form.
      model.boss = null;
      for (var form = 0; form < 4; form++) {
        model.wreckBoss = _carrier(form, shield: false);
        model.mode = RunMode.victory;
        model.transitionDuration = 5.5;
        for (final (i, p) in [.15, .45, .75].indexed) {
          model.transitionLeft = 5.5 * (1 - p);
          await _capture(scene, 'wreck-$form-$i');
        }
      }
      model.wreckBoss = null;
      model.mode = RunMode.playing;

      // Beside the gargoyles and a sentinel over the Carrier sector, at
      // phone and desktop sizes.
      model.boss = _carrier(1);
      model.demons
        ..add(Demon(60, 330, 0, 3, 0))
        ..add(Demon(130, 350, 1, 3, 0))
        ..add(Demon(230, 345, 2, 3, 0))
        ..add(Demon(300, 330, 3, 3, 0, elite: true))
        ..add(
          Demon(
            180,
            70,
            3,
            8,
            0,
            archetype: EnemyArchetype.armoredSentinel,
            shieldMax: 6,
            armorMax: 4,
          ),
        );
      model.shots.addAll([
        Shot(180, 420, 0, -420),
        Shot(120, 300, 0, 160, hostile: true),
      ]);
      await _capture(scene, 'world-phone');
      await _capture(scene, 'world-desktop', w: 1440, h: 900);
      model.boss = _carrier(3, door: 1);
      await _capture(scene, 'world-final-phone');
    });
  });
}
