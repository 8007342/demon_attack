# Demon Attack — game design and current tuning

This original remake uses winged demons, a horizontally moving defender, permanent auto-fire, four multi-wave sectors and a low-flying brood carrier. A campaign ends after five carrier victories. Artwork and music are original. Historical references belong in the research document; the values here describe the implementation and remain playtesting defaults.

## Campaign and difficulty

A route visits Krybor, Ringfall, Ember Moon, The Hollow, and a carrier. Five routes progressively approach the brood base. Internal route indices are zero-based; players see destination names instead of level/cycle numbers.

| World | Route 1 | Route 2 | Route 3 | Route 4 | Route 5 |
| --- | --- | --- | --- | --- | --- |
| Frontier | Krybor | Krybor Slums | Krybor Docks | Krybor Mountains | Krybor Command |
| Orbit | Ringfall | Ringfall Patrol Belt | Ringfall Wreckfields | Ringfall Shipyards | Ringfall Blockade |
| Foundries | Ember Moon | Ember Ashlands | Ember Forges | Ember Crucible | Ember Brood Heart |
| Command | The Hollow | Hollow Outskirts | Hollow Towers | Hollow Catacombs | Hollow Throne |
| Carrier | The Carrier | Brood Ark | Siege Carrier | Brood Citadel | Brood Flagship |

| Policy | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Starting lives | 5 | 3 | 3 |
| Hostile movement / attack rate | 90% | 100% | 100% |
| Boss shield / core HP | 80%, rounded | 100% | 100% |
| Enemy points | 75% | 100% | 100% |
| Initial roster multiplier | 80% | 100% | 120% |
| Extra enemies per later route | +1 | +3 | +4 |
| Roster ceiling | 24 | 30 | 36 |
| Heart-piece chance per eligible kill | 1.2% | 0.8% | None |

Normal is available initially. Three game overs before any boss victory permanently unlock Easy on that browser. Any boss victory records that a boss has been beaten; a Normal boss victory permanently unlocks Hard. Player movement and firing are identical across modes. Easy adjusts hostile actors rather than slowing the whole simulation.

Every boss awards one medal and one life, once. Difficulty determines the medal design; Hard medals are most elaborate. After the falling-carrier and fleet-recognition scene, travel leads to the next named destination. The fifth carrier ends the campaign after its reward sequence. Remaining lives include the final +1UP. Active time advances during combat only; pauses, introductions, salvage and cinematic travel do not count.

## Simulation and progression

The arena is 360 × 520 logical units; ship y=477. A separate touch console sits beneath it. Dragging moves a horizontal target; arrow keys also move it. The ship approaches its target at up to 330 units/s, clamped to x=18–342. Baseline fire interval is 0.23 s; bullets travel upward at 390 units/s. The simulation uses 60 fixed steps/s and clamps a single update's elapsed time to 0.1 s.

One unprotected hit removes a life and grants 2.5 s invulnerability. The initial ship has 2 s protection. Pause freezes combat, powers and transition clocks. Each sector starts with a 2.633 s introduction. Initially Krybor and Ringfall have three waves, Ember Moon and The Hollow four. Each later route adds one wave per sector, capped at three extra waves. Clearing an intermediate wave gives a 1.733 s introduction. The sector's final wave gives a protected 2 s salvage window, a 4.333 s victory scene and 4.333 s travel. A boss victory uses a 5.833 s reward sequence.

The base roster is `6 + sector×2 + (wave−1)×2`, where sectors are 1–4. Apply the difficulty multiplier, round, add route growth, then clamp to the difficulty ceiling with a minimum of four enemies. Six-column formations compress row spacing for larger rosters. Later routes mix all four species; later waves of the first route mix prior species into the local flock. Ordinary HP is `1 + floor(kind/2) + min(route,3)`, with two extra HP for selected later-route elites.

Flocks follow individual sinusoidal paths. Dive warnings sample the player's x once; dives do not continuously track the player. Multi-hit creatures visibly molt, become angry at their final HP, and telegraph an attack. Later elites have more armor and targeted fans. Naturally spawned hostile bullets are capped at 120.

After the first boss victory only, scarce wide line-wing sentinels descend slowly after late-wave swarm arrivals, hover above their protective screen, then anticipate a fast dive with warning sprite poses, with at most one special enemy in a generated flock. Normal and Hard gain additional later-wave eligibility on later routes. Shield sentinels start with `5 + min(route,4)` total HP; armored sentinels start with `8 + min(route,4)`, appearing from route index 2 in Normal and Hard. They have shield/armor presentation, survive repeated attacks and dives, and break apart in a distinct wing-and-ember defeat animation. A minority of sentinels (15% Easy, 25% Normal/Hard, selected once on spawn) make a last stand at 25% health or less: a 0.9-second climbing tell locks the player position, followed by a nonhoming 600-unit/s sacrifice rush (Easy retains 10% slower hostile timing and movement). Impact or escape destroys them without kill rewards; shooting one still earns its normal reward. Dedicated raised-wing and folded-wing sprite frames distinguish this attack. Ordinary sprite forms retain their established behavior.

## Boss

