# Tasks

## 1. Research
- [x] 1.1 Browser matrix for `beforeinstallprompt` / `prompt()` and the Web Install API (design.md §1)
- [x] 1.2 Installability criteria and what the project already had (design.md §2)

## 2. Web shell
- [x] 2.1 `web/install_bridge.js`: defer `beforeinstallprompt`, track `appinstalled` and standalone, `window.demonInstall`
- [x] 2.2 `web/sw.js`: cache-free worker with a navigation fetch handler and offline notice
- [x] 2.3 `web/flutter_bootstrap.js`: load without Flutter's self-unregistering worker
- [x] 2.4 `web/index.html`: load the bridge before Flutter

## 3. Toast
- [x] 3.1 `InstallPrompt` (JS interop on web, nothing elsewhere)
- [x] 3.2 `InstallToastPolicy` (90-day snooze, try/catch storage) and `InstallToast` (radio-toast style)
- [x] 3.3 Title page only, never over Start; scroll room while it shows

## 4. Verification
- [x] 4.1 `test/install_toast_test.dart` (policy, widget, landing page, run start)
- [x] 4.2 `test-worker/pwa-install.test.mjs` (bridge, worker, manifest, bootstrap)
- [x] 4.3 `flutter analyze`, full `flutter test`, `npm run test:worker`
- [x] 4.4 `npm run build`; Chromium on the local preview reports the page installable and fires
      `beforeinstallprompt`; screenshot of the toast (design.md §5)
