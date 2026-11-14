# Release: game → main (2026-11-14)

Everything on `game` since the last release merge (`1c3bef7d`, work/comms-v4, 2026-11-10). The operator
playtested this build on 2026-11-14 and approved it ("I approve of all this magnificent progress").

## Player-facing
- **Wave pressure and fog:** the next wave approaches out of the horizon fog before the current one ends
  (Easy 2 / Normal 3 / Hard 4 enemies left) and joins after 10 / 8 / 6 s if the player lingers. The first wave
  keeps its dramatic arrival. Far creatures fade into the haze; shields, armour, halos and HP pips stay hidden
  until a creature comes out of the fog.
- **Radio, middle ground:** livelier squad chatter (paced to roughly a quarter to a third of the time), no line
  cuts another (each finishes plus a grace gap), cards stay up long enough to read, air-cover and ground lines
  match the real ground battle. The full 574-clip radio bank ships (Opus only).
- **Fluid transitions:** one message at a time over a slim progress strip; level transitions alternate a silent
  tip over a screenshot with a full-screen radio interlude; the director hushes for tips.
- **Mobile radio toasts:** framed cards (rounded, bordered, shadowed, speaker accent).
- **Campaign:** the ending plays only after the fifth carrier.
- **Music level is constant:** no ducking under speech.
- **/qr:** a poster page with a QR code to demonattack.tlatoani.net, laid out for portrait and landscape.
- **/console:** start a fresh, unranked run at any sector, route and difficulty (path URL).
- **/studio, /gallery:** asset review studio with notes (API guarded by `NOTES_TOKEN`; new Durable Object
  `ReviewNotes`, migration v2 in `wrangler.jsonc`).

## Under the hood
- OpenSpec changes: wave-pressure, fluid-transitions, comms-middle-ground, comms-pacing, console-runs-final-
  ending, ground-forces-rework (design approved, Phase 0 next), atmosphere-and-swarms (designed, in progress).
- Research: `plan/atmosphere-research.md`; music and voice requirements: `plan/audio-studio/music-requirements.md`.
- Music pilot (not yet audible): L3 Ember Moon 96-bar multitrack score (`art/music/scores/`) and real-instrument
  render workflows for the audio studio (tillandsias#1103).
- Tools: `tools/qr_svg` (Go), `tools/score_l3.py`, `tools/production/l3_pilot_workflow.lua`.

## Gate (run on the release head)
- `flutter analyze`: no issues.
- `flutter test`: 425 passed, 1 skipped.
- `npm run test:worker`: 39 passed.
- `npm run build`: game and gallery built.

## Deploy notes
- `main` auto-deploys to demonattack.tlatoani.net (Cloudflare). The deploy creates the `ReviewNotes` Durable
  Object (migration v2). Set the `NOTES_TOKEN` secret if review notes should sync on production; without it the
  notes API refuses every call and the pages keep notes locally.
