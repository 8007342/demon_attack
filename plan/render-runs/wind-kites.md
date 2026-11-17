# Render ledger: wind kites (change `crosswind`)

The Crosswind bonus level's two kite species (`openspec/changes/crosswind` design §6, §Pipelines). The operator
delegated the picks (project memory "autonomy"); each pick is logged here with its reasons.

- Kit: `art/families/wind-kites.json`. Run log: `art/families/wind-kites-runs.json` (8 entries: job, seed, prompt,
  models, output hashes, `selected`).
- Picks (full-resolution alpha crops, the pick of record): `art/sprites/sources/wind-kites/<id>-raw.png`;
  box-downscaled sources `<id>.png`.
- Candidates sheet: `art/contact/wind-kites-candidates.png` (each raw over a checker, then its five bank frames and the
  torn frame at x5). Finished atlas sheet: `art/contact/wind-kites.png` (over night sky and bright cloud).

## How to rebuild (no GPU)

```sh
cd tools/wind_kites && go run . offline   # byte-identical: atlas, Dart and contact sheet
```

## Runs (studio.run_workflow, `art/workflows/backgrounds/sprite-transparent.json`, 4 candidates each)

| Job | Species | Seeds | GPU | Verdict |
| --- | --- | --- | --- | --- |
| st-1794947875643-175 | ember-kite | 770100–03 | 48.4 s | **Pick 770100** |
| st-1794947937748-176 | lantern-moth | 770200–03 | 45.4 s | **Pick 770203** |

**Picks and why**
- **ember-kite 770100:** the clearest kite silhouette (a crimson diamond with a glowing bone cross); warm, so it reads
  against the cold Crosswind grade and stays apart from the cyan player shots.
- **lantern-moth 770203:** gold-veined jade wings round a glowing lantern body; the widest, brightest silhouette at
  24 px, a clear second species beside the ember kite.

**Rejected**
- 770101: a glossy purple gem plate; reads as a pickup, not a kite. 770102: two separate pieces (a pendant and a
  lantern on a string), no kite. 770103: a thin violet spear; nothing to hit at 24 px.
- 770200: a flat green moth, muddy at 24 px. 770201: a lantern with no wings. 770202: a wasp-like body, too insect for
  a kite.

## Finish (CPU, tools/wind_kites)

`bodyCrop` drops the thin string most raws drew under the kite (rows and columns under 15 % of the widest solid run),
then a box downscale to 24 px, binary alpha, a 20 % pull toward the species hint, a 6-level posterise, a 1 px dark
outline, five nearest-neighbour bank frames (−24°..24°) and a torn frame (the halves thrown apart). The tail is the
painter's: a ribbon of six line segments that streams with the wind.

## Spent

GPU 93.8 s for 8 candidates (2 jobs). The tool (new, ~600 lines of Go, about half copied from
`tools/ground_wildlife`) and the picks took about 40 minutes.
