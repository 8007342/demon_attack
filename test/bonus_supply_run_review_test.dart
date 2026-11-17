@Tags(['review'])
library;

import 'dart:io';
import 'dart:math' as math;
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

import 'progression_test.dart' show clearWave, reach;

/// Supply Run review strips (openspec/changes/bonus-levels task 6.1): the
/// bonus level end to end at phone portrait (360 x 780, the arena cropped
/// from the letterbox), with every in-game atlas loaded.
///
/// - `bonus-level-a-story`: 12 frames, sector 1's last kill to the arrival
///   in sector 3: the fog transition in, the graded arrival, crates on
///   parachutes, a crate shot open, the two bonus powers beside the ship,
///   wave 2, the last kill, the fog transition out.
/// - `bonus-level-a-look`: sectors 2-4 as they are (top) and as the bonus
///   level grades them (bottom).
///
/// Checked while rendering: the grade is fully on through the level and
/// fully off outside it, and it only ever changes under cloud cover of at
/// least 85 % (the swap is hidden); the graded frame differs measurably
/// from the plain one but stays as bright or brighter.
///
/// Sheets go to `$BONUS_REVIEW_DIR` (default .cache/bonus-levels-review);
/// with `--dart-define=BONUS_CONTACT=true` also to art/contact/.
const _dir = String.fromEnvironment(
  'BONUS_REVIEW_DIR',
  defaultValue: '.cache/bonus-levels-review',
);
const _contact = bool.fromEnvironment('BONUS_CONTACT');
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
  return scene;
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

/// The 360 × 520 arena inside a [w] × [h] frame (paintArena, centred).
Rect _arena(double w, double h) {
  final k = math.min(w / ArcadeModel.width, h / ArcadeModel.height);
  final aw = ArcadeModel.width * k, ah = ArcadeModel.height * k;
  return Rect.fromLTWH((w - aw) / 2, (h - ah) / 2, aw, ah);
}

