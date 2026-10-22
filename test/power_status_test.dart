import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/power_status.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'every legal offensive combination preserves its layers and shield',
    (tester) async {
      await tester.runAsync(() async {
        for (final active in [
          {Power.spread, Power.rapid, Power.shield},
          {Power.spread, Power.powerful, Power.shield},
          {Power.large, Power.rapid, Power.shield},
          {Power.large, Power.powerful, Power.shield},
          {Power.spread, Power.rapid},
          {Power.large, Power.powerful},
        ]) {
          final recorder = ui.PictureRecorder();
          PowerGlyphPainter(active)
              .paint(ui.Canvas(recorder), const Size(64, 64));
          final picture = recorder.endRecording();
          final image = await picture.toImage(64, 64);
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          for (final p in Power.values) {
            final color = powerColors[p]!;
            var count = 0;
            for (var i = 0; i < data.lengthInBytes; i += 4) {
              if (data.getUint8(i) == ((color.toARGB32() >> 16) & 255) &&
                  data.getUint8(i + 1) == ((color.toARGB32() >> 8) & 255) &&
                  data.getUint8(i + 2) == (color.toARGB32() & 255) &&
                  data.getUint8(i + 3) > 200) {
                count++;
              }
            }
            expect(
              count,
              active.contains(p) ? greaterThan(20) : 0,
              reason:
                  'Each active glyph must stay visible in the combined mark',
            );
          }
          if (active.contains(Power.large) && active.contains(Power.powerful)) {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '.cache/powers/combined-glyph-${active.length}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
          }
          picture.dispose();
          image.dispose();
        }
      });
    },
  );
  testWidgets(
    'controller displays independent timers and still accepts drags on badge',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ScoreService(
        client: MockClient((_) async => http.Response('{"scores":[]}', 200)),
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
                    find.byWidgetPredicate((w) => w is GameWidget),
                  )
                  .first
                  .game
              as DemonScene;
      scene.model
        ..mode = RunMode.playing
        ..invulnerable = 0;
      scene.model.powerTimers.addAll({
        Power.spread: 9,
        Power.rapid: 7,
        Power.shield: 5,
      });
      scene.onTick();
      await tester.pump();
      final status = find.byType(PowerStatus);
      for (final name in ['SPREAD', 'RAPID', 'SHIELD', '9s', '7s', '5s']) {
        expect(
          find.descendant(of: status, matching: find.text(name)),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('combined-power-glyph')),
        findsOneWidget,
      );
      final initial = scene.model.targetX;
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('combined-power-glyph'))),
        const Offset(40, 0),
      );
      expect(scene.model.targetX, greaterThan(initial));
      scene.model.collect(Power.powerful);
      scene.onTick();
      await tester.pump();
      expect(
        find.descendant(of: status, matching: find.text('RAPID')),
        findsNothing,
      );
      expect(
        find.descendant(of: status, matching: find.text('POWERFUL')),
        findsOneWidget,
      );
      expect(scene.model.powerTimers[Power.spread], 9);
      expect(scene.model.powerTimers[Power.shield], 5);
      scene.model.collect(Power.large);
      scene.onTick();
      await tester.pump();
      expect(
        find.descendant(of: status, matching: find.text('SPREAD')),
        findsNothing,
      );
      expect(
        find.descendant(of: status, matching: find.text('LARGE')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CustomPaint>(
              find.byKey(const ValueKey('combined-power-glyph')),
            )
            .painter,
        isA<PowerGlyphPainter>().having((p) => p.active, 'active layers', {
          Power.powerful,
          Power.large,
          Power.shield,
        }),
      );
      final replacementTarget = scene.model.targetX;
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('combined-power-glyph'))),
        const Offset(-35, 0),
      );
      expect(scene.model.targetX, lessThan(replacementTarget));
      scene.model.hitPlayer();
      scene.onTick();
      await tester.pump();
      expect(
        find.descendant(of: status, matching: find.text('SHIELD')),
        findsNothing,
      );
      expect(
        find.descendant(of: status, matching: find.text('LARGE')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: status, matching: find.text('POWERFUL')),
        findsOneWidget,
      );
      scene.model.collect(Power.rapid);
      scene.model.collect(Power.spread);
      scene.onTick();
      await tester.pump();
      expect(
        find.descendant(of: status, matching: find.text('POWERFUL')),
        findsNothing,
      );
      expect(
        find.descendant(of: status, matching: find.text('LARGE')),
        findsNothing,
      );
      expect(
        find.descendant(of: status, matching: find.text('RAPID')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: status, matching: find.text('SPREAD')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
