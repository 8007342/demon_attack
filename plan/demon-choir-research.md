# Demon choir: research (2026-11-18)

The question (operator, verbatim): "see if we can find a music model agents that could consider those grunts and war
cryes as part of the music :) remember that our Epic/Doom metal had some wordless chorus, how about some wordless demon
grunts :D ?! That would be an epic addition to our musical score."

What can produce **wordless demon vocals as musical material** for the MIDI-first score
(`openspec/changes/adaptive-soundtrack` §11-§12):
- rhythmic grunts ("HUH!", "HA!", "HRAA!");
- a low wordless choir ("ohh", "ahh", doom style) as sustained pitched notes, cut into sampler zones (vowel × pitch);
- growled war cries.

Licence rule: CC0 or CC-BY for samples, MIT or Apache-2.0 for code and models. The change that acts on this is
`openspec/changes/demon-choir`; the pilot's run ledger is `plan/render-runs/demon-choir.md`.

**Reach of the forge on 2026-11-18.** zenodo.org, the ISMIR archives, Wikipedia, arXiv, freesound.org,
opengameart.org and kenney.nl reset the connection (curl and WebFetch). GitHub, raw.githubusercontent.com and
huggingface.co answered. So every source marked "read" below is one of those three. Nothing was routed around the
proxy. No audio sample or model weight was downloaded: only licence files, readmes, SFZ maps, and one 130 KB CSV of
vowel measurements (§7).

## Verdict

| | Best now (nothing new downloaded) | Best once more is admitted |
|---|---|---|
| Doom choir ("ohh", "ahh") | **Our own formant synthesis** (`tools/brood_choir`): pitch-exact zones at any root, deterministic, licence-free. Piloted: 12 zones, every one within 0.14 semitone of its root. | **`thepok/epic-choir` B part** (CC BY 4.0, real male bass voices from VocalSet, ah/oh × p/mf/f, A2-F4). It needs a pin, the register's admission, and VocalSet's licence confirmed on Zenodo from outside the forge (§6a). |
| Grunts, war cries | **ACE-Step 1.5 XL turbo** (MIT, installed in the studio): shouted lyrics ("Huh! Ha! Hraaa!") in an a cappella prompt. Piloted: 8 grunt cuts and 3 war cries in one take pair. | **Karoryfer 272 Merry Orks** (CC0 death-metal growls: `argh`, `ugh`, `hey`, growled vowels; §5a), then **Dia 1.6B** `(groans)`, `(screams)` with a cloned demon voice once the voice stack is admitted (§2). |
| Wordless choir *from a model* | ACE-Step was tried and is **not** usable for zones: its "a cappella" takes still carry a drone or pad, and it sings chords, not single sustained notes (§1, pilot). | ACE-Step's base-model `extract` task (`vocals`, `backing_vocals`) could isolate a sung line from a generated mix (§1). Not tried: the studio's workflow set has no extract graph yet. |

So the pilot ships the **formant choir** for the drones and **ACE-Step cuts** for the grunts and war cries
(`openspec/changes/demon-choir` design §2). Both are behind the bank switch, off by default.

## 1. ACE-Step 1.5 (installed in the studio; cleared for music pilots)

