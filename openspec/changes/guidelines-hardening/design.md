# Design: guidelines-hardening

## 1. Picks (made autonomously, 2026-11-16)

| Pick | Reason |
|---|---|
| `CLAUDE.md` is authoritative and `AGENTS.md` points to it | One copy of the rules can't drift. Nothing outside the repo survives a forge exit. |
| Archive in chronological order. `--skip-specs` for the four oldest changes, whose text was already hand-synced into the main specs; spec sync for the other eleven | The delta checker (`ADDED … already exists`) showed those four were already in main, while `balance-five-tour-campaign` and later had never been applied. Applying them oldest first keeps every later MODIFIED block on top. |
| Don't archive `boss-grandeur`, `bonus-levels`, `boss-hero-assets`, `terrain-shadows`, `transition-ascent`, `alien-insignia`, `pwa-install`, or any change with unchecked tasks | Other workstreams are still building on them (coordinator's limit). |
| Shorten over-long requirements by moving numbers into scenarios, keeping the requirement names | Open deltas aim at requirements by name. Renaming would break their MODIFIED targets. |
| No inline provenance edits in the D files (busy workstreams); citations listed in the audit only | Inline edits there would conflict with those branches. Task 6.2 applies them after they merge. |
| Defer every code blocker; derive nothing in `test/` either | Four agents are editing `lib/`, and two of them are adding radio lines that touch the same test count (blocker A16). |

## 2. Archived changes

`build-demon-attack-game`, `smooth-level-progression`, `combine-powerups` and `deepen-sector-campaign` were archived
with `--skip-specs`. These were archived with their spec deltas applied: `balance-five-tour-campaign`,
`sprite-64-grid-overhaul`, `add-ground-forces-homing`, `add-terrain-relief`, `tune-ground-war-front`, `ground-war-v4`,
`local-image-ship-asset-pipeline`, `comms-radio-v3`, `console-runs-final-ending`, `gameplay-round-3` and
`ground-forces-rework`. The archives created three main capabilities: `run-persistence`, `local-image-asset-pipeline`
and `squad-comms`. I wrote the `squad-comms` Purpose by hand.

## 3. Strict validation

Before: `openspec validate --all --strict` failed on 7 of 47 items. All seven failures were requirements longer than
500 characters. Fixed: `arcade-combat` (Scores and powers, Perspective-scaled swarm hitboxes), `arcade-presentation`
(Swarm perspective depth), `high-scores` (Inline landing Top10), `gameplay-round-3` (Life-loss sequence split into a
second requirement, Reserve ship return), `comms-middle-ground` (3), `fog-restoration` and `ground-blocks-runtime`.
The archives also exposed two `cinematic-flow` MODIFIED blocks that would have dropped scenarios added by
`balance-five-tour-campaign`. Slums and docks was copied in, and Fleet recognition was rewritten to the current
medal-glyph flourish.

After: 3 of 36 items still fail, for these reasons.

| Item | Why it is not fixed here |
|---|---|
| `arcade-presentation` "Layered power status glyph" | Open `ux-declutter` replaces it. Changing its scenarios now would break that delta. Task 5.1. |
| `arcade-progression` "Animated victory and travel" | Open `cinematic-flow` replaces it with shorter text. Task 5.1. |
| `third-party-licence-demucs-weights-unstated` (2 requirements) | The forge's licence acknowledgement tool wrote this record from a template that quotes the licence verbatim. A hand edit would drift from the signed record (`licences/acknowledgements/adefossez-htdemucs.yaml`). Task 5.2. |

## 4. Blind-test blocker triage

Of the 63 entries (A1–A31 plus A12a; B F1–F9, R1–R7, A1–A5, S1–S4, T1–T5 plus T3b), 34 were fixed by docs, config
or specs here (one of them in part, A7), or found already resolved. The other 29 are tasks with their reasons.