Future<ui.Image> _sheet(List<ui.Image> frames, {int cols = 6}) async {
  const gap = 4.0, cell = 240.0;
  const fh = cell * ArcadeModel.height / ArcadeModel.width;
  final rows = (frames.length / cols).ceil();
  final sw = gap + cols * (cell + gap), sh = gap + rows * (fh + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, sw, sh),
    Paint()..color = const Color(0xFF101218),
  );
  for (var i = 0; i < frames.length; i++) {
    c.drawImageRect(
      frames[i],
      _arena(_w, _h),
      Rect.fromLTWH(
        gap + (i % cols) * (cell + gap),
        gap + (i ~/ cols) * (fh + gap),
        cell,
        fh,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  return rec.endRecording().toImage(sw.round(), sh.round());
}

Future<void> _save(ui.Image sheet, String name) async {
  await _png(sheet, '$_dir/bonus-level-a-$name.png');
  if (_contact) await _png(sheet, 'art/contact/bonus-level-a-$name.png');
}

/// Mean linear-ish RGB of the arena (0-255 per channel).
Future<(double, double, double)> _mean(ui.Image image) async {
  final data = (await image.toByteData())!;
  final r = _arena(_w, _h);
  var sr = 0.0, sg = 0.0, sb = 0.0, n = 0;
  for (var y = r.top.round(); y < r.bottom.round(); y += 3) {
    for (var x = r.left.round(); x < r.right.round(); x += 3) {
      final o = (y * image.width + x) * 4;
      sr += data.getUint8(o);
      sg += data.getUint8(o + 1);
      sb += data.getUint8(o + 2);
      n++;
    }
  }
  return (sr / n, sg / n, sb / n);
}

class _Story {
  _Story(this.m, this.scene);
  final ArcadeModel m;
  final DemonScene scene;
  final frames = <ui.Image>[];

  /// The cloud cover whenever the grade was part-way (it must be hidden).
  double leastCloudWhileFading = 1;
  bool safe = true;

  void step() {
    if (safe) m.invulnerable = 5;
    scene.advancePresentation(1 / 60);
    m.update(1 / 60);
    scene.creatures.update(m, 1 / 60);
    m.takeEvents();
    m.takeGameEvents();
    final a = scene.bonusLook.amount;
    if (a > 0 && a < 1) {
      leastCloudWhileFading = math.min(
        leastCloudWhileFading,
        m.flow.env('cloud'),
      );
    }
  }

  void run(double seconds) {
    for (var i = 0; i < seconds * 60; i++) {
      step();
    }
  }

  bool until(bool Function() done, {double limit = 40}) {
    for (var i = 0; i < limit * 60; i++) {
      if (done()) return true;
      step();
    }
    return done();
  }

  Future<void> shoot() async {
    final image = await _frame(scene, _w, _h);
    frames.add(image);
    final n = frames.length.toString().padLeft(2, '0');
    await _png(image, '$_dir/frames/story-$n.png');
  }

  void killAll() {
    for (final d in List<Demon>.of(m.demons)) {
      if (d.entering) continue;
      for (var guard = 0; guard < 1000 && m.demons.contains(d); guard++) {
        m.hitDemon(d);
      }
    }
  }
}

Future<_Story> _storyboard() async {
  final m = ArcadeModel(seed: 11)
    ..startAt(sector: 1, wave: ArcadeModel.wavesFor(sector: 1, route: 0));
  // This run's bonus level: sector 2 becomes the Supply Run.
  m.bonusRun
    ..seed = 11
    ..plan = BonusPlan.forced(supplyRun, route: 0, sector: 2);
  final scene = await _scene(m);
  final s = _Story(m, scene);
  reach(m, RunMode.playing);
  s.run(3);
  expect(scene.bonusLook.amount, 0);
  clearWave(m);
  expect(m.mode, RunMode.salvage);
  expect(m.bonusAhead?.id, 'supplyRun');
  // 1-3: the way in is the ordinary fog transition.
  s.until(() => m.mode == RunMode.travel);
  s.run(1.2);
  await s.shoot(); // 1 pursuit: climbing into the cloud
  s.until(() => m.flow.env('cloud') >= .97, limit: 10);
  await s.shoot(); // 2 inside the cloud (the swap)
  s.until(() => m.mode == RunMode.transition && m.level == 2, limit: 12);
  expect(m.bonus?.id, 'supplyRun');
  s.until(() => m.flow.env('cloud') < .45, limit: 8);
  await s.shoot(); // 3 descent: the graded sector appears
  s.until(() => m.combat, limit: 10);
  expect(scene.bonusLook.amount, 1);
  // 4: arrival; the ship keeps to the left so crates gather.
  m.moveTo(40);
  s.run(1.9);
  await s.shoot(); // 4 first crate, scavengers
  // 5: several crates in the air (one of each bonus power shown).
  m.supplyCrates
    ..add(SupplyCrate(250, 150, Power.shield, bonus: salvageMagnet))
    ..add(SupplyCrate(150, 96, Power.shield, bonus: doubleScore));
  s.run(.6);
  await s.shoot(); // 5 crates on parachutes
  // 6: shoot the magnet crate open; its badge falls.
  final crate = m.supplyCrates.firstWhere((c) => c.bonus == salvageMagnet);
  m.moveTo(crate.x);
  s.until(() => !m.supplyCrates.contains(crate), limit: 6);
  s.run(.25);
  await s.shoot(); // 6 crate burst, bonus badge falling
  // 7: catch it; then the coin crate.
  s.until(() => m.hasBonusPower('salvageMagnet'), limit: 8);
  final coins = m.supplyCrates.where((c) => c.bonus == doubleScore);
  if (coins.isNotEmpty) {
    final c2 = coins.first;
    m.moveTo(c2.x);
    s.until(() => !m.supplyCrates.contains(c2), limit: 6);
  }
  s.run(.5);
  await s.shoot(); // 7 magnet on, coins falling toward the ship
  s.until(() => m.hasBonusPower('doubleScore'), limit: 6);
  m.pickups
    ..add(Pickup(80, 330, Power.rapid))
    ..add(Pickup(300, 360, Power.spread));
  s.run(.35);
  await s.shoot(); // 8 both bonus powers beside the ship, pickups pulled in
  // 9: wave 2.
  s.until(() {
    s.killAll();
    return m.wave == 2 || !m.combat;
  });
  m.moveTo(200);
  s.run(2.4);
  await s.shoot(); // 9 the second scavenger wave
  // 10: the last kill: leftover crates burst, the Rout begins.
  s.until(() {
    s.killAll();
    return m.mode == RunMode.salvage;
  });
  expect(m.bonusRun.award, greaterThan(0));
  s.run(.3);
  await s.shoot(); // 10 last kill
  // 11-12: the way out is the ordinary fog transition.
  s.until(() => m.mode == RunMode.travel);
  s.until(() => m.flow.env('cloud') >= .6, limit: 10);
  expect(scene.bonusLook.amount, 1, reason: 'the grade holds into the cloud');
  await s.shoot(); // 11 pursuit out
  s.until(() => m.mode == RunMode.transition && m.level == 3, limit: 12);
  expect(m.bonus, isNull);
  s.until(() => m.combat, limit: 10);
  s.run(1);
  expect(scene.bonusLook.amount, 0);
  await s.shoot(); // 12 sector 3, as it is
  return s;
}

Future<List<ui.Image>> _looks(List<double> shift) async {
  final plain = <ui.Image>[], graded = <ui.Image>[];
  for (final sector in const [2, 3, 4]) {
    for (final bonus in const [false, true]) {
      final m = ArcadeModel(seed: 11)
        ..startAt(sector: sector, bonus: bonus ? 'supplyRun' : null);
      final scene = await _scene(m);
      reach(m, RunMode.playing);
      m.bonusRun.crateLeft = 1e9;
      for (var i = 0; i < 90; i++) {
        m.invulnerable = 5;
        scene.advancePresentation(1 / 60);
        m.update(1 / 60);
        scene.creatures.update(m, 1 / 60);
      }
      (bonus ? graded : plain).add(await _frame(scene, _w, _h));
    }
    final (r0, g0, b0) = await _mean(plain.last);
    final (r1, g1, b1) = await _mean(graded.last);
    shift
      ..add((r1 - r0).abs() + (g1 - g0).abs() + (b1 - b0).abs())
      ..add((r1 + g1 + b1) - (r0 + g0 + b0));
  }
  return [...plain, ...graded];
}

void main() {
  testWidgets('Supply Run review strips at phone size', (tester) async {
    late _Story story;
    final shift = <double>[];
    await tester.runAsync(() async {
      story = await _storyboard();
      final sheet = await _sheet(story.frames);
      await _save(sheet, 'story');
      final looks = await _looks(shift);
      await _save(await _sheet(looks, cols: 3), 'look');
    });
    // ignore: avoid_print
    print(
      'bonus-level-a review: ${story.frames.length} frames; least cloud '
      'while the grade fades ${story.leastCloudWhileFading.toStringAsFixed(2)}; '
      'colour shift / brightness gain per sector '
      '${shift.map((v) => v.toStringAsFixed(1)).join(', ')}',
    );
    expect(story.frames.length, 12);
    expect(story.leastCloudWhileFading, greaterThanOrEqualTo(.85));
    for (var i = 0; i < shift.length; i += 2) {
      expect(shift[i], greaterThan(6), reason: 'the grade must show');
      expect(shift[i + 1], greaterThanOrEqualTo(0), reason: 'never darker');
    }
  });
}
