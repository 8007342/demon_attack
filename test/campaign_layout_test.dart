import 'package:demon_attack/main.dart';
import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('campaign captions and reward fit at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ArcadePage(
            scoreService: ScoreService(
              client: MockClient(
                (_) async => http.Response('{"scores":[]}', 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'landing header');
      await tester.ensureVisible(find.text('START GAME  →'));
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
      for (final phase in [
        RunMode.transition,
        RunMode.travel,
        RunMode.victory,
      ]) {
        scene.model
          ..mode = phase
          ..level = phase == RunMode.travel ? 2 : 5
          ..cycle = 4
          ..wave = 1
          ..medals = 5
          ..transitionDuration = 5
          ..transitionLeft = 2.5;
        scene.onTick();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$phase at $size');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
