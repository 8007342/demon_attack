# Design: fang-and-wings-comms

Inputs: the operator's request (proposal); `voice-direction` (emotion beats, banter threads), `voice-stack` design
§3.2 (tone guide, two layers, the pseudo-swear allowlist), `squad-comms`, `comms-pacing`, `comms-middle-ground`
(one channel, grace gap, lookahead, reading time), `portrait-comms-lanes` (lanes and the combined toast),
`cinematic-flow` §10.3 (no floating text), `gargoyle-insignia` and the parallel `insignia-ranks` (the marks),
`plan/endgame-reveal-ledger.md`. No outside research is claimed here: every number below is this project's own
measurement or choice.

## 1. Lore: "Fang and Wings!"

**The creed.** The brood's battle cry is its creed, three words long: "Fang and Wings!" It is self-appointed: no
one gave it to them, and they say it as if everyone should already know it.

- **Wings are given.** Every gargoyle hatches with wings; wings mean the flock. A creature that flies in formation,
  keeps its place in the skein and comes back after a dive has earned its *wing mark* (the elite grunt's winglet). A
  sentinel's escort guards instead, and wears the small crown (the crownlet): wing = brood, crown = guard.
- **Fangs are earned.** A fang means the hunt: a creature that picks its own target and dives on it. Only hunters
  wear "Fang and Wings" (the winged fang with its ember core), and only sentinels wear the winged crown of three
  fangs. A fang always means a creature that will come for the ship.
- **Why the ranks wear them.** The marks are bragging rights the brood sews onto its own heads: a grunt has nothing
  yet, so it squeaks the creed louder than anyone; an elite grunt shows off its little wings; a hunter does not need
  to say much; a sentinel intones the creed like a vow. The ladder is insignia-ranks' (grunts bare, elite grunts a
  winglet or crownlet, hunters Fang and Wings, sentinels the winged crown), so what the head shows and what the
  radio says agree.
- **The squad's reaction.** Teasing first ("Fang and Wings? More like Flap and Whine!", "Fangs for nothing!"),
  respect where it counts ("Fangs on its head? That one hunts. Watch it."), and puns. The squad uses the marks as a
  field guide, which is the player's lesson: no mark, a rookie; wings, a show-off; fangs, a hunter.
- **Two layers.** A young player hears monsters with a silly motto and badges they are very proud of. An older player
  hears a team chant at a table (the reveal, §6), a lunch special ("Sounds like the lunch special"), stickers that
  come unstuck ("My wing came unstuck!", "Not stickers! Badges!") and a dog asking for a snack (Krag). All original
  phrasing; no quotes, no catchphrases from other works; insults stay at tactics, gear and ego.

## 2. The creed as a topic

| Trigger | Who | Lines | When |
|---|---|---|---|
| `fangChatter` | brood only | 12 (`fangChatter.d0`–`d11`) | the director's brood-chatter moment: the creed stands in with chance 0.25 |
| `fangBanter` | exchange, brood first | 9 brood cries, 12 squad comebacks | the brood-chatter moment, chance 0.3 (tried first) |
| `fangTease` | exchange, squad first | 7 squad teases, 8 brood retorts | `eliteSighted` (a hunter, the first Fang and Wings on screen), chance 0.45 |

- The stand-ins live in `commsCreedSwaps` (`lib/comms/comms_creed.dart`); one draw from the director's own creed
  generator (seed 1666), so the other line picks keep their sequence. A stand-in plays only when its own cooldown has
  passed (40 s, 25 s, 45 s); otherwise the event plays as usual.
- The brood-chatter moment is the director's starvation timer (20 s of combat without a brood line). So the creed
  comes up when the brood has been quiet, never over the fight's own calls.
- Every line is one sentence on one line. Brood glosses are ≤ 49 characters, squad lines ≤ 53, cries ≤ 25
  (`commsOneLineMax` = 28).

## 3. Dive war cries

### 3.1 Event

The model already fires `divePrep` a beat (0.5 s) before every dive tell. It now also publishes `kind`, `maxHp` and
`tellIn` (no behaviour, no random draw). `GameEventObserver.onGameEvent` feeds each `divePrep` to its `DiveCryGate`
(`lib/game/dive_cry.dart`, pure Dart). When the gate lets a cry through, the observer dispatches `diveCry` (§API). The
radio and the demon choir both read that one event, so a toast and a grunt always belong to the same cry.

### 3.2 Rate limits

