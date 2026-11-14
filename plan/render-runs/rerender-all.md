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

## 1. Radio voices: `radio-bank-2026-11-12` (CPU, one guarded worker)

- [x] 1.1 Render the last 12 clips (562/574 done at 21:40 UTC):
      heavyArmorSighted-d3, -d4; groundTide-surge-h0..h4, -d0..d4. Done at about 22:05 UTC; 574/574 current, worker exited.
- [x] 1.2 Revalidate hashes across the whole spec: status.lua reports 574/574 current and 0 stale, so no refresh needed.
- [x] 1.3 Strict full-bank assembly: `radio-bank --out /home/forge/.cache/demon-attack/radio-bank-staging-full`
      validated 574/574 (385 human, 189 demon), 8.29 MB Opus, complete=true. `stage_radio_bank.lua` wrote the
      Dart bank (574 lines, all with measured clips) to `/home/forge/.cache/demon-attack/radio-bank-dart/`
      (persistent cache, not the PWA). Mouth/context review videos: `tools/production/mux_mouth_review.lua`.
- [x] 1.4 Operator audition: mostly much better; bank promoted into `game` (546e7874). Flat or growl-less clips are
      being tagged in /gallery/?page=studio. See 1.5.
- [ ] 1.5 Re-render the tagged clips (CPU, several workers; growl via pitch, formant and saturation post-processing).

## 2. Campaign music (one epic composition that builds across waves and levels; radio must never duck it): `art/music/batch-2026-11-12.json` (host GPU studio)

- [ ] 2.0 **Blocked:** wait for the host tray rebuild with tillandsias PR #1091
      (AudioAdjustVolume pinned). The host session will report when it's ready. Don't bypass admission.
- [x] 2.1 level-1-take-1 (first 96-bar candidate, retained).
- [ ] 2.2 The other 26 requests through the headroom workflows, in batch order:
      level-1 takes 2–3; level-2..5 takes 1–3; bridges 1-2, 2-3, 3-4, 4-5 (takes 1–2); ending takes 1–2; menu takes 1–2.
      Keep every ticket and result receipt, then run the matching music-bank job.
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
  - [x] creatures and sentinels (`art/families/sprites`)
  - [x] carrier (`art/families/carrier`)
  - [x] ground forces (`art/families/ground-forces.json`)
  - [x] ground troops (`art/families/ground-troops.json`)
  - [x] flyover vegetation (`art/families/flyover-vegetation.json`)
  - [ ] widescreen backdrops (`art/families/widescreen-backdrops.json`)
- [ ] 4.2 Contact sheets and operator acceptance per family; repack atlases; run the gallery and tests.

## 5. Big-model refinement pilot

- [x] 5.1 Pilot: gargoyle, ally turret, ally rifleman via Qwen-Image-Edit-2511 + BiRefNet
      (`assets/research/refinement-pilot/`).
- [x] 5.2 Operator approved the pilot (2026-11-14). Refinement batch runs on `work/refinement-pass`: every sprite
      family, then the flyover (3.4), one GPU job at a time, pushed per family. This also settles 4.1 (Qwen-Image-Edit-2511 + BiRefNet).
- [ ] 5.3 New Undercroft Host units per `openspec/changes/gargoyle-ground-army`, and terrain poses per
      `openspec/changes/ground-terrain-interaction`.

## Log

- 2026-11-14 01:34 UTC: refinement pass, flyover vegetation: 10 species refined (seeds 641500-641590), 0 rerolls, 0 skipped. Prompts describe what each shipped source actually shows (several first-pass SDXL sources drifted from their spec prompts, e.g. ice-crystal-shrub and ruin-rubble hold two objects); only the luminance high-pass reaches the atlas. Atlas rebuilt with `go run . offline`; vegetation_atlas.dart unchanged. Sheet: art/contact/refine-flyover-vegetation.png. Analyze clean, 384 tests pass.

- 2026-11-14 01:25 UTC: refinement pass, carrier and boss armada: 4 texture sources refined (hide 641400, masonry 641410, membrane 641420, plating 641430), 0 rerolls, 0 skipped. Full-frame surface textures, so no BiRefNet matte (nothing to cut out); masters kept opaque. Carrier detail maps and all five boss-*.png atlases rebuilt; geometry, anchors and palettes unchanged. Sheet: art/contact/refine-carrier.png. Analyze clean, 384 tests pass.

- 2026-11-14 01:19 UTC: refinement pass, creatures and sentinels: 4 gargoyle keyframes refined (violet reuses pilot seed 641101; teal 641110, coral 641120, gold 641130), 0 rerolls, 0 skipped. Keyframes are flattened on light grey for the colour-key finish; detail maps and combat.png rebuilt, ship-weapons, sentinel-effects and boss atlases byte-identical (fully procedural, no AI source to refine; ship-parts.png is not loaded by lib/). No molt sources exist (molts reuse the hide map). Every frame comes from one detail map, so no drift. Sheet: art/contact/refine-creatures.png. Analyze clean, 384 tests pass.

- 2026-11-14 01:13 UTC: refinement pass, ground forces: 10 refined (ally-ember reuses pilot seed 641200; demon-krybor/ringfall/ember/hollow 641210-641240, missile 641250, ally-krybor/ringfall/hollow 641260-641280, explosion 641290), 0 rerolls, 0 skipped. ally-ringfall came out grey-green; harmless because the pack keeps only the luminance high-pass and the reserved ally ramp. Sheet: art/contact/refine-ground-forces.png. Analyze clean, 384 tests pass.

- 2026-11-14 01:05 UTC: refinement pass, ground troops: 4 refined (ally-rifle reuses pilot seed 641300; ally-rocket 641310, demon-grunt 641320, demon-rocketeer 641330), 0 rerolls, 0 failures. demon-tank skipped (waits for the gargoyle-army redesign). Sources of record are bbox-fitted area downscales of the matted masters; the atlas rebuilds through `go run . offline` (frames stay procedural, the refined source drives the shading texture). Sheet: art/contact/refine-ground-troops.png. Analyze clean, 384 tests pass.

- 2026-11-14 01:50 UTC: operator approved the refinement pilot; batch started on work/refinement-pass with a babysitter.
  Asked the host for ETAs on #1092/#1091/#1093 and which fixes can land without a relaunch.

- 2026-11-14 01:30 UTC: work/game-polish merged to game (546e7874): radio bank, comms pacing (17-20% airtime, no
  overlap), constant music, end-aligned dive and ground warnings (predicted; firing unchanged), final-boss-only
  ending, unranked console runs, asset review studio and notes. 384 Flutter tests and 35 Worker tests pass.
  Preview notes sync returns 503: the managed preview does not load .dev.vars; notes save in the browser and export.

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
