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

/// Transition-ascent review strips (openspec/changes/transition-ascent task
/// 5.1, design §5): a sector change 2 -> 3 in full and in reduced motion,
/// 12 frames across the plan, each rendered at phone portrait (360 x 780)
/// and landscape (1280 x 720) with every in-game atlas loaded. The sheet's
/// top two rows are the phone frames, the bottom two the landscape frames.
///
/// Checked per frame:
/// - the ship stays within [FlowPlan.ascentClimb] of its row;
/// - full motion: the horizon drops and near ground leaves first (the
///   pitch transform), the world banks, streaks are drawn in the Pursuit;
/// - reduced motion: no pitch, roll or streaks at any frame, speed ≤ ×2.
///
/// Sheets go to `$TRANSITION_ASCENT_REVIEW_DIR` (default
/// .cache/transition-ascent-review); with `--dart-define=
/// TRANSITION_ASCENT_CONTACT=true` also to
/// art/contact/transition-ascent-{full,reduced}.png.
const _dir = String.fromEnvironment(
  'TRANSITION_ASCENT_REVIEW_DIR',
  defaultValue: '.cache/transition-ascent-review',
);
const _contact = bool.fromEnvironment('TRANSITION_ASCENT_CONTACT');
const _sizes = [(360.0, 780.0), (1280.0, 720.0)];
const _frames = 12;

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
      'assets/images/sector-${i + 1}.png',
    );
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = reduced;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode('assets/images/cosmic-sky.png');
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

