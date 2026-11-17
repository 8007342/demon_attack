@Tags(['review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/insignia_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// dive-shield-thinning review (openspec/changes/dive-shield-thinning): real
/// in-game frames from the real scene with the in-game atlases loaded.
///
/// `--dart-define=DST_TAG=before` (run on c7b5ffde, the code before the change) writes
/// one tile per case and zoom to `.cache/dst/before/`; the default `after`
/// run writes `.cache/dst/after/`, then lays out the sheet
/// `art/contact/dive-shield-thinning.png` (with `DST_CONTACT=true`):
///
/// - one row per case: small 1/1; not-so-small 2/2, 1/2; elite 3/3, 2/3,
///   1/3; sentinel dive shield 5/5, 3/5, 1/5; sentinel rush shield 8/8,
///   4/8, 1/8;
/// - columns: zoom 0.6, 1.0 and 1.5, each as a before | after pair.
///
/// `DST_SHOT=gif` writes the frames of an elite's dive with three hits and
/// a sentinel's dive with hits to `.cache/dst/gif/` (encoded to
/// `art/contact/dive-shield-thinning-dive.gif` by `tools/gifstrip`).
const _root = '.cache/dst';
const _contact = bool.fromEnvironment('DST_CONTACT');
const _tag = String.fromEnvironment('DST_TAG', defaultValue: 'after');
const _only = String.fromEnvironment('DST_SHOT');

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
  scene.silhouetteAtlas = await _decode(
    'assets/images/${SentinelSilhouetteAtlas.file}',
  );
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.insignia.image = await _decode('assets/images/${InsigniaAtlas.file}');
  scene.groundForces
    ..image = await _decode('assets/images/${GroundAtlas.file}')
    ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}');
  await scene.atmosphere.load();
  scene.atmosphere.groundArt = GroundAtmosphereArt(
    await _decode('assets/images/${GroundAtmosphereAtlas.file}'),
  );
  scene.environment = m.level - 1.0;
  return scene;
}

ArcadeModel _bare() {
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

/// The arena (360 × 520) painted at 2× and the [crop] (arena units) cut out.
Future<ui.Image> _tile(DemonScene scene, Rect crop) async {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 720, 1040),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(canvas, Vector2(720, 1040), alignY: 0);
  final pic = rec.endRecording();
  final full = await pic.toImage(720, 1040);
  pic.dispose();
  final src = Rect.fromLTRB(
    crop.left * 2,
    crop.top * 2,
    crop.right * 2,
    crop.bottom * 2,
  );
  final rec2 = ui.PictureRecorder();
  ui.Canvas(rec2).drawImageRect(
    full,
    src,
    Rect.fromLTWH(0, 0, src.width, src.height),
    Paint(),
  );
  final pic2 = rec2.endRecording();
  final out = await pic2.toImage(src.width.round(), src.height.round());
  pic2.dispose();
  full.dispose();
  return out;
}

Future<void> _png(ui.Image image, String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
}

typedef _Case = ({String name, bool big, Demon Function() make});

Demon _diver(int kind, int hp, int pts, int max, {bool elite = false}) =>
    Demon(180, 230, kind, hp, 1.3, elite: elite)
      ..dive = 1
      ..vy = 0
      ..diveShieldMax = max
      ..diveShield = pts;

Demon _sentinel(int pts, int max) =>
    Demon(
        180,
        230,
        0,
        9,
        .7,
        archetype: EnemyArchetype.shieldSentinel,
        shieldMax: 4,
      )
      ..dive = 1
      ..diveShieldMax = max
      ..diveShield = pts;

Demon _rush(int pts, int max) =>
    Demon(
        180,
        230,
        0,
        9,
        .7,
        archetype: EnemyArchetype.shieldSentinel,
        shieldMax: 4,
      )
      ..lastStand = true
      ..rushing = true
      ..rushPhase = RushPhase.rush
      ..rushShieldMax = max
      ..rushShield = pts;

final List<_Case> _cases = [
  (name: 'small-1of1', big: false, make: () => _diver(0, 1, 1, 1)),
  (name: 'medium-2of2', big: false, make: () => _diver(2, 3, 2, 2)),
  (name: 'medium-1of2', big: false, make: () => _diver(2, 3, 1, 2)),
  (name: 'elite-3of3', big: false, make: () => _diver(3, 4, 3, 3, elite: true)),
  (name: 'elite-2of3', big: false, make: () => _diver(3, 4, 2, 3, elite: true)),
  (name: 'elite-1of3', big: false, make: () => _diver(3, 4, 1, 3, elite: true)),
  (name: 'sentinel-5of5', big: true, make: () => _sentinel(5, 5)),
  (name: 'sentinel-3of5', big: true, make: () => _sentinel(3, 5)),
  (name: 'sentinel-1of5', big: true, make: () => _sentinel(1, 5)),
  (name: 'rush-8of8', big: true, make: () => _rush(8, 8)),
  (name: 'rush-4of8', big: true, make: () => _rush(4, 8)),
  (name: 'rush-1of8', big: true, make: () => _rush(1, 8)),
];

