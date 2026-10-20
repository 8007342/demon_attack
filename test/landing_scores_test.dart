import 'dart:async';
import 'dart:convert';
import 'package:demon_attack/main.dart';
import 'package:demon_attack/services/scores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final topTen = List.generate(
  10,
  (index) => {
    'rank': index + 1,
    'initials': 'A0$index',
    'score': 100000 - index,
  },
);

void main() {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets(
      'landing automatically shows all ten scores at ${size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var loads = 0;
        final scores = ScoreService(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            loads++;
            return http.Response(jsonEncode({'scores': topTen}), 200);
          }),
        );
        await tester.pumpWidget(
          MaterialApp(home: ArcadePage(scoreService: scores)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(loads, 1);
        expect(find.text('START GAME  →').hitTestable(), findsOneWidget);
        expect(find.text('TOP 10 SCORES'), findsNothing);
        expect(find.text('TOP 10'), findsOneWidget);
        for (var index = 0; index < 10; index++) {
          expect(find.text('A0$index'), findsOneWidget);
        }
        // The board is part of the landing scroll, including its last ranked row.
        await tester.ensureVisible(find.text('A09'));
        await tester.pump();
        expect(find.text('A09').hitTestable(), findsOneWidget);
        expect(find.text('LEAVE YOUR MARK'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'leaderboard loading and failures keep Start usable and retry inline',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<http.Response>();
      var loads = 0;
      final scores = ScoreService(
        client: MockClient((_) async {
          loads++;
          if (loads == 1) return pending.future;
          return http.Response('{"scores":[]}', 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: ArcadePage(scoreService: scores)),
      );
      await tester.pump();
      final start = find.text('START GAME  →');
      expect(start.hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(of: start, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
      );
      pending.complete(http.Response('Unavailable', 503));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(start.hitTestable(), findsOneWidget);
      expect(find.text('TOP 10 SCORES'), findsNothing);
      final retry = find.text('RETRY');
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(loads, 2);
      expect(find.text('RETRY'), findsNothing);
      expect(find.text('TOP 10'), findsOneWidget);
      expect(find.textContaining('BE THE FIRST'), findsOneWidget);
      await tester.ensureVisible(start);
      await tester.pump();
      expect(start.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
