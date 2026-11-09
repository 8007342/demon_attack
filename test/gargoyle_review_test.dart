import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/creature_motion.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sprite_atlas.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Uint8List> _capture(DemonScene scene, String name) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520));
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final raw = (await image.toByteData())!.buffer.asUint8List();
  final file = File('.cache/gargoyle-review/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
  picture.dispose();
  return raw;
}

/// Places a demon and pins its presentation motion state.
Demon _place(
  ArcadeModel model,
  DemonScene scene,
  double x,
  double y,
  int kind, {
  int maxHp = 1,
  int hp = 1,
  int dir = 0,
  double phase = 0.1,
  bool glide = false,
  bool elite = false,
  double flash = 0,
}) {
  final d = Demon(x, y, kind, maxHp, 0, elite: elite)
    ..hp = hp
    ..flash = flash;
  model.demons.add(d);
  scene.creatures.motion.update(model, 1 / 60);
  final m = scene.creatures.motion.of(d)!
    ..dir = dir
    ..phase = phase
    ..gliding = glide;
  if (glide) m.vy = 80;
  return d;
}

void main() {
  testWidgets('motion state picks directional, stroke and glide frames', (
    tester,
  ) async {
    final d = Demon(100, 100, 0, 1, 0);
    final m = CreatureMotion(0);
    // Steady leftward flight crosses the enter threshold once.
    for (var i = 0; i < 30; i++) {
      d.x -= 90 / 60;
      m.update(d.x, d.y, 1 / 60);
    }
    expect(m.dir, -1);
    // Slowing to below the enter threshold but above exit keeps the bank.
    for (var i = 0; i < 30; i++) {
      d.x -= 35 / 60;
      m.update(d.x, d.y, 1 / 60);
    }
    expect(m.dir, -1, reason: 'hysteresis holds the bank');
    for (var i = 0; i < 30; i++) {
      m.update(d.x, d.y, 1 / 60);
    }
    expect(m.dir, 0);
    // Jitter around zero never flickers into a bank.
    var flips = 0;
    for (var i = 0; i < 120; i++) {
      d.x += (i.isEven ? 0.5 : -0.5);
      final before = m.dir;
      m.update(d.x, d.y, 1 / 60);
      if (m.dir != before) flips++;
    }
    expect(flips, 0);
    // Sinking glides; climbing strokes with a longer downstroke.
    for (var i = 0; i < 40; i++) {
      d.y += 110 / 60;
      m.update(d.x, d.y, 1 / 60);
    }
    expect(m.gliding, isTrue);
    expect(m.frame, inInclusiveRange(8, 9));
    for (var i = 0; i < 40; i++) {
      d.y -= 60 / 60;
      m.update(d.x, d.y, 1 / 60);
    }
    expect(m.gliding, isFalse);
    var down = 0;
    for (var i = 0; i < 120; i++) {
      d.y -= 60 / 60;
      m.update(d.x, d.y, 1 / 60);
      if (m.frame < 4) down++;
    }
    expect(down, greaterThan(66), reason: 'climbing emphasises downstroke');

    // Lookup: direction picks the column block; flash and molts their rows.
    final cell = CombatAtlas.creature(
      d,
      0,
      motion: m
        ..dir = 1
        ..phase = .1,
    );
    expect(cell.col ~/ CombatAtlas.flightFrames, 2);
    expect(cell.row, CombatAtlas.base(0));
    final hurt = Demon(0, 0, 2, 3, 0)..hp = 2;
    final hurtCell = CombatAtlas.creature(hurt, 0, motion: m..dir = -1);
    expect(hurtCell.row, CombatAtlas.base(2) + 1);
    expect(hurtCell.col, lessThan(CombatAtlas.flightFrames));
    hurt.flash = .1;
    final flashCell = CombatAtlas.creature(hurt, 0, motion: m);
    expect(
      flashCell.row,
      inInclusiveRange(CombatAtlas.base(2) + 5, CombatAtlas.base(2) + 6),
    );
    hurt.telegraph = .3;
    expect(
      CombatAtlas.creature(hurt, 0, motion: m).row,
      CombatAtlas.actionRow(2),
      reason: 'dive warning outranks flight frames',
    );
  });

  testWidgets('combat atlas honours the gargoyle contract', (tester) async {
    await tester.runAsync(() async {
      // plan/sprite-atlas.md: 32 x 40 cells of 64 x 64, stored 1x.
      final atlas = await _decode('assets/images/combat.png');
      expect(atlas.width, CombatAtlas.columns * 64);
      expect(atlas.height, 40 * 64);
      final data = (await atlas.toByteData())!.buffer.asUint32List();
      final colours = <int>{};
      for (final pixel in data) {
        final alpha = (pixel >> 24) & 255;
        expect(alpha, isIn([0, 255]), reason: 'no antialiased edges');
        if (alpha == 255) colours.add(pixel);
      }
      expect(colours.length, lessThanOrEqualTo(96), reason: 'bounded palette');
      List<int> cell(int row, int col) => [
        for (var y = row * 64; y < (row + 1) * 64; y++)
          ...data.sublist(
            y * atlas.width + col * 64,
            y * atlas.width + col * 64 + 64,
          ),
      ];
      bool empty(List<int> c) => c.every((p) => p == 0);
      List<int> mirrored(List<int> c) => [
        for (var y = 0; y < 64; y++) ...c.sublist(y * 64, y * 64 + 64).reversed,
      ];
      for (var k = 0; k < 4; k++) {
        final b = CombatAtlas.base(k);
        for (var v = 0; v < 5; v++) {
          final frames = {
            for (var c = 0; c < 30; c++) cell(b + v, c).join(','),
          };
          expect(
            frames,
            hasLength(30),
            reason: 'species $k variant $v: 30 distinct flight frames',
          );
          for (var f = 0; f < 10; f++) {
            final left = cell(b + v, f);
            final right = cell(b + v, 20 + f);
            expect(empty(left), isFalse);
            expect(
              right,
              isNot(mirrored(left)),
              reason: 'right banks are real renders, not mirrors',
            );
          }
        }
        // Downstroke lifts the body, upstroke folds the wings: the folded
        // recovery is clearly narrower than the level downstroke pose.
        int width(List<int> c) {
          var first = 64, last = -1;
          for (var i = 0; i < c.length; i++) {
            if (c[i] == 0) continue;
            final x = i % 64;
            if (x < first) first = x;
            if (x > last) last = x;
          }
          return last - first + 1;
        }

        expect(width(cell(b, 10 + 5)), lessThan(width(cell(b, 10 + 2)) * .8));
        for (var slot = 0; slot < 60; slot++) {
          expect(
            empty(cell(b + 5 + slot ~/ 32, slot % 32)),
            isFalse,
            reason: 'flash slot $slot',
          );
        }
        for (var c = 0; c < 32; c++) {
          expect(
            empty(cell(CombatAtlas.actionRow(k), c)),
            isFalse,
            reason: 'action col $c',
          );
        }
        for (var c = 0; c < 16; c++) {
          expect(
            empty(cell(CombatAtlas.eliteRow(k), c)),
            isFalse,
            reason: 'elite col $c',
          );
        }
      }
      atlas.dispose();
    });
  });

  testWidgets('gargoyle review frames at phone size', (tester) async {
    await tester.runAsync(() async {
      final model = ArcadeModel()..start();
      final scene = DemonScene(model, () {});
      scene.atlas = await _decode('assets/images/combat.png');
      scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
      model.mode = RunMode.playing;
      model.invulnerable = 0;
      model.clock = 2;

      // Sheet 1: every species left/neutral/right x downstroke/upstroke,
      // plus glide; one species per row pair.
      model.demons.clear();
      for (var k = 0; k < 4; k++) {
        for (var c = 0; c < 6; c++) {
          _place(
            model,
            scene,
            30 + c * 60.0,
            40 + k * 120.0,
            k,
            dir: c ~/ 2 - 1,
            phase: c.isEven ? 0.15 : 0.7,
          );
        }
        for (var c = 0; c < 3; c++) {
          _place(
            model,
            scene,
            60 + c * 120.0,
            95 + k * 120.0,
            k,
            dir: c - 1,
            glide: true,
          );
        }
      }
      final motion = await _capture(scene, 'motion');

      // Sheet 2: damage states per species: intact, molt 1-3, angry, flash.
      model.demons.clear();
      for (var k = 0; k < 4; k++) {
        for (var c = 0; c < 6; c++) {
          final maxHp = 4;
          final hp = [4, 3, 2, 1, 1, 3][c];
          final d = _place(
            model,
            scene,
            30 + c * 60.0,
            60 + k * 120.0,
            k,
            maxHp: maxHp,
            hp: hp,
            dir: c.isEven ? 0 : 1,
            phase: .2,
            flash: c == 5 ? .1 : 0,
          );
          if (c == 3) {
            // Molt 3 without anger: maxHp 4, hp 1 is angry, so use 5.
            model.demons.remove(d);
            _place(
              model,
              scene,
              d.x,
              d.y,
              k,
              maxHp: 5,
              hp: 2,
              dir: 0,
              phase: .2,
            );
          }
        }
        // Elite with armour, banking left and right.
        _place(
          model,
          scene,
          90,
          115 + k * 120.0,
          k,
          maxHp: 4,
          hp: 4,
          elite: true,
          dir: -1,
        );
        _place(
          model,
          scene,
          270,
          115 + k * 120.0,
          k,
          maxHp: 4,
          hp: 2,
          elite: true,
          dir: 1,
        );
      }
      final damage = await _capture(scene, 'damage');
      expect(motion, isNot(damage));

      // Sheet 3: combat over each sector background at phone size.
      await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
      scene.sectors.flyover.reducedMotionOverride = true;
      scene.sky = await _decode('assets/images/cosmic-sky.png');
      for (var i = 0; i < 5; i++) {
        scene.sectors.images[i] = await _decode(
          'assets/images/sector-${i + 1}.png',
        );
      }
      for (var level = 1; level <= 5; level++) {
        model.level = level;
        model.demons.clear();
        model.shots.clear();
        model.boss = null;
        scene.environment = (level - 1).toDouble();
        for (var i = 0; i < 12; i++) {
          _place(
            model,
            scene,
            40 + i % 4 * 93.0,
            70 + i ~/ 4 * 62.0,
            (i + level) % 4,
            maxHp: 3,
            hp: 3 - i % 3,
            dir: [-1, 0, 1, 0][i % 4],
            phase: (i * .13) % 1,
            elite: i == 5,
          );
        }
        model.shots.addAll([
          Shot(180, 370, 0, -420),
          Shot(80, 290, 0, 160, hostile: true),
          Shot(290, 330, 0, 160, hostile: true),
        ]);
        await _capture(scene, 'sector-$level');
      }
      scene.atlas!.dispose();
      scene.effectsAtlas!.dispose();
    });
  });
}
