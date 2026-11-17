# Arcade presentation

## MODIFIED Requirements

### Requirement: Adaptive MIDI soundtrack
A MIDI-event synthesizer SHALL remain the fallback of the recorded song: it SHALL play a song's motifs on the same grid when none of the song's recorded sections can be decoded, with distinct level tracks, escalating boss music and a victory flourish. Audio SHALL start only after a user gesture and provide mute and lifecycle pause.

#### Scenario: Boss transforms
- **WHEN** the boss enters a more advanced phase
- **THEN** the score transitions smoothly into more intense boss music without restarting audio abruptly

#### Scenario: Recorded sections unavailable
- **WHEN** no recorded section of the current song decodes
- **THEN** the MIDI fallback plays that song's motifs on its grid, and the recorded song takes over on a bar line once a section is ready
