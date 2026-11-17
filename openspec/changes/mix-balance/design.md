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

## 2. Target

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
