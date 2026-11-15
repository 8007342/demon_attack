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

/// Demon-intelligence review frames (openspec/changes/demon-intelligence
/// task 8.1), phone portrait (360 x 780) with every in-game atlas loaded,
/// in the style of test/continuous_swarm_review_test.dart: motion strips
/// of a hunter threading the player's shots (and a straight diver for
/// comparison), a pincer tell, the sentinel rush (rally, lock with the
/// shadow on the ship's, the rush with its aura, the shield broken with
/// the stagger, the next pass out of the fog), the reduced-motion rush and
/// the tier comparison. Frames go to `$DEMON_INTELLIGENCE_REVIEW_DIR`
/// (default .cache/demon-intelligence-review); with `--dart-define=
/// DEMON_INTELLIGENCE_CONTACT=true` the strips are also written to
/// art/contact/demon-intelligence-*.png (tracked review evidence).
const _dir = String.fromEnvironment(
  'DEMON_INTELLIGENCE_REVIEW_DIR',
  defaultValue: '.cache/demon-intelligence-review',
);
const _contact = bool.fromEnvironment('DEMON_INTELLIGENCE_CONTACT');
const _w = 360.0, _h = 780.0;

/// The strips kept as tracked review evidence in art/contact.
const _onSheet = {
  'thread',
  'thread-straight',
  'pincer',
  'rush',
  'rush-shield-broken',
  'rush-second-pass',
  'rush-reduced',
  'tiers',
};

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
  if (_contact && _onSheet.contains(name)) {
    await _png(sheet, 'art/contact/demon-intelligence-$name.png');
  }
  sheet.dispose();
  for (final f in frames) {
    f.dispose();
  }
}

