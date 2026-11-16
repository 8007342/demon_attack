# Design

## Context
ArcadeModel holds one power and one countdown. Both firing branches and shield rendering compare this singular value, so collecting rapid cancels spread. The HUD uses a single arena label. The controller panel is a stable location that avoids covering the ship or demons.

## Goals / Non-Goals
Goals: fully concurrent effects, independent expiry and refresh, readable composite glyphs and accessible per-effect timing.
Non-goals: additional power types, permanent upgrades, stacking multiple charges of the same type, and a new art dependency.

## Decisions
- Replace singular state with a Power-keyed timer map, activePowers, hasPower and timeLeft. Use separate rapid/spread checks when constructing a volley; removing shield only removes its map entry.
- Retain existing nine-second duration and combat-only decrement. Recollecting refreshes its own type; same-run cycle transitions preserve the map and Start clears it.
- Draw a native pixel glyph with an outer violet shield, cyan three-arrow spread and central gold bolt. Existing pickup sprites have opaque backing tiles and would hide each other when literally stacked; independent transparent glyph paths remain readable together.
- Put the badge and three small timer rows inside the touch panel. Keep it noninteractive and allow all pointer events to continue to the controller.

## Risks / Trade-offs
- Rapid spread changes late-game damage → intended combined effect; verify volley count and shield behavior rather than changing enemy balance.
- Three glyphs could hide one another → spatially separate outer ring, side arrows and central bolt, and verify all three palette components in the rendered badge.

## Migration Plan
No persistent data changes. Update model callers and regression tests, validate release build and local browser, then push the final fix using the session branch workflow.
