# Squad comms

## ADDED Requirements

### Requirement: Bonus level entry call
The transition into a bonus level SHALL fill its one radio slot with that level's entry call (`bonusEntry.<level>`), or a general entry call (`bonusEntry`) when the level has none, ahead of the front-line call and the mission line. The line SHALL fit the slot's window like any other.

#### Scenario: Entry call
- **WHEN** the run flies toward its Supply Run
- **THEN** the transition's radio opens with one of the Supply Run's entry calls, the invite of its urgent-mission card

#### Scenario: A level without its own lines
- **WHEN** a bonus level has no entry lines of its own
- **THEN** the general entry call plays in the slot

#### Scenario: No bonus level ahead
- **WHEN** the next sector is regular
- **THEN** the transition's radio line is chosen exactly as before

### Requirement: Urgent-mission script
The urgent-mission card's chatter SHALL be a short back-and-forth on the radio channel: the level's entry call as the invite, a dare from another squadmate, and a brood retort from the destination sector's net. The turns SHALL play in order, one voice at a time, each after the grace gap and none cut, and the rest of the squad SHALL wait while the card is up, except an exchange already on screen, which gets its answer.

#### Scenario: Three turns
- **WHEN** the card opens for Stormfront
- **THEN** a squadmate's invite, another squadmate's dare and a brood officer's or minion's retort follow one another with no overlap

#### Scenario: Squad chatter meanwhile
- **WHEN** the celebration of the cleared sector is still on air as the card opens
- **THEN** its exchange finishes first, and nothing else speaks between the card's turns

### Requirement: Bonus level banter
A bonus level's second wave SHALL ask once for its mid-level banter (`bonusMidway`, keyed by the level's id): a squad tease answered by the brood. Bonus banter SHALL stay playful and MAY carry sparse, unexplained hints of the campaign's hidden story.

#### Scenario: Midway
- **WHEN** the Supply Run's second wave begins combat
- **THEN** a squad tease and a brood retort may play as one exchange

### Requirement: Bonus level events speak through the line bank
The start of a bonus level, an opened crate, a collected bonus-only powerup, the level's last kill and the run's modifier SHALL each be a game event whose radio trigger is looked up first with the level's, powerup's or modifier's id and then without it. Their lines SHALL obey the channel's ordinary priority, pacing and lineup rules.

#### Scenario: Level-specific line
- **WHEN** a Supply Run crate is shot open
- **THEN** the channel may play one of the Supply Run's crate lines, under the loot group's pacing

#### Scenario: No line for the moment
- **WHEN** an event's trigger has no line in the bank
- **THEN** nothing plays and the game goes on

### Requirement: Bonus lines borrow recorded clips until recorded
Until its own recording exists, every bonus-level and run-modifier line SHALL name a recorded line of the same kind as its placeholder and SHALL play that clip with that clip's own subtitle and speaker, so audio and text always agree; except the card's and the banter's written lines, which SHALL show their own words silently. Every such line SHALL be listed in the pending voice batch with its speaker, emotion, text and placeholder. Recording a line SHALL need no code change.

#### Scenario: Borrowed clip
- **WHEN** a Supply Run entry call plays before the voice batch has run
- **THEN** a recorded salvage line is heard and its own words are shown

#### Scenario: Written line
- **WHEN** a card turn plays before the voice batch has run
- **THEN** its own words and speaker are shown, no audio plays, and the portrait's mouth stays closed

#### Scenario: Pending list
- **WHEN** the line bank is regenerated
- **THEN** each unrecorded bonus line appears in the pending voice batch with its placeholder
