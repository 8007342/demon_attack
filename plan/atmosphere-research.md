# Atmosphere, depth and swarm arrivals: research

2026-11-14. Two research passes for the operator's request after the wave-pressure playtest ("what a
delicious fog … let's do so much more with it"): fog layers, aerial perspective, parallax, shadows, a giant
silhouette in the fog, and flock/swarm arrivals. **[inference]** marks engineering judgement, not a source.
Some primary pages refused fetches (iquilezles.org, Reynolds' GDC 99 page, the INSIDE slides); claims taken
from search snippets or memory are flagged in the source list.

## 1. Aerial perspective (distance colour)

- Koschmieder: `L = L0·e^(−βd) + L∞·(1 − e^(−βd))`; contrast `C = C0·e^(−βd)`; visual range
  `V = −ln ε / β` (ε ≈ 0.02–0.05). Graphics form: `f = 1 − exp(−density·distance)`,
  `colour = mix(obj, fog, f)` (Quilez). Per-channel extinction makes distance blue (red lost first); a
  sun-aware fog colour warms toward the sun. [UNSOURCED: plan/provenance-audit.md#R-01]
- Painters' rules (Leonardo): with distance things get lighter, lower-contrast, less saturated, cooler (toward
  the sky colour) and softer-edged.
- **Recipe [inference]:** one transmittance `t = exp(−k·(1 − nearness))`, k 2.5–4, drives tint
  (`mix(fogColour, sprite, t)` as a colour filter), saturation (`mix(.2, 1, t)`) and contrast, so cues never
  disagree. Fog colour = sky horizon colour, value .6–.75, saturation .15–.25.
- **Detail reveal [inference]:** t < .25 silhouette only; ≈ .4 outline and muted team colour; ≈ .6 shields,
  armour and glows (must be readable before the enemy can fire); > .85 full colour. Emissive points (eyes)
  fade slower: `glowAlpha = max(t, .5)` (INSIDE clamped fog so bright things punch through).

## 2. Fog layers

Sources: Ori (fog blending colour and value over depth, non-linear depth of field) [UNSOURCED: plan/provenance-audit.md#R-02], Hollow Knight (fog sheets
between parallax planes, strongest contrast kept in the playable middle ground), INSIDE (simple linear fog
plus local box fog volumes), Disney's multiplane camera (6–7 planes at different speeds).

| Layer (back → front) | Recipe | Parallax (ground = 1) | Alpha |
|---|---|---|---|
| Sky gradient + horizon band (waves hold here) | gradient + one noise band | .05–.1 | .7–.9 peak, 8–15 % of height |
| Boss silhouette slot | §5 | .1–.15 | — |
| Distant fog bank(s), interleaved with terrain strips | gradient + fBm | .2–.4 | .3–.5 |
| Ground (height) fog: `ρ(h) = a·e^(−b·h)` (Quilez, Wenzel/Crytek) | gradient fading upward from terrain × noise, drift 2–6 px/s | .8–1.0 | .2–.4 at ground → 0 at ~15 % height |
| Gameplay plane | enemies, bullets, player | 1.0 | — |
| Thin sky sheets (1–2) over everything | full-screen fBm, drifting sideways | 1.1–1.4 | .04–.10, never > .12 over the player |

- **Noise:** fBm 4–5 octaves, lacunarity 2, gain .5 (Book of Shaders); domain warping
  `f(p) = fbm(p + 4·fbm(p + t·v))` so the fog evolves instead of translating (Quilez). Against the
  "scrolling bitmap" look [inference]: two lookups at different scales and directions, a slow time term in the
  warp, `smoothstep(.35, .75, n)` for wisps with gaps, density also following a vertical gradient, dithering
  against banding (Playdead).
- **Through the layers [inference]:** draw each creature between the layers its nearness puts it between
  (bin by nearness), and apply the §1 tint, so occlusion and tint agree.
- **Cost:** blended overdraw is the mobile cost (Arm: ~2.5× average overdraw is "quite high", 10× too much).
  Prefer one fragment shader computing all fog layers in one full-screen pass (4–5 octaves, ~60–100 ALU/px,
  half resolution if needed); fallback: 2–3 tiling 256² fBm textures via `ImageShader`. Flutter: precache
  `FragmentProgram`s, reuse `FragmentShader` objects, only `sampler2D`, no repeat tile mode (wrap with
  `fract`), premultiplied colour.

## 3. Parallax, flyers and shadows (45° camera)

- Screen scroll and scale both ≈ 1/distance; keep one curve for both (the existing `Perspective`). [UNSOURCED: plan/provenance-audit.md#R-03]
- A flyer at altitude h over ground point g: g's screen position minus h·cos(tilt); scale by g's depth.
- **Shadow [Unity demo + inference]:** offset `h·tan(zenith)` along the sun azimuth (zenith 25–40°);
  blur `σ0 + k·h` (1–2 px → 6–10 px for the highest flyers; use 3 pre-blurred shadow sprites, not live
  `MaskFilter.blur`); opacity `.45·(1 − .6·h/hmax)·T_ground` (fades through ground fog, drawn under the ground
  fog layer); scale × (1 + .1–.2·h).
- **Shadows lead arrivals [inference]:** an incoming wave's shadows cross the terrain before the bodies clear
  the horizon band, a cheap "something is coming" cue.

## 4. Light shafts

Mitchell, GPU Gems 3 ch. 13 (radial blur of an occlusion mask toward the light). In 2D, cheapest first
[inference]: 3–6 additive gradient wedge sprites (alpha .05–.15, animated, multiplied by the sky-sheet noise);
or a 16–24-sample radial march over the fog density at quarter resolution (desktop quality tier).

## 5. A giant silhouette in the fog

No authoritative postmortem found; recipe from §1 plus monster-reveal practice [inference]:
- value .08–.15 below the fog behind it (a darker patch of fog, not a black cutout); soft edges eaten by the
  same fog noise; a thin warm rim toward the sun (alpha .1–.3) and 2–4 emissive eyes that ignore most fog;
- behind the distant fog band, parallax .1–.15 (near-stillness reads as size) [UNSOURCED: plan/provenance-audit.md#R-04]; partly cut by the horizon;
  known-size waves passing in front;
- grow over waves: nearness .05 → .15 → .3 → .5, raising t, parallax and scale together; slow breathing
  (scale ±1 %, 4–6 s).

## 6. Flocking into formation

- **Reynolds (1987, GDC 1999):** steering = desired − velocity, truncated by max_force; seek, *arrive*
  (`desired = min(max_speed·d/slowing, max_speed)·offset/d`), separation (1/r weighted), cohesion, alignment,
  wander; leader following and *offset pursuit* (the formation-slot primitive). Pseudocode from memory.
- **Topological neighbours:** starlings track ~6–7 nearest neighbours regardless of distance (Ballerini et al.
  2008); topological rules keep stragglers, metric ones lose them. Use k = 6–7.
- **Couzin et al. 2002 zones** (repulsion > orientation > attraction; small orientation zone = swarm/mill,
  large = parallel group). Vicsek 1995: heading = neighbours' mean + noise η. (Parameter values from memory.)
- **Per-agent update [inference]:** `F = w_slot·Arrive(slot) + w_sep·Sep(k) + w_ali·Align(k) +
  w_coh·Coh(k) + w_wan·Wander`. Arrival → settle weights: slot .6 → 2.0, sep 1.5, ali 1.0, coh .8 → .2,
  wander .3 → .05. max_speed .35–.6 field widths/s, max_force 1.5–3 × max_speed/s, slowing distance
  .08–.15, separation radius ~1.2 sprite diameters.
- **No lockstep [inference]:** seeded per-agent speed and force factor U(.85, 1.15), launch delay, wander and
  wingbeat phases U(0, 2π), wingbeat rate ±10 %.
- **Slot hand-off without popping [inference]:** within r_lock ≈ .03 and slow, blend β 0 → 1 over .3–.6 s
  (smoothstep): render `lerp(sim, slot, β)`, blending the velocity used for banking too; force the ramp after
  ~4 s for stragglers; a dive is the reverse ramp.

## 7. Arriving from depth

[inference] 2D boids in ground space (x, z) plus a scripted altitude curve, projected through the existing
camera (3D boids hide most of their structure in a top-down shooter):
- depth progress `z_i = z_far + (z_slot − z_far)·easeOutCubic(u_i)`, `u_i = clamp((t − Δt_i)/T_i)`;
- neighbour distances in world space so the far flock does not look compressed;
- altitude arc as the missiles: `h(u) = h_peak·4u(1 − u)` with per-agent h_peak ±20 % (layering through fog);
- 2–4 squadrons per wave, each a leader on a Catmull–Rom/Bézier from a horizon point to the anchor,
  followers leader-following + flocking; stagger 40–120 ms within, .5–1.5 s between squadrons;
- LOD (Saber's Swarm Engine): far = group motion, near = per-agent flocking. [UNSOURCED: plan/provenance-audit.md#R-05]

## 8. Swarm aesthetics

- Murmuration "agitation waves" are orientation waves travelling through the flock (Hemelrijk/Hildenbrandt);
  correlations are flock-wide (Cavagna et al. 2010). Cheap fake: a travelling phase offset along the flock axis
  tilting sprites.
- Insect swarms (Kelley & Ouellette 2013): a binding pull to the swarm centre, little alignment, sub-clusters.
  For a boss's swarm: drop alignment, spring to a moving centre that follows the boss, strong noise.
- Wingbeat phase variance is the cheapest, strongest cue (Abzu animated schools with shader/morph-target phase
  offsets, not skeletons); schools part around a predator and re-form (Abzu): a brief separation impulse
  around bullets.
- Pacing: L4D's Director (Booth 2009), "structured unpredictability" for reinforcement timing.

## 9. Performance and determinism (N ≤ 200) [inference]

Uniform grid (cell = neighbour radius) in flat `Int32List`s, rebuilt per step; k-nearest via a fixed 7-slot
insertion buffer; brute force is fine to ~300. Simulate at 30 Hz with an accumulator and interpolate. One
seeded PRNG per wave (levelSeed, waveIndex), per-agent constants drawn at spawn, fixed iteration order.
Precompute authored set pieces (boss entrance) as 10–15 Hz keyframes; simulate followers live.

## 10. Figure-eight boss path

- Gerono (Lissajous 1:2): `x = a·cos t, y = (a/2)·sin 2t`; Bernoulli: `x = a·cos t/(1 + sin²t),
  y = a·sin t·cos t/(1 + sin²t)`. [UNSOURCED: plan/provenance-audit.md#R-06]
- Depth [inference]: `z = z_c + Z·sin t` (one lobe swoops near) or `Z·cos 2t` (near at the crossing);
  altitude `H·sin 2t`; bank by the curvature sign. Linger at the ends: `t(τ) = τ + .15·sin 2τ`.
- Over waves p: 0 → 1: `z_c = lerp(z_horizon, z_arena, smoothstep(p))`, period 8–12 s, fog over it thinning
  with p; final approach blends from a lobe tip into an arrive spline with the swarm spawned from its body.

## 11. Readability and fairness

Sources (Anatomy of a Shmup; Boghog; SLYNYRD; Hollow Knight): no off-screen fire; high bullet contrast;
low-contrast midtone backgrounds; saturated bullets drawn on top; brighter, thicker-outlined actors than
scenery. Applied [inference]:
- bullets and the player are never fogged (draw after the sky sheets or cut a hole around them);
- untargetable and harmless while in fog (typically 1.5–3 s), then .5–1 s targetable-but-silent grace;
- a clear "now targetable" pop (saturation/outline/rim);
- reinforcements telegraphed 1–2 s ahead (fog disturbance, ground shadows, a cue);
- never settle a slot within ~.25 field widths of the player; at most ~12 in flight at once;
- wander ~0 once in formation; a "reduced atmosphere" option doubles as the low-end tier.

Shadows on the relief (`terrain-shadows`): a shadow draped over a bright slope reads darker, but the
`groundLight` factor and the 0.9 alpha cap still apply, and bullets are never dimmed. The sentinel's lurking
shadow is atmosphere, not a telegraph: it never announces a gameplay event the player must react to, so it carries
no fairness rule of its own. It is drawn as an occluder of the ground's light (desaturate plus a cool
multiply that also dims the fog banks above it): an ink shadow, even at alpha 0.5, read as nothing on the dark
sector grounds.

## Sources

Atmosphere: Quilez, "Better fog" (https://iquilezles.org/articles/fog/, snippets only) and "Domain warping"
(https://iquilezles.org/articles/warp/); Gonzalez Vivo & Lowe, The Book of Shaders ch. 13; Hillaire, SIGGRAPH
2015 Advances (Frostbite volumetrics) and EGSR 2020 (sky and atmosphere); Bruneton & Neyret, EGSR 2008 (from
memory); Wenzel, "Real-time Atmospheric Effects in Games", SIGGRAPH 2006; Mitchell, GPU Gems 3 ch. 13;
Gjøl & Svendsen, "INSIDE Rendering", GDC 2016; Tarel & Hautière (Koschmieder); Narasimhan & Nayar, IJCV 2002;
"Aerial perspective" and "Multiplane camera" (Wikipedia); Ori developer posts (Polycount); "The Art of Hollow
Knight" (Medium); Arm GPU Best Practices, Blending; Flutter docs, fragment shaders; Unity Discussions,
top-down projectile shadow.

Swarms: Reynolds 1987 (https://www.red3d.com/cwr/boids/) and GDC 1999
(https://www.red3d.com/cwr/steer/gdc99/); Couzin et al., J. Theor. Biol. 2002; Vicsek et al., PRL 1995;
Ballerini et al., PNAS 2008; Cavagna et al., PNAS 2010; Hildenbrandt, Carere & Hemelrijk, Behav. Ecol. 2010;
Hemelrijk et al., Behav. Ecol. Sociobiol. 2015; Kelley & Ouellette, Sci. Rep. 2013; Booth, "The AI Systems of
Left 4 Dead", GDC 2009; Emerson, Game AI Pro 2013 (flow fields); Nava, "Creating the Art of ABZÛ", GDC 2017;
Saber Swarm Engine coverage; "Lemniscate of Gerono" (Wikipedia).

Shooter design: "The Anatomy of a Shmup" and "Designing smart, meaningful SHMUPs" (Game Developer); Boghog,
"Bullet hell shmup 101" (Shmups Wiki); SLYNYRD Pixelblog 31.
