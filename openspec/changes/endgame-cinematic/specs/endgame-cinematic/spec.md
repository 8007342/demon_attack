# endgame-cinematic

## ADDED Requirements

### Requirement: The reveal sequence
The ending SHALL be a cinematic of 20 to 35 seconds in at least five shots that shows the campaign was a board game played by kids at a beachfront restaurant named Krybor. It SHALL open on a match cut from the falling carrier to a plastic carrier figure tipping over on the board, and SHALL show the board with its plastic figures, the players, the waitress, the owner and the mother. The shots, timings, cameras and transitions are fixed by the committed shot script.

#### Scenario: First completion
- **WHEN** the carrier of route 5 falls and the ending opens
- **THEN** the shots S1 to S7 of the shot script play in order, about 29 seconds in all, and the credits follow

#### Scenario: The match cut
- **WHEN** shot S1 reaches its cut point
- **THEN** the plastic carrier figure appears at the same screen position, angle and size as the game's carrier wreck in the frame before, and the fall continues as the figure tipping over

#### Scenario: The cast as bystanders
- **WHEN** the shots S4, S5 and S6 play
- **THEN** the waitress, the owner and the mother each carry the accent colour, the voice and one prop of the radio character the cast table in `docs/styleguide/endgame-cinematic.md` maps them to

#### Scenario: After the credits
- **WHEN** the credits reach their end or are closed after a full viewing
- **THEN** the short button shot S8 plays once before the completed result opens

### Requirement: Skippable, pausable and never in the way
A skip control SHALL be visible from the first frame and SHALL lead straight to the credits. The first viewing SHALL ask for a confirming second press so a stray tap does not lose the scene; replays SHALL skip on one press. The cinematic SHALL pause while the app is in the background. Skipping, pausing, replaying or failing to load SHALL never change the score, lives, medals or score entry.

#### Scenario: Stray tap on the first viewing
- **WHEN** the player taps once during the first viewing
- **THEN** the skip control highlights for 2 seconds and the scene keeps playing; a second press within that time skips to the credits

#### Scenario: Skip on a replay
- **WHEN** the player presses skip, Escape or the gamepad's back button during a replay
- **THEN** the credits open at once

#### Scenario: Backgrounded
- **WHEN** the tab or the app goes to the background at second 12
- **THEN** picture, voices and sound stop, and all resume from second 12 when it returns

#### Scenario: Assets missing
- **WHEN** the scene's images have not loaded within 3 seconds of the ending opening
- **THEN** the still reveal with its two captions plays instead, and the credits and the completed result follow as usual

### Requirement: Exclusive dialogue with subtitles
The cinematic SHALL have its own lines, which no radio trigger ever plays. They SHALL be spoken in the cast members' voices without the radio effect, and each SHALL show a one-line subtitle with the speaker's role. A line whose clip is not yet recorded SHALL show its subtitle for its reading time with no borrowed voice. The opening line SHALL start with the radio effect and lose it as the picture cuts to the table.

#### Scenario: A recorded line
- **WHEN** the mother's line plays in shot S6
- **THEN** her clip plays in the Admiral's voice with room sound and no radio filter, and the subtitle stays for the length of the clip

#### Scenario: An unrecorded line
- **WHEN** a line has no recorded clip
- **THEN** its subtitle shows for its reading time, no other clip is borrowed, and the shot keeps its timing

#### Scenario: Never on the radio
- **WHEN** the radio director picks lines during a run
- **THEN** no cinematic line id is ever eligible

### Requirement: An in-engine layered scene
The cinematic SHALL run in the game engine as layered still images moved by a data-driven timeline (camera, parallax, focus, a few animated layers), not as a video file. It SHALL frame every shot for both portrait phones and landscape screens from the same layers, keeping each shot's subject inside the frame. Its timeline SHALL be evaluable without rendering, so a test can check any moment of it.

#### Scenario: Portrait phone
- **WHEN** the scene plays on a 360 by 780 screen
- **THEN** each shot's subject box from the shot script is fully visible and no subtitle is clipped

#### Scenario: Landscape
- **WHEN** the scene plays on a 1920 by 1080 screen
- **THEN** each shot fills the screen with no letterbox wider than 5 percent, and its subject box is fully visible

