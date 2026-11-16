# Render ledger: mission medals (B2)

This ledger covers the composable end-of-run mission medals that replace the modifier text chips (SUPPLY RUN, HEAVY
ORDNANCE, …) on the medal card, the score card and the scoreboard rows. It lists every run, every pick with its
reasons and rejections, and how to rebuild the atlas.
- Direction: `plan/operator-feedback-2026-11-16.md` B2 ("special mission medals with little ribbons or accents per
  mission … hero art goes through the shared asset pipeline").
- Change: `openspec/changes/mission-medals` (the runtime widget is a separate task with its own owner).
- Kit: `art/families/mission-medals.json`.
- Run log: `art/families/mission-medals-runs.json` (27 entries: job, seed, prompt, overrides, model and input hashes,
  output hash, verdict).
- Picks: `art/sprites/sources/mission-medals/<hull>/<seed>.png`.

The operator delegated the picks (project memory "autonomy"). Each pick is recorded below with its reasons and
rejections. Branch `work/mission-medals-art` (worktree `~/.cache/tillandsias-project/worktrees/mission-medals-art`),
off `work/mission-medals` at 7c1da7d1.

## 0. How to rebuild (no GPU)

```sh
lua tools/rigkit/bake_layers.lua art/families/mission-medals.json --cols 6 \
  --atlas assets/images/mission-medals.png \
  --dart lib/widgets/mission_medal_atlas.dart MissionMedalAtlas \
  --sheet art/contact/mission-medals-variants.png "MISSION MEDALS: VARIANTS AND LAYERS"
```

The command renders the rig: all 7 hulls in the one fixed frame, hero view, clay, hint and id passes, in about 2 s. It
then cuts each committed pick into per-module cells by the id pass, packs the atlas and writes the Dart, in about 5 s
in all. Two runs give byte-identical output. The candidates sheet:

```sh
rigsheet layercands art/families/mission-medals.json ~/.cache/tillandsias-project/rigkit/mission-medals/rig \
  art/contact/mission-medals-candidates.png "MISSION MEDALS: HERO CANDIDATES (DENOISE 0.72)" HULL=RAW,RAW,… …
```

This sheet needs the unpicked raws. They are kept only in `~/.cache/tillandsias-project/mission-medals-raw/`, which a
host reset wipes, so after a reset the committed sheet is the only record of them.

## 1. Deliverable

- `assets/images/mission-medals.png`: 576 × 336, a 6 × 3 grid of **96 × 112 cells**. The file is **55,200 bytes**
  (774 KB resident). Every cell uses the same frame (rigkit `render.frame` [-48, -68, 48, 44]), so a medal is drawn by
  stacking whole cells. The medal disc (r 36) is centred 12 px below the cell centre, and the ribbon and clasp fill the
  top third. `assets/images/` is already listed in `pubspec.yaml`, so the asset needs no new entry.
- `lib/widgets/mission_medal_atlas.dart` (generated, so never edit it by hand; it has a row in CLAUDE.md §4). It holds
  `MissionMedalAtlas.asset`, `cellWidth = 96`, `cellHeight = 112`, and `cells`, which maps a layer id to its
  (column, row):
  `base`, `ribbon|accent|emblem.supplyRun`, `….stormfront`, `….noShield`, `….spreadOnly`, `….heavyOrdnance`,
  `ribbon.generic`, `emblem.generic`. The draw order is ribbon, base, accent, emblem. `generic` has no accent, so a
  missing `accent.<id>` is simply skipped.
- **Adding a mission:** add a `ribbon` set and an `emblem` set (and an `accent` set if wanted) named by the mission
  id, a hull, and an entry in `layers.hulls`. Render its control (`rigsheet ctl`), paint it (§3 recipe), commit the
  pick, add it to `selected`, and rerun §0.

## 2. Library extensions (generic)

- `tools/rigkit`:
  - The family option `render.frame`: one fixed frame for every hull, which a layer family needs so that its cells
    stack.
  - A `star` prim: a flat badge outline (n points alternating `r` and `r2`, or a regular n-gon), extruded along z,
    with an optional `hole` that makes it a ring.
  - A module `frame: "flat"` is used so that `prism` polygons lie in x/y. This needed no code change.
  - `bake_layers.lua`.
- `tools/rigsheet/layers.go`:
  - `layeratlas`: fits each pick (bbox register), cuts it per module by the id pass, falls back to the hint colour
    where the paint is key, packs the cells (paletted when the page has ≤ 256 colours) and writes the Dart.
  - `layersheet`: every variant stacked, at the display sizes, with its layer breakdown.
  - `layercands`.
  - Family `layers.colours: "keep"` keeps the area-averaged paint and coverage, with no palette snap and no ink. The
    default, `palette`, is the existing pixel-art finish.
- Regression: `rig.py --check` is still ok for `alien-carriers` (`carrier1-thorn`) and `flight-joystick`.

## 3. Model (CPU, clay only)

| Layer | Geometry |
| --- | --- |
| Base | Gold rim with 20 scallops (r 36 / 33.4), bronze bezel (r 30.6), dark enamel field (r 27.2) |
| Ribbon | Trapezoid drape (44 wide at the clasp, 28 where it tucks behind the medal) and a gold clasp bar |
| Accent | A 3.6-unit enamel ring over the bezel, one colour per mission |
| Emblem | Raised over the field, inside r ≈ 23 |

The emblem stays inside r ≈ 23 so that it reads against the field. The ribbon and accent colours are chosen so that
the colour alone tells the missions apart at 20 px:

| Mission | Ribbon | Accent | Emblem |
| --- | --- | --- | --- |
| supplyRun | mint / gold / mint (fleet dawn) | mint | mint parachute, cords, amber crate |
| stormfront | violet / thin yellow / violet | lilac | yellow lightning bolt |
| noShield | red / white / red | red | sky shield, navy inner, red slash |
| spreadOnly | 5 stripes blue / sky | sky | three sky shot trails from a mint muzzle, white rounds |
| heavyOrdnance | 5 stripes orange / iron (hazard) | orange | orange bomb, nose down, steel fins and tail |
| generic | slate / silver / slate | none (the bronze bezel shows) | silver 5-point star |

The clay controls were checked before any GPU work. `heavyOrdnance` v1 had iron fins. On the first sheet its bomb read
as an orange egg at 20 px, so v2 has larger steel fins, which made one more GPU job (§4).

## 4. Hero (GPU)

Every job is a one-image edit of the hull's control (`rigsheet ctl`: clay plus hints on the green key) with the
committed `art/workflows/sprites/carrier-hero-qwen-fast.json` (Qwen-Image-Edit 2511 + Lightning 4-step, 1.6 MP). The
jobs ran one at a time, behind the carrier re-render on the shared GPU. Nothing was downloaded, there was no
`consent_required`, and the studio was never restarted.

The prompt is `prompts.hero`, with `{subject}` = `subject_<hull>` and `{ribbon}` = `prompts.ribbon` (empty for the
base). The negative is `prompts.negative`.

| Job | Hull | Seeds | Denoise | Verdict |
| --- | --- | --- | --- | --- |
| st-…-118 | supplyRun | 8010000–02 | 1.0 | Rejected: the edit re-framed the medal and redrew the ribbon as a folded band on a ring, so the id cut no longer fits |
| st-…-120 | supplyRun | 8020000–02 | **0.72** + "flat drape, no ring" | **Pick 8020001** |
| st-…-123 | stormfront | 8040000–02 | 0.72 | **Pick 8040001** |
| st-…-125 | noShield | 8050000–02 | 0.72 | **Pick 8050001** |
| st-…-127 | spreadOnly | 8060000–02 | 0.72 | **Pick 8060002** |
| st-…-129 | heavyOrdnance (v1 fins) | 8070000–02 | 0.72 | Superseded: an orange egg at 20 px |
| st-…-131 | generic | 8080000–02 | 0.72 | **Pick 8080001** |
| st-…-133 | base | 8030000–02 | 0.72 | **Pick 8030000** |
| st-…-135 | heavyOrdnance (v2 steel fins) | 8090000–02 | 0.72 | **Pick 8090002** |

The key fix was **denoise 0.72**, passed as the override `$node:11.denoise`, which the workflow allows. At 1.0 the
model redesigns the medal. At 0.72 it keeps the control's framing, so the id-pass cut lands on the painted shapes.
bbox registration absorbs the remaining drift.

**Picks and why:**

| Hull | Pick | Why |
| --- | --- | --- |
| base | 8030000 | An even field with no glare streak. 8030001's diagonal glare would show between emblem parts. 8030002 was the runner-up. |
| supplyRun | 8020001 | A clean mint and gold drape. The canopy and crate read at 20 px. |
| stormfront | 8040001 | The brightest yellow bolt, closest to the hint. |
| noShield | 8050001 | A clean drape and a crisp shield and slash. |
| spreadOnly | 8060002 | Clean stripes and crisp white rounds. |
| heavyOrdnance | 8090002 | The pointed steel nose and steel fins make it read as a bomb, not an egg. |
| generic | 8080001 | A flat drape and a clean star. |

**Rejected:**

| Hull | Seed | Reason |
| --- | --- | --- |
| supplyRun | 8020000 | The translucent ribbon despilled to grey in the cut |
| supplyRun | 8020002 | A flat canopy |
| stormfront | 8040002 | A creased ribbon and a gradient bolt |
| noShield | 8050000 | A pleated ribbon |
| spreadOnly | 8060000 | A glossy ribbon fold |
| generic | 8080000 | A creased ribbon |
| generic | 8080002 | An extra clasp loop |

Every verdict is also in the run log.

## 5. Finish

- **Colours "keep":** the paint is area-averaged from 768 × 896 to 96 × 112 and keeps its coverage alpha, with no
  palette snap and no ink. The first finish used the default `palette` mode (hard alpha, ink outline, ramp snap). It
  read as pixel art next to the vector medals in `lib/widgets/medal.dart`, the 1-texel ink swallowed the parachute
  cords and the 3.6 px accent ring, and the ramp snap speckled the silk. Edges stay smooth when the cells are stacked,
  because each lower layer is whole under the layer above it: the base cell is the full disc from hull `base`.
- The `base` cell comes from its own hull, so every variant shares one painted base. The mission hulls' own base
  paint is cut away.

## 6. Sheets

- `art/contact/mission-medals-variants.png` shows each variant in one row: the composite at ×2 on the card colour, the
  medal at 20 px, 20 px × 2, 36 px, 36 px × 2 and 36 px × 3 (by width, filtered), and the ribbon, base, accent and
  emblem layers on a checker. The bottom row shows all six side by side at 20 px, 36 px and 20 px × 2, as in a
  scoreboard row.
- `art/contact/mission-medals-candidates.png` has one row per hull. For each candidate it shows the raw, its cut
  stacked over the picked base (×2), and the medal at 20 and 36 px. The pick is outlined.
- **Legibility check (20 px, 1×):** the ribbon colours tell all six apart. The bolt, the slash, the spread fan and the
  bomb read. The supply crate is the faintest. At 20 px × 2 (40 device px) and above, every emblem reads.

## 7. Spent

- **GPU:** 27 Lightning images in 9 jobs, **560.7 s** of run time (≈ 17 s per image, plus ≈ 9 s for the model load
  each job). The jobs waited ≈ 85 min in total in the shared queue behind the carrier re-render; that wait was not
  GPU work for this run.
- **CPU:** rig runs of about 2 s each (≈ 6 runs), and about 5 s per atlas rebuild.

## 8. Left

- At 20 px and 1× device pixels the supply crate is only a few pixels. If the operator wants it bolder, a larger crate
  (and a smaller canopy) would take one geometry change and one more job.
- The ribbons carry a little painted glare (heavyOrdnance, generic). It is harmless at display sizes.
- No in-game mock yet. The runtime widget, and the medal card and scoreboard placement, belong to the parent task.

## Gates (2026-11-16, work/mission-medals after merging origin/game at d6369896)
- `flutter analyze`: clean. Full suite through the lock: +936 ~33, "All tests passed!" (the 33 skipped are `review`-tagged).
- `test/mission_medals_review_test.dart` ran alone (`--concurrency=1 --run-skipped --tags review`): passed; it writes
  `art/contact/mission-medals-screens.png` and `art/contact/mission-medals-supply-run.png`.
- `npm run test:worker`: 51 pass, 0 fail. `npm run build`: ok. `openspec validate mission-medals --strict`: valid.
