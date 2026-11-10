# Ground war v4 presentation

## ADDED Requirements

### Requirement: Mixed forces by level
Demon ground forces SHALL mix sector vehicles with infantry squads from sector 1, rocket troopers from sector 2 and heavy tanks from sector 3. The convoy SHALL mix vehicles with rifle and rocket squads. Demon troopers are gargoyle-demon soldiers in military attire; their fallen crack into stone, never blood.

#### Scenario: Variety in a late sector
- **WHEN** sector 4 is flown for a minute
- **THEN** vehicles, infantry, rocket troopers and heavy tanks all appear, and the convoy fields vehicles, rifle squads and rocket squads

### Requirement: Full-width manoeuvre
Skirmish units SHALL manoeuvre laterally across the whole ground plane, including the central lane: along low ground, spreading out and flanking. Threat units SHALL weave inside their side band. The convoy SHALL escort the ship, advance only to engage, and fall back to its slots.

#### Scenario: Units weave across the plane
- **WHEN** sector 3 is flown
- **THEN** units range from the left to the right edge, and most weave by more than 25 units on their way in

### Requirement: Coarse, readable relief
The relief SHALL be coarse: fewer, far larger hills, ridges and valleys that reach across the lane, with no seam on the centre line. An additive slope-and-crest light SHALL make the relief read on dark grounds.

#### Scenario: Lane relief
- **WHEN** relief is sampled across many camera positions
- **THEN** the lane has hills (> 12 texels), the sides exceed 34 texels, and neighbouring columns at the centre line agree

### Requirement: Depth order with vegetation
A plant nearer than a ground unit SHALL be drawn in front of it.

#### Scenario: Plant in front
- **WHEN** a plant at depth 500 overlaps a unit at depth 600
- **THEN** the plant is painted after the unit

### Requirement: Ground war v4 radio events
The model SHALL queue `groundSkirmish`, `infantryEngaged`, `skirmishWon`, `allyFallingBack`, `heavyArmorSighted` and `groundTide`, each rate-limited, with `sector` and, where positional, `x` and `y`.

#### Scenario: Events in a skirmish-rich level
- **WHEN** sector 2 is flown for 100 s
- **THEN** `groundTide`, `groundSkirmish`, `infantryEngaged` and `skirmishWon` fire, with `groundSkirmish` at most once per 6 s
