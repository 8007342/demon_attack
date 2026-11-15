# Operator playtest feedback, 2026-11-15 (after the ground-forces close-out)

Verbatim summary of the operator's playtest of `game` at 651fab07+ (preview, iPhone 12 Pro Max), split into
workstreams. Each workstream has (or gets) an OpenSpec change; this file is the index.

**Loved:** the assets ("pretty"), their animations ("cute"), the ground shadows of the swarm ("terrific"), the sentinel
silhouette hovering in the back ("fantastic"), the walking robot tanks ("super cute"), squads as groups.

## W1. Ground presentation tuning (OpenSpec `ground-presentation-tuning`)
- All ground animation at **≤ 50 % of the current speed**: they should read as distant events.
- **Allied (Fleet) tanks half the size; enemy (Host) tanks 30 % larger; soldiers 10 % smaller.**
- Walkers (tall legged robot tanks) walk **even slower** than the other troops.
- Foot soldiers walk **individually** (own gait phase, spacing, small drift) while staying a group; groups of **1–5**,
  most often **2–4**.

## W2. Fog: back toward the earlier implementation (OpenSpec `fog-restoration`)
- An earlier attempt was much better. The current fog is **bound to the ship's movement** (the ship controller drags
  the fog with it): wrong; fog must not follow the ship.
- It is again a **narrow band in the middle**; it must be **pervasive**: multiple additive layers covering multiple
  elements, incoming waves slowly rising up through the underlying layers.
- The sentinel's **slow fade-in through the cloud** of an earlier version was fantastic (current play felt simpler);
  the late-layer hovering sentinel needs soft composed layers that add up carefully for the epic effect.
- Keep the enhancements made since (silhouette sheet, depth tint, atlas art) where they help.

## W3. Continuous swarm (OpenSpec `continuous-swarm`)
- No discrete ladder of incoming enemies / discrete batches: a **continuous inflow** along **parabolic curves traced by
  swarm behaviour**, which merely **accelerates** if the previous wave is cleared faster.
- Real swarm patterns and behaviours while flying in **and while fighting** (not hovering / little figure-eights).
- Show enemies **sideways more often** (use the angled renders; they face front too much).
- Reinforcements, waves, level transitions, boss transitions, sentinels, enemy dives and relevant radio chatter must
  play together as **one consistent swarm flocking through continuous space, through layers of fog**.
- **Shadows** stay when creatures reach the front row; shift back and forth as they swarm; play with demon and ship
  shadows for immersion.
- Research swarm behaviours and continuous (non-batched) arrival.

## W4. Demon intelligence (OpenSpec `demon-intelligence`)
- Look at sibling **8007342/atrapa** (a small JEPA-style model trained to play snake): leverage it for a few levels of
  enemy intelligence; some top enemies **dive between enemy fire** and **react to skilful play**.
- **Sentinel final rush**: happens a little more often; gets its **own extra shield** for the massive dive, its own
  **radio chatter**, and is **properly scary and fast** (today too easy).

## W5. UX cleanup and cinematic flow (OpenSpec `cinematic-flow`)
- The UX is covered with junk: **remove everything with a progress bar**.
- Research sibling **8007342/cannonball** (cited research on cinematic transitions and outros) and
  **8007342/macron.dev** (a recent animation job) for transitions, outros and orchestration (W3's "one consistent
  swarm").

Sibling clones (read-only reference data): `~/.cache/tillandsias-project/siblings/{atrapa,cannonball,macron.dev}`.

Research for W3, W4 and W5b: `plan/swarm-research.md`. Order: `continuous-swarm` (W3) lands first; `demon-intelligence`
(W4) and `cinematic-flow` (W5b) build on it independently.
