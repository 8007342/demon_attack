# Proposal: demon-choir (the brood choir: wordless demon voices as part of the score)

## Why
The operator, 2026-11-18, verbatim: "see if we can find a music model agents that could consider those grunts and war
cryes as part of the music :) remember that our Epic/Doom metal had some wordless chorus, how about some wordless demon
grunts :D ?! That would be an epic addition to our musical score."

The score (`adaptive-soundtrack` §11-§12) is MIDI played by synth voices, with a CC0 sample bank behind a switch. Its
only voice is a synth "choir" pad. The brood's war cries are radio lines, outside the music.

## What Changes
- **Research** (`plan/demon-choir-research.md`): what can make wordless demon vocals today (ACE-Step 1.5, our own
  formant synthesis) and once more is admitted (epic-choir, 272 Merry Orks, Dia's non-verbals), with sources.
- **The brood choir bank**: a second bank beside `bank.json`, `web/audio/bank/choir.json` with its own sprites, built
  by the same builder (`tools/bank/bank_build.lua --recipe art/music/bank/choir-recipe.json`). It has three roles:
  - `brood`: doom-choir drones, vowel × pitch zones (oh/ah × six roots);
  - `grunt`: one-shot shouts, syllable × round robin;
  - `warcry`: long war cries.
- **Sources**: `tools/brood_choir/brood.lua` renders the formant-synth choir (deterministic) and cuts the picked
  ACE-Step takes. The recipe is `art/music/choir/brood.json`.
- **The score**: new sampled-only tracks `brood`, `grunts` and `cries`. The pilot writes the carrier core (`c1:core`:
  root drones, oh then ah) and one world battle section (Krybor `B`: drones and downbeat grunts) into the masks.
- **War cries as music**: the structured event `diveCry` plays the `warcry` stinger. It lands on the next 8th of the
  section's grid, pitched to its tonic, through the music bus. It waits 8 beats between cries and yields while a
  radio line speaks. `diveCry` is a stub name until `fang-and-wings-comms` lands.
- **Off by default**: everything rides the bank switch. With the bank off nothing new is fetched, scheduled or heard,
  and the synth score is note for note as before.

## Impact
- Code:
  - `web/audio/demon-score.js` (the second bank, sampled-only roles, the voice bus, the stinger's speech yield),
    `web/audio/demon-audio.js` (`speaking()`), `lib/game/music_director.dart` (`diveCry`);
  - `tools/bank/` (a recipe `name` and `src`), `tools/midi_stats.lua` (the choir's coverage),
    `tools/mix_meter/page.mjs` (decodes the choir sprites);
  - the score: `tools/score/` (tracks, `A.drones`, `A.grunts`), `art/music/soundtrack/song-map.json` (tracks, masks,
    the `warcry` stinger and accent).
- Generated: `web/audio/score/` (c1/core, k/B, score.json), `lib/game/song_map.dart`,
  `web/audio/score/mix-trim.json` (the bank block), `web/audio/bank/choir*`, `art/music/bank/choir.manifest.tsv`.
- Size: +381 KB of Opus and +7.7 MB decoded, on desktops only and only with the bank on.
- Specs: `soundtrack` (added: brood choir bank, sampled-only voices, war cries as music).
