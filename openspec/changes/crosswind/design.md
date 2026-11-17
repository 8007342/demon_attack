# Design: crosswind

The operator's request and the later direction on demons are quoted in `proposal.md`. Builds on dynamic-weather (the
seeded plan and the stateless layers), fire-rate-tune (the shot speeds and the 15 u/s anti-strobe grid),
phone-performance (the tiers, `ShotLayer`), bonus-levels (catalogue, mechanic, painters), bonus-briefing-clarity (the
card and its one radio line) and bonus-challenges (the 1UP framework, merged into this branch).

"Sometimes, just like thunder": thunder is Stormfront's (its lightning is now `lightning-rework`'s); the regular-level
weather that comes "sometimes" is the rain's seeded plan. The wind gets the same kind of plan, with its own salt, so the
two are independent and may coincide (then the rain slants with the wind).

## 1. The plan and the field (`lib/game/weather/wind_field.dart`, pure Dart)

`WindPlan.forLevel(runSeed, route:, sector:, bonus:)` draws from `Random((runSeed ^ 'WIND') + route·1013 +
sector·157)`, every number every time:

| Draw | Value |
|---|---|
| windy | p = 0.2, sectors 1–4; route 0 sector 1 (the run's first sector), sector 5, bonus levels and unseeded runs are calm |
| tier | breeze 55 %, gale 45 % (the crosswind tier is the bonus level's only) |
| start | half from the level's start; half at 10–40 s, rising over 4–8 s |
| stop | four in ten die away 40–80 s after the start, over 5–8 s |
| field seed | its own 30-bit draw |

Measured over 2000 seeds × 3 routes × the eligible sectors: 17–23 % windy (test).

`WindField(spec)` draws a fixed list of `WindShift`s from the field seed up to 900 s (at most 400): a hold (breeze
4.5–8 s, gale 3.5–6.5 s, crosswind 2.6–5 s), then a swing over 1.2–2.4 s to a new lateral strength (60 % of the time to
the other side; magnitude 0.45–0.9), with an along-screen component in 35 % of shifts (±0.45–1). A gust (20 %, 30 % in
the crosswind) is a 0.5 s surge to full strength that falls back to 0.5–0.8 on the same side 1.2–1.8 s later. A
±6 % flutter (two sines) rides on top. `at(t)` is a pure function of the time (binary search, smoothstep between
shifts) scaled by the spec's ramp in and out; `forecast(t) = at(t + 1.5)`.

| Constant | Value | Why |
|---|---|---|
| `peakDrift` breeze / gale / crosswind | 34 / 52 / 66 u/s | a full gale carries a player shot 12–30 u by the swarm's rows (one target width) |
| `settle` | 0.55 s | a shot is carried by the air: its sideways speed relaxes toward the wind's, never past it |
| `lead` | 1.5 s | every change is visible this long before it pushes (≥ the 1 s tell rule of bonus mechanics) |
| `tailwind` | 0.5 | along-screen strength at the muzzle that earns the speed-up |

## 2. Wind in the model (`lib/game/model_wind.dart`)

Hooks (`// --- crosswind`): `_windBeginLevel()` beside both `_bonusBeginLevel()` calls; `_windStep()` once per combat
step before the shot loop; `_windShot(s, dt)` inside it; `_windUnpush()` / `_windPush(dt)` around `_updateDemons`;
`_windLead` in `_hostile`. A calm level costs one null check per step and per shot and draws nothing, so every
unseeded calibration gate is unchanged draw for draw.

- **Shots, both sides:** `windVx += (W − windVx) · dt / 0.55` with `W = lateral · peakDrift` (no hostile-rate scaling:
  wind is wind). `ShotLayer.drawn` and the smear include it.
- **Speed-up (anti-strobe):** at the muzzle (the first step, `age == 0`), if the along wind at the shot's back is ≥ 0.5,
  `windVy = ±15 u/s` along its own track for the whole flight; never slower. 15 u/s is fire-rate-tune's hostile grid
  step (0.25 u per 60 Hz step), so a player shot goes from 8 to 8.25 u per step and a hostile climb stays on the grid:
  the rounded step length never beats below 15 Hz at 60 or 30 fps, the bound phone-performance §6 and fire-rate-tune
  accepted for hostile shots. +3 % for the player's 480, +6–10 % for hostile climbs ("a tiny little bit"). The smear
  cap (16 u) still covers a 495 u/s shot at 30 Hz (16.5 → 16).
- **Demons fight the wind** (the operator's direction): the flight code steers in still air; the push rides on top
  (`d.windOffset`), settling over 0.8 s toward `W · yield · 0.6 s` and fading with the wind, clamped to the arena. The
  yield is 0.24 − 0.02·species (heavier species steadier), × 0.7 elite, × 0.8 escort, × 0.6 in a committed dive, and
  0.08 for a sentinel: a full crosswind moves an ordinary creature at most about 9.5 u, a sentinel about 3 u. They lean
  into it: the bank gains `−lateral · 0.04 · (1 − yield)` per step (bounded by the bank's own clamp), so they visibly
  correct. Hostile shots are fired from the still-air position (at most a few units from the drawn one).
- **The brood aims with the wind** ("it's their planet"): a demon's shot gets `−0.6 ·` the drift it expects over its fall
  to the ship's row, as extra sideways speed. Without it the wind bent the brood's fire off the ship and made a windy
  level easier for the scripted pilot (§8).
- **Calls:** `windStart` (tier, sector, side) when the share passes 0.05; `windStop` when it falls under 0.02; at each
  shift's telegraph (1.5 s before it pushes), `windGust` (from, to, gust, strength, endIn 1.5) when it is a gust or a
  swing of ≥ 0.6 of full strength, never while the ship is away. Structured events: radio and music only (no raw string,
  so the radio never speaks twice).

## 3. Fairness: reading the wind

The player sees the wind before it acts: the windsock, the billows and the wisps all draw `forecast(t)`, the wind 1.5 s
ahead, and the sock pulses amber while a call is on; the radio and the `gust` stinger call big swings and gusts at the
same moment. Shots keep a straight-line feel for their first few frames (the 0.55 s settle), so a shot visibly bends,
not jumps. The brood's lead is partial (0.6), so a player who moves still dodges most aimed fire.

## 4. Look (`lib/game/weather/wind_layer.dart`)

Drawn by `DemonScene.paintArena` right after the rain (`// --- crosswind`): up to 7 billows (three soft radial puffs
each, stretched along the wind, alpha 0.08–0.18; a unit radial gradient scaled per puff, so no blur filter on any tier)
high in the sky, then up to 56 wisps (one `drawRawPoints` batch, length and count growing with strength, brighter in a
call), all moving by the integrated forecast (`run`), so a swing reverses them smoothly. The windsock (pole and four
tapering stripes, orange and white, 1.5×) sits at the arena's top-left corner (16, 30), clear of the score; it droops
when calm, stands out downwind at full strength and flutters (still with reduced motion). Under the play, like the rain:
only the sock is over it. Budget `FrameBudget.windScale` 1 / 0.6 / 0.35; reduced motion halves the wisps and slows the
stream to 0.35. A shower on a windy level takes `lateral · 0.3` as its slant (blended by the wind's share).

## 5. Crosswind: the level (`lib/game/bonus/levels/crosswind.dart`)

The squadron finds the brood flying kites in a gale. **Goal:** "Pop the kites riding the wind!" **How:** "Single shots
only. Aim upwind and let the gust carry it."

- `BonusLevelDef(id: 'crosswind', wind: true)`: the crosswind tier from start to end (`WindPlan.bonusLevel` on the
  level's seed). Sectors 2–4, routes 0–4, weight 1, appended after Stormfront (bonus-levels' append-only rule).
- Rules: `PowerRules(banned: {spread, rapid})`. `CrosswindMechanic` also strips carried-in Spread and Rapid each step and
  removes such drops; `PowerRules.merge` now lets a level's ban beat a run's `only` (Spread Only falls back to the
  regular cycle here). Powerful (single wing-cannon shots), Large and Shield stay: they help a deliberate shot.
- Waves: the sector's own (bonus-balance gates a bonus level's enemies and time against the sector it replaces); the
  kites come on top.
- **Kites:** 3 + min(route, 2) per wave, at most 3 at once, one every 2.8 s (first at 1.5 s). Each enters from the
  upwind edge at a height of 60–210 (from the top in a lull, |drift| < 10), rides the wind at 1.5 × a shot's drift plus
  14 u/s of its own, bobs ±12, and leaves when the wind carries it off or climbs away after 15 s. One player shot pops
  it (hit box 9 × 12 ember, 12 × 7 moth, +2, +6 for a blast round): 120 × (route + 1) through `bonusAward` (inside the
  level's cap), `kitePopped`; one that gets away, `kiteEscaped`. Kites never hurt the ship. Fixed draws per kite from
  the level's seed (`^ 0xC0157`), never `ArcadeModel.random`. At the clear the rest are let go (not counted).
- Scoring: kills × 0.6; clear 0.2 of the sector's par, flawless 0.1, cap 0.45 (Supply Run's shape).
- Look: a cold wind-scoured grade (`0xFF9FC4D8`, 0.2), glow, light fog; music cue `bonus-wind`.
- **Challenge** (bonus-challenges' API): `everyKite`, "POP EVERY KITE", icon `kite` (a new pictogram), fails on
  `kiteEscaped`, needs at least one `kitePopped` by the clear.

## 6. Kites, medal and how-to: the assets

- Kites: two species from the studio (SDXL + pixel-art-xl + LayerDiffuse, `sprite-transparent.json`), finished on the
  CPU by a new Go tool `tools/wind_kites` into a 168 × 60 atlas (`assets/images/wind-kites.png`, 4 KB): 5 bank frames
  (−24°..24°) and a torn frame per species. The tail is painted: a six-segment ribbon per kite, one line batch per
  species, streaming downwind. Picks and rejections: `plan/render-runs/wind-kites.md`.
- Mission medal: a `crosswind` hull in the rigkit layer family (windsock ribbon, white ring, orange kite emblem), one
  Qwen-Image-Edit job at denoise 0.72; `plan/render-runs/mission-medals.md` §9.
- Briefing card: `CrosswindHowTo` (windsock → a shot aimed off the kite bending in → pop), drawn with a painter.
- Challenge badge: `ChallengeIcons.paintKite`.

## 7. Radio, music, review

- Radio (`art/comms/lines.json`, appended; text-only, voices blocked on tillandsias#1103): `bonusCall.crosswind`
  (the card's one sentence), `bonusChallenge.crosswind`, `bonusChallengeEarned/Failed.crosswind`, `bonusEntry`,
  `bonusDare`, `bonusStart`, `bonusMidway`, `bonusCleared` for the level, `kitePopped` (squad cheers, brood "My kite!"),
  `kiteEscaped` (brood taunts first), and the regular levels' `windStart`, `windGust` (urgent, 9 s cooldown, 60 %),
  `windStop`. Family friendly; brood lines are grunts with a gloss.
- Music: the director looks for a section tagged with the level's id, then one named like `BonusLook.cue`; with neither
  it sends nothing and the music stays (tested with and without a `bonus-wind` section). Accents: `windGust` → `gust`,
  `bonusChallengeEarned` → `oneup`, `bonusChallengeFailed` → `challenge-fail`; the score player already returns
  nothing for an accent it has no stinger for.
- Review: `test/crosswind_review_test.dart` (tag `review`) → `art/contact/crosswind-sheet.png`: calm, breeze, gale,
  gale + rain, the level at 6 s and 16 s, a gale at LITE and with reduced motion. Gallery: three wind tiles on the
  weather page; Crosswind on the bonus page (it lists the catalogue).

## 8. Calibration

See `plan/calibration-current.md`, "Crosswind". Every calibration gate runs unseeded, so it is calm and unchanged. The
wind's own effect, measured with the Average pilot (`dart run tools/ordinary_wave_probe.dart 24 wind=on skill=S`:
sectors 1–4 of routes 0–2, 24 seeds, every eligible sector windy with the plan's own tiers and timings):

CALIBRATION_TABLE

## Pipelines

How flexible each pipeline proved, for this change (the operator: "good to figure out how flexible and extensible our
pipelines are early on").

| Pipeline | Used for | Time | Verdict |
|---|---|---|---|
| ComfyUI studio, `sprite-transparent.json` | kite candidates | 2 jobs, 94 s GPU, ~5 min with copying | **Easy.** Committed workflow + prompt override; no consent, no restart. The outputs vanish at forge exit, so they must be copied out at once. |
| New Go atlas tool (`tools/wind_kites`, modelled on `tools/ground_wildlife`) | kite atlas, Dart, sheets | ~40 min | **Works, but bespoke.** No shared Go package: load/crop/downscale/PNG/Dart-emit were copied (~half the tool). The raws drew kite strings, which needed a new body-crop. Offline rebuild is byte-identical on the first try. |
| rigkit layer family + Qwen edit (mission medal) | Crosswind medal | ~15 min, 66 s GPU | **The most extensible.** Data-only (a hull and three sets in the family JSON), clay right first time, the documented denoise 0.72 recipe worked unchanged. Friction: the run log is one-object-per-line JSON with no appender; `bake_layers` waits behind any other `forge-guard` heavy job. |
| Painters (wind layer, windsock, kite tails, how-to strip, badge pictogram) | everything animated or tiny | fastest | **Best for small, moving or state-driven art**: no art in `.git`, tier-aware, testable for counts. |
| Comms (`lines.json` + `comms_pipeline.py dart`) | radio lines | ~20 min | **Fragile formatting.** `jq` rewrites the whole hand-formatted file, so new triggers needed a custom jq formatter and a Lua splice; a merge with bonus-challenges conflicted textually and was resolved by re-splicing. Regeneration itself is quick and deterministic. |
| Review sheets (`*_review_test.dart`) | contact sheets | ~15 min | **Copy-paste.** The scene-loading harness (~190 lines) is duplicated per change; a shared `test/support/review_scene.dart` would cut that. |
| Calibration probe | wind deltas | 3 × ~10 min CPU | **Extensible:** two flags on `ordinary_wave_probe.dart` and a pilot option. Shell word-splitting cost one wasted run. |

Lessons: (1) a shared Go `spritekit` package (load raw + alpha, crop, downscale, finish, pack, emit Dart) would make a
new sprite family a JSON file and ~100 lines; (2) a `lines.json` formatter (or a JSON5/one-trigger-per-file layout)
would make radio edits and merges mechanical; (3) a shared review-scene harness.

## Open questions

- Should the wind push the player's ship too? The operator's words cover bullets and demons; the coordinator's note
  mentioned the ship in passing. Not done: it would change the controls' feel.
- `bonus-wind`, `gust`, `oneup` and `challenge-fail` need bonus-music's sections and stingers; until then they are
  silent by design.
- `lightning-rework` owns lightning; the weather hooks here are `_windBeginLevel`, `_windStep` and the scene's
  `wind.advance`/`paintSky`/`paintSock`.
