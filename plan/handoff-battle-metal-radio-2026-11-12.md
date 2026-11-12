# Handoff: Battle Metal score and radio bank

Branch: `work/battle-metal-radio-rework`. Latest verified remote checkpoint at handoff preparation: `d378499` (`allyRetreated-h0`). Checkpoints are serialized by `tools/production/checkpoint.lua` and pushed to this remote work branch. Forge-local caches and any uncheckpointed work are disposable.

## Live radio production

The supervised radio controller and model worker are live. Controller command:

```sh
lua tools/production/resume_radio.lua groundForceSighted-h10 \
  >> /home/forge/.cache/demon-attack/campaign-batch-2026-11-12/radio-supervised.log 2>&1
```

At handoff refresh, it had just started `allyRetreated-h1` after `allyRetreated-h0` checkpointed. Check the controller/worker and latest log before restarting; never start a second controller. It recycles the model worker every 40 jobs and stops on a job failure. Each completed clip is pushed immediately through the checkpoint helper.

The last full audio audit recorded 294/574 clips (208 human, 86 demon), 4.30 MB Opus; this predates recent completions and is not a current count. Re-run the partial audit for current measured progress:

```sh
/home/forge/.cache/tillandsias-project/bin/radio-bank --allow-partial \
  --out /home/forge/.cache/demon-attack/radio-bank-staging
```

The production ledger last showed substantial stale records after the strict worker input hash changed when concurrency increased to 20 threads. Once pending jobs finish, refresh stale records using content-keyed cached audio, then run strict full-bank assembly, mouth/timing validation, and human review. Do not promote a partial staging bank.

## Music blocker

Music has one rendered candidate out of 27. The studio is available, but admission refuses the committed workflow `art/workflows/music/campaign-a2a-headroom.json` because `AudioAdjustVolume` is `node_not_pinned`. It rejected before queueing. Retry only through the host studio tool after the forge allowlist changes; do not post directly to ComfyUI or bypass admission. Raw FLAC exports hit full scale, so headroom must be applied before integer export. Blocker record: `plan/render-runs/campaign-batch-2026-11-12/headroom-blocker.json`.

## Other verified work and acceptance still open

- Linked radio UI combines paired human/demon comebacks into a full-width conversation toast with portraits and both language/translation texts; isolated messages use half-width toasts.
- Stable alien script, compressed browser audio, credits, beach ending, and score/progression behavior are pushed. Ending tests cover timing/progression preservation and final score entry.
- CPU trial: same expressive clip took 10.42 s at 20 threads versus 12.09 s at four. Worker recycling and three immediate socket-reuse restarts passed smoke verification.
- Two synchronized candidate mouth previews and provenance are retained under `assets/research/battle-metal-radio/mouth-review-2026-11-12/`; all-cast geometry tests pass. Listening, broader contextual mouth review, and final visual/audio acceptance remain open.
- Production PWA assets have not been replaced. No music candidate has passed human audition; no complete radio bank has passed strict validation.

Read `plan/battle-metal-radio-production.md`, the active OpenSpec change, and `plan/render-runs/campaign-batch-2026-11-12/cpu-and-recovery.md` for the production record and requirements. Keep the goal open until music and radio are complete, reviewed, and remotely checkpointed.
