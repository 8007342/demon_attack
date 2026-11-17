# Design: voice-stack

Research, sources and the engine comparison: `plan/voice-stack-research.md`. This file records the decisions. Every
research conclusion here points to a section of that file, where its source sits beside it.

## 1. Where voice rendering runs

The coordinator (relayed by the lead, 2026-11-16) set the frame:

- tillandsias#1103 batch 1 is music through ComfyUI (the `tillandsias_audio` node pack, ACE-Step 1.5 XL-SFT, CC0 SFZ
  libraries) plus a CPU audio appliance. It has no expressive TTS. ETA a day or two.
- The host GPU is one RTX A5000 (24 GB), shared by ComfyUI and ACE-Step. No second GPU container.
- A TTS engine is a studio capability, designed like #1103: ComfyUI (or studio) nodes behind the admission and licence
  register. New models never come in by a direct pull; a restricted licence needs the operator's `/accept-licence`.

So the pipeline is: `lines.json` → (forge, pure Python/Lua) validation and a render request per take → host studio
workflow (TTS node, then the audio-pack nodes for trim, loudness and save) → forge pulls the takes, writes the ledger
→ pick → radio chain, encode, verify, `dart`. The radio chain and encoder stay in `tools/comms_pipeline.py`, or move
to the #1103 audio-pack nodes (EQ, Saturate, Compressor, NormalizeLoudness) once those are live; the clip ids, the
manifest and the bank do not change either way.

The forge's cgroup is 12 GiB and has no GPU (`plan/battle-metal-radio-production.md`), and the last bank took a CPU
worker on about 15 cores. A GPU studio node replaces that worker; the forge only orchestrates.

## 2. Engine choice

Decision (research §8, revised after the licence re-read in research §10): VoxCPM2 for speech (Apache-2.0, ~8 GB,
style text, cloning from identity clips) and Dia 1.6B for non-verbals and efforts (Apache-2.0, ~4.4 GB, 21 tags) are
the default, with no condition on the audio. Fish Audio S2-Pro and Higgs Audio v2, whose licences leave the outputs
unrestricted apart from a credit line, compete with VoxCPM2 in the pilot (task 6.1), after the operator signs their
licences (`plan/licences-to-sign.md`).

Operator decisions, 2026-11-16 (research §10.4):
- **Chatterbox is dropped** (with Turbo and Nano). VoxCPM2 renders placeholders as well as final speech; Dia renders
  the non-verbals. Its pin left `art/comms/audio.json` (the engine-independent delivery shaping moved to `delivery`,
  the reference sentence to `identity`), and the CPU worker tools that ran it left `tools/production/`. The shipped
  2026-11-12 takes stay, and stay credited, until each is re-rendered.
- **Non-commercial with a credit line is acceptable.** The credits generator lists the voice engines and the exact
  credit lines Fish Audio and Boson AI require.
- **IndexTTS-2.5 stays out.** Revisit it only for a need the others cannot meet, such as exact duration control to fit
  a cue.

VRAM, licences and the "OK for this repo?" verdicts, with sources, are in research §9 and §10. The spec is
engine-agnostic: an engine is a row in `art/comms/voice-engines.json`:

```json
{
  "id": "voxcpm2",
  "studio_node": "<class name from the admission register>",
  "revision": "<pinned commit>",
  "licence": {"code": "Apache-2.0", "weights": "Apache-2.0", "outputs": "unrestricted", "credit": null,
              "decision": null},
  "sample_rate": 48000,
  "cues": "stingers",
  "emotions": {"urgent": {"style": "urgent, clipped, shouting over engine noise"}}
}
```

`emotions` carries the per-emotion engine settings (for VoxCPM2 a style text, for Fish S2-Pro inline tags, for Higgs
its scene prompt); intensity scales the engine's own expressiveness control (§3). The engine-independent post-shaping
stays in `audio.json` `delivery`. A challenger row (Fish S2-Pro, Higgs v2) has `outputs: "credit"`, its `credit`
line and the `decision` file that records the operator's signature. `licence.outputs` is `unrestricted`, `credit` (unrestricted apart from the `credit` line) or `restricted`;
`decision` names a signed file in `licences/acknowledgements/` when the operator has accepted conditions. `verify`
rejects a shipped clip whose engine is `restricted` without a `decision`, and the credits list every `credit` line
of the engines that actually shipped.

## 3. Line schema (lines.json v5)

