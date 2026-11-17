# Design: lightning rework

Operator round 7b (2026-11-17, proposal). Builds on `bonus-levels` (Stormfront, `StormCell`), `bonus-balance` (the
gate), `bonus-briefing-clarity` (the card), `alien-insignia` / `gargoyle-insignia` (the rank ladder and the troop style
guide, `docs/styleguide/alien-troops.md`), `demon-intelligence` (deterministic, readable creature behaviour) and
`dynamic-weather` (regular sectors rain but never strike).

## 1. One rule, every storm
`lib/game/lightning.dart` (`part of 'model.dart'`, pure Dart, an extension on `ArcadeModel`) owns what a bolt does.
A storm (today Stormfront's mechanic) decides *where* and *when*; the model decides *what happens*:

| API | Does |
|---|---|
| `strikeLightning(x, column, {stunEvent, data})` | stuns every targetable creature in the column; charges rod-armoured ones within 58 u |
| `zapShip()` | strips the ship; false while protected, away, in its grace or in the life-loss sequence |
| `dodgeLightning(tells)` | sets each creature's dodge goal from the tells on screen (call once a step) |
| `stunKills` | creatures shot down while stunned since the storm last read it |

Regular sectors still have no lightning: dynamic-weather chose rain without strikes (its design, "No lightning, no
thunder and no flash in regular levels"). The operator's "applies to world weather" is met by construction: any
future storm (for example a stormy tier of `crosswind`'s scheduler) calls the same three functions and gets the stun,
the zap, the dodges and the rods. Adding strikes to regular sectors is left to the operator (open question 1).

## 2. The stun (parameters in `LightningTuning`)
| | Small creature | Sentinel |
|---|---:|---:|
| Fall | 0.45 s at 400 u/s², at most 44 u | 0.28 s, at most 18 u |
| Floor | never below the ship's row − 70 u | same |
| Climb back | ≤ 150 u/s across, ≤ 130 u/s up, to its live formation or pattern target | same |
| Whole stun | 0.9 s (fall + 0.45 s shortest climb) to 1.8 s (cap) | same |

While stunned (`Demon.stun > 0`) the creature's ordinary step is skipped (`_stunnedDemon`, hooked right after the
life-loss regroup in `_updateDemons`): it cannot fire (also filtered from the random shooter), prepare a dive, dive
(the bolt cancels dive, dive shield, tell and prep) or dodge. A life-loss regroup ends every stun (the swarm gathers).

**Points: a stunned creature shot down scores its ordinary points.** Justification: (a) the calibrated economy is
per kill (`_killBase`), so a stun multiplier would make storms out-score their sector and break the bonus balance gate;
(b) the stun already pays twice, as an easy target and with its shield and armour down; (c) the dive bonus (× 1.5)
does not apply because the bolt cancels the dive, so luring a bolt onto a diver trades the bonus for safety; (d)
Stormfront adds its own capped bait bonus (§7), so the reward for the skill lives inside the level's cap.

## 3. The zap
`zapShip()` strips every `powerTimers` entry and every bonus power, blows the modules off the hull as `FallingPart`s
(fixed fan-out velocities, −110 u/s up; nothing drawn from `random`), and sets `shipShock` 0.9 s (presentation),
`lightningGrace` 1.5 s and `shockLost`. It never touches `lives`, `invulnerable` or the life-loss sequence. A
protected (blinking) ship ignores the bolt as before. The grace makes a fork in the same instant, or the next bolt
1.5 s later, harmless; Stormfront's gap (≥ 2.5 s after a bolt plus a 1.15 s tell) means the grace never hides a
whole strike, it only stops a chain. Avoidability is unchanged: every bolt that can reach the ship keeps its ≥ 1 s tell
and its column never follows the ship, and the ship now shows static in the tell's second half (§5).

## 4. Rank avoidance (deterministic)
`lightningRank(d)` is the insignia ladder (`CombatAtlas.rankOf`, tested equal): R0 drone, R1 skirmisher, R2 veteran,
R3 hunter, R4 sentinel. For each tell, each creature has a fixed roll `lightningRoll(seed, strike index)` in [0, 1).
It dodges when the roll is under its rank's share:

| Rank | Share (route 0) | Reacts at tell progress | Sidestep speed |
|---|---:|---:|---:|
| R0 drone | 0 | never | — |
| R1 skirmisher | 25 % | 0.40 | 150 u/s |
| R2 veteran | 45 % | 0.35 | 160 u/s |
| R3 hunter | 70 % | 0.25 | 190 u/s |
| R4 sentinel | 85 % | 0.25 | 140 u/s (its body follows at ≤ 90 u/s) |

Each later route adds 4 points (routes 0-4, cap 95 %). Because the roll does not depend on the rank, a higher rank
dodges every bolt a lower rank would on the same roll (monotonic by construction; tested). The dodge is an x offset
(`Demon.boltDodge`) added to the formation, pattern or sentinel target, eased at the rank's speed toward a goal that
puts the *target* 10 u past the column's edge on the side the creature already leans to (toward the open side near a
wall); the goal is recomputed every step from the target without the offset, so the sway and shot evasions never
carry it back in, and it eases home once the tell ends. Every creature that decides to dodge clears the column before
the bolt (tested over 60 rolls per rank). Drones staying put keeps the bait fantasy: the small fry are what the pilot
lures the storm onto; the elite read the sky.

## 5. Lightning-rod armour
Worn in a storm by **sentinels from the second tour (route ≥ 1)** and **hunters from the third (route ≥ 2)**;
`lightningRodArmour(d, route)`, fitted by Stormfront's mechanic on every creature it sees. A rod-armoured creature is
never stunned. A bolt within 58 u of it (wider than the 34 u column: the rods attract it) **charges** it for 5 s:
its attack and volley timers run 1.8× faster (more triple volleys from hunters, more beak shots from sentinels), shown
by a violet-white halo, white-hot rod tips and an arc jumping between the rods. It also drifts toward a tell within
96 u (`dodgeLightning` sets its goal *into* the column), so a careless bait feeds it. Where they appear: Stormfront
only (the only storm), so tour 1 Stormfront has none, tour 2 has rodded sentinels, tours 3+ rodded sentinels and
hunters. Drones, skirmishers and veterans never wear rods.

### 5.1 The look (pipeline: a procedural painter)
The rods are drawn by `LightningPainter.rods` in the creature's own transform (so they scale with perspective, fade
with the fog reveal and tumble with the body), not baked into `combat.png`: the troop atlas is a Pillow/ComfyUI
pipeline (`tools/generate_sprites.py`) with no venv in this forge, and a gear overlay keeps one atlas for every tour.
Three candidates were drawn on the real scene with the rank glyphs (`art/contact/lightning-rework-rods.png`):
**shoulders** (two rods off the shoulders), **crest** (one rod from the skull), **crown** (three rods fanning).
Pick: **shoulders**, logged in `plan/render-runs/lightning-rework.md`: the rank glyph sits on the head anchor
(style guide §4), and only the shoulder pair leaves it clear; two spikes read as a pair at 0.5× where one crest rod
vanishes into the glyph and the crown's three tips merge into the winged-crown glyph. Colours: the brood's dark iron
(#2E2A33, edge #5A5262) with bone tips (the insignia's bone #E9DFC8); charged, the tips go to Stormfront's white
and violet-white. Never cyan or teal (friendly technology, `plan/style-guide.md`).

### 5.2 Other presentation
Stun: four short white arcs with a violet glow crawl over the body (re-forked 14×/s), and the body rolls ±0.55 rad
while it falls, ±0.22 easing out as it climbs. Ship: amber static sparks on the hull in a told core past the tell's
midpoint; on a zap a white-violet burst (0.9 s), three arcs over the hull, the ship hidden on alternate 20 Hz frames
for the first 0.45 s, a stripped shield's ring breaking into eight shards, and the modules tumbling off. Reduced
motion: no tumble, no flicker, arcs steady. The whole-screen flash stays Stormfront's faint ≤ 0.10.
Sounds (`web/audio/demon-audio.js`): `stormStun` (a crackle), `shipZapped` (a buzz and a falling sweep), `demonCharged`
(a rising whine).

## 6. Radio
All new lines are written lines (`"pending": "text"`: own words and speaker, no audio) while voices wait on
tillandsias#1103; the borrowed-line count stays 55.

| Trigger | When | Side | Pacing |
|---|---|---|---|
| `stormStrike.avoid` | every other tell on the ship (the first included), ends on the bolt | squad | shares `stormStrike`'s 11 s cooldown; ≤ 3 words so it fits the 1.15 s tell |
| `stormBait.stun` | a baited bolt stuns | squad cue, brood yelp 0.4 s later | 12 s, chance 0.85 |
| `lightningStun` | any other bolt stuns | squad (rare), brood | 14 s, chance 0.6 |
| `lightningShipHit[.powers/.clean]` | a zap | squad reassurance (a moment: never dropped as flavour), brood gloat | 8 s / 12 s |
| `lightningCharged` | rods drink a bolt | squad warning, brood roar | 12 s |

The operator's "Your fine" is written "You're fine". The voiced `stormStrike` lines alternate with "Avoid lightning!".
The old `stormBait` lines (about kills) stay in the bank for their clip ids but are no longer reached: the event now
always carries variant `stun`. Lanes: human and brood lines go to their own portrait lanes as before
(`portrait-comms-lanes`).

## 7. Stormfront, redesigned
Goal: **"Lure the lightning onto the demons!"** How: **"Sit under them, slide away, then shoot them as they fall."**
Radio call: "Lure the lightning onto the brood, then shoot them while they fall!" The pictogram gains a fifth step
(the stunned demon drops, the ship shoots it). Bait: a bolt aimed at the ship (or its fork) that misses the ship marks
the creatures it stunned; each one shot down while still stunned pays `baitPoints × (route + 1)` inside the level's
cap, and the wave's first drops the lightning rod. The rod still grounds the ship and widens the column (now a wider
stun). Rosters drop from × 1.15 (which compensated for storm kills) to × 0.93, kills pay 77 % (was 70 %) and the
storm strikes a little less often (Easy 3.4-4.6 s, Normal 3.3-4.7 s, Hard 3.4-4.8 s, Hard fork .25; §8).
`StormfrontMechanic` keeps `bolts`, `shipHits` (now zaps) and `StormStrike.hitShip`, so `bonus-challenges`' "dodge
every bolt" 1UP reads them unchanged; it adds `stuns`, `charges`, and `stormKills`/`baitKills` now count stunned
creatures shot down.

