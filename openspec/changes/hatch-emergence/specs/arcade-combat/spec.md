# Arcade combat

## ADDED Requirements

### Requirement: Hatch emergence leaves the fight unchanged
The hatch emergence SHALL be presentation only: it SHALL NOT change any creature's launch moment, entrance, arrival moment, targetability or fire, nor any carrier timer, so every calibration gate keeps its value.

#### Scenario: Parity
- **WHEN** two identical carrier fights run 30 s, one with the emergence director stepping every frame
- **THEN** every creature's position, hit points and entrance progress, the carrier's shield and the score are identical
