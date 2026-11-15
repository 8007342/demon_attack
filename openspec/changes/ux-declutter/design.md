# Design: ux-declutter

## 1. Inventory (what had a bar, where, what happened)
| # | Element | Where (before) | Decision |
|---|---|---|---|
| 1 | Transition strip: sector pips, `WAVE 2/3 · REINFORCEMENTS` / `JUMP → RINGFALL · 42%` / `RECOVERY WINDOW · COLLECT CARGO · 2s` / `SECTOR 1/5 CLEAR · ROUTE I`, wave pips, phase hairline | `TransitionStrip` in `lib/widgets/interlude_card.dart`, mounted by `TransitionPresenter.build` (`lib/widgets/transition_overlay.dart`); `stripInset` offsets in `lib/main.dart` | Removed (widget, label, inset). |
| 2 | Carrier alert bar | `LinearProgressIndicator` in `TransitionPresenter._bossAlert` | Removed; the alert text stays. |
| 3 | Power timer rows (`SPREAD 9s` + bar) and `HOMING` pips | `PowerStatus` (`lib/widgets/power_status.dart`) in the pilot console | Rows removed; glyph kept (§2). |
| 4 | Slider rail, notch, ticks, carriage | `ConsolePainter` (`lib/main.dart`) | Removed; the finger pillar stays as touch feedback. |
| 5 | Two-segment volume meter | `LevelToggle` (`lib/widgets/level_toggle.dart`) in HUD and menu | Removed; icon and level word (`FULL`/`LOW`/`OFF`) stay. |
| 6 | Signal-strength bars on radio tiles | `CommsTilePainter` (`lib/comms/comms_view.dart`) | Removed; the live dot stays. |
| 7 | Creature health pips | `DemonScene` creature pass (`lib/game/scene.dart`) | Removed (§2). |
| 8 | Supply crate durability pips | `DemonScene._paintSupplyCrate` | Removed (§2). |
| 9 | Loading spinners | score board and ranking overlay (`lib/main.dart`), credits (`lib/ending/ending_page.dart`) | Replaced by `LOADING SCORES…`, `RANKING…`, `LOADING CREDITS…`. |

Looked at and kept, because they are not progress UI:
- HUD heart inventory (`0/4` per heart): an item count with icons, not a fill bar.
- Story card storyboards: the travel route map shows the ship flying a leg between sector nodes. It is an
  illustration on a card fluid-transitions kept, and `cinematic-flow` will redesign that card; the arrival
  storyboard's pip row is painted only for `RunMode.transition`, which never shows a story card in the game.
- Cinematic letterbox bars in `scene.dart` (framing, not progress).
- Ground weapon channel fill (gargoyle-ground-army): an in-world telegraph in `ground_*` painters, owned by other
  workstreams and not UI.
- Dev console, gallery and review studio: tools, untouched.

## 2. Information that had a bar: kept or dropped
Default is to drop. Kept only where the player needs it during play, and then without a bar:
- **Which powers are active** (essential, decides how to fly): kept as the composite glyph's layers, as before.
- **A power about to end** (essential enough: losing shield unannounced costs a life): kept as an *icon state*, the
  layer blinks at 4 Hz in its last 3 s. The blink is derived from the remaining time (`(t * 4).floor().isOdd`), so it is
  deterministic and freezes with pause. Exact seconds are dropped from the screen and stay in the semantics label.
- **Homing missiles left**: already drawn as pylon missiles on the glyph; the separate pip row was a duplicate.
- **Wave number and sector**: the HUD already shows `<SECTOR NAME>` and `NORMAL · WAVE n / N`; the strip duplicated it.
- **Salvage window**: the pilot console already says `COLLECT POWERUPS · WEAPONS SAFE` while piloting without
  combat; the seconds countdown is dropped.
- **Jump percentage, phase hairline, carrier alert bar**: dropped. Transitions are timed by the game and cannot be
  sped up except by skipping the card (still `TAP TO SKIP`).
- **Volume level**: the level word under the icon carries it.
- **Creature and crate hit points**: dropped. Hits read from the white hit flash, and elite creatures still shed one
  armour level per hit; the atmosphere-and-swarms rule (gear hidden in fog) is trivially kept for pips.
- **Radio signal strength**: carried no game information; dropped.

## 3. Spec bookkeeping
fluid-transitions is not archived; its delta added "Slim transition progress". That requirement is removed from its
delta (with a pointer here) so archiving it cannot reintroduce the strip. This change modifies the main spec's
"Layered power status glyph" and adds "No progress bars in the game UI".

## Review frames
`test/ux_declutter_test.dart` reuses the fluid-transitions harness (`snap`, `FLUID_RENDER`, `FLUID_FONTS`) and renders
opening tip, combat with three powers (shield blinking off), wave change, sector clear, travel and carrier alert at
360×780 and 1280×720. Before frames come from the same test run on the base commit with the assertions disabled.
