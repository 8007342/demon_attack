import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// window.commsAudio from web/audio/comms-audio.js. Every call is guarded so a
// missing script (tests, an old cached index.html) is a silent no-op.
JSObject? get _comms {
  final value = globalContext.getProperty<JSAny?>('commsAudio'.toJS);
  return value.isA<JSObject>() ? value as JSObject : null;
}

void commsPrefetch(List<String> ids) => _comms?.callMethod<JSAny?>(
  'prefetch'.toJS,
  ids.map((id) => id.toJS).toList().toJS,
);
void commsPlay(String id, int priority, bool demon) =>
    _comms?.callMethod<JSAny?>('play'.toJS, id.toJS, priority.toJS, demon.toJS);
void commsStop(String id) => _comms?.callMethod<JSAny?>('stop'.toJS, id.toJS);
void commsStopAll() => _comms?.callMethod<JSAny?>('stopAll'.toJS);
void commsVolume(double volume) =>
    _comms?.callMethod<JSAny?>('setVolume'.toJS, volume.toJS);
