import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Review renders of the ground war. PNGs land in GROUND_REVIEW_DIR
/// (default .cache/ground-review): one sheet per staged moment, columns are
/// sectors 1-4, at 1x arena size (phone scale). Pass
/// `--dart-define=GROUND_REVIEW_DIR=dir` to write elsewhere.
const _out = String.fromEnvironment('GROUND_REVIEW_DIR', defaultValue: '.cache/ground-review');

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

ArcadeModel _stage(int sector) {
  final m = ArcadeModel(seed: 7)..start();
  m.level = sector + 1;
  m.mode = RunMode.playing;
  m.demons.clear();
  m.shots.clear();
  m.invulnerable = 0;
  m.ground.clearField();
  m.shipX = m.targetX = 180;
  return m;
}

GroundUnit _unit(ArcadeModel m, int sector, int side, double across, double z) {
  final u = GroundUnit(m.ground.nextId++, sector, side, across, z);
  m.ground.units.add(u);
  return u;
}

GroundAlly _ally(ArcadeModel m, GroundUnit foe) {
  final a = GroundAlly(m.ground.nextId++, foe.sector, foe.side,
      foe.across < .5 ? foe.across + .35 : foe.across - .35,
      foe.z - GroundTuning.allyLead, 5)
    ..attacker = foe
    ..announced = true;
  foe.ally = a;
  m.ground.allies.add(a);
  return a;
}

void main() {
  testWidgets('ground war review renders, every sector', (tester) async {
    await tester.runAsync(() async {
      final moments = <String, List<Uint8List>>{};
      for (var sector = 0; sector < 4; sector++) {
        final m = _stage(sector);
        final scene = await _scene(m);
        scene.environment = sector.toDouble();
        scene.sectors.flyover.distance = 800 + sector * 300.0;
        Future<void> shot(String name) async =>
            (moments[name] ??= []).add(await _render(scene));

        // 1. Approach: small and dim at the horizon, growing toward the ship.
        final far = _unit(m, sector, 0, .5, 1350);
        final mid = _unit(m, sector, 1, .4, 800);
        _ally(m, mid);
        final near = _unit(m, sector, 0, .6, 480);
        await shot('1-approach');

        // 2. Telegraph: the near unit raises its launcher; the skirmish
        // trades tracers.
        near.z = 360;
        near.telegraph = GroundTuning.telegraph * .3;
        m.ground.tracers
          ..add(GroundTracer(mid.x, mid.bodyY, mid.ally!.x, mid.ally!.bodyY)
            ..age = .1)
          ..add(GroundTracer(mid.ally!.x, mid.ally!.bodyY, mid.x, mid.bodyY,
              friendly: true)
            ..age = .05);
        await shot('2-telegraph');

        // 3. Missiles growing toward the ship (launch, mid-flight, plane).
        near.telegraph = 0;
        near.fireFlash = .2;
        m.ground.tracers.clear();
        for (final t in [.06, .5, .93]) {
          final missile = GroundMissile(near.x + 8, near.bodyY, 180 + (t - .5) * 120,
              GroundTuning.missileFlight, sector)
            ..age = GroundTuning.missileFlight * t;
          m.ground.missiles.add(missile);
        }
        await shot('3-missiles');

        // 4. Homing lock-on: the rack has fired one; the reticle sits on the
        // most threatening unit.
        m.ground.missiles.clear();
        near.fireFlash = 0;
        near.telegraph = GroundTuning.telegraph * .6;
        m.ground.salvo.remaining = 2;
        m.ground.salvo.active =
            HomingMissile(150, 390, 120, -260, -1)
              ..age = .4
              ..target = near
              ..kind = HomingTargetKind.ground;
        m.ground.pickups.add(HomingPickup(250, 300));
        await shot('4-homing-lock');

        // 5. Hit: the unit erupts into a ground explosion and scorch; the
        // saved ally rolls on.
        m.ground.salvo
          ..active = null
          ..remaining = 1;
        m.ground.pickups.clear();
        near.destroyed = true;
        near.wreckAge = .2;
        mid.destroyed = true;
        mid.wreckAge = 1.2;
        await shot('5-hit');

        // 6. An overwhelmed ally is totalled: it limps off smoking; another
        // crew ejects in a pod. Allies never die.
        final limping = _ally(m, far)
          ..z = 700
          ..totalled = true
          ..retreatAge = .9;
        final podFoe = _unit(m, sector, 1, .5, 900);
        if (m.ground.nextId.isEven) m.ground.nextId++; // an ejecting crew
        final pod = _ally(m, podFoe)
          ..z = 560
          ..totalled = true
          ..retreatAge = .7;
        expect(pod.ejects, isTrue);
        expect(limping.alive || pod.alive, isFalse);
        await shot('6-ally-retreat');
        expect(far.alive, isTrue);
      }
      for (final e in moments.entries) {
        await _sheet(e.key, e.value);
      }
    });
  });
}
