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

Decision (research §8): VoxCPM2 for speech (Apache-2.0, ~8 GB, style text, cloning from identity clips), Dia 1.6B for
non-verbals and efforts (Apache-2.0, ~4.4 GB, 21 tags), Chatterbox / Chatterbox-Turbo (MIT) as placeholder and
fallback engine. VRAM and licences, with sources, are in research §2 and §9. The spec is engine-agnostic: an engine
is a row in `art/comms/voice-engines.json`:

```json
{
  "id": "chatterbox",
  "studio_node": "<class name from the admission register>",
  "revision": "<pinned commit>",
  "licence": {"code": "MIT", "weights": "MIT", "commercial": true},
  "sample_rate": 24000,
  "cues": "native-tags",
  "emotions": {"urgent": {"exaggeration": 1.0, "cfg_weight": 0.4, "temperature": 0.8}}
}
```

`emotions` carries the per-emotion settings that `audio.json` `chatterbox.emotions` holds today; intensity scales the
engine's own expressiveness control (§3). `verify` reads `licence.commercial` for every shipped clip's engine.

## 3. Line schema (lines.json v5)

Additions, all optional, so today's bank validates unchanged:

| Field | Where | Meaning |
|---|---|---|
| `emotion` | human line, demon line | Closed list: today's `excited, urgent, panicked, triumphant, teasing, warm, exhausted, calm, stern` plus `cheering, furious, relieved, awed, smug`. |
| `intensity` | line | 0 low, 1 normal (default), 2 high, 3 peak. Maps to the engine's control, e.g. Chatterbox exaggeration ×0.7 / ×1 / ×1.3 / ×1.6 of the emotion's base, capped at the engine's stable range. |
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
invented words. Rules:

1. Allowed exclamations (allowlist, extendable by review): `frak`, `frakking`, `blast`, `blast it`, `blasted`,
   `son of a glitch`, `glitch it`, `scrap`, `scrapheap`, `slag`, `slag it`, `drat`, `dang`, `darn`, `shoot`, `heck`,
   `holy smokes`, `holy rivets`, `sweet thrusters`, `burn me`, `rust and ruin`, `sparks`, `what the flux`, `mother of
   moons`, `for crying out loud`, `oh, come on`, `nuts`. Brood glosses get their own: `void-spawn`, `sky-worm`, `rot`.
2. Allowed idioms where the bare word is denied: `hell of a`.
3. Deny list (word-boundary, case-insensitive, also with common letter swaps such as `@`→`a`, `1`→`i`, `0`→`o`,
   `$`→`s`, and repeated letters collapsed): real profanity of any strength, including the mild `damn`, `hell`
   (bare), `crap` and `ass`; religious oaths (`god`, `jesus`, `christ` as exclamations); slurs and insults aimed at
   any group; anything sexual, bodily or about drugs. The list itself lives in `tone.json`, not in the spec.
4. Insults stay at the target's tactics or ego ("bucket of bolts", "overgrown gnat"), never at bodies, groups or
   families.
5. No new line says a human dies (the existing rule: a downed ship or squad is "totalled" and heads back to base).

The check runs in the `dart` stage, so the bank cannot be regenerated with a denied word. It covers human `text`,
demon `say` and `gloss`, and the pending-lines files.

## 4. Takes, picks and identities

- Identity: `art/comms/voices/<id>.flac` (mono, 6–20 s, lossless) plus transcript and description in `cast.json`.
  Today's identities were Kokoro-82M voices (Apache-2.0) re-voiced by Chatterbox; the existing reference-clip text is
  `audio.json` `chatterbox.reference_text`. The identity clip is the only thing that conditions a character, so it is
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
(`"placeholder"`) or `"pending": "text"`. The fastest legitimate placeholder route, once the coordinator agrees, is
research §9 item 1 (restore the pinned Kokoro + Chatterbox, both MIT/Apache, through the studio's admission).

## 7. The swap from placeholder to final

1. A batch renders `candidate` takes; nothing in `web/audio/comms/` changes.
2. Picks are logged; picked masters committed.
3. Promotion: radio chain, encode, `verify`, then `dart` (regenerates `comms_bank.dart` and `voice-batch-pending.md`).
   Tiers become `final`. Lines that borrowed a clip lose their `placeholder` field in `lines.json`; the borrowed-line
   count in `test/comms_director_test.dart` (55 today) drops by the same number.
4. Full gates (CLAUDE.md §2), then merge into `game`. A clip id never changes, so the director, gates and moments
   that refer to clip ids keep working.
