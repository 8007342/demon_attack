# Ground war v4 combat

## ADDED Requirements

### Requirement: Skirmish layer
Each sector 1–5 SHALL run a skirmish layer beside the threat front. Mixed demon forces arrive across the whole ground plane with a surge-and-lull tide and fight the convoy. Skirmish units SHALL never fire at the player and SHALL never reach fire range. They SHALL never change the ground pressure, allied strength or the shared random stream.

#### Scenario: Same threat
- **WHEN** a level is flown by the same deterministic pilot with the skirmish layer off and on
- **THEN** breakthroughs and ground missiles fired at the player are equal (zero in sectors 1–2), and visible ally–foe engagements per minute are at least three times higher in sectors 1–4

### Requirement: Fall back instead of retreat
A convoy ally battered in a skirmish SHALL fall back to its escort slot and repair (`allyFallingBack`) instead of being totalled. Only a threat engagement may total an ally.

#### Scenario: Fleet intact in early sectors
- **WHEN** sectors 1–2 are fought with the skirmish layer on
- **THEN** no ally retreats

### Requirement: Homing priority
Homing missiles SHALL keep preferring threat ground units. Skirmish units SHALL NOT be homing targets.

#### Scenario: Salvo with only skirmish units on the ground
- **WHEN** a salvo is armed and only skirmish units are on the ground
- **THEN** it targets air demons (or holds) as before
