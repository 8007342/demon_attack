# Tasks

## 1. Lore and lines

- [x] 1.1 Lore note: the creed, wings given and fangs earned, why the ranks wear the marks, the squad's reaction, the two layers (design §1)
- [x] 1.2 `art/comms/lines.json`: append `diveCry.grunt|veteran|hunter|sentinel`, `fangChatter`, `fangBanter`, `fangTease`, `spearThrow` as written text (`"pending": "text"`); `python3 -I tools/comms_pipeline.py dart`
- [x] 1.3 Endgame reveal ledger: row E19 and plants N21–N22 (the kids' team name)

## 2. Dive war cries

- [x] 2.1 `divePrep` publishes `kind`, `maxHp`, `tellIn` (`lib/game/model.dart`; no behaviour, no random draw)
- [x] 2.2 `lib/game/dive_cry.dart`: `BroodRank` (reads insignia-ranks' `mark` when present), `DiveCryGate` (one in flight, 8 s gap, rank chances, own generator)
- [x] 2.3 `GameEventObserver` raises `diveCry` from `divePrep`; event names `diveCry`, `spearThrow`, `fangChatter`, `fangBanter`, `fangTease`
- [x] 2.4 Director: cries offered after the event batch, timed to end on the dive or riding the plunge behind the squad's call; species voices; a waiting useful line drops them; `divePrep` no longer cries itself in timed pacing
- [x] 2.5 The recorded `divePrep` cries join the grunt and veteran pools (`commsCryBank`)
- [x] 2.6 Cries need airtime budget to start but spend none (design §3.2, §7)

## 3. Creed topic and threads

- [x] 3.1 `commsCreedSwaps`: the creed stands in for some brood chatter and elite sightings, by its own generator and cooldowns
- [x] 3.2 `commsCreedThreads`: the reply of a creed exchange prefers the answers written for its opening

## 4. Validation

- [x] 4.1 `test/fang_and_wings_comms_test.dart`: ladder and marks, the model's fields, the observer's event, gate rate limits and determinism, rank weighting, lines per species and rank, deliveries, no borrowed voice, cry timing (free channel, plunge, yield to a recommendation), the combined-toast threads both ways, the creed in brood chatter
- [x] 4.2 `test/comms_pacing_sim.dart` raises the cries as the observer does; pacing targets still met (design §7)
- [x] 4.3 Borrowed-line count in `test/comms_director_test.dart` unchanged at 55 (comment updated)
- [x] 4.4 Gates (CLAUDE.md §2) and `openspec validate fang-and-wings-comms --strict`

## 5. Follow-ups (other changes)

- [x] 5.1 After insignia-ranks merges: `'mark': InsigniaRanks.markOf(d).name` in `ArcadeModel._prepDive` (whichever lands second)
- [x] 5.2 spear-bearers: queue `GameEventNames.spearThrow` when a spear leaves the hand (design §API)
- [x] 5.3 demon-choir: wordless grunts on `diveCry` (design §API; round 8 landed them on the dive's start)
- [ ] 5.4 Voices for the 83 written lines once tillandsias#1103 lands
- [ ] 5.5 Phone playtest of the cry rate and the toasts (operator)