| Entry | Disposition |
|---|---|
| A1 level is not data | Task 2.1 (the `LevelDef` plan, §5) |
| A2 closed `enum Power` | Task 2.2 |
| A3 two run seeds | Task 2.3 |
| A4 homing pickup outside powers | Task 2.4 |
| A5 drops undocumented; README says three powers | **Fixed**: README; spec `arcade-combat` "Power drop sources" (checked against `model.dart`) |
| A6 no CLAUDE.md/AGENTS.md; layout | **Fixed**: `CLAUDE.md` §3, `AGENTS.md`, README layout |
| A7 main specs behind | **Fixed in part**: 15 archived. The rest are tasks 5.1 and 5.3. |
| A8 config context is the 2025 game | **Fixed**: `openspec/config.yaml` |
| A9 propose skill only plans; skill files uncommitted | **Fixed**: `CLAUDE.md` §6 says to write the artifacts by hand. The `.agents/skills` version question is task 7.1 (forge-managed). |
| A10 strict rejects long paragraphs | **Fixed**: `config.yaml` rules, `CLAUDE.md` §6 |
| A11 bonus level announcement | **Resolved**: the "URGENT MISSION!" radio card (`plan/bonus-levels-interface.md`, bonus-briefing) |
| A12 board fairness | **Resolved by the operator (2026-11-16)**: balance the levels with no board rule ("when you play you get what you get"); the medal screen records modifiers. That work is `bonus-balance` (B1). |
| A12a `--all --strict` fails | **Fixed**, except the 3 items in §3 |
| A13 special lines inaudible | Blocked on tillandsias#1103. `"pending": "text"` now shows their words (R1). |
| A14 line-bank schema buried | **Fixed**: `CLAUDE.md` §4 names the schema (`jq -r .comment art/comms/lines.json`) |
| A15 trigger names unchecked | Task 3.1 |
| A16 hard-coded borrowed count | Task 3.2. The merge recipe is in `CLAUDE.md` §4 for now. |
| A17 borrowed clips repeat | Task 3.3 |
| A18 modifier announcement vs opening tip | Task 3.4 |
| A19 no recipe for a small icon; atlas layout in comments | Task 4.1 |
| A20 bonus backdrop and music keyed by sector | Task 2.5 |
| A21 grade tuned on stills | Task 4.2 (`bonus-balance` owns the look) |
| A22 sector pay unrecorded | Task 4.3 |
| A23 calibration tools ignore bonus levels | Task 4.4 |
| A24 `sectorPar` underestimates | Task 4.4 (`bonus-balance`) |
| A25 flutter timeout under concurrency | **Fixed**: `CLAUDE.md` §2 (one at a time, retry once). Forge side: task 7.2. |
| A26 policy hook drops the whole command | **Fixed**: `CLAUDE.md` §9 |
| A27 not `dart format`-clean | **Fixed**: `CLAUDE.md` §3 rule (format only your own files) |
| A28 Lua rule vs Python pipeline | **Fixed**: `CLAUDE.md` §9 (existing Python pipelines are the sanctioned exception) |
| A29 long test run; how to read the verdict | **Fixed**: `CLAUDE.md` §2 |
| A30 review-strip boilerplate | Task 3.5 |
| A31 rebase vs pushed branch | **Fixed**: `CLAUDE.md` §1; spec `development-workflow` "Branch flow" |
| B F1 mechanic hook | **Resolved**: in the interface note's "Changes since the first commit" |
| B F2 model is pure Dart | **Fixed**: `CLAUDE.md` §3 |
| B F3 `bonusEvent` / `bonusAward` | **Resolved**: in the interface note |
| B F4 filler `Pickup.power` | Task 2.6 |
| B F5 opaque level-owned powers | Task 2.7 |
| B F6 note and code disagreed | **Resolved**: the note now names the commit it describes (`d83fe73f`) and lists later changes |
| B F7 shared generated files | Recipe **fixed** in `CLAUDE.md` §4. The per-change split `art/comms/lines.d/` is task 3.6. |
| B F8 no fog colour | Task 2.8 |
| B F9 console seed | Task 2.9 |
| B R1 pending lines can't show their words | **Resolved**: `"pending": "text"` (bonus-briefing; `plan/audio-studio/README.md`) |
| B R2 no clip search by words | Task 3.7 |
| B R3 pending file is generated | **Fixed**: `plan/audio-studio/README.md` |
| B R4 timed warnings hard-coded | `endIn` is kept. Migrating `diveIn`, `rushIn` and `fireIn` is task 3.8. |
| B R5 two event channels undocumented | **Fixed**: `plan/audio-backend.md` "Two event channels"; `CLAUDE.md` §3 |
| B R6 transition slot fits the placeholder | Goes away with #1103. Recorded with task 7.3. |
| B R7 may ground crew comment on the air fight | **Fixed** (pick: yes): `plan/audio-studio/README.md` |
| B A1 no SFX table; 0.5 s noise buffer | Buffer and recipe **documented** in `plan/audio-backend.md`. The table and an offline render are task 3.9. |
| B A2 no hazards and weather rule | **Fixed**: `plan/style-guide.md` "Hazards, weather and flashes" |
| B A3 no flash rule | **Fixed**: spec `arcade-presentation` "Flash safety" (WCAG 2.3.1, sourced) and the style guide. Auditing existing effects is task 4.5. |
| B A4 recoloured bonus badges | Task 4.1 |
| B A5 `BonusLook.cue` unread | Task 2.5 |
| B S1 two agents, one change | **Fixed**: `CLAUDE.md` §6, `config.yaml` rules |
| B S2 rules live in designs | **Fixed**: spec `arcade-combat` "Rules every hazard keeps", plus `development-workflow`. "Transitions speak only by radio" reaches main when `cinematic-flow` is archived (task 5.1). |
| B S3 CLAUDE.md, config, layout | **Fixed** (as A6, A8) |
| B S4 roadmap doesn't list open changes | **Fixed**: `plan/roadmap.md` points to `openspec list` |
| B T1 Lua has no JSON module | **Fixed**: `CLAUDE.md` §9 (use `jq`; Python pipelines are the exception). Forge image: task 7.2. |
| B T2 flutter source timeout | **Fixed** (doc) as A25. Forge retry: task 7.2. |
| B T3 `ls-remote` shows two refs | **Fixed**: `CLAUDE.md` §1 |
| B T3b dependants rebasing | **Fixed**: `CLAUDE.md` §1 |
| B T4 review harness copies | Task 3.5 |
| B T5 harness can't show the dock or HUD | Task 3.10 |

