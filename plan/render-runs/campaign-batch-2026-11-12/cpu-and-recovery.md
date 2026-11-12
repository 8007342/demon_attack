# CPU benchmark and recovery — 2026-11-12

The host exposes 20 logical CPUs with no cgroup CPU quota. The forge's
read-only memory.max is 12 GiB and memory.high is 10.2 GiB; the host's 64 GB
is not all allocated to this container. Studio GPU work uses a separate
container and its own allocation.

After 218 completed radio jobs, the resident model worker grew to the guard's
8.7 GiB pinned-memory threshold and was terminated. The scheduler then failed
at `flawlessVictory-h3`. Completed outputs were already remotely checkpointed.

A serial fresh-process comparison used the same `sectorStart.h4` text, seed,
reference, model revision and acceptance settings in an isolated cache. With
20 Torch/OMP/MKL threads its expressive stage took 10.42 seconds; with four
threads it took 12.09 seconds. This single-clip trial supports using 20 threads
for the resumed batch; it is not a full-corpus throughput benchmark.

`tools/production/resume_radio.lua` now owns one worker at a time and recycles
it between groups of 40 jobs, outside active requests. It kills only its exact
child PID and confirms termination before starting another. A flock prevents
duplicate controllers. A failed job stops production; `run.lua` retains its
atomic failure record. Resume began at the failed job, with all remaining jobs
still individually hash-verified and remotely checkpointed.

Changing the worker's thread policy changes its input hash. Earlier completed
ledgers therefore become stale under strict orchestration validation. Before
final acceptance, run the full spec again to refresh those records using the
content-keyed existing model takes, then assemble/validate all 574 candidates.
Do not claim partial metadata or a resumed range proves full-bank completion.

The ending interface's isolated widget checks pass, and integration checks
exercise preserved score/lives/medals and frozen time while the route is open,
first-tour continuation, and final-campaign score entry after closing it.
Final music, visual review and complete media acceptance remain pending.

The first 40-job group finished and pushed through job 258, then restart failed
with `EADDRINUSE`: the HTTP server had not enabled socket reuse. The old worker
was confirmed gone before recovery. `WorkerServer.allow_reuse_address = True`
fixes subsequent immediate binds; `resume_radio.lua --smoke` started, health
checked, terminated and immediately restarted the actual worker three times
successfully without loading models. Production then resumed at job 259,
`groundForceSighted-h10`. No completed clip was lost.
