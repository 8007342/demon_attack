---
tags: [ux, animation, 25d-lighting, smootherstep, boids, ship-inertia, sling-shooting, cockpit-yoke, device-tilt, plasma-vfx, pixel-art]
languages: [dart]
since: 2026-10-26
last_verified: 2026-10-26
sources:
  - https://www.red3d.com/cwr/steer/
  - https://www.ryanjuckett.com/damped-springs/
  - https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity
  - https://docs.godotengine.org/en/stable/classes/class_tween.html
  - https://www.gdcvault.com/play/1014652/
authority: high
status: current
tier: pull-on-demand
summary_generated_by: agent-generated-at-runtime
bundled_into_image: false
committed_for_project: true
pull_recipe: see-section-pull-on-demand
---
# Arcade 2.5D Motion, Quintic Transitions, Cockpit Yoke/Tilt & Pixel VFX

@trace spec:arcade-combat, spec:arcade-presentation, spec:arcade-progression

**Version baseline**: Flutter 3.x / Flame 1.x nearest-neighbor pixel canvas (`360 × 520` logical grid)  
**Use when**: Implementing curved squadron entrances, home-tethered Boids flocking, inertial ship banking & sling-shooting, coupled cockpit yoke & calibrated 3D device-tilt gun vectoring (`±6°..±24°`), 3-beat cockpit zoom-out transitions, or thermal blackbody re-entry plasma vs. geometric force shields.

## Quick reference

| Technique & Provenance | Mathematical / Visual Rule | Gameplay & Readability Purpose |
| --- | --- | --- |
| **Quintic Smootherstep Handoff** (Perlin / sibling `ranitas`) | `u = t³(t(6t - 15) + 10)` where `u'(0)=u'(1)=0` and `u''(0)=u''(1)=0` | Blends curved entrance arcs (`enterStyle` 0..3) into active wave coordinates with **zero position or velocity snap**. |
| **Home-Tethered Arcade Boids** (Reynolds 1987/1999) | Local Separation (`<34 u`), Cohesion (`<68 u`), and Shot Evade (`dx<28, dy<95`) clamped to `±22 x / ±10 y` around `(homeX, homeY)` | Gives demon swarms organic spacing and shot-dodging life without drifting offscreen or collapsing onto the player rail. |
| **Inertial Banking & Sling-Shooting** (Juckett 2008 / sibling `cannonball`) | `shipVx` (`±330 u/s` max), `shipBank ∈ [-1, 1]` (`±0.14 rad` tilt), shot inherits `vx = shipVx * 0.38` + up to `+18%` vertical speed | Rewards rhythmic lateral strafing: banked shots curve around carrier shield/hull edges into open hatches (`sling_shot` hint). |
| **Coupled Cockpit Yoke, Interim Gun Angles & 3D Tilt** (sibling `cannonball` Wheel/Tilt + *Star Wars* 1983 + *Ikari Warriors* 1986) | `screenRoll = atan2(gx, sqrt(gy² + gz²))`, circular-mean neutral posture calibration, jump-free touch-release rebasing, stepped gun angles `±6°, ±12°, ±18°, ±24°` | Couples starfighter steering with multi-angle turret vectoring from an interactive bottom Cockpit Control Panel (Weapon/Shield Schematic + Rotating Yoke). |
| **3-Beat Cockpit Zoom-Out & Storyboard Transitions** (Cianciolo GDC 2011 / sibling `cannonball` `DepartureTimeline`) | Beat 1: tight Cockpit Panel ignition -> Beat 2: continuous zoom-out to `360 × 520` arena without fade-to-black -> Beat 3: horizon reveal & squadron entry | Motivates camera framing from the starfighter dashboard directly into live combat and bridges sectors with pictorial storyboard panels. |
| **Aerothermal Blackbody Plasma vs. Geometric Force Shields** (Aerothermal Stagnation / Riot 2020 / sibling `cannonball`) | Re-entry dive shields: white stagnation core -> solar yellow -> ablation orange -> crimson/charcoal smoke + embers (zero cyan/violet); Force shields: cool cyan/teal/violet hex/segments | Instantly distinguishes chaotic thermal atmospheric dive shields (`diveShield`) from engineered technological energy barriers. |

