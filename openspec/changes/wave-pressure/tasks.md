# Tasks

- [x] 1.1 Split `_spawnWave` into the enemy-side reset and a roster builder for any wave number.
- [x] 1.2 Early approach of the next wave at the difficulty threshold; not targetable, silent, fogged.
- [x] 1.3 Finish-first merge mirrors a fresh wave start (release, checkpoint, wave events).
- [x] 1.4 Forced join after `incomingSeconds`; a lost life pauses the clock; one sentinel at a time.
- [x] 1.5 Distance fade, harder fog on the approaching wave, mist wisps, horizon smoke band.
- [x] 1.6 Tests: threshold per difficulty, finish-first, forced join with occupancy bound, life-loss pause,
      no approach on a level's last wave, roster identical to a fresh wave.
- [x] 1.7 Campaign playtest, ground-front and perspective-parity guards unchanged and passing.
- [ ] 2.1 Operator plays it: is the pressure felt, fair, and fun on each difficulty? Tune threshold/seconds.
- [ ] 2.2 Replace the procedural mist with the ground-atmosphere atlas when it lands.
- [ ] 2.3 Radio: a line when the next wave appears on the horizon (event `incoming`), from the comms rework.
