# arcade-combat

## Purpose
Provide readable, repeatable arcade combat against organic demon swarms and an evolving carrier boss.

## Requirements

### Requirement: Controls and permanent fire
The player SHALL move horizontally with arrow keys or a dedicated bottom touch trackpad, remain inside the arena, and fire automatically during combat. The ship SHALL move with horizontal inertia (`shipVx`), bank (`shipBank`), and transfer lateral sling-shot velocity to fired projectiles.

#### Scenario: Touch movement
- **WHEN** the player drags in the controller panel
- **THEN** the ship follows horizontal movement with inertial banking without entering the panel

#### Scenario: Strategic sling shooting
- **WHEN** the player strafes horizontally at speed while firing
- **THEN** fired projectiles inherit a fraction of the ship's horizontal velocity and travel on an angled trajectory

### Requirement: Cockpit yoke, interim shooting angles, and device tilt
The player SHALL steer and vector turret fire via the bottom Cockpit Control Panel steering yoke (supporting multi-touch drag with jump-free release rebasing), keyboard, or calibrated 3D device tilt (`screenRoll` with circular-mean neutral posture calibration). Ship steering and yoke deflection SHALL couple to discrete interim shooting angles (`±6°, ±12°, ±18°, ±24°`).

#### Scenario: Multi-angle steering, interim shooting angles, and calibrated device tilt
- **WHEN** the player steers via the cockpit yoke, keyboard, or calibrated 3D device tilt
- **THEN** the starfighter banks and vectors its turret projectiles across discrete interim shooting angles (`±6°, ±12°, ±18°, ±24°`), and releasing one finger during multi-touch drag rebases the anchor without jumping

### Requirement: Lives and pause
Each run SHALL start with three lives. A single unprotected hit SHALL remove one life, grant brief respawn protection, and end the run at zero. Pause and backgrounding SHALL freeze combat.

#### Scenario: Lethal hit
- **WHEN** an unprotected ship is hit with one life remaining
- **THEN** combat ends and the final score is shown

### Requirement: Last-life-lost defeat celebration and skyward High Score pan
When the final life is lost, the player ship SHALL explode in a multi-stage hull breakup, surviving ordinary demons, Sentinels, or the Dreadnought Carrier SHALL execute a post-mortem victory celebration formation, and the viewport SHALL pan skyward into the starfield to present the High Scores and initials entry.

#### Scenario: Enemy victory celebration and skyward pan on final life lost
- **WHEN** an unprotected hit removes the player's last life
- **THEN** the ship detonates, surviving enemies or bosses perform a celebratory victory formation, and the camera pans upward to the High Scores console

### Requirement: Demon swarms and transformations
Four levels SHALL introduce faster organic swarms, home-tethered Boids separation/cohesion with incoming-shot lateral evasion and an offline JEV action prior (`SwarmPolicy`), telegraphed predatory dives, and armored demons that visibly weaken after hits; advanced enemies SHALL enter angry final forms.

#### Scenario: Armored demon
- **WHEN** a multi-hit demon takes a nonlethal hit
- **THEN** its form changes and its remaining final form can attack more aggressively

### Requirement: Three-tier diving shields
All diving creatures SHALL project a tier-scaled atmospheric re-entry plasma fire shield (`diveShield`) with a thermal blackbody palette (white core -> yellow -> orange -> crimson/charcoal smoke, zero cyan/violet) distinct from cool geometric force shields: 1-HP on small demons, 2–3 HP on medium creatures (`elite || kind >= 2 || maxHp >= 3`), and `4 + cycle ~/ 2` on Sentinels (broken only by active offensive powerups).

#### Scenario: Three-tier diving shields
- **WHEN** a small demon, elite/tough demon, or large Sentinel dives toward the player
- **THEN** small demons use a 1-HP lil' thermal shield, not-so-small demons use a 2–3 HP medium thermal shield, and large Sentinels use a re-entry thermal shield that only takes damage from active offensive powerups, while force shields remain geometric cyan/teal/violet

### Requirement: Carrier shield and door
The boss SHALL fly low above the player, release flocks, and protect its core with a destructible geometric force shield followed by 3 mechanical launch bay shutters. Non-final boss forms (`phase < formCount - 1`) SHALL expose Left and Right auxiliary side hatches (`sideDoorLeft`, `sideDoorRight`) alongside the center door; the final form SHALL seal the side hatches so core hits only count through the open center door.

#### Scenario: Protected core
- **WHEN** a player shot strikes the boss with its shield active or door closed
- **THEN** the core does not lose health

#### Scenario: Auxiliary side hatches on non-final forms
- **WHEN** the carrier shield is depleted during a non-final boss form (`phase < formCount - 1`) and a player shot strikes an open Left or Right auxiliary hatch
- **THEN** the carrier core takes reduced auxiliary damage (`0.75×` rounded, minimum 1), whereas on the final form (`phase == formCount - 1`) the side hatches remain sealed

### Requirement: Multi-part Dreadnought Carrier arrival and destruction
The Brood Dreadnought Carrier SHALL fight as a `184 × 120` logical pixel multi-part hierarchy across 4 evolution forms (`Carrier`, `Brood Ark`, `Siege Carrier`, `Brood Flagship`) with articulated mandibles, dorsal retro-thrusters, tracking ventral dual-turrets, and progressive fracture overlays, arriving via orbital retro-burn and exploding in a sequential chain-reaction meltdown (wing pylons -> auxiliary bays -> central core).

#### Scenario: Dreadnought orbital arrival and sequential chain-reaction destruction
- **WHEN** the Brood Dreadnought Carrier enters the sector or its core health reaches zero
- **THEN** it arrives with orbital retro-burn deceleration, gravitational dust ripples, mandible deployment, and klaxon telemetry, and upon defeat detonates sequentially from wing pylons to auxiliary bays to the central brood core in a listing hull descent

### Requirement: Repeat cycles
Defeating each carrier SHALL continue the same run at LV1 with retained score, lives, powers and kill count. Later cycles SHALL increase speed, waves, roster size, species variety and multi-molt elites with stronger telegraphed attacks. Speed, waves and density SHALL have safe upper bounds.

#### Scenario: Victory
- **WHEN** the boss core is destroyed
- **THEN** the next cycle starts at level one with the score and remaining lives retained

#### Scenario: Two carrier victories
- **WHEN** the player defeats two carriers in one run
- **THEN** each return to LV1 retains the run and adds complexity compared with the preceding cycle

#### Scenario: Advanced elites
- **WHEN** an elite appears in later cycles
- **THEN** its extended damage forms are visible and its attacks are stronger but telegraphed

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

## Research and reference traceability

- Master reference index: [plan/reference-register.md](../../../plan/reference-register.md)
- External & sibling source disposition ledger: [plan/research-source-ledger.md](../../../plan/research-source-ledger.md)
- Offline synthetic-imitation JEV swarm policy: [plan/policy.md](../../../plan/policy.md)
- Project-committed UX cheatsheets:
  - [.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md](../../../.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md)
  - [.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md](../../../.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md)
