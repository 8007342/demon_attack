# Design: voice-direction

Research and sources: `plan/audio-voices-research.md` (cited as "research §n"). Engine choice, licences, the
emotion list, cues, tone list, identities, loudness and tiers are in change `voice-stack` and are not repeated here.
This change adds what one label per line cannot carry: swings, banter, and brood that emote.

## 1. Frame

- Engines run as admitted ComfyUI studio capabilities on the host's 24 GB RTX A5000 (voice-stack design §1). Nothing
  is admitted yet; this design is ready for the day they are.
- Default stack: VoxCPM2 for speech, Dia 1.6B for non-verbals (Apache-2.0, no condition on the audio). Challengers:
  Fish Audio S2-Pro and Higgs Audio v2, licences signed (PRs #4–#7), credit lines in `assets/credits.json`.
- Forge side: Lua orchestrates (`tools/production/run.lua`), Rust does DSP (`tools/brood_fx`), Go or Rust wraps the
  speech recogniser (whisper.cpp), `tools/comms_pipeline.py` keeps the radio chain, encode, verify and `dart`.

## 2. Engine roles going into the pilot

| Role | Default | Challenger(s) | Why (research) |
|---|---|---|---|
| Single lines | VoxCPM2 | S2-Pro, Higgs v2 | VoxCPM2's instruction text is the best-documented mood control (§2.1) |
| Beats (swing inside a line) | VoxCPM2, per-beat calls or a ramp instruction | **S2-Pro**, word-level tags | S2-Pro is the only engine that documents an emotion change inside one generation (§2.2, §3) |
| Threads (banter) | VoxCPM2, turn by turn | **Higgs v2**, chunked dialogue with audio context; S2-Pro multi-speaker | Higgs keeps previous turns' audio as context and leads on "contrasting emotions" (§2.3, §4) |
| Vocals (efforts, laughs, screams) | **Dia** reels | S2-Pro tags, Higgs `[laugh]`/`[cheering]` | Dia's 21 documented tags (§2.4, §5.1) |
| Growls, snarls | DSP over efforts + procedural growl | S2-Pro `[growl]`, Higgs `<SE>[Growl]</SE>` (experiments) | No engine documents a growl (§5.1) |

## 3. Schema: `lines.json` v6

All additions optional; a bank without them is byte-identical through `dart`.

### 3.1 Beats

```json
{"speaker": "kestrel", "text": "Frak! They're on my six!", "emotion": "panicked", "intensity": 2,
 "beats": [
   {"text": "Frak!", "emotion": "furious", "intensity": 3},
   {"text": "They're on my six!", "emotion": "panicked", "intensity": 2, "direction": "breathless"}
 ]}
```

- Two to four beats. Their words, joined with single spaces, equal `text` without cues. Cues stay in `text` and in the
  beat that holds them.
- The line's `emotion`/`intensity` equal the last beat's, so the director's mood, face and any reader of the old
  fields see where the line lands.
- A brood beat may carry `voice`: `brood` (default) or `plain` (§5.4).

### 3.2 Threads

```json
"convoyStuck": {
  "threads": [
    {"turns": [
      {"speaker": "kessler", "text": "Son of a glitch, the tracks are spinning! We're stuck!", "emotion": "panicked", "intensity": 3},
      {"speaker": "mensah", "text": "Easy, Bulwark. Rock it. Forward, back, forward.", "emotion": "calm", "intensity": 1, "gap": 0.1},
      {"speaker": "kessler", "text": "Rocking... rocking... [whoop] We're loose! Sweet thrusters!", "emotion": "cheering", "intensity": 3, "gap": -0.2,
       "beats": [{"text": "Rocking... rocking...", "emotion": "exhausted", "intensity": 1},
                 {"text": "We're loose! Sweet thrusters!", "emotion": "cheering", "intensity": 3}]}
    ]}
  ]
}
```

- Two to four turns; each turn is a full human or brood line (brood turns carry `grunt`, `gloss`, `say`).
- `gap`: seconds from the end of the previous turn, −0.6 to 1.5, default 0.15; negative overlaps.
- Clip ids `<trigger>.x<n>.<k>`, appended only, like `.h<n>` and `.d<n>`.
- A trigger may have `lines`, `demon` and `threads`; the director prefers a playable thread with probability
  `threadChance` (trigger field, default 0.5) and falls back to single lines.
- Coverage: the `stats` stage reports, per trigger, the share of possible lineups that can play at least one thread
  (lineup is five fleet and two ground per run, `cast.json`), so writers know when a thread needs the Admiral.

### 3.3 Brood vocal layers

```json
{"speaker": "gorrak", "grunt": "snarl", "gloss": "Again! AGAIN!", "say": "Again! [snarl] AGAIN!",
 "emotion": "furious", "intensity": 3,
 "vocal": {"cue": "snarl", "source": "effort", "mix_db": -3},
 "growl": {"mix_db": -8}}
```

- `say` is the performance; cues inside it are vocals placed in the performance.
- `vocal` (optional): the vocal layer under or around the performance. `source` is `effort` (a Dia or challenger
  effort take, then DSP) or `growl` (procedural only). Default from the `grunt` kind: `roar`, `snarl`, `warcry` → an
  effort `screams`/`groans`; `cackle`, `gloat` → `laughs`; `alarm` → `gasps`; `order`, `rally` → none.
- `growl` (optional): the procedural growl's level; default today's mix.
- A vocal-only line is `"say": "[growl]"` (voice-stack cue-only line).
- The demon side of `cues.json` gains `cheer` and `laugh` (Grunnok cheers, the brood laugh), mapped like the human ones.

### 3.4 Engine recipes: `art/comms/voice-engines.json`

The voice-stack row gains `roles` and a `recipe` per role, the translation of beats, intensity and cues into the
engine's inputs:

```json
{"id": "voxcpm2", "roles": ["single", "beats", "threads"],
 "recipe": {
   "instruction": "{emotion_phrase}{intensity_adverb}{direction}",
   "intensity_adverbs": ["slightly ", "", "very ", "extremely "],
   "cfg_value": [1.8, 2.0, 2.2, 2.4], "inference_timesteps": 16,
   "beats": "per-beat-if-1s-else-ramp", "clone": "controllable",
   "tags": {"laugh": "[laughing]", "sigh": "[sigh]", "gasp": "[Surprise-wa]"}}}
```

```json
{"id": "fish-s2-pro", "roles": ["single", "beats", "threads", "vocals"],
 "recipe": {"beat_tag": "[{emotion_tag}]", "intensity_tags": ["[low voice]", "", "[volume up]", "[shouting]"],
            "temperature": 0.7, "top_p": 0.7, "hot_reference_at": 3, "precision": "bf16|nf4"}}
```

```json
{"id": "higgs-v2", "roles": ["single", "threads"],
 "recipe": {"scene": "Two pilots on a crackling fleet radio in the middle of a dogfight.",
            "chunk_method": "speaker", "buffer": 2, "temperature": 0.7, "tags": {"laugh": "[laugh]", "cheer": "[cheering]"}}}
```

```json
{"id": "dia-1.6b", "roles": ["vocals"],
 "recipe": {"reel_seconds": [8, 15], "max_bang_per_sentence": 1,
            "cfg_scale": 4.0, "temperature": 1.8, "top_p": 0.9, "cfg_filter_top_k": 50,
            "tags": {"laugh": "(laughs)", "chuckle": "(chuckle)", "groan": "(groans)", "gasp": "(gasps)",
                     "scream": "(screams)", "breath": "(inhales)", "exhale": "(exhales)", "cheer": "(applause)"}}}
```

Values are the documented defaults or examples (research §2), not tuned settings; the pilot replaces them.

### 3.5 Hot references (`cast.json`)

Each character's `identity` gains an optional `hot` clip: the same voice, excited and loud, made once by VoxCPM2
voice design or controllable cloning from the neutral identity, picked and committed as
`art/comms/voices/<id>.hot.flac` with its transcript. Engines whose output follows the reference's energy (S2-Pro,
Dia) use it for intensity 3 beats (research §3, finding 2).

