# Squad comms

## ADDED Requirements

### Requirement: Fang and Wings is the brood's creed
The brood SHALL treat "Fang and Wings!" as its battle cry and creed: wings are given (the flock), fangs are earned (the hunt), and the marks above the heads show what each rank has earned. The creed SHALL be a recurring radio topic in brood chatter and in banter both ways, family friendly, in original phrasing, one line per line.

#### Scenario: Quiet brood
- **WHEN** the brood has been quiet in combat long enough for the director to raise brood chatter
- **THEN** the creed sometimes stands in: a creed line, or a brood cry answered by a squad comeback

#### Scenario: A hunter appears
- **WHEN** an elite (Fang and Wings) is sighted and the tease is off cooldown
- **THEN** the squad sometimes teases or explains the marks and the brood retorts, in one combined toast

### Requirement: Dive war cries
A creature committing to a dive MAY shout a war cry chosen for its rank and species: grunts squeak, elite grunts roar, hunters snarl, sentinels intone "FANG AND WINGS!". The observer SHALL raise a `diveCry` event for each cry, carrying rank, species, position and the seconds until the tell and the dive, so the radio and the demon choir share one cry.

#### Scenario: A sentinel dives
- **WHEN** a sentinel's dive prep passes the cry gate
- **THEN** `diveCry` carries rank `sentinel`, its species, x, y, `diveIn` and `tellIn`, and the radio picks a sentinel line naming the creed

#### Scenario: Species voice
- **WHEN** a violet creature cries
- **THEN** the line is Grunnok's or a voice of no species, never Skritch's, Blatch's or Morth's

### Requirement: Cry rate limits
At most one cry SHALL be in flight (from the decision until 0.8 s after its dive starts), two cries SHALL be at least 8 s apart, and a dive SHALL cry only with its rank's chance, rising from grunts to sentinels. The gate SHALL use its own seeded generator, never the model's. A waiting useful line, recommendation or warning SHALL drop the cries not yet on air.

#### Scenario: A swarm dives
- **WHEN** creatures start a dive every 0.3–1 s for ten minutes
- **THEN** cries are at least 8 s apart, none starts while another is in flight, and the same seed gives the same cries

#### Scenario: Pacing holds
- **WHEN** ten minutes of busy and calm sector-3 combat are simulated with seeds 4, 11 and 23, cries included
- **THEN** every comms-middle-ground pacing target is still met

#### Scenario: Ranks
- **WHEN** many dives of each rank are offered with the gap never deciding
- **THEN** the share that cries rises from grunt to veteran to hunter to sentinel

### Requirement: Cries are timed brood-lane toasts
A cry SHALL play as an ordinary brood radio line, never as floating text over the arena. It SHALL end as its dive starts (within the dive tolerance) when the channel is free; otherwise it SHALL start right behind the squad's dive call, at most 0.7 s after the dive starts, or be dropped. A cry SHALL never cut a line, play late or delay a squad dive call.

#### Scenario: Free channel
- **WHEN** a hunter's cry arrives and nothing else is due
- **THEN** its line ends within 0.3 s of the dive's start

#### Scenario: The squad warns first
- **WHEN** a sentinel's prep brings both the squad's sentinel warning and a cry
- **THEN** the warning plays first and the cry starts after the grace gap, no later than 0.7 s after the dive starts

### Requirement: Creed banter threads
The creed exchanges SHALL play as one combined toast, opening then answer. The answer SHALL prefer the lines written for that opening when their speaker is on the call or, for the squad, on the run's lineup; otherwise any answer of the exchange fits.

#### Scenario: Brood cry, squad comeback
- **WHEN** a creed banter opens with a brood cry
- **THEN** a squad comeback follows after the grace gap in the same toast, and usually one written for that cry
