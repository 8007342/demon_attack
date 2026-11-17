// --- adaptive-soundtrack: the review studio's music tab plays the score.
//
// The game's music is the MIDI-first score (web/audio/score/), played live by
// demon-score.js, so a music "cue" in the studio is one score section. This
// adapter gives MusicView the same transport it had for recorded files: play
// starts the section on the live player at once (its tier-4 mask), pause and
// resume suspend the audio clock, and the position is the time since the
// section's start (the loop wraps it). A seek restarts the section: a score
// section has no file offset to jump to.
import 'dart:math' as math;

import '../services/audio.dart';
import 'review_platform.dart';

class ScoreReviewAudio implements ReviewAudio {
  String? _song, _section;
  bool _playing = false;

  /// The section's written length in seconds (MusicView's cue knows it).
  double length = double.nan;

  /// `audio/score/<song>/<section>.mid` → the song and section.
  static (String, String)? parse(String url) {
    final m = RegExp(r'audio/score/([^/]+)/([^/]+)\.mid$').firstMatch(url);
    return m == null ? null : (m.group(1)!, m.group(2)!);
  }

  @override
  void play(String url) {
    final target = parse(url);
    if (target == null) return;
    _song = target.$1;
    _section = target.$2;
    audioUnlock();
    audioResume();
    audioSong({
      'song': _song,
      'section': _section,
      'at': -1,
      'quantum': 'now',
      'enter': 'start',
      'tier': 4,
      'reason': 'review',
    });
    _playing = true;
  }

  @override
  void pause() {
    audioPause();
    _playing = false;
  }

  @override
  void resume() {
    audioResume();
    _playing = _song != null;
  }

  @override
  void seek(double seconds) {
    if (_song != null && _section != null) {
      play('audio/score/$_song/$_section.mid');
    }
  }

  @override
  bool get playing => _playing;

  @override
  double get position {
    final p = audioScorePosition();
    if (p == null || p.song != _song) return 0;
    final t = math.max(0.0, audioTime() - p.start);
    return length.isFinite && length > 0 ? t % length : t;
  }

  @override
  double get duration => length;

  @override
  void dispose() {}
}
