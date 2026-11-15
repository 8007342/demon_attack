# Proposal: demon intelligence and the sentinel final rush (W4)

## Why
Operator playtest, 2026-11-15 (`plan/operator-feedback-2026-11-15.md` W4):
- "Look at sibling atrapa (a small JEPA-style model trained to play snake); leverage it for a few levels of enemy
  intelligence; some top enemies dive between enemy fire and react to skilful play."
- "Sentinel final rush: happens a little more often; gets its own extra shield for the massive dive, its own radio
  chatter, and is properly scary and fast (today too easy)."

**What atrapa actually is** (`plan/swarm-research.md` §2.1): a plain 18 k-parameter policy MLP. It imitates a
flood-fill bot and is then refined by self-play. It has no JEPA, no latent model and no planning. Our
`SwarmPolicy` already follows the same recipe at a smaller scale. A learned world model buys nothing here, because
the game knows its true state exactly.

So we adopt the two JEPA ideas the operator hoped for as hand-written, deterministic behaviours:
- a **forecast of the player's next positions** (`PilotModel`);
- **energy-based action scoring** over exact kinematics (`DemonPlanner`). This generalises the synthetic teacher
  that trained `SwarmPolicy`.

Today's sentinel final rush has these weaknesses:
- it is rolled at 0.15 / 0.25;
- its 0.9 s tell leads into a straight 600 u/s line at a stale ship x;
- its dive shield is zeroed, so it dies to a few hits;
- it has no radio line;
- it is easy to sidestep and gives up after one pass.

## What Changes
- **Four intelligence tiers**, each defined by the brain it runs. Bodies, HP, budgets and fire rates are unchanged.

  | Tier | Who | Brain |
  |---|---|---|
  | T0 drone | small creatures | today's gated `SwarmPolicy` evade, unchanged |
  | T1 skirmisher | not-so-small creatures | the MLP proposes; a 3-candidate planner check vetoes moves into other shots |
  | T2 hunter | elites (≤ 1/2/3 per wave by the existing budget; none on route 0) | the full planner over 7 manoeuvres against every player shot, with perception delay, time-to-collision foresight and a softmin temperature |
  | T3 sentinel | sentinels | planner-backed evade plus the rush |

- **Hunters dive between player fire.** A hunter's dive keeps today's fixed aim point from the tell. On the way
  down it weaves through the gaps in the player's shot stream, re-planning at 10 Hz with bounded lateral speed. It
  never tracks the ship.
- **Hunters react to skilful play.** A bounded, deterministic `SkillMeter` (0 to the difficulty cap) is built from
  accuracy, clear tempo and near-miss dodges. It drops sharply on a lost life. It tightens hunters' reaction delay,
  foresight, temperature and dodge cooldown, switches their dive aim to the `PilotModel` forecast, and allows
  pincer dives by two hunters inside the existing dive cap. It never adds HP, births, simultaneous dives or
  bullets. The brood comments when it starts adapting.
- **Sentinel final rush:**
  - **Chance** 0.20 / 0.35 / 0.45, up to +0.10 with skill. It also triggers when a sentinel is left alone below
    half hull.
  - **Its own rush shield**, 3 / 4 + cycle÷2 / 5 + cycle÷2. Any hit damages it, unlike the dive shield. Breaking it
    mid-rush staggers the sentinel and scores a bonus.
  - **A rally–lock–rush sequence** with at least 1.0 s of tell. The rush accelerates to 640 / 780 / 880 u/s with a
    bounded homing turn (0 / 50 / 75 °/s) up to a commit line, aimed at the forecast.
  - **Up to 1 / 2 / 3 passes**, coming around through the fog between passes.
  - A berserk aura, ≤ 2 px shake (none with reduced motion) and its shadow snapping onto the ship's.
  - **Fairness guard:** a dodging ship always escapes, and a stationary ship is almost always hit.
- **Sentinel rush radio chatter.** New triggers:
  - `sentinelRushTell` (urgent, end-aligned to the rush);
  - brood `sentinelRush` war cries;
  - `sentinelRushAgain`;
  - `rushShieldBroken`;
  - `rushSurvived`;
  - brood `sentinelRushMissed`;
  - brood `broodAdapting`.

  Texts are specified for recording. Until the voice batch runs (blocked on the audio studio, tillandsias#1103),
  each line borrows an existing clip **together with its own subtitle**, so audio and text always agree. A trigger
  with no truthful placeholder stays silent until it is recorded.

## Capabilities
### Modified Capabilities
- `arcade-combat`: intelligence tiers, thread dives, bounded skill reaction, the reworked sentinel final rush, and
  rush chatter.

## Impact
- **New:** `lib/game/pilot_model.dart`, `lib/game/demon_planner.dart`, `lib/game/skill_meter.dart`,
  `lib/game/sentinel_rush.dart` (all pure Dart).
- **Changed:**
  - `lib/game/model.dart`: `_evadeSmall`, `_evade`, `_prepDive` / `_startDiveTell`, the dive branch of
    `_updateDemons`, `hitDemon`'s last-stand block, the `lastStand` update;
  - `lib/game/difficulty.dart`: rush and skill caps;
  - `lib/game/scene.dart`: berserk aura, rush shadow, shake;
  - `lib/game/music_director.dart`: rush stages;
  - `lib/game/game_events.dart`;
  - `art/comms/lines.json` plus `tools/comms_pipeline.py`: the `placeholder` field and a pending voice batch
    list; `lib/comms/comms_types.dart`: `CommsLine.clip`; `web/audio/comms-audio.js`: clip resolution;
  - `lib/comms/comms_bank.dart` (regenerated).
- **Tests:** new `test/demon_planner_test.dart`, `test/pilot_model_test.dart`, `test/skill_meter_test.dart`,
  `test/sentinel_rush_test.dart`, `test/sentinel_rush_fairness_test.dart`; extended
  `test/campaign_playtest_test.dart` metrics; `test/swarm_policy_test.dart` and the comms tests stay green.
- **Depends on** `continuous-swarm` (squads, the `AveragePilot` baseline, re-entry through the fog).
