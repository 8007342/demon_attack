import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Review frames go to .cache/transition-review with
/// --dart-define=DEMON_RENDER=true;
/// nothing is written otherwise (the source tree is a small shared tmpfs).
final String? renderDir = const bool.fromEnvironment('DEMON_RENDER')
    ? '.cache/transition-review'
    : null;

Future<ui.Image> decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Uint8List> pixelsOf(ui.Image image, String? name) async {
  final raw = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  if (renderDir != null && name != null) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$renderDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  }
  return raw;
}

Future<Uint8List> captureArena(DemonScene scene, String name) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520));
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final pixels = await pixelsOf(image, name);
  image.dispose();
  picture.dispose();
  return pixels;
}

/// Count of pixels that differ inside [box] of a 360-wide RGBA frame.
int diffIn(Uint8List a, Uint8List b, Rect box, {int width = 360}) {
  var count = 0;
  for (var y = box.top.toInt(); y < box.bottom.toInt(); y++) {
    for (var x = box.left.toInt(); x < box.right.toInt(); x++) {
      final i = (y * width + x) * 4;
      if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) {
        count++;
      }
    }
  }
  return count;
}

void loadout(ArcadeModel model, List<Power> powers) {
  model.powerTimers.clear();
  for (final p in powers) {
    // Past the deploy transition, still healthy.
    model.powerTimers[p] = ArcadeModel.powerDuration - 1;
  }
}

void main() {
  test(
    'spent modules keep falling through salvage, level clear and travel',
    () {
      for (final phase in [
        RunMode.salvage,
        RunMode.levelClear,
        RunMode.travel,
        RunMode.victory,
      ]) {
        final model = ArcadeModel()..start();
        model.demons.clear();
        model.mode = phase;
        model.transitionDuration = 4;
        model.transitionLeft = 4;
        model.fallingParts.add(
          FallingPart(150, ArcadeModel.shipY + 4, Power.rapid, vx: 12),
        );
        final part = model.fallingParts.single;
        final y0 = part.y, x0 = part.x;
        final left0 = model.transitionLeft;
        for (var i = 0; i < 30; i++) {
          model.update(1 / 60);
        }
        expect(model.mode, phase, reason: 'still in $phase');
        expect(part.y, greaterThan(y0), reason: 'falls during $phase');
        expect(part.x, greaterThan(x0), reason: 'drifts during $phase');
        expect(part.rotation, isNot(0), reason: 'tumbles during $phase');
        // Phase timing is untouched.
        expect(model.transitionLeft, closeTo(left0 - .5, .02));
        for (var i = 0; i < 40 && model.fallingParts.isNotEmpty; i++) {
          model.update(.1);
        }
        expect(model.fallingParts, isEmpty, reason: 'leaves during $phase');
      }
    },
  );

  test('salvage collection of a rival module ejects debris that falls', () {
    final model = ArcadeModel()..start();
    model.demons.clear();
    model.mode = RunMode.salvage;
    model.transitionDuration = 2;
    model.transitionLeft = 2;
    model.powerTimers[Power.rapid] = 5;
    model.collect(Power.powerful);
    expect(model.fallingParts, hasLength(1));
    final y0 = model.fallingParts.single.y;
    model.update(.1);
    expect(model.fallingParts.single.y, isNot(y0));
    // Loot rules are unchanged: the new module is equipped at full time.
    expect(model.timeLeft(Power.powerful), ArcadeModel.powerDuration);
  });

  testWidgets('cutscene ship draws the equipped modules and shield', (
    tester,
  ) async {
    final model = ArcadeModel()..start();
    model.demons.clear();
    final scene = DemonScene(model, () {});
    await tester.runAsync(() async {
      scene.atlas = await decode('assets/images/combat.png');
      scene.ship.image = await decode('assets/images/ship-weapons.png');
      // Each cutscene places the ship differently; check all of them.
      final shots = <String, (RunMode, double, Rect)>{
        'clear': (
          RunMode.levelClear,
          3.9,
          Rect.fromCenter(
            center: Offset(model.shipX, ArcadeModel.shipY),
            width: 52,
            height: 52,
          ),
        ),
        // cinematic-flow: the ship stays at its row in a Pursuit (it
        // climbs on the flow's climb beat; no flow runs here).
        'travel': (
          RunMode.travel,
          2,
          Rect.fromCenter(
            center: Offset(model.shipX, ArcadeModel.shipY),
            width: 52,
            height: 52,
          ),
        ),
        'victory': (
          RunMode.victory,
          5.4,
          Rect.fromCenter(
            center: Offset(model.shipX, ArcadeModel.shipY),
            width: 52,
            height: 52,
          ),
        ),
      };
      for (final MapEntry(key: name, value: (phase, left, box))
          in shots.entries) {
        model.mode = phase;
        model.transitionDuration = 4;
        model.transitionLeft = left;
        if (phase == RunMode.victory) model.transitionDuration = 5.5;
        loadout(model, []);
        final bare = await captureArena(scene, 'cutscene-$name-bare');
        loadout(model, [Power.powerful, Power.spread]);
        final armed = await captureArena(scene, 'cutscene-$name-armed');
        loadout(model, [Power.powerful, Power.spread, Power.shield]);
        final shielded = await captureArena(scene, 'cutscene-$name-shield');
        expect(
          diffIn(bare, armed, box),
          greaterThan(40),
          reason: '$name: modules must be drawn on the cutscene ship',
        );
        expect(
          diffIn(armed, shielded, box),
          greaterThan(40),
          reason: '$name: the shield bubble must be drawn',
        );
      }
      // Debris is drawn outside the ship, so it stays visible in cutscenes.
      model.mode = RunMode.levelClear;
      model.transitionDuration = 4;
      model.transitionLeft = 3.9;
      loadout(model, []);
      final empty = await captureArena(scene, 'debris-clear-empty');
      model.fallingParts.add(FallingPart(100, 300, Power.rapid, vx: -8));
      final falling = await captureArena(scene, 'debris-clear-falling');
      for (var i = 0; i < 30; i++) {
        model.update(1 / 60);
      }
      final later = await captureArena(scene, 'debris-clear-later');
      model.fallingParts.clear();
      final box = Rect.fromCenter(
        center: const Offset(100, 300),
        width: 60,
        height: 60,
      );
      expect(diffIn(empty, falling, box), greaterThan(20));
      expect(diffIn(falling, later, box), greaterThan(20));
    });
  });
  // cinematic-flow: the storyboard banner and its route glyph left the
  // sector transitions (no cards, no strips); the cutscene ship above is the
  // one the transition draws.
}
