# Session roadmap

Work branch: `game`. Production `main` remains unchanged until stable.

1. Research original versions and write OpenSpec plus art/game/music direction.
2. Implement testable combat and original sprites/MIDI, persistent scores and responsive UI.
3. Validate phone/desktop input, score failure/retry, boss shielding, evolving cycles and web build.
4. Refresh managed Wrangler preview and push working checkpoints.
5. Playtest balance on the host browser, tune readability/feel, then consider a stable main merge.

Tracked implementation tasks: `openspec/changes/build-demon-attack-game/tasks.md`.
Current design and tunables: `game-design.md`. Art direction: `style-guide.md`.
Historical references and screenshots: `research-original.md`.
6. Flyover backgrounds (horizon pass, branch `work/parallax-refine`): left — check frame rate on a real phone GPU (the ground plane is a perspective image shader; CPU raster harness: `test/flyover_perf_test.dart`), and reroll the Ember Forges "forge-channel" landmark (it came out as a sphere) with `tools/flyover_assets.py run --only landmark/ember/2/forge-channel` after a prompt change.
7. Swarm perspective (branch `work/gargoyle-perspective`): gargoyles carry a simulated depth on the flyover camera; far arrivals fly out of the horizon small and hazed, the formation breathes, divers grow, hitboxes scale with the drawn size and the difficulty bot keeps hit rate, clear time and lives within ±6% ([perspective.md](perspective.md)). Left — judge the size pops and the faint diver shadows on a real phone; consider pre-baked half-size frames if 20-unit arrivals read too rough on low-DPI screens.

Asset pipeline (branch `research/local-image-large-models`): see `asset-pipeline/README.md`.
Left: stage-0 deterministic isolate/pixelize/QA scripts; consented I2/I3 ladder once Tillandsias #679 lands; ComfyUI workflow templates once studio lands; style LoRA; a vertical slice with one demon species' full frame set.

Ground forces rework (branch `work/ground-forces-design`, design only): `openspec/changes/ground-forces-rework/`. Left — operator review of the Fleet style guide, the 5-heading spec and the open questions; then rigs and the `offline` build (CP0), the 90-job pilot (CP1), production per `render-runs/ground-forces-rework.md`.

Bonus levels and run modifiers (branch `work/bonus-levels-a`, change `bonus-levels`): framework and bonus level #1 (Supply Run) are built and tested; contract in `bonus-levels-interface.md`, gaps in `bonus-levels-blockers-a.md`. Left — integrate bonus level #2 from `work/bonus-levels-b` (one catalogue line, its `lines.json` block, regenerate the comms bank, add its lines to the borrowed-line count); operator phone playtest through `/console` → BONUS LEVEL; calibrate the Supply Run's length and score shares and the modifier chances with the protected pilot; record the 23 voice lines when tillandsias#1103 unblocks.

Bonus level #2, Stormfront (branch `work/bonus-levels-b`, on top of `work/bonus-levels-a`): built and tested; design in `openspec/changes/bonus-levels/design.md` ("Bonus level #2"), gaps in `bonus-levels-blockers-b.md`. Left — merge after `work/bonus-levels-a`; operator phone playtest through `/console` → BONUS LEVEL → STORMFRONT (the storm's pace, the 34-unit column and the bait bonus are first guesses); listen to the two storm sound effects; record its 18 voice lines when tillandsias#1103 unblocks.
