# Arcade presentation

## ADDED Requirements

### Requirement: Transition chatter keeps the flow
The transition chatter over the clouds SHALL follow the cinematic-flow advisories: its opacity SHALL be a function of the flow clock, from Pursuit's start to the Descent, it SHALL take no input (tap, Space and Enter still skip), it SHALL stay clear of the ship's highest climb, it SHALL never lengthen the transition, and it SHALL be gone when the Descent begins.

#### Scenario: Sector change on a phone
- **WHEN** a sector is cleared on a 390 × 844 or a 360 × 640 screen
- **THEN** the chatter appears centred over the clouds above the ship's path, never covers the ship, lets taps through, and is gone by the Descent

#### Scenario: No room for a second line
- **WHEN** one short line plays and a second short line would end after the Descent
- **THEN** no second line is queued and the transition keeps its length