const _zooms = [.6, 1.0, 1.5];

Future<void> _tiles() async {
  final m = _bare();
  final scene = await _scene(m);
  for (final k in _cases) {
    for (final z in _zooms) {
      m.demons
        ..clear()
        ..add(
          k.make()
            ..scale = z
            ..nearness = 1,
        );
      for (var t = 0; t < 6; t++) {
        scene.creatures.update(m, 1 / 60);
        m.clock += 1 / 60;
      }
      final half = k.big ? 110.0 : 50.0;
      final img = await _tile(
        scene,
        Rect.fromCenter(
          center: const Offset(180, 230),
          width: half * 2,
          height: half * 2,
        ),
      );
      await _png(img, '$_root/$_tag/${k.name}-z$z.png');
      img.dispose();
    }
  }
}

/// The before | after sheet: one row per case, a pair per zoom.
Future<void> _sheet() async {
  const cell = 150.0, gap = 6.0, pair = 2;
  final cols = _zooms.length * pair;
  final w = gap + cols * (cell + gap) + gap * 2;
  final h = gap + _cases.length * (cell + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF16141F),
  );
  final loaded = <ui.Image>[];
  for (final (r, k) in _cases.indexed) {
    for (final (zi, z) in _zooms.indexed) {
      for (final (pi, tag) in const ['before', 'after'].indexed) {
        final f = File('$_root/$tag/${k.name}-z$z.png');
        if (!f.existsSync()) continue;
        final img = await _decode(f.path);
        loaded.add(img);
        final x = gap + (zi * pair + pi) * (cell + gap) + zi * gap;
        final y = gap + r * (cell + gap);
        c.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          Rect.fromLTWH(x, y, cell, cell),
          Paint()..filterQuality = FilterQuality.medium,
        );
        // A thin strip marks the pair: grey before, gold after.
        c.drawRect(
          Rect.fromLTWH(x, y + cell - 3, cell, 3),
          Paint()
            ..color = tag == 'before'
                ? const Color(0xFF5A5A66)
                : const Color(0xFFFFC23A),
        );
      }
    }
  }
  final pic = rec.endRecording();
  final sheet = await pic.toImage(w.round(), h.round());
  pic.dispose();
  for (final i in loaded) {
    i.dispose();
  }
  await _png(sheet, '$_root/dive-shield-thinning.png');
  if (_contact) await _png(sheet, 'art/contact/dive-shield-thinning.png');
  sheet.dispose();
}

/// Frames of two dives with hits, cropped around each diver.
Future<void> _gif() async {
  final m = _bare();
  final scene = await _scene(m);
  final elite = _diver(3, 4, 3, 3, elite: true)
    ..x = 120
    ..y = 120
    ..targetX = 150
    ..scale = .8;
  final sentinel = _sentinel(5, 5)
    ..x = 250
    ..y = 110
    ..targetX = 240
    ..scale = .8;
  m.demons.addAll([elite, sentinel]);
  m.powerTimers[Power.powerful] = 99;
  var frame = 0;
  for (var f = 0; f < 90 && frame < 200; f++) {
    for (final d in m.demons) {
      // The perspective zoom of the dive: the divers grow as they near.
      d.nearness = 1;
      d.scale = (.8 + f / 90 * .7 * 16).round() / 16;
    }
    if (f % 24 == 12) {
      if (m.demons.contains(elite)) m.hitDemon(elite);
      if (m.demons.contains(sentinel)) m.hitDemon(sentinel);
    }
    m.invulnerable = 5;
    scene.advancePresentation(1 / 60);
    m.update(1 / 60);
    scene.creatures.update(m, 1 / 60);
    m.takeEvents();
    m.takeGameEvents();
    for (final d in [elite, sentinel]) {
      d.dive = math.max(d.dive, 1);
    }
    if (f % 2 != 0) continue;
    final img = await _tile(scene, const Rect.fromLTWH(30, 40, 300, 360));
    await _png(img, '$_root/gif/${(frame++).toString().padLeft(3, '0')}.png');
    img.dispose();
  }
}

void main() {
  testWidgets('dive-shield-thinning review sheet', (tester) async {
    await tester.runAsync(() async {
      if (_only.isEmpty || _only == 'tiles') await _tiles();
      if (_tag == 'after' && (_only.isEmpty || _only == 'tiles')) {
        await _sheet();
      }
      if (_tag == 'after' && _only == 'gif') await _gif();
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
