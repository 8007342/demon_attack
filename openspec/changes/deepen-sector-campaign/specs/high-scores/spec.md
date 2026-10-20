# Score presentation

## ADDED Requirements

### Requirement: Inline landing Top10
The landing page SHALL load and display all available Top10 entries, with loading, empty, unavailable and retry states independent of Start. Desktop SHALL present it alongside the title and mobile SHALL allow scrolling to it below the title. Successful initials submission SHALL return to that inline board.

#### Scenario: Unavailable scores
- **WHEN** the score endpoint fails
- **THEN** retry is offered on the landing page and starting a game remains available

#### Scenario: Score accepted
- **WHEN** a score submission succeeds
- **THEN** the player returns to the landing page with the returned board and confirmation
