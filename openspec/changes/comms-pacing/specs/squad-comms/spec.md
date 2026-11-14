# Squad comms

## ADDED Requirements

### Requirement: Paced radio with real silence
The director SHALL limit paced speech with an airtime budget and a rest after every line that carries seeded random jitter. In busy combat, paced airtime (everything except must-play ground-fire warnings) SHALL be 15–25 %, and lower in calm stretches. The jitter SHALL be deterministic for a given seed. Flavour lines SHALL expire after a short wait, and at most two SHALL wait at once.

#### Scenario: Busy sector
- **WHEN** ten minutes of busy sector-3 combat events are simulated with a fixed seed
- **THEN** paced airtime is between 15 % and 25 %, and the same seed replays the same lines at the same times

#### Scenario: Burst of chatter
- **WHEN** many flavour events arrive while a line is playing
- **THEN** at most two of them wait, briefly, and the others are dropped rather than stacked

### Requirement: No voice over another
Two lines SHALL never sound at once, apart from the regroup chorus overlapping itself. A playing line SHALL be cut only by an urgent warning or a must-play ground-fire warning, and only when it is of a lower class (flavour < useful < hint < urgent < must-play). A must-play warning SHALL never be cut.

#### Scenario: Flavour yields to ground fire
- **WHEN** a ground unit commits to a shot while a banter line is playing and the warning cannot fit after it
- **THEN** the banter line stops and the full warning plays

### Requirement: Recommendations win over flavour
When a shield pickup falls while the ship has no shield, or a weapon power-up falls while the ship has no weapon power, the squad SHALL recommend it. A recommendation SHALL rank above flavour and useful lines, ignore the budget and the long rest, and SHALL be said again right after a warning that cut it. At most one SHALL play per 12 s.

#### Scenario: Bare ship
- **WHEN** a shield pickup falls in busy combat and the ship has no shield
- **THEN** a full recommendation such as "Shield pickup falling. Grab it!" starts within 8 s (in at least 95 % of cases, and always within 12 s)

### Requirement: Dive calls end on the dive
`divePrep` SHALL carry `diveIn`, the seconds until the dive starts. The director SHALL pick a dive call whose measured clip duration fits and start it early, so that its speech ends within 0.3 s of the dive start. A call that cannot end on time SHALL be dropped, never played late.

#### Scenario: Ordinary dive
- **WHEN** `divePrep` arrives with `diveIn` 1.2 s
- **THEN** a call such as "Divers coming down!" (1.28 s) starts at once and ends within 0.3 s of the dive

#### Scenario: Observed too late
- **WHEN** a dive call is observed only as the dive starts (`diveIn` 0)
- **THEN** nothing plays

### Requirement: Must-play ground-fire warnings
A ground unit's shot at the player SHALL be preceded by a committed beat (`groundFirePrep`, `fireIn` seconds before the launch) without changing its shot cadence or damage. The warning SHALL never be dropped by the pacing and never cut. Its full clip SHALL end at the launch, or at most 0.8 s before it. A launch within 2 s after a completed warning SHALL count as warned by it (a salvo). Must-play warnings SHALL be outside the airtime budget, and their share SHALL be reported separately.

#### Scenario: Every launch warned
- **WHEN** ten minutes of combat with ground fire are simulated
- **THEN** every launch has a complete, uncut warning that ended at the launch or at most 2 s before it

### Requirement: Readable subtitles
Radio and brood subtitles SHALL use the larger text sizes (compact cards 13 px, SIGINT translations 12.5 px, side tiles 13.5 px, transmissions 17 px). They SHALL stay on screen 2.6 s after a human clip ends and 3.2 s after a demon clip ends. The compact dock SHALL still never cover the HUD or the ship.

#### Scenario: Reading after the voice
- **WHEN** a pilot's 1.5 s line ends
- **THEN** its text stays readable for another 2.6 s before it fades
