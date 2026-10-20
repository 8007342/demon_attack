import 'package:demon_attack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone landing shows only construction identity', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DemonAttackApp());
    await tester.pump();
    expect(find.text('UNDER CONSTRUCTION'), findsOneWidget);
    expect(find.text('DEMON ATTACK'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('Coded Live'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
