# Bonus levels: blocker log, agent B (bonus level #2, Stormfront)

Branch `work/bonus-levels-b`, 2026-11-15. Written while building a bonus level from the project's own documents and
agent A's interface note (`plan/bonus-levels-interface.md`), without asking anyone. Each entry says what was missing,
wrong or ambiguous, what I did about it, and what would remove the blocker for the next level.

Severity: **S** needed a significant change, **M** cost time or forced a guess, **L** small friction.

## 1. Framework (agent A's contract)

| # | Sev | Blocker | What I did | What would fix it |
|---|---|---|---|---|
| F1 | **S** | "A bonus level is data" has no place for a rule of play. `BonusLevelDef` describes waves, drops, crates, scoring and a colour grade; every level built from it is the regular fight with different numbers. A level with its own mechanic (here: lightning) cannot be written without model hooks, and the note's rule was "you do not edit `model.dart`, `scene.dart` or `main.dart`". | Added `BonusLevelDef.mechanic` (a constructor tear-off, default null) and `lib/game/bonus/bonus_mechanic.dart`: `BonusMechanic.step` / `idle`, made per visit from the level's own seed. Hooks: three lines in `model_bonus.dart`, one line in `model.dart` (`_bonusIdle` in the cinematic branch). The rules a mechanic must keep are in that file's header. | Keep the mechanic hook as part of the framework contract and say so in the interface note. |
| F2 | **S** | No way for a level to draw anything but a colour grade. `BonusLook` is a wash, a horizon light and haze. | Added `lib/game/bonus/bonus_painters.dart`: a registry by level id with `under` (after the grade) and `over` (after the fight), two calls in `scene.dart`. The painter is kept out of the model's import graph because `dart run tools/*.dart` runs the model without `dart:ui`; nothing documents that constraint (I found it from `tools/analyze_difficulty.dart`). | Document "the model is pure Dart, tools run it headless" in the README's project layout. |
| F3 | M | The model's event queue and the capped bonus score are private (`_queueGameEvent`, `_bonusCapped`), so code outside `model.dart`'s parts cannot emit a radio event or award capped points. | Added public `bonusEvent` and `bonusAward` to `ArcadeBonus`. | Same: part of the contract. |
| F4 | M | A bonus-only pickup announces itself as a regular power. `Pickup(x, y, power, bonus: def)` needs a filler `power` (the framework uses `Power.shield`), and `GameEventObserver` then says "Shield pickup falling. Grab it!" for a salvage magnet or a lightning rod. | One-line fix in `game_events.dart` (skip pickups with `bonus`). It affects level #1 too. | Make `Pickup.power` nullable, or give `Pickup` a named constructor for bonus powers. |
| F5 | M | `BonusPowerDef` is "a sum of primitives" (score scale, magnet, grants, fire rate). A power whose effect belongs to one level has no primitive. | The lightning rod has no primitive; Stormfront's mechanic checks `hasBonusPower('lightningRod')`. It works, but the catalogue cannot say what the rod does. | An optional free-text `effect` on `BonusPowerDef` for the console and the review studio, or accept that level-owned powers are opaque. |
| F6 | M | The first interface note and the code disagreed for about an hour: the note gave `bonusEntry.*` as `priority 6, ttl 6, transmission: true` (the code: `5 / 45 / 3`, no transmission), called `label` "HUD chip text" (the code: never drawn in play), and lacked `BonusLevelDef.label` (required), `BonusLook.glow`, `BonusPowerDef.twin`. A's second push corrected the note and added par scoring (`clearPar`, `flawlessPar`, `capPar`), after I had tuned flat awards. | Followed the code; re-measured and moved Stormfront to par shares (design, "Bonus level #2"). | A contract that is generated from the code, or a note that names the commit it describes. |
| F7 | M | Two agents append to the same generated files. `art/comms/lines.json` (end of file), `lib/comms/comms_bank.dart`, `plan/audio-studio/voice-batch-pending.md` and the hard-coded count in `test/comms_director_test.dart` (`expect(borrowed, 29)`) conflict on every parallel branch. | Appended my block, regenerated, set the count to 70 (29 + 23 + 18). Resolution recipe: keep both `lines.json` blocks, rerun `python3 -I tools/comms_pipeline.py dart`, add the counts. | Split `lines.json` per change (`art/comms/lines.d/*.json`, merged by the pipeline), and make the test count placeholders from the pending file instead of a literal. |
| F8 | L | `BonusLook.fog` is white haze only; a dark level cannot darken the horizon band. | Used a low value (0.14). | A fog colour. |
| F9 | L | The `/console` BONUS LEVEL row forces a level but not a seed, so a level cannot be replayed with the storm of a given run. | Tests use `startAt(runSeed:)`. | A seed field on `/console`. |

## 2. Radio

