# Tasks

## 1. Audit
- [x] 1.1 Inventory every bar, strip, timer bar, meter, pip row and spinner in the game UI (design.md §1)
- [x] 1.2 Decide per item what information is kept and how (design.md §2)

## 2. Removal
- [x] 2.1 Remove `TransitionStrip`, its label and the `stripInset` offsets (transition_overlay, interlude_card, main)
- [x] 2.2 Remove the carrier alert progress bar
- [x] 2.3 `PowerStatus`: glyph only, expiry blink in the last 3 s, seconds in semantics
- [x] 2.4 `ConsolePainter`: remove the slider rail, notch, ticks and carriage
- [x] 2.5 Remove the volume segment meter, radio signal bars, creature and crate pips
- [x] 2.6 Replace loading spinners with a word
- [x] 2.7 Drop "Slim transition progress" from the fluid-transitions delta

## 3. Verification
- [x] 3.1 `test/ux_declutter_test.dart`: no bars at 360×780 and 1280×720 through opening, combat with powers, wave
      change, sector clear, travel and carrier alert; review frames before and after
- [x] 3.2 Update fluid-transitions, power status and pilot console tests
- [x] 3.3 `flutter analyze` and the full `flutter test`
- [ ] 3.4 Operator playtest on a phone
