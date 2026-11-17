// terrain-shadows tasks 3.1-3.4 (design §3, §4): the lurking shadow (cast
// from the silhouette since sentinel-shadow-align), its hand-off into the rising sentinel's shadow, the ground's
// hesitation under it, and the boss shadow.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/terrain_field.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel m, int sector) async {
  final scene = DemonScene(m, () {});
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.environment = sector - 1.0;
  scene.sectors.flyover.reducedMotionOverride = false;
  return scene;
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

/// A model one wave before its sector's first sentinel wave.
ArcadeModel _sentinelWave({bool before = false}) {
  final probe = ArcadeModel(seed: 7)
    ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1);
  var w = 2;
  while (probe.sentinelFor(w) == null) {
    w++;
  }
  return ArcadeModel(seed: 7)..startAt(
    difficulty: Difficulty.normal,
    sector: 2,
    route: 1,
    wave: before ? w - 1 : w,
  );
}

void main() {
  testWidgets('a foreshadowed sentinel: one shadow, from lurk to combat', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = _sentinelWave();
      final scene = await _scene(m, 2);
      Offset? last;
      var lurkFrames = 0, handoffFrames = 0, inPlay = 0;
      var maxStep = 0.0;
      for (var f = 0; f < 60 * 30; f++) {
        _step(m, scene);
        final sentinel = m.demons.where((d) => d.isLarge).firstOrNull;
        final lurk = scene.lurkCenter;
        final own = sentinel == null ? null : scene.shadowCenterOf(sentinel);
        // Never two sentinel shadows.
        expect(lurk != null && own != null, isFalse, reason: 'frame $f');
        final now = lurk ?? own;
        if (lurk != null) {
          lurkFrames++;
        }
        if (own != null) {
          if (scene.lurkCover == null && m.foreshadow == null) inPlay++;
          if (last != null && inPlay < 60) handoffFrames++;
        }
        if (now != null && last != null) {
          maxStep = math.max(maxStep, (now - last).distance);
        }
        last = now;
        if (sentinel != null && !sentinel.entering) break;
      }
      expect(lurkFrames, greaterThan(60));
      expect(handoffFrames, greaterThan(30));
      // No pop: the shadow glides into the sentinel's own.
      expect(maxStep, lessThan(8));
    });
  });

  testWidgets('the lurk is drawn within the layer budget and covers ground', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = _sentinelWave(before: true);
      final scene = await _scene(m, 2);
      for (var f = 0; f < 60 * 14; f++) {
        _step(m, scene);
      }
      expect(m.foreshadow?.visible, isTrue);
      expect(scene.lurkCenter, isNotNull);
      expect(scene.shadowLayers, lessThanOrEqualTo(3));
      // The lurk's footprint covers ground; a pose inside it hesitates.
      final cover = scene.lurkCover;
      if (cover != null) {
        final t = scene.sectors.flyover.terrain;
        final z = GroundCamera.zOf(cover.center.dy);
        final inside = t.placeAt(cover.center.dx, z);
        if ((inside.y - cover.center.dy).abs() < cover.height / 2) {
          expect(inside.hesitate, .7);
        }
      }
    });
  });

  test('ground poses under the lurk cover hesitate (x .7), others not', () {
    final t = TerrainView()
      ..configure(1, 1)
      ..cam = 300;
    final z = GroundCamera.zOf(300);
    final pose = t.placeAt(120, z);
    expect(pose.hesitate, 1);
    t.lurkCover = Rect.fromCenter(
      center: Offset(120, pose.y),
      width: 80,
      height: 30,
    );
    expect(t.placeAt(120, z).hesitate, .7);
    expect(t.placeAt(250, z).hesitate, 1);
    t.lurkCover = null;
    expect(t.placeAt(120, z).hesitate, 1);
  });

  testWidgets('the boss casts a shadow that shrinks and fades as it climbs', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final m = ArcadeModel(seed: 3)
        ..startAt(difficulty: Difficulty.normal, sector: 2, route: 0);
      final scene = await _scene(m, 2);
      scene.armada.setAtlas(0, await _decode('assets/images/boss-frigate.png'));
      for (var f = 0; f < 30; f++) {
        _step(m, scene);
      }
      m.boss = Carrier(0)..x = 180;
      _step(m, scene);
      final low = scene.bossShadow;
      expect(low, isNotNull);
      expect(low!.alpha, lessThanOrEqualTo(.35));
      expect(scene.shadowLayers, lessThanOrEqualTo(3));
      expect(scene.shadowDrawCallsPerBucket, lessThanOrEqualTo(4));
      scene.bossShadowAltitude = 320;
      _step(m, scene);
      final high = scene.bossShadow!;
      expect(high.scale, lessThan(low.scale));
      expect(high.alpha, lessThan(low.alpha));
      // The cell is baked once per hull load.
      scene.bossShadowAltitude = DemonScene.defaultBossShadowAltitude;
      _step(m, scene);
      expect(scene.bossShadow!.scale, low.scale);
    });
  });
}
