# Squad comms

## ADDED Requirements

### Requirement: Bonus level entry call
The transition into a bonus level SHALL fill its one radio slot with that level's entry call (`bonusEntry.<level>`), or a general entry call (`bonusEntry`) when the level has none, ahead of the front-line call and the mission line. The line SHALL fit the slot's window like any other.

#### Scenario: Entry call
- **WHEN** the run flies toward its Supply Run
- **THEN** the transition's radio line is one of the Supply Run's entry calls

#### Scenario: A level without its own lines
- **WHEN** a bonus level has no entry lines of its own
- **THEN** the general entry call plays in the slot

#### Scenario: No bonus level ahead
- **WHEN** the next sector is regular
- **THEN** the transition's radio line is chosen exactly as before

### Requirement: Bonus level events speak through the line bank
The start of a bonus level, an opened crate, a collected bonus-only powerup, the level's last kill and the run's modifier SHALL each be a game event whose radio trigger is looked up first with the level's, powerup's or modifier's id and then without it. Their lines SHALL obey the channel's ordinary priority, pacing and lineup rules.

#### Scenario: Level-specific line
- **WHEN** a Supply Run crate is shot open
- **THEN** the channel may play one of the Supply Run's crate lines, under the loot group's pacing

#### Scenario: No line for the moment
- **WHEN** an event's trigger has no line in the bank
- **THEN** nothing plays and the game goes on

### Requirement: Bonus lines borrow recorded clips until recorded
Until its own recording exists, every bonus-level and run-modifier line SHALL name a recorded line of the same kind as its placeholder and SHALL play that clip with that clip's own subtitle and speaker, so audio and text always agree. Every such line SHALL be listed in the pending voice batch with its speaker, emotion, text and placeholder. Recording a line SHALL need no code change.

#### Scenario: Borrowed clip
- **WHEN** a Supply Run entry call plays before the voice batch has run
- **THEN** a recorded salvage line is heard and its own words are shown

#### Scenario: Pending list
- **WHEN** the line bank is regenerated
- **THEN** each unrecorded bonus line appears in the pending voice batch with its placeholder
