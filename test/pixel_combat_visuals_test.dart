import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  return image;
}

Future<Uint8List> _capture(DemonScene scene, String name) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520));
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  final file = File('.cache/pixel-review/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
  picture.dispose();
  return bytes;
}

List<int> _crop(Uint8List image, int x, int y, int width, int height) => [
  for (var row = y; row < y + height; row++)
    ...image.sublist((row * 360 + x) * 4, (row * 360 + x + width) * 4),
];

void main() {
  testWidgets('effects atlas preserves solid original doubled pixel cells', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final atlas = await _decode('assets/images/sentinel-effects.png');
      expect(atlas.width, 1024);
      expect(atlas.height, 640);
      final data = (await atlas.toByteData())!.buffer.asUint32List();
      for (var y = 0; y < atlas.height; y += 2) {
        for (var x = 0; x < atlas.width; x += 2) {
          final index = y * atlas.width + x;
          final pixel = data[index];
          expect((pixel >> 24) & 255, isIn([0, 255]));
          expect(data[index + 1], pixel);
          expect(data[index + atlas.width], pixel);
          expect(data[index + atlas.width + 1], pixel);
        }
      }
      List<int> cell(int row, int col) => [
        for (var y = row * 64; y < (row + 1) * 64; y++)
          ...data.sublist(
            y * atlas.width + col * 128,
            y * atlas.width + (col + 1) * 128,
          ),
      ];
      int occupiedWidth(List<int> frame) {
        var first = 128;
        var last = -1;
        for (var i = 0; i < frame.length; i++) {
          if (frame[i] == 0) continue;
          final x = i % 128;
          if (x < first) first = x;
          if (x > last) last = x;
        }
        return last - first + 1;
      }

      for (final row in [6, 7]) {
        expect(
          {for (var col = 0; col < 8; col++) cell(row, col).join(',')},
          hasLength(8),
          reason: 'Every charge/rush frame has its own visible pixel pose',
        );
        expect(
          cell(row, 0),
          isNot(cell(row - 6, 4)),
          reason: 'Last-stand charge differs from the ordinary attack tell',
        );
        expect(
          occupiedWidth(cell(row, 4)),
          lessThan(occupiedWidth(cell(row, 0)) * .7),
          reason: 'Rush folds the massive wings into a narrow silhouette',
        );
      }
      double outerWingY(List<int> frame) {
        final heights = <int>[];
        for (var i = 0; i < frame.length; i++) {
          if (frame[i] != 0 && i % 128 < 40) heights.add(i ~/ 128);
        }
        return heights.reduce((a, b) => a + b) / heights.length;
      }

      for (final row in [0, 1]) {
        expect({
          for (var col = 0; col < 8; col++) cell(row, col).join(','),
        }, hasLength(8));
        expect(
          outerWingY(cell(row, 4)) - outerWingY(cell(row, 0)),
          greaterThan(16),
          reason: 'The outer wings sweep down through a full stroke',
        );
        expect(
          occupiedWidth(cell(row, 5)),
          lessThan(occupiedWidth(cell(row, 2)) * .7),
          reason: 'Folded wings articulate inward during recovery',
        );
        expect(
          cell(row + 8, 4),
          isNot(cell(row + 6, 4)),
          reason: 'Recoverable falcon dives differ from final rushes',
        );
      }
      atlas.dispose();
    });
  });

  testWidgets('sentinel poses, armor loss and carrier damage stay readable', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      final sentinel = Demon(
        105,
        52,
        1,
        6,
        0,
        archetype: EnemyArchetype.shieldSentinel,
        shieldMax: 4,
        armorMax: 2,
      );
      final heavy = Demon(
        255,
        52,
        3,
        8,
        0,
        archetype: EnemyArchetype.armoredSentinel,
        shieldMax: 6,
        armorMax: 4,
      );
      model.demons.addAll([sentinel, heavy]);
      for (var i = 0; i < 10; i++) {
        model.demons.add(
          Demon(55 + i % 5 * 62, 140 + i ~/ 5 * 44, i % 4, 2, 0),
        );
      }
      final scene = DemonScene(model, () {});
      scene.atlas = await _decode('assets/images/combat.png');
      scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
      scene.sectors.images[0] = await _decode('assets/images/sector-1.png');
      final idle = await _capture(scene, 'sentinels-idle');
      model.clock = .2;
      final held = await _capture(scene, 'sentinels-held-frame');
      expect(
        _crop(idle, 40, 20, 280, 65),
        _crop(held, 40, 20, 280, 65),
        reason: 'Eight articulated sentinel poses hold for .4 seconds each',
      );
      model.clock = .8;
      final flap = await _capture(scene, 'sentinels-downstroke');
      expect(_crop(idle, 40, 20, 280, 65), isNot(_crop(flap, 40, 20, 280, 65)));
      for (var pose = 0; pose < 8; pose++) {
        model.clock = pose * .4 + .01;
        await _capture(scene, 'sentinel-wing-pose-$pose');
      }
      model.clock = .8;
      sentinel.telegraph = heavy.telegraph = .8;
      final warning = await _capture(scene, 'sentinels-warning');
      expect(
        _crop(warning, 40, 20, 280, 65),
        isNot(_crop(flap, 40, 20, 280, 65)),
      );
      // Warning changes are confined to the creature; no arrow enters the gap.
      expect(_crop(warning, 40, 85, 280, 30), _crop(flap, 40, 85, 280, 30));
      sentinel.telegraph = heavy.telegraph = 0;
      sentinel.dive = heavy.dive = .2;
      final dive = await _capture(scene, 'sentinels-falcon-dive');
      expect(
        _crop(dive, 40, 20, 280, 65),
        isNot(_crop(warning, 40, 20, 280, 65)),
      );
      sentinel.dive = heavy.dive = 0;
      sentinel.shield = heavy.shield = 0;
      final unshielded = await _capture(scene, 'sentinels-shield-depleted');
      expect(
        _crop(unshielded, 40, 70, 280, 15),
        isNot(_crop(flap, 40, 70, 280, 15)),
      );
      expect(
        _crop(unshielded, 40, 20, 280, 30),
        _crop(flap, 40, 20, 280, 30),
        reason: 'Absorbing shield removal preserves the armored creature',
      );
      sentinel.hp = heavy.hp = 2;
      sentinel.armor = heavy.armor = 0;
      final damaged = await _capture(scene, 'sentinels-shed-armor');
      expect(
        _crop(damaged, 190, 20, 130, 65),
        isNot(_crop(flap, 190, 20, 130, 65)),
      );
      model.pause();
      scene.update(.1);
      expect(await _capture(scene, 'sentinels-paused'), damaged);
      model.resume();
      model.demons.clear();
      model.blasts.add(
        Blast(180, 70, archetype: EnemyArchetype.shieldSentinel),
      );
      model.blasts.single.age = .45;
      await _capture(scene, 'sentinel-wing-breakup');
      model.blasts.clear();
      model.boss = Carrier(0);
      model.boss!.shield = 0;
      model.boss!.core = 1;
      final burning = await _capture(scene, 'carrier-fire-smoke');
      model.clock += .15;
      final nextFire = await _capture(scene, 'carrier-fire-next-frame');
      expect(
        _crop(burning, 80, 140, 200, 60),
        isNot(_crop(nextFire, 80, 140, 200, 60)),
      );
      scene.atlas!.dispose();
      scene.effectsAtlas!.dispose();
      scene.sectors.images[0]!.dispose();
    });
  });

  testWidgets('small enemy tells stay entirely inside their monster sprite', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      model.mode = RunMode.playing;
      model.demons.clear();
      final demon = Demon(180, 160, 0, 1, 0);
      model.demons.add(demon);
      final scene = DemonScene(model, () {});
      scene.atlas = await _decode('assets/images/combat.png');
      scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
      final ordinary = await _capture(scene, 'small-enemy-idle');
      demon.telegraph = .5;
      final tell = await _capture(scene, 'small-enemy-sprite-tell');
      var changed = 0;
      for (var i = 0; i < tell.length; i += 4) {
        if (tell[i] == ordinary[i] &&
            tell[i + 1] == ordinary[i + 1] &&
            tell[i + 2] == ordinary[i + 2]) {
          continue;
        }
        final x = (i ~/ 4) % 360;
        final y = (i ~/ 4) ~/ 360;
        expect(x, inInclusiveRange(160, 199));
        expect(y, inInclusiveRange(140, 179));
        changed++;
      }
      expect(changed, greaterThan(20));
      scene.atlas!.dispose();
      scene.effectsAtlas!.dispose();
    });
  });

  testWidgets(
    'weapon shapes and pickups remain distinct with restrained bursts',
    (tester) async {
      await tester.runAsync(() async {
        final model = ArcadeModel()..start();
        model.mode = RunMode.playing;
        model.demons.clear();
        model.shots.addAll([
          Shot(55, 250, 0, -400),
          Shot(105, 250, 0, -400, kind: ShotKind.powerful, damage: 2),
          Shot(155, 250, 0, -400, kind: ShotKind.large, blastRadius: 30),
          Shot(
            205,
            250,
            0,
            -400,
            kind: ShotKind.large,
            damage: 2,
            blastRadius: 30,
          ),
          Shot(255, 250, 0, 200, hostile: true),
          Shot(305, 250, 0, 240, hostile: true, kind: ShotKind.sentinel),
        ]);
        model.pickups.addAll([
          Pickup(140, 310, Power.powerful),
          Pickup(220, 310, Power.large),
        ]);
        model.blasts.addAll([
          Blast(80, 380)..age = .15,
          Blast(180, 380, blastRadius: 30)..age = .15,
          Blast(280, 380, archetype: EnemyArchetype.shieldSentinel)..age = .4,
        ]);
        final scene = DemonScene(model, () {});
        scene.atlas = await _decode('assets/images/combat.png');
        scene.effectsAtlas = await _decode(
          'assets/images/sentinel-effects.png',
        );
        final shots = model.shots.toList();
        model.shots.clear();
        final background = await _capture(scene, 'weapon-example-background');
        model.shots.addAll(shots);
        final captured = await _capture(
          scene,
          'weapon-pickup-explosion-shapes',
        );
        final isolatedShots = Uint8List(captured.length);
        for (var i = 0; i < captured.length; i += 4) {
          if (captured[i] == background[i] &&
              captured[i + 1] == background[i + 1] &&
              captured[i + 2] == background[i + 2]) {
            continue;
          }
          isolatedShots.setRange(i, i + 4, captured, i);
        }
        expect({
          for (var x = 55; x <= 305; x += 50)
            _crop(isolatedShots, x - 10, 240, 20, 20).join(','),
        }, hasLength(6));
        expect(
          _crop(captured, 125, 295, 30, 30),
          isNot(_crop(captured, 205, 295, 30, 30)),
        );

        final recorder = ui.PictureRecorder();
        scene.effectSprite(
          ui.Canvas(recorder),
          4,
          2,
          const ui.Offset(64, 32),
          opacity: .65,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(128, 64);
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        final visibleAlpha = {
          for (var i = 3; i < rgba.length; i += 4)
            if (rgba[i] > 0) rgba[i],
        };
        expect(
          visibleAlpha,
          hasLength(1),
          reason: 'Translucency preserves crisp uniform pixel edges',
        );
        expect(visibleAlpha.single, inInclusiveRange(160, 170));
        image.dispose();
        picture.dispose();
        scene.atlas!.dispose();
        scene.effectsAtlas!.dispose();
      });
    },
  );
}
