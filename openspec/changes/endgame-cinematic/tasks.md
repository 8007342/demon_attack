# Tasks

## 1. Research, design and plan (this branch)

- [x] 1.1 Craft and pipeline research with sources (`plan/endgame-cinematic-research.md`); unsourced claims listed in `plan/provenance-audit.md` Part E
- [x] 1.2 Reveal ledger: 167 rows, the 25-speaker mapping, proposed plants (`plan/endgame-reveal-ledger.md`)
- [x] 1.3 Style guide (`docs/styleguide/endgame-cinematic.md`), storyboard and shot list (`art/storyboards/endgame/`, `art/contact/endgame-storyboard.png`), line proposal (`art/comms/endgame-lines.proposal.json`)
- [ ] 1.4 CP0: the operator reviews the storyboard and answers the open questions (design §10); fold the answers into the ledger, the guide and the boards; reconcile the "Beach reveal and credits" requirement of `battle-metal-radio-rework` and update `plan/story-hooks.md`
- [ ] 1.5 Re-read the blocked sources when the proxy allows them and clear or confirm the Part E rows

## 2. Shot script, timeline and animatic (no GPU)

- [ ] 2.1 `art/cinematic/endgame/shots.json`: per shot the duration, lens, camera keys for landscape and portrait, subject box, layers with depth and payoff ledger ids, pose swaps, subtitle and audio cues; a JSON schema check in Lua with `jq`
- [ ] 2.2 Pure-Dart timeline (`lib/ending/cinematic_timeline.dart`, no `dart:ui`): state at time t (shot, camera, layer transforms, focus, cue); unit tests for the cut at 2.0 s, shot bounds, subject boxes at 360×780 and 1920×1080
- [ ] 2.3 Player widget in `lib/ending/` with grey placeholder plates: parallax, camera, rack focus, pose swaps, subtitles as text, skip with first-viewing confirm, pause in background, reduced-motion stills, the 3 s fallback to the still reveal
- [ ] 2.4 CP1 animatic: `art/contact/endgame-animatic.png` from a `review`-tagged test; operator review on a phone

## 3. Layout (bpy, CPU)

- [ ] 3.1 `tools/cinematic/layout.py` on `tools/rigkit/rigkit.py`: set blockout (table, board, patio, building), mannequins, the seven cameras from `shots.json`; clay, depth, normal and id passes per shot; `layout.json`
- [ ] 3.2 The carrier toy from the game's carrier mesh at the S1 camera; check the match-cut registration against the game's wreck frame (silhouette overlap ≥ 90 %)
- [ ] 3.3 Toy tip poses through `rigkit/bake.py` (6 to 8 frames with shadow)
- [ ] 3.4 Layout contact sheet `art/contact/endgame-layout.png`

## 4. Cast and figure sheets (GPU, installed models only)

- [ ] 4.1 Job files for `lua tools/production/run.lua`; run ledger `plan/render-runs/endgame-cinematic.md`
- [ ] 4.2 Model sheets for Mom, the owner, the waitress and the five kids: front, three-quarter, two expressions, beside the radio portrait; picks committed under `art/cinematic/endgame/selected/sheets/`
- [ ] 4.3 Figure sheet: the five brood colours, ship, tank, carrier, dice, cards, tokens
- [ ] 4.4 CP2: `art/contact/endgame-cast.png`; the three tests of the guide §11

## 5. Keyframes, plates and motion (GPU)

- [ ] 5.1 Seven keyframe stills from clay and depth with the sheets as references; S2 first as the vertical slice; picks and seeds committed
- [ ] 5.2 Sign, menu, chalkboard, tickets, box lid and placemat as typeset layers (never generated); letter check
- [ ] 5.3 Layer plates per shot (back plate, cast groups, props) with mattes; registration check against the id pass
- [ ] 5.4 Pose swaps (blink, head turn, arms up, smile) as edits from the still
- [ ] 5.5 Optional inserts (the pour, the surf) with the committed Fun VACE workflow, cropped, at most 33 frames; fall back to a fizz loop if the pour fails review
- [ ] 5.6 CP3 stills (`art/contact/endgame-keys.png`) and CP4 motion (`art/contact/endgame-motion.gif`)

## 6. Pack and integrate

- [ ] 6.1 `rigsheet` verb: grade, grain, despill, WebP encode, strip atlases, `assets/cinematic/endgame.json`; the size check (images ≤ 7 MB, audio ≤ 1.5 MB) in `scripts/build-web.sh`
- [ ] 6.2 Replace the still reveal in `lib/ending/ending_page.dart` with the player; keep the still as the fallback; `// --- endgame-cinematic` markers in `lib/main.dart`
- [ ] 6.3 Preload during the route-5 carrier fight; evict when the route closes; decode at 1024 wide on small screens
- [ ] 6.4 Run details R1 to R7: store the last completed run and the completion count in `lib/services/run_storage.dart`; typeset layers read them; defaults for a replay with no stored run
- [ ] 6.5 Replay control on the medal screen; rename the title tooltip; S8 after the credits
- [ ] 6.6 Tests: timeline, skip and confirm, background pause, reduced motion, fallback, replay leaves the run unchanged, portrait and landscape goldens (`review` tag); `test/ending_progression_test.dart` updated

## 7. Lines, plants and sound

- [ ] 7.1 With `voice-stack`: add `plant` (ledger ids) and `set` (`first` or `second`) to the line schema; the director's one-plant-per-sector ration and the second-set gate on the ending-seen flag; tests
- [ ] 7.2 With `voice-stack`: the tone check rejects plant lines that state the frame; append the accepted plant lines to `art/comms/lines.json`, regenerate `lib/comms/comms_bank.dart`, update the borrowed-line count in `test/comms_director_test.dart`
- [ ] 7.3 Vexxa's rank label and her presence in every sector, and the fleet's nickname for Gorrak, if the operator confirms decisions D1 and D2
- [ ] 7.4 Cinematic lines: the "room" chain in `art/comms/audio.json` terms; two child identities; the 12 clips as `final` tier; subtitles only until then (blocked on tillandsias#1103)
- [ ] 7.5 Ambience bed, the four echo sounds (fizz, bell, grill, neon) derived from the game's own sounds, the ukulele bars of the campaign theme (blocked on tillandsias#1103)
- [ ] 7.6 Ledger check (Lua + `jq`): every payoff layer in `shots.json` has a ledger row; every ledger row's shot, layer and line id exists; run it in the test gate

## 8. In-game art plants (after CP0)

- [ ] 8.1 The teal chevron on one Krybor outpost landmark and on Gorrak's cap; the same mark on the sign, cups and cap in the scene
- [ ] 8.2 Any other art plant the operator accepts from ledger §4.2, each as its own small task in the owning change

## 9. Release

- [ ] 9.1 CP5: the whole scene on the operator's phone, portrait and landscape, reduced motion on and off
- [ ] 9.2 `plan/asset-provenance.md` paragraphs, `assets/credits.json` entries, the run ledger closed
- [ ] 9.3 All gates of `CLAUDE.md` §2; `openspec validate endgame-cinematic --strict`; archive after the merge
