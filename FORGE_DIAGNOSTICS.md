# Demon Attack: outstanding blockers and recovery

Observed 2026-11-13 UTC on `work/battle-metal-radio-rework` after crash recovery.
For forge maintainers. This report distinguishes infrastructure failures from
unfinished production and human acceptance. No credentials are required below.

## 1. Music generation: host node admission refuses the headroom workflow

**Active infrastructure blocker; confirmed again at 02:02 UTC.**

- Studio starts successfully and reports its ComfyUI service available.
- Calling host `studio.run_workflow` with committed workflow
  `art/workflows/music/campaign-a2a-headroom.json` returns:

  ```
  node_not_pinned: AudioAdjustVolume is not a ComfyUI core node nor one of a pinned custom-node package (images/imagegen-studio/node-classes.tsv); the studio runs only pinned nodes
  ```

- Admission rejects before queueing. One of 27 campaign music candidates was
  retained previously; remaining rendering is held. Raw exports reach full
  scale, so attenuation must happen before integer export; lowering the volume
  of an already clipped FLAC cannot restore its peaks.
- **Maintainer action:** verify the installed built-in AudioAdjustVolume class
  (`comfy_extras.nodes_audio`) against the pinned ComfyUI version, update the
  host core-node allowlist/package pin, and refresh the deployed admission
  service. Keep licence and node checks enabled.
- **Verify/unblock:** retry the committed workflow through the host studio tool
  with its declared guide inputs. Retain host receipts, inspect headroom and
  duration, then run the corresponding music-bank ingestion job and audition.
  Do not POST directly to ComfyUI to bypass admission.
- Evidence: `plan/render-runs/campaign-batch-2026-11-12/headroom-blocker.json`,
  `art/music/batch-2026-11-12.json`, `tools/production/music-bank-2026-11-12.lua`.

## 2. CPU voice production and shared memory budget

**Throughput/resource constraint; radio generation itself is working.**

- This forge exposes 20 CPUs but memory.max is 12,884,901,888 bytes (12 GiB),
  memory.high 10,951,327,744 bytes (about 10.2 GiB). Host RAM is not the budget.
- At 02:07 UTC the single worker had about 5.7 GiB RSS; total cgroup memory was
  about 9.6 GiB. Do not overlap Flutter builds and model work at this pressure.
- The recorded Chatterbox Torch build reports CUDA unavailable inside the
  forge; GPU inference works separately through host studio. Voice rendering
  is CPU-bound. This is not evidence that the host GPU is broken.
- **Maintainer action (optional acceleration):** provide a supported admitted
  voice inference service/adapter using the host GPU, or a correctly matched
  runtime/device allocation; validate model licences and actual CUDA execution.
  Do not expose a container socket or start nested containers in the forge.
- **Current workaround:** one guarded worker, 20 threads, recycle every 40
  jobs, per-clip hash records and immediate remote checkpoints. Serialize heavy
  builds with voice production. Do not start multiple workers.
- Production recovered 505/574 complete clips after the crash. The count is
  moving; use `lua tools/production/status.lua
  tools/production/radio-bank-2026-11-12.lua` for current metadata status.
  This status checks input freshness; final runner/output hashes and complete
  bank validation are still required. Do not confuse a partial ledger with
  accepted assets.

## 3. Crash recovery and tool bootstrap

**Radio bootstrap repaired; operational caveats remain.**

- No controller or model worker survived the session crash. Remote checkpoints
  did survive; persistent cache also happened to remain available. Neither a
  local log nor a model cache alone proves an active or durable job.
- Cold-start bootstrap originally passed multiple Chatterbox filenames as
  positional `hf download` arguments, rejected by the pinned CLI. Fixed with
  `--include` in commit `1cdccf1f`; model restoration then succeeded.
- The ffmpeg provisioning shim installed ffmpeg 9.0.2, but its first invocation
  printed `Unrecognized option '-formula'`. Calling the installed binary
  directly succeeded and bootstrap finished. **Maintainer action:** check shim
  argument forwarding after on-demand Homebrew installation; reproduce on a
  cold forge with `ffmpeg -version` and ensure the user's argv is preserved.
- A shell-backgrounded supervisor did not stay alive after its command session
  ended. A retained foreground exec session works. **Maintainer action:**
  provide/document a supported persistent task supervisor with exit/error
  reporting if jobs are expected to survive agent/session termination. A forge
  restart still requires restoring dependencies and restarting from ledgers.
