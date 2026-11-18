# Arcade presentation

## MODIFIED Requirements

### Requirement: Alien rank insignia
Rank marks SHALL be rarer than ranks. Grunts SHALL wear none. One grunt in five of the tough species (2-3) SHALL be an elite grunt: a bone winglet, or a crownlet in a sentinel's escort, with no fang and no ember. Hunters SHALL wear Fang and Wings (a winged fang with an ember core), sentinels the winged crown. The carrier's forms SHALL show fang, twin fangs, Fang and Wings and winged crown. The elite's dotted ring SHALL stay removed.

#### Scenario: Mixed formation
- **WHEN** a formation of drones, skirmishers, an elite grunt, a hunter and a sentinel is on screen
- **THEN** only the elite grunt (winglet), the hunter (Fang and Wings) and the sentinel (winged crown) wear a mark

#### Scenario: Fangs only on the higher ranks
- **WHEN** any creature below the hunter rank is drawn
- **THEN** its mark, if any, carries no fang and no ember core

#### Scenario: The ladder escalates at a glance
- **WHEN** the marks are drawn side by side at their in-game size
- **THEN** the winglet (11 x 5 glyph pixels) and the crownlet (7 x 5) are narrower and shorter than Fang and Wings (13 x 9), which is narrower than the winged crown (15 x 7)

#### Scenario: Carrier forms
- **WHEN** the carrier is in its first, second, third or fourth form
- **THEN** its brood sigil shows the fang, the twin fangs, Fang and Wings or the winged crown respectively, at twice the size

#### Scenario: A mark is fixed for life
- **WHEN** a marked creature is damaged, turns angry or changes formation
- **THEN** it keeps the same mark (only the tone changes: gold when angry, white in a dive tell)

## ADDED Requirements

### Requirement: Most of a wave wears no mark
Across every tour, most creatures in the fight SHALL wear no rank mark: on Normal, each tour's waves SHALL average at most 20 % marked and at most 10 % wearing a fang, and no single wave SHALL exceed one third marked or 12.5 % fanged, as measured by tools/insignia_share.dart.

#### Scenario: The old fang flood is gone
- **WHEN** tour 1 sector 4 is played, where every creature used to wear a fang
- **THEN** about one in five wears a winglet and none wears a fang

#### Scenario: Measured on the real model
- **WHEN** `dart run tools/insignia_share.dart` drives all 212 Normal and Hard waves of tours 1-5
- **THEN** the marked share averages 10-19 % per tour (it was 52-100 %), the fang share 0-9.4 %, and test/insignia_ranks_test.dart holds the Normal bounds

### Requirement: Spear-bearers wear the crownlet
When the spear-bearer creature lands, it SHALL wear the crownlet, the guard's mark: the elite-grunt notch, below hunters, with no fang. Its share SHALL count toward the marked-share bounds.

#### Scenario: A spear-bearer in a formation
- **WHEN** a spear-bearer flies with grunts and a hunter
- **THEN** it wears the crownlet, the grunts wear nothing and the hunter wears Fang and Wings
