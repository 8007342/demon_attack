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
import 'package:demon_attack/game/bonus/levels/crosswind_painter.dart';
import 'package:demon_attack/game/bonus/levels/wind_kites_atlas.dart';
import 'package:demon_attack/game/perf/frame_budget.dart';
import 'package:demon_attack/game/weather/rain_plan.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// crosswind review sheet (openspec/changes/crosswind design §7): calm,
/// breeze, gale, gale with rain, the Crosswind bonus level early and late,
/// a gale at the LITE tier and with reduced motion. Whole phone portrait
/// frames (360 x 780), every in-game atlas loaded, the fight live.
///
/// Sheets go to `$CROSSWIND_REVIEW_DIR` (default
/// ~/.cache/tillandsias-project/crosswind-review); with
/// `--dart-define=CROSSWIND_CONTACT=true` also to
/// art/contact/crosswind-sheet.png.
const _dir = String.fromEnvironment(
  'CROSSWIND_REVIEW_DIR',
  defaultValue: '/home/forge/.cache/tillandsias-project/crosswind-review',
);
const _contact = bool.fromEnvironment('CROSSWIND_CONTACT');
const _fonts = String.fromEnvironment(
  'WEATHER_FONTS',
  defaultValue: '/home/forge/.cache/tillandsias-project/tmp/fonts',
);

