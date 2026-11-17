# Tasks: dive-shield-thinning

## 1. Cause
- [x] 1.1 Trace every dive-shield drawing path (ordinary divers, elites, sentinels, the rush) and record why it narrowed and why its parts moved apart from the body (design §1)
- [x] 1.2 Confirm the drawn shape never fed a hit test (design §3)

## 2. Thinning shield
- [x] 2.1 `lib/game/dive_shield.dart`: one arc of constant 124° span, specs sized from the atlas silhouettes, thickness by points down to a hairline, heat, flicker, hit flash
- [x] 2.2 Draw it in the body's transform: ordinary divers inside the wing roll; sentinels inside the bank on the snapped centre
- [x] 2.3 Rush shield: the thickest, forming in place; remove the fixed-size rush cell ring
- [x] 2.4 Remove the playtest-fixes-3 bow code and its shape tests

## 3. Verification
- [x] 3.1 `test/dive_shield_thinning_test.dart`: constant angular width and body coverage at every zoom, monotone thickness, one connected shape
- [x] 3.2 Review sheet `art/contact/dive-shield-thinning.png` (before | after, three zooms) and `art/contact/dive-shield-thinning-dive.gif`
- [x] 3.3 Full gates
