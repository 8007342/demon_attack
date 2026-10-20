# Combined temporary powers

## MODIFIED Requirements

### Requirement: Scores and powers
Kills SHALL award larger scores for stronger enemies and bosses. Spread, rapid-fire and shield powers SHALL work concurrently with independent nine-second timers. Recollecting a type SHALL refresh only its timer. Expiry SHALL remove only the expired effect, and a shield hit SHALL consume only shield. Power time SHALL freeze outside combat and on pause; starting a new run SHALL clear all effects.

#### Scenario: Power expires
- **WHEN** one active power's duration elapses
- **THEN** that effect ends while the other active effects continue with their own remaining time

#### Scenario: Combined firing
- **WHEN** spread and rapid fire are active together
- **THEN** every rapid-fire volley includes the central and both angled shots

#### Scenario: Shield protects combined powers
- **WHEN** the ship is hit with spread, rapid fire and shield active
- **THEN** shield is consumed without losing a life or cancelling spread or rapid fire

#### Scenario: Refresh one modifier
- **WHEN** an already-active type is collected
- **THEN** only that type returns to nine seconds and other timers are unchanged
