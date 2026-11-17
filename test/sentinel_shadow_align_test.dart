// sentinel-shadow-align: the looming sentinel's shadow is cast from its
// silhouette by the demons' projection, and hands off without a jump.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/shadow_projector.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel m) async {
  final scene = DemonScene(m, () {});
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.environment = 1;
  scene.sectors.flyover.reducedMotionOverride = false;
  return scene;
}

void _dispose(DemonScene s) {
  s.atlas?.dispose();
  s.effectsAtlas?.dispose();
  s.ship.image?.dispose();
}

void _step(ArcadeModel m, DemonScene scene) {
  m.invulnerable = 5;
  scene.sectors.flyover.advance(1 / 60, m, scene.environment);
  m.update(1 / 60);
  scene.creatures.update(m, 1 / 60);
  m.shots.removeWhere((s) => !s.hostile);
  final rec = ui.PictureRecorder();
  scene.paintShadowPass(ui.Canvas(rec));
  rec.endRecording().dispose();
}

/// A model [ahead] waves before its sector's first sentinel wave (0: the
/// sentinel's own wave, its silhouette waiting for the escort).
ArcadeModel _sentinelWave(int ahead) {
  final probe = ArcadeModel(seed: 7)
    ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
  var w = 3;
  while (probe.sentinelFor(w) == null) {
    w++;
  }
  return ArcadeModel(seed: 7)..startAt(
    difficulty: Difficulty.normal,
    sector: 2,
    route: 1,
    wave: w - ahead,
  );
}

// The flyers' sun offset at the silhouette's altitude (no relief).
final _lead =
    SentinelForeshadow.shadowAltitude *
    ShadowProjector.tanSun *
    ShadowProjector.offsetScale;

void main() {
  for (final mode in ShadowMode.values) {
    testWidgets('the looming shadow lies under its silhouette ($mode)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final ahead in [2, 1, 0]) {
          final m = _sentinelWave(ahead);
          final scene = await _scene(m)
            ..shadowModeOverride = mode;
          var samples = 0;
          for (var f = 0; f < 60 * 24; f++) {
            _step(m, scene);
            final fs = m.foreshadow;
            final at = scene.lurkCenter;
            if (fs == null || at == null || f % 7 != 0) continue;
            samples++;
            final base = DemonScene.foreshadowBase(fs);
            expect(base.dx, fs.x);
            // Along the sun from the ground under it, within a pixel: its
            // x leads the silhouette's by the flyers' offset (cos of a ±4°
            // drift), less where the relief catches it sooner.
            final dx = at.dx - fs.x;
            final minLead = mode == ShadowMode.flat
                ? _lead * math.cos(4 * math.pi / 180)
                : 0.0;
            expect(
              dx,
              inInclusiveRange(minLead - 1, _lead + 1),
              reason: 'ahead $ahead frame $f',
            );
            if (mode == ShadowMode.flat) {
              final dy = at.dy - base.dy;
              final s4 = math.sin(4 * math.pi / 180);
              expect(
                dy,
                inInclusiveRange(
                  _lead * (.25 - s4) - 1,
                  _lead * (.25 + s4) + 1,
                ),
                reason: 'ahead $ahead frame $f',
              );
            }
          }
          expect(samples, greaterThan(20), reason: 'ahead $ahead');
          _dispose(scene);
        }
      });
    });
  }

  testWidgets('smaller at a distance: its size follows the projection', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final samples = <(double, double)>[]; // (silhouette nearness, scale)
      final stageMax = <int, double>{}, stageMin = <int, double>{};
      for (final ahead in [2, 1, 0]) {
        final m = _sentinelWave(ahead);
        final scene = await _scene(m);
        for (var f = 0; f < 60 * 24; f++) {
          _step(m, scene);
          final fs = m.foreshadow, s = scene.lurkScale;
          if (fs == null || s == null || f % 5 != 0) continue;
          samples.add((fs.nearness, s));
          stageMax[ahead] = math.max(stageMax[ahead] ?? 0, s);
          stageMin[ahead] = math.min(stageMin[ahead] ?? 9, s);
        }
        _dispose(scene);
      }
      expect(samples.length, greaterThan(200));
      // Nearer (by more than the sun drift's wobble) is never smaller.
      samples.sort((a, b) => a.$1.compareTo(b.$1));
      for (var i = 0; i < samples.length; i++) {
        for (var j = i + 1; j < samples.length; j++) {
          if (samples[j].$1 - samples[i].$1 <= .01) continue;
          expect(
            samples[j].$2,
            greaterThan(samples[i].$2),
            reason: 'n ${samples[i].$1} -> ${samples[j].$1}',
          );
        }
      }
      // Each wave nearer, larger; the fight's is larger still (1.1 at .62).
      expect(stageMax[2]!, lessThan(stageMin[0]!));
      expect(stageMax[2]!, lessThan(stageMax[1]!));
      expect(stageMax[0]!, lessThan(DemonScene.sentinelShadowScale(.62, 85)));
    });
  });

  testWidgets('no jump at the hand-off into the rising sentinel', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = _sentinelWave(0);
      final scene = await _scene(m);
      Offset? last;
      double? lastScale, firstRise, peak;
      var looming = 0, rising = 0;
      var maxStep = 0.0, maxScaleStep = 0.0, maxDip = 0.0;
      for (var f = 0; f < 60 * 30; f++) {
        _step(m, scene);
        final s = m.demons.where((d) => d.isLarge).firstOrNull;
        final lurk = scene.lurkCenter;
        final own = s == null ? null : scene.shadowCenterOf(s);
        expect(lurk != null && own != null, isFalse, reason: 'frame $f');
        final at = lurk ?? own;
        final sc = lurk != null
            ? scene.lurkScale
            : (s == null ? null : scene.shadowScaleOf(s));
        if (lurk != null) looming++;
        if (own != null && s!.entering) {
          rising++;
          firstRise ??= sc;
          peak = math.max(peak ?? 0, sc!);
          maxDip = math.max(maxDip, 1 - sc / peak);
        }
        if (at != null && last != null) {
          maxStep = math.max(maxStep, (at - last).distance);
        }
        if (sc != null && lastScale != null) {
          maxScaleStep = math.max(maxScaleStep, (sc / lastScale - 1).abs());
        }
        last = at;
        lastScale = sc;
        if (s != null && !s.entering) break;
      }
      expect(looming, greaterThan(60));
      expect(rising, greaterThan(60));
      expect(maxStep, lessThan(4));
      expect(maxScaleStep, lessThan(.03));
      // It grows through the rise into the fight's size; the only give is
      // the penumbra narrowing as its altitude falls (about 2 %).
      expect(lastScale!, greaterThan(firstRise! * 1.5));
      expect(maxDip, lessThan(.03));
    });
  });
}
