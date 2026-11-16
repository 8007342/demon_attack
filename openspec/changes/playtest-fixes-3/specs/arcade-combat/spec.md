# Arcade combat

## ADDED Requirements

### Requirement: Sentinel berserk invulnerability
A sentinel SHALL take no damage of any kind (hull, shield, armour or rush shield) during its berserk transformation, the rally and lock before each rush pass, whatever powers or homing hits strike it. Every hit that lands in that time SHALL glance off with a visible deflect spark at the impact and SHALL NOT flash the sentinel as if hurt.

#### Scenario: Shooting a transforming sentinel
- **WHEN** the player lands hits, powered or not, on a sentinel during its rally and lock
- **THEN** its hull, shields and rush shield are unchanged and each hit shows a deflect spark

### Requirement: Rush shield is a super-powerful diving shield
During a rush pass the rush shield SHALL be a super-powerful diving shield of 6 / 8 + cycle÷2 / 10 + cycle÷2 points (Easy / Normal / Hard). Base-gun hits SHALL deflect with no damage; hits under an offensive power, and homing hits, SHALL wear it by their damage plus one each for Powerful and Large. The hull SHALL take nothing while it holds. Breaking it mid-rush SHALL stagger the sentinel and award 150 × (cycle + 1) × enemy points.

#### Scenario: Base gun against the charge
- **WHEN** a player with no power active lands hits on a rushing sentinel
- **THEN** each hit deflects and the rush shield keeps all its points

#### Scenario: Powered breaker
- **WHEN** a player with Powerful active lands a hit on a rushing sentinel
- **THEN** its rush shield loses three points

### Requirement: Dodging the rush always pays best
Every rush pass the sentinel finishes without touching the ship SHALL award 300 × (cycle + 1) × the difficulty's enemy points, more than breaking the rush shield. A sentinel whose last pass is dodged SHALL burn out off screen paying its full kill value, without a power drop and without counting as a kill. A sentinel that ends the rush by taking a life SHALL still pay nothing.

#### Scenario: Outlasting the rush
- **WHEN** the player dodges every pass of a sentinel's rush
- **THEN** the score rises by the dodge award per pass plus the sentinel's kill value, at least as much as breaking its shield and shooting it down would have paid

### Requirement: Final rushes are more frequent
A sentinel SHALL be eligible for a final rush with probability 0.28 / 0.45 / 0.55 (Easy / Normal / Hard), plus up to 0.10 with skill, superseding 0.20 / 0.35 / 0.45. The triggers, passes, speeds and homing limits are unchanged.

#### Scenario: Normal sentinel births
- **WHEN** many sentinels are born on Normal at skill 0
- **THEN** about 45 % of them are eligible for a final rush
