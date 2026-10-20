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
  for (final mode in [RunMode.transition, RunMode.salvage]) {
    for (final keyboard in [false, true]) {
      testWidgets(
        '${keyboard ? 'keyboard' : 'touch'} pilots and collects during ${mode.name}',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scores = ScoreService(
            client: MockClient(
              (_) async => http.Response('{"scores":[]}', 200),
            ),
          );
          await tester.pumpWidget(
            MaterialApp(home: ArcadePage(scoreService: scores)),
          );
          await tester.pump();
          await tester.tap(find.text('START GAME  →'));
          await tester.pump();
          final scene =
              tester
                      .widgetList<GameWidget>(
                        find.byWidgetPredicate(
                          (widget) => widget is GameWidget,
                        ),
                      )
                      .first
                      .game
                  as DemonScene;
          final model = scene.model;
          model
            ..mode = mode
            ..wave = 2
            ..transitionLeft = 1
            ..transitionDuration = 1;
          model.demons.clear();
          model.shots.clear();
          model.events.clear();
          model.pickups.add(
            Pickup(
              270,
              ArcadeModel.shipY - (mode == RunMode.salvage ? 55 : 25),
              Power.spread,
            ),
          );
          scene.onTick();
          await tester.pump();
          expect(model.canPilot, isTrue);
          expect(model.combat, isFalse);
          final before = model.shipX;
          if (keyboard) {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
          } else {
            final controller = find.text('◀     SLIDE TO PILOT     ▶');
            await tester.dragFrom(
              tester.getCenter(controller),
              const Offset(80, 0),
            );
          }
          // Advance the actual scene path so keyboard and model movement are tested together.
          for (var frame = 0; frame < 3; frame++) {
            scene.update(.1);
          }
          if (keyboard) {
            await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
          }
          await tester.pump();
          expect(model.shipX, greaterThan(before + 50));
          expect(model.power, Power.spread);
          expect(model.pickups, isEmpty);
          expect(model.mode, mode);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
}
