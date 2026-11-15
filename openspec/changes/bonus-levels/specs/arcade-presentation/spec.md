# Arcade presentation

## ADDED Requirements

### Requirement: Bonus levels enter and leave through the fog
A bonus level SHALL be reached and left by the ordinary sector transition: the rout, the pursuit into the cloud and the descent. It SHALL be announced by radio: its urgent-mission card on the comms dock, which is a radio comm and the one card a sector transition may show; no other card, title, caption, banner or floating text SHALL announce it, its award or a run modifier. The skip, the pickup grace, the reduced-motion plan and the transition's length rules SHALL be those of a regular sector.

#### Scenario: Flying in
- **WHEN** the next sector of the run is its bonus level
- **THEN** the ship climbs into the cloud as for any sector change, the radio slot opens the bonus level's urgent-mission card with its entry call, and no floating text is drawn over the play area

#### Scenario: Flying out
- **WHEN** the bonus level's last creature falls
- **THEN** the rout, pursuit and descent into the next regular sector play as usual

### Requirement: Urgent-mission card
The transition into a bonus level SHALL show an "URGENT MISSION!" radio card heading the comms dock in its toast style, with an alert frame, the current speaker's portrait, the level's name, its rule in one or two lines, the run modifier in play and the scripted chatter as it is spoken. The card SHALL end above the ship row at every screen size and SHALL leave its turns out of the dock while it is up.

#### Scenario: Phone
- **WHEN** a 360 × 780 phone flies into the Supply Run
- **THEN** the card shows "URGENT MISSION!", "SUPPLY RUN", "Crack the falling crates…" and the chatter, compactly, and its bottom edge stays above the ship row

#### Scenario: Short screen
- **WHEN** the arena leaves little room above the ship (a phone held sideways)
- **THEN** the card keeps only the newest turns and a smaller portrait, and still ends above the ship row

### Requirement: The card goes before the fight
The urgent-mission card SHALL close when its chatter has been read, when the player dismisses it, or at the latest a little over a second into the bonus level's first combat. A tap on the card SHALL dismiss it without skipping the transition; Space or Enter SHALL dismiss it when there is no transition left to skip. Closing SHALL never cut a line on air: it finishes on the dock, and the rest of the script is dropped.

#### Scenario: Dismissed
- **WHEN** the player taps the card while its first line plays
- **THEN** the card closes, the transition continues, that line finishes on the dock and the dare and retort never play

#### Scenario: The fight begins
- **WHEN** the level's first wave has been in combat for 1.2 s
- **THEN** the card is gone

### Requirement: The card with reduced motion
With reduced motion the urgent-mission card SHALL appear and go without fading, glowing or animating its portrait.

#### Scenario: Reduced motion
- **WHEN** reduced motion is enabled
- **THEN** the card is fully shown on its first frame and gone on the frame it closes

### Requirement: Bonus level look
A bonus level SHALL keep the replaced sector's backdrop, ground and creatures and MAY grade them with a colour wash, a light along the horizon and haze, defined as data with the level. The grade SHALL change only while the cloud cover is at least 85 %, as a plain crossfade that is the same with reduced motion, and SHALL never make the scene darker than the ungraded sector. It SHALL be drawn under ground units, creatures, the ship, shots and the HUD.

#### Scenario: Hidden change
- **WHEN** the run enters or leaves a bonus level
- **THEN** the grade fades in or out entirely inside the cloud

#### Scenario: Readability
- **WHEN** a graded and an ungraded frame of the same sector are compared
- **THEN** the graded frame is visibly different in colour and at least as bright

### Requirement: Bonus-only powerup badges
A bonus-only powerup SHALL be drawn with a badge from the existing pickup art, recoloured (and optionally doubled) so that it cannot be mistaken for a regular power, on its falling pickup and on its supply crate, whose parachute SHALL carry the same colour. While it is active, its badge SHALL ride beside the ship inside a ring that runs down with its timer and blinks in its last two seconds; no text SHALL label it over the play area.

#### Scenario: Falling bonus powerup
- **WHEN** a crate with a bonus-only powerup is shot open
- **THEN** a recoloured badge with a pulsing halo falls from it

#### Scenario: Active bonus powerup
- **WHEN** the ship holds a bonus-only powerup
- **THEN** its badge and countdown ring follow the ship until it runs out
