# Design: portrait comms lanes

Inputs: operator round 6, T1 and T2 (`plan/operator-feedback-2026-11-17.md`); the cinematic-flow advisories
(`openspec/changes/cinematic-flow/design.md` §1, §2.1, §2.2 and §10.3; `openspec/specs/arcade-presentation/spec.md`
"One primary transition message"); `plan/transition-research.md` (one normalized clock). No outside research is
claimed here: every number below is this project's own measurement or choice.

"Portrait" means the compact dock layout (`CommsLayout.side == false`): phones held upright, and also short
landscape windows such as a phone held sideways (740 × 360). The wide layout with four call tiles in the margins is
"landscape" and does not change.

## 1. Before

`CommsHudStack.dockEntries` sorted every active message by start, paired linked ones, then filled two halves of one
row, oldest first. When the left card expired, the right one became "oldest" and slid into the left half. The row was
an `IntrinsicHeight` with `_PortraitRow` sizing each card to its text, so both cards jumped to the taller one's height
as soon as a second card appeared. Lines that did not fit waited in a one-line ticker under the dock. Text past four
lines was cut with an ellipsis.

## 2. Two lanes (`lib/comms/comms_lanes.dart`)

- **Sides.** Humans (fleet and ground link) on the left, the brood on the right (`CommsLanes.laneOf`). This matches the
  landscape tiles, where the brood is always in the right column. The ground link sits on the right in landscape but
  on the left here: the operator asked for "humans and demons on either side".
- **State.** `CommsLanes` lives on the director (`director.lanes`) so it persists across frames, and is cleared by
  `reset()`. The dock calls `sync(now, active, queue:, hidden:)` each build. Pure Dart, exact timestamps.
- **Intake.** Each message that has started is taken once, in start order. A line already over is skipped. Hidden
  messages (the urgent-mission card's turns, the transition chatter's lines) are not taken while hidden.
- **Per lane.** A FIFO: a line waits until its lane is free; nothing later jumps ahead of it. A lane never borrows
  the other side. At most two lines wait per lane (the oldest is dropped), and a waiting line is dropped 2 s after
  its own end (stale).
- **Persistence.** A toast closes at the later of its message's `endsAt` (speech, hold, reading time; unchanged) and
  `shownAt + readingTime`, so a line that waited still gets its full reading time once shown. It fades out in place
  over the last 0.18 s; the next toast of that lane fades in where it was.
- **Waiting count.** A lane with lines waiting shows `+n` under it (replacing the ticker).

## 3. The comeback toast and the pairing rule

- An exchange (a message with `reply`, or an answer with `inReplyTo`) is one toast across both lanes
  (`comms-conversation`): the human half left, the brood half right; two of one side put the opening on the left.
  Before the answer starts its half shows the speaker's portrait and `…`. The label under it reads `A → B`.
- **It waits for both lanes and reserves them.** While it waits, nothing new enters either lane.
- **Pairing rule (preemption).** A single toast blocking the pair closes now, in place, if it has been on screen for
  its reading time and is no longer speaking; any other blocking toast closes once the pair has waited
  `pairWait` = 1.0 s. "Close" is always the usual in-place fade, never a move. So the combined toast appears at most
  1.18 s after the opening starts, and usually at once.
- Why this is enough: the director already starts an exchange only when every line on screen will have ended before
  the answer begins (`_screenFree`), so the answer always plays inside its combined toast.
- The toast stays until the answer has had its hold and reading time. If the answer is still queued, the toast waits
  for it until the answer's `expiresAt`; a withdrawn answer releases it.

## 4. Fixed size, and long lines

