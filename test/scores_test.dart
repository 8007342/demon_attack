import 'dart:convert';
import 'package:demon_attack/services/scores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'loads global leaderboard and submits only initials and score',
    () async {
      final endpoint = Uri.parse('https://game.test/api/scores');
      var requests = 0;
      final service = ScoreService(
        endpoint: endpoint,
        client: MockClient((request) async {
          requests++;
          expect(request.url, endpoint);
          if (request.method == 'POST') {
            expect(request.headers['content-type'], 'application/json');
            expect(jsonDecode(request.body), {
              'initials': 'A09',
              'score': 1234,
            });
          } else {
            expect(request.method, 'GET');
          }
          return http.Response(
            jsonEncode({
              'scores': [
                {'rank': 1, 'initials': 'A09', 'score': 1234},
              ],
            }),
            request.method == 'POST' ? 201 : 200,
          );
        }),
      );
      addTearDown(service.close);
      final loaded = await service.load();
      expect(loaded.single.initials, 'A09');
      expect(loaded.single.score, 1234);
      expect((await service.submit('A09', 1234)).single.score, 1234);
      expect(requests, 2);
    },
  );

  test(
    'surfaces server rejection and malformed responses for retry UI',
    () async {
      for (final response in [
        http.Response('unavailable', 503),
        http.Response('not JSON', 200),
        http.Response('{"scores":null}', 200),
      ]) {
        final service = ScoreService(client: MockClient((_) async => response));
        addTearDown(service.close);
        await expectLater(service.load(), throwsA(anything));
      }
    },
  );
}