| Rule | Value | Why |
|---|---|---|
| One cry in flight | from the decision to the dive's start + `hold` 0.8 s | a swarm never stacks cries |
| Gap between cries | `minGap` 8 s | 9–14 cries heard per ten busy minutes (§7) |
| Chance by rank | grunt 0.15, veteran 0.35, hunter 0.6, sentinel 0.9 | only some dives cry, and the higher ranks most |
| Yield | a cry is dropped while a useful line, recommendation or warning waits for the channel | a cry is colour; they are the point of the radio |
| Airtime budget | a cry needs budget to start but spends none (like a must-play warning) | a bark of about a second, paced by this gate; spending budget pushed out the wave-start calls in the simulation |
| Simultaneous preps (a pincer) | the first prep of the frame takes the slot | both are hunters, the same rank |

The gate draws from its own generator (seed 1666, reset with the observer), never the model's.

### 3.3 Timing

- **Before the dive.** When the channel is free, the cry is a timed brood line that ends as the dive starts (within
  the dive tolerance, 0.3 s), like a squad dive call: it is heard over the tell, while the mark above the creature's
  head flashes white (`InsigniaPainter.tellOn`). The flashing mark is the link between the arena and the radio.
- **Riding the plunge.** When the squad's dive call holds that slot (it always wins: the director offers the cry only
  after the event batch), the cry starts right behind it, after the grace gap, at most `commsCryAfter` (0.7 s) after
  the dive started: "Sentinel diving, move!" then "FANG AND WINGS!" as it plunges. Later than that it is dropped.
- A cry never cuts a line, never plays late and never blocks a ground-fire warning (a must-play warning drops queued
  timed calls that overlap it, cries included).

### 3.4 Lines and voices

| Rank (mark) | Delivery | Trigger | Examples |
|---|---|---|---|
| grunt (none) | squeak: `cackle`, `warcry`, excited | `diveCry.grunt` (8 written + 4 recorded) | "Eep! Watch me!", "Fang and... eep! Wings!", "Fangy-wingy!", "Big wings someday!" |
| veteran (winglet, crownlet) | roar: `roar`, triumphant | `diveCry.veteran` (6 + 4 recorded) | "WINGS OUT!", "Got my wings! Fangs next!", "The crown dives!" |
| hunter (Fang and Wings) | snarl: `snarl`, stern | `diveCry.hunter` (6) | "Fangs first!", "Bite and dive!", "Fang and Wings, darling!" |
| sentinel (winged crown) | intoned creed: `warcry`, `roar`, `rally` | `diveCry.sentinel` (9) | "FANG AND WINGS!", "FANG! AND! WINGS!", "BY FANG AND WING!" |

- **Species voices.** Each species has a voice on the brood net: teal → Skritch (the teal scout imp), violet →
  Grunnok (the violet brute), coral → Blatch (the coral gunner), gold → Morth (the gold-and-bone prelate). A cry
  picks from its species' voice and from voices that belong to no species (Nibb, Krag, Sliss and the officers), never
  from another species' voice (`commsCryLines`). So the brood lane's portrait tells the species and the words tell
  the rank.
- The four recorded `divePrep` cries join the pools by meaning: "Watch this!", "My turn!" to grunts; "Wings in!",
  "Down we go!" to veterans. They keep their own clips and voices.
- `divePrep` no longer offers a brood cry itself in timed pacing; the legacy (untimed) pacing still does.

### 3.5 Display: a brood-lane toast, not a floating bubble

The cry is an ordinary brood radio line: the right lane's toast in portrait, the brood tile in landscape. A floating
bubble over the diving demon was considered and rejected:

1. `cinematic-flow` §10.3: the operator removed text that showed "floating randomly without windows or toasts"; the
   squad-comms purpose is a radio "instead of floating text". A toast is a window.
2. A bubble rides the dive path toward the ship: it hides the most dangerous creature at its most dangerous moment,
   and at the tell it sits on the mark the player should be reading.
3. `comms-middle-ground` gives every line its reading time and keeps the channel to one voice; the lanes'
   per-lane FIFO, stale drop (2 s after its end) and cap of two waiting already bound a burst. A bubble would need
   its own clock, outside the director's pacing.
4. The arena already carries the in-world half of the cry: the tell's white flash on the mark. The toast names it.

### 3.6 Measured (test/comms_pacing_sim.dart, sector 3, 600 s, seeds 4 / 11 / 23)

See §7.

## 4. Banter threads in the combined toast

