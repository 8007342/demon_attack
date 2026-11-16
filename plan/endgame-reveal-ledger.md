# End-game reveal ledger

Detail inventory for the end-game cinematic (operator round 3d, E1, `plan/operator-feedback-2026-11-16.md`). The
reveal: the whole game was imagined by kids playing a board game at a restaurant called Krybor. This ledger lists
every game detail that can mean something new on a second run, where it lives in the repo, what it turns out to be at
the table, whether the game already hints at it, and which shot of the cinematic pays it off.

Working reconciliation with the earlier canon (`plan/story-hooks.md`, `lib/ending/ending_page.dart`): Krybor is a
beachfront burger restaurant in San Diego, with patio tables on the sand under umbrellas. Section 5 lists what fights
this.

**How to add a row.** Open the file or grep the key first: the "Where" column holds only paths and keys that were
actually read. Quote existing plants word for word with their clip id (`<trigger>.h<n>` human, `<trigger>.d<n>`
brood, in list order of `art/comms/lines.json`). Put a new idea in "Proposed new plant", never in "Already planted".
Give the row one payoff shot. New radio lines are proposals only: the live bank `art/comms/lines.json` belongs to
the voice-stack change, and its clip ids are positional (append, never reorder).

**Shot ids** (final; `art/storyboards/endgame/README.md`). S1 the last piece falls (the carrier wreck match-cuts to
a plastic carrier figure tipping over). S2 the board (the pull-back). S3 the players on both sides of the table.
S4 free refills: the waitress. S5 the General: the owner at the pass window. S6 Overwatch: Mom, "time to go home".
S7 Krybor: the exterior wide, the KRYBOR sign, the box lid, "Same friends. Next round?". S8 the button after the
credits: the shelf of figures by the register.

Everything here was read from the repo on 2026-11-16. No external source is cited.

## 0. Decisions taken by the lead (2026-11-16)

The operator overrides any of these; each is also an open question in
`openspec/changes/endgame-cinematic/design.md` §10.

| # | Decision | Reason | Section |
|---|---|---|---|
| D1 | "The grumpy General" is GORRAK, the teal Brood Marshal. The fleet nicknames him "the General"; his rank label stays | the only grumpy voice, the only peaked cap, and the officer of sector 1, Krybor | 1.1 |
| D2 | "The sassy purple cadet" is VEXXA. Proposed new rank label WING CADET, and a part in every sector | the only sassy violet voice; her taunts already read as a waitress's teasing | 1.2 |
| D3 | The kids cast the restaurant's staff as the brood and their own families as the fleet. The brood's reversed speech is heard plainly for the first time in the cinematic | it makes the two reveals the operator named land on the two officers the player has fought longest | 1.3, C16, C17 |
| D4 | Krybor is a beachfront burger restaurant in San Diego with patio tables on the sand. The sign reads KRYBOR; people say "Krybor's" | keeps every sand, sea, cooler and umbrella line already recorded | 5 (3, 10, 13) |
| D5 | The brood-side players are kids in horned hoodies (crimson and gold). No literal demons; the button shot S8 keeps one wink | "the kids were just imagining the whole thing" (operator) | 5 (4, 8) |
| D6 | The players are about nine to twelve; the waitress is about seventeen | she must be visibly older than the kids she teases | 5 (5) |
| D7 | The pilot is the player: hands and the back of a head, never a face, never a voice | every player stays the pilot | 1.3 |
| D8 | Mom is in her forties with one silver streak. The kids imagine every grown-up older and grander | the Admiral's sixties and Pip's "19" are the kids' picture, not the room's | 5 (7) |
| D9 | S8 is the shelf of figures by the register, not the arcade cabinet. The cabinet stands in the corner in S5, with the title screen's words on its marquee | one twist only: a second "it was a video game" turn would blur the first. The room still explains the title | P2, U9 |
| D10 | Seven details of the scene come from the finished run (section 2.11) | "I wanna finish it again so I can see if…" (operator) | 2.11 |

## 1. Identities

### 1.1 Who is "the grumpy General"?

No cast member holds the rank General (`art/comms/cast.json`: FLEET ADM, CDRE, WING CAPT, MAJ ×2, CAPT, LT ×4, ENS,
CADET, SGT ×2, CPL; brood: BROOD MARSHAL, WING COLONEL, FURNACE MAJOR, HOLLOW PRELATE, ARK WARDEN).

**Recommendation: GORRAK, the teal Brood Marshal.** The fleet nicknames him "the General"; his rank label stays.

- He is the only character who looks like a general: "military peaked cap with chevron insignia, epaulettes"
  (`cast.json`, `look`). A marshal is a general-grade rank.
- He is the only character written grumpy. The humans are all written warm.
  - "Fine! Take this patch of sky!" (`levelClear.d0`)
  - "You dodge like someone avoiding a chore!" (`broodTaunt.d5`)
  - "Stop counting their boxes! Count ours!" (`bonusMidway.supplyRun.d0`)
  - "Again! AGAIN!" (`sentinelRushMissed.d0`)
- He is the fixed brood officer of sector 1, which is Krybor (`cast.json`, `demonSectors."1": ["gorrak"]`). The man
  who runs Krybor in the game is the man who runs Krybor's in the restaurant.
- The gag is the contrast the operator asked for: red eyes and underbite fangs in the kids' game, an always-smiling
  owner at the counter. The cap carries the match cut: Gorrak's peaked cap with a teal chevron becomes the owner's
  cap with the restaurant's teal chevron logo.
- Cost: none in the cast file. Two or three proposed fleet lines call him "the General" (section 4).

**Runner-up: Capt. Teo Brandt, ANVIL**, the gruffest human: "Nice speech. Shame about your aim."
(`broodTaunt.h3`), "Unopened crates are just litter. Pop them on the way down." (`bonusCrateMissed.supplyRun.h3`),
"Hydrate, pilot. Commander's orders. Well, my orders." (`transmissionJunior.h9`). He would need a rank change, and he
is gruff, not grumpy.

**Not recommended: Maj. Elena March, BASTION.** She is stern and kind ("That's the air wing I know. Thank you.",
`allySaved.h5`), and a recorded line names her rank: "Fight on the flank, Major." (`groundSkirmish.h6`, Mensah). A
promotion to General would leave that clip wrong.

