# Arcade presentation

## MODIFIED Requirements

### Requirement: Illustrated gameplay instruction
Gameplay hints SHALL pair one brief actionable sentence with one original pixel illustration and equivalent semantics where an illustration is shown. Illustrated hints SHALL appear during the run's opening arrival and in the pause menu's tips. During later sector transitions a hint SHALL appear as a single caption line at the bottom edge, alternating with a radio line, never both at once. Hints SHALL advance automatically without guide, Hold, Menu or manual-advance controls. Normal pause SHALL freeze the opening card. Advice SHALL describe actual game rules without promising protection the simulation does not grant.

#### Scenario: One tactic at a glance
- **WHEN** an illustrated hint is shown at phone size
- **THEN** one recommended action is legible in both the sentence and picture without clipping or unrelated decorative detail

#### Scenario: Automatic loading hint
- **WHEN** a run begins
- **THEN** one complete illustrated hint appears during the opening arrival and disappears automatically before the initial swarm flies in

#### Scenario: Caption between sectors
- **WHEN** a later sector transition carries a tip
- **THEN** the tip shows as one line at the bottom edge for its reading time, with no card and no radio line at the same time

#### Scenario: Accurate shield advice
- **WHEN** a hint explains shield renewal
- **THEN** it associates the grace period with absorbing a hit and never claims that unused shield expiry grants invulnerability
