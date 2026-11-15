import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/flock.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/shadow_projector.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Timing harness for the atmosphere (design §6: fog <= 2 ms per frame,
/// flock <= .5 ms for 40 agents). Prints the fog layers' Dart recording
/// cost and their CPU raster cost at phone size (3x the arena) for the
/// shader, tile and reduced tiers, and the flock's cost per step. The
/// tester rasterises on the CPU, so raster numbers are an upper bound for
/// a GPU; asserts only generous ceilings against pathological regressions.
void main() {
  testWidgets('atmosphere frame cost', (tester) async {
    await tester.runAsync(() async {
      final atmosphere = Atmosphere();
      await atmosphere.load();
      const slots = FogSlot.values;
      Future<(double, double)> run(String tier) async {
        void paint(ui.Canvas c) {
          c.scale(3);
          for (final s in slots) {
            atmosphere.paint(c, s);
          }
        }

        final record = Stopwatch()..start();
        for (var i = 0; i < 300; i++) {
          atmosphere.advance(1 / 60, distance: i * .43);
          final r = ui.PictureRecorder();
          paint(ui.Canvas(r));
          r.endRecording().dispose();
        }
        final recordUs = record.elapsedMicroseconds / 300;
        final r = ui.PictureRecorder();
        paint(ui.Canvas(r));
        final pic = r.endRecording();
        (await pic.toImage(1080, 1560)).dispose();
        final raster = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          (await pic.toImage(1080, 1560)).dispose();
        }
        pic.dispose();
        final rasterUs = raster.elapsedMicroseconds / 10;
        // ignore: avoid_print
        print(
          'fog $tier: record ${(recordUs / 1000).toStringAsFixed(3)} ms, '
          'cpu raster ${(rasterUs / 1000).toStringAsFixed(2)} ms (1080x1560)',
        );
        return (recordUs, rasterUs);
      }

      final shader = await run(atmosphere.usesShader ? 'shader' : 'tiles*');
      atmosphere.shaderEnabled = false;
      final tiles = await run('tiles');
      atmosphere.quality = AtmosphereQuality.reduced;
      final reduced = await run('reduced');
      expect(shader.$1, lessThan(2000));
      expect(tiles.$1, lessThan(2000));
      expect(reduced.$1, lessThan(tiles.$1 * 1.5 + 200));

      // Flock: 40 agents entering at once.
      final model = ArcadeModel(seed: 3)..startAt(sector: 3, wave: 2);
      final flock = ArrivalFlock(seed: 3);
      final demons = [
        for (var i = 0; i < 40; i++)
          Demon(38 + (i % 6) * 56.0, 70 + (i ~/ 6) * 32.0, 0, 1, i * 1.7)
            ..entranceProgress = 0
            ..arrivesFromDistance = true,
      ];
      flock.launch(demons, sector: 3, route: 0, wave: 2);
      final sw = Stopwatch()..start();
      const frames = 600;
      for (var f = 0; f < frames; f++) {
        for (final d in demons) {
          d.entranceProgress = (f / frames) * .98;
          flock.reference(d, sector: 3, route: 0, wave: 2);
        }
        flock.advance(1 / 60);
      }
      final perFrame = sw.elapsedMicroseconds / frames;
      // ignore: avoid_print
      print(
        'flock 40 agents: ${(perFrame / 1000).toStringAsFixed(3)} ms per '
        '60 Hz frame (30 Hz steps)',
      );
      expect(perFrame, lessThan(2000));
      expect(model.demons, isNotEmpty);
    });
  });
  // continuous-swarm task 6.7: a 61-creature combat frame with every
  // shadow costs at most 1.5 ms more to record than without them.
  testWidgets('61-creature combat frame with shadows', (tester) async {
    await tester.runAsync(() async {
      Future<ui.Image> decode(String file) async {
        final codec = await ui.instantiateImageCodec(
          await File(file).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      }

      final m = ArcadeModel(seed: 6)
        ..startAt(difficulty: Difficulty.hard, sector: 4, route: 4);
      final scene = DemonScene(m, () {});
      for (var i = 0; i < 5; i++) {
        scene.sectors.images[i] = await decode(
          'assets/images/sector-${i + 1}.png',
        );
      }
      scene.atlas = await decode('assets/images/combat.png');
      scene.effectsAtlas = await decode('assets/images/sentinel-effects.png');
      scene.ship.image = await decode('assets/images/ship-weapons.png');
      await scene.atmosphere.load();
      for (var i = 0; i < 60 * 8; i++) {
        m.invulnerable = 5;
        m.update(1 / 60);
        scene.creatures.update(m, 1 / 60);
        m.shots.removeWhere((s) => !s.hostile);
      }
      // Fill to the active cap with fighting creatures.
      final template = m.demons.firstWhere((d) => !d.isLarge);
      while (m.demons.length < ArcadeModel.maxActiveDemons) {
        final i = m.demons.length;
        m.demons.add(
          Demon(
              30 + (i % 10) * 30.0,
              70 + (i ~/ 10) * 34.0,
              template.kind,
              1,
              i * .7,
            )
            ..nearness = .62 + (i ~/ 10) * .03
            ..altitude = 80
            ..scale = 1.2,
        );
      }
      double cost() {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 120; i++) {
          final r = ui.PictureRecorder();
          scene.paintArena(ui.Canvas(r), Vector2(360, 780));
          r.endRecording().dispose();
        }
        return sw.elapsedMicroseconds / 120;
      }

      scene.creatureShadows = false;
      cost();
      final without = cost();
      scene.creatureShadows = true;
      cost();
      final withShadows = cost();
      // ignore: avoid_print
      print(
        'combat frame (61): ${(without / 1000).toStringAsFixed(3)} ms, '
        'with shadows ${(withShadows / 1000).toStringAsFixed(3)} ms '
        '(${scene.shadowCount} shadows, ${scene.shadowLayers} layers)',
      );
      expect(scene.shadowCount, greaterThanOrEqualTo(50));
      expect(scene.shadowLayers, lessThanOrEqualTo(3));
      expect(withShadows - without, lessThan(1500));

      // terrain-shadows task 4.1: the draped pass (sun-ray march + 4 x 3
      // drape per caster, drawVertices) against today's flat pass, Dart
      // recording and CPU raster of the pass alone at phone size (3x).
      Future<(double, double)> pass(ShadowMode mode) async {
        scene.shadowModeOverride = mode;
        void paint(ui.Canvas c) {
          c.scale(3);
          scene.paintShadowPass(c);
        }

        final sw = Stopwatch()..start();
        for (var i = 0; i < 200; i++) {
          final r = ui.PictureRecorder();
          paint(ui.Canvas(r));
          r.endRecording().dispose();
        }
        final record = sw.elapsedMicroseconds / 200;
        final r = ui.PictureRecorder();
        paint(ui.Canvas(r));
        final pic = r.endRecording();
        (await pic.toImage(1080, 1560)).dispose();
        final raster = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          (await pic.toImage(1080, 1560)).dispose();
        }
        pic.dispose();
        return (record, raster.elapsedMicroseconds / 10);
      }

      await pass(ShadowMode.flat);
      final flat = await pass(ShadowMode.flat);
      await pass(ShadowMode.draped);
      final draped = await pass(ShadowMode.draped);
      scene.shadowModeOverride = null;
      // ignore: avoid_print
      print(
        'shadow pass (${scene.shadowCount}): flat record '
        '${(flat.$1 / 1000).toStringAsFixed(3)} ms, raster '
        '${(flat.$2 / 1000).toStringAsFixed(2)} ms; draped record '
        '${(draped.$1 / 1000).toStringAsFixed(3)} ms, raster '
        '${(draped.$2 / 1000).toStringAsFixed(2)} ms (1080x1560 cpu)',
      );
      expect(draped.$1 - flat.$1, lessThan(500));
      expect(draped.$2, lessThan(flat.$2 * 1.5 + 2000));
    });
  });
}
