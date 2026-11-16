# arcade-presentation

## Purpose
Present original animated pixel-art worlds and responsive arcade screens with adaptive synthesized music.

## Requirements

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

### Requirement: Stepped 2.5D pixel lighting and banked poses
The renderer SHALL present 2.5D depth using nearest-neighbor stepped directional hemisphere/rim highlights, banked ship transforms (`shipBank`), angled sling-shot bolts, 3-tier diving bow-shock shields (`diveShield`), and open/sealed carrier auxiliary side doors (`sideDoorLeft`, `sideDoorRight`) without smooth GLSL normal-map blur.

#### Scenario: Stepped 2.5D pixel lighting, banked ship poses, and 3-tier dive shields
- **WHEN** the player ship banks, creatures dive with their 3-tier atmospheric shields, or the carrier exposes its center and auxiliary side hatches
- **THEN** volume and shielding render as crisp stepped pixel layers with directional highlights and shadow contrast

#### Scenario: Sling-shooting arrival hint
- **WHEN** the `sling_shot` arrival card is selected during sector loading
- **THEN** it pairs a concise 5–9 word action sentence on strafing to curve shots with an original pixel illustration of banked diagonal shots entering an open hatch

### Requirement: Thermal re-entry plasma fire vs. geometric force shields
Diving creature shields (`diveShield`) SHALL use a strictly thermal blackbody gradient (blinding white stagnation core -> incandescent solar yellow -> superheated ablation orange -> deep crimson/charcoal smoke trail and embers, with zero cyan/violet bands). Technological force shields SHALL use cool geometric cyan/teal/violet hex and segmented pixel barriers.

#### Scenario: Thermal blackbody dive shields vs. cool geometric force shields
- **WHEN** a creature dives with an atmospheric re-entry shield or an entity displays a technological force shield
- **THEN** the re-entry shield renders as a white-yellow-orange-crimson thermal envelope with embers and zero cyan/violet bands, while the force shield renders as a geometric cyan/teal/violet barrier

### Requirement: Multi-part Dreadnought Carrier presentation
The Brood Dreadnought Carrier SHALL render as a `184 × 120` logical pixel multi-part sprite hierarchy across 4 evolution forms (`Carrier`, `Brood Ark`, `Siege Carrier`, `Brood Flagship`) with articulated mandibles, dorsal retro-thrusters, tracking ventral dual-turrets, 3 launch bay shutters, progressive fracture overlays, orbital retro-burn arrival, and sequential meltdown.

#### Scenario: Dreadnought multi-part hierarchy, arrival, and meltdown
- **WHEN** the Brood Dreadnought arrives, fights across its 4 forms, or is defeated
- **THEN** it displays its `184 × 120` multi-part carapace and sub-components, descends with orbital retro-burn and klaxon telemetry, and explodes sequentially from wing pylons to auxiliary bays to central core

### Requirement: Cockpit Control Panel, defeat celebration, and 3-beat opening zoom-out
The bottom panel SHALL render a Stylized Starfighter Cockpit Control Panel combining the Weapon/Shield Telemetry Schematic with a rotating Steering Yoke & Gun Angle Gimbal (`±6°, ±12°, ±18°, ±24°`) for touch and 3D device tilt. New games SHALL open with a 3-beat Cockpit Panel zoom-out; final life loss SHALL show an enemy victory celebration and skyward pan to High Scores.

#### Scenario: Cockpit Control Panel yoke, interim gun angles, and 3-beat opening zoom-out
- **WHEN** a new game starts or the pilot steers via touch drag or calibrated 3D device tilt
- **THEN** the camera pulls back continuously from the igniting Cockpit Control Panel into the live arena without fading to black, and the rotating yoke and gimbal reflect interim shooting angles (`0°, ±6°, ±12°, ±18°, ±24°`)

#### Scenario: Last-life-lost victory celebration and skyward High Score pan
- **WHEN** the player loses their final life
- **THEN** the ship explodes, surviving enemies, Sentinels, or the Dreadnought perform a victory celebration swarm, and the camera pans skyward into the starfield High Scores table

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

### Requirement: Adaptive MIDI soundtrack
A MIDI-event synthesizer SHALL provide distinct level tracks, escalating boss-phase music, a victory fanfare, and transitions aligned to musical phrases with fades. Audio SHALL start only after a user gesture and provide mute and lifecycle pause.

