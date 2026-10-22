import 'dart:js_interop';

import 'run_storage.dart';

@JS('localStorage.getItem')
external JSString? _read(JSString key);
@JS('localStorage.setItem')
external void _write(JSString key, JSString value);
@JS('localStorage.removeItem')
external void _remove(JSString key);

class BrowserLocalStore implements LocalStore {
  @override
  String? read(String key) => _read(key.toJS)?.toDart;
  @override
  void write(String key, String value) => _write(key.toJS, value.toJS);
  @override
  void remove(String key) => _remove(key.toJS);
}

LocalStore createLocalStore() => BrowserLocalStore();