## 4. Render routes

### 4.1 Beats

| Engine | Route |
|---|---|
| VoxCPM2 | Each beat of 1 s or more of expected audio is its own call with its own instruction, all from the same identity clip and seed; splice at the pause between beats with a 30–60 ms crossfade. If any beat is shorter, render the whole line once with a ramp instruction ("starts calm, then panicked, ends cheering"). |
| S2-Pro | One call; the beat's tag before its words, the intensity tag after it. |
| Higgs v2 | One call; the arc in the scene prompt ("he starts calm and panics halfway") and in the words. |

The ledger records the route per take, so the pilot compares the splice and the ramp.

### 4.2 Threads

| Engine | Route |
|---|---|
| Higgs v2 | One dialogue job: `[SPEAKER0..n]` turns, one reference per speaker, `chunk_method speaker`, buffer 2; output split at turn boundaries by the recogniser's word timestamps. |
| S2-Pro | Multi-Speaker Split TTS node: one aligned track per speaker. |
| VoxCPM2 | Turn by turn. Turn k gets turn k−1's picked take as continuation context if the admitted node exposes it; otherwise its instruction names the energy it answers ("answering an excited teammate, matching the energy"). |

Each turn becomes its own clip. The engine's own pauses are trimmed; timing comes only from `gap`, so the director
controls overlap and a lineup-skipped thread costs nothing.

