import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/insignia_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:demon_attack/game/terrain_field.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progression_test.dart' show clearWave, reach;

/// playtest-fixes-3 review sheets (openspec/changes/playtest-fixes-3): real
/// in-game frames from the real scene with every in-game atlas loaded.
///
/// - `shields`: diving shields at five scales, three tiers and two dive
///   poses, and the sentinel's dive shield (`PF3_TAG` names the sheet, so
///   a run on the old code writes `shields-before`);
/// - `rush`: a sentinel's lurk, hand-off, play, berserk (deflect sparks),
///   lock and rush, each frame with its terrain shadow;
/// - `band`: the background through the toast band at 360 × 640,
///   390 × 844, 1280 × 720 and 1920 × 1080 (the game's bottom alignment);
/// - `ascent`: the sector change's fly-up, 12 frames from the Rout into
///   the cloud and out in the Descent.
///
/// Frames go to `.cache/pf3`; with `--dart-define=PF3_CONTACT=true` the
/// sheets are also written to `art/contact/playtest-fixes-3-<shot>.png`.
/// `--dart-define=PF3_SHOT=<shot>` renders only that one.
const _dir = '.cache/pf3';
const _contact = bool.fromEnvironment('PF3_CONTACT');
const _only = String.fromEnvironment('PF3_SHOT');
const _tag = String.fromEnvironment('PF3_TAG', defaultValue: 'after');

bool _wants(String shot) => _only.isEmpty || _only == shot;

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
  scene.insignia.image = await _decode('assets/images/${InsigniaAtlas.file}');
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
  scene.environment = m.level - 1.0;
  return scene;
}

void _step(ArcadeModel m, DemonScene scene, {bool protect = true}) {
  if (protect) m.invulnerable = 5;
  scene.advancePresentation(1 / 60);
  m.update(1 / 60);
  scene.creatures.update(m, 1 / 60);
  scene.syncAtmosphere(1 / 60);
  m.takeEvents();
  m.takeGameEvents();
}

/// One frame as the game paints it: the arena on the pilot dock
/// ([alignY] 1), any spare height a band at the top.
Future<ui.Image> _frame(
  DemonScene scene,
  double w,
  double h, {
  double alignY = 1,
}) async {
  final keep = scene.model.invulnerable;
  scene.model.invulnerable = 0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF000000),
  );
  scene.paintArena(canvas, Vector2(w, h), alignY: alignY);
  final picture = recorder.endRecording();
  final image = await picture.toImage(w.round(), h.round());
  picture.dispose();
  scene.model.invulnerable = keep;
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

/// Lays [tiles] (image, source rect, label colour) out in rows of [cols]
/// at [cell] width each and writes the sheet.
Future<void> _sheet(
  String name,
  List<(ui.Image, Rect)> tiles, {
  int cols = 6,
  double cell = 200,
}) async {
  const gap = 6.0;
  final rowH = <double>[];
  for (var i = 0; i < tiles.length; i += cols) {
    var h = 0.0;
    for (final (_, src) in tiles.skip(i).take(cols)) {
      if (src.isEmpty) continue;
      h = math.max(h, src.height * cell / src.width);
    }
    rowH.add(h);
  }
  final w = gap + cols * (cell + gap);
  final h = gap + rowH.fold(0.0, (a, b) => a + b + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF16141F),
  );
  var y = gap;
  for (var r = 0; r < rowH.length; r++) {
    for (var k = 0; k < cols && r * cols + k < tiles.length; k++) {
      final (img, src) = tiles[r * cols + k];
      if (src.isEmpty) continue;
      final dh = src.height * cell / src.width;
      c.drawImageRect(
        img,
        src,
        Rect.fromLTWH(gap + k * (cell + gap), y, cell, dh),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    y += rowH[r] + gap;
  }
  final pic = rec.endRecording();
  final sheet = await pic.toImage(w.round(), h.round());
  pic.dispose();
  await _png(sheet, '$_dir/$name.png');
  if (_contact) await _png(sheet, 'art/contact/playtest-fixes-3-$name.png');
  sheet.dispose();
}

Rect _all(ui.Image i) =>
    Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());

ArcadeModel _bare({int sector = 2}) {
  final m = ArcadeModel(seed: 11)..startAt(sector: sector, route: 1);
  m
    ..mode = RunMode.playing
    ..invulnerable = 0
    ..clock = 3;
  m.demons.clear();
  m.incoming.clear();
  m.shots.clear();
  return m;
}

// --- shields ---------------------------------------------------------------

