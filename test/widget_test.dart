import 'package:demon_attack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';

void main() {
  testWidgets('phone landing shows announcement and correct event link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DemonAttackApp());
    await tester.pump();
    expect(find.text('UNDER CONSTRUCTION'), findsOneWidget);
    expect(find.text('Coded Live\nOct 20'), findsOneWidget);
    expect(tester.widget<Link>(find.byType(Link)).uri.toString(), eventUrl);
    expect(tester.takeException(), isNull);
  });
}
