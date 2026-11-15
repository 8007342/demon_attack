// pwa-install: one-click "install as an app" bridge (openspec/changes/pwa-install).
//
// Loaded before flutter_bootstrap.js so the browser's `beforeinstallprompt`
// is captured even when it fires before Flutter has started. The Dart side
// (lib/services/install_prompt_web.dart) reads `window.demonInstall`:
//
//   status()      -> { available, installed }
//   prompt()      -> Promise<'accepted' | 'dismissed' | 'unavailable'>
//   subscribe(fn) -> calls fn() whenever status() may have changed
//
// `available` is true ONLY while the browser holds a deferred
// BeforeInstallPromptEvent, i.e. one click on our button opens the
// browser's own install approval. Browsers that never fire it (Safari on
// macOS and iOS, Firefox) leave it false, and the game shows nothing.
//
// It also registers /sw.js, a tiny network-first worker with a real fetch
// handler (Chromium only fires `beforeinstallprompt` for a page controlled
// by a worker that handles fetch).
(function (root) {
  'use strict';

  let deferred = null;
  let installed = false;
  const listeners = [];

  function notify() {
    for (const fn of listeners.slice()) {
      try { fn(); } catch (_) { /* a listener's failure is its own */ }
    }
  }

  function standalone() {
    try {
      if (root.navigator && root.navigator.standalone === true) return true; // iOS home screen
      if (typeof root.matchMedia !== 'function') return false;
      return ['standalone', 'fullscreen', 'minimal-ui', 'window-controls-overlay']
        .some((mode) => root.matchMedia('(display-mode: ' + mode + ')').matches);
    } catch (_) {
      return false;
    }
  }

  function status() {
    const isInstalled = installed || standalone();
    return { available: !isInstalled && deferred !== null, installed: isInstalled };
  }

  async function prompt() {
    const event = deferred;
    if (!event || typeof event.prompt !== 'function') return 'unavailable';
    // A BeforeInstallPromptEvent can be prompted once; forget it either way.
    deferred = null;
    notify();
    try {
      const result = await event.prompt();
      const choice = result && result.outcome ? result : await event.userChoice;
      const outcome = choice && choice.outcome;
      if (outcome === 'accepted') installed = true;
      notify();
      return outcome === 'accepted' ? 'accepted' : 'dismissed';
    } catch (_) {
      notify();
      return 'unavailable';
    }
  }

  function subscribe(fn) {
    if (typeof fn === 'function') listeners.push(fn);
  }

  root.addEventListener('beforeinstallprompt', (event) => {
    // Keep the browser's own mini-infobar away: the title-page toast is the
    // one place we offer installing, and only on the player's click.
    event.preventDefault();
    deferred = event;
    notify();
  });

  root.addEventListener('appinstalled', () => {
    installed = true;
    deferred = null;
    notify();
  });

  try {
    if (typeof root.matchMedia === 'function') {
      const query = root.matchMedia('(display-mode: standalone)');
      if (query && typeof query.addEventListener === 'function') query.addEventListener('change', notify);
    }
  } catch (_) { /* older engines: status() still reads the mode */ }

  function registerWorker() {
    try {
      const nav = root.navigator;
      if (!nav || !nav.serviceWorker || typeof nav.serviceWorker.register !== 'function') return;
      if (root.isSecureContext === false) return;
      nav.serviceWorker.register('/sw.js', { scope: '/' }).catch(() => {});
    } catch (_) { /* no worker: the game runs, it just is not installable */ }
  }

  if (root.document && root.document.readyState === 'complete') {
    registerWorker();
  } else {
    root.addEventListener('load', registerWorker);
  }

  root.demonInstall = { status, prompt, subscribe };
})(typeof window !== 'undefined' ? window : globalThis);
