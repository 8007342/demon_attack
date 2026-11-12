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
