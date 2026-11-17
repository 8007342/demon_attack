@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/insignia_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// alien-insignia review strips (openspec/changes/alien-insignia, design
/// §7): the real scene with the real atlases, each shot at phone portrait
/// 360 × 780 and landscape 1280 × 720, plus a 2x close-up of the phone
/// frame's action band (the left third of each strip).
///
/// - formation: drones, skirmishers, veterans, hunters and a sentinel;
/// - shields: sentinel shield 5/5 and 3/5 with a break (white cells, then
///   shards), the rush-shield arc, segmented dive shields, the carrier's
///   hull cells;
/// - states: wound warm-up by molt, angry, the dive tell.
///
/// Frames go to `$ALIEN_INSIGNIA_DIR` (default .cache/alien-insignia-review).
/// With `--dart-define=ALIEN_INSIGNIA_CONTACT=true` the strips are also
/// written to `art/contact/alien-insignia-ingame-<shot>.png`.
const _dir = String.fromEnvironment(
  'ALIEN_INSIGNIA_DIR',
  defaultValue: '.cache/alien-insignia-review',
);
const _contact = bool.fromEnvironment('ALIEN_INSIGNIA_CONTACT');

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel m) async {
  final scene = DemonScene(m, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(
      'assets/images/sector-${i + 1}.webp',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.webp');
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.insignia.image = await _decode('assets/images/${InsigniaAtlas.file}');
  await scene.atmosphere.load();
  scene.environment = 1;
  return scene;
}

ArcadeModel _model() {
  final m = ArcadeModel(seed: 11)..startAt(sector: 2, route: 1);
  m
    ..mode = RunMode.playing
    ..invulnerable = 0
    ..clock = 3;
  m.demons.clear();
  m.incoming.clear();
  m.shots.clear();
  return m;
}

Demon _flier(
  double x,
  double y,
  int kind,
  int maxHp, {
  int? hp,
  bool elite = false,
  double seed = 0,
}) {
  final d = Demon(x, y, kind, maxHp, seed, elite: elite);
  if (hp != null) d.hp = hp;
  return d;
}

/// Lets the presentation trackers see the frame (motion, shield memory).
/// Every creature is placed in the clear near air (nearness 1).
void _settle(DemonScene scene, ArcadeModel m, [double seconds = 1 / 60]) {
  for (final d in m.demons) {
    d.nearness = 1;
  }
  for (var t = 0.0; t < seconds - 1e-9; t += 1 / 60) {
    scene.creatures.update(m, 1 / 60);
  }
}

Future<ui.Image> _frame(DemonScene scene, double w, double h) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(canvas, Vector2(w, h));
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.round(), h.round());
  picture.dispose();
  return image;
}

Future<void> _png(ui.Image image, String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
}

/// One strip: phone 360 × 780, a 2x close-up of the phone arena's band
/// [bandTop, bandTop + 200) and the 1280 × 720 frame.
Future<void> _strip(DemonScene scene, String shot, double bandTop) async {
  final phone = await _frame(scene, 360, 780);
  final wide = await _frame(scene, 1280, 720);
  // The 2x close-up: the phone arena is bottom-centred? No: paintArena
  // centres it (alignY .5): 360 x 520 at scale 1, offset (780-520)/2.
  final zr = ui.PictureRecorder();
  final zc = ui.Canvas(zr)
    ..scale(2)
    ..translate(0, -(130 + bandTop));
  scene.paintArena(zc, Vector2(360, 780));
  final zp = zr.endRecording();
  final zoom = await zp.toImage(720, 400);
  zp.dispose();
  await _png(phone, '$_dir/$shot-360x780.png');
  await _png(wide, '$_dir/$shot-1280x720.png');
  await _png(zoom, '$_dir/$shot-zoom.png');

  const gap = 12.0;
  final w = gap + 360 + gap + 720 + gap + 1280 + gap;
  const h = gap + 780 + gap;
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF16141F),
  );
  c.drawImage(phone, const Offset(gap, gap), Paint());
  c.drawImage(zoom, const Offset(gap + 360 + gap, gap), Paint());
  c.drawImage(wide, const Offset(gap + 360 + gap + 720 + gap, gap), Paint());
  final pic = rec.endRecording();
  final sheet = await pic.toImage(w.round(), h.round());
  pic.dispose();
  await _png(sheet, '$_dir/alien-insignia-ingame-$shot.png');
  if (_contact) {
    await _png(sheet, 'art/contact/alien-insignia-ingame-$shot.png');
  }
  for (final i in [phone, wide, zoom, sheet]) {
    i.dispose();
  }
}

