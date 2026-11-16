# Tasks

## 0. Research and spec
- [x] 0.1 Research with provenance: `plan/carrier-render-engine-research.md` (deformation, destruction, shield wear, mobile-web performance); CRE entries in `plan/provenance-audit.md`
- [x] 0.2 This change: proposal, design, delta spec, tasks; `openspec validate carrier-render-engine --strict`
- [ ] 0.3 Operator review of the sheets and clips (the operator overrides the picks)

## 1. Compose, then warp
- [x] 1.1 `lib/game/carrier_compose.dart`: `CarrierComposer` (one texture per pass, `toImageSync`, 2 px/unit), `CarrierHeightGrid` (topmost-covering heights, blurred), `CarrierWarpMesh` (one shared-vertex grid, footprint cull, 0.02° rebuild threshold)
- [x] 1.2 `BossPainter`: the composite cache keyed by the damage state; one height field for both passes; `bent()` through the same field with no lag; the field's distance map as the footprint
- [x] 1.3 `CarrierBend`: per-layer meshes and the wing lag removed (rigid turn); limits and springs unchanged
- [x] 1.4 Tests: `test/carrier_render_engine_test.dart` (one surface, rigid, deck lock, rig points, height steps), `test/carrier_bend_test.dart` (counts per hull)

## 2. The cohesive collapse
- [x] 2.1 `lib/game/carrier_wreck.dart`: `CarrierFracture` (jittered grid, noisy Voronoi over the structure, sections, cracks) and `CarrierCollapse` (closed-form bodies, v + ω × r at release, sag, list, depth scale, smoke, blasts)
- [x] 2.2 `BossDirector`: a v2 carrier's collapse is one `CarrierCollapse` (module wrecks stay for the frontal hulls); the phase holds until it is done
- [x] 2.3 `BossPainter.paintCollapse` / `paintCollapseSmoke` and the scene hook in `_bossWrecks`: one texture, one `drawVertices`, one shadow, the fog and the cloud-deck dissolve; the fight's composites are released
- [x] 2.4 Tests: hierarchy, continuity and kick bound, cohesion and list, headless and reduced motion, the director

## 3. The field thins in place
- [x] 3.1 `CarrierFieldPainter`: fixed offset, `wear(s)`, `dropout(s)` patches, lost regions worn instead of switched off, local crackle within the flash limits, shield-down thinning in place, a static pattern under reduced motion
- [x] 3.2 Tests: the wear and dropout curves and the fixed offset; `test/carrier_field_equivalence_test.dart` unchanged (the hit log is identical)

## 4. Review
- [x] 4.1 `test/carrier_render_engine_review_test.dart` (`review`): `art/contact/carrier-render-engine-{bend,collapse,field}.png`
- [x] 4.2 `tools/gifstrip` (Go, stdlib): `art/contact/carrier-render-engine-collapse.gif` and `-bend-sweep.gif`
- [x] 4.3 Picks, logged on the sheets and here: list 0.011 rad/s², depth scale 0.35 about hull-local (0, −150), gravity 4/6/10, the cloud deck dissolving instead of tinting (a light tint turned the pieces into flat white shapes on the first sheet), lost regions kept at 0.3 × wear (switching them off read as narrowing)
- [ ] 4.4 Phone profile on CanvasKit and skwasm at DPR 2 (with carrier-v3 task 3.5): the fight's two passes and the collapse's two `saveLayer`s

## 5. When the re-render lands (`work/carrier-v3-render`, design §5)
- [ ] 5.1 Read `layers[].height` into `CarrierHeightGrid` (topmost-covering merge, one blur) and lift the parallax cap
- [ ] 5.2 Read `wreck.chunks` and the section ids into `CarrierFracture.build` in place of the Voronoi seeds
- [ ] 5.3 Use the envelope margin: drop the `dstOut` feather where the art extends past the frame
- [ ] 5.4 Vortex and sag weights from `slots.<slot>.vortex` / `.hinge`
- [ ] 5.5 Reconcile carrier-v3's field requirement ("an offset that tightens as the shield wears") with this change's when either is archived
