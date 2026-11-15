# Story hooks in the radio

Where the hidden story is hinted, and what is still open for the operator. Written with the bonus levels' banter
(`work/bonus-briefing`, change `bonus-levels`, design "Urgent-mission card and banter").

## The story as the project already defines it

- `openspec/changes/battle-metal-radio-rework` (proposal, design "Ending"): the whole five-tour campaign is a board
  game. After the fifth carrier the camera pulls back to teenage human and demon friends playing it on a San Diego
  beach, sharing burgers, fries and sodas; then the credits. The battle chatter should carry "sparse ambiguous
  references to turns, supplies, sand or snacks … without explaining the setting".
- `lib/ending/ending_page.dart`: the reveal ("SAN DIEGO · AFTER THE LAST TURN", "Same friends. Next round?").
- `openspec/changes/console-runs-final-ending`: the reveal plays only after the fifth carrier.
- Existing clues in `art/comms/lines.json`: the brood's "Our turn to fly!", "My turn!", "My sky, my rules!", "You have
  come a long way to lose this turn!", and the squad's "Sentinel class on the board."

Nothing contradicts this, so the new hints follow it.

## Hints placed in the bonus levels

All are written lines (`"pending": "text"`): shown with their own words now, voiced once tillandsias#1103 records
them. One or two per pool, so a run meets a few at most.

| Where | Speaker | Line | Hint |
|---|---|---|---|
| `bonusDare` | SPARROW | Loser buys the snacks. Just saying. | snacks |
| `bonusDare` | VEXXA (brood) | Your turn ends here. | turns |
| `bonusDare` | GORRAK (brood) | Come, little ship. Our rules now. | rules |
| `bonusDare.supplyRun` | SUNNY | Grab me a snack crate. The salty ones! | snacks |
| `bonusDare.supplyRun` | PIP | Who even packs fries in a supply crate? | fries |
| `bonusDare.supplyRun` | KESTREL | Catch them all and the next round is on me. | "next round" (the ending's last words) |
| `bonusDare.supplyRun` | VEXXA (brood) | Those crates are ours. Wait your turn! | turns |
| `bonusDare.supplyRun` | NIBB (brood) | Dibs on the crunchy ones! | snacks |
| `bonusDare.stormfront` | ROOK | Bet you flinch first. Loser carries the cooler. | the beach cooler |
| `bonusDare.stormfront` | SPARROW | Who rolled for weather? I want a word. | dice |
| `bonusDare.stormfront` | NIBB (brood) | Rain? Nobody said rain was in the rules! | rules |
| `bonusDare.stormfront` | MORTH (brood) | Every storm passes. So does every turn. | turns |
| `bonusMidway.supplyRun` | ANVIL | Odd. This crate is half full of sand. Who packed it? | sand |
| `bonusMidway.supplyRun` | SUNNY | Smell that? Salt air. Way out here? | the sea |
| `bonusMidway.supplyRun` | SLISS (brood) | Sticky crate. Who spilled the soda? | soda |
| `bonusMidway.supplyRun` | VEXXA (brood) | Enjoy your boxes. The next turn is mine. | turns |
| `bonusMidway.stormfront` | NOMAD | Funny. That thunder sounded like someone shaking dice. | dice |
| `bonusMidway.stormfront` | MORTH (brood) | Storms pass. Turns pass. The brood remains. | turns |
| `bonusMidway.stormfront` | SLISS (brood) | Wet scales! Somebody move the umbrella! | the beach umbrella |
| `bonusCleared.supplyRun` | PIP | Can we play that one again? Please? | "play" (voiced by a borrowed clip until recorded) |
| `bonusCleared.stormfront` | NOMAD | Fine flying. I would play that round again. | "round" (borrowed clip until recorded) |

The brood is written as a rival who is also, quietly, a friend at the same table: it argues about turns and rules
and grabs the snacks, it never threatens anyone off the board.

## Open questions for the operator

1. **How strong may the hints get, and when?** All hints are equally faint today, whatever the tour. Should they
   grow bolder on later tours (route 3-4) so the reveal feels earned, and stay out of tour 1 entirely?
2. **Who knows?** Should any character seem to know (Pip's innocence, Sunny's jokes, Morth's "the brood remains")?
   The lines are written so nobody does. A knowing character would be a stronger hook and a bigger commitment.
3. **Names at the table.** Do the teenage players map onto the call signs (Sunny, Rook, Pip …) and brood officers?
   If yes, the beach image and the credits could name them, and a few lines could rhyme with it.
4. **San Diego details.** Specific places (a pier, a taco stand) would be stronger clues and sharper jokes, and also
   more explicit. Not used yet.
5. **After the reveal.** "Same friends. Next round?" suggests a replay. Should a second campaign (or New Game+) have
   the squad acknowledge it ("Same table, new game")?
6. **Bonus levels as event cards.** The urgent missions could be the board game's event or chance cards ("someone
   drew a storm"). Sparrow's "Who rolled for weather?" leans that way. Make it canon, or keep it a wink?
7. **Recording.** When tillandsias#1103 records these lines, should the brood's hint lines keep their glyph-and-SIGINT
   form (the reading is the fleet's translation, so a hint is "intercepted") or be voiced more plainly?
