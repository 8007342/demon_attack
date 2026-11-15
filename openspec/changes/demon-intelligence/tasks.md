# Tasks: demon intelligence (W4)

Prerequisite: `continuous-swarm` merged into `game`, including its Post-W3 metrics and `AveragePilot`. Branch
`work/demon-intelligence` off `game`. Each group is one commit with `flutter analyze` and `flutter test` green.
Groups 2–4 can land before group 5. The rush (5) is independent of the hunters (3–4) apart from `PilotModel`.

## 1. Forecast
- [x] 1.1 `lib/game/pilot_model.dart`: a 10 Hz ring buffer (30 samples), lane-mean EWMA, jitter, μ(τ), σ(τ),
      `pHit(x, τ, halfWidth)` (design §2). `ArcadeModel` owns one (`pilot`), fed in `_step` while combat runs and
      reset on a life loss and on `_beginLevel`.
- [x] 1.2 `test/pilot_model_test.dart`:
      - constant velocity is predicted within 2 u at τ 0.3;
      - a player oscillating around a lane is predicted toward the lane mean at τ 1.5;
      - σ grows with |v| and τ;
      - deterministic;
      - no allocation per query (ring buffer reuse).

## 2. Planner
- [x] 2.1 `lib/game/demon_planner.dart`:
      - candidates (design §3 table);
      - closed-form time-to-collision of a constant-velocity path against a shot;
      - the energy terms with named weights;
      - softmin with its own seeded PRNG;
      - perception delay (ignore shots younger than δ, back-project the rest);
      - a `PlannerConfig` per tier.
- [x] 2.2 Teacher parity: export the held-out fixtures of `assets/policy/manifest.json`, and with a single shot and
      the T1 config check that the planner's argmin agrees with the recorded teacher label on ≥ 95 %. Document
      any systematic disagreement: the planner is the exact version.
- [x] 2.3 `test/demon_planner_test.dart`:
      - a shot dead ahead is dodged away from the wall side;
      - two shots bracketing the creature → hold;
      - walls respected;
      - T → 0 is argmin;
      - same seed gives the same choice;
      - 6 decisions × 24 shots run in < 0.3 ms in total (VM median).
- [x] 2.4 Weight tuning sweep (a test-only harness over 2 000 synthetic states). Record the chosen weights and why
      in the design note.

## 3. Tiers
- [x] 3.1 `model.dart`: `tierOf(Demon)`.
      - `_evadeSmall` runs T0 unchanged; T1 adds the planner veto; T2 uses the planner with its own concurrency
        slot.
      - `_evade` (T3) is planner-backed with today's spans and cooldown.
      - Gating (sector 1 route 0, a waiting sentinel) is unchanged.
- [x] 3.2 Planner scheduling: 10 Hz per creature, staggered by `seed`, at most 6 decisions per frame (a queue).
- [x] 3.3 Tests in `test/demon_intelligence_test.dart`:
      - tier classification;
      - T0 behaviour bit-identical to today on the existing `test/swarm_policy_test.dart` fixtures;
      - a T2 elite survives a straight shot that kills a T0 at the same spot;
      - only one T0/T1 evader at a time;
      - one hunter evader at a time.

## 4. Hunters: thread dives, skill and pincers
- [x] 4.1 Thread dive in the dive branch of `_updateDemons`: a 10 Hz lateral choice {−110, 0, +110} · tempo, the
      |x − x*_line| ≤ 60 clamp, lateral acceleration ≤ 900. The vertical speed, dive shield and exit are
      unchanged. The aim x* stays fixed from the tell (`_startDiveTell`).
- [x] 4.2 `lib/game/skill_meter.dart` (design §7):
      - inputs from model counters: add `shotsFired`, `shotsHit` and `nearMisses` to `ArcadeModel`, counting
        near misses in `_collisions`;
      - per-difficulty caps;
      - the lost-life drop and freeze;
      - a checkpoint reset to 0.3.
- [x] 4.3 Skill effects: T2 δ, τ0, T and cooldown interpolation; `PilotModel` aim at s ≥ 0.4 in
      `_startDiveTell` for hunters; pincers at s ≥ 0.5 in the dive clock branch, inside
      `_maxConcurrentSmallDives`.
- [x] 4.4 Tests:
      - `test/skill_meter_test.dart`: bounded by the cap; a lost life drops it ≥ 0.35; score and power-ups do not
        move it; deterministic.
      - `test/demon_intelligence_test.dart`:
        - a thread dive passes between two shots 88 u apart that would hit a straight diver;
        - the aim never moves after the tell;
        - pincer aims are μ ± 34 and both tells are shown;
        - the dive cap is never exceeded over a 10-minute Hard sim.