Additions, all optional, so today's bank validates unchanged:

| Field | Where | Meaning |
|---|---|---|
| `emotion` | human line, demon line | Closed list: today's `excited, urgent, panicked, triumphant, teasing, warm, exhausted, calm, stern` plus `cheering, furious, relieved, awed, smug`. |
| `intensity` | line | 0 low, 1 normal (default), 2 high, 3 peak. Maps to the engine's control, e.g. a VoxCPM2 style adverb ladder ("a little", plain, "very", "extremely") or a scale on an engine's expressiveness knob, capped at the engine's stable range. |
| `direction` | line | Up to 120 characters for the take: "out of breath, grinning", "through gritted teeth". Goes to engines that take text instructions; logged for the rest. |
| cues | inside `text` / `say` | `[laugh]`, `[whoop]` … from `art/comms/cues.json`. |

Example:

```json
{"speaker": "kessler", "text": "[whoop] Frak yes! Convoy's through!", "emotion": "cheering", "intensity": 3,
 "direction": "shouting over engine noise"}
```

### 3.1 Cue vocabulary (`art/comms/cues.json`)

Human: `laugh`, `chuckle`, `sigh`, `gasp`, `breath`, `exhale`, `groan`, `grunt`, `effort`, `whoop`, `cheer`,
`crowd-cheer`, `woo`, `hmm`, `cough`. Demon: `growl`, `snarl`, `roar`, `cackle`, `hiss`, `chitter`, `grunt`. The demon
side keeps today's eight grunt kinds (`alarm, cackle, gloat, order, rally, roar, snarl, warcry`) as `grunt` values.

Each cue maps per engine to `{"tag": "<laugh>"}` (a native paralinguistic tag), or `{"stinger": "<cue>"}` (render the
cue on its own and splice it with a 60 ms crossfade), or `{"drop": true}` (the engine cannot do it; log it). Which
engines have native tags is in research §2. `crowd-cheer` is always a stinger: a layered bed (research §4), never TTS.

Subtitles drop cues; reading time counts only the words.

### 3.2 Tone guide (`art/comms/tone.json`)

The radio is a PG game for all ages that sometimes sounds like a PG-13 film: pilots under fire swear, but only in
invented words. The curated pseudo-swears are a feature, not a filter's leftovers: the cast trades them back and
forth, and each one is built in two layers (operator, Round 3d, V1 addendum).

- **Surface.** A young player hears a funny, safe, space-salvage exclamation and gets the whole joke.
- **Hidden.** An older player catches a second reading: a nod to older games and arcade culture, the shape of a
  familiar mild oath, or (on a second run) a hint of the end-game reveal (change `endgame-cinematic`: the war is a
  board game the kids are playing in the Krybor restaurant).

**Rules for the hidden layer.**

1. Original phrasing only. A nod works by allusion to a mechanic, an object or an era (coin slots, cartridges,
   high-score initials, attract mode, continues, lag), never by quoting a line, lyric, catchphrase, character name
   or title from another work. `quoteDeny` holds famous catchphrases the check rejects outright.
2. The surface must stand alone. If a line only works for someone who knows the reference, rewrite it.
3. The hidden layer is as PG as the surface. "Double entendre" here means a second meaning about games, the radio or
   the reveal; never sexual, bodily or drug innuendo, even veiled.
4. Insults stay at the target's tactics, gear or ego ("bucket of bolts", "overgrown gnat"), never at bodies, groups
   or families.
5. No new line says a human dies (a downed ship or squad is "totalled" and heads back to base).
6. Rationing: `nod` and `reveal` entries count as `signature` lines for the director, so a run hears each only a few
   times and they stay a discovery.

**Schema.**

```json
{
  "theme": "Salvage-yard space navy at the arcade: machines, sparks, radio static, coin-op cabinets, a board game underneath",
  "allow": [
    {"phrase": "son of a glitch", "theme": "machine", "layer": "nod",
     "surface": "angry at a broken machine",
     "hidden": "shape of a familiar mild oath; glitches as a speedrunner's friend",
     "speakers": ["kessler", "rook"], "retorts": ["glitch yourself"]}
  ],
  "idioms": ["hell of a"],
  "deny": ["…"],
  "quoteDeny": ["…"]
}
```

