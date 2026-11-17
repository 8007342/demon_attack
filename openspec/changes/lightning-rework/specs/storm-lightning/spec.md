# Storm lightning

## ADDED Requirements

### Requirement: Lightning stuns creatures
A bolt SHALL stun, never damage, every targetable creature inside its column that wears no lightning-rod armour. A stunned creature SHALL fall for a moment, then climb back to its place in the formation or its pattern, and SHALL never fall closer than 70 units above the ship's row.

#### Scenario: A small creature is struck
- **WHEN** a bolt lands on a drone
- **THEN** it falls for 0.45 s, at most 44 units below where it was struck, climbs back at up to 150 by 130 u/s, and flies normally again 0.9-1.8 s after the bolt, with its hit points unchanged

#### Scenario: A sentinel is struck
- **WHEN** a bolt lands on a sentinel without rods
- **THEN** it sags for 0.28 s, at most 18 units, and recovers the same way

### Requirement: A stunned creature is defenceless
While stunned, a creature SHALL NOT fire, prepare a dive, dive or dodge, its dive and any tell SHALL be cancelled, and its shield and armour SHALL NOT absorb hits. Shot down while stunned it SHALL score its ordinary kill points and count as an ordinary kill.

#### Scenario: Shooting a falling creature
- **WHEN** the player shoots a creature while it is stunned
- **THEN** the hit goes straight to its body and the kill scores exactly what the same creature would score unstunned and not diving

### Requirement: Lightning zaps the ship and never costs a life
A bolt whose core meets the ship SHALL strip every active shield, power-up and bonus power at once and SHALL NOT cost a life or start the life-loss sequence. A protected ship, a ship that is away, and a ship inside its lightning grace SHALL ignore the bolt.

#### Scenario: Zapped with a full loadout
- **WHEN** a bolt meets a ship carrying a shield, spread and rapid fire
- **THEN** all three are gone, the two modules are blown off the hull, the ship flies on and the lives are unchanged

#### Scenario: Zapped with nothing to lose
- **WHEN** a bolt meets a ship with no powers
- **THEN** the ship flickers and flies on, and no life is lost

### Requirement: Lightning grace
After a zap the ship SHALL ignore every bolt for 1.5 s, so a fork landing in the same instant or the next bolt cannot strike it again.

#### Scenario: A forked bolt
- **WHEN** two columns of one forked strike both cover the ship
- **THEN** the ship is zapped once

### Requirement: The zap is readable and avoidable
Every bolt that can meet the ship SHALL be telegraphed for at least one second. In the second half of a tell on its column the ship SHALL show static sparks; a zap SHALL show a burst on the hull for 0.9 s, the ship flickering for its first half, a stripped shield breaking into shards and the modules tumbling away. With reduced motion nothing SHALL flicker.

#### Scenario: Static before the bolt
- **WHEN** the ship sits in a told core past the tell's midpoint
- **THEN** amber sparks crawl over the hull until the bolt or until it slides out

### Requirement: Ranks dodge lightning
In a storm, a marked creature SHALL sidestep out of a told column by a deterministic share that grows with its rank and route; drones SHALL never dodge. A higher rank SHALL dodge every bolt a lower rank on the same roll would. A creature that decides to dodge SHALL clear the column before the bolt.

#### Scenario: Shares per rank on the first tour
- **WHEN** a tell begins over creatures of each rank on route 0
- **THEN** about 25 % of skirmishers, 45 % of veterans, 70 % of hunters and 85 % of sentinels slide out, reacting at 40 %, 35 %, 25 % and 25 % of the tell

#### Scenario: Later tours
- **WHEN** the same tell comes on a later route
- **THEN** each marked rank's share is 4 points higher per route, up to route 4 and at most 95 %

### Requirement: Lightning-rod armour
In a storm, sentinels from the second tour and hunters from the third SHALL wear lightning-rod armour. A rod-armoured creature SHALL NOT be stunned: a bolt within 58 units of it SHALL charge it for 5 s, during which it fires 1.8 times as often and glows; it SHALL drift toward a tell within 96 units.

#### Scenario: A charged hunter
- **WHEN** a bolt lands 50 units from a rod-armoured hunter
- **THEN** the hunter is not stunned, glows and arcs between its rods, and its volleys come 1.8 times as often for 5 s

#### Scenario: The first tour
- **WHEN** a storm is flown on route 0
- **THEN** no creature wears rods

### Requirement: The lightning radio
The squad SHALL warn "Avoid lightning!" on a tell on the ship, ending on the bolt and at most once per 11 s, and SHALL reassure the pilot after a zap. The squad SHALL cue stunned creatures and warn of a charge; the brood SHALL yelp when stunned, gloat after a zap and roar when charged. Each SHALL be one family-friendly line, rate-limited per trigger, on its own side's lane.

#### Scenario: After a zap
- **WHEN** a zap strips the ship's power-ups
- **THEN** a line such as "You're fine, only the power-ups are gone." plays, or "You're fine, the ship can take it." when nothing was lost

#### Scenario: Unrecorded lines
- **WHEN** a lightning line has no recording yet
- **THEN** it is shown with its own words and speaker and plays no audio

### Requirement: Lightning is deterministic
A bolt's stun, zap, dodges and charges SHALL draw nothing from the simulation's random stream; a creature's dodge SHALL be a pure function of its seed, its rank, the route and the strike's index.

#### Scenario: Same seed, same storm
- **WHEN** the same storm is played twice with the same input
- **THEN** the same creatures dodge, are stunned and are charged at the same moments
