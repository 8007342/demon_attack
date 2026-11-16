# Combined power status

## ADDED Requirements

### Requirement: Layered power status glyph
The controller panel SHALL show a single composite pixel glyph formed from the visible layers of all active modifiers, with distinct spread arrows, rapid-fire lightning and an enclosing shield. Each effect SHALL also show its own name, countdown and duration bar. Removing an effect SHALL remove only its glyph layer and timer, and the status SHALL not block touch piloting.

#### Scenario: Triple combination
- **WHEN** all three modifiers are active
- **THEN** arrows, lightning and shield remain visible in the composite glyph and all three independent countdowns are shown

#### Scenario: One effect ends
- **WHEN** shield is consumed or an effect expires
- **THEN** the other layers and countdowns remain visible and touch piloting continues
