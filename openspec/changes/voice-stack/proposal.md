# Proposal: voice-stack

## Why

Operator, 2026-11-16 (`plan/operator-feedback-2026-11-16.md`, Round 3c, V1): "Even the existing voices are somewhat
flat of emotion... we're likely going to re-render most of our radio speech once we figure out how to add proper
emotion and excitement, as well as a bit of cheering, wooing, grunting, growling, etc." The operator asked which
models, pipelines or software suite to use with local models, to file the research in `plan/` and the specs here, and
allowed a few PG-13-cleared pseudo-swears while keeping the game family friendly. Round 3d (same file, V1 addendum):
re-read the non-commercial model licences for a free GPL-3.0 game, and make the pseudo-swear list a two-layer
feature, a surface for young players and nods to older games and pop culture for older ones, in original phrasing.

Today's bank (574 clips: 380 Chatterbox, 188 Chatterbox reverse-pitch demon, 5 Kokoro, 1 synthesized grunt, from
`web/audio/comms/manifest.json`) was rendered on CPU in a forge venv that a reset has since wiped. It has one emotion
label per line and no non-verbal vocabulary, and nothing checks the tone of the words. Voice work is blocked on
tillandsias#1103, and #1103 batch 1 (per the coordinator, relayed 2026-11-16) is music only: it has no expressive TTS.

## What changes

- Research: `plan/voice-stack-research.md` surveys expressive TTS, voice identity, non-verbal vocalisations, radio FX
  and authoring tooling, with a source beside every conclusion, and recommends a stack and a fallback.
- New capability `voice-authoring`:
  - line direction: emotion (closed list, five new emotions), intensity 0–3 and a direction note;
  - non-verbal cues from a closed vocabulary (`art/comms/cues.json`), mapped per engine to native tags or stingers;
  - a family-friendly tone check (`art/comms/tone.json`: a two-layer, themed pseudo-swear allowlist the cast trades
    lines with, a deny list and a quote deny list) that fails the build;
  - in-fight hint lines flagged for the one-line subtitle test of `carrier-hatches`;
  - committed voice identities per character;
  - take/pick ledgers in `plan/render-runs/voice-<batch>/`;
  - loudness and format targets;
  - clip tiers (`text`, `placeholder`, `candidate`, `final`) and the promotion rule;
  - engines as admitted host-studio capabilities whose licences leave the audio unrestricted (or carry a credit
    line), unless the operator signs a decision (Round 3d licence re-read, research §10).
- A request list for the coordinator (research §9): the models, VRAM, licences and studio nodes this needs.

## Not in this change

- No placeholder audio: no TTS engine is installed in the forge or the studio today (design §6).
- No code. The schema checks, ledger writer and tier field are tasks, implemented once an engine is admitted.
- No change to the director, pacing or the existing clips. The current bank keeps playing until a batch is promoted.

## Impact

- `art/comms/lines.json` (new optional fields, cues in text), new `art/comms/{cues,tone,voice-engines}.json`,
  `art/comms/voices/`, `tools/comms_pipeline.py` (`dart` and `verify` checks), `web/audio/comms/manifest.json`
  (`tier`, `licence`), `plan/render-runs/voice-*`.
- Depends on the coordinator admitting a TTS engine as a studio capability (tillandsias, after #1103).
