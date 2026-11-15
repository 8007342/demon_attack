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
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Continuous-swarm review frames (openspec/changes/continuous-swarm task
/// 8.1), phone portrait (360 x 780) with every in-game atlas loaded:
/// single frames and motion strips (frames over time tiled in one PNG) of
/// the reserve in the fog, a streamed arrival, the fighting patterns, an
/// agitation wave, a cohort merge in the lull, a diver and its shadow, a
/// re-entry from a deep gate, the sentinel's rise and the reduced tier.
/// Frames go to `$CONTINUOUS_SWARM_REVIEW_DIR` (default
/// .cache/continuous-swarm-review). With `--dart-define=
/// CONTINUOUS_SWARM_CONTACT=true` the strips are also written to
/// art/contact/continuous-swarm-*.png (tracked review evidence).
const _dir = String.fromEnvironment(
  'CONTINUOUS_SWARM_REVIEW_DIR',
  defaultValue: '.cache/continuous-swarm-review',
);
const _contact = bool.fromEnvironment('CONTINUOUS_SWARM_CONTACT');
const _w = 360.0, _h = 780.0;

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
      'assets/images/sector-${i + 1}.png',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.png');
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

/// Steps model and scene together. [fire]: keep the player's shots.
void _run(
  ArcadeModel m,
  DemonScene scene,
  double seconds, {
  bool fire = false,
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
    if (!fire) m.shots.removeWhere((s) => !s.hostile);
  }
}

Future<ui.Image> _frame(DemonScene scene) async {
  scene.model.invulnerable = 0; // no protection blink on review frames
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _w, _h),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(canvas, Vector2(_w, _h));
  final picture = recorder.endRecording();
  final image = await picture.toImage(_w.round(), _h.round());
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

Future<void> _single(DemonScene scene, String name) async {
  final image = await _frame(scene);
  await _png(image, '$_dir/$name.png');
  image.dispose();
}

/// [count] frames [interval] s apart, tiled [cols] wide at [scale], the
/// arena rows [top]..[bottom] only; a time stamp bar on each.
Future<void> _strip(
  ArcadeModel m,
  DemonScene scene,
  String name, {
  int count = 12,
  double interval = .25,
  int cols = 6,
  double scale = .5,
  double top = 0,
  double bottom = _h,
  bool fire = false,
  void Function()? each,
}) async {
  final frames = <ui.Image>[];
  for (var i = 0; i < count; i++) {
    if (i > 0) _run(m, scene, interval, fire: fire, each: each);
    frames.add(await _frame(scene));
  }
  const gap = 4.0;
  final fw = _w * scale, fh = (bottom - top) * scale;
  final rows = (count / cols).ceil();
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
      Rect.fromLTWH(0, top, _w, bottom - top),
      Rect.fromLTWH(x, y, fw, fh),
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Progress tick: frame i of count.
    c.drawRect(
      Rect.fromLTWH(x, y, fw * (i + 1) / count, 2),
      Paint()..color = const Color(0xFF3FA36B),
    );
  }
  final pic = rec.endRecording();
  final sheet = await pic.toImage(sw.round(), sh.round());
  await _png(sheet, '$_dir/strip-$name.png');
  if (_contact) await _png(sheet, 'art/contact/continuous-swarm-$name.png');
  sheet.dispose();
  for (final f in frames) {
    f.dispose();
  }
}

ArcadeModel _combat(int sector, {int route = 1, int wave = 1, int seed = 7}) {
  final m = ArcadeModel(seed: seed)
    ..startAt(
      difficulty: Difficulty.normal,
      sector: sector,
      route: route,
      wave: wave,
    );
  return m;
}

void main() {
  testWidgets('continuous swarm review frames', (tester) async {
    await tester.runAsync(() async {
      // An arrival stream: wave 1 cleared at once, wave 2 streams in skein
      // by skein out of the fog (12 frames over 3 s).
      {
        final m = _combat(2);
        final scene = await _scene(m, 2);
        _run(m, scene, 6);
        m.flocksSpawned = m.flocksPlanned;
        for (final d in List.of(m.demons)) {
          m.hitDemon(d, damage: 99);
        }
        m.shipX = m.targetX = 150;
        _run(m, scene, .2);
        await _single(scene, 'reserve-in-fog');
        await _strip(
          m,
          scene,
          'arrival',
          count: 12,
          interval: .25,
          cols: 4,
          scale: .6,
          top: 130,
          bottom: 650,
        );
        await _single(scene, 'skein-mid-swoop');
      }
      // The fight: squads milling, ribboning and sweeping (12 frames over
      // 6 s), and a longer look (12 frames over 24 s) for state changes.
      {
        final m = _combat(2, wave: 2);
        final scene = await _scene(m, 2);
        _run(m, scene, 8);
        m.shipX = m.targetX = 200;
        await _strip(
          m,
          scene,
          'fight',
          count: 12,
          interval: .5,
          cols: 4,
          scale: .6,
          top: 130,
          bottom: 650,
        );
        await _strip(
          m,
          scene,
          'fight-long',
          count: 12,
          interval: 2,
          cols: 4,
          scale: .6,
          top: 130,
          bottom: 650,
        );
        await _single(scene, 'fight');

      }
    });
  });
}