void main() {
  testWidgets('alien-insignia review strips', (tester) async {
    await tester.runAsync(() async {
      // --- formation: every rank, a dense pair, a sentinel.
      {
        final m = _model();
        final scene = await _scene(m);
        m.demons.addAll([
          _flier(50, 150, 0, 1, seed: 1),
          _flier(110, 140, 1, 2, seed: 2),
          _flier(170, 150, 2, 2, seed: 3), // skirmisher (kind 2)
          _flier(230, 140, 3, 3, seed: 4), // skirmisher (maxHp 3)
          _flier(300, 150, 1, 4, seed: 5), // veteran
          _flier(60, 220, 2, 5, seed: 6), // veteran
          _flier(130, 230, 0, 3, elite: true, seed: 7), // hunter
          _flier(200, 220, 3, 4, elite: true, seed: 8), // hunter
          _flier(260, 232, 0, 1, seed: 9),
          // A dense pair: the lower-rank glyph yields.
          _flier(318, 224, 2, 5, seed: 10),
          _flier(324, 216, 0, 3, seed: 11),
          Demon(
            180,
            70,
            1,
            12,
            0,
            archetype: EnemyArchetype.armoredSentinel,
            shieldMax: 4,
            armorMax: 4,
          ),
        ]);
        _settle(scene, m, .2);
        await _strip(scene, 'formation', 40);
      }

      // --- shields.
      {
        final m = _model();
        final scene = await _scene(m);
        final full = Demon(
          100,
          90,
          0,
          9,
          0,
          archetype: EnemyArchetype.shieldSentinel,
          shieldMax: 5,
        );
        final worn = Demon(
          260,
          90,
          1,
          12,
          1,
          archetype: EnemyArchetype.armoredSentinel,
          shieldMax: 5,
          armorMax: 4,
        );
        // Rushing sentinel with its rush shield 3/5.
        final rush =
            Demon(
                180,
                330,
                0,
                9,
                2,
                archetype: EnemyArchetype.shieldSentinel,
                shieldMax: 4,
              )
              ..shield = 0
              ..lastStand = true
              ..rushPhase = RushPhase.lock
              ..rushShieldMax = 5
              ..rushShield = 3;
        // Divers with segmented thermal shields.
        final diveSmall = _flier(60, 240, 0, 1, seed: 3)
          ..dive = 1
          ..diveShieldMax = 1
          ..diveShield = 1;
        final diveMid = _flier(150, 230, 2, 3, seed: 4)
          ..dive = 1
          ..diveShieldMax = 2
          ..diveShield = 1;
        final diveElite = _flier(300, 240, 3, 4, elite: true, seed: 5)
          ..dive = 1
          ..diveShieldMax = 3
          ..diveShield = 3;
        m.demons.addAll([full, worn, rush, diveSmall, diveMid, diveElite]);
        _settle(scene, m, .1);
        // Two hits on the worn sentinel and one on the elite's dive
        // shield: the cells flash white this frame.
        worn.shield = 3;
        diveElite.diveShield = 2;
        _settle(scene, m);
        await _strip(scene, 'shields-break', 30);
        // A moment later: sockets and falling shards (a painted frame after
        // the two white frames sheds them).
        _settle(scene, m, 2 / 60);
        await _frame(scene, 360, 780);
        _settle(scene, m, .1);
        await _strip(scene, 'shields', 30);

        // The carrier's hull cells (8/12 lit) and its form glyph.
        final k = 1;
        scene.armada.setAtlas(
          k,
          await _decode('assets/images/${BossAtlas.classes[k].asset}'),
        );
        m
          ..cycle = k
          ..demons.clear();
        final b = Carrier(k)
          ..x = 180
          ..y = 205;
        b.shield = (b.shieldMax * .6).round();
        m.boss = b;
        _settle(scene, m, .1);
        await _strip(scene, 'shields-carrier', 120);
      }

      // --- states: wound warm-up, angry, tell.
      {
        final m = _model();
        final scene = await _scene(m);
        for (final (i, kind) in [0, 1, 2, 3].indexed) {
          final y = 110.0 + i * 70;
          m.demons.addAll([
            _flier(50, y, kind, 4, seed: i * 5 + 1), // intact
            _flier(110, y, kind, 4, hp: 3, seed: i * 5 + 2), // molt 1
            _flier(170, y, kind, 4, hp: 2, seed: i * 5 + 3), // molt 2
            _flier(230, y, kind, 4, hp: 1, seed: i * 5 + 4), // angry
            _flier(300, y, kind, 4, seed: i * 5 + 5)..telegraph = .5, // tell
          ]);
        }
        _settle(scene, m, .1);
        await _strip(scene, 'states', 60);
      }
    });
  });
}
