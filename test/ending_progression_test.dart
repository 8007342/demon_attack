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

/// The beach ending and credits belong to the campaign's last carrier only:
/// sector 5 of the fifth route (cycle 4). The four earlier carriers keep their
/// normal victory → travel flow into the next route.
void main() {
  group('finalBoss', () {
    test('is true only for sector 5 of the fifth route', () {
      final model = ArcadeModel();
      for (var route = 0; route < 5; route++) {
        for (var sector = 1; sector <= 5; sector++) {
          model.startAt(sector: sector, route: route);
          expect(
            model.finalBoss,
            sector == 5 && route == 4,
            reason: 'route $route sector $sector',
          );
        }
      }
    });

    test('bosses 1-4 travel on to the next route; boss 5 completes', () {
      for (var route = 0; route < 5; route++) {
        final model = ArcadeModel()..startAt(sector: 5, route: route);
        model
          ..mode = RunMode.victory
          ..transitionDuration = 1
          ..transitionLeft = .001;
        model.update(.02);
        if (route < 4) {
          expect(model.mode, RunMode.travel, reason: 'boss ${route + 1}');
          model.transitionLeft = .001;
          model.update(.02);
          expect(model.cycle, route + 1, reason: 'boss ${route + 1}');
          expect(model.level, 1);
        } else {
          expect(model.mode, RunMode.completed);
        }
      }
    });
  });

  Future<DemonScene> pumpArcade(WidgetTester tester) async {
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
    return tester
            .widgetList<GameWidget>(
              find.byWidgetPredicate((w) => w is GameWidget),
            )
            .first
            .game
        as DemonScene;
  }

  /// A carrier of [route] just fell; the victory cinematic is at 80 %.
  void lateVictory(ArcadeModel model, int route) {
    model.startAt(sector: 5, route: route);
    model
      ..mode = RunMode.victory
      ..score = 12345
      ..lives = 2
      ..medals = route + 1
      ..transitionDuration = 10
      ..transitionLeft = 2;
    model.events.clear();
  }

  for (final route in [0, 1, 2, 3]) {
    testWidgets('no ending after boss ${route + 1}; the run travels on', (
      tester,
    ) async {
      final scene = await pumpArcade(tester);
      final model = scene.model;
      lateVictory(model, route);
      // Through the whole victory cinematic, frame by frame.
      for (var i = 0; i < 6; i++) {
        model.transitionLeft = 2 - i * .3;
        scene.onTick();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(EndingPage), findsNothing);
      expect(model.mode, RunMode.victory);
      model.transitionLeft = .001;
      model.update(.02);
      expect(model.mode, RunMode.travel);
      model.transitionLeft = .001;
      model.update(.02);
      expect(model.cycle, route + 1);
      expect(model.level, 1);
      expect(model.score, 12345);
      scene.onTick();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(EndingPage), findsNothing);
      expect(find.text('SAVE SCORE'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('the ending opens after boss 5 and preserves the result', (
    tester,
  ) async {
    final scene = await pumpArcade(tester);
    final model = scene.model;
    lateVictory(model, 4);
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
    expect(model.medals, 5);
    await tester.tap(find.byKey(const ValueKey('ending-close')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byType(EndingPage), findsNothing);
    expect(model.mode, RunMode.victory);
    expect(model.score, 12345);
    expect(model.lives, 2);
    expect(model.medals, 5);
    model.transitionLeft = .001;
    model.update(.02);
    expect(model.mode, RunMode.completed);
    scene.onTick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('SAVE SCORE'), findsOneWidget);
    expect(find.byType(EndingPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
