import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/flock.dart';
import 'package:demon_attack/game/model.dart';
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
}
