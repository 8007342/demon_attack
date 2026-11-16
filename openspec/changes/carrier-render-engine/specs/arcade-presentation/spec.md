# Arcade presentation

## ADDED Requirements

### Requirement: Carrier hull drawn as one surface
Each pass of a carrier hull SHALL be composed into one texture, re-composed only when its damage state changes, and warped by one continuous mesh whose vertices are shared by all of its modules, so the hull bends as one rigid body. No module SHALL move against its neighbours under the bend. The hit windows SHALL stay within 3 arena units of their hit areas.

#### Scenario: Full bend
- **WHEN** the carrier is held at its lean, bank and pitch limits together
- **THEN** each pass is one `drawVertices` call over one texture, no seam or gap opens between modules, and the core window moves less than 3 units

#### Scenario: Damage state changes
- **WHEN** a module is torn away or the hull reaches a new damage stage
- **THEN** the pass is re-composed once with the new art and the old texture is released, and during steady flight nothing is re-composed

#### Scenario: Rig points follow the surface
- **WHEN** lights, nozzles, fires, gates or the field are drawn on a bent hull
- **THEN** each is displaced by the same displacement and height field as the mesh, so it stays on its spot of the art

### Requirement: Cohesive carrier collapse
A carrier SHALL collapse as one structure. The hull as it was at death breaks along its structure into a hierarchy of sections, then chunks. Each piece stays attached until it is released, then inherits its parent's velocity at its own pivot and its spin, plus a small separation kick. All pieces recede at one depth scale and sink into the cloud deck together.

#### Scenario: The breakup
- **WHEN** a carrier's core is destroyed
- **THEN** the hull first sags and cracks while held together, the sections shear off between 1.2 and 2.1 s, chunks follow between 2.2 and 4.6 s, the deck stays with the fore hull, and the wreck is gone by 7 s

#### Scenario: Shared momentum
- **WHEN** a section or chunk is released
- **THEN** its position is continuous at the release and its velocity differs from its parent's velocity at that point by no more than its separation kick (under 20 units per second)

#### Scenario: Cohesion
- **WHEN** the wreck has sunk to the start of its fade
- **THEN** every chunk is within 120 units of where the intact hull would have carried it, and the hull has listed by less than 10 degrees

#### Scenario: Off-screen parts
- **WHEN** a part of the hull that was off-screen at death moves into view during the collapse
- **THEN** it is drawn from the same composed texture as the rest of the wreck, never as a separate sprite, and the art's cut edges are dissolved, not drawn as straight lines

### Requirement: Collapse continuity and restraint
The collapse SHALL leave world-space smoke trails from its cracks, show blasts that ride the breaking pieces, and fade into the cloud deck from below. It SHALL use at most 32 blasts and 90 smoke puffs. Under reduced motion the pieces SHALL neither spin nor list and SHALL emit no smoke.

#### Scenario: Falling into the clouds
- **WHEN** the collapse passes its midpoint
- **THEN** the lower pieces dissolve into the rising cloud deck before the upper ones, and no piece turns into a flat light shape

#### Scenario: Reduced motion
- **WHEN** the collapse plays with reduced motion on
- **THEN** the hull does not list, no piece spins, no smoke is emitted, and the wreck still sinks and fades

### Requirement: Carrier field wears thin
The carrier's field membrane SHALL stay at one fixed offset from the hull at every shield level. As the shield wears, its width and opacity SHALL fall and coherent patches of it SHALL wear through. A lost shield cell's region SHALL stay drawn, worn thinnest, and SHALL never be switched off while the shield holds.

#### Scenario: Wearing down
- **WHEN** the shield falls from full to a quarter
- **THEN** the membrane stays where it was, its line thins and dims, and about a third of it shows worn-through gaps

#### Scenario: A cell is lost
- **WHEN** a shield cell is lost
- **THEN** its region flashes once and stays drawn as a thin, gapped line at the same offset

#### Scenario: Shield down
- **WHEN** the shield reaches zero
- **THEN** the membrane thins to nothing and breaks apart in place within 0.4 s, without moving inward

### Requirement: Field wear flashes stay safe
A worn carrier field SHALL crackle only in small, local sparks. Its whole-field flicker SHALL stay at or below 3 flashes per second, low in contrast and not red. Under reduced motion it SHALL show a static worn pattern with no crackle.

#### Scenario: A low field
- **WHEN** the shield is at or below a quarter
- **THEN** at most a few short segments flash at a time, the remaining field's brightness varies by no more than 30 percent at under 2 Hz, and the shield's gameplay surface is unchanged
