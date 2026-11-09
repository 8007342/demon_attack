import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_view.dart';
import 'package:demon_attack/comms/squad_comms.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Review frames are written to this directory with
/// --dart-define=COMMS_RENDER=/abs/dir (never into the checkout).
const renderDir = String.fromEnvironment('COMMS_RENDER');

class _Rig {
  _Rig(this.tester, this.comms, this.scene);
  final WidgetTester tester;
  final SquadComms comms;
  final DemonScene scene;
  ArcadeModel get model => scene.model;
  CommsDirector get director => comms.director;

  /// Feeds raw model events and advances the comms clock in small steps.
  Future<void> run(List<String> raw, double seconds) async {
    model.events.addAll(raw);
    final steps = (seconds / .05).ceil().clamp(1, 1000);
    for (var i = 0; i < steps; i++) {
      _wall += seconds / steps;
      scene.onTick();
    }
    await tester.pump();
  }
}

double _wall = 0;

/// Review frames only: real glyphs instead of the test font's boxes.
/// --dart-define=COMMS_FONTS=/dir/with/Roboto-Regular.ttf,Roboto-Bold.ttf
const _fontDir = String.fromEnvironment('COMMS_FONTS');
bool _fontsLoaded = false;
Future<void> _loadReviewFonts() async {
  if (_fontsLoaded || _fontDir.isEmpty) return;
  _fontsLoaded = true;
  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
    final file = File('$_fontDir/$name');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      roboto.addFont(Future.value(ByteData.sublistView(bytes)));
    }
  }
  await roboto.load();
  final icons = File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

Future<_Rig> _launch(
  WidgetTester tester,
  Size size, {
  bool reduce = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _wall = 0;
  final comms = SquadComms(
    playAudio: false,
    lineupSeed: 5,
    wallClock: () => _wall,
  );
  await tester.runAsync(() => CommsPortraitAtlas.instance.load());
  if (renderDir.isNotEmpty) await tester.runAsync(_loadReviewFonts);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: reduce),
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
  await tester.tap(find.text('START GAME  →'));
  await tester.pump();
  final scene =
      tester
              .widgetList<GameWidget>(
                find.byWidgetPredicate((w) => w is GameWidget),
              )
              .first
              .game
          as DemonScene;
  scene.model.mode = RunMode.playing;
  return _Rig(tester, comms, scene);
}

Rect _arena(WidgetTester tester) {
  final games = find.byWidgetPredicate((w) => w is GameWidget);
  final rects = [
    for (var i = 0; i < games.evaluate().length; i++)
      tester.getRect(games.at(i)),
  ];
  rects.sort((a, b) => (a.width * a.height).compareTo(b.width * b.height));
  return rects.first; // the arena proxy, not the full-screen sky
}

