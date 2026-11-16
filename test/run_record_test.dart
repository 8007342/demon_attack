// bonus-balance: the run record. The model names a run's modifiers (the
// bonus levels it reached, its run rule); the scoreboard stores them with
// the play date, older records without either still load; the end-of-run
// medal screen shows medals, modifiers, date, time and score, compact on a
// 360-wide phone.
import 'dart:convert';

import 'package:demon_attack/game/model.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:demon_attack/widgets/run_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A run seed whose plan has a bonus level on route 0 and a run modifier.
int seedWithLevelAndModifier() {
  for (var s = 1; s < 200000; s++) {
    final p = BonusPlan.forRun(s);
    if (p.modifier != null && p.slots.isNotEmpty && p.slots[0].route == 0) {
      return s;
    }
  }
  throw StateError('no seed');
}

void main() {
  group('the model names the run\'s modifiers', () {
    test('an unseeded run has none', () {
      final m = ArcadeModel()..start();
      expect(m.runModifierIds, isEmpty);
    });

    test('a forced bonus level and run rule', () {
      final m = ArcadeModel()
        ..startAt(sector: 2, bonus: 'supplyRun', modifier: 'noShield');
      expect(m.runModifierIds, ['supplyRun', 'noShield']);
    });

    test('a bonus level counts once the run reaches it, and survives a '
        'checkpoint', () {
      final seed = seedWithLevelAndModifier();
      final plan = BonusPlan.forRun(seed);
      final slot = plan.slots[0];
      final early = ArcadeModel()..start(runSeed: seed);
      expect(early.runModifierIds, [plan.modifier!.id]);
      final later = ArcadeModel()
        ..startAt(sector: slot.sector, route: slot.route, runSeed: seed);
      expect(later.runModifierIds, [slot.level.id, plan.modifier!.id]);
      final restored = ArcadeModel();
      expect(
        restored.restoreCheckpoint({
          ...later.checkpoint(),
          'routeIndex': 1,
          'sector': 2,
          'medals': 1,
        }),
        isTrue,
      );
      expect(restored.runModifierIds, [slot.level.id, plan.modifier!.id]);
    });

    test('every tag has a display name; unknown ids are spelled out', () {
      for (final l in bonusLevels) {
        expect(runTagLabel(l.id), l.label);
      }
      for (final r in runModifiers) {
        expect(runTagLabel(r.id), isNotEmpty);
        expect(runTagLabel(r.id), r.label);
      }
      expect(runTagLabel('ionStorm'), 'ION STORM');
    });
  });

  group('the scoreboard keeps them', () {
    test('a record sends its modifiers and play date', () async {
      Map<String, dynamic>? sent;
      final service = ScoreService(
        endpoint: Uri.parse('https://scores.example/api/scores'),
        client: MockClient((r) async {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response('{"scores":[]}', 201);
        }),
      );
      await service.submit(
        'ABC',
        10,
        medals: 2,
        modifiers: const ['stormfront', 'spreadOnly'],
        playedOn: '2026-11-16',
      );
      expect(sent!['modifiers'], ['stormfront', 'spreadOnly']);
      expect(sent!['playedOn'], '2026-11-16');
      await service.submit('ABC', 10, playedOn: '2026-11-16');
      expect(sent!.containsKey('modifiers'), isFalse);
    });

    test('old records decode with no modifiers and no date', () async {
      final service = ScoreService(
        endpoint: Uri.parse('https://scores.example/api/scores'),
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'scores': [
                {'initials': 'OLD', 'score': 900, 'medals': 3},
                {
                  'initials': 'NEW',
                  'score': 800,
                  'modifiers': ['supplyRun'],
                  'playedOn': '2026-11-16',
                },
              ],
            }),
            200,
          ),
        ),
      );
      final [old, fresh] = await service.load();
      expect(old.modifiers, isEmpty);
      expect(old.playedOn, isNull);
      expect(fresh.modifiers, ['supplyRun']);
      expect(fresh.playedOn, '2026-11-16');
    });

    test('the play date is the local calendar day', () {
      expect(playDate(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
      expect(playDateLabel('2026-11-16'), '16 NOV 2026');
      expect(playDateLabel(null), isNull);
      expect(playDateLabel('16/11/2026'), isNull);
      expect(playTimeLabel(3723000), '62:03');
    });
  });

  group('the medal screen', () {
    Future<void> pumpCard(WidgetTester tester, ScoreEntry entry) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              // The board's own gutter on a phone.
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: RunRecordCard(entry: entry),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows medals, modifiers, date, time and score', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const ScoreEntry(
          'YOU',
          123456,
          difficulty: Difficulty.hard,
          medals: 3,
          activeMilliseconds: 754000,
          modifiers: ['supplyRun', 'heavyOrdnance'],
          playedOn: '2026-11-16',
        ),
      );
      expect(find.text('3/5 MEDALS'), findsOneWidget);
      expect(find.text('123456'), findsOneWidget);
      expect(find.text('TIME 12:34'), findsOneWidget);
      expect(find.text('16 NOV 2026'), findsOneWidget);
      expect(find.text('SUPPLY RUN'), findsOneWidget);
      expect(find.text('HEAVY ORDNANCE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Compact: under a fifth of the phone's height.
      final h = tester.getSize(find.byKey(const ValueKey('run-record'))).height;
      expect(h, lessThan(780 / 5));
    });

    testWidgets('every catalogue tag at once still fits 360 wide', (
      tester,
    ) async {
      await pumpCard(
        tester,
        ScoreEntry(
          'YOU',
          999999999,
          medals: 5,
          activeMilliseconds: 99 * 60000,
          modifiers: [
            for (final l in bonusLevels) l.id,
            runModifiers.last.id,
          ].take(4).toList(),
          playedOn: '2026-12-31',
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a run without modifiers says so', (tester) async {
      await pumpCard(tester, const ScoreEntry('YOU', 5, medals: 0));
      expect(find.text('STANDARD RUN'), findsOneWidget);
      expect(find.byKey(const ValueKey('run-record-date')), findsNothing);
      expect(find.text('TIME —'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
