# Arcade combat

## ADDED Requirements

### Requirement: Waves arrive as a continuous stream
Within a sector, each wave's roster, reinforcement groups and escort SHALL reach the screen as a continuous stream of small skeins (3–6 creatures). Each skein SHALL fly a parabolic swoop out of the fog: it rises, crests and settles into the fight. There SHALL be no transition phase between two waves of one sector.

#### Scenario: Next wave without a ladder
- **WHEN** a Normal wave 2 is down to three enemies with every reinforcement group admitted
- **THEN** wave 3's first skeins rise out of the fog and fly toward the fight while the stragglers are still fighting, and no transition card or phase separates the two waves

### Requirement: The stream changes timing, never content
A wave's content SHALL be unchanged by the stream: count, species, HP, elite budget, finite groups, escort size and occupancy admission, as in plan/difficulty-calibration.md. Wave number and checkpoint SHALL still advance once per wave.

#### Scenario: Unchanged budget
- **WHEN** the 318 generated wave configurations are audited
- **THEN** every roster, group, escort, HP and elite count equals its value before this change

### Requirement: The reserve waits visibly in the fog
Reinforcement groups and the next wave's not-yet-released skeins SHALL wait as veiled shapes in the deep fog. While waiting they SHALL NOT be targetable, SHALL NOT fire, SHALL NOT count toward clearing the wave or toward occupancy, and SHALL NOT show gear. Releasing a group SHALL follow the existing casualty, cooldown, fallback and occupancy rules.

#### Scenario: Group in reserve
- **WHEN** a wave starts that plans two reinforcement groups
- **THEN** the groups drift as shapes in the deep fog until each is admitted, then swoop in

### Requirement: The inflow accelerates when the player clears faster
The gaps between a wave's skeins and the next wave's approach time SHALL shrink when the player clears faster than the wave's expected clear time. The approach SHALL be no shorter than the difficulty's floor (0.65 / 0.55 / 0.5 of the approach time for Easy / Normal / Hard). A lost life SHALL pause the approach and reset the next wave's pacing to the unaccelerated value. Pacing SHALL NOT add HP, births or simultaneous attackers.

#### Scenario: Fast clear
- **WHEN** a Normal player clears a wave in half its expected time
- **THEN** the next wave's approach takes 0.55 of its usual time

#### Scenario: Life lost
- **WHEN** the player loses a life while the next wave approaches
- **THEN** its approach clock pauses, and the wave after it uses the unaccelerated approach time

### Requirement: The swarm keeps flocking while it fights
Arrived skeins SHALL fight as squads in collective swarm states: mill (a ring circling a station), ribbon (a chain on a figure-eight) and sweep (a stretched line traversing the band). Sentinel escorts SHALL fight as a cloud bound to their sentinel. A squad SHALL change state every 7–12 s, only to a neighbouring state, with a 1.2 s crossfade and no position snap. Squads SHALL stay above `shipY - 130` except when diving, and inside the arena margins.

#### Scenario: Squad changes pattern
- **WHEN** a milling squad has held its state for its dwell time
- **THEN** it unrolls into a ribbon over 1.2 s, with no creature jumping position

### Requirement: Swarm motion is deterministic, with an onboarding hover
Swarm motion SHALL be deterministic for a run seed and SHALL NOT change the sequence of the run's other random draws. The static hover SHALL remain only for onboarding (Easy route 0, sector 1, waves 1–2) and for creatures without a squad.

#### Scenario: Replay
- **WHEN** the same sector is simulated twice with the same seed and inputs
- **THEN** every creature position, event and the score are identical

### Requirement: Visible evasion does not move hitboxes
A squad SHALL visibly react to player fire with agitation waves, flash expansion around a kill and closing gaps where a member was lost. These cosmetic offsets SHALL stay within one third of the creature's hitbox half-width and SHALL NOT change the creature's simulated position or hitbox.

#### Scenario: Shot through a squad
- **WHEN** a player shot passes close to a milling squad
- **THEN** a ripple runs through the squad from the nearest creature outward, and which creatures can be hit is unchanged

### Requirement: Divers rejoin the swarm out of the fog
A creature whose dive leaves the bottom of the arena SHALL re-enter from the fog behind the swarm and swoop back to its squad. It SHALL stay untargetable and silent until it rejoins.

#### Scenario: Missed dive
- **WHEN** a diving gargoyle passes the ship and leaves the bottom of the screen
- **THEN** it reappears far away in the fog on its side and flies back into its squad

### Requirement: Swarm calls arrive with the swarm
Events announcing a sighted wave, a reinforcement admission and a sentinel's rise SHALL carry the seconds until those creatures become targetable. Radio calls for them SHALL end close to that moment. A sighted wave SHALL reuse the existing next-wave radio lines.

#### Scenario: Reinforcement call
- **WHEN** a reinforcement skein is admitted with a 1.6 s swoop
- **THEN** the radio call about it ends within 0.3 s of the skein becoming targetable
