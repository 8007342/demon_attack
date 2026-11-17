# Render run: fire-rate-tune review sheet (2026-11-17)

Sheet: `art/contact/fire-rate-tune.png` (1500 × 4432). Rebuild it with
`flutter test --concurrency=1 --run-skipped --tags review --dart-define=FIRE_RATE_CONTACT=true test/fire_rate_tune_review_test.dart`.
It is a deterministic model render through the real scene (seed 1982, Hard, route 3, sector 3); no GPU, no picks
from a batch.

## Layout
- Row 1, half size: one dense frame, four times. Base gun before | after, Rapid before | after. The demons and
  hostile shots are the same frame; only the player's stream differs.
- Rows 2–5: eight consecutive displayed frames of an 80 × 480 unit column over the ship, Rapid:
  1. before at 60 fps (390 u/s, 0.105 s volleys);
  2. after at 60 fps (480 u/s, 8-step volleys);
  3. before at 30 fps (every second model step);
  4. after at 30 fps.

## What to look for, and the call made
- **Clutter (row 1).** Before, the Rapid column holds 11–12 shots between the ship and the swarm; after, 7–8, with
  even gaps. Kept: this is the readability the operator asked for.
- **Spacing (rows 2–5).** Before, one gap in three is a step longer (39 against 45.5 units); after, every gap is 64
  units. Kept.
- **30 fps (rows 4–5).** Before, a shot moves 13 units per frame against 41-unit gaps (ρ = 0.32): neighbouring frames
  can be read as a shot sliding back to its neighbour's place. After, 16 against 64 (ρ = 0.25): each shot's next
  position is clearly its own.
- **Not fixed here (renderer, `phone-performance`):** at 30 fps a shot still jumps more than its own length, so there
  is no smear; and the sprite's two animation frames flip by y band, which the strips show as alternating heads.
  Both are in design §4.
- **Pick:** the sheet as rendered. The ship sits near the left wall in this frame, so the column is at the left edge;
  re-framing it did not change what the strips show, so it was left as is.
