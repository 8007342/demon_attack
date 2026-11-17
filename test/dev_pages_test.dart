// dev-pages-overhaul: the gallery's scene list builds, every scene and
// atlas the dev pages show is one the game draws today, and the three
// pages link to each other (openspec/changes/dev-pages-overhaul).
import 'dart:convert';
import 'dart:io';

import 'package:demon_attack/game/boss_atlas.dart';
import 'package:demon_attack/game/boss_painter.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/game/perf/frame_budget.dart';
import 'package:demon_attack/gallery_main.dart';
import 'package:demon_attack/review/dev_nav.dart';
import 'package:demon_attack/review/gallery_scenes.dart';
import 'package:demon_attack/review/review_catalog.dart';
import 'package:demon_attack/review/review_notes.dart';
import 'package:demon_attack/review/review_platform_stub.dart';
import 'package:demon_attack/review/review_studio.dart';
import 'package:demon_attack/widgets/mission_medal_atlas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The game's own sources: lib/ without the review pages.
final _gameSource = [
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File &&
        f.path.endsWith('.dart') &&
        !f.path.contains('lib/review/') &&
        !f.path.endsWith('gallery_main.dart'))
      f.readAsStringSync(),
].join('\n');

/// Whether the game names [file] (an `assets/images/` file) literally.
bool _gameNames(String file) => _gameSource.contains(file);

/// The hero hull every run draws, over the five tours and a spread of
/// run seeds' variants.
Set<String> _heroAssets() => {
  for (var route = 0; route < 8; route++)
    for (var variant = 0; variant < 16; variant++)
      ...BossPainter.assetsOf(BossPainter.heroForRun(route, variant)!.key),
};