| # | Sev | Blocker | What I did | What would fix it |
|---|---|---|---|---|
| R1 | **S** | The level's own words cannot be heard or read. Voices are blocked (tillandsias#1103) and a pending line plays its placeholder **with the placeholder's subtitle and speaker**, so none of the 18 Stormfront lines is ever shown. The storm's radio is therefore assembled from existing lines that happen to fit ("Incoming from above, look sharp!", "Thanks for the thunder!", "Clean skies! That's the forecast I like."). The bank has no weather vocabulary at all. | Chose placeholders by meaning, one by one. Pending entries are in `plan/audio-studio/voice-batch-pending.md`. | Until #1103: allow a pending line to show its **own subtitle** over a neutral radio-static clip (text is truthful, audio is not speech), as an option per trigger. |
| R2 | M | No tool finds a recorded clip by its words. Choosing 18 placeholders meant an ad hoc regex over `lines.json` joined with the files in `web/audio/comms/`. The review studio filters by speaker, emotion and event, not by text, and it needs a browser. | Inline script (not committed). | `tools/comms_pipeline.py find <regex> [--recorded]`, or a text filter in the review studio's radio tab. |
| R3 | M | The task said "add pending entries to `plan/audio-studio/voice-batch-pending.md`", but that file is generated ("do not edit"). The entries come from `lines.json`. | Edited `lines.json` and regenerated. | Say so at the top of `plan/audio-studio/` (a two-line README). |
| R4 | M | A warning that must end on a moment (a dive, a rush) is a hard-coded `switch` on event names in `CommsDirector._handleTimed`. A new timed warning means editing the director. | Added a generic default: any event carrying `endIn` (seconds) gets its squad line end-aligned, or dropped if it cannot fit. Stormfront's `stormStrike` uses it. | Keep it; move `diveIn`, `rushIn`, `fireIn` to the same key over time. |
| R5 | M | Nothing documents that a raw string event (`model.events`) is forwarded as a `GameEvent` of the same name **and** sent to `audioSfx`. Queuing a structured event with the same name would have voiced it twice. I found it by reading `game_events.dart` and `main.dart`. | Raw `stormTell` / `stormBolt` carry the sound; structured `stormStrike` / `stormBait` carry the radio. | A short "events" section in the README or `plan/audio-backend.md`: the two channels, who consumes each, the `unforwarded` set. |
| R6 | L | The transition's radio slot picks a line only if its **placeholder's** duration fits the window, so which entry call can play depends on a clip chosen for its words. | Three entry lines with placeholders of different lengths. | Goes away with R1 / #1103. |
| R7 | L | Ground-crew speakers (Mensah, Kessler, Voss) are the only voices with "rain" and "thunder" lines; whether they may comment on the air fight is not written anywhere. | Used them (they are on the channel in every sector). | A line in the cast guide. |

## 3. Sound, art and style

| # | Sev | Blocker | What I did | What would fix it |
|---|---|---|---|---|
| A1 | M | Sound effects are `if (name === '…')` lines in `web/audio/demon-audio.js`; there is no table, no guide for adding one, and the shared noise buffer is 0.5 s long, which silently truncates a longer burst (a thunder roll). | Two lines in `groundSfx` (`stormTell`, `stormBolt`), the rumble as two overlapping bursts. Not audible in tests: there is no audio test harness, so the thunder is unverified by ear. | An SFX table (name → recipe) and a note on the buffer length; an offline render of one effect to a WAV for review. |
| A2 | M | The style guide has no weather, no lightning and no rule for a hazard that hurts both sides. Colour meaning had to be inferred: warm = hostile hazard markers (ground missiles), cyan/teal/violet = friendly technology, thermal gradients = dive shields. | Tell in warm amber (hazard), bolt white with a pale violet-white halo, never cyan. Written into the painter's header and the design. | A "hazards and weather" paragraph in `plan/style-guide.md`. |
| A3 | M | No accessibility rule for flashes. Reduced motion is specified for transitions, tilt and shake only. | Set my own limits and tested them: whole-screen flash ≤ 10 % white for 0.12 s, bolts at most once a second, no flicker, rain or flash with reduced motion. | A project-wide rule (flash area, alpha and rate) in the style guide and `arcade-presentation`. |
| A4 | L | Bonus-power badges are recoloured regular badges; the rod is the rapid-fire bolt in lavender. It reads, but two bonus powers on the same badge would not. | Used badge 1. | A small bonus-badge row in `combat.png` when the art pipeline is free. |
| A5 | L | No music cue for a level (`BonusLook.cue` exists, nothing reads it). The storm plays the sector's cue. | Events `stormTell`, `stormBolt`, `stormBait` are in the queue for the future music engine. | The dynamic music engine (R8 item 5). |

## 4. Specs and OpenSpec

