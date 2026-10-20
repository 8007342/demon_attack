# Demon Attack — game design and current tuning

This original remake uses winged demons, a horizontally moving defender, permanent auto-fire, four increasingly difficult waves, and a low-flying brood carrier. Artwork and music are original. Historical references belong in the research document; values below describe `lib/game/model.dart` and are tuning defaults rather than claims about the 1982 game.

## Current simulation

The arena is 360 × 520 logical units; ship y=477. The responsive interface places a separate futuristic touch console beneath it. Dragging moves a horizontal target; arrow keys also move it. The ship approaches that target at up to 330 units/s, clamped to x=18–342. Baseline fire interval is 0.23 s and bullets travel upward at 390 units/s. The simulation advances at 60 fixed steps/s and clamps one update's elapsed time to 0.1 s.

A new run has three lives, zero score, and a zero-based cycle counter. One unprotected hit removes a life and grants 2.5 s invulnerability. The third death ends the run. The initial ship has 2 s protection. Pause freezes combat, transition timers, powers, and effects; Resume restores the previous mode. Each level starts with a 2.3 s introduction. In cycle 1, LV1–2 contain three combat waves each; LV3–4 contain four. Each subsequent cycle adds one wave per level, capped at three extra waves. Clearing an intermediate wave gives a 1.4 s wave introduction within the same level, without level-victory music. Clearing the final wave gives a protected 2 s salvage window with piloting and pickup collection, then holds the current level for a 4 s level-clear scene, followed by a 4 s travel scene, then the next level introduction. After LV4 this route introduces the carrier. On boss defeat, hostile entities disappear immediately, points are awarded once, and a 5.5 s triumph precedes 4 s of travel to the next cycle's LV1 / wave 1. Score, remaining lives, and active powers persist; power durations freeze throughout cinematics, including salvage and intermediate-wave introductions. The ship remains controllable in intermediate-wave introductions, with pickups falling at 64 units/s. In final salvage, pickups fall at 144 units/s to offer a last collection chance; no firing or damage occurs. All cinematic phases can be paused and resumed without losing progress.

| Level | Title | Wave rosters in first cycle | Base HP | Identity |
| --- | --- | --- | --- | --- |
| 1 | KRYBOR | 8 / 10 / 12 teal demons | 1 | Winged introductory flock |
| 2 | RINGFALL | 10 / 12 / 14, violet dominant | 1 | Dives begin |
| 3 | EMBER MOON | 12 / 14 / 16 / 18, coral dominant | 2 | Multi-hit forms and angry survivors |
| 4 | THE HOLLOW | 14 / 16 / 18 / 20, elder dominant | 2 | Denser, faster attacks |
| 5 | THE CARRIER | Carrier with replenished flocks | Shield 72 / core 24 | Shield, sliding door, successive boss forms |

After wave 1 in the first cycle, every fourth spawn mixes in the previous level’s species. Subsequent cycles mix all four species from LV1. Each cycle adds two creatures per wave, capped at eight extra creatures and 24 creatures total, arranged in six columns and no more than four rows. Ordinary HP is `1 + floor(kind/2) + min(cycle,3)` (species kind is zero-based), capped at five. Beginning with cycle 2, every fifth creature (offset by wave) is an elite with two extra HP, capped at seven. `moltStage` is the number of hits sustained, allowing additional armor overlays beyond the three intermediate atlas forms. Each species has normal, three intermediate molt, and angry wing animations. Each nonlethal hit reveals the next weakened silhouette; the final remaining HP of a multi-hit creature triggers anger and a telegraphed dive.

Flocks use individual sinusoidal paths around home positions, producing organic wing motion rather than synchronized mechanical marching. A dive warns for 0.7 s and samples the player's x once. Diving creatures steer toward that sampled x, descend, then rejoin their home position after leaving the arena. Dives begin in LV2, or LV1 on later cycles. Dive interval is `max(0.8,(4.2−level×0.45−min(cycle,5)×0.22)/speed)`; base vertical dive speed is `115+kind×16`. Angry dives progress faster. Hostile aimed drops come from one randomly selected demon per firing interval, with limited lateral velocity. Movement multiplier is `1+min(cycle,8)×0.1`, capped at 1.8. Hostile fire interval has a 0.45 s floor. Elites telegraph dives for at least 0.55 s, descend 15% faster, and launch targeted three-shot fans every `max(2,4−min(cycle,5)×0.3)` seconds after an initial 2.4 s delay. The attack direction samples the player before launch; active dives do not retarget. The simulation caps naturally spawned hostile bullets at 120.

