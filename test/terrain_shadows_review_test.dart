@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:demon_attack/game/shadow_projector.dart';
import 'package:demon_attack/game/terrain_field.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Terrain-shadows review strips (openspec/changes/terrain-shadows task
/// 4.2, design §5), every in-game atlas loaded, phone portrait 360 x 780
/// and landscape 1280 x 720:
/// - relief: Hollow and Ringfall with a swarm overhead, flat | draped;
/// - morph: shadows across ridges and crests while the terrain blends from
///   one sector to the next;
/// - diver: a diver converging over a ridge;
/// - lurk: the sentinel's lurking shadow along its track, and its hand-off;
/// - boss: the boss shadow at two altitudes.
/// Frames go to `$TERRAIN_SHADOWS_REVIEW_DIR` (default
/// .cache/terrain-shadows-review). With `--dart-define=
/// TERRAIN_SHADOWS_CONTACT=true` the sheets are also written to
/// art/contact/terrain-shadows-*.png (tracked review evidence).
const _dir = String.fromEnvironment(
  'TERRAIN_SHADOWS_REVIEW_DIR',
  defaultValue: '.cache/terrain-shadows-review',
);
const _contact = bool.fromEnvironment('TERRAIN_SHADOWS_CONTACT');

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel m, int sector) async {
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
  scene.groundForces
    ..image = await _decode('assets/images/${GroundAtlas.file}')
    ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}')
    ..blocks.install(sector - 1, {
      for (final f in GroundBlocksLayer.files(sector - 1))
        f.substring('ground-blocks/'.length): await _decode('assets/images/$f'),
    });
  await scene.atmosphere.load();
  scene.atmosphere.groundArt = GroundAtmosphereArt(
    await _decode('assets/images/${GroundAtmosphereAtlas.file}'),
  );
  scene.environment = sector - 1.0;
  return scene;
}

void _run(
  ArcadeModel m,
  DemonScene scene,
  double seconds, {
  void Function()? each,
}) {
  for (var t = 0.0; t < seconds - 1e-9; t += 1 / 60) {
    m.invulnerable = 5;
    each?.call();
    scene.sectors.advance(1 / 60, m, scene.environment);
    m.update(1 / 60);
    scene.creatures.update(m, 1 / 60);
    scene.syncAtmosphere(1 / 60);
    m.takeEvents();
    m.takeGameEvents();
    m.shots.removeWhere((s) => !s.hostile);
  }
}

Future<ui.Image> _frame(DemonScene scene, double w, double h) async {
  scene.model.invulnerable = 0;
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

/// Tiles [frames] (each [src] of its image) [cols] wide at [scale], with a
/// progress tick and an optional label bar colour per frame.
Future<void> _sheet(
  List<ui.Image> frames,
  String name, {
  required Rect src,
  int cols = 6,
  double scale = .5,
  List<Color>? marks,
}) async {
  const gap = 4.0;
  final fw = src.width * scale, fh = src.height * scale;
  final rows = (frames.length / cols).ceil();
  final sw = gap + cols * (fw + gap), sh = gap + rows * (fh + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, sw, sh),
    Paint()..color = const Color(0xFF101218),
  );
  for (var i = 0; i < frames.length; i++) {
    final x = gap + (i % cols) * (fw + gap);
    final y = gap + (i ~/ cols) * (fh + gap);
    c.drawImageRect(
      frames[i],
      src,
      Rect.fromLTWH(x, y, fw, fh),
      Paint()..filterQuality = FilterQuality.medium,
    );
    c.drawRect(
      Rect.fromLTWH(x, y, fw * (i + 1) / frames.length, 2),
      Paint()..color = marks?[i] ?? const Color(0xFF3FA36B),
    );
  }
  final pic = rec.endRecording();
  final sheet = await pic.toImage(sw.round(), sh.round());
  await _png(sheet, '$_dir/$name.png');
  if (_contact) await _png(sheet, 'art/contact/terrain-shadows-$name.png');
  sheet.dispose();
  for (final f in frames) {
    f.dispose();
  }
}

ArcadeModel _combat(int sector, {int route = 1, int wave = 1, int seed = 7}) =>
    ArcadeModel(seed: seed)..startAt(
      difficulty: Difficulty.normal,
      sector: sector,
      route: route,
      wave: wave,
    );

/// One shadow pass, as every painted game frame runs (the lurk and its
/// hand-off are tracked by the pass).
void _tick(DemonScene scene) {
  final rec = ui.PictureRecorder();
  scene.paintShadowPass(ui.Canvas(rec));
  rec.endRecording().dispose();
}

