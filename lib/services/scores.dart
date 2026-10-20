import 'dart:convert';
import 'package:http/http.dart' as http;

class ScoreEntry {
  const ScoreEntry(this.initials, this.score);
  final String initials;
  final int score;
}

class ScoreService {
  ScoreService({http.Client? client, Uri? endpoint})
    : client = client ?? http.Client(),
      endpoint = endpoint ?? Uri.base.resolve('/api/scores');
  final http.Client client;
  final Uri endpoint;
  Future<List<ScoreEntry>> load() async =>
      _decode(await client.get(endpoint).timeout(const Duration(seconds: 8)));
  Future<List<ScoreEntry>> submit(String initials, int score) async => _decode(
    await client
        .post(
          endpoint,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'initials': initials, 'score': score}),
        )
        .timeout(const Duration(seconds: 8)),
  );
  List<ScoreEntry> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('Scores unavailable');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['scores'] as List)
        .map((e) => ScoreEntry(e['initials'] as String, e['score'] as int))
        .toList();
  }

  void close() => client.close();
}
