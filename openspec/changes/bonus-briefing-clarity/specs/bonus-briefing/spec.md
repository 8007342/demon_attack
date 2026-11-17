# Bonus briefings a first-time player can read

## ADDED Requirements

### Requirement: Goal and how-to at a glance
Each bonus level's urgent-mission card SHALL show a goal line of at most 40 characters, drawn bold, and a how-to line of at most 60 characters under it, in short words, describing the level's actual rules and where to fly. A level SHALL show its rule as a pictogram strip when the card has the room.

#### Scenario: Supply Run
- **WHEN** the transition into Supply Run opens its card
- **THEN** it reads "Pop the crates, catch the prizes!" over "Shoot a crate till it bursts, then fly under what falls." with the five-step crate pictogram

#### Scenario: Stormfront
- **WHEN** the transition into Stormfront opens its card
- **THEN** it reads "Let the lightning zap the demons!" over "Sit under them. When the orange mark blinks, slide away!" with a four-step pictogram: ship under a demon, the amber mark, the ship sliding away, the bolt striking the demon

### Requirement: A guaranteed reading time
The card SHALL open at the transition's radio slot whatever the radio channel is doing, and SHALL stay up for at least its reading time unless the player dismisses it with a tap, Space or Enter. Radio activity SHALL never close it. It SHALL close when the transition is over and it has been read, or after 1.2 s of combat.

#### Scenario: Reading time
- **WHEN** a card shows a goal, a how-to line and a run rule
- **THEN** its reading time is 1.5 s plus one second per 18 characters, at least 4 s and at most 8 s, and the card is up at least that long

#### Scenario: Busy channel
- **WHEN** squad chatter and urgent warnings keep arriving and the card's own line expires unplayed
- **THEN** the card stays open until the player taps or its reading time has passed and the transition is over

#### Scenario: Short flight
- **WHEN** the flight would end before the reading time
- **THEN** the level's start is held at the flight's end with TAP TO START until it has been read (at most 15 s), and a tap starts the level at once

### Requirement: One radio line per bonus level
Each bonus level SHALL have exactly one briefing radio line (`bonusCall.<level>`): one sentence in a squadmate's voice, family friendly, not a copy of the card's text. The card SHALL speak only that line, shown on the card. Until recorded it SHALL be a written line with its own words and no borrowed audio.

#### Scenario: The line plays with the card
- **WHEN** the card opens
- **THEN** its one line is queued, shown on the card as it is spoken, kept out of the dock while the card is drawn, and no dare or brood retort follows

#### Scenario: Card closes first
- **WHEN** the card closes while its line is on air
- **THEN** the line finishes on the dock and is never cut

### Requirement: The radio never covers the card
While the card is up, the squad channel SHALL be hushed except for the card's own line and urgent or must-play warnings, and no radio toast SHALL be drawn over the card at any screen size.

#### Scenario: Chatter during the briefing
- **WHEN** squad chatter and warnings arrive while the card is up on a 360 × 780 phone
- **THEN** ordinary chatter waits until the card closes, and any toast that does show sits below the card, never over it

### Requirement: No extra step
The briefing SHALL add no modal screen or control: the card remains the transition's one radio message, the transition's skip still sends the flight to its Descent, and the only pause is the existing hold at the flight's end.

#### Scenario: Flow kept
- **WHEN** a player flies into a bonus level without touching anything
- **THEN** the card appears during the flight, the level starts by itself once the card has been read, and no extra screen is shown
