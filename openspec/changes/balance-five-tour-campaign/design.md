# Design

## Context
See proposal.md for motivation. The current Dart model has four species, multi-hit elites, bounded repeat scaling, three lives and no completion state. CampaignStory shares five arrival/victory captions; SectorBackground combines five PNG worlds with procedurally painted stars and occupation scenery. Main owns title, HUD, cinematics and score rows. Scores currently contain only initials/score; the worker strictly rejects additional keys and prunes one global SQLite table to ten entries. Existing tests include endless-run, progression, cinematic, background, controls and score behavior.

## Goals / Non-Goals
**Goals:** Centralize difficulty/route tuning; retain deterministic model tests; make checkpoints independent of rendering internals; migrate existing scores without deletion.

**Non-Goals:** Exact mid-frame restoration, account synchronization, changing the established power combinations or ordinary enemy animation style, and production deployment in this change.

## Decisions

### Difficulty policy
Use an explicit difficulty enum separate from the existing RunMode phase enum. Policy owns starting lives, enemy speed/cadence, roster budgets, scoring and pickup probability. Easy scales hostile movement and firing rate to 0.9 while retaining player speed/fire; boss health is round(normal ×0.8). Normal/Hard retain current boss hit totals. Initial tuning: Easy enemy points ×0.75, Normal/Hard ×1; heart drop probability 4%/3%/0% per eligible enemy kill, sampled independently of existing powers. These values are proposed tuning defaults.

Preserve current Normal base rosters. Easy uses approximately 80%, Hard 120%, rounded with a minimum roster. Later-route extra roster growth is +1/+3/+4 enemies per route in Easy/Normal/Hard, with bounded counts and spacing. Raise the present 24-enemy ceiling only alongside layout and bullet-budget validation. Hard remains the strict life economy; greater density supplies its extra challenge. Avoid speeding all simulation time: that would also impair the player and distort elapsed time.

### Small checkpoints and separate history
Use browser local storage through a platform abstraction with a test/in-memory implementation and safe native fallback. It can hold compact JSON without sending state with HTTP requests as cookies would. Write once on each wave/boss entrance, not every frame or unload. Also clear on game over/completion and replace on a new run. Persist history only on failure or unlock events. Returning to title keeps the latest checkpoint.

Checkpoint fields: schemaVersion, difficulty, route index, sector, wave, score, lives, medals, kills, heart slots and activeMilliseconds. No positions, entities, power timers or random engine state. Restart the wave from its normal entrance; clear powers. Restore accumulated time from that same boundary, intentionally replaying any unsaved wave time and score. Validate known values; default missing optional fields, tolerate additional fields and preserve valid old route identifiers through mappings if names change. Do not reject merely because an optional version field differs. Malformed required route data disables Resume without blocking Start. A schema-less minimal checkpoint defaults to Normal, first route/sector, mode starting lives, zero medals/hearts/time and known score/wave. Current code has no checkpoint format to migrate.

Three failures before any boss victory unlock Easy permanently. Any boss victory records everBeatBoss; only Normal victory unlocks Hard. Resuming does not count as failure. History is separate so replaying a checkpoint cannot revoke earned unlocks.

### Rewards and finite progression
Keep internal route indices 0–4 while presenting names. Award medal count and +1UP once in the boss-defeat transition, then animate wreck, recognition and route departure. The next wave checkpoint includes committed rewards; interruption during reward presentation replays the preceding wave rather than stacking rewards. A distinct completed phase ends route five and captures remaining lives after +1UP for score submission. Count time in active combat updates only. Pauses, salvage, introductions and travel do not count.

Heart inventory is three sets of left/right/top bits. Fill the first set missing a picked part; when complete, increment lives and clear that set. Three left pieces occupy three sets; a fourth is ignored. Paint three complementary pieces of one heart outline, with clear left/right/top identity. Life HUD uses a count when icons cannot fit rather than truncating at three.

