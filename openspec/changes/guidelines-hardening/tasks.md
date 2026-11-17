# Tasks: guidelines-hardening

## 1. Guidelines, config, archive, provenance (this branch)

- [x] 1.1 Write `CLAUDE.md` (authoritative) and `AGENTS.md`, and run every documented command
- [x] 1.2 Refresh `openspec/config.yaml` (context and rules) and `openspec/project.md`
- [x] 1.3 Archive the 15 finished, untouched changes in chronological order
- [x] 1.4 Fix the strict-validation failures, and record the three left (design §3)
- [x] 1.5 Promote durable rules: `development-workflow`, "Rules every hazard keeps", "Power drop sources", "Flash safety"
- [x] 1.6 Fix the doc and config blockers (design §4)
- [x] 1.7 Write the provenance audit (`plan/provenance-audit.md`), with inline citations and `UNSOURCED` marks for parts R and C

## 2. Model refactors (deferred: `lib/` is being edited by four workstreams)

- [ ] 2.1 Extract `LevelDef` from `model.dart`, following design §5. Blocker A1. Reason: needs all `model.dart` work merged first
- [ ] 2.2 Add a power registry (id, badge, colour, exclusions, effect primitives), with the five regular powers as entries. Blocker A2. Reason: changes every run's drops and three atlases; do it after 2.1
- [ ] 2.3 Unify the interlude planner's clock seed with the run seed (`start(runSeed:)`). Blocker A3. Reason: `lib/` code
- [ ] 2.4 Bring `HomingPickup` under the power or drop rules, so run modifiers can ban it. Blocker A4. Reason: `lib/` code, ground war
- [ ] 2.5 Key backdrops and music cues by level instead of sector index, and read `BonusLook.cue`. Blockers A20, B A5. Reason: `lib/` code; part of 2.1 step 5
- [ ] 2.6 Make `Pickup.power` nullable, or add a named constructor for bonus powers. Blocker B F4. Reason: `lib/` code
- [ ] 2.7 Add an optional `effect` description to `BonusPowerDef` for the console and the review studio. Blocker B F5. Reason: `lib/` code
- [ ] 2.8 Add a fog colour to `BonusLook`. Blocker B F8. Reason: `lib/` code
- [ ] 2.9 Add a seed field to the `/console` BONUS LEVEL row. Blocker B F9. Reason: `lib/` code

## 3. Radio, tests and tools (deferred)

- [ ] 3.1 Add a test that every `lines.json` trigger is an emitted `GameEvent` name or a documented variant. Blocker A15. Reason: needs an event-name registry in `lib/`
- [ ] 3.2 Derive the borrowed-line count in `test/comms_director_test.dart` from `lines.json` and the pending file. Blocker A16. Reason: two branches are adding lines and editing that count now; land it at integration
- [ ] 3.3 Apply the director's recency rule per clip, not per line id. Blocker A17. Reason: `lib/comms` code
- [ ] 3.4 Test what is heard when the run-modifier announcement meets the opening tip, and stop it repeating on resume. Blocker A18. Reason: `lib/` code and tests
- [ ] 3.5 Write a shared review harness (`test/support/review_scene.dart`) and migrate the review strips to it. Blockers A30, B T4. Reason: touches about 17 test files owned by open changes
- [ ] 3.6 Split `art/comms/lines.json` per change (`art/comms/lines.d/*.json`, merged by the pipeline). Blocker B F7. Reason: pipeline change while radio lines are in flight
- [ ] 3.7 Add a clip search by words (`find <regex> [--recorded]`), in Go or Lua with `jq`. Blocker B R2. Reason: new tool, not a doc fix
- [ ] 3.8 Move `diveIn`, `rushIn` and `fireIn` to the generic `endIn` key. Blocker B R4. Reason: `lib/comms` code
- [ ] 3.9 Replace the `if (name === …)` chain in `web/audio/demon-audio.js` with an SFX table, and add an offline WAV render for review. Blocker B A1. Reason: code
- [ ] 3.10 Add a harness that pumps the page widget at phone size, so strips can show the dock and HUD. Blocker B T5. Reason: test code

## 4. Art, balance and calibration (deferred)

- [ ] 4.1 Write a GPU-free recipe for adding one 64 px cell to an atlas, document `combat.png`'s layout outside `sprite_atlas.dart`, and add a small bonus-badge row. Blockers A19, B A4. Reason: art pipeline work
- [ ] 4.2 Retune the bonus colour grade in play rather than on stills. Blocker A21. Reason: owned by `bonus-balance`
- [ ] 4.3 Record in `plan/difficulty-calibration.md` what each sector pays (score per sector, per mode and route). Blocker A22. Reason: needs a measurement run
- [ ] 4.4 Teach `tools/analyze_difficulty.dart` and `tools/profile_difficulty.dart` bonus levels (`--bonus <id>`), and fix `sectorPar`. Blockers A23, A24. Reason: owned by `bonus-balance`
- [ ] 4.5 Audit the existing whole-screen effects (boss collapse, explosions, life loss) against "Flash safety", including reduced motion. Blocker B A3. Reason: a playtest or capture pass, possibly `lib/` changes

## 5. OpenSpec follow-ups (deferred)

- [ ] 5.1 Archive `ux-declutter`, `cinematic-flow` and the other open changes once their tasks are checked; that also clears the two long main requirements. Blocker A7. Reason: unchecked tasks
- [ ] 5.2 Ask the forge to keep generated licence records under 500 characters per requirement (template change), or accept the warning. Reason: forge-generated record
- [ ] 5.3 Archive `boss-grandeur`, `bonus-levels`, `boss-hero-assets`, `terrain-shadows`, `transition-ascent`, `alien-insignia` and `pwa-install` once their workstreams are idle. Reason: other workstreams are still building on them

## 6. Provenance follow-ups (deferred)

- [ ] 6.1 Act on the contradictions: C-09 (keep the AAC fallback for Safari, and fix the `battle-metal-radio-rework` design; **decided 2026-11-17: no fallback format (operator), the AAC twins are deleted and the design stands**), and D-13 and D-15 (the `pwa-install` design's dates and engine positions). Reason: decision and edit in other changes
- [ ] 6.2 Apply part D's citations and `UNSOURCED` marks inline once `bonus-levels`, `boss-*`, `terrain-shadows`, `transition-ascent`, `alien-insignia`, `pwa-install` and the style guides are idle. Reason: concurrent workstreams
- [ ] 6.3 Re-source the 35 `UNSOURCED` claims once the forge proxy lets the reference sites through (Wikipedia, arXiv, GDC Vault, Google's developer sites), checking each "candidate" first. Never bypass the proxy through host tools. Reason: those hosts reset connections from the forge on 2026-11-16
- [ ] 6.4 Align `plan/carrier-v3-research.md` and the `carrier-v3` design, whose **[S]** mark means "search snippet", with the `unread: snippet only` label. Reason: carrier-v3 is under concurrent work

## 7. Forge (outside this repo)

- [ ] 7.1 Decide which version of the `.agents/skills` OpenSpec skills is authoritative (OpenSpec 2.0.0 regenerated them over 1.14.3). Blocker A9. Reason: forge-managed files, never committed here
- [ ] 7.2 Forge: retry `flutter` once on a `source` or `list` timeout, and ship a Lua JSON module (`lua-cjson` or `dkjson`). Blockers A25, B T1, B T2. Reason: forge image
- [ ] 7.3 Voices and music: tillandsias#1103. Blockers A13, B R6. Reason: external; don't work around it