The carrier cruises near y=205 with a 12-unit bob and an 80-unit horizontal sweep. Normal/Hard shield HP is `72 + route×18`; core HP is `24 + route×10`. Easy scales both by 0.8 and rounds. Shield hits across the hull remove one HP. After the shield breaks, core damage requires a shot through the center aperture while the sliding door is sufficiently open (`door >= 0.65`). Closed hull blocks shots. Shield, belly and hatch share a centerline.

The shield's visible width/coverage reflects remaining strength. Atlas-animated pixel smoke, sparks and flames communicate core damage instead of health bars. The carrier retains a wreck visual for its falling defeat scene. Carrier phases and music change as it takes damage.

The boss releases flocks when fewer than ten minions are present, with no more than ten simultaneous minions. Minion HP grows to three. They replenish while the core remains reachable; clearing them is not required to defeat the carrier. The boss also launches a downward fan. Boss score is `5000×(route+1)`; clearing minions at victory awards no extra minion points. Easy's enemy-points multiplier applies to enemy eliminations. Continuous boss flocks remain a possible source of score farming in this trust-based arcade leaderboard.

## Powers and hearts

Enemy eliminations award points once; damage alone earns none. Ordinary base points are `(100 + kind×75 + (maxHp−1)×50)×(route+1)`, then apply difficulty scaling. Kill count persists through sectors and routes. Every fifth kill drops the next power in a repeating spread → rapid → shield sequence.

Spread, rapid and shield combine, each with a nine-second timer. A pickup refreshes only its own type. Spread adds two angled shots; rapid changes the fire interval to 0.105 s. Shield absorbs one collision, consumes itself and grants 1 s protection. Life loss preserves offensive powers. Pause and cinematic phases freeze power expiry. Pickups normally fall at 64 units/s, increasing to 144 during the final salvage window.

Easy and Normal independently sample rare heart-piece drops alongside powers. Three complementary left/right/top pieces form a heart and award a life immediately. Three unfinished slots each hold a bitmask of distinct parts. A repeated piece fills the next slot missing that part; three left pieces reserve all three slots, and a fourth is ignored. Completing a slot clears it for future pieces, with a brief solid-heart flash, explicit +1UP notification and a larger life count; a new piece immediately takes visual precedence over that flash. Slots show individual counts out of three. Hard has no heart drops or collection; bosses provide its only extra lives.

## Resume and browser history

Save a small checkpoint at each wave/boss entrance, not on every frame. Fields include schema version, difficulty, route, sector, wave, score, lives, medal count, kills, heart slots and active milliseconds. Resume restarts that entrance without powerups or transient entities. It restores score and accumulated time from the same entrance, so unfinished-wave progress is replayed. New runs replace the checkpoint; game over and completion clear it. Returning to title preserves the latest entrance.

Browser local storage holds checkpoints and separate unlock history, through a safe platform abstraction. Valid older snapshots receive defaults for absent optional fields; extra fields and schema-version differences do not by themselves reject a checkpoint. Invalid required route/wave data disables Resume without blocking a new game. History persists failures and unlock events independently so replaying a checkpoint cannot revoke an unlock. Clearing browser data removes this device-local history.

## Presentation and scores

HUD uses the named destination, score, lives, heart inventory and power status. Backgrounds retain the original world artwork, adding independently scrolling terrain, silhouettes and structures on deeper routes. Larger concise story captions and travel bars connect destinations, with each story phase extended by one third of a second. District silhouettes make slum roofs, dock cranes, mountain ridges and command pylons visible in separate parallax layers. Captions connect destinations, carrier discoveries and fleet recognition. The controller status overlays its panel without shifting the drag-guidance label. Spread uses cannon glyphs, rapid a gold bolt, shield a violet outline.

Initials entry uses three rotating A–Z/0–9 wheels, initially AAA, with touch and keyboard controls. Each unlocked difficulty has a separate Top10 tab. Every row displays five medal positions, active time and score; five-medal rows also display remaining lives. Unknown legacy time displays an em dash. Failed submissions retain their metadata for retry.

The same-origin `/api/scores` Worker API uses the existing `global-top10-v1` SQLite Durable Object. GET accepts `difficulty=easy|normal|hard` (default Normal); POST accepts initials, score and optional difficulty, medals, activeMilliseconds and remainingLives. Legacy initials/score requests remain valid. Additive guarded migrations retain older rows as Normal with zero medals and unknown time. Boards retain ten scores independently, ordered by score descending and insertion ID ascending. Bounds and completion metadata are validated before writes. Lives metadata is permitted only for five-medal scores. Local unlocks do not prevent direct API access, and client-reported scores are not cheat-proof.

## Validation and follow-up tuning

Verify all five routes end at exactly five medals, rewards happen once, and Hard cannot earn lives from hearts. Check density ceilings, rare-enemy overlap, symmetric shield/hatch geometry and closed-door core protection. Exercise complementary and duplicate heart storage, old and malformed checkpoints, unlock permanence, active-time exclusions, and independent board migration/pruning. Browser review should cover narrow phones and desktop, controller guidance, long captions, medals, power combinations, audio unlock, pause/resume and network retry. Deployment remains a separate action after local playtesting.