## Common patterns

### 1. Quintic Smootherstep Squadron Entrance (Zero-Snap Handoff)
Compute the enemy's live formation target `(formX, formY)` throughout the entrance and decay the curved entrance offset by `(1 - smootherstep(t))` so position and velocity match the formation trajectory at `t == 1.0`:

```dart
double smootherstep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Blend curved entrance offset (sweep arc, loop, figure-8, pincer) into formation:
final progress = 1.0 - (enemy.enterTime / enemy.enterDuration).clamp(0.0, 1.0);
final u = smootherstep(progress);
final envelope = 1.0 - u; // Zero 1st and 2nd derivative at progress == 1.0
enemy.x = formationX + curveOffsetX(progress, enemy.enterStyle) * envelope;
enemy.y = formationY + curveOffsetY(progress, enemy.enterStyle) * envelope;
```

### 2. Home-Tethered Boids with Incoming-Shot Evasion
Combine Reynolds local steering with a harmonic spring back to the sinusoidal formation anchor:

```dart
// 1. Separation (<34u), 2. Cohesion (<68u), 3. Evade approaching friendly bullets (dx<28, 0<dy<95)
// 4. Spring restoration toward formation anchor + bounded offset clamp:
enemy.steerVx = (enemy.steerVx + (sepX + cohX + evadeX - enemy.steerX * 4.5) * dt) * 0.90;
enemy.steerX = (enemy.steerX + enemy.steerVx * dt).clamp(-22.0, 22.0);
enemy.steerY = (enemy.steerY + enemy.steerVy * dt).clamp(-10.0, 10.0);
```

### 3. Inertial Ship Banking & Strategic Sling-Shooting
Update `shipVx` with distinct acceleration (`2200 u/s²`), deceleration (`1800 u/s²`), and reversal (`2800 u/s²`) rates; derive `shipBank` and transfer lateral momentum into fired projectiles:

```dart
final shotVx = shipVx * 0.38;
final speedBoost = 1.0 + 0.18 * (shipVx.abs() / 330.0).clamp(0.0, 1.0);
final shotVy = -390.0 * speedBoost; // +angled spread offset when Spread is active
```

### 4. Coupled Cockpit Yoke, Interim Gun Angles (`±6°..±24°`) & Calibrated 3D Tilt
Project 3D accelerometer gravity onto the screen plane (`screenRoll`), calibrate neutral hand posture via circular mean (`atan2(meanSin, meanCos)`), rebase touch pointers on multi-touch release to prevent coordinate jumps, and quantize coupled turret gun angles across discrete steps (`0°, ±6°, ±12°, ±18°, ±24°`):

```dart
// 3D gravity projection & circular-mean neutral posture delta:
final screenRoll = atan2(gx, sqrt(gy * gy + gz * gz));
final deltaRoll = atan2(sin(screenRoll - neutralRoll), cos(screenRoll - neutralRoll));

// Quantize coupled steering / yoke deflection into interim turret firing angles:
const interimAnglesDeg = <double>[-24, -18, -12, -6, 0, 6, 12, 18, 24];
```

### 5. 3-Beat Cockpit Zoom-Out & Thermal vs. Geometric Shield Palettes
- **3-Beat Opening Cockpit Zoom-Out (`DepartureTimeline` pattern)**: Start tightly framed on the bottom **Starfighter Cockpit Control Panel** (Beat 1: schematic & yoke ignition), pull the camera back continuously into the `360 × 520` arena without a fade-to-black cut (Beat 2: thruster launch onto `y = 477`), and stabilize on the planetary horizon as the first squadron enters (Beat 3).
- **Thermal Re-Entry Plasma vs. Geometric Force Shields**: Render diving creature shields (`diveShield`) strictly with a chaotic thermal blackbody ramp (`#FFFDF7` white stagnation core -> `#FFE042` solar yellow -> `#FF6B1A` ablation orange -> `#9E1B1B`/`#3B171D` crimson/charcoal smoke trail + shedding embers; **zero cyan/violet bands**). Reserve cool geometric cyan/teal/violet (`#39DFCC`, `#70F5D5`, `#A888FF`) hex/segmented barriers exclusively for technological force shields.