- **Size: 84 px tall** (`CommsHudStack.stripHeight`, the dock's tallest card since carrier-hatches §A12), half the
  dock wide (a comeback: the full width). Keeping 84 px means the dock's footprint (`maxHeight`, 104 px with the label)
  does not grow, so the urgent-mission card, the heart notice and the ship row keep their room.
- **Fits.** The 40 px portrait plus four lines at 14.5 px (`commsStripFont`, raised for readability in §A12). On a
  360 px phone a half lane's text column is about 112 px, about 12 monospace glyphs a line, so about 48 characters
  with the speaker tag. Every one-line-target line (`commsOneLine`, ≤ 28 characters) fits with room to spare.
- **Longer lines scroll** (`CommsScrollBox`). Of the bank's 480 human texts the median is 43 characters, the 90th
  percentile 61 and the longest 88 (`jq` over `art/comms/lines.json`, 2026-11-17). Shrinking the font would undo §A12,
  and a taller box would push the dock toward the ship row, so the words keep their size and the box scrolls: the
  first lines hold for 30 % of the toast's reading window, the text glides up until 80 %, and the last lines hold.
  Reduced motion jumps a page at a time instead. Text that fits is centred vertically. Nothing is cut with an ellipsis
  any more.
- Landscape keeps its tiles; the one-line full-width rule of §A12 no longer applies in portrait, since every lane is
  half the dock.

## 5. Transition chatter (`lib/comms/comms_transition_chatter.dart`)

- **When.** A sector change, carrier arrival or carrier victory: Pursuit, from its start (`descentAt - pursuitSeconds`)
  to the Descent (`plan.descentAt`). Portrait only (the landscape tiles already show the lines at full size), and not
  on the way into a bonus level (its urgent-mission card is that transition's radio). It opens at Pursuit's start, not
  at the `slot` beat (+0.5 s), because the squad's `levelClear` exchange, the natural "line and its comeback", starts
  on Pursuit's first frame; a later open would show it on the dock first and then move it. A line started up to
  0.1 s before the open counts (the event and the open can fall in neighbouring frames).
- **What it takes,** in start order, from the lines that start on the channel after it opens:
  - the first line, unless it answers an exchange opened before (that pair stays on the dock) or starts later than
    2 s before the Descent (too late to read);
  - then its comeback (the opening's `reply`), whatever its length; or
  - if the first line is short (≤ 48 characters of text or SIGINT gloss) and unlinked, one more short unlinked line;
  - nothing else. A long line stands alone. Lines it passes over stay on the dock's lanes.
- **The extra short line.** When only one short line stands and the channel's queue is empty, the presenter queues one
  short, recorded, non-exchange bank line (briefing, banter, joke or taunt; preferring the other side, then the
  shortest) if it fits: its start after the first line's speech and the grace gap, plus its `needs`, must end before
  the Descent less one fade. Its `ttl` is the room left after it, so the director drops it rather than run past the
  Descent. One try per transition. It never extends Pursuit (`slotExtra` is still sized for the slot's own line).
- **Layout.** One long line: one card up to 300 px wide (the landscape tiles' widest). Otherwise two cards side by
  side, each up to 300 px or half the width: the human on the left, the brood on the right (two of one side in start
  order). A short first line holds its half from the start, so a second line fills the other half and nothing moves.
  A comeback's two cards share one frame with the `A → B` label. A card is the landscape tile: tag row, square
  lip-synced portrait (`_TransmissionPortrait`), and a 76 px subtitle box at `commsTileFont`.
- **Where.** Centred horizontally, and vertically between the dock's tallest footprint (104 + 4 px) and the ship's top
  at its highest climb less 40 arena units. It scales down to fit that band, never over it.
- **Never twice.** The dock leaves the chatter's lines out (`TransitionPresenter.chatterHidden`), including a comeback
  waiting to start, and keeps leaving them out after the slot closes until they leave the channel. A line shown in the
  middle never reappears on the dock.

## 6. The cinematic-flow advisories, point by point

| Advisory | How the chatter keeps it |
|---|---|
| One clock: actors read envelopes (§1) | Opacity is a pure function of the flow clock: in over 0.3 s from Pursuit's start, out over the `slot` beat's last 0.5 s; nothing keeps its own timer. |
| Never an art beat and an instruction at once (§2.1) | It opens at Pursuit's start, 3 s before the swap (1.5 s with reduced motion) (where the radio's level-clear line already played), and adds nothing at the swap. |
| No black, ship continuity (§2.1) | Translucent cards over the cloud; the ship's climb band is kept clear. |
| No floating text (§10.3) | Every word is inside a framed radio card with a portrait (a window). |
| Skip within one frame (§2.2) | `IgnorePointer`: taps reach the arena's skip; skipping jumps to the Descent, where the envelope is 0. |
| Reading time inside the transition | No extension beyond the slot's own `slotExtra`; the extra short line must fit or is not queued. |
| Gone before play resumes | The `slot` beat ends at `descentAt`, before the next sector's swarm wheels in. |

`cinematic-flow`'s "One primary transition message" still says the transition's line plays "on the comms dock". That
change is not archived yet, so this one does not modify that requirement; it adds "Transition chatter keeps the flow"
in arcade-presentation and rewrites squad-comms' "Phone transmissions". When both are archived, the dock clause
should read "on the comms dock, or in portrait over the clouds (squad-comms, Phone transmissions)". Archive this
change after `cinematic-flow`.

## 7. Coordination with `bonus-briefing-clarity`

That change owns the bonus briefing, `comms_pacing.dart` (a quiet window) and new lines in `art/comms/lines.json`.
This change touches neither file. The urgent-mission card's turns keep reaching the dock through the existing `hide`
set, and the chatter does not open on a transition into a bonus level (the card is that slot).

## 8. Decisions taken on the operator's behalf

1. Humans left, brood right (as the landscape tiles).
2. 84 px fixed toasts with scrolling text, not a smaller font or a taller dock.
3. The pairing rule: read occupants close at once, unread ones after 1 s, always in place.
4. Short means ≤ 48 characters.
5. Transition chatter in portrait only; landscape keeps its side tiles.
6. One extra short line at most, and only inside the existing transition time.
