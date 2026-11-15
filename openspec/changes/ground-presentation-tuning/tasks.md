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
- [ ] 4.5 Decide on the gameplay-side travel slowdown (design §3)
