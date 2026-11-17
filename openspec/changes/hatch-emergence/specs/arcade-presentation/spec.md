# Arcade presentation

## ADDED Requirements

### Requirement: Carrier hatches as focal points
Each carrier hatch SHALL read as the fight's focal point without new hull art: an inner glow as its tusks part, a telegraph pulse that quickens toward the opening, steam from its tusk roots when it opens, ichor from a cracked hatch, a break burst when destroyed, and staging that darkens around the live tier and sinks the sealed tiers. No layer SHALL form paired lights, rows or arcs over a slot (the head-reading guard).

#### Scenario: A hatch telegraphs and opens
- **WHEN** a hatch's volley telegraphs for 1.2 s and its doors open for 0.5 s
- **THEN** an ember ring pulses out of it at a rate rising from 2 to 5 Hz, a warm glow blooms as the tusks part, and two steam jets leave each tusk root sideways

#### Scenario: A hatch is destroyed
- **WHEN** a hatch's hull reaches 0
- **THEN** a white-amber flash, a shock ring to 50 units and 10 ember sparks play over its ivory splinters within 0.45 s

#### Scenario: Staging the live tier
- **WHEN** the hatch chapter runs on tour 5
- **THEN** the vulnerable tier's hatches sit in a dark vignette under an amber halo, and the idle sealed tiers are dimmed under char

### Requirement: Hatch field thins in thickness
A hatch's own force field SHALL be one continuous ring at its hit radius whose thickness falls with its field hit points while it keeps its whole circle, the principle of the thinning dive shields, and it SHALL ripple on every hit.

#### Scenario: Field hits
- **WHEN** a hatch field goes from full to its last point
- **THEN** its ring thins from 7 to 1.2 units, its angular extent stays 360 degrees with no gaps, and each hit shows a 0.28 s ripple

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
