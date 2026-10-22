## 1. Difficulty and finite campaign model
- [x] 1.1 Add explicit difficulty policy, starting lives, mode-dependent enemy points and roster budgets, Easy hostile speed/cadence and boss health tuning; preserve existing powers and player responsiveness.
- [x] 1.2 Add five-boss completion, once-only medal/+1UP rewards, combat-only accumulated time, and final remaining lives; replace endless-run expectations with bounded campaign tests.
- [x] 1.3 Add complementary heart drops, three-slot inventory and collection feedback in Easy/Normal, with Hard boss-only extra lives; verify duplicates, overflow and completed-slot reuse.

## 2. Checkpoints and unlocks
- [x] 2.1 Add version-tolerant compact checkpoint/history codecs, platform storage abstraction and safe unavailable-storage behavior; cover older missing fields, unknown fields and corruption.
- [x] 2.2 Save at wave and boss entrances only, clear terminal runs, restore checkpoints without powers, and expose Resume Game; verify score/lives/route/medals/hearts/time restore together and replay cannot duplicate rewards.
- [x] 2.3 Persist three-failure Easy unlock and Normal-boss Hard unlock; expose unlocked start buttons and retain permanent unlocks independently of checkpoints.

## 3. Enemy variety and carrier visuals
- [x] 3.1 Add rare broad-wing shielded/armored sentinel archetypes and later-route variants, final-wave refresh eligibility, later Normal/Hard wave eligibility, bounded counts, multi-hit dives and unique defeat animation.
- [x] 3.2 Center belly/shield/hatch geometry on a shared coordinate, replace boss meters with depleting shield coverage and escalating damage effects, and retain a falling-wreck cinematic after boss removal.
- [x] 3.3 Verify difficulty density order and bounded later-route scaling, enemy telegraphs, hit rules, single kill rewards and shield/core door collision regression.

## 4. Story and presentation
- [x] 4.1 Implement the 25 named route destinations and connected arrivals/departures/recognition/final ending; replace numeric level/cycle HUD headings and display arbitrary life counts.
- [x] 4.2 Compose distinctive same-theme parallax variants with independent layer rates and increased later-route complexity; preserve projectile readability and existing creature/power artwork.
- [x] 4.3 Create five medal designs per difficulty with increasing detail and corresponding silhouettes; animate medal and +1UP recognition between carrier collapse and the next destination.
- [x] 4.4 Enlarge cinematic text and travel progress bars responsively; fix controller guidance displacement under composite power status while retaining drag input and timers, and redraw the standalone spread glyph as clearly recognizable twin cannons without cross-shaped silhouettes.

## 5. Durable mode scores
- [x] 5.1 Add backward-compatible SQLite achievement columns, validated expanded API payloads and independent mode filtering/pruning while preserving existing Normal scores and stable ties.
- [x] 5.2 Extend score client/result metadata and retries; show unlocked-mode tabs, five medal positions, active time and finisher heart × remaining lives on responsive score rows.
- [x] 5.3 Verify populated legacy database migration, old payloads, malformed metadata, independent Top10 pruning and metadata-preserving network retries with worker/client tests.

## 6. Integrated validation and documentation
- [x] 6.1 Run Flutter analysis/tests and worker tests; update relevant widget, progression, cinematic and background coverage for this campaign while preserving existing controls/power regressions.
- [x] 6.2 Validate managed Wrangler on desktop, narrow phone and landscape: unlocked boards, checkpoint reload, all heart states, controller alignment, boss symmetry, legible interludes and medal rows.
- [x] 6.3 Playtest all five routes in each mode using a reproducible harness where needed; assess Normal boss pressure, Easy accessibility, rare-enemy overlap and final reward/completion flow, then adjust documented tuning.
- [x] 6.4 Update plan/game-design.md and README with the implemented balance, storage semantics, mode unlocks, named route and leaderboard behavior; validate the OpenSpec change without deploying production.

## 7. Pixel style and readability follow-up
- [x] 7.1 Reconcile persistent art/animation guides and presentation specs with the current campaign; document pixel grids, frame animation, slow segmented sentinel wings, sprite warnings/effects and readable route storytelling; validate specs.
- [x] 7.2 Replace vector sentinel/warning/carrier damage effects with original pixel sprite frames and review native/enlarged render captures against the atlas palette and animation guide.
- [x] 7.3 Gate sentinels after the first boss, stage a slow entrance after the swarm, hover above its protection, and launch a telegraphed heavy fast dive; verify gate, vertical separation, entrance safety and return behavior.
- [x] 7.4 Reduce rare heart drops and make the three complementary-piece slots and completed-heart collapse/+1UP clearly visible; test duplicates, reuse, notification timing and stored inventory compatibility.
- [x] 7.5 Enlarge cinematic captions, extend each story phase by roughly one third of a second, and make named route details recognizable in matching parallax scenery; verify narrow-phone/landscape layout, pause and phase timing.
- [x] 7.6 Run relevant/full checks, rebuild release assets, reload managed local preview and verify browser renders before telling the user to reload; record results and push the game branch.

## 8. Injured sentinel last stand
- [x] 8.1 Add a rare low-health self-sacrifice attack for only a minority of sentinels: distinct movement tell, fixed sampled aim, fast rush, interruptible by player fire, one-way impact/exit removal without player kill rewards; test dodging, pause and once-only cleanup.
- [x] 8.2 Give the last-stand tell and rush distinct pixel sprite poses/charge markings, persist the warning and fairness rules in art/combat specs, and review rendered frames.
- [x] 8.3 Re-run integrated checks, rebuild/reload the local preview including the last-stand change and report when to reload.

## 9. Layered swarm combat refinement
- [x] 9.1 Add finite escalating mid-wave flocks and strong sentinel escort arrivals, with meaningful initial shields/armor, bounded shot evasion, distinct faster sentinel bullets and tested wave completion/checkpoint replay.
- [x] 9.2 Revise articulated wide-wing flight, predatory dives and final-rush sprites; remove external ordinary-enemy tell marks, soften explosion opacity, refine smoke and render damage-driven angry carrier eyes/motion with randomized opening direction; review pixel frames.
- [x] 9.3 Change hearts to four complementary quadrants, migrate legacy top pieces into both top quarters without losing progress, and verify four-part UI/assembly/overflow/restore.
- [x] 9.4 Reduce power-drop frequency, add mutually replacing Powerful/Fast and Large/Spread groups, double-damage and bounded area-hit behavior, unique projectiles/pickups and composable shield glyphs; test timers, damage, gates and rewards.
- [x] 9.5 Make Hard unlock Easy, migrate existing Hard histories, and use neutral Top10 heading with difficulty tabs as the only mode labels; verify landing behavior.
- [ ] 9.6 Update persistent specs/guides, run model/widget/worker/browser checks, rebuild/reload the local preview, record results and push the game branch.

## 10. Illustrated tactical arrivals
- [x] 10.1 Research brief visual-instruction usability from primary sources, persist sourced readability/timing/accessibility guidelines, and design concise contextual hints with no immediate repeats.
- [x] 10.2 Generate and review original detailed pixel-art hint illustrations, connect a tested hint catalog/shuffle bag, and verify the shield-consumption invulnerability/refill tactic against gameplay.
- [x] 10.3 Replace repeated first-wave arrival story with stable illustrated hints, retain travel storytelling, provide pause/untimed field-guide review, and test phone/landscape presentation and selection boundaries.
- [ ] 10.4 Validate all ongoing refinements together, rebuild/reload the preview, record evidence and push game before reporting readiness.