`fangBanter` and `fangTease` are ordinary exchanges, so `portrait-comms-lanes` shows each as one combined toast across
both lanes (`A → B`). Every comeback answers the creed in general, so any pairing reads; `commsCreedThreads` names
the answers written for an opening, and the director's reply pick prefers them when their speaker is on the call (or,
for the squad, on this run's lineup). Examples:

| Opening | Answer |
|---|---|
| Gorrak: "Look up, pilot! FANG AND WINGS!" | Rook: "Fang and Wings? More like Flap and Whine!" / Admiral: "Mottos don't fly. Pilots do." |
| Vexxa: "Fang and Wings, shiny-shell. Read it and weep." | Sparrow: "Fang and Wings? Fangs for nothing!" / Anvil: "Nice wings. Mine came with engines." |
| Skarn: "FANG AND WINGS! Feel the heat!" | Sunny: "Fangs and wings? Sounds like the lunch special." / Kessler: "Fang and Wings? Down here it's Tracks and Treads!" |
| Morth: "Every fang is earned. Every wing is sworn." | Nomad: "Every flock needs a motto. Ours is duck." / Lindqvist: "Battle cry logged. Threat level unchanged." |
| Nibb: "Fang and Wings! I said it right!" | Sunny (lunch special) / Pip: "Can I earn a fang too? For the fleet, I mean!" |
| Rook: "Hey, Fangs! Your little wings are crooked!" | Skritch: "Not stickers! Badges! Very serious badges!" / Vexxa: "These wings are EARNED, tin-can!" |
| Sparrow: "That one has wings on its head. Is that a hat?" | Grunnok: "It is a crown! A small one! Still counts!" |
| Pip: "How come the little ones don't get badges?" | Morth: "Rookies earn wings first. Fangs come after." / Nibb: "I get my wings next week!" |
| Kestrel: "Fangs on its head? That one hunts. Watch it." | Blatch: "Yes. Fear the fangs." / Gorrak: "Mock the marks again. I dare you!" |

This is the cheap form of `voice-direction`'s threads (§3.2 there): two turns, paired by id in Dart, no schema change.
When v6 threads land, these pairs move into `lines.json` `threads`.

## 5. Line ids (appended; clip ids are positional)

| Trigger | Ids | Side |
|---|---|---|
| `diveCry.grunt` | `.d0`–`.d7` | brood |
| `diveCry.veteran` | `.d0`–`.d5` | brood |
| `diveCry.hunter` | `.d0`–`.d5` | brood |
| `diveCry.sentinel` | `.d0`–`.d8` | brood |
| `fangChatter` | `.d0`–`.d11` | brood |
| `fangBanter` | `.h0`–`.h11`, `.d0`–`.d8` | both (brood first) |
| `fangTease` | `.h0`–`.h6`, `.d0`–`.d7` | both (squad first) |
| `spearThrow` | `.d0` Grunnok "Catch!", `.d1` Krag "Long fang! Hrrah!", `.d2` Skarn "Special delivery!", `.d3` Blatch "Fang from afar!", `.d4` Vexxa "Heads up, shiny-shell!", `.d5` Gorrak "Fang and Wings! THROW!" | brood |

