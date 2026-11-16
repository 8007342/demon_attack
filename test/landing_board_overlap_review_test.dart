@Tags(['review'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// carrier-v3 tune: the board screen (the landing after a run, scrolled to
/// the hall of fame) at 360 × 640 and 390 × 844. The landing's scroll
/// viewport stops under the top bar (label and toggles) and above the
/// credits row, so row 01 never sits under the HUD. Sheet:
/// `art/contact/landing-board-overlap.png` with
/// `--dart-define=BOARD_CONTACT=true`.
const _contact = bool.fromEnvironment('BOARD_CONTACT');
const _fonts = String.fromEnvironment(
  'BONUS_BALANCE_FONTS',
  defaultValue: '/home/forge/.cache/tillandsias-project/tmp/fonts',
);

Future<void> _loadFonts() async {
  final dir = Directory(_fonts);
  if (!dir.existsSync()) return;
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
    final file = File('${dir.path}/$f');
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  testWidgets('board screen: the hall of fame scrolls under nothing', (
    tester,
  ) async {
    await tester.runAsync(_loadFonts);
    final frames = <ui.Image>[];
    final board = [
      for (var i = 0; i < 10; i++)
        {
          'initials': ['ACE', 'K9X', 'ZED', 'RUN', 'MAX', 'JET', 'OWL', 'B52',
            'FOX', 'NOV'][i],
          'score': 980000 - i * 61000,
          'medals': i < 2 ? 5 : 4 - i % 4,
          'activeMilliseconds': 2400000 - i * 90000,
          if (i == 0) 'remainingLives': 3,
        },
    ];
    for (final size in const [Size(360, 640), Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final service = ScoreService(
        endpoint: Uri.parse('https://scores.example/api/scores'),
        client: MockClient(
          (r) async => http.Response(jsonEncode({'scores': board}), 200),
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('sheet'),
          child: MaterialApp(home: ArcadePage(scoreService: service)),
        ),
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
              as dynamic;
      final model = scene.model as ArcadeModel;
      expect(
        model.restoreCheckpoint({'sector': 3, 'score': 9850, 'lives': 1}),
        isTrue,
      );
      model.mode = RunMode.gameOver;
      scene.onTick();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      final scroll = find.byKey(const ValueKey('landing-scroll'));
      expect(scroll, findsOneWidget);
      // Scrolled to the board: the viewport starts below the top bar.
      await tester.drag(scroll, const Offset(0, -900));
      await tester.pump();
      final view = tester.getRect(scroll);
      final label = tester.getRect(find.text('KRYBOR / DEFENSE SYSTEM'));
      expect(view.top, greaterThanOrEqualTo(label.bottom), reason: '$size');
      final credits = tester.getRect(find.text('CREDITS'));
      expect(view.bottom, lessThanOrEqualTo(credits.top), reason: '$size');
      expect(tester.takeException(), isNull);
      final boundary =
          tester.renderObject(find.byKey(const ValueKey('sheet')))
              as RenderRepaintBoundary;
      frames.add((await tester.runAsync(() => boundary.toImage()))!);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    if (_contact) {
      await tester.runAsync(() async {
        const gap = 8.0;
        final w = frames.fold<double>(gap, (a, f) => a + f.width + gap);
        final h = frames.fold<double>(0, (a, f) => a > f.height ? a : f.height.toDouble());
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(Rect.fromLTWH(0, 0, w, h + 2 * gap),
            Paint()..color = const Color(0xFF2A2F3A));
        var x = gap;
        for (final f in frames) {
          c.drawImage(f, Offset(x, gap), Paint());
          x += f.width + gap;
        }
        final img = await rec.endRecording().toImage(w.round(), (h + 2 * gap).round());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        img.dispose();
        await File('art/contact/landing-board-overlap.png')
            .writeAsBytes(png!.buffer.asUint8List());
      });
    }
    for (final f in frames) {
      f.dispose();
    }
  });
}
