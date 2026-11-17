// Shadows (continuous-swarm design §8, task 6.6): every flying creature
// casts one, the reserve none; at most three layers; the ship's dim is
// capped.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
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

Future<DemonScene> _scene(ArcadeModel m) async {
  final scene = DemonScene(m, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(
      'assets/images/sector-${i + 1}.webp',
    );
  }
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.environment = 1;
  return scene;
}

void _paint(DemonScene scene) {
  final rec = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(rec), Vector2(360, 780));
  rec.endRecording().dispose();
}

void _run(ArcadeModel m, DemonScene scene, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    m.invulnerable = 5;
    m.update(1 / 60);
    scene.creatures.update(m, 1 / 60);
    m.shots.removeWhere((s) => !s.hostile);
  }
}

void main() {
  testWidgets('every flyer casts a shadow, the reserve none, <= 3 layers', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = ArcadeModel(seed: 4)
        ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
      final scene = await _scene(m);
      var checked = 0;
      for (var i = 0; i < 40; i++) {
        _run(m, scene, .25);
        _paint(scene);
        expect(scene.shadowLayers, lessThanOrEqualTo(3));
        final shadowed = scene.shadowed.toSet();
        for (final d in m.demons) {
          if (d.swarmState == SwarmState.reserve) {
            expect(shadowed, isNot(contains(d)), reason: 'reserve: none');
            continue;
          }
          if (d.isLarge || d.entering || d.nearness <= 0) continue;
          if (Perspective.groundY(d.nearness) > 530) continue;
          expect(d.altitude, greaterThan(0));
          expect(shadowed, contains(d), reason: 'a fighting creature');
          checked++;
        }
        for (final d in m.swarmReserve) {
          expect(shadowed, isNot(contains(d)));
        }
      }
      expect(checked, greaterThan(100));
      // A diver keeps its shadow all the way down.
      final diver = m.demons.firstWhere((d) => !d.isLarge && !d.entering);
      diver
        ..dive = .3
        ..targetX = m.shipX;
      _run(m, scene, 1 / 60);
      _paint(scene);
      expect(scene.shadowed, contains(diver));
      // The reduced tier draws one sharp layer.
      scene.atmosphere.quality = AtmosphereQuality.reduced;
      _paint(scene);
      expect(scene.shadowLayers, 1);
    });
  });

  testWidgets('a shadow over the ship dims it, never past 15 %', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = ArcadeModel(seed: 4)
        ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
      final scene = await _scene(m);
      _run(m, scene, 6);
      // Stack every creature's shadow onto the ship.
      for (final d in m.demons) {
        d
          ..entranceProgress = 1
          ..x = m.shipX
          ..nearness = (ArcadeModel.shipY - 172 - 2) / 348
          ..altitude = 4;
      }
      _paint(scene);
      expect(scene.shipShadowDim, greaterThan(0));
      expect(scene.shipShadowDim, lessThanOrEqualTo(DemonScene.shipDimCap));
    });
  });
}