Future<void> _snap(WidgetTester tester, String name) async {
  if (renderDir.isEmpty) return;
  final boundary = tester.renderObject(
    find.byKey(const ValueKey('page')),
  ) as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$renderDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  test('layout modes', () {
    expect(CommsLayout.of(const Size(1440, 900)).side, isTrue);
    expect(CommsLayout.of(const Size(800, 700)).side, isTrue);
    expect(CommsLayout.of(const Size(760, 900)).side, isFalse);
    expect(CommsLayout.of(const Size(390, 844)).side, isFalse);
    expect(CommsLayout.of(const Size(1440, 300)).side, isFalse);
    for (final size in [
      const Size(800, 600),
      const Size(1440, 900),
      const Size(2560, 1300),
    ]) {
      final layout = CommsLayout.of(size);
      final rects = layout.tileRects(size);
      final cabinet = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: CommsLayout.cabinetWidth,
        height: size.height,
      );
      expect(rects, hasLength(4));
      for (final r in rects) {
        expect(r.overlaps(cabinet), isFalse, reason: '$size $r');
        expect(r.top, greaterThanOrEqualTo(0));
        expect(r.bottom, lessThanOrEqualTo(size.height));
      }
      expect(rects[0].bottom, lessThanOrEqualTo(rects[1].top));
    }
  });

  testWidgets('wide desktop: four call tiles beside the shared arena', (
    tester,
  ) async {
    final rig = await _launch(tester, const Size(1440, 900));
    await rig.run([], 7);
    await rig.run(['reinforcements'], 3.2);
    await rig.run(['allyUnderAttack:1,120'], 1.4);
    await rig.run(['groundForceSighted'], 3.0);
    await rig.run(['shieldSpotted'], .2);
    await rig.run([], .6);
    final occupied = rig.director.slots.where((s) => s.occupant != null).length;
    expect(
      occupied,
      4,
      reason:
          '${rig.director.slots.map((s) => s.occupant).join(',')} ${rig.director.history}',
    );
    final arena = _arena(tester);
    final cabinet = Rect.fromLTWH((1440 - 500) / 2, 0, 500, 900);
    for (var i = 0; i < 4; i++) {
      final tile = tester.getRect(find.byKey(ValueKey('comms-tile-$i')));
      expect(tile.overlaps(cabinet), isFalse, reason: 'tile $i $tile');
      expect(tile.overlaps(arena), isFalse);
    }
    expect(find.byKey(const ValueKey('comms-hud-stack')), findsNothing);
    expect(
      find.text('DEMON / ATTACK'),
      findsNothing,
      reason: 'side labels yield to the call',
    );
    await _snap(tester, 'wide-four-slots');
    // A grunting officer's tile zooms in, inside its own margin.
    await rig.run([], 2.5);
    await rig.run(['eliteSighted'], 0);
    await rig.run([], 1.05);
    final demon = rig.director.active.where((m) => m.isDemon).firstOrNull;
    expect(demon, isNotNull);
    final zoomed = tester.getRect(
      find.byKey(ValueKey('comms-tile-${demon!.slot}')),
    );
    expect(
      zoomed.height,
      greaterThan(
        CommsLayout.of(const Size(1440, 900))
                .tileRects(const Size(1440, 900))[demon.slot]
                .height *
            1.2,
      ),
    );
    expect(zoomed.overlaps(cabinet), isFalse);
    await _snap(tester, 'wide-demon-zoom');
  });

  for (final (name, size) in [
    ('phone-360x780', const Size(360, 780)),
    ('phone-390x844', const Size(390, 844)),
    ('phone-412x915', const Size(412, 915)),
    ('phone-360x640', const Size(360, 640)),
    ('landscape-740x360', const Size(740, 360)),
    ('narrow-700x900', const Size(700, 900)),
  ]) {
    testWidgets('compact $name: the call dock never covers the HUD', (
      tester,
    ) async {
      final rig = await _launch(tester, size);
      await rig.run([], .1);
      await rig.run(['reinforcements'], .9);
      final stack = find.byKey(const ValueKey('comms-hud-stack'));
      expect(stack, findsOneWidget);
      expect(find.byKey(const ValueKey('comms-tile-0')), findsNothing);
      expect(
        rig.director.active.length,
        2,
        reason: 'human line and demon grunt',
      );
      // One strip, the second message collapsed into a chip.
      final rects = [
        for (final m in rig.director.active) ...[
          ...find
              .byKey(ValueKey('comms-strip-${m.line.id}'))
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget))),
          ...find
              .byKey(ValueKey('comms-chip-${m.line.id}'))
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget))),
        ],
      ];
      expect(rects, hasLength(2));
      expect(find.byKey(const ValueKey('hud-score')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-lives')), findsOneWidget);
      expect(find.byKey(const ValueKey('hud-hearts')), findsOneWidget);
      final hud = [
        for (final key in ['hud-score', 'hud-lives', 'hud-hearts'])
          (key, tester.getRect(find.byKey(ValueKey(key)))),
      ];
      final arena = _arena(tester);
      final ship = Rect.fromLTWH(
        arena.left,
        arena.top + arena.height * .7,
        arena.width,
        arena.height * .3,
      );
      for (final r in [...rects, tester.getRect(stack)]) {
        for (final (key, h) in hud) {
          expect(r.overlaps(h), isFalse, reason: '$key $h vs comms $r');
        }
        expect(r.top, greaterThanOrEqualTo(arena.top), reason: 'below HUD');
        expect(r.overlaps(ship), isFalse, reason: 'player ship region');
      }
      await _snap(tester, 'compact-$name');
      if (size.width == 390) {
        await rig.run([], .2);
        await _snap(tester, 'phone-demon-zoom');
      }
    });
  }

  testWidgets('reduced motion: no zoom shake, call still shows', (
    tester,
  ) async {
    final rig = await _launch(tester, const Size(1440, 900), reduce: true);
    await rig.run([], .1);
    await rig.run(['reinforcements'], 1.0);
    expect(rig.director.active.any((m) => m.isDemon), isTrue);
    expect(tester.takeException(), isNull);
  });
}
