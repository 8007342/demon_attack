# Arcade presentation

## ADDED Requirements

### Requirement: Flash safety
Nothing in the game SHALL flash more than three times in any one-second period over an area larger than the WCAG 2.3.1 general and red flash thresholds. A whole-screen flash SHALL stay at or below 10 % white for at most 0.12 s, and with reduced motion on, flashes over large areas SHALL be removed.

#### Scenario: Lightning strike
- **WHEN** a weather or hazard effect lights the whole screen
- **THEN** the wash stays at or below 10 % white for 0.12 s and repeats at most once a second

#### Scenario: Reduced motion
- **WHEN** reduced motion is on
- **THEN** the whole-screen flashes are not drawn and the gameplay tell is still shown
