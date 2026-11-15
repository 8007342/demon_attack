# Proposal: pwa-install (one-click "install as an app" toast)

## Why
Operator feedback, 2026-11-15 (plan/operator-feedback-2026-11-15b.md, R7): "have a dismissable toast on the landing
page with a one click button to install as a ProgressiveWebApp on mobile and desktop browsers, please only do so if
it's truly a one click solution, prompting directly for user approval, we don't want to add an annoying link to
instructions. Please don't make it intrusive."

The game already ships a complete web app manifest and icons, but it is not installable through a prompt: the only
service worker it registers is Flutter's deprecated worker, which unregisters itself on activation, so Chromium never
fires `beforeinstallprompt` for a page without a fetch-handling worker.

## What Changes
- **Install bridge** (`web/install_bridge.js`, loaded before Flutter): captures and defers `beforeinstallprompt`,
  tracks `appinstalled` and `display-mode: standalone`, exposes `window.demonInstall` (`status`, `prompt`,
  `subscribe`) and registers `/sw.js`.
- **Service worker** (`web/sw.js`): cache-free; a real fetch handler answers page navigations network-first with a
  short offline notice. Every deploy is still live on the next load.
- **Custom `web/flutter_bootstrap.js`**: loads the app without Flutter's self-unregistering worker (it shares the
  root scope and would remove `/sw.js`).
- **Install toast** (`lib/widgets/install_toast.dart`, `lib/services/install_prompt*.dart`): a small card on the title
  page only, styled like the radio toasts, with `INSTALL` (calls the browser's `prompt()`) and a close `✕`. Shown
  only while the browser holds a deferred `beforeinstallprompt`; never during a run, never when installed. Closing it
  or declining the browser dialog snoozes it for 90 days (localStorage, every access in try/catch).
- **Nowhere else**: Safari (iOS, macOS) and Firefox have no one-click install API; they see nothing at all: no
  toast, no instructions, no links.

## Capabilities
### New Capabilities
- `pwa-install`: one-click install offer on the landing page, and the installability the build must keep.

## Impact
- `web/index.html`, `web/install_bridge.js`, `web/sw.js`, `web/flutter_bootstrap.js` (also used by the gallery build,
  which therefore no longer registers Flutter's worker either).
- `lib/main.dart` (title page), `lib/widgets/install_toast.dart`, `lib/services/install_prompt*.dart`.
- Tests: `test/install_toast_test.dart`, `test-worker/pwa-install.test.mjs`.
- Worker (`worker/index.mjs`) unchanged: `/sw.js` is a static asset.