#### Scenario: Timeline test
- **WHEN** a test asks the timeline for its state at 2.0 seconds
- **THEN** it gets shot S1, the cut flag, the camera and the layer positions as plain values, with no image decoded

### Requirement: Reduced motion and comfort
With reduced motion on, the cinematic SHALL show each shot as a still with crossfades, with the same dialogue and subtitles and no camera move, parallax, focus pull or shake. In every mode it SHALL never flash more than three times in one second.

#### Scenario: Reduced motion
- **WHEN** the system asks for reduced motion and the ending opens
- **THEN** seven stills crossfade in order with the same lines, and nothing else on screen moves

#### Scenario: The neon sign
- **WHEN** the sign in shot S7 flickers on
- **THEN** it changes brightness at most three times within any one second

### Requirement: Loading and size
The cinematic's images and audio SHALL stay out of the first-load download and the offline precache. They SHALL be fetched while the player fights the carrier of route 5, or when a replay is opened. Together they SHALL stay within the size budget set in the design.

#### Scenario: Preload during the last fight
- **WHEN** the carrier of route 5 appears
- **THEN** the scene's files start downloading in the background without a frame drop the player can notice

#### Scenario: Budget
- **WHEN** the web build is made
- **THEN** a check fails the build if the scene's images exceed 7 MB or its audio exceeds 1.5 MB

### Requirement: The table remembers the run
At least three details of the scene SHALL come from the run just finished, so that two completions do not look the same. A replay SHALL use the last completed run stored on the device, and a fixed default when there is none. The details and their sources are the R rows of the reveal ledger.

#### Scenario: Score, medals and lives
- **WHEN** a run ends with 184 300 points, three medals and two lives
- **THEN** the order ticket in shot S5 reads 184300, three medal tokens lie by the pilot's place in shot S2, and two heart tokens remain

#### Scenario: Difficulty
- **WHEN** the run was played on Hard
- **THEN** the game box in shot S7 carries the Hard edition's label

#### Scenario: Replay with no stored run
- **WHEN** the replay opens on a device with no completed run stored
- **THEN** the scene shows the default table

### Requirement: Every payoff is planted
Each detail the cinematic pays off SHALL have a row in the reveal ledger that names where the game plants it. A check SHALL fail when a ledger row names a shot, layer or line id that does not exist, or when a shot script layer marked as a payoff has no ledger row.

#### Scenario: A payoff without a plant
- **WHEN** the shot script marks the sugar packets in S2 as a payoff and no ledger row points at them
- **THEN** the check exits non-zero and names the layer

#### Scenario: A stale row
- **WHEN** a ledger row cites the line id `sectorStart.1.h9` and the bank has no such line
- **THEN** the check exits non-zero and names the row

### Requirement: Plants hide in plain sight
A plant line SHALL make sense as battle chatter on first hearing and SHALL never say outright that the war is a game, that the players are kids or that Krybor is a restaurant. Plant lines SHALL be rationed so a first run hears only a few. Once the ending has been seen on a device, a second set of bolder plant lines SHALL become eligible.

#### Scenario: First run
- **WHEN** a player who has never seen the ending plays one sector
- **THEN** at most one plant line is spoken in it, and none of the second set

#### Scenario: Second run
- **WHEN** the ending has been seen and a new run starts
- **THEN** lines of the second set may be picked, under the same one-per-sector ration

#### Scenario: Tone check
- **WHEN** a proposed plant line contains "board game", "restaurant", "pretend" or "kids"
- **THEN** the line check rejects it

### Requirement: A committed, licence-clean pipeline
Every image and clip of the cinematic SHALL be rebuilt from committed inputs: the shot script, the layout scenes, the picked raw renders, the workflows and their seeds. Each generative model used SHALL be recorded with its licence, and only models whose licence allows their outputs in a GPL-3.0 project that others may reuse commercially SHALL be used. Picks SHALL be logged with their reasons in a run ledger.

#### Scenario: Rebuild without a GPU
- **WHEN** the layer images are rebuilt from the committed picks on a machine with no GPU
- **THEN** the build finishes and the images match the committed ones

#### Scenario: A non-commercial model
- **WHEN** a workflow names a model whose licence forbids commercial use of its outputs
- **THEN** the pipeline check rejects the workflow before anything is queued
