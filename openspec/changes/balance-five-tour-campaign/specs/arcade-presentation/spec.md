## MODIFIED Requirements

### Requirement: Illustrated gameplay instruction
Gameplay hints SHALL pair one brief actionable sentence with one original pixel illustration and equivalent semantics. Hints SHALL advance automatically during loading without guide, Hold, Menu or manual-advance controls. Normal pause SHALL freeze the card. Advice SHALL describe actual game rules without promising protection the simulation does not grant.

#### Scenario: One tactic at a glance
- **WHEN** an illustrated hint is shown at phone size
- **THEN** one recommended action is legible in both the sentence and picture without clipping or unrelated decorative detail

#### Scenario: Automatic loading hint
- **WHEN** a sector begins
- **THEN** one complete illustrated hint appears during loading and disappears automatically before the initial swarm flies in

#### Scenario: Accurate shield advice
- **WHEN** a hint explains shield renewal
- **THEN** it associates the grace period with absorbing a hit and never claims that unused shield expiry grants invulnerability

### Requirement: Original pixel artwork
Creatures, player, boss, fire, smoke, explosions, warnings, pickups and controller artwork SHALL use original Atari-era-inspired pixel art on fixed low-resolution grids, bounded palettes and nearest-neighbor sampling. Original-game sprites/screenshots SHALL NOT be copied or traced. Creatures and effects SHALL use discrete pixel frames, including runtime-generated art; smooth vector silhouettes, antialiased curves, gradients and continuously deforming flames SHALL NOT replace those frames.

#### Scenario: Creature flight
- **WHEN** a demon is active
- **THEN** its wings animate and its damage state remains visually readable

#### Scenario: Enlarged rare creature
- **WHEN** a large creature is drawn larger than an ordinary demon
- **THEN** its outline, segmented wings and damage forms retain visible logical pixels and discrete animation poses without smooth vector edges

#### Scenario: Articulated heavy flight and subtle tell
- **WHEN** a sentinel hovers or prepares its attack
- **THEN** its wide wings articulate through eight distinct slow pixel poses and its own small pose change supplies the warning without an oversized detached marker

#### Scenario: Carrier damage and attack warning
- **WHEN** carrier fire or a rare creature's dive warning is visible
- **THEN** the effect uses original bounded-palette pixel frames, and the warning is a creature-associated sprite cue rather than an arrow

### Requirement: Planetary parallax
Each of the five sectors SHALL retain its distinct original pixel-art theme, terrain, planets, moons and satellites. Each of five campaign routes SHALL have a distinct named variant of every sector with recognizable location-specific scenery, not only a changed name, tint or decoration count. Independently moving background layers and occupation details SHALL increase in complexity toward the base and on later routes, with smooth transitions and readable threats.

#### Scenario: Advance level
- **WHEN** the game advances to another sector
- **THEN** terrain and celestial composition change rather than only hue

#### Scenario: Territory story
- **WHEN** the player revisits a sector on a later route
- **THEN** its name, layered scenery and captions communicate a different location and a deeper threat

#### Scenario: Slums and docks
- **WHEN** Krybor Slums and Krybor Docks are viewed at phone size without their destination labels
- **THEN** dense irregular habitation distinguishes the Slums from docking gantries, berths and cargo structures at the Docks while the firing lane stays readable

### Requirement: Arcade screens
The app SHALL provide title, play, pause, victory, campaign-complete and game-over screens, inline unlocked-mode Top10 tabs, three-wheel score entry, a score/lives/destination/wave HUD, and a futuristic pixel controller panel. Destinations SHALL replace numeric level/cycle headings. Lives SHALL remain readable above three.

#### Scenario: Start
- **WHEN** a visitor starts a game
- **THEN** play shows five lives in Easy or three in Normal/Hard and automatic fire starts during combat

#### Scenario: Landing scores
- **WHEN** the landing page loads
- **THEN** Top10 appears without a separate scoreboard action and locked difficulty tabs are hidden

### Requirement: Layered power status glyph
The controller panel SHALL show a single composite pixel glyph with distinct Spread side cannons, Rapid central lightning, Powerful central heavy cannon, Large side explosive shells and enclosing Shield. Each active effect SHALL show its own name, countdown and duration bar. Only one effect per offensive group SHALL appear. Removing an effect SHALL remove only its glyph layer and timer. Status SHALL not block piloting or displace the controller guidance label as effects change. The standalone multi-fire glyph SHALL resemble twin cannons rather than crosses.

