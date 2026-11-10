import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Swarm perspective review frames (plan/perspective.md): an arrival out of
/// the distance, formation breathing and a dive at the player, at phone
/// portrait (360 x 780, also at 3x device pixels) and a wide window, under
/// .cache/perspective-review/ (or PERSPECTIVE_REVIEW_DIR). Also checks the depth contract the frames
/// show: far arrivals are small, divers large, draw order far to near.
/// PERSPECTIVE_REVIEW_DIR moves the frames off a full checkout volume.
final _outDir =
    Platform.environment['PERSPECTIVE_REVIEW_DIR'] ??
    '.cache/perspective-review';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> _capture(DemonScene scene, String name) async {
  for (final (tag, w, h, ratio) in [
    ('phone', 360.0, 780.0, 1.0),
    ('phone3x', 360.0, 780.0, 3.0),
    ('wide', 1280.0, 720.0, 1.0),
  ]) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(ratio);
    scene.paintArena(canvas, Vector2(w, h));
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (w * ratio).round(),
      (h * ratio).round(),
    );
    final file = File('$_outDir/$name-$tag.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List(),
    );
    image.dispose();
    picture.dispose();
  }
}

void _run(ArcadeModel model, DemonScene scene, double seconds) {
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    model.invulnerable = 5;
    model.update(1 / 60);
    scene.creatures.update(model, 1 / 60);
    model.takeEvents();
    model.shots.removeWhere((s) => !s.hostile); // keep the swarm whole
  }
}

void main() {
  test('nearness maps the flight sheet and quantises crisp sizes', () {
    expect(Perspective.nearnessAtY(Perspective.topY), Perspective.nearTop);
    expect(Perspective.nearnessAtY(Perspective.shipY), Perspective.nearShip);
    // Far arrivals are small, the formation larger than the old 40-unit
    // sprite, divers clearly larger, all in whole 4-unit sprite steps.
    expect(Perspective.scaleOf(Perspective.nearFar), .5);
    final formation = Perspective.scaleOf(Perspective.nearnessAtY(140));
    expect(formation, inInclusiveRange(1.1, 1.3));
    expect(
      Perspective.scaleOf(
        Perspective.targetNearness(Perspective.shipY, diving: true),
      ),
      Perspective.smallMax,
    );
    for (var n = .2; n < 1.1; n += .013) {
      final size = 40 * Perspective.scaleOf(n);
      expect((size / 4 - (size / 4).round()).abs(), lessThan(1e-9));
    }
  });

  testWidgets('perspective review frames', (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel(seed: 1982)..startAt(sector: 2, wave: 2);
      final scene = DemonScene(model, () {});
      scene.atlas = await _decode('assets/images/combat.png');
      scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
      scene.sky = await _decode('assets/images/cosmic-sky.png');
      for (var i = 0; i < 5; i++) {
        scene.sectors.images[i] = await _decode(
          'assets/images/sector-${i + 1}.png',
        );
      }
      await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
      scene.sectors.flyover.reducedMotionOverride = true;
      scene.environment = 1;

      // 1. Arrival out of the horizon haze: early, mid, settling.
      _run(model, scene, .2);
      final early = [
        for (final d in model.demons)
          if (d.entering && d.entranceProgress > 0) d.scale,
      ];
      expect(early, isNotEmpty);
      expect(early.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(.7));
      await _capture(scene, '1-arrival-early');
      _run(model, scene, .25);
      await _capture(scene, '2-arrival-mid');
      _run(model, scene, .35);
      await _capture(scene, '3-arrival-settling');

      // 2. Formation breathing: two moments half a breath apart, with a
      // sentinel hovering above the swarm.
      final sentinel = Demon(
        180,
        44,
        0,
        9,
        0,
        archetype: EnemyArchetype.shieldSentinel,
        shieldMax: 3,
        armorMax: 2,
      );
      model.demons.add(sentinel);
      _run(model, scene, 3);
      expect(sentinel.scale, inInclusiveRange(.875, 1.125));
      final formed = model.demons
          .where((d) => !d.entering && !d.isLarge)
          .toList();
      expect(formed, isNotEmpty);
      for (final d in formed) {
        expect(d.scale, inInclusiveRange(1.0, 1.5));
        expect(d.hitHalfWidth, closeTo(13 * d.scale, 1e-9));
      }
      await _capture(scene, '4-formation-a');
      _run(model, scene, 1.85 / 2);
      await _capture(scene, '5-formation-b');

      // 3. A dive at the player: forced on one demon, captured on approach.
      final diver = formed.first;
      diver
        ..dive = .001
        ..targetX = model.shipX;
      var frames = 0;
      while (diver.y < 360 && frames++ < 600 && model.demons.contains(diver)) {
        _run(model, scene, 1 / 60);
      }
      model.shots.removeWhere((s) => !s.hostile); // keep the diver alive
      await _capture(scene, '6-dive-mid');
      while (diver.y < 440 && frames++ < 600 && model.demons.contains(diver)) {
        _run(model, scene, 1 / 60);
        model.shots.removeWhere((s) => !s.hostile);
      }
      expect(diver.scale, greaterThanOrEqualTo(1.4));
      await _capture(scene, '7-dive-close');

      // 4. The sentinel's heavy dive grows past its hover size.
      if (model.demons.contains(sentinel)) {
        sentinel
          ..dive = .001
          ..targetX = model.shipX;
        frames = 0;
        while (sentinel.y < 330 && frames++ < 600 && sentinel.dive > 0) {
          _run(model, scene, 1 / 60);
        }
        expect(sentinel.scale, greaterThan(1.1));
        await _capture(scene, '8-sentinel-dive');
      }
      scene.atlas!.dispose();
      scene.effectsAtlas!.dispose();
    });
  });
}
