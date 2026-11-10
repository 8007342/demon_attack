import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Review frames: --dart-define=CONSOLE_RENDER=/abs/dir (never the checkout).
const renderDir = String.fromEnvironment('CONSOLE_RENDER');

/// Optional monospace font for review frames (instead of the test boxes):
/// --dart-define=CONSOLE_FONT=/abs/RobotoMono-Regular.ttf
const fontFile = String.fromEnvironment('CONSOLE_FONT');

Future<void> _loadReviewFonts() async {
  if (fontFile.isNotEmpty && File(fontFile).existsSync()) {
    final bytes = File(fontFile).readAsBytesSync();
    await (FontLoader(
      'monospace',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  final icons = File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ArcadeModel _arcadeModel(WidgetTester tester) =>
    (tester
                .widgetList<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .first
                .game
            as DemonScene)
        .model;

Future<void> _disposeApp(WidgetTester tester) async {
  // Dispose Flame tickers before the test binding checks for pending timers.
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  test('/console is recognised, other paths are not', () {
    for (final path in ['/console', '/console/', '/CONSOLE', '/console?x=1']) {
      expect(isConsoleRoute(path), isTrue, reason: path);
    }
    for (final path in ['/', '', '/consoles', '/gallery/', null]) {
      expect(isConsoleRoute(path), isFalse, reason: '$path');
    }
  });

  group('startAt', () {
    test('every sector and route starts fresh at 0 points', () {
      for (final difficulty in Difficulty.values) {
        for (var route = 0; route < 5; route++) {
          for (var sector = 1; sector <= 5; sector++) {
            final model = ArcadeModel();
            ConsoleStart(
              difficulty: difficulty,
              sector: sector,
              route: route,
            ).applyTo(model);
            expect(model.score, 0);
            expect(model.level, sector);
            expect(model.cycle, route);
            expect(model.medals, route);
            expect(model.difficulty, difficulty);
            expect(model.boss != null, sector == 5);
          }
        }
      }
    });

    test('the sentinel jump lands on a wave with a sentinel', () {
      for (final difficulty in Difficulty.values) {
        for (var route = 0; route < 5; route++) {
          for (final sector in [1, 2, 3, 4, 5]) {
            final start = ConsoleStart.sentinel(
              difficulty: difficulty,
              sector: sector,
              route: route,
            );
            expect(start.route, greaterThanOrEqualTo(1));
            final model = ArcadeModel();
            start.applyTo(model);
            for (var i = 0; i < 240; i++) {
              model.update(1 / 60);
            }
            expect(
              model.demons.any((d) => d.isLarge),
              isTrue,
              reason: '$difficulty ${start.label}',
            );
          }
        }
      }
    });
  });

  testWidgets('a normal visit to / still opens the title', (tester) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(const DemonAttackApp());
    await tester.pump();
    expect(find.text('START GAME  →'), findsOneWidget);
    expect(find.text('CONSOLE'), findsNothing);
    expect(find.byKey(const ValueKey('back-to-console')), findsNothing);
    await _disposeApp(tester);
  });

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('console renders its buttons at ${size.width.toInt()}px', (
      tester,
    ) async {
      _size(tester, size);
      await tester.pumpWidget(const DemonAttackApp(initialRoute: '/console'));
      await tester.pump();
      expect(find.text('CONSOLE'), findsOneWidget);
      expect(find.byType(GameWidget), findsNothing);
      for (final key in [
        for (var i = 0; i < 3; i++) 'console-difficulty-$i',
        for (var i = 0; i < 5; i++) 'console-run-$i',
        for (var i = 0; i < 5; i++) 'console-sector-$i',
        'console-launch',
        'console-boss',
        'console-sentinel',
        'console-gallery',
      ]) {
        final button = find.byKey(ValueKey(key));
        expect(button, findsOneWidget, reason: key);
        expect(
          tester.getRect(button).overlaps(Offset.zero & size),
          isTrue,
          reason: key,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('launch starts the chosen sector and route at 0 points', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(const DemonAttackApp(initialRoute: '/console'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('console-difficulty-2')));
    await tester.tap(find.byKey(const ValueKey('console-run-2')));
    await tester.tap(find.byKey(const ValueKey('console-sector-3')));
    await tester.pump();
    final launch = find.byKey(const ValueKey('console-launch'));
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final model = _arcadeModel(tester);
    expect(model.mode, isNot(RunMode.title));
    expect(model.difficulty, Difficulty.hard);
    expect(model.level, 4);
    expect(model.cycle, 2);
    expect(model.medals, 2);
    expect(model.score, 0);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('START GAME  →'), findsNothing);
    expect(tester.takeException(), isNull);
    await _disposeApp(tester);
  });

  testWidgets('boss jump opens the carrier of the chosen run', (tester) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(const DemonAttackApp(initialRoute: '/console'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('console-run-3')));
    await tester.pump();
    final boss = find.byKey(const ValueKey('console-boss'));
    await tester.ensureVisible(boss);
    await tester.tap(boss);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final model = _arcadeModel(tester);
    expect(model.boss, isNotNull);
    expect(model.level, 5);
    expect(model.cycle, 3);
    expect(model.score, 0);
    await _disposeApp(tester);
  });

  testWidgets('sentinel jump on run 1 lands on run 2 with a sentinel', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(const DemonAttackApp(initialRoute: '/console'));
    await tester.pump();
    final sentinel = find.byKey(const ValueKey('console-sentinel'));
    await tester.ensureVisible(sentinel);
    await tester.tap(sentinel);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final model = _arcadeModel(tester);
    expect(model.cycle, greaterThanOrEqualTo(1));
    expect(model.medals, model.cycle);
    expect(model.score, 0);
    for (var i = 0; i < 240; i++) {
      model.update(1 / 60);
    }
    expect(model.demons.any((d) => d.isLarge), isTrue);
    await _disposeApp(tester);
  });

  testWidgets('a console run can return to the console from its title', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(const DemonAttackApp(initialRoute: '/console'));
    await tester.pump();
    final launch = find.byKey(const ValueKey('console-launch'));
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final scene =
        tester
                .widgetList<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .first
                .game
            as DemonScene;
    scene.model.mode = RunMode.title;
    scene.onTick();
    await tester.pump();
    final back = find.byKey(const ValueKey('back-to-console'));
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('CONSOLE'), findsOneWidget);
    expect(find.byType(ArcadePage), findsNothing);
    await _disposeApp(tester);
  });

  testWidgets('review frames of the console page', (tester) async {
    if (renderDir.isEmpty) return;
    await tester.runAsync(_loadReviewFonts);
    for (final (name, size) in [
      ('console-phone-390x844', const Size(390, 844)),
      ('console-desktop-1440x900', const Size(1440, 900)),
    ]) {
      _size(tester, size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('page'),
          child: const DemonAttackApp(initialRoute: '/console'),
        ),
      );
      await tester.pump();
      if (name.startsWith('console-phone')) {
        await tester.tap(find.byKey(const ValueKey('console-run-1')));
        await tester.tap(find.byKey(const ValueKey('console-sector-1')));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
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
  });
}
