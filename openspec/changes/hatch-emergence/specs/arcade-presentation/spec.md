# Arcade presentation

## ADDED Requirements

### Requirement: Carrier hatches as focal points
Each carrier hatch SHALL read as the fight's focal point without new hull art: two separate tusks beside a ragged slot that narrows inward, light from deep inside, a telegraph pulse that quickens toward the opening, steam when it opens, ichor when cracked, a break burst, and light falling down the hull from the live tier. No layer SHALL form paired lights, rows, arcs or concentric rings round a slot.

#### Scenario: A hatch telegraphs and opens
- **WHEN** a hatch's volley telegraphs for 1.2 s and its doors open for 0.5 s
- **THEN** its tusks' rim light and the light deep in its slot pulse at a rate rising from 2 to 5 Hz, the light rises as the tusks part, and two steam jets leave each tusk root sideways

#### Scenario: A hatch is destroyed
- **WHEN** a hatch's hull reaches 0
- **THEN** a white-amber flash, a shock ring to 50 units and 10 ember sparks play over its ivory splinters within 0.45 s

#### Scenario: Staging the live tier
- **WHEN** the hatch chapter runs on tour 5
- **THEN** warm light falls down the hull below the vulnerable tier's hatches and rims their tusks, with no disc or vignette round any hatch, and the idle sealed tiers keep shaded tusks

### Requirement: Hatch field thins in thickness
A hatch's own force field SHALL be one continuous open membrane conforming to its slot, hung from its tusk roots, never a circle round it. Its thickness SHALL fall with its field hit points while its extent stays the same, the principle of the thinning dive shields, and it SHALL ripple on every hit.

#### Scenario: Field hits
- **WHEN** a hatch field goes from full to its last point
- **THEN** its membrane thins from 7 to 1.2 units, keeps its whole extent with no gaps, and each hit shows a 0.28 s ripple

### Requirement: One-shot hatch emergence
Every creature a fighting carrier's hatch launches SHALL play an emergence sequence exactly once: a claw grips the rim, the head and shoulders peek beside the held tusk, it holds the door, crouches, leaps, opens its wings and glides down, then hands off to its flight sprites when its entrance ends. A flock's members SHALL play different variants.

#### Scenario: A flock of three
- **WHEN** a hatch launches three creatures
- **THEN** the lead grips during the telegraph, peeks and holds the door during the opening, the second grips the other tusk and vaults, the third springs from the centre, and each plays crouch, leap, unfurl, flare and glide once

#### Scenario: The hand-off
- **WHEN** an emerging creature's entrance ends
- **THEN** its flight sprite takes over at its own position with no jump, and its emergence never restarts

#### Scenario: The shortest entrance
- **WHEN** a flock leaves the core door with its 0.55 s entrance
- **THEN** crouch, leap, unfurl and flare end by 0.44 s and the drawn position has joined the creature's own path before the entrance ends

### Requirement: Emergence art and tiers
The emergence frames SHALL come from the rig pipeline (rigkit key poses, a studio hero repaint per species, the projection bake, a rigsheet pose pack) as one atlas of at most 64 KB and 1 MB resident. FULL SHALL draw three lurkers a held hatch, LEAN one, and LITE none, with no emergence frames and no vents.

#### Scenario: LITE
- **WHEN** the phone's tier is LITE during a carrier fight
- **THEN** no lurker is drawn, launched creatures keep their flight sprites, and the hatches draw no vents or pulse rings

#### Scenario: Draw budget
- **WHEN** tour 5's hatch chapter is drawn
- **THEN** each lurker or emerging creature costs one image draw, at most 16 a frame, and the hatches stay within 160 draw calls

### Requirement: A hatch never reads as an eye
A hatch at rest (closed, telegraphing or open) SHALL NOT read as an eye: drawn over the hull and seen at a glance (area-averaged to 24 by 24), its luminance SHALL correlate with a reptile-eye template (an almond iris with a slit pupil, a ring, a socket) below 0.35, and rings about its centre SHALL explain less than 0.45 of its luminance variance.

#### Scenario: The guard test
- **WHEN** hatch u1R of tour 1 is drawn on the live tier, closed, mid-telegraph and open
- **THEN** each pose scores below both ceilings, where the rejected first draft scored 0.53 to 0.58 and 0.63 to 0.67
