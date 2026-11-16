# End-game cinematic: storyboard and shot list

Change `endgame-cinematic`. Look and rules: `docs/styleguide/endgame-cinematic.md`. Details and their plants:
`plan/endgame-reveal-ledger.md`. Lines: `art/comms/endgame-lines.proposal.json`. Research:
`plan/endgame-cinematic-research.md`.

The boards are flat vector thumbnails. They fix staging, camera, timing and the colour script. They are not the
final look. Contact sheet: `art/contact/endgame-storyboard.png`.

Rebuild (no GPU, no model; ImageMagick's built-in SVG renderer needs a font file named on the command line):

```sh
lua art/storyboards/endgame/boards.lua art/storyboards/endgame
for f in art/storyboards/endgame/*.svg; do
  magick -font "/usr/share/fonts/google-noto-vf/NotoSans[wght].ttf" "$f" -resize 720x -colors 64 "${f%.svg}.png"
done
magick montage -font "/usr/share/fonts/google-noto-vf/NotoSans[wght].ttf" art/storyboards/endgame/s?-*.png \
  -tile 2x4 -geometry +8+8 -background '#fff6e6' -colors 64 art/contact/endgame-storyboard.png
```

## The story in one breath

The last carrier falls, and lands as a plastic toy on a board game. We pull back: the war was five kids and a
board on the patio of Krybor, a burger place on a San Diego beach. The enemy colonel is the teenage waitress with
the free refills. The grumpy brood marshal is the owner, who has never stopped smiling in his life. The Admiral is
Mom, and it is time to go home. One more turn, then.

Nothing is taken back. The kids won the same battle the player won, and they are as pleased about it.

## Geography (it never changes)

- The table's long side faces the camera. The fleet side sits frame left, the brood side frame right. The pilot
  sits on the near side with their back to us.
- The camera stays on the land side of the table. The sea and the low sun are always behind the table.
- The building, with the pass window and the sign, is always frame right. Staff come from the right. Mom comes
  from the left, where the grown-ups' table is.
- This one line of action holds from S2 to S7. S5 is the only shot that leaves it, and it is a clean insert
  through the pass window.

## Shot list

Total 29.0 s for S1 to S7, then the credits, then S8 (3.0 s). Times are from the first frame of S1. Line ids are
those of the proposal file.

| Shot | Time | Size and camera | Action | Dialogue and sound | Out |
|---|---|---|---|---|---|
| **S1 The last piece falls** | 0.0–3.5 | Game frame, then a locked macro at board level, 85 mm look, very shallow focus | The carrier wreck falls as in the game's victory scene. At 2.0 s it is a violet plastic carrier at the same place, angle and size, tipping over. A kid's finger has just flicked it. It clacks down on the board; the word KRYBOR is printed under it | e1 ADMIRAL (radio, losing its filter): "Overwatch to squadron. Carrier's down. All wings… come home." The rumble thins into one plastic clack. The metal track drops to a small speaker somewhere in the room. Surf and gulls start 0.6 s before the cut | **Match cut** on the fall at 2.0 s (position, angle and motion hold; material, light and sound change). Then the camera starts to rise: S2 is the same move |
| **S2 The board** | 3.5–8.5 | Crane up and back to a high three-quarter over the table, 35 mm look. Focus deepens as we rise. The one showpiece move | The whole board: four coloured regions around the Carrier, a track of squares, plastic gargoyles in five colours, white fleet ships, olive tanks, two dice on six and six, URGENT MISSION cards, sugar packets in the power-up colours, heart tokens, bottle caps, fries, a soda ring, a paper placemat with the brood alphabet | e2 KID, BROOD SIDE: "No way. You rolled a six again?" e3 KID, FLEET SIDE: "Carrier's down! That's the game!" The radio hiss is now soda fizzing | Cut on the fleet kid's arms going up |
| **S3 The players** | 8.5–12.5 | Eye-level wide across the table, 35 mm look, slow drift left | Five kids: the pilot (back to us, a bike helmet on the chair), the red-haired joker, the quiet one with the score pad, and across from them two kids in horned hoodies, crimson and gold. A toddler in a sun hat. The gold kid growls, then laughs. A bottle cap is slid across the table. Bystanders, soft: the regulars at the counter, the grown-ups' table | e4 KID, BROOD SIDE: "A rematch. After a short break." (two words in his monster voice, then his own) e5 LITTLE SISTER: "Dibs on the crunchy ones!" | Cut on a pitcher entering frame |
| **S4 Free refills** | 12.5–17.0 | Medium, low, from the kids' eye line, 50 mm look. Rack focus at 16.2 s | The waitress leans in on the near side: violet hair, violet name tag, three pins on her apron. She pours. The glass fills, the fizz rises. She nods back at the counter | e6 WAITRESS: "Refills for the fleet. On the house." e7 (stage whisper): "Don't tell the General." The fizz rises exactly like the shield hum. The ice clinks at the pickup chime's pitch | **Rack focus** from her to the pass window, then cut in on it |
| **S5 The General** | 17.0–20.0 | Medium close through the pass window, framed by order tickets, 50 mm look, slow push-in | The owner, beaming under a cap with a teal chevron. A spatula salute. He spikes a ticket (the player's score) and hits the bell. Grill flames to his right. Behind him the KRYBOR HALL OF FAME chalkboard and, in the corner, an old arcade cabinet | e8 OWNER: "Order up, table five! Smile, everybody. It's a beautiful day!" The bell is the weapon-pickup chime. The grill flare is the Ember Moon forge roar, an octave up | Cut on the bell |
| **S6 Overwatch** | 20.0–24.5 | Over the kids' shoulders, low, 50 mm look, locked | Mom stands against the low sun, gold rim light. Navy cardigan with gold buttons, a teal star on her keys, one earbud. The kids' heads turn on her first word. A beat. Her smile | e9 MOM: "Squadron. Time to go home." e10 LITTLE BROTHER: "One more turn? Please?" e11 MOM: "…One more turn." No radio at all now. The music is down to the surf | Cut on her smile |
| **S7 Krybor** | 24.5–29.0 | Crane up and back to a wide exterior, 24 mm look. It rhymes with S2 | The patio, the umbrellas, the building. The neon sign KRYBOR flickers on as the sun touches the sea: the game's violet and teal return as neon. A van with one wheel in the sand, a sandcastle, a gull with a fry, a dog asleep. Dice rattle: the kids are playing again | Captions: "SAN DIEGO · AFTER THE LAST TURN", then "Same friends. Next round?" The neon hum is the carrier field's hum. The campaign theme comes back on a ukulele for four bars | Fade to the credits |
| **S8 The button** | after the credits, 3.0 | Locked insert, 85 mm look, dusk blue with one warm lamp | A shelf by the register marked LOST + FOUND: one plastic brood officer for each campaign finished on this device. A hand stands the teal marshal with the others. For four frames its eyes catch the lamp | e12 WAITRESS (off): "Same time next week, Marshal?" One soft glint. Black | Cut to black, then the completed result |

## Transitions

| Between | Transition | Why this one |
|---|---|---|
| Game and S1 | Match cut on action | The one place where the two worlds touch. Everything else about the cut holds still so the change of material carries it |
| S1 and S2 | None: one continuous rise | The reveal is a camera move, not a cut, so the viewer finds the board themselves |
| S2, S3, S4 | Straight cuts on movement (arms up, the pitcher) | Cuts hide in motion and keep the pace of the game |
| S4 and S5 | Rack focus, then a cut in | Her nod and the focus pull point at the owner before we see him |
| S5 and S6 | Straight cut on the bell | The bell ends the staff's part; Mom's voice starts on a quiet frame |
| S6 and S7 | Cut on her smile, into a rising camera | Ends the scene on the answer "one more turn" and lets the wide shot be the breath after it |
| S7 and credits | Fade | The only fade. It marks the end |

With reduced motion on, every shot is a still, every transition is a 400 ms crossfade, and the match cut is a
crossfade between the game frame and the toy at the same position.

## Sound, start to end

1. Restaurant ambience fades in 0.6 s before the match cut, under the game's last second.
2. The Admiral's line starts with the radio effect and loses it over the cut. No later line has it.
3. The battle track does not stop at the cut. It becomes the music of a small speaker in the room, then gives way
   to the surf by S6.
4. Four game sounds come back as room sounds: the shield hum (soda fizz), the pickup chime (ice, then the bell),
   the forge roar (the grill), the carrier field hum (the neon sign).
5. The campaign theme returns once, on a ukulele, in S7.

## What changes from run to run

Seven details come from the run just finished (ledger rows R1 to R7): the score on the ticket, the bottle caps for
medals, the heart tokens for lives, the box lid's edition for the difficulty, the initials on the chalkboard, which
patrons are on the patio (this run's radio lineup), and how many officers stand on the shelf in S8.

## Files

| File | Shot |
|---|---|
| `s1-last-piece.svg`, `.png` | S1 |
| `s2-the-board.svg`, `.png` | S2 |
| `s3-the-players.svg`, `.png` | S3 |
| `s4-free-refills.svg`, `.png` | S4 |
| `s5-the-general.svg`, `.png` | S5 |
| `s6-overwatch.svg`, `.png` | S6 |
| `s7-krybor.svg`, `.png` | S7 |
| `s8-button.svg`, `.png` | S8 |
| `boards.lua` | the generator for all of them |
