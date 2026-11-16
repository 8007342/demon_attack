# Demon Attack changes

## MODIFIED Requirements

### Requirement: Mobile web landing page
The app SHALL run in Flutter on mobile web with readable content and a quiet dark background.

#### Scenario: Opening on a phone
- **WHEN** a visitor opens the page at 390 CSS pixels wide
- **THEN** the title and play screens fit without horizontal scrolling

### Requirement: Construction identity
The landing page SHALL show the Demon Attack identity and provide Start and Top10 actions.

#### Scenario: Viewing the landing page
- **WHEN** the page loads
- **THEN** the visitor sees an original demon logo, Demon Attack, and controls to start or view scores

### Requirement: Flame foundation
The Flutter app SHALL embed a Flame game scene for its animated arcade background and gameplay.

#### Scenario: Rendering the landing page
- **WHEN** Flutter loads the landing page
- **THEN** Flame renders the starfield, and gameplay begins only on Start with audio gated by a user gesture
