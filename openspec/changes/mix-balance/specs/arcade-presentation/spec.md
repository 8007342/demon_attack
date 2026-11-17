# Arcade presentation

## RENAMED Requirements

- FROM: `### Requirement: Music volume is constant; speech never ducks music`
- TO: `### Requirement: Music sits under the radio; speech ducks it`

## MODIFIED Requirements

### Requirement: Music sits under the radio; speech ducks it
At the default levels the music SHALL sit about 2–4 LU under the radio at its loudest, and every section and tier SHALL sit within about 2 LU of the loudest (a per-section trim). While a radio line plays the music SHALL duck a few dB on its own gain stage, with short attack and release ramps on the audio clock; a demon growl or a clip under 1 s SHALL duck it less. Effects and life-loss accents SHALL never lower the music. The speech toggle SHALL change only the speech volume.

#### Scenario: Default mix
- **WHEN** no level is stored and the score plays at its loudest gameplay section (a carrier core, tier 4)
- **THEN** its integrated loudness is 2–4 LU under the radio clips' (metered with `tools/mix_meter`; Full is -14 dB on the music level, Low 10 dB under Full)

#### Scenario: Calm sections
- **WHEN** a calm section plays (tier 1, an arrival tail, the menu overture, the coda)
- **THEN** one pass of it is within about 2 LU of the loudest gameplay section, through the trims in `web/audio/score/mix-trim.json`, applied on the score's output gain at the move or tier change

#### Scenario: A clip plays over the score
- **WHEN** a squad line plays during a level cue
- **THEN** the duck stage reaches -3 dB within 200 ms of the clip's first sample, holds until 250 ms after its last, and returns with a 150 ms time constant; the music bus and the music level are unchanged

#### Scenario: Growl or stinger
- **WHEN** a demon line or a clip shorter than 1 s plays
- **THEN** the music ducks 1.5 dB

#### Scenario: Score transitions
- **WHEN** a bar-quantised move lands while lines play, or with the trims on
- **THEN** it lands on the same time, at the same entry, as without the radio or the trims

#### Scenario: Stored levels
- **WHEN** a Mute, Low or Full choice is stored
- **THEN** it is read back as stored; only the gain behind each level changed

#### Scenario: Speech toggle
- **WHEN** the player cycles the speech level through Low and Mute
- **THEN** the music level is unchanged
