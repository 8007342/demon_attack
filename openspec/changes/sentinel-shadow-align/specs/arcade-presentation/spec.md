## ADDED Requirements

### Requirement: The looming sentinel's shadow follows its silhouette
While a coming sentinel's silhouette circles behind the fog, its shadow SHALL be cast from that silhouette the way every flyer's shadow is: from the ground under the silhouette's depth, below its drawn position, along the sun. Its size SHALL follow from that projection alone, smaller far away and growing as the silhouette nears. It SHALL hand off to the rising sentinel's shadow without a jump.

#### Scenario: Aligned while it circles
- **WHEN** the silhouette flies its figure-eight two waves, one wave or just before its sentinel's arrival
- **THEN** the shadow's x stays within 1 unit of the silhouette's x plus the flyers' sun lead at altitude 120 (120 · tan 32° · 0.22 · cos(sun drift), 16.4–16.5 units), on flat ground and draped on the relief
- **AND** on flat ground its y stays within 1 unit of the ground under the silhouette's nearness plus the same lead's vertical share

#### Scenario: Smaller at a distance
- **WHEN** the silhouette is farther (a smaller nearness) at one moment than at another
- **THEN** its shadow is no larger at the farther moment, with no fixed shrink factor beyond the projection

#### Scenario: No jump at the hand-off
- **WHEN** the silhouette hands over to its sentinel rising out of the fog and the sentinel takes its place
- **THEN** the one sentinel shadow moves less than 4 units and changes size by less than 3 % between any two frames
