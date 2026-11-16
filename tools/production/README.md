# Recoverable production trials

Run trusted, committed Lua job specifications from the repository root:

```
lua tools/production/run.lua tools/production/campaign-guides.lua
```

The runner serializes each run with flock, writes atomic per-job Lua ledgers in
`plan/render-runs/<id>/`, fingerprints the job file, runner, declared inputs and
arguments, and verifies every output SHA-256 before skipping a completed job.
Interrupted jobs and missing/changed outputs run again. Jobs must themselves be
safe to retry. Failed commands stop the run. Keep large temporary files off the
checkout; wrap model adapters in forge-guard to bound memory, threads and time.

With `checkpoint=true`, each successful job commits its ledger and explicit
`assets/research/` outputs on a work branch and pushes it. An interrupted push is
retried on resume. Pushes do not certify creative acceptance. Checkpoint the job
specification and adapters separately before launching. Do not run another Git
writer concurrently with a checkpointing runner.

This initial runner is for bounded trials. It does not implement GPU scheduling,
remote object storage, model installation, musical composition, or listening
acceptance. Full-bank production remains pending those requirements. The host
studio tools own admission and model licence validation for GPU workflows.

## Full cast / campaign batch

After a cold forge start, restore the Python env, Kokoro and ffmpeg with
`lua tools/production/bootstrap_radio.lua` (it never starts a render). The
2026-11-12 radio bank was rendered by a resident CPU Chatterbox worker
(`model_worker.py`, `resume_radio.lua`, `voice_job.lua`, `voice_bank_job.lua`,
`voice-trial.lua`, `radio-bank-2026-11-12.lua`). Chatterbox was dropped on
2026-11-16 (operator, change `voice-stack`), and those files were removed; the
ledgers under `plan/render-runs/radio-bank-2026-11-12/` stay as the record, and
`git log -- tools/production/model_worker.py` recovers them. New voice batches
render VoxCPM2 speech and Dia non-verbals as admitted host-studio workflows,
queued one at a time by a new batch job (voice-stack task 4.1).

`run.lua SPEC.lua JOB-ID` runs one selected job. Per-job inputs are hashed along
with global inputs. `status.lua SPEC.lua` reports current versus stale completed
records after a source edit. `checkpoint.lua` holds a repository-wide flock for
the complete commit/push transaction, so CPU and admitted host-GPU jobs can
checkpoint independently. Stop the scheduling runner and drain its current model
request before changing production source inputs; resume revalidates all hashes.
The worker imports code once, so code changes require a worker restart.

The 27 GPU requests are in art/music/batch-2026-11-12.json. Host studio tools own
node/model admission. The first 96-bar level candidate completed. The new
pre-export headroom workflows are currently refused because AudioAdjustVolume
is absent from the host node allowlist. Do not bypass that refusal with a direct
ComfyUI POST. After the operator refreshes admission, use the headroom workflows,
keep every ticket/result receipt, then run the matching music-bank selected job
to preserve source, provenance, preview and measurements remotely. To restore
missing plan/*-host.json receipts, copy their retained music/<job>/host-job.json
counterparts before resuming. Source audio alone does not certify artistic quality.
