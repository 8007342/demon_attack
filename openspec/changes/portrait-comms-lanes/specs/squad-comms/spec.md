# Squad comms

## ADDED Requirements

### Requirement: Portrait radio lanes
In the compact (portrait) dock, radio toasts SHALL use two independent lanes: humans (fleet and ground link) on the left, the brood on the right. Each lane SHALL keep its own queue, timeout and persistence. A toast SHALL stay where it appeared until it expires and then close in place; it SHALL never move to the other lane. A line whose lane is busy SHALL wait for that lane, never borrow the other.

#### Scenario: The left toast closes
- **WHEN** a squad line and a brood line are up side by side and the squad line expires first
- **THEN** the squad toast fades out in place and the brood toast stays exactly where it was until its own expiry

#### Scenario: Two lines from one side
- **WHEN** a second squad line starts while the first squad toast is still up
- **THEN** it waits for the left lane (shown as `+1` under it) and appears there when the first closes, with its full reading time

#### Scenario: Busy channel
- **WHEN** five minutes of pickups, brood chatter, sector clears, taunts and lost ships are simulated
- **THEN** no toast ever appears in the other side's lane and no closed toast comes back

### Requirement: Fixed portrait toast size
Every portrait toast SHALL have one fixed size: the dock's toast height (84 px) and half the dock's width, or the full width for a comeback. A toast SHALL never shrink to its text or grow to match its neighbour. Text longer than the box SHALL stay at its normal size and scroll inside the box in time with its reading time (a page at a time with reduced motion), never cut off.

#### Scenario: Short beside long
- **WHEN** a one-word brood line is up and a squad line of 85 characters appears beside it
- **THEN** both toasts are 84 px tall, the brood toast neither moves nor grows, and the long line scrolls inside its box

### Requirement: Combined comeback toast
In portrait, an exchange and its answer (human to brood or brood to human) SHALL share one full-width toast, the human half on the left and the brood half on the right. It SHALL wait for both lanes and reserve them while it waits. A blocking toast that has been read and is silent SHALL close at once; any other SHALL close after 1 s of waiting. Closing is always in place.

#### Scenario: Sector cleared
- **WHEN** the squad's level-clear line starts while a brood taunt has been up for its reading time
- **THEN** the taunt closes in place, one combined toast shows the squad line and, when it starts, the brood's answer beside it

#### Scenario: Unread neighbour
- **WHEN** an exchange opens 0.1 s after a long brood line appeared
- **THEN** the brood toast closes after the exchange has waited 1 s, and the combined toast appears in its place in both lanes

## MODIFIED Requirements

### Requirement: Phone transmissions
In portrait, a sector change's radio chatter SHALL show at the landscape call tiles' size in the middle of the arena, over the clouds, during Pursuit: one long line, or two short ones (each ≤ 48 characters), or one line with its comeback, chosen by length. Lines it shows SHALL not appear on the dock. Landscape keeps its call tiles.

#### Scenario: Travel briefing
- **WHEN** the ship travels to the next sector on a 390 × 844 screen and the mission transmission is the first line of Pursuit
- **THEN** it shows in the middle of the arena at full tile size with a lip-synced portrait, and not on the dock

#### Scenario: Sector cleared with a comeback
- **WHEN** the squad's level-clear exchange opens Pursuit
- **THEN** its line and the brood's answer show in one frame in the middle, and a mission transmission after them plays on the dock

#### Scenario: Two short lines
- **WHEN** a short line plays alone in Pursuit and a second short, unlinked line fits before the Descent
- **THEN** the second line is queued once and shows beside the first, which keeps its place

#### Scenario: A line and its comeback
- **WHEN** the slot's first line opens an exchange
- **THEN** its answer joins it in one shared frame, the human card left and the brood card right
