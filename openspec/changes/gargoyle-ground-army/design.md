# Design: the Undercroft Host

Art direction, roster and prompts: `plan/gargoyle-army-style-guide.md`. Research and sources: `plan/gargoyle-army-research.md`. This document covers the decisions, atlas contracts, simulation hooks and proof.

## Goals and non-goals
**Goals**
- One recognisable gargoyle ground army whose units read by role at phone size. The black-fill test runs at mid-field scale (×0.62).
- More legible ground war: who carries troops, who shells the convoy, who repairs, who commands.
- Reuse the v4 skirmish machinery. Every new behaviour is local to the skirmish layer.

**Non-goals**
- No new threat to the player. The threat front, ground missiles, breakthroughs, homing rules, scoring and difficulty are untouched.
- No change to the four threat vehicle rows (`ground-forces.png` rows 0–3). A refresh inside their cells is a separate, optional task.
- No new radio clips in this change.

## Decisions

### 1. "Carved" as the faction's tech language
Allies are *built* (welded grey-blue plate) and the swarm is *living* (membrane, hide). The Host is *carved*: dressed stone, iron bands, lead, chains, and stone that has faces and cracks. The alternatives:
- a grown biomass army would collide with well-known swarm factions and drift toward gore;
- a demonic-industrial army would blur with the allies' welded language.

Carved stone comes straight from the gargoyle's real history and keeps the game's "cracked stone, never blood" damage rule.

### 2. The spout rule as the telegraph grammar
A historical gargoyle is a waterspout: a channel along its back, water out of its mouth. Every Host weapon is a carved mouth fed by a back-channel. The telegraph is the channel filling, rear to front, in 2–3 warm segments, then the eyes flare, then the mouth blooms. Threat units keep their existing ground bracket in addition; skirmish units need no bracket because they never fire at the player.

### 3. Rank = height + gilt, never colour alone
Castes (Rubble → Ashlar → Tracery → Spire) are read through the height of the vertical ornament plus a new **`demon_gilt`** ramp: #1B1406 #36280D #644B18 #9A7324, luma ≤ 0.46. Gilt never blinks and covers at most 6% of pixels (Spire) or 2% (Tracery). That keeps it clearly below `demon_warm`, which stays the only blinking, brightest accent. "Pointed up = rank, open up = artillery" keeps command and artillery apart.

### 4. Atlases

**`assets/images/ground-host.png`**: cells of 48 × 40 texels, 16 columns × 12 rows (768 × 480 px), binary alpha, colours drawn from the ground family's reserved sets plus `demon_gilt` and the sector ramps.

| Row | Content | Tier |
| --- | --- | --- |
| 0 | Crocket | A |
| 1 | Reliquary | A |
| 2 | Carillon | A |
| 3 | Buttress Strider | A |
| 4 | Hodcrawler | A |
| 5 | Chapterhouse: move, telegraph, pulse, hit | A |
| 6 | Chapterhouse: banners, damage, fall | A |
| 7 | fx: slag shell ×2, bell ripple ×3, command ring ×3, smoke puff ×4, mortar seam ×2, rubble heap ×2 | A |
| 8 | Narthex | B (empty until made) |
| 9 | Rosegun | B |
| 10 | Thurible | B |
| 11 | Cistern | B |

Column layouts are generated into `lib/game/ground_host_atlas.dart` with a column map per row:

| Layout | Move | Telegraph | Fire | Recoil | Hit | Damage | Special | Wreck |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Tracked vehicle | 0–3 | 4–5 | 6 | 7 | 8 | 9–10 | 11–13 | 14–15 |
| Walker | 0–5 | 6–7 | 8 | — | 9 | 10–11 | 12–13 | 14–15 |

The Chapterhouse uses the walker layout over two rows.

**Sector tint.** The atlas stores the hull on a neutral stone ramp, and the painter maps the ramp per sector. Alternatively, the generator bakes five sector variants. This is resolved in task 2.3 by a size and draw-call check: baking five variants is 5 × 768 × 480, about 0.9 MB of RGBA in memory and about 60–90 KB compressed.

