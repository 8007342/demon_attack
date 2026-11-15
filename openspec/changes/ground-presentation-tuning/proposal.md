# Proposal: ground presentation tuning (operator playtest 2026-11-15, W1)

## Why
The operator's playtest of the ground-forces close-out ([plan/operator-feedback-2026-11-15.md](../../../plan/operator-feedback-2026-11-15.md),
W1) loved the assets, the walking robot tanks and the squads as groups, but the ground moves too fast to read as
distant events, the allied tanks are too big next to the enemy's, and the foot soldiers march in lock-step in fixed
groups:
- all ground animation at **at most 50 % of the current speed**;
- **allied (Fleet) tanks half the size, enemy (Host) tanks 30 % larger, soldiers 10 % smaller**;
- walkers (the legged robot tanks) walk **even slower** than the other troops;
- foot soldiers walk **individually** (own gait phase, spacing, small drift) while staying a group; groups of
  **1–5**, most often **2–4**.

## What Changes
- **`GroundPace`** (`lib/game/ground_presentation.dart`): one place for the presentation rates. Every ground cycle
  (vehicle move, tread and wheel cycles, idle, lights pulse, infantry walk, run, idle and fall, overlays, wreck
  flicker, totalled limp and pod), the hull and turret slew rates and minimum holds, purely visual ground effects
  (dust, flames, debris arcs, the shock ring, fireball and puff column of a wreck, crumble, skid dust), easter-egg
  motion (dances, jig, turret twirl, jackpot) and the critter leaps run at **0.5x**; walkers (Stilt, Kiln Ox,
  Buttress Strider, Belfry and the Chapterhouse) stride at **0.3x**.
- **`GroundSize`**: draw-scale multipliers on top of the perspective scale: Fleet vehicles **0.5x**, Host vehicles
  and the heavy tank **1.3x**, troopers of both factions **0.9x**. Runtime nearest-neighbour scaling; the atlases
  are not regenerated.
- **`GroundSquadLook`**: a squad is drawn as a group of **1–5** individuals (weights 1:3:4:3:1, so 2–4 five times in
  six; rocket teams 1–3), decoupled from the simulation's squad strength; each trooper has its own spacing, a
  slow drift, a lead or lag along the march, its own gait cadence (±15 %) and phase, and its own heading tracker
  that follows the squad's march through its own lag and hold, so the group turns one by one. Fallen troopers lie
  where they fell.
- Easter-egg running times in `EasterEggBudget.rules` are doubled for the one-shot eggs (dance 3.2 s, jig 2 s,
  jackpot 5 s, critter scatter 5 s); the looping sector-clear dance keeps 3 s.
- `GroundHeading` takes a `pace` (turn rate scale, hold stretched by its inverse) and a `hold` factor.

## Not changed (gameplay)
Unit travel speeds and positions, skirmish timing, the threat telegraph's timing and blink (the timing contract),
threat-vehicle launch clocks, fire flashes, recoil, hit flashes, tracers, wreck lifetime (6 s), squad hp and fire,
`GroundUnit.scale` / `width` / `bodyY` (placement, launch point, homing aim). The simulation fingerprint of every
sector is identical before and after. Slowing unit *travel* needs a gameplay change; design §3 proposes one.

## Follow-up: ground travel pace (gameplay; design §3a)
The operator delegated the travel decision. Skirmish units travel at **0.6×** (walkers **0.45×**), the v4 convoy at
0.6×; the skirmish hand-over moves out (`assignZ` 1050, `fireStartZ` 880) so engagements per minute hold; the
threat front (travel, telegraph and launch clocks, warning bracket) is unchanged. While marching, a legged unit's
walk cycle follows the ground it covers (`GroundStride`), so feet plant instead of sliding.

## Capabilities
### Modified Capabilities
- `arcade-presentation`: ground animation pace, ground unit draw sizes, squad groups of individuals; planted feet.
- `arcade-combat`: skirmish and convoy travel pace (follow-up).

## Impact
- **New code:** `lib/game/ground_presentation.dart`.
- **Changed:** `lib/game/ground_blocks_painter.dart`, `lib/game/ground_painter.dart`, `lib/game/ground_heading.dart`,
  `lib/game/easter_eggs.dart` (running times), `lib/game/flyover_background.dart` (critter leaps).
- **Tests:** `test/ground_presentation_tuning_test.dart` (new), `test/ground_easter_eggs_test.dart` (running times).
- **Untouched:** the simulation and its tests, the atmosphere and fog (`atmosphere.dart`, `ground_atmosphere.dart`,
  the battlefield smoke drift and walls: W2), HUD widgets (W5), the air swarm (W3).