## 5. Sentinel final rush
- [x] 5.1 `lib/game/sentinel_rush.dart`: a phase machine (rally, lock, rush, recover), passes, rush shield, stagger
      (design §6). The `Demon` fields `lastStand`, `rushing`, `rushVx` and `rushVy` are reused. Add `rushPhase`,
      `rushPass`, `rushShield`, `rushShieldMax`, `rushRoll`.
- [x] 5.2 `model.dart`:
      - In `_buildRoster`, store `rushRoll = random.nextDouble()` in place of the boolean draw. It is the same
        single draw, so the random sequence is unchanged; a test asserts it.
      - In `hitDemon`, the trigger (threshold or alone), the rush-shield absorption and the breaker damage.
      - The `_updateDemons` `lastStand` branch delegates to `SentinelRush.update`.
      - `difficulty.dart` gets `rushChance`, `rushShieldBase`, `rushSpeed`, `rushTurnRate`, `rushPasses` and
        `skillCap`.
- [x] 5.3 Events: `sentinelRushTell` (with `rushIn`), `sentinelRush`, `sentinelRushAgain`, `rushShieldBroken`,
      `rushSurvived`, `sentinelRushMissed`, `broodAdapting` in `game_events.dart`. Music: `music_director.dart`
      maps the rally to `lastStandTell` and the rush to peril intensity 4. `test/music_director_test.dart` stays
      green.
- [x] 5.4 Presentation in `scene.dart`:
      - berserk aura, smoke trail and the shrinking shield ring;
      - rush frames;
      - lock shudder;
      - shake ≤ 2 px, gated by reduced motion;
      - the shadow snap on lock (uses W3 `_creatureShadows`).
- [x] 5.5 `test/sentinel_rush_test.dart`:
      - rates by difficulty over 2 000 births;
      - the alone-trigger;
      - the shield absorbs hull damage, base-gun hits break it, the stagger and bonus apply;
      - passes per difficulty, then the sacrifice;
      - the tell is ≥ 1.0 s real;
      - a reduced-motion run has no shake.
- [x] 5.6 `test/sentinel_rush_fairness_test.dart`: the escape guard (≥ 99 %), the threat guard (≥ 90 %) and the
      corridor inequality, over 200 seeds × difficulty × route ≥ 1 (design §6.4).
- [x] 5.7 Update `test/sentinel_last_stand_visual_test.dart` for the new phases. Add frames to the review set
      (group 8).

## 6. Radio chatter with placeholders
- [ ] 6.1 `lib/comms/comms_types.dart`: `CommsLine.clip` (default `id`). `web/audio/comms-audio.js`: load by `clip`.
      `test-worker` audio tests stay green.
- [ ] 6.2 `tools/comms_pipeline.py`:
      - the `placeholder` field;
      - emit borrowed clip, text, mouth and duration when the line's own clip is missing;
      - leave out lines with neither;
      - write `plan/audio-studio/voice-batch-pending.md`.

      This is an existing Python tool; keep the change inside it rather than adding a new language.
- [ ] 6.3 `art/comms/lines.json`: append the triggers and lines of design §8 (append only), then regenerate
      `lib/comms/comms_bank.dart`. `comms_moments.dart`: map the new events, with the urgent tell end-aligned to
      `rushIn`.
- [ ] 6.4 Tests:
      - `test/comms_director_test.dart`: the rush tell ends within 0.3 s of the rush start; a placeholder line's
        subtitle equals the borrowed line's text; silent triggers produce nothing.
      - `test/comms_pacing_test.dart` and `test/comms_lineup_test.dart` stay green.

## 7. Calibration
- [ ] 7.1 Extend `test/support/swarm_metrics.dart` with tier, dive and rush outcomes and the s trajectory (design
      §9).
- [ ] 7.2 Run all modes. Check the acceptance list in design §9 and record the Post-W4 table in
      `plan/calibration-current.md`. If it is out, tune in this order: T2 τ0 and δ, then the thread lateral speed,
      then rush homing and speed. Never touch HP or budgets.
- [ ] 7.3 Record the atrapa-workflow note (teacher of record, fixtures, held-out selection) in `plan/policy.md` for
      any future retraining. No training is run in this change.

## 8. Review frames and playtest
- [ ] 8.1 `test/demon_intelligence_review_test.dart` writes to `.cache/demon-intelligence-review/`:
      - a hunter threading two shots;
      - a pincer tell;
      - rush rally, lock (with the shadow snapped onto the ship's), mid-rush with the aura, the shield broken with
        the stagger, the second pass coming out of the fog;
      - the reduced-motion rush.
- [ ] 8.2 Preview playtest at phone portrait: a route-1 Normal sentinel wave, captured for the operator. Note the
      "properly scary and fast" verdict as an open item for the operator.

## 9. Docs and specs
- [ ] 9.1 `plan/game-design.md` (dodging, dives, last stand), `plan/policy.md` (tiers, planner as teacher).
- [ ] 9.2 `openspec validate demon-intelligence`; sync at archive.
