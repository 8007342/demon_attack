import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('demonAudio.unlock')
external void _unlock();
@JS('demonAudio.cue')
external void _cue(
  JSString mode,
  JSNumber level,
  JSNumber phase,
  JSNumber cycle,
);
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
void audioCue(String mode, int level, int phase, int cycle) =>
    _cue(mode.toJS, level.toJS, phase.toJS, cycle.toJS);
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
