# Design: bonus-briefing-clarity

## 1. Why the box closed (diagnosis on `game` at b29c9749)
`BonusBriefing.update` closed the card on `dismissed || ending || _done(director, now)`. `_done` was true once every
scripted turn had ended **or had expired in the queue**: "A turn that is neither [started nor queued] has expired,
and so has everything after it." Two paths closed the card early:
1. **Overlapping chatter.** The script's first turn queues behind whatever is on air at the slot's start (the
   sector-clear celebration, a transmission). When that ran long, or an urgent warning took the channel, the turn
   passed its time-to-live, `_done` became true, and the card closed within a frame. This is the operator's report.
2. **A quick script.** Three short written turns could finish before the brief's reading time. `readFor` gated only
   the hold at the flight's end (mission-medals), never the close.

The brief was also a single two-clause sentence ("Lure the lightning onto the swarm. When the air hums over you,
slide out."), and the card's three voices (invite, dare, retort) competed with it.

## 2. Instructions
Each `BonusLevelDef` carries a goal (`brief`, ≤ 40 characters) and a how-to line (`how`, ≤ 60 characters). Words are
short (≤ 9 letters; `test/bonus_briefing_test.dart` checks it). The controls are the game's own: drag or the arrow
keys move, and the gun fires by itself, so the how-to line says where to fly, not which button to press.

| Level | Goal (bold) | How-to | Checked against |
|---|---|---|---|
| Supply Run | Pop the crates, catch the prizes! | Shoot a crate till it bursts, then fly under what falls. | `SupplyCrate.maxHp` 3 (several hits), `killDrops: false`, cargo falls as a `Pickup` caught at the ship |
| Stormfront | Let the lightning zap the demons! | Sit under them. When the orange mark blinks, slide away! | `StormCell`: 68 % of tells sample the ship's x once; `StormPainter._paintTell` blinks an amber (`0xFFFFB45A`) bracket on the ship row; the bolt strikes that column, the swarm above it and the ship if it stayed |

Pictograms: Supply Run keeps its five-step strip (mission-medals). Stormfront gets `StormfrontHowTo`, four steps in
the level's colours: ship under a demon, then the amber mark under the ship, then the ship sliding away, then the
bolt striking the demon. It costs one `CustomPainter`, no art. Both are shown when the card has the room (`tight`
150 px); on a sideways phone the goal and how-to lines drop to one line each.

## 3. The card's life
- **Opens** at the transition's radio slot, always: `offer` queues the line and opens the card even when the line
  cannot queue (the words on the card are the instructions; the radio only keeps the flow).
- **Reading time** `readFor = clamp(1.5 + chars / 18, minRead 4 s, maxRead 8 s)` over the goal, the how-to line and
  the run rule. That is about 18 characters a second after a 1.5 s glance. The two levels come out at 6.4 s, or 8 s
  with a run rule.
- **Closes** only when one of these happens:
  - the player dismisses it (a tap on the card, its ×, or Space or Enter with nothing else to skip);
  - the fight has run `combatGrace` (1.2 s);
  - the transition is over **and** `readFor` has passed.

  The radio has no say. `read(now)` is time only.
- **Hold:** unchanged mechanics (mission-medals). At the flight's last quarter second the model is not stepped while
  the card is open and unread, for at most 15 s, and the card shows TAP TO START. Now "unread" means only that
  `readFor` has not passed.
- **Slot length:** `needs()` is the longer of the line's airtime (with the grace gap and half its reading hold) and
  `readFor`. The flow may add at most `FlowPlan.maxExtra` (2 s) for it, and the hold covers any remainder. So the
  usual cost is zero to a few seconds of a soft hold, not a new screen.

## 4. Radio: one line, never over the card
- New trigger `bonusCall.<level>` with exactly one line each, appended to `art/comms/lines.json` as written lines
  (`"pending": "text"`, so no borrowed placeholder and the borrowed count stays 55):
  - `bonusCall.supplyRun.h0`, PIP (excited): "Presents from the sky, so pop 'em open and grab the goodies!"
  - `bonusCall.stormfront.h0`, SUNNY (teasing): "Park under the brood, then scoot, and let the thunder zap them!"
- The line is the card's only turn (`BonusBriefing.script()`), shown on the card with its speaker's portrait and left
  out of the dock while the card is drawn. If it is still on air when the card closes, it finishes as an ordinary
  dock toast, never cut.
- **Quiet window:** while the card is up the director is hushed (`CommsDirector.hush`, the comms-middle-ground
  quiet window that the opening tip card uses), and the card's own turn is `scripted` so the hush does not hold it.
  Flavour, useful and hint lines wait, and they may still play just after the card closes. Only urgent and must-play
  warnings could sound. In portrait those stack **under** the card (`CommsHudStack.banner`), and in landscape they
  sit in the side tiles, so nothing is drawn over it.
- `bonusEntry*` still selects the slot (`InterludePlanner._bonusEntry`), so a bonus transition is recognised as
  before. `bonusEntry*` and `bonusDare*` keep their clip ids (append-only bank) but are no longer spoken.
- No edits to `comms_view.dart`, `comms_director.dart` or `comms_lineup.dart` (owned by `portrait-comms-lanes`). If
  that change moves the dock, `CommsHudStack.banner` must keep the card above the toasts. The widget test "radio
  chatter neither closes nor covers the card" guards this.

## 5. Specs this supersedes (archive order)
`bonus-levels` (complete, not archived) says the card "SHALL close when its chatter has been read", and
`mission-medals` defines "read" as the reading time **and** every scripted turn. Both predate this change. Archive
them first, then this one. When this change is archived, the `bonus-briefing` capability's requirements win, and the
older close and read clauses are to be dropped from `arcade-presentation` in the same archive commit.

## 6. Cinematic-flow check
`openspec/changes/cinematic-flow` §2.2 and `openspec/specs/arcade-presentation` ("One primary transition message"):
the card stays the transition's one sanctioned radio card. There is no floating text, no new modal step and no new
control. A tap, Space or Enter still never cuts a radio line, and the skip still sends the flight to its Descent.
