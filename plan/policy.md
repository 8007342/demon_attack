# Tiny offline Swarm JEV action prior (`SwarmPolicy`)

`lib/game/swarm_policy.dart` contains a trained `10→16→4` neural action prior: **244 parameters**, a `tanh` hidden activation, and `softmax` scores ordered **`hold`, `evade_left`, `evade_right`, `dive_commit`**. The six-decimal weight JSON payload is **2,326 bytes**, well below the 5 KB budget. It uses Dart core only, with the weights compiled in as constants: no downloads, inference runtime, or asset loading. The manifest (`assets/policy/manifest.json`) records training provenance, confusion matrix, and held-out parity fixtures.

Run from the repository root (about 3–4 s):

```sh
node scripts/train-policy.mjs
flutter test test/swarm_policy_test.dart
```

## Training setup

- **Method:** deterministic seeded SGD with cross-entropy loss, per-example updates, and a shuffled training order (following sibling project `8007342/ranitas` `scripts/train-policy.mjs`).
- **Data:** 24,000 training examples; 4,000 held-out examples.
- **Schedule:** 95 epochs; learning rate `0.024 / (1 + epoch/45)`.
- **Seeds:** train generator `1724`, held-out generator `90421`, initialization and shuffle `731`.
- **Evaluation:** evaluated on the weights after rounding to the six exported decimal places.

## Exact encoder (`SwarmPolicy.encode`)

Inputs are normalized arena coordinates (`360 × 520`), approaching player shot position and lateral velocity (capturing **sling shooting** and **spread** trajectories), player ship position and lateral velocity, local Boids neighbor crowding balance, creature health ratio, and creature tier factor. Every feature is clipped to `[-1, 1]` in this order:

| Index | Formula | Meaning |
| ---: | --- | --- |
| 0 | `(demonX - 180.0) / 160.0` | Normalized horizontal position (wall proximity awareness) |
| 1 | `(demonY - 140.0) / 100.0` | Normalized vertical patrol depth |
| 2 | `(shotX - demonX) / 72.0` | Lateral offset of nearest incoming player shot |
| 3 | `(demonY - shotY) / 160.0` | Vertical distance to incoming player shot |
| 4 | `shotVx / 90.0` | Lateral velocity of incoming shot (sling-shot / spread angle) |
| 5 | `(shipX - demonX) / 180.0` | Lateral offset to player ship |
| 6 | `shipVx / 350.0` | Player ship lateral velocity |
| 7 | `crowdBalance` | Signed Boids neighbor balance (`(right - left) / 4.0`) |
| 8 | `2.0 * healthRatio - 1.0` | Normalized creature remaining health |
| 9 | `tierFactor` | `-0.75` small, `+0.35` not-so-small, `+1.0` elite |

## Synthetic teacher and measured results

The teacher evaluates all four candidate maneuvers (`hold` `dx=0`, `evade_left` `dx=-26`, `evade_right` `dx=+26`, `dive_commit` toward predicted `shipX + shipVx * 0.22`) across 10 lookahead samples over `0.32 s` against the incoming projectile vector `(shotX + shotVx * t, shotY - 385 * t)`, combining projectile clearance, arena wall margins (`x in [34, 326]`), Boids neighbor crowding penalties, and predatory dive alignment.

**Result:** the trained network scored **3,879 / 4,000 = 96.98%** held-out teacher agreement against a majority-class baseline of **29.68%**:

| Teacher \ Prediction | `hold` | `evade_left` | `evade_right` | `dive_commit` |
| --- | ---: | ---: | ---: | ---: |
| `hold` | 776 | 10 | 6 | 16 |
| `evade_left` | 2 | 1154 | 29 | 2 |
| `evade_right` | 3 | 35 | 1103 | 4 |
| `dive_commit` | 7 | 3 | 4 | 846 |

## Intelligence tiers and the planner as teacher (demon-intelligence, 2026-11-15)

`SwarmPolicy` stays the brain of the drones (T0) and proposes the skirmishers' (T1) sidesteps, which a
three-candidate check of the energy planner (`lib/game/demon_planner.dart`) vetoes when they run into more danger
than holding. Hunters (T2, elites) and sentinels (T3) run the planner itself: candidate manoeuvres over a short
duration, scored by time-to-collision danger against every visible player shot, walls, crowding, a leash to the
squad's pattern target, a dive-commit reward and hysteresis; a softmin choice from the planner's own seeded PRNG.
Tiers only exist from route 1; route 0 is bit-identical to the policy-only swarm. Design:
`openspec/changes/demon-intelligence/design.md` §3-§4.

The planner is the **teacher of record** for any future retraining (the atrapa workflow, design §1). No training is
run in this change; when the MLP is retrained:

1. **Teacher.** Generate labels with the Dart planner (T1 config, one shot, the teacher's geometry — see
   `test/demon_planner_test.dart` `parityConfig`) instead of the JS copy of the old teacher in
   `scripts/train-policy.mjs`. The planner agrees with that old teacher on 98.2 % of the held-out states some action
   escapes (`node scripts/train-policy.mjs --fixtures` exports them to `test/fixtures/policy_heldout.json`); where no
   action escapes, the old teacher minimises penetration and the planner maximises time to contact.
2. **Fixtures.** Write the planner-labelled train and held-out sets as fixtures, so the JS trainer reads exactly
   what the Dart planner decided (no second implementation of the teacher).
3. **Manifest.** Keep `assets/policy/manifest.json` checksummed with its parity cases; `test/swarm_policy_test.dart`
   checks the compiled weights against them.
4. **Selection.** Select checkpoints on held-out seeds only (never on the states trained on), and re-run the
   swarm calibration (`test/swarm_calibration_test.dart`) before shipping new weights.
