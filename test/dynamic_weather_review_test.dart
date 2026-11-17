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
import 'package:demon_attack/game/weather/rain_plan.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// dynamic-weather review sheets: drizzle, rain and downpour over two
/// sectors (with a dry frame for reference), the same downpour with
/// reduced motion, and a fade-in strip. Every frame is the whole phone
/// portrait viewport (360 x 780), so the band above the arena shows; every
/// in-game atlas is loaded and the fight is live (creatures, the ship,
/// shots).
///
/// Sheets go to `$WEATHER_REVIEW_DIR` (default .cache/dynamic-weather);
/// with `--dart-define=WEATHER_CONTACT=true` also to
/// art/contact/dynamic-weather-{tiers,reduced,fade}.png.
const _dir = String.fromEnvironment(
  'WEATHER_REVIEW_DIR',
  defaultValue: '.cache/dynamic-weather',
);
const _contact = bool.fromEnvironment('WEATHER_CONTACT');
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

const _tiers = {
  'drizzle': RainSpec(tier: RainTier.drizzle, peak: .26, wind: -.08),
  'rain': RainSpec(tier: RainTier.rain, peak: .56, wind: .16),
  'downpour': RainSpec(tier: RainTier.downpour, peak: .95, wind: .3),
};

/// A live fight in [sector] with [spec] forced, after [seconds].
Future<(ui.Image, Map<String, int>)> _shot(
  int sector,
  RainSpec? spec, {
  bool reduced = false,
  double seconds = 6,
}) async {
  final m = ArcadeModel(seed: 11)..startAt(sector: sector, wave: 2);
  final scene = await _scene(m, reduced: reduced);
  scene.rain.override = spec;
  for (var f = 0; f < 60 * 10 && m.mode != RunMode.playing; f++) {
    _step(m, scene);
  }
  for (var f = 0; f < (seconds * 60).round(); f++) {
    m.moveTo(180 + 90 * (f % 240 < 120 ? 1 : -1) * .6);
    _step(m, scene);
  }
  final image = await _frame(scene);
  return (
    image,
    {
      'far': scene.rain.lastFar,
      'near': scene.rain.lastNear,
      'splashes': scene.rain.lastSplashes,
    },
  );
}

void main() {
  testWidgets('dynamic weather review sheets', (tester) async {
    final counts = <String, Map<String, int>>{};
    await tester.runAsync(() async {
      await _loadFonts();
      final tiers = <(String, ui.Image)>[];
      final reduced = <(String, ui.Image)>[];
      for (final sector in [1, 3]) {
        final dry = await _shot(sector, null);
        tiers.add(('sector $sector: dry', dry.$1));
        for (final e in _tiers.entries) {
          final s = await _shot(sector, e.value);
          tiers.add(('sector $sector: ${e.key}', s.$1));
          await _png(s.$1, '$_dir/frames/s$sector-${e.key}.png');
          counts['s$sector ${e.key}'] = s.$2;
        }
        final r = await _shot(sector, _tiers['downpour'], reduced: true);
        reduced.add(('sector $sector: downpour, reduced', r.$1));
        counts['s$sector downpour reduced'] = r.$2;
      }
      final sheet = await _sheet(tiers);
      await _png(sheet, '$_dir/dynamic-weather-tiers.png');
      if (_contact) await _png(sheet, 'art/contact/dynamic-weather-tiers.png');
      final rsheet = await _sheet(reduced, cols: 2);
      await _png(rsheet, '$_dir/dynamic-weather-reduced.png');
      if (_contact) {
        await _png(rsheet, 'art/contact/dynamic-weather-reduced.png');
      }

      // Fade-in: rain begins 2 s into the level and builds over 8 s.
      const fadeSpec = RainSpec(
        tier: RainTier.rain,
        peak: .6,
        wind: .18,
        startAt: 2,
        rampIn: 8,
      );
      final m = ArcadeModel(seed: 11)..startAt(sector: 2, wave: 2);
      final scene = await _scene(m);
      scene.rain.override = fadeSpec;
      for (var f = 0; f < 60 * 10 && m.mode != RunMode.playing; f++) {
        _step(m, scene);
      }
      final fade = <(String, ui.Image)>[];
      final at = [1.5, 3.5, 5.5, 7.5, 9.5, 12.5];
      var next = 0;
      final start = m.levelClock;
      for (var f = 0; f < 60 * 20 && next < at.length; f++) {
        if (m.levelClock - start >= at[next]) {
          final k = scene.rain.amount.toStringAsFixed(2);
          fade.add(('t ${at[next]} s, rain $k', await _frame(scene)));
          next++;
        }
        m.moveTo(180 + 54 * (f % 240 < 120 ? 1 : -1));
        _step(m, scene);
      }
      final fsheet = await _sheet(fade, cols: 6, cell: 200);
      await _png(fsheet, '$_dir/dynamic-weather-fade.png');
      if (_contact) await _png(fsheet, 'art/contact/dynamic-weather-fade.png');
      for (final s in [sheet, rsheet, fsheet]) {
        s.dispose();
      }
      for (final f in [...tiers, ...reduced, ...fade]) {
        f.$2.dispose();
      }
      expect(fade.length, at.length);
    });
    // ignore: avoid_print
    print('dynamic-weather review counts: $counts');
    expect(counts['s1 downpour']!['far'], greaterThan(100));
    expect(counts['s1 downpour reduced']!['splashes'], 0);
  });
}