- **Licence: MIT.** `ace-step/ACE-Step-1.5` at `ca1e85fe9430179831e6bc6be790c332190a3866`, `LICENSE` sha256
  `05a6bce42a62636d2cfb24139cc008b6b899754e244175814bb5dd2f4a485357`, beginning "MIT License / Copyright (c) 2026
  ACEStep". The Hugging Face card says `license: mit` and "You can strictly use the generated music for commercial
  purposes". `plan/licences-round-2.md` already records ACE-Step as MIT.
  [source: ACE-Step, "ACE-Step-1.5 LICENSE", https://github.com/ace-step/ACE-Step-1.5/blob/ca1e85fe9430179831e6bc6be790c332190a3866/LICENSE, read 2026-11-18];
  [source: ACE-Step, "Ace-Step1.5 model card", https://huggingface.co/ACE-Step/Ace-Step1.5, read 2026-11-18]
- **Vocals in the docs.**
  - The caption vocabulary has "male vocal, breathy, powerful, falsetto, raspy, choir".
  - Lyrics can carry style hints such as "[raspy vocal]". "Uppercase indicates stronger vocal intensity … (high
    intensity, shouting)". `[Instrumental]` means no vocals.
  - **The docs never mention wordless singing, vocalise, humming, a cappella or grunts.** Wordless output has to be
    coaxed from syllables in the lyrics.
  - The base model has `extract` and `lego` tasks, whose track list includes `vocals` and `backing_vocals`.
  [source: ACE-Step, "Tutorial.md", https://github.com/ace-step/ACE-Step-1.5/blob/ca1e85fe9430179831e6bc6be790c332190a3866/docs/en/Tutorial.md, read 2026-11-18];
  [source: ACE-Step, "INFERENCE.md", https://github.com/ace-step/ACE-Step-1.5/blob/ca1e85fe9430179831e6bc6be790c332190a3866/docs/en/INFERENCE.md, read 2026-11-18];
  [source: ACE-Step, "ace_step_musicians_guide.md", https://github.com/ace-step/ACE-Step-1.5/blob/ca1e85fe9430179831e6bc6be790c332190a3866/docs/en/ace_step_musicians_guide.md, read 2026-11-18];
  [source: Gong et al., "ACE-Step 1.5: Pushing the Boundaries of Open-Source Music Generation", https://huggingface.co/papers/2602.00744, read 2026-11-18]
- **ComfyUI core node.** `TextEncodeAceStepAudio1.5` takes `tags`, `lyrics`, `seed`, `bpm`, `duration`,
  `timesignature`, `language`, `keyscale` and the LM settings. A separate `ReferenceTimbreAudio` node sets a timbre
  reference. **Pitch control stops at key, scale and BPM**: there is no note-level pitch or timing.
  [source: Comfy-Org, "comfy_extras/nodes_ace.py", https://github.com/Comfy-Org/ComfyUI/blob/fce1f53e3573379b8e3ab83e374d309cd25ecbd0/comfy_extras/nodes_ace.py, read 2026-11-18]
- **What the pilot measured** (6 takes, ledger §2). These are our own measurements:
  - **Quality:** the grunt takes have real shouted transients, 18-20 dB over a low drone that the model adds anyway.
    The take was asked in F minor, and the shouts and cries land on its notes: cuts measure C3 (131 Hz), F3 (174 Hz) and
    A3 (220 Hz).
  - **Choir:** the "a cappella male choir" takes are chords under a sub-bass drone, not single sustained notes, so
    zones cannot be cut from them.
  - **Controllability:** key and tempo only. Every cut's onset and pitch had to be found by measurement.
  - **Licence:** MIT; the outputs are ours.
  - **Admitted:** yes. It runs on the studio's pinned models, about 4-10 s of GPU per 20-30 s take, and needed no
    download.
  - **Size:** 1.2-2.4 MB of FLAC per take, kept in the cache and not committed. The 11 cuts encode to about 60 KB of
    Opus.

## 2. Dia 1.6B-0626 (non-verbals; **not admitted**)

- **Pin:** `nari-labs/dia` at `876125e461a03b157ec905b0fe8b57a0f8b9e7a0` (Apache-2.0). Weights
  `nari-labs/Dia-1.6B-0626` at `ef2795fcc29c5abe6ffc91fd33808588b49bbc66`, tagged apache-2.0, 6.44 GB in safetensors
  (`plan/model-pins-voice.md`).
- **Non-verbal tags, verbatim:** "(laughs), (clears throat), (sighs), (gasps), (coughs), (singing), (sings), (mumbles),
  (beep), (groans), (sniffs), (claps), (screams), (inhales), (exhales), (applause), (burps), (humming), (sneezes),
  (chuckle), (whistles)". The README warns that they "might result in unexpected output".
- **Assessment:**
  - Quality: unknown, since nothing was rendered.
  - Controllability: timing comes from the script; there is no pitch control, and pitch would be set afterwards by the
    sampler's zone root.
  - Use: `(groans)`, `(screams)`, `(humming)` and `(inhales)` with a cloned demon voice are the best route to
    character-specific grunts.
- **Status:** blocked with the rest of the voice stack on the Tillandsias register and #1121
  (`plan/handoff-2026-11-17.md`).
- [source: Nari Labs, "dia README.md", https://github.com/nari-labs/dia/blob/876125e461a03b157ec905b0fe8b57a0f8b9e7a0/README.md, read 2026-11-18]
- VoxCPM2, Fish S2-Pro and Higgs v2 were not examined for non-verbals. They are speech models, and the same block
  applies.

## 3. VocalSet (Wilkins, Seetharaman, Wahl, Pardo, ISMIR 2018)

- **Contents:** 20 professional singers (11 male, 9 female), 17 techniques including vocal fry, all five vowels; about
  8 GB. [source: Zenodo, "VocalSet: A Singing Voice Dataset", https://zenodo.org/records/1442513, unread: snippet only]
- **Licence: CC BY 4.0, per a Hugging Face mirror only.** The mirror's card says `license: cc-by-4.0` and "Mirror of
  https://zenodo.org/records/1442513". Its technique labels include `vocal_fry`. It carries no singer, vowel or pitch
  columns, so it is no use for cutting zones.
  [source: Bill13579, "vocalset-mirror README", https://huggingface.co/datasets/Bill13579/vocalset-mirror, read 2026-11-18]
- **Admitted:** no. Zenodo is unreachable from the forge, so its licence must be confirmed from outside before
  anything built on it is pinned.

## 4. VSCO 2 CE and VCSL (already pinned for the bank)

Neither library has any voice. A recursive tree search at the pins for Choir, Vocal, Voice, Vox, Aah, Ooh, Human,
Chant, Shout, Grunt, Sing, Throat, Mouth and Breath found nothing in VSCO 2 CE, and only whistles and sirens in VCSL.
[source: sgossner, "VSCO-2-CE git tree", https://api.github.com/repos/sgossner/VSCO-2-CE/git/trees/28092772094b2d9f1148d84cea97f4545b8c687d?recursive=1, read 2026-11-18];
[source: sgossner, "VCSL git tree", https://api.github.com/repos/sgossner/VCSL/git/trees/c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e?recursive=1, read 2026-11-18]

## 5. Grunts and war cries

### 5a. Karoryfer 272 Merry Orks (CC0): the best sample source for growls

- **Pin:** `sfzinstruments/karoryfer.272-merry-orks` at `a437e2c02014e02710a104a6692193eab8672d0a`. `LICENSE` is the
  CC0 1.0 legal code, sha256 `a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499`, the same text as the
  admitted Karoryfer repos.
- **Readme, verbatim:** "272 Merry Orks is a sample library of female death metal vocals… one for monster voice sound
  design… Royalty-free for all commercial and non-commercial use."
- **Quality:** mono 44.1 kHz 24-bit (read from one WAV header), 3 round robins. `misc/` holds `argh`, `ugh`, `hey`,
  `oh`, `ay`, `ey`, `go`, `oi`. `vowels/` holds growled `a_from_car`, `o_from_pot`, `oo_from_too` and others, which
  `ork_vocals.sfz` maps to keys.
- **Controllability:** the growls are unpitched; the sampler's root sets the pitch. The voice is female, so for male
  demons it would be pitched down and layered.
- **Size:** 277 files, 45.6 MB in total. A subset of 21 `misc` grunts plus the 36 growled vowels is about 9.4 MB raw.
- **Admitted:** no. It needs a pin row per file and the register's admission, like the bank's round 2.
- [source: Karoryfer Samples/sfzinstruments, "272 Merry Orks readme.txt, LICENSE, ork_vocals.sfz, git tree", https://github.com/sfzinstruments/karoryfer.272-merry-orks/tree/a437e2c02014e02710a104a6692193eab8672d0a, read 2026-11-18];
  [source: sfzinstruments, "data/sfz/instruments.yml", https://github.com/sfzinstruments/sfzinstruments.github.io/blob/cde59004c9812bd5797973241bc7858c8f6bded5/data/sfz/instruments.yml, read 2026-11-18]

### 5b. NCSOFT Designed Vocalizations Dataset (CC BY 4.0, mixed per clip)

- **Pin:** `NCSOFT/Designed-Vocalizations-Dataset` at `e66abedc34038f89ada0a28621203a945da8e740`.
- **Licences:** CC BY 4.0 for the compilation. The NOTICE says each clip's source licence still applies. Per-clip
  counts in `raw/train`: CC0 1,488, CC BY 4.0 3,901, CC BY 3.0 265.
- **Contents:** among others, `monster_mimic` 321 and `interjection` 1,364 clips. 44.1 kHz 16-bit mono.
- **Size:** about 0.9 GB for `raw` and 36 GB for `designed`. Too heavy for a pilot. Optional: the CC0 subset of
  `monster_mimic` and `interjection`, each kept with its attribution.
- [source: NC AI, "Designed Vocalizations Dataset README/NOTICE/LICENSE.md", https://huggingface.co/datasets/NCSOFT/Designed-Vocalizations-Dataset, read 2026-11-18];
  [source: Lee et al., "Designed Vocalizations Dataset…", https://huggingface.co/papers/2607.20951, read 2026-11-18]

### 5c. Ruled out

- **Kenney voice-over ports:** spoken words only (`war_go_go_go.ogg`, …), not wordless. One port is CC0
  (`Boyquotes/kenney-voiceover-fighter-for-godot` at `08f93f0697459505e83f351f0e532115ca0550da`); the other is GPL-3.0.
  kenney.nl itself is unreachable.
- **Freesound and OpenGameArt:** unreachable, so no CC0 kiai or battle-cry one-shot could be pinned.

## 6. Multisampled choirs and sustained vowels

### 6a. thepok/epic-choir (CC BY 4.0): the best real low male choir

- **Pin:** `thepok/epic-choir` at `38df98f5dbb170da6d8e3ea2d52c7170d2a2b8e3`. `LICENSE` (sha256
  `89d6c6c8e6d919152ca115fce46c180b7e843dd04d0722602e7bd7986dc18ec6`): "Creative Commons Attribution 4.0
  International (CC BY 4.0) … a derived work of VocalSet … released under the same licence".
- **Required credit, verbatim:** "Choir samples derived from VocalSet (Wilkins, Seetharaman, Wahl, Pardo 2018), CC BY
  4.0, https://doi.org/10.5281/zenodo.1442513 — epic-choir by thepok".
- **Quality:** S, A, T and B parts; vowels ah, oh, oo, ee, eh; three dynamics. The **B part uses the 10 male VocalSet
  singers**, A2-F4, with 3-10 real singers summed per sample. "No consonants or words: wordless vowels only."
- **Controllability:** one sample per whole tone, so it is pitch-exact within a tone and maps straight onto zones.
- **Size:** release asset `epic-choir-v1.0-B.zip`, 173,859,746 B, sha256
  `3f78e9b59018dc2ef45bb30d1b57cb68f22768d15e1f1c1a4f93d0b5e4b3002f`. An ah/oh subset is about 60 WAVs.
- **Caution:** a single-author repo created 2026-10-24, whose licence chain rests on VocalSet's CC BY 4.0 (§3).
- [source: thepok, "epic-choir README.md/LICENSE/ATTRIBUTION.txt/SOURCE.json/B_ah.sfz", https://github.com/thepok/epic-choir/tree/38df98f5dbb170da6d8e3ea2d52c7170d2a2b8e3, read 2026-11-18];
  [source: GitHub API, "thepok/epic-choir releases", https://api.github.com/repos/thepok/epic-choir/releases, read 2026-11-18]

### 6b. sfzinstruments/legato_vocal_tutorial (CC0): a deep male solo "ah"

- **Pin:** at `fac6461ee4c7f498b23246eced644616fa58d2ec`, with the same CC0 `LICENSE` sha256 (`a2010f34…0499`). The
  readme: "It's the a vowel from the Hadzi-Fia sample library by Karoryfer Samples". The full Hadzi-Fia library is
  commercial; only this subset is CC0.
- **Contents:** 23 sustains, chromatic C3-Bb4, stereo 44.1 kHz 24-bit, 38.0 MB.
- **Use:** one voice, so a choir needs stacking and detuning. This makes it a candidate for an "ah" layer.
- [source: sfzinstruments, "legato_vocal_tutorial readme.txt/LICENSE/tree", https://github.com/sfzinstruments/legato_vocal_tutorial/tree/fac6461ee4c7f498b23246eced644616fa58d2ec, read 2026-11-18]

### 6c. Out or unverified

- **Virtual Playing Orchestra 3, male choir:** its SFZ says it is "from Sonatina Symphonic Orchestra", which is Creative
  Commons Sampling Plus 1.0, so **OUT**. `peastman/sso` at `32bbdb169aef636b8216029a2e056424ba7c2abb` confirms that
  licence, so Sonatina is OUT too.
  [source: open-soundfonts, "Virtual_Playing_Orchestra_3 Documentation/license.htm", https://github.com/open-soundfonts/Virtual_Playing_Orchestra_3/tree/b0afa0f570e0e33c83da9bc4e626a4a239714dff, read 2026-11-18];
  [source: peastman, "sso LICENSE", https://github.com/peastman/sso/tree/32bbdb169aef636b8216029a2e056424ba7c2abb, read 2026-11-18]
- **Philharmonia:** CC BY-SA 3.0 per VPO's licence page, and it has no voices: OUT.
- **NicolaDiSalvatore/florestan-ahh-choir-soundfont:** the card says only `cc0-1.0`, with no provenance. Not admitted.
- **University of Iowa MIS:** unreachable, so unverified.

## 7. Formant synthesis from scratch (what the pilot built)

- **The synthesizer design.** A cascade/parallel formant synthesizer driven by a glottal source with flutter, an
  open-phase ratio, breathiness and spectral tilt is the Klatt design. `chdh/klatt-syn` (MIT) implements it after
  Klatt (1980) and Klatt & Klatt (1990), with `impulsive`, `natural` (KLGLOTT88) and `noise` sources. It has **no
  diplophonia or period-doubling** parameter.
  [source: Christian d'Heureuse, "klatt-syn README.md and src/Klatt.ts", https://github.com/chdh/klatt-syn/tree/3a1eddd519fec2bea7c5e47237c7047786a23abc, read 2026-11-18].
  The Klatt papers themselves were not read.
- **Vowel formants.** The pilot uses male means of Hillenbrand et al. (1995), computed from a GitHub copy of the data
  (`julian3rd/hillenbrand-vowel-clustering` at `9654782c16a1fd781e3db104c704912d47c8e552`,
  `data/hillenbrand-vowel-formatted.csv`, sha256 `cf916c4ecc37724938d729c869db6e97d74069b616d63dbc90e5da50f609cefa`,
  rows with zeros excluded, n ≈ 45 per vowel). This is a secondary copy: the WMU original was not read.

  | Vowel | F0 | F1 | F2 | F3 | Used for |
  |---|---:|---:|---:|---:|---|
  | /ɑ/ (`ah`) | 127 | 756 | 1309 | 2535 | the "ah" zones |
  | /o/ (`oa`) | 130 | 498 | 910 | 2459 | the "oh" zones |
  | /ɔ/ (`aw`) | 125 | 656 | 1023 | 2521 | |
  | /u/ (`uw`) | 144 | 380 | 992 | 2355 | |
  | /ʌ/ (`uh`) | 129 | 621 | 1181 | 2548 | |

  [source: julian3rd, "hillenbrand-vowel-clustering data/hillenbrand-vowel-formatted.csv", https://github.com/julian3rd/hillenbrand-vowel-clustering/blob/9654782c16a1fd781e3db104c704912d47c8e552/data/hillenbrand-vowel-formatted.csv, read 2026-11-18]
- **Glottal source.** The pilot uses a Rosenberg pulse (raised-cosine opening, cosine closing). Its harmonic slope was
  measured on the rendered source: about −15 dB at 2 kHz relative to 100 Hz (ledger §1). The LF model would be the
  next step. `mvsoom/lf-model` (no licence, so reference only) quotes "Typical values for male vowels are Fa = 700 Hz,
  Rk = 0.30, Rg = 1.20".
  [source: mvsoom, "lf-model README.md", https://github.com/mvsoom/lf-model/blob/425985b70c9ec71b96aa9a223c558c1f6d622068/README.md, read 2026-11-18].
  Rosenberg (1971) and Fant, Liljencrants & Lin (1985) were not read.
  [UNSOURCED: plan/provenance-audit.md#dc-rosenberg-pulse]
- **The demon colour: period doubling.** Alternate glottal periods run 2-4.5 % long or short, and the odd ones are
  18-32 % quieter. This puts energy at f0/2, a growl under the sung note, which is our model of false-fold growl or
  kargyraa. No primary source on growl phonation was reachable. The nearest source read describes the growl and scream
  classes in metal but gives no synthesis recipe.
  [source: Kalbag & Lerch, "Scream Detection in Heavy Metal Music", https://huggingface.co/papers/2205.05580, read 2026-11-18].
  [UNSOURCED: plan/provenance-audit.md#dc-growl-period-doubling]
- **The choral ensemble.** Each zone is 8 voices with ±14 cents of detune, independent 4.4-5.6 Hz vibrato of 10-22
  cents, slow jitter and onsets spread over 50 ms. These numbers are our judgement: Ternström's choir measurements were
  unreachable. The Emulated-Inc SATB F0 dataset (CC BY 4.0) would let us measure real pitch scatter ourselves.
  [source: Emulated Inc, "satb-choir-voice-f0 README", https://huggingface.co/datasets/Emulated-Inc/satb-choir-voice-f0, read 2026-11-18].
  [UNSOURCED: plan/provenance-audit.md#dc-choir-scatter]
- **Assessment** (our measurements, ledger §1):
  - Quality: a dark, synthetic ensemble. The spectrum falls about 45 dB from the F1-F2 region to F3, so it is darker
    than a trained singer; a first-order shelf above 1.5 kHz (up to +12 dB) partly restores it. It is unproven by ear; the operator's
    listening decides.
  - Controllability: exact pitch at any root (12 zones, all within 0.14 semitone), any vowel in the table, any length,
    and byte-identical renders.
  - Licence: ours.
  - Size: 0.7 s of CPU per zone in Lua. The 12 zones encode to about 320 KB of Opus.

## 8. Open items for the operator

1. Confirm VocalSet's licence on Zenodo from outside the forge. epic-choir (§6a) depends on it.
2. Admit `karoryfer.272-merry-orks` and/or `epic-choir`'s B part to the register? Both would replace pilot material
   zone for zone: the recipe already has the vowel × pitch and syllable × round-robin axes.
3. Whether the forge proxy should allow zenodo.org, freesound.org and opengameart.org for research reads.