## Common pitfalls

- **Piecewise entrance-to-combat coordinate snaps**: Switching from an entrance spline `p_entry(t)` to an independent combat sine wave `p_combat(age)` at `t = 1` causes a visible 1-frame teleport or velocity kink unless the entrance offset multiplies `(1 - smootherstep(t))` atop the live combat anchor.
- **Untethered Boids in fixed-bottom shooters**: Without a restoring spring toward `(homeX, homeY)` and hard offset bounds (`±22 x, ±10 y`), separation forces push outer demons offscreen or into the player's horizontal rail (`y = 477`).
- **Smooth GLSL normal maps on low-res pixel art**: Applying bilinear/per-pixel smooth shaders over a `32 × 32` logical sprite grid blurs crisp pixel silhouettes and muddies hostile bullet readability. Use stepped pixel rim highlights, banked pose transforms, and discrete layered plasma envelopes instead.
- **Mixing cool cyan/violet hues into atmospheric re-entry fire**: Using cyan or violet bands on diving creature shields confuses aerothermal friction with technological energy barriers; keep re-entry plasma strictly thermal blackbody (white -> yellow -> orange -> crimson/charcoal smoke) and force shields strictly geometric cyan/teal/violet.
- **Multi-touch pointer-release jumps on cockpit yokes**: Releasing one finger during a two-finger touch drag will snap the yoke and ship target unless the active anchor rebases cleanly to the surviving pointer.

## Provenance

- <https://www.red3d.com/cwr/steer/> (do-not-bundle; sidecar only — Craig Reynolds *Steering Behaviors For Autonomous Characters*)
- <https://www.ryanjuckett.com/damped-springs/> (do-not-bundle; sidecar only — Ryan Juckett *Damped Springs*)
- <https://www.riotgames.com/en/news/valorant-shaders-and-gameplay-clarity> (do-not-bundle; sidecar only — Riot Games *VALORANT Shaders and Gameplay Clarity*)
- <https://docs.godotengine.org/en/stable/classes/class_tween.html> (do-not-bundle; sidecar only — Godot Engine *Tween Interpolation & Easing*)
- <https://www.gdcvault.com/play/1014652/> (do-not-bundle; sidecar only — Dominic Cianciolo, NetherRealm Studios GDC 2011 *Seamless Transitions from Cutscenes to Gameplay*)
- Classic arcade & aerothermal references: SNK *Ikari Warriors* (1986) rotary turret vectoring, Atari *Star Wars* (1983) cockpit flight yoke & wireframe schematic, and Anderson (2006) *Hypersonic and High-Temperature Gas Dynamics* blackbody stagnation layers.
- Derived cross-project transfers: sibling `8007342/ranitas` (`03f3901` quintic smootherstep) and `8007342/cannonball` (`238d7de` lateral roll/banking, hemisphere lighting, 3D gravity-projected `screenRoll` tilt + circular-mean posture calibration + touch-release rebasing, and `DepartureTimeline` continuous zoom-out), documented in `plan/research-source-ledger.md`.

## Pull on Demand

> Upstream steering and shader references are off-allowlist and NOT bundled into the forge image. Materialize into the per-project pull cache when inspecting original equations.

### Source

- **Upstream URL(s):**
  - `https://www.red3d.com/cwr/steer/`
  - `https://www.ryanjuckett.com/damped-springs/`
- **Archive type:** `single-html`
- **Expected size:** `~250 KB`
- **Cache target:** `~/.cache/tillandsias/cheatsheets-pulled/$PROJECT/arcade-25d-motion/`
- **License:** see-license-allowlist
- **License URL:** https://www.red3d.com/cwr/steer/

### Materialize recipe (agent runs this)

```bash
set -euo pipefail
TARGET="$HOME/.cache/tillandsias/cheatsheets-pulled/${PROJECT:-demon_attack}/arcade-25d-motion"
mkdir -p "$TARGET"
curl --fail --silent --show-error "https://www.red3d.com/cwr/steer/" -o "$TARGET/reynolds-steer.html"
```

## See also

- `ux/game-flow-and-combat-pacing.md`
- `plan/research-source-ledger.md`
- `plan/style-guide.md`
