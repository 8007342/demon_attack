---
tags: [ux, game-design, combat-pacing, gameflow, ai-director, boss-onboarding, playtesting]
languages: [dart]
since: 2026-10-26
last_verified: 2026-10-26
sources:
  - https://doi.org/10.1145/1077246.1077253
  - https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf
  - https://cdn.akamai.steamstatic.com/apps/valve/2008/GDC2008_PortalPostMortem.pdf
  - https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf
authority: high
status: current
tier: pull-on-demand
summary_generated_by: agent-generated-at-runtime
bundled_into_image: false
committed_for_project: true
pull_recipe: see-section-pull-on-demand
---
# GameFlow, AI Director Pacing & Graduated Boss Onboarding

@trace spec:arcade-combat, spec:arcade-progression

**Version baseline**: Flutter 3.x / Flame 1.x deterministic 60 Hz arcade loop (`demon_attack`)  
**Use when**: Tuning wave reinforcement rhythm, dive concurrency, diegetic enemy telegraphs, multi-stage boss weak points, or empirical difficulty audits.

## Quick reference

| Principle & Source | Arcade Implementation Pattern | Anti-Pattern to Avoid |
| --- | --- | --- |
| **GameFlow Challenge-Skill Match** (Sweetser & Wyeth 2005) | Dial down Route 0–1 boss HP (`48/16`, `64/20`) and attack cadence; reward movement mastery with sling-shot momentum and shield-shatter bonuses. | Flat linear HP formulas that front-load attrition before the player learns aperture timing. |
| **Build-Up → Peak → Release** (Booth / Valve L4D 2009) | Trigger finite reinforcement groups on casualty thresholds (`0.6s` / `1.2s` cooldowns), cap concurrent dives (`2 + min(route, 2)`), and preserve 2.0s post-wave salvage. | Hidden runtime Dynamic Difficulty Adjustment (DDA) that alters drops or HP behind a competitive leaderboard. |
| **Implicit Visual Onboarding** (Valve HL2 / Portal 2008) | Telegraph dives with a brief upward crest (`-16 u/s`) + wing glint; expose wide Left/Right auxiliary boss hatches (`±52 u`, `0.75×` dmg) in early forms before sealing to center-only on the final form. | Interrupting arcade flow with text-heavy modal tutorials, or starting Boss Phase 1 with a narrow single-pixel weak spot. |
| **Empirical Budget Auditing** (Ambinder / Valve 2009) | Pair static wave-budget analyzers (`tools/analyze_difficulty.dart`) and simulated pilot clear-time profilers (`tools/profile_difficulty.dart`) with human playtest feedback. | Treating automated test completion as proof that early boss pacing feels fair to human players. |
| **Multi-Part Dreadnought Hierarchy & Chain-Reaction Meltdown** (Treasure *Radiant Silvergun* / *Ikaruga*, Konami *Gradius*, *Phoenix* 1980) | Assemble the `184 × 120` Brood Dreadnought across 4 evolution forms (`Carrier`, `Brood Ark`, `Siege Carrier`, `Brood Flagship`) with articulated mandibles, dorsal retro-thrusters, tracking ventral dual-turrets, 3 mechanical launch bay shutters, orbital retro-burn arrival, and sequential wing-pylon -> auxiliary-bay -> central-core meltdown. | Scaling up a static single-cell sprite or vanishing the boss in a single generic puff frame. |
| **Post-Mortem Enemy Victory & Skyward High-Score Pan** (Namco *Galaga* 1981 & classic arcade defeat staging) | On final life lost, detonate the defender, transition surviving demons/Sentinels/Boss into a celebratory victory parade, and pan the camera skyward into the starfield Top 10 & 3-wheel initials console. | Abruptly freezing or blacking out the arena the instant the final hit lands. |

## Common patterns

### 1. Deterministic Build-Up → Peak → Release without hidden DDA
Separate **encounter timing** from **individual unit durability** so waves breathe without tampering with competitive leaderboard fairness:

```dart
// Cap simultaneous active dives so large swarms do not create unavoidable walls.
final maxConcurrentDives = 2 + min(route, 2);
if (activeDivingDemons < maxConcurrentDives && diveCooldown <= 0) {
  triggerTelegraphedDive(candidate);
}
```

### 2. Graduated Boss Weak-Point Onboarding & Multi-Part Dreadnought Choreography
Let players master shield stripping and aperture timing across wider targets in early/intermediate carrier forms (`phase < formCount - 1`), then demand precision on the final form (`phase == formCount - 1`), framed by unmistakable arrival and destruction choreography:
- **Arrival ("Coming-In")**: High-orbit retro-burn deceleration with dorsal retro-thruster flare, gravitational dust ripples, mandible deployment, and klaxon telemetry.
- **Destruction ("Going-Down")**: Sequential multi-part chain-reaction meltdown (wing pylons -> auxiliary side bays -> central brood core) and listing hull descent.

```dart
final hasSideHatches = boss.phase < boss.formCount - 1;
final sideDoorOpen = hasSideHatches && boss.sideDoorLeft >= 0.55;
if (hitCenterAperture && boss.door >= 0.65) {
  boss.applyCoreDamage(shot.damage); // 1.0x full damage
} else if (sideDoorOpen && hitSideAperture) {
  boss.applyCoreDamage(max(1, (shot.damage * 0.75).round())); // 0.75x auxiliary damage
}
```

