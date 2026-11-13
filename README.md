# Demon Attack

An original pixel arcade remake inspired by Imagic's 1982 Demon Attack and its expanded conversions. Flutter and Flame power a finite campaign of five carrier victories, with four multi-wave sectors before each boss, named destinations, layered parallax worlds, and fleet recognition cutscenes.

Drag the bottom controller panel or use **← →** to pilot. Firing is automatic. Press **P / Esc** to pause. Sound starts after a user gesture and can be muted. Collect and combine spread, rapid-fire, and shield powers; each has its own nine-second timer. Cannon glyphs, a rapid-fire bolt, a shield, and countdowns show the active combination without moving the controller guidance. Between waves, keep piloting to collect falling powers; each sector ends with a protected salvage window.

Normal starts with three lives. Three game overs before any boss victory unlock Easy: five starting lives, 10% slower hostile movement and attacks, 20% less boss health, smaller flocks, and 25% fewer enemy points. A Normal boss victory unlocks Hard and Easy; Hard has three starting lives, larger flocks and 5% faster hostile activity. Later routes grow through one bounded campaign curve. Reinforcements and dedicated escorts share their parent wave’s health rules, with small whole-wave elite budgets. After the first boss, scarce segmented-wing sentinels descend slowly above the swarm, with heavier armored variants deeper in the campaign. Pixel warning poses precede their fast dives. Some badly wounded sentinels make a one-way last-stand rush: move after their climbing tell to dodge the committed attack. Player movement and firing remain equally responsive in every mode.

Each boss awards a difficulty-specific medal and +1UP. Easy and Normal also drop rare left/right/top heart pieces (1.2% and 0.8% per kill): assemble all three complementary parts to gain a life. Three unfinished hearts can store duplicates; a fourth copy of a part is ignored until a slot clears. Each slot displays its collected-piece count; completing one flashes the assembled heart and +1UP. Hard earns extra lives only from bosses. The fifth medal ends the campaign. Time counts active combat only.

**Resume Game** restarts the saved wave without powerups. A compact browser-local checkpoint is saved at wave and boss entrances; leaving partway through a wave replays that wave's starting score, lives, and accumulated time. Older snapshots receive defaults for missing optional fields. Unlock history is stored separately and survives new runs; clearing browser storage removes local progress.

Top10 scores load on the landing page through a Cloudflare SQLite Durable Object. Each unlocked difficulty has its own board. Enter three rotating A–Z/0–9 initials. Rows display five medal positions, active time, and score; five-medal finishers also show their remaining lives. Existing scores stay on Normal with unknown time. Scores are client-reported arcade scores, not a cheat-proof competition.

## Development

```sh
npm ci
npm run dev
```

Wrangler runs the pinned Flutter web build and serves the app, MIDI synth, assets and `/api/scores` together. `flutter run -d web-server` is useful for the Dart UI alone, but does not serve the Worker API or copy the browser audio bridge.

The managed local preview is https://www.demon-attack.localhost:18443/. After Dart edits rebuild with `npm run build`; reload the preview runtime after Worker bindings or Wrangler config changes. Assets are watched. Local Durable Object scores are separate from production and reset when the managed sibling container is replaced.

### /console

`/console` (served by the SPA fallback) opens a start console: pick difficulty, run 1–5 and sector 1–5 and launch, or jump straight to the run's carrier (**BOSS**) or the first sentinel wave (**SENTINEL**, at least run 2). Runs start fresh at 0 points through `ArcadeModel.startAt` (earlier runs count as won, so medals = run − 1) and use normal scoring and the normal top-10 entry. Launching moves the address bar to `/`; browser back or **BACK TO CONSOLE** on the title returns to the console. The console also links the art gallery (`lib/gallery_main.dart`), which `scripts/build-web.sh` builds into `build/web/gallery` and serves at `/gallery/`. Code: `lib/widgets/dev_console.dart`, `// --- console route` sections in `lib/main.dart`.

### Asset review studio and notes

**ASSET REVIEW** on `/console` opens `/gallery/?page=studio` (`lib/review/`). It plays the sector flyovers live, every atlas animation frame by frame (speed, step, loop/ping-pong/once), the staged gallery scenes, the radio bank (filter by speaker, human/demon, emotion and event, with lip-sync and subtitles) and the music cues and stems (loop the whole cue, the seam, a bar range or a stem slot). Each item has a notes panel: quick tags (regenerate, refine, needs-growl, flat-emotion, uncompressed-sound, clipping, too-loud, too-quiet, timing, keep, …), free text and the playhead time. Notes record the asset reference, source file, content hash and build commit. Deep link: `?page=studio&tab=radio&item=<clip id>`.

Notes are saved in the browser at once. **Export** downloads them as JSON (`demon-attack.notes/v1`); **Sync** sends them to the operator-only `/api/notes` (`worker/notes.mjs`, its own `REVIEW_NOTES` SQLite Durable Object, never the score board). The API needs a secret: `wrangler secret put NOTES_TOKEN` in production, `NOTES_TOKEN=...` in `.dev.vars` locally; enter the same value under the key icon in the studio. Without the secret the API answers 503.

`tools/review_notes.lua` turns notes into a markdown worklist grouped by tag:

```sh
lua tools/review_notes.lua demon-attack-notes-2026-11-13T101500.json > worklist.md
lua tools/review_notes.lua --tag needs-growl --kind radio notes.json
curl -sH "authorization: Bearer $NOTES_TOKEN" https://demonattack.tlatoani.net/api/notes | lua tools/review_notes.lua -
```

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

Difficulty formulas, primary gameplay research, 318-wave before/after audits and protected-pilot measurements are recorded in [difficulty calibration](plan/difficulty-calibration.md). Run `dart run tools/analyze_difficulty.dart /tmp/difficulty-audit` and `dart run tools/profile_difficulty.dart /tmp/difficulty-pilot.json` to reproduce the current measurements.
