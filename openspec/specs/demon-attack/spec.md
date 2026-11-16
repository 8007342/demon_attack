# Demon Attack

## Purpose
A mobile web game inspired by the 1982 arcade classic, built live with Flutter and Flame. The app offers a playable arcade title and a repeatable campaign.

## Requirements

### Requirement: Mobile web landing page
The app SHALL run in Flutter on mobile web with readable content and a quiet dark background.

#### Scenario: Opening on a phone
- **WHEN** a visitor opens the page at 390 CSS pixels wide
- **THEN** the title and play screens fit without horizontal scrolling

### Requirement: Construction identity
The landing page SHALL show the Demon Attack identity, a Normal start action and inline Top10. Easy and Hard start actions and matching board tabs SHALL appear only when unlocked. A valid interrupted checkpoint SHALL expose Resume Game, using its saved difficulty independently of current board selection.

#### Scenario: Viewing the landing page
- **WHEN** a new visitor opens the page
- **THEN** the original demon logo, title, Normal start and Normal board are visible

#### Scenario: Resume selection
- **WHEN** a player selects Resume Game while another board is selected
- **THEN** the checkpoint resumes in its original difficulty

### Requirement: Flame foundation
The Flutter app SHALL embed a Flame game scene for its animated arcade background and gameplay.

#### Scenario: Rendering the landing page
- **WHEN** Flutter loads the landing page
- **THEN** Flame renders the starfield, and gameplay begins only on Start with audio gated by a user gesture
