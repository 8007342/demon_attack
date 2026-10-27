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
