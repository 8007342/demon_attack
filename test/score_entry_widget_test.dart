import 'dart:convert';

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'score wheels retain initials after failed submission and retry',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final submissions = <Map<String, dynamic>>[];
      var loads = 0;
      final service = ScoreService(
        endpoint: Uri.parse('https://scores.example/api/scores'),
        client: MockClient((request) async {
          if (request.method == 'GET') {
            loads++;
            return http.Response('{"scores":[]}', 200);
          }
          expect(request.method, 'POST');
          expect(request.headers['content-type'], 'application/json');
          submissions.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (submissions.length == 1) return http.Response('Unavailable', 503);
          return http.Response(
            '{"scores":[{"initials":"B9A","score":12345}]}',
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: ArcadePage(scoreService: service)),
      );
      await tester.pump();
      await tester.tap(find.text('START GAME  →'));
      await tester.pump();
      final scene =
          tester
                  .widgetList<GameWidget>(
                    find.byWidgetPredicate((widget) => widget is GameWidget),
                  )
                  .first
                  .game
              as DemonScene;
      scene.model
        ..score = 12345
        ..mode = RunMode.gameOver;
      scene.onTick();
      await tester.pump();
      expect(find.text('RECORD SCORE'), findsOneWidget);
      await tester.tap(find.text('RECORD SCORE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(loads, 1);
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(EditableText), findsNothing);

      Future<void> rotate(String tooltip) async {
        await tester.tap(find.byTooltip(tooltip));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      await rotate('Next character 1');
      await rotate('Previous character 2');
      await rotate('Next character 3');
      await rotate('Previous character 3');
      final wheels = tester.widgetList<ListWheelScrollView>(
        find.byType(ListWheelScrollView),
      );
      expect(
        wheels.map(
          (wheel) =>
              (wheel.controller! as FixedExtentScrollController).selectedItem %
              36,
        ),
        [1, 35, 0],
      );
      await tester.tap(find.text('SAVE SCORE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text('Transmission failed. Your score is ready to retry.'),
        findsOneWidget,
      );
      expect(find.byType(ListWheelScrollView), findsNWidgets(3));
      expect(submissions, [
        {'initials': 'B9A', 'score': 12345},
      ]);
      await tester.tap(find.text('SAVE SCORE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(submissions.length, 2);
      expect(submissions[1], submissions[0]);
      expect(submissions[1]['initials'], matches(RegExp(r'^[A-Z0-9]{3}$')));
      expect(find.text('TOP 10'), findsOneWidget);
      expect(find.text('B9A'), findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(of: find.text('B9A'), matching: find.byType(Row))
              .first,
          matching: find.text('012345'),
        ),
        findsOneWidget,
      );
      expect(find.text('SIGNAL RECEIVED'), findsOneWidget);
      expect(find.byType(ListWheelScrollView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
