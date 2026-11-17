# Proposal: adaptive soundtrack (one run, one long song)

## Why
The operator, 2026-11-16/17 (`plan/operator-feedback-2026-11-16.md`):
- "one whole run of the game should feel like one smooth play of a long song with a game to match ;) and it's all
  about the boss fights";
- the carrier needs "doom and epic-metal undertones over the battle-metal score";
- "Don't just re-render, remember we're redesigning": research the tools and make the pipelines carry the design.

The music shipped today is a set of separate cues: per level an intro, four tier loops (different takes of one
style), an outro, and accents (`plan/audio-backend.md`). The carrier fight plays the level-5 tiers plus re-used
accents; its new structure (approach, hatch tiers, transformation, core, collapse, carrier-hatches §A8) has events
but no music of its own. The operator rejected the last generated bank as thin and low-fidelity
(`plan/audio-studio/music-requirements.md` §1). Music was blocked on tillandsias#1103; the coordinator cleared a
pilot with ComfyUI's core ACE-Step nodes on 2026-11-17.

Research with sources: `plan/soundtrack-research.md`.

**Revision, 2026-11-17 (MIDI first).** The operator: "let's keep MIDI as the fallback, but try to make it so it
becomes our first layer instead", and "No fallback format, this project is already asset heavy, no need to
duplicate assets." Research: `plan/midi-first-research.md`. The score becomes the adaptive backbone. Rendered audio
becomes optional texture holding only parts the score does not play (design §11).

## What Changes
- **MIDI first** (design §11): committed multitrack scores per section, played by an in-browser sampler from one
  curated CC0 bank (Opus, ≤ 2 MB), with intensity as track masks on one arrangement. Rendered ACE-Step sections
  narrow to optional texture beds (choir, air, risers, the worldized ending) that never duplicate a score part. The
  oscillator synth plays the same score where the bank cannot. The whole run is about 2.2 MB plus beds, against
  about 18 MB rendered. Production waits on a listening bake-off.
- **A song map for the whole run** (`art/music/soundtrack/song-map.json`, design §3): an overture, five movements
  (routes), each four sector songs and a carrier song, bridges between them, and a coda that hands over to the
  ending's ukulele. Keys and tempos stay per world; bridges pivot between them.
- **The boss fight as a section graph** (design §4): approach → hatch tiers → transformation bridge → core →
  collapse → victory, driven by the carrier's structured events, every move on the carrier's own bar line.
- **A hybrid engine** (design §5): horizontal re-sequencing between whole-bar sections by a transition table,
  same-position switches between intensity variants, and a thin layer set (stingers, dive and power layers, later
  sampled beds). A pure-Dart `SongDirector` turns game events into section requests; `demon-audio.js` schedules them
  sample-accurately and bounds decoded memory.
- **A pipeline that conveys the design** (design §6): the song map drives generation (core ACE-Step nodes through
  `studio.run_workflow` overrides), automatic checks (`tools/soundtrack_check`, Go: tempo, key, air, loudness,
  seams, clicks), picks logged in `plan/render-runs/`, and packaging (bar-exact cuts, −19 LUFS, Opus 160 kbps,
  manifest v5).
- **The pilot** (design §8): the tour-1 carrier's seven sections end to end with core nodes, a listening and
  transition page, and the picks ledger `plan/render-runs/soundtrack-pilot.md`.
- What waits for tillandsias#1103: XL SFT, SFZ stems (true vertical layers, the drum and bass bed, the sampled
  ukulele), and any repaint across seams (design §7).

## Capabilities
- New: `soundtrack` (the song map, the boss section graph, the transition rules, the runtime limits, the pipeline
  gates).
- Modified: `arcade-presentation` ("Adaptive MIDI soundtrack": the MIDI score becomes the first layer, played by a
  sampler; the synthesizer voices play the same score where the bank cannot).

## Impact
- MIDI first: `web/audio/score/` (scores), the bank (`bank.json` + Opus sprites), `tools/midi_stats.lua` (Lua),
  a Lua bank builder and score generator, the sampler in `demon-audio.js`.
- New files: `art/music/soundtrack/` (song map, recipes, pilot encodes), `tools/soundtrack_check/` (Go),
  `tools/soundtrack_pilot.lua`, `plan/render-runs/soundtrack-pilot.md`.
- Later code (tasks 3–5): `lib/game/song_director.dart` (pure Dart), `lib/game/music_director.dart` and
  `MusicBridge` (forward the carrier events), `lib/services/audio.dart` (one new bridge call),
  `web/audio/demon-audio.js` (section graph scheduler, manifest v5), `test-worker/music.test.mjs`.
- The shared events are unchanged; the music reads the structured carrier events that carrier-hatches already
  queues. No gameplay or calibration change.
- Supersedes the tier/cue layout of `battle-metal-radio-rework` for the music only (its radio, credits and PWA media
  requirements stand).
