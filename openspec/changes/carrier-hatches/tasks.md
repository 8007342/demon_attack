# Tasks

## 0. Research and spec (this phase, `work/carrier-hatches`)
- [x] 0.1 Research with provenance: `plan/carrier-hatches-research.md` (launch hatches, progressive destruction, adds staging, staggered break-up, adaptive music); CH entries in `plan/provenance-audit.md`
- [x] 0.2 This change: proposal, design, delta specs, tasks; `openspec validate carrier-hatches --strict`
- [x] 0.3 Link it from `plan/operator-feedback-2026-11-16.md`, round 3c (C4, C5)
- [ ] 0.4 Operator review of the spec (the operator overrides the picks in design §C)

**Every task below follows the merge of `work/carrier-v3-render` into `game`.** That branch has uncommitted edits to
`carrier_bend`, `carrier_field`, `carrier_presentation`, `carrier_wreck`, `boss_painter` and `scene.dart`, and it
delivers the door states, the gate map and the chunk data.

## 1. Re-base on the merged render (after `work/carrier-v3-render` is in `game`)
- [ ] 1.1 `git merge origin/game` into `work/carrier-hatches` (merge, never rebase); read the merged `paintGates`, `BossHeroHull.gates`, `BossHeroView.doors` and the wreck frames; note in design §A9 what changed
- [ ] 1.2 Re-check design §B1 against the merged code: how a form change and the S2 shed remove art now

