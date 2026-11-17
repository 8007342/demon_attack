@Tags(['review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/bonus/levels/storm_cell.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:demon_attack/game/weather/lightning_painter.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show reach;

/// lightning-rework review sheets (openspec/changes/lightning-rework,
/// plan/render-runs/lightning-rework.md). Off by default; tagged `review`:
/// `flutter test --concurrency=1 --run-skipped --tags review
/// test/lightning_rework_review_test.dart` (through the test lock) writes
/// - art/contact/lightning-rework-rods.png: the three rod-armour
///   candidates (shoulders, crest, crown) on a hunter and a sentinel in the
///   real scene, cold and charged, at phone size and at 3x, with the rank
///   glyphs drawn, so the pick can be judged against the insignia;
/// - art/contact/lightning-rework-storm.png: a Stormfront strip, the tell on
///   the ship with its static, the bolt stunning a column (the fall, the
///   tumble and the crackle), the ship's zap with its modules blown off,
///   the climb back, and the reduced-motion frames.
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
  await scene.atmosphere.load();
  scene.atmosphere.reducedMotion = reduced;
  scene.environment = m.level - 1.0;
  m.reducedMotion = reduced;
  return scene;
}

void _step(ArcadeModel m, DemonScene scene, {bool protect = true}) {
  if (protect) m.invulnerable = 5;
  scene.advancePresentation(1 / 60);
  m.update(1 / 60);
  scene.creatures.update(m, 1 / 60);
  m.takeEvents();
  m.takeGameEvents();
}

Future<ui.Image> _frame(DemonScene scene) async {
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

/// The arena rect of a phone frame.
Rect get _arena {
  final k = math.min(_w / ArcadeModel.width, _h / ArcadeModel.height);
  return Rect.fromLTWH(
    (_w - ArcadeModel.width * k) / 2,
    (_h - ArcadeModel.height * k) / 2,
    ArcadeModel.width * k,
    ArcadeModel.height * k,
  );
}

/// Frame [i]'s [src] (arena units) drawn into [dst].
void _blit(ui.Canvas c, ui.Image frame, Rect src, Rect dst) {
  final a = _arena, k = a.width / ArcadeModel.width;
  c.drawImageRect(
    frame,
    Rect.fromLTWH(
      a.left + src.left * k,
      a.top + src.top * k,
      src.width * k,
      src.height * k,
    ),
    dst,
    Paint()..filterQuality = FilterQuality.none,
  );
}

Future<void> _png(ui.Image image, String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List(),
  );
}

/// A sector-4 model, route 2, with a hand-placed line-up: two hunters and
/// a sentinel wearing rods (the right-hand ones charged), and an ordinary
/// skirmisher and drone for scale.
ArcadeModel _lineup() {
  final m = ArcadeModel(seed: 7)..startAt(sector: 4, route: 2);
  reach(m, RunMode.playing);
  m.demons.clear();
  m.incoming.clear();
  Demon at(Demon d) => d
    ..homeX = d.x
    ..homeY = d.y;
  m.demons.addAll([
    at(Demon(70, 150, 1, 2, 1.1, elite: true))..lightningRods = true,
    at(Demon(150, 150, 2, 2, 2.3, elite: true))
      ..lightningRods = true
      ..charged = 4,
    at(Demon(250, 140, 0, 5, 3.1, archetype: EnemyArchetype.shieldSentinel))
      ..lightningRods = true
      ..charged = 4,
    at(Demon(90, 250, 2, 3, 4.7)),
    at(Demon(160, 250, 0, 1, 5.3)),
  ]);
  return m;
}

void main() {
  test('rod armour candidates', () async {
    final frames = <ui.Image>[];
    for (final style in RodStyle.values) {
      LightningPainter.rodStyle = style;
      final m = _lineup();
      final scene = await _scene(m);
      for (var f = 0; f < 20; f++) {
        _step(m, scene);
        for (final d in m.demons) {
          if (d.charged > 0) d.charged = 4;
        }
      }
      frames.add(await _frame(scene));
    }
    LightningPainter.rodStyle = LightningPainter.pick;
    // One column per candidate: the line-up at phone size, then the hunter
    // pair and the sentinel at 3x.
    const gap = 6.0, colW = 300.0;
    const top = Rect.fromLTWH(20, 90, 300, 220);
    const pair = Rect.fromLTWH(40, 115, 140, 70);
    const big = Rect.fromLTWH(200, 80, 100, 110);
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    const sheetW = gap + 3 * (colW + gap);
    const sheetH = gap + 220 + gap + 150 + gap + 330 + gap;
    c.drawRect(
      const Rect.fromLTWH(0, 0, sheetW, sheetH),
      Paint()..color = const Color(0xFF101218),
    );
    for (var i = 0; i < frames.length; i++) {
      final x = gap + i * (colW + gap);
      _blit(c, frames[i], top, Rect.fromLTWH(x, gap, colW, 220));
      _blit(c, frames[i], pair, Rect.fromLTWH(x, gap * 2 + 220, colW, 150));
      _blit(c, frames[i], big, Rect.fromLTWH(x, gap * 3 + 370, colW, 330));
    }
    final sheet = await rec.endRecording().toImage(
      sheetW.round(),
      sheetH.round(),
    );
    await _png(sheet, 'art/contact/lightning-rework-rods.png');
    sheet.dispose();
    for (final f in frames) {
      f.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('the storm strip', () async {
    final shots = <ui.Image>[];
    for (final reduced in [false, true]) {
      final m = ArcadeModel(seed: 1982)
        ..startAt(sector: 3, route: 1, bonus: 'stormfront');
      final scene = await _scene(m, reduced: reduced);
      reach(m, RunMode.playing);
      final mech = m.bonusMechanic! as StormfrontMechanic;
      for (var f = 0; f < 600 && m.demons.every((d) => d.entering); f++) {
        _step(m, scene);
      }
      // Wait for a tell on the ship, standing under the swarm with powers.
      StormStrike? s;
      for (var f = 0; f < 3600 && s == null; f++) {
        _step(m, scene);
        for (final t in mech.cell.strikes) {
          if (t.telling && t.aim == StrikeAim.ship) s = t;
        }
      }
      expect(s, isNotNull);
      final present = m.demons.where((d) => !d.entering).take(3).toList();
      var shot = 0;
      final wanted = reduced
          ? const [40, 75, 120]
          : const [20, 40, 62, 72, 84, 100, 130, 160];
      for (var f = 0; f < 200; f++) {
        if (s!.telling) {
          for (final (i, d) in present.indexed) {
            d.x = s.x + (i - 1) * 14;
          }
          m.powerTimers[Power.shield] = 9;
          m.powerTimers[Power.spread] = 9;
          m.powerTimers[Power.rapid] = 9;
          m
            ..shipX = s.x
            ..targetX = s.x;
        }
        m.invulnerable = 0;
        // Nobody shoots in the strip: the stunned creatures stay on show.
        m.shots.clear();
        _step(m, scene, protect: false);
        if (shot < wanted.length && f == wanted[shot]) {
          shots.add(await _frame(scene));
          shot++;
        }
      }
    }
    // Frames of the arena's middle and lower band, in a row of six.
    const cols = 6, gap = 4.0, cw = 240.0, ch = 368.0;
    const src = Rect.fromLTWH(30, 60, 300, 460);

    final rows = (shots.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    final sw = gap + cols * (cw + gap), sh = gap + rows * (ch + gap);
    c.drawRect(
      Rect.fromLTWH(0, 0, sw, sh),
      Paint()..color = const Color(0xFF101218),
    );
    for (var i = 0; i < shots.length; i++) {
      _blit(
        c,
        shots[i],
        src,
        Rect.fromLTWH(
          gap + (i % cols) * (cw + gap),
          gap + (i ~/ cols) * (ch + gap),
          cw,
          ch,
        ),
      );
    }
    final sheet = await rec.endRecording().toImage(sw.round(), sh.round());
    await _png(sheet, 'art/contact/lightning-rework-storm.png');
    sheet.dispose();
    for (final f in shots) {
      f.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