Future<void> _shields() async {
  final m = _bare();
  final scene = await _scene(m);
  const scales = [.55, .8, 1.0, 1.25, 1.6];
  // Three tiers (small, not-so-small, elite), five scales, two frames.
  for (final (i, s) in scales.indexed) {
    for (final (j, tier) in const [(0, 1, 1), (2, 3, 2), (3, 4, 3)].indexed) {
      final (kind, hp, n) = tier;
      m.demons.add(
        Demon(
            34.0 + i * 72,
            70.0 + j * 92,
            kind,
            hp,
            i * 1.7 + j,
            elite: j == 2,
          )
          ..dive = 1
          ..diveShieldMax = n
          ..diveShield = n
          ..scale = s,
      );
    }
  }
  // A worn shield (one point burnt) and the sentinel's dive shield.
  m.demons.add(
    Demon(70, 360, 2, 3, 4)
      ..dive = 1
      ..diveShieldMax = 3
      ..diveShield = 2
      ..scale = 1.25,
  );
  for (final (i, s) in const [.8, 1.15].indexed) {
    m.demons.add(
      Demon(
          170.0 + i * 120,
          380,
          0,
          9,
          i.toDouble(),
          archetype: EnemyArchetype.shieldSentinel,
          shieldMax: 4,
        )
        ..dive = 1
        ..diveShieldMax = 4
        ..diveShield = 4 - i
        ..scale = s,
    );
  }
  final tiles = <(ui.Image, Rect)>[];
  for (var f = 0; f < 3; f++) {
    for (var t = 0; t < 9; t++) {
      for (final d in m.demons) {
        d.nearness = 1;
      }
      scene.creatures.update(m, 1 / 60);
      m.clock += 1 / 60;
    }
    final img = await _frame(scene, 720, 1040, alignY: 0);
    // The paintArena scale is 2 here: arena = the whole frame.
    tiles.add((img, const Rect.fromLTWH(0, 80, 720, 880)));
  }
  await _png(tiles.first.$1, '$_dir/shields-$_tag-frame.png');
  await _sheet('shields-$_tag', tiles, cols: 3, cell: 480);
}

// --- sentinel rush and its shadow -------------------------------------------

/// The shadow pass alone over the terrain mesh on grey (arena 360 × 520),
/// so the sentinel's shadow reads whatever the ground's palette.
Future<ui.Image> _diag(DemonScene scene) async {
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
  scene.paintShadowPass(c);
  final pic = rec.endRecording();
  final img = await pic.toImage(360, 520);
  pic.dispose();
  return img;
}

/// The shadow pass as every painted frame runs it (the lurk hand-off is
/// tracked there).
void _tick(DemonScene scene) {
  final rec = ui.PictureRecorder();
  scene.paintShadowPass(ui.Canvas(rec));
  rec.endRecording().dispose();
}

/// Sizes of the sentinel's shadow along the sequence (tests read them).
final rushShadowScales = <String, double>{};

Future<void> _rush() async {
  ArcadeModel combat(int wave) => ArcadeModel(seed: 7)
    ..startAt(difficulty: Difficulty.normal, sector: 2, route: 1, wave: wave);
  final probe = combat(1);
  var w = 2;
  while (probe.sentinelFor(w) == null) {
    w++;
  }
  // The wave before: the lurking shadow crosses the ground, then the
  // sentinel's own wave.
  final m = combat(w - 1);
  final scene = await _scene(m);
  final real = <ui.Image>[], diag = <ui.Image>[];
  final labels = <String>[];
  Future<void> grab(String label) async {
    real.add(await _frame(scene, 360, 640));
    diag.add(await _diag(scene));
    labels.add(label);
  }

  // Lurk: two frames along its track.
  var lurks = 0;
  for (var f = 0; f < 60 * 40 && lurks < 2; f++) {
    _step(m, scene);
    _tick(scene);
    final p = m.foreshadow?.lurk.progress ?? 0;
    if (scene.lurkCenter != null && p >= .45 + lurks * .5) {
      await grab('lurk');
      rushShadowScales['lurk$lurks'] = scene.lurkScale ?? 0;
      lurks++;
    }
  }
  // Into the sentinel's wave: clear what is left, then wait for it.
  for (var f = 0; f < 60 * 60 && m.wave < w; f++) {
    if (m.combat) {
      for (final d in List<Demon>.of(m.demons)) {
        if (!d.entering && !d.isLarge) m.hitDemon(d, damage: 9);
      }
    }
    _step(m, scene);
    _tick(scene);
  }
  Demon? sentinel;
  var rising = 0;
  for (var f = 0; f < 60 * 30; f++) {
    _step(m, scene);
    _tick(scene);
    sentinel = m.demons.where((d) => d.isLarge).firstOrNull;
    if (sentinel == null) continue;
    if (sentinel.entering && sentinel.entranceProgress > .3 + rising * .4) {
      await grab('hand-off');
      rushShadowScales['rise$rising'] = scene.shadowScaleOf(sentinel) ?? 0;
      rising++;
    }
    if (!sentinel.entering) break;
  }
  final s = sentinel!;
  for (var f = 0; f < 90; f++) {
    _step(m, scene);
    _tick(scene);
  }
  await grab('in play');
  rushShadowScales['play'] = scene.shadowScaleOf(s) ?? 0;
  // Wear it to a quarter hull with an eligible roll: the rush starts.
  s.rushRoll = 0;
  for (var k = 0; k < 200 && !s.lastStand && m.demons.contains(s); k++) {
    m.hitDemon(s, damage: 1, atX: s.x, atY: s.y + 20);
  }
  expect(s.lastStand, isTrue, reason: 'the rush started');
  // The berserk transformation: hits deflect with sparks.
  var shots = 0;
  for (var f = 0; f < 120 && s.rushPhase != RushPhase.rush; f++) {
    if (f % 6 == 0) {
      m.hitDemon(s, damage: 1, atX: s.x - 8 + (shots * 7) % 16, atY: s.y + 24);
      shots++;
    }
    _step(m, scene);
    _tick(scene);
    if (f == 20 || f == 50 || (s.rushPhase == RushPhase.lock && f % 18 == 0)) {
      await grab(s.rushPhase.name);
      rushShadowScales[s.rushPhase.name] = scene.shadowScaleOf(s) ?? 0;
    }
  }
  // The rush: the bare gun deflects off the super diving shield.
  for (var f = 0; f < 60 && m.demons.contains(s); f++) {
    if (f % 4 == 0 && s.y < ArcadeModel.shipY - 40) {
      m.hitDemon(s, damage: 1, atX: s.x, atY: s.y + 30);
    }
    _step(m, scene);
    _tick(scene);
    if (f % 5 == 2 && s.rushPhase == RushPhase.rush) {
      await grab('rush');
      rushShadowScales['rush'] = scene.shadowScaleOf(s) ?? 0;
    }
  }
  final tiles = <(ui.Image, Rect)>[];
  const cols = 6;
  for (var i = 0; i < real.length; i += cols) {
    final n = math.min(cols, real.length - i);
    for (var k = 0; k < n; k++) {
      tiles.add((real[i + k], _all(real[i + k])));
    }
    for (var k = n; k < cols; k++) {
      tiles.add((real[i + k - n], Rect.zero));
    }
    for (var k = 0; k < n; k++) {
      tiles.add((diag[i + k], _all(diag[i + k])));
    }
    for (var k = n; k < cols; k++) {
      tiles.add((diag[i + k - n], Rect.zero));
    }
  }
  // ignore: avoid_print
  print('rush sequence: ${labels.join(', ')}; shadow $rushShadowScales');
  await _sheet('rush', tiles, cols: cols, cell: 220);
}

