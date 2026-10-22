## MODIFIED Requirements

### Requirement: Durable Top10
A Cloudflare Durable Object SHALL persist independent Easy, Normal and Hard Top10 boards, each ordered by descending score with stable ties. Each result SHALL retain initials, score, difficulty, zero to five medals, accumulated active time and remaining lives for completed campaigns. Existing entries SHALL remain Normal results with default metadata.

#### Scenario: Reload scores
- **WHEN** a valid score has been accepted and its mode board is loaded
- **THEN** the persisted result appears if it remains in that mode Top10

#### Scenario: Independent pruning
- **WHEN** a Hard result enters its Top10
- **THEN** no Easy or Normal result is removed

### Requirement: Validation and failure handling
The API SHALL reject malformed initials, invalid modes, noninteger or out-of-range score/medals/time/lives and inconsistent completion metadata. Legacy requests SHALL default to Normal with absent achievement metadata. The client SHALL show loading, empty and unavailable states and retain failed submissions for retry.

#### Scenario: Offline submission
- **WHEN** a submission fails
- **THEN** retry preserves initials and the complete run result

#### Scenario: Legacy client
- **WHEN** a valid request supplies only initials and score
- **THEN** it is accepted as a Normal result with default metadata

### Requirement: Inline landing Top10
The landing page SHALL display separate unlocked-mode Top10 tabs, with loading, empty, unavailable and retry independent of starting play. Desktop SHALL show the board beside the title; mobile SHALL scroll below it. Rows SHALL show rank, initials, five medal positions, active time and score; five-medal finishers SHALL additionally show a heart times remaining lives. Successful submission SHALL return to its mode board.

#### Scenario: Unavailable scores
- **WHEN** the endpoint fails
- **THEN** retry is offered while starting play remains available

#### Scenario: Score accepted
- **WHEN** submission succeeds
- **THEN** its mode board and confirmation appear

#### Scenario: Finisher row
- **WHEN** a result has five medals and four remaining lives
- **THEN** its row displays all five medals, active time, score and heart ×4
