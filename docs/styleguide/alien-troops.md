# Styleguide: alien troops (rank, shields, status)

Change: `openspec/changes/alien-insignia` (R6 in `plan/operator-feedback-2026-11-15b.md`).
Mockups (CPU, regenerate with `cd tools/alien_insignia && go run . sheets -root ../..`):
- `art/contact/alien-insignia-ranks.png`: species × rank, art ×3 and true phone size;
- `art/contact/alien-insignia-shields.png`: force shield cells, a break, wound tint, angry rim, dive tell;
- `art/contact/alien-insignia-phone.png`: one formation today and as proposed, 360 × 640 CSS at DPR 2;
- `art/contact/alien-insignia-glyphs.png`: the glyph set and palette.

This guide extends `plan/style-guide.md` (air creatures) and sits beside `plan/gargoyle-army-style-guide.md` (the
ground Host). Where they disagree on *rank and status readouts* for fliers, this guide wins.

## 1. The problem in one paragraph
The original 32-grid fliers (commit 8cf79246, `tools/generate_sprites.py`) signalled everything with the whole body:
- species by a flat teal, violet, coral or gold hide behind a 2 px midnight outline;
- each molt by a hue shift of the entire creature;
- "angry" by turning the whole sprite gold with red eyes;
- code drew 2 × 2 health pips and armour plates around elites.

At about 1.35 CSS px per art pixel, all of that read across a phone. Today's 64-grid gargoyles are drawn at the same
40 units, so each art pixel is about 0.68 CSS px, half the size:
- the colour now lives in shaded, textured hide;
- molts and anger are small decals (holes, cracks, scorched membranes);
- the species rank marks are capped at about 5 × 5 art px (3–4 CSS px) and often hidden by wings in the 3/4 banked
  view;
- the elite overlay adds a few gold pixels (brow chevron, crest spikes);
- health pips were removed in ux-declutter (869410ad).

The only signal that still reads is the elite's rotating ring of 2 × 2 dots, which is the "dots" the operator sees.
The crest spikes are the "spikes". **The detail doubled, but nothing that signals rank or status was scaled to keep
up.**

## 2. Principles
1. **Status reads by silhouette and colour first, detail last.** Every signal must survive an area downscale to 40 CSS
   px at DPR 1 (the right-hand columns of the ranks sheet).
2. **One channel per question:**
   - species is the hide hue (unchanged);
   - rank is a glyph above the head;
   - protection is cyan cells in front of the body;
   - health is the warmth of the whole hide;
   - imminent action is a white flash of the glyph and rim.

   No channel borrows another's colour.
3. **Coarse pixels.** Insignia are drawn on the *old* 32-grid pixel, one glyph pixel = 2 art px (≈ 1.35 CSS px). Each
   has a 1-glyph-pixel ink outline, so they sit on any hide or sky.
4. **Alien, not human.** No chevrons, bars or stars copied from human militaries. The brood brands rank as *talons*
   (claw hooks) and *ocelli* (rayed eyes), and its officers wear *crowns of tines*.
5. **Drawn after the camera.** Insignia, shield cells and rims are overlays drawn at a fixed CSS size after the
   `boss-grandeur` zoom, so a zoom never shrinks them. They follow a per-cell head anchor, so they stay on the creature
   in every bank and flap pose, and they are never rotated.
6. **Quiet unless it matters.** At most two marks per creature (a rank glyph and a shield arc) and at most one animated
   element. Drones carry nothing.

## 3. Palette
| Token | Hex | Use |
|---|---|---|
| `insignia.ink` | `#0B0A14` | 1 px outline of every glyph and cell |
| `insignia.bone` | `#F6EBC8` | Rank glyph fill (the brood's bone brand) |
| `insignia.ember` | `#FF5A36` | Ocellus core; angry rim |
| `insignia.angry` | `#FFC24A` | Rank glyph fill while angry (1 HP left) |
| `shield.cell` | `#62F0FF` | Force-shield cell, lit |
| `shield.spent` | `#1C6F86` | Force-shield socket, spent |
| `shield.rim` | `#62F0FF` @ 0.6 | 1 art px silhouette rim while any force shield is up |
| `tell.white` | `#FFFFFF` | Glyph and rim during a dive tell |

The cyan family is the force-shield language of the main spec ("geometric cyan/teal/violet"). The thermal dive
shields keep their blackbody palette (§5.2) and never use cyan.

## 4. Rank insignia (the alien chevrons and stars)
| Rank | Who (game data) | Glyph | Size (glyph px → CSS px at 40-unit draw) |
|---|---|---|---|
| R0 Drone | Intelligence tier T0: small creatures (`kind < 2`, `maxHp < 3`, not elite) | none | — |
| R1 Skirmisher | Tier T1: not-so-small creatures (`kind ≥ 2` or `maxHp ≥ 3`) | one **talon** | 7 × 5 → 9.5 × 6.8 |
| R2 Veteran | T1 with `maxHp ≥ 4` (route-hardened) | two stacked **talons** | 7 × 9 → 9.5 × 12 |
| R3 Hunter | Elites (tier T2) | **ocellus**: a four-rayed eye, ember core | 9 × 9 → 12 × 12 |
| R4 Sentinel | Shield and armoured sentinels (tier T3) | **crown** of five tines over an ocellus | 9 × 4 + 9 × 9, on the sentinel sheet's head anchor at the sentinel's scale |
| Carrier forms | Boss forms 1–4 | the same ladder on the brood sigil: talon, two talons, ocellus, crown | at the hull's scale |

**Placement.** Bottom-centre one art px above the head's top, at the per-cell head anchor (species head tops in the
neutral glide pose are at art y 22 / 21 / 22 / 20). The glyph never overlaps the eyes. The crest region above the
head is kept free of horns wider than 6 art px in future hero art (§8).