/// Rows of models stepped together, frames tiled by time (columns).
Future<void> _grid(
  List<(ArcadeModel, DemonScene, void Function())> rows,
  String name, {
  int count = 8,
  double interval = .12,
  double scale = .5,
  double top = 0,
  double bottom = _h,
}) async {
  final frames = <List<ui.Image>>[for (final _ in rows) []];
  for (var i = 0; i < count; i++) {
    for (var r = 0; r < rows.length; r++) {
      final (m, scene, each) = rows[r];
      if (i > 0) _run(m, scene, interval, fire: true, each: each);
      frames[r].add(await _frame(scene));
    }
  }
  const gap = 4.0;
  final fw = _w * scale, fh = (bottom - top) * scale;
  final sw = gap + count * (fw + gap), sh = gap + rows.length * (fh + gap);
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, sw, sh),
    Paint()..color = const Color(0xFF101218),
  );
  for (var r = 0; r < rows.length; r++) {
    for (var i = 0; i < count; i++) {
      final x = gap + i * (fw + gap), y = gap + r * (fh + gap);
      c.drawImageRect(
        frames[r][i],
        Rect.fromLTWH(0, top, _w, bottom - top),
        Rect.fromLTWH(x, y, fw, fh),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }
  final pic = rec.endRecording();
  final sheet = await pic.toImage(sw.round(), sh.round());
  await _png(sheet, '$_dir/strip-$name.png');
  if (_contact && _onSheet.contains(name)) {
    await _png(sheet, 'art/contact/demon-intelligence-$name.png');
  }
  sheet.dispose();
  for (final row in frames) {
    for (final f in row) {
      f.dispose();
    }
  }
}

/// An empty route-1 Normal arena of [sector] (nothing streams in).
Future<(ArcadeModel, DemonScene)> _arena({
  int sector = 3,
  Difficulty difficulty = Difficulty.normal,
  int route = 1,
}) async {
  final m = ArcadeModel(seed: 7)
    ..startAt(difficulty: difficulty, sector: sector, route: route);
  final scene = await _scene(m, sector);
  _run(m, scene, 5); // the opening arrival
  m.demons.clear();
  m.shots.clear();
  m.flocksSpawned = m.flocksPlanned;
  return (m, scene);
}

Demon _settled(
  double x,
  double y, {
  bool elite = false,
  int kind = 1,
  int hp = 3,
}) => Demon(x, y, kind, hp, x / 40, elite: elite)
  ..attackLeft = 1e9
  ..volleyLeft = 1e9;

/// Keeps only [keep] (no reinforcements, no next cohort) and no hostile
/// fire in the frame.
void Function() _only(ArcadeModel m, List<Demon> keep) => () {
  m.demons.removeWhere((d) => !keep.contains(d));
  m.shots.removeWhere((s) => s.hostile);
};

void main() {
  testWidgets('demon intelligence review frames', (tester) async {
    await tester.runAsync(() async {
      const top = 130.0, bottom = 650.0;
      // (1) A hunter's thread dive through a column of shots 88 u apart,
      // and the same dive straight (the intelligence off) for comparison.
      for (final thread in [true, false]) {
        final (m, scene) = await _arena();
        m.intelligence = thread;
        m.shipX = m.targetX = 320;
        final d = _settled(180, 170, elite: true)
          ..dive = .001
          ..threadLine = 180
          ..targetX = 180;
        m.demons.add(d);
        for (var i = 0; i < 6; i++) {
          m.shots.add(Shot(180, 360.0 + i * 88, 0, -385)..age = .5);
        }
        await _strip(
          m,
          scene,
          thread ? 'thread' : 'thread-straight',
          count: 12,
          interval: .1,
          cols: 6,
          scale: .55,
          top: top + 120,
          bottom: bottom,
          fire: true,
          each: () {
            m.moveTo(320);
            _only(m, [d])();
          },
        );
      }
      // (2) A pincer: two hunters tell either side of the forecast.
      {
        final (m, scene) = await _arena();
        final a = _settled(120, 150, elite: true),
            b = _settled(240, 150, elite: true);
        m.demons.addAll([a, b]);
        m.shipX = m.targetX = 180;
        for (var f = 0; f < 60 * 90; f++) {
          m.skill.level = 1;
          m.moveTo(180);
          m.update(1 / 60);
          m.shots.removeWhere((s) => !s.hostile || s.hostile);
          m.demons.removeWhere((d) => d != a && d != b);
          if (a.divePrep > 0 && b.divePrep > 0) break;
          for (final d in [a, b]) {
            if (d.dive > 0 ||
                (d.telegraph > 0 && (a.telegraph <= 0 || b.telegraph <= 0))) {
              d
                ..dive = 0
                ..telegraph = 0
                ..divePrep = 0;
            }
          }
        }
        await _strip(
          m,
          scene,
          'pincer',
          count: 12,
          interval: .12,
          cols: 6,
          scale: .55,
          top: top,
          bottom: bottom,
          each: () {
            m.skill.level = 1;
            m.moveTo(180);
            _only(m, [a, b])();
          },
        );
      }
      // (3) The rush: rally, lock (its shadow onto the ship's), the charge
      // with its aura (20 frames over 1.5 s); then the shield broken
      // mid-rush and the stagger; then the second pass out of the fog.
      {
        final (m, scene) = await _arena(sector: 2);
        final s =
            Demon(
                150,
                44,
                2,
                12,
                0,
                archetype: EnemyArchetype.shieldSentinel,
                lastStandEligible: true,
              )
              ..hp = 4
              ..volleyLeft = 1e9
              ..attackLeft = 1e9;
        m.demons.add(s);
        m.shipX = m.targetX = 210;
        _run(m, scene, .3, each: _only(m, [s]));
        m.hitDemon(s);
        _run(m, scene, .45, each: _only(m, [s])); // into the rally
        await _strip(
          m,
          scene,
          'rush',
          count: 20,
          interval: .08,
          cols: 8,
          scale: .5,
          top: top,
          bottom: bottom,
          each: () {
            m.moveTo(210);
            _only(m, [s])();
          },
        );
        // Recover and come again; break the shield early in the charge.
        while (s.rushPhase != RushPhase.rush || s.rushClock > .05) {
          _run(
            m,
            scene,
            1 / 60,
            each: () {
              m.moveTo(60);
              _only(m, [s])();
            },
          );
          if (!m.demons.contains(s)) break;
        }
        _run(m, scene, .08, each: _only(m, [s]));
        while (s.rushShield > 0) {
          m.hitDemon(s);
        }
        await _strip(
          m,
          scene,
          'rush-shield-broken',
          count: 8,
          interval: .06,
          cols: 8,
          scale: .5,
          top: top,
          bottom: bottom,
          each: () {
            m.moveTo(60);
            _only(m, [s])();
          },
        );
      }
      {
        final (m, scene) = await _arena(sector: 2);
        final s =
            Demon(
                200,
                44,
                2,
                12,
                0,
                archetype: EnemyArchetype.armoredSentinel,
                lastStandEligible: true,
              )
              ..hp = 4
              ..volleyLeft = 1e9
              ..attackLeft = 1e9;
        m.demons.add(s);
        m.shipX = m.targetX = 200;
        _run(m, scene, .3, each: _only(m, [s]));
        m.hitDemon(s);
        while (s.rushPhase != RushPhase.recover) {
          _run(
            m,
            scene,
            1 / 60,
            each: () {
              m.invulnerable = 5;
              m.moveTo(330);
              _only(m, [s])();
            },
          );
        }
        await _strip(
          m,
          scene,
          'rush-second-pass',
          count: 12,
          interval: .14,
          cols: 6,
          scale: .55,
          top: top,
          bottom: bottom,
          each: () {
            m.moveTo(330);
            _only(m, [s])();
          },
        );
      }
      // (4) The same rush with reduced motion: no shake, no shudder.
      {
        final (m, scene) = await _arena(sector: 2);
        scene.sectors.flyover.reducedMotionOverride = true;
        final s =
            Demon(
                150,
                44,
                2,
                12,
                0,
                archetype: EnemyArchetype.shieldSentinel,
                lastStandEligible: true,
              )
              ..hp = 4
              ..volleyLeft = 1e9
              ..attackLeft = 1e9;
        m.demons.add(s);
        m.shipX = m.targetX = 210;
        _run(m, scene, .3, each: _only(m, [s]));
        m.hitDemon(s);
        await _strip(
          m,
          scene,
          'rush-reduced',
          count: 8,
          interval: .2,
          cols: 8,
          scale: .5,
          top: top,
          bottom: bottom,
          each: () {
            m.moveTo(210);
            _only(m, [s])();
          },
        );
      }
      // (5) Tiers: a drone, a skirmisher and a hunter (rows) under the
      // same straight column of shots from a ship tracking it.
      {
        final rows = <(ArcadeModel, DemonScene, void Function())>[];
        for (final (kind, hp, elite) in [
          (0, 1, false),
          (2, 3, false),
          (1, 3, true),
        ]) {
          final (m, scene) = await _arena();
          final d = _settled(180, 170, elite: elite, kind: kind, hp: hp);
          m.demons.add(d);
          m.shipX = m.targetX = 180;
          rows.add((
            m,
            scene,
            () {
              m.skill.level = .6;
              m.moveTo(d.x);
              _only(m, [d])();
            },
          ));
        }
        await _grid(
          rows,
          'tiers',
          count: 8,
          interval: .15,
          scale: .75,
          top: top + 70,
          bottom: top + 300,
        );
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