#### Scenario: Boss transforms
- **WHEN** the boss enters a more advanced phase
- **THEN** the score transitions smoothly into more intense boss music without restarting audio abruptly

### Requirement: Layered power status glyph
The controller panel SHALL show a single composite pixel glyph with distinct Spread side cannons, Rapid central lightning, Powerful central heavy cannon, Large side explosive shells and enclosing Shield. Each active effect SHALL show its own name, countdown and duration bar. Only one effect per offensive group SHALL appear. Removing an effect SHALL remove only its glyph layer and timer. Status SHALL not block piloting or displace the controller guidance label as effects change. The standalone multi-fire glyph SHALL resemble twin cannons rather than crosses.

#### Scenario: Triple combination
- **WHEN** all three modifiers are active
- **THEN** all glyph layers and independent countdowns remain visible without shifting controller guidance

#### Scenario: One effect ends
- **WHEN** shield is consumed or an effect expires
- **THEN** remaining layers stay visible, guidance stays aligned and touch piloting continues

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

### Requirement: Swarm perspective depth
Gargoyles and sentinels SHALL be drawn at the simulation's quantised perspective scale, consistent with the flyover camera (see "Scale steps"); the carrier is not scaled. Wave and reinforcement arrivals SHALL set out small and hazed just above the horizon near the vanishing point and grow along a depth-linear approach into formation, staying undrawn until their entrance begins. Divers SHALL grow as they close on the ship. Demons SHALL be drawn far to near (see "Depth cues").

#### Scenario: Formation breathing
- **WHEN** a demon holds its formation slot
- **THEN** it breathes about one size step in phase with its bob

