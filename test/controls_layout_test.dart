import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('one touch layout everywhere: no desktop mode, keyboard steers', (
    tester,
  ) async {
    // A wide desktop browser gets the same pilot console as a phone.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockScores = ScoreService(
      client: MockClient((_) async => http.Response('{"scores":[]}', 200)),
    );

    await tester.pumpWidget(
      MaterialApp(home: ArcadePage(scoreService: mockScores)),
    );
    await tester.pump();

    void expectNoDesktopMode() {
      expect(
        find.byKey(const ValueKey('title-touch-toggle-button')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('touch-toggle-button')), findsNothing);
      expect(find.byKey(const ValueKey('enable-touch-bottom')), findsNothing);
      expect(find.textContaining('DESKTOP'), findsNothing);
      expect(find.textContaining('CONTROLS:'), findsNothing);
      expect(find.byIcon(Icons.touch_app), findsNothing);
      expect(find.byIcon(Icons.keyboard), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').contains('Desktop'),
        ),
        findsNothing,
      );
    }

    expectNoDesktopMode();
    await tester.tap(find.text('START GAME  →'));
    await tester.pump();
    expectNoDesktopMode();
    expect(find.text('◀     SLIDE TO PILOT     ▶'), findsOneWidget);

    final scene =
        tester
                .widgetList<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .first
                .game
            as DemonScene;
    scene.model.mode = RunMode.playing;
    scene.onTick();
    await tester.pump();

    // Keyboard controls still steer in the one remaining layout.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(scene.keyboardDirection, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(scene.keyboardDirection, -1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
    await tester.pump();
    expect(scene.keyboardDirection, 0);

    // The pause menu no longer offers a controls toggle.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(find.text('SIGNAL PAUSED'), findsOneWidget);
    expectNoDesktopMode();
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('◀     SLIDE TO PILOT     ▶'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('defeat sequence allows tap or key skip to terminal ranking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockScores = ScoreService(
      client: MockClient((_) async => http.Response('{"scores":[]}', 200)),
    );

    await tester.pumpWidget(
      MaterialApp(home: ArcadePage(scoreService: mockScores)),
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

    final model = scene.model;
    model.mode = RunMode.playing;
    model.invulnerable = 0;
    model.lives = 1;
    model.hitPlayer(); // Triggers defeatActive = true
    scene.onTick();
    await tester.pump();

    expect(model.defeatActive, isTrue);

    // Tapping skips defeat sequence
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
    expect(model.defeatTimer, 0);

    // Next tick finishes run into score entry / ranking
    scene.onTick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(model.defeatActive, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
