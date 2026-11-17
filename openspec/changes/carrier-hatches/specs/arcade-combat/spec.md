# Arcade combat

## ADDED Requirements

### Requirement: Carrier launch hatches on the top surface
In the fight, the carrier SHALL release creatures only through hatches on the side of its hull facing the player: dorsal hatches in tiers, then its core door. Only the topmost intact tier SHALL launch. No creature SHALL leave from under the hull.

#### Scenario: A fresh fight
- **WHEN** the carrier comes in range
- **THEN** its minion flocks come out of the topmost tier's dorsal hatches, alternating sides

#### Scenario: Tiers per tour
- **WHEN** the carrier of tours 1, 2, 3, 4 and 5 or later is built
- **THEN** it has 2, 2, 3, 3 and 4 upper tiers of one hatch pair each

### Requirement: Shootable upper hatches with their own fields
Each upper hatch SHALL have its own small force field and hit points. Only the topmost intact tier SHALL be vulnerable; shots pass over sealed tiers. A shot on the armour outside a vulnerable hatch SHALL do no damage. The carrier SHALL have no hull-wide shield.

#### Scenario: Breaking a hatch
- **WHEN** the player's shots strike a vulnerable hatch
- **THEN** its field takes the hits until it breaks, then the hatch itself, and at zero the hatch is destroyed and breaks apart

#### Scenario: A tier destroyed
- **WHEN** both hatches of the vulnerable tier are destroyed
- **THEN** the next tier down arms its fields and becomes the vulnerable, launching tier

#### Scenario: A miss on the armour
- **WHEN** a shot strikes the hull away from any vulnerable hatch
- **THEN** it sparks off and does no damage

### Requirement: Carrier transformation exposes the core door
Only when every upper hatch is destroyed and has fallen SHALL the carrier transform, for 3.5 s, with no hitbox, no fire and its flock timer held. The transformation SHALL expose the core door, the lower delicate hatch, which is then the only target, and the camera SHALL zoom back in slowly.

#### Scenario: The last hatch falls
- **WHEN** the last upper hatch's break-up completes
- **THEN** the transformation starts, the camera eases from the tour's minimum zoom toward 0.86 at 0.04 per second, and after 3.5 s the core door is exposed

#### Scenario: Before the hatches are gone
- **WHEN** any upper hatch is intact
- **THEN** no shot can damage the core

### Requirement: Fairer core chapter
In the core chapter, the core door SHALL take hits only while it is at least 0.4 open, with a hit half-width of 24 × its openness. The carrier's lateral motion SHALL be slowed to 0.25 of today's rate in the hatch chapter and 0.4 in the core chapter. The side hatches SHALL be sealed. Core-chapter flocks SHALL leave through the open core door, never forcing it open.

#### Scenario: Leading the door
- **WHEN** the carrier glides at its fastest in the core chapter
- **THEN** the core door moves at most about 48 units per second, and a shot from the ship's row needs a lead of about 30 units or less

### Requirement: Carrier launch arrival invariance
Hatches SHALL change where the fight's creatures come from, not when they arrive. The flock timer, size, kinds and caps SHALL be unchanged. Each entrance SHALL end when it does today, except during a core-door hold or the transformation. A creature SHALL not be targetable above hull-local y + 40.

#### Scenario: A top-tier flock
- **WHEN** a flock launches from a tier far above its home row
- **THEN** it leaves the hatch earlier, by its longer transit less today's 0.55 s entrance, and each creature reaches its home at today's moment

### Requirement: Easier carrier by calibrated targets
The carrier fight SHALL get easier on purpose. For the expert pilot, time-to-kill SHALL fall by 25, 20 and 10 % on Easy, Normal and Hard, and lives lost by 30, 25 and 15 %, each within 5 points. A naive pilot that does not lead SHALL kill every carrier on Easy and 90 % on Normal.

#### Scenario: Calibration run
- **WHEN** `test/boss_fairness_test.dart` runs against the values recorded before the change
- **THEN** every ratio lies inside its band, and the before and after values and the commit are in `plan/calibration-current.md`

#### Scenario: Later changes
- **WHEN** a later change runs the endurance test
- **THEN** it is gated within 5 % pooled and 10 % per difficulty of the new baseline

### Requirement: Hatch and transformation events
The volley lifecycle SHALL be emitted as `bossHatchTelegraph`, `bossHatchOpen`, `bossLaunch` and `bossHatchClose`, not as the `bossGate*` names. `bossHatchFieldDown`, `bossHatchDrop`, `bossHatchTier`, `bossTransform` (start, end) and `bossCoreExposed` SHALL follow the structure. All SHALL be structured events only.

#### Scenario: A tier destroyed
- **WHEN** a shot destroys the second hatch of a tier
- **THEN** the queue carries `bossHatchDrop`, then `bossHatchTier` with the next tier, the tier count, depth and shootable, and none of these names appears in the raw event list

#### Scenario: The transformation
- **WHEN** the last upper hatch has fallen
- **THEN** the queue carries `bossShieldDown`, `bossTransform` start, and 3.5 s later `bossTransform` end, then `bossCoreExposed`
