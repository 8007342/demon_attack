import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('demonAudio.unlock')
external void _unlock();
@JS('demonAudio.sfx')
external void _sfx(JSString name);
@JS('demonAudio.intensity')
external void _intensity(JSNumber tier);
@JS('demonAudio.accent')
external void _accent(JSString name);
@JS('demonAudio.fleetIntact')
external void _fleetIntact();
@JS('demonAudio.mute')
external void _mute(JSBoolean muted);
@JS('demonAudio.setLevel')
external void _setLevel(JSString channel, JSString level);
@JS('demonAudio.levels')
external JSObject? get _levels;
@JS('demonAudio.powerLayer')
external void _powerLayer(JSNumber active, JSBoolean falling);
@JS('demonAudio.pause')
external void _pause();
@JS('demonAudio.resume')
external void _resume();
void audioUnlock() => _unlock();
void audioSfx(String name) => _sfx(name.toJS);
void audioMute(bool muted) => _mute(muted.toJS);
void audioPause() => _pause();
void audioResume() => _resume();
void audioIntensity(int tier) => _intensity(tier.toJS);
void audioAccent(String name) => _accent(name.toJS);
void audioFleetIntact() => _fleetIntact();

/// Music / speech volume level ('mute' | 'low' | 'full'), remembered per
/// device by web/audio/demon-audio.js.
void audioSetLevel(String channel, String level) =>
    _setLevel(channel.toJS, level.toJS);
String audioLevel(String channel) {
  try {
    final value = _levels?.getProperty<JSAny?>(channel.toJS);
    return value.isA<JSString>() ? (value as JSString).toDart : 'full';
  } catch (_) {
    return 'full';
  }
}

void audioPowerLayer(int active, bool falling) =>
    _powerLayer(active.toJS, falling.toJS);

// --- sample-bank: the score's CC0 sample bank, off by default until the
// operator approves it (demon-score.js BANK_DEFAULT). The /console music panel
// switches it per device; `?bank=1` decides for one page load.
@JS('demonAudio.scoreBank')
external JSBoolean? get _scoreBank;
@JS('demonAudio.setScoreBank')
external JSBoolean? _setScoreBank(JSBoolean on);
@JS('demonAudio.state')
external JSObject? get _audioState;

bool audioScoreBank() {
  try {
    return _scoreBank?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

/// Switches the sample bank on or off (stored on this device); returns the new
/// state, false when the page has no score.
bool audioSetScoreBank(bool on) {
  try {
    return _setScoreBank(on.toJS)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

int _int(JSObject o, String key) {
  final v = o.getProperty<JSAny?>(key.toJS);
  return v.isA<JSNumber>() ? (v as JSNumber).toDartDouble.round() : 0;
}

/// The bank's loading state for the panel: sprites loaded of this device's,
/// decoded bytes, notes sampled so far.
({bool on, int loaded, int sprites, int decodedBytes, int sampled})?
audioScoreBankState() {
  try {
    final score = _audioState?.getProperty<JSAny?>('score'.toJS);
    if (score == null || !score.isA<JSObject>()) return null;
    final bank = (score as JSObject).getProperty<JSAny?>('bank'.toJS);
    if (bank == null || !bank.isA<JSObject>()) return null;
    final b = bank as JSObject;
    final on = b.getProperty<JSAny?>('enabled'.toJS);
    return (
      on: on.isA<JSBoolean>() && (on as JSBoolean).toDart,
      loaded: _int(b, 'loaded'),
      sprites: _int(b, 'sprites'),
      decodedBytes: _int(b, 'decodedBytes'),
      sampled: _int(b, 'sampled'),
    );
  } catch (_) {
    return null;
  }
}

// --- adaptive-soundtrack: the score player (web/audio/demon-score.js, driven
// by SongDirector). Every call is safe when the page has no audio engine.
@JS('demonAudio.song')
external JSNumber? _song(JSAny? move);
@JS('demonAudio.time')
external JSNumber? get _time;
@JS('demonAudio.scorePosition')
external JSObject? get _scorePosition;

/// Sends a section or mask move; returns the time it lands on (audio clock),
/// -1 while the score or the audio context is not ready, -2 when it failed.
double audioSong(Map<String, Object?> move) {
  try {
    return _song(move.jsify())?.toDartDouble ?? -2;
  } catch (_) {
    return -2;
  }
}

/// Seconds on the audio clock, or -1 before the first gesture.
double audioTime() {
  try {
    return _time?.toDartDouble ?? -1;
  } catch (_) {
    return -1;
  }
}

/// The section the score is playing and the time of its beat 0.
({String song, String section, double start})? audioScorePosition() {
  try {
    final p = _scorePosition;
    if (p == null) return null;
    final song = p.getProperty<JSAny?>('song'.toJS);
    final section = p.getProperty<JSAny?>('section'.toJS);
    final start = p.getProperty<JSAny?>('start'.toJS);
    if (!song.isA<JSString>() || !section.isA<JSString>()) return null;
    if (!start.isA<JSNumber>()) return null;
    return (
      song: (song as JSString).toDart,
      section: (section as JSString).toDart,
      start: (start as JSNumber).toDartDouble,
    );
  } catch (_) {
    return null;
  }
}
