import 'dart:math' as math;

import 'package:demon_attack/gallery_main.dart' show isStudioPath;
import 'package:demon_attack/review/page_notes.dart';
import 'package:demon_attack/review/review_notes.dart';
import 'package:demon_attack/review/review_platform_stub.dart';
import 'package:demon_attack/widgets/dev_console.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewNotesStore _store(MemoryReviewPlatform platform, [int seed = 1]) {
  var t = DateTime.utc(2026, 11, 14, 10);
  return ReviewNotesStore(
    platform,
    clock: () => t = t.add(const Duration(seconds: 1)),
    random: math.Random(seed),
  );
}

final _clip = ReviewAsset(
  kind: ReviewKind.radio,
  id: 'gloat.d3',
  title: 'GORRAK · gloat',
  source: 'web/audio/comms/gloat.d3.ogg',
  hash: 'a030bf5d03fb8b389f83b69092752c3a',
);

void main() {
  test(
    'the worklist groups notes by tag, fix-first, keep and untagged last',
    () {
      final store = _store(MemoryReviewPlatform());
      store.add(_clip, tags: ['keep'], text: 'great growl');
      store.add(
        _clip,
        tags: ['needs-growl', 'regenerate'],
        text: 'flat\nsecond roar',
        offset: 1.234,
      );
      store.add(consoleNotesAsset, text: 'sector 3 dives feel too fast');
      final md = store.worklistMarkdown();
      expect(md, startsWith('# Demon Attack review notes'));
      expect(md, contains('3 notes'));
      final order = [
        '## regenerate (1)',
        '## needs growl (1)',
        '## good / keep (1)',
        '## untagged (1)',
      ].map(md.indexOf).toList();
      expect(order, everyElement(greaterThan(0)));
      expect(order, orderedEquals([...order]..sort()));
      expect(
        md,
        contains('- **radio / gloat.d3** (@ 1.23 s): flat second roar'),
      );
      expect(md, contains('web/audio/comms/gloat.d3.ogg · sha a030bf5d03fb'));
      expect(
        md,
        contains('- **page / console**: sector 3 dives feel too fast'),
      );
    },
  );

  test('a change re-reads storage, so another tab\'s notes survive', () {
    final platform = MemoryReviewPlatform();
    final studio = _store(platform, 1);
    final console = _store(platform, 2); // a second tab, loaded first
    studio.add(_clip, text: 'from the studio');
    console.add(consoleNotesAsset, text: 'from the console');
    expect(_store(platform, 3).count, 2);
    console.refresh();
    expect(console.count, 2);
  });

  test('drafts outlive a reload until the note is added', () {
    final platform = MemoryReviewPlatform();
    _store(platform).saveDraft('page / console', 'half a thought', ['bug']);
    final after = _store(platform).draft('page / console');
    expect(after?.text, 'half a thought');
    expect(after?.tags, ['bug']);
    _store(platform).saveDraft('page / console', '', const []);
    expect(_store(platform).draft('page / console'), isNull);
  });

  test('/studio is the studio path; other paths are not', () {
    for (final p in ['/studio', '/studio/', '/STUDIO']) {
      expect(isStudioPath(p), isTrue, reason: p);
    }
    for (final p in ['/', '/gallery/', '/studios', '/console']) {
      expect(isStudioPath(p), isFalse, reason: p);
    }
  });

  testWidgets('page notes: a typed draft returns, adding saves and copies', (
    tester,
  ) async {
    final platform = MemoryReviewPlatform();
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget app(ReviewNotesStore store) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: PageNotesButton(asset: consoleNotesAsset, store: store),
        ),
      ),
    );

    await tester.pumpWidget(app(_store(platform)));
    await tester.tap(find.byKey(const ValueKey('page-notes')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-text')), 'too fast');
    await tester.pump();

    // A "reload": a fresh store and widget on the same browser storage.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(_store(platform)));
    await tester.tap(find.byKey(const ValueKey('page-notes')));
    await tester.pumpAndSettle();
    expect(find.text('too fast'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tag-bug')));
    await tester.pump();
    await tester.tap(find.text('Add note'));
    await tester.pump();
    expect(_store(platform).notesFor('page / console').single.text, 'too fast');
    expect(_store(platform).draft('page / console'), isNull);

    await tester.tap(find.byKey(const ValueKey('notes-copy')));
    await tester.pump();
    expect(clipboard, contains('## bug (1)'));
    expect(clipboard, contains('**page / console**: too fast'));

    await tester.tap(find.byKey(const ValueKey('notes-save')));
    await tester.pump();
    expect(platform.downloads.keys.single, endsWith('.md'));
  });
}
