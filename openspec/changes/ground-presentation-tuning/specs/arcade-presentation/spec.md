# Ground presentation tuning

## ADDED Requirements

### Requirement: Ground animation reads as distant events
Ground animation (cycles, slews, overlays, purely visual ground effects, easter-egg motion and critter leaps) SHALL
play at no more than half its authored rate, and legged units SHALL stride slower than the other troops.

#### Scenario: Animation at half speed
- **WHEN** a rifle squad marches, a tank rolls and a wreck burns
- **THEN** walk, tread and flame cycles run at half their authored rate or slower

#### Scenario: A heavy turns
- **WHEN** a Lodestar's travel swings 90°
- **THEN** it shows every heading on the way and completes the swing in 2.0–2.8 s

#### Scenario: Walkers walk slower
- **WHEN** a Kiln Ox and a rifle squad hold their ground, idling or turning on the spot
- **THEN** the Kiln Ox's stride cycle runs at 0.3 of its authored cadence and the troopers' at 0.5

### Requirement: Feet plant
While a trooper or a legged walker marches, its walk cycle SHALL advance with the ground it covers on screen (one
cycle per stride: 8 cell texels for troopers, 14 for W-block walkers, 22 for the Chapterhouse), never faster than
1.25 times the authored cadence for troopers and the authored cadence for walkers, and backward while it backs up.

#### Scenario: A squad marches
- **WHEN** a demon rifle squad marches toward the convoy
- **THEN** its walk frames advance one cycle per 8 cell texels of screen travel and its feet do not slide

### Requirement: Gameplay timing is not slowed
The threat telegraph's timing, fire flashes, recoil, hit flashes, tracers and every simulation timer SHALL be
unchanged, and the simulation SHALL produce the same results.

#### Scenario: Telegraph unchanged
- **WHEN** a threat vehicle telegraphs a launch
- **THEN** its raise, glow blink and warning bracket keep exactly the previous timing

### Requirement: Ground unit draw sizes
Allied (Fleet) vehicles SHALL be drawn at half their previous size, enemy (Host) vehicles and the heavy tank at
1.3 times, and troopers of both factions at 0.9 times, with nearest-neighbour scaling; every part of a unit (hull,
articulated layer, overlays, muzzle, wreck effects) SHALL use the same scale. Placement, launch points, homing aim
and hit boxes SHALL be unchanged.

#### Scenario: Convoy tank fires
- **WHEN** a half-size Lodestar fires at a foe
- **THEN** its turret sits on its hull's pivot and the friendly tracer leaves the drawn muzzle

### Requirement: Squads are groups of individuals
A squad SHALL be drawn as a group of 1 to 5 troopers, most often 2 to 4, chosen deterministically per unit and
independent of the simulation's squad strength; the drawn group SHALL fall in proportion to the squad's remaining
hits. Each trooper SHALL have its own gait phase and cadence, its own place in the group, a slow drift, a lead or lag
along the march and its own turn, while staying within a few texels of its formation slot.

#### Scenario: A squad turns
- **WHEN** a marching squad changes direction
- **THEN** its troopers turn one after another rather than all on the same frame, and stay a group

#### Scenario: A squad takes a hit
- **WHEN** a demon squad of 3 hp drawn as 4 troopers takes one hit
- **THEN** ceil(2 · 4 / 3) = 3 troopers stay standing and the one that fell topples where it stood
