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
The landing page SHALL show the Demon Attack identity, Start action and inline Top10.

#### Scenario: Viewing the landing page
- **WHEN** the page loads
- **THEN** the visitor sees an original demon logo, Demon Attack, Start and the scoreboard without opening a separate screen

### Requirement: Flame foundation
The Flutter app SHALL embed a Flame game scene for its animated arcade background and gameplay.

#### Scenario: Rendering the landing page
- **WHEN** Flutter loads the landing page
- **THEN** Flame renders the starfield, and gameplay begins only on Start with audio gated by a user gesture
