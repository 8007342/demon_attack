# Tasks

Prerequisite: `ground-blocks-runtime`, `ground-easter-eggs`.

## 1. Pace
- [x] 1.1 `GroundPace` (anim 0.5, walker 0.3, turn 0.5, fx 0.5, egg 0.5) in `lib/game/ground_presentation.dart`
- [x] 1.2 Block painter: move / tread / walk / idle cycles, lights, totalled, pod, hulk, Chapterhouse fall, skid dust,
      trooper fall, jackpot, twirl, flourish frames
- [x] 1.3 Legacy painter: move and tank cycles, dust, wreck timeline (shock, fireball, flames, debris, puffs), ally
      dust, totalled effects, squad walk and fall
- [x] 1.4 `GroundHeading(pace:, hold:)`; hull and layer trackers at `GroundPace.turn`
- [x] 1.5 Walkers (W and K blocks) stride at `GroundPace.walker`
- [x] 1.6 Critter leaps and flee at half speed (flyover background); egg running times doubled
- [x] 1.7 Telegraph, fire, recoil, hit and tracer timing untouched; simulation fingerprint identical before/after

## 2. Sizes
- [x] 2.1 `GroundSize` and `GroundPainter.drawScale` / `allyDrawScale` (Fleet vehicles 0.5, Host vehicles 1.3,
      troopers 0.9); every part of a unit at the same scale; simulation scale, width and bodyY unchanged

## 3. Squads
- [x] 3.1 `GroundSquadLook.size`: drawn groups 1–5 (most often 2–4), rocket teams 1–3; falling in proportion to hp
- [x] 3.2 Per-trooper spacing, drift, lead/lag (eased by the marching amount), gait cadence and phase
- [x] 3.3 Per-trooper heading trackers with their own lag and hold; formation no longer mirrored; the fallen lie
      where they fell

## 4. Verification
- [x] 4.1 `test/ground_presentation_tuning_test.dart`; easter-egg running-time tests updated
- [x] 4.2 Review frames before/after; contact sheet `art/contact/ground-tuning.png`
- [x] 4.3 Render ledger §18
- [ ] 4.4 Operator playtest on a phone (pace, sizes, squads)
- [x] 4.5 Decide on the gameplay-side travel slowdown (design §3): operator delegated it; implemented (§5)

## 5. Ground travel pace (gameplay follow-up, design §3a)
- [x] 5.1 `GroundV4Tuning.skirmishPace` 0.6 / `walkerPace` 0.45 as `GroundUnit.travelPace` on skirmish approach and
      lateral speed; walkers = skirmish vehicles cast as W/K blocks (`GroundV4Tuning.walks`)
- [x] 5.2 v4 convoy advance, fall-back and lateral at the skirmish pace (not against a threat-front foe)
- [x] 5.3 Threat front untouched: travel, telegraph, launch clocks, warning bracket (test: identical threat clocks
      with the skirmish layer on and off)
- [x] 5.4 Re-balance: `assignZ` 900 → 1050, `fireStartZ` 700 → 880; v4 sim engagements within their floors;
      calibration and comms pacing outputs identical; variety test window 80 → 100 s (reshuffled draws)
- [x] 5.5 `GroundStride`: walk cycles of troopers and W/K walkers follow the ground covered (feet plant)
- [x] 5.6 `test/ground_travel_pace_test.dart`; render ledger §18 note
- [ ] 5.7 Operator playtest on a phone (travel pace, planted feet)
