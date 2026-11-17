# Design: pwa-install

## Context
R7 asks for a one-click install toast on the landing page, and only where it is truly one click: the click must open
the browser's own install approval directly. No instruction links, nothing intrusive. Research date: 2026-11-15.

## 1. Browser matrix

"One click" here means: a page script, from one user click, opens the browser's own install dialog. Today the only
shipped API for that is the non-standard `BeforeInstallPromptEvent` (`beforeinstallprompt` + `prompt()`).

| Browser | `beforeinstallprompt` / `prompt()` | One click? | What the game shows |
|---|---|---|---|
| Chrome desktop (Windows, macOS, Linux, ChromeOS) | yes, 44 / 76 | yes | toast |
| Chrome Android | yes, 44 / 76 (installs a WebAPK) | yes | toast |
| Edge desktop and Android | yes (Chromium) | yes | toast |
| Opera desktop and Android | yes (Chromium) | yes | toast |
| Samsung Internet | yes, 5.0 | yes | toast |
| Firefox desktop | no | **no** (install, where offered at all, is browser UI only) | nothing |
| Firefox Android | no | **no** (menu "Add to Home screen" / "Install" only) | nothing |
| Safari macOS (17+) | no | **no** (File › Add to Dock, manual) | nothing |
| Safari iOS / iPadOS, and every iOS browser (all WebKit) | no | **no** (Share › Add to Home Screen, manual) | nothing |
| Android WebView / in-app browsers | listed as supported, but hosts rarely install | rarely | toast only if the host fires the event |

Sources: MDN browser-compat-data `api/BeforeInstallPromptEvent.json` (experimental, not on a standards track;
Firefox and Safari "not supported"); Chrome's "Revisiting Chrome's installability criteria".

**Web Install API** (`navigator.install()`, and the declarative `<install>` element): not shipped by default in any
stable browser as of this date. Chromium DevTrial from 139, desktop origin trial in Chrome and Edge 143–148
(extended through 153); the `<install>` element has its own origin trial in 148–153. The blink-dev Intent to Ship
(September 2026) targets desktop M156; Android comes later and Android WebView is not planned. Safari and Firefox
have not announced it. Decision: **not used now**: it needs an origin-trial token, and every browser that has it also
fires `beforeinstallprompt`, so it adds no reach. Revisit when a non-Chromium engine ships it; the bridge's
`status()` / `prompt()` contract can then gain a second source without touching the Dart side.

**Plainly: one-click install is impossible today on Safari (iOS and macOS) and Firefox (desktop and Android).**
There the game shows nothing at all, as the operator asked.

## 2. Installability criteria and what the project had

Chromium (the only family that prompts):
- HTTPS (or localhost). Production is `https://demonattack.tlatoani.net`; the preview is HTTPS on :18443. ✔
- A linked manifest with `name` or `short_name`, `start_url`, `display` standalone / fullscreen / minimal-ui /
  window-controls-overlay, icons of 192 px and 512 px, `prefer_related_applications` not true. `web/manifest.json`
  already had all of it, plus `id`, maskable and monochrome icons, `theme_color` and `background_color`. ✔
- A service worker: since Chrome 108 (Android) / 112 (desktop) the menu install no longer needs one, but Chrome's
  prompt heuristics still look for a worker with a fetch handler. The project had **none that works**: Flutter
  3.47's `flutter_service_worker.js` (registered by the default bootstrap) is a deprecated cleanup worker that
  unregisters itself on activation. ✘ → fixed here (§3).
- Engagement: Chromium fires `beforeinstallprompt` only after the user has interacted with the page and is not
  already installed. That suits a non-intrusive toast: it cannot appear on a cold first paint.

Already present: `web/icons/Icon-192/512.png` (any), maskable 192/512, monochrome 512, `apple-touch-icon.png`, the
`apple-mobile-web-app-*` metas (iOS home-screen look for players who add it by hand). The landing page is the
`RunMode.title` screen in `lib/main.dart` (`_titleScreen`).

## 3. Decisions