## 2. Hatch geometry and script (pure Dart, no art)
- [ ] 2.1 `lib/game/carrier_hatches.dart`: `CarrierHatch` (id, tier, side, kind, x, y, normal, width, shootable), `CarrierHatches.forTour` (design §A2 table; tours beyond 5 use tour 5's), the drop thresholds in cells (§A3), and `transit(hatch, home)` (§A5); move `GateRun`, `CarrierLaunches` and `CarrierVolleyTiming` here unchanged, and leave `carrier_gates.dart` as a deprecated re-export until §10
- [ ] 2.2 `CarrierScript`: `hatches` and `hatchOrder` replace `gates` and `gateOrder`; the seeded variation picks the side that starts each tier, and nothing else
- [ ] 2.3 Tests in `test/carrier_hatches_test.dart`: the tier counts 4/4/5/5/6; every upper hatch inside the visible arena at zoom 0.86 for the whole glide (screen y ≥ −70) and within |x| ≤ 110; the thresholds; the topmost intact tier; determinism per seed

## 3. Model (`model.dart`, `// --- carrier-hatches` markers)
- [ ] 3.1 Tier state on the carrier's launches: active tier, dropped set; drops evaluated in `hitBoss` after the shield cells, and at the form change that seals the side hatches (§A3)
- [ ] 3.2 Fight flocks from the active tier (§A4): the lead is `telegraph + open + transit − 0.55`; the flock's cap and size are decided at that lead; the timer reloads by `+= period`, so its nominal schedule is unchanged; the entrance starts at the hatch and lasts `transit`; not targetable above the transit line (§A5)
- [ ] 3.3 Deck and maw launches (§A6): forecast the door cycles in closed form at the release moment; pick the opening that is open; otherwise park in the first to open, at most one period; no forced doors
- [ ] 3.4 Re-routing on a drop (§A3): queued creatures go to the same side on the next tier, with the telegraph shortened to at most 0.4 s
- [ ] 3.5 The approach (§A7): launch waves round-robin over all the upper hatches; the entry nearness is at least the carrier's slot nearness + 0.02
- [ ] 3.6 Events (§A8): rename `bossGate*` to `bossHatch*` in `game_events.dart`, with `tier`, `hatch` and `shootable`; add `bossHatchDrop` and `bossHatchTier` (with `bossHatchTier` tier 1 after `bossInRange`); structured only; update `test/boss_intro_events_test.dart` and `test/boss_decay_events_test.dart` (order, and no raw strings)
- [ ] 3.7 Tests: arrival invariance (the arrival log of a scripted fight with the deck hold disabled equals the pre-change log); the hold bound; re-routing; same seed, same volleys; an identical event log at every zoom

## 4. Presentation
- [ ] 4.1 `scene.dart`: in the fight, the prow pass, deck, hatches and field lip are drawn before the creature loop; creatures, tells and deaths are drawn over the hull (§A10); approach launches are drawn in front of the slot
- [ ] 4.2 `CarrierPresentation`: dorsal hatch doors (door layers from the render if present, runtime leaves otherwise), the pop-up (0.3 s, 0.8 → 1), the field ripple on the way out (no event), the drop (flicker, blown leaves as §B components, char, world-space smoke), and the cascade chase with the ember arming (§A10)
- [ ] 4.3 Reduced motion (§A10)

## 5. Calibration (CLAUDE.md §7)
- [ ] 5.1 Run `test/boss_endurance_test.dart`, `test/campaign_playtest_test.dart` and the boss level's clear time; print the deck hold's share of delayed arrivals
- [ ] 5.2 If a gate fails, apply the levers in the order of §A11, one at a time; record the before and after values and the commit in `plan/calibration-current.md`

## 6. Break-up core (`lib/game/carrier_breakup.dart`, pure Dart where possible)
- [ ] 6.1 `BreakupTransition`: the before and after states, and the removed texels per layer (layer alpha minus the after state's, occluded by later layers) (§B3)
- [ ] 6.2 Components: from the manifest's `comp` ids when the pack has them; otherwise the fallback of §B6 (connected regions, split to at most 48 units, merged up to 48 per transition; pivot on the seam; axis to the farthest texel; size class); computed at hull install with the field's distance transform
- [ ] 6.3 The schedule (§B4): shed, detach and hatch-drop releases; outer first; the 25 %-per-0.25 s rule; the impact-triggered early releases; the burst when a new transition starts
- [ ] 6.4 Bodies (§B5): the root tear, the closed-form flight from `v + ω × r` and the kick, spin, gravity, shrink, fade; fragments at their crack; sparks and the shared smoke cap; reduced motion
- [ ] 6.5 Tests in `test/carrier_breakup_test.dart`: every removed texel in exactly one component; the release-rate rule; continuity at release; the seamless start (≤ 2 % mean colour difference); determinism; the budgets (§B7); reduced motion

## 7. Break-up integration
- [ ] 7.1 `BossDirector`: carriers make no module `BossWreck` and no random `plate` wrecks; the schedule is driven from the decay (S1, `bossArmourShed`, the form change, the shield-down shed, hatch drops); the frontal hulls are unchanged
- [ ] 7.2 `BossPainter`: the transition composites (one, or a split under/over pair when a later layer overlaps the module, §B3); the attached components and the free bodies in one `drawVertices` over the before-composite; the before-composite is released when the transition ends
- [ ] 7.3 The collapse (§B8): attached components are drawn into the wreck composite at compose time; released ones finish; `test/carrier_render_engine_test.dart` cohesion passes unchanged

## 8. Review
- [ ] 8.1 `test/carrier_hatches_review_test.dart` (`review`): `art/contact/carrier-hatches-cascade.png` (a full fight's tiers, a pop-up, a drop and the chase, the deck hold) and `-breakup.png` (spines, the S2 shed, a hatch drop, reduced motion), at 360 × 640 and 360 × 780; plus a check that no creature pixel is covered by the hull
- [ ] 8.2 `tools/gifstrip`: `art/contact/carrier-hatches-cascade.gif` and `-breakup.gif`
- [ ] 8.3 Log the picks on the sheets and in design §C

## 9. Art pipeline (the re-render's follow-up; `plan/render-runs/`)
- [ ] 9.1 `art/families/alien-carriers.json`: dorsal hatch modules at the `CarrierHatches` anchors per tour (§B9.4); the prong pods, flank maws, sacs and aft gates retired as launchers (kept closed as decor, or cleared); `rig.py --check` reads the hatch anchors from `lib/game/carrier_hatches.dart`
- [ ] 9.2 `tools/rigkit`: array elements and door leaves as separate objects; a `comp` id pass; a component manifest (pivot, axis, size, crack, parent) in the bake's sidecar (§B9.1–§B9.2)
- [ ] 9.3 S3 stump sockets per detached element (§B9.3); `boss_sheet pack`: `BossHeroData.components` and the component page; `rigsheet budget` ≤ 16 MB per hull
- [ ] 9.4 Render run on the GPU: hatches and sockets per tour; the ledger in `plan/render-runs/carrier-hatches.md`; the picks committed (CLAUDE.md §5)

## 10. Gates and archive
- [ ] 10.1 All gates in CLAUDE.md §2; `openspec validate carrier-hatches --strict`
- [ ] 10.2 Archive order: `boss-grandeur`, `carrier-v3`, `carrier-render-engine`, then this change. Reconcile carrier-v3's "Carrier gate launches" and its gate event names with the requirements here when carrier-v3 is archived; delete `carrier_gates.dart`'s re-export
