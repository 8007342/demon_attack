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

List<Map<String, dynamic>> creditSections() =>
    ((jsonDecode(File('assets/credits.json').readAsStringSync())
                as Map)['sections']
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  testWidgets('credits open with "By Tlatoāni, with love", then the built-on '
      'cards and the source link, then the models, licences and projects', (
    tester,
  ) async {
    await openEnding(tester, reduced: true, credits: true);
    await waitForCredits(tester);
    await tester.pumpAndSettle();
    expect(find.text('By '), findsOneWidget);
    expect(find.text(', with love'), findsOneWidget);
    expect(find.byKey(const ValueKey('credits-link-Tlatoāni')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('credits-link-alongside')),
      findsOneWidget,
    );
    expect(find.text('Made alongside '), findsOneWidget);
    double top(Finder f) => tester.getTopLeft(f).dy;
    final creator = top(find.byKey(const ValueKey('credits-creator')));
    final cards = top(find.byKey(const ValueKey('credits-card-Tillandsias')));
    final source = top(find.byKey(const ValueKey('credits-source-link')));
    final models = top(
      find.text('MODELS USED TO MAKE THE ART, MUSIC AND VOICES'),
    );
    final licences = top(find.text('THIRD-PARTY LICENCES'));
    final samples = top(find.text('CC0 SAMPLE LIBRARIES (COMING)'));
    final engine = top(find.text('ENGINE AND LANGUAGES'));
    final built = top(find.text('BUILT WITH'));
    expect(creator, lessThan(cards));
    expect(cards, lessThan(source));
    expect(source, lessThan(models));
    expect(models, lessThan(licences));
    expect(licences, lessThan(samples));
    expect(samples, lessThan(engine));
    expect(engine, lessThan(built));
    final data =
        jsonDecode(File('assets/credits.json').readAsStringSync()) as Map;
    expect(data['source_url'], 'https://github.com/8007342/demon_attack');
    final creatorEntry =
        ((data['sections'] as List).first as Map)['entries'][0];
    expect(creatorEntry['url'], 'https://tlatoani.net/');
  });

  for (final size in [const Size(360, 780), const Size(1280, 800)]) {
    testWidgets('$size: Tillandsias, Fedora and Podman cards with icons and '
        'the repository link sit in the first screen', (tester) async {
      await openEnding(tester, reduced: true, credits: true, size: size);
      await waitForCredits(tester);
      await tester.pumpAndSettle();
      final data =
          jsonDecode(File('assets/credits.json').readAsStringSync()) as Map;
      final cards = (data['built_on'] as List).cast<Map<String, dynamic>>();
      expect(cards.map((c) => c['name']), ['Tillandsias', 'Fedora', 'Podman']);
      expect(cards.map((c) => c['url']), [
        'https://tillandsias.org/',
        'https://fedoraproject.org/',
        'https://podman.io/',
      ]);
      for (final c in cards) {
        final card = find.byKey(ValueKey('credits-card-${c['name']}'));
        expect(card, findsOneWidget);
        expect(tester.getBottomLeft(card).dy, lessThan(size.height));
        expect(
          find.byKey(ValueKey('credits-icon-${c['name']}')),
          findsOneWidget,
        );
        expect(find.text(Uri.parse(c['url'] as String).host), findsOneWidget);
      }
      // Tillandsias shows its own icon; Fedora and Podman neutral glyphs.
      expect(
        tester.widget(find.byKey(const ValueKey('credits-icon-Tillandsias'))),
        isA<Image>(),
      );
      for (final name in ['Fedora', 'Podman']) {
        expect(
          tester.widget(find.byKey(ValueKey('credits-icon-$name'))),
          isA<Icon>(),
        );
      }
      // The repository link follows the cards: in the first screen on a
      // desktop, within the first scroll on a phone.
      final link = find.byKey(const ValueKey('credits-source-link'));
      expect(link, findsOneWidget);
      expect(
        tester.getBottomLeft(link).dy,
        lessThan(size.height * (size.width >= 600 ? 1 : 1.25)),
      );
      expect(
        find.text('Source code · github.com/8007342/demon_attack'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('credits-trademark-note')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every credits.json row renders, the licence lines verbatim', (
    tester,
  ) async {
    await openEnding(tester, reduced: true, credits: true);
    await waitForCredits(tester);
    await tester.pumpAndSettle();
    var rows = 0;
    for (final (i, s) in creditSections().indexed) {
      if (s['degree'] == 'creator') continue;
      final entries = (s['entries'] as List).cast<Map<String, dynamic>>();
      expect(entries, isNotEmpty, reason: s['title'] as String);
      for (final (j, e) in entries.indexed) {
        final row = find.byKey(ValueKey('credits-row-$i-$j'));
        expect(row, findsOneWidget, reason: e['name'] as String);
        expect(
          find.descendant(of: row, matching: find.text(e['name'] as String)),
          findsOneWidget,
        );
        rows++;
      }
    }
    expect(rows, greaterThan(80));
    expect(
      find.text(
        'Built with Meta Llama 3 · Meta Llama 3 is licensed under the Meta '
        'Llama 3 Community License, Copyright © Meta Platforms, Inc. All '
        'Rights Reserved.',
      ),
      findsOneWidget,
    );
    expect(find.text('Demucs, Alexandre Défossez'), findsOneWidget);
    for (final name in ['Flutter', 'Flame', 'Blender', 'ComfyUI', 'OpenSpec']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
  });

  test('credits list every signed licence, the CC0 libraries as coming, '
      'and the open-source projects with links', () {
    final sections = creditSections();
    Map<String, dynamic> by(String degree) =>
        sections.firstWhere((s) => s['degree'] == degree);
    final licences = (by('licences')['entries'] as List)
        .cast<Map<String, dynamic>>();
    final signed = Directory('licences/acknowledgements')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yaml'));
    final ids = {
      for (final f in signed)
        RegExp(
          r'^licence: (\S+)$',
          multiLine: true,
        ).firstMatch(f.readAsStringSync())!.group(1),
    };
    expect(licences, hasLength(ids.length));
    for (final l in licences) {
      expect(l['url'], startsWith('https://github.com/8007342/demon_attack/'));
    }
    final samples = by('samples');
    expect(samples['title'], contains('coming'));
    for (final e in samples['entries'] as List) {
      expect(e['license'], 'CC0 1.0');
    }
    final projects = sections
        .where((s) => s['degree'] == 'projects')
        .expand((s) => s['entries'] as List)
        .cast<Map<String, dynamic>>();
    expect(projects.length, greaterThanOrEqualTo(20));
    for (final p in projects) {
      expect(p['url'], startsWith('https://'), reason: p['name'] as String);
    }
  });

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
        await tester.pumpAndSettle();
        expect(find.text('Tillandsias'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('ending-close')));
        await tester.pumpAndSettle();
        expect(find.text('OPEN ENDING'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final reduced in [false, true]) {
    testWidgets('credits stay still (reduced motion: $reduced) and scroll by '
        'hand, by drag and by keyboard', (tester) async {
      await openEnding(tester, reduced: reduced, credits: true);
      await waitForCredits(tester);
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('credits-scroll')),
          )
          .controller!;
      final start = scroll.offset;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      expect(scroll.offset, start, reason: 'no auto-scroll');
      expect(find.byKey(const ValueKey('credits-auto-scroll')), findsNothing);
      expect(find.text('PAUSE SCROLL'), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('credits-scroll')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(start));
      final dragged = scroll.offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(dragged));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
    });
  }

  testWidgets('the reveal reaches the credits, which then stay still', (
    tester,
  ) async {
    await openEnding(tester);
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();
    await waitForCredits(tester);
    final scroll = tester
        .widget<SingleChildScrollView>(
          find.byKey(const ValueKey('credits-scroll')),
        )
        .controller!;
    final before = scroll.offset;
    await tester.pump(const Duration(seconds: 3));
    expect(scroll.offset, before);
  });
}
