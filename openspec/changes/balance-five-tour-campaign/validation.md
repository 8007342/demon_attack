# Validation

- `flutter analyze`: no issues.
- `flutter test`: 67 tests passed, including checkpoint compatibility/atomic rejection, persistent unlocks, heart assembly/overflow, mode roster order, reward replay safety, score retry, responsive captions and controller-label stability.
- `npm run test:worker`: 8 tests passed, including populated legacy SQLite migration, independent mode pruning, bounded metadata/body validation and audio behavior.
- `npm run build`: release web build and Wasm dry run succeeded.
- `openspec validate balance-five-tour-campaign --strict`: valid.
- `git diff --check`: clean.

## Sustained campaign simulation

A deterministic protected pilot uses actual movement, automatic projectiles, collision detection, shield damage and hatch timing to finish all five routes in every difficulty. It does not call direct enemy/boss damage helpers. Each run produces 111 entrance checkpoints (106 ordinary waves plus five bosses), five medal/life rewards and one completion. Peak hostile bullets were 18/24/27 for Easy/Normal/Hard, below the 120 cap, with at most one large threat. Active combat lasted approximately 1905/2407/2482 seconds. Protection guarantees coverage; these checks do not establish a human player's survival difficulty.

## Browser verification

The managed local Wrangler preview serves the release assets and SQLite-backed score API. `tools/browser-smoke.cjs` passed on desktop and phone Chromium: inline Top10 GET, title, keyboard start/movement, pause/resume, controller drag, MIDI requests, and no runtime/console errors.

`tools/campaign-browser-smoke.cjs` uses isolated browser contexts and mocked score rows (no submissions). Desktop, phone and landscape checks cover unlocked mode actions/tabs, five medals, accumulated time, finisher lives, compatible future-field checkpoints, saved-difficulty resume, inventory preservation and reload persistence. Screenshots are written under `/tmp/campaign-{scores,resume}-*.png`; widget render tests additionally cover boss shield/hull damage, medals, parallax and 320px/landscape captions.

The host visible-browser launcher repeatedly failed its HTTPS navigation with `ERR_CONNECTION_CLOSED`, despite the managed service reporting healthy. Browser checks therefore used local headless Chromium against the same managed Wrangler runtime. The managed preview remains running; no production deployment or main merge was performed. A rebuild replaces assets, so reload the managed runtime after building to avoid Wrangler watch races.
