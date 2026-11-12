## ADDED Requirements

### Requirement: Continuous campaign metal score
The game SHALL present an original long-form Battle Metal score connecting five levels, their intros/outros and boss phases through compatible musical phrases. Extended sections and alternate arrangements SHALL conceal repetition during ordinary play. Waves and special attacks SHALL influence synchronized layers or accents without restarting the underlying score. Wordless vocals MAY be used.

#### Scenario: Variable-duration campaign
- **WHEN** a player advances across all five levels at a variable pace
- **THEN** themes develop from a permitted slow opening toward the final boss crescendo, level bridges remain fluid, and repeated gameplay events vary the musical arrangement

### Requirement: Paired compact radio exchanges
Compact layouts SHALL show isolated messages as half-width toasts, allowing up to two independent messages at once. A linked human-to-demon or demon-to-human exchange SHALL use a single full-width toast, with the opening portrait on the left, the reply portrait on the right, both texts and the demon script with translation. It SHALL retain the opening line through the comeback without hiding the score, lives or touch controls.

#### Scenario: Phone comeback
- **WHEN** a human or demon answers another caller on a 360px-wide phone
- **THEN** both lines remain visible together, the right portrait appears on the right, and HUD and controls remain usable

### Requirement: Expressive playful radio and original alien script
Human comms SHALL use expressive performances with light radio processing. Demons SHALL receive regular airtime, distinct original transformed performances and a consistent original written alphabet revealed progressively with a slightly delayed readable translation. Cross-faction teasing SHALL remain playful. Mouths SHALL remain aligned to the face and follow the final voice timing.

#### Scenario: Demon taunt and human response
- **WHEN** a demon initiates an exchange
- **THEN** its writing develops with the voice, the translation follows slightly behind, and the human comeback preserves the playful battle fiction

### Requirement: Beach reveal and credits
After completion of all five levels, the game SHALL offer a brief cinematic revealing teenage humans and teenage demons playing DemonAttack as a board game at a San Diego beach, sharing burgers, fries and sodas, followed by verified credits. Earlier clues SHALL remain subtle and scattered among battle chatter. The sequence SHALL support skipping and reduced motion without losing progression or score entry.

#### Scenario: Final victory
- **WHEN** the player defeats the fifth level
- **THEN** the score resolves into the beach reveal and credits, and skipping preserves victory progression and score submission

### Requirement: Modern compressed PWA media
All runtime campaign media SHALL be served as PWA assets on the application's own origin. Recorded music and speech SHALL use high-quality compressed Opus delivery targeting current browsers; older-browser AAC fallback is not required. Lossless production masters SHALL remain separate from the deployed assets. Loading and caching SHALL bound decoded audio memory while preserving continuous phrase playback.

#### Scenario: Extended music on a phone
- **WHEN** extended campaign sections are played in the installed PWA
- **THEN** compressed sections load from the application origin, needed upcoming phrases are prepared in time, and the entire lossless campaign is neither downloaded nor decoded into memory
