# Wing cannons and the single shooter

## ADDED Requirements

### Requirement: Single shooter
With no wing powerup active, the ship SHALL be a single shooter: each primary shot leaves from the nose with a brief nose muzzle flash.

#### Scenario: No powerups
- **WHEN** no offensive powerup is active
- **THEN** each shot leaves from the nose and the nose flashes, while the wings show no recoil

### Requirement: Wing-cannon fire
While rapid fire or powerful is active, wing cannons SHALL take every primary shot, alternating left and right; the cannon that fired SHALL recoil briefly with a muzzle flash. With wing cannons fitted, spread SHALL still add its angled pair from the nose and large SHALL still enlarge each primary shot. Fire interval, damage, shot speed and steering aim SHALL be unchanged.

#### Scenario: Wing cannons alternate
- **WHEN** rapid fire or powerful is active and four volleys are fired
- **THEN** the primary shots leave from the left, right, left and right wing muzzles, one per volley

#### Scenario: Spread with wing cannons
- **WHEN** powerful and spread are active together
- **THEN** each volley has one alternating wing shot plus spread's angled pair from the nose

#### Scenario: Large with wing cannons
- **WHEN** rapid fire and large are active together
- **THEN** the alternating wing shots are large shots

#### Scenario: Recoil follows the firing side
- **WHEN** the left wing cannon fires
- **THEN** only the left cannon shows recoil and a muzzle flash until its recoil time ends
