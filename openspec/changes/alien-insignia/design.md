# Design: alien insignia

The visual language is defined in `docs/styleguide/alien-troops.md`. This design covers how the game draws it.

## 1. Rank from game data (`CombatAtlas.rankOf`)
```
sentinel (isLarge)                       → R4
elite                                    → R3
kind ≥ 2 || maxHp ≥ 3:  maxHp ≥ 4 → R2, else R1
otherwise                                → R0
```
- This mirrors the `demon-intelligence` tiers (T0–T3) and the medium dive-shield rule, so the glyph tells the player
  how the creature will behave.
- It is a pure function of existing fields: it stores nothing and changes nothing.

## 2. Glyph atlas and painter
- `tools/alien_insignia atlas` writes `assets/images/insignia.png`. It holds the glyphs (talon, double talon, ocellus,
  crown, cell, socket) in bone, angry gold, tell white and cyan variants, at 2 device px per glyph pixel. It is under
  4 KB.
  - As built: 813 bytes, plus the generated rects `lib/game/insignia_atlas.dart`.
  - The double talon shares one glyph row (7 × 9).
  - The sentinel's crown is one glyph: the band seated on the ocellus, whose top ray sinks into it (9 × 11, not
    9 × 13).
  - The cells are lit (cyan), spent (socket), flash (white) and rush (`#FFA88C`, cyan pushed to ember, see §4).
- `InsigniaPainter` draws after the arena camera transform (`boss-grandeur` §3), in screen space:
  - position = `camera.toScreen(creatureCentre + headAnchor(cell) · scale)`;
  - size is fixed in CSS px (1 glyph px = 1.35 CSS px), regardless of creature scale or zoom.
- **One `drawAtlas` per frame** for all glyphs and cells; rims go in one `saveLayer` (they need the silhouette).
- **Rims.** The silhouette rim is the creature cell drawn 4 times at ±1 px offsets in the rim colour under the body
  (srcIn tint), only for creatures with a rim state: shielded, angry or telling. That is at most about 8 per frame.
- **Reveal.** Alpha is `smoothstep(0.6, 0.75, transmittance)`, so nothing in the fog wears a glyph.
- **Overlap.** Glyph rects are tested in rank order. A lower-rank glyph whose rect overlaps an already placed one is
  skipped that frame, with no flicker: the decision holds for 0.3 s.

## 3. Head anchors
- `tools/generate_sprites.py` already rigs every cell. It adds the projected skull-top point per (species, damage
  variant, direction, frame) to `plan/sprite-atlas.md` and to the generated Dart as `CombatAtlas.headAnchor(row,
  col)`. That is 32 × 36 small records.
- Until the regenerated atlas lands, the fallback is the per-species neutral value (art y 22 / 21 / 22 / 20) plus the
  frame's `lift`.
- Sentinels take their anchor from the sentinel effects sheet's head point, and the carrier from the brood sigil
  anchor.

**As built (2.2).**
- The anchor is the screen top of the posed skull ellipsoid (wings omitted, so it needs no raster), for flight rows
  0–4, flash rows 5–6 and the action row (anticipation, fire, angry fire, dive, dive flash).
- The ellipsoid lacks the outline, brow and horn bases, so each species is calibrated once: its neutral glide is
  matched to the topmost opaque pixel over the skull in the shipped `combat.png`. The measured values are art y
  21 / 20 / 21 / 21 (the styleguide's 22 / 21 / 22 / 20 were read by eye from a probe). They are the fallback,
  `CombatAtlas.neutralHeadTop`.
- The table goes to a generated `lib/game/combat_anchors.dart` (one string per species row, so `dart format` leaves
  it alone), not into the hand-written `sprite_atlas.dart`. `python tools/generate_sprites.py --anchors` rewrites it
  from the shipped atlas without a re-render.

## 4. Shields
**Force shields** (sentinel `shield`, rush shield, boss shield):
- Cells are placed per the styleguide §5.1.
- **Sentinels:** lit cells = `shield`, sockets = `shieldMax − shield`. The rush shield uses the same arc one row lower
  and in ember-tinted cyan, so the two are not confused.
- **Boss:** 12 cells, `ceil(12 · shield / shieldMax)` lit, on the hull's arc (shared with `boss-grandeur` S0).
- **Break and shards:** 2 frames white, then 3 shards with gravity, at most 12 alive. Shards are particles, not
  sprites.

**Dive shields:** the existing thermal arc is cut into N segments (N = dive-shield points). A hit removes the outermost
segment with a white flash. The palette is unchanged.

## 5. Health and state
- **Wound warm-up.** A colour matrix (lerp toward `#FF6E3C` by 0.12 · molt, applied when luma > 0.14 so the outline
  stays). It is applied with the body draw's existing colour filter slot: no extra layer.
- **Angry:** an ember rim (§2) and the glyph's angry-gold variant.
- **Dive tell:** the glyph and rim go white for the tell's length. It is the only animated insignia element, and
  reduced motion keeps it as a steady white.

## 6. Removed
- The elite dotted ring (`scene.dart` ~848–863). The ocellus replaces it.
- The rank pips on the carrier sigil. The ladder glyph replaces them.

## 7. Validation
- `test/insignia_test.dart`:
  - `rankOf` table;
  - glyph luma contrast ≥ 0.35 against each species' mean hide luma;
  - fixed CSS size at Z = 1 and Z = 0.86;
  - overlap rule;
  - reveal gate.
- **Review strips** `art/contact/alien-insignia-ingame-{formation,shields,states}.png` from the real scene at
  360 × 780 and 1280 × 720, compared against the mockups.
- **Performance:** one extra `drawAtlas` and at most one rim layer per frame, measured in the existing perf test.

## 8. Decisions taken on the operator's behalf
- **Above the head, not on the chest.** The chest is small and covered by wings in banked frames, which is where
  today's marks were lost. Above the head is free in every pose.
- **Overlay, not baked.** It is resolution- and zoom-independent, needs no re-render to adjust, and costs one atlas
  draw. The art keeps species identity, and the overlay carries rank.
- **No HP pips.** ux-declutter removed them on purpose, and the whole-hide warm-up carries "hurt" without clutter.
- **Mockups by composition, not AI.** The sheets compose the shipped atlas with exact glyphs, so the operator judges
  the real proposal. Hero-art changes (crest zone, coarse elite plates) wait for the next creature render pass.
