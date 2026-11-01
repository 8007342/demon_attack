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

Asset pipeline (branch `research/local-image-large-models`): see `asset-pipeline/README.md`.
Left: stage-0 deterministic isolate/pixelize/QA scripts; consented I2/I3 ladder once Tillandsias #679 lands; ComfyUI workflow templates once studio lands; style LoRA; a vertical slice with one demon species' full frame set.
