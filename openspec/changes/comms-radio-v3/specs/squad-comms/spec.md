# Squad comms

## ADDED Requirements

### Requirement: One sequenced radio channel
Lines SHALL play one at a time with a short natural gap. A playing line SHALL never be cut, except by a trigger marked urgent: a sentinel's dive, the shield running out, or a ground breakthrough.

#### Scenario: Burst of calls
- **WHEN** a briefing, an ally's plea and pilot chatter arrive in the same frame
- **THEN** they play in priority order, one after another, and none is cut short

#### Scenario: Urgent warning
- **WHEN** a sentinel's dive tell begins during a pilot's line
- **THEN** the pilot's line stops and the warning plays at once

### Requirement: Two-party exchanges
An exchange trigger SHALL play its first side's line and then the other side's reply. No other non-urgent line SHALL start between the two turns.

#### Scenario: Victory and the boss's answer
- **WHEN** the carrier falls
- **THEN** the Admiral's line plays, and the Warden's growled reply follows before anything else

### Requirement: The brood is heard
Demon lines SHALL rank higher in the queue while the brood's share of airtime is under 30 %. After 20 s of combat without a demon line, the director SHALL raise brood chatter.

#### Scenario: Busy level
- **WHEN** five minutes of frequent pickups, ground events, dives and waves are simulated
- **THEN** the brood holds more than 15 % of the airtime and no line is cut

### Requirement: Losing a life
On a lost ship, several short demon celebration grunts SHALL play, overlapping for about a second (at most three voices). Once the next ship launches, the fleet SHALL talk about it without blocking play.

#### Scenario: Regroup
- **WHEN** `playerDestroyed` (or the lost ship) and then `regroupStart` arrive
- **THEN** two or three brood grunts overlap briefly, and a respawn line like "Spare ship on deck four, launch!" follows the relaunch

### Requirement: Smooth lip-sync
Mouth frames SHALL follow a smoothed openness envelope. Each mouth shape SHALL be held for at least two frames (133 ms), and the mouth SHALL end closed. Talk frames SHALL differ only inside one fixed mouth box per character.

#### Scenario: No flicker
- **WHEN** any shipped clip plays
- **THEN** no mouth shape lasts a single frame

### Requirement: Phone transmissions
On phones, a transmission line that plays during a transition SHALL show as a full-size card with the caller's portrait, backdrop, name and subtitle. The card SHALL replace the transition art and SHALL never cover the HUD.

#### Scenario: Travel briefing
- **WHEN** the ship travels to the next sector on a 390 × 844 screen
- **THEN** the Admiral's mission transmission shows full size with a lip-synced portrait

### Requirement: Immersive language
No spoken line or gloss SHALL mention screens, phones, displays, UI, buttons or input gestures. Lines SHALL use in-world spatial words such as "coming in high", "far ahead", "on your six" and "below us".

#### Scenario: Regression guard
- **WHEN** `lines.json` is scanned
- **THEN** none of screen, phone, display, tap, swipe, button, HUD, UI or click appears
