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
