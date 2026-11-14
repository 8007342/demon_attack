# Design: atmosphere and swarm arrivals

Grounded in [plan/atmosphere-research.md](../../../plan/atmosphere-research.md) (section numbers below refer to
it) and the existing depth camera ([plan/perspective.md](../../../plan/perspective.md)): horizon at y 172 of
520, nearness n = z0/z, ground y = 172 + 348·n, arrivals from n .30, formation n .62–.72, haze between
n .30 and .56.

## 1. Transmittance, one number per creature (§1)
`t = exp(−k·(1 − n))` remapped so t ≈ .05–.1 at the arrival depth (n .30) and ≈ 1 at the formation (n ≥ .6);
k ≈ 3. From t:
- tint: `ColorFilter.matrix` mixing toward the sector fog colour by `1 − t`, plus saturation `mix(.2, 1, t)`
  and contrast pulled toward the fog value; one cached Paint per 16 depth buckets;
- detail reveal: halo, armour, shields, HP pips at `smoothstep(.45, .7, t)` (f050241f uses haze; this
  replaces it); eyes and glows at `max(t, .5)`;
- holding in the fog (`model.incoming`): t capped at .25 (silhouette only).
The sector fog colour comes from the sector's horizon (tints in `plan/ground-atmosphere.md` §2).

## 2. Fog layers (§2)
`lib/game/atmosphere.dart` owns layer state (drift offsets, wind, density per sector) and paints:

| Slot | Drawn | Parallax | Alpha |
|---|---|---|---|
| horizon band | after the sky, before far creatures | .05–.1 | .7–.9 peak |
| far banks A/B | between depth bins | .2–.4 | .3–.5 |
| ground fog | over terrain below the formation, under shadows' fade | .8–1 | .2–.4 → 0 |
| sky sheets 1–2 | after creatures and ship, before bullets and HUD | 1.1–1.4 | ≤ .10 (≤ .12 near the ship) |

Rendering: one fragment shader (`shaders/fog.frag`) evaluates fBm (4 octaves, domain-warped) for the requested
layer band and is drawn once per slot as a rect, at half resolution on phones. Fallback (no shader support or
reduced atmosphere): two pre-baked 256² fBm tiles scrolled with `ImageShader` at two scales. Bullets, the
player, tell chevrons and HUD are drawn after the sky sheets: never fogged (§11).

Depth bins: creatures are sorted far → near (as today) and the far-bank and ground-fog slots are drawn when the
sort passes their nearness, so a creature at n .35 is behind bank B and in front of bank A.

## 3. Flock arrivals (§6–§9)
`lib/game/flock.dart`: a deterministic steering simulation for entering creatures only.
- State per agent: ground-space position (x, z) and velocity, seeded constants (speed factor U(.85, 1.15),
  launch delay, wander phase, wingbeat phase, altitude peak ±20 %).
- Squadrons: a wave splits into 2–4 squadrons by formation column; each has a leader on a Catmull–Rom path from
  a horizon point (spread around the vanishing point) to the formation anchor. Squadron starts stagger .5–1.5 s,
  agents within a squadron 40–120 ms, all inside the wave's existing entrance window, so the first shot the
  player can take arrives no earlier and no later than today (parity test).
- Steering: arrive-to-slot + separation + alignment + cohesion with k = 7 nearest + wander; weights from §6,
  arrival → settle. 30 Hz fixed step with interpolation; brute-force neighbours (N ≤ ~40 entering at once).
- Depth: n follows the agent's z; screen y from n and an altitude arc `h = h_peak·4u(1 − u)` (as the missiles).
- Hand-off: within r_lock of the slot and slow, β ramps 0 → 1 over .4 s (smoothstep) between the flock position
  and `_placeEntering`'s slot position; forced after 4 s. Entering creatures stay untargetable, as today.
- Determinism: one PRNG per wave seeded from (run seed, level, wave), fixed iteration order.
- Reinforcement groups use the same flock; a dive's return is unchanged.

## 4. Shadows (§3)
`_swarmShadows` gains an altitude model: offset `h·tan(zenith)` along the sun azimuth (zenith ~32°), blur from
three pre-blurred shadow sprites by altitude, opacity `.45·(1 − .6·h/hmax)·t_ground`, drawn under the ground
fog. Incoming creatures' shadows are visible (today they are nearly invisible on purpose under the formation;
that stays for settled creatures to keep the shot lane clean).

## 5. Sentinel foreshadowing (§5, §10)
When a sentinel is scheduled for wave w, its silhouette appears at the start of wave w − 2 (w − 1 if that is
the first wave of the level):
- path: Gerono figure-eight `x = a·cos τ, y = (a/2)·sin 2τ`, depth `z = z_c + Z·sin τ`, linger at the ends
  (`τ + .15·sin 2τ`), period ~10 s, bank by curvature;
- per wave p ∈ {0, .5}: z_c, scale and t rise (n ≈ .08 → .18), parallax .1–.15, behind the far banks,
  partly cut by the horizon band; slow breathing (scale ±1 %, 5 s);
- art: a dedicated silhouette sheet (8 banking frames × 2 blur levels per species) at value .08–.15 below the
  fog, a warm rim and 2–4 eyes that ignore most fog;
- arrival: from a lobe tip the silhouette blends into the sentinel's existing entrance, bringing its escort as an
  insect-style swarm (binding spring to a centre following the sentinel, no alignment, strong noise) that
  settles into the formation via the flock hand-off.
The silhouette is pure presentation: no hitbox, no fire, no effect on the encounter budget.

## 6. Performance and settings
Budget: fog ≤ 2 ms per frame on a mid-range phone at half resolution; flock ≤ .5 ms for 40 agents. Settings
gain "Atmosphere: full / reduced"; reduced = horizon band + ground fog via tiles, no sky sheets, no shader.
Reduced motion keeps the layers static.

## 7. Risks
- Readability: sky sheets over the ship. Mitigation: alpha cap, bullets and tells drawn above, playtest.
- Shader support on CanvasKit/Skwasm: verify `FragmentProgram` on the web build early; the tile fallback ships
  first.
- Balance drift from staggered arrivals: entrance-window parity test plus the existing calibration bots.