/// Labels in Roboto when the fonts are there (else the test font's boxes).
Future<void> _loadFonts() async {
  final dir = Directory(_fonts);
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
    final file = File('${dir.path}/$f');
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

const _w = 360.0, _h = 780.0;

Future<ui.Image> _decode(String file) async {
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<DemonScene> _scene(ArcadeModel m, {bool reduced = false}) async {
  final scene = DemonScene(m, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(
      'assets/images/sector-${i + 1}.webp',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = reduced;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.webp');
  scene.silhouetteAtlas = await _decode(
    'assets/images/${SentinelSilhouetteAtlas.file}',
  );
  scene.ship.image = await _decode('assets/images/ship-weapons.png');
  scene.groundForces
    ..image = await _decode('assets/images/${GroundAtlas.file}')
    ..troops = await _decode('assets/images/${GroundTroopsAtlas.file}');
  for (var s = 0; s < 5; s++) {
    scene.groundForces.blocks.install(s, {
      for (final f in GroundBlocksLayer.files(s))
        f.substring('ground-blocks/'.length): await _decode('assets/images/$f'),
    });
  }
  await scene.atmosphere.load();
  scene.atmosphere.groundArt = GroundAtmosphereArt(
    await _decode('assets/images/${GroundAtmosphereAtlas.file}'),
  );
  scene.atmosphere.reducedMotion = reduced;
  scene.environment = m.level - 1.0;
  m.reducedMotion = reduced;
  scene.rain.emit = (_) {};
  CrosswindPainter.image ??= await _decode(
    'assets/images/${WindKitesAtlas.file}',
  );
  return scene;
}

void _step(ArcadeModel m, DemonScene scene) {
  m.invulnerable = 5;
  scene.advancePresentation(1 / 60);
  m.update(1 / 60);
  scene.creatures.update(m, 1 / 60);
  m.takeEvents();
  m.takeGameEvents();
}

Future<ui.Image> _frame(DemonScene scene) async {
  scene.model.invulnerable = 0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _w, _h),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(canvas, Vector2(_w, _h), alignY: 1);
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

/// Whole phone frames, [cols] to a row, each at [cell] wide, with a label.
Future<ui.Image> _sheet(
  List<(String, ui.Image)> frames, {
  int cols = 4,
  double cell = 240,
}) async {
  const gap = 6.0, label = 18.0;
  final fh = cell * _h / _w;
  final rows = (frames.length / cols).ceil();
  final sw = gap + cols * (cell + gap);
  final sh = gap + rows * (fh + label + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, sw, sh),
    Paint()..color = const Color(0xFF101218),
  );
  for (var i = 0; i < frames.length; i++) {
    final x = gap + (i % cols) * (cell + gap);
    final y = gap + (i ~/ cols) * (fh + label + gap);
    final tp = TextPainter(
      text: TextSpan(
        text: frames[i].$1,
        style: const TextStyle(
          color: Color(0xFFE6E9F0),
          fontSize: 12,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: cell);
    tp.paint(c, Offset(x + 2, y + 2));
    c.drawImageRect(
      frames[i].$2,
      const Rect.fromLTWH(0, 0, _w, _h),
      Rect.fromLTWH(x, y + label, cell, fh),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  return rec.endRecording().toImage(sw.round(), sh.round());
}

/// A live fight in [sector] after [seconds]: [wind] forced (or the
/// Crosswind level with [bonus]), optionally with [rain], a forced [tier]
/// and reduced motion. Returns the frame and the wind layer's counts.
Future<(ui.Image, String)> _shot(
  int sector, {
  WindTier? wind,
  bool bonus = false,
  RainSpec? rain,
  PerfTier? tier,
  bool reduced = false,
  double seconds = 8,
}) async {
  final m = ArcadeModel(seed: 11)
    ..windRun.force = wind == null
        ? null
        : (r, s) => WindPlan.draw(77 + s, tier: wind);
  m.startAt(
    sector: sector,
    wave: 2,
    runSeed: bonus ? 5 : null,
    bonus: bonus ? 'crosswind' : null,
  );
  final scene = await _scene(m, reduced: reduced);
  scene.rain.override = rain;
  if (tier != null) {
    scene.perf.forced = tier;
    scene.applyBudget();
  }
  for (var f = 0; f < 60 * 10 && m.mode != RunMode.playing; f++) {
    _step(m, scene);
  }
  for (var f = 0; f < (seconds * 60).round(); f++) {
    m.moveTo(180 + 90 * (f % 240 < 120 ? 1 : -1) * .6);
    _step(m, scene);
  }
  final image = await _frame(scene);
  final w = scene.wind;
  return (
    image,
    'wind ${(w.lateral * w.amount).toStringAsFixed(2)} '
        'wisps ${w.lastWisps} billows ${w.lastBillows}',
  );
}

void main() {
  testWidgets('crosswind review sheet', (tester) async {
    final notes = <String>[];
    await tester.runAsync(() async {
      await _loadFonts();
      final frames = <(String, ui.Image)>[];
      Future<void> add(String label, Future<(ui.Image, String)> shot) async {
        final (image, note) = await shot;
        frames.add(('$label · $note', image));
        notes.add('$label: $note');
        await _png(image, '$_dir/frames/${frames.length}.png');
      }

      await add('calm s2', _shot(2));
      await add('breeze s3', _shot(3, wind: WindTier.breeze));
      await add('gale s2', _shot(2, wind: WindTier.gale));
      await add(
        'gale+rain s4',
        _shot(
          4,
          wind: WindTier.gale,
          rain: const RainSpec(tier: RainTier.rain, peak: .56, wind: .16),
        ),
      );
      await add('CROSSWIND 6 s', _shot(3, bonus: true, seconds: 6));
      await add('CROSSWIND 16 s', _shot(3, bonus: true, seconds: 16));
      await add(
        'gale LITE',
        _shot(2, wind: WindTier.gale, tier: PerfTier.lite),
      );
      await add('gale reduced', _shot(2, wind: WindTier.gale, reduced: true));
      final sheet = await _sheet(frames);
      await _png(sheet, '$_dir/crosswind-sheet.png');
      if (_contact) await _png(sheet, 'art/contact/crosswind-sheet.png');
      sheet.dispose();
      for (final f in frames) {
        f.$2.dispose();
      }
    });
    // ignore: avoid_print
    print('crosswind review: $notes');
    expect(notes.length, 8);
  });
}
