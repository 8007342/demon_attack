# Demon Attack

An original pixel arcade remake inspired by Imagic's 1982 Demon Attack and its expanded conversions. Flutter and Flame power a finite campaign of five carrier victories, with four multi-wave sectors before each boss, named destinations, layered parallax worlds, and fleet recognition cutscenes.

Drag the bottom controller panel or use **← →** to pilot. Firing is automatic. Press **P / Esc** to pause. Sound starts after a user gesture and can be muted. Collect and combine spread, rapid-fire, and shield powers; each has its own nine-second timer. Cannon glyphs, a rapid-fire bolt, a shield, and countdowns show the active combination without moving the controller guidance. Between waves, keep piloting to collect falling powers; each sector ends with a protected salvage window.

Normal starts with three lives. Three game overs before any boss victory unlock Easy: five starting lives, 10% slower hostile movement and attacks, 20% less boss health, smaller flocks, and 25% fewer enemy points. A Normal boss victory unlocks Hard, with three starting lives and larger flocks. Later routes add more enemies, with stronger growth in Normal and Hard. Scarce shielded line-wing sentinels, followed by heavier armored variants, join late waves. Player movement and firing remain equally responsive in every mode.

Each boss awards a difficulty-specific medal and +1UP. Easy and Normal also drop rare left/right/top heart pieces: assemble all three complementary parts to gain a life. Three unfinished hearts can store duplicates; a fourth copy of a part is ignored until a slot clears. Hard earns extra lives only from bosses. The fifth medal ends the campaign. Time counts active combat only.

**Resume Game** restarts the saved wave without powerups. A compact browser-local checkpoint is saved at wave and boss entrances; leaving partway through a wave replays that wave's starting score, lives, and accumulated time. Older snapshots receive defaults for missing optional fields. Unlock history is stored separately and survives new runs; clearing browser storage removes local progress.

Top10 scores load on the landing page through a Cloudflare SQLite Durable Object. Each unlocked difficulty has its own board. Enter three rotating A–Z/0–9 initials. Rows display five medal positions, active time, and score; five-medal finishers also show their remaining lives. Existing scores stay on Normal with unknown time. Scores are client-reported arcade scores, not a cheat-proof competition.

## Development

```sh
npm ci
npm run dev
```

Wrangler runs the pinned Flutter web build and serves the app, MIDI synth, assets and `/api/scores` together. `flutter run -d web-server` is useful for the Dart UI alone, but does not serve the Worker API or copy the browser audio bridge.

The managed local preview is https://www.demon-attack.localhost:18443/. After Dart edits rebuild with `npm run build`; reload the preview runtime after Worker bindings or Wrangler config changes. Assets are watched. Local Durable Object scores are separate from production and reset when the managed sibling container is replaced.

## Validation

```sh
flutter analyze
flutter test
npm run test:worker
npm run build
openspec validate --all --strict
```

`tools/browser-smoke.cjs` drives a standalone Playwright Chromium against `URL` (default `http://127.0.0.1:8765`) and captures phone/desktop screenshots. Install Playwright's Chromium separately; it is a developer tool, not a runtime dependency.
`tools/campaign-browser-smoke.cjs` additionally checks unlocked boards, achievement rows, compatible saved-wave resume and reload on desktop, phone and landscape. It uses isolated local state and mocked score rows, and accepts the same `URL` and `PLAYWRIGHT_MODULE` settings.

## Project layout

- `lib/game/model.dart`: deterministic combat and progression.
- `lib/game/difficulty.dart`: lives, hostile pacing, roster, scoring, and heart-drop policies.
- `lib/services/run_storage.dart`: compatible local checkpoints and permanent unlock history.
- `lib/game/scene.dart`: Flame rendering, sprite animation and celestial parallax.
- `lib/main.dart`: responsive cabinet, touch/keyboard controls and score wheels.
- `worker/index.mjs`: same-origin API and independent persistent difficulty Top10s.
- `web/audio/`: original MIDI cues, generator and browser synthesizer.
- `assets/images/`: original sprite atlas and generated cosmic artwork.
- `openspec/changes/`: tracked requirements and implementation, including `balance-five-tour-campaign`.
- `plan/`: original-game research, game tuning, visual/music guides and validation evidence.

Regenerate sprite pixels with `python3 tools/generate_sprites.py`; regenerate MIDI with `python3 web/audio/generate-midi.py`.

## Deployment

Production: https://demonattack.tlatoani.net. Work and push checkpoints on **game**. Pushes to **main** auto-deploy; merge only after stable playtesting.

```sh
npm run deploy:check
```

This builds and validates without publishing. Production uses Worker Static Assets, the `ASSETS` binding, and the `HIGH_SCORES` SQLite Durable Object with migration `v1`. The Cloudflare account needs the active custom-domain zone. Node.js22+, npm, Bash and Git are required; the build obtains the pinned Flutter SDK automatically if necessary. Credentials stay outside source control.