All eight triggers are `"pending": "text"`: their own words, silent, mouth closed, until recorded (tillandsias#1103).
They are listed in `plan/audio-studio/voice-batch-pending.md`. Demon-choir's grunts are the cries' first sound.

## 6. Second run: the team name

At Krybor, "Fang and Wings" is the brood-side kids' team name, written at the top of their column on the score pad
and printed on the backs of their horned hoodies (reveal ledger D5). They named it over a basket of chicken wings,
and the youngest wore plastic vampire fangs to the table. On a second run every creed line lands twice: the chant of
a team at a board game, "Sounds like the lunch special", the wing stickers that come unstuck, and Nibb's "I get my
wings next week!" (next visit). Ledger row E19 and proposed plants N21–N22 (`plan/endgame-reveal-ledger.md`).

## §API: for demon-choir, spear-bearers and insignia-ranks

### `diveCry` (`GameEventNames.diveCry`, dispatched through `dispatchGameEvent`)

Raised by `GameEventObserver.onGameEvent` when its `DiveCryGate` lets a `divePrep` cry. Subscribe with
`GameEvents.listen`.

| Key | Type | Meaning |
|---|---|---|
| `rank`, `variant` | String | `grunt`, `veteran`, `hunter`, `sentinel` (`BroodRank.name`) |
| `species` | String | `teal`, `violet`, `coral`, `gold` (`broodSpecies[kind]`) |
| `kind` | int | `Demon.kind`, 0–3 |
| `x`, `y` | double | the diver's arena position at the decision |
| `diveIn` | double | real seconds from now until the dive starts (the commit): the beat plus the tell, at this difficulty's pace |
| `tellIn` | double | real seconds from now until the tell starts (≤ `diveIn`) |
| `intensity` | double | 0.25, 0.5, 0.75, 1.0 by rank: how big the grunt may be |
| `cry` | int | running id since the observer's last reset |
| `clock` | double | model clock at the decision |
| `mark` | String? | insignia-ranks' `RankMark` name, once the model publishes it |

- **Timing for the choir.** Land the grunt's attack on the dive's start (`now + diveIn`), snapped to the nearest beat
  or half beat no more than 0.3 s away (the radio's dive tolerance); if no beat is that close, land it on the tell
  (`now + tellIn`) instead. At most one cry is in flight, so the choir never needs to mix two.
- The radio may drop its toast (a busy channel, a waiting recommendation). The cry still happened: the choir plays it
  regardless, so the arena keeps the brood's voice even when the radio is busy.
- Sizing: `intensity` 1.0 is a sentinel's intoned "FANG AND WINGS" (three syllables, low); 0.25 a grunt's squeak.

### `spearThrow` (`GameEventNames.spearThrow`)

For spear-bearers: queue a structured `GameEvent(GameEventNames.spearThrow, {'x': …, 'y': …})` from the model when a
spear leaves the hand. The director voices `spearThrow.d0`–`d5` (brood lane, chance 0.6, cooldown 5 s). The constant
is defined here; please reuse it rather than adding a second one. If the throw is timed (a wind-up), add
`endIn: <seconds until release>` and the generic timed path ends the line on the release.

### The rank and insignia-ranks' marks

`BroodRank.of` reads an optional `mark` (`RankMark.name`). Without it, the stand-in is: sentinel, elite → hunter,
`maxHp ≥ 4` → veteran, else grunt. When insignia-ranks has merged, whichever change lands second adds one line to
`ArcadeModel._prepDive`: `'mark': InsigniaRanks.markOf(d).name`. Spear-bearers wear the crownlet, so their dives cry
as veterans; their throw shout is separate.

## 7. Measured

Paced-airtime simulation (`test/comms_pacing_sim.dart`, which now raises the cries as the observer does), busy sector
3, 600 s:

| Seed | Paced airtime, busy (35–45 %) | Paced, calm (< 30 %) | Cries heard, busy | Cries offered (riding the plunge) | Recommendations within 8 s | Wave-start lines, busy |
|---|---|---|---|---|---|---|
| 4 | 40.0 % | 25.3 % | 14 | 14 (9) | 24/25 | 9 |
| 11 | 41.0 % | 26.0 % | 10 | 15 (15) | 21/22 | 6 |
| 23 | 40.2 % | 25.6 % | 9 | 10 (8) | 21/21 | 10 |

Before this change: 4–7 recorded `divePrep` cries per busy ten minutes; paced airtime 38.8–40.2 %.

- No overlaps, no cut line, every pacing target of `comms-middle-ground` met (`test/comms_pacing_test.dart`).
- How it was tuned: with a 6 s gap and cries spending budget, seed 11 heard only 2–4 wave-start lines (the test
  wants more than 4) and once missed a recommendation for 12 s. Exempting cries from the budget and an 8 s gap fixed
  both. The simulation is chaotic: with the gate seeded 1666 (the game's seed) instead of the simulation's seed,
  seed 4 misses the recommendation of its opening second (t = 5 s, while a cry is on air and a dive call is due),
  so the sim seeds the gate from its own seed like its other generators. The cry rate is a judgement call for the
  playtest (§8).

## 8. Open questions

1. Rates: 9–14 cries heard per ten busy minutes, one per 45–65 s (§7). More cries need more airtime or fewer other lines; the
   operator decides after a playtest.
2. The species voices put a named minion's portrait on every cry of that species (Skritch "is" the teal flock's
   channel). If the operator wants anonymous cries, a generic brood portrait per species is a portrait-pipeline job.
3. "Fang and Wings" spelling: the operator wrote both "Fang and Wings" and "Fangs and Wings". The creed is "Fang and
   Wings" (singular fang, the emblem); squad lines sometimes say "Fangs and wings" when they mean the marks.
4. Plants N21–N22 in the ledger (hoodie print, score pad) are proposals for the endgame cinematic's storyboard.
