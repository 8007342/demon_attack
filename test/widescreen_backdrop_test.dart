import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/squad_comms.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/widescreen_backdrop.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Review renders go to this directory with
/// --dart-define=WIDESCREEN_RENDER=/abs/dir (never into the checkout).
const renderDir = String.fromEnvironment('WIDESCREEN_RENDER');

/// Review renders only: real glyphs instead of the test font's boxes.
/// --dart-define=WIDESCREEN_FONT=/abs/Roboto-Regular.ttf
const _font = String.fromEnvironment('WIDESCREEN_FONT');

Future<void> _loadFont() async {
  if (_font.isEmpty || !File(_font).existsSync()) return;
  final bytes = File(_font).readAsBytesSync();
  for (final family in ['monospace', 'Roboto']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

class _Rig {
  _Rig(this.tester, this.scene);
  final WidgetTester tester;
  final DemonScene scene;
  ArcadeModel get model => scene.model;

  Future<void> tick([int frames = 1]) async {
    for (var i = 0; i < frames; i++) {
      scene.onTick();
    }
    await tester.pump();
  }
}

Future<_Rig> _launch(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var wall = 0.0;
  final comms = SquadComms(
    playAudio: false,
    lineupSeed: 5,
    wallClock: () => wall += .05,
  );
  if (renderDir.isNotEmpty) {
    await tester.runAsync(() async {
      await _loadFont();
      await WidescreenArt.instance.loadAll();
    });
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('page'),
          child: ArcadePage(
            scoreService: ScoreService(
              client: MockClient(
                (_) async => http.Response('{"scores":[]}', 200),
              ),
            ),
            runStorage: RunStorage(store: MemoryLocalStore()),
            squadComms: comms,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final scene =
      tester
              .widgetList<GameWidget>(
                find.byWidgetPredicate((w) => w is GameWidget),
              )
              .first
              .game
          as DemonScene;
  if (renderDir.isNotEmpty) {
    await tester.runAsync(() async {
      try {
        await scene.onLoad();
      } catch (_) {}
    });
    scene.ambient = 41.3;
  }
  return _Rig(tester, scene);
}

Future<void> _start(_Rig rig) async {
  await rig.tester.tap(find.text('START GAME  →'));
  await rig.tester.pump();
  rig.model.mode = RunMode.playing;
  await rig.tick();
}

Future<void> _snap(WidgetTester tester, String name) async {
  if (renderDir.isEmpty) return;
  final boundary =
      tester.renderObject(find.byKey(const ValueKey('page')))
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$renderDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

Rect _arena(WidgetTester tester) {
  final games = find.byWidgetPredicate((w) => w is GameWidget);
  final rects = [
    for (var i = 0; i < games.evaluate().length; i++)
      tester.getRect(games.at(i)),
  ];
  rects.sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
  return rects.first;
}

const _backdrop = ValueKey('widescreen-backdrop');

void main() {
  test('shows only on landscape windows with room beside the column', () {
    expect(WidescreenBackdrop.shows(const Size(390, 844)), isFalse);
    expect(WidescreenBackdrop.shows(const Size(820, 1180)), isFalse);
    expect(WidescreenBackdrop.shows(const Size(560, 400)), isFalse);
    expect(WidescreenBackdrop.shows(const Size(640, 480)), isTrue);
    for (final s in [
      const Size(1280, 720),
      const Size(1920, 1080),
      const Size(2560, 1080),
      const Size(3440, 1440),
      const Size(5120, 1440),
    ]) {
      expect(WidescreenBackdrop.shows(s), isTrue, reason: '$s');
      final u = WidescreenBackdropPainter.unit(s);
      expect(u, u.roundToDouble(), reason: 'whole-pixel scale');
      expect(160 * u, greaterThanOrEqualTo(s.height), reason: 'covers height');
    }
  });

  test('sector scenes follow the travel crossfade', () {
    expect(WidescreenBackdrop.assetsFor(BackdropScene.sector, 0), [
      'sector-1',
    ]);
    expect(WidescreenBackdrop.assetsFor(BackdropScene.sector, 2.4), [
      'sector-3',
      'sector-4',
    ]);
    expect(WidescreenBackdrop.assetsFor(BackdropScene.vista, 3), ['vista']);
  });

  testWidgets('phone portrait shows no backdrop', (tester) async {
    final rig = await _launch(tester, const Size(390, 844));
    expect(find.byKey(_backdrop), findsNothing);
    await _start(rig);
    expect(find.byKey(_backdrop), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in const [
    Size(1280, 720),
    Size(1920, 1080),
    Size(2560, 1080),
    Size(3440, 1440),
  ]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('$tag: every screen lays out without overflow', (
      tester,
    ) async {
      final rig = await _launch(tester, size);
      final model = rig.model;

      // Title: the fleet versus swarm vista.
      expect(find.byKey(_backdrop), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snap(tester, '$tag-1-title');

      // Gameplay: the sector's world, the column unchanged.
      await _start(rig);
      expect(find.byKey(_backdrop), findsOneWidget);
      final arena = _arena(tester);
      expect(arena.width, lessThanOrEqualTo(500));
      expect(arena.center.dx, closeTo(size.width / 2, 1));
      await rig.tick(80);
      await _snap(tester, '$tag-2-gameplay');

      // Travel crossfade toward the next sector, mid-fade.
      model.level = 3;
      rig.scene.environment = 2.5;
      await rig.tick();
      await _snap(tester, '$tag-3-travel');
      model.level = 4;
      rig.scene.environment = 3;
      await rig.tick();
      await _snap(tester, '$tag-4-hollow');

      // Pause.
      model.pause();
      await rig.tick();
      expect(tester.takeException(), isNull);
      await _snap(tester, '$tag-5-pause');
      model.resume();

      // Boss victory.
      model.mode = RunMode.victory;
      await rig.tick();
      expect(tester.takeException(), isNull);
      await _snap(tester, '$tag-6-victory');

      // Game over: the horde triumphant.
      model.mode = RunMode.gameOver;
      model.defeatTimer = 2;
      await rig.tick();
      expect(tester.takeException(), isNull);
      await _snap(tester, '$tag-7-gameover');

      // Initials entry / top 10: the hall of heroes.
      model.defeatTimer = 0;
      await rig.tick();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(_backdrop), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _snap(tester, '$tag-8-entry');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
