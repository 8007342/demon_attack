# Bonus missions read at a glance

## ADDED Requirements

### Requirement: A one-sentence goal
Supply Run's brief on the urgent-mission card SHALL be one short sentence naming the goal (the crates and the catch), and the card SHALL show the rule as a pictogram strip when it has the room.

#### Scenario: The card's words
- **WHEN** the transition into Supply Run opens its urgent-mission card
- **THEN** the brief reads "Shoot the falling crates open and catch the cargo." (at most 60 characters, one sentence) and the pictogram shows a bracketed crate, three shots, the crate bursting, the cargo falling and the ship catching it

### Requirement: The card holds the start until read
The urgent-mission card SHALL hold a bonus level's start at the end of the transition's flight (the model is not stepped) while it is open and unread. Read means the brief's reading time has passed since it opened and every scripted turn has finished. A tap, Space or Enter releases it at once; it never holds longer than 15 seconds; while holding it shows TAP TO START.

#### Scenario: A player who reads
- **WHEN** the flight into a bonus level has a quarter second left and the card's script is still playing
- **THEN** the game holds there with the card up and TAP TO START shown, and the level starts once the brief has been up for its reading time (3-7 s) and the last turn has ended

#### Scenario: A player who taps
- **WHEN** the card is holding and the player taps it
- **THEN** the hold ends at once and the level's combat begins

#### Scenario: A stalled channel
- **WHEN** a scripted turn cannot finish
- **THEN** the hold ends after 15 seconds anyway

### Requirement: Cues on the crates and the cargo
Supply Run SHALL show its mechanic on the objects, never as text over the play area: an unhit crate in pulsing gold target brackets, one crack per hit taken, falling cargo with a dotted drop line and a landing marker on the ship row, the salvage magnet's reach and its pull beams, and double score as two gold coins orbiting the ship. With reduced motion the marks are steady.

#### Scenario: A crate takes hits
- **WHEN** a crate has taken one hit, then two
- **THEN** it shows one crack, then two, and no brackets

#### Scenario: Cargo falls
- **WHEN** a crate's cargo falls toward the ship row
- **THEN** a landing marker on the ship row under it shows where to catch it

### Requirement: Feedback when the player gets it right
Opening a crate SHALL burst a ring where it was and play the `crateOpen` sound (not the wave-clear jingle); catching cargo SHALL flash at the ship; the arena's top-left corner SHALL tally the crates opened as gold pips. The cue tracker SHALL draw no random numbers and award nothing, so the level's balance is unchanged.

#### Scenario: A crate is shot open
- **WHEN** the third hit opens a crate
- **THEN** a ring bursts there, the raw event is `crateOpen` (not `salvage`), the tally gains a pip, and the radio's `bonusCrate.supplyRun` call speaks three times in four (rate-limited with the loot family)

#### Scenario: The balance gate
- **WHEN** `test/bonus_balance_test.dart` measures Supply Run against its sectors
- **THEN** it passes with the numbers it had before this change

### Requirement: The radio explains in its own words
Supply Run's in-level radio (its start call, the crate call, the two bonus power pickups and the missed-crate banter) SHALL show the lines' own words as written lines until recorded, never a borrowed clip's unrelated subtitle. A crate that falls past the ship unopened SHALL queue `bonusCrateMissed` with the level's id.

#### Scenario: The magnet is collected
- **WHEN** the salvage magnet is collected
- **THEN** the dock shows a squad line about the magnet pulling the cargo in (e.g. "Salvage magnet online. Loose cargo flies to you now."), not "New toy! Try it out."

#### Scenario: A missed crate
- **WHEN** a crate falls past the ship unopened
- **THEN** the squad may tease the pilot and a brood minion may claim it (`bonusCrateMissed.supplyRun`)
