# Render ledger: flight joystick (J1)

The production ledger of the control pad's flight stick: every run, every pick and why, and how to rebuild it.
- Direction: `plan/operator-feedback-2026-11-16.md` J1.
- Change: `openspec/changes/flight-joystick` (design §1–5).
- Kit: `art/families/flight-joystick.json`.
- Run log: `art/families/flight-joystick-runs.json`.

The operator delegated the picks (project memory "autonomy"); each is recorded with its reasons and rejections.

Branch `work/flight-joystick` (worktree `~/.cache/tillandsias-project/worktrees/flight-joystick`), off `game` at
1c670982.

## 0. How to rebuild (no GPU)

```sh
lua tools/rigkit/bake_poses.lua art/families/flight-joystick.json stick --texel 1.0 --cols 5 \
  --atlas assets/images/flight-joystick.png \
  --dart lib/widgets/flight_joystick_atlas.dart FlightJoystickAtlas \
  --sheet art/contact/flight-joystick-tilt-grid.png "FLIGHT STICK TILT GRID: 8 DIRECTIONS X 9/18/27 DEG + REST (PICK 7030005, TEXEL 1.0, SHOWN X3)"
```

It runs the rig (hero view, clay per pose), fits the committed pick
(`art/sprites/sources/flight-joystick/hero/7030005.png`, registered by the silhouette box), bakes the 25 poses, and
finishes and packs the atlas: about 11 s at 8 threads. The in-game sheet:

```sh
flutter test test/flight_joystick_review_test.dart --dart-define=FLIGHT_JOYSTICK_CONTACT=true \
  --dart-define=FLIGHT_JOYSTICK_FONTS=<folder with Roboto-Regular.ttf and Roboto-Bold.ttf>
```

## 1. Library extensions (generic)
- `tools/rigkit`: an optional family `articulation` block (pivot, dirs, tilts, per-slot follow factor and pivot);
  `rigkit.poses / pose_matrix / apply_pose`; the frame holds every pose; `rig.py --pose-passes clay,…`;
  `bake.py --poses 1` (parts move with their projected texture); `bake_poses.lua`. Anchors are now optional.
- `tools/rigsheet`: `fit … bbox` (register a raw's subject box to the clay silhouette box), `poseatlas` (finish,
  shared-cell trim, pack, generated Dart), `posesheet`, `posecands`.
- Carrier regression: `rig.py art/families/alien-carriers.json --check --hulls carrier1-thorn` is still ok.

## 2. Model (CPU, clay only)
1. **v1**: base 52 units wide, short grip with two thumb keys. The base dominated the frame and the grip head with
   two dots under a dome read as a face (the carrier head-reading lesson). Rejected on the first clay preview.
2. **v2 (current)**: base 48 × 35, a taller grip (31–57), one hat switch, the trigger paddle 4.6× wider than deep so its
   amber tips show beside the grip from the pilot's seat, the mint band raised proud of the grip. Clay tilt grid
   checked at all 25 poses before any GPU.

## 3. Hero (GPU)
All one-image edits of the rest-pose control (`/work/tmp/imagegen/flight-joystick/ctl1.png`, clay + hints on the green
key) with the committed `art/workflows/sprites/carrier-hero-qwen-fast.json` (Qwen-Image-Edit 2511 + Lightning 4-step,
1.6 MP). No downloads, one job at a time, the studio never restarted.

| Job | Prompt | Seeds | Verdict |
| --- | --- | --- | --- |
| st-…-112 | hero + rugged | 7010000–03 | Rejected: rust, stencilled text, hazard signs, an extra orange button on the base |
| st-…-113 | hero + clean | 7020000–03 | Rejected: the shared "worn paint" clause still painted rust; an extra button or lever in every seed |
| st-…-114 | hero v2 (clean satin, "nothing else on the base", negative: rust, extra buttons, levers, signs) + clean | 7030000–05 | **Pick 7030005** |

**Pick 7030005**: a clean satin slate base, mint ring and cyan arrows, a ribbed navy grip with a glowing band, a red
fire button, grey back bolts. Rejected in the same batch: 7030001 (orange bolts read as extra buttons), 7030002 (an
extra lever). Runners-up: 7030000, 7030003 and 7030004 (an orange front strip instead of the mint status light).

No full-model (40-step) repaint: at 52 × 66 finished texels the Lightning detail already exceeds the finish.

**Framing drift.** The edit re-framed the small subject (taller and higher than the control). The first bake projected
the base onto the grip. Fix: `rigsheet fit … bbox`. After it, the rest pose matches the raw.

## 4. Bake, finish, atlas
- 25 poses (rest + 8 directions × 9°, 18°, 27°); the boot leans by 0.45 about its foot.
- Projection bake: 26 renders in 4.1 s.
- Finish at texel 1.0 with the UI palette plus a **navy ramp**. Without it, the painted navy grip quantised to the
  pad's own navy (#101F2D) and vanished on the pad.
- Atlas `assets/images/flight-joystick.png`: 260 × 330 (5 × 5 cells of 52 × 66), **25,596 bytes PNG, 0.34 MB
  resident**.

## 5. Runtime picks (delegated)
- **Forward axis = flight speed.** The ship only moves sideways while piloting. Forward lean comes from the world's
  speed above cruise × the carrier climb's flow boost, so "up-right fast" is a real in-game state (strafing right
  during the carrier climb).
- **Eight directions, three steps, nearest frame, no crossfade.** A crossfade ghosts a doubled stick.
- **Ease**: rate 14/s out and 9/s back. The ticker stops at rest, so the stick is idle when the ship is.
- **Reduced motion**: snap, first step only.
- **No idle wiggle.** The brief says rest when idle. The affordance comes from the art (lit arrows, ring light) and a
  flat mint under-glow that brightens on touch.
- **Hint**: `DRAG TO PILOT` (the operator's words) without the `◀ ▶` glyphs, which now live on the stick's base.
- **Centred**: equal flex on both sides puts the stick at the pad centre, under the arena.

## 6. Sheets
- `art/contact/flight-joystick-candidates.png`: the control and the 14 candidates, each raw and finished at the
  stored density, with the pick outlined.
- `art/contact/flight-joystick-tilt-grid.png`: clay and finished rows per tilt × 8 directions, plus rest (×3).
- `art/contact/flight-joystick-ingame.png`: 360 × 780 at DPR 2. Rest (sector 1), moving left at top speed, and up-right
  fast (the carrier climb, flow boost 1.78, strafing right). Shown as the pages and the pads at device pixels.

## 7. Spent
- **GPU**: 14 Lightning images in 3 jobs, 279 s total (≈ 17–28 s per image, including one model load per job).
- **CPU** (Blender, 8 threads): about 1 min of wall time over ≈ 8 rig runs (2.4–2.7 s each), 4 bakes (4.1 s each)
  and 2 full rebuilds (11 s).

## 8. Left
- The grip's lower half stays dark on the pad. A brighter rim on the grip (a refine pass, or a "rim light" hint
  material) would lift it if the operator wants more pop.
- Sides seen only in tilted poses take the flat family fill (the back of the grip at 27° toward the pilot, the
  trigger). They read fine at 52 × 66; a second hero from behind would cover them if the stick ever grows.
