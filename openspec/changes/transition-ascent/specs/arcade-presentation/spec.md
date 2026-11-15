# Arcade presentation

## ADDED Requirements

### Requirement: Pursuit acceleration
During a sector transition's Pursuit the ship SHALL visibly accelerate away from the fight: the world's scroll speed SHALL rise steadily to its peak inside the cloud and ease back through the arrival, and the ground, fog layers and creatures SHALL all move at that same speed. The ship SHALL show the thrust through its engine plume.

#### Scenario: Speeding into the cloud
- **WHEN** a level is cleared and the Pursuit begins
- **THEN** the ground and fog rush past faster and faster until the cloud covers the screen, then slow through the next sector's arrival

### Requirement: Ascent by camera pitch
During the Pursuit the world below SHALL tilt and slide down, with its horizon lowering and near ground leaving the screen before far ground, so that the ship appears to fly up while staying close to its own row. The HUD, the comms dock, the ship and bullets SHALL NOT be tilted or rolled.

#### Scenario: Climbing out
- **WHEN** the Pursuit's cloud rises
- **THEN** the horizon drops and the ground tilts away beneath a ship that rises only slightly on screen

#### Scenario: Reduced motion
- **WHEN** reduced motion is enabled
- **THEN** the transition plays without tilt, roll or streaks, as crossfades with a gentle speed change

### Requirement: Front-line radio call
When a sector transition returns the squadron to a sector it has already visited in the run, the transition's radio line SHALL be a front-line call from that destination sector, such as "Ground support needed in <sector>!" or "We're getting overwhelmed here!". Until its own recording exists, a call SHALL play a recorded ground-distress line with that line's own subtitle, so audio and text always agree.

#### Scenario: Revisiting a sector
- **WHEN** a later tour heads back into Ringfall
- **THEN** the transition radio carries a ground team's call for help from Ringfall, or a recorded ground-distress line with its own subtitle

#### Scenario: First visit
- **WHEN** the squadron enters a sector for the first time in the run
- **THEN** the transition keeps its mission or banter line
