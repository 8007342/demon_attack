import 'dart:js_interop';

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
@JS('demonAudio.mute')
external void _mute(JSBoolean muted);
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
