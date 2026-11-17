# Arcade presentation

<!-- Rebased onto the arcade-presentation text after `fluid-transitions` was archived (2026-11-15). The
     interlude requirements that change below came from that change; they now describe slots, not cards. -->

## MODIFIED Requirements

### Requirement: Illustrated gameplay instruction
Gameplay hints SHALL pair one brief actionable sentence with one original pixel illustration and equivalent semantics where an illustration is shown. Illustrated hints SHALL appear during the run's opening arrival and in the pause menu's tips. Later sector transitions SHALL NOT show hints or any other floating text: they speak only through a radio line on the comms dock (or, flying into a bonus level, its urgent-mission radio card on the dock; see bonus-levels). Hints SHALL advance automatically without guide, Hold, Menu or manual-advance controls; a tap, Space or Enter MAY skip the opening card early. Normal pause SHALL hold the opening card and resume it where it was. Advice SHALL describe actual game rules without promising protection the simulation does not grant.

#### Scenario: One tactic at a glance
- **WHEN** an illustrated hint is shown at phone size
- **THEN** one recommended action is legible in both the sentence and picture without clipping or unrelated decorative detail

#### Scenario: Automatic loading hint
- **WHEN** a run begins
- **THEN** one complete illustrated hint appears during the opening arrival and disappears automatically before the initial swarm flies in

#### Scenario: No caption between sectors
- **WHEN** a later sector transition plays
- **THEN** no tip sentence, caption or title text is drawn over the play area; the transition's message is a radio line on the comms dock

#### Scenario: Tips in the pause menu
- **WHEN** the player opens the pause menu
- **THEN** a tips pane shows the illustrated hints without resuming play

#### Scenario: Accurate shield advice
- **WHEN** a hint explains shield renewal
- **THEN** it associates the grace period with absorbing a hit and never claims that unused shield expiry grants invulnerability

### Requirement: One primary transition message
During any transition the play area SHALL show at most one primary message. Transitions SHALL communicate level passing only through radio chatter: in a sector transition that message SHALL be a radio line on the comms dock. No text SHALL be drawn over the play area without a window or toast: no caption, tip sentence, sector or tour title, reward text, story card, storyboard banner, interlude card or sector pips. The opening arrival MAY show its illustrated tip card (a window), and the carrier arrival MAY show its alert (a window). The one sanctioned exception for a sector transition is a bonus level's urgent-mission card (change `bonus-levels`): a radio comm in the dock's toast style with a speaker portrait and the scripted chatter, not floating text. The medal SHALL show as a brief glyph flourish beside the ship without text; the extra life is counted by the HUD. The tour escalation SHALL be carried by the radio line. The title screen, pause and ending pages are unaffected.

#### Scenario: Sector change
- **WHEN** a sector is cleared and the run travels to the next
- **THEN** a radio line plays on the comms dock, no floating text is drawn over the play area, and no card covers it

#### Scenario: Flying into a bonus level
- **WHEN** the next sector is the run's bonus level
- **THEN** the transition's radio is the urgent-mission card heading the comms dock (a radio comm, not floating text), it never covers the ship row, and nothing else is drawn over the play area

#### Scenario: Story beats kept
- **WHEN** a sector is secured, a carrier falls or the run jumps into a new route
- **THEN** the next leg's briefing or crew chatter plays as a radio line, and the medal glyph flourishes beside the ship

### Requirement: Alternating transition interludes
Every level and mission transition SHALL schedule one message slot during the pursuit, and that slot SHALL be a recorded radio line on the comms dock. The run's opening arrival SHALL show an illustrated tip instead. The line SHALL be seeded by category (briefing, banter, joke, taunt) and SHALL never repeat the line shown just before; when no fresh line fits, the shortest recorded line SHALL be used, so a transition is never silent. No new audio is generated for it.

#### Scenario: Alternation
- **WHEN** a run passes several sector transitions
- **THEN** the opening is an illustrated tip and every later slot is a radio line that plays on the dock (no caption alternates with it), no line repeats back to back, and the same seed gives the same sequence

### Requirement: Silent tips and radio cards
The opening tip card SHALL be silent: the squad channel is held quiet while it shows and the music carries the moment. A radio slot SHALL play a recorded bank line on the comms dock with its normal portrait and subtitle, chosen by event and emotion: the next-mission briefing, banter, a joke or a brood taunt. It SHALL present the squad channel's own transition line when one is on air, and otherwise play one bank line only while the channel is free.

#### Scenario: Silent tip
- **WHEN** the opening tip card is up
- **THEN** the squad voice is held quiet until the card ends or it is skipped, and the player's speech setting is restored afterwards

#### Scenario: Radio card on travel
- **WHEN** a radio slot opens and the squad channel sends the next-mission briefing
- **THEN** the dock shows that briefing and no second line plays over it

### Requirement: Readable, skippable, fluid cards
A radio slot SHALL be planned so that its clip and hold fit inside the pursuit, which MAY lengthen by up to 2 seconds for it, and SHALL never start within 0.5 seconds of the sector swap. A tap, Space or Enter SHALL NOT cut a radio line: it finishes on the dock. The opening tip card SHALL be at most 460 px wide inside the cabinet and full width less a 12 px gutter on phones, without overflow at 390, 900 and 1440 px.

#### Scenario: Readable card
- **WHEN** a slot is planned for a pursuit
- **THEN** its clip plus hold (or its reading time, 1.2 s plus 4 words per second) fits the pursuit

#### Scenario: Skip
- **WHEN** the player taps or presses Space or Enter during a transition
- **THEN** the radio line finishes on the dock, and the ship begins its descent on the next frame

### Requirement: Planetary parallax
Each of the five levels SHALL have a distinct original pixel-art environment with terrain, planets, moons and satellites. Background complexity and visible demon infrastructure SHALL grow toward the carrier and on later cycles, with relative layer motion and smooth transitions that preserve threat readability.

#### Scenario: Advance level
- **WHEN** the game advances to another sector
- **THEN** the environment changes in terrain and celestial composition rather than only hue

#### Scenario: Territory story
- **WHEN** the player travels toward the carrier or begins a harder cycle
- **THEN** radio chatter on the comms dock and environmental occupation details communicate the deeper threat, with no floating captions or storyboard interludes

#### Scenario: Slums and docks
- **WHEN** Krybor Slums and Krybor Docks are viewed at phone size without their destination labels
- **THEN** dense irregular habitation distinguishes the Slums from docking gantries, berths and cargo structures at the Docks while the firing lane stays readable
