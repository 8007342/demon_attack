# Soundtrack

## ADDED Requirements

### Requirement: One run as one continuous song
From the menu to the credits the score SHALL never stop or restart between scenes. Every change of music SHALL start on a bar line of the music already playing, or pass through a written bridge. Each route SHALL build through its four sector songs to its carrier song, and the fifth carrier SHALL be the climax of the run.

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
Within a section, intensity changes SHALL change which score tracks play (the section's mask for the tier), or switch to a variant with the same bars at the same position, on the next bar line. A tier change SHALL never restart the section.

#### Scenario: Peril rises in a sector
- **WHEN** `musicIntensity` rises from 2 to 3 in section B
- **THEN** B's tier-3 tracks (double kick, harmony lead, pads) join on the next bar line, and the section continues from the same bar and beat

#### Scenario: Peril falls
- **WHEN** `musicIntensity` falls from 4 to 1
- **THEN** the tracks outside the tier-1 mask fade out over at most 60 ms at the next bar line, and drums, bass and rhythm guitars continue unbroken

### Requirement: Ending handoff to ukulele
After the fifth carrier's victory the score SHALL resolve to F major, carry over the cut into the ending as a worldized small-speaker sound, and hand over to ukulele bars of the campaign theme in F major at 95 BPM, half the carrier tempo.

#### Scenario: Last carrier falls
- **WHEN** the fifth carrier's collapse ends and the cinematic starts
- **THEN** the finale continues band-limited and mono over the first two shots, and the ukulele theme enters on the half-time grid from the third shot

### Requirement: Bounded section playback on the web
Recorded music (texture beds) SHALL ship as Ogg Opus at 48 kHz, each a whole number of bars and mastered to -19 LUFS with true peak at most -1.5 dBTP. The player SHALL hold the sample bank and only the current song's reachable beds within 48 MB of decoded audio, and SHALL keep playing the current section when a requested one is not ready.

#### Scenario: A slow phone
- **WHEN** the next hatch section has not finished decoding at the requested bar
- **THEN** the current section keeps looping and the move happens on the first bar line after the decode

#### Scenario: Memory cap
- **WHEN** a song's sections would exceed 48 MB decoded
- **THEN** unreachable sections are evicted first, and the current section and its neighbours are kept

### Requirement: Screened music picks
Every shipped recorded section or texture bed SHALL come from a committed recipe (song map, prompt, seed, workflow and overrides) and pass the automatic gates before listening: tempo within 0.6 % of its grid, its key among the top three estimates, whole bars, and a loop wrap without a step or spectral jump. Each pick SHALL be logged with its reason.

#### Scenario: A drifting take
- **WHEN** a generated take measures 1 % off the grid's tempo
- **THEN** it is rejected before cutting, with the measured tempo as the reason

#### Scenario: A pick
- **WHEN** a section's take is picked
- **THEN** its recipe, measurements and reason appear in the render-run ledger, and only its encoded section is committed

### Requirement: Score as the first layer
The soundtrack's backbone SHALL be a committed multitrack MIDI score per section (drums, bass, guitars, leads, pads, stingers) played in the browser by a sampler on the song's grid, moved by the section graph and transition table. Recorded audio SHALL only add texture beds of parts the score does not play. No part of a section SHALL ship both as score and as recorded audio.

#### Scenario: A section plays
- **WHEN** the carrier song enters `H1`
- **THEN** the `H1` score's tracks for the current tier play through the sampled bank, starting on the bar line

#### Scenario: A bed that duplicates the score
- **WHEN** a candidate texture bed contains a drum kit or a bass line
- **THEN** the bed gate rejects it before listening, with its percussive share or low-band energy as the reason

#### Scenario: A score replaces a recording
- **WHEN** a section's score is approved
- **THEN** any recorded full mix of that section is removed from the shipped assets, and its recipe stays committed

### Requirement: Sampled instrument bank
The score SHALL be voiced by one bank of CC0 or similarly permissive samples, shipped as Ogg Opus with a manifest of zones, sizes, hashes, sources and licences, within 2 MB compressed and 41 MB decoded (16 MB on phones). The bank SHALL load by priority, core drums, bass and guitar first, and the score SHALL start before the bank has finished loading. A section's track with a note outside the bank's zones SHALL play through the synthesizer voice for that whole section.

#### Scenario: A partly covered track
- **WHEN** a section's brass track has a note above the bank's highest horn zone
- **THEN** that track plays through the synthesizer voice for the whole section, and the score gate reports the role's coverage instead of failing

#### Scenario: Cold start
- **WHEN** the music starts and only the core group has decoded
- **THEN** notes of decoded zones play sampled, other notes play through the oscillator voice, and they switch to samples as their groups decode

#### Scenario: Phone tier
- **WHEN** the device is classed as a phone
- **THEN** the bank loads one velocity layer and one round-robin per zone and stays within 16 MB decoded

#### Scenario: A source that is not the pin
- **WHEN** a source file's size or git blob sha1 differs from the pin manifest
- **THEN** the bank builder refuses, names the file, and writes no bank

#### Scenario: No bank
- **WHEN** `bank.json` is absent
- **THEN** the score plays through the synthesizer voices exactly as without a sampler, and the section trims stay byte-identical

### Requirement: Score voice budget
The sampler SHALL cap simultaneous voices at 48 on desktop and 32 on phones. When the cap is reached it SHALL steal pad voices first, then lead voices, and SHALL never steal kick, snare or bass voices. Every shipped score section SHALL peak at most 32 voices with a 0.5-beat release.

#### Scenario: Dense climax on a phone
- **WHEN** the core section at tier 4 asks for a 33rd voice on a phone
- **THEN** the oldest pad voice is released and the kick, snare and bass continue

#### Scenario: Gate
- **WHEN** a score section peaks at 36 voices with a 0.5-beat release
- **THEN** the score gate rejects it with the peak and the bar where it occurs

### Requirement: Score recipes and gates
Every shipped score SHALL be reproducible from a committed recipe (generator, inputs, seed, and for transcribed or model-generated material the source take or model, tool versions and manual edits) and SHALL pass the score gates: whole bars, onsets on the grid within 12 ms, out-of-scale notes at most 3 % outside marked chromatic passages, and pitches inside the bank's zones for the roles it covers in full.

#### Scenario: An off-grid transcription
- **WHEN** a transcribed bass motif has onsets 30 ms off the 16th grid
- **THEN** cleanup snaps them to the grid before the motif reaches the generator, and the gate passes only the snapped score

#### Scenario: Model output
- **WHEN** generated bars from a symbolic model are absorbed into a score
- **THEN** the recipe names the model, its licence, the prompt or prime, the seed, and which bars were kept

### Requirement: The score is the only music
Every scene SHALL play the score: the overture, the four world songs with a Stormfront storm section each, one carrier song per tour with a hatch section per upper tier, the bridges between songs, the defeat and the coda. A pure-Dart director SHALL move it from the game's cues and structured events. No recorded music cue, MIDI fallback cue or score switch SHALL ship.

#### Scenario: A full campaign trace
- **WHEN** a five-route campaign's events drive the director
- **THEN** the songs play menu, menu-k, then per route k, k-r, r, r-e, e, e-h, h, h-c and the tour's carrier (c-k between routes), then the coda, each move on a bar line of the music playing before it (the collapse and the clear on a beat line, the defeat at once)

#### Scenario: Every hatch tier native
- **WHEN** tour 5's carrier reports upper tiers 1 to 4
- **THEN** sections H1 to H4 play, one per tier, with no depth folding

#### Scenario: Stormfront
- **WHEN** a sector is the Stormfront bonus level
- **THEN** the world's half-time storm section in its own key plays from the arrival's end until the clear

#### Scenario: Nothing recorded
- **WHEN** the game plays a whole run
- **THEN** it fetches only web/audio/score/, and web/audio/music/ and web/audio/midi/ do not exist

### Requirement: Score listening aid
The console SHALL offer a panel that drives the live score player through the same director and event names as the game, with a FULL RUN tour, a scripted carrier fight per tour, a scripted sector song per world, a button per song, section move and stinger, and the overture, defeat and coda.

#### Scenario: Full run
- **WHEN** the operator presses FULL RUN
- **THEN** the overture, route 1's four worlds with their bridges and a storm, the first carrier, the bridge into route 2, and the last carrier into the coda play from scripted game events

#### Scenario: Scripted fight
- **WHEN** the operator presses CARRIER FIGHT
- **THEN** the carrier song plays arrival, approach, the hatch tiers, the transformation, the core, the collapse and the victory from the fight's events, each move on a bar or beat line
