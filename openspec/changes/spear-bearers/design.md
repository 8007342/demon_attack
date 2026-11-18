# Design: spear-bearers

Model: `lib/game/spear_bearers.dart` (`part of 'model.dart'`, pure Dart, no `dart:ui`). Painter:
`lib/game/spear_bearer_painter.dart`. Art: `tools/spear_bearers` → `assets/images/spear-bearers.png` and the generated
`lib/game/spear_bearer_atlas.dart`. Every hook in a shared file carries `// --- spear-bearers`.

## 1. Who and where ("the armored ones later")

The armoured ones are the **elites** (R3 hunters): the only small creatures with authored armour plates, the
winged-fang mark, demon-intelligence's planner and thread dive. A spear-bearer is an elite with a kit
(`Demon.spear`, a `SpearKit`); it keeps the elite's hit points (`ordinaryHealth(elite: true)`), its plates and its rank.

| | Normal, Hard | Easy |
|---|---|---|
| First route (0-based) | 2 (the third tour) | 3 (the fourth) |
| Sectors | 2–4 | 3–4 |
| Share of the wave's elites | the elite whose wave + elite ordinal is even | the same rule; Easy has one elite a wave, so every other wave |
| Never | bonus levels, the carrier sector (5), routes 0–1 | the same, and route 2 |

Why there:
- **Later, so it is learnt.** Routes 0–1 teach the hunter (elites start at route 1); lightning-rework gives hunters rods
  from route 2 as well, so "tour 3 is where hunters get gear" is one consistent beat. Easy waits a tour: its pilots get
  one more tour with the plain hunter.
- **Sector 1 of each tour stays a known fight**; the carrier sector keeps its own script; bonus levels keep their own
  rosters and rules.
- **Replace, never add.** `_ordinaryProfile` sets `spearRun.next` for the elite it just counted; the three birth sites
  wrap the new `Demon` in `_spearUp`. The roster, its HP sums and every random draw are unchanged, so the 318-wave
  defence budgets (`tools/analyze_difficulty.dart`) are untouched. It is *parity-based* and draws nothing: half of the
  elites, alternating by wave (Normal's budget is 2, Hard's 3, Easy's 1).
- **Rank.** Elite → hunter (`CombatAtlas.rankOf`). insignia-ranks (parallel, not pushed when this landed) reworks the
  ladder ("hunters and up get fangs"); the bearer takes whatever mark it gives the hunter rank. Hook:
  `SpearBearerPainter.rankOf` and its test.

## 2. The throw ("wielding the spear as they dive, and throwing it mid dive")

The dive itself is the hunter's (speed, thread dive, aim): no dive timing changes, so weather-everywhere's dive hooks
for smart demons stay independent. `_spearStep` runs once per creature per step, before the life-loss and stun steps,
and only reads the dive.

1. **Levelled.** From the tell on, the spear points at the ship (frame `spearLevel`).
2. **Wind-up, mid-dive.** When the bearer has come `windupAt` = 30 % of the way from where its dive began to the ship's
   row (`from + 0.3 · (shipY − from)`; y 241 from a formation slot at 140) it winds up for `windup` = 0.55
   hostile-rate seconds: 0.61 s on Easy, 0.55 s Normal, 0.52 s Hard. That is the telegraph: the spear drawn back over the
   shoulder (a big pose change), a white glint on its head that grows and pulses, and the `spearGlint` ting.
3. **Release.** One spear at where the ship is now (no lead: a player who moves dodges it), sideways speed clamped to
   ±90 u/s, falling at 255 u/s × the tour's speed on the hostile grid: about 0.6 s from the claw to the ship row. So the
   player gets ≈ 1.1 s from the first glint to the impact. It leaves from the levelled spear's head (7, 16 units from the
   centre × scale), the same point the art draws.
4. **Withheld** when the release point would be closer than 120 units above the ship's row (a dive that started low,
   or a regroup): the spear stays levelled. The ship being away also withholds it.
5. **Once a dive.** Empty-handed after the throw (the release pose for 0.35 s, then no spear); re-armed once it is no
   longer diving, entering or stunned (back on its station).
6. **No triple spread.** The hunter's three-shot spread is suppressed for a bearer (its attack timer still prepares
   dives): the spear replaces that pressure, it does not stack on it.

## 3. The buckler: knocked away (chosen) vs thinning

Two options were on the table: the shield *thins* under fire, or it is *knocked away*. Picked: **knocked away**.
- **Readable.** dive-shield-thinning already owns "a shield that thins" (the thermal crescent to its 40 % floor). A
  second thinning shield on the same creature would be two meters for one question. A physical buckler that is either
  there or tumbling off is a one-bit read at phone size.
