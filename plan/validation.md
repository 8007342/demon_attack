# Playable checkpoint validation — 2026-10-20

Branch: `game`. No production deployment or main merge performed.

## Automated checks

- `flutter analyze`: no issues.
- `flutter test`: 17 passing tests. Covers lives, respawn grace, power expiry, movement bounds, fixed-step stability, armor/anger, all four waves, boss shield/door gating, actual final-shot collision and evolved restart, phone/desktop layouts, Enter/P input, visible star rendering, score serialization and errors, and three-wheel initials with failed-submit retry preserving B9A / 12345.
- `npm run test:worker`: 4 passing tests. Real SQLite Top10 ordering/eviction and ties; strict initials, body and score bounds; API routing and origin validation; MIDI gesture unlock, scheduling, cue transitions, mute, pause/resume, fourth boss intensity and victory cadence continuation.
- `npm run build`: release web build succeeds, including local renderer, original sprite atlas/sky, synth JavaScript and fifteen MIDI assets.
- `openspec validate --all --strict`: main specs and active change pass.
- Wrangler deployment dry run passes; recognizes HIGH_SCORES SQLite Durable Object and ASSETS bindings. No remote deployment.

## Browser and managed preview

`tools/browser-smoke.cjs` ran against the actual sibling Wrangler service on desktop1280×900 and phone390×844. Enter starts without a mouse fallback. Arrows, pointer/touch drag and P pause/resume work. Title emblem, player, demon wingbeats, explosion effects, stars, planetary layers and controller panel render correctly. MIDI requests return200. No console errors or browser runtime exceptions.

Screenshots were captured at `/tmp/demon-title.png`, `/tmp/demon-play.png` and the corresponding `-phone.png` files. These temporary captures are review evidence, not shipped assets.

Managed API smoke accepted TST / 0, returned it in subsequent GETs, and rejected malformed initials. The managed service was then recreated to refresh the final preview. Its ephemeral local SQLite state resets when that sibling container is replaced; a fresh board was observed after recreation. Production uses Cloudflare Durable Object storage, not this ephemeral local container. A local container replacement is different from ordinary score requests or a production Worker update.

The host-browser tool still fails HTTPS navigation with ERR_CONNECTION_CLOSED on this host. Standalone Playwright Chromium reached the sibling directly and provided the browser validation above. The user's existing host browser can use https://www.demon-attack.localhost:18443/.

## Playtest focus

Review touch sensitivity, projectile readability, wave pacing, boss door timing, and perceived music intensity on the actual device. Music generation and scheduling are tested; human listening remains the final check for musical taste and mix. Client-submitted scores are a casual honor board and remain forgeable. Native sound needs a separate adapter; the deployed web game has the MIDI synthesizer.


## Multiwave and cinematic update

The smooth-level-progression checkpoint passes flutter analyze, all21 Flutter tests, all4 backend/audio tests, strict OpenSpec validation, and a new release web build. A dedicated renderer test loads the shipping pixel atlas and sky, confirms different victory/travel frames, checks exact pixel equality during pause, and checks that departure-to-travel and travel-to-arrival black-fade boundaries match. Review images are in .cache/cinematics/ (ignored by Git).

The model tests traverse all14 waves before the carrier (3/3/4/4), verify same-level pickup preservation, protected cutscene power timers, 72 shield hits and24 gated core hits, 5.5-second carrier triumph, 4-second sector celebrations, 4-second travel, and retained score/lives on the next cycle. Immediate level-clear, continuing victory cadence, travel and next-level MIDI handoffs pass audio scheduler tests. The soundtrack now contains17 original MIDI files.

The rebuilt game was republished to the managed sibling Wrangler runtime at the usual HTTPS preview URL. Standalone Chromium verifies phone and desktop Enter start, arrows, controller drag, pause/resume, synthesizer presence and successful MIDI loading against the actual sibling service. The visible host Chromium tool continues to report ERR_CONNECTION_CLOSED; browser availability is reported separately from the running service.
