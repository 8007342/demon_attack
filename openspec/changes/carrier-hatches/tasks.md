# Tasks

## 0. Research and spec (`work/carrier-hatches`)
- [x] 0.1 Research with provenance: `plan/carrier-hatches-research.md`; CH entries in `plan/provenance-audit.md`
- [x] 0.2 This change: proposal, design, delta specs, tasks; `openspec validate carrier-hatches --strict`
- [x] 0.3 Linked from `plan/operator-feedback-2026-11-16.md` (round 3c; round 3d's C4 revision)
- [x] 0.4 Round 3d revision folded in: shootable hatches with fields, the transformation and zoom-in, the core chapter, hints, subtitles, the easier calibration (design §A2–§A12, §C)
- [ ] 0.5 Operator review of the spec (the operator overrides the picks in design §C)

**Every task below follows the merge of `work/carrier-v3-render` into `game`.** Check it with
`git merge-base --is-ancestor origin/work/carrier-v3-render origin/game`.

## 1. Re-base on the merged render
- [x] 1.1 `git merge origin/game` into `work/carrier-hatches` (merge, never rebase); read the merged `paintGates`, `BossHeroHull.gates`, `BossHeroView.doors`, the wreck frames and the field painter; note in design §A9 what changed
- [x] 1.2 Re-check design §B1 against the merged code: how a form change and the S2 shed remove art now

## 2. Calibration "before" (on the merge, before any gameplay change)
- [x] 2.1 `test/boss_fairness_test.dart`: the naive pilot (aims at the target's current x, no lead, protected, 240 s cap per carrier); record its time-to-kill, hits taken and kill share per difficulty
- [x] 2.2 Re-measure the expert's seconds and hits (`test/boss_endurance_test.dart`); record both pilots as "Carrier hatches: before" in `plan/calibration-current.md`, with the commit

## 3. Hatch geometry and script (pure Dart)
- [x] 3.1 `lib/game/carrier_hatches.dart`: `CarrierHatch` (id, tier, side, kind, x, y, normal, field radius 18, hull radius 12), `CarrierHatches.forTour` (design §A3 table), the HP split (pool `k`, 60/40, ≥ 3 each), `transit`; move `GateRun`, `CarrierLaunches` and `CarrierVolleyTiming` here; `carrier_gates.dart` becomes a deprecated re-export — as built: design §D
- [x] 3.2 `CarrierScript`: `hatches`, `hatchOrder`, `hatchPool`, `hatchGlide`, `coreGlide`, `coreWindow`, `transformSeconds`, `zoomInRate`
- [x] 3.3 `test/carrier_hatches_test.dart`: the counts; every upper hatch inside the visible arena at zoom 0.86 over the glide; the HP split sums to the pool; determinism

## 4. Model (`model.dart`, `// --- carrier-hatches` markers)
- [x] 4.1 The carrier's chapters (hatches → transform → core); hatch state; `shield`/`shieldMax` as the fields' sum
- [x] 4.2 `hitBoss`: the vulnerable tier's fields and hulls; armour deflects (no damage); the core door only in the core chapter, half-width `16·door`; side hatches sealed
- [x] 4.3 The transformation (§A4): on the last hatch's fall (the break-up's release count, mirrored into the model as a deterministic 1.2 s), 3.5 s with no hitbox, fire or timers
- [x] 4.4 The glide factors (0.35, 0.6) on the lateral phase rate
- [x] 4.5 Flocks from the vulnerable tier, then the core door (§A5–§A6): arrival invariance (lead `transit − 0.55`, `+=` reload); the core-door hold; not targetable above y + 40
- [x] 4.6 The approach launches from all upper hatches (§A6, "The approach"; the arcade-progression spec)
- [x] 4.7 Hints (§A7): the shot-pattern detectors and cooldowns; `bossHintHatches`, `bossHintTiming`, `bossHintLead`
- [x] 4.8 Events (§A8): renames and new names in `game_events.dart`; `bossCoreExposed` moved; cell and impact events retired for the carrier; structured only; update `test/boss_intro_events_test.dart` and `test/boss_decay_events_test.dart`
- [x] 4.9 Tests: arrival invariance; the hold bound; no core damage while any hatch stands; armour deflects; the transformation's timing; hint triggers and cooldowns; the same seed gives the same volleys; an identical event log at every zoom

## 5. Pilot and calibration (CLAUDE.md §7)
- [x] 5.1 `campaign_playtest_test.dart` `steer`: aim at the vulnerable hatch nearest the column with the forecast lead, then at the open core door; the campaign playtest's bounds hold
- [x] 5.2 Run both pilots; meet the targets of §A11 with the levers in order, one at a time
- [x] 5.3 `test/boss_endurance_test.dart`: `baseline` ← the new expert means; the old map kept as `preHatches` (commit noted); a test that the ratios lie in the target bands; `test/carrier_field_equivalence_test.dart` retired for the carrier
- [x] 5.4 Record "Carrier hatches: after" (both pilots, per difficulty, the commit) in `plan/calibration-current.md`

## 6. Radio
- [x] 6.1 `art/comms/lines.json`: append `bossHintHatches`, `bossHintTiming`, `bossHintLead` (one line each, `"pending": "text"`, priority 7, ttl 3, cooldowns 20/20/25 s); then `python3 -I tools/comms_pipeline.py dart` (CLAUDE.md §4); the borrowed-line count in `test/comms_director_test.dart` stays 55 (written-only lines borrow nothing), with the comment updated
- [x] 6.2 `lib/comms/comms_view.dart`: strip text 13 → 14.5 px (tag 9.5 → 10.5), desktop unchanged at 13.5 × scale (14.5 and 15 overflowed the brood glyph column by 1.4 px); flagged one-line lines at full dock width with `maxLines: 1`
- [x] 6.3 `test/comms_line_length_test.dart`: ≤ 28 characters for the hint triggers and the `oneLine` set; a widget test at 360 px with the fonts loaded (`didExceedMaxLines` false for the hints; no ellipsis for any line at the new size, at 360 × 640 and 1280 × 720)

## 7. Presentation
- [x] 7.1 `scene.dart`: in the fight, the hull passes, deck, hatches and fields before the creature loop; approach launches in front of the slot
- [x] 7.2 `CarrierPresentation`: hatch doors and rims, per-hatch fields with the wear look, armour sparks, the pop-up and the field ripple on the way out, destruction (§B components), the cascade chase and the arming — as built: design §D
- [x] 7.3 The transformation: the shutter, the S2 shed burst (§B4), the zoom-in through `ArenaCamera` at 0.04/s, the halved bend in the core chapter
- [x] 7.4 The lead pip (Easy and Normal, after the first lead hint); reduced motion (§A10) — as built: design §D

## 8. Break-up core (`lib/game/carrier_breakup.dart`)
- [x] 8.1 `BreakupTransition`: before and after states; removed texels per layer, occluded by later layers (§B3)
- [x] 8.2 Components: from the manifest when the pack has them; otherwise the §B6 fallback, computed at hull install
- [x] 8.3 The schedule (§B4): shed (by destroyed-hatch share, then the transformation's burst), detach, hatch destroyed; the rate rule; the overlap burst — as built: design §D
- [x] 8.4 Bodies (§B5): the root tear, closed-form flight, fragments, sparks, smoke cap; reduced motion
- [x] 8.5 `test/carrier_breakup_test.dart`: partition, rate rule, continuity, seamless start, determinism, budgets, reduced motion

## 9. Break-up integration
- [x] 9.1 `BossDirector`: no module `BossWreck` or random `plate` wreck for carriers; the schedule driven from the decay and hatch events
- [x] 9.2 `BossPainter`: the transition composites (single, or the split pair) and one `drawVertices` for the components; the before-texture released at the end — as built: design §D
- [x] 9.3 The collapse (§B8): attached components composed into the wreck; the carrier-render-engine cohesion tests unchanged — as built: design §D

## 10. Review, art and archive
- [x] 10.1 `test/carrier_hatches_review_test.dart` (`review`): `art/contact/carrier-hatches-cascade.png`, `-transform.png`, `-breakup.png` (360 × 640 and 360 × 780), plus a check that no creature pixel is covered by the hull; `tools/gifstrip` GIFs of the fight (`-fight.gif`) and the break-up; picks logged in design §C — as built: design §D
- [ ] 10.2 Archive order: `boss-grandeur`, `carrier-v3`, `carrier-render-engine`, then this change. Reconcile carrier-v3's gate requirements and events, its shield-intercept requirement, and the main spec's side-hatch rule; delete the `carrier_gates.dart` re-export
- [ ] 10.3 Art pipeline (design §B9): dorsal hatches at the new anchors with door and rim pieces; the rigkit `comp` pass, the manifest and sockets; `boss_sheet pack`; the GPU run and its ledger `plan/render-runs/carrier-hatches.md`
- [x] 10.4 All gates in CLAUDE.md §2
