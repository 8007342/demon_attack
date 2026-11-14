import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/run_storage.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A /console run: one life, 0 points, any sector or route, never ranked.
void main() {
  group('console start', () {
    test('every sector, route and difficulty: 1 life, 0 points, unranked', () {
      for (final difficulty in Difficulty.values) {
        for (var route = 0; route < 5; route++) {
          for (var sector = 1; sector <= 5; sector++) {
            final model = ArcadeModel();
            ConsoleStart(
              difficulty: difficulty,
              sector: sector,
              route: route,
            ).applyTo(model);
            final at = '$difficulty route $route sector $sector';
            expect(model.lives, 1, reason: at);
            expect(model.score, 0, reason: at);
            expect(model.ranked, isFalse, reason: at);
            expect(model.level, sector, reason: at);
            expect(model.cycle, route, reason: at);
            expect(model.boss != null, sector == 5, reason: at);
          }
        }
      }
    });

    test('boss and sentinel jumps are console runs too', () {
      for (final start in [
        ConsoleStart.boss(route: 4),
        ConsoleStart.sentinel(route: 2),
      ]) {
        final model = ArcadeModel();
        start.applyTo(model);
        expect(model.lives, 1, reason: start.label);
        expect(model.score, 0, reason: start.label);
        expect(model.ranked, isFalse, reason: start.label);
      }
    });

    test('a normal start or a resumed save is ranked again', () {
      final model = ArcadeModel();
      ConsoleStart.boss(route: 1).applyTo(model);
      expect(model.ranked, isFalse);
      model.start(difficulty: Difficulty.easy);
      expect(model.ranked, isTrue);
      expect(model.lives, 5);
      final saved = (ArcadeModel()..startAt(sector: 2, route: 1)).checkpoint();
      ConsoleStart.boss(route: 1).applyTo(model);
      expect(model.restoreCheckpoint(saved), isTrue);
      expect(model.ranked, isTrue);
      // startAt without the console flag keeps the difficulty's lives.
      model.startAt(sector: 3, route: 2);
      expect(model.lives, 3);
      expect(model.ranked, isTrue);
    });
  });

  testWidgets('a console run is tagged, never prompts or POSTs a score', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <String>[];
    final store = MemoryLocalStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ArcadePage(
          consoleStart: ConsoleStart.boss(
            difficulty: Difficulty.hard,
            route: 4,
          ),
          runStorage: RunStorage(store: store),
          scoreService: ScoreService(
            client: MockClient((request) async {
              requests.add(request.method);
              return http.Response('{"scores":[]}', 200);
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final scene =
        tester
                .widgetList<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .first
                .game
            as DemonScene;
    final model = scene.model;
    expect(model.boss, isNotNull);
    expect(model.cycle, 4);
    expect(model.lives, 1);
    expect(model.score, 0);
    expect(find.byKey(const ValueKey('hud-unranked')), findsOneWidget);
    expect(find.text('CONSOLE RUN · NOT RANKED'), findsOneWidget);

    // A score that would top an empty board, then the run ends.
    model
      ..score = 987654
      ..mode = RunMode.gameOver;
    scene.onTick();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(model.mode, RunMode.title);
    expect(find.text('SAVE SCORE'), findsNothing);
    expect(find.byKey(const ValueKey('result-unranked')), findsOneWidget);
    expect(find.text('YOUR FINAL SCORE'), findsOneWidget);
    expect(requests, everyElement('GET'));
    // The player's saved run and unlock history are untouched.
    expect(store.values.containsKey(RunStorage.checkpointKey), isFalse);
    expect(store.values.containsKey(RunStorage.historyKey), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