void main() {
  group('scene list', () {
    test('ids are unique and every area is listed', () {
      final ids = [for (final p in scenePages) p.id];
      expect(ids.toSet().length, ids.length);
      expect({for (final p in scenePages) p.area}, GameArea.values.toSet());
      // Notes written against the earlier pages keep their scene.
      expect(
        ids,
        containsAll([
          'creatures',
          'elites',
          'actions',
          'weapons',
          'sentinels',
          'carrier',
        ]),
      );
    });

    test('every scene page builds its tiles', () {
      for (final p in scenePages) {
        final tiles = galleryTiles(p.id);
        expect(tiles, isNotEmpty, reason: p.id);
        for (final t in tiles) {
          expect(t.label, isNotEmpty, reason: p.id);
          expect(t.scene != null || t.widget != null, isTrue, reason: p.id);
          final s = t.scene;
          if (s == null) continue;
          expect(s.live, p.live, reason: '${p.id} ${t.label}');
          if (!s.live) {
            // A staged model is started like the game's (a sector and
            // run), never a bare ArcadeModel.
            expect(s.model.level, inInclusiveRange(1, 4), reason: p.id);
            expect(s.model.mode, RunMode.playing, reason: p.id);
          }
        }
      }
      expect(galleryTiles('no-such-page').single.label, 'CREATURES');
    });

    test('carrier scenes run the console fight on a packed hero hull', () {
      for (final id in ['carrier', 'carrier-tours']) {
        for (final t in galleryTiles(id)) {
          final m = t.scene!.model;
          expect(m.level, 5, reason: t.label);
          expect(
            BossPainter.heroForRun(m.cycle, m.bossVariant),
            isNotNull,
            reason: '${t.label}: drawn from its hero hull, not a fallback',
          );
          // A few seconds of the run: the carrier is up (the approach
          // tile reaches it later) and the ship stays alive.
          for (var i = 0; i < 180; i++) {
            GalleryScene.keepAlive(m);
            m.update(1 / 60);
          }
          if (!t.label.contains('APPROACH')) {
            expect(m.boss, isNotNull, reason: t.label);
          }
          expect(m.mode, isNot(RunMode.gameOver), reason: t.label);
        }
      }
    });

    test('weather, bonus and perf tiles carry their forced state', () {
      final weather = galleryTiles('weather');
      expect(weather.length, weatherSpecs.length);
      for (final (i, t) in weather.indexed) {
        expect(t.scene!.rain.override, weatherSpecs[i].$3);
      }
      for (final t in galleryTiles('bonus')) {
        expect(t.scene!.model.bonus, isNotNull, reason: t.label);
      }
      expect([
        for (final t in galleryTiles('perf-tiers')) t.scene!.perf.tier,
      ], PerfTier.values);
      expect(MedalSheet.ids, isNotEmpty);
    });

    test('every source names an OpenSpec change or spec', () {
      final archive = Directory('openspec/changes/archive')
          .listSync()
          .map((d) => d.path.split('/').last)
          .toList();
      for (final p in scenePages) {
        expect(p.sources, isNotEmpty, reason: p.id);
        for (final s in p.sources) {
          final found =
              Directory('openspec/changes/$s').existsSync() ||
              Directory('openspec/specs/$s').existsSync() ||
              archive.any((a) => a.endsWith('-$s'));
          expect(found, isTrue, reason: '${p.id}: $s');
        }
      }
    });
  });

  group('staleness guard', () {
    test('scene assets are game assets', () {
      for (final p in scenePages) {
        for (final a in p.assets) {
          expect(
            File('assets/images/$a').existsSync(),
            isTrue,
            reason: '${p.id}: $a',
          );
          expect(_gameNames(a), isTrue, reason: '${p.id}: the game draws $a');
        }
      }
      for (final id in MedalSheet.ids) {
        expect(MissionMedalAtlas.cells, contains('ribbon.$id'));
      }
    });

    test('every studio atlas is one the game draws, never a fallback', () {
      final ship = jsonDecode(
        File('assets/images/ship-weapons.json').readAsStringSync(),
      );
      final anims = atlasAnimations(shipWeapons: ship as Map<String, Object?>);
      final hero = _heroAssets();
      // Sheets the game keeps only as a fallback while the current art
      // loads (or never, once every tour is packed).
      final fallbacks = {
        for (final c in BossAtlas.classes) c.asset,
        'ground-troops.png',
      };
      for (final a in anims) {
        expect(File(a.path).existsSync(), isTrue, reason: a.path);
        expect(_gameNames(a.image), isTrue, reason: '${a.group}: ${a.image}');
        expect(fallbacks, isNot(contains(a.image)), reason: a.group);
        if (a.image.startsWith('boss-')) {
          expect(hero, contains(a.image), reason: a.group);
        }
      }
      // The current art is listed.
      final images = {for (final a in anims) a.image};
      expect(
        images,
        containsAll([
          'insignia.png',
          'hatch-emergence.png',
          'sentinel-silhouettes.png',
          'ground-wildlife.png',
        ]),
      );
    });

    test('every tour draws a packed hero hull (the frontal sheets are '
        'unreachable)', () {
      for (var route = 0; route < 8; route++) {
        for (var variant = 0; variant < 16; variant++) {
          expect(
            BossPainter.heroForRun(route, variant),
            isNotNull,
            reason: 'route $route variant $variant',
          );
        }
      }
    });

    test('the removed provisional ship pack stays removed', () {
      expect(File('assets/images/ship-parts.png').existsSync(), isFalse);
      expect(File('assets/images/ship-parts.json').existsSync(), isFalse);
      expect(_gameNames('ship-parts'), isFalse);
    });
  });

  group('navigation', () {
    testWidgets('the gallery index lists every scene by area', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const GalleryApp(query: {}, path: '/gallery/'));
      await tester.pump();
      for (final p in DevPage.values) {
        expect(find.byKey(ValueKey('dev-nav-${p.name}')), findsOneWidget);
      }
      for (final a in GameArea.values) {
        expect(find.text(a.label), findsWidgets, reason: a.name);
      }
      for (final p in scenePages) {
        expect(
          find.byKey(ValueKey('gallery-scene-${p.id}')),
          findsOneWidget,
          reason: p.id,
        );
      }
      expect(find.byKey(const ValueKey('dev-footer-version')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a widget scene page shows its label and sources', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const GalleryApp(query: {'page': 'medals'}, path: '/gallery/'),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('gallery-scene-label')), findsOneWidget);
      expect(find.textContaining('mission-medals'), findsWidgets);
      expect(find.byKey(const ValueKey('gallery-index')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the studio groups scenes by area and links the pages', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewStudio(
            platform: MemoryReviewPlatform(),
            sceneBuilder: (page) => Text('scene $page'),
            loadText: (path) async => null,
            initialTab: StudioTab.scenes,
          ),
        ),
      );
      await tester.pump();
      for (final p in DevPage.values) {
        expect(find.byKey(ValueKey('dev-nav-${p.name}')), findsOneWidget);
      }
      for (final a in GameArea.values) {
        expect(
          find.byKey(ValueKey('scene-area-${a.name}')),
          findsOneWidget,
          reason: a.name,
        );
      }
      expect(find.text('scene creatures'), findsOneWidget);
      expect(sceneAsset('carrier').source, contains('carrier-v3'));
      expect(sceneAsset('carrier').kind, ReviewKind.scene);
      expect(find.byKey(const ValueKey('dev-footer-version')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
