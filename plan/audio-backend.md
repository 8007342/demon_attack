# Audio and global Top10

Implemented in `web/audio/`, `worker/index.mjs`, and `test-worker/`.

## Music direction

Original suspenseful chiptune compositions honor arcade tension without copying the original soundtrack. All tracks share a 120 BPM grid so musical cues can change on a four-beat boundary while their release tails overlap. The synthesizer schedules MIDI notes ahead on the Web Audio clock. It uses square lead, saw bass, sine pads, and short pitched percussion; no network audio service or soundfont is needed.

`generate-midi.py` creates actual Standard MIDI Format 0 assets with tempo, note-on, note-off, and end-of-track events. Four level cues increase note density; four boss phases introduce stronger chromatic tension and increasingly rapid figures. Each boss phase has an evolved loop variant for subsequent runs. Victory changes to a major arpeggio and sustained chord; game over descends chromatically. Victory plays a finite triumphant opening and repeats its final four-beat major cadence until the next level cue, avoiding silence if the transition scene lasts longer than the MIDI opening. Game over remains finite. The fourth boss phase adds the fastest chromatic arpeggios, with another density increase for evolved runs. Menu music is quiet and spacious.

The implementation is a custom MIDI event synthesizer because no MIDI SYNTHESIZER connector is available in the session. These portable `.mid` files can also be played by external MIDI software. Browser audio starts after an actual pointer/key gesture; mute has a short gain ramp; pausing freezes the audio clock. Backgrounding pauses playback.

Integration: load `audio/demon-audio.js` before Flutter bootstrap, then call `window.demonAudio.cue(mode, level, phase, cycle)` for `menu`, `level`, `boss`, `victory`, or `gameover`. Other methods: `unlock()`, `mute(boolean)`, `pause()`, `resume()`, `sfx(name)`. SFX names: `shot`, `explosion`, `hit`, `powerup`, `life`. Native platforms need a separate audio adapter; this first implementation targets the deployed web app.

## Global leaderboard

One SQLite-backed Cloudflare Durable Object owns the worldwide table. `GET /api/scores` returns `{scores:[{rank,initials,score}]}`. `POST /api/scores` accepts only JSON `{initials:"ABC",score:123}` and returns the resulting Top10. It keeps exactly ten rows, orders by descending score, and favors earlier submissions on ties. The submitted initials must match `[A-Z0-9]{3}`; score must be an integer from 0 through 999999999. Requests are streamed with a 256-byte cap, unknown fields are rejected, and cross-origin browser writes are rejected. Responses are uncached. No account, name, IP address, timestamp, or tracking ID is stored in the score database. Cloudflare infrastructure logging remains governed by deployment configuration.

Scores are client reported. Input validation prevents malformed data but does not prove that a game was played or defeat cheating; a determined caller can forge a legal numeric score. Before competitive use, add server-issued run tickets, event/replay validation, and suitable request throttling. The current scope is an arcade honor board rather than a verified tournament service.

Wrangler uses `HIGH_SCORES`, class `HighScores`, with migration `v1` / `new_sqlite_classes`. Assets remain served through `ASSETS` and `/api/*` runs the Worker first. Cloudflare docs: [SQLite storage API](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/) and [Durable Object migrations](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/).

## Validation

`npm run test:worker` runs four tests: score bounds/initials/body shape, persistent Top10 eviction and tie order using real SQLite, HTTP routing/origin checks, and MIDI scheduling/gesture unlock/mute/pause/resume with an instrumented audio clock. `node --check web/audio/demon-audio.js` validates syntax. Actual listening and game-state timing remain part of browser playtesting.

A real local Wrangler runtime smoke test also passed: GET, valid POST, invalid initials rejected, SQLite-backed persistence, and MIDI asset served. `wrangler deploy --dry-run --no-bundle` passed with the full Flutter build and both bindings. No remote deployment was performed.
