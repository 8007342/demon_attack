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

/// Cinematic-flow review frames (openspec/changes/cinematic-flow task 7.1,
/// design §7), phone portrait (360 x 780) with every in-game atlas loaded.
/// For each flow plan (a sector change, the carrier's arrival, its fall and
/// the route jump, the campaign outro, game over, and a reduced-motion
/// sector change) it renders 30 frames across the plan and measures:
/// - the no-black rule: every frame's mean linear luminance at least the
///   sector's night floor (its own combat frame, see below), and no frame
///   95 % one colour;
/// - ship continuity: at most 6 units per 60 Hz frame;
/// - direction: the pursued flock's screen x velocity keeps its sign across
///   the palette swap;
/// - smoothness (macron.dev): the mean frame-to-frame change of the ship
///   and of the flock centroid, next to the pre-change transition's ship
///   path (computed from its formulas) for comparison.
///
/// Frames and sheets go to `$CINEMATIC_FLOW_REVIEW_DIR` (default
/// .cache/cinematic-flow-review). With `--dart-define=
/// CINEMATIC_FLOW_CONTACT=true` the sheets are also written to
/// art/contact/cinematic-flow-*.png (tracked review evidence). Sheets have
/// no progress tick (operator feedback W5: nothing that reads as a bar).
const _dir = String.fromEnvironment(
  'CINEMATIC_FLOW_REVIEW_DIR',
  defaultValue: '.cache/cinematic-flow-review',
);
const _contact = bool.fromEnvironment('CINEMATIC_FLOW_CONTACT');
const _w = 360.0, _h = 780.0;

/// The arena rows of the phone frame (the 360 x 520 arena letterboxed).
const _top = 130.0, _bottom = 650.0;

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

/// One presentation + model step, as the game loop does it.
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

double _lin(int c) {
  final v = c / 255;
  return v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
}

/// Mean linear luminance of the arena rows and the share of its most common
/// colour.
Future<(double, double)> _measure(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final bytes = data.buffer.asUint8List();
  final w = image.width;
  var sum = 0.0, n = 0;
  final counts = <int, int>{};
  for (var y = _top.round(); y < _bottom.round(); y += 2) {
    for (var x = 0; x < w; x += 2) {
      final i = (y * w + x) * 4;
      final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
      sum += .2126 * _lin(r) + .7152 * _lin(g) + .0722 * _lin(b);
      final key = (r << 16) | (g << 8) | b;
      counts[key] = (counts[key] ?? 0) + 1;
      n++;
    }
  }
  final mode = counts.values.fold(0, math.max);
  return (sum / n, mode / n);
}

/// Tiles [frames] (arena rows) [cols] wide at [scale]: no progress tick.
Future<ui.Image> _sheet(List<ui.Image> frames, {int cols = 6}) async {
  const scale = .4, gap = 4.0;
  final fw = _w * scale, fh = (_bottom - _top) * scale;
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
      Rect.fromLTWH(0, _top, _w, _bottom - _top),
      Rect.fromLTWH(x, y, fw, fh),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  final pic = rec.endRecording();
  return pic.toImage(sw.round(), sh.round());
}

/// Ship screen position as drawn (the flow ship is drawn over the cover).
Offset _shipAt(ArcadeModel m) {
  final flow = m.flow;
  final y = flow.active
      ? ArcadeModel.shipY - flow.plan.climb * flow.env('climb')
      : ArcadeModel.shipY;
  return Offset(m.shipX, y);
}

Offset? _flockCentre(ArcadeModel m) {
  if (m.flowFlock.isEmpty) return null;
  var x = 0.0, y = 0.0;
  for (final f in m.flowFlock) {
    x += f.demon.x;
    y += f.demon.y;
  }
  return Offset(x / m.flowFlock.length, y / m.flowFlock.length);
}

