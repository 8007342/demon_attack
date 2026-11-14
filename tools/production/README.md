# Recoverable production trials

Run trusted, committed Lua job specifications from the repository root:

```
lua tools/production/run.lua tools/production/voice-trial.lua
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

After a cold forge start, restore the required external dependencies with
`lua tools/production/bootstrap_radio.lua`. It restores the frozen installed
package versions (including recorded dependency overrides), downloads the pinned
Kokoro and Chatterbox models through their SDK CLI, and provisions ffmpeg through
the forge shim. The actual cache lives under the persistent project volume;
the original absolute path is a symlink so existing render fingerprints remain
valid. This bootstrap never starts a render or marks a candidate accepted.

Resume with `forge-guard run --need-mb 3072 --threads 20 -- lua
tools/production/resume_radio.lua JOB-ID`. Find the first unfinished job from
the ledgers; do not infer it from an old handoff. This controller starts the
resident worker automatically. Calling `run.lua` alone requires a worker that
is already running.

`radio-bank-2026-11-12.lua` schedules all 574 lines. Start the single local
`model_worker.py` adapter under forge-guard with HF_HOME/COMMS_WORK pointing to
the restored model cache. It retains required Kokoro/Chatterbox instances,
serves only localhost:18851, and exits after 15 idle minutes. Do not launch
multiple model workers. Per-clip jobs retain 24-bit PCM FLAC baseline, expressive
and transformed voice masters, Opus radio, and source/model/timing metadata.
Float-source hashes and any master gain are explicit. These are candidates;
logged fallback engines and listening decisions must be reviewed before promotion.

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
