# Arcade presentation

<!-- Rebased onto the arcade-presentation text after `fluid-transitions` was archived (2026-11-15). The
     interlude requirements that change below came from that change; they now describe slots, not cards. -->

## MODIFIED Requirements

### Requirement: Illustrated gameplay instruction
Gameplay hints SHALL pair one brief actionable sentence with one original pixel illustration and equivalent semantics where an illustration is shown. Illustrated hints SHALL appear during the run's opening arrival and in the pause menu's tips. During later sector transitions a hint SHALL appear as a single caption line at the bottom edge, alternating with a radio line, never both at once. Hints SHALL advance automatically without guide, Hold, Menu or manual-advance controls; a tap, Space or Enter MAY skip the opening card early. Normal pause SHALL hold the opening card and resume it where it was. Advice SHALL describe actual game rules without promising protection the simulation does not grant.

#### Scenario: One tactic at a glance
- **WHEN** an illustrated hint is shown at phone size
- **THEN** one recommended action is legible in both the sentence and picture without clipping or unrelated decorative detail

#### Scenario: Automatic loading hint
- **WHEN** a run begins
- **THEN** one complete illustrated hint appears during the opening arrival and disappears automatically before the initial swarm flies in

#### Scenario: Caption between sectors
- **WHEN** a later sector transition carries a tip
- **THEN** the tip shows as one line at the bottom edge for its reading time, with no card and no radio line at the same time

#### Scenario: Tips in the pause menu
- **WHEN** the player opens the pause menu
- **THEN** a tips pane shows the illustrated hints without resuming play

#### Scenario: Accurate shield advice
- **WHEN** a hint explains shield renewal
- **THEN** it associates the grace period with absorbing a hit and never claims that unused shield expiry grants invulnerability

### Requirement: One primary transition message
During any transition the play area SHALL show at most one primary message. In a sector transition that message SHALL be a radio line on the comms dock or a caption line at the bottom edge, plus a brief sector title at the top edge during the descent; no story card, storyboard banner, interlude card or sector pips SHALL appear. The opening arrival MAY show its illustrated tip card, and the carrier arrival MAY show its alert. The medal and extra-life reward SHALL show as a brief flourish beside the ship, and the tour escalation SHALL be carried by the radio line and the caption.

#### Scenario: Sector change
- **WHEN** a sector is cleared and the run travels to the next
- **THEN** at every moment at most one of the radio line or the caption is shown, and no card covers the play area

#### Scenario: Story beats kept
- **WHEN** a sector is secured, a carrier falls or the run jumps into a new route
- **THEN** the next leg's briefing plays as a radio line, the medal and life reward flourish beside the ship, and a new route names its tour in the caption or the radio line

### Requirement: Alternating transition interludes
Level and mission transitions SHALL schedule one message slot during the pursuit: a radio line on the comms dock or a caption line. The run's opening arrival SHALL show an illustrated tip instead. After the opening tip, slots SHALL alternate between a caption tip and a radio line. The choice SHALL be seeded and SHALL never present the same item twice in a row.

#### Scenario: Alternation
- **WHEN** a run passes several sector transitions
- **THEN** the slots go caption, radio, caption, radio… and no item repeats back to back; the same seed gives the same sequence

### Requirement: Silent tips and radio cards
A caption tip SHALL be the hint's sentence alone, with no voice: the squad channel is held quiet while it shows and the music carries the moment. A radio slot SHALL play a recorded bank line on the comms dock with its normal portrait and subtitle, chosen by event and emotion: the next-mission briefing, banter, a joke or a brood taunt. It SHALL present the squad channel's own transition line when one is on air, and otherwise play one bank line only while the channel is free.

#### Scenario: Silent tip
- **WHEN** a caption tip is up
- **THEN** the squad voice is held quiet until its slot ends or it is skipped, and the player's speech setting is restored afterwards

#### Scenario: Radio card on travel
- **WHEN** a radio slot opens and the squad channel sends the next-mission briefing
- **THEN** the dock shows that briefing and no second line plays over it

### Requirement: Readable, skippable, fluid cards
A message slot SHALL be planned only when its text, and for radio its clip and hold, can be read inside the pursuit, which MAY lengthen by up to 2 seconds for it. Captions SHALL fade in and out over 0.5 seconds, sit on one line at an edge of the play area, and SHALL never start within 0.5 seconds of the sector swap. A tap, Space or Enter SHALL end a caption at once; a radio line SHALL finish on the dock. The opening tip card SHALL be at most 460 px wide inside the cabinet and full width less a 12 px gutter on phones, without overflow at 390, 900 and 1440 px.

#### Scenario: Readable card
- **WHEN** a slot is planned for a pursuit
- **THEN** its reading time (1.2 s plus 4 words per second) or its clip plus hold fits the pursuit

#### Scenario: Skip
- **WHEN** the player taps or presses Space or Enter during a transition
- **THEN** the caption closes, the radio line finishes on the dock, and the ship begins its descent on the next frame