/// The pre-change sector transition's ship path (scene `_cinematic` before
/// this change): level clear 4⅓ s flying off the top, a cut, travel 4⅓ s
/// at a fixed flyby, a cut, the arrival from below. Mean |Δ| per 60 Hz
/// frame and the largest single jump.
(double, double) _oldShipPath() {
  const clear = 4 + 1 / 3, travel = 4 + 1 / 3, arrival = 4.5;
  final pts = <Offset>[];
  double cubic(double t) => t * t * t;
  double outCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
  for (var t = 0.0; t < clear; t += 1 / 60) {
    final p = t / clear;
    final dep = cubic(((p - .35) / .65).clamp(0.0, 1.0));
    pts.add(Offset(180, ArcadeModel.shipY - dep * 650));
  }
  for (var t = 0.0; t < travel; t += 1 / 60) {
    final p = t / travel;
    pts.add(
      Offset(
        180 + math.sin(p * math.pi * 2) * 10,
        340 + math.sin(p * math.pi) * 22,
      ),
    );
  }
  for (var t = 0.0; t < arrival; t += 1 / 60) {
    final p = t / arrival;
    final a = outCubic((p / .8).clamp(0.0, 1.0));
    pts.add(Offset(180, ArcadeModel.shipY + (1 - a) * 130));
  }
  var sum = 0.0, worst = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final d = (pts[i] - pts[i - 1]).distance;
    sum += d;
    worst = math.max(worst, d);
  }
  return (sum / (pts.length - 1), worst);
}

class _Result {
  _Result(this.kind);
  final String kind;
  double minLum = 9, meanLum = 0, maxShare = 0, floor = 0;
  double shipMean = 0, shipMax = 0, flockMean = 0;
  int? dirBefore, dirAfter;
  double seconds = 0;
  final lums = <double>[];
}

/// Runs [m] from now through [seconds] of its flow, rendering [count]
/// frames evenly; [stop] ends early.
Future<_Result> _review(
  String kind,
  ArcadeModel m,
  DemonScene scene, {
  required double seconds,
  required double floor,
  int count = 30,
}) async {
  final r = _Result(kind)..floor = floor;
  final frames = <ui.Image>[];
  final steps = (seconds * 60).round();
  final every = steps / count;
  var next = 0.0;
  Offset? lastShip, lastFlock;
  var shipSum = 0.0, flockSum = 0.0;
  var shipN = 0, flockN = 0;
  final swap = m.flow.plan.swapAt;
  final dirs = <double, double>{};
  var lumSum = 0.0;
  for (var i = 0; i <= steps; i++) {
    if (i >= next && frames.length < count) {
      final image = await _frame(scene);
      final (lum, share) = await _measure(image);
      r.minLum = math.min(r.minLum, lum);
      r.lums.add(lum);
      r.maxShare = math.max(r.maxShare, share);
      lumSum += lum;
      frames.add(image);
      next += every;
    }
    final ship = _shipAt(m);
    if (lastShip != null) {
      final d = (ship - lastShip).distance;
      shipSum += d;
      shipN++;
      r.shipMax = math.max(r.shipMax, d);
    }
    lastShip = ship;
    final flock = _flockCentre(m);
    if (flock != null && lastFlock != null) {
      flockSum += (flock - lastFlock).distance;
      flockN++;
      if (swap != null) {
        final s = m.flow.seconds;
        for (final probe in [swap - .5, swap + 1.5]) {
          if ((s - probe).abs() < 1 / 120) {
            dirs[probe] = flock.dx - lastFlock.dx;
          }
        }
      }
    }
    lastFlock = flock;
    if (i < steps) _step(m, scene);
  }
  // The night floor is the darker sector's: after a sector change the
  // Descent ends in the new sector, so its own combat frame counts too.
  if (m.mode == RunMode.playing || m.mode == RunMode.transition) {
    for (var i = 0; i < 120; i++) {
      _step(m, scene);
    }
    if (m.mode == RunMode.playing) {
      r.floor = math.min(r.floor, await _floorOf(m, scene));
    }
  }
  r
    ..meanLum = lumSum / frames.length
    ..shipMean = shipN == 0 ? 0 : shipSum / shipN
    ..flockMean = flockN == 0 ? 0 : flockSum / flockN
    ..seconds = seconds;
  if (swap != null && dirs.length == 2) {
    r
      ..dirBefore = dirs[swap - .5]!.sign.toInt()
      ..dirAfter = dirs[swap + 1.5]!.sign.toInt();
  }
  final sheet = await _sheet(frames);
  await _png(sheet, '$_dir/sheet-$kind.png');
  if (_contact) await _png(sheet, 'art/contact/cinematic-flow-$kind.png');
  sheet.dispose();
  for (final f in frames) {
    f.dispose();
  }
  return r;
}

