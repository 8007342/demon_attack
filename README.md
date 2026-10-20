# Demon Attack

An original pixel arcade remake inspired by Imagic's 1982 Demon Attack and its expanded conversions. Flutter and Flame power four multi-wave swarm levels, animated victory/travel cutscenes, a shielded carrier with a sliding core door, and increasingly evolved repeat runs.

Drag the bottom controller panel or use **← →** to pilot. Firing is automatic. LV1–2 have three waves each; LV3–4 have four. Clear a sector for a victory flourish, ship departure, star-flight and destination arrival before combat resumes. Start with three lives; one unprotected hit costs one life. Collect spread, rapid-fire, and shield powers. Press **P / Esc** to pause. Sound starts after a user gesture and can be muted.

Top10 scores are shared through a Cloudflare SQLite Durable Object. Enter only three rotating A–Z/0–9 initials. Scores are client-reported arcade scores, not a cheat-proof competition.

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

## Project layout

- `lib/game/model.dart`: deterministic combat and progression.
- `lib/game/scene.dart`: Flame rendering, sprite animation and celestial parallax.
- `lib/main.dart`: responsive cabinet, touch/keyboard controls and score wheels.
- `worker/index.mjs`: same-origin API and persistent Top10.
- `web/audio/`: original MIDI cues, generator and browser synthesizer.
- `assets/images/`: original sprite atlas and generated cosmic artwork.
- `openspec/changes/build-demon-attack-game/`: current behavior requirements and tracked implementation.
- `plan/`: original-game research, game tuning, visual/music guides and validation evidence.

Regenerate sprite pixels with `python3 tools/generate_sprites.py`; regenerate MIDI with `python3 web/audio/generate-midi.py`.

## Deployment

Production: https://demonattack.tlatoani.net. Work and push checkpoints on **game**. Pushes to **main** auto-deploy; merge only after stable playtesting.

```sh
npm run deploy:check
```

This builds and validates without publishing. Production uses Worker Static Assets, the `ASSETS` binding, and the `HIGH_SCORES` SQLite Durable Object with migration `v1`. The Cloudflare account needs the active custom-domain zone. Node.js22+, npm, Bash and Git are required; the build obtains the pinned Flutter SDK automatically if necessary. Credentials stay outside source control.
