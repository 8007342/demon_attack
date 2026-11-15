# RESUME: start here after a forge relaunch

Written 2026-11-14 (late) by the session that ran the music batch, the notes/studio routes, and the
battle-flow backlog. The operator is asleep; the host session (macuahuitl-fedora) relaunches the forge onto
the new audio studio. Read this file, then `plan/render-runs/rerender-all.md` on `work/music-batch` (its
"Session handoff" section and log), then act.

## 0. First checks (2 minutes)

1. `git fetch --all` in `/home/forge/src/demon_attack`. Integration branch: `game`. Never push `main`
   (level-1 discipline: main advances only by pull request).
2. Disk: `/home/forge/src` is a 2.5 GB RAM tmpfs. Put every worktree and build output under
   `/home/forge/.cache/tillandsias-project/worktrees/`. Agent `isolation: "worktree"` puts worktrees in the
   repo on tmpfs and filled it once: create worktrees on ~/.cache yourself and point agents at them.
3. `mcp__host-browser__tillandsias_lane_version` must say `current`.
4. `mcp__host-browser__studio_models` (and `studio_status`): confirm the batch-1 audio additions are listed
   (FluidSynth/SFZ renderer, NAM, Pedalboard/LSP, Matchering, R128 analysis, Audiobox, HTDemucs (restricted,
   internal only), ACE-Step 1.5 XL-SFT + 4B LM, VoxCPM2) and the audio node pack (the "ComfyUI for music"
   studio). Ask macuahuitl-fedora (ListAgents → SendMessage) for the PR and exact node class names.
5. `/home/forge/.cache/demon-attack` must be a symlink to `/home/forge/.cache/tillandsias-project/demon-attack`;
   if missing, `lua tools/production/bootstrap_radio.lua` from a checkout (it restores it).

## Update 2026-11-14 17:35 UTC (relaunched session)

- Lane current (56.11.14.3). The audio studio batch 1 is draft PR **tillandsias#1103**, NOT live yet (operator
  review → land → image + tray rebuild → forge relaunch). Node pack `tillandsias_audio`: TillandsiasLoadMIDI,
  TillandsiasMIDITransform, TillandsiasSFZRender, TillandsiasAudioPan/MixBus/Crossfade/LoopSeam/EQ/Compressor/
  Limiter/Saturate, TillandsiasAudioLoudness/NormalizeLoudness/Scope, TillandsiasBarGrid, TillandsiasSaveLoopWAV;
  core PreviewAudio, SplitAudioChannels, JoinAudioChannels, AudioMerge, EmptyAudio, AudioEqualizer3Band; ACE-Step
  1.5 XL-SFT. SFZ (CC0): Karoryfer big-rusty / swirly / unruly drums; black-and-blue, meatbass, growlybass basses;
  black-and-green, shiny guitars; VCSL. Batch 2 (later): FluidSynth, NAM amp/cab, Pedalboard/LSP/Matchering,
  scoring. Until then guitars = clean CC0 samples → Saturate + EQ.
