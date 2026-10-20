# Demon Attack — game design and current tuning

This original remake uses winged demons, a horizontally moving defender, permanent auto-fire, four increasingly difficult waves, and a low-flying brood carrier. Artwork and music are original. Historical references belong in the research document; values below describe `lib/game/model.dart` and are tuning defaults rather than claims about the 1982 game.

## Current simulation

The arena is 360 × 520 logical units; ship y=477. The responsive interface places a separate futuristic touch console beneath it. Dragging moves a horizontal target; arrow keys also move it. The ship approaches that target at up to 330 units/s, clamped to x=18–342. Baseline fire interval is 0.23 s and bullets travel upward at 390 units/s. The simulation advances at 60 fixed steps/s and clamps one update's elapsed time to 0.1 s.

A new run has three lives, zero score, and a zero-based cycle counter. One unprotected hit removes a life and grants 2.5 s invulnerability. The third death ends the run. The initial ship has 2 s protection. Pause freezes combat, transition timers, powers, and effects; Resume restores the previous mode. A level introduction lasts 2.3 s. On boss defeat, hostile entities disappear immediately, points are awarded once, and a 4.5 s victory transition precedes the next cycle's LV1. Score and remaining lives persist.

| Level | Title | Roster in first cycle | Base HP | Identity |
| --- | --- | --- | --- | --- |
| 1 | KRYBOR | 8 teal demons | 1 | Winged introductory flock |
| 2 | RINGFALL | 10 violet demons | 1 | Dives begin |
| 3 | EMBER MOON | 12 coral predators | 2 | Multi-hit forms and angry survivors |
| 4 | THE HOLLOW | 14 crowned elders | 2 | Denser, faster attacks |
| 5 | THE CARRIER | Carrier with replenished flocks | Shield 18 / core 16 | Shield, sliding door, successive boss forms |

Ordinary HP is `1 + floor((level−1)/2) + min(cycle,3)`, currently reaching 5 in LV3–4. Each species has normal, three intermediate molt, and angry wing animations. Each nonlethal hit reveals the next weakened silhouette; the final remaining HP of a multi-hit creature triggers anger and a telegraphed dive.

Flocks use individual sinusoidal paths around home positions, producing organic wing motion rather than synchronized mechanical marching. A dive warns for 0.7 s and samples the player's x once. Diving creatures steer toward that sampled x, descend, then rejoin their home position after leaving the arena. Dives begin in LV2, or LV1 on later cycles. Dive interval is `(4.2−level×0.45)/speed`; base vertical dive speed is `115+kind×16`. Angry dives progress faster. Hostile aimed drops come from one randomly selected demon per firing interval, with limited lateral velocity. Movement multiplier is `1+min(cycle,8)×0.1`, capped at 1.8. Hostile fire interval has a 0.45 s floor.

## Boss

The carrier cruises near y=205 with a 12-unit vertical bob and an 80-unit horizontal sweep. Shield HP is `18+cycle×6`; core HP is `16+cycle×8`. Shield hits across the hull width remove one HP. After the shield is gone, damage requires a shot through the center aperture while the sliding door is sufficiently open (`door >= 0.65`). Its width follows the visible opening; closed hull blocks shots. The sinusoidal opening accelerates with damage phase. There are `min(4,2+cycle)` transformation phases, beginning with two and reaching four. Music and art react to phase changes.

The carrier releases three demons at a time when fewer than ten are present. Flock additions are clamped to a maximum of ten simultaneous minions. Their HP is `1+min(cycle,2)`, capped at three, and their forms advance with cycle. Flocks replenish continuously, while the exposed core remains reachable; players need not clear every minion to damage or defeat the carrier. This is deliberate survival pressure. The carrier also launches a three-shot downward fan. Boss kill score is `5000×(cycle+1)`; killing it clears minions without awarding their kill scores.

Continuous flocks permit score farming. A future competitive integrity policy may limit per-boss minion scoring or use elapsed-time validation, but finite flocks are not a current gameplay requirement. Shield and core HP grow without a cap; playtesting should determine whether later-cycle endurance needs a cap independently of speed.

## Score and powers

A demon elimination awards `(100+kind×75+(maxHp−1)×50)×(cycle+1)` once; damage alone earns no points. Kill count persists through levels and cycles. Every fifth kill drops the next power in a repeating spread → rapid → shield sequence. Pickups descend at 64 units/s and disappear below the arena. These deterministic defaults make powers discoverable during short tests.

Exactly one power is active at a time; collecting another replaces it and starts a nine-second timer. Spread adds two angled bullets to the central shot. Rapid reduces fire interval to 0.105 s. Shield absorbs one collision, consumes itself, and grants 1 s invulnerability. Pause freezes expiry. Current life loss preserves an active non-shield power; no extra lives are awarded.

## Screen and interaction requirements

Title presents the demon emblem, Demon Attack, Start, Top 10, a sound control, and short drag / arrow / auto-fire guidance. Start supplies the browser's audio-unlock gesture. HUD shows score, level/cycle, lives, current power, and boss health when relevant. The touch console has a recessed pixel panel, clear drag feedback, and comfortable targets separate from the arena. Initial touch must not teleport the ship. Desktop must support a complete run with arrow movement and automatic fire.

Game-over initials entry uses exactly three rotating character wheels from A–Z and 0–9, initially AAA, with visible up/down targets and keyboard support. It offers Submit rather than freeform text entry. Top 10 presents rank, initials, and score; the Cloudflare Durable Object is the shared authority. A network failure must not falsely claim submission success. Server checks initials and score bounds; client-provided scores alone cannot establish legitimate play.

## Acceptance and follow-up tuning

- Complete four waves, break the shield, hit the core through the visible door, defeat the boss, and return to a faster LV1 without reloading.
- Confirm three unprotected hits end a run, invulnerability prevents collision stacking, pause freezes timers, and power replacement/expiry works.
- Confirm multi-hit enemies display an angry final state; later cycles add HP and unlock carrier forms through the fourth form.
- Ensure individual dive warnings and hostile projectiles stay legible against each scene; no direct player-tracking dive after launch.
- Confirm door-closed shots do zero core damage and victory awards exactly one boss bonus.
- Validate relative touch and keyboard controls, narrow-phone layout, complete score submission/retrieval, audio unlock, and pause/resume in the actual browser.
- Further visual work may add flock separation steering and reduced-motion settings. These are refinements, not claims of current simulation behavior.
