# Demon Attack

## Purpose
A mobile web game inspired by the 1982 arcade classic, built live with Flutter and Flame. The first release is an construction landing page.

## Requirements

### Requirement: Mobile web landing page
The app SHALL run in Flutter on mobile web with readable content and a quiet dark background.

#### Scenario: Opening on a phone
- **WHEN** a visitor opens the page at 390 CSS pixels wide
- **THEN** the content fits without horizontal scrolling and displays Under Construction

### Requirement: Construction identity
The landing page SHALL display only a demon logo, “Demon Attack” as the primary heading, and “Under Construction” over the starfield.

#### Scenario: Viewing the landing page
- **WHEN** the page loads
- **THEN** the visitor sees the logo, Demon Attack, and Under Construction without event announcements, links, or footer content

### Requirement: Flame foundation
The Flutter app SHALL embed a Flame game scene as its background.

#### Scenario: Rendering the landing page
- **WHEN** Flutter loads the landing page
- **THEN** Flame renders a clearly visible, quiet static starfield behind the content without audio or animation