- **Step 1a is done:** `art/music/scores/l3-ember-moon/` (full.mid, parts/*.mid, score.json) from
  `tools/score_l3.py`; form and parts in `art/music/scores/README.md`. Composition sketch (old synth, arrangement
  only): `~/.cache/demon-attack/scores/l3-ember-moon-sketch.{flac,opus}` via `tools/score_sketch.py`. Awaiting the
  operator's ear on the arrangement.
- **Step 1b, dry pass drafted:** `art/workflows/music/l3-ember-moon-dry.json` from
  `lua tools/production/l3_pilot_workflow.lua` (signatures from #1103 nodes.py, relayed by macuahuitl-fedora):
  LoadMIDI($midi = full.mid copied under /work/tmp/imagegen/) → MIDITransform(channel = N) per part →
  SFZRender → SaveLoopWAV stem + four-input MixBus chain → dry mix. SFZ instrument paths are `TBD:<lib>`
  until `studio_models` lists them (paths `models/<id>/…sfz`; ids big-rusty-drums, meatbass,
  black-and-green-guitars, shinyguitar, vcsl): fill the `SFZ` table, regenerate, then queue.
- **Mixed pass drafted too:** the same script writes `l3-ember-moon-mix.json` (128 nodes): per-part EQ
  (one band per node), Saturate as amp stand-in, Compressor, Pan; bus chain; master Compressor →
  NormalizeLoudness −18.5 LUFS (ceiling −1.5) → Limiter −1 dB; BarGrid (180 BPM, 96 bars) into the mix's
  SaveLoopWAV grid_json. BarGrid regions are 0-based,
  end-exclusive ([0, 96)); combo inputs (bits, beat_unit) are integers (both confirmed by the host). Run dry first, then mix; then 1c, 1d.

## Operator playtest 2026-11-14 (evening): approved all of section 2's game work

Loved the fog; radio "much cleaner and fluid, a lot of the speech now has great emotion". Asked for:
- **Atmosphere and swarms**: OpenSpec `atmosphere-and-swarms` (proposal, design, tasks, spec), research in
  `plan/atmosphere-research.md` (fog layers incl. ground fog and thin sky sheets over the ship, creatures flying
  through the layers, flock arrivals at varied speeds, shadows leading arrivals, a giant sentinel silhouette
  flying a figure-eight 1–2 waves ahead, then arriving with its swarm). Interim done: gear (shields, armour,
  halos, pips) hidden in the fog (f050241f). Next: tasks 1.1 → 2.x → 3.x.
- **Mobile toasts framed** (f050241f): rounded, bordered, shadowed, accent bar; needs a phone look.
- **Tips become radio with a picture**: voiced by a few command officers over the tip art, part of the random
  transition chatter (needs recorded lines: VoxCPM2 batch).
- **Demon voices much growlier** (keep the low-pitch reverse "language" trick): creature processing in the
  voice re-render (UC8).
- Music: still hears loops and clipping in the current score: the L3 real-instrument pilot is the fix.
- Ground assets re-render: still waiting on the 8 questions in section 2.

## 1. Music: next steps (the main job once the studio is loaded)

Spec: `plan/audio-studio/music-requirements.md` (on `game`). The operator rejected ALL current music. Do not
promote anything from `work/music-batch`.

1. **Pilot L3 Ember Moon** (180 BPM, 64000 samples/bar, E minor, 96 bars in six sections; motif and
   progression in `art/music/campaign.json` and `web/audio/music/manifest.json` `motifs.3`):
   a. Write the full 96-bar multitrack MIDI arrangement (drums, bass, two rhythm guitars, lead, choir/organ
      layers), committed under `art/music/scores/` (new), generated from `tools/music_motifs.py` motifs.
   b. Build a studio workflow: MIDI → SFZ drums/bass, clean DI guitars → NAM amp + cab IR, orchestra/choir
      (VCSL) → bus FX → master (R128 target −18 to −19 LUFS) → full mix + stems through the master bus.
   c. Screen it (loudness, true peak, clicks via audio.detect_glitches, bandwidth > 16 kHz, aesthetics).
   d. Give the operator an A/B in `/studio` (music tab) against the current in-game L3 score. Only after
      approval: the adaptive cut (tiers, layers, power, accents) per spec section 4.
2. Voices: once VoxCPM2 is in, a 5-clip pilot of the worst offenders (the five Kokoro clips:
   `bossArrival.h2`, `groundMissileLaunch.h5`, `sentinelDive.h3`, `shieldSpotted.h0`, `weaponPickup.h0`) at
   48 kHz for the operator, before re-rendering the 574-clip bank.

## 2. Game backlog status (operator, 2026-11-14)

On `game` now:
- `d6c1f868` **wave pressure + distance fog** (OpenSpec `wave-pressure`): the next wave approaches out of the
  fog at Easy 2 / Normal 3 / Hard 4 remaining, joins after 10/8/6 s if the player lingers. Procedural mist and
  horizon smoke are placeholders for the atmosphere atlas. Needs the operator's playtest (task 2.1).
- `40ff5983` **fluid transitions** (OpenSpec `fluid-transitions`): one message at a time, a slim progress
  strip, alternating silent-tip / radio interlude cards on level transitions, wave changes strip-only. Needs a
  browser playtest to tune fade length and reading speed (task 4.3).
- `1aaf284f` **comms middle ground** (OpenSpec `comms-middle-ground`): see section 3.
- `0af66a20` transitions use the comms `hush`/`offer` hooks (silent tips hush the director; the radio card's
  pick is offered through pacing, never over the squad).

All of the above: `flutter analyze` clean, 425 tests passing (1 pre-existing skip). Nobody has played or
listened to any of it in a browser yet; that is the operator's first look.

On branches, awaiting the operator:
- `work/ground-forces-design` (`f7a7b1d0`): OpenSpec `ground-forces-rework` plus
  `plan/human-ground-forces-style-guide.md`, `plan/ground-unit-animation.md`, `plan/ground-atmosphere.md`,
  `plan/ground-easter-eggs.md`, `plan/render-runs/ground-forces-rework.md`. GPU estimate about 13 h (lean
  6.5 h). **Operator questions** before any render:
  1. Five headings per faction, or four (about 20% less art)?
  2. Pilot human and demon sides together, or demons first?
  3. Full pipeline (about 13 h) or lean (about 6.5 h)?
  4. Do the 4 existing threat vehicles also get headings (gameplay contract, behind a flag)?
  5. A Carrier-sector human slot (Skiff), or keep reusing the Hollow units?
  6. Easter-egg rarities (1/3 dances, 1/8 turret-pop jackpots, 2/5 tree flocks)?
  7. Do allied squads dance on `allySaved`?
  8. Half-resolution far atlas if phone memory is tight?

Not started: easter eggs in code (they need the ground art first, see `plan/ground-easter-eggs.md`).

## 3. Comms (middle ground), on `game`

Seeded sim (`test/comms_pacing_sim.dart`, busy sector 3, 600 s, seeds 4/11/23): paced airtime 17–20 % →
38–39 % busy (24–25 % calm), 0 overlaps, 0 cut lines (was 7–12). Ground warnings are never dropped; 1–2 of
51–60 end late (they wait for the line on air plus a 0.4 s grace gap; a fire forecast avoids most conflicts).
Dive calls: 31–40 of 41–42 end within ±0.3 s; the misses are sentinel calls that waited for a line.
Cards stay up max(clip end + hold, 0.9 s + 0.055 s/char), capped 7 s; taunt pairs stay up together.
Air-cover/ground lines are gated on the real ground picture (`groundPicture`, `allyUnderAttack` within 10 s,
engaged units, flank/arm data). Reinforcements, escorts, carrier phases, wave starts, salvage and the new
wave-pressure `incoming` event reuse existing clips.
Pending (no audio yet): `art/comms/pending-lines-2026-11-14.json` (carrier hatch, last stand, incoming, escort,
air cover gained/lost, transitions) plus six interlude lines the transitions author suggested (in the
fluid-transitions OpenSpec report). Record them with the coming 48 kHz voice model (VoxCPM2).
Still silent: `lastStandTell` (needs a recorded line).

## 4. Preview

`npm run build` in a checkout, then `mcp__host-browser__preview_publish {category: WEB}` (reload after
`wrangler.jsonc` edits). Routes: `/` game, `/console`, `/studio` (asset review + notes), `/gallery/`.
Notes from all three pages share one browser store; "Copy for an agent" gives a markdown worklist.

## Update 2026-11-14 22:55 UTC (graphics session after relaunch)

- Lane current (56.11.14.3), studio up, cache symlink restored with `bootstrap_radio.lua`.
- Ground-forces Phase 1 (pilot, about 90 jobs) still waits for the operator's **CP0** approval
  (`art/contact/ground-rig-turntables.png`). Prep done meanwhile: VACE in-between workflows (17 and 33 frames) and
  the batch matte, generated by `tools/production/inbetween_vace_workflow.lua` (tasks 3.1–3.3).
- **Fixed 22:55 by the host** (volume dir was mode 700 after the studio.restart crash). Was BLOCKED: the studio could not reach this forge's `/work/tmp/imagegen` since the relaunch: every input
  "does not exist", and a no-input txt2img fails writing its output with "Permission denied (os error 13)". Every
  studio GPU job is blocked until the host fixes the mount. Reported to macuahuitl-fedora.
- Missing for the plan's VACE timings: the lightx2v 4-step LoRA for Wan2.2 (not admitted); without it a clip runs 20 steps.
- `studio.validate_family` refuses all families (contract 1935-k2ib/v1 headers); runs don't need it.
- Smoke runs of all three new graphs passed (render plan §8, with the heading-edit findings: rig pose holds at
  denoise 0.7, not at 1.0; name the magenta key in the prompts). `go run . control [ids]` writes the VACE control
  strips. Next, on the operator's CP0 go: `go run . rig` + `jobs`, then the Phase 1 pilot one job at a time.

## Update 2026-11-15 (before the relaunch for the Wan2.2-Lightning LoRA)

- **Done:** CP0 approved by the operator. Pilot heroes rendered and ingested (12 candidates; ledger in
  `plan/render-runs/ground-forces-rework.md` §9; raws in `~/.cache/demon-attack/ground-blocks/{raw,pilot}/`). No GPU
  jobs in flight; the last ones were st-1794721235621-7, -8, -9 and st-1794721555014-10, all done.
- **Waiting on the operator:** how `tools/ground_blocks finish` should treat AI art. Today it keeps only luminance inside
  the rig and recolours from rig ramps, which flattens the heroes (`art/contact/ground-pilot-heroes-finished.png`).
  Options put to the operator: (1, recommended) keep AI colour quantised to the faction palette inside the rig
  silhouette ±1 texel; (2) as 1 but let the AI outline win on soft parts; (3) no-AI fallback (rig shading only).
  Do not run headings, turret angles or VACE clips before that answer.
- **Next after the answer:** implement it in `finish`, re-finish the 12 heroes into a before/after sheet, the
  operator picks a hero per unit (`hero.selected` in the family), then `go run . jobs` and the heading jobs
  (try denoise 0.7 vs 1.0 on Lodestar first, §8).
- **New after relaunch:** the Wan2.2-Lightning LoRA (lightx2v/Wan2.2-Lightning rev 18bccf88, Seko-V1.1 high- and
  low-noise) via LoraLoaderModelOnly. Add it to `tools/production/inbetween_vace_workflow.lua` (one loader per
  expert, before ModelSamplingSD3), set steps 4, cfg 1, split 2/2; check exact file names with `studio.models`.
- Inputs for studio jobs go under `/work/tmp/imagegen/in/` (that folder is wiped on relaunch: re-copy the rig refs
  with `cp -r ~/.cache/demon-attack/ground-blocks/work/rig /work/tmp/imagegen/in/ground-blocks/`).

## Update 2026-11-15 (after the relaunch, tray 56.11.15.3)

- **Done: Wan2.2-Lightning wired.** `tools/production/inbetween_vace_workflow.lua` now loads
  `lora/high_noise_model.safetensors` and `lora/low_noise_model.safetensors` (lightx2v/Wan2.2-Lightning rev 18bccf88,
  Seko-V1.1; sha256 698321cb… / ec95216e…) via LoraLoaderModelOnly, one per expert, before ModelSamplingSD3; schedule
  steps 4, cfg 1, split 2/2. Both VACE graphs regenerated. The 20-step schedule is still reachable by `$node` overrides
  (comment at the top of the script).
- Smoke st-1794722605549-0 (Ashlar h090 walk, 17 frames): 34 s run against 135 s before; the host fetched the LoRA on
  first use (88 s, now on disk). Raws in `~/.cache/demon-attack/ground-blocks/smoke/vace-lightning-st-1794722605549-0/`.
- After a relaunch: `lua tools/production/bootstrap_radio.lua` first (the `~/.cache/demon-attack` symlink was gone
  again), then re-copy `work/rig` and `work/control` into `/work/tmp/imagegen/in/ground-blocks/`.

## Handoff 2026-11-15 (before the next restart)

State: `game` pushed, studio idle (no jobs in flight; last st-1794722605549-0), qwen2.5:14b unloaded by us (it reloads
itself). The operator approved every open recommendation: the table is `ground-forces-rework.md` §10 (A1–A6).

On resume:
1. `lua tools/production/bootstrap_radio.lua` (restores the `~/.cache/demon-attack` symlink), `studio.start {}`, then
   `mkdir -p /work/tmp/imagegen/in/ground-blocks && cp -r ~/.cache/demon-attack/ground-blocks/work/{rig,control} /work/tmp/imagegen/in/ground-blocks/`.
   Free GPU memory with `gpu.unload_model`; never `studio.restart`.
2. **A1, next job:** change `tools/ground_blocks finish` to keep AI colour quantised to the faction palette inside the
   rig silhouette dilated ±1 texel (today it keeps luminance only and recolours from rig ramps). Re-finish the 12 pilot
   heroes into a before/after sheet (`art/contact/ground-pilot-heroes-finished.png` is the "before"); the operator
   picks one hero per unit (`hero.selected` in the family).
3. Then `go run . jobs` and the heading jobs, Lodestar first at denoise 0.7 vs 1.0 (A3), then turret angles and the
   VACE clips (Lightning graphs, A2), one job at a time; push after each checkpoint (CP1 sheet `ground-pilot.png`).
4. ~~A6 renames and silhouette tweaks before Phase 2~~ Done on `work/a6-originality`: Gutter-runner → Spout-runner
   (`art/families/rigs/spout-runner.json`), Stilt chin pod, Sleet four wheels plus a tail skid (§10 A6).

## Relaunch 2026-11-15 ~07:15 UTC (tray 56.11.15.5): the cache volume was wiped

- **The host's guest reset plus podman reset wiped every volume**, `~/.cache/tillandsias-project` included. No snapshot
  exists. Lost: `ground-blocks/{work,raw,pilot,smoke}`, the voice-trial venv, the music/score caches.
  **Rule: anything that must survive a host reset goes in git, or in a rebuild script plus its recorded seeds, never only
  in the cache.**
- Rebuilt from the repo: `cd tools/ground_blocks && go run . rig && go run . control && go run . jobs` (CPU, seconds).
  The hero raws are re-rendered from the seeds in `art/families/ground-*-runs.json` (one count-4 run per unit).
- `bootstrap_radio.lua` restores the symlink, then fails creating the voice venv (`uv` has no Python 3.11 and
  downloads are manual). The render work doesn't need it; fix with `uv python install 3.11` when the voices are next needed.
- **A1 done** (a7aed0b0, majority-vote follow-up; ledger §11): `finish` keeps the AI colour (see §10). `go run . sheet OUT CELL=RAW.png ...` draws the review rows
  rig | raw | finished.

## Status 2026-11-15 ~08:40 UTC (autonomous run; the operator delegated picks and checkpoint calls)

- Ground forces: CP1 decided (lean hybrid, ledger §12). In flight: the 23 remaining heroes (runner agent, on `game`),
  `bake` smoothing (branch `work/bake-smooth`), runtime integration of the block atlases (OpenSpec
  `ground-blocks-runtime`, branch `work/ground-blocks-runtime`). A6 done (Spout-runner, Stilt chin pod, Sleet).
- **Music L3 pilot: BLOCKED on tillandsias#1103** (audio studio batch 1 is a draft awaiting operator review; tray
  56.11.15.5 has no SFZ/audio nodes). Don't work around it or build the nodes in-forge (host, 2026-11-15).
- Voices (VoxCPM2 batch, tips-as-radio, growlier demons, pending lines): blocked on the same audio batch.

## Status 2026-11-15 ~10:30 UTC: ground forces closed out (autonomous run)

Everything on `game`, `flutter analyze` clean, `flutter test` 500 passed / 1 skipped. Read
`plan/render-runs/ground-forces-rework.md` §12–§17 (decisions, ledgers, close-out with deferred lists and the
operator's playtest checklist).
- Art: 26 heroes picked and committed (`art/sprites/sources/ground-blocks-selected/`), all blocks baked (bake v2) and
  packed per sector; atmosphere atlas (procedural); wildlife flock + critter leaps; sentinel silhouettes.
- Runtime: OpenSpec `ground-blocks-runtime` (headings, turrets, overlays, LOD; legacy behind
  `GroundPainter.useBlocks`), `ground-easter-eggs` (budget, dances, breakups, jackpot, flocks, scatter), atmosphere
  atlas in the depth sort, unit fog tint, battlefield smoke.
- Not archived: the OpenSpec changes await the operator's playtest before `openspec archive`.
- Still blocked: music L3 pilot and every voice task on tillandsias#1103 (audio studio batch 1, draft).

## Operator playtest 2026-11-15 (after the close-out): see `plan/operator-feedback-2026-11-15.md`
Five workstreams W1–W5 (ground tuning, fog restoration, continuous swarm, demon intelligence, UX cleanup + cinematic
flow), each with an OpenSpec change, delegated to agents on `work/*` branches.
