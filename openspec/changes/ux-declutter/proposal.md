# Proposal: ux-declutter (no progress bars in the game UI)

## Why
Operator playtest, 2026-11-15 (plan/operator-feedback-2026-11-15.md, W5): "Our current UX is covered with junk, please
remove everything with a progress bar on it." The playtest on an iPhone 12 Pro Max found the arena framed by meters:
a wave strip under the HUD (`KRYBOR · WAVE 1/3`, sector pips, wave pips and a hairline), a timer panel in the pilot
console (`SPREAD 5s` with a bar per power), a bar under the carrier alert, a slider rail under `SLIDE TO PILOT`, and
small meters (volume segments, radio signal bars, health pips) around the edges.

This change only removes clutter. The later `cinematic-flow` change (W5, part b) redesigns transitions as one
continuous swarm; nothing here redesigns a transition.

## What Changes
Removed from the game UI (design.md §1 lists every item with its file):
- **Transition progress strip** (`TransitionStrip`, fluid-transitions): sector pips, the status line, wave pips and
  the phase hairline over the arena during salvage, sector clear, travel and wave entrances.
- **Carrier alert progress bar** under `BREAK THE SHIELD · FIRE INTO THE OPEN HATCH`.
- **Power-up timer rows**: name, seconds and duration bar per power, and the `HOMING` pip row. The composite glyph
  stays; a layer blinks in its last 3 s.
- **Pilot console slider rail**: the track line, centre notch, quarter ticks and the carriage on it. The soft pillar
  under the finger stays.
- **Small meters**: the two-segment level meter in the music/speech toggles, the signal-strength bars on radio tiles,
  the violet health pips over creatures and the durability pips under supply crates.
- **Loading spinners** on the score board, ranking screen and ending credits, replaced by one quiet word.

Kept: the HUD's `WAVE n / N`, sector name, lives and heart inventory; story cards and storyboards; the interlude cards;
the cinematic letterbox; dev console (`/console`), gallery and review studio (tools, not the game UX).

## Capabilities
### Modified Capabilities
- `arcade-presentation`: the layered power status glyph loses its per-effect countdown and bar; a new requirement
  forbids progress bars, strips and meters in the game UI. It supersedes fluid-transitions' "Slim transition
  progress" requirement (removed from that change's delta).

## Impact
`lib/widgets/transition_overlay.dart`, `lib/widgets/interlude_card.dart`, `lib/widgets/power_status.dart`,
`lib/widgets/level_toggle.dart`, `lib/comms/comms_view.dart`, `lib/game/scene.dart` (two pip loops),
`lib/main.dart` (strip insets, console rail, spinners), `lib/ending/ending_page.dart` (spinner). No model, audio or
balance change. Tests: new `test/ux_declutter_test.dart` (with review frames); updated
`test/fluid_transitions_test.dart`, `test/power_status_test.dart`, `test/pilot_console_content_test.dart`.
