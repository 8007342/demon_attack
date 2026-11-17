# Arcade presentation

## ADDED Requirements

### Requirement: Diving shields thin in place
Every diving shield (ordinary divers, elites, a sentinel's dive shield and its rush shield) SHALL be one continuous thermal crescent of constant span, drawn in the creature's own transform so it scales and moves with the body, and wide enough to cover the body's widest pose. Spending a point SHALL only thin it, by equal steps to 35–45 % of its full thickness on the last point; it SHALL never narrow, split, move or vanish before it breaks. The rush shield SHALL be the thickest.

#### Scenario: A three-point elite takes two hits
- **WHEN** an elite's three-point diving shield loses one point and then another
- **THEN** the crescent keeps its 48-unit span, curve and leading edge, its thickness drops to 70 % and then 40 % of full, and it reads as one shape with no gaps

#### Scenario: Zooming dive
- **WHEN** a diving creature is drawn at 0.45, 1, 1.25 or 1.6 times scale
- **THEN** its shield scales with it and its tips reach the creature's widest dive pose on both sides

#### Scenario: Shield hit
- **WHEN** a hit spends a diving shield point
- **THEN** the whole crescent flashes white for about 0.12 s and settles thinner, and on the last point it flickers under 2 Hz

### Requirement: The rush shield forms in place
During a sentinel's rally and lock its crimson rush shield SHALL form at its final size and thickness, fading in with the tell, and during the rush it SHALL thin with the rush shield's points. No separate fixed-size readout of the rush shield SHALL be drawn beside it.

#### Scenario: Transformation
- **WHEN** a sentinel goes through its rally and lock
- **THEN** its crimson shield keeps one size and grows only in opacity, and no cell arc is drawn under it

#### Scenario: Rush shield worn
- **WHEN** four of a rush shield's eight points are spent
- **THEN** the crimson arc keeps its span and is thinner than at full strength
