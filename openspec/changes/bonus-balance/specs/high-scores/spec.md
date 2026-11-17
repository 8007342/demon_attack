# High scores: the run record

## ADDED Requirements

### Requirement: Records keep the run's modifiers and play date
A score record SHALL carry the run's modifiers, as catalogue ids in run order (each bonus level the run reached, then its run rule; none for a run without a plan), and its play date. Records saved before these fields existed SHALL load with no modifiers and no date, and the board SHALL show them as before.

#### Scenario: A bonus run's record
- **WHEN** a run that met Supply Run under the no-shields rule is saved
- **THEN** the board returns its record with the modifiers `supplyRun` and `noShield` and its play date

#### Scenario: An old record
- **WHEN** the board loads a record stored before the run record existed
- **THEN** it has no modifiers and no date, and its initials, medals, time and score show unchanged

### Requirement: Run record validation
The API SHALL accept at most four distinct modifier ids, each of letters and digits starting with a lower-case letter, and SHALL reject any other. It SHALL keep the client's play date when it is a real calendar day within a day of its own, and stamp its own (UTC) otherwise.

#### Scenario: A malformed modifier
- **WHEN** a record names five modifiers, a repeated one or one with a dash
- **THEN** the API rejects it and stores nothing

#### Scenario: A far-off clock
- **WHEN** a record's play date is three days from the server's
- **THEN** the server's date is stored