| # | Sev | Blocker | What I did | What would fix it |
|---|---|---|---|---|
| S1 | M | Two agents, one change. OpenSpec has one `design.md` and one `tasks.md` per change; there is no convention for a second author. | My requirements are a capability of their own (`specs/bonus-level-stormfront/spec.md`); my design is one section and my tasks one group, appended at the end. | A convention in `openspec/project.md`: one capability spec per level, `design.md` sections named by level. |
| S2 | M | The project's rules live in change designs, not in specs. "Every lethal tell is at least one second of real time", "nothing starts while the ship is away", "transitions speak only by radio", "allies never die" are each stated in one change's design or in `plan/game-design.md`; `openspec/specs/` does not hold them as requirements a new level could be checked against. Most changes are not archived, so `openspec/specs/` lags the game. | Restated the ones that bind Stormfront as its own requirements. | Archive the finished changes; add a "rules every hazard keeps" requirement to `arcade-combat`. |
| S3 | L | No `CLAUDE.md` or `AGENTS.md`. `openspec/config.yaml`'s context still says "four demon-swarm levels … MIDI". The README's project layout lists six paths; the game has over a hundred source files. | Read the code. | A current project layout (the `// ---` section markers are a good index: list them). |
| S4 | L | `plan/roadmap.md` is a numbered history plus "left" notes; it does not say which changes are open. | Read `openspec/changes/` and the git log. | List the open changes there, or drop the file for `openspec list`. |

## 5. Tooling and the forge

| # | Sev | Blocker | What I did | What would fix it |
|---|---|---|---|---|
| T1 | M | "Lua > Rust > Go" against a Python-only pipeline. `tools/comms_pipeline.py` is the only way to regenerate the bank, and the forge's `lua` has no JSON module (`cjson`, `dkjson` absent), so even reading `lines.json` from Lua needs a hand-written parser. | Ran the project's Python stage as documented (`python3 -I`); used throwaway inline Python to inspect JSON; wrote no new tool. | Ship `lua-cjson` or `dkjson` in the forge image, or state that a project's existing Python pipeline is the sanctioned exception. |
| T2 | M | The first `flutter` call failed: `runtime_unavailable: podman failed at step source (timeout)` / `refused:flutter:host-toolchain-unavailable`. The retry worked. Other agents were using the lane at the time. | Retried. | The wrapper could retry once on a `source` timeout before refusing. |
| T3 | L | `git ls-remote origin work/bonus-levels-a` returns two refs (`refs/heads/…` and `refs/remotes/origin/…`), which broke a naive poll for A's push. | Polled `refs/heads/work/bonus-levels-a`. | — |
| T3b | M | A's branch was rewritten under me (rebased onto a newer `game` and amended: `d83fe73f` became `7c701d68`), after I had merged it as the task suggested ("merge or rebase"). A merge of a branch that is later rebased duplicates its commits. | `git rebase --onto work/bonus-levels-a <old A head>`; one conflict (the borrowed-line count). | A rule for parallel work refs: either never rewrite a pushed work branch, or dependants always rebase, never merge. |
| T4 | L | Every review strip copies about 120 lines of scene set-up (atlas loading, frame capture, sheet layout); this branch adds one more copy to about seventeen. | Copied `test/transition_ascent_review_test.dart`. | `test/support/review_harness.dart` (R10: a shared library before the next level). |
| T5 | L | The review harness draws the arena only: the comms dock, the HUD and the radio line cannot be shown on a strip, so "the level speaks by radio" is proven by tests, not by a picture. | Tests for the slot, the events and the bank. | A harness that pumps the page widget at phone size. |

## 6. What I could not verify

- **By ear:** the two sound effects and every radio line (no audio in the test host).
- **On a phone:** frame cost of the storm painter (at most about 60 short lines and three stroked paths per frame; I
  expect it to be negligible, but it was not measured on a device).
- **Balance:** the storm's numbers (a tell every 3.7-4.9 s on Normal, a 34-unit column, three damage, 100 points of
  bait per creature, cap 4000 per route step) are first guesses. The calibration tools measure the unseeded campaign
  only; nothing measures a bonus level.
- **Leaderboard fairness:** a bolt kills up to a column of creatures for ordinary points. A run with Stormfront may
  clear its sector faster than a regular one. The cap covers the bait and clear bonuses, not time.

## 7. Suggested next steps for organic growth (R10)

1. Promote `BonusMechanic` + `BonusPainters` to the documented way to add a level with its own rule, with Stormfront
   as the worked example.
2. One file per level for radio (`lines.d/`), and a clip search tool: the two steps that cost the most time here.
3. A shared review harness and a headless audio render, so a level's look and sound can both be reviewed from the
   forge.
4. A calibration run for bonus levels (`tools/analyze_difficulty.dart --bonus <id>`).
