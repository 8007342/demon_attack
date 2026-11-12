import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/comms/comms_director.dart';
import 'package:demon_attack/comms/comms_mouth.dart';
import 'package:demon_attack/comms/comms_portraits.dart';
import 'package:demon_attack/comms/comms_types.dart';
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

  /// Runs until [test] holds (or [limit] seconds pass).
  Future<bool> until(bool Function() test, {double limit = 12}) async {
    for (var t = 0.0; t < limit; t += .05) {
      if (test()) {
        await tester.pump();
        return true;
      }
      _wall += .05;
      scene.onTick();
    }
    await tester.pump();
    return test();
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
    for (final raw in [
      'reinforcements',
      'allyUnderAttack:1,120',
      'groundForceSighted',
      'diveWarning',
    ]) {
      if (rig.director.slots.every((s) => s.occupant != null)) break;
      await rig.run([raw], 6);
    }
    await rig.until(() => rig.director.active.any((m) => !m.isDemon));
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
    await rig.run(['demonRout'], 0);
    await rig.until(
      () => rig.director.active.any(
        (m) =>
            m.isDemon && m.age(rig.comms.now) > .5 && m.speaking(rig.comms.now),
      ),
    );
    final demon = rig.director.active
        .where((m) => m.isDemon && m.speaking(rig.comms.now))
        .firstOrNull;
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
      await rig.run([], 7);
      // A lost ship: our line plus the brood's overlapping celebration.
      await rig.run(['life'], .5);
      final stack = find.byKey(const ValueKey('comms-hud-stack'));
      expect(stack, findsOneWidget);
      expect(find.byKey(const ValueKey('comms-tile-0')), findsNothing);
      expect(
        rig.director.active.length,
        greaterThanOrEqualTo(2),
        reason: '${rig.director.active}',
      );
      // Both callers get readable cards in the same row.
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
      expect(rects.length, 2, reason: 'two full dialogue cards');
      expect(rects[0].top, rects[1].top);
      expect(rects[0].overlaps(rects[1]), isFalse);
      expect(rects[0].width, closeTo(rects[1].width, .01));
      final ordered = [...rects]..sort((a, b) => a.left.compareTo(b.left));
      final faces = [
        for (final m in rig.director.active)
          ...find
              .byKey(ValueKey('comms-portrait-${m.line.id}'))
              .evaluate()
              .map((e) => tester.getRect(find.byWidget(e.widget))),
      ]..sort((a, b) => a.left.compareTo(b.left));
      expect(faces.first.left - ordered.first.left, lessThan(4));
      expect(ordered.last.right - faces.last.right, lessThan(4));
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
        await rig.run([], 4);
        await rig.run(['demonRout'], 0);
        await rig.until(
          () => rig.director.active.any(
            (m) =>
                m.isDemon &&
                m.speaking(rig.comms.now) &&
                m.age(rig.comms.now) > .25,
          ),
        );
        await _snap(tester, 'phone-demon-zoom');
      }
    });
  }

  testWidgets('compact reply keeps its retired opening line visible', (
    tester,
  ) async {
    final director = CommsDirector();
    const trigger = CommsTriggerSpec(
      name: 'exchange',
      priority: 1,
      cooldown: 1,
      ttl: 10,
      lines: [],
    );
    CommsMessage message(String id, String text, double start) => CommsMessage(
      trigger: trigger,
      line: CommsLine(
        id: id,
        speaker: commsCast.values.first.id,
        duration: 1,
        text: text,
      ),
      character: commsCast.values.first,
      priority: 1,
      queuedAt: 0,
      readyAt: 0,
      expiresAt: 10,
      sequence: 0,
    )..startedAt = start;
    final opening = message('opening', 'That sector is mine!', 0);
    final answer = message('answer', 'Only until my next turn!', 2)
      ..inReplyTo = opening;
    director.active.add(answer); // Opener has already retired from audio.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CommsHudStack(director: director, now: 2.5),
          ),
        ),
      ),
    );
    expect(
      find.textContaining('That sector is mine!', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Only until my next turn!', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('comms-strip-opening')), findsOneWidget);
    expect(find.byKey(const ValueKey('comms-strip-answer')), findsOneWidget);
    final toast = find.byKey(const ValueKey('comms-conversation'));
    expect(toast, findsOneWidget);
    expect(tester.getSize(toast).width, 360);
    final firstPortrait = tester.getRect(
      find.byKey(const ValueKey('comms-portrait-opening')),
    );
    final secondPortrait = tester.getRect(
      find.byKey(const ValueKey('comms-portrait-answer')),
    );
    expect(firstPortrait.left, lessThan(10));
    expect(secondPortrait.right, greaterThan(350));
    expect(tester.takeException(), isNull);

    // An isolated call reserves half the dock, even when no second call exists.
    answer.inReplyTo = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CommsHudStack(director: director, now: 2.5),
          ),
        ),
      ),
    );
    expect(toast, findsNothing);
    final isolated = find.byKey(const ValueKey('comms-strip-answer'));
    expect(tester.getSize(isolated).width, 179);
    director.active.add(message('unrelated', 'Hold the line!', 2.1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: CommsHudStack(director: director, now: 2.5),
          ),
        ),
      ),
    );
    final unrelated = find.byKey(const ValueKey('comms-strip-unrelated'));
    expect(tester.getSize(unrelated).width, 179);
    expect(
      tester.getRect(isolated).overlaps(tester.getRect(unrelated)),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: a full transmission replaces the travel transition', (
    tester,
  ) async {
    final rig = await _launch(tester, const Size(390, 844));
    await rig.run([], 7);
    rig.model.mode = RunMode.travel;
    rig.model.transitionDuration = 12;
    rig.model.transitionLeft = 12;
    await rig.run(['travel'], 0);
    final on = await rig.until(
      () =>
          rig.director.transmission != null &&
          rig.director.transmission!.age(rig.comms.now) > 1.2,
      limit: 20,
    );
    expect(on, isTrue, reason: '${rig.director.history}');
    final card = find.byKey(
      ValueKey('comms-transmission-${rig.director.transmission!.line.id}'),
    );
    expect(card, findsOneWidget);
    final hud = tester.getRect(find.byKey(const ValueKey('hud-score')));
    expect(tester.getRect(card).overlaps(hud), isFalse);
    await _snap(tester, 'phone-transmission');
  });

  testWidgets('review: lip-sync sequences at desktop and phone sizes', (
    tester,
  ) async {
    if (renderDir.isEmpty) return;
    await tester.runAsync(() => CommsPortraitAtlas.instance.load());
    for (final (id, speaker) in [
      ('sectorStart.1.h0', 'admiral'),
      ('allyUnderAttack.h0', 'kessler'),
      ('reinforcements.d0', 'gorrak'),
    ]) {
      final line = [
        for (final spec in [
          ...commsHumanTriggers.values,
          ...commsDemonTriggers.values,
        ])
          ...spec.lines,
      ].firstWhere((l) => l.id == id);
      expect(line.speaker, speaker);
      final frames = CommsMouth.of(line).frames;
      final count = frames.length.clamp(1, 24);
      for (final (label, cell, small, scale) in [
        ('desktop', commsPortraitCell, false, 2),
        ('phone', commsPortraitSmallCell, true, 1),
      ]) {
        final w = cell * scale;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w * 12.0, (w * ((count + 11) ~/ 12)).toDouble()),
          Paint()..color = const Color(0xFF0B1424),
        );
        for (var i = 0; i < count; i++) {
          final r = Rect.fromLTWH(
            (i % 12) * w.toDouble(),
            (i ~/ 12) * w.toDouble(),
            w.toDouble(),
            w.toDouble(),
          );
          paintBackdrop(
            canvas,
            r,
            commsCast[speaker]!,
            i / 15,
            reduceMotion: true,
          );
          paintPortrait(canvas, r, speaker, frames[i], small: small);
        }
        final picture = recorder.endRecording();
        await tester.runAsync(() async {
          final image = await picture.toImage(w * 12, w * ((count + 11) ~/ 12));
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$renderDir/mouth-$speaker-$label.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });

  testWidgets('reduced motion: no zoom shake, call still shows', (
    tester,
  ) async {
    final rig = await _launch(tester, const Size(1440, 900), reduce: true);
    await rig.run([], 7);
    await rig.run(['demonRout'], 0);
    expect(
      await rig.until(() => rig.director.active.any((m) => m.isDemon)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
