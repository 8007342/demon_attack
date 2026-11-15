# Tasks: cinematic flow (W5b)

Prerequisites: `continuous-swarm` merged; `ux-declutter` merged (progress bars gone); `fog-restoration` merged or its
`cloudCover` / `fogThin` accessors agreed (design §6). Branch `work/cinematic-flow` off `game`. Each group is one
commit with `flutter analyze` and `flutter test` green. Group 6 (attract demo) is optional.

## 0. Archive order
- [x] 0.1 If `fluid-transitions` is still unarchived, archive it first, then rebase this change's spec deltas onto
      the resulting `arcade-presentation` text. Its "Alternating transition interludes", "Silent tips and radio
      cards" and "Readable, skippable, fluid cards" requirements become slot-based here. Add MODIFIED deltas for
      them at that point.

## 1. Director
- [x] 1.1 `lib/game/flow_director.dart`:
      - `bump`, `FlowBeat`, `FlowPlan`, `FlowDirector` (design §1);
      - plans for sectorChange, bossArrival, bossVictory, campaignOutro, gameOverOutro and attract, each in full
        and reduced motion;
      - whole-beat rounding of Pursuit;
      - `skipToDescent()`.
- [x] 1.2 `test/flow_director_test.dart`:
      - envelopes in [0, 1] and continuous;
      - every plan's swap beat lies inside cloud ≥ 0.85;
      - the radio and caption slots never overlap each other or the swap ± 0.5 s;
      - reduced plans have the same beat ids as full plans;
      - Pursuit is a whole number of beats.

## 2. Model phases
- [x] 2.1 `model.dart` cinematic branch of `_step` (the `if (cinematic)` block):
      - `levelClear` lasts 2.0 s, `travel` 4.0 s, plus reading time only when a slot is scheduled;
      - skip input (`ArcadeModel.skipTransition()`) jumps to the end of `travel`, never cutting the salvage grace;
      - the director is fed `transitionProgress`;
      - pause freezes it (already true of phase clocks).
- [x] 2.2 `swarm_stream.dart`:
      - `drain()` at the level's last wave;
      - `rout(dir)` on the last kill or the carrier's first chain blast (cosmetic reserve silhouettes, ≤ 18);
      - `preload(cohort)` in `_beginLevel`, placing the new sector's first cohort as reserve in the pursued
        flock's screen direction.
- [x] 2.3 Boss arrival (`_beginLevel` for level 5): the flock mills, opens the vacuole and pours into the bays when
      the carrier settles. It is cosmetic and removed before carrier combat. Boss victory: rout from the chain
      detonation.
- [x] 2.4 `test/cinematic_flow_test.dart` (design §7, model-level list).
      `test/campaign_run_test.dart` and `test/campaign_playtest_test.dart` must stay green; update only the
      phase-length assertions and list each one.

## 3. Presentation
- [x] 3.1 `scene.dart` cinematic drawing (the block around `mode == RunMode.levelClear / victory / travel`):
      - ship climb and camera tilt from envelopes;
      - the pursued flock (pattern `sweep`, silhouette tint) ahead of the ship;
      - the palette and backdrop swap under cloud ≥ 0.85;
      - the Descent placing the flock;
      - `Atmosphere.cloudCover` and `fogThin` driven from `env('cloud')` and `env('thin')`.
- [x] 3.2 Boss vacuole and the hangar pour, the victory remnant scatter, the game-over torus (design §3, §4.2).
- [x] 3.3 Campaign outro: fog thins, shadows lift, the climb above the clouds, a crossfade *up* into
      `lib/ending/ending_page.dart`. Update `test/ending_progression_test.dart`.
- [x] 3.4 Juice on the last kill: a 60 ms hit-stop (presentation clock only; the model is not paused) and shake
      ≤ 2 px gated by reduced motion.

## 4. Messages without cards
- [x] 4.1 `lib/widgets/transition_overlay.dart`, `lib/game/interlude.dart`, `lib/widgets/interlude_card.dart`,
      `lib/widgets/storyboard_banner.dart`:
      - sector transitions schedule a radio *slot* (a comms dock line with its subtitle) or a caption *slot*;
      - remove the interlude card, storyboard banner and sector pips from sector transitions;
      - keep the opening arrival's illustrated tip;
      - add a tips pane to the pause menu.

      Coordinate with whatever `ux-declutter` left in these files.
- [x] 4.2 `lib/widgets/flow_caption.dart`: one line at the bottom edge, 0.5 s fades, `readSeconds` timing, the
      sector title variant at the top edge (1.5 s).
- [x] 4.3 Medal and +1UP flourish beside the ship during Pursuit (the existing glyphs).
- [x] 4.4 Update `test/fluid_transitions_test.dart` (slots, not cards; alternation kept),
      `test/transition_loadout_test.dart`, `test/hints_test.dart` and `test/cinematic_scene_test.dart`.

## 5. Music
- [x] 5.1 `music_director.dart` / event timing: the `level` cue is requested on the beat boundary that ends
      Pursuit. Verify that `npm run test:worker` audio tests still pass (`levelclear` immediate, `travel` on a
      4-beat boundary, `level` on the grid).

## 6. Attract mode (optional)
- [ ] 6.1 The title backdrop: squads milling with `swarm_patterns.dart` (no model run), the sentinel silhouette,
      shadows. Frame-time check on the preview.
- [ ] 6.2 (Optional) `lib/game/demo_pilot.dart`: move the real-shot pilot out of
      `test/campaign_playtest_test.dart` (the test imports it from there). A 30 s idle starts a sector-1 demo run,
      with no score saved; any input returns to the title. Test: the demo completes a wave deterministically and
      never writes scores.

## 7. Review frames and playtest
- [ ] 7.1 `test/cinematic_flow_review_test.dart` (design §7):
      - 30 frames per kind;
      - the luminance, ship-displacement, direction and smoothness metrics as assertions where they are rules
        (no black, ≤ 6 u per frame, direction kept) and as a recorded table otherwise;
      - contact sheets to `.cache/cinematic-flow-review/` (`studio.contact_sheet` if available, otherwise a Lua
        tiler).
- [ ] 7.2 Preview capture at phone portrait: a sector change, a boss arrival, the campaign outro (console route),
      game over, and the title attract. Hand them to the operator with the open questions.

## 8. Docs and specs
- [ ] 8.1 `plan/transition-research.md` (append "Swarm-event transitions"), `plan/game-design.md` (transition
      flow).
- [ ] 8.2 `openspec validate cinematic-flow`; sync at archive (after `fluid-transitions`, see 0.1).