### 4.3 Vocal reels

One Dia generation of 8–15 s per character and engine, a short `[S1]` scene with three to six efforts in the
character's identity ("[S1] (groans) Heavy. (groans) Heavier! (screams)"), cut at the efforts using word timestamps,
the words discarded. Three seeds per reel. The cut efforts form a per-character vocal library
(`art/comms/vocals/<id>/<cue>-<n>.flac`), and brood lines draw their `vocal` layer from it, so most brood lines need
no new vocal render.

## 5. Brood vocals

### 5.1 Layers

performance (clean speech of `say`) + vocal (an effort from the library) + growl (procedural) → the character's FX
chain over the performance and the vocal, the growl mixed after → radio chain. Each clean layer is a master.

### 5.2 FX chain: `demon-delivery.json` v2

```json
{"schema": "demon-attack.demon-delivery/v2",
 "characters": {
   "gorrak": {"identity": "gorrak", "seed": 7,
     "chain": [
       {"step": "reverse", "on": "vocal"},
       {"step": "pitch", "semitones": -6},
       {"step": "formant", "semitones": -4},
       {"step": "subharmonic", "level_db": -10},
       {"step": "ringmod", "hz": 55, "wet": 0.2},
       {"step": "drive", "amount": 0.3},
       {"step": "eq", "cut_hz": 250, "cut_db": -3}
     ],
     "growl_mix_db": -8}}}
```

- Steps (closed set): `reverse` (`on`: `vocal`, `all` or `none`), `pitch`, `formant`, `subharmonic`, `ringmod`,
  `drive`, `granular`, `doubler`, `eq`. Research §5.2 has the tools and starting ranges.
