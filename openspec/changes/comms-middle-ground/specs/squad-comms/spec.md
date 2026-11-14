# Squad comms

## ADDED Requirements

### Requirement: Middle-ground airtime
The director SHALL pace speech so that, in ten minutes of busy sector-3 combat simulated with a fixed seed, paced airtime (everything except must-play ground-fire warnings) is between 35 % and 45 %. This replaces the 15–25 % band of comms-pacing. The airtime budget SHALL scale with the music director's intensity tier, so that a calm stretch talks clearly less than busy combat. The rests SHALL keep their seeded jitter, and the same seed SHALL replay the same lines at the same times.

#### Scenario: Busy sector
- **WHEN** ten minutes of busy sector-3 combat are simulated with seeds 4, 11 and 23
- **THEN** paced airtime is between 35 % and 45 % for each seed

#### Scenario: Release stretch
- **WHEN** a calm stretch is simulated at intensity tier 1
- **THEN** paced airtime stays below 30 %

### Requirement: No line cuts another
A line SHALL never be cut by another line, whatever its class. The comms-pacing rule that urgent and must-play warnings cut lower classes is withdrawn. After every line the channel SHALL keep a grace gap of 0.35–0.5 s (0.4 s by default) before the next line starts. The regroup chorus is the only exception and overlaps only itself.

#### Scenario: Urgent warning during a briefing
- **WHEN** a sentinel or shield-expiring warning arrives while a briefing is speaking
- **THEN** the briefing finishes, the grace gap follows, and the warning plays next

### Requirement: Lookahead for timed calls
The director SHALL NOT start a line that would still be speaking (with its grace gap, and with an exchange's answer) when a known timed call is due: a queued dive call, a queued ground-fire warning, or the last 2.1 s before a forecast launch (`groundFireForecast`). If a conflict still happens, the line on air SHALL finish, the grace gap SHALL follow, and the waiting warning SHALL play its shortest variant. A must-play warning SHALL never be dropped. The simulation SHALL report how many warnings ended after their launch, and that number SHALL stay at or below 8 % of launches.

#### Scenario: Warning after a long line
- **WHEN** a ground unit commits to a shot due in 1 s while a 3 s line is speaking
- **THEN** that line finishes, and the shortest warning starts after the grace gap and is counted as late

#### Scenario: Forecast shot
- **WHEN** a launch is forecast 4 s ahead and a long line is waiting
- **THEN** the long line does not start, and the full warning ends at the launch

### Requirement: Moments are voiced from recorded clips
Wave starts, reinforcement arrivals, sentinel escorts, carrier phases and hatch, the next wave on the horizon (`incoming`), level clear, salvage and sector starts SHALL rank as useful lines. One moment observed twice (`reinforcements` and `reinforcementsArrived`, `incoming` and `waveStart`) SHALL be voiced once. Only existing bank clips SHALL be used at runtime. Lines still to be recorded SHALL be listed in a pending-lines file for the next voice render.

#### Scenario: Reinforcements
- **WHEN** a reinforcement flock arrives (both events in one frame)
- **THEN** exactly one squad reinforcement call plays

#### Scenario: Carrier hatch
- **WHEN** the carrier's hatch opens
- **THEN** a recorded line such as "Field's down! Hit the core!" plays

### Requirement: Readable radio text
Each subtitle or card SHALL stay on screen until the later of its clip end plus its hold (2.6 s human, 3.2 s demon) and its reading time (0.9 s + 0.055 s per character of text or SIGINT gloss, at most 7 s). A linked exchange's opening line SHALL stay up until its answer has been read. In the compact dock, cards SHALL keep their place, oldest first, until read. A linked exchange SHALL take the full width. A card without room SHALL wait as a one-line ticker under the dock, so that no card hides another and the dock never grows past its maximum height.

#### Scenario: Taunt and retort
- **WHEN** the brood taunts and the squad answers
- **THEN** both texts stay up together until the answer's reading time has passed

#### Scenario: A warning during an exchange
- **WHEN** a ground-fire warning starts while an exchange is still on screen
- **THEN** the exchange keeps its toast and the warning shows as the ticker line

### Requirement: Air-cover and ground lines match the fight below
The observer SHALL publish `groundPicture` (engaged units, threats, whether the ship is over the battle) whenever it changes. A line whose words go beyond its own event SHALL play only when they are true:
- Air-cover lines only while the ship is over the fight.
- Calls for help only within 10 s of `allyUnderAttack` while ground units are engaged.
- Surge and pressure narration only while ground units are engaged.
- Flank, force and artillery lines only when the event's data matches.
- Ground-crew comebacks only in sectors with a ground war.

#### Scenario: Ship away from the battle
- **WHEN** ground units reach range while the ship flies far from them
- **THEN** "You're right over them. Bring the rain!" is not said, and another in-range line may be

### Requirement: Transition hooks
`CommsDirector.hush` SHALL hold every line below urgent until the hush ends, without muting the voice, and SHALL still play must-play and urgent warnings. `CommsDirector.offer` SHALL queue one chosen bank line through the normal pacing, so it plays after the line on air and the grace gap.

#### Scenario: Silent tip
- **WHEN** a tip interlude hushes the radio for 4 s while a briefing and a ground-fire warning arrive
- **THEN** the warning plays during the hush and the briefing plays after it