/// The shadow pass alone over the terrain mesh on grey (arena 360 x 520):
/// where every shadow lies on the relief, readable whatever the ground's
/// palette. [stage] temporarily poses casters for the frame.
Future<ui.Image> _diag(DemonScene scene, {void Function()? stage}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    const Rect.fromLTWH(0, 0, 360, 520),
    Paint()..color = const Color(0xFFB4B8C0),
  );
  final t = scene.sectors.flyover.relief..prepare();
  final line = Paint()
    ..color = const Color(0xFF6A88B8)
    ..strokeWidth = .6;
  for (var i = 0; i < TerrainView.rows; i += 2) {
    for (var j = 0; j < TerrainView.columns - 1; j++) {
      c.drawLine(
        Offset(j * TerrainView.columnStep, t.vertexY(i, j)),
        Offset((j + 1) * TerrainView.columnStep, t.vertexY(i, j + 1)),
        line,
      );
    }
  }
  stage?.call();
  scene.paintShadowPass(c);
  final pic = rec.endRecording();
  final img = await pic.toImage(360, 520);
  pic.dispose();
  return img;
}

/// Poses up to [count] fighting creatures as a row of far casters over the
/// relief band (flat-ground y 250-330), restoring them afterwards.
void Function() _farRow(ArcadeModel m, {int count = 12}) {
  final saved = <Demon, (double, double, double, double)>{};
  final row = m.demons.where((d) => !d.isLarge && !d.entering).take(count);
  var i = 0;
  for (final d in row) {
    saved[d] = (d.x, d.nearness, d.altitude, d.entranceProgress);
    d
      ..x = 22 + (i % 6) * 63.0
      ..nearness = (i < 6 ? 250.0 : 315.0) / 348 - 172 / 348 + .0
      ..altitude = 40 + 12.0 * (i % 3);
    i++;
  }
  return () {
    for (final e in saved.entries) {
      e.key
        ..x = e.value.$1
        ..nearness = e.value.$2
        ..altitude = e.value.$3
        ..entranceProgress = e.value.$4;
    }
  };
}

/// Captures a real frame and a diagnostic frame of [scene].
Future<void> _pair(
  DemonScene scene,
  List<ui.Image> real,
  List<ui.Image> diag, {
  bool farRow = false,
}) async {
  real.add(await _frame(scene, 360, 780));
  if (!farRow) {
    diag.add(await _diag(scene));
    return;
  }
  void Function()? restore;
  diag.add(await _diag(scene, stage: () => restore = _farRow(scene.model)));
  restore?.call();
}

/// One sheet: the real frames (ground band [band], full scale) above the
/// diagnostic frames (same band).
Future<void> _twoRows(
  List<ui.Image> real,
  List<ui.Image> diag,
  String name, {
  required Rect band,
}) async {
  const gap = 4.0;
  final n = real.length;
  final fw = band.width, fh = band.height;
  final sw = gap + n * (fw + gap), sh = gap + 2 * (fh + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, sw, sh),
    Paint()..color = const Color(0xFF101218),
  );
  for (var i = 0; i < n; i++) {
    final x = gap + i * (fw + gap);
    c.drawImageRect(
      real[i],
      band.shift(const Offset(0, 130)),
      Rect.fromLTWH(x, gap, fw, fh),
      Paint(),
    );
    c.drawImageRect(
      diag[i],
      band,
      Rect.fromLTWH(x, gap * 2 + fh, fw, fh),
      Paint(),
    );
    c.drawRect(
      Rect.fromLTWH(x, gap, fw * (i + 1) / n, 2),
      Paint()..color = const Color(0xFF3FA36B),
    );
  }
  final pic = rec.endRecording();
  final sheet = await pic.toImage(sw.round(), sh.round());
  await _png(sheet, '$_dir/$name.png');
  if (_contact) await _png(sheet, 'art/contact/terrain-shadows-$name.png');
  sheet.dispose();
  for (final f in [...real, ...diag]) {
    f.dispose();
  }
}

Future<void> _wide(DemonScene scene, String name) async {
  final wide = await _frame(scene, 1280, 720);
  await _sheet(
    [wide],
    name,
    src: const Rect.fromLTWH(0, 0, 1280, 720),
    cols: 1,
    scale: 1,
  );
}

/// A model at its sector's first sentinel wave ([before]: the wave before,
/// whose foreshadow lasts the whole wave).
ArcadeModel _sentinelWave(int sector, {bool before = false}) {
  final probe = _combat(sector, route: 1);
  var w = 2;
  while (probe.sentinelFor(w) == null) {
    w++;
  }
  return _combat(sector, route: 1, wave: before ? w - 1 : w);
}

