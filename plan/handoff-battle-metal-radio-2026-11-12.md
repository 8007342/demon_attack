# Handoff: Battle Metal score and radio bank

Branch: `work/battle-metal-radio-rework`. Latest verified remote checkpoint at handoff refresh: `d0217d7` (`regroupStart-d0`); the controller had started `regroupStart-d1`. Checkpoints are serialized by `tools/production/checkpoint.lua` and pushed to this remote work branch. Forge-local caches and any uncheckpointed work are disposable.

## Live radio production

The supervised radio controller and model worker are live. Controller command:

```sh
lua tools/production/resume_radio.lua groundForceSighted-h10 \
  >> /home/forge/.cache/demon-attack/campaign-batch-2026-11-12/radio-supervised.log 2>&1
```

At handoff refresh, `groundUnitDestroyed-h2` had checkpointed and the supervisor was continuing. A transient `.git/index.lock` collision had stopped the controller while checkpointing the completed `allyRetreated-d2`; after confirming no Git process remained, its exact generated outputs and done ledger were checkpointed manually as `6355a15`, then the controller resumed. The failed job was not lost or rerendered. Check the controller/worker and latest log before restarting; never start a second controller. It recycles the model worker every 40 jobs and stops on a job failure. Observed forge limits: 20 CPUs exposed and the worker uses about 15 cores; cgroup memory.max is 12 GiB (current about 10.7 GiB), despite 62 GiB host memory being visible. Host GPU status reports 23.07 GiB VRAM free, but the Chatterbox torch build reports CUDA unavailable in this forge, so voice rendering is CPU-bound. Avoid parallel workers under the present cgroup limit. Each completed clip is pushed immediately through the checkpoint helper.

Latest partial audio audit: 403/574 clips (255 human, 148 demon), 5.72 MB Opus; production is still running, so this is a moving count. Re-run the partial audit for current measured progress:

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

## Crash recovery — 2026-11-13 02:03 UTC

Fetched all origin refs; newest remote tip was `4f282d83` on this branch.
Recovered 505/574 current completed radio ledgers, zero stale, with 69 pending;
first pending job is `convoyStuck-h0`. No controller/worker survived the crash.
Restored the pinned runtime and ffmpeg. Fixed bootstrap Chatterbox download
selection to use `hf download --include`; fix pushed as `1cdccf1f`.
Restarted exactly one foreground-session guarded supervisor with:

```
forge-guard run --need-mb 3072 --threads 20 -- lua tools/production/resume_radio.lua convoyStuck-h0
```

Output appends to the existing radio-supervised.log in the project cache.
Check live processes and current ledgers before any restart. Retained earlier
log entries alone do not prove a worker is alive. Completed jobs still push via
the checkpoint helper; final bank assembly and creative review remain pending.
Studio started successfully. Retried the committed campaign-a2a-headroom
workflow through the host tool; admission still refuses `AudioAdjustVolume`
with `node_not_pinned`. No music render queued. Host node allowlist repair is
still required; do not bypass admission.

## Local integration — 2026-11-13 02:12 UTC

Radio paused after a successful checkpoint to serialize model memory with
Flutter verification. Reached 526/574 complete, zero stale/failed. Targeted
Flutter tests (54), Node audio/Worker tests (30), changed-runtime analysis,
strict active-change validation and release app/gallery builds passed.
`game` fast-forwarded and remotely pushed to `5f9d1d06`, including the maintainer
report `FORGE_DIAGNOSTICS.md`. Production main was not advanced. Research media
remain outside the deployed PWA asset set. Managed Wrangler preview is live at
https://www.demon-attack.localhost:18443; score API returns 200. Desktop/phone
loaded; missing arrow glyphs and browser-control limitations are documented in
the diagnostics report. This is a local smoke check, not full campaign approval.
Radio supervisor resumed on the work branch at `groundSkirmish-h1` after builds.
Check live state before restarting. Music admission remains blocked.
