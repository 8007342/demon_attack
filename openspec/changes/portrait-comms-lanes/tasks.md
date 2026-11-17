## 1. Portrait lanes

- [x] 1.1 `lib/comms/comms_lanes.dart`: two lanes (humans left, brood right), per-lane FIFO, timeout and persistence, stale drop and a cap of two waiting per lane; held on the director, cleared by `reset()`
- [x] 1.2 The comeback toast across both lanes, and the pairing rule (read occupants close at once, unread ones after 1 s, always in place)
- [x] 1.3 `CommsHudStack`: lanes instead of the single queue; fixed 84 px toasts; `+n` waiting counts replace the ticker
- [x] 1.4 `CommsScrollBox`: long lines scroll inside the fixed box in time with their reading time (a page at a time with reduced motion)

## 2. Transition chatter

- [x] 2.1 `lib/comms/comms_transition_chatter.dart`: selection by length (one long, two short, or a line and its comeback)
- [x] 2.2 `TransitionPresenter`: opens the chatter at Pursuit's start (portrait only, not into a bonus level), queues at most one extra short line inside the transition's clock, hides the chatter's lines from the dock for their whole life
- [x] 2.3 `TransitionChatterView`: landscape-tile cards centred over the clouds, between the dock and the ship's climb, on the flow clock, `IgnorePointer`

## 3. Validation

- [x] 3.1 `test/portrait_comms_lanes_test.dart`: lane independence, waiting per lane, stale and capped queues, the comeback toast and pairing rule, fixed size and scrolling, a five-minute busy channel (bounded loop), the chatter selection rules, and the chatter on the page at 390 × 844 and 360 × 640
- [x] 3.2 `test/comms_layout_test.dart` and `test/comms_middle_ground_test.dart` moved to the lanes
- [x] 3.3 Gates (CLAUDE.md §2)
- [ ] 3.4 Phone playtest of the lanes and the chatter (operator)