- Never restart blindly: inspect exact supervisor/worker PIDs, verify no active
  Git transaction, and find the first unfinished job from the current spec.
  See `tools/production/README.md` and the handoff for commands. The checkpoint
  helper uses `.git/production-checkpoint.lock`; serialize other Git writers
  with that lock. Never delete an active index lock.

## 4. Cloud usage observability

**Partial telemetry failure; not a Cloudflare build blocker.**

Host `cloud.usage` at 02:06 UTC reported all GitHub metrics unavailable with
`github:transport` (cache, Actions timing and billing; queried repositories
were tillandsias and macron.dev, not a Demon Attack Actions audit).
**Maintainer action:** inspect the host GitHub transport/auth/network path and
retry; unavailable must not be interpreted as zero usage.

Cloudflare telemetry succeeded: 236.3/3,000 monthly build minutes, zero running,
177.0 minutes attributed to demon-attack. These are the tool's summed build
wall-time estimates. A new build is affordable within this observed allowance;
this does not establish production readiness or future account usage.

## 5. Production acceptance and application work still preventing final release

**Project work/review, not forge infrastructure defects.**

The candidate masters are under `assets/research/battle-metal-radio/`; they are
not promoted into the PWA. Runtime UI/playback/ending changes can be tested with
the existing production bank independently of the blocked new score.

- Finish all 574 radio clips; revalidate hashes across the entire spec, refresh
  any stale metadata using content-keyed audio, assemble the strict full bank,
  verify final timings/mouths, audition clean/transformed/encoded voices, and
  only then promote the complete accepted bank. Never promote partial staging.
- After admission repair, render/review the remaining campaign score, inspect
  clipping, guide alignment and musical continuity, preserve masters and
  provenance remotely, and select accepted takes.
- Finish phrase/section-aware transitions and bridges, synchronized stems and
  accents, compression audition, pause/resume, event-density and full campaign
  decoded-memory checks with the final long-form assets. The 64 MiB decoded
  cache limit is not proof of total browser memory usage.
- Verify contributor/dependency/model credits against project records; finish
  beach-ending music/visual acceptance and phone mouth/context review. Existing
  ending implementation and tests do not close all creative acceptance tasks.
- Complete full phone/desktop campaign playtesting and all final OpenSpec
  acceptance checks before a production release. Also outstanding in the older
  roadmap: real-phone flyover performance/perspective review and Ember Forges
  forge-channel landmark reroll/review.
- Owners/closure: project implementation plus operator audition/playtest. Track
  acceptance in `openspec/changes/battle-metal-radio-rework/tasks.md`; do not
  mark its open items complete merely because partial work merges into game.

## 6. Historical issues: do not treat as currently reproduced

Earlier low-power-host image generation lacked Vulkan 16-bit storage and a CPU
fallback; older I2/I3 research mentioned missing accel_vram_gb. Those observations
refer to older hosts/forge versions and are not freshly reproduced here. If that
host remains supported, maintainers should test capability detection and an
explicit unsupported/CPU fallback path before retrying its image jobs.

The previous NVIDIA CDI `/dev/nvidia-modeset` studio-start failure has cleared:
studio now starts. Immediate worker socket reuse and old strict-input-hash stale
records were also addressed; current status at recovery showed zero stale.
Reproduce before reopening these as active blockers.

## 7. Local smoke-test findings — 02:12 UTC

App and gallery release builds pass. 54 targeted Flutter checks, 30 Node audio/
Worker tests, changed-runtime static analysis and strict validation of the active
OpenSpec change pass. Existing landscape widget fixture still warns that its
START GAME tap is offscreen; do not treat that fixture as a real landscape
interaction check.

Managed Wrangler preview starts and serves the Flutter UI and `/api/scores`
(HTTP 200). Desktop and Galaxy S24 Chromium windows load. Phone screenshot shows
the landing page, but arrow glyphs appear as missing-character boxes. Console
reports failed `fonts.gstatic.com` fallback font fetches (Noto Sans Math/SC/TC).
**Project remedy:** bundle a suitable licensed symbol font and configure local
fallbacks (or replace simple arrows with drawn icons), then rebuild and test
with outbound network disabled. **Maintainer check:** confirm this is expected
project-only browser egress behavior; do not relax browser isolation just to
fetch fallback fonts. This is a visual/offline-quality limitation of the current
local candidate and should be fixed or explicitly accepted before production.

Host browser `browser.cdp` Input.dispatchTouchEvent calls timed out for the phone
window. **Maintainer check:** inspect the window/session CDP routing and timeout
logs. Screenshots and browser.eval work. Loading and screenshot inspection are
confirmed; these timed-out calls do not establish touch/gameplay success.
