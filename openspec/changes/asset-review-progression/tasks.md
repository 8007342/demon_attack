# Tasks

## 1. Pipeline

- [x] 1.1 Add `retire --tiers`, refusing tiers that accepted parts come from; retire I0 and I1 (48 candidates removed, 88 I2/I3 remain).
- [x] 1.2 Add `plan --round N`, per-part `gen_size`, and the vertical-orientation step for wing modules; bump the pipeline version to 4.
- [x] 1.3 Generate alternatives at I2 and I3: round 1 for rapid, powerful and shield (1024²); round 2 for rapid and powerful (576×1024 portrait).
- [x] 1.4 Record acceptances: hull-I2-820000-0, spread-I3-820010-3, large-I3-820020-2.
- [x] 1.5 Pack writes `wing_muzzles` and `nose_muzzle` into `ship-parts.json`.
- [x] 1.6 Accept powerful-I2-820041-2; withdraw spread and large for the wing-cannon redesign (`withdraw`, kept in history).
- [x] 1.7 Regenerate nose modules styled to match the hull: drop round 1, which drew whole starfighters (`retire --seeds 820011,820021`); keep round 2 (spread and large) and round 3 (spread, flat top-down wording).

## 2. Review surface

- [x] 2.1 Show progression, collapsed accepted sections, a remembered hide switch, and status and tier filters.
- [x] 2.2 Preview every candidate on the selected ship and show the selected ship on its own.
- [x] 2.4 Show the single-shooter and wing-shooter ships, and preview nose candidates on both.
- [ ] 2.3 Human acceptance of rapid, shield, spread and large (powerful accepted).

## 3. Alternating wing cannons

- [x] 3.1 Model: wing cannons own the primary shot whenever a wing powerup is active (alternating, per-side recoil); single shooter fires from the nose with `noseFlash`.
- [x] 3.2 Scene: per-side wing drawing with recoil kick and muzzle flash; load muzzles from `ship-parts.json`.
- [x] 3.3 Tests: alternation, muzzle distance, recoil side, spread and large with wing cannons, single-shooter nose flash (`test/wing_cannons_test.dart`); 136 tests pass.
- [ ] 3.4 Play-check alternating fire and recoil readability on phone and desktop in the local preview.
