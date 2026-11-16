# Proposal: a living, time-driven ground front

## Why
After playing `add-ground-forces-homing`, the user wants the ground alive almost from the start. In early levels the allies should win quietly in the background, and only later levels should let demon units break through to fire range. The old schedule was tied to air waves, so a skilled player who clears waves quickly saw almost nothing, and a slow player saw everything at once.

## What Changes
- **The front replaces the wave plan.** A per-sector `GroundFront` sets presence, arrival interval, first delay, demon toughness, base allied strength and base pressure. It runs on combat time, independent of air waves. The first unit arrives 5–7 s into Krybor on every difficulty, including Easy.
- **The allies fight back.** Allied fire now damages demon units. In sectors 1–2 every demon unit is escorted and the allies always win before fire range (guaranteed). In sector 3 breakthroughs are occasional; in sector 4 they are regular unless the player helps.
- **Two dynamic meters.** `GroundWar.alliedStrength` (0.2–1) is the chance a unit is met by an ally and how fast allies fire. Player homing kills and saves raise it ("allies push ahead"); retreats and breakthroughs lower it. `GroundWar.pressure` (0–1) responds to live, threatening and broken-through units, level progress and allied strength. It shortens arrival intervals and speeds demon fire. Only one broken-through unit fires at a time, so a slow player is never swamped.
- **Urgency events.** `allyUnderAttack` now means "calling for help": it fires once per unit predicted to break through (out-gunned or unescorted), before that happens. The new `groundBreakthrough` fires when a unit reaches fire range. The new `groundPressure` reports the meter at each tenth, for music intensity. `groundUnitDestroyed` gains `by: allies | homing`.
- **Homing drops.** A 30/25/20% chance per kill (Easy/Normal/Hard), a 3/4/5 s pity timer and an airdrop apply while a breakthrough looms or a broken-through unit can fire. Otherwise homing missiles are an ordinary pickup every 40 kills (the cadence of each module in the eight-kill rotation), over the carrier too.
- **Hints.** The missile-dodge card moves to the first Ember entrance and the homing card to the first Hollow entrance.

## Capabilities
### Modified Capabilities
- `arcade-progression`: a time-based ground front with allied strength and pressure; homing drop tuning.
- `arcade-combat`: allied fire destroys demon units; breakthroughs only from sector 3.
- `arcade-presentation`: call-for-help beacon and the new events.

## Impact
Changes `lib/game/ground_war.dart`, `game_events.dart`, `ground_painter.dart` (the distress beacon now shows only while calling for help), `hints.dart`, the tests, the profiler and the plan docs. No asset or API changes.
