# Tasks

## 1. Audit and design
- [x] 1.1 Audit every transition overlay, what shows at once and for how long (design.md §1)
- [x] 1.2 Define the one-primary-message rule, the progress strip and the interlude window

## 2. Planner
- [x] 2.1 `InterludePlanner`: opening tip, strict tip/radio alternation, seeded items, no back-to-back repeats
- [x] 2.2 Radio pool from the recorded bank by category (briefing, banter, joke, taunt), lineup, sector officers and mood
- [x] 2.3 Reading time from word count; cards only planned when they fit their window

## 3. Presentation
- [x] 3.1 `InterludeFrame`, `TipInterludeCard`, `RadioInterludeCard`, `TransitionStrip` (desktop-sized in the cabinet, full width on phones)
- [x] 3.2 `TransitionPresenter`: windows across travel and arrival, radio adoption of the squad channel's line or its own `commsPlay` pick, silent tip, skip
- [x] 3.3 Merge: sector-secured card carries the next leg's briefing; strip replaces progress bars, wave banner and salvage banner; one carrier alert
- [x] 3.4 `lib/main.dart`: old transition UI removed, delimited hooks; radio dock hidden under a card; call tiles dim under a silent tip

## 4. Verification
- [x] 4.1 Tests (`test/fluid_transitions_test.dart`): one primary message, seeded alternation without repeats, readable windows, skip, layout at 390 / 900 / 1440 px
- [x] 4.2 `flutter analyze` and the full `flutter test`
- [ ] 4.3 Playtest with music and voice in the browser; tune fade length and reading speed by ear
