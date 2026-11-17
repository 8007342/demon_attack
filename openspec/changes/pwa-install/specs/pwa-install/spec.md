# pwa-install

## ADDED Requirements

### Requirement: One-click install toast on the landing page
The title (landing) page SHALL show an install toast ONLY while the browser has fired `beforeinstallprompt` and
the game holds that deferred event, so that one click on its `INSTALL` button calls the event's `prompt()` and opens
the browser's own install approval directly. It SHALL NOT appear during a run, pause, score or ending screen.

#### Scenario: Chromium browser offers install
- **WHEN** Chrome, Edge, Opera or Samsung Internet fires `beforeinstallprompt` while the title page is up
- **THEN** the toast appears at the bottom of the title page and `INSTALL` opens the browser's install dialog with one click

#### Scenario: Run starts
- **WHEN** the player starts a run with the toast showing
- **THEN** the toast is gone for the whole run

### Requirement: Small, non-intrusive toast
The install toast SHALL carry exactly one action button (`INSTALL`) and a close control (`✕`), SHALL be styled like
the game's radio toasts, SHALL fit one line no wider than 360 px, and SHALL NOT cover the Start button.

#### Scenario: Phone landing page
- **WHEN** the toast shows on a 360 × 640 screen
- **THEN** it is one short line with INSTALL and ✕, and Start stays fully tappable

### Requirement: Nothing where one click is impossible
On browsers that offer no API opening their install approval from a page click (Safari on iOS and macOS, Firefox
desktop and Android), the game SHALL show no install toast, no install instructions and no links to instructions.

#### Scenario: iPhone Safari
- **WHEN** the landing page opens in Safari on iOS
- **THEN** no install toast, hint or link is shown

### Requirement: Installed apps are not asked
The toast SHALL NOT show when the game runs as an installed app (`display-mode` standalone, fullscreen, minimal-ui or
window-controls-overlay, or iOS `navigator.standalone`) and SHALL hide when the browser fires `appinstalled`.

#### Scenario: Launched from the home screen
- **WHEN** the game opens as an installed app
- **THEN** no install toast appears

#### Scenario: Install accepted
- **WHEN** the player accepts the browser's install dialog
- **THEN** the toast hides and is not remembered as a dismissal

### Requirement: Dismissal is remembered per viewer
Closing the toast, or declining the browser's install dialog, SHALL hide it and SHALL be remembered in this viewer's
localStorage so that the toast does not ask again for 90 days. Every storage access SHALL tolerate a store that throws
(private mode, blocked site data); then the dismissal holds for the page view only.

#### Scenario: Return visit after closing
- **WHEN** a viewer closed the toast and returns within 90 days
- **THEN** the toast does not appear even if the browser offers install again

### Requirement: Installable build
The web build SHALL emit a manifest with `id`, `name`, `short_name`, `start_url`, `display: standalone`, 192 px and
512 px `any`-purpose PNG icons (plus maskable icons), `prefer_related_applications` not true, and SHALL register a
root-scope service worker with a fetch handler. The service worker SHALL NOT cache the build: every deploy SHALL be
live on the next load. Flutter's own deprecated, self-unregistering service worker SHALL NOT be registered.

#### Scenario: Chromium installability check
- **WHEN** the built game is served over HTTPS and opened in Chromium
- **THEN** the page reports no installability errors and fires `beforeinstallprompt`

#### Scenario: Offline navigation
- **WHEN** the installed app is opened without a network
- **THEN** the worker answers with a short "NO SIGNAL · RECONNECT TO PLAY" page instead of a browser error
