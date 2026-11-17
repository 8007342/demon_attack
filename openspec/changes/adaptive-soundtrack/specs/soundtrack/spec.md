# Soundtrack

## ADDED Requirements

### Requirement: One run as one continuous song
From the menu to the credits the recorded score SHALL never stop or restart between scenes. Every change of music SHALL start on a bar line of the music already playing, or pass through a written bridge. Each route SHALL build through its four sector songs to its carrier song, and the fifth carrier SHALL be the climax of the run.

#### Scenario: Sector to sector
- **WHEN** a sector is cleared and the fleet travels to the next world
- **THEN** the clear plays, a bridge pivots to the next world's key, and the next world's arrival starts on the bridge's last bar line, with no silence between them

#### Scenario: Into the carrier
- **WHEN** The Hollow is cleared and the carrier level starts
- **THEN** the bridge resolves from C minor to F minor and the carrier song's arrival starts on its bar line

### Requirement: Carrier fight section graph
The carrier song SHALL have an approach, one hatch section per upper tier, a transformation bridge, a core, a collapse and a victory. The structured carrier events SHALL move it between them on the carrier's own grid, and the game SHALL never wait for the music.

#### Scenario: A hatch tier falls
- **WHEN** `bossHatchTier` reports tier 2 during hatch section 1
- **THEN** hatch section 2 starts on the next bar line, at its own start

#### Scenario: The transformation
- **WHEN** `bossTransform` with stage start arrives
- **THEN** the 3-bar bridge starts on the next bar line and the core follows its last bar, at most one bar after `bossCoreExposed`

#### Scenario: Two tiers in quick succession
- **WHEN** two `bossHatchTier` events arrive within two bars
- **THEN** only the later tier's section plays, on a bar line

#### Scenario: The collapse and victory
- **WHEN** `bossCollapseStart` arrives during the core
- **THEN** the collapse starts on the next beat, and the victory follows on the next bar line after `bossCollapseEnd`

### Requirement: Intensity without restarting
Within a section, intensity changes SHALL switch to a variant with the same bars at the same position, or add a layer, on the next bar line. A tier change SHALL never restart the section.

#### Scenario: Peril rises in a sector
- **WHEN** `musicIntensity` rises from 2 to 3 in section B
- **THEN** B's peril variant continues from the same bar and beat on the next bar line

### Requirement: Ending handoff to ukulele
After the fifth carrier's victory the score SHALL resolve to F major, carry over the cut into the ending as a worldized small-speaker sound, and hand over to ukulele bars of the campaign theme in F major at 95 BPM, half the carrier tempo.

#### Scenario: Last carrier falls
- **WHEN** the fifth carrier's collapse ends and the cinematic starts
- **THEN** the finale continues band-limited and mono over the first two shots, and the ukulele theme enters on the half-time grid from the third shot

### Requirement: Bounded section playback on the web
Music sections SHALL ship as Ogg Opus at 48 kHz, each a whole number of bars and mastered to -19 LUFS with true peak at most -1.5 dBTP. The player SHALL decode only the current song's reachable sections, within 48 MB of decoded audio, and SHALL keep looping the current section when a requested one is not ready.

#### Scenario: A slow phone
- **WHEN** the next hatch section has not finished decoding at the requested bar
- **THEN** the current section keeps looping and the move happens on the first bar line after the decode

#### Scenario: Memory cap
- **WHEN** a song's sections would exceed 48 MB decoded
- **THEN** unreachable sections are evicted first, and the current section and its neighbours are kept

### Requirement: Screened music picks
Every shipped section SHALL come from a committed recipe (song map, prompt, seed, workflow and overrides) and pass the automatic gates before listening: tempo within 0.6 % of its grid, its key among the top three estimates, whole bars, and a loop wrap without a step or spectral jump. Each pick SHALL be logged with its reason.

#### Scenario: A drifting take
- **WHEN** a generated take measures 1 % off the grid's tempo
- **THEN** it is rejected before cutting, with the measured tempo as the reason

#### Scenario: A pick
- **WHEN** a section's take is picked
- **THEN** its recipe, measurements and reason appear in the render-run ledger, and only its encoded section is committed
