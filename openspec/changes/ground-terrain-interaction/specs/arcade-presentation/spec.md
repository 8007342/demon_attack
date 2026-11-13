# Ground troops on terrain presentation

## ADDED Requirements

### Requirement: Movement-state poses
Ground units nearer than depth 900 SHALL show their movement state with authored discrete frames: walk or roll, climb, descend, jump or crest hop, ford, bridge, queue and grind. Slopes SHALL be shown with authored pitch and lean frames, never by rotating or smooth-scaling a sprite. A state SHALL be held for at least 0.35 s and SHALL use hysteresis (enter at the limit, leave at 0.8 × it). At most three units on screen SHALL show a non-walk state at once, and the nearest win.

#### Scenario: Climb is visible
- **WHEN** an infantry squad near the camera crosses a slope steeper than 0.45 uphill
- **THEN** its troopers draw climb frames and its walk cycle slows

#### Scenario: No flicker
- **WHEN** a unit drives along a slope that oscillates around its walk limit
- **THEN** its state changes at most once per 0.35 s

### Requirement: Climb measured along each unit's travel
A unit's reported climb SHALL be the slope along its own direction of travel relative to the ground: toward the camera for advancing demons, and up the plane for the convoy while the ground scrolls under it. Uphill dust, tread pace, `convoyClimbing` and `convoyStuck` SHALL use that sign.

#### Scenario: Convoy climbing a ridge
- **WHEN** a holding ally's ground rises in its direction of travel (higher further up the plane)
- **THEN** its climb is positive, it throws uphill dust, and `convoyClimbing` may fire; on the far side of the crest its climb is negative

### Requirement: Hidden ground hides units
A unit standing on ground hidden behind a nearer crest SHALL be drawn at its true ground position, clipped by the crest line, never lifted onto the crest.

#### Scenario: Behind a ridge
- **WHEN** a unit's ground point is hidden behind a nearer crest
- **THEN** nothing of it is drawn below the crest line at its x, and its contact shadow is hidden too

### Requirement: Contact shadow
Every live ground unit SHALL cast a stepped pixel contact shadow under its contact row. The shadow SHALL stay on the ground while the unit jumps or hops.

#### Scenario: Hop over a crest
- **WHEN** a light vehicle at full pace crosses a ridge crest whose slope is at most 0.75
- **THEN** it lifts 2–4 texels for a moment while its shadow stays on the ground and narrows

### Requirement: Terrain tells
Dust SHALL follow the slope: behind and up when climbing, ahead and low when descending. Fords SHALL splash in the sector's material. Terrain tells SHALL stay below unit body luminance and SHALL never cover a telegraph, a launch flash, an IFF chevron or a distress beacon.

#### Scenario: Tell yields to a telegraph
- **WHEN** a climbing demon unit starts its launch telegraph
- **THEN** it draws its telegraph frames and no climb dust covers the launcher

### Requirement: Reduced-motion terrain states
Reduced motion SHALL replace jump arcs with a one-frame step and drop splashes and pebbles, while keeping the pitch and climb frames.

#### Scenario: Reduced motion
- **WHEN** reduced motion is on and a squad takes a jump-down link
- **THEN** it steps down in one frame with no arc and no particles

### Requirement: Ground terrain radio events
The model SHALL queue `convoyFording`, `convoyBridge`, `troopsClimbing` and `enemyDetour` through the shared dispatcher, in combat only, with `sector`, `side`, `x` and `y`, each rate-limited (15, 20, 15 and 20 s).

#### Scenario: Rate limit
- **WHEN** allies ford canyons continuously in sector 2
- **THEN** `convoyFording` events are at least 15 s apart