## 8. Balance
The calibrated campaign is unseeded and has no bonus levels or lightning, so its gates are untouched (difficulty
analysis identical before and after; `plan/calibration-current.md`). Stormfront is measured by the bonus balance gate
(`test/bonus_balance_test.dart`, routes 0-1, eight seeds, both pilots); the before and after tables and the tuning path
are in `plan/calibration-current.md` ("Lightning rework").

## 9. Parallel changes
- `crosswind` owns the weather scheduler; this change adds nothing to it (no scheduler hook), so a merge is clean.
- `bonus-challenges` (merged): "DODGE EVERY BOLT" stays meaningful. `_land` notes `boltHit` whenever a bolt strips
  the ship (a zap, with or without powers to lose), `boltGrazed` for a bolt in the bright column outside the core, and
  also for a bolt in the core during the zap's grace (it strips nothing but was not dodged); a grounded bolt and a
  protected ship note nothing, as before.
- `bonus-music`: its Stormfront `thunder` accent fires on `stormBait`, which is kept (a bolt drawn to the ship that
  misses it and stuns creatures; variant `stun`).

- `bonus-music`: `stormTell` / `stormBolt` raw events are unchanged; three new raw sound names are added.

## 10. Open questions
1. Should regular stormy sectors (crosswind's or dynamic-weather's heaviest tier) throw bolts now that they no longer
   kill? The API is ready; dynamic-weather ruled it out for flashing reasons.
2. Voice lines: the written lines wait for tillandsias#1103.
3. Should the old `stormBait` voiced lines be retired from the bank (their clip ids are positional)?
