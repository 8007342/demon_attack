# Arcade presentation

## ADDED Requirements

### Requirement: Carrier creatures drawn over the hull
In the carrier fight, no creature, tell or death burst SHALL be covered by the hull, its prow, its deck or its field. They SHALL be drawn after every hull pass. During the approach, a launched creature SHALL be drawn in front of the carrier's fog slot.

#### Scenario: A flock at its home row
- **WHEN** fight minions hold their places just below the prow
- **THEN** each creature is fully visible over the prow's art

#### Scenario: An approach launch
- **WHEN** a launch wave leaves the approaching carrier's dorsal hatches
- **THEN** its creatures are drawn in front of the hull from their first frame

### Requirement: Hatch launch presentation
Each launch SHALL read as coming out of the top surface. The creature pops up out of the open hatch for 0.3 s, growing from 0.8 to full size, then swoops over the hull to its place, never aimed at the ship's row. Its passage out through the force field SHALL show a faint ripple and queue no event.

#### Scenario: A pop-up
- **WHEN** a creature leaves a dorsal hatch
- **THEN** it rises out of the opening in the hatch's glow, then crosses the hull visibly toward the formation

### Requirement: Hatch drop and cascade presentation
A dropped hatch SHALL go dark with a short flicker, blow its doors off as break-up components, and keep smoking where it is. A light chase SHALL run down the hull to the new tier, whose hatches arm with an ember pulse. A drop SHALL add no camera shake.

#### Scenario: Tier 1 drops
- **WHEN** the first threshold is reached
- **THEN** both tier-1 hatches blow and seal in smoke, the chase runs down to tier 2 within 1 s, and tier 2's hatches glow ember

#### Scenario: Reduced motion
- **WHEN** reduced motion is on and a tier drops
- **THEN** the hatches go dark and seal, the doors fall without spin, and the new tier lights without a chase

### Requirement: Carrier components break off individually
Art removed between two damage states SHALL leave as individual components, never as a whole layer. This covers the plates and crystals of the S2 shed, the module of a form change, and a dropped hatch's doors. Each component SHALL stay attached until released, and no more than a quarter of a transition's components, at least two, SHALL release in any 0.25 s.

#### Scenario: The spines break off
- **WHEN** the carrier's first form change tears away its spines
- **THEN** the spines leave one by one or in small clumps over at least 1.2 s, staggered from the outer tips inward, and the hull never shows the whole spine layer vanishing in one frame

#### Scenario: Seamless start
- **WHEN** a damage transition begins and nothing has been released yet
- **THEN** the hull looks as it did on the frame before, within 2 % mean colour difference over the transition's texels

### Requirement: Component physics and fragmenting
A released component SHALL keep its last attached motion, the hull's velocity at its pivot by `v + ω × r`, plus a kick along its axis. It SHALL tear at its root, then fly, spin by size class, sink and shrink toward the cloud deck, and fade. Medium and large components SHALL split into two or three fragments that inherit their parent's motion.

#### Scenario: A large plate
- **WHEN** a large component is released
- **THEN** it swings about its root for under 0.35 s, flies free with the inherited velocity, splits into three fragments within 0.7 s, and is gone within 3.6 s

#### Scenario: Reduced motion
- **WHEN** reduced motion is on
- **THEN** components still release one by one and fall, shrink and fade, without root swing, spin, fragments or sparks

### Requirement: Break-up consistent with the cohesive collapse
The break-up SHALL NOT change the final collapse. Components still attached when the core dies SHALL be composed into the wreck and fall with it. Components already released SHALL finish their own flight.

#### Scenario: Death mid-transition
- **WHEN** the core is destroyed while a module is half broken away
- **THEN** its attached components are part of the wreck's one structure, its released ones keep falling on their own, and the collapse's cohesion test still passes