### 3. Diegetic Pre-Dive Telegraph & 3-Tier Thermal Re-Entry Shield Counterplay
Precede high-speed or shielded dives with an unmistakable posture/motion cue on the creature itself (no detached UI arrows), render dive shields with a strictly **thermal blackbody gradient** (blinding white stagnation core -> incandescent solar yellow -> superheated ablation orange -> deep crimson/charcoal smoke trail + embers; zero cyan/violet bands, contrasting against cool geometric cyan/teal/violet force shields), and scale across a 3-tier creature hierarchy:
- **Small creatures** (`1–2 HP` lower-tier ordinary demons): upward crest (`-16 units/s`) + wing-edge glint during `warningTime`, then a **1-HP "lil'" thermal re-entry diving shield** (`diveShieldMax = 1`, popped by 1 baseline shot or pierced in one shot by 2-damage `Powerful`).
- **Not-so-small creatures** (`elite || kind >= 2 || maxHp >= 3`): **2–3 HP medium ablative diving shield** (`diveShieldMax = 2..3`) with a wider double-layered thermal bow-shock envelope.
- **Large creatures (Sentinels)**: **large atmospheric re-entry diving shield** (`diveShieldMax = 4 + cycle ~/ 2`) that **can ONLY be damaged/broken while the player has an active offensive powerup** (unpowered baseline shots deflect off the re-entry shield). Shattering it mid-dive triggers **Plasma Shatter** (`0.45s` stun, `+250 × (route + 1)` bonus, and `1.5×` dive kill score).

### 4. Last-Life-Lost Enemy Victory Celebration & Skyward Camera Pan
When `lives == 0`, stage a two-beat arcade curtain call instead of an instant modal cut:
1. **Ship Breakup & Enemy Victory Swarm**: Detonate the starfighter and transition surviving ordinary demons, Sentinels, or the Brood Dreadnought into celebratory victory formations (synchronized figure-8/chevron loops, Sentinel wing salutes, or Carrier mandible/thruster patrols).
2. **Skyward Pan to High Scores**: Smoothly pan the camera upward past the victorious swarm into the upper starfield canopy where the Top 10 leaderboard and 3-wheel initials entry settle into place.

## Common pitfalls

- **Hidden DDA in leaderboard games**: Never silently adjust enemy HP, speed, or heart-piece drop rates based on runtime deaths when players compete on a shared Top 10 board (`/api/scores`). Keep mode rules (`Easy`, `Normal`, `Hard`) explicit and deterministic.
- **Compounding route multipliers**: Scaling population, HP, reinforcement group count, and dive frequency simultaneously causes exponential workload spikes (e.g., 9×–11× opening hit budgets). Bound route evolution (`tier = route ~/ 2`) and share a single whole-wave elite birth budget.
- **Unbounded dive concurrency**: Allowing every hovered demon to roll independent dive timers turns a 24-enemy wave into an unavoidable bullet/body curtain. Always enforce `maxConcurrentDives`.
- **Single-aperture boss walls on Route 0**: Requiring players to strip a 72-HP shield and thread a narrow center door on their very first carrier encounter causes premature campaign churn. Dial down Route 0–1 HP and keep auxiliary side hatches active until the final boss form.

## Provenance

- <https://doi.org/10.1145/1077246.1077253> (do-not-bundle; sidecar only — Sweetser & Wyeth 2005 *GameFlow*)
- <https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf> (do-not-bundle; sidecar only — Booth GDC 2009 *Left 4 Dead AI Director*)
- <https://cdn.akamai.steamstatic.com/apps/valve/2008/GDC2008_PortalPostMortem.pdf> (do-not-bundle; sidecar only — Valve GDC 2008 *Portal Postmortem*)
- <https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf> (do-not-bundle; sidecar only — Ambinder GDC 2009 *Empiricism in Playtesting*)
- Classic arcade boss & defeat staging references: Treasure (*Radiant Silvergun*, *Ikaruga*), Konami (*Gradius*), Amstar/Centuri *Phoenix* (1980), and Namco *Galaga* (1981).
- Derived project disposition and calibration audit: `plan/research-source-ledger.md` and `plan/difficulty-calibration.md`.

## Pull on Demand

> This cheatsheet's underlying academic/GDC PDFs are off-allowlist and NOT bundled into the forge image. Materialize into the per-project pull cache when deeper slide inspection is needed.

### Source

- **Upstream URL(s):**
  - `https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf`
  - `https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf`
- **Archive type:** `pdf`
- **Expected size:** `~6 MB`
- **Cache target:** `~/.cache/tillandsias/cheatsheets-pulled/$PROJECT/valve-gdc-2009/`
- **License:** see-license-allowlist
- **License URL:** https://store.steampowered.com/

### Materialize recipe (agent runs this)

```bash
set -euo pipefail
TARGET="$HOME/.cache/tillandsias/cheatsheets-pulled/${PROJECT:-demon_attack}/valve-gdc-2009"
mkdir -p "$TARGET"
curl --fail --silent --show-error \
  "https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf" \
  -o "$TARGET/ai_systems_of_l4d_mike_booth.pdf"
```

## See also

- `ux/arcade-25d-motion-and-transitions.md`
- `plan/research-source-ledger.md`
- `plan/difficulty-calibration.md`
