# Ground war progression

## ADDED Requirements

### Requirement: Slow ground-force introduction
Ground forces SHALL appear only over sectors 1–4. On the first route, Normal and Hard SHALL field one unit, late in Krybor's final wave, and Easy none in Krybor. Unit budgets SHALL ramp gently with sector and route, ordered Easy ≤ Normal ≤ Hard, with at most three active at once. Skirmishing allies SHALL follow the same ramp.

#### Scenario: First Krybor
- **WHEN** a Normal run plays its first Krybor visit
- **THEN** exactly one ground unit appears, during the final wave

#### Scenario: Carrier
- **WHEN** the carrier level is fought
- **THEN** no ground units appear

### Requirement: Homing availability
While demon ground units are alive, each ordinary kill SHALL have a chance to drop homing missiles. A pity timer SHALL guarantee a drop after a few seconds of ground pressure, and the fleet SHALL air-drop one if no kill delivers it. Over the carrier, homing missiles SHALL drop as an ordinary kill-count power-up. No second drop SHALL occur while one is falling or a salvo is armed.

#### Scenario: Guarantee before range
- **WHEN** a fresh ground unit appears at the horizon and the player keeps destroying demons
- **THEN** a homing pickup drops before the unit reaches the near-ground fire line

### Requirement: Fleet intact tally
The model SHALL track per level and per run whether no ally retreated and no wingmate was lost. It SHALL emit `fleetIntact` at a clean level clear and at a clean campaign victory, and MAY award a bonus, never a penalty.

#### Scenario: Clean sector
- **WHEN** a sector is cleared without any ally retreating
- **THEN** a `fleetIntact` event with scope `level` fires
