import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flutter_test/flutter_test.dart';

/// openspec/changes/fog-restoration: the fog is world-anchored, pervasive
/// and layered in depth, keeps the near lane readable, and the sentinel's
/// silhouette sits behind several soft layers.

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Uint8List> _render(void Function(ui.Canvas c) draw) async {
  final r = ui.PictureRecorder();
  draw(ui.Canvas(r));
  final pic = r.endRecording();
  final img = await pic.toImage(360, 520);
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  img.dispose();
  pic.dispose();
  return data.buffer.asUint8List();
}

void _paintFog(Atmosphere a, ui.Canvas c) {
  for (final (_, l) in a.groundLayers) {
    a.paintGroundLayer(c, l);
  }
  for (final slot in FogSlot.values) {
    a.paint(c, slot);
  }
}

void main() {
  group('layers in depth', () {
    test('the air layers sit between the horizon and the formation', () {
      var last = 0.0;
      for (final slot in Atmosphere.depthSlots) {
        final n = Atmosphere.layers[slot]!.nearness;
        expect(n, greaterThan(last), reason: '$slot is sorted far to near');
        expect(n, lessThan(Perspective.nearTop),
            reason: 'formation creatures are in front of every layer');
        last = n;
      }
      expect(Atmosphere.depthSlots.length, greaterThanOrEqualTo(5));
      // An arrival (from n .30) crosses at least four layers on its way in.
      expect(
        Atmosphere.depthSlots
            .where((s) => Atmosphere.layers[s]!.nearness > Perspective.nearFar)
            .length,
        greaterThanOrEqualTo(4),
      );
    });

    test('pervasive: fog over the whole field depth, not a band', () {
      for (var y = 40.0; y <= 340; y += 2) {
        expect(Atmosphere.combinedAlphaAt(180, y), greaterThan(.1),
            reason: 'row $y has fog');
      }
      // Several layers overlap at every row of the mid field.
      for (var y = 120.0; y <= 260; y += 4) {
        final n = FogSlot.values
            .where((s) => Atmosphere.peakAlphaAt(s, 180, y) > .04)
            .length;
        expect(n, greaterThanOrEqualTo(3), reason: 'row $y');
      }
    });

    test('the sentinel silhouette is behind several soft layers', () {
      // Its path: y 136-150 (+- 13), nearness at most .31.
      for (final y in [126.0, 140.0, 156.0]) {
        final front = Atmosphere.depthSlots
            .skip(1) // drawn after the horizon band
            .where((s) => Atmosphere.layers[s]!.nearness > .31)
            .where((s) => Atmosphere.peakAlphaAt(s, 180, y) > .03)
            .length;
        expect(front, greaterThanOrEqualTo(3), reason: 'row $y');
      }
    });
  });

  group('near lane', () {
    test('combined peak opacity stays under the lane cap', () {
      for (var y = GroundAtmosphereAtlas.laneTop; y < 520; y += 2) {
        for (var x = GroundAtmosphereAtlas.laneLeft;
            x <= GroundAtmosphereAtlas.laneRight;
            x += 4) {
          expect(Atmosphere.combinedAlphaAt(x, y),
              lessThanOrEqualTo(GroundAtmosphereAtlas.laneCap),
              reason: '($x, $y)');
        }
      }
    });

    testWidgets('rendered fog in the lane stays under the cap', (t) async {
      await t.runAsync(() async {
        final art = await _decode(
            'assets/images/${GroundAtmosphereAtlas.file}');
        for (final shader in [true, false]) {
          final a = Atmosphere()
            ..environment = 2
            ..groundArt = GroundAtmosphereArt(art);
          await a.load(shader: shader);
          a.advance(11, distance: 300);
          final px = await _render((c) => _paintFog(a, c));
          var worst = 0;
          for (var y = GroundAtmosphereAtlas.laneTop.toInt(); y < 520; y++) {
            for (var x = 96; x < 264; x++) {
              final v = px[(y * 360 + x) * 4 + 3];
              if (v > worst) worst = v;
            }
          }
          expect(worst / 255,
              lessThanOrEqualTo(GroundAtmosphereAtlas.laneCap + 2 / 255));
        }
      });
    });
  });

  group('world-anchored', () {
    testWidgets('the ship\'s position never moves the fog', (t) async {
      await t.runAsync(() async {
        final art = await _decode(
            'assets/images/${GroundAtmosphereAtlas.file}');
        Future<Uint8List> frame(double shipX) async {
          final m = ArcadeModel(seed: 3)..startAt(sector: 2);
          final s = DemonScene(m, () {});
          await s.atmosphere.load(shader: false);
          s.atmosphere.groundArt = GroundAtmosphereArt(art);
          s.environment = 1;
          m.shipX = m.targetX = shipX;
          for (var i = 0; i < 90; i++) {
            m.shipX = m.targetX = shipX;
            s.syncAtmosphere(1 / 60);
          }
          return _render((c) => _paintFog(s.atmosphere, c));
        }

        final left = await frame(40), right = await frame(320);
        expect(left, right);
      });
    });

    test('the foreshadow silhouette does not follow the ship', () {
      SentinelForeshadow at() {
        final f = SentinelForeshadow(EnemyArchetype.shieldSentinel, .5)
          ..clock = 3.7;
        // The model owns the ship; the path no longer takes it.
        f.place();
        return f;
      }

      final a = at(), b = at();
      expect(a.x, b.x);
      expect(a.y, b.y);
      // Two runs with the ship held at opposite edges see the same path.
      double run(double shipX) {
        final w = ArcadeModel(seed: 7)..startAt(sector: 2, route: 1);
        var sw = 0;
        for (var i = 2; i <= w.wavesPerLevel; i++) {
          if (w.sentinelFor(i) != null) {
            sw = i;
            break;
          }
        }
        final m = ArcadeModel(seed: 7)
          ..startAt(sector: 2, route: 1, wave: sw - 1);
        for (var i = 0; i < 240; i++) {
          m.invulnerable = 5;
          m.shipX = m.targetX = shipX;
          m.update(1 / 60);
          m.shots.removeWhere((s) => !s.hostile);
        }
        return m.foreshadow!.x;
      }

      expect(run(40), run(320));
    });
  });
}
