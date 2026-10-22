import 'dart:convert';

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/medal.dart';
import 'package:demon_attack/widgets/heart_parts.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

DemonScene sceneOf(WidgetTester tester) =>
    tester
            .widgetList<GameWidget>(
              find.byWidgetPredicate((widget) => widget is GameWidget),
            )
            .first
            .game
        as DemonScene;

Future<void> showPage(
  WidgetTester tester,
  RunStorage storage, {
  List<Uri>? requests,
  List<Map<String, dynamic>> board = const [],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ArcadePage(
        runStorage: storage,
        scoreService: ScoreService(
          client: MockClient((request) async {
            requests?.add(request.url);
            return http.Response(jsonEncode({'scores': board}), 200);
          }),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> disposePage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets(
    'resume restarts checkpoint in saved mode with inventory and no powers',
    (tester) async {
      final storage = RunStorage(store: MemoryLocalStore());
      final model = ArcadeModel()..start(difficulty: Difficulty.easy);
      final saved = model.checkpoint()
        ..['score'] = 1234
        ..['lives'] = 7
        ..['routeIndex'] = 2
        ..['sector'] = 3
        ..['wave'] = 2
        ..['medals'] = 2
        ..['heartSlots'] = [1, 3, 4]
        ..['activeMilliseconds'] = 42000;
      storage.saveCheckpoint(saved);
      storage.saveHistory(RunHistory(easyUnlocked: true, hardUnlocked: true));
      await showPage(tester, storage);
      await tester.ensureVisible(find.byKey(const ValueKey('board-hard')));
      await tester.tap(find.byKey(const ValueKey('board-hard')));
      await tester.pump();
      await tester.ensureVisible(find.text('RESUME GAME'));
      await tester.tap(find.text('RESUME GAME'));
      await tester.pump();
      final resumed = sceneOf(tester).model;
      expect(resumed.difficulty, Difficulty.easy);
      expect(resumed.score, 1234);
      expect(resumed.lives, 7);
      expect(resumed.cycle, 2);
      expect(resumed.level, 3);
      expect(resumed.wave, 2);
      expect(resumed.medals, 2);
      expect(resumed.heartSlots, [1, 3, 4]);
      expect(resumed.activeMilliseconds, 42000);
      expect(resumed.activePowers, isEmpty);
      expect(tester.takeException(), isNull);
      await disposePage(tester);
    },
  );

  testWidgets(
    'third failure unlocks Easy while interruptions do not and terminal clears resume',
    (tester) async {
      final storage = RunStorage(store: MemoryLocalStore());
      storage.saveHistory(RunHistory(failures: 2));
      await showPage(tester, storage);
      expect(find.text('EASY MODE'), findsNothing);
      expect(find.byKey(const ValueKey('board-hard')), findsNothing);
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      final scene = sceneOf(tester);
      expect(storage.loadCheckpoint(), isNotNull);
      expect(storage.loadHistory().failures, 2);
      scene.model
        ..mode = RunMode.gameOver
        ..lives = 0;
      scene.model.events.add('gameover');
      scene.onTick();
      await tester.pump();
      expect(storage.loadCheckpoint(), isNull);
      expect(storage.loadHistory().failures, 3);
      await tester.tap(find.text('RETURN TO TITLE'));
      await tester.pump();
      expect(find.text('EASY MODE'), findsOneWidget);
      expect(find.byKey(const ValueKey('board-easy')), findsOneWidget);
      expect(find.text('RESUME GAME'), findsNothing);
      await tester.ensureVisible(find.text('EASY MODE'));
      await tester.tap(find.text('EASY MODE'));
      await tester.pump();
      expect(scene.model.difficulty, Difficulty.easy);
      expect(scene.model.lives, 5);
      expect(tester.takeException(), isNull);
      await disposePage(tester);
    },
  );

  testWidgets('power overlay leaves guidance fixed and touch piloting active', (
    tester,
  ) async {
    await showPage(tester, RunStorage(store: MemoryLocalStore()));
    await tester.tap(find.text('START GAME  →'));
    await tester.pump();
    final scene = sceneOf(tester);
    final guidance = find.text('◀     SLIDE TO PILOT     ▶');
    final before = tester.getCenter(guidance);
    scene.model.mode = RunMode.playing;
    scene.model.powerTimers.addAll({for (final p in Power.values) p: 9});
    scene.onTick();
    await tester.pump();
    expect(tester.getCenter(guidance), before);
    expect(find.byKey(const ValueKey('combined-power-glyph')), findsOneWidget);
    final ship = scene.model.shipX;
    await tester.dragFrom(before, const Offset(60, 0));
    for (var i = 0; i < 3; i++) {
      scene.update(.1);
    }
    await tester.pump();
    expect(scene.model.shipX, greaterThan(ship));
    expect(tester.takeException(), isNull);
    await disposePage(tester);
  });

  testWidgets(
    'unlocked boards show five medals, time and finisher lives on phone',
    (tester) async {
      final storage = RunStorage(store: MemoryLocalStore());
      storage.saveHistory(RunHistory(easyUnlocked: true, hardUnlocked: true));
      final requests = <Uri>[];
      await showPage(
        tester,
        storage,
        requests: requests,
        board: [
          {
            'initials': 'DAN',
            'score': 123456,
            'difficulty': 'hard',
            'medals': 5,
            'activeMilliseconds': 62000,
            'remainingLives': 7,
          },
        ],
      );
      await tester.ensureVisible(find.byKey(const ValueKey('board-hard')));
      await tester.tap(find.byKey(const ValueKey('board-hard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(requests.last.queryParameters['difficulty'], 'hard');
      expect(find.byType(Medal), findsNWidgets(5));
      expect(find.text('01:02'), findsOneWidget);
      expect(find.text('♥ ×7'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposePage(tester);
    },
  );
  testWidgets(
    'heart assembly flashes a full heart and life reward before slot reuse',
    (tester) async {
      await showPage(tester, RunStorage(store: MemoryLocalStore()));
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      final scene = sceneOf(tester);
      scene.model.mode = RunMode.playing;
      for (var i = 0; i < 3; i++) {
        scene.model.collectHeart(HeartPart.left);
      }
      scene.onTick();
      await tester.pump();
      expect(find.text('1/3'), findsNWidgets(3));
      expect(find.text('HEART PIECE COLLECTED'), findsOneWidget);
      expect(scene.model.collectHeart(HeartPart.left), isFalse);
      scene.model.collectHeart(HeartPart.right);
      scene.model.collectHeart(HeartPart.top);
      scene.onTick();
      await tester.pump();
      expect(scene.model.lives, 4);
      expect(scene.model.heartSlots, [0, 1, 1]);
      expect(find.text('HEART ASSEMBLED · +1UP'), findsOneWidget);
      expect(find.text('♥ ×4'), findsOneWidget);
      expect(
        tester
            .widget<HeartParts>(find.byKey(const ValueKey('heart-slot-0')))
            .mask,
        7,
      );
      scene.model.pause();
      scene.update(1);
      expect(scene.model.heartAssemblyLeft, greaterThan(0));
      scene.model.resume();
      scene.model.collectHeart(HeartPart.left);
      scene.onTick();
      await tester.pump();
      expect(
        tester
            .widget<HeartParts>(find.byKey(const ValueKey('heart-slot-0')))
            .mask,
        1,
        reason: 'A newly stored piece remains visible during the previous reward flash',
      );
      expect(find.text('1/3'), findsNWidgets(3));
      for (var i = 0; i < 20; i++) {
        scene.update(.1);
      }
      await tester.pump();
      expect(find.text('HEART ASSEMBLED · +1UP'), findsNothing);
      expect(scene.model.heartSlots, [1, 1, 1]);
      expect(tester.takeException(), isNull);
      await disposePage(tester);
    },
  );
}
