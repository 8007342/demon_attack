import 'review_platform.dart';

ReviewPlatform createPlatform() => MemoryReviewPlatform();

/// In-memory platform for tests and non-web builds; records downloads.
class MemoryReviewPlatform implements ReviewPlatform {
  final store = <String, String>{};
  final downloads = <String, String>{};
  final players = <MemoryReviewAudio>[];

  @override
  String? read(String key) => store[key];

  @override
  void write(String key, String value) => store[key] = value;

  @override
  void download(String filename, String text, {String type = ''}) =>
      downloads[filename] = text;

  @override
  ReviewAudio audio() {
    final player = MemoryReviewAudio();
    players.add(player);
    return player;
  }
}

/// A silent player whose playhead follows the wall clock while playing.
class MemoryReviewAudio implements ReviewAudio {
  String? url;
  double _base = 0;
  DateTime? _since;
  @override
  double duration = double.nan;

  @override
  void play(String url) {
    this.url = url;
    _base = 0;
    _since = DateTime.now();
  }

  @override
  void pause() {
    _base = position;
    _since = null;
  }

  @override
  void resume() => _since ??= DateTime.now();

  @override
  void seek(double seconds) {
    _base = seconds;
    if (_since != null) _since = DateTime.now();
  }

  @override
  bool get playing => _since != null;

  @override
  double get position {
    final since = _since;
    if (since == null) return _base;
    return _base + DateTime.now().difference(since).inMicroseconds / 1e6;
  }

  @override
  void dispose() => _since = null;
}