void main() {
  testWidgets('terrain shadows review strips', (tester) async {
    await tester.runAsync(() async {
      // (1) Relief: Hollow and Ringfall with a swarm overhead; each pair is
      // flat then draped (alternating columns), full-scale ground band.
      // Below: the pass over the mesh, with a row of far casters posed
      // over the relief band.
      {
        final real = <ui.Image>[], diag = <ui.Image>[];
        for (final (sector, route) in const [(4, 1), (2, 2)]) {
          final m = _combat(sector, route: route);
          final scene = await _scene(m, sector);
          _run(m, scene, 7);
          for (var i = 0; i < 2; i++) {
            if (i > 0) _run(m, scene, 1.6);
            for (final mode in [ShadowMode.flat, ShadowMode.draped]) {
              scene.shadowModeOverride = mode;
              void Function()? restore;
              diag.add(await _diag(scene, stage: () => restore = _farRow(m)));
              restore?.call();
              real.add(await _frame(scene, 360, 780));
            }
          }
          scene.shadowModeOverride = null;
          if (sector == 4) await _wide(scene, 'relief-wide');
        }
        await _twoRows(
          real,
          diag,
          'relief',
          band: const Rect.fromLTWH(0, 60, 360, 400),
        );
      }
      // (2) Morph: the terrain blends from Ringfall to Ember under the
      // swarm and a posed row of far casters (environment 1 -> 2).
      {
        final m = _combat(2, route: 2);
        final scene = await _scene(m, 2);
        _run(m, scene, 7);
        final real = <ui.Image>[], diag = <ui.Image>[];
        for (var i = 0; i < 8; i++) {
          scene.environment = 1 + i / 7;
          _run(m, scene, .1);
          await _pair(scene, real, diag, farRow: true);
        }
        await _twoRows(
          real,
          diag,
          'morph',
          band: const Rect.fromLTWH(0, 60, 360, 400),
        );
      }
      // (3) A diver converging on the ship over the relief.
      {
        final m = _combat(3, route: 2);
        final scene = await _scene(m, 3);
        _run(m, scene, 7);
        m.shipX = m.targetX = 120;
        final diver = m.demons.firstWhere((d) => !d.isLarge && !d.entering);
        diver
          ..dive = .3
          ..targetX = m.shipX;
        final real = <ui.Image>[], diag = <ui.Image>[];
        for (var i = 0; i < 8; i++) {
          if (i > 0) {
            _run(
              m,
              scene,
              .15,
              each: () {
                if (diver.dive <= 0) diver.dive = .3;
              },
            );
          }
          await _pair(scene, real, diag);
        }
        await _twoRows(
          real,
          diag,
          'diver',
          band: const Rect.fromLTWH(0, 200, 360, 320),
        );
      }
      // (4) The lurking shadow at 0 / 25 / 50 / 75 / 100 % of its track,
      // then its hand-off as the sentinel rises.
      {
        final m = _sentinelWave(2, before: true);
        final scene = await _scene(m, 2);
        final real = <ui.Image>[], diag = <ui.Image>[];
        var next = 0;
        for (var f = 0; f < 60 * 40 && next < 5; f++) {
          _run(m, scene, 1 / 60);
          _tick(scene);
          final p = m.foreshadow?.lurk.progress;
          if (p == null || scene.lurkCenter == null) continue;
          if (p >= next / 4 - 1e-9) {
            await _pair(scene, real, diag);
            next++;
          }
        }
        expect(next, 5, reason: 'the lurk reached the front');
        await _wide(scene, 'lurk-wide');
        await _twoRows(
          real,
          diag,
          'lurk',
          band: const Rect.fromLTWH(0, 0, 360, 360),
        );
        final h = _sentinelWave(2);
        final hs = await _scene(h, 2);
        final hr = <ui.Image>[], hd = <ui.Image>[];
        var handed = -1;
        for (var f = 0; f < 60 * 30 && hr.length < 8; f++) {
          _run(h, hs, 1 / 60);
          _tick(hs);
          final s = h.demons.where((d) => d.isLarge).firstOrNull;
          if (handed < 0 && s != null && s.entranceProgress > 0) handed = f;
          final at = handed < 0 ? -1 : f - handed;
          // Two frames before, then every 0.15 s through the hand-off.
          if ((handed < 0 && hs.lurkCenter != null && f % 90 == 0) ||
              (at >= 0 && at % 9 == 0)) {
            await _pair(hs, hr, hd);
            if (handed < 0 && hr.length > 2) {
              hr.removeAt(0).dispose();
              hd.removeAt(0).dispose();
            }
          }
        }
        await _twoRows(
          hr,
          hd,
          'lurk-handoff',
          band: const Rect.fromLTWH(0, 0, 360, 360),
        );
      }
      // (5) The boss shadow at its default altitude and climbing (160,
      // 240, 320).
      {
        final m = _combat(5, route: 0);
        final scene = await _scene(m, 5);
        scene.armada.setAtlas(
          0,
          await _decode('assets/images/boss-frigate.png'),
        );
        _run(m, scene, 2);
        for (final d in List.of(m.demons)) {
          m.demons.remove(d);
        }
        m.boss = Carrier(0)..x = 170;
        final real = <ui.Image>[], diag = <ui.Image>[];
        for (final alt in const [160.0, 240.0, 320.0]) {
          scene.bossShadowAltitude = alt;
          _run(m, scene, .5);
          await _pair(scene, real, diag);
        }
        scene.bossShadowAltitude = DemonScene.defaultBossShadowAltitude;
        await _wide(scene, 'boss-wide');
        await _twoRows(
          real,
          diag,
          'boss',
          band: const Rect.fromLTWH(0, 0, 360, 520),
        );
      }
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
