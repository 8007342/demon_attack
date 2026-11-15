# Tasks

## 1. Styleguide and mockups (done in this change)
- [x] 1.1 `docs/styleguide/alien-troops.md`: principles, palette, rank ladder, shields, health and state, phone-scale rules, hero-art guidance
- [x] 1.2 `tools/alien_insignia` (Go, standard library): `sheets`, `probe`, `montage` verbs; byte-identical output
- [x] 1.3 Mockups `art/contact/alien-insignia-{ranks,shields,phone,glyphs}.png` on the real `combat.png` cells

## 2. Data
- [ ] 2.1 `CombatAtlas.rankOf(Demon)` (design §1) with a table test
- [ ] 2.2 Head anchors: `tools/generate_sprites.py` emits per-cell skull-top points; `CombatAtlas.headAnchor`; fallback per-species values plus `lift`; update `plan/sprite-atlas.md`
- [ ] 2.3 `tools/alien_insignia atlas` → `assets/images/insignia.png` (< 4 KB) and its Dart rects

## 3. Runtime
- [ ] 3.1 `lib/game/insignia_painter.dart`: one `drawAtlas` after the camera transform, fixed CSS size, reveal gate, overlap rule (design §2)
- [ ] 3.2 Rims (shield, angry, tell) in one layer for at most ~8 creatures
- [ ] 3.3 Force-shield cells for sentinel shield, rush shield and boss shield; shards (≤ 12 alive)
- [ ] 3.4 Dive-shield arc segments (thermal palette unchanged)
- [ ] 3.5 Wound warm-up colour matrix in the body draw; angry glyph variant; tell flash (steady under reduced motion)
- [ ] 3.6 Remove the elite dotted ring and the carrier sigil pips

## 4. Validation
- [ ] 4.1 `test/insignia_test.dart`: rank table, contrast ≥ 0.35, fixed size under zoom, overlap, reveal
- [ ] 4.2 Review strips `art/contact/alien-insignia-ingame-{formation,shields,states}.png` at 360 × 780 and 1280 × 720
- [ ] 4.3 Pointer from `plan/style-guide.md` to `docs/styleguide/alien-troops.md`

## Workflow follow-up
- Hero art: crest zone and coarse elite plates in the next creature render pass (styleguide §8).
- Operator phone playtest, then `openspec archive alien-insignia`.
