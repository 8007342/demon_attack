# Portrait comms lanes: two independent radio lanes, and chatter over the clouds

## Why
Operator round 6, T1 and T2 (`plan/operator-feedback-2026-11-17.md`), after a phone playtest:

- T1: "On portrait format (mobile friendly) the radio chatterbox double-toast system seems to be currently
  implemented as a single queue that displays the last two active messages, this is incorrect. It needs a double
  queue, once a message is displayed on one side it shall remain there until its expiration and closing, they're
  currently sliding to the left after the left toast closes down. There are also toasts with shorter text, being
  collapsed to their text height, but when another toast appears on the other side they both expand to fit both
  sizes, Please make the Portrait mode toasts a fixed size, and behave as TWO independent queues, with messages for
  humans and demons appearing on either side, but with their own timeout queue and persistence management."
- T2: "During level transitions we shall display one or two radio chatters, in full size as displayed in Landscape
  mode, in the middle, over the flowing clouds; either one of the longer radio chatters, or two of the smaller ones,
  or one with a comback (human-demon, or demon-human). For the radio chatter with comebacks make sure yo display them
  in Portrait mode in a combined toast display, the queues for these toasts shall support these cases. Please look at
  our gameflow and cinematic transitions advisory in our specs to keep these non invasive, we want them to preserve
  game flow."

## What Changes
- **Two lanes in the portrait dock** (`CommsHudStack`, the compact layout): humans (squad and ground link) on the
  left, the brood on the right, as in the landscape call tiles. Each lane has its own FIFO, timeout and persistence
  (`lib/comms/comms_lanes.dart`). A toast never moves sideways; it closes in place when it expires. The one-line
  ticker under the dock goes; a lane's waiting count shows as `+n` under it.
- **One fixed toast size**: 84 px tall (the dock's existing tallest card), half the dock wide. Text that does not fit
  scrolls inside the box in time with its reading time (reduced motion: a page at a time).
- **The comeback toast**: an exchange and its answer share one full-width toast (humans' half left, brood's half
  right). It waits for both lanes and reserves them; the pairing rule closes the blocking occupants in place once read,
  or after 1 s (design §3).
- **Transition chatter** (portrait): during a sector change's message slot, the lines that start on the channel show
  at the landscape tiles' size in the middle of the arena, over the clouds: one long line, or two short ones, or one
  line and its comeback (`lib/comms/comms_transition_chatter.dart`). It follows the slot's envelope, takes no input,
  stays clear of the ship's climb, and is gone at the Descent. The presenter may queue one extra short line when only
  one short line plays and a second fits inside the transition's clock; it never lengthens a transition.
- Landscape (the four call tiles) is unchanged.

## Impact
- Code: `lib/comms/comms_lanes.dart` (new), `lib/comms/comms_transition_chatter.dart` (new),
  `lib/comms/comms_view.dart` (dock, scroll box, chatter view), `lib/comms/comms_director.dart` (holds the lanes),
  `lib/widgets/transition_overlay.dart` (chatter selection and overlay), `lib/main.dart` (the dock's hidden set).
- Not touched: `lib/comms/comms_pacing.dart` and `art/comms/lines.json` (the parallel `bonus-briefing-clarity`
  change owns its quiet window and new lines). No line text or audio changes.
- Tests: `test/portrait_comms_lanes_test.dart` (new); `test/comms_layout_test.dart` and
  `test/comms_middle_ground_test.dart` move from the single-queue dock to the lanes.
- Specs: squad-comms (ADDED lanes, fixed size, comeback toast; MODIFIED "Phone transmissions"), arcade-presentation
  (ADDED "Transition chatter keeps the flow"). Archive after `cinematic-flow`, whose "One primary transition
  message" still says the transition's line plays on the dock (design §6).
