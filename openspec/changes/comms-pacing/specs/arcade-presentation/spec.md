# Arcade presentation

## ADDED Requirements

### Requirement: Music volume is constant; speech never ducks music
The music bus level SHALL stay constant at all times. Speech (human or demon, at any priority), effects and life-loss accents SHALL never lower it. Only the player's music level (Mute / Low / Full) and the master mute SHALL change what the music sounds like. The speech Mute / Low / Full toggle SHALL change only the speech volume.

#### Scenario: A clip plays over the score
- **WHEN** a radio clip plays during a level cue
- **THEN** the music bus gain is unchanged while the clip plays and after it ends, and no gain ramp is scheduled on it

#### Scenario: Speech toggle
- **WHEN** the player cycles the speech level through Low and Mute
- **THEN** the music level is unchanged
