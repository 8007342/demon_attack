# arcade-presentation updates

## MODIFIED Requirements

### Requirement: Illustrated gameplay instruction
Gameplay hints SHALL pair one brief actionable sentence with one original pixel illustration and equivalent semantics. Hints SHALL appear as silent tip interludes on level and mission transitions (the run's opening card is always one) and SHALL advance automatically without guide, Hold or Menu controls; a tap, Space or Enter MAY skip a card early. Normal pause SHALL hold the card and resume it where it was. Advice SHALL describe actual game rules without promising protection the simulation does not grant.

#### Scenario: One tactic at a glance
- **WHEN** an illustrated hint is shown at phone size
- **THEN** one recommended action is legible in both the sentence and picture without clipping or unrelated decorative detail

#### Scenario: Automatic loading hint
- **WHEN** a new run begins, or a sector transition's interlude is a tip
- **THEN** one illustrated hint appears during the transition and disappears automatically by the time the swarm engages

#### Scenario: Accurate shield advice
- **WHEN** a hint explains shield renewal
- **THEN** it associates the grace period with absorbing a hit and never claims that unused shield expiry grants invulnerability

## ADDED Requirements

### Requirement: One primary transition message
During any transition the play area SHALL show at most one primary message: an interlude card, a story card (sector secured, carrier victory, jump into a new route) or the carrier arrival alert. On phones the radio dock SHALL hide while an interlude card is up. The story cards SHALL keep their storyboard, the next leg's briefing, the medal and life reward and the tour escalation.

#### Scenario: Sector change
- **WHEN** a sector is cleared and the run travels to the next
- **THEN** at every moment at most one of the story card or the interlude card is shown

#### Scenario: Story beats kept
- **WHEN** a sector is secured, a carrier falls or the run jumps into a new route
- **THEN** the story card shows its storyboard and the next leg's briefing, the medal and life reward, or the tour escalation respectively

### Requirement: Slim transition progress
Transition progress SHALL be one slim strip at the top of the arena naming the sector and wave (or the salvage window), with sector pips and one hairline of phase progress, in place of per-card progress bars. A wave change within a sector SHALL show only the strip.

#### Scenario: Wave change
- **WHEN** a new wave begins inside a sector
- **THEN** no card appears; the strip shows the wave number for the length of the wave entrance

#### Scenario: Travel
- **WHEN** the run travels between sectors
- **THEN** the strip names the destination and the share of the jump completed

### Requirement: Alternating transition interludes
Level and mission transitions SHALL present one interlude card centred in the play area, spanning the travel leg and the arrival after it, or the arrival alone at the opening, on resume and on a new route. After an opening tip, cards SHALL alternate between a silent tip and a radio card. The choice SHALL be seeded and SHALL never show the same item twice in a row.

#### Scenario: Alternation
- **WHEN** a run passes several sector transitions
- **THEN** the cards go tip, radio, tip, radio… and no item repeats back to back; the same seed gives the same sequence

### Requirement: Silent tips and radio cards
A silent tip SHALL show an illustrated tip over a staged game scene with no voice: the squad channel is held quiet and the music carries the moment. A radio card SHALL be a full-size transmission (portrait, speaker, subtitle) of a recorded bank line, chosen by event and emotion: the next-mission briefing, banter, a joke or a brood taunt. It SHALL present the squad channel's own transition line when one is on air, and otherwise play one bank line only while the channel is free.

#### Scenario: Silent tip
- **WHEN** a tip card is up
- **THEN** the squad voice is held quiet until the card's window ends or it is skipped, and the player's speech setting is restored afterwards

#### Scenario: Radio card on travel
- **WHEN** a radio card's window opens and the squad channel sends the next-mission briefing
- **THEN** the card shows that briefing and no second line plays over it

### Requirement: Readable, skippable, fluid cards
An interlude card SHALL be planned only when its text, and for radio its clip and hold, can be read inside its window. Cards SHALL fade in and out over one musical beat, SHALL be skippable by tap, Space or Enter, and SHALL never lengthen a transition. Cards SHALL be at most 460 px wide inside the cabinet and full width less a 12 px gutter on phones, without overflow at 390, 900 and 1440 px.

#### Scenario: Readable card
- **WHEN** a card is planned for a window
- **THEN** its reading time (1.2 s plus 4 words per second) or its clip plus hold fits the window, and a tip shows its detail sentence only when that still fits

#### Scenario: Skip
- **WHEN** the player taps the card or presses Space or Enter
- **THEN** the card closes for the rest of the window; during an arrival the fight starts, during travel the jump continues unchanged
