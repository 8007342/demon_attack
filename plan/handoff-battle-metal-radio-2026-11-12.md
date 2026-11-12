# Handoff: Battle Metal score and radio bank

Branch: `work/battle-metal-radio-rework`. Latest upstream checkpoint:
`be5e156` (`allyUnderAttack-d7`). Continue to checkpoint every completed
clip with `tools/production/checkpoint.lua`; forge-local caches are disposable.

## Live work

The supervised radio controller and resident model worker were confirmed live
at handoff. The controller is running:

```sh
lua tools/production/resume_radio.lua allyUnderAttack-d8 \
  > /home/forge/.cache/demon-attack/campaign-batch-2026-11-12/radio-supervised.log 2>&1
```

It was at `allyUnderAttack-d8` after `allyUnderAttack-d7` was pushed. Check the
live process and latest log before restarting; do not start a second controller
or model worker. It recycles the model worker every 40 jobs and stops on a job
failure. Each clip checkpoints to the remote work branch.

Last full audio audit accepted 286/574 clips (203 human, 83 demon), 4.19 MB
Opus. This is an older point-in-time count; rerun the audit for current state:

```sh
/home/forge/.cache/tillandsias-project/bin/radio-bank --allow-partial \
  --out /home/forge/.cache/demon-attack/radio-bank-staging
```

The production ledger previously showed 29 current done, 258 stale, 1 running,
0 failed, 286 pending. Stale ledgers reflect the strict worker input hash
changing when concurrency increased to 20 threads. Preserve that validation:
after pending jobs finish, run the complete spec to refresh stale records using
content-keyed cached audio; then run strict full-bank assembly, mouth/timing
validation and final review. Do not promote the partial staging bank.

## Music blocker

Music has one rendered candidate out of 27. The studio is available, but its
admission check refuses `AudioAdjustVolume` as `node_not_pinned`. Retry the
committed workflow only through the host studio tool after the forge allowlist
changes; it currently rejects before queueing. Do not post directly to
ComfyUI or bypass the node check. Raw FLAC exports hit full scale, so headroom
must be added before integer export. The blocker record is
`plan/render-runs/campaign-batch-2026-11-12/headroom-blocker.json`.

## Other verified work and open acceptance

- Linked radio UI, stable alien script, compressed browser audio, credits and
  beach ending implementation are pushed. Ending tests cover time/progression
  preservation and final score entry.
- CPU trial: same expressive clip took 10.42 s at 20 threads versus 12.09 s at
  four threads. Worker recycling and three immediate socket-reuse restarts
  passed smoke verification.
- Two synchronized candidate mouth previews and provenance are retained under
  `assets/research/battle-metal-radio/mouth-review-2026-11-12/`; all-cast
  geometry tests pass. Listening, broader contextual mouth review and final
  visual/audio acceptance are still open.
- Production PWA assets have not been replaced. No music candidate has passed
  human audition; no complete radio bank has passed strict validation.

Read `plan/battle-metal-radio-production.md`, the active OpenSpec change and
`plan/render-runs/campaign-batch-2026-11-12/cpu-and-recovery.md` for the longer
production record and requirements. Keep the goal open until all music and
radio work is complete, reviewed and remotely checkpointed.
