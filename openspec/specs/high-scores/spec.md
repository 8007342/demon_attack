# high-scores

## Purpose
Persist a shared Top10 scoreboard with constrained arcade initials and recoverable network failures.

## Requirements

### Requirement: Durable Top10
A Cloudflare Durable Object SHALL persist independent Easy, Normal and Hard Top10 boards, each ordered by descending score with stable ties. Each result SHALL retain initials, score, difficulty, zero to five medals, accumulated active time and remaining lives for completed campaigns. Existing entries SHALL remain Normal results with default metadata.

#### Scenario: Reload scores
- **WHEN** a valid score has been accepted and its mode board is loaded
- **THEN** the persisted result appears if it remains in that mode Top10

#### Scenario: Independent pruning
- **WHEN** a Hard result enters its Top10
- **THEN** no Easy or Normal result is removed

### Requirement: Three-wheel entry
Score entry SHALL offer exactly three rotating wheels containing only A–Z and 0–9 and no free-text name input.

#### Scenario: Choose initials
- **WHEN** a player adjusts the three wheels
- **THEN** the submission contains exactly three permitted characters

### Requirement: Validation and failure handling
The API SHALL reject malformed initials, invalid modes, noninteger or out-of-range score/medals/time/lives and inconsistent completion metadata. Legacy requests SHALL default to Normal with absent achievement metadata. The client SHALL show loading, empty and unavailable states and retain failed submissions for retry.

#### Scenario: Offline submission
- **WHEN** a submission fails
- **THEN** retry preserves initials and the complete run result

#### Scenario: Legacy client
- **WHEN** a valid request supplies only initials and score
- **THEN** it is accepted as a Normal result with default metadata

### Requirement: Inline landing Top10
The landing page SHALL display a neutral Top10 heading with unlocked difficulty tabs labelled only by mode; a lone Normal tab SHALL be hidden. It SHALL provide loading, empty, unavailable and retry independent of starting play. Desktop SHALL show the board beside the title; mobile SHALL scroll below it. Rows SHALL show rank, initials, five medal positions, active time and score; five-medal finishers SHALL additionally show a heart times remaining lives.

#### Scenario: Unavailable scores
- **WHEN** the endpoint fails
- **THEN** retry is offered while starting play remains available

#### Scenario: Score accepted
- **WHEN** submission succeeds
- **THEN** its mode board and confirmation appear

#### Scenario: Finisher row
- **WHEN** a result has five medals and four remaining lives
- **THEN** its row displays all five medals, active time, score and heart ×4

### Requirement: Direct terminal score routing
At run completion the client SHALL check the matching difficulty Top10 and open three-character entry directly for qualifying scores. Nonqualifying results SHALL appear below that difficulty's board on landing. Ranking-load failures SHALL preserve submission access; submission failures SHALL retain initials and run metadata for retry.

#### Scenario: Tenth-place tie
- **WHEN** a finished score ties tenth place in a full board
- **THEN** its personal final result appears below that difficulty board without initials entry

#### Scenario: Qualifying result
- **WHEN** a score exceeds tenth place or the matching board has fewer than ten entries
- **THEN** the three-character entry appears directly

### Requirement: Console runs are not ranked
The game SHALL NOT submit a console run's result to `/api/scores` and SHALL NOT open the initials entry for it, whatever its score. Its final score SHALL be shown beside the board, tagged `CONSOLE RUN · NOT RANKED`.

#### Scenario: High console score
- **WHEN** a console run ends with a score that would enter an empty or low board
- **THEN** no initials entry opens, no POST is sent, and the result shows with the unranked tag
