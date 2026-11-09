# Asset pipeline

A local, deterministic pipeline from generated images to game-ready layered sprites.
The design rationale is in `plan/asset-pipeline/README.md`.

```
plan ─► generate (backend) ─► ingest ─► process ─► review ─► accept ─► pack
```

| Stage | What it does | Output |
|---|---|---|
| `plan --tier I0` | Builds one request per part from `families/<family>.json` (prompt + shared style prompt, seeds, size, steps for the tier). | `assets/research/asset-pipeline/<family>/queue-<tier>.json` |
| generate | **Backend: Forge `image.generate` MCP tool.** An agent runs each queued request **one at a time** (parallel calls crash the engine when VRAM is shared) and saves the JSON responses as a list. A ComfyUI HTTP backend will replace this step. | the `/work/tmp/imagegen/*.png` paths in the responses |
| `ingest --tier I0 --results r.json` | Copies the raws out of ephemeral storage. Each image is matched to its request by seed and records sha256, model, licence, backend, steps and timing. | `raw/<part>/…`, `runs.json` |
| `process` | Matte (OKLab distance from the border colour, Otsu threshold, largest component, defringe) → crop → optional mirror symmetry → BOX downscale into the part's slot → snap to palette (OKLab nearest) → binary alpha → despeckle → 1px outline → placed on the shared canvas. QA gates mark each candidate PASS, WARN or FAIL and give it a score. | `candidates/<part>/*.png`, `candidates.json` |
| `review` | Builds a static gallery: raw, matte and in-context view for each candidate, all loadout combinations, and the wear states. | `web/asset-pipeline-review/<family>/` (served at `/asset-pipeline-review/<family>/`) |
| `accept <part> <candidate>` | Records a human choice. | `selections.json` |
| `pack` | Docks modules onto the hull and derives the wear states (fresh/worn/critical). Writes the atlas plus metadata. Refuses parts no human has accepted unless you pass `--provisional`. | `assets/images/<family>-parts.png/.json`, `pack.json` |

Run it with the project venv (Pillow, NumPy, SciPy):

```bash
python3 -m venv .cache/asset-venv && .cache/asset-venv/bin/pip install pillow numpy scipy
.cache/asset-venv/bin/python tools/asset_pipeline/pipeline.py plan --tier I0
```

## Swapping in bigger models

Tiers are a parameter of `plan`. When I2/I3 or ComfyUI arrive, run `plan --tier I2`, generate, `ingest --tier I2`, then `process`/`review`. Candidates from every tier compete in the same gallery, and nothing downstream changes.

## Ship family (`families/ship.json`)

- 48×48 logical canvas, stored at 2× (96 px cells). Drawn 1:1 in the arena with `FilterQuality.none`.
- Parts: `hull`, `spread`/`large` (nose slot, never both at once), `rapid`/`powerful` (wing slot, never both at once, one side generated and mirrored), and `shield` (dorsal emitter). That gives 3 × 3 × 2 = 18 loadouts.
- Atlas rows follow the `parts` order. Columns are the wear states. `lib/game/scene.dart` (`_shipLayers`) picks the column from the power's remaining time: above half → fresh, above 2.5 s → worn, otherwise it flickers worn/critical. Spent modules tumble away using their critical sprite.
- If `ship-parts.png` is missing, the game falls back to the original sprite and the attachments drawn in code.