/// The sector's night floor: half its own combat frame's mean luminance,
/// and never under [_black]. Design §2.1 names 0.06, but the dark sectors'
/// combat frames measure about 0.03, and the same scene without the lit
/// swarm (the Rout) about 0.02 (design.md, deviations).
Future<double> _floorOf(ArcadeModel m, DemonScene scene) async {
  final image = await _frame(scene);
  final (lum, _) = await _measure(image);
  image.dispose();
  return math.max(_black, lum * .5);
}

/// No frame of any plan is darker than this (mean linear luminance).
const _black = .01;

/// A model in the last wave of [sector], at the last kill.
Future<(ArcadeModel, DemonScene, double)> _atLastKill(
  int sector, {
  int route = 1,
  bool reduced = false,
}) async {
  final m = ArcadeModel(seed: 11)
    ..startAt(
      sector: sector,
      route: route,
      wave: ArcadeModel.wavesFor(sector: sector, route: route),
    );
  final scene = await _scene(m, reduced: reduced);
  reach(m, RunMode.playing);
  for (var i = 0; i < 240; i++) {
    _step(m, scene);
  }
  final floor = await _floorOf(m, scene);
  clearWave(m);
  expect(m.mode, RunMode.salvage);
  return (m, scene, floor);
}

void main() {
  testWidgets('cinematic flow review frames and continuity rules', (
    tester,
  ) async {
    final results = <_Result>[];
    (double, double, double)? attractCost;
    await tester.runAsync(() async {
      // (1) A sector change, 2 -> 3, through to the new sector's fight.
      {
        final (m, scene, floor) = await _atLastKill(2);
        results.add(
          await _review(
            'sector-change',
            m,
            scene,
            seconds: m.flow.plan.seconds,
            floor: floor,
          ),
        );
      }
      // (2) Reduced motion: the same beats as crossfades.
      {
        final (m, scene, floor) = await _atLastKill(2, reduced: true);
        results.add(
          await _review(
            'reduced-motion',
            m,
            scene,
            seconds: m.flow.plan.seconds,
            floor: floor,
          ),
        );
      }
      // (3) The carrier's arrival through the swarm: 4 -> 5.
      {
        final (m, scene, floor) = await _atLastKill(4);
        results.add(
          await _review(
            'boss-arrival',
            m,
            scene,
            seconds: m.flow.plan.seconds,
            floor: floor,
          ),
        );
      }
      // (4) The carrier's fall, the remnant's scatter and the route jump.
      {
        final m = ArcadeModel(seed: 11)..startAt(sector: 5, route: 1);
        final scene = await _scene(m);
        reach(m, RunMode.playing);
        for (var i = 0; i < 240; i++) {
          _step(m, scene);
        }
        final floor = await _floorOf(m, scene);
        final b = m.boss!
          ..shield = 0
          ..core = 1
          ..door = 1;
        m.hitBoss(b.x);
        results.add(
          await _review(
            'boss-victory',
            m,
            scene,
            seconds: m.flow.plan.seconds,
            floor: floor,
          ),
        );
      }
      // (5) The campaign outro: fog thins, shadows lift, the climb above
      // the clouds (the ending page fades up at 72 %, in main.dart).
      {
        final m = ArcadeModel(seed: 11)
          ..startAt(sector: 5, route: ArcadeModel.finalRoute);
        final scene = await _scene(m);
        reach(m, RunMode.playing);
        for (var i = 0; i < 240; i++) {
          _step(m, scene);
        }
        final floor = await _floorOf(m, scene);
        final b = m.boss!
          ..shield = 0
          ..core = 1
          ..door = 1;
        m.hitBoss(b.x);
        results.add(
          await _review(
            'outro',
            m,
            scene,
            seconds: m.flow.plan.seconds - 1 / 60,
            floor: floor,
          ),
        );
      }
      // (7) The title's attract loop (task 6.1): squads in the fog, the
      // sentinel's pass, shadows; and its frame cost against a bare title.
      {
        final m = ArcadeModel(seed: 11);
        final scene = await _scene(m);
        scene.environment = 1;
        final sw = Stopwatch();
        Future<double> cost() async {
          sw
            ..reset()
            ..start();
          for (var i = 0; i < 20; i++) {
            final rec = ui.PictureRecorder();
            scene.paintArena(ui.Canvas(rec), Vector2(_w, _h));
            final pic = rec.endRecording();
            final img = await pic.toImage(_w.round(), _h.round());
            img.dispose();
            pic.dispose();
          }
          sw.stop();
          return sw.elapsedMicroseconds / 20 / 1000;
        }

        final bare = await cost();
        for (var i = 0; i < 180; i++) {
          _step(m, scene);
        }
        final withSwarm = await cost();
        // A combat frame of sector 2 in the same harness, for reference.
        final fight = ArcadeModel(seed: 11)..startAt(sector: 2, route: 1);
        final fightScene = await _scene(fight);
        reach(fight, RunMode.playing);
        for (var i = 0; i < 240; i++) {
          _step(fight, fightScene);
        }
        sw
          ..reset()
          ..start();
        for (var i = 0; i < 20; i++) {
          final rec = ui.PictureRecorder();
          fightScene.paintArena(ui.Canvas(rec), Vector2(_w, _h));
          final pic = rec.endRecording();
          final img = await pic.toImage(_w.round(), _h.round());
          img.dispose();
          pic.dispose();
        }
        sw.stop();
        final combat = sw.elapsedMicroseconds / 20 / 1000;
        attractCost = (bare, withSwarm, combat);
        // The design's budget: no more than a combat frame.
        expect(withSwarm, lessThan(combat * 1.25));
        results.add(
          await _review(
            'attract',
            m,
            scene,
            seconds: FlowPlan.attractSeconds,
            floor: _black,
          ),
        );
      }
      // (6) Game over: the swarm mills over the wreck, then the pan.
      {
        final m = ArcadeModel(seed: 11)..startAt(sector: 2, route: 1);
        final scene = await _scene(m);
        reach(m, RunMode.playing);
        for (var i = 0; i < 240; i++) {
          _step(m, scene);
        }
        m
          ..lives = 1
          ..invulnerable = 0;
        m.shots.add(Shot(m.shipX, ArcadeModel.shipY, 0, 0, hostile: true));
        m.update(.1);
        expect(m.mode, RunMode.gameOver);
        // The pan reveals the deep sky (its own night floor, below).
        results.add(
          await _review(
            'game-over',
            m,
            scene,
            seconds: ArcadeModel.defeatDuration - .2,
            floor: _black,
          ),
        );
      }
    });
    final (oldMean, oldMax) = _oldShipPath();
    final table = StringBuffer()
      ..writeln(
        '| kind | s | mean lum | min lum | floor | max colour share | '
        'ship mean/frame | ship max/frame | flock mean/frame | dir before/after |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|---|---|');
    for (final r in results) {
      table.writeln(
        '| ${r.kind} | ${r.seconds.toStringAsFixed(1)} | '
        '${r.meanLum.toStringAsFixed(3)} | ${r.minLum.toStringAsFixed(3)} | '
        '${r.floor.toStringAsFixed(3)} | ${r.maxShare.toStringAsFixed(2)} | '
        '${r.shipMean.toStringAsFixed(2)} | ${r.shipMax.toStringAsFixed(2)} | '
        '${r.flockMean.toStringAsFixed(2)} | ${r.dirBefore ?? '-'}/${r.dirAfter ?? '-'} |',
      );
    }
    table.writeln(
      '| before (sector change ship path) | 13.2 | - | - | - | - | '
      '${oldMean.toStringAsFixed(2)} | ${oldMax.toStringAsFixed(2)} | - | - |',
    );
    if (attractCost != null) {
      table.writeln(
        'title frame (ms, record + raster, 360 x 780): bare '
        '${attractCost!.$1.toStringAsFixed(1)}, with the attract swarm '
        '${attractCost!.$2.toStringAsFixed(1)}, a sector-2 combat frame '
        '${attractCost!.$3.toStringAsFixed(1)}',
      );
    }
    for (final r in results) {
      table.writeln(
        '${r.kind}: ${[for (final l in r.lums) l.toStringAsFixed(3)].join(' ')}',
      );
    }
    // ignore: avoid_print
    print(table);
    await tester.runAsync(
      () => File('$_dir/metrics.md').writeAsString(table.toString()),
    );
    for (final r in results) {
      expect(
        r.minLum,
        greaterThanOrEqualTo(r.floor),
        reason: '${r.kind} black',
      );
      expect(r.maxShare, lessThan(.95), reason: '${r.kind} one colour');
      expect(r.shipMax, lessThanOrEqualTo(6), reason: '${r.kind} ship jump');
      if (r.dirBefore != null) {
        expect(r.dirBefore, r.dirAfter, reason: '${r.kind} direction');
        expect(r.dirBefore, isNot(0));
      }
    }
  });
}
