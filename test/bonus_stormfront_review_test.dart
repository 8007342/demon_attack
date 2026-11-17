@Tags(['review'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:demon_attack/game/bonus/levels/storm_cell.dart';
import 'package:demon_attack/game/bonus/levels/stormfront_painter.dart';
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

/// Stormfront review strips (openspec/changes/bonus-levels, bonus level
/// #2): a seeded run flies Ringfall's last wave, the fog transition into
/// the storm over Ember Moon, the storm itself with a bot that baits the
/// lightning and picks up the rod, and the way out. Every frame is drawn
/// at phone portrait (360 x 780) with every in-game atlas loaded; the
/// sheet shows each frame's arena.
///
/// Sheets go to `$BONUS_B_REVIEW_DIR` (default .cache/bonus-level-b); with
/// `--dart-define=BONUS_B_CONTACT=true` also to
/// art/contact/bonus-level-b-{stormfront,reduced}.png.
const _dir = String.fromEnvironment(
  'BONUS_B_REVIEW_DIR',
  defaultValue: '.cache/bonus-level-b',
);
const _contact = bool.fromEnvironment('BONUS_B_CONTACT');
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

/// The frames' arenas (the phone letterbox is cropped), [cols] to a row.
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
  final k = math.min(_w / ArcadeModel.width, _h / ArcadeModel.height);
  final src = Rect.fromLTWH(
    (_w - ArcadeModel.width * k) / 2,
    (_h - ArcadeModel.height * k) / 2,
    ArcadeModel.width * k,
    ArcadeModel.height * k,
  );
  for (var i = 0; i < frames.length; i++) {
    c.drawImageRect(
      frames[i],
      src,
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

/// A run seed whose plan puts Stormfront on Ember Moon of the first tour.
int _seedFor(int route, int sector) {
  for (var seed = 1; seed < 100000; seed++) {
    final slot = BonusPlan.forRun(seed).at(route, sector);
    if (slot?.id == 'stormfront' && BonusPlan.forRun(seed).modifier == null) {
      return seed;
    }
  }
  fail('no seed draws stormfront at route $route sector $sector');
}

StormfrontMechanic? _mech(ArcadeModel m) {
  final mech = m.bonusMechanic;
  return mech is StormfrontMechanic ? mech : null;
}

/// The review pilot: waits under the swarm's densest column, slides away
/// from every tell (unless it carries the rod), and fetches a falling rod.
void _pilot(ArcadeModel m) {
  final mech = _mech(m);
  if (mech == null || !m.combat) return;
  final tells = mech.cell.strikes.where((s) => s.telling).toList();
  final rod = m.hasBonusPower('lightningRod');
  final present = [
    for (final d in m.demons)
      if (!d.entering) d.x,
  ];
  final under = present.isEmpty ? 180.0 : StormCell.densest(present, 34);
  if (tells.isNotEmpty && !rod) {
    final x = tells.first.x;
    final left = tells.map((s) => s.x).reduce(math.min);
    final right = tells.map((s) => s.x).reduce(math.max);
    m.moveTo(left - 18 > 342 - right ? left - 64 : right + 64);
    if (tells.length == 1) m.moveTo(x < 180 ? x + 64 : x - 64);
    return;
  }
  final falling = m.pickups.where((p) => p.bonus != null && p.y > 60);
  if (falling.isNotEmpty && !rod) {
    m.moveTo(falling.first.x);
    return;
  }
  m.moveTo(under);
}

class _Shot {
  _Shot(this.name, this.when);
  final String name;
  final bool Function(ArcadeModel m, StormfrontMechanic? mech) when;
  ui.Image? image;
}

Future<Map<String, Object>> _review({required bool reduced}) async {
  final seed = _seedFor(0, 3);
  final m = ArcadeModel(seed: 11)
    ..startAt(
      sector: 2,
      route: 0,
      wave: ArcadeModel.wavesFor(sector: 2, route: 0),
      runSeed: seed,
    );
  expect(m.bonusPlan.at(0, 3)?.id, 'stormfront');
  final scene = await _scene(m, reduced: reduced);
  reach(m, RunMode.playing);
  for (var i = 0; i < 120; i++) {
    _step(m, scene);
  }
  clearWave(m);
  expect(m.mode, RunMode.salvage);
  expect(m.bonusAhead?.id, 'stormfront');

  bool tell(StormfrontMechanic? k, StrikeAim aim, double from) =>
      k != null &&
      k.cell.strikes.any(
        (s) => s.telling && s.aim == aim && s.tellProgress >= from,
      );
  bool bolt(StormfrontMechanic? k, bool Function(StormStrike) which) =>
      k != null &&
      k.cell.strikes.any(
        (s) => s.landed && s.glowLeft > k.cell.tuning.glow - .05 && which(s),
      );
  final shots = reduced
      ? [
          _Shot('tell', (m, k) => tell(k, StrikeAim.ship, .5)),
          _Shot('bolt', (m, k) => bolt(k, (s) => true)),
          _Shot(
            'afterglow',
            (m, k) =>
                k != null &&
                k.cell.strikes.any((s) => s.landed && s.glowLeft < .2),
          ),
          _Shot('rod', (m, k) => bolt(k, (s) => s.grounded)),
        ]
      : [
          _Shot('pursuit', (m, k) => m.mode == RunMode.travel),
          _Shot(
            'descent',
            (m, k) => k != null && m.flow.active && m.flow.env('cover') < .7,
          ),
          _Shot('arrival', (m, k) => k != null && m.combat && m.levelClock > 1),
          _Shot('tell-early', (m, k) => tell(k, StrikeAim.ship, .12)),
          _Shot('tell-late', (m, k) => tell(k, StrikeAim.ship, .85)),
          _Shot(
            'bolt-baited',
            (m, k) => bolt(k, (s) => s.aim == StrikeAim.ship && s.stunned > 0),
          ),
          _Shot(
            'rod-falling',
            (m, k) => m.pickups.any((p) => p.bonus != null && p.y > 200),
          ),
          _Shot('fork', (m, k) => tell(k, StrikeAim.fork, .6)),
          _Shot(
            'rod-tell',
            (m, k) =>
                k != null &&
                k.cell.strikes.any(
                  (s) => s.telling && s.rod && s.tellProgress > .7,
                ),
          ),
          _Shot('rod-grounded', (m, k) => bolt(k, (s) => s.grounded)),
          _Shot(
            'bolt-swarm',
            (m, k) => bolt(k, (s) => s.aim == StrikeAim.swarm),
          ),
          _Shot(
            'way-out',
            (m, k) => m.level == 3 && m.mode == RunMode.levelClear,
          ),
        ];

  var maxFlash = 0.0, bolts = 0, hits = 0;
  for (var f = 0; f < 60 * 240; f++) {
    final k = _mech(m);
    if (k != null) {
      maxFlash = math.max(
        maxFlash,
        StormPainter.flashOf(k.cell, reduced: reduced),
      );
      bolts = k.bolts;
      hits = k.shipHits;
    }
    for (final shot in shots) {
      if (shot.image == null && shot.when(m, k)) {
        shot.image = await _frame(scene);
        await _png(
          shot.image!,
          '$_dir/frames/${reduced ? 'reduced' : 'full'}-${shot.name}.png',
        );
      }
    }
    if (shots.every((s) => s.image != null)) break;
    if (m.level == 4 && m.combat) break; // past the storm
    _pilot(m);
    _step(m, scene);
  }
  final missing = [
    for (final s in shots)
      if (s.image == null) s.name,
  ];
  final name = reduced ? 'reduced' : 'stormfront';
  final sheet = await _sheet([
    for (final s in shots)
      if (s.image != null) s.image!,
  ], cols: reduced ? 4 : 6);
  await _png(sheet, '$_dir/bonus-level-b-$name.png');
  if (_contact) await _png(sheet, 'art/contact/bonus-level-b-$name.png');
  sheet.dispose();
  for (final s in shots) {
    s.image?.dispose();
  }
  return {
    'missing': missing,
    'flash': maxFlash,
    'bolts': bolts,
    'hits': hits,
    'score': m.score,
  };
}

void main() {
  testWidgets('Stormfront review strips, full and reduced motion', (
    tester,
  ) async {
    late Map<String, Object> full, reduced;
    await tester.runAsync(() async {
      full = await _review(reduced: false);
      reduced = await _review(reduced: true);
    });
    // ignore: avoid_print
    print('bonus-level-b review: full $full; reduced $reduced');
    expect(full['missing'], isEmpty);
    expect(reduced['missing'], isEmpty);
    // Gentle on the eyes: a faint flash at most, none with reduced motion.
    expect(full['flash'], lessThanOrEqualTo(StormPainter.maxFlash));
    expect(full['flash'], greaterThan(0));
    expect(reduced['flash'], 0);
    // The review pilot baits every bolt and is never struck.
    expect(full['hits'], 0);
  });
}
