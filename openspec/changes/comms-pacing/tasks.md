# Tasks

- [x] Seeded airtime simulation of busy and calm combat through the real bank; baseline measured on the old director
- [x] CommsPacing: airtime budget, jittered rests, flavour expiry and no stacking, message classes and cut rules
- [x] Recommendations: observer `hint` on `shieldSpotted`, new `powerupSpotted`, hint specs built from bank lines, retry after a warning
- [x] Dive calls scheduled from `divePrep.diveIn` and the sentinel tell, end-aligned within ±0.3 s; late observer calls dropped
- [x] Ground-fire beat (`groundFirePrep`, cadence unchanged) and must-play warnings ending at the launch
- [x] Subtitle hold (2.6 s human, 3.2 s demon) and larger radio and SIGINT text; compact dock still clears the HUD and the ship
- [x] Remove speech ducking, the effects side-chain and the life-loss dip; worker and Dart tests prove the music gain is constant
- [x] Tests: comms_pacing_test (duty, overlaps, cuts, dive alignment, recommendations, ground warnings), director, lineup, layout, ground and worker tests updated
- [ ] Listen in the browser: silence between transmissions, dive calls landing on the dive, ground warnings before each launch, music never dipping
