# Render ledger: boss carrier v2 (R8, R10)

This is the production ledger for the v2 boss art direction: the Thornwake carriers. It records every run, every pick
and why, and what is left.
- Direction: `plan/operator-feedback-2026-11-15b.md` R8 and R10.
- Design: `openspec/changes/boss-hero-assets/design.md` §8.
- Rules: `docs/styleguide/alien-capital-ships.md`.
- Kit: `art/families/alien-carriers.json`.
- Run log: `art/families/alien-carriers-runs.json`.

The operator delegated the picks (project memory "autonomy"). Each checkpoint records the pick, the reasons and the
rejected runs, and the operator can override any of them.

Branch `work/boss-carrier-v2` (worktree `~/.cache/tillandsias-project/worktrees/boss-carrier-v2`), off `game` (with
`origin/game`'s merge of `work/boss-hulls-b3`). The v1 frigate, cruiser and battlecruiser picks in
`plan/render-runs/boss-hero-assets.md` are superseded.

## 0. How to rebuild (preflight of every run)

```sh
PY=$(lua tools/boss_rig/setup_bpy.lua)                                   # bpy 5.3.0 venv (idempotent)
$PY -I tools/rigkit/rig.py art/families/alien-carriers.json --check       # originality, symmetry, counts, anchor gate
(cd tools/rigsheet && go build -o ~/.cache/tillandsias-project/rigsheet .)
lua tools/rigkit/bake_family.lua art/families/alien-carriers.json carrier1-thorn --sheets art/contact/boss-carrier-v2-thorn
```

`bake_family.lua` rebuilds a hull without GPU: rig → fit and symmetrise the committed picks → mask diff → projection
bake → finish → manifest → budget (→ sheets). The picked raws are committed under
`art/sprites/sources/boss-carrier-v2/<hull>/`.

## 1. C1: the shared libraries, the kit and the turntables (2026-11-15, CPU)

**Built**
- `tools/rigkit/` (design §8.5):
  - `rigkit.py`, the bpy module kit;
  - `rig.py`, the rig, `--check` and the controls;
  - `bake.py`, the projection bake;
  - `bake_family.lua`, the no-GPU rebuild;
  - `collect.lua`, studio outputs → raws + run log.
- `tools/rigsheet/` (Go, standard library): finishing, the manifest, the budget and every sheet.
- The v1 `tools/boss_rig` and `tools/boss_sheet` are untouched. They keep the superseded frigate provenance
  reproducible, and `boss-grandeur` is adding its pack to `boss_sheet`, so nothing here edits it.

**The kit** (`art/families/alien-carriers.json`):
- tour 1 is built from six slots with three sets each, baked as three combinations (`carrier1-thorn`, `-lattice`,
  `-shroud`; 9 instances each);
- tours 2–5 add `maw`, `barrier`, `tendril`, `sac` and `crown` slots and extra blister and emitter batteries (13 / 17 /
  21 / 24 instances, extent ×1.08 → ×1.32).

**Look iterations, all on clay, no GPU except one 2-image probe:**
1. **v2a, a round dome with a small prow pod.** The prow read as a mouth with teeth: thin bone pillars between the
   openings, a bead apron and a radiating thorn mane. Two dome blisters read as eyes. Rejected on the first preview.
   It gave the head-reading guard (styleguide §3.4).
2. **v2b, solid bulkheads, battery blisters, forward prongs.** One full-model probe (st-1794784185894-83, seeds
   1010000–1010001, 40 steps, ≈ 5.4 min per image) and 8 Lightning seeds (st-1794784753371-84) showed:
   - a glossy spiked *beetle*: a round dome, a black pod for a jaw;
   - the two violet emitters on the dome read as **eyes** in every seed;
   - the octagonal scale grid painted as studs.

   Rejected. The Lightning batches queued on the v2b controls for lattice and shroud (st-…-85, -86) confirmed it:
   grimacing faces.
3. **v2c (current).** A flat wedge slab:
   - superellipse exponent 6, a straight ±300 front, two terraces, a bone keel or crystal crown;
   - long fore-and-aft armour strakes (a ship's linear detail in grown material) instead of a scale grid;
   - emitters in rows of three per flank, never a lone pair;
   - the thorn prow's thorns jut sideways like a ram;
   - drop offsets fixed (several prims had been buried under the surface).

   It reads as a capital ship in the full-plan lineup and as a hangar deck flanked by prongs at the screen crop.

**Gates.** `--check` ok on all 7 hulls (originality, mirror symmetry by KD tree to 0.5 units, the anchor gate at 9
views). The anchor gate is ok in every rendered view and stage. Two library fixes came from the symmetry check:
- jitter is keyed on |x| (mirror twins draw the same numbers, mirrored);
- dropped elements on the left cast at their right twin and mirror the hit (the BVH triangulates quads along one
  diagonal).

The displacement uses Newell normals.

**CPU.**
- Full rig of the three tour-1 hulls (9 views × S0/S2/S3 × 6 passes): 191–209 s per run, peak RSS 1.57 GB (< 2 GB),
  8 threads.
- Four full runs plus about 15 hero-only previews this checkpoint: ≈ 16 min of Blender wall time.

**Sheets.**
- `art/contact/boss-carrier-v2-kit.png`: per tour-1 combination, the 3 × 3 clay views with hints, the simulation
  windows and the solid body, and the id, depth, S2, S3, normal and hint passes at the hero view.
- `art/contact/boss-carrier-v2-lineup.png`: tours 1–5 as full plans (`--envelope off`) at one scale, with the phone
  screen at Z 0.70 dashed. The ship always overflows it.
