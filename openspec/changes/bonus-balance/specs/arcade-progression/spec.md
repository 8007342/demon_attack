# Arcade progression: bonus balance

## ADDED Requirements

### Requirement: Bonus levels are balanced against the sector they replace
Every bonus level in the catalogue SHALL last about as long as the regular sector it replaces, bring about as many enemies, offer about the same possible score and be about as hard; by design a level MAY sit a little easier or a little harder. A balance gate SHALL check this with the test suite, with the calibration pilots on sectors 2-4 of routes 0 and 1 at every difficulty: the protected real-shot pilot for duration, enemies and possible score, the Average pilot's lives lost for difficulty.

#### Scenario: Pooled within 15 %
- **WHEN** the gate pools a level's cells
- **THEN** its duration, enemies, possible score and lives lost are each within 15 % of the regular sectors'

#### Scenario: Per difficulty within 20 %
- **WHEN** the gate pools a level's cells of one difficulty
- **THEN** its duration, enemies and possible score are each within 20 % of the regular sectors'

#### Scenario: No three-second bonus level
- **WHEN** a bonus level replaces any gated sector, Easy sector 2 of the first route included
- **THEN** it lasts at least 60 % of that sector's combat time and brings at least 85 % of its enemies

#### Scenario: A new level joins the gate
- **WHEN** a level is appended to the catalogue
- **THEN** the balance gate measures it against its sectors with no change to the gate

### Requirement: Bonus level par counts the whole sector
The par score a bonus level's awards and cap are shares of SHALL be what the regular sector at its place pays in kill points at face value: every wave's opening roster, its finite reinforcement groups, and on a sentinel wave the sentinel and its escort, on that route and difficulty.

#### Scenario: A sentinel sector
- **WHEN** the replaced sector brings a sentinel in its last wave
- **THEN** its par includes the sentinel's and its escort's points