void _step(ArcadeModel m, DemonScene scene) {
  m.invulnerable = 5;
  scene.advancePresentation(1 / 60);
  m.update(1 / 60);
  scene.creatures.update(m, 1 / 60);
  m.takeEvents();
  m.takeGameEvents();
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

/// Two rows of six per size, each frame's arena at [cell] width (the
/// letterbox is cropped; both sizes keep the arena's 360:520 aspect).
Future<ui.Image> _sheet(Map<int, List<ui.Image>> bySize) async {
  const cols = 6, gap = 4.0, cell = 200.0;
  final heights = [
    for (var i = 0; i < _sizes.length; i++)
      cell * ArcadeModel.height / ArcadeModel.width,
  ];
  final rowsPer = (_frames / cols).ceil();
  var sh = gap;
  for (final h in heights) {
    sh += rowsPer * (h + gap);
  }
  final sw = gap + cols * (cell + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, sw, sh),
    Paint()..color = const Color(0xFF101218),
  );
  var top = gap;
  for (var s = 0; s < _sizes.length; s++) {
    final frames = bySize[s]!;
    final fh = heights[s];
    for (var i = 0; i < frames.length; i++) {
      final x = gap + (i % cols) * (cell + gap);
      final y = top + (i ~/ cols) * (fh + gap);
      c.drawImageRect(
        frames[i],
        _arena(_sizes[s].$1, _sizes[s].$2),
        Rect.fromLTWH(x, y, cell, fh),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    top += rowsPer * (fh + gap);
  }
  final pic = rec.endRecording();
  return pic.toImage(sw.round(), sh.round());
}

class _Seen {
  double pitch = 0, roll = 0, streaks = 0, speed = 0, rise = 0;
}

Future<_Seen> _review(String name, {required bool reduced}) async {
  final m = ArcadeModel(seed: 11)
    ..startAt(
      sector: 2,
      route: 1,
      wave: ArcadeModel.wavesFor(sector: 2, route: 1),
    );
  final scene = await _scene(m, reduced: reduced);
  reach(m, RunMode.playing);
  for (var i = 0; i < 240; i++) {
    _step(m, scene);
  }
  clearWave(m);
  expect(m.mode, RunMode.salvage);
  final seen = _Seen();
  final seconds = m.flow.plan.seconds;
  final steps = (seconds * 60).round();
  final every = steps / _frames;
  var next = 0.0;
  final bySize = {for (var s = 0; s < _sizes.length; s++) s: <ui.Image>[]};
  for (var i = 0; i <= steps; i++) {
    final flow = m.flow;
    if (flow.active) {
      seen
        ..pitch = math.max(seen.pitch, flow.env('pitch'))
        ..roll = math.max(seen.roll, flow.env('roll'))
        ..streaks = math.max(seen.streaks, flow.env('streaks'))
        ..speed = math.max(seen.speed, flow.plan.speedFactor(flow.env('speed')))
        ..rise = math.max(seen.rise, ArcadeModel.shipY - scene.flowShipAt().dy);
    }
    if (i >= next && bySize[0]!.length < _frames) {
      for (var s = 0; s < _sizes.length; s++) {
        final image = await _frame(scene, _sizes[s].$1, _sizes[s].$2);
        bySize[s]!.add(image);
        if (s == 0) {
          final n = bySize[s]!.length.toString().padLeft(2, '0');
          await _png(image, '$_dir/frames/$name-$n.png');
        }
      }
      next += every;
    }
    if (i < steps) _step(m, scene);
  }
  final sheet = await _sheet(bySize);
  await _png(sheet, '$_dir/transition-ascent-$name.png');
  if (_contact) await _png(sheet, 'art/contact/transition-ascent-$name.png');
  sheet.dispose();
  for (final list in bySize.values) {
    for (final f in list) {
      f.dispose();
    }
  }
  return seen;
}

void main() {
  test('the pitch drops the horizon and near ground leaves first', () {
    for (final q in const [.25, .5, 1.0]) {
      const h = 172.0;
      // The horizon drops by 96·q.
      expect(DemonScene.pitchedRow(h, q), closeTo(h + 96 * q, 1e-9));
      // Near rows move further than far rows.
      final far = DemonScene.pitchedRow(220, q) - 220;
      final near = DemonScene.pitchedRow(500, q) - 500;
      expect(near, greaterThan(far), reason: 'q $q');
      // The sky above the horizon only translates.
      expect(DemonScene.pitchedRow(40, q) - 40, closeTo(96 * q, 1e-9));
    }
    expect(DemonScene.pitchedRow(300, 0), 300);
    // The bank is at most 3° and follows the pursuit's side.
    expect(DemonScene.worldRoll(1, 1), closeTo(3 * math.pi / 180, 1e-12));
    expect(DemonScene.worldRoll(1, -1), lessThan(0));
  });

  testWidgets('transition ascent review strips, full and reduced motion', (
    tester,
  ) async {
    late _Seen full, reduced;
    await tester.runAsync(() async {
      full = await _review('full', reduced: false);
      reduced = await _review('reduced', reduced: true);
    });
    // ignore: avoid_print
    print(
      'transition-ascent review: full pitch ${full.pitch.toStringAsFixed(2)} '
      'roll ${full.roll.toStringAsFixed(2)} streaks '
      '${full.streaks.toStringAsFixed(2)} speed ×${full.speed.toStringAsFixed(2)} '
      'rise ${full.rise.toStringAsFixed(1)}; reduced pitch ${reduced.pitch} '
      'roll ${reduced.roll} streaks ${reduced.streaks} speed '
      '×${reduced.speed.toStringAsFixed(2)} rise ${reduced.rise}',
    );
    expect(full.pitch, closeTo(1, .02));
    // playtest-fixes-3: no bank (it read as flying sideways).
    expect(full.roll, 0);
    expect(full.streaks, greaterThan(.9));
    expect(full.speed, closeTo(8, .05));
    expect(full.rise, lessThanOrEqualTo(FlowPlan.ascentClimb + 1e-9));
    expect(reduced.pitch, 0);
    expect(reduced.roll, 0);
    expect(reduced.streaks, 0);
    expect(reduced.speed, lessThanOrEqualTo(2));
    expect(reduced.rise, lessThanOrEqualTo(1e-9));
  });
}