**Replaces:**
- the elite's rotating 12-dot ring: the ocellus *is* the elite mark;
- the 2 × 2 rank pips on the carrier sigil.

The species chest badges in the art (teal chevron, violet twin bars, coral fang slashes, gold star jewel) stay as
*species identity*. They are no longer asked to say rank.

**Reveal.** Glyphs follow the existing staged reveal: they appear when the fog transmittance reaches 0.6, and fade in
over 0.25 s. Nothing in the fog wears a glyph.

## 5. Shields that read as shields
### 5.1 Force shields (sentinel shield, sentinel rush shield, the boss's shield)
- **Cells.** One hex cell per shield point, on an arc in front of the body (toward the player, screen down). The arc
  radius is 30 × 22 art px about the body centre, with 0.44 rad between cells. A spent cell stays as a dark *socket*,
  so "how much is left of how much" reads at a glance (shields sheet, 5/5, 3/5, 1/3).
- **Rim.** While any cell is lit, a 1 art px cyan rim (alpha 0.6) traces the silhouette. That is the "it is shielded"
  read at phone size, where cells merge into a dotted bar.
- **Hit.** The struck cell flashes white for 2 frames, splits into 2–3 cyan shards that fall, and becomes a socket.
  A hit that does not break a cell flashes the rim only.
- **Break.** When the last cell goes, the rim pops outward (1 frame, 2 px) and is gone.
- **Scale.** Sentinels use the same cell glyph at their scale. The boss uses 12 cells on its hull (`boss-grandeur` §6,
  S0).

### 5.2 Thermal dive shields (all divers)
They stay a blackbody re-entry envelope (main spec). To read as layers, the envelope's bow arc is split into one
segment per dive-shield point (1 / 2–3 / 4 + cycle÷2), and a hit burns one segment off with a white flash. They are
never cyan and never hex.

### 5.3 Elite armour
The authored elite plates (helm plates, crest spikes, gorget, pauldrons) remain and shed one level per hit. They are
armour, not a shield, so they carry no cyan.

## 6. Health and state
| State | Today | Proposed |
|---|---|---|
| Wounded (molt 1–3) | holes and orange cracks | **plus** a whole-hide warm-up, lerped toward ember by 12 / 24 / 36 % (dark outline untouched). This restores the old whole-body molt shift on the painted art |
| Angry (1 HP, `maxHp > 1`) | scorched membranes, red eyes | **plus** a 2 art px ember rim and the rank glyph turning `insignia.angry` |
| Dive tell | anticipation pose, eyes flare | **plus** the glyph and a 2 art px rim flash white, for the tell's length (one animated element) |
| Hit flash | white tint | unchanged |

There is no numeric HP readout. ux-declutter removed the pips on purpose, and the warm-up carries "hurt" without
clutter.

## 7. Phone-scale rules (acceptance)
On a 360 CSS px wide arena at DPR 1 (the worst case), with creatures drawn at 40 units:
- **Glyph stroke.** 2 glyph px (≈ 2.7 CSS px); smallest glyph ≥ 9 × 6 CSS px; ink outline always on.
- **Distinguishability.** Each rank must be told apart from its neighbours in a 40 px area downscale. This is checked
  on the ranks sheet's right-hand columns and by a contrast test (glyph-to-hide luma difference ≥ 0.35).
- **Shield count.** The cells of a 3-point shield must stay countable at DPR 2 (phone sheet). At DPR 1 the rim and the
  bar must read as "shielded".
- **Camera zoom.** Glyphs, cells and rims are drawn after the zoom at a fixed CSS size.
- **Density.** In a dense formation (phone sheet) no glyph overlaps another creature's glyph. If one would, the
  lower-rank glyph yields: it is skipped that frame.

## 8. Hero art to match
- **Head anchors.** `tools/generate_sprites.py` emits a per-cell head anchor (top of skull, centre x) for every
  species, direction and pose, as `CombatAtlas.headAnchor`. The overlay follows it through banks and flaps.
- **Crest zone.** Future hero renders keep a clear zone of 12 × 10 art px above the skull for the glyph. Horns may
  frame it but not fill it.
- **Elite plates.** The authored elite armour is re-drawn at one coarse-pixel scale (2 art px plates), so that it also
  survives the downscale.
- **Sentinels and the boss.** They take the same ladder and cell language: sentinel sheet head anchors, and the
  boss's brood sigil on the hull (`boss-hero-assets` palette notes).
- **Ground Host.** Unchanged. Its gilt spires already "echo, not copy" the air ranks.

## 9. Do and don't
- **Do:** one glyph per creature, bone on ink, above the head.
- **Don't:** put rank on the chest, under the wings or in the hide colour.
- **Do:** count shield points as cells, and keep spent sockets visible.
- **Don't:** use cyan for anything that is not a force shield, or thermal colours for anything that is not a dive
  shield.
- **Do:** let the whole hide carry health.
- **Don't:** bring back numeric pips.
- **Don't:** rotate, blur or zoom insignia, or draw them on creatures still in the fog.