`theme` on the root is the house style; `theme` on an entry is one of `machine`, `space`, `radio`, `arcade`, `board`,
`brood`. `layer` is `surface` (one reading), `nod` (a second reading for older players) or `reveal` (a second-run
reading tied to the ending). `hidden` is a reviewer's note describing the nod; it is never shown in game and never
quotes the thing it nods to. `speakers` (optional) limits who says it, so each character keeps a voice. `retorts`
lists entries that answer it in an exchange.

**Starting allowlist** (original phrasing; reviewers extend it):

| Phrase | Theme | Layer | Surface (for a young player) | Hidden (reviewer's note) |
|---|---|---|---|---|
| frak / frakking | space | nod | a space pilot's swear word | the operator's pick; an invented TV-space-opera word, used as a word, never with its show's lines |
| blast it / blasted | space | surface | angry, like a blaster misfire | — |
| son of a glitch | machine | nod | angry at a broken machine | shape of a familiar mild oath |
| what the flux | machine | nod | confused by a weird energy reading | shape of a mild exclamation; time-travel-gadget era of films, by the one word only |
| holy rivets / holy smokes | machine | surface | amazed | — |
| rust and ruin | machine | surface | a dramatic old-spacer curse | — |
| slag it | machine | surface | "melt it down", frustrated | — |
| sweet thrusters | space | surface | delighted | — |
| burn me | space | surface | rueful "you got me" | — |
| eat static | radio | nod | radio-talk "get lost" | the hiss of an untuned channel and old TV sets |
| insert coin, you bucket of bolts | arcade | nod | taunt at a clunky enemy | coin-op cabinets |
| don't make me blow on your cartridge | arcade | nod | silly threat to a malfunctioning foe | home consoles of the cartridge era |
| back to your attract mode | arcade | nod | "go back where you came from" | the demo loop a cabinet plays with nobody at it |
| not on my last continue | arcade | nod | determined, nearly beaten | the continue countdown |
| three letters on the board, and none are yours | arcade | nod | boast after a big hit | high-score initials |
| lag spike! | arcade | nod | "everything just went wobbly" | online-play complaint |
| pixel-pusher | arcade | nod | insult at the brood | sprite artists and low-resolution screens |
| roll for it | board | reveal | "let's take the chance" | the war is a board game (second run) |
| that's not in the rulebook | board | reveal | "that move is unfair" | the brood's tricks are a kid bending the rules |
| who's keeping score? | board | reveal | bragging | someone at the table is |
| don't flip the table | board | reveal | "stay calm" after a loss | a sore loser at the restaurant |
| void-spawn / sky-worm (brood glosses) | brood | surface | brood insults for humans | — |
| tin-can / shiny-shell (brood glosses) | brood | nod | brood insults for ships | the figures on the board are plastic and painted |

**Trading lines** (exchange examples, original):

- Brood (gloss): "Shiny-shell! Your fleet is painted tin!" → Sparrow: "Painted tin with a full tank, pixel-pusher. Eat
  static!"
- Kessler: "Son of a glitch, the convoy's stuck!" → Mensah: "Then roll for it. Push through!"
- Pip: "What the flux was that?!" → Admiral: "A lag spike, cadet. Fly through it."
- Rook: "Not on my last continue, you bucket of bolts!" → Brood (gloss): "Back to your attract mode, tin-can!"

**Deny list** (word-boundary, case-insensitive, with common letter swaps such as `@`→`a`, `1`→`i`, `0`→`o`,
`$`→`s`, and repeated letters collapsed): real profanity of any strength, including the mild `damn`, `hell` (bare),
`crap` and `ass`; religious oaths (`god`, `jesus`, `christ` as exclamations); slurs and insults aimed at any group;
anything sexual, bodily or about drugs. A phrase that reads as a real swear when said aloud quickly (a minced oath
one letter away) is denied too, unless it is on the allowlist after review: "what the flux" passes review because
the radio's fast delivery keeps the science word clear; anything closer is denied. The lists live in `tone.json`, not
in the spec.

**Quote deny list** (`quoteDeny`): well-known catchphrases from games, films and songs that a writer might reach for
by reflex. The check rejects them so a nod never becomes a copy. The list is a reviewer's tool and grows with
review.

The check runs in the `dart` stage, so the bank cannot be regenerated with a denied word. It covers human `text`,
demon `say` and `gloss`, and the pending-lines files.

### 3.3 Hint lines

In-fight hints ("Destroy the hatches!", "Time the open hatch!", "Fire ahead of its position!"; Round 3d, C4) carry
`"hint": true`, no cues, and must fit one radio subtitle line. The radio font size and the line-length test belong to
change `carrier-hatches`; this change only adds the flag and rejects cues in hint lines.

## 4. Takes, picks and identities

- Identity: `art/comms/voices/<id>.flac` (mono, 6–20 s, lossless) plus transcript and description in `cast.json`.
  Today's identities are Kokoro-82M voices (Apache-2.0), which Chatterbox re-voiced for the 2026-11-12 bank; the
  reference sentence is `audio.json` `identity.reference_text`, and the `refs` stage renders it per character. The identity clip is the only thing that conditions a character, so it is
  committed (CLAUDE.md §5: GPU re-renders are not byte-identical).
- Take counts: three seeds for priority ≥ 8 and `signature` lines, two for the rest, one for cue-only stingers plus a
  pick from a small cue library per character.
- Automatic accept rules before a human hears it: duration within 0.5–2.5× the text's expected length at the
  speaker's rate, no clipping, no silence longer than 0.8 s inside the speech, and (when an ASR model is admitted)
  word error under 15 %. A rejected take is logged, never picked.
- Ledger: `plan/render-runs/voice-<batch>/ledger.json` (machine) and `README.md` (human: picks and reasons), the same
  layout as `plan/render-runs/radio-bank-2026-11-12/`. The picker is the agent running the batch (CLAUDE.md §5
  autonomy); the operator overrides later.
- Masters: picked takes as mono FLAC at the engine rate under `art/comms/masters/<batch>/`. Budget: about 3 s × 574
  clips × 24 kHz × 16 bit ≈ 83 MB raw, about half that as FLAC. Clean and demon-transformed masters are both kept
  for brood lines.

## 5. Loudness and format

Unchanged where the current bank already works: human −18 LUFS, demon −18.5 LUFS integrated (`audio.json`
`loudness`), Opus 48 kbps mono, playback gain +2 dB, decoded peak ≤ 0 dBFS. Additions:

- Short clips (< 1 s, most stingers) are normalised by maximum momentary loudness (the 400 ms meter) to the same
  target, because integrated loudness has few or no complete gating blocks on them (research §5, where the
  meter is sourced and the gating claim is marked [UNSOURCED: plan/provenance-audit.md#V-02]).
- Masters keep ≥ 1 dB true-peak headroom before the radio chain, so the chain's saturation shapes the peaks, not the
  engine's clipping.
- Tolerance in `verify`: ±1 LU.
- The AAC copies (`aac_kbps` 24) are legacy; Opus-only fetch is already implemented. They are not re-rendered.

## 6. Placeholders today: none rendered

The operator OK'd quick placeholders; the lead's rule is "only TTS that is already installed, no new download, no new
nodes". Inventory on 2026-11-16:

- Forge: no `kokoro`, `torch`, `chatterbox`, `espeak`, `piper`, `flite` or `festival`; no Hugging Face cache; the
  comms venv and its weights were wiped with `~/.cache` (the only Python environments left are the bpy venv and
  pip-user tools). ffmpeg 9.0.2 is built without `libflite`. `tools/comms_pipeline.py voices` therefore cannot run
  as is: it needs `pip install` of torch and kokoro and a Hugging Face download of the pinned weights.
- Studio (`studio.models`, tray 56.11.15.5): image models and ACE-Step 1.5 only. No TTS node or weight.
- Host audio appliance (`audio.transform`): loudness, stretch, Opus/AAC encode, resample. No synthesis.

So nothing qualifies, and no placeholder was rendered. New lines keep using the existing mechanisms: a borrowed clip
(`"placeholder"`) or `"pending": "text"`. Since Chatterbox was dropped (§2), placeholders wait for VoxCPM2's admission
as a studio node (research §9.1 row 1): a placeholder is then a quick single VoxCPM2 take with tier `placeholder`.

## 7. The swap from placeholder to final

1. A batch renders `candidate` takes; nothing in `web/audio/comms/` changes.
2. Picks are logged; picked masters committed.
3. Promotion: radio chain, encode, `verify`, then `dart` (regenerates `comms_bank.dart` and `voice-batch-pending.md`).
   Tiers become `final`. Lines that borrowed a clip lose their `placeholder` field in `lines.json`; the borrowed-line
   count in `test/comms_director_test.dart` (55 today) drops by the same number.
4. Full gates (CLAUDE.md §2), then merge into `game`. A clip id never changes, so the director, gates and moments
   that refer to clip ids keep working.
