import 'package:demon_attack/ending/ending_page.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final cycle in [0, 4]) {
    testWidgets('skipping ending preserves route $cycle victory and result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(740, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ArcadePage(
            runStorage: RunStorage(store: MemoryLocalStore()),
            scoreService: ScoreService(
              client: MockClient(
                (_) async => http.Response('{"scores":[]}', 200),
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
      final model = scene.model;
      model.startAt(sector: 5, route: cycle);
      model
        ..mode = RunMode.victory
        ..score = 12345
        ..lives = 2
        ..medals = cycle + 1
        ..transitionDuration = 10
        ..transitionLeft = 2;
      model.events.clear();
      scene.onTick();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byType(EndingPage),
        findsOneWidget,
        reason: 'mode=${model.mode} progress=${model.transitionProgress}',
      );
      expect(model.mode, RunMode.paused);
      final left = model.transitionLeft;
      final active = model.activeMilliseconds;
      await tester.pump(const Duration(seconds: 2));
      expect(model.transitionLeft, left);
      expect(model.activeMilliseconds, active);
      expect(model.score, 12345);
      expect(model.lives, 2);
      expect(model.medals, cycle + 1);
      await tester.tap(find.byKey(const ValueKey('ending-close')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byType(EndingPage), findsNothing);
      expect(model.mode, RunMode.victory);
      expect(model.score, 12345);
      expect(model.lives, 2);
      expect(model.medals, cycle + 1);
      model.transitionLeft = .001;
      model.update(.02);
      if (cycle == 0) {
        expect(model.mode, RunMode.travel);
        model.transitionLeft = .001;
        model.update(.02);
        expect(model.cycle, 1);
        expect(model.level, 1);
        expect(model.score, 12345);
        scene.onTick();
        await tester.pump();
        expect(find.byType(EndingPage), findsNothing);
      } else {
        expect(model.mode, RunMode.completed);
        scene.onTick();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('SAVE SCORE'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
