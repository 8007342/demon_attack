import 'package:demon_attack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('title starts a playable cabinet at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const DemonAttackApp());
      await tester.pump();
      expect(find.text('DEMON'), findsOneWidget);
      expect(find.text('ATTACK'), findsOneWidget);
      expect(find.text('TOP 10'), findsOneWidget);
      expect(find.text('UNDER CONSTRUCTION'), findsNothing);
      final start = find.text('START GAME  →');
      expect(start, findsOneWidget);
      expect(tester.getRect(start).overlaps(Offset.zero & size), isTrue);
      await tester.tap(start);
      await tester.pump();
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('KRYBOR'), findsOneWidget);
      expect(find.text('TACTICAL BRIEFING'), findsOneWidget);
      expect(find.text('◀     SLIDE TO PILOT     ▶'), findsOneWidget);
      expect(find.byTooltip('Pause game'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Dispose Flame tickers before the test binding checks for pending timers.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('desktop Enter starts and pause resumes through keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DemonAttackApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('SCORE'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(find.text('SIGNAL PAUSED'), findsOneWidget);
    await tester.tap(find.text('RESUME'));
    await tester.pump();
    expect(find.text('SIGNAL PAUSED'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
