import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
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

/// Review frames go to $BOSS_REVIEW_DIR (default .cache/carrier-review).
final _dir =
    Platform.environment['BOSS_REVIEW_DIR'] ?? '.cache/carrier-review';

/// Renders the arena at [w] x [h] and writes `<dir>/<name>.png`.
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
  final file = File('$_dir/$name.png');
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

/// Run [cls]'s carrier showing form [form].
Carrier _carrier(int cls, int form, {bool shield = true, double door = 0}) {
  final b = Carrier(cls)
    ..x = 180
    ..y = 205;
  b.core = (b.coreMax * (1 - (form + .5) / b.formCount)).round();
  b.shield = shield ? b.shieldMax : 0;
  b.door = door;
  b.sideDoorLeft = b.sideDoorRight = door;
  return b;
}

void main() {
  testWidgets('armada review frames: classes, forms, jaws, damage, wrecks', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      final scene = DemonScene(model, () {});
      scene.atlas = await _decode('assets/images/combat.png');
      scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
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

      for (final (k, hull) in BossAtlas.classes.indexed) {
        final atlas = await _decode('assets/images/${hull.asset}');
        scene.armada.setAtlas(k, atlas);
        model.cycle = k;
        model.mode = RunMode.playing;
        model.wreckBoss = null;
        model.demons.clear();
        model.shots.clear();

        // Each form: shield up with the jaws sealed, then jaws and bays open.
        for (var form = 0; form < hull.forms; form++) {
          model.boss = _carrier(k, form);
          await _capture(scene, 'k$k-form-$form-shield');
          model.boss = _carrier(k, form, shield: false, door: 1);
          await _capture(scene, 'k$k-form-$form-open');
        }

        // Jaw cycle: openness 0, 1/3, 2/3, 1.
        for (var j = 0; j < 4; j++) {
          model.boss = _carrier(k, 0, shield: false, door: j / 3);
          await _capture(scene, 'k$k-jaw-$j');
        }

        // Engines respond to movement: drifting left, still, right.
        for (final (i, v) in [-90.0, 0.0, 90.0].indexed) {
          model.boss = _carrier(k, 0)..horizontalVelocity = v;
          await _capture(scene, 'k$k-thrust-$i');
        }
        model.boss = _carrier(k, 0);

        // Idle life: frames half a second apart differ on the bow.
        final idle = <Uint8List>[];
        for (var f = 0; f < 4; f++) {
          model.clock = 2 + f * .5;
          idle.add(await _capture(scene, 'k$k-idle-$f'));
        }
        expect(
          _crop(idle[0], 120, 150, 120, 60),
          isNot(_crop(idle[2], 120, 150, 120, 60)),
          reason: 'eyes pulse and fins breathe between idle frames',
        );
        model.clock = 2;

        // Damage escalation: cracks, torn plates, breaches, fire.
        for (final (i, fraction) in [1.0, .8, .6, .35, .12].indexed) {
          final b = Carrier(k)
            ..x = 180
            ..y = 205;
          b.shield = 0;
          b.core = (b.coreMax * fraction).round().clamp(1, b.coreMax);
          model.boss = b;
          await _capture(scene, 'k$k-damage-$i');
        }

        // The falling wreck (the final form, as in play).
        model.boss = null;
        model.wreckBoss = _carrier(k, hull.forms - 1, shield: false);
        model.mode = RunMode.victory;
        model.transitionDuration = 5.5;
        for (final (i, p) in [.15, .45, .75].indexed) {
          model.transitionLeft = 5.5 * (1 - p);
          await _capture(scene, 'k$k-wreck-$i');
        }
        model.wreckBoss = null;
        model.mode = RunMode.playing;

        // Beside the gargoyles and a sentinel over the Carrier sector, at
        // phone and desktop sizes.
        model.boss = _carrier(k, 1);
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
          Shot(96, 120, 0, -420),
          Shot(120, 300, 0, 160, hostile: true),
        ]);
        await _capture(scene, 'k$k-world-phone');
        await _capture(scene, 'k$k-world-desktop', w: 1440, h: 900);
        model.boss = _carrier(k, hull.forms - 1, door: 1)..x = 100;
        await _capture(scene, 'k$k-world-final-phone');
        atlas.dispose();
      }
    });
  });
}
