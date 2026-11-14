# Arcade combat

## ADDED Requirements

### Requirement: The next wave approaches before the current one ends
On an ordinary wave that is not the level's last, once every reinforcement group has arrived, no sentinel is alive or waiting, and at most the difficulty's threshold of enemies remain (Easy 2, Normal 3, Hard 4), the game SHALL bring the next wave in from the horizon.

#### Scenario: Last few stragglers
- **WHEN** a Normal wave 1 is down to three enemies with all reinforcements in
- **THEN** wave 2 appears far away in the fog

### Requirement: An approaching wave is harmless and unchanged
While it approaches, the next wave SHALL be visible, SHALL NOT be targetable, SHALL NOT fire, and SHALL NOT count toward clearing the current wave. Its roster SHALL be exactly the roster that wave would otherwise have had: count, species, HP and elite budget.

#### Scenario: Approaching roster
- **WHEN** wave 2 is approaching while three wave-1 stragglers remain
- **THEN** only the stragglers can be hit, and wave 2's enemies match a freshly started wave 2

### Requirement: Finishing first keeps the release; lingering lets it join
If the stragglers fall before the approach ends, the approaching wave SHALL settle in during the usual short release, as a fresh wave would. If the approach time (Easy 10 s, Normal 8 s, Hard 6 s at hostile rate) runs out first, the wave number SHALL advance and the approaching roster SHALL join the fight without a pause, alongside the remaining stragglers, within the calibrated occupancy bound. A lost life SHALL pause the approach clock.

#### Scenario: Lingering player
- **WHEN** a Normal player leaves three stragglers alive for eight seconds after the next wave appears
- **THEN** the wave counter advances and the new wave closes in while combat continues

### Requirement: Distance is fogged
Creatures far from the camera SHALL be faded and veiled by the horizon haze, the still-approaching wave more strongly, with smoke and low cloud along the horizon behind them. The fog SHALL never veil a creature that can attack the player more than the existing haze does.

#### Scenario: Approaching wave
- **WHEN** the next wave is approaching
- **THEN** it reads as distant shapes in weather, and becomes clear only as it closes in
