import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:demon_attack/comms/comms_bank.dart';
import 'package:demon_attack/review/notes_panel.dart';
import 'package:demon_attack/review/review_catalog.dart';
import 'package:demon_attack/review/review_notes.dart';
import 'package:demon_attack/review/review_platform_stub.dart';
import 'package:demon_attack/review/review_studio.dart';
import 'package:demon_attack/review/sha256.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ReviewAsset _clipAsset() => ReviewAsset(
  kind: ReviewKind.radio,
  id: 'gloat.d3',
  title: 'GORRAK · gloat',
  source: 'web/audio/comms/gloat.d3.ogg',
  hash: 'a030bf5d03fb8b389f83b69092752c3a',
);

ReviewNotesStore _store(MemoryReviewPlatform platform, [int seed = 1]) {
  var t = DateTime.utc(2026, 11, 13, 10);
  return ReviewNotesStore(
    platform,
    clock: () => t = t.add(const Duration(seconds: 1)),
    random: math.Random(seed),
  );
}

void main() {
  test('sha256 matches the FIPS test vectors and sha256sum', () {
    expect(
      sha256Hex(const []),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      sha256Hex(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      sha256Hex(
        utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
    // A real asset against the music manifest's recorded hash.
    final manifest = jsonDecode(
      File('web/audio/music/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final menu = manifest['cues']['menu']['sha256']['ogg'] as String;
    expect(sha256Hex(File('web/audio/music/menu.ogg').readAsBytesSync()), menu);
  });

  test('notes persist, export, merge and keep the newer edit', () {
    final platform = MemoryReviewPlatform();
    final store = _store(platform);
    final note = store.add(
      _clipAsset(),
      tags: const ['needs-growl', 'uncompressed-sound'],
      text: '  still no growl  ',
      offset: 1.234,
      section: 'gloat',
    );
    expect(note.ref, 'radio / gloat.d3');
    expect(note.text, 'still no growl');
    expect(note.offset, 1.23);
    expect(note.hash, startsWith('a030bf5d'));
    expect(RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(note.id), isTrue);
    expect(store.pending, 1);

    // Reload from storage.
    final again = _store(platform, 2);
    expect(again.count, 1);
    expect(again.notesFor('radio / gloat.d3').single.tags, [
      'needs-growl',
      'uncompressed-sound',
    ]);
    expect(again.pending, 1);

    // Export round trip in the shared format.
    final exported = jsonDecode(again.exportJson()) as Map<String, dynamic>;
    expect(exported['schema'], notesSchema);
    expect(exported['count'], 1);
    final first = exported['notes'][0] as Map<String, dynamic>;
    expect(
      first.keys,
      containsAll([
        'id',
        'ref',
        'kind',
        'asset',
        'source',
        'hash',
        'tags',
        'text',
        'offset',
        'createdAt',
        'updatedAt',
      ]),
    );
    final parsed = ReviewNotesStore.parse(again.exportJson());
    expect(parsed.single.toJson(), note.toJson());

    // Merge: newer updatedAt wins, older does not overwrite.
    again.edit(note.id, text: 'growl added but too quiet');
    final edited = again.notes.single;
    expect(edited.updatedAt.compareTo(note.updatedAt), greaterThan(0));
    expect(again.merge([note]), 0);
    expect(again.notes.single.text, 'growl added but too quiet');

    again.remove(note.id);
    expect(again.count, 0);
    expect(again.pending, 0, reason: 'never synced, so no server delete');
  });

  test('sync pushes, deletes and pulls through /api/notes', () async {
    final platform = MemoryReviewPlatform();
    final store = _store(platform);
    final server = <String, Map<String, dynamic>>{};
    final calls = <String>[];
    final api = NotesApi((method, url, headers, body) async {
      calls.add('$method ${url.path}${url.hasQuery ? '?${url.query}' : ''}');
      if (headers['authorization'] != 'Bearer secret') {
        return (401, '{"error":"Operator token required"}');
      }
      switch (method) {
        case 'POST':
          for (final n in (jsonDecode(body!) as Map)['notes'] as List) {
            server[n['id'] as String] = n as Map<String, dynamic>;
          }
          return (201, '{}');
        case 'DELETE':
          server.remove(url.queryParameters['id']);
          return (200, '{"deleted":1}');
        default:
          return (
            200,
            jsonEncode({
              'schema': notesSchema,
              'notes': server.values.toList(),
            }),
          );
      }
    }, base: Uri.parse('https://game.test/api/notes'));

    expect(await store.sync(api), contains('token'));
    store.token = 'wrong';
    final a = store.add(_clipAsset(), tags: const ['flat-emotion']);
    await expectLater(store.sync(api), throwsA(isA<NotesApiException>()));
    expect(store.pending, 1, reason: 'a failed sync keeps the note pending');

    store.token = 'secret';
    server['remote-note-1'] = {
      'id': 'remote-note-1',
      'kind': 'music',
      'asset': 'l1-t3',
      'tags': ['timing'],
      'text': 'drums drag',
      'createdAt': '2026-11-12T09:00:00.000Z',
    };
    final result = await store.sync(api);
    expect(result, contains('sent 1'));
    expect(store.pending, 0);
    expect(store.count, 2);
    expect(server.containsKey(a.id), isTrue);

    store.remove(a.id);
    expect(store.pending, 1);
    await store.sync(api);
    expect(server.containsKey(a.id), isFalse);
    expect(calls, contains('DELETE /api/notes?id=${a.id}'));
    expect(store.notes.single.ref, 'music / l1-t3');
  });

  test('catalog covers the radio bank, the music manifest and the atlases', () {
    final comms = jsonDecode(
      File('web/audio/comms/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final clips = radioClips();
    final bankIds = {for (final c in clips) c.line.id};
    expect(bankIds.length, clips.length, reason: 'clip ids are unique');
    expect(bankIds, containsAll((comms['clips'] as Map).keys));
    expect(clips.any((c) => c.demon), isTrue);
    expect(clips.any((c) => !c.demon && c.emotion.isNotEmpty), isTrue);
    expect(clips.every((c) => commsCast.containsKey(c.line.speaker)), isTrue);

    final music = jsonDecode(
      File('web/audio/music/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cues = musicCues(music);
    expect(cues.length, (music['cues'] as Map).length);
    final layers = cues.firstWhere((c) => c.name == 'l1-layers');
    expect(layers.slots, contains('stab'));
    expect(layers.stem, isTrue);
    expect(
      cues.firstWhere((c) => c.name == 'l1-t1').score,
      'web/audio/midi/l1-t1.mid',
    );
    for (final c in cues) {
      expect(File('web/${c.url}').existsSync(), isTrue, reason: c.url);
      if (c.score != null) {
        expect(File(c.score!).existsSync(), isTrue, reason: c.score);
      }
    }

    final ship = jsonDecode(
      File('assets/images/ship-weapons.json').readAsStringSync(),
    );
    final anims = atlasAnimations(shipWeapons: ship as Map<String, Object?>);
    final ids = {for (final a in anims) a.asset().id};
    expect(ids.length, anims.length, reason: 'atlas ids are unique');
    expect(
      ids,
      containsAll([
        'creature-teal/flight-neutral',
        'sentinel/breakup',
        'ship/hull-exhaust',
        'portraits/gorrak',
      ]),
    );
    for (final a in anims) {
      expect(File(a.path).existsSync(), isTrue, reason: a.path);
      expect(a.frames, isNotEmpty, reason: a.id);
      expect(a.bounds.isEmpty, isFalse, reason: a.id);
    }
    for (var s = 0; s < 5; s++) {
      for (final f in backgroundFiles(s)) {
        expect(File(f).existsSync(), isTrue, reason: f);
      }
    }
  });

  testWidgets('notes panel stamps tags, text and the playhead on an asset', (
    tester,
  ) async {
    final platform = MemoryReviewPlatform();
    final store = _store(platform);
    final link = PlayheadLink()
      ..position = (() => 2.5)
      ..section = (() => 'bars 3-4');
    double? sought;
    link.seek = (s) => sought = s;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotesPanel(asset: _clipAsset(), store: store, link: link),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('tag-needs-growl')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tag-jitter')),
      findsNothing,
      reason: 'visual tags are not offered for radio',
    );
    await tester.tap(find.byKey(const ValueKey('tag-needs-growl')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('note-text')),
      'sounds like uncompressed audio',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-save')));
    await tester.pump();
    final note = store.notes.single;
    expect(note.tags, ['needs-growl']);
    expect(note.text, 'sounds like uncompressed audio');
    expect(note.offset, 2.5);
    expect(note.section, 'bars 3-4');
    await tester.tap(find.text('@ 0:02.50'));
    expect(sought, 2.5);
  });

  testWidgets('studio lists radio clips by filter and exports notes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final platform = MemoryReviewPlatform();
    final comms = File('web/audio/comms/manifest.json').readAsStringSync();
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewStudio(
          platform: platform,
          sceneBuilder: (page) => Text('scene $page'),
          loadText: (path) async => path.contains('comms') ? comms : null,
          initialTab: StudioTab.radio,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final demonClip = radioClips().firstWhere((c) => c.demon);
    await tester.tap(find.byKey(const ValueKey('side-demon')));
    await tester.pump();
    expect(
      find.textContaining('of ${radioClips().length} clips'),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('clip-${demonClip.line.id}')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('clip-${demonClip.line.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tag-needs-growl')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-export')));
    await tester.pump();
    final exported =
        jsonDecode(platform.downloads.values.single) as Map<String, dynamic>;
    final note = (exported['notes'] as List).single as Map<String, dynamic>;
    expect(note['ref'], 'radio / ${demonClip.line.id}');
    expect(note['tags'], ['needs-growl']);
    expect(note['hash'], isNotNull, reason: 'manifest sha256');
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(390, 844),
    const Size(900, 700),
    const Size(1440, 900),
  ]) {
    testWidgets('every studio tab lays out at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final music = File('web/audio/music/manifest.json').readAsStringSync();
      for (final (tab, item) in [
        (StudioTab.sprites, 'creature-gold/death'),
        (StudioTab.music, 'l2-layers'),
        (StudioTab.backgrounds, 'sector-3'),
        (StudioTab.scenes, 'carrier'),
        (StudioTab.radio, null),
        (StudioTab.notes, null),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$tab'),
            home: ReviewStudio(
              platform: MemoryReviewPlatform(),
              sceneBuilder: (page) => Text('scene $page'),
              loadText: (path) async => path.contains('music') ? music : null,
              initialTab: tab,
              initialItem: item,
            ),
          ),
        );
        await tester.pump();
        // Manifests and the ship JSON load asynchronously.
        for (
          var i = 0;
          i < 20 && find.byType(NotesPanel).evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull, reason: '$tab');
        if (item != null && size.width >= 720) {
          expect(find.byType(NotesPanel), findsOneWidget, reason: '$tab');
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
