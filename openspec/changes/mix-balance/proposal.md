# Mix balance: the radio above the music

## Why
Operator round 5, M1 (`plan/operator-feedback-2026-11-17.md`): "the current soundtrack is way too loud, I had to use
half music volume to be able to hear the radio chatter at full volume, and it was still a little louder." Metered end
to end, the score at the default levels sat 6–8 LU over the radio and drove the master limiter. The operator loves
the score itself, so only the mix changes.

## What Changes
- The music level table moves: Full is -20 dB (was +6 dB), Low stays 10 dB under Full, Mute is silent. Speech
  levels, the master and the effects are unchanged.
- **Speech ducks the music again**, on its own gain stage: 4 dB under a squad line, 2 dB under a brood (demon) growl
  or a stinger shorter than 1 s, with a 30 ms attack, a 250 ms hold and a 150 ms release time constant on the audio
  clock. This replaces comms-pacing's "music volume is constant" rule for speech; effects and the life loss still
  never dip the music.
- Stored Mute/Low/Full choices keep their names and storage keys; a player with nothing stored starts at Full.
- `tools/mix_meter/`: an offline Web Audio renderer that plays the shipped players and meters them (BS.1770), so the
  mix can be measured again.

## Retune (operator follow-up, 2026-11-17)
The operator found -20 dB far too quiet ("even at half radio it was louder than music"). Full moves to -14 dB,
the loudest gameplay 2.5 LU under the radio; per-section trims hold calm sections within 2 LU of it; the duck
softens to 3 dB (1.5 dB for growls and stingers). Design §5.

## Impact
- `web/audio/demon-audio.js` (level table, duck stage), `web/audio/comms-audio.js` (duck calls).
- Tests: `test-worker/mix-balance.test.mjs` (new), `audio-levels`, `comms-audio`.
- Specs: arcade-presentation (comms-pacing's requirement renamed and rewritten), squad-comms (Voice playback).
- Archive after `comms-pacing` and `squad-comms`, whose requirements this one modifies.
