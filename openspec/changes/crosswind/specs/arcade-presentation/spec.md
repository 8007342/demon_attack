# Arcade presentation

## ADDED Requirements

### Requirement: The wind is visible before it pushes
A windy level SHALL show the wind the field will blow 1.5 s ahead: soft cloud billows and thin wisps streaming with it over the backdrop and under the play, and a striped windsock in the arena's top-left corner over the play that droops when calm, stands out downwind as the wind strengthens and pulses amber while a call is on. A shower on a windy level SHALL slant with the wind.

#### Scenario: Gale in a fight
- **WHEN** a gale blows during a fight at phone portrait size
- **THEN** the billows, the wisps and the windsock show its direction and every creature, the ship and every shot stays clearly visible

#### Scenario: Calm
- **WHEN** a level has no wind
- **THEN** no billow, wisp or windsock is drawn

### Requirement: Wind within the perf tiers
The wind's billows and wisps SHALL be capped by the quality tier (`FrameBudget.windScale`: 1, 0.6 and 0.35 of at most 7 billows and 56 wisps), drawn without blur filters, the wisps as one batched draw call. Reduced motion SHALL halve the wisps, slow the stream to about a third and still the windsock's flutter.

#### Scenario: Tiers
- **WHEN** the same full gale is drawn at FULL, LEAN and LITE
- **THEN** LEAN draws fewer billows and wisps than FULL and LITE fewer than 40 % of FULL

### Requirement: Wind music and radio fail soft
A called gust SHALL ask the score for its `gust` stinger, and the radio MAY speak a wind line. A stinger or section the score does not have SHALL play nothing and leave the music where it is.

#### Scenario: Gust stinger
- **WHEN** `windGust` reaches the music bridge
- **THEN** it asks for the `gust` accent