- **Fair.** 2 points for the creature's *whole life*, never refreshed, so every hit the player lands is progress. The
  hunter's thermal shield is 2 points *per dive*, so over two or more dives the bearer is the softer of the two.
- **Rules.** While diving, a player hit from the front (not a homing missile, which comes round the side, and not a
  splash landing above the body's middle) spends `damage` buckler points and leaves the creature unhurt (overflow is
  absorbed: the buckler soaks the whole shot). At 0 it is knocked away: 25 × enemy points, a tumbling prop
  (`FallenBuckler`, 1.4 s), `bucklerOff`. In formation it is carried at the side and blocks nothing.
- **With the thermal shield.** `_igniteDiveShield` asks `_spearIgnite` first: while the buckler lasts it sets the dive
  shield to "spent but present" (max 1, points 0), which the hit test skips and the scene does not draw; the dive it is
  knocked off in keeps that (no instant thermal shield behind a lost buckler); later dives ignite the hunter's 2 points.
- **Lightning** (lightning-rework): a stunned bearer's guard is down (the buckler absorbs nothing, as a stunned
  creature's shield and armour), and the stun, which ends the dive, cancels a wind-up: no throw from a stunned bearer.

## 4. Sprites (`tools/spear_bearers`)

Gear overlays on the shipped gargoyles, drawn in the body's transform after the elite armour, so they scale with
perspective, fade with the fog reveal and follow the 3/4 bank (shifted 3 units by the bank). Frames (64 px cells):

| Row | Frames |
|---|---|
| 0 spear | idle (upright at the right side), levelled (dive, head at the release point), wind-up (drawn back over the shoulder), release (the empty claw flung open, two speed lines) |
| 1 buckler | carried (a 3/4 ellipse at the left side), raised (r 9.5 in front of the chest and belly), hit (white rim, a crack), knocked away (edge-on prop) |
| 2 | the thrown spear at leans −24, −12, 0, 12, 24°; the 15 px glint |

Palette and rules in `docs/styleguide/alien-troops.md` §5.6; picks and rejected candidates in
`plan/render-runs/spear-bearers.md`. The pipeline choice follows crosswind's §Pipelines: a small, state-driven sprite set
is best authored as pixels in code (no GPU, no raws to commit, byte-identical rebuild), not a diffusion raw downscaled
to 18 px.

## 5. Events, sound, wind

- **Structured** `spearThrow` (x, y, kind, throws) on each release: the war-cry hook. fang-and-wings-comms adds dive war
  cries through a structured event; its branch was not pushed when this landed. When it lands: merge it and voice a
  throw shout on `spearThrow` with its documented API and line ids.
- **Raw sounds** (`web/audio/demon-audio.js`, synth, no assets): `spearGlint`, `spearRelease`, `bucklerClang`,
  `bucklerOff`. None shares the structured event's name, so the radio never hears a throw twice.
- **Wind** (crosswind): the spear is a `Shot`, so `_windShot` drifts it like every hostile shot, and `_hostile` adds the
  brood's wind lead. The painter picks the lean from the drawn velocity, drift included, so a bent spear looks bent.

## 6. Balance

See `plan/calibration-current.md`, "Spear-bearers". The defence budgets are unchanged by construction (§1). The behaviour
is measured with the Average pilot on routes 2–4 (`dart run tools/ordinary_wave_probe.dart 24 routes=2,3,4
spears=off|on`).

## 7. Performance

At most three `drawImageRect` per bearer (buckler, spear, glint), one per spear in flight and one per falling buckler;
at most one bearer per wave on Normal and Hard (one in two waves on Easy). Thrown spears skip the shot layer's batch
(one extra call each). Nothing is tier-gated: every piece is gameplay readout. Reduced motion keeps the glint steady.

## 8. Gallery

`spear-bearers` page: "SPEAR-BEARER STATES" (the seven states on the four species) and "SPEAR-BEARER DIVE" (one dive in
a 4 s loop: levelled, wind-up, throw with a crosswind bending the spear, a buckler hit, the knock-off).

## Open questions

- Should the spear lead the ship a little on Hard? Today it aims at where the ship is (§6 has the measured effect).
- Should a bearer that lost its buckler regain one on a later tour's rosters? Today a buckler is per creature.
- A thrown spear could be shot down by the player (a parry). Not done: it would be the only destructible hostile shot.
