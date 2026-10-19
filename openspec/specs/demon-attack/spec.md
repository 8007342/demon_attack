# Demon Attack

## Purpose
A mobile web game inspired by the 1982 arcade classic, built live with Flutter and Flame. The first release is an event landing page.

## Requirements

### Requirement: Mobile web landing page
The app SHALL run in Flutter on mobile web with readable content and a quiet dark background.

#### Scenario: Opening on a phone
- **WHEN** a visitor opens the page at 390 CSS pixels wide
- **THEN** the content fits without horizontal scrolling and displays Under Construction

### Requirement: Live coding announcement
The landing page SHALL display “Coded Live Oct 20”.

#### Scenario: Viewing the announcement
- **WHEN** the page loads
- **THEN** the visitor sees Coded Live Oct 20 as the primary heading

### Requirement: Event link
The landing page SHALL provide an accessible link to https://eventship.com/event/building-a-game-in-a-framework-i-ve-never-touched.

#### Scenario: Joining the live build
- **WHEN** a visitor activates Join the live build
- **THEN** the event URL opens in a new browser tab

### Requirement: Flame foundation
The Flutter app SHALL embed a Flame game scene as its background.

#### Scenario: Rendering the landing page
- **WHEN** Flutter loads the landing page
- **THEN** Flame renders a quiet static starfield behind the content without audio or animation
