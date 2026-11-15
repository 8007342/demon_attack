# Arcade presentation

## ADDED Requirements

### Requirement: Bonus levels enter and leave through the fog
A bonus level SHALL be reached and left by the ordinary sector transition: the rout, the pursuit into the cloud and the descent. No card, title, caption, banner or other text SHALL announce a bonus level, its rules, its award or a run modifier over the play area; they are announced by radio only. The skip, the pickup grace, the reduced-motion plan and the transition's length SHALL be the same as for a regular sector.

#### Scenario: Flying in
- **WHEN** the next sector of the run is its bonus level
- **THEN** the ship climbs into the cloud as for any sector change, the radio slot carries the bonus level's entry call, and no text is drawn over the play area

#### Scenario: Flying out
- **WHEN** the bonus level's last creature falls
- **THEN** the rout, pursuit and descent into the next regular sector play as usual

### Requirement: Bonus level look
A bonus level SHALL keep the replaced sector's backdrop, ground and creatures and MAY grade them with a colour wash, a light along the horizon and haze, defined as data with the level. The grade SHALL change only while the cloud cover is at least 85 %, as a plain crossfade that is the same with reduced motion, and SHALL never make the scene darker than the ungraded sector. It SHALL be drawn under ground units, creatures, the ship, shots and the HUD.

#### Scenario: Hidden change
- **WHEN** the run enters or leaves a bonus level
- **THEN** the grade fades in or out entirely inside the cloud

#### Scenario: Readability
- **WHEN** a graded and an ungraded frame of the same sector are compared
- **THEN** the graded frame is visibly different in colour and at least as bright

### Requirement: Bonus-only powerup badges
A bonus-only powerup SHALL be drawn with a badge from the existing pickup art, recoloured (and optionally doubled) so that it cannot be mistaken for a regular power, on its falling pickup and on its supply crate, whose parachute SHALL carry the same colour. While it is active, its badge SHALL ride beside the ship inside a ring that runs down with its timer and blinks in its last two seconds; no text SHALL label it over the play area.

#### Scenario: Falling bonus powerup
- **WHEN** a crate with a bonus-only powerup is shot open
- **THEN** a recoloured badge with a pulsing halo falls from it

#### Scenario: Active bonus powerup
- **WHEN** the ship holds a bonus-only powerup
- **THEN** its badge and countdown ring follow the ship until it runs out
