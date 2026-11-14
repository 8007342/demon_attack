# Ground forces rework presentation

## ADDED Requirements

### Requirement: Ground hull headings
Every reworked ground vehicle SHALL have five authored hull headings in 22.5° steps, mirrored for the other side: 0°–90° for the Ground Fleet and 90°–180° for the Undercroft Host, where 0° points up the plane and 180° toward the camera. Infantry SHALL have three authored headings, mirrored. Ground sprites SHALL NOT be rotated or smooth-scaled at runtime to show a heading; only quarter turns of debris pieces are allowed.

#### Scenario: Heading set present
- **WHEN** the generated ground block metadata is read for any reworked vehicle
- **THEN** it names a move cycle at each of the five authored headings, and every named cell exists in the atlas with binary alpha

### Requirement: Turning through intermediate headings
A ground unit's shown heading SHALL follow its smoothed, rate-limited direction of travel, change by one authored step at a time with hysteresis, and hold each step for at least its class's minimum hold (0.10 s infantry, 0.12 s light, 0.20 s heavy, 0.18 s walker, 0.40 s command). A turn SHALL NOT skip a heading.

#### Scenario: A heavy turns 90°
- **WHEN** a Lodestar's direction of travel swings from straight up the plane to screen right
- **THEN** it shows the 0°, 22.5°, 45°, 67.5° and 90° headings in order, each for at least 0.2 s, and the turn takes between 1.0 and 1.4 s

#### Scenario: No flicker on a wobble
- **WHEN** a unit's direction of travel oscillates ±5° around the midpoint between two headings
- **THEN** its shown heading does not change

### Requirement: Independent articulated layer
A vehicle with a turret or other articulated layer SHALL draw that layer from a per-heading pivot at its own angle, chosen from the same 22.5° grid with its own rate limit and hysteresis, independent of the hull heading. Muzzle points SHALL be taken per layer angle.

#### Scenario: Driving one way, aiming another
- **WHEN** an engaged Lodestar drives at 45° to the right while its foe is 22.5° to the left
- **THEN** the hull shows the 45° heading and the turret shows the mirrored 22.5° angle, seated on the hull's turret ring, and its tracer leaves from that angle's muzzle

### Requirement: Ground Fleet design language
Ground Fleet vehicles SHALL use straight and chamfered faceted plate from the `ally_hull` ramp, cyan light strips from `ally_cyan`, a compact turret set forward with a 2-texel-thick main gun, and antenna height as the rank cue. They SHALL NOT use `demon_warm`, `demon_gilt`, warm lamps, hooks, pointed arches, horns or faces. Allied vehicles SHALL NOT break into pieces or show death imagery.

#### Scenario: Palette scan
- **WHEN** every Fleet cell is scanned
- **THEN** no pixel belongs to `demon_warm` or `demon_gilt`, and no body pixel is brighter than `ally_hull` step 4 except 1-texel speculars and cyan strips

#### Scenario: Turret reads at the far scale
- **WHEN** a Fleet vehicle is drawn at its farthest advance (z 620)
- **THEN** its turret top differs from the surrounding hull by at least two ramp steps and a reviewer can tell which way the turret points

### Requirement: Rich Undercroft Host animation
Every Tier A Undercroft Host unit SHALL have authored or generated frames for idle, move at every authored heading, attack wind-up (channel fill) and release, hit, two damage states, death and arrival, plus its special action. Idle loops SHALL run at 2–3 fps. The Host SHALL stay carved stone: no insect, chitin, creep, slime or tentacle forms.

#### Scenario: A Crocket's full set
- **WHEN** the Crocket's block is inspected
- **THEN** it holds 4 move frames at each of 5 headings, `fill1`–`fill3` and `lights` overlays per heading, `dmg1` and `dmg2` overlays per heading, 4 `arrive` frames, wreck and rubble frames, and 12 debris pieces

### Requirement: Host arrival by unearthing
A Host unit that appears mid-field SHALL be able to arrive by unearthing: a crypt slab cracks with warm seams, heaves, and the unit climbs out with a dust ring, in four frames. Far arrivals SHALL be able to emerge from the fog instead.

#### Scenario: Unearthing frames
- **WHEN** a Host vehicle's `arrive` frames play
- **THEN** frame 0 shows a slab with warm seams, frame 2 shows the unit's top half above the ground line, and frame 3 shows it at full height before its move cycle starts

### Requirement: Distance atmosphere layers
The ground SHALL have stepped-alpha atmosphere layers per sector: a horizon fog band, a low cloud deck, two mist banks that take part in the ground depth sort, cloud shadows, battlefield smoke and a tide dust veil. Units SHALL be tinted toward the sector's fog colour by depth, with emissive pixels fogged at half rate, so that beyond z 1150 mainly their light pattern shows. Threat units SHALL be fogged by at most 45%.

#### Scenario: Emerging from the mist
- **WHEN** a Host unit walks from z 1400 to z 700
- **THEN** it starts as a fogged silhouette with visible eye lights, passes behind and then in front of the mist banks, and arrives at z 700 with no fog tint

#### Scenario: Threat stays readable
- **WHEN** a threat vehicle is telegraphing at any depth
- **THEN** its telegraph frames and ground bracket are never covered by an atmosphere layer, and its fog tint is at most 45%

### Requirement: Atmosphere never covers play
Atmosphere layers SHALL be drawn below the air layer, SHALL keep a combined alpha of at most 0.30 inside the central lane below y 300, SHALL stay at luma 0.40 or below, and SHALL NOT use `demon_warm`, `ally_cyan` or gilt colours. Under reduced motion their drift SHALL stop.

#### Scenario: Lane cap
- **WHEN** smoke from a wreck drifts toward the central lane
- **THEN** the combined atmosphere alpha over any lane pixel below y 300 stays at or below 0.30

### Requirement: Ground easter eggs
The ground war SHALL include four rare presentation-only flourishes: Fleet squads dancing after a won skirmish (always at sector clear), light Host vehicles breaking into tumbling authored pieces (with a rarer jackpot in which the turret pops and a tiny crew scampers off), falling trees releasing a flock of small original flyers that fly away into the distance, and ground critters fleeing nearby troops.

#### Scenario: A tree releases a flock
- **WHEN** the convoy pushes over a frost-pine and the egg budget allows it
- **THEN** a flock of 5 to 9 small flyers leaves the crown, flies up and away from the lane toward the horizon, and is gone within 2.5 s

### Requirement: Easter eggs never obscure gameplay
Ground easter eggs SHALL have no hitbox, score or simulation effect, and SHALL draw randomness from a presentation stream, never the game's shared random stream. They SHALL NOT enter the central lane below y 300, SHALL keep body luma at 0.34 or below without signal colours, SHALL be suppressed while a threat telegraph, ground missile, boss fight or last life is in play, SHALL run at most two at once for at most 2.5 s each (3 s for the sector-clear dance), and SHALL be off under reduced motion.

#### Scenario: Same game with eggs on and off
- **WHEN** the deterministic bots fly every sector with easter eggs on and off
- **THEN** the simulation state hashes are identical

#### Scenario: Quiet during a threat
- **WHEN** a ground missile is in flight and a Crocket is destroyed
- **THEN** no jackpot variant, dance or flock starts until the missile is gone
