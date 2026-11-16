# Proposal

## Why
Collecting a new temporary power currently replaces the previous one, preventing the intended combinations in harder cycles. Preserve independent effects and make their combined state immediately readable.

## What Changes
- Spread, rapid fire and shield run concurrently with separate nine-second timers.
- Recollecting one type refreshes that timer only; expiry and shield consumption remove only the relevant effect.
- A layered pixel glyph combines the three modifiers without hiding them, alongside individual names, countdowns and duration bars in the controller panel.
- Preserve pause, recovery and continuous-cycle timer behavior; a new run clears all effects.

## Capabilities
### New Capabilities
None.
### Modified Capabilities
- `arcade-combat`: independently timed combined powers and shield consumption.
- `arcade-presentation`: composite active-power glyphs and independent visible countdowns.

## Impact
Dart combat model, shield rendering, Flutter controller status, model/widget/visual tests and plan guides. No API, score data or asset-format changes. Validate and refresh the local preview, then ship the final fix through game and main under the established session release workflow.
