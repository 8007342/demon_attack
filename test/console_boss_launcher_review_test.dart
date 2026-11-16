@Tags(['review'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:demon_attack/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Operator C2: the console's rows with the CARRIER row (APPROACH, FIGHT,
/// FAST DECAY), run 3 and sector 5 picked, at 390 × 844.
/// `--dart-define=CONSOLE_CONTACT=true` writes
/// `art/contact/console-carrier-row.png`.
const _contact = bool.fromEnvironment('CONSOLE_CONTACT');

Future<void> _fonts() async {
  const dir = '/home/forge/.cache/tillandsias-project/tmp/fonts';
  for (final family in ['Roboto', 'monospace']) {
    final loader = FontLoader(family);
    for (final f in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final file = File('$dir/$f');
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }
}

void main() {
  testWidgets('console rows with the carrier launcher', (tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const RepaintBoundary(
        key: ValueKey('page'),
        child: DemonAttackApp(initialRoute: '/console'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('console-run-2')));
    await tester.tap(find.byKey(const ValueKey('console-sector-4')));
    await tester.pump();
    final decay = find.byKey(const ValueKey('console-carrier-2'));
    await tester.ensureVisible(decay);
    await tester.tap(decay);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('FAST DECAY'), findsOneWidget);
    final boundary =
        tester.renderObject(find.byKey(const ValueKey('page')))
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      if (_contact) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('art/contact/console-carrier-row.png')
            .writeAsBytes(png!.buffer.asUint8List());
      }
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
