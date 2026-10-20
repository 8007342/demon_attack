# high-scores

## Purpose
Persist a shared Top10 scoreboard with constrained arcade initials and recoverable network failures.

## ADDED Requirements

### Requirement: Durable Top10
A Cloudflare Durable Object SHALL persist the ten highest scores in descending order and return them from a same-origin endpoint.

#### Scenario: Reload scores
- **WHEN** a valid score has been accepted and a new request loads the board
- **THEN** the persisted score appears if it remains in the Top10

### Requirement: Three-wheel entry
Score entry SHALL offer exactly three rotating wheels containing only A–Z and 0–9 and no free-text name input.

#### Scenario: Choose initials
- **WHEN** a player adjusts the three wheels
- **THEN** the submission contains exactly three permitted characters

### Requirement: Validation and failure handling
The API SHALL reject malformed initials and noninteger, negative, or excessive scores. The client SHALL show loading, empty, and unavailable states and retain failed submissions for retry.

#### Scenario: Offline submission
- **WHEN** a score submission fails
- **THEN** the player can retry without reentering initials or losing the result