### Enemy and boss presentation
Add separate enemy archetype identity from existing species and damage stages so ordinary sprites keep their forms. Initial rare archetypes: a wide shielded line-wing sentinel and a heavier armored variant for later Normal/Hard waves. Spawn at final-wave refresh initially (the existing wave-introduction boundary, not an arbitrary mid-combat spawn); stronger modes gain later-wave eligibility. Bound simultaneous large threats, starting at one, with readable dive telegraphs and several-hit defenses. Use a unique wing breakup/falling-ember defeat sequence. Keep score/drop awards single-shot through the normal kill path.

Use one local centerline for boss belly, shield and hatch geometry so viewport scaling cannot introduce asymmetry. Shield health controls visible width/coverage; keep enough visible outline to distinguish active from broken. Core health drives smoke/sparks/flames. Preserve door timing/collision semantics and remove both bar/text health meters. Capture a wreck visual on death so removing the live boss does not erase the falling animation.

### Story and layered worlds
Use a 5×5 route table shared by HUD, arrivals, travel and backgrounds. Proposed sector variants, ordered by route:
- Krybor; Krybor Slums; Krybor Docks; Krybor Mountains; Krybor Command.
- Ringfall; Ringfall Patrol Belt; Ringfall Wreckfields; Ringfall Shipyards; Ringfall Blockade.
- Ember Moon; Ember Ashlands; Ember Forges; Ember Crucible; Ember Brood Heart.
- The Hollow; Hollow Outskirts; Hollow Towers; Hollow Catacombs; Hollow Throne.
- The Carrier; Brood Ark; Siege Carrier; Brood Citadel; Brood Flagship.

Retain existing world themes and original artwork. Add independently scrolling procedural terrain, silhouettes, orbital structures and occupation layers with distinct depth rates and route-specific composition. Later routes reveal more layers without obscuring projectiles. Caption writing connects the exact previous and next destinations and culminates at the base. Recognition uses fleet service language and an animated medal plus heart. Larger responsive text panels and travel bars use arena space; verify longest captions on narrow phones. Redraw the spread layer as twin cannon barrels with broad muzzle openings and angled weapon mounts, legible on its own and within the shield. Keep power status over the controller using an overlay/fixed guidance anchor, rather than allowing its width to change label placement.

### Scores and compatibility
Extend ScoreEntry and the worker payload with difficulty, medals, activeMilliseconds and remainingLives. Missing mode defaults to Normal; legacy rows use zero medals/time and no finisher lives. Display unknown legacy time as an em dash rather than implying a measured zero. Add SQLite columns with migration guards; preserve the current Durable Object identity so its scores survive. Filter and prune per mode, maintaining score-descending/id-ascending ties. Extend payload size limit deliberately and validate integer ranges and completion consistency before writes. Only include finisher lives for five-medal results. UI hides locked boards; this is a local progression feature, not authorization against direct endpoint access. Keep failed submission metadata immutable for retry.

## Risks / Trade-offs
- Wave replay can restore lost lives/score from its beginning → accepted checkpoint semantics; label Resume as restarting the saved wave.
- Browser data can be cleared or edited → unlocks are device-local and client scores remain trust-based, matching the current system.
- Roster growth can create excessive pressure → deterministic budget tests and playtest all five routes, especially Normal bosses and large-enemy overlap.
- Larger captions and score metadata crowd phones → responsive wrapping and browser verification at narrow/landscape sizes.
- Existing endless-run tests/specs conflict with a five-boss ending → replace the endless expectation while retaining regression coverage for prior phases and powers.

## Migration Plan
Implement additive worker schema/API compatibility before the extended client; retain old request support. Verify migration against a populated pre-change database and independent per-mode pruning. Validate local checkpoints with omitted/new fields. Complete model/widget/worker checks, then review managed Wrangler on phone and desktop. Do not deploy or merge as part of planning. For rollback, retain added columns and old scores; an older client can still submit legacy Normal payloads.
