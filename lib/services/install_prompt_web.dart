import 'dart:js_interop';

import 'install_prompt_base.dart';

export 'install_prompt_base.dart';

extension type _InstallStatus._(JSObject _) implements JSObject {
  external bool get available;
  external bool get installed;
}

@JS('demonInstall')
external JSObject? get _bridge;

@JS('demonInstall.status')
external _InstallStatus _status();

@JS('demonInstall.prompt')
external JSPromise<JSString> _prompt();

@JS('demonInstall.subscribe')
external void _subscribe(JSFunction listener);

/// Reads web/install_bridge.js; without it (a page that did not load the
/// bridge) nothing is ever offered.
class BrowserInstallPrompt extends InstallPrompt {
  BrowserInstallPrompt() {
    if (_bridge == null) return;
    try {
      _subscribe(notifyListeners.toJS);
    } catch (_) {}
  }

  _InstallStatus? get _current {
    if (_bridge == null) return null;
    try {
      return _status();
    } catch (_) {
      return null;
    }
  }

  @override
  bool get available => _current?.available ?? false;
  @override
  bool get installed => _current?.installed ?? false;

  @override
  Future<InstallOutcome> prompt() async {
    if (_bridge == null) return InstallOutcome.unavailable;
    try {
      final outcome = (await _prompt().toDart).toDart;
      return InstallOutcome.values.firstWhere(
        (value) => value.name == outcome,
        orElse: () => InstallOutcome.unavailable,
      );
    } catch (_) {
      return InstallOutcome.unavailable;
    }
  }
}

InstallPrompt createInstallPrompt() => BrowserInstallPrompt();
