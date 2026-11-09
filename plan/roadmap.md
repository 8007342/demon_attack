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
6. Flyover backgrounds (branch `work/parallax-flyover`): left — eyeball the flyover on a real phone GPU (headless host Chromium is software-rendered: ~2x slower than the old background there), consider pre-baking the veiled sky per sector if real devices drop frames, and replace the weakest generated landmarks (Ringfall Patrol Belt sphere/gate, Ember Forges channel) by rerunning their jobs with new prompts (`tools/flyover_assets.py run --only landmark/...`).

Asset pipeline (branch `research/local-image-large-models`): see `asset-pipeline/README.md`.
Left: stage-0 deterministic isolate/pixelize/QA scripts; consented I2/I3 ladder once Tillandsias #679 lands; ComfyUI workflow templates once studio lands; style LoRA; a vertical slice with one demon species' full frame set.
