# Re-render everything: master checklist

Operator direction (2026-11-13, relayed by the host session): re-render pretty
much every asset (sprites, music, radio voices) to raise quality, working
through this list in order. **This file is the agent's memory across forge
restarts.** On every restart, re-read it and the production ledgers before doing
anything else. Push after every checkpoint. If a sprite or image job hits a
studio refusal, ask the operator and continue with the next item; don't pause
the whole list over one item.

Branch: `work/battle-metal-radio-rework`. The radio controller commits from this
checkout; serialize any other Git write with `flock .git/production-checkpoint.lock`.

## Restart procedure

**Disk:** `/home/forge/src` (checkout and agent worktrees) is a 2.4 GB RAM-backed tmpfs. It filled up on 2026-11-14.
Keep large raws and caches under `/home/forge/.cache/tillandsias-project/` (`.cache/flyover-raw` is a symlink there),
remove finished agent worktrees, and push often: unpushed work in tmpfs may not survive a restart.
It can't be resized live (a launcher change plus a restart is filed). Keep at least 300 MB free for git; put new worktrees and
build outputs under `/home/forge/.cache/tillandsias-project/worktrees/`. That overlay survives a container restart, not a
recreate, so it is only a cache: everything that matters must be pushed.

**Do not restart the forge on purpose** until the host launcher fix (tillandsias #1092) is installed: a restart
brings back the 12 GiB cgroup caps. New models and the music allowlist (#1091, #1093) arrive live through a host
tray rebuild. There is no persistent supervisor; long batches run from a retained session, with a babysitter
checking in every 20–30 min (ScheduleWakeup).

1. `pgrep -af 'model_worker|resume_radio'`. Never start a second controller or worker.
2. `/home/forge/.cache/demon-attack` must be a symlink to
   `/home/forge/.cache/tillandsias-project/demon-attack`. If it is missing, run
   `lua tools/production/bootstrap_radio.lua`. If it is a plain directory, the
   resume script created it before bootstrap; inspect it, move it aside, then bootstrap.
3. `lua tools/production/status.lua tools/production/radio-bank-2026-11-12.lua`, then
   resume from the first job without a ledger:
   `forge-guard run --need-mb 3072 --threads 20 -- lua tools/production/resume_radio.lua JOB-ID`.

## Session handoff (2026-11-14, resume here)

**Music is PAUSED until the host's audio infra is built, admitted and loaded** (batch 1: real-instrument chain
FluidSynth/Carla + SFZ kits + NAM + LSP + Pedalboard/Matchering + R128; analysis, Audiobox/CLAP; ACE-Step 1.5
XL-SFT + 4B LM; VoxCPM2 48 kHz TTS; a ComfyUI audio node pack = the audio studio). The operator approved the
permissive licences. Demucs (internal use only) still needs the operator's /accept-licence on the host. Every new
model or node needs a tray rebuild AND a forge relaunch.

Read first: `plan/audio-studio/music-requirements.md` (on `game`, f2bc29a1): use cases, the game's asset contract,
generic host capabilities, first pilot (L3 Ember Moon via real instruments, auditioned before any adaptive cut).
The operator rejected ALL current music (in-game score, 27 campaign takes, turbo/base A/B); do not promote any.

On resume: `tillandsias_lane_version` current? `studio_models` lists the new audio nodes/models? Ask
macuahuitl-fedora for the node class names + PR, then build the L3 pilot pipeline.

Landed on `game` this session: /console path routing (24e71158); /studio route, NOTES on /studio, /gallery and
/console with copy-for-agent markdown, drafts that survive reload, gallery music muted (7c2788cc); the music spec
(f2bc29a1). Preview: `npm run build`, then preview.publish (reload after wrangler.jsonc edits).

### Game backlog (operator, 2026-11-14), CPU work that can proceed without the music infra

1. **Ground assets rework** (GPU art, start with design):
   - Human ground vehicles: a style guide (futuristic tanks), plus rotation frames for turning, like the
     player ship's banking frames.
   - Alien ground forces: a richer appearance and animation set (an RTS-style swarm army: original designs,
     genre inspiration only, no copying of any existing game's look). Builds on
     `openspec/changes/gargoyle-ground-army` (0/28 tasks; research + style guide in
     plan/gargoyle-army-*.md).
   - Goal: the ground battle as exciting as the air war.
2. **Radio chatter back to the middle:** duty is .16 now (comms-pacing cut it); raise it to about the midpoint.
   Add lines for cutscenes and transitions, wave reinforcements and similar moments. No line may cut another
   off: let each finish, plus a grace gap.
3. **Readable comms:** dive calls, ground-attack calls and the demon–human taunt exchanges must stay on screen
   long enough to read (per-line timeouts from text length).
4. **Wave arrival pressure:** the very first wave keeps its dramatic arrival. Reinforcements and later waves
   approach from a distance, and the next wave starts coming in before the current one ends (when the
   remaining enemies drop below a threshold), so players feel pressure to finish.
5. **Calmer transitions:** combine the overlapping transition tips and progress messages. Use transitions to
   show, alternately, (a) a silent tip over a game screenshot with the music playing, or (b) a full-screen
   radio message (desktop-style, centred in the play area) for the next mission: tips, banter, taunts, jokes.
   Everything stays fluid with the music.

## 1. Radio voices: `radio-bank-2026-11-12` (CPU, one guarded worker)

- [x] 1.1 Render the last 12 clips (562/574 done at 21:40 UTC):
      heavyArmorSighted-d3, -d4; groundTide-surge-h0..h4, -d0..d4. Done at about 22:05 UTC; 574/574 current, worker exited.
- [x] 1.2 Revalidate hashes across the whole spec: status.lua reports 574/574 current and 0 stale, so no refresh needed.
- [x] 1.3 Strict full-bank assembly: `radio-bank --out /home/forge/.cache/demon-attack/radio-bank-staging-full`
      validated 574/574 (385 human, 189 demon), 8.29 MB Opus, complete=true. `stage_radio_bank.lua` wrote the
      Dart bank (574 lines, all with measured clips) to `/home/forge/.cache/demon-attack/radio-bank-dart/`
      (persistent cache, not the PWA). Mouth/context review videos: `tools/production/mux_mouth_review.lua`.
- [ ] 1.4 Operator audition (clean, transformed, encoded). Promote only the complete accepted bank.

## 2. Campaign music (one epic composition that builds across waves and levels; radio must never duck it): `art/music/batch-2026-11-12.json` (host GPU studio)

- [x] 2.0 Host tray 56.11.14.3 loaded after the forge relaunch (lane current); AudioAdjustVolume admitted.
      - Log 2026-11-14: guides re-rendered (level-1 sha matches take 1). First headroom job (level-1-take-2,
        ticket tk-1794632349091-428592-0) still refused `node_not_pinned: AudioAdjustVolume`. The forge lane is
        stale (runs 56.11.10.1; 56.11.14.3 installed), so the new allowlist is not loaded. Relaunch the forge, then
        retry. Record: plan/render-runs/campaign-batch-2026-11-12/level-1-take-2-refusal.json. No bypass, nothing rendered.
- [x] 2.1 level-1-take-1 (first 96-bar candidate, retained).
- [x] 2.2 The other 26 requests through the headroom workflows (done 2026-11-14; 27/27 candidates ingested, peaks -7 to
      -14 dBFS, NaN/silence check passes on all 26 headroom takes; take 1 predates headroom and peaks at 0 dBFS). Level 4 and 5
      needed workarounds for NaN output: level-4 guide cut by one 40 ms frame (3839 frames), level-5 duration set to the guide
      length. Record: `campaign-batch-2026-11-12/levels-4-5-nan.json`; `art/music/batch-2026-11-12.json` shows what ran.
- [ ] 2.3 Check clipping, guide alignment and continuity; operator selects accepted takes.

## 3. Flyover and landmark rerolls (host GPU studio)

- [x] 3.1 Ember Forges `landmark/ember/2/forge-channel` came out as a sphere. The prompt now asks for a long low
      boxy hall with a straight molten trench and no round shapes (seed_offset 11). Rerolled through
      studio.run_workflow (job st-1794606171970-0, seeds 24221–24224). No spheres. Candidates and provenance are in
      `assets/research/flyover-reroll/landmark-ember-2-forge-channel/`. Seed 24221 is the spec-reproducible pick.
- [x] 3.1b Integrate the pick : packed in the 3.3 run (flyover-props.png). Python steps need
      `uv run --no-project --with numpy --with pillow python -I tools/flyover_assets.py ...`.
- [x] 3.3 Full flyover re-render (90/90 jobs, 0 failures, 40 min on the A5000 at SDXL). Same seeds and workflow
      reproduced every strip, plane and creature byte for byte, so only the forge-channel landmark changed.
      This proves exact rebuilds; it is NOT the quality upgrade. Analyzer clean, flyover tests pass.
- [ ] 3.4 Flyover quality upgrade (required; 3.3 only reproduced the old art): put all 90 flyover images through
      the same Qwen-Image-Edit-2511 + BiRefNet refinement as the sprite pilot (5.1), after the operator reviews
      the pilot. Steps: `jobs`, every job through studio.run_workflow,
      `ingest --results`, `process`, `pack`; operator review of `art/contact/flyover-*.png`.
- [ ] 3.2 Operator review of the reroll; real-phone flyover frame rate and perspective check.

## 4. Sprites (host GPU studio)

Shipped sprites are the 64-grid atlases (sprite-64-grid-overhaul), accepted by the operator on
2026-11-13. The research-branch candidates are history: 14 local-image candidates
(`research/local-image-asset-pipeline`, all REJECTED) and the FLUX ship parts
(`work/asset-review-progression`, superseded). Nothing there is resumable; re-render from the
current families instead.

- [ ] 4.1 Agree the target tier/model and order with the operator. Then re-render each family through its
      committed workflow and family spec, validating with `studio.validate_family`:
  - [ ] creatures and sentinels (`art/families/sprites`)
  - [ ] carrier (`art/families/carrier`)
  - [ ] ground forces (`art/families/ground-forces.json`)
  - [ ] ground troops (`art/families/ground-troops.json`)
  - [ ] flyover vegetation (`art/families/flyover-vegetation.json`)
  - [ ] widescreen backdrops (`art/families/widescreen-backdrops.json`)
- [ ] 4.2 Contact sheets and operator acceptance per family; repack atlases; run the gallery and tests.

## 5. Big-model refinement pilot

- [x] 5.1 Pilot: gargoyle, ally turret, ally rifleman via Qwen-Image-Edit-2511 + BiRefNet
      (`assets/research/refinement-pilot/`).
- [ ] 5.2 Operator review of the pilot; then refine each sprite family and the flyover (3.4) the same way.
- [ ] 5.3 New Undercroft Host units per `openspec/changes/gargoyle-ground-army`, and terrain poses per
      `openspec/changes/ground-terrain-interaction`.

## Log

- 2026-11-14 07:40 UTC: host audio research (licence-checked). Music: no commercial-OK open model does good metal;
  pilot ACE-Step 1.5 XL-SFT + 4B LM (MIT), fallback DiffRhythm (Apache). Real answer: symbolic route, MIDI rendered via
  FluidSynth/Carla + LSP, CC0/CC-BY SFZ drums, Karoryfer CC0 bass, VCSL CC0 orchestra/choir/organ, CC0 clean DI
  guitar through NAM (train our own captures). Stems: HTDemucs v4 (internal use only). Voices: VoxCPM2 (Apache,
  48 kHz, cloning) replaces Chatterbox; RVC for conversion. Mix/master: Pedalboard/DawDreamer, Matchering, loudnorm.
  Screening: Audiobox Aesthetics, CLAP. Avoid: CC-BY-SA / NC libraries, madmom models, Essentia (AGPL), FlashSR.
  Batch 1 awaits operator licence sign-off, then one rebuild + relaunch. Operator also made the ComfyUI-style audio
  studio top priority (asked of the host: ComfyUI + audio node pack).

- 2026-11-14 07:05 UTC: OPERATOR VERDICT: every campaign take and the l3 A/B (ACE-Step turbo vs base, 80 vs 256 kbps)
  is "quite bad"; l3-campaign-take-3 is the richest but too simple and not the battle-metal theme. The in-game
  adaptive music sounds "far worse than before" (runtime muxing regression to research). Radio voices sound
  low-res: measured hard 12 kHz band limit (Chatterbox 24 kHz). Music top end above 8 kHz is a noise floor (turbo).
  Do NOT promote any 2026-11-12 batch take. Asked the host session for: bigger music models (largest that fits the
  24 GB A5000), stem separation, voice bandwidth extension or a 48 kHz GPU TTS, and an audio mixing studio.
  Next: research plan (models, runtime muxing, audio studio) before any re-render.

- 2026-11-14 06:25 UTC: music batch complete, 27/27 candidates. Level 4/5 NaN traced with the host session to exactly
  3840 latent frames (level 4) and a duration 40 samples shorter than the guide (level 5); worked around, studio-side
  refusal requested from the host. Next: operator listening and take selection (2.3).

- 2026-11-14 06:15 UTC: relaunch verified (lane 56.11.14.3 current). Guides re-rendered (bit-identical), studio started,
  20 music takes rendered with 8 dB headroom and checkpointed (level 1-3, all bridges, ending, menu). Level 4/5 guides
  give NaN audio at full length; diagnostics in levels-4-5-nan.json. Operator choice needed on the fix.

- 2026-11-14 00:20 UTC: operator rule: music volume is constant; radio never ducks it. Radio airtime target cut to
  about 15-25 percent so the score carries the game.

- 2026-11-14 00:10 UTC: operator audition: most radio clips much better; some human clips flat, some demon clips
  lack growl or sound uncompressed. Tagging comes via the new /console notes; tagged clips re-render on CPU with
  several workers (no GPU voice service soon). Try a pitch, formant and saturation post-process for growl.
  Agents on work/game-polish: comms pacing, ending after boss 5 plus unranked console runs, asset studio and notes.

- 2026-11-13 23:45 UTC: FLUX.1-dev and SD3.5 are off (gated; needs an HF login). Qwen-Image text-to-image
  (Apache-2.0) is being admitted as the big text-to-image model. The audition build's source is pushed as
  `work/radio-bank-audition`.

- 2026-11-13 23:30 UTC: refinement pilot committed; radio-bank preview served locally from an uncommitted worktree
  build (/home/forge/.cache/tillandsias-project/worktrees/radio-preview).

- 2026-11-13 23:00 UTC: cgroup uncapped by the operator; flyover 3.3 done and packed. Admitted big models (host register):
  Qwen-Image-Edit-2511, FLUX.2-klein-4B, Wan2.2-VACE, BiRefNet matting, SDXL family. FLUX.1-dev and SD3.5 need licence
  acceptance. 4x upscaler and GPU voice service coming upstream.
- 2026-11-13 22:10 UTC: radio bank complete and strictly assembled; full flyover re-render (3.3) running on the studio, one job at a time.
- 2026-11-13 21:58 UTC: radio at heavyArmorSighted-d4 done; Ember forge-channel rerolled (3.1).

- 2026-11-13 21:40 UTC: forge restart had dropped the cache symlink. Bootstrap restored the runtime
  from the persistent cache, and the radio controller resumed at heavyArmorSighted-d3.
