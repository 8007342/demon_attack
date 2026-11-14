# Undercroft Host combat

## ADDED Requirements

### Requirement: Host forces by sector
The skirmish layer SHALL add Host forces sector by sector:
- Krybor: Rubbling packs and Crocket light tanks;
- Ringfall: Reliquary carriers and Hodcrawlers;
- Ember: Carillon artillery and Knell-bearers;
- Hollow: Buttress Striders and Priors;
- Carrier: an elite mix.

#### Scenario: Variety in the Hollow
- **WHEN** sector 4 on route 1 is flown for two minutes
- **THEN** every Tier A Host force available there appears at least once

### Requirement: Shared skirmish caps
Skirmish caps and arrival intervals SHALL stay as in ground war v4, and Host forces SHALL share them with the v4 forces.

#### Scenario: Cap held
- **WHEN** any sector is flown with Host forces on
- **THEN** the live skirmish count never exceeds the v4 cap for that sector and tide

### Requirement: Same threat with the Host
Host forces SHALL NOT fire at the player and SHALL hold at 430 texels or more. They SHALL NOT change ground pressure or allied strength, SHALL NOT draw from the shared random stream, SHALL NOT be homing targets, and SHALL NOT total an ally.

#### Scenario: Host off and on
- **WHEN** every sector is flown by the same deterministic pilots with the Host forces off and on
- **THEN** breakthroughs and ground missiles fired at the player are equal, and no ally retreats in sectors 1–2

### Requirement: Reliquary unload
A Reliquary SHALL unload one Ashlar squad, at most once, at its hold line or at 50% HP or below, and only while the live skirmish count is under the cap.

#### Scenario: Unload respects the cap
- **WHEN** a Reliquary reaches its hold line while the live skirmish count is at the cap
- **THEN** it does not unload, and it may unload later once the count drops, still at most once

### Requirement: Carillon stand-off fire
A Carillon SHALL hold at 620–760 texels and lob arcing slag shells at its engaged ally.

#### Scenario: Artillery holds deep
- **WHEN** a Carillon is engaged
- **THEN** it never advances nearer than 620 texels, and `artilleryRanging` fires before its first salvo

### Requirement: Mending and rally
A Hodcrawler SHALL restore 1 HP to the most damaged Host unit within 90 texels every 4 s. Knell-bearers SHALL, on each tide surge, hasten Host units within 120 texels by 20% for 5 s.

#### Scenario: Mend
- **WHEN** a Host tank at 2 of 6 HP stays within 90 texels of a Hodcrawler for 8 s without being hit
- **THEN** it has 4 HP

### Requirement: Chapterhouse command
At most one Chapterhouse SHALL appear per visit: in the Hollow from route 1 and in the Carrier sector from route 2. While it lives, skirmish arrival intervals SHALL be ×0.85. Its fall SHALL rout Rubblings within 160 texels and force a 6 s tide lull.

#### Scenario: Command falls
- **WHEN** the allies destroy a Chapterhouse with a Rubbling pack 100 texels away
- **THEN** `hostCommandFallen` fires, the pack runs toward the horizon and leaves, and no new skirmish arrival comes for 6 s
