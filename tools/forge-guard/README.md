# forge-guard

A small Go tool that stops heavy local jobs from stalling the shared forge.

## Why it exists

On 2026-11-10 four parallel Chatterbox (torch) workers stalled the forge for about 1.5 h:

- **Sized from the host:** the job took its worker count from `nproc`, which reports the host's 20 CPUs. It started 4 workers × 5 threads, each loading its own model copy.
- **Soft limit, silent stall:** the forge cgroup's limit is a soft `memory.high` (about 10.2 GiB here). Crossing it kills nothing; the kernel reclaims forever (9 million `high` events), so every process slows to a crawl and no error ever shows up.
- **Killed workers came back:** the Python multiprocessing pool respawned workers that were killed.
- **Waits that never ended:** agents waited with `until ! pgrep -f <name>`, and the pattern matched the waiting shell's own command line, so the wait could never finish.

## Use

Build it once (it's already built at `~/.cache/tillandsias-project/bin/forge-guard`):

```bash
go build -o ~/.cache/tillandsias-project/bin/forge-guard ./tools/forge-guard
```

Wrap every heavy local job, such as torch or ML inference, big image or audio batches, or `flutter build web`:

```bash
G=~/.cache/tillandsias-project/bin/forge-guard
$G run -- python -I tools/comms_pipeline.py expressive --workers 1
$G run --need 4 --threads 6 -- cargo run --release -p terrain-gen
```

What `run` does:

- **Queues heavy jobs:** it takes a forge-wide flock (`--lock heavy` by default), so heavy jobs from different agents run one at a time.
- **Waits for headroom:** it starts the job only once `--need` GiB (default 3) is free under `memory.high`, counting anonymous memory plus shmem/tmpfs.
- **Caps threads:** it limits OMP, MKL, OpenBLAS, numexpr, torch, rayon and GOMAXPROCS threads (`--threads`, default 4).
- **Fails loudly instead of stalling:** it kills the job's whole process group (TERM, then KILL, exit 137, reason printed) when pinned memory stays above `--kill-at` (default `memory.high` − 1.5 GiB), or the `memory.high` reclaim rate stays above `--max-events`/s, for `--grace` seconds (default 20).

To wait for a background job, never `pgrep -f`; use:

```bash
$G wait --pid 12345            # until that PID exits
$G wait --file out/done.flag   # until a done-file exists
$G status                      # memory, reclaim events, current lock holder
```

Exit codes: the job's own code, `137` when the guard kills the job, `75` when it gives up waiting for the lock or for headroom (`--start-timeout`), and `124` when `wait` times out.