**`assets/images/ground-troops.png`** gains rows 6–8 (Rubbling, Knell-bearer, Prior) in its 32 × 24 cells, with the existing trooper columns:
- walk 0–3, aim 4, fire 5, hit 6, fall 7, rubble 8;
- Knell-bearers use aim and fire for the ring, plus 9 for the return swing;
- the Prior's 9–10 are the spire topple.

Rows 0–5 keep their indices. The atlas becomes 12 × 9 cells.

### 5. Tooling
`tools/ground_host` is Go, standard library only, as a sibling of `tools/ground_troops`, with the same `jobs`, `run`, `ingest`, `pack` and `offline` verbs. The forge prefers Lua, then Rust, then Go for new tools. Go is chosen here to share the existing ground_troops rasteriser and keyframe-shading code instead of porting it. Silhouettes and frames are authored on the grid. The selected ComfyUI keyframe contributes only a −1/0/+1 shading texture on the hull ramp, as for ground-troops. Large-model concept turnarounds are review references only.

### 6. Simulation hooks (skirmish layer)
New `GroundForce` values: `swarm`, `rally`, `officer`, `lightTank`, `apc`, `artillery`, `walker`, `mender` and `command` (Tier B: `superHeavy`, `rocketArtillery`, `smoke`, `tanker`, behind a flag).

Approach speeds are in texels/s × hostile rate. Every unit uses `GroundSkirmish.rng` only.

| Force | HP | Approach | Hold line | Weapon vs. its ally | Behaviour |
| --- | --- | --- | --- | --- | --- |
| swarm (Rubblings) | 1 per body (5–6) | 85 | U(430, 520) | thrown stone 0.8 s / 1 (small-arms tracer) | Routs to the horizon when a `command` within 160 texels falls |
| rally (Knell-bearers) | 2 | 50 | U(480, 600) | none | On each `groundTide` surge: units of the Host within 120 texels gain +20% approach and fire rate for 5 s (a bell ripple fx) |
| officer (Prior + 2 Ashlar) | 3 bodies, Prior last | 55 | U(440, 560) | 1.0 s / 1 | Squads within 150 texels widen their flank offset by 20 (presentation only) |
| lightTank (Crocket) | 3 | 120 | U(430, 520) | 1.1 s / 1 | — |
| apc (Reliquary) | 5 | 80 | U(450, 560) | ridge gun 1.6 s / 1 | Once, at its hold line or at ≤ 50% HP, unloads 3 Ashlar Guard as an infantry unit if the live cap allows (`reliquaryUnloading`) |
| artillery (Carillon) | 4 | 60 | U(620, 760) | arcing slag shell 3.2 s / 2 (new arc tracer) | Ranging: one tilt frame plus channel fill before the first salvo (`artilleryRanging`) |
| walker (Buttress Strider) | 5 | 45 | U(440, 540) | 1.8 s / 2 | `walkerSighted` at z ≤ 900 |
| mender (Hodcrawler) | 3 | 60 | trails the most damaged Host unit by 60 texels | 2.0 s / 1 | Mends +1 HP on the most damaged Host unit within 90 texels every 4 s |
| command (Chapterhouse) | 10 | 30 | U(600, 700) | none | At most one per visit. While alive, the arrival interval is ×0.85 (`hostCommandSighted`). Its fall (`hostCommandFallen`) routs swarm within 160 texels and forces the tide into a 6 s lull |

**Mix by sector** (Normal). Skirmish caps and intervals are **unchanged** from v4 (5 / 5 / 5 / 6 / 3); the new forces share them.

