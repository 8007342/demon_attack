import 'dart:convert';

import 'package:http/http.dart' as http;

import '../game/difficulty.dart';

class ScoreEntry {
  const ScoreEntry(
    this.initials,
    this.score, {
    this.difficulty = Difficulty.normal,
    this.medals = 0,
    this.activeMilliseconds,
    this.remainingLives,
  });
  final Difficulty difficulty;
  final int medals;
  final int? activeMilliseconds;
  final int? remainingLives;
  final String initials;
  final int score;
}

class ScoreService {
  ScoreService({http.Client? client, Uri? endpoint})
    : client = client ?? http.Client(),
      endpoint = endpoint ?? Uri.base.resolve('/api/scores');
  final http.Client client;
  final Uri endpoint;
  Future<List<ScoreEntry>> load({
    Difficulty difficulty = Difficulty.normal,
  }) async => _decode(
    await client
        .get(
          difficulty == Difficulty.normal
              ? endpoint
              : endpoint.replace(
                  queryParameters: {
                    ...endpoint.queryParameters,
                    'difficulty': difficulty.name,
                  },
                ),
        )
        .timeout(const Duration(seconds: 8)),
  );
  Future<List<ScoreEntry>> submit(
    String initials,
    int score, {
    Difficulty difficulty = Difficulty.normal,
    int medals = 0,
    int? activeMilliseconds,
    int? remainingLives,
  }) async => _decode(
    await client
        .post(
          endpoint,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'initials': initials,
            'score': score,
            if (difficulty != Difficulty.normal) 'difficulty': difficulty.name,
            if (medals != 0) 'medals': medals,
            'activeMilliseconds': ?activeMilliseconds,
            'remainingLives': ?remainingLives,
          }),
        )
        .timeout(const Duration(seconds: 8)),
  );
  List<ScoreEntry> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('Scores unavailable');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['scores'] as List)
        .map(
          (e) => ScoreEntry(
            e['initials'] as String,
            e['score'] as int,
            difficulty: Difficulty.values.firstWhere(
              (mode) => mode.name == e['difficulty'],
              orElse: () => Difficulty.normal,
            ),
            medals: e['medals'] as int? ?? 0,
            activeMilliseconds: e['activeMilliseconds'] as int?,
            remainingLives: e['remainingLives'] as int?,
          ),
        )
        .toList();
  }

  void close() => client.close();
}
