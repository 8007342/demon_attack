# Arcade presentation: the run record

## ADDED Requirements

### Requirement: End-of-run medal screen shows the run record
At the end of a run, the screen that shows the final score (and the initials entry, when the score qualifies) SHALL show the run record: the medals earned of five, the run's modifiers by name (or "STANDARD RUN" when it had none), the play date, the play time and the score. It SHALL fit a 360-wide phone without overflow and take under a fifth of a 360 × 780 screen. Board rows SHALL add one small line with a record's date and modifiers when it has either.

#### Scenario: A bonus run ends
- **WHEN** a run that met Stormfront ends with three medals
- **THEN** the screen shows three of five medals, "STORMFRONT", today's date, the run's time and its score

#### Scenario: A narrow phone
- **WHEN** the run had the most modifiers a record can carry and the screen is 360 wide
- **THEN** the record wraps its tags and nothing overflows