#### Scenario: Scale steps
- **WHEN** a demon has nearness n = z0/z on the flight sheet (0.62 at the top to the ship's 0.876)
- **THEN** an ordinary demon is drawn at `1.8 · n` in 0.1 steps between 0.5 and 1.5 and a sentinel at `n / 0.622` in 1/16 steps between 0.75 and 1.25, changing only in those quantised steps with nearest-neighbour sampling so pixels stay square and stable

#### Scenario: Depth cues
- **WHEN** a frame draws the swarm
- **THEN** demons are drawn far to near, arrivals carry distance haze, and a faint pixel ground shadow lies beneath each demon's depth

#### Scenario: Arrival from the distance
- **WHEN** a new wave enters
- **THEN** its gargoyles appear about 20 units wide and hazed near the horizon and reach their roughly 48-unit formation size as they settle

#### Scenario: Dive at the player
- **WHEN** a gargoyle dives at the ship
- **THEN** it grows to the 60-unit cap, passes in front of the formation and its ground shadow darkens as it closes in

### Requirement: One primary transition message
During any transition the play area SHALL show at most one primary message: an interlude card, a story card (sector secured, carrier victory, jump into a new route) or the carrier arrival alert. On phones the radio dock SHALL hide while an interlude card is up. The story cards SHALL keep their storyboard, the next leg's briefing, the medal and life reward and the tour escalation.

#### Scenario: Sector change
- **WHEN** a sector is cleared and the run travels to the next
- **THEN** at every moment at most one of the story card or the interlude card is shown

#### Scenario: Story beats kept
- **WHEN** a sector is secured, a carrier falls or the run jumps into a new route
- **THEN** the story card shows its storyboard and the next leg's briefing, the medal and life reward, or the tour escalation respectively

<!-- "Slim transition progress" was removed: openspec/changes/ux-declutter forbids progress strips and bars. -->

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

### Requirement: Encasing carrier field
The carrier's force field SHALL keep a width larger than the hull at every remaining strength, showing a symmetric pixelated lower egg outside the ship. Depletion SHALL bring the lower surface and projectile impacts progressively toward the hull rather than narrowing the field. At zero strength the field SHALL disappear and the exposed hatch rules SHALL apply. A matching illustrated hint SHALL explain wearing down the field before attacking the carrier.

#### Scenario: Nearly depleted field
- **WHEN** the carrier retains only a little shield energy
- **THEN** its field still spans the ship but shots hit nearer its underside than at full strength

### Requirement: Same footprint, more detail
Combat creatures SHALL be authored on a 64 × 64 logical grid with a bounded palette, hard edges and discrete frames, and SHALL render at the same arena size as before so hitboxes and readability at phone size are unchanged.

#### Scenario: Creature size
- **WHEN** an ordinary demon is drawn
- **THEN** it occupies 40 × 40 arena units (44 when angry), sampled nearest-neighbour from its 64 × 64 cell

### Requirement: Articulated wing stroke
Ordinary demons SHALL flap through eight distinct poses per 0.5-second stroke in which roots, forearms and fingers articulate separately; sentinels SHALL hold eight poses for 0.4 seconds each, with recovery folding the span below 70 % of full span.

#### Scenario: Recovery folds
- **WHEN** a sentinel reaches its recovery pose
- **THEN** its silhouette is narrower than 70 % of its level pose

### Requirement: Visible equipment
Each species SHALL show armour, a rank insignia and a weapon mount that animates when that creature fires; elites SHALL show authored plates that shed one level per hit.

#### Scenario: Creature fires
- **WHEN** a hostile shot leaves an ordinary demon
- **THEN** the demon plays its weapon-fire frames and a muzzle flash appears at the shot's spawn point

### Requirement: Per-side cannon presentation
The cannon that fired SHALL play its own recoil and muzzle-flash frames while the other rests, and module muzzle anchors SHALL equal the projectile spawn points.

#### Scenario: Alternating wing cannons
- **WHEN** a wing module is fitted and two volleys are fired
- **THEN** the left cannon recoils on the first and the right cannon on the second

### Requirement: Ground units on the flyover camera
Ground units, allies, wrecks and skirmish tracers SHALL be drawn on the flyover ground with its projection, small and subdued at the horizon and full-bright on the near ground, between the background and the air combat. Demon units SHALL use warm threat accents; allies SHALL use cyan/teal friendly accents. Both SHALL be distinguishable from the decorative ground creatures. Retreating allies SHALL show sparks, smoke and limping or an escape pod, never death imagery.

#### Scenario: Approach
- **WHEN** a ground unit approaches from the horizon
- **THEN** it grows and brightens on the ground plane without entering the central lane

### Requirement: Readable missiles and homing
Ground missiles SHALL show their launch flash, a smoke trail, a size that grows toward the ship and a marker where the path crosses the ship's plane. Homing missiles SHALL show a cyan exhaust and a lock-on reticle on their target. The ship SHALL show its loaded homing pylons, including in the transition loadout glyph, and the HUD SHALL show a HOMING row with its remaining missiles.

#### Scenario: Lock-on
- **WHEN** a homing missile is in flight
- **THEN** a reticle marks its current target

### Requirement: Ground war events and hints
Ground-war moments SHALL leave the simulation through one no-op-safe dispatcher with stable names (`groundForceSighted`, `groundForceInRange`, `groundMissileLaunch`, `homingPickup`, `homingLaunch`, `homingHit`, `groundUnitDestroyed`, `allyUnderAttack`, `allySaved`, `allyRetreated`, `fleetIntact`) for music and commander callouts. Arrival hints SHALL teach sidestepping ground missiles and collecting homing missiles after ground forces first appear.

#### Scenario: No listeners
- **WHEN** no music or comms consumer is registered
- **THEN** dispatching events has no effect on play

### Requirement: Endless sector relief
The flyover ground SHALL be an endless heightfield generated deterministically from the sector and route (rolling hills plus ridges, valleys, canyons, mesas, forests, crystal fields and ruins in each sector's identity), drawn as a textured mesh displaced by height, with slope light from the sector's sky and distance fog. The same flight distance SHALL render identically on every device, with no seams at any distance.

#### Scenario: Determinism
- **WHEN** the same sector, route and distance are rendered twice
- **THEN** the relief is identical, and another route gives a different relief

### Requirement: Readable firing lane
Relief SHALL be gentle in the central firing lane and fade out toward the horizon; the lane SHALL stay darker than the banks and below the scenery luminance caps.

#### Scenario: Lane
- **WHEN** any sector is shown with relief
- **THEN** the lane's relief stays under a fifth of the side relief and the lane stays dark

### Requirement: One surface for everything on the ground
Walls, landmarks, props, creatures, vegetation and ground units SHALL stand on the visible surface given by one API (`surfaceAt` / `terrainHeight` / `yOf`), which SHALL match where the ground mesh draws that point.

#### Scenario: Consistency
- **WHEN** the surface is queried at a mesh vertex
- **THEN** it returns that vertex's screen position

### Requirement: Units navigate the relief without rule changes
Ground units SHALL follow valley floors, wind around mesas and ride slopes visually, never entering the central lane. The fire range gate, breakthroughs and collisions SHALL depend only on logical depth, side and band.

#### Scenario: Rules unchanged
- **WHEN** relief displaces a unit on screen
- **THEN** its fire range and breakthrough timing are the same as on flat ground

### Requirement: Vegetation pushed by the ground fleet
Each sector SHALL show its own vegetation and obstacles in the side bands, with multi-frame idle, bend, break and settled animation and burst particles when a ground unit pushes through them.

#### Scenario: Push
- **WHEN** a ground unit's footprint meets a plant
- **THEN** the plant bends and topples (or shatters, flattens, snaps or is shoved) and stays down

### Requirement: Terrain radio events
The presentation SHALL emit rate-limited `terrainAhead` (kind, side), `convoyClimbing`, `convoyClearingVegetation` and `convoyStuck` events through the no-op-safe dispatcher, only in combat.

#### Scenario: Rate limit
- **WHEN** features approach continuously
- **THEN** `terrainAhead` events are at least 12 s apart and repeat a kind at most every 30 s

### Requirement: Crossfades and reduced motion
Travel crossfades SHALL morph one blended relief between sectors. Reduced motion SHALL freeze scrolling, swaying and toppling while keeping the static relief.

#### Scenario: Reduced motion
- **WHEN** reduced motion is on
- **THEN** repeated frames are identical and pushed plants show their settled frame without particles

### Requirement: Urgency signals
The model SHALL expose a ground pressure level (0–1) and emit `groundPressure` when it crosses each tenth. Allies SHALL call for help (`allyUnderAttack`, with a visible cyan beacon) before a predicted breakthrough, never during skirmishes they are winning. All ground-war events SHALL go through the shared game-event queue.

#### Scenario: Call before breakthrough
- **WHEN** a demon unit is predicted to reach fire range
- **THEN** `allyUnderAttack` fires and the beacon shows before `groundBreakthrough`

#### Scenario: Quiet skirmish
- **WHEN** allies are winning a skirmish in sector 1 or 2
- **THEN** no call for help or beacon appears, while `groundForceSighted` and `groundUnitDestroyed` still report the activity

### Requirement: Mixed forces by level
Demon ground forces SHALL mix sector vehicles with infantry squads from sector 1, rocket troopers from sector 2 and heavy tanks from sector 3. The convoy SHALL mix vehicles with rifle and rocket squads. Demon troopers are gargoyle-demon soldiers in military attire; their fallen crack into stone, never blood.

#### Scenario: Variety in a late sector
- **WHEN** sector 4 is flown for a minute
- **THEN** vehicles, infantry, rocket troopers and heavy tanks all appear, and the convoy fields vehicles, rifle squads and rocket squads

### Requirement: Full-width manoeuvre
Skirmish units SHALL manoeuvre laterally across the whole ground plane, including the central lane: along low ground, spreading out and flanking. Threat units SHALL weave inside their side band. The convoy SHALL escort the ship, advance only to engage, and fall back to its slots.

#### Scenario: Units weave across the plane
- **WHEN** sector 3 is flown
- **THEN** units range from the left to the right edge, and most weave by more than 25 units on their way in

### Requirement: Coarse, readable relief
The relief SHALL be coarse: fewer, far larger hills, ridges and valleys that reach across the lane, with no seam on the centre line. An additive slope-and-crest light SHALL make the relief read on dark grounds.

#### Scenario: Lane relief
- **WHEN** relief is sampled across many camera positions
- **THEN** the lane has hills (> 12 texels), the sides exceed 34 texels, and neighbouring columns at the centre line agree

### Requirement: Depth order with vegetation
A plant nearer than a ground unit SHALL be drawn in front of it.

#### Scenario: Plant in front
- **WHEN** a plant at depth 500 overlaps a unit at depth 600
- **THEN** the plant is painted after the unit

### Requirement: Ground war v4 radio events
The model SHALL queue `groundSkirmish`, `infantryEngaged`, `skirmishWon`, `allyFallingBack`, `heavyArmorSighted` and `groundTide`, each rate-limited, with `sector` and, where positional, `x` and `y`.

#### Scenario: Events in a skirmish-rich level
- **WHEN** sector 2 is flown for 100 s
- **THEN** `groundTide`, `groundSkirmish`, `infantryEngaged` and `skirmishWon` fire, with `groundSkirmish` at most once per 6 s

### Requirement: Shared events for radio and music
The model SHALL queue these structured events through the shared game-event queue, with exactly these names:
- `playerDestroyed`, `regroupStart` and `playerRespawn` for the life-loss sequence;
- `divePrep`, one beat (0.5 s) before every dive tell;
- `groundNearMiss` and `groundBreakthroughWarning` for the ground war.

#### Scenario: Dive radio
- **WHEN** a demon is about to dive
- **THEN** `divePrep` fires about half a second before its telegraph starts

### Requirement: Console page
The `/console` web route SHALL show console-styled buttons to start any sector 1–5 on any run 1–5 at any difficulty, with quick jumps to the boss and a sentinel encounter. Every other path SHALL open the arcade unchanged.

#### Scenario: Open the console
- **WHEN** the browser navigates to `/console`
- **THEN** the console page renders its selectors and the launch, boss and sentinel buttons

### Requirement: Ground hull headings
Every reworked ground vehicle SHALL have five authored hull headings in 22.5° steps, mirrored for the other side: 0°–90° for the Ground Fleet and 90°–180° for the Undercroft Host, where 0° points up the plane and 180° toward the camera. Infantry SHALL have three authored headings, mirrored. Ground sprites SHALL NOT be rotated or smooth-scaled at runtime to show a heading; only quarter turns of debris pieces are allowed.

#### Scenario: Heading set present
- **WHEN** the generated ground block metadata is read for any reworked vehicle
- **THEN** it names a move cycle at each of the five authored headings, and every named cell exists in the atlas with binary alpha

### Requirement: Turning through intermediate headings
A ground unit's shown heading SHALL follow its smoothed, rate-limited direction of travel, change by one authored step at a time with hysteresis, and hold each step for at least its class's minimum hold (0.10 s infantry, 0.12 s light, 0.20 s heavy, 0.18 s walker, 0.40 s command). A turn SHALL NOT skip a heading.

#### Scenario: A heavy turns 90°
- **WHEN** a Lodestar's direction of travel swings from straight up the plane to screen right
- **THEN** it shows the 0°, 22.5°, 45°, 67.5° and 90° headings in order, each for at least 0.2 s, and the turn takes between 1.0 and 1.4 s

#### Scenario: No flicker on a wobble
- **WHEN** a unit's direction of travel oscillates ±5° around the midpoint between two headings
- **THEN** its shown heading does not change

### Requirement: Independent articulated layer
A vehicle with a turret or other articulated layer SHALL draw that layer from a per-heading pivot at its own angle, chosen from the same 22.5° grid with its own rate limit and hysteresis, independent of the hull heading. Muzzle points SHALL be taken per layer angle.

#### Scenario: Driving one way, aiming another
- **WHEN** an engaged Lodestar drives at 45° to the right while its foe is 22.5° to the left
- **THEN** the hull shows the 45° heading and the turret shows the mirrored 22.5° angle, seated on the hull's turret ring, and its tracer leaves from that angle's muzzle

### Requirement: Ground Fleet design language
Ground Fleet vehicles SHALL use straight and chamfered faceted plate from the `ally_hull` ramp, cyan light strips from `ally_cyan`, a compact turret set forward with a 2-texel-thick main gun, and antenna height as the rank cue. They SHALL NOT use `demon_warm`, `demon_gilt`, warm lamps, hooks, pointed arches, horns or faces. Allied vehicles SHALL NOT break into pieces or show death imagery.

#### Scenario: Palette scan
- **WHEN** every Fleet cell is scanned
- **THEN** no pixel belongs to `demon_warm` or `demon_gilt`, and no body pixel is brighter than `ally_hull` step 4 except 1-texel speculars and cyan strips

#### Scenario: Turret reads at the far scale
- **WHEN** a Fleet vehicle is drawn at its farthest advance (z 620)
- **THEN** its turret top differs from the surrounding hull by at least two ramp steps and a reviewer can tell which way the turret points

### Requirement: Rich Undercroft Host animation
Every Tier A Undercroft Host unit SHALL have authored or generated frames for idle, move at every authored heading, attack wind-up (channel fill) and release, hit, two damage states, death and arrival, plus its special action. Idle loops SHALL run at 2–3 fps. The Host SHALL stay carved stone: no insect, chitin, creep, slime or tentacle forms.

#### Scenario: A Crocket's full set
- **WHEN** the Crocket's block is inspected
- **THEN** it holds 4 move frames at each of 5 headings, `fill1`–`fill3` and `lights` overlays per heading, `dmg1` and `dmg2` overlays per heading, 4 `arrive` frames, wreck and rubble frames, and 12 debris pieces

### Requirement: Host arrival by unearthing
A Host unit that appears mid-field SHALL be able to arrive by unearthing: a crypt slab cracks with warm seams, heaves, and the unit climbs out with a dust ring, in four frames. Far arrivals SHALL be able to emerge from the fog instead.

#### Scenario: Unearthing frames
- **WHEN** a Host vehicle's `arrive` frames play
- **THEN** frame 0 shows a slab with warm seams, frame 2 shows the unit's top half above the ground line, and frame 3 shows it at full height before its move cycle starts

### Requirement: Distance atmosphere layers
The ground SHALL have stepped-alpha atmosphere layers per sector: a horizon fog band, a low cloud deck, two mist banks that take part in the ground depth sort, cloud shadows, battlefield smoke and a tide dust veil. Units SHALL be tinted toward the sector's fog colour by depth, with emissive pixels fogged at half rate, so that beyond z 1150 mainly their light pattern shows. Threat units SHALL be fogged by at most 45%.

#### Scenario: Emerging from the mist
- **WHEN** a Host unit walks from z 1400 to z 700
- **THEN** it starts as a fogged silhouette with visible eye lights, passes behind and then in front of the mist banks, and arrives at z 700 with no fog tint

#### Scenario: Threat stays readable
- **WHEN** a threat vehicle is telegraphing at any depth
- **THEN** its telegraph frames and ground bracket are never covered by an atmosphere layer, and its fog tint is at most 45%

### Requirement: Atmosphere never covers play
Atmosphere layers SHALL be drawn below the air layer, SHALL keep a combined alpha of at most 0.30 inside the central lane below y 300, SHALL stay at luma 0.40 or below, and SHALL NOT use `demon_warm`, `ally_cyan` or gilt colours. Under reduced motion their drift SHALL stop.

#### Scenario: Lane cap
- **WHEN** smoke from a wreck drifts toward the central lane
- **THEN** the combined atmosphere alpha over any lane pixel below y 300 stays at or below 0.30

### Requirement: Ground easter eggs
The ground war SHALL include four rare presentation-only flourishes: Fleet squads dancing after a won skirmish (always at sector clear), light Host vehicles breaking into tumbling authored pieces (with a rarer jackpot in which the turret pops and a tiny crew scampers off), falling trees releasing a flock of small original flyers that fly away into the distance, and ground critters fleeing nearby troops.

#### Scenario: A tree releases a flock
- **WHEN** the convoy pushes over a frost-pine and the egg budget allows it
- **THEN** a flock of 5 to 9 small flyers leaves the crown, flies up and away from the lane toward the horizon, and is gone within 2.5 s

### Requirement: Easter eggs never obscure gameplay
Ground easter eggs SHALL have no hitbox, score or simulation effect, and SHALL draw randomness from a presentation stream, never the game's shared random stream. They SHALL NOT enter the central lane below y 300, SHALL keep body luma at 0.34 or below without signal colours, SHALL be suppressed while a threat telegraph, ground missile, boss fight or last life is in play, SHALL run at most two at once for at most 2.5 s each (3 s for the sector-clear dance), and SHALL be off under reduced motion.

#### Scenario: Same game with eggs on and off
- **WHEN** the deterministic bots fly every sector with easter eggs on and off
- **THEN** the simulation state hashes are identical

#### Scenario: Quiet during a threat
- **WHEN** a ground missile is in flight and a Crocket is destroyed
- **THEN** no jackpot variant, dance or flock starts until the missile is gone

## Research and reference traceability

- Master reference index: [plan/reference-register.md](../../../plan/reference-register.md)
- External & sibling source disposition ledger: [plan/research-source-ledger.md](../../../plan/research-source-ledger.md)
- Project-committed UX cheatsheets:
  - [.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md](../../../.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md)
  - [.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md](../../../.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md)
