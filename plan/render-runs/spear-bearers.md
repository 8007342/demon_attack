# Render ledger: spear-bearers (buckler, spear, thrown spear)

Direction: operator, 2026-11-17 (verbatim): "perhaps we could also have them wielding a little shield and spear for
the armored ones later, wielding the spear as they dive, and throwing it mid dive ;) New enemy sprites :D !!"
Change: `openspec/changes/spear-bearers` (design §4). Style guide: `docs/styleguide/alien-troops.md` §5.6.
The operator delegated the picks (project memory "autonomy"); made 2026-11-18 on `work/spear-bearers`.

## Pipeline and why
A Go pixel tool, `tools/spear_bearers` (standard library only, modelled on `tools/alien_insignia`): the gear is
authored as geometry at the combat atlas's art pixel in `gear.go` (2 art px strokes, the insignia's coarse pixel; a
1 art px ink outline), packed into `assets/images/spear-bearers.png` (256 × 176, 3 KB) with a generated
`lib/game/spear_bearer_atlas.dart`, and drawn as overlays on the shipped gargoyle bodies, the way the elite armour is.

Why not the others (crosswind design §Pipelines is the comparison):
- **ComfyUI studio** (`sprite-transparent.json`): the pieces are 9–25 CSS px at phone size. A diffusion raw of a
  buckler or a spear has to be cropped and box-downscaled to 18–40 art px, where it turns to mush and loses its ink
  outline; the kite raws even drew strings that needed a bespoke crop. No GPU job was run, so no model download and no
  raw to commit.
- **rigkit layer family**: built for medals and hero hulls (a clay, hint and bake chain); a two-colour 18 px disc and a
  2 px shaft need none of it.
- **A pure Dart painter** (like the lightning rods): would also work, but the spear needs a hand-placed tusk head and
  five baked leans, and an atlas keeps it one `drawImageRect` per piece and reviewable as pixels on a sheet.
- **The Go pixel tool**: deterministic, no GPU, rebuilt byte-identically offline (`go run . check`), and its review
  sheets composite the gear on the real `combat.png` cells, so it is judged where it will be seen.

## How to rebuild
```sh
cd tools/spear_bearers
go test ./...        # palette channels, emblem asymmetry, pointed heads, release point = model
go run . offline     # assets/images/spear-bearers.png, lib/game/spear_bearer_atlas.dart,
                     # art/contact/spear-bearers.png, art/contact/spear-bearers-candidates.png
go run . check       # byte-identical against the committed files
```

## Sheets
- `art/contact/spear-bearers.png`: the gear on every species, at 4× and at 40 px (phone, DPR 1): idle, tell, dive,
  wind-up with the glint, release (empty claw), buckler hit, bare dive; the knocked-away buckler; the thrown spear at
  its five leans.
- `art/contact/spear-bearers-candidates.png`: three spearheads × three emblems on the dive and wind-up poses.

## Picks
| Item | Candidates | Pick | Why | Rejected because |
|---|---|---|---|---|
| Spearhead | leaf, tusk, barb | **tusk** | a long tapering bone head hooked a little to one side: it rhymes with the brood's fangs and the carrier's ivory tusk-prongs (`alien-capital-ships.md` §3), and its 5 px base still reads as a "point" at 1× | **leaf**: symmetric, reads as a human arrowhead and at 1× as a blob on a stick; **barb**: 3 px wide, vanishes at 1×, and its single barb reads as a fish hook |
| Buckler emblem | fang, boss, whorl | **fang** (one bone fang leaning right, tapering to one point) | asymmetric, one point, no lobes (§4.1 rules 2–4); echoes the hunter's mark without repeating the glyph | **boss**: a bone dot in a bone ring is an eye or a target at 1×; **whorl**: three spokes merge into a smudge at 1× |
| Emblem first pass | zigzag fang | redrawn as a straight taper | — | the first fang had alternating offsets and read as a **lightning bolt**, which means something else in this game (storm-lightning) |
| Buckler colours | — | bone rim (lit `#F6EBC8` top, `#B8AC90` below), iron face `#2E2A33` with an `#5A5262` edge | the bright 2 px rim is the "it is shielded" read at phone size; iron and bone are the brood's (the lightning rods) | cyan is the force shield's (§3); blackbody colours are the dive shield's |
| Buckler size | — | raised r 9.5 art px (≈ 12 CSS px across), carried as a 5 × 8.5 ellipse at the side | covers the chest and belly from the front in the dive; at the side it does not hide the wing | larger hid the body's molt decals |
| Hit / knock-off | — | the rim flashes white with a crack across the face; knocked away it tumbles edge-on (a 19 × 7 ellipse), fading over 1.4 s | white is the hit flash language of shield cells (§5.1) | — |
| Wind-up tell | — | spear drawn back over the right shoulder (head 32 art px above the levelled one) + a white 4-point glint on the head, growing and pulsing at ~5 Hz (steady with reduced motion) | a pose change big enough to read at 1×, and a light that reads before the shape | — |
| Release | — | the empty claw flung forward, open, with two soft speed lines | "empty hand" reads by the missing shaft; the lines carry the motion | — |
| Thrown spear | — | the same tusk spear, tip down, 40 art px (25 units) long, five leans (−24…24°) chosen by its drawn velocity, wind included; the tip is the hit point | longer than any bolt, so it never reads as ordinary fire; the lean shows the wind bending it | — |
| Rank mark | — | none drawn here: the bearer is an elite, so it wears the hunter mark (`SpearBearerPainter.rankOf`; insignia-ranks hook) | §4: rank lives in the glyph only | — |
