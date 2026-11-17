# Proposal: voice-direction

## Why

Operator, 2026-11-17: "Don't just re-render, remember we're redesigning, so make sure we research the tools and ensure
the pipelines convey the new chatter with full emotion swings and banter, as well as demon growls and grunting for
those low pitch-reversed audio, which might end up as regular grunts from the new models, please research
accordingly." Earlier (2026-11-16, Round 3c): "Even the existing voices are somewhat flat of emotion ... proper
emotion and excitement, as well as a bit of cheering, wooing, grunting, growling".

Change `voice-stack` chose the engines (VoxCPM2 for speech, Dia 1.6B for non-verbals, Fish Audio S2-Pro and Higgs
Audio v2 as challengers; licences signed in PRs #4–#7) and gave every line one emotion, an intensity and cues. One
label per line cannot carry a swing from calm to panic to triumph, a banter exchange in which the second speaker
answers the first one's energy, or a brood officer who growls the first words and then talks. The brood today speak
in reversed, pitched-down performances with a procedural growl under them; the new engines can make real grunts,
growls and snarls, and those need a design so the brood stay alien and still emote. The ending reveal
(`endgame-cinematic` design §12) turns the brood into the restaurant's people, so the voice under the demon effect
must be a voice the cinematic can play plainly.

## What changes

- Research: `plan/audio-voices-research.md` reads each engine's direction controls, dialogue modes and non-verbal
  support, the DSP tools for the brood chain, the take-rejection models and the ComfyUI nodes, with a source beside
  every conclusion.
- New capability `voice-direction`:
  - **beats**: a line may split its words into beats, each with its own emotion and intensity, so one line can swing;
  - **threads**: authored banter exchanges (two to four turns, fixed speakers, gaps and overlaps) rendered and played
    as one unit, with each turn conditioned on the one before;
  - **brood vocals**: a layered brood voice (performance, model-made vocalisation, procedural growl) through a
    per-character demon FX chain whose wet amount may change inside a line, with clean masters kept for the ending;
  - **takes and rejection**: per-take automatic checks (words, identity, loudness, clipping, duration, silence, cue
    presence) before any pick, and per-engine take counts;
  - **promotion**: the voice-stack tiers gain a pilot step, and picks are logged with listening scores;
  - **the pilot**: 20 lines and 10 brood vocalisations on VoxCPM2 + Dia against Fish S2-Pro and Higgs v2, scored
    blind against written listening criteria.
- A "ready to run when the models land" checklist in `design.md` §10.

## Not in this change

- No audio is rendered and nothing is downloaded: the engines are not admitted in the studio yet.
- No change to `lines.json`, the Dart bank or the director in this branch. The schema and the director's thread
  playback are tasks, implemented after the pilot confirms the design.
- The engine choice, licences, tone list, cue vocabulary, identities and loudness targets stay in `voice-stack`; this
  change builds on them and does not repeat them.

## Impact

- `art/comms/lines.json` (v6: `beats`, `threads`, brood `vocal` layers), `art/comms/demon-delivery.json` (v2: FX
  chain, wet envelope), `art/comms/voice-engines.json` (per-engine direction recipes), `tools/comms_pipeline.py`
  (`dart` validation), `lib/comms/comms_director.dart` (thread playback), `plan/render-runs/voice-pilot/`.
- Depends on `voice-stack` (engines admitted in the studio, tasks 1.4 and 2.x) and on tillandsias#1103 for the
  studio audio nodes.
