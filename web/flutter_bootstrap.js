{{flutter_js}}
{{flutter_build_config}}

// pwa-install: load the app WITHOUT Flutter's own service worker. Flutter's
// worker is deprecated and only unregisters itself, which would also remove
// the game's /sw.js (same scope); web/install_bridge.js registers that one.
_flutter.loader.load();
