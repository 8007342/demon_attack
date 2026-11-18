# Tasks: demon-choir

## 1. Research
- [x] 1.1 `plan/demon-choir-research.md`: ACE-Step 1.5, Dia, VocalSet, VSCO 2 CE and VCSL, grunt packs (272 Merry
      Orks, NCSOFT), choirs (epic-choir, legato_vocal_tutorial, out: VPO/Sonatina, Philharmonia), formant synthesis;
      sources per §8 of CLAUDE.md, unread claims in `plan/provenance-audit.md` Part DC
- [x] 1.2 The verdict: best now (formant choir + ACE-Step shouts), best once admitted (epic-choir, Merry Orks, Dia)

## 2. Sources
- [x] 2.1 `tools/brood_choir/brood.lua` (Lua): the formant-synth ensemble (render), the ACE-Step cuts (cut), the
      manifest (manifest); recipe `art/music/choir/brood.json`
- [x] 2.2 ACE-Step pilot in the studio (3 jobs, 6 takes, no download, no consent ask); raws in the cache; picks and
      measurements in `plan/render-runs/demon-choir.md`
- [x] 2.3 Determinism: a second render reproduces every synth zone's git blob sha1

## 3. The bank
- [x] 3.1 `tools/bank`: a recipe `name` (JSON name, sprite prefix, own sprites replaced) and `src`; `bank.json`
      unchanged
- [x] 3.2 `art/music/bank/choir-recipe.json`: brood (strict pitch), grunt, warcry; levels by solo loudness
- [x] 3.3 Build `web/audio/bank/choir.json`, `choir-3dm.ogg`, `choir-4dm.ogg` (380,958 B Opus, 7.68 MB decoded)
- [x] 3.4 `tools/midi_stats.lua check` joins the choir; its roles are `cover: full`

## 4. The score
- [x] 4.1 Tracks `brood`, `grunts`, `cries`; masks; `A.drones`, `A.grunts`
- [x] 4.2 `c1:core` (root drones, oh then ah) and `k:B` (drones, downbeat grunts); every gate at or under 32 voices
- [x] 4.3 The `warcry` stinger (an 8th, spacing 8, `speech: yield`) and accent; `score_gen.lua`, `song_map.dart`
- [x] 4.4 `mix-trim.json` regenerated in both modes (`trim.mjs`; `--check` reproduces it)

## 5. Runtime
- [x] 5.1 `demon-score.js`: `choir.json` beside `bank.json` (desktops), `joinBanks`, sampled-only roles, the voice
      bus, the speech yield; `demon-audio.js` passes `speaking()`
- [x] 5.2 `MusicBridge`: `diveCry` → `warcry` (stub name until `fang-and-wings-comms` lands)
- [x] 5.3 Tests: `music.test.mjs` (plan, gate, off, on, cry on an 8th in key, rate limit, radio yield),
      `score.test.mjs` (player size), `audio_toggles_test.dart`
- [x] 5.4 `tools/mix_meter/page.mjs` decodes the choir's sprites

## 6. Listening and gates
- [x] 6.1 Listening page (private artifact): the choir solo, grunt hits, war cries over a battle section, the full
      mix with and without the choir
- [x] 6.2 §2 gates; commit; push `work/demon-choir`

## 7. Follow-ups (open)
- [ ] 7.1 The operator's verdict on the listening page (open questions, design §10)
- [x] 7.2 Merge `origin/work/fang-and-wings-comms` once pushed; align `MusicBridge.diveCryEvent` with its §API
      (round 8, `work/round8`: `GameEventNames.diveCry`; the grunt lands at `now + diveIn` snapped to the stinger's 8th
      within 0.3 s, else at `tellIn`: `demonAudio.accent(name, inSeconds, fallbackIn)`, design §6.1)
- [x] 7.3 Re-check the choir's sprites against `bank-fidelity` §12.11 once pushed (round 8: rebuilt, design §4.1)
- [ ] 7.4 Phone tier for the choir, more sections, and the register (epic-choir, 272 Merry Orks)

## 8. Real samples (`work/choir-real`, design §11)
- [x] 8.1 `tools/brood_choir/pins.lua`: fetch and verify the pins (git blobs by size and sha1; the epic-choir zip by
      sha256 before extraction, each member by CRC32); the zip stays in `~/.cache/tillandsias-project/choir-src/`
- [x] 8.2 `brood.lua cut`: picks from pinned sources with a tape-style `shift`; `manifest`: `sources` used as they are
- [x] 8.3 `bank_build.lua`: `dc: true` (opt-in; `bank.json` and the approved `choir.json` rebuild byte for byte)
- [x] 8.4 Measure and pick: brood mono sum at 160 kbps, declip and DC, A#2 stretched to E2 (against two formant zones);
      Orks grunts −7 with a 0.7 s trim; ACE-Step war cries kept (against the Orks growls); levels matched
- [x] 8.5 Recipe `art/music/choir/real.json`, `art/music/bank/choir-real-recipe.json`, `choir-real.manifest.tsv`
- [x] 8.6 Credits: the two choir rows go live when `choir.json` names their source; `assets/credits.json` regenerated
- [x] 8.7 A/B listening page (approved, real, hybrid): https://claude.ai/artifact/BRp5LaDJBJYiiQAG7ioU35
- [x] 8.8 Verdict: real recommended, not active (brood codec SNR 0.5 dB under the approved); score, `midi_stats`, trims
      unchanged; §2 gates
- [ ] 8.9 The operator's listen: ship the real candidate (design §11.6 commands) or keep the approved choir
