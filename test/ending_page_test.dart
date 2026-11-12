import 'dart:convert';
import 'dart:io';

import 'package:demon_attack/ending/ending_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openEnding(
  WidgetTester tester, {
  bool reduced = false,
  bool credits = false,
  Size size = const Size(360, 780),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(() => rootBundle.loadString('assets/credits.json'));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaQuery(
                  data: MediaQueryData(size: size, disableAnimations: reduced),
                  child: EndingPage(creditsOnly: credits),
                ),
              ),
            ),
            child: const Text('OPEN ENDING'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN ENDING'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> waitForCredits(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    if (find.byKey(const ValueKey('credits-scroll')).evaluate().isNotEmpty) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(find.byKey(const ValueKey('credits-scroll')), findsOneWidget);
}

void main() {
  test(
    'credits contain verified project names and only runtime dependencies',
    () {
      final data =
          jsonDecode(File('assets/credits.json').readAsStringSync()) as Map;
      final sections = data['sections'] as List;
      final creator =
          sections.firstWhere((s) => s['degree'] == 'creator')['entries']
              as List;
      expect(creator.map((e) => e['name']), contains('Tlatoāni'));
      final dependencies = sections
          .where((s) => ['direct', 'indirect'].contains(s['degree']))
          .expand((s) => s['entries'] as List)
          .map((p) => p['name'])
          .toSet();
      expect(
        dependencies,
        containsAll(['flame', 'http', 'url_launcher', 'collection']),
      );
      expect(dependencies, isNot(contains('flutter_test')));
      expect(dependencies, isNot(contains('flutter_lints')));
      final actual = Process.runSync('sha256sum', ['pubspec.lock']);
      expect(actual.exitCode, 0);
      expect(
        data['sources']['lockfile_sha256'],
        actual.stdout.toString().split(' ').first,
      );
    },
  );

  for (final size in [const Size(360, 780), const Size(740, 360)]) {
    testWidgets(
      'beach reveal fits $size; skipping exposes credits and closes',
      (tester) async {
        await openEnding(tester, size: size);
        expect(
          find.byKey(const ValueKey('beach-reveal-image')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('ending-skip')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await waitForCredits(tester);
        await tester.tap(find.byKey(const ValueKey('credits-auto-scroll')));
        await tester.pumpAndSettle();
        expect(find.text('Tillandsias.org'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('ending-close')));
        await tester.pumpAndSettle();
        expect(find.text('OPEN ENDING'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reduced motion keeps credits still and permits manual scrolling',
    (tester) async {
      await openEnding(tester, reduced: true, credits: true);
      await waitForCredits(tester);
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('credits-scroll')),
          )
          .controller!;
      final start = scroll.offset;
      await tester.pump(const Duration(seconds: 5));
      expect(scroll.offset, start);
      expect(find.byKey(const ValueKey('credits-auto-scroll')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('credits-scroll')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(start));
    },
  );

  testWidgets(
    'normal reveal reaches credits; user can pause and manually review them',
    (tester) async {
      await openEnding(tester);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      await waitForCredits(tester);
      expect(find.byKey(const ValueKey('credits-scroll')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('credits-auto-scroll')));
      await tester.pump();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('credits-scroll')),
          )
          .controller!;
      final before = scroll.offset;
      await tester.pump(const Duration(seconds: 2));
      expect(scroll.offset, before);
      expect(find.text('RESUME SCROLL'), findsOneWidget);
    },
  );
}
