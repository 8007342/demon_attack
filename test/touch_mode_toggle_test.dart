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
  testWidgets('title and HUD touch toggle switches between touch console and desktop strip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockScores = ScoreService(
      client: MockClient((_) async => http.Response('{"scores":[]}', 200)),
    );

    await tester.pumpWidget(MaterialApp(home: ArcadePage(scoreService: mockScores)));
    await tester.pump();

    // Title screen toggle button
    final titleToggle = find.byKey(const ValueKey('title-touch-toggle-button'));
    expect(titleToggle, findsOneWidget);

    // Toggle off on title screen -> Desktop mode
    await tester.tap(titleToggle);
    await tester.pump();

    // Start game in desktop mode
    await tester.tap(find.text('START GAME  →'));
    await tester.pump();

    // Verify desktop strip is active and touch console is not rendered
    expect(find.text('DESKTOP MODE · ← / A  → / D TO STEER · AUTO-FIRING'), findsOneWidget);
    expect(find.text('◀     SLIDE TO PILOT     ▶'), findsNothing);

    // Tap "ENABLE TOUCH" on desktop strip
    final enableTouchBtn = find.byKey(const ValueKey('enable-touch-bottom'));
    expect(enableTouchBtn, findsOneWidget);
    await tester.tap(enableTouchBtn);
    await tester.pump();

    // Verify touch console is back
    expect(find.text('◀     SLIDE TO PILOT     ▶'), findsOneWidget);
    expect(find.text('DESKTOP MODE · ← / A  → / D TO STEER · AUTO-FIRING'), findsNothing);

    // Toggle off via in-game HUD toggle button
    final hudToggle = find.byKey(const ValueKey('touch-toggle-button'));
    expect(hudToggle, findsOneWidget);
    await tester.tap(hudToggle);
    await tester.pump();

    expect(find.text('DESKTOP MODE · ← / A  → / D TO STEER · AUTO-FIRING'), findsOneWidget);

    // Enter gameplay mode
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

    // Pause menu also allows toggling controls
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(find.text('SIGNAL PAUSED'), findsOneWidget);
    final pauseToggle = find.text('CONTROLS: DESKTOP (TOUCH OFF)');
    expect(pauseToggle, findsOneWidget);
    await tester.tap(pauseToggle);
    await tester.pump();
    expect(find.text('CONTROLS: TOUCH (ON)'), findsOneWidget);

    // Resume game
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('◀     SLIDE TO PILOT     ▶'), findsOneWidget);

    // Dispose
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

    await tester.pumpWidget(MaterialApp(home: ArcadePage(scoreService: mockScores)));
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
