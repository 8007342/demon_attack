import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Review renders for gameplay round 3: the life-loss explosion, regroup and
/// respawn; the homing arc into the ground plane; the convoy in live play.
/// PNG sheets land in GAMEPLAY_REVIEW_DIR (default .cache/gameplay-review).
const _out = String.fromEnvironment(
  'GAMEPLAY_REVIEW_DIR',
  defaultValue: '.cache/gameplay-review',
);
const dt = 1 / 60;

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel model) async {
  final scene = DemonScene(model, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode('assets/images/sector-${i + 1}.png');
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = true;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.groundForces.image = await _decode('assets/images/${GroundAtlas.file}');
  return scene;
}

Future<Uint8List> _render(DemonScene scene) async {
  final recorder = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(recorder), Vector2(360, 520));
  final picture = recorder.endRecording();
  final image = await picture.toImage(360, 520);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
      .buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

Future<void> _sheet(String name, List<Uint8List> frames) async {
  final w = 364 * frames.length;
  final rgba = Uint8List(w * 520 * 4);
  for (var f = 0; f < frames.length; f++) {
    for (var y = 0; y < 520; y++) {
      rgba.setRange(
        (y * w + f * 364) * 4,
        (y * w + f * 364 + 360) * 4,
        frames[f],
        y * 360 * 4,
      );
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: 520,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final image = (await codec.getNextFrame()).image;
  final file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
  image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
}

ArcadeModel _live(int sector, {int route = 0}) {
  final m = ArcadeModel(seed: 7)..startAt(sector: sector, route: route);
  while (!m.combat) {
    m.update(dt);
  }
  return m;
}

void _run(ArcadeModel m, double seconds, {bool keepWave = true}) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    if (keepWave) m.shots.removeWhere((s) => !s.hostile && s.y < 200);
    m.update(dt);
  }
}

void main() {
  testWidgets('gameplay round 3 review renders', (tester) async {
    await tester.runAsync(() async {
      // 1. Life loss: hit, explosion frames, regroup with fizzles, fly-in,
      // blinking protection.
      final m = _live(3, route: 1);
      final scene = await _scene(m);
      scene.environment = 2;
      m.invulnerable = 99;
      _run(m, 6);
      m.collect(Power.powerful);
      m.collect(Power.spread);
      for (var i = 0; i < 14; i++) {
        m.shots.add(Shot(40.0 + i * 22, 240.0 + (i % 5) * 40, 0, 70, hostile: true));
      }
      m.invulnerable = 0;
      m.hitPlayer();
      final life = <Uint8List>[];
      for (final t in [.08, .2, .4, .65]) {
        _run(m, t - (m.lifeLossElapsed));
        life.add(await _render(scene));
      }
      await _sheet('1-explosion', life);
      final regroup = <Uint8List>[];
      for (final t in [.78, .95, 1.4, 2.1]) {
        _run(m, t - m.lifeLossElapsed);
        regroup.add(await _render(scene));
      }
      await _sheet('2-regroup', regroup);
      final respawn = <Uint8List>[];
      for (final t in [2.36, 2.5, 2.7, 3.3]) {
        _run(m, t - m.lifeLossElapsed);
        respawn.add(await _render(scene));
      }
      await _sheet('3-respawn', respawn);

      // 2. Homing into the ground plane, at a far unit.
      final h = _live(3);
      final hs = await _scene(h);
      hs.environment = 2;
      h.demons
        ..clear()
        ..add(Demon(40, 60, 0, 99, 0));
      h.ground
        ..units.clear()
        ..front = GroundFront.none;
      final u = GroundUnit(900, 2, 1, .45, 1150, hp: 99);
      h.ground.units.add(u);
      h.invulnerable = 0; // the ship stays visible (no protection blink)
      h.collectHoming();
      final arc = <Uint8List>[];
      _run(h, .14);
      for (final p in [.2, .45, .7, .92]) {
        for (var i = 0; i < 200; i++) {
          final missile = h.ground.homing;
          if (missile == null || missile.groundProgress >= p) break;
          h.update(dt);
        }
        arc.add(await _render(hs));
      }
      for (var i = 0; i < 200 && !u.destroyed; i++) {
        h.update(dt);
      }
      _run(h, .25);
      arc.add(await _render(hs));
      await _sheet('4-homing-arc', arc);

      // 3. Live ground war: the convoy, skirmishes and effects (Hollow, Ember).
      for (final sector in [2, 4, 3]) {
        final g = _live(sector, route: 1);
        final gs = await _scene(g);
        gs.environment = sector - 1.0;
        final frames = <Uint8List>[];
        for (var k = 0; k < 5; k++) {
          g.invulnerable = 99;
          _run(g, k == 0 ? 8 : 5);
          frames.add(await _render(gs));
        }
        await _sheet('5-live-sector$sector', frames);
      }
    });
  });
}
