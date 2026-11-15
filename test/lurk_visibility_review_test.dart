import 'dart:io';
import 'dart:typed_data';
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

/// Lurk-visibility review (openspec/changes/terrain-shadows, follow-up):
/// the sentinel's lurking shadow in real phone frames (360 x 780, every
/// atlas loaded) on the darkest sectors, 0.5 to 10 s after it appears, and
/// the same last frame without it. Prints the core darkening (mean luma
/// inside the footprint's core, with vs without) and asserts a floor.
/// Sheets go to `$TERRAIN_SHADOWS_REVIEW_DIR` (default
/// .cache/terrain-shadows-review); with `--dart-define=
/// TERRAIN_SHADOWS_CONTACT=true` also to art/contact/terrain-shadows-*.png.
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

ArcadeModel _combat(int sector, {int route = 1, int wave = 1, int seed = 7}) =>
    ArcadeModel(seed: seed)..startAt(
      difficulty: Difficulty.normal,
      sector: sector,
      route: route,
      wave: wave,
    );

void _tick(DemonScene scene) {
  final rec = ui.PictureRecorder();
  scene.paintShadowPass(ui.Canvas(rec));
  rec.endRecording().dispose();
}

Future<Uint8List> _rgba(ui.Image i) async =>
    (await i.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
        .asUint8List();

/// Mean luma (0-255) of [px] inside the ellipse [r] (arena units; the
/// frame letterboxes the arena at y 130).
double _luma(Uint8List px, Rect r) {
  var sum = 0.0, n = 0;
  for (var y = r.top.floor(); y <= r.bottom.ceil(); y++) {
    for (var x = r.left.floor(); x <= r.right.ceil(); x++) {
      final dx = (x - r.center.dx) / (r.width / 2);
      final dy = (y - r.center.dy) / (r.height / 2);
      if (dx * dx + dy * dy > 1 || x < 0 || x >= 360) continue;
      final i = ((y + 130) * 360 + x) * 4;
      sum += .2126 * px[i] + .7152 * px[i + 1] + .0722 * px[i + 2];
      n++;
    }
  }
  return n == 0 ? 0 : sum / n;
}

const _times = [.5, 1.0, 1.5, 2.0, 4.0, 7.0, 10.0];

void main() {
  testWidgets('lurk visibility on the darkest sectors', (tester) async {
    await tester.runAsync(() async {
      final rows = <List<ui.Image>>[];
      final report = StringBuffer();
      final darkening = <(int, double, double)>[];
      for (final sector in const [4, 3, 1, 2]) {
        final probe = _combat(sector);
        var w = 2;
        while (w <= probe.wavesPerLevel && probe.sentinelFor(w) == null) {
          w++;
        }
        if (w > probe.wavesPerLevel) continue;
        final m = _combat(sector, wave: w - 1);
        final scene = await _scene(m, sector);
        final frames = <ui.Image>[];
        double? born;
        var t = 0.0, next = 0;
        Rect? core;
        for (var f = 0; f < 60 * 40 && next < _times.length; f++) {
          _run(m, scene, 1 / 60);
          _tick(scene);
          t += 1 / 60;
          if (born == null && (m.foreshadow?.visible ?? false)) born = t;
          if (born == null || t - born < _times[next]) continue;
          final img = await _frame(scene, 360, 780);
          final cover = scene.lurkCover;
          if (cover != null) {
            core = Rect.fromCenter(
              center: cover.center,
              width: cover.width * .5,
              height: cover.height * .5,
            );
            scene.drawLurk = false;
            final off = await _frame(scene, 360, 780);
            scene.drawLurk = true;
            final a = _luma(await _rgba(img), core);
            final b = _luma(await _rgba(off), core);
            report.writeln(
              'sector $sector t ${_times[next]}s: core luma '
              '${b.toStringAsFixed(1)} -> ${a.toStringAsFixed(1)} '
              '(${((1 - a / b) * 100).toStringAsFixed(0)} % darker)',
            );
            if (next == _times.length - 1) {
              frames.add(img);
              frames.add(off);
              next++;
              continue;
            }
            off.dispose();
            // A player notices it within two seconds of it appearing.
            if (_times[next] >= 1.5) {
              darkening.add((sector, _times[next], 1 - a / b));
            }
          }
          frames.add(img);
          next++;
        }
        expect(core, isNotNull, reason: 'sector $sector lurk drawn');
        rows.add(frames);
      }
      // ignore: avoid_print
      print(report);
      // One row per sector: the times above, then the last without it;
      // the arena's upper 400 units at phone scale.
      const band = Rect.fromLTWH(0, 130, 360, 400), gap = 4.0;
      final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      final sw = gap + cols * (band.width + gap);
      final sh = gap + rows.length * (band.height + gap);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(
        Rect.fromLTWH(0, 0, sw, sh),
        Paint()..color = const Color(0xFF101218),
      );
      for (var r = 0; r < rows.length; r++) {
        for (var i = 0; i < rows[r].length; i++) {
          final x = gap + i * (band.width + gap);
          final y = gap + r * (band.height + gap);
          c.drawImageRect(
            rows[r][i],
            band,
            Rect.fromLTWH(x, y, band.width, band.height),
            Paint(),
          );
          final last = i == rows[r].length - 1;
          c.drawRect(
            Rect.fromLTWH(x, y, band.width * (i + 1) / rows[r].length, 2),
            Paint()
              ..color = last
                  ? const Color(0xFF8A8F99)
                  : const Color(0xFF3FA36B),
          );
          rows[r][i].dispose();
        }
      }
      final pic = rec.endRecording();
      final sheet = await pic.toImage(sw.round(), sh.round());
      await _png(sheet, '$_dir/lurk-visibility.png');
      if (_contact) {
        await _png(sheet, 'art/contact/terrain-shadows-lurk-visibility.png');
      }
      sheet.dispose();
      // From 1.5 s on, the core is on average over 30 % darker in every
      // sector (single frames dip where creatures fly over it or a nearer
      // crest hides it).
      for (final sector in {for (final d in darkening) d.$1}) {
        final ds = [
          for (final d in darkening)
            if (d.$1 == sector) d.$3,
        ];
        final mean = ds.reduce((a, b) => a + b) / ds.length;
        expect(mean, greaterThan(.3), reason: 'sector $sector');
      }
    });
  }, timeout: const Timeout(Duration(minutes: 10)));
}
