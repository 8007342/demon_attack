# Ground travel pace

## ADDED Requirements

### Requirement: Skirmish travel pace
Skirmish units SHALL travel (depth approach and lateral manoeuvre) at 0.6 of their v4 speeds, and skirmish
vehicles drawn as legged walkers at 0.45; the v4 convoy SHALL advance, fall back and slew at 0.6 of its speeds except
while it fights a threat-front unit. The threat front's travel, telegraph and launch clocks and the warning bracket
SHALL be unchanged, and skirmish engagements per minute SHALL stay at least three times the v3 ground war's in
sectors 1–4.

#### Scenario: A rifle squad advances
- **WHEN** a skirmish rifle squad advances to its hold line at hostile rate 1
- **THEN** its depth closes at 34.8 texels per second

#### Scenario: A threat vehicle launches
- **WHEN** a threat vehicle telegraphs and launches with the skirmish layer on
- **THEN** its depth, telegraph and launch times match the same level played with the skirmish layer off
