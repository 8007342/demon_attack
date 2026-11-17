# Bonus challenges: a perfect run for a 1UP

## ADDED Requirements

### Requirement: One perfect-run challenge per bonus level
Each bonus level SHALL declare one perfect-run challenge as data on its definition: a short condition label, a pictogram, the notes that fail it at once, the notes it needs by the level's clear and the lives it pays (one). A level SHALL add a condition without changes to the framework; its mechanic reports its own notes to the model.

#### Scenario: Supply Run
- **WHEN** a Supply Run is played
- **THEN** its challenge reads CATCH ALL CARGO with a parachute-crate pictogram, and fails when a crate passes the ship's row unopened or a prize falls past the ship uncaught

#### Scenario: Stormfront
- **WHEN** a Stormfront is played
- **THEN** its challenge reads DODGE EVERY BOLT with a bolt pictogram, and fails when a bolt touches the ship, a shield knocked off included; a bolt the lightning rod grounds does not fail it

#### Scenario: A new level
- **WHEN** a new bonus level declares a challenge that fails on a note of its own and its mechanic reports that note
- **THEN** the challenge is tracked, shown, voiced and paid like the shipped ones, with no change to the framework

### Requirement: Live, deterministic challenge state
The model SHALL track the challenge of the bonus level being played as live (in progress and still possible), failed or earned, in pure Dart and without drawing random numbers. A failing note SHALL fail it in the step it is reported; the level's last kill SHALL settle a live challenge as earned when its needs are met, else failed. A settled challenge SHALL never change again.

#### Scenario: Failure is immediate
- **WHEN** a crate passes the ship's row unopened in a Supply Run
- **THEN** the challenge is failed within one step and one failure event is queued for the radio

#### Scenario: Falling short at the clear
- **WHEN** a Supply Run is cleared before any prize was caught
- **THEN** the challenge is failed at the clear and no life is paid

### Requirement: The 1UP is paid once
An earned challenge SHALL add its lives through the extra-life path at the level's last kill, play the extra-life fanfare, and pay once per visit. The run's won challenges SHALL be kept in the checkpoint and shown on the run record as the level's perfect-run medal.

#### Scenario: A clean storm
- **WHEN** a Stormfront is cleared with no bolt touching the ship
- **THEN** the player gains exactly one life, the earned event is queued before the clear's own, and the run record shows the STORMFRONT · 1UP medal

#### Scenario: Restored run
- **WHEN** a run that won a 1UP is restored from its checkpoint
- **THEN** its record still shows the perfect-run medal

### Requirement: The challenge badge
The challenge SHALL be shown as a badge with its pictogram and an arcade 1UP plate: on the urgent-mission card with its condition in words, and as a small pip beside the lives while the level is played. The badge SHALL break the moment the challenge fails and burst when it is earned. Reduced motion SHALL keep the states without motion.

#### Scenario: Briefing
- **WHEN** the urgent-mission card of a level with a challenge is up
- **THEN** it shows the badge and the condition (CATCH ALL CARGO, DODGE EVERY BOLT) under the how-to line, and its accessibility label names the challenge and its 1UP

#### Scenario: Failed
- **WHEN** the challenge fails mid-level
- **THEN** the HUD pip turns grey with a red slash across the pictogram and a struck-through 1UP, after a short shake and red flash

#### Scenario: Earned
- **WHEN** the challenge is earned
- **THEN** the HUD pip's 1UP plate turns gold and a burst of rays, a ring and sparks plays for about 1.4 s, then a steady gold halo stays

### Requirement: Challenge radio
Each challenge level SHALL have one single-sentence challenge call, spoken as the urgent-mission card's one line, a squad quip when the challenge fails, and a squad cheer when the 1UP is earned; the quip and cheer MAY draw a brood retort. Lines SHALL be family friendly, and SHALL follow the card's quiet window.

#### Scenario: Briefing call
- **WHEN** the card of a level with a challenge opens
- **THEN** it speaks exactly one line, the level's challenge call, which names the 1UP, and no other line plays over the card

#### Scenario: Quip and cheer
- **WHEN** the challenge fails, or is earned
- **THEN** a squadmate's quip, or 1UP cheer, is queued once, and a brood retort may follow it