## Boss

The carrier cruises near y=205 with a 12-unit vertical bob and an 80-unit horizontal sweep. Shield HP is `72+cycle×18`; core HP is `24+cycle×10`. This gives the shield a substantially longer opening phase than the earlier prototype. Shield hits across the hull width remove one HP. After the shield is gone, damage requires a shot through the center aperture while the sliding door is sufficiently open (`door >= 0.65`). Its width follows the visible opening; closed hull blocks shots. The sinusoidal opening accelerates with damage phase. There are `min(4,2+cycle)` transformation phases, beginning with two and reaching four. Music and art react to phase changes.

The carrier releases three demons at a time when fewer than ten are present. Flock additions are clamped to a maximum of ten simultaneous minions. Their HP is `1+min(cycle,2)`, capped at three, and their forms advance with cycle. Flocks replenish continuously, while the exposed core remains reachable; players need not clear every minion to damage or defeat the carrier. This is deliberate survival pressure. The carrier also launches a three-shot downward fan. Boss kill score is `5000×(cycle+1)`; killing it clears minions without awarding their kill scores.

Continuous flocks permit score farming. A future competitive integrity policy may limit per-boss minion scoring or use elapsed-time validation, but finite flocks are not a current gameplay requirement. Shield and core HP grow without a cap; playtesting should determine whether later-cycle endurance needs a cap independently of speed.

## Score and powers

A demon elimination awards `(100+kind×75+(maxHp−1)×50)×(cycle+1)` once; damage alone earns no points. Kill count persists through levels and cycles. Every fifth kill drops the next power in a repeating spread → rapid → shield sequence. Pickups descend at 64 units/s and disappear below the arena. These deterministic defaults make powers discoverable during short tests.

Exactly one power is active at a time; collecting another replaces it and starts a nine-second timer. Spread adds two angled bullets to the central shot. Rapid reduces fire interval to 0.105 s. Shield absorbs one collision, consumes itself, and grants 1 s invulnerability. Pause freezes expiry. Current life loss preserves an active non-shield power; no extra lives are awarded.

## Screen and interaction requirements

Title presents the demon emblem, Demon Attack, Start, Top 10, a sound control, and short drag / arrow / auto-fire guidance. Start supplies the browser's audio-unlock gesture. HUD shows score, level/cycle, lives, current power, and boss health when relevant. The touch console has a recessed pixel panel, clear drag feedback, and comfortable targets separate from the arena. Initial touch must not teleport the ship. Desktop must support a complete run with arrow movement and automatic fire.

Game-over initials entry uses exactly three rotating character wheels from A–Z and 0–9, initially AAA, with visible up/down targets and keyboard support. It offers Submit rather than freeform text entry. Top 10 presents rank, initials, and score; the Cloudflare Durable Object is the shared authority. A network failure must not falsely claim submission success. Server checks initials and score bounds; client-provided scores alone cannot establish legitimate play.

## Acceptance and follow-up tuning

- Complete all three / three / four / four waves, with level-clear and travel cinematics only after each level’s final wave; break the shield, hit the core through the visible door, defeat the boss, and return to a faster LV1 without reloading.
- Confirm three unprotected hits end a run, invulnerability prevents collision stacking, pause freezes timers, and power replacement/expiry works.
- Confirm multi-hit enemies display an angry final state; later cycles add HP and unlock carrier forms through the fourth form.
- Ensure individual dive warnings and hostile projectiles stay legible against each scene; no direct player-tracking dive after launch.
- Confirm door-closed shots do zero core damage and victory awards exactly one boss bonus.
- Validate relative touch and keyboard controls, narrow-phone layout, complete score submission/retrieval, audio unlock, and pause/resume in the actual browser.
- Further visual work may add flock separation steering and reduced-motion settings. These are refinements, not claims of current simulation behavior.