#### Scenario: Triple combination
- **WHEN** all three modifiers are active
- **THEN** all glyph layers and independent countdowns remain visible without shifting controller guidance

#### Scenario: One effect ends
- **WHEN** shield is consumed or an effect expires
- **THEN** remaining layers stay visible, guidance stays aligned and touch piloting continues

## ADDED Requirements

### Requirement: Readable story interludes
Story captions SHALL use substantially larger text and more arena area than the initial campaign captions, a larger travel bar and approximately one third of a second of extra reading time per text-bearing phase. Travel, carrier falls, recognition, departures and the ending SHALL tell a continuous story matching every route's names and scenery. Complete messages SHALL remain visible without clipping on narrow phones and landscape.

#### Scenario: Phone interlude
- **WHEN** travel is shown on a 390-pixel-wide phone
- **THEN** its destination, story message and progress bar are legible without clipping

### Requirement: Boss visual damage
Boss shield and belly geometry SHALL be symmetric around the sliding door at every viewport size. A full shield SHALL be wider and visibly deplete as damaged. Boss shield/core health bars SHALL be removed. Increasing core damage SHALL produce escalating original pixel-frame smoke, sparks and flames, followed by a falling-wreck cinematic on defeat. Fire SHALL share the combat sprites' hard-edged logical pixel grid and bounded palette, without smooth vector flames or continuous shape deformation.

#### Scenario: Damaged carrier
- **WHEN** the shield and then core take damage
- **THEN** the shield visibly recedes and hull effects intensify without health bars

### Requirement: Difficulty medal artwork
Every mode SHALL have five distinguishable medal awards and matching empty silhouettes. Easy medals SHALL be simpler than Normal and Hard medals more elaborate than Normal. Reward scenes and Top10 SHALL use the same medal designs.

#### Scenario: Partial achievement
- **WHEN** a Normal player has defeated three bosses
- **THEN** the score row shows its three Normal medals and two empty medal silhouettes

### Requirement: Distinct sacrifice tell
An injured sentinel's last-stand tell SHALL combine a subtle distinct pixel pose on the creature itself with a small preparatory movement for its full 0.9-second warning interval. It SHALL remain distinguishable from ordinary dive warnings through shape and motion, not color alone. The rush and self-destruction SHALL retain the original pixel-frame style and SHALL NOT imply a return to formation or a player-earned reward.

#### Scenario: Recognize the last stand
- **WHEN** a sentinel commits to its sacrifice attack
- **THEN** its special pose and preparatory movement signal the rush before it accelerates, giving the player time to move away from the sampled aim point

### Requirement: Articulated sentinel and readable effects
Sentinel wings SHALL use eight articulated pixel poses across a slow 3.2-second stroke, with separate normal warning, falcon-like dive and last-stand poses. Tells SHALL remain confined to the creature, without arrows or oversized detached markers. Sentinel defenses and faster bullets SHALL be visibly distinct. Carrier rage eyes, stepped smoke and reduced-opacity explosions SHALL communicate damage while keeping threats readable.

#### Scenario: Damaged crowded encounter
- **WHEN** sentinel bullets, damaged carrier smoke and explosions overlap
- **THEN** the different projectile shapes remain identifiable through restrained translucent effects and the sentinel's own pose provides its warning

### Requirement: Extended power glyph combinations
Every legal offensive pair plus Shield SHALL retain distinguishable original pixel glyph layers and independent timers. Powerful SHALL use a chunky red central cannon or double-shell mark; Large SHALL use amber explosive shell heads at the sides. Replacement SHALL remove only the replaced group's glyph and timer while preserving controller touch input.

#### Scenario: Powerful explosive shield
- **WHEN** Powerful, Large and Shield are active
- **THEN** red central cannon, amber side shells and violet shield remain visible, with three independent countdowns and working drag controls

### Requirement: Contextual arrival hints
First-wave arrivals SHALL replace repeated arrival story text with a randomly selected eligible five-to-nine-word gameplay hint and one matching pixel illustration. A shuffled bag SHALL avoid repeating eligible hints until exhausted, including across bag boundaries when alternatives exist. Selection SHALL occur once per entrance and stay stable through rebuilds and pause. Travel SHALL retain destination storytelling.

#### Scenario: Relevant encounter advice
- **WHEN** a Hard run is on its first route
- **THEN** arrival hints exclude heart collection and sentinel tactics while retaining applicable movement, power or carrier advice

#### Scenario: Stable shuffled selection
- **WHEN** an arrival card rebuilds or the player pauses and resumes
- **THEN** the selected hint remains unchanged and its card is not counted as a new draw