**If the operator meant a human:** a new ground-forces General is cleaner than re-ranking anyone. It costs a
portrait render and a voice (blocked on tillandsias#1103, so written lines only). Open question 1 in section 5.

### 1.2 Who is "the sassy purple cadet"?

No existing character is all three. Pip Alvarado is the only CADET (teal, eager, male, 19). Ens. Mira Sato, WISP,
has the violet accent and is calm. VEXXA is violet and sassy, and a brood Wing Colonel.

**Recommendation: VEXXA, re-ranked from WING COLONEL to a cadet rank (for example "WING CADET") and made
prominent.**

- She is the only sassy purple character in the game, and every line she has teases:
  - "You brought a whole fleet for little old me?" (`broodTaunt.d1`)
  - "I was saving that patch of sky!" (`broodTaunt.d6`)
  - "Those crates are ours. Wait your turn!" (`bonusDare.supplyRun.d1`)
  - "Slippery little ship!" (`sentinelRushMissed.d1`)
- She already talks like someone serving a table: "Enjoy it. I know the way back!" (`levelClear.d1`), "Enjoy your
  boxes. The next turn is mine." (`bonusMidway.supplyRun.d2`).
- Her look is a "narrow fanged grin" (`cast.json`), and her source voice is a woman's
  (`art/comms/demon-delivery.json`, `af_sarah`).
- The re-rank is one field. No line in the bank says "Colonel" (grep of all 695 lines).
- She pairs with Gorrak: they share sector 2 (`demonSectors."2": ["vexxa","gorrak"]`) and one backdrop
  (`art/comms/portraits.json`, `backdrops.assign`: both `demon-warroom`, "table with a strategy map"). The kids cast
  the two people who run the restaurant as the two officers who run the brood.
- "Prominent from now on" then means: she appears in every sector, not only 2 and 3, and her teasing comes with a
  gift. The waitress gives free refills, so Vexxa's taunts arrive with a falling shield (section 4, plants N3-N5).
- Limit: brood speech is glyphs plus a fleet gloss (`lib/comms/brood_script.dart`), and the audio is a reversed
  performance. A prominent Vexxa is read, not heard clearly, until the operator decides otherwise (open question 2).

**Runner-up: WISP, re-ranked ENS to CADET, with sassier appended lines.** She is the strongest human option:

- Violet trim, a young woman, the most junior officer after Pip. No line says "Ensign".
- She already reports what is in stock: "Supply only has spread modules today. Wide coverage it is."
  (`runModifier.spreadOnly.h0`).
- Two lines are dry: "Translation received. Tactical value: questionable." (`broodTaunt.h8`), "I logged your last
  run. Your dodge rate is ridiculous." (`transmissionJunior.h5`).
- Against: her other 33 recorded lines are calm and careful, so the sass would be new, and a second cadet sits
  beside Pip.

**Third: a new violet human cadet.** The cleanest tone from the first line. It costs a portrait render, a voice
(blocked on tillandsias#1103), and a rule in `lib/comms/comms_lineup.dart` so she is on the call as often as the
Admiral.

If the operator picks Wisp or a new cadet, only the mapping rows for Vexxa and Wisp below swap. The ledger rows hold.

### 1.3 All 25 speakers at the restaurant

The portrait backdrops already group the cast into eight rooms (`art/comms/portraits.json`, `backdrops.assign`).
The mapping uses those groups as zones of the restaurant. Ages in `cast.json` are the ages the kids imagine. Every
role is an ordinary, likeable person or animal: no caricature (`cast.json` comment).

| Speaker (rank, call sign) | Backdrop group | Who they are at Krybor | Evidence (clip id) |
|---|---|---|---|
| IMANI HALE (FLEET ADM, OVERWATCH) | fleet-bridge | Mom, watching over the kids from the grown-ups' table. She says it is time to go home | "Every one of you is coming home." (`flawlessVictory.h0`); "Bring it home, pilot. We'll launch again." (`defeat.h1`); "We can play this all afternoon." (`broodTaunt.h0`) |
| RHEA LINDQVIST (CDRE, BEACON) | fleet-bridge | The other family's parent, sharing Mom's table and holding the order pager | "Noted. Logged. Still ignoring it." (`broodTaunt.h9`); "Rest up. The fleet will be ready when you are." (`defeat.h2`); "Enjoy!" (`bonusEntry.h1`) |
| AMARA SINGH (WING CAPT, KESTREL) | fleet-ops | A regular at the counter who buys the kids a round | "Catch them all and the next round is on me." (`bonusDare.supplyRun.h3`) |
| GIDEON ABARA (MAJ, NOMAD) | fleet-ops | The oldest regular, thirty years at the same stool, calls everyone "friend" | "Thirty years flying, and you still surprise me." (`transmissionJunior.h6`); "Easy, friend. Save some thunder for the next round." (`broodTaunt.h7`) |
| TEO BRANDT (CAPT, ANVIL) | fleet-cockpit | The lifeguard from the tower next door, on his break (the tower is in `assets/images/beach-ending.webp`) | "Hydrate, pilot." (`transmissionJunior.h9`); "Play it safe." (`shieldExpiring.h2`); "Unopened crates are just litter." (`bonusCrateMissed.supplyRun.h3`) |
| JUNO OKAFOR (LT, SPARROW) | fleet-cockpit | Fleet-side kid 1, the competitive one | "Loser buys the snacks. Just saying." (`bonusDare.h1`); "Your move, then. Try to impress me." (`broodTaunt.h2`) |
| REN DANNER (LT, ROOK) | fleet-cockpit | Fleet-side kid 2, the joker who does the sound effects | "Rapid cannons. Brrrrt!" (`weaponPickup.rapid.h1`); "New toy! Try it out." (`weaponPickup.h0`); "Loser carries the cooler." (`bonusDare.stormfront.h0`) |
| MIRA SATO (ENS, WISP) | fleet-ops | The quiet kid with glasses who keeps the score pad and reads the rulebook | "I logged your last run." (`transmissionJunior.h5`); "Translation received." (`broodTaunt.h8`) |
| HANA PARK (LT, SUNNY) | fleet-cockpit | The weather presenter on the TV above the counter | "Forecast says clear skies, with a chance of demons." (`sectorStart.h5`); "Halftime weather report: still stormy, still winning." (`bonusMidway.stormfront.h0`) |
| PIP ALVARADO (CADET, PIP) | fleet-cockpit | The little brother who is not allowed his own piece yet. A pip is also a dot on a die | "Do you think I'll get my own ship someday? A real one?" (`transmissionJunior.h1`); "Can we play that one again? Please?" (`bonusCleared.supplyRun.h3`) |
| ELENA MARCH (MAJ, BASTION) | ground-tent | The floor manager who runs the patio under the big umbrella | "Convoy halted. Air wing, cover us until we're free." (`convoyStuck.h3`); "Keep the convoy tight." (`terrainAhead.forest.h3`) |
| BRAM KESSLER (SGT, BULWARK) | ground-tent | The delivery driver whose van gets stuck in the sand | "We're stuck! Tracks are spinning!" (`convoyStuck.h0`); "Drinks are on Bulwark tonight!" (`flawlessVictory.h5`) |
| DANA VOSS (CPL, LANTERN) | ground-tank | The busser who lights the patio lanterns at dusk | "Lantern's lights on. It's dark between these cliffs." (`terrainAhead.canyon.h2`); "All lights on, all teams home." (`flawlessRun.h5`) |
| KOFI MENSAH (SGT, GRANITE) | ground-tank | The steady kitchen hand who carries the crates | "Solid as a rock, thanks to you." (`allySaved.h3`); "Uphill all the way. Granite doesn't mind." (`convoyClimbing.h1`) |
| GORRAK (BROOD MARSHAL, TEAL BROOD) | demon-warroom | **The owner**, always smiling ("the grumpy General") | section 1.1 |
| VEXXA (WING COLONEL, VIOLET BROOD) | demon-warroom | **The teenage waitress** ("the sassy purple cadet") | section 1.2 |
| SKARN (FURNACE MAJOR, CORAL BROOD) | demon-forge | The grill cook, goggles pushed up on his forehead | `look`: "goggles on forehead"; "Burn the boxes! Burn the sky!" (`bonusDare.supplyRun.d3`); "Tell your ground crew I said hello!" (`allyUnderAttack.d2`) |
| MORTH (HOLLOW PRELATE, GOLD BROOD) | demon-throne | Brood-side kid 2, the patient one who always asks for a rematch | "A rematch! After a short break!" (`bossDefeated.d1`); "I have all afternoon. Do you?" (`broodTaunt.d3`) |
| ULGRA (ARK WARDEN, THE CARRIER) | demon-throne | Brood-side kid 1, who owns the game and plays the carrier | "Welcome to my side of the sky!" (`bossArrival.d0`); "All right. That was a good move!" (`bossDefeated.d0`) |
| SKRITCH (SCOUT IMP) | demon-warroom | A seagull after the fries | "Shiny boxes! Mine, mine, mine!" (`bonusDare.supplyRun.d0`); "Dropped it! Finders keepers!" (`bonusCrateMissed.supplyRun.d0`) |
| GRUNNOK (TROOPER BRUTE) | demon-forge | The brood kids' big brother, who only watches and cheers | "Oh, that was good!" (`reinforcements.d8`); "That was almost clever!" (`reinforcements.d16`) |
| BLATCH (BROOD GUNNER) | demon-forge | The takeout-window worker with a headset | `look`: "gunner's headset"; "Again! Do that again!" (`reinforcements.d9`) |
| NIBB (BROOD SPRITELING) | demon-warroom | The toddler sister in a sun hat too big for her | `look`: "oversized dented iron helmet tilted on its head"; "Dibs on the crunchy ones!" (`bonusDare.supplyRun.d2`) |
| KRAG (STONE HULK) | demon-forge | The owner's old dog, asleep like a boulder under the table | `look`: "iron chain collar", "patches of moss" |
| SLISS (VENOM SKULKER) | demon-throne | The restaurant cat, who hates getting wet | "Wet scales! Somebody move the umbrella!" (`bonusMidway.stormfront.d2`); "Sticky crate. Who spilled the soda?" (`bonusMidway.supplyRun.d1`) |

The pilot (the player) is in no cast file. The radio calls them "pilot", "flyer" and once "Captain"
(`transmissionJunior.h0`). Recommendation: the pilot is the viewer's own seat at the table. S3 shows hands on the
ship figure and never a face, so every player stays the pilot (open question 6).

## 2. The ledger

Columns: `#`, game detail, where it is in the game, reveal meaning, already planted (quote and clip id, or "no"),
proposed new plant, payoff shot. "N…" refers to a proposal in section 4.

### 2.1 Cast and call signs

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| C1 | The Fleet Admiral anchors every run; the rest of the lineup changes | `lib/comms/comms_lineup.dart` (doc comment); `art/comms/cast.json` `anchor` | Mom is there every visit. The other patrons differ each time | "New sector, same promise." (`sectorStart.h0`) | none needed | S6 |
| C2 | Call sign OVERWATCH | `cast.json` admiral | Mom watching over the kids from her table | "Pilot, Overwatch. The fleet is moving on your signal." (`transmissionMission.h0`) | N1 | S6 |
| C3 | The Admiral's "home" lines | `art/comms/lines.json` | "Time to go home" | "Every sector you clear brings our people home." (`transmissionMission.h2`); "Bring it home, pilot." (`defeat.h1`) | N1, N2 | S6 |
| C4 | "All afternoon" | `lines.json` `broodTaunt` | One long afternoon at the table | "Keep talking. We can play this all afternoon." (`broodTaunt.h0`); "I have all afternoon. Do you?" (`broodTaunt.d3`) | none needed | S3 |
| C5 | Call sign PIP | `cast.json` pip | The dots on a die are pips | no | N12; a die showing one pip beside the little brother | S2 |
| C6 | Call sign ROOK | `cast.json` rook | A game piece. His figure stands on a castle-tower base | "Sentinel class on the board." (`sentinelIncoming.h4`, Lindqvist) | a tower-shaped base under one fleet figure | S2 |
| C7 | Bird call signs KESTREL, SPARROW | `cast.json` | Beach birds on the patio rail | no | two small birds on the rail | S7 (background) |
| C8 | Call sign LANTERN | `cast.json` voss | The string of patio lanterns, lit at dusk | "Lantern's lights on." (`terrainAhead.canyon.h2`) | lanterns switch on during the cinematic | S5 (background) |
| C9 | Call signs BASTION, BULWARK, GRANITE, BEACON | `cast.json` | Things in view: the patio wall, the delivery van's bumper, the stone counter top, the order pager's light | "Solid as a rock" (`allySaved.h3`) | none needed | S5 (background) |
| C10 | SUNNY's forecasts | `lines.json` `sectorStart.h5`, `bonusEntry.stormfront.h0`, `levelClear.h7` | The TV weather report above the counter | "Forecast: thunderstorm, ninety percent chance of fried demons." (`bonusEntry.stormfront.h0`) | N13 | S5 (background) |
| C11 | "Can demons get sunburns?" | `lines.json` `transmissionJunior.h2` | A day at the beach | quoted | sunscreen on the table | S3 |
| C12 | Rounds and drinks on someone | `lines.json` | Soda rounds and free refills | "When this is over, first round's on me. Deal?" (`transmissionJunior.h4`); "Drinks are on Bulwark tonight!" (`flawlessVictory.h5`) | N4 | S4 |
| C13 | "Hydrate, pilot." | `lines.json` `transmissionJunior.h9` | The lifeguard telling kids to drink water | quoted | none needed | S4 (background) |
| C14 | Rook's sound effects | `lines.json` `weaponPickup.rapid.h1` | A kid making gun noises with his mouth | "Rapid cannons. Brrrrt!" | none needed | S3 |
| C15 | Pip wants his own ship | `lines.json` `transmissionJunior.h1`, `weaponPickup.h4` | The little brother wants his own figure and his own turn | "Ooh, can I have one of those next?" (`weaponPickup.h4`) | in S3 he finally gets to hold the ship | S3 |
| C16 | The brood speaks in glyphs with a translation | `lib/comms/brood_script.dart` ("Original 26-sign brood alphabet"); `lines.json` comment ("brood glyphs with a fleet SIGINT gloss") | The brood-side kids' secret code: one sign per letter, key printed on the kids' menu | "Translation received. Tactical value: questionable." (`broodTaunt.h8`) | the glyph key on a paper placemat | S2 |
| C17 | Brood voices are reversed and pitched down | `art/comms/demon-delivery.json` (`reverse: true`); `art/comms/audio.json` `gibberish` | Kids doing monster voices | no | in S3 a brood-side kid growls one line, then laughs in a normal voice | S3 |
| C18 | Brood officers are fixed per sector | `cast.json` `demonSectors` | Staff work fixed stations: owner at the door, waitress on the floor, cook at the grill | no | none needed | S5 |
| C19 | Portrait backdrops | `art/comms/portraits.json` `backdrops.variants` | Zones of the restaurant: `fleet-ops` "holographic tactical map table" is the counter, `ground-tent` "canvas walls, folding table … hanging lantern, crates" the patio umbrella, `demon-forge` "glowing lava channels, chains and anvils … smoke" the grill | no | hold each real zone in the same framing as its backdrop | S4, S5 |
| C20 | The brood argues about turns and rules | `lines.json` | It is a board game | "Our turn to fly!" (`waveStart.d0`); "My turn!" (`divePrep.d3`); "My sky, my rules!" (`reinforcements.d15`); "One round to you, pilot!" (`levelClear.d2`) | none needed | S3 |
| C21 | "Who moved the convoy?" | `lines.json` `allySaved.d3`, `demonRout.d3` | Someone moved the pieces while the others looked away | quoted | a kid slides a tank back with one finger | S3 |
| C22 | "That was my wing!" | `lines.json` `demonRout.d0`, `allySaved.d0` | A basket of chicken wings on the table | "That was my wing!"; "Keep those wings up!" (`diveWarning.d1`) | wings on the menu board | S2 |
| C23 | Gorrak's cap and chevron | `cast.json` gorrak `look`; `plan/style-guide.md` ("teal chevron" species badge) | The owner's cap with the restaurant's teal chevron logo | no | the same chevron on the sign, the cups and the cap | S5, S7 |
| C24 | Vexxa serves and leaves | `lines.json` `levelClear.d1` | The waitress drops the order and heads back | "Enjoy it. I know the way back!" | N3 | S4 |
| C25 | "I was saving that patch of sky!" | `lines.json` `broodTaunt.d6` | She was saving that table | quoted | a small "reserved" card on the next table | S4 (background) |
| C26 | The whole fleet watches the last fight | `lines.json` `sectorStart.5.h3` | The whole patio watches the last turn | "Every ship in the fleet is watching this feed. Make it count." | none needed | S1, S3 |
| C27 | The radio's key-up click | `art/comms/audio.json` `radio.keying` ("rounded sine 'tock'") | A plastic piece tapped on the board before a kid speaks | no | tap the piece in S3 with the same sound | S3 |
| C28 | Comms dock labels | `lib/comms/comms_view.dart` ("◉ SQUAD CHANNEL · SHARING ARENA", "◉ PRIORITY TRANSMISSION · FLEET COMMAND") | Everyone shares one table. A priority transmission is Mom calling across the patio | no | none needed | S6 |
| C29 | Skritch, the scout imp who snatches crates | `art/comms/cast.json` skritch `look`; `lines.json` `bonusDare.supplyRun`, `bonusCrateMissed.supplyRun` | A seagull after the fries | "Shiny boxes! Mine, mine, mine!" (`bonusDare.supplyRun.d0`); "Dropped it! Finders keepers!" (`bonusCrateMissed.supplyRun.d0`) | N19; a gull on the umbrella pole, one fry in its beak | S7 (background) |

### 2.2 Places and sectors

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| P1 | Krybor, the frontier being defended | `lib/game/campaign_story.dart` `destinations[0]`; `lines.json` `sectorStart.1.h0` | The restaurant's name, on the sign | "Krybor's frontier is waiting." (`transmissionMission.1.h0`) | none needed | S7 |
| P2 | "KRYBOR / DEFENSE SYSTEM", "AN ARCADE REBORN" | `lib/main.dart` (title screen labels) | The marquee of an old arcade cabinet in the restaurant's corner | quoted (title screen) | the cabinet, lit, behind the counter | S5 (background) |
| P3 | "The outpost families are counting on you" | `lines.json` `transmissionMission.1.h0`, `sectorStart.1.h1` | Families eating on the patio | quoted | none needed | S7 |
| P4 | The lost frontier signal | `campaign_story.dart` `arrivals[0]`, `victories[0]` ("The frontier signal is restored.") | The order pager that buzzes when the food is ready | "Frontier signal is faint, but it's there." (`sectorStart.1.h3`) | N14; a pager with a blinking light on the table | S2 |
| P5 | Krybor's five route names: Krybor, Slums, Docks, Mountains, Command | `campaign_story.dart` `destinations[0]`; `plan/sector-style-guide.md` | Parts of the place: the patio, the crowded umbrellas ("Crowded roofs shelter the last frontier families"), the pier ("Cargo cranes line the dark piers"), the dunes, the counter | no | a hand-drawn map of the restaurant on the kids' menu with the five names | S2 |
| P6 | Ringfall, rings and a supply route | `campaign_story.dart` `destinations[1]`; `plan/sector-style-guide.md` (violet gas giant, "broad diagonal planetary rings") | A basket of onion rings, and the wet rings soda cups leave on the board | "Ooh, rings! This sector really put a ring on it." (`sectorStart.2.h3`); "Break their supply line and the brood starves." (`transmissionMission.2.h0`) | menu item "Ringfall Rings" | S2 |
| P7 | Ember Moon, heat and foundries | `campaign_story.dart` `destinations[2]`; `lines.json` `sectorStart.3.*` | The grill. The kitchen makes everything | "Is it just me, or is this moon really, really hot?" (`sectorStart.3.h3`); "Their foundries build every demon you've fought." (`transmissionMission.3.h0`) | N13; menu item "Ember Moon burger" (spicy) | S5 |
| P8 | The Hollow: ancient towers, arches, catacombs, a throne | `campaign_story.dart` `destinations[3]`, `routeDetails[3]` | A sandcastle beside the patio, half fallen in | "These ruins are ancient. Who built all this?" (`terrainAhead.ruins.h3`) | N15 | S7 (background) |
| P9 | "Something old is watching from those ruins." | `lines.json` `sectorStart.4.h1`; `routeDetails[3][1]` | The dog (Krag) asleep beside the sandcastle | quoted | N17 | S7 (background) |
| P10 | The Carrier and its four later names | `campaign_story.dart` `destinations[4]` (Brood Ark, Siege Carrier, Brood Citadel, Brood Flagship) | The biggest toy in the box, with new clip-on parts each round | "That thing's the size of a moon." (`sectorStart.5.h2`) | none needed | S1 |
| P11 | Five routes ("tours") through the same five places | `campaign_story.dart` `tourEscalation`; `lib/main.dart` ("FIVE CARRIERS · ONE FRONTIER") | Five rounds of the same board at one table | "Five tours." (`flawlessRun.h0`); "Here comes round two!" (`waveStart.h1`) | "5 rounds" printed on the box lid | S7 |
| P12 | The route chart with the ship marker | `plan/transition-research.md` ("the marker flying the route chart") | The printed track on the board, with the ship pawn moved space by space | no | none needed | S2 |
| P13 | The travel cloud between sectors | `plan/transition-research.md` (Pursuit beat: "a bright cloud covers the frame") | A napkin or a menu passing over the board as the kids reset the pieces | no | a paper napkin lifts off the board at the start of S2 | S2 |
| P14 | The flyover camera and its horizon | `plan/sector-style-guide.md` ("oblique 3/4 flyover with a horizon") | A kid's eye level at the table edge: the board runs away to the real sea horizon | "Smell that? Salt air. Way out here?" (`bonusMidway.supplyRun.h2`) | hold the game's horizon line on the ocean horizon | S1, S2 |
| P15 | The sector colour arc: blue, violet, coral, green, red-black | `plan/sector-style-guide.md` (table of five paintings) | The afternoon passing. Sector 5's "blood-red storm clouds" are the sunset in `assets/images/beach-ending.webp` | "We can play this all afternoon." (`broodTaunt.h0`) | N2 | S6, S7 |
| P16 | The empty central firing lane | `plan/sector-style-guide.md` ("almost empty dark central 60% firing lane") | The track down the middle of the board | no | none needed | S2 |
| P17 | "SAN DIEGO · AFTER THE LAST TURN", "Same friends. Next round?" | `lib/ending/ending_page.dart` | Kept: the closing captions | "Catch them all and the next round is on me." (`bonusDare.supplyRun.h3`) | none needed | S7 |
| P18 | "The frontier is free. Return home, fleet champion." | `campaign_story.dart` `travel` (level 5, last route) | Go home | quoted (final travel caption) | none needed | S6 |

### 2.3 Enemies and bosses

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| E1 | Four gargoyle species: teal, violet, coral, gold | `plan/style-guide.md` (sprite rows "per species (teal, violet, coral, gold)") | Four colours of plastic figures, like the player colours in any game box | no | four moulding trays in the box | S2 |
| E2 | Species chest badges: chevron, twin bars, fang slashes, star jewel | `plan/style-guide.md`; `docs/styleguide/alien-troops.md` §4 | Marks moulded into each figure's chest | no | close-up on one figure's chest | S2 |
| E3 | Rank insignia: talon, two talons, ocellus, crown | `docs/styleguide/alien-troops.md` §4 | Stickers the brood-side kids put on the figures' heads | no | a half-used sticker sheet with the four glyphs | S2 |
| E4 | Stone gargoyles that crack and tumble | `plan/style-guide.md` ("deaths are an eight-frame species sequence … the stone body breaking") | Grey plastic figures knocked off the board | no | fallen figures in the sand under the table | S2 |
| E5 | Elites: gold-plated, extra armour that comes off hit by hit | `plan/sector-style-guide.md` ("Each hit removes a plate"); `plan/game-design.md` | Figures wrapped in burger foil, unwrapped hit by hit | "Fancy armor on that one. Somebody dressed up." (`eliteSighted.h4`) | scraps of foil on the board | S2 |
| E6 | Reinforcements keep arriving | `plan/game-design.md` ("skeins of 3-6 that swoop out of the fog") | Handfuls of figures from the box | "More? Where do they keep coming from?" (`reinforcements.h7`); "They called their friends. Rude." (`reinforcements.h2`) | a brood-side kid's hand in the box | S3 |
| E7 | Swarm states: mill, ribbon, sweep | `plan/game-design.md` | How a kid arranges a handful of figures: a ring, a chain, a line | no | figures left in a ring on the board | S2 |
| E8 | From tour 2 the brood learns | `plan/game-design.md` ("intelligence tiers"); `lines.json` `broodAdapting` | The other kid has learned your tricks | "It learns. So do we." (`broodAdapting.d1`) | none needed | S3 |
| E9 | Sentinels: the giant that hovers high, then dives | `plan/style-guide.md` ("broad horizontal body"); `plan/game-design.md` | The biggest gargoyle figure. Its real double is a pelican on the pier post | "Sentinel class on the board. Watch its eyes for the tell." (`sentinelIncoming.h4`) | a pelican eyeing the fries | S7 (background) |
| E10 | The sentinel's silhouette circling in the fog | `lib/game/attract.dart` (doc: "the giant circling deep in the fog"); `openspec/changes/fog-restoration/proposal.md` | A big bird's shadow crossing the board | no | a wing shadow sweeps the table | S2 |
| E11 | Dive battle cries | `lines.json` `divePrep` | A kid swooping a figure down by hand | "Watch this!" (`divePrep.d2`); "Down we go!" (`divePrep.d1`) | none needed | S3 |
| E12 | The carrier's force field: cool hex cells | `plan/game-design.md` ("geometric cyan/teal/violet hex & segmented pixel barriers") | A clear plastic cup turned over the carrier toy, plus hex shield tokens taken off one by one | "Break its field and strike the hatch." (`sectorStart.5.h0`) | hex tokens in a pile; a cup lifted off the toy | S1, S2 |
| E13 | The hatch | `lib/game/hints.dart` ("The core takes damage only while the central hatch is open."); `art/comms/pending-lines-2026-11-14.json` | The toy's hinged door, flicked open with a finger | "It opened its mouth! Feed it!" (pending, `carrierHatchOpen`, Rook) | a fry stuck in the toy's hatch | S1 |
| E14 | The carrier changes form and grows each tour | `docs/styleguide/alien-capital-ships.md` §5 (Carrier, Broodmother, Siege-Ark, Bastion; added maws, barriers, sacs) | Snap-on parts added each round | "It's changing form. Stay on the hatch." (`bossPhase.h0`) | spare parts on the sprue, in the box | S2 |
| E15 | The carrier's collapse into pieces | `lib/game/carrier_wreck.dart` (doc: "cut into a two-level hierarchy of chunks"); `plan/game-design.md` ("listing hull descent") | The toy tips over and its snap-on parts pop off | "It's falling! It's actually falling!" (`bossDefeated.h1`) | none needed | S1 |
| E16 | The carrier concedes | `lines.json` `bossDefeated.d0`, `bossArrival.d1` | The kid who plays the brood, being a good sport | "All right. That was a good move!"; "You have come a long way to lose this turn!" | none needed | S3 |
| E17 | Carrier minions, never more than ten | `plan/game-design.md` ("no more than ten simultaneous minions") | Ten figure slots printed around the carrier's space | no | ten small circles on the board | S2 |
| E18 | The carrier's arrival klaxon | `plan/game-design.md` ("warning klaxon telemetry") | The order pager buzzing | no | N14 | S2 |

### 2.4 Ground war

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| G1 | The Ground Fleet: Sleet, Cairn, Tether, Lodestar, Sextant, Stilt, Skiff | `plan/human-ground-forces-style-guide.md` §3; `art/families/ground-fleet.json` | The fleet-side kids' own toy trucks, brought from home | no | names written under the toys in marker | S2 |
| G2 | The cyan IFF chevron on every ally | `plan/human-ground-forces-style-guide.md` ("cyan IFF chevron") | A sticker on each toy's roof so the kids know whose it is | no | a cyan sticker on a figure base | S2 |
| G3 | "Survey gear that learned to fight" | `plan/human-ground-forces-style-guide.md` §1 | Toy diggers and a bucket-and-spade set pressed into service | no | a toy digger with a straw taped on as its gun | S2 |
| G4 | The Undercroft Host: carved stone on iron frames | `plan/gargoyle-army-style-guide.md` §1 ("A cathedral that walks to war") | The grey plastic set, shaped like castle pieces | no | none needed | S2 |
| G5 | Host castes Rubble, Ashlar, Tracery, Spire: rank is height | `plan/gargoyle-army-style-guide.md` §3 | Piece sizes, small to tall, as in any set | no | pieces lined up by height in the box tray | S2 |
| G6 | Bells in the Host: Carillon, Knell-bearers, Belfry | `plan/gargoyle-army-style-guide.md` §4; `plan/campaign-composition.md` (The Hollow: "tolling bells") | The "order up" bell on the counter | no | the owner rings the bell | S5 |
| G7 | Chapterhouse, the command walker whose spire topples | `plan/gargoyle-army-style-guide.md` §7 ("Command fall") | The tallest piece, always the first to fall over | no | it lies on its side on the board | S2 |
| G8 | Kiln Ox, Thurible (smoke), Cistern (slag tanker) | `plan/gargoyle-army-style-guide.md` §4 | The grill, its smoke, and the ketchup bottle | no | a ketchup bottle standing on the board as a tower | S2, S5 |
| G9 | Captured Krybor hulls that shed a human plate | `plan/ground-easter-eggs.md` §3; `art/families/ground-host.json` (`crocket-captured`) | A fleet toy borrowed by the brood side, painted over in marker | no | a grey-blue toy with brood glyph stickers | S2 |
| G10 | Allies are never destroyed: totalled, back to base | `lines.json` comment ("allies never die"); `plan/human-ground-forces-style-guide.md` §4.2 | House rule: nobody is out. A knocked-over piece goes back to the box lid, the "base" | "I'm totalled! Going back to base!" (`allyRetreated.h0`); "Heading back to base to patch up!" (`allyRetreated.h3`) | toppled toys parked on the box lid | S2 |
| G11 | The convoy gets stuck | `lines.json` `convoyStuck` | The board's edge is on sand. So is the delivery van outside | "We're stuck! Tracks are spinning!" (`convoyStuck.h0`); "Keep them off us while we dig out!" (`convoyStuck.h1`) | N16; a van with a wheel in the sand | S7 (background) |
| G12 | Terrain calls: ridge, valley, canyon, forest, crystal field, ruins | `lines.json` `terrainAhead.*` | Folds in the paper board, a gap between two trays, parsley, ice cubes, the sandcastle | "Mind the crystals, they cut tracks like paper!" (`terrainAhead.crystalField.h1`) | spilled ice cubes on one corner of the board | S2 |
| G13 | Vegetation the convoy pushes over | `art/families/flyover-vegetation.json` (frost-pine, cinder-tree, grave-fungus, brood-stalk …) | Toothpick flags and paper cocktail umbrellas stuck around the board | "Clearing the tree line!" (`convoyClearingVegetation.h0`) | a flattened paper umbrella | S2 |
| G14 | Crystals that shatter | `art/families/flyover-vegetation.json` (ring-crystal, ice-crystal-shrub) | Ice cubes from the sodas, melting | "It's glowing. That's not normal." (`terrainAhead.crystalField.h0`) | none needed | S2 |
| G15 | Flocks that burst from falling trees | `plan/ground-easter-eggs.md` §4 (rime moths, dust kites, ash flits, puffwings, hull gnats); `art/families/ground-wildlife.json` | Moths around the patio lantern, sparrows after crumbs, kites over the beach | no | kites in the sky | S7 |
| G16 | Critters that flee the troops | `plan/ground-easter-eggs.md` §5; `art/families/flyover-backgrounds.json` (frost-hopper, shell-crawler, rock-mite …) | Sand crabs and ants running from the kids' hands | no | a tiny crab crosses the sand by the table leg | S7 (background) |
| G17 | The victory dance and the taunt jig | `plan/ground-easter-eggs.md` §2; `lib/game/easter_eggs.dart` | A kid making his figures dance after a win | "Ha! They did not see that coming!" (`skirmishWon.h5`) | a kid bounces two figures | S3 |
| G18 | The jackpot: a turret pops, spins, bounces, lands upright | `plan/ground-easter-eggs.md` §3 | A flicked piece spinning on the table like a coin | no | the last frame of S1: one part spins and settles upright | S1 |
| G19 | Ground missiles cannot be shot down | `plan/game-design.md` ("Shots cannot destroy missiles") | A thrown fry: once it is in the air you can only duck | "Something's coming up at you!" (`groundMissileLaunch.h5`) | none needed | S3 |
| G20 | Demon officers greet the ground crew | `lines.json` `allyUnderAttack.d2` | The cook says hello to the patio staff through the kitchen window | "Tell your ground crew I said hello!" | none needed | S5 |

### 2.5 Power-ups, lives and scoring

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| L1 | The shield bubble that runs out | `lines.json` `shieldExpiring`, `shieldBroken`; `lib/widgets/power_status.dart` (`SHIELD`) | A cup of soda running low | "Shield about to run out." (`shieldExpiring.h0`); "Shield spent." (`shieldBroken.h2`) | N3 | S4 |
| L2 | Free shields fall from the sky | `lines.json` `shieldSpotted` | Free refills | "Free shield! Don't let it fall." (`shieldSpotted.h3`) | N3, N4 | S4 |
| L3 | Powers drop in a fixed order: spread, rapid, shield, powerful, large | `plan/game-design.md` ("Every eighth kill drops the next power in a repeating … sequence") | A small deck of power cards, never shuffled | no | five cards fanned beside the board | S2 |
| L4 | Every power lasts nine seconds | `plan/game-design.md` ("each with a nine-second timer") | A little sand timer on the table | no | a sand timer, its sand run out | S2 |
| L5 | "New toy!" | `lines.json` `weaponPickup.h0` | They are toys | "New toy! Try it out." | none needed | S2 |
| L6 | Homing missiles: a salvo of three | `plan/game-design.md`; `lines.json` `homingPickup` | Three fries, flicked one after another | "Homing missiles! They really get attached." (`homingPickup.h2`) | three fries lined up on the board edge | S2 |
| L7 | Reserve ships | `lines.json` `lifeLost`, `playerRespawn` | Spare ship figures waiting at the board's edge | "Next ship, launch!" (`lifeLost.h0`); "New ship smell! Try not to scratch this one." (`playerRespawn.h6`) | spare ships in a row | S2 |
| L8 | "Fresh paint, fresh engines." | `lines.json` `playerRespawn.h3` | Hand-painted figures | quoted | a paint pot and brush in the box | S2 |
| L9 | "Ship's totalled, pilot's safe." | `lines.json` `lifeLost.h0`, `defeat.h0` | The tiny pilot peg comes out and goes into the next ship | "Pod's away and safe. Spare ship's warm." (`lifeLost.h4`) | a pilot peg being moved between two ships | S3 |
| L10 | Heart pieces: four quarters make a life | `plan/game-design.md` ("Four complementary … quarters form a heart"); `lib/main.dart` ("HEART ASSEMBLED · +1UP") | The restaurant's stamp card: four stamps, one free refill | "A whole new ship! You've got a big heart." (`extraLife.h3`) | a stamp card with heart stamps in four quarters | S4 |
| L11 | Three unfinished heart slots | `plan/game-design.md` ("Three unfinished slots") | Three stamp cards on the table, one per fleet-side kid | no | none needed | S4 (background) |
| L12 | Difficulty: Easy 5 lives, Normal 3, Hard no hearts | `plan/game-design.md` (policy table) | House rules by age: the little one gets five ships, the big kids get no free refills | no | "little kids: 5 ships" pencilled on the rules sheet | S2 |
| L13 | Easy unlocks after three game overs | `plan/game-design.md` ("Three game overs before any boss victory permanently unlock Easy") | Mom's rule: after three losses the little one plays the easy way | no | N1 variant | S6 |
| L14 | Every boss awards one medal and one life | `lib/game/hints.dart` ("Every defeated carrier awards one medal and one extra life.") | A bottle cap and a refill for every round won | no | five bottle caps in a row | S2 |
| L15 | Salvage after a wave | `lines.json` `salvage` | Sweeping the tokens back into the tray | "Loot time! Grab everything." (`salvage.h1`) | none needed | S3 |
| L16 | Bets and score | `lines.json` `transmissionJunior.h3`, `bonusDare.supplyRun.h0` | Small change on the table and a score pad | "Betting pool says you'll beat my score." (`transmissionJunior.h3`); "Ten credits says you drop more than you catch." (`bonusDare.supplyRun.h0`) | a score pad with tally marks | S2 |
| L17 | "Two stars for that threat." | `lines.json` `broodTaunt.h5` | A review of the restaurant | quoted | a framed five-star review by the door | S5 (background) |

### 2.6 Bonus missions

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| B1 | The "URGENT MISSION!" card | `lib/comms/comms_briefing.dart` (`title`); `plan/bonus-levels-interface.md` | An event card drawn from the deck | "Overwatch, urgent. Special orders ahead." (`bonusEntry.h0`) | two event cards face up: SUPPLY RUN, STORMFRONT | S2 |
| B2 | Supply Run: crates on parachutes | `lib/game/bonus/levels/supply_run.dart` | The order arriving: baskets and boxes carried to the table | "Who even packs fries in a supply crate?" (`bonusDare.supplyRun.h2`); "Cracked it! Tell me it's snacks this time." (`bonusCrate.supplyRun.h3`) | the waitress's tray as the "convoy" | S4 |
| B3 | Three hits open a crate | `lines.json` `bonusStart.supplyRun.h0`; `supply_run.dart` | A takeout box with three tabs | "Three hits and it pops, remember?" (`bonusCrateMissed.supplyRun.h1`) | none needed | S4 (background) |
| B4 | Crates, sand and the sea | `lines.json` `bonusMidway.supplyRun`, `bonusCrate.supplyRun.h4` | The table stands on the beach | "This crate is half full of sand. Who packed it?" (`bonusMidway.supplyRun.h1`); "Catch it before it hits the sand." (`bonusCrate.supplyRun.h4`); "That crate's going to the fish." (`bonusCrateMissed.supplyRun.h0`) | none needed | S7 |
| B5 | "Sticky crate. Who spilled the soda?" | `lines.json` `bonusMidway.supplyRun.d1` | A spilled soda on the board | quoted | a sticky ring and a wet corner on the board | S2 |
| B6 | Salvage magnet | `supply_run.dart` (`MAGNET`, "a horseshoe magnet") | A toy horseshoe magnet from the game box | "A magnet! Everything is attracted to you." (`bonusPickup.salvageMagnet.h1`) | a red horseshoe magnet with tokens stuck to it | S2 |
| B7 | Double score: gold coins | `supply_run.dart` (`DOUBLE`, "a pair of gold coins") | Two arcade tokens for the cabinet in the corner | "Gold coins! Every kill and crate pays double for a bit." (`bonusPickup.doubleScore.h0`) | two gold tokens on the board's edge | S2 |
| B8 | Stormfront: thunder | `lib/game/bonus/levels/stormfront.dart`; `plan/game-design.md` ("Bonus level: Stormfront") | Dice shaken in a cup | "Funny. That thunder sounded like someone shaking dice." (`bonusMidway.stormfront.h1`); "Who rolled for weather? I want a word." (`bonusDare.stormfront.h2`) | a dice cup shaken in S3, with the game's thunder | S3 |
| B9 | Stormfront: lightning | `plan/game-design.md` ("Lightning strikes a column after a 1.15 s tell") | Mom's camera flash | no | N1 follows a flash | S6 |
| B10 | Lightning rod | `lines.json` `bonusPickup.lightningRod` | A metal fork stood upright in a burger | "Lightning rod! You are grounded." (`bonusPickup.lightningRod.h0`) | a fork standing in a burger | S2 |
| B11 | "Somebody move the umbrella!" | `lines.json` `bonusMidway.stormfront.d2` | The patio umbrella over the table | quoted | none needed | S7 |
| B12 | "Rain? Nobody said rain was in the rules!" | `lines.json` `bonusDare.stormfront.d2` | The youngest player objecting to an event card | quoted | none needed | S3 |
| B13 | Run rule "no shields": out of stock | `lib/game/bonus/bonus_catalog.dart` (`noShield`); `lines.json` `runModifier.noShield.h0` | The soda machine is out today | "Shield modules are out of stock this sortie." | an "out of order" note on the soda machine | S4 (background) |
| B14 | Run rule "spread only" | `bonus_catalog.dart` (`spreadOnly`); `lines.json` `runModifier.spreadOnly.h0` | Only one flavour today | "Supply only has spread modules today." | a specials board with one item crossed out | S5 (background) |
| B15 | Run rule "heavy ordnance" | `bonus_catalog.dart` (`heavyOrdnance`); `lines.json` `runModifier.heavyOrdnance.h0` | Extra large portions today | "Extra blast rounds in the supply chain this run. Boom!" | "extra large today" on the specials board | S5 (background) |
| B16 | "Can we play that one again? Please?" | `lines.json` `bonusCleared.supplyRun.h3` | The little brother, exactly as he is | quoted | he says "again?" in the cinematic | S6 |

### 2.7 Weather and transitions

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| W1 | Fog in many soft layers; waves rise out of it | `openspec/changes/fog-restoration/proposal.md` | Smoke from the grill drifting over the table | "Ash cover is heavy. Trust your instruments over your eyes." (`sectorStart.3.h2`) | smoke drifts across the board | S2, S5 |
| W2 | Rain on one regular level in four | `openspec/changes/dynamic-weather/proposal.md` ("drizzle, rain or downpour") | The patio misters switching on | no | N18; misters hiss above the umbrella | S4 (background) |
| W3 | Rain starts dry and builds, or eases off | `openspec/changes/dynamic-weather/proposal.md` | The misters run on a timer | no | none needed | S4 (background) |
| W4 | Cloud shadows on the ground | `art/families/ground-atmosphere.json` (`cloudShadow`) | The umbrella's shadow moving across the board as the sun drops | no | the shadow's edge crosses the board | S2 |
| W5 | Ground haze layers | `art/families/ground-atmosphere.json` (`dustVeil`, `smokeDrift`, `horizonFog`) | Blown sand and sea mist | "Second pass! Watch the fog!" (`sentinelRushAgain.h1`) | none needed | S7 |
| W6 | Sector change: rout, pursuit, descent | `plan/transition-research.md` (cinematic-flow table) | Clearing the pieces, moving the pawn, setting up the next region | "Regroup on the carrier lane. Briefing in a moment." (pending, `levelClear.transition`) | none needed | S2 |
| W7 | The opening: a zoom out from the cockpit panel | `plan/game-design.md` ("3-Beat Opening Cockpit Panel Zoom-Out") | The ending mirrors the opening: the game began by pulling back from a panel and ends by pulling back from the board | no | S2 repeats the opening's camera move | S2 |
| W8 | "Shopping break!" | `art/comms/pending-lines-2026-11-14.json` (`salvage.transition`, Sunny) | A break to order more food | "Best shopping trip ever." (`bonusCleared.supplyRun.h2`) | none needed | S4 |

### 2.8 Sound and music

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| A1 | Battle metal on every level | `plan/campaign-composition.md` (table of five levels) | The cook's radio at the grill | no | the same riff, thin and tinny, from a small radio | S5 |
| A2 | The shared four-note theme | `art/music/campaign.json` `theme` (`degrees_minor` 1, 3, 5, 4) | The tune the owner whistles | no | he whistles the four notes | S5 |
| A3 | The ending reprise: F major, 96 BPM | `art/music/campaign.json` `ending` ("slow original theme reprise for beach and credits") | Kept: the score of the cinematic | n/a | none needed | S2 to S7 |
| A4 | The Hollow's tolling bells | `plan/campaign-composition.md` | The "order up" bell | no | one bell stroke on the cut to S5 | S5 |
| A5 | The Carrier's organ | `plan/campaign-composition.md` ("Blackened power metal, organ") | A boardwalk carousel far down the beach | no | a faint organ in the S7 ambience | S7 |
| A6 | Ember's war drums | `plan/campaign-composition.md` ("Fiery galloping metal and war drums") | The cook's spatulas on the grill | no | two spatula taps in rhythm | S5 |
| A7 | Stormfront thunder | `web/audio/demon-audio.js` (comment: "a rising static crackle, then thunder") | Dice in a cup | "That thunder sounded like someone shaking dice." (`bonusMidway.stormfront.h1`) | cross-fade the thunder into the dice | S3 |
| A8 | The crate-open sound | `web/audio/demon-audio.js` (`crateOpen`) | A soda can opening | no | the same sound when a can opens | S4 |
| A9 | The heart and extra-life sounds | `lib/main.dart` (`audioSfx('heart')`, `audioSfx('extraLife')`) | The stamp on the card; the soda fountain filling a cup | no | the extra-life sound under the refill | S4 |
| A10 | The wave jingle | `lib/main.dart` (`audioSfx('wave')`) | The bell on the restaurant door | no | the jingle as a customer walks in | S5 (background) |
| A11 | The fleet-intact fanfare | `lib/services/audio_web.dart` (`demonAudio.fleetIntact`); `lib/comms/comms_view.dart` ("★ FLEET INTACT · ALL SHIPS HOME ★") | Everyone is still at the table when Mom calls | "All hands, all ships, all squads. Every one of you is coming home." (`flawlessVictory.h0`) | none needed | S6 |

### 2.9 UI and console

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| U1 | "KRYBOR HALL OF FAME", "KRYBOR FLEET TOP DEFENDERS" | `lib/main.dart`; `lib/game/scene.dart` | The wall of fame behind the counter | quoted (Top 10 screen) | a chalkboard headed "KRYBOR HALL OF FAME" with ten rows | S5 |
| U2 | Three-letter initials, "LEAVE YOUR MARK", "THREE CHARACTERS. THAT’S YOUR LEGEND." | `lib/main.dart` (score entry) | Initials scratched into the wooden table | quoted | three-letter initials carved in the table top, including the player's own from this run | S2 |
| U3 | "NO SIGNALS YET. BE THE FIRST." | `lib/main.dart` (empty board) | An empty chalkboard on opening day | quoted | none needed | S5 (background) |
| U4 | "TRANSMISSION 001 · KRYBOR" | `lib/main.dart` (title) | Order ticket number 001 | quoted | a receipt on the table: "KRYBOR · ORDER 001" | S2 |
| U5 | "SIGNAL PAUSED", "TAKE A BREATH." | `lib/main.dart` (pause overlay) | The game stops when the food arrives | quoted | none needed | S4 |
| U6 | The "TIPS" button on the pause screen | `lib/main.dart` ("HIDE TIPS" / "TIPS") | The tip jar on the counter | quoted | a jar labelled TIPS | S5 (background) |
| U7 | "SIGNAL RECEIVED" after saving a score | `lib/main.dart` | The pager: the order is ready | quoted | N14 | S2 |
| U8 | "CONSOLE RUN · NOT RANKED" | `lib/main.dart`; `openspec/changes/archive/2026-11-16-console-runs-final-ending/proposal.md` | "That one was practice. It doesn't count." | quoted | none needed | S3 |
| U9 | "◀  BACK TO CONSOLE" and the console | `lib/main.dart`; `lib/widgets/dev_console.dart` | The arcade cabinet in the corner | quoted | the cabinet's screen shows the console's green text | S5 (background) |
| U10 | "RESUME GAME · RESTART THE SAVED WAVE · NO POWERUPS" | `lib/main.dart`; `plan/game-design.md` ("Resume and browser history") | The board left set up for next weekend, cards back in the deck | "Same friends. Next round?" (`lib/ending/ending_page.dart`) | a phone photo of the board "so we can set it up again" | S7 |
| U11 | "DEMON / ATTACK", "THE SWARM IS ALIVE." | `lib/main.dart` (title) | The game's box lid | quoted | the box lid with both lines | S7 |
| U12 | First-wave hint cards ("Tactical briefing.") | `lib/game/hints.dart`; `lib/widgets/interlude_card.dart` | Rule cards from the box | "Watch the wings, then sidestep the dive." (`hints.dart`) | a few rule cards beside the board | S2 |
| U13 | The steering yoke and cockpit panel | `plan/game-design.md` ("Steering Yoke & Gun Angle Gimbal"); `art/families/flight-joystick.json` | The cabinet's joystick, and the kid's hand steering the ship figure | no | the pilot's hand on the ship figure | S3 |
| U14 | "Thanks for keeping the sky interesting." | `lib/ending/ending_page.dart` (credits) | Kept: the last credit line, over the evening sky | quoted | none needed | S7 |
| U15 | The hall-of-heroes backdrop | `art/families/widescreen-backdrops.json` (`hall`: "rows of gold medals and star emblems in glowing alcoves") | The restaurant wall of framed photos and bottle caps | no | match its composition | S5 |
| U16 | Active time stops in pauses and cutscenes | `plan/game-design.md` ("pauses, introductions, salvage and cinematic travel do not count") | Eating does not count against your turn | no | none needed | S4 |

### 2.10 Medals

| # | Game detail | Where it is in the game | Reveal meaning (table / restaurant) | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| M1 | Five campaign medals | `lib/game/hints.dart` ("Collect all five medals. Liberate the frontier."); `lib/widgets/run_record.dart` ("/5 MEDALS") | Five soda bottle caps, one per round won | no | five caps in a row on the fleet side | S2 |
| M2 | Medal design depends on difficulty | `plan/game-design.md` ("Hard medals are most elaborate"); `lib/widgets/medal.dart` | Caps from different sodas: plain, striped, gold | no | three kinds of cap in the tip jar | S5 (background) |
| M3 | Mission medals: ribbon, base, accent, emblem | `lib/widgets/mission_medal_atlas.dart` (cells `ribbon.*`, `base`, `accent.*`, `emblem.*`) | Badges made at the table: a cap for the base, a folded straw wrapper for the ribbon | no | one badge pinned to a kid's shirt | S3 |
| M4 | The Supply Run and Stormfront medals | `mission_medal_atlas.dart` (`emblem.supplyRun`, `emblem.stormfront`); `art/families/mission-medals.json` (supplyRun emblem prim `canopy`) | Stickers from the event cards, stuck inside the box lid | no | the two stickers in the lid | S7 |
| M5 | Run-rule medals: no shield, spread only, heavy ordnance | `mission_medal_atlas.dart` (`emblem.noShield`, `emblem.spreadOnly`, `emblem.heavyOrdnance`) | Pins on the waitress's apron, one per daily special | no | three pins on her apron | S4 |
| M6 | Medals replace text on score rows | `openspec/changes/mission-medals/specs/mission-medals/spec.md` ("Missions are medals, not text") | The chalkboard shows little drawings beside the initials | no | chalk doodles beside each row | S5 |
| M7 | "The fleet has recognized your service / courage / resolve / valor / labor." | `lib/game/campaign_story.dart` `victories` | The brood-side kids hand over a cap after each round | quoted (victory captions) | a cap passed across the table | S3 |

### 2.11 Details that come from the finished run

These rows are the spec's "The table remembers the run" requirement. Each is drawn from data the game already
keeps, so two completions never show the same table. A replay uses the last completed run stored on the device.

| # | Run detail | Where it is in the game | What the scene shows | Already planted? | Proposed new plant | Payoff shot |
|---|---|---|---|---|---|---|
| R1 | The final score | `lib/widgets/run_record.dart` (the run record card) | The number on the order ticket the owner spikes: "ORDER 184300" | no | none needed: the player knows their own score | S5 |
| R2 | Medals won this run, 0 to 5 | `lib/widgets/run_record.dart` ("/5 MEDALS") | That many bottle caps in a row at the pilot's place (M1) | no | M1's caps | S2 |
| R3 | Lives left | `lib/main.dart` (the HUD's lives) | That many heart tokens beside the board; the stamp card shows the spare quarters (L10) | no | none needed | S2 |
| R4 | Difficulty | `openspec/specs/high-scores/spec.md` (Easy, Normal, Hard boards) | The box lid's corner flash: "JUNIOR RULES", "STANDARD RULES" or "EXPERT RULES" | no | none needed | S7 |
| R5 | The player's initials and the Top 10 last fetched | `lib/main.dart` ("KRYBOR HALL OF FAME", "LEAVE YOUR MARK") | The chalkboard behind the counter lists them; with no board fetched it lists the cast's call signs | quoted (U1, U2) | none needed | S5 (background) |
| R6 | This run's lineup: five fleet and two ground voices | `lib/comms/comms_lineup.dart`; `art/comms/cast.json` `lineup` | Only the patrons mapped to this run's lineup are on the patio; the others' seats are empty (C1) | "New sector, same promise." (`sectorStart.h0`) | none needed | S3, S7 (background) |
| R7 | Campaigns finished on this device | the flag behind "The title's ending replay SHALL be offered only after the fifth carrier has fallen at least once" (`openspec/specs/arcade-progression/spec.md`), extended to a count | The shelf in the button shot holds one brood officer per completion, up to five: Gorrak, Vexxa, Skarn, Morth, Ulgra | no | none needed | S8 |

Rows: 29 + 18 + 18 + 20 + 17 + 16 + 8 + 11 + 16 + 7 + 7 = **167**.

## 3. The twelve strongest hooks

1. Krybor is the sign over the door, and the title screen has said "KRYBOR / DEFENSE SYSTEM" all along (P1, P2).
2. The Admiral keeps saying "home", and Mom says it for real (C3).
3. "We can play this all afternoon." The sector colours run from cold blue to a red sunset (C4, P15).
4. The grumpy marshal's cap and chevron are the smiling owner's cap and logo (C23).
5. Free shields are free refills; a fading shield is an empty cup; Vexxa says "Enjoy" (L1, L2, C24).
6. Four heart quarters are four stamps on the refill card (L10).
7. The brood's glyph language is a kids' cipher, and their growls are monster voices (C16, C17).
8. Thunder is dice in a cup, and the game already says so (B8, A7).
9. "Ship's totalled, pilot's safe": nobody is ever out, pieces go back to the box lid (G10, L9).
10. "KRYBOR HALL OF FAME" and "LEAVE YOUR MARK": the player's own initials are carved in the table (U1, U2).
11. "That was my wing!", "Who moved the convoy?", "Who spilled the soda?": table talk, word for word (C21, C22, B5).
12. The stuck convoy is a delivery van in the sand, and the ruins are a sandcastle (G11, P8).

## 4. Proposed plants

All proposals. Radio lines go to a separate proposal file; nothing here edits `art/comms/lines.json`. Until
tillandsias#1103 lands, new lines would be written lines (`"pending": "text"`). All phrasing is original.

### 4.1 Radio lines

| Id | Speaker | Trigger (existing unless marked new) | Line | Plants |
|---|---|---|---|---|
| N1 | admiral | `lowLives` | "Last ship, pilot. Then we pack up. Make it a good one." | Mom, time to go home (S6) |
| N2 | admiral | `sectorStart.5` | "Sun's getting low on the Carrier. One more, then home." | sunset, home (S6) |
| N3 | vexxa | `shieldSpotted` (new brood part) | "Fine. That one is on the house." | free refills (S4) |
| N4 | vexxa | `shieldBroken` (new brood part) | "Empty already? I just topped you up!" | refills, teasing (S4) |
| N5 | vexxa | `broodTaunt` | "Sit still, little ship. I am carrying a full tray." | the waitress (S4) |
| N6 | rook | `broodTaunt` (when Gorrak speaks) | "The General sounds grumpy today. Somebody smile at him." | the nickname and the smile (S5) |
| N7 | sunny | `sectorStart.1` | "Krybor! I hear the General runs a tidy place." | the owner, the nickname (S5) |
| N8 | gorrak | `sectorStart.1` (new brood part) | "My house, my rules. And wipe your feet!" | the owner (S5) |
| N9 | gorrak | `levelClear` | "Fine. Keep the corner. You are good for business." | the corner table (S5) |
| N10 | skarn | `waveStart` (sector 3) | "Order up! I mean, wings up!" | the grill cook (S5) |
| N11 | wisp | `levelClear` | "Scoring that one. In pen." | the score pad (S2) |
| N12 | pip | `weaponPickup` | "Count the dots! Did I roll that? I rolled that!" | dice pips (S2) |
| N13 | sunny | `sectorStart.3` | "Forecast for Ember Moon: sizzling, with a chance of onions." | the grill (S5) |
| N14 | lindqvist | `transmissionMission` | "Beacon is buzzing, Overwatch. I think our number is up." | the order pager (S2) |
| N15 | voss | `terrainAhead.ruins` | "Careful. One good wave and this whole place washes out." | the sandcastle (S7) |
| N16 | kessler | `convoyStuck` | "It's the sand again! Who parks a rig on a beach?" | the delivery van (S7) |
| N17 | sliss | `broodChatter` (sector 4) | "Quiet. The big one under the table is asleep." | the dog (S7) |
| N18 | nomad | `rainStart` (new trigger; the event exists in `lib/game/game_events.dart`) | "Light rain, right on the hour. You could set a watch by it." | the patio misters (S4) |
| N19 | skritch | `bonusCrateMissed.supplyRun` | "One fry! I only took one fry!" | the seagull (S7) |
| N20 | morth | `bossDefeated` (last route only) | "Five rounds. Good game. Same table next week?" | "Same friends. Next round?" (S7) |

The lines live, with their fields, in `art/comms/endgame-lines.proposal.json`. That file adds six lines for the
**second set** (N21 to N26), which only become eligible once the ending has been seen on the device, and moves N17
and N20 into it because they say "table". Second-set lines may wink at the room: Vexxa's "Back again? I kept your
corner." (N21), Gorrak's "You again! The usual, I suppose?" (N22), the Admiral's "I said one more turn. One."
(N23, the answer to her last line in the cinematic).

How bold the first set may be, and on which tours, was open question 3 of `plan/story-hooks.md`. Decision: first-set
lines must work as plain battle chatter, at most one is spoken per sector, and N1, N2, N6 to N9 wait for tour 3.

### 4.2 Art tweaks and names

- **One logo.** The teal chevron on Gorrak's cap is the Krybor logo: on the sign, the cups, the owner's cap and the
  waitress's apron (C23).
- **Menu board** with items named after the sectors: "Ringfall Rings", "Ember Moon burger", "Frontier Fries", "The
  Carrier" (a tray combo for the whole table), "Hollow Tower" (the tall one). A price tag on each (P6, P7).
- **Kids' menu placemat** with the 26-sign brood alphabet as a decoder game, and a hand-drawn map of the five Krybor
  route names (C16, P5).
- **The box lid**: "DEMON / ATTACK", "THE SWARM IS ALIVE.", "5 rounds", with the Supply Run and Stormfront stickers
  inside (U11, P11, M4). An original box design, not modelled on any real product.
- **Figure bases**: a cyan chevron sticker on fleet toys, glyph stickers on brood figures, a tower base under Rook's
  figure, names in marker under the trucks (G1, G2, E3, C6).
- **On the table**: five bottle caps, a stamp card with four heart quarters, a sand timer, a dice cup, a red horseshoe
  magnet, five power cards, a score pad, a pager, receipt "KRYBOR · ORDER 001", a spilled-soda ring, foil scraps,
  three fries in a row, a fork standing in a burger (section 2.5, 2.6).
- **At the counter**: the "KRYBOR HALL OF FAME" chalkboard, a TIPS jar, the order bell, a small radio, the TV
  weather, the specials board (U1, U6, G6, A1, C10, B14).
- **Outside**: the lifeguard tower already in `assets/images/beach-ending.webp`, a sandcastle, a van with a wheel in
  the sand, a pelican on a post, kites, patio lanterns and misters (P8, G11, E9, G15, C8, W2).
- **The cabinet in the corner** (S5, background): an old arcade cabinet, marquee "KRYBOR DEFENSE SYSTEM", attract
  loop running. An original cabinet, no real machine's likeness. It explains the title screen; it is not a second
  twist (decision D9).
- **S8, the button**: a shelf by the register marked LOST + FOUND, with one plastic brood officer per campaign
  finished on this device (R7). The waitress stands the teal marshal with the others. For four frames its eyes
  catch the lamp.
- **In-game, optional**: a tiny teal chevron on one Krybor outpost landmark (`outpost-dome` in
  `art/families/flyover-backgrounds.json`), so the logo is on screen from sector 1.

## 5. Conflicts and open questions

1. **Who the General and the cadet are.** The brief names ranks no cast member holds. Section 1 recommends Gorrak
   (nickname) and Vexxa (re-rank), which makes the two staff members brood officers while the brief says "the radio
   cast appears as bystanders" next to the human Admiral. If the operator meant humans, the picks become a new
   General and Wisp or a new cadet.
2. **A prominent character who speaks in glyphs.** If Vexxa is the cadet, her lines are glyphs with a gloss and
   reversed audio. Open question 7 of `plan/story-hooks.md` (voice the brood more plainly?) decides how well players
   can follow her.
3. **Beach versus restaurant.** The shipped canon says "on a San Diego beach": `lib/ending/ending_page.dart` (the
   semantics text), `openspec/specs/arcade-progression/spec.md` ("The beach ending and credits"), the
   `arcade-presentation` requirement "Beach reveal and credits" in `openspec/changes/battle-metal-radio-rework`,
   `art/music/campaign.json` (`ending.arc`), and the tooltip "Replay beach ending" in `lib/main.dart`. The image
   `assets/images/beach-ending.webp` shows a wooden table on open sand with palms and a lifeguard tower, and no
   building. A beachfront patio reconciles them, but the requirement text and the image need a MODIFIED delta.
4. **Real demons at the table.** The canon says "teenage human and demon friends", and the image shows two winged,
   horned demon teenagers (one blue, one purple) eating burgers. Under "the kids imagined it", the demons are
   imagined too. Options: the brood-side kids wear horned hoodies in teal and violet, or the last frame keeps one
   wink (a shadow with wings). The operator must choose.
5. **Teenagers or kids.** The canon says teenagers; the new brief says kids, and a teenage waitress who teases
   them. The waitress should be visibly older than the players, so the players are about nine to twelve.
6. **Who the pilot is.** The player is never named or shown. Recommendation in section 1.3: hands only.
   `plan/story-hooks.md` question 3 (do the players map onto call signs?) is answered by the table in 1.3 if the
   operator accepts it.
7. **The Admiral's age.** `cast.json` gives her as in her sixties. As the mother of young kids she reads as a
   grandmother. Either the kids imagine her grander and older, or S6 shows a grandmother and the line stays "time
   to go home". Pip is "19" the same way: the age the little brother wishes he were.
8. **The brood's colours.** The image seats a blue and a purple friend on the brood side. This ledger gives teal to
   the owner and violet to the waitress, and makes the brood-side kids Ulgra (crimson) and Morth (gold). The new
   cinematic replaces the image, so the kids' clothes can follow either scheme.
9. **Krybor's place in the story.** In the game Krybor is the human frontier the fleet defends
   (`campaign_story.dart`), and the brood attacks it. If the owner is the brood's marshal, he attacks his own
   restaurant. It reads as a joke (the kids made the boss of the place the boss of the baddies), but it is a
   choice.
10. **The sign.** The brief says "Krybor is the restaurant's name". The UI says "KRYBOR" everywhere. The sign
    should read KRYBOR, with no possessive, unless the operator prefers "Krybor's".
11. **Dark captions.** Two campaign texts are grimmer than a kids' game: "The brood left no survivors."
    (`routeDetails[1][2]`) and "Total fleet victory or extinction across Tour V!" (`tourEscalation(4)`). They sit
    oddly beside "allies never die". Kids do talk like this in play, so they can stay, or be softened.
12. **Nobody knows, so far.** `plan/story-hooks.md` wrote every hint so that no character seems to know. Proposals
    N1, N2, N8 and N20 lean further. Question 2 there (may any character seem to know?) is still open.
13. **The cooler and the umbrella.** "Loser carries the cooler." (`bonusDare.stormfront.h0`) fits a beach picnic
    better than a restaurant. Reading: the families walked up from the beach with their cooler. The umbrella fits
    the patio as it is.
14. **Length.** The brief says "a few seconds long"; eight shots with exclusive dialogue is more than that. Many
    rows are marked "(background)" so one shot can pay several rows, but the operator should confirm the length.
    Skip and reduced motion must stay (`arcade-presentation`, "Beach reveal and credits").
15. **Voices.** The cinematic's exclusive dialogue cannot be recorded until tillandsias#1103 lands. Until then it
    is subtitles, or the three bystanders speak with their existing Kokoro voices.
16. **Mom says go home, the caption says "Next round?".** Both hold if the caption is the kids' answer: next
    weekend, same table (U10, N20).
17. **Two naming schemes for the carrier.** The campaign calls its forms Brood Ark, Siege Carrier, Brood Citadel
    and Brood Flagship (`campaign_story.dart`); the art guide calls them Thornwake Carrier, Broodmother, Siege-Ark
    and Bastion (`docs/styleguide/alien-capital-ships.md`). "Bastion" is also Maj. March's call sign. The box lid
    and the cards should use one scheme.
18. **The Hollow.** Its green palette has no obvious match at a burger restaurant. The sandcastle reading rests on
    its towers, arches and "ancient" ruins, not on colour (P8, P15).
