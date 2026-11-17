# Credits

## ADDED Requirements

### Requirement: Still, readable credits
The credits SHALL never scroll by themselves, from the title's CREDITS or after the ending. The reader SHALL scroll them by touch, wheel, scrollbar or keyboard, and Escape SHALL close them. The page SHALL fit phone portrait and desktop widths without horizontal scrolling.

#### Scenario: Nothing moves on its own
- **WHEN** the credits have been open for 10 seconds, with or without reduced motion
- **THEN** the scroll position has not changed and no pause or resume control is shown

#### Scenario: Reading by hand
- **WHEN** the reader drags the credits, presses Page Down, or presses Home
- **THEN** the credits scroll down, further down, and back to the top

### Requirement: Built-on cards and source link
Near the top, after the creator line, the credits SHALL show cards for Tillandsias, Fedora and Podman, each with an icon, a line on its role and a link to its website, then a link to the source repository. A project's own logo SHALL appear only where its published rules allow it; otherwise a neutral glyph.

#### Scenario: Cards on a phone
- **WHEN** the credits open at 360 × 780
- **THEN** the Tillandsias, Fedora and Podman cards, each with its icon and host (tillandsias.org, fedoraproject.org, podman.io), end within the first screen

#### Scenario: Source link
- **WHEN** the credits open at 1280 × 800
- **THEN** a button "Source code · github.com/8007342/demon_attack" opening https://github.com/8007342/demon_attack is in the first screen, followed by a not-affiliated note for Fedora and Podman

#### Scenario: Logos
- **WHEN** the cards render
- **THEN** Tillandsias shows its own icon and Fedora and Podman show neutral glyphs that imitate neither mark

### Requirement: Complete, generated credits
`tools/generate_credits.lua` SHALL generate every credit into `assets/credits.json`, and the page SHALL render every row: the models used in production, every signed third-party licence, the CC0 sample libraries (marked coming until the bank ships), the open-source projects in groups, the SDKs and the Dart packages. Rows SHALL link to their pages.

#### Scenario: Every row renders
- **WHEN** the credits open
- **THEN** every entry of every section of `assets/credits.json` appears by name, and "Built with Meta Llama 3 · Meta Llama 3 is licensed under the Meta Llama 3 Community License, Copyright © Meta Platforms, Inc. All Rights Reserved." and "Demucs, Alexandre Défossez" appear verbatim

#### Scenario: A licence is signed
- **WHEN** a new acknowledgement lands in `licences/acknowledgements/` and the generator runs
- **THEN** the credits list its licence, linked to its text in the repository

### Requirement: Credits song
The title's CREDITS SHALL play their own slow, loopable song, a reprise of the campaign theme, through the score player at the music level setting. It SHALL start on the title music's next bar line and give way to the title music on its own next bar line when the credits close.

#### Scenario: Opening the credits from the title
- **WHEN** the overture is playing and the player opens CREDITS
- **THEN** `credits:dawn` (G major, 72 BPM, 4 bars) starts on the overture's next bar line and opens into the 16-bar `drift` loop

#### Scenario: Closing the credits
- **WHEN** the player closes the credits
- **THEN** the overture returns on the credits song's next bar line, without a restart or a click

#### Scenario: Whole bars
- **WHEN** `lua tools/score/score_gen.lua --check` runs
- **THEN** the credits sections pass the score gates: whole bars, on the grid, at most 32 voices, nothing out of key
