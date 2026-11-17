// phone-performance §2: the frame-cost harness.
//
// Renders the heaviest scenes headless through a CountingCanvas and records,
// per layer, the draw calls, sprites, vertex draws, saveLayers and blurs, plus
// the scene's own object counts (shots, creatures, blasts, rain, shadows,
// carrier mesh). Counts are deterministic; the wall times it also prints are
// the forge CPU's and only indicative (the tester rasterises on the CPU).
//
//   flutter test --concurrency=1 --run-skipped --tags review \
//     --dart-define=PERF_TAG=after test/phone_performance_review_test.dart
//
// Writes build/perf/<tag>.json and build/perf/<tag>-<scene>.png (the frame
// at phone size, for the before/after contact sheets in art/contact/).
@Tags(['review'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_grammar.dart';
import 'package:demon_attack/game/ground_atlas.dart';
import 'package:demon_attack/game/ground_atmosphere.dart';
import 'package:demon_attack/game/ground_atmosphere_atlas.dart';
import 'package:demon_attack/game/ground_blocks_painter.dart';
import 'package:demon_attack/game/ground_troops_atlas.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/perf/frame_budget.dart'; // TIERS-LINE
import 'package:demon_attack/game/scene.dart';
import 'package:demon_attack/game/sentinel_silhouette_atlas.dart';
import 'package:demon_attack/game/weather/rain_plan.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'boss_carrier_wire_review_test.dart' show seedFor;
import 'support/counting_canvas.dart';

const _tag = String.fromEnvironment('PERF_TAG', defaultValue: 'after');
const _phone = (w: 390.0, h: 844.0); // iPhone 12-15 CSS viewport
const _dpr = 3.0;

final _decoded = <String, ui.Image>{};
Future<ui.Image> _decode(String file) async {
  final hit = _decoded[file];
  if (hit != null) return hit;
  final codec = await ui.instantiateImageCodec(await File(file).readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return _decoded[file] = frame.image;
}

/// Sector backdrops: whichever format is committed (png before, webp after).
String _sector(int i) {
  for (final ext in ['webp', 'png']) {
    final f = 'assets/images/sector-$i.$ext';
    if (File(f).existsSync()) return f;
  }
  throw StateError('no sector-$i art');
}

String _art(String stem) {
  for (final ext in ['webp', 'png']) {
    final f = 'assets/images/$stem.$ext';
    if (File(f).existsSync()) return f;
  }
  throw StateError('no $stem art');
}

Future<DemonScene> _scene(ArcadeModel m) async {
  final scene = DemonScene(m, () {});
  for (var i = 0; i < 5; i++) {
    scene.sectors.images[i] = await _decode(_sector(i + 1));
  }
  await scene.sectors.loadFlyover((f) => _decode('assets/images/$f'));
  scene.sectors.flyover.reducedMotionOverride = false;
  scene.atlas = await _decode('assets/images/combat.png');
  scene.effectsAtlas = await _decode('assets/images/sentinel-effects.png');
  scene.sky = await _decode(_art('cosmic-sky'));
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
  scene.environment = m.level - 1.0;
  scene.rain.emit = (_) {};
  return scene;
}

void _step(ArcadeModel m, DemonScene scene, {bool protect = true}) {
  if (protect) {
    m
      ..lives = 5
      ..invulnerable = 5;
  }
  scene.advancePresentation(1 / 60);
  m.update(1 / 60);
  scene.creatures.update(m, 1 / 60);
}

/// One measured frame: counts per layer, object counts, timings.
Future<Map<String, Object?>> _measure(
  DemonScene scene,
  String name, {
  Map<String, Object?> extra = const {},
}) async {
  final m = scene.model;
  final size = Vector2(_phone.w, _phone.h);
  final rec = ui.PictureRecorder();
  final counting = CountingCanvas(rec);
  counting.scale(_dpr);
  scene.paintArena(counting, size);
  final pic = rec.endRecording();
  // Indicative timings (forge CPU): Dart recording, and CPU raster at 3x.
  final sw = Stopwatch()..start();
  for (var i = 0; i < 30; i++) {
    final r = ui.PictureRecorder();
    final c = ui.Canvas(r)..scale(_dpr);
    scene.paintArena(c, size);
    r.endRecording().dispose();
  }
  final recordUs = sw.elapsedMicroseconds / 30;
  final w = (_phone.w * _dpr).round(), h = (_phone.h * _dpr).round();
  (await pic.toImage(w, h)).dispose();
  sw
    ..reset()
    ..start();
  for (var i = 0; i < 5; i++) {
    (await pic.toImage(w, h)).dispose();
  }
  final rasterUs = sw.elapsedMicroseconds / 5;
  // The frame at 1x for the contact sheets.
  final r1 = ui.PictureRecorder();
  scene.paintArena(ui.Canvas(r1), size);
  final p1 = r1.endRecording();
  final img = await p1.toImage(_phone.w.round(), _phone.h.round());
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  p1.dispose();
  pic.dispose();
  final file = File('build/perf/$_tag-$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png!.buffer.asUint8List());

  final total = counting.total;
  final out = <String, Object?>{
    'total': total.toMap(),
    'layers': {for (final e in counting.layers.entries) e.key: e.value.toMap()},
    'objects': {
      'shots': m.shots.length,
      'demons': m.demons.length,
      'blasts': m.blasts.length,
      'deflects': m.deflects.length,
      'groundUnits': m.ground.units.length,
      'rainFar': scene.rain.lastFar,
      'rainNear': scene.rain.lastNear,
      'rainSplashes': scene.rain.lastSplashes,
      'shadows': scene.shadowCount,
      'shadowLayers': scene.shadowLayers,
      'environment': scene.environment,
      ...extra,
    },
    'recordMs': recordUs / 1000,
    'cpuRasterMs': rasterUs / 1000,
  };
  // ignore: avoid_print
  print(
    'PERF $_tag $name: $total | record ${(recordUs / 1000).toStringAsFixed(2)} ms, '
    'cpu raster ${(rasterUs / 1000).toStringAsFixed(1)} ms | ${out['objects']}',
  );
  for (final e in counting.layers.entries) {
    // ignore: avoid_print
    print('PERF $_tag $name   ${e.key.padRight(10)} ${e.value}');
  }
  return out;
}

/// Fills the swarm to the active cap and the sky with a bullet fight:
/// [player] player shots in streams and [hostile] hostile shots.
void _bulletFight(ArcadeModel m, {int player = 70, int hostile = 60}) {
  final template = m.demons.firstWhere((d) => !d.isLarge);
  while (m.demons.length < ArcadeModel.maxActiveDemons) {
    final i = m.demons.length;
    m.demons.add(
      Demon(
          30 + (i % 10) * 30.0,
          70 + (i ~/ 10) * 34.0,
          template.kind,
          1,
          i * .7,
        )
        ..nearness = .62 + (i ~/ 10) * .03
        ..altitude = 80
        ..scale = 1.2,
    );
  }
  m.shots.removeWhere((s) => true);
  for (var i = 0; i < player; i++) {
    final lane = i % 5;
    m.shots.add(
      Shot(120 + lane * 30.0, 460 - (i ~/ 5) * 30.0, (lane - 2) * 40.0, -390)
        ..age = i * .03,
    );
  }
  for (var i = 0; i < hostile; i++) {
    m.shots.add(
      Shot(
        20 + (i * 37) % 320,
        90 + (i * 53) % 360,
        ((i % 7) - 3) * 20.0,
        i.isEven ? 240 : 130,
        hostile: true,
        kind: i % 3 == 0 ? ShotKind.sentinel : ShotKind.ordinary,
      )..age = i * .05,
    );
  }
  for (var i = 0; i < 30; i++) {
    m.blasts.add(Blast(30 + i * 10.0, 120 + (i * 31) % 260)..age = i * .015);
  }
}

void main() {
  testWidgets('phone-performance frame-cost harness', (tester) async {
    await tester.runAsync(() async {
      final results = <String, Object?>{};

      // 1. A dense bullet fight: sector 4, hard, 61 creatures, 130 shots.
      {
        final m = ArcadeModel(seed: 6)
          ..startAt(difficulty: Difficulty.hard, sector: 4, route: 4);
        final scene = await _scene(m);
        for (var i = 0; i < 60 * 8; i++) {
          _step(m, scene);
          m.shots.removeWhere((s) => !s.hostile);
        }
        _bulletFight(m);
        scene.advancePresentation(1 / 60);
        results['bullet-fight'] = await _measure(scene, 'bullet-fight');
        // TIERS-BEGIN (the baseline has no tiers)
        for (final t in [PerfTier.lean, PerfTier.lite]) {
          scene.perf.forced = t;
          scene.applyBudget();
          results['bullet-fight-${t.name}'] = await _measure(
            scene,
            'bullet-fight-${t.name}',
          );
        }
        scene.perf.forced = null;
        scene.applyBudget();
        // TIERS-END
      }

      // 2. The ground war at its busiest (sector 3), rain forced on.
      {
        final m = ArcadeModel(seed: 1982)..startAt(sector: 3);
        final scene = await _scene(m);
        scene.rain.override = const RainSpec(
          tier: RainTier.downpour,
          peak: .95,
          wind: .3,
        );
        var next = 0.0;
        for (var f = 0; f < 60 * 40; f++) {
          if (m.combat && m.levelClock >= next) {
            next = m.levelClock + 2.6;
            final t = m.demons.where((x) => !x.entering).firstOrNull;
            if (t != null) m.hitDemon(t, damage: 99);
          }
          _step(m, scene);
          if (f > 60 * 20 &&
              m.ground.tracers.isNotEmpty &&
              m.ground.units.where((u) => u.alive && u.z < 800).length >= 2) {
            break;
          }
        }
        results['ground-war-rain'] = await _measure(scene, 'ground-war-rain');
        // TIERS-BEGIN (the baseline has no tiers)
        for (final t in [PerfTier.lean, PerfTier.lite]) {
          scene.perf.forced = t;
          scene.applyBudget();
          scene.advancePresentation(1 / 60);
          results['ground-war-rain-${t.name}'] = await _measure(
            scene,
            'ground-war-rain-${t.name}',
          );
        }
        scene.perf.forced = null;
        scene.applyBudget();
        // TIERS-END
        // The same frame, the environment a hair short of the sector (the
        // exponential approach after a travel never lands on the integer).
        scene.environment = 2 - 1e-12;
        scene.advancePresentation(1 / 60);
        results['ground-war-env-unsettled'] = await _measure(
          scene,
          'ground-war-env-unsettled',
        );
      }

      // 3. The carrier fight into its break-up (sector 5, route 0).
      {
        const route = 0;
        final key = BossGrammar.baked[route][0];
        final m = ArcadeModel(seed: 11)
          ..startAt(
            sector: 5,
            route: route,
            wave: ArcadeModel.wavesFor(sector: 5, route: route),
            runSeed: seedFor(route, 0),
          );
        final scene = await _scene(m);
        scene.bossDirector.reset();
        final hull = BossHeroAtlas.hulls[key]!;
        final pages = [
          for (final p in hull.pages) await _decode('assets/images/$p'),
        ];
        scene.armada.setHero(route, hull, pages);
        await scene.breakup.prepare(scene.armada);
        for (var g = 0; g < 60 * 50 && !m.boss!.fightReady; g++) {
          _step(m, scene);
        }
        expect(m.boss!.fightReady, isTrue);
        for (var g = 0; g < 60 * 3; g++) {
          _step(m, scene);
        }
        results['carrier-fight'] = await _measure(
          scene,
          'carrier-fight',
          extra: {
            'meshVertices': scene.armada.meshVertices,
            'breakupVertices': scene.breakup.lastVertices,
          },
        );
        final b = m.boss!..shield = 0;
        for (var g = 0; g < 6; g++) {
          _step(m, scene);
        }
        for (var g = 0; g < 108; g++) {
          _step(m, scene);
        }
        b.core = (b.coreMax * (1 - 1 / b.armourSteps)).floor();
        b.door = 1;
        m.hitBoss(b.x);
        for (var g = 0; g < 78; g++) {
          _step(m, scene);
        }
        b.core = (b.coreMax * (1 - 2 / b.armourSteps)).floor() + 1;
        b.door = 1;
        m.hitBoss(b.x);
        for (var g = 0; g < 72; g++) {
          _step(m, scene);
        }
        results['carrier-breakup'] = await _measure(
          scene,
          'carrier-breakup',
          extra: {
            'meshVertices': scene.armada.meshVertices,
            'breakupVertices': scene.breakup.lastVertices,
            'breakupCalls': scene.breakup.lastCalls,
            'components': scene.breakup.components.length,
          },
        );
      }

      final file = File('build/perf/$_tag.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent(' ').convert(results),
      );
      for (final img in _decoded.values) {
        img.dispose();
      }
      _decoded.clear();
    });
  });
}