// --- background band --------------------------------------------------------

Future<void> _band() async {
  final m = ArcadeModel(seed: 7)
    ..startAt(difficulty: Difficulty.normal, sector: 4, route: 1);
  final scene = await _scene(m);
  reach(m, RunMode.playing);
  for (var i = 0; i < 60 * 6; i++) {
    _step(m, scene);
  }
  final tiles = <(ui.Image, Rect)>[];
  for (final (w, h) in const [
    (360.0, 640.0),
    (390.0, 844.0),
    (1280.0, 720.0),
    (1920.0, 1080.0),
  ]) {
    final img = await _frame(scene, w, h);
    await _png(img, '$_dir/band-${w.round()}x${h.round()}.png');
    tiles.add((img, _all(img)));
  }
  await _sheet('band', tiles.take(2).toList(), cols: 2, cell: 390);
  await _sheet('band-wide', tiles.skip(2).toList(), cols: 2, cell: 640);
}

// --- ascent -----------------------------------------------------------------

Future<void> _ascent() async {
  final m = ArcadeModel(seed: 11)
    ..startAt(
      sector: 2,
      route: 1,
      wave: ArcadeModel.wavesFor(sector: 2, route: 1),
    );
  final scene = await _scene(m);
  reach(m, RunMode.playing);
  for (var i = 0; i < 240; i++) {
    _step(m, scene);
  }
  clearWave(m);
  final plan = m.flow.plan;
  final p1 = plan.descentAt, p0 = p1 - plan.pursuitSeconds;
  // Every 0.25 s from the Rout's end through the climb into the cloud,
  // then the Descent.
  final at = <double>[
    for (var k = 0; k < 8; k++) p0 - .5 + k * .3,
    for (var k = 0; k < 4; k++) p1 + .3 + k * .5,
  ];
  final tiles = <(ui.Image, Rect)>[];
  var i = 0;
  for (var f = 0; f < 60 * 40 && i < at.length; f++) {
    if (m.flow.active && m.flow.seconds >= at[i]) {
      final img = await _frame(scene, 360, 640);
      await _png(img, '$_dir/ascent-${i.toString().padLeft(2, '0')}.png');
      tiles.add((img, _all(img)));
      i++;
    }
    _step(m, scene);
  }
  await _sheet('ascent', tiles, cols: 6, cell: 220);
}

void main() {
  testWidgets('playtest-fixes-3 review sheets', (tester) async {
    await tester.runAsync(() async {
      if (_wants('shields')) await _shields();
      if (_wants('rush')) await _rush();
      if (_wants('band')) await _band();
      if (_wants('ascent')) await _ascent();
    });
  }, timeout: const Timeout(Duration(minutes: 30)));
}