## 5. Plan: extract `LevelDef` from `model.dart` (task 2.1)

**Goal.** A level is data. Regular sectors and bonus levels go through one `LevelDef`, so a new level is a new
definition rather than new hooks in `model.dart`.

**Today.** The waves-per-sector formula exists three times: the `wavesPerLevel` getter (`model.dart` ≈949),
`ArcadeModel.wavesFor` (≈1010) and inline in `restoreCheckpoint` (≈1136). Bonus levels reach into the model
through 12 private hooks: `_bonusStartRun`, `_bonusBeginLevel`, `_bonusRoster`, `_bonusReinforcements`,
`_bonusKind`, `_bonusDrop` (×2), `_bonusKillPoints`, `_bonusCrateOpened`, `_bonusClear`, `_bonusStep`, `_bonusIdle`
and `_bonusForce`. Each is marked `// --- bonus levels`. The rosters, species, elites, sentinels, drops, score and
fire-rate rules come from `DifficultyPolicy` (`lib/game/difficulty.dart`) and from code spread through `model.dart`.

**Steps.** Each step is its own commit, and `flutter test` must stay green after each one, including the calibration
gates (`CLAUDE.md` §7):

1. *Characterise.* Add a golden test that records, for seed 1982 and each difficulty × route × sector, the wave
   count, each wave's roster (kinds, elites, reinforcements, sentinels), the drop sequence of the first 40 kills and
   the score of a scripted clear. Every later step must keep it byte-identical.
2. *One wave formula.* Add `LevelDef.waves(route, sector)` and point the three sites at it. No behaviour change.
3. *Introduce `LevelDef`* in `lib/game/level_def.dart`: `waves`, `roster(wave)`, `reinforcements(wave)`,
   `species`, `elites`, `sentinels`, `drops` (a `DropRule`, which has the eighth-kill cycle, the dive drop and the
   crate roll from spec "Power drop sources"), `scoreScale`, `fireRate`, `look` and `cue`. Add `RegularLevel(policy,
   route, sector)`, which wraps `DifficultyPolicy` unchanged.
4. *Route the model through it.* `ArcadeModel` holds `LevelDef current` and asks it at each existing hook point.
   The 12 `_bonus*` hooks become `current.<rule>` calls, and `BonusLevelDef` becomes a `LevelDef` that delegates to the
   `RegularLevel` it replaces, with its overrides. `model_bonus.dart` keeps run-plan drawing and the capped score.
5. *Key art and music by level, not by sector index* (blockers A20, B A5). `sector_background.dart` and the
   `audioCue('level', sector, …)` call take `current.look` and `current.cue`, which default to the sector's.
6. *Clean up.* Remove the `// --- bonus levels` hook markers that are no longer hooks. Update
   `plan/bonus-levels-interface.md` so that a bonus level is one `LevelDef` file plus a catalogue line, and keep the
   `mechanic` and painter hooks.

**Out of scope.** The power registry (task 2.2) comes after this and reuses `DropRule`.

**Preconditions.** Start only once `bonus-balance`, `playtest-fixes-3` and the boss work have merged into `game`,
because they edit the same hooks. The whole refactor should be one agent's branch, with no parallel `model.dart` work
while it runs.
