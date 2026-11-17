# Arcade presentation

## MODIFIED Requirements

### Requirement: Adaptive MIDI soundtrack
A committed MIDI score SHALL be the first layer of the soundtrack: a sampler SHALL play it with distinct level songs, escalating boss sections, a victory flourish and bar-aligned transitions. Where the sample bank is not loaded or cannot decode, the same score SHALL play through the built-in synthesizer voices, with no second audio asset. Audio SHALL start only after a user gesture and provide mute and lifecycle pause.

#### Scenario: Boss transforms
- **WHEN** the boss enters a more advanced phase
- **THEN** the score transitions smoothly into more intense boss music without restarting audio abruptly

#### Scenario: Bank unavailable
- **WHEN** the browser cannot decode the sample bank (e.g. Safari before 18.4)
- **THEN** the same score plays on its grid through the synthesizer voices, with the same sections and transitions

#### Scenario: Bank arrives late
- **WHEN** the bank's core group finishes decoding during a section
- **THEN** later notes play sampled from the next note on, without a restart or a gap