**JS bridge, Flutter toast.** `beforeinstallprompt` can fire before Flutter has booted, so a plain script
(`web/install_bridge.js`, before `flutter_bootstrap.js`) captures it, calls `preventDefault()` (no browser
mini-infobar: our toast is the one offer) and keeps the event. Dart reads it through `dart:js_interop`
(`lib/services/install_prompt_web.dart`, same pattern as `tilt_control_web.dart`); the bridge calls a Dart listener
on every change, so no polling. The toast is a Flutter widget rather than an HTML overlay so it lives inside the
title page's layout (never over Start, gone the moment a run begins) and matches the radio toast styling exactly.

**Service worker.** `web/sw.js` is cache-free: `install` → `skipWaiting`, `activate` → `clients.claim`, and a fetch
handler that only takes GET navigations, network-first, with an inline "NO SIGNAL · RECONNECT TO PLAY" page on
failure. Assets, audio and `/api/*` go straight to the browser. A cache-first worker would make deploys stale, which
the operator's playtest loop cannot afford.

**Custom `web/flutter_bootstrap.js`.** `{{flutter_js}}`, `{{flutter_build_config}}`, `_flutter.loader.load()` with no
`serviceWorkerSettings`. Flutter's cleanup worker shares the root scope; registering it would replace `/sw.js` and
then unregister the registration. The gallery build (same `web/`) loses it too, which is harmless.

**Policy.** Show iff the bridge holds a deferred event, the page is not standalone / installed, and the viewer has not
dismissed within 90 days. ✕ and "Cancel" in the browser dialog both store `demonAttack.installDismissedAt`
(epoch ms) in localStorage through `RunStorage.store`; reads and writes are wrapped in try/catch, and the value is
read once per page view (the title rebuilds every frame). A timestamp more than 90 days in the future is ignored.
Accepting is not a dismissal (`appinstalled` and standalone keep it hidden anyway). After one `prompt()` the event
is spent; the toast stays hidden until the next page view.

**Look.** Rounded 8 px card, the radio toast gradient (`#E6121D2E → #D90A1220`), `#6694A3B8` border, soft shadow, mint
accent bar on the left; one line `PLAY IT AS AN APP`, a mint `INSTALL` text button and a muted `✕` (40 px targets),
max 360 px wide, under 56 px tall, centred 64 px above the bottom of the title page. The landing scroll gains bottom
room while it shows so it never covers content.

## 4. Risks
- `beforeinstallprompt` is non-standard and Chromium may change its heuristics; the toast then simply does not show.
- A Chromium user who already dismissed our toast can still install from the omnibox/menu; we do not nag.
- Removing Flutter's worker registration: any old self-unregistering registration on players' devices already removed
  itself, and `/sw.js` takes the root scope cleanly.

## 5. Verification
See tasks 4.x; browser results are recorded below.

### Results (2026-11-15)
- `flutter analyze`: no issues. `flutter test`: 732 passed, 4 skipped, none failed (16 new in
  `test/install_toast_test.dart`). `npm run test:worker`: 48 passed (8 new in `test-worker/pwa-install.test.mjs`).
- `npm run build`: `build/web` carries `manifest.json`, the icons, `install_bridge.js`, `sw.js` and the custom
  `flutter_bootstrap.js` (no service worker settings; Flutter's `flutter_service_worker.js` is still emitted but no
  longer registered).
- Host Chromium 156 (desktop and Galaxy S24 emulation) on `https://www.demon-attack.localhost:18443` with service
  workers kept: `/sw.js` registered and controlling the page at scope `/`; CDP `Page.getAppManifest` parses the
  manifest with no errors; `Page.getInstallabilityErrors` reports only `in-incognito`, i.e. every site criterion
  passes and the one blocker is the host's ephemeral (incognito) test profile, in which Chromium never installs or
  fires `beforeinstallprompt`. `navigator.install` is undefined in that build (Web Install API not on by default).
- The toast was therefore shown by dispatching a synthetic `beforeinstallprompt` with a stub `prompt()`: the bridge
  deferred it (`defaultPrevented`), the toast appeared, one click on INSTALL called `prompt()` exactly once, and the
  stub's "dismissed" stored `demonAttack.installDismissedAt`. Nothing was installed on the host.
