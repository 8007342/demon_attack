# arcade-presentation updates

## MODIFIED Requirements

### Requirement: Layered power status glyph
The controller panel SHALL show a single composite pixel glyph formed from the visible layers of all active modifiers, with distinct spread arrows, rapid-fire lightning and an enclosing shield. It SHALL NOT show per-effect names, countdowns or duration bars; a layer SHALL blink during its effect's last 3 seconds, and the remaining seconds SHALL be available to assistive technology. Removing an effect SHALL remove only its glyph layer, and the status SHALL not block touch piloting.

#### Scenario: Triple combination
- **WHEN** all three modifiers are active
- **THEN** arrows, lightning and shield remain visible in the composite glyph, with no timer text or bar beside it

#### Scenario: Effect about to expire
- **WHEN** an effect has less than 3 seconds left
- **THEN** only its layer blinks, deterministically from the remaining time, and it freezes while paused

#### Scenario: One effect ends
- **WHEN** shield is consumed or an effect expires
- **THEN** the other layers remain visible and touch piloting continues

## ADDED Requirements

### Requirement: No progress bars in the game UI
The game UI (title, HUD, arena overlays, pilot console, transitions, score and ending screens) SHALL NOT show progress bars, progress strips, timer bars, segment meters, health or durability pips, or loading spinners. Information a bar used to carry SHALL appear only if the player needs it, and then as text already on screen or an icon state. The HUD SHALL remain the one place that names the sector and the wave. Developer tools (console, gallery, review studio) are out of scope.

#### Scenario: Wave change
- **WHEN** a new wave begins inside a sector
- **THEN** no card, strip or bar appears and the HUD shows the new wave number

#### Scenario: Sector release and carrier arrival
- **WHEN** a sector is cleared, the run travels, or the carrier arrives
- **THEN** the story card, interlude card or carrier alert shows without any progress bar or strip

#### Scenario: Loading
- **WHEN** the score board, ranking or credits are loading
- **THEN** a single quiet word stands in for a spinner
