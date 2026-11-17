# Proposal: lightning rework (stun the brood, zap the ship)

## Why
Operator, 2026-11-17 (verbatim): "lightning is too punishing for the poor little demons, let's just stun them for a
moment, and have them drop of the sky for a brief instant and then recover flight. Hitting our ship with lightning on
the other hand should be punishing, being hit by lighning should drop all shields and powerups, but never cost a life.
This should also be explained in radio chatter "Avoid lightning!" and "Your fine, the ship can take it", "You're fine,
only the powerups are gone", etc. ... Similarly later on higher ranking gargoyles should avoid lightning much better, or
even wear armor with lightning rods that will empower them ;)"

Today a bolt deals a creature a heavy hit (2 damage, usually a kill) and costs the ship a life like any hostile hit
(`lib/game/bonus/levels/stormfront.dart`). Stormfront's goal, "Let the lightning zap the demons!", was built on that.

## What Changes
- **One lightning rule for every storm** (`lib/game/lightning.dart`, a `part of` the model, pure Dart): a bolt
  *stuns* the creatures in its column (a short fall with a tumble and a crackle, then a climb back to its place; no
  fire, no dive, no dodge, shield and armour down; shot down while stunned it scores its ordinary points) and *zaps* a
  ship in its core (every shield and power-up, bonus powers too, stripped at once and blown off the hull; never a life;
  1.5 s lightning grace). Regular sectors still have no lightning (dynamic-weather); a future storm calls the same API.
- **Rank avoidance:** each marked rank sidesteps a told column with a deterministic share that grows with rank
  (R1 25 % … R4 85 %) and route (+4 % a route), reacting earlier and faster the higher it is.
- **Lightning-rod armour:** sentinels from tour 2 and hunters from tour 3 wear iron rods in a storm; a bolt within 58
  units *charges* them (5 s, fire 1.8× as often, a violet glow and arcs between the rods) instead of stunning them, and
  they drift toward a tell to catch it.
- **Stormfront redesigned around the stun:** "Lure the lightning onto the demons!" / "Sit under them, slide away, then
  shoot them as they fall." Shooting a creature stunned by a baited bolt pays the bait bonus and the wave's first such
  kill drops the lightning rod; rosters 93 % of the sector's (the storm no longer kills), kills pay 77 %, slightly
  longer storm gaps; five-step pictogram.
- **Radio** (all written lines, `"pending": "text"`, voices blocked on tillandsias#1103): "Avoid lightning!" on every
  other tell on the ship (rate-limited, ends on the bolt), reassurance after a zap ("You're fine, only the power-ups
  are gone." / "You're fine, the ship can take it."), squad cues and brood yelps on stuns, warnings and gloats on a
  charge.
- **Presentation** (`lib/game/weather/lightning_painter.dart`, procedural): stun sparks and tumble, the rods (pick:
  shoulder rods, `plan/render-runs/lightning-rework.md`), the charge glow, static on the hull before a bolt, the zap
  burst, flicker and shield shards. Three sounds in `web/audio/demon-audio.js`.

## Capabilities
### New Capabilities
- `storm-lightning`: what a bolt does to creatures and to the ship, rank avoidance, rod armour, the lightning radio.
### Modified Capabilities
- `bonus-level-stormfront` (from `bonus-levels`): rosters, "does not take sides", scoring of storm kills, the rod, radio.
- `bonus-briefing` (from `bonus-briefing-clarity`): Stormfront's goal, how-to line and pictogram.

## Impact
- Code: new `lib/game/lightning.dart`, `lib/game/weather/lightning_painter.dart`; hooks marked `// --- lightning-rework`
  in `model.dart` (Demon fields, model state, stun step, fire filter, charge rate, the dodge offset in the formation
  target, stunned hits), `scene.dart` (tumble, gear, ship), `game_events.dart`, `comms_moments.dart`,
  `bonus_painters.dart`, `comms_briefing_view.dart`; Stormfront's `stormfront.dart` and `storm_cell.dart`.
- Radio: `art/comms/lines.json` (7 new triggers, `bonusCall.stormfront` reworded), regenerated `comms_bank.dart`.
- Balance: the calibrated campaign has no lightning, so its gates do not move; Stormfront re-measured with the bonus
  balance gate (design §8, `plan/calibration-current.md`).
- Tests: `test/lightning_rework_test.dart`, `test/bonus_stormfront_test.dart`; review sheets
  `test/lightning_rework_review_test.dart` → `art/contact/lightning-rework-{rods,storm}.png`.
- Order: archive after `bonus-levels` and `bonus-briefing-clarity` (their requirements are modified here).
