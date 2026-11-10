# Terrain relief presentation

## ADDED Requirements

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
