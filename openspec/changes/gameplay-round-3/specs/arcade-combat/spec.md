# Gameplay round 3 combat

## ADDED Requirements

### Requirement: Life-loss sequence
A hit that costs a non-final life SHALL destroy the ship in a multi-frame explosion and start a regroup pause of 1.5–2 s.
- During the pause, hostile shots SHALL fizzle out and no new hostile fire, dive or ground launch SHALL start.
- During the pause, the swarm SHALL return to formation and nothing SHALL hit the player.
- After the pause, the reserve ship SHALL fly up from the bottom edge with 2 s of blinking protection, and play SHALL resume.
- Lives, scoring and the loadout rules SHALL be unchanged, and module timers SHALL freeze while the ship is away.

#### Scenario: Regroup
- **WHEN** an unshielded hit costs a life with lives remaining
- **THEN** `playerDestroyed` fires, `regroupStart` fires 0.7 s later and every hostile shot fizzles out, and `playerRespawn` fires 2.3 s after the hit as the reserve ship flies in protected

#### Scenario: Final life
- **WHEN** the last life is lost
- **THEN** `playerDestroyed` fires with `final: true` and the defeat celebration starts as before

### Requirement: Ground homing flight
A homing missile fired at a ground unit SHALL fly a longer arc, 0.95–1.75 s depending on depth. It SHALL climb away from the ship, arc out and dive into the perspective ground plane, shrinking with distance, and impact at the unit's ground position. Air targets SHALL keep their fast direct flight.

#### Scenario: Far ground target
- **WHEN** the salvo targets a ground unit near the horizon
- **THEN** the missile takes about 1.5 s, shrinks as it flies, and destroys the unit on impact

### Requirement: Allied convoy
Allied ground units SHALL hold station in the near ground band beside the ship's depth, in the side bands. They SHALL advance up the ground plane only to engage an incoming demon unit and SHALL fall back afterwards. They SHALL never scroll off the bottom of the screen while active, collide with the player, or block shots.

#### Scenario: Escort
- **WHEN** a demon unit approaches on the left
- **THEN** the left convoy ally advances to engage it and returns to station once the unit is destroyed
