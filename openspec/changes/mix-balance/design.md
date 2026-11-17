# Mix balance: design

## 1. Measurement

`node tools/mix_meter/measure.mjs` loads `demon-score.js`, `demon-audio.js` and `comms-audio.js` into an offline
Web Audio renderer (`tools/mix_meter/offline-audio.mjs`), plays each case for 24 s through the shipped graph (buses,
music level, master 0.65, limiter) and meters the stereo output with BS.1770-4 (`loudness.mjs`, which matched
ffmpeg's `ebur128` to 0.1 LU on the same render). Radio: 48 bank clips (every 12th), decoded by ffmpeg, back to back
through the voice bus. These are **rendered estimates**, not browser captures: the oscillators, per-block biquads,
convolver latency and limiter are approximations (listed in the renderer's header).

Measured 2026-11-17, music and speech levels both Full (the defaults), integrated loudness in LUFS:

| Case | Before (Full = +6 dB) | After (Full = -20 dB) |
|---|---|---|
| Radio, 48 clips | -16.5 | -16.5 |
| Sectors k/r/e/h, section A, tier 1 | -9.1 to -10.3 | -28.5 to -30.8 |
| Sectors, tier 2 | -8.9 to -9.7 | -27.4 to -29.6 |
| Sectors, tier 3–4 | -8.6 to -9.4 | -25.1 to -28.6 |
| Carrier cores c1–c5, tier 4 | -8.7 to -8.8 | -25.0 to -25.2 |
| Menu overture | -10.4 | -32.2 |
| Defeat (cackle) | -8.5 | -29.2 |
| Krybor A tier 1–4 at **Low** (the operator's workaround) | -11.5 to -14.2 | (Full − 10 dB: -37 to -40, computed) |

Before, every music case sat 6–8 LU **over** the radio, and the limiter was cutting the music by several dB (its
pre-limiter level at Full was about -4 LUFS), which also pressed the radio down whenever both played. At Low the music
was still 2–6 LU over the radio (Krybor A tiers 1–4, carrier c1), which matches the operator's report. After, the loudest gameplay
music (carrier cores, sector e at tier 3–4) is 8.3–8.7 LU under the radio, tier 2 is 10.9–13.1 LU under, and music peaks
stay under -9 dBFS, so the limiter rests in normal play. Low is now linear (10 dB under Full) because the limiter no
longer acts on it.

## 2. Target (superseded by §5)

Dialogue-first game mixes keep the music bed well under speech; the task set 8–10 LU under dialogue as common
practice [UNSOURCED: plan/provenance-audit.md#mb-dialogue-gap]. The score is dynamic (tiers differ by about 3 LU), so
the target is set at its loud end: -20 dB puts the loudest gameplay cases at 8.3–8.7 LU under the radio; quieter tiers
sit further down. Speech, effects and master are untouched: the operator found speech at Full right.

## 3. Ducking

Engines duck music under voices with a side-chain, and call it common in game mixing [source: Godot Engine,
"AudioEffectCompressor" class reference,
https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/AudioEffectCompressor.xml, read 2026-11-17]
(its default release is 250 ms, same source). The game knows each line's exact start and length, so the duck is
scheduled rather than detected:

- `demonAudio.duck(key, depthDb, from, until)` from `comms-audio.js` when a clip starts (its first and last sample on
  the audio clock); `demonAudio.unduck(key, at)` when a line is cut.
- The duck stage is the music chain's spare unity gain (`sidechain`, `demonAudio.graph.duck`). The score's track
  gains, masks, moves and stingers never see it, so bar-quantised transitions land on the same times (tested).
- Depth: the deepest sounding line: 4 dB for a squad line, 2 dB for a brood growl or a clip under 1 s
  [UNSOURCED: plan/provenance-audit.md#mb-duck-depth]. With the 8–10 LU base gap, a line sits about 12 LU over the
  loudest music.
- Ramps: `setTargetAtTime` with a 30 ms attack and 150 ms release time constant (about 3 constants to settle
  [source: MDN, "AudioParam: setTargetAtTime() method",
  https://raw.githubusercontent.com/mdn/content/main/files/en-us/web/api/audioparam/settargetattime/index.md, read
  2026-11-17]); a 250 ms hold after the last line keeps back-to-back chatter from pumping.
- `demon-audio.js` keeps its own copy of the scheduled steps, so a change mid-ramp restarts from the exact value
  without reading `AudioParam.value`.

## 4. Stored levels

The stored values (`demonAttack.musicVolume` / `speechVolume`: mute, low, full) and their keys are unchanged, so a
saved choice is read back as saved. Only the gain behind each name moved. A player with nothing stored starts at
Full, the new mix.

## 5. Retune (operator follow-up, 2026-11-17)

The operator played §1–4: "the volume went too far, this time volume went too low, even at half radio it was louder
than music, and I had to crank my speakers much louder." Before mix-balance, at Low (Full −10 dB, so −4 dB absolute)
the music was "a little louder" than the radio, so the level sits between the two. The coordinator's targets: the
loudest gameplay music 2–4 LU under the radio, calm sections within about 2 LU of it, a gentler duck. These are the
operator's rulings, not research; they supersede §2's 8–10 LU.

**Section trims.** At one fixed level the score spreads 9.9 LU: carrier and tier 4 sections are loudest (−24.97 LUFS
at −20 dB), arrival tails, bridges and the coda quietest (−34.8). `tools/mix_meter/trim.mjs` renders every section
untrimmed: tier-masked loops at tiers 1–4, fixed-mask sections once, one pass of their bars (loops 8–16 s), 217
cases. It narrows the spread to 2 LU and keeps the order: L' = max(top − 2, top − (top − L)·k) with k = 2 / (top −
5th percentile) = 0.299, so the louder of two sections stays louder. Each trim (L' − L, at most +8 dB, the loudest
0 dB) goes into `web/audio/score/mix-trim.json`, a generated file: rerun the script after `score_gen.lua` changes the
score; `--check` compares. The file stores each level as if the music level were 0 dB, so it changes only with the
score, not with the Full setting. `demon-score.js` sets the playing section's trim on its own output gain (0.55 × trim) at the
move or mask change, which already lands on a bar or beat line, with a 50 ms glide. The notes, the masks and the
timing are untouched (tested: the same moves with and without trims). Each section keeps its dynamics inside itself;
for example the overture's loudest 3 s still read 2.1 LU over one pass of it.

**Level.** Full = −14 dB (Low −24 dB): the loudest case moves from −24.97 to about −19.0 LUFS, 2.5 LU under the radio's
−16.5, and the trimmed calm sections sit about 4.5 LU under it.

**Duck.** 3 dB under a squad line, 1.5 dB under a growl or a clip under 1 s; timing as §3.

Measured 2026-11-17 with `node tools/mix_meter/measure.mjs` (24 s per case, from 1.5 s), defaults Full/Full, LUFS:

| Case | Radio gap | mix-balance (−20 dB) | mix-retune (−14 dB + trims) |
|---|---|---|---|
| Radio, 48 clips | — | −16.5 | −16.5 |
| Sectors k/r/e/h, A, tier 1 | 3.6–4.2 LU | −28.5 to −30.8 | −20.1 to −20.7 |
| Sectors, tier 2 | 3.2–3.9 LU | −27.4 to −29.6 | −19.7 to −20.4 |
| Sectors, tier 3–4 | 2.5–3.6 LU | −25.1 to −28.6 | −19.0 to −20.1 |
| Carrier cores c1–c5, tier 4 | 2.5 LU | −25.0 to −25.2 | −19.0 |
| Menu overture | 5.5 LU (one pass: 4.2) | −32.2 | −22.0 (one pass −20.7) |
| Defeat (cackle) | 3.7 LU | −29.2 | −20.2 |
| Coda reprise | 4.5 LU | — | −21.0 |

The overture's 24 s window counts its quiet opening twice; one pass of its bars, the unit the trims use, reads
−20.7. One pass of an arrival tail (k) and of the coda ukulele reads −21.0 and −20.9. Music peaks stay at −5.6 dBFS
or lower, under the limiter's −1.5 dBFS.
