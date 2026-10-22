## Purpose
Preserve interrupted campaign progress across browser visits and retain earned difficulty unlocks through compatible updates.

## ADDED Requirements

### Requirement: Wave checkpoint resume
The game SHALL save a compact checkpoint at each wave entrance, including boss encounters. Resume SHALL restart the saved wave with saved score, mode, route, lives, medals, heart inventory and accumulated active time, and zero powerups. In-wave positions and projectiles SHALL NOT be persisted.

#### Scenario: Interrupted wave
- **WHEN** a player closes the browser midway through a wave and later resumes
- **THEN** the saved wave starts anew with its checkpoint values and no powers

### Requirement: Compatible local state
Missing fields in older saves SHALL receive safe defaults, unknown optional fields SHALL be ignored, and valid older checkpoints SHALL remain loadable after updates. Corrupt state or unavailable storage SHALL leave a playable landing page. Completed or lost runs SHALL cease offering Resume.

#### Scenario: Older checkpoint
- **WHEN** an otherwise valid checkpoint omits newer metadata
- **THEN** Resume defaults that metadata and restores the known route and score

#### Scenario: Storage failure
- **WHEN** browser storage is unavailable or malformed
- **THEN** starting a new Normal run remains possible without a crash

### Requirement: Permanent mode unlocks
Normal SHALL always be available. Easy SHALL unlock after three game overs while no boss has ever been beaten in any mode. Hard SHALL unlock only upon a Normal boss victory. Unlocks SHALL persist locally and remain unlocked thereafter; interruptions SHALL NOT count as failures.

#### Scenario: Easy unlock
- **WHEN** a player with no boss victories loses their third run
- **THEN** Easy becomes permanently available

#### Scenario: Hard eligibility
- **WHEN** a player defeats a boss in Easy
- **THEN** Hard remains locked until a Normal boss is defeated
