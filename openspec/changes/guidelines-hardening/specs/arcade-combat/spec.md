# Arcade combat

## ADDED Requirements

### Requirement: Rules every hazard keeps
Every telegraphed lethal attack (dives, sentinel rushes, ground fire, bonus-level strikes and any new mechanic) SHALL show its tell for at least one second of real time, never shortened by difficulty or time scaling. No such attack SHALL start while the ship is away (the regroup pause). Allies SHALL never die: at zero health an ally is totalled and leaves the field. A new hazard SHALL state how it keeps these rules in its design.

#### Scenario: Hard difficulty
- **WHEN** a hazard's tell is scaled by Hard's faster hostile rate
- **THEN** it still lasts at least 1.0 s of real time

#### Scenario: An ally loses its health
- **WHEN** an ally's health reaches zero
- **THEN** it is totalled and retreats instead of being destroyed

### Requirement: Power drop sources
Regular powers SHALL drop from three sources: every eighth kill, cycling through the five powers in enum order; a large demon (sentinel) shot down while diving, which gives the current cycle's power; and, once the carrier's shield is down, fleet supply crates (at most two at a time, one every 16 s, or 11 s with two lives or fewer), which roll Large 70 %, Powerful 10 %, Spread 10 % and Shield 10 %. A bonus level or run modifier MAY change or withhold any drop.

#### Scenario: Eighth kill
- **WHEN** the 16th kill of a run happens outside a bonus rule
- **THEN** the second power of the cycle (rapid) drops at the kill