| Sector | Added Host forces (on top of v4's) | Command |
| --- | --- | --- |
| 1 Krybor | swarm, lightTank (captured hulls) | — |
| 2 Ringfall | + apc, mender | — |
| 3 Ember | + artillery, rally | — |
| 4 Hollow | + walker, officer | from route 1, once per visit, 20–40 s in |
| 5 Carrier | officer, apc, walker, artillery (obsidian elite) | from route 2, once per visit |

Weights live in the `SkirmishFront` table beside the existing ones. Each sector keeps at least 40% of arrivals as v4 forces, so the existing art stays in play.

**Invariants**, all inherited from v4 and re-proved:
- skirmish units never fire at the player and hold at ≥ 430 texels;
- they never move pressure or allied strength;
- they never draw from `model.random`;
- they are never homing targets;
- they never total an ally (fall back and repair, as v4).

Artillery shells, mending and rally boosts act only between the skirmish units and the convoy.

### 7. Presentation
- Host units draw from `ground-host.png` through `GroundPainter`, depth-sorted with the existing units and plants. Brightness ramps from 38% at the horizon, as now.
- The arc tracer is a 2-frame slag shell on a parabola from the Carillon's mouth to its ally. It is drawn on the ground layer under air threats, with a luma cap below hostile shots.
- Smoke (Tier B) stays outside the lane, or at no more than 30% alpha inside it.
- Telegraph frames play for 0.6 s before each Host shot, so the spout rule shows on every attack.
- With reduced motion, idle loops (banners, eye pulse, censer swing) freeze. Telegraphs, blooms and ripples become hard cuts.

### 8. Events
The events go in a `// --- undercroft host` block in `lib/game/game_events.dart`, each carrying `sector`, `x` and `y`. The minimum gap per event:

| Event | Min gap |
| --- | --- |
| `reliquaryUnloading` | 8 s |
| `artilleryRanging` | 10 s |
| `walkerSighted` | 12 s |
| `hostCommandSighted` | once per visit |
| `hostCommandFallen` | once per visit |

The music director adds nothing new: these events do not raise tiers, because they carry no threat. The comms layer maps them onto existing generic ground-war lines until new clips exist.

## Proof
- `test/ground_host_sim_test.dart`, built on `ground_war_v4_sim_test.dart`, flies every sector, every difficulty, fast and slow pilots, routes 0–2, with the Host forces off and on:
  - breakthroughs and ground shots at the player are **equal**;
  - allies retreated stays 0 in sectors 1–2;
  - every Tier A force appears at least once in its sectors;
  - the Chapterhouse appears at most once per visit.
- `test/ground_host_test.dart`: unload, mend, rally, rout, the artillery hold line and the invariants (no `model.random` draws, no homing targeting, no pressure change).
- `test/ground_host_visual_test.dart`: review frames at 360 × 780 and 1280 × 720 in every sector with the Host present, a black-fill sheet at ×0.62, and frame cost < 16 ms (v4 measured 1.1–2.7 ms).
- Atlas contract tests: cell sizes, binary alpha, palette membership, gilt coverage caps, no ally-cyan pixels on Host rows, and walkers keeping ≥ 3 texels of ground between their legs in every stride frame.

## Risks
- **Clutter on phones.** Mitigation: unchanged caps, Host units sharing them, artillery and command holding deep (small and fogged), and the black-fill review.
- **Hollow verdigris against ally teal.** Mitigation: hue ≤ 155°, low chroma, plus an automated nearest-colour check against `ally_cyan`.
- **Gilt read as a telegraph.** Mitigation: luma ≤ 0.46, coverage caps, and a no-animation rule enforced in the contract test (gilt pixels identical across a row's move frames).
- **Art budget.** Tier A is 6 vehicle rows plus 3 troop rows. Tier B stays behind a flag and can ship later without contract changes.

## Open questions
1. Should the Chapterhouse ever become a homing target, which would give the player a reason to pick a fight on the ground? Default: no (v4 rule). Revisit only with a balance proof.
2. Should the threat-vehicle refresh (Gutter-runner, Scrapmason, Kiln Ox, Belfry) be its own change?
3. Sector tint: runtime ramp mapping or baked variants (decision 4)?
