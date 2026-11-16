# Arcade combat

## ADDED Requirements

### Requirement: Carrier launch hatches on the top surface
In the fight, the carrier SHALL release creatures only through launch hatches on the side of its hull that faces the player: dorsal hatches in tiers, then the deck bays, then the core door. Only the topmost intact tier SHALL launch. No creature SHALL leave from under the hull.

#### Scenario: A fresh fight
- **WHEN** the carrier comes in range with its shield full
- **THEN** its minion flocks come out of the first, topmost upper tier's dorsal hatches, alternating sides

#### Scenario: Tiers per tour
- **WHEN** the carrier of tours 1, 2, 3, 4 and 5 or later is built
- **THEN** it has 2, 2, 3, 3 and 4 upper tiers of one hatch pair each, plus the deck tier and the maw tier: 4, 4, 5, 5 and 6 tiers in all

### Requirement: Hatch tiers drop with the shield and the forms
Upper tiers SHALL drop at fixed shield-cell counts, one tier per threshold, the topmost first. The deck tier SHALL take over at shield zero, and the maw tier at the last form, when the side hatches seal. A dropped hatch SHALL never launch again.

#### Scenario: Thresholds
- **WHEN** the lit shield cells fall to 6 and then 0 on tours 1–2, to 9, 6 and 0 on tours 3–4, or to 9, 6, 3 and 0 from tour 5
- **THEN** the topmost intact upper tier drops at each of those counts, and at 0 the deck tier becomes the launching tier

#### Scenario: The last form
- **WHEN** the carrier enters its last form and its side hatches seal
- **THEN** the deck bays drop and the core door is the only launching hatch until the collapse

#### Scenario: A volley caught by a drop
- **WHEN** a tier drops while one of its hatches still holds creatures waiting to leave
- **THEN** those creatures leave from the next tier's hatch on the same side, or from the other side when that hatch is outside the arena

### Requirement: Shootable last tiers ride the door cycles
A deck-tier launch SHALL leave through a deck bay or the core door that is open in the simulation at that moment, and a maw-tier launch through the open core door. When none is open, the volley SHALL wait in the hatch for the first opening, at most one door period. A launch SHALL NOT force a door open.

#### Scenario: No opening is open
- **WHEN** a deck-tier flock is due and both bays and the core door are closed
- **THEN** the creatures wait unseen and untargetable in the bay that opens first, and leave as it opens, while the core's hit windows follow the unchanged door cycles

### Requirement: Carrier launch arrival invariance
Hatches SHALL change where the fight's creatures come from, not when they arrive. The flock timer, flock size, kinds and caps SHALL be unchanged. Each creature's entrance SHALL end when it does today, except for a deck or maw hold. A creature SHALL not be targetable above the transit line, hull-local y + 40.

#### Scenario: A top-tier flock
- **WHEN** a flock launches from the topmost tier, about 300 units above its home row
- **THEN** it leaves the hatch earlier, by its longer transit less today's 0.55 s entrance, and each creature reaches its home at today's moment

#### Scenario: Crossing the hull
- **WHEN** a player shot passes a creature still above the transit line
- **THEN** the shot does not hit it

### Requirement: Calibrated hatch cascade
The cascade SHALL keep boss endurance pooled within 5 % and each difficulty within 10 % of its baseline. It SHALL keep the campaign playtest metrics in bounds and the boss level's clear time within 10 %. The before and after values SHALL be recorded in `plan/calibration-current.md`.

#### Scenario: Calibration run
- **WHEN** `test/boss_endurance_test.dart` and `test/campaign_playtest_test.dart` run with the cascade
- **THEN** they pass within those gates, and the deck hold's share of delayed arrivals is printed

### Requirement: Hatch events for the score
The volley lifecycle SHALL be emitted as `bossHatchTelegraph`, `bossHatchOpen`, `bossLaunch` and `bossHatchClose`, each with the hatch, tier and shootability; carrier-v3's `bossGate*` names SHALL no longer be emitted. Each knocked-out hatch SHALL emit `bossHatchDrop`, and each tier change `bossHatchTier`, as structured events only.

#### Scenario: A tier drops
- **WHEN** a shot takes the shield to the first threshold
- **THEN** the queue carries `bossShieldCellLost`, then `bossHatchDrop` for the left and then the right hatch of tier 1, then `bossHatchTier` with tier 2, the tier count, depth and shootable false, and none of these names appears in the raw event list

#### Scenario: The fight begins
- **WHEN** the carrier comes in range
- **THEN** `bossHatchTier` with tier 1 is queued right after `bossInRange`
