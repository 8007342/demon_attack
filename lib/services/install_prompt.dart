// pwa-install: the browser's one-click install offer, as seen from Dart.
//
// On the web this reads web/install_bridge.js (`window.demonInstall`); on
// every other platform, and in tests, nothing is ever offered.
export 'install_prompt_stub.dart'
    if (dart.library.js_interop) 'install_prompt_web.dart';
