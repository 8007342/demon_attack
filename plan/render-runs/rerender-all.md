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

1. `pgrep -af 'model_worker|resume_radio'`. Never start a second controller or worker.
2. `/home/forge/.cache/demon-attack` must be a symlink to
   `/home/forge/.cache/tillandsias-project/demon-attack`. If it is missing, run
   `lua tools/production/bootstrap_radio.lua`. If it is a plain directory, the
   resume script created it before bootstrap; inspect it, move it aside, then bootstrap.
3. `lua tools/production/status.lua tools/production/radio-bank-2026-11-12.lua`, then
   resume from the first job without a ledger:
   `forge-guard run --need-mb 3072 --threads 20 -- lua tools/production/resume_radio.lua JOB-ID`.

## 1. Radio voices: `radio-bank-2026-11-12` (CPU, one guarded worker)

- [ ] 1.1 Render the last 12 clips (562/574 done at 21:40 UTC):
      heavyArmorSighted-d3, -d4; groundTide-surge-h0..h4, -d0..d4. Running since 21:47 UTC.
- [ ] 1.2 Revalidate hashes across the whole spec; refresh stale records with content-keyed audio.
- [ ] 1.3 Strict full-bank assembly; timing and mouth validation.
- [ ] 1.4 Operator audition (clean, transformed, encoded). Promote only the complete accepted bank.

## 2. Campaign music: `art/music/batch-2026-11-12.json` (host GPU studio)

- [ ] 2.0 **Blocked:** wait for the host tray rebuild with tillandsias PR #1091
      (AudioAdjustVolume pinned). The host session will report when it's ready. Don't bypass admission.
- [x] 2.1 level-1-take-1 (first 96-bar candidate, retained).
- [ ] 2.2 The other 26 requests through the headroom workflows, in batch order:
      level-1 takes 2–3; level-2..5 takes 1–3; bridges 1-2, 2-3, 3-4, 4-5 (takes 1–2); ending takes 1–2; menu takes 1–2.
      Keep every ticket and result receipt, then run the matching music-bank job.
- [ ] 2.3 Check clipping, guide alignment and continuity; operator selects accepted takes.

## 3. Flyover and landmark rerolls (host GPU studio)

- [ ] 3.1 Ember Forges `landmark/ember/2/forge-channel` came out as a sphere: revise the prompt in
      `art/families/flyover-backgrounds.json`, then `tools/flyover_assets.py run --only landmark/ember/2/forge-channel`.
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

## Log

- 2026-11-13 21:40 UTC: forge restart had dropped the cache symlink. Bootstrap restored the runtime
  from the persistent cache, and the radio controller resumed at heavyArmorSighted-d3.
