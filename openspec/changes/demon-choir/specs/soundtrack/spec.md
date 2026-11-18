# Soundtrack: the brood choir

## ADDED Requirements

### Requirement: Brood choir bank
The score SHALL have a second sample bank for demon voices, `choir.json`, built by the bank builder from its own recipe. Its `brood` zones SHALL be vowel by velocity times pitch, and its `grunt` and `warcry` zones SHALL be one-shots by syllable and round robin. It SHALL load after the first bank, on desktops only, and only while the bank switch is on.

#### Scenario: The switch is off
- **WHEN** the page loads with the bank off (the default)
- **THEN** nothing under `audio/bank/` is fetched, not `choir.json` either, and the synth score plays note for note as before

#### Scenario: The switch is on, on a desktop
- **WHEN** the bank is on and both `bank.json` and `choir.json` exist
- **THEN** the choir's instruments, roles, zones and sprites join the first bank's, its sprites load after the first bank's, and the decoded budget is the sum of both banks' budgets (41 MB plus 9 MB)

#### Scenario: A phone
- **WHEN** the bank is on and the device is a phone
- **THEN** `choir.json` is not fetched, and the brood, grunt and war-cry notes stay silent

#### Scenario: The vowel axis
- **WHEN** a brood note at velocity 72 and one at velocity 102 play on the same pitch
- **THEN** the first plays the "oh" zone (velocity 1-84) and the second the "ah" zone (85-127) of the nearest root, pitched by playbackRate

### Requirement: Sampled-only voices
The `brood`, `grunt` and `warcry` roles SHALL have no synth voice. Their notes SHALL sound only from decoded zones. Without the bank, or before a note's zone decodes, the note SHALL rest and take no voice from the cap. The score gate SHALL require every note of these roles to have a zone (`cover: full`).

#### Scenario: Zones still decoding
- **WHEN** the bank is on and a grunt note is due before the choir's sprite has decoded
- **THEN** no voice starts for it and no other voice is stolen

#### Scenario: The gate
- **WHEN** `lua tools/midi_stats.lua check` runs on the committed score
- **THEN** every brood and grunt note and every `warcry` stinger note in every key has a zone, or the check fails

### Requirement: Brood choir in the score
The carrier core and at least one world battle section SHALL carry brood tracks. The core SHALL hold root drones on its harmony, "oh" in its first half and "ah" in its second. The battle section SHALL hold drones and a grunt on every downbeat, on the bar's chord root. The tracks SHALL join through the tier masks, and every gate's voice limit SHALL hold.

#### Scenario: Krybor B at tier 4, bank on
- **WHEN** Krybor's B section plays at tier 4 with the bank on
- **THEN** brood drones sound under the band, and a grunt lands on each bar's beat 1 (and beat 3 of bars 4 and 8), pitched from its zone's root to the bar's root

#### Scenario: Voice budget
- **WHEN** the score generator gates the core with the 1UP stinger layered over it
- **THEN** the peak stays at or under 32 voices

### Requirement: War cries as music
A `diveCry` event SHALL play the `warcry` stinger. The stinger SHALL be a war-cry sample on the next 8th of the playing section's grid, pitched to the section's tonic, through the music bus. It SHALL play at most once per 8 beats, never while a radio line holds the speech duck, and only while the bank is on.

#### Scenario: A dive cry in E minor
- **WHEN** `diveCry` fires during Krybor B (E minor) with the bank on
- **THEN** a war cry starts on the next 8th line, its playbackRate taking its zone's root to E3

#### Scenario: Rate limit
- **WHEN** a second `diveCry` fires 3 beats after the first
- **THEN** it plays nothing

#### Scenario: The radio is speaking
- **WHEN** `diveCry` fires while a radio line holds the speech duck
- **THEN** it plays nothing, and the next cry after the line plays

#### Scenario: Bank off
- **WHEN** `diveCry` fires with the bank off
- **THEN** `demonAudio.accent('warcry')` returns null and nothing sounds
