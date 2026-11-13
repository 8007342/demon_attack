// Web-only adapter, imported conditionally by review_platform.dart.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'review_platform.dart';

ReviewPlatform createPlatform() => _WebReviewPlatform();

@JS('localStorage')
external _Storage? get _storage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
}

@JS('Audio')
extension type _Audio._(JSObject _) implements JSObject {
  external factory _Audio();
  external set src(String value);
  external set preload(String value);
  external bool get paused;
  external double get currentTime;
  external set currentTime(double value);
  external double get duration;
  external JSPromise<JSAny?> play();
  external void pause();
  external void removeAttribute(String name);
  external void load();
}

class _WebReviewPlatform implements ReviewPlatform {
  @override
  String? read(String key) {
    try {
      return _storage?.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    try {
      _storage?.setItem(key, value);
    } catch (_) {
      // Private windows may refuse storage; export still works.
    }
  }

  @override
  void download(
    String filename,
    String text, {
    String type = 'application/json',
  }) {
    final blobClass = globalContext.getProperty<JSFunction>('Blob'.toJS);
    final options = JSObject()..setProperty('type'.toJS, type.toJS);
    final blob = blobClass.callAsConstructor<JSObject>(
      [text.toJS].toJS,
      options,
    );
    final url = globalContext
        .getProperty<JSObject>('URL'.toJS)
        .callMethod<JSString>('createObjectURL'.toJS, blob);
    final document = globalContext.getProperty<JSObject>('document'.toJS);
    final anchor = document.callMethod<JSObject>(
      'createElement'.toJS,
      'a'.toJS,
    );
    anchor
      ..setProperty('href'.toJS, url)
      ..setProperty('download'.toJS, filename.toJS);
    document
        .getProperty<JSObject>('body'.toJS)
        .callMethod('appendChild'.toJS, anchor);
    anchor.callMethod('click'.toJS);
    anchor.callMethod('remove'.toJS);
    globalContext
        .getProperty<JSObject>('URL'.toJS)
        .callMethod('revokeObjectURL'.toJS, url);
  }

  @override
  ReviewAudio audio() => _WebReviewAudio();
}

class _WebReviewAudio implements ReviewAudio {
  final _element = _Audio()..preload = 'auto';

  @override
  void play(String url) {
    _element.src = Uri.base.resolve(url).toString();
    _element.play().toDart.ignore();
  }

  @override
  void pause() => _element.pause();

  @override
  void resume() => _element.play().toDart.ignore();

  @override
  void seek(double seconds) {
    try {
      _element.currentTime = seconds;
    } catch (_) {}
  }

  @override
  bool get playing => !_element.paused;

  @override
  double get position => _element.currentTime;

  @override
  double get duration => _element.duration;

  @override
  void dispose() {
    _element.pause();
    _element.removeAttribute('src');
    _element.load();
  }
}