- `reverse` defaults to `vocal`: efforts and tails run backwards, words forwards but pitched and formant-shifted, so
  the emotion of the words survives. A character may keep `all` (today's sound) if the pilot prefers it.
- Implemented in `tools/brood_fx` (Rust: `signalsmith-stretch`, `fundsp`, `ebur128`, all MIT). Deterministic for a
  given input, chain and seed. ffmpeg's `rubberband` filter cannot shift formants by an amount (research §5.2).
- v1 fields (`source_voice`, `speed`, `pitch_semitones`, `reverse`) stay readable for the shipped bank until each
  clip is re-rendered.

### 5.3 Character sketches (starting points for the pilot)

| Character | Reveal person | Chain idea | Vocals |
|---|---|---|---|
| Gorrak | owner, booming, kind | deep pitch and formant, ring mod, drive | snarl, roar |
| Vexxa | teenage waitress, sassy | moderate pitch, formant up a little against the pitch (bright, sly), light doubler | cackle |
| Skarn | grill cook | drive high, crackle (granular light) | warcry, roar |
| Grunnok | big brother who cheers | sub layer, doubler | cheer, laugh |
| Skritch | seagull | pitch up, granular chitter | chitter, squawk |
| Krag | the owner's dog | very low, effort only | growl |
| Sliss | the cat | breath-only, hiss shaping | hiss |
| Ulgra, Morth, Nibb | children | as today until a child voice is approved | laughs, groans |

### 5.4 Plain beats and the reveal

- `voice: "plain"` on a beat crossfades from the processed to the clean render of the same take over 80–200 ms at the
  beat boundary (spec "Wet amount may change inside a brood line"). This is how `endgame.e4` growls "A rematch." and
  finishes as himself.
- A plain beat is allowed only in second-run lines (`"set": "second"`, the field `endgame-cinematic` adds) and in the
  ending's own lines. The radio never lets a first-run player hear the person under the brood.
- Brood identities are re-cast to the reveal people (spec "Brood identities survive the reveal"). Children stay
  transformed or subtitled until the operator approves a child voice (endgame design §12, decision 9).

## 6. The pipeline

| # | Step | Where | Output |
|---|---|---|---|
| 1 | Script: `lines.json` v6, tone check, beats and threads validated | forge, `dart` | bank, pending list |
| 2 | Direction: recipe applied per engine, render requests written | forge, Lua | `plan/render-runs/<batch>/requests/*.json` |
| 3 | Takes: studio workflows, one at a time | studio (§7 of research: VoxCPM2, Dia, S2-Pro, Higgs nodes; core `TrimAudioDuration`, `AudioConcat`, `SaveAudioAdvanced`; #1103 save node with provenance) | raw takes in `~/.cache` |
| 4 | Automatic rejection: duration, clipping (≥ −0.5 dBFS), inner silence > 0.8 s, WER < 15 % (whisper.cpp on the clean take), speaker similarity ≥ threshold (ECAPA or WeSpeaker), no words in vocal-only takes | forge CLI | verdict per take |
| 5 | Pre-rank: passing takes ordered by WER, similarity and loudness range; listening page built, engine-blind | forge | `listen/index.html` via `preview.*` |
| 6 | Pick: scores and a one-line reason per clip into the ledger | listener + agent | `ledger.json`, `README.md` |
| 7 | Brood FX on picked brood takes (§5) | forge, `tools/brood_fx` | transformed master |
| 8 | Radio chain, loudness, Opus, verify, `dart` | forge, `comms_pipeline.py` | `web/audio/comms/` |

**Take counts** (spec "Take counts per kind"): four for threads, beat lines, `signature` and priority ≥ 8 lines; three
for other speech; three seeds per vocal reel. One retry round of the same count if every take is rejected.

**Similarity thresholds** are calibrated per engine in the pilot: score every take against its identity, and set the
threshold at the lowest score among takes a listener accepted, minus a margin.

**Ledger** (`plan/render-runs/voice-<batch>/`): `ledger.json` per take (clip id, engine, revision, recipe, route,
seed, input hash, output sha256, duration, loudness, peak, WER, similarity, verdict and reasons), per clip the pick,
reason and scores; `listen-key.json` maps blind codes to takes; `README.md` is the human summary. Same layout as
`plan/render-runs/radio-bank-2026-11-12/` job records.

**Masters** (CLAUDE.md §5 durability): picked takes as FLAC under `art/comms/masters/<batch>/`; for the pilot, each
engine's best take per item also as 96 kbps Opus under `art/comms/masters/pilot/compare/`, so the comparison
survives a reset without tens of megabytes of FLAC on the checkout.

**Promotion:** voice-stack's tiers (`text` → `placeholder` → `candidate` → `final`) are unchanged. A pilot pick is a
`candidate` until the engine decision (§7.4) is recorded; then the pilot's picks promote to `final` with the usual
gates. A VoxCPM2 single take may ship as `placeholder` before the pilot, replacing a borrowed clip.

## 7. The pilot

### 7.1 Twenty lines

| # | Clip | Speaker | Text | Emotion arc (beats) | Tests |
|---|---|---|---|---|---|
| 1 | `sentinelDive.h3` | rook | Incoming! Dodge, dodge, dodge! | panicked 3 | peak without a scream |
| 2 | `defeat.h0` | admiral | All ships totalled, but every pilot is safe. Regroup at base. We go again. | exhausted 1 → warm 2 | low energy, resolve |
| 3 | `levelClear.h2` | rook | [laugh] Ha! Did you see that? Textbook. | triumphant 2 → smug 2 | laugh cue |
| 4 | `allySaved.h7` | kessler | Whew. That was close. Thanks, friend! | relieved 1 → warm 2 | breath, relief |
| 5 | `sectorStart.h4` | pip | Cadet Pip, reporting for awesome! I mean, for duty! | excited 3 → calm 1 (flustered) | quick self-correction |
| 6 | `bossDefeated.h3` | sparrow | [whoop] Carrier down! Woohoo! | cheering 3 | whoop, cheering |
| 7 | `broodTaunt.h0` | admiral | Keep talking. We can play this all afternoon. | stern 1 | dry, understated |
| 8 | new (pending) | kestrel | Frak! They're on my six! | furious 3 → panicked 2 | pseudo-swear, swing |
| 9–11 | thread T1 `convoyStuck` | kessler, mensah, kessler | as §3.2 | panicked 3 / calm 1 / exhausted 1 → cheering 3 | energy hand-off, overlap −0.2 |
| 12–14 | thread T2 `bossDefeated` | sparrow, rook, admiral | "[whoop] Carrier's down! Did you see that?!" / "[laugh] Saw it, heard it, want it on a poster!" (gap −0.3) / "Settle down, squadron. ...Okay. One cheer." | cheering 3 / excited 3 / stern 1 → warm 2 | overlap, laugh, deadpan turn |
| 15–17 | thread T3 `broodTaunt` (demon first) | vexxa, sparrow, vexxa | "Shiny-shell! Your fleet is painted tin!" [cackle] / "Painted tin with a full tank, pixel-pusher. Eat static!" / "[snarl]" | teasing 2 / smug 2 / furious 2 | brood-human banter, tone list retort |
| 18–20 | thread T4 `sentinelDive` | pip, nomad, pip | "It's diving at me! It's diving at me!" / "Breathe, cadet. Left. Now." (gap 0) / "[gasp] Missed me? It missed me! Woo!" | panicked 3 / calm 1 / awed 1 → cheering 3 | calm against panic, swing |

T3's Vexxa turns count as brood items too (B3, B4). New text is `pending: text` material for `lines.json` once the
schema lands; every line passes the voice-stack tone check (frak, son of a glitch, sweet thrusters, pixel-pusher,
eat static are allowlist entries).

### 7.2 Ten brood vocalisations

| # | Speaker | Item | Layers | Tests |
|---|---|---|---|---|
| B1 | gorrak | `[roar]` (bossArrival style) | vocal + growl | size, no words |
| B2 | gorrak | `sentinelRushMissed.d0` "Again! AGAIN!" | performance + snarl + growl | fury legible through FX |
| B3 | vexxa | `broodTaunt.d1` "You brought a whole fleet for little old me?" | performance + cackle | teasing through FX; clean master usable as the waitress |
| B4 | vexxa | `[cackle]` | vocal | laugh as a brood sound |
| B5 | skarn | `bonusDare.supplyRun.d3` "Burn the boxes! Burn the sky!" | performance + warcry | war cry |
| B6 | gorrak | `levelClear.d0` "Fine! Take this patch of sky!", beats `brood` → `plain` (pilot-only test of §5.4) | performance, wet → dry | the morph technique, on an adult voice |
| B7 | grunnok | `reinforcements.d8` "Oh, that was good!" | performance + cheer + laugh | a brood cheer |
| B8 | krag | `[growl]` | effort + growl | dog in the reveal (research V-07) |
| B9 | sliss | `[hiss]` | breath effort | cat in the reveal |
| B10 | skritch | `bonusDare.supplyRun.d0` "Shiny boxes! Mine, mine, mine!" + `[chitter]` | performance + granular chitter | gull in the reveal |

Each item is rendered with the default stack's vocals (Dia) and, where the item has a vocal, with the S2-Pro and
Higgs free-form growl experiments; the performances come from each speech engine in the pilot.

### 7.3 Listening criteria (1–5 each)

| Code | Criterion | Applies to |
|---|---|---|
| L1 | Emotion matches each beat | all speech |
| L2 | The swing is audible where the beats change | lines with beats, threads |
| L3 | The answer picks up the previous turn's energy | threads |
| L4 | Intelligible through the radio chain at game volume | all speech |
| L5 | Sounds like the character, same voice across takes and turns | all |
| L6 | Free of artefacts (5 = none: no skips, babble, metallic smear, invented words) | all |
| L7 | Non-verbals sound performed, not read out | lines with cues |
| B1 | Alien on first hearing | brood |
| B2 | Emotion still legible through the FX | brood |
| B3 | No word is heard in a vocal-only item | brood vocals |
| B4 | The clean master fits the reveal person or animal | brood |
| F | Family-friendly delivery: nothing heard as a real swear (pass/fail) | all |

Listening happens through the radio chain, on phone speakers and on headphones, blind to the engine.

### 7.4 Decision rule

Per role (§2), the score is the mean of the role's criteria over each item's best take. A challenger takes the role
if its score beats the default's by at least 0.5 and its share of takes with L6 ≤ 2 is no higher; any F fail on an
item disqualifies that take. Otherwise the default keeps the role (no credit line needed). The result goes into §2,
`voice-engines.json` `roles`, and the research §8 table.

### 7.5 GPU plan

1. VoxCPM2 + Dia resident together (about 12.4 GB, voice-stack research §7): all default-stack takes, hot references,
   vocal reels.
2. `gpu.unload_model`; S2-Pro alone (bf16 if it fits beside ComfyUI, else NF4; logged).
3. `gpu.unload_model`; Higgs v2 alone.
4. Never beside ACE-Step music batches. Never `studio.restart`.

## 8. Not decided here

- Thread playback in the director is specified (spec "Threads play as one unit") and implemented after the pilot.
- The listening page format is the batch agent's choice, as long as it is engine-blind and exports scores to the
  ledger.

## 9. Open questions

1. Who scores the pilot: the operator, or someone the operator names? Agents can pre-rank by the automatic checks but
   cannot judge emotion by ear.
2. Child voices for Ulgra, Morth and Nibb in the ending (endgame design §12, decision 9).
3. Admission pins: Dia examples moved to `Dia-1.6B-0626`; the Higgs and fish-speech repos moved on to v3 and Drama 3
   (research §9). The coordinator pins code revisions that run our pinned weights.
4. S2-Pro in 24 GB: bf16 or NF4 (research §2.2).
5. Does the admitted VoxCPM2 node expose continuation for thread turns (research §4)?
6. Whisper weights for the recogniser need the operator's consent token, like any model.

## 10. Ready to run when the models land

- [ ] `studio.models` lists VoxCPM2 and Dia (and, for the challengers, S2-Pro and Higgs v2 with the tokenizer) at
      the revisions of `plan/model-pins-voice.md`; `voice-engines.json` rows carry the admitted node class names.
- [ ] Consent tokens: each model download asked for and approved by the operator; nothing pulled without one.
- [ ] `studio.status` up, `gpu.status` shows ≥ 13 GB free for VoxCPM2 + Dia; no ACE-Step batch queued.
- [ ] Identity clips committed (`art/comms/voices/<id>.flac`, voice-stack task 3.2), brood re-cast to the reveal people,
      hot references for the pilot's speakers.
- [ ] `lines.json` v6 validation in `dart` (tasks 2.x) and the pilot script `art/comms/voice-pilot.json` validated.
- [ ] whisper.cpp built in the forge (`~/.cache/tillandsias-project/bin/`), its small English model approved and
      fetched; speaker-embedding model approved; `tools/brood_fx` built.
- [ ] Lua job file `tools/production/voice-pilot.lua` dry-runs: requests written, no studio call.
- [ ] Ledger directory `plan/render-runs/voice-pilot/` created with an empty `ledger.json`.
- [ ] Run order §7.5; one workflow at a time; checkpoint commits of picks and compare Opus files per engine.
- [ ] Listening page published locally, engine-blind; scorer named (§9, question 1).
- [ ] Decision recorded (§7.4); voice-stack task 6.1 closed by reference to this pilot.
