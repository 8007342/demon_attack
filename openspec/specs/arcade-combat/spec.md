# arcade-combat

## Purpose
Provide readable, repeatable arcade combat against organic demon swarms and an evolving carrier boss.

## Requirements

### Requirement: Controls and permanent fire
The player SHALL move horizontally with arrow keys or a dedicated bottom touch trackpad, remain inside the arena, and fire automatically during combat. The ship SHALL move with horizontal inertia (`shipVx`), bank (`shipBank`), and transfer lateral sling-shot velocity to fired projectiles.

#### Scenario: Touch movement
- **WHEN** the player drags in the controller panel
- **THEN** the ship follows horizontal movement with inertial banking without entering the panel

#### Scenario: Strategic sling shooting
- **WHEN** the player strafes horizontally at speed while firing
- **THEN** fired projectiles inherit a fraction of the ship's horizontal velocity and travel on an angled trajectory

### Requirement: Cockpit yoke, interim shooting angles, and device tilt
The player SHALL steer and vector turret fire via the bottom Cockpit Control Panel steering yoke (supporting multi-touch drag with jump-free release rebasing), keyboard, or calibrated 3D device tilt (`screenRoll` with circular-mean neutral posture calibration). Ship steering and yoke deflection SHALL couple to discrete interim shooting angles (`±6°, ±12°, ±18°, ±24°`).

#### Scenario: Multi-angle steering, interim shooting angles, and calibrated device tilt
- **WHEN** the player steers via the cockpit yoke, keyboard, or calibrated 3D device tilt
- **THEN** the starfighter banks and vectors its turret projectiles across discrete interim shooting angles (`±6°, ±12°, ±18°, ±24°`), and releasing one finger during multi-touch drag rebases the anchor without jumping

### Requirement: Lives and pause
Easy SHALL start with five lives; Normal and Hard SHALL start with three. A single unprotected hit SHALL remove one life, grant brief respawn protection, and end the run at zero. Pause and backgrounding SHALL freeze combat.

#### Scenario: Lethal hit
- **WHEN** an unprotected ship is hit with one life remaining
- **THEN** combat ends and the final score is shown

#### Scenario: Easy start
- **WHEN** an Easy run starts
- **THEN** the player has five lives

### Requirement: Last-life-lost defeat celebration and skyward High Score pan
When the final life is lost, the player ship SHALL explode in a multi-stage hull breakup, surviving ordinary demons, Sentinels, or the Dreadnought Carrier SHALL execute a post-mortem victory celebration formation, and the viewport SHALL pan skyward into the starfield to present the High Scores and initials entry.

#### Scenario: Enemy victory celebration and skyward pan on final life lost
- **WHEN** an unprotected hit removes the player's last life
- **THEN** the ship detonates, surviving enemies or bosses perform a celebratory victory formation, and the camera pans upward to the High Scores console

### Requirement: Demon swarms and transformations
Four levels SHALL introduce faster organic swarms, home-tethered Boids separation/cohesion with incoming-shot lateral evasion and an offline JEV action prior (`SwarmPolicy`), telegraphed predatory dives, and armored demons that visibly weaken after hits; advanced enemies SHALL enter angry final forms.

#### Scenario: Armored demon
- **WHEN** a multi-hit demon takes a nonlethal hit
- **THEN** its form changes and its remaining final form can attack more aggressively

### Requirement: Three-tier diving shields
All diving creatures SHALL project a tier-scaled atmospheric re-entry plasma fire shield (`diveShield`) with a thermal blackbody palette (white core -> yellow -> orange -> crimson/charcoal smoke, zero cyan/violet) distinct from cool geometric force shields: 1-HP on small demons, 2–3 HP on medium creatures (`elite || kind >= 2 || maxHp >= 3`), and `4 + cycle ~/ 2` on Sentinels (broken only by active offensive powerups).

#### Scenario: Three-tier diving shields
- **WHEN** a small demon, elite/tough demon, or large Sentinel dives toward the player
- **THEN** small demons use a 1-HP lil' thermal shield, not-so-small demons use a 2–3 HP medium thermal shield, and large Sentinels use a re-entry thermal shield that only takes damage from active offensive powerups, while force shields remain geometric cyan/teal/violet

### Requirement: Carrier shield and door
The boss SHALL fly low above the player, release flocks, and protect its core with a destructible geometric force shield followed by 3 mechanical launch bay shutters. Non-final boss forms (`phase < formCount - 1`) SHALL expose Left and Right auxiliary side hatches (`sideDoorLeft`, `sideDoorRight`) alongside the center door; the final form SHALL seal the side hatches so core hits only count through the open center door.

#### Scenario: Protected core
- **WHEN** a player shot strikes the boss with its shield active or door closed
- **THEN** the core does not lose health

#### Scenario: Auxiliary side hatches on non-final forms
- **WHEN** the carrier shield is depleted during a non-final boss form (`phase < formCount - 1`) and a player shot strikes an open Left or Right auxiliary hatch
- **THEN** the carrier core takes reduced auxiliary damage (`0.75×` rounded, minimum 1), whereas on the final form (`phase == formCount - 1`) the side hatches remain sealed

### Requirement: Multi-part Dreadnought Carrier arrival and destruction
The Brood Dreadnought Carrier SHALL fight as a `184 × 120` logical pixel multi-part hierarchy across 4 evolution forms (`Carrier`, `Brood Ark`, `Siege Carrier`, `Brood Flagship`) with articulated mandibles, dorsal retro-thrusters, tracking ventral dual-turrets, and progressive fracture overlays, arriving via orbital retro-burn and exploding in a sequential chain-reaction meltdown (wing pylons -> auxiliary bays -> central core).

#### Scenario: Dreadnought orbital arrival and sequential chain-reaction destruction
- **WHEN** the Brood Dreadnought Carrier enters the sector or its core health reaches zero
- **THEN** it arrives with orbital retro-burn deceleration, gravitational dust ripples, mandible deployment, and klaxon telemetry, and upon defeat detonates sequentially from wing pylons to auxiliary bays to the central brood core in a listing hull descent

### Requirement: Repeat cycles
Each of the first four carrier victories SHALL continue the same run at the first sector, retaining score, lives, powers and kill count and adding its medal and +1UP. The fifth SHALL finish the campaign. Later routes SHALL increase bounded speed, waves, roster size, species variety and multi-molt elites with stronger telegraphed attacks.

#### Scenario: Victory
- **WHEN** the first boss core is destroyed
- **THEN** the next route starts at the first sector with retained score and lives plus the boss reward

#### Scenario: Two carrier victories
- **WHEN** the player defeats two carriers in one run
- **THEN** both returns retain the run and add complexity compared with the preceding route

#### Scenario: Advanced elites
- **WHEN** an elite appears in later routes
- **THEN** extended damage forms remain visible and stronger attacks are telegraphed

#### Scenario: Final victory
- **WHEN** the fifth carrier is defeated
- **THEN** the campaign finishes without a sixth route

### Requirement: Scores and powers
Kills SHALL award larger scores for stronger enemies and bosses. Powers SHALL last nine independent seconds: Rapid/Powerful and Spread/Large are exclusive groups; Shield is independent. Collection SHALL replace only the other member of its group; recollection refreshes only itself. Expiry and shield consumption SHALL remove only that effect. Power clocks SHALL freeze outside combat and on pause; new runs clear all effects. Guaranteed drops SHALL cycle all five types every eight kills.

#### Scenario: Replace fast fire
- **WHEN** Powerful is collected while Rapid, Spread and Shield are active
- **THEN** Powerful replaces Rapid for nine seconds and preserves Spread and Shield with their remaining timers

#### Scenario: Replace area fire
- **WHEN** Spread is collected while Large and Powerful are active
- **THEN** Spread replaces Large and Powerful retains its remaining time

#### Scenario: Restore rapid fire
- **WHEN** Rapid is collected while Powerful is active
- **THEN** Rapid replaces Powerful without altering the other offensive group or Shield

#### Scenario: Legal triple combination
- **WHEN** Powerful, Large and Shield are active
- **THEN** all three work concurrently and consuming Shield leaves both offensive effects active

#### Scenario: Power expires
- **WHEN** one active power's duration elapses
- **THEN** that effect ends while the other active effects continue with their own remaining time

#### Scenario: Combined firing
- **WHEN** spread and rapid fire are active together
- **THEN** every rapid-fire volley includes the central and both angled shots

#### Scenario: Shield protects combined powers
- **WHEN** the ship is hit with spread, rapid fire and shield active
- **THEN** shield is consumed without losing a life or cancelling spread or rapid fire

#### Scenario: Refresh one modifier
- **WHEN** an already-active type is collected
- **THEN** only that type returns to nine seconds and other timers are unchanged

### Requirement: Perspective-scaled swarm hitboxes
The simulation SHALL own each demon's perspective nearness and quantised scale (`Demon.nearness`, `Demon.scale`; `plan/perspective.md`), and every collision SHALL use that scale, with the sizes in the "Collision sizes" scenario. Demons SHALL remain unhittable while entering. Overall difficulty SHALL stay within about ±10% of the flat game (`ArcadeModel.perspective = false`) in hit rate, time to clear and lives lost, as measured by `test/perspective_difficulty_test.dart`.

#### Scenario: Collision sizes
- **WHEN** a demon at quantised scale `scale` is tested for a collision
- **THEN** an ordinary shot hitbox is `±13 × ±10 · scale` (the drawn silhouette), a sentinel's `±27 × ±18 · scale`, ship contact `10 + 11 · scale`, blast reach `radius + 14 · scale`, hostile muzzles sit `12 · scale` / `14 · scale` below the centre, and evasive sidesteps are proportional to scale

#### Scenario: What you see is what you hit
- **WHEN** a diving gargoyle drawn at 1.5× passes beside the ship
- **THEN** a shot or contact counts against its 1.5× box, while a shot passing 16 units beside a 1.1× top-row demon, visibly clear of its wing tips, misses

#### Scenario: Difficulty holds
- **WHEN** the deterministic pilot plays sectors 1, 3 and 5 on routes 0 and 1 with and without perspective
- **THEN** pooled hit rate and time to clear differ by at most 10%, and lives lost by at most 10% or two standard errors

### Requirement: Difficulty balance
Easy SHALL reduce enemy movement and attack cadence by 10% and boss shield/core health by 20% relative to Normal, without slowing player controls or fire. Enemy point awards SHALL be lower in Easy than Normal. Comparable waves SHALL have Easy fewer enemies than Normal and Hard more than Normal. From the second route, density growth SHALL be substantially greater in Normal/Hard than Easy.

#### Scenario: Mode comparison
- **WHEN** the same route and wave are started in all modes
- **THEN** roster counts increase from Easy to Normal to Hard and Easy enemies award fewer points

### Requirement: Complementary heart collection
Easy and Normal enemies SHALL rarely drop four complementary heart quarters, more often in Easy, at rates substantially below the initial 4%/3%. Three slots SHALL accept bottom-left, bottom-right, top-left and top-right; pickups fill the earliest eligible slot and excess copies are ignored. Completion SHALL grant one life, free the slot and independently show a completed-heart/+1UP cue. Shapes SHALL show filled and missing quarters.

#### Scenario: Repeated left pieces
- **WHEN** three bottom-left quarters are collected with empty slots
- **THEN** each slot holds a bottom-left quarter and further bottom-left quarters are ignored until a slot completes

#### Scenario: Completed heart
- **WHEN** a slot containing three different quarters collects its missing fourth quarter
- **THEN** exactly one life is granted, a completed-heart and +1UP cue is visible, and that slot becomes available again

#### Scenario: Dense waves
- **WHEN** a later-route wave contains more enemies
- **THEN** heart pieces remain occasional rewards rather than a repeated stream of life pickups

#### Scenario: Hard life economy
- **WHEN** a Hard enemy dies
- **THEN** it cannot drop a heart piece and boss victories remain the only extra-life source

### Requirement: Rare winged threats
Scarce large enemies SHALL use original broad horizontal pixel silhouettes, segmented wings, shields and armor, withstand several hits and survive repeated dives if undamaged. They SHALL require a boss victory in the current campaign and use final-wave refresh entrances initially; stronger modes may add later-wave entrances after that gate. Later routes SHALL introduce distinct enemy types. Large threats SHALL have a distinct pixel-frame defeat animation.

#### Scenario: Special entrance
- **WHEN** an eligible final-wave refresh introduces a large threat
- **THEN** a small ordinary swarm arrives first, the threat enters slowly from above, and its segmented wings, defenses and extended hover above the swarm distinguish it before a sprite warning and fast dive

#### Scenario: First campaign route
- **WHEN** the current campaign has no boss victories, even if the device has unlocked Hard
- **THEN** no large winged threat appears

#### Scenario: Hover before diving
- **WHEN** a large winged threat has finished its slow entrance
- **THEN** it remains above all ordinary enemies with very slow stepped wing poses until its visible sprite warning precedes the fast dive

#### Scenario: Special defeat
- **WHEN** a large enemy is destroyed by player fire
- **THEN** it plays its own defeat animation and awards its score once

### Requirement: Staged sentinel arrival and attack
An eligible wave SHALL introduce a small ordinary swarm before a large threat. The threat SHALL enter slowly from above the arena, then hover above every ordinary enemy for an extended interval with very slow discrete segmented-wing poses. A sprite-style warning SHALL precede its heavy fast dive; arrow warnings SHALL NOT be used.

#### Scenario: Swarm before sentinel
- **WHEN** an eligible special wave starts
- **THEN** the small swarm enters before the sentinel's slow descent, high hover, warning and fast dive occur in that order

### Requirement: Rare sentinel sacrifice rush
A minority of sentinels SHALL be eligible once for a sacrifice rush at 25% health or below. It SHALL lock aim at the start of a distinct movement tell, then rush on a straight path without retargeting. Normal SHALL use 0.9s/600 units/s; Easy 1s/540 units/s; calibrated Hard approximately 0.857s/630 units/s. Impact or escape SHALL destroy it without kill rewards. Player fire SHALL interrupt either phase and grant normal kill rewards.

#### Scenario: Dodge after the tell
- **WHEN** the player moves aside after an injured eligible sentinel begins its tell
- **THEN** the sentinel rushes toward the earlier sampled position and does not steer toward the player's new position

#### Scenario: Irreversible sacrifice
- **WHEN** the rush misses the player and reaches the arena boundary
- **THEN** the sentinel destroys itself instead of returning to formation, with no score, kill count or pickup awarded

#### Scenario: Shoot down the attacker
- **WHEN** player fire destroys the sentinel during the tell or rush
- **THEN** its normal defeat rewards are granted exactly once and it cannot subsequently deal collision damage

#### Scenario: Rare eligibility
- **WHEN** an ineligible or healthier sentinel is updated repeatedly
- **THEN** it retains normal behavior without repeated chance rolls that would eventually force a sacrifice rush

### Requirement: Powerful and explosive shots
Powerful SHALL double player-shot damage at normal fire cadence with a distinctive shot. Large SHALL create a small bounded pixel explosion on impact that damages nearby demons. Combined Powerful/Large SHALL retain both effects. Area damage SHALL reach the carrier core only when its shield is depleted and sliding door is open, without bypassing either protection or awarding duplicate kills.

#### Scenario: Nearby demons
- **WHEN** a Large shot hits one demon with another inside the blast radius
- **THEN** both take the appropriate damage while enemies outside the radius remain unaffected

#### Scenario: Protected core and splash
- **WHEN** a Large impact overlaps a carrier with an active shield or closed door
- **THEN** the core takes no damage

### Requirement: Finite reinforcement flocks
Ordinary waves SHALL add a finite difficulty/route/sector-dependent number of small reinforcement flocks during combat: up to two in Easy, three in Normal and four in Hard. Each flock SHALL contain four to six demons, subject to a 42-active-enemy cap. A fresh escort flock SHALL precede an eligible sentinel's delayed entrance. Reinforcements SHALL NOT create checkpoints or prevent eventual wave completion.

#### Scenario: Reinforcement budget ends
- **WHEN** a wave has used its reinforcement allowance and all remaining enemies are defeated
- **THEN** the wave completes without additional flocks or a replacement checkpoint

### Requirement: Sentinel defenses and evasion
Large sentinels SHALL possess separately depleted shield and armor defenses from their first appearance, protecting hull health. They SHALL evade threatening incoming fire with bounded lateral moves and fire visually distinct faster bullets than ordinary demons. Their existing slow entrance, hover and warned dive SHALL remain readable.

#### Scenario: Protected hull
- **WHEN** a sentinel with remaining defensive layers is hit
- **THEN** damage reduces the appropriate layer before hull health and its appearance reflects the depleted layer

### Requirement: Carrier movement escalation
Each carrier encounter SHALL select a seeded random starting movement direction and phase. Damage SHALL progressively increase movement speed and a visible rage state while preserving bounded movement and existing shield/door protection.

#### Scenario: Damaged carrier moves faster
- **WHEN** carrier health falls
- **THEN** movement accelerates and the eyes visibly intensify without enabling hits through a closed door

### Requirement: Dedicated sentinel escorts and prompt replenishment
Ordinary waves SHALL replenish through multiple finite casualty-triggered flocks with the same capped parent-wave evolution. Every sentinel SHALL bring a separate fresh escort larger than ordinary reinforcement groups. Earlier flocks SHALL NOT fulfill that escort. Escorts SHALL settle below their sentinel before it attacks. Active populations SHALL remain bounded and wave completion SHALL wait for remaining scheduled flocks.

#### Scenario: Earlier ordinary flocks
- **WHEN** ordinary reinforcements arrive before a sentinel's escort
- **THEN** the sentinel still brings its own fresh larger defending swarm

#### Scenario: Falling comrades
- **WHEN** enemies start falling in a wave with remaining reinforcements
- **THEN** replacement groups request prompt entry while respecting the wave population budget

### Requirement: Bounded parent-wave evolution
Initial ordinary enemies, reinforcements and escorts SHALL share species, health and elite rules. Reinforcement ordinal SHALL NOT add HP or make all arrivals elite. Ordinary HP SHALL cap at five with two route evolution tiers. Elite births SHALL share a whole-wave budget. Second ordinary groups SHALL add at most one body and admissions SHALL obey wave-specific population ceilings.

#### Scenario: Parent and sub-wave creatures
- **WHEN** the same species and elite state occurs in a parent roster and its reinforcements
- **THEN** both have equal health and the new group does not reset the wave elite budget

#### Scenario: Mode-aware offensive efficacy
- **WHEN** the player combines Powerful and Large
- **THEN** damage remains two per target, never multiplies again for splash, and area radii are 32/30/28 for Easy/Normal/Hard

#### Scenario: Shared elite birth limits
- **WHEN** a reinforcement or escort joins a wave
- **THEN** it shares the existing elite budget: zero on route zero, otherwise 1/2/3 total births for Easy/Normal/Hard, never a fresh per-group allowance

### Requirement: Demon ground forces
In sectors 1–4, demon ground units SHALL advance along the flyover ground plane using the background's perspective projection, staying in the side bands outside the central firing lane. They SHALL fire only from the near ground, after a telegraph of at least one second (launcher raise, then glow) and with a launch flash. Player shots SHALL pass over ground units; only homing missiles destroy them.

#### Scenario: Far units hold fire
- **WHEN** a ground unit is still beyond the near-ground fire line
- **THEN** it does not telegraph or launch

#### Scenario: Telegraphed launch
- **WHEN** a loaded unit reaches the near ground
- **THEN** it telegraphs for the full tell before a missile launches

#### Scenario: Shots fly over
- **WHEN** a player shot crosses a ground unit
- **THEN** the unit is unharmed and the shot continues

### Requirement: Fair ground missiles
A ground missile SHALL fly a fixed path to the player's x sampled at launch, without tracking, growing in drawn size as it approaches. It SHALL collide only once it reaches the ship's plane, with a hitbox matching its drawn warhead there. A hit SHALL count exactly like a hostile shot. Player shots SHALL NOT destroy missiles.

#### Scenario: Sidestep
- **WHEN** the ship moves one hitbox width away from the sampled x before the missile arrives
- **THEN** the missile misses and no life is lost

#### Scenario: Shielded hit
- **WHEN** a missile reaches a shielded ship
- **THEN** the shield is consumed and no life is lost

### Requirement: Homing missiles
Collecting the homing power-up SHALL fire three homing missiles automatically, each launched after the previous one hits. One missile SHALL destroy a ground unit; against air targets it SHALL deal one hit of 3 damage. The salvo SHALL combine with every other power and the shield, and survive a life loss.

#### Scenario: Sequential salvo
- **WHEN** homing missiles are collected with three ground units alive
- **THEN** exactly one missile flies at a time and all three units are destroyed by three successive missiles

### Requirement: Homing target order
Homing missiles SHALL target ground units first, the one closest to firing first; otherwise the highest-ranking air target: open carrier core, sentinel, elite, gold, coral, violet, teal; and finally the carrier's shield or closed core.

#### Scenario: Air fallback
- **WHEN** no ground unit is alive
- **THEN** the missile seeks the highest-ranking air target and deals 3 damage

### Requirement: Allied ground units
Allied units SHALL skirmish with some demon ground units, trading visible tracers. They SHALL never collide with the player or block shots, and SHALL never be destroyed: when overwhelmed they are totalled and retreat off screen. Destroying an engaged ally's attacker SHALL save it with a score bonus; no ally outcome SHALL penalise the player.

#### Scenario: Ally overwhelmed
- **WHEN** an engaged ally's health runs out
- **THEN** it limps off or its crew ejects, an `allyRetreated` event fires, and the player's lives and score are unchanged

#### Scenario: Ally saved
- **WHEN** a homing missile destroys an engaged ally's attacker
- **THEN** an `allySaved` event fires and the score increases

### Requirement: Allied fire
Allied ground units SHALL damage the demon unit they are fighting; a demon unit reduced to zero SHALL be destroyed without player score. Allies SHALL still never collide with the player, block shots or die.

#### Scenario: Allies win a skirmish
- **WHEN** an escorted demon unit loses its last hit points to allied fire
- **THEN** it is destroyed, a `groundUnitDestroyed` event with `by: allies` fires, and allied strength rises

### Requirement: Breakthrough
A demon unit that reaches fire range alive SHALL be a breakthrough: a `groundBreakthrough` event fires, and only then may it telegraph and fire ground missiles.

#### Scenario: Breakthrough fires
- **WHEN** a demon unit reaches fire range in sector 3 or 4
- **THEN** `groundBreakthrough` fires before its first telegraph

### Requirement: Skirmish layer
Each sector 1–5 SHALL run a skirmish layer beside the threat front. Mixed demon forces arrive across the whole ground plane with a surge-and-lull tide and fight the convoy. Skirmish units SHALL never fire at the player and SHALL never reach fire range. They SHALL never change the ground pressure, allied strength or the shared random stream.

#### Scenario: Same threat
- **WHEN** a level is flown by the same deterministic pilot with the skirmish layer off and on
- **THEN** breakthroughs and ground missiles fired at the player are equal (zero in sectors 1–2), and visible ally–foe engagements per minute are at least three times higher in sectors 1–4

### Requirement: Fall back instead of retreat
A convoy ally battered in a skirmish SHALL fall back to its escort slot and repair (`allyFallingBack`) instead of being totalled. Only a threat engagement may total an ally.

#### Scenario: Fleet intact in early sectors
- **WHEN** sectors 1–2 are fought with the skirmish layer on
- **THEN** no ally retreats

### Requirement: Homing priority
Homing missiles SHALL keep preferring threat ground units. Skirmish units SHALL NOT be homing targets.

#### Scenario: Salvo with only skirmish units on the ground
- **WHEN** a salvo is armed and only skirmish units are on the ground
- **THEN** it targets air demons (or holds) as before

### Requirement: Life-loss sequence
A hit that costs a non-final life SHALL destroy the ship in a multi-frame explosion and start a regroup pause of 1.5–2 s.
- During the pause, hostile shots SHALL fizzle out and no new hostile fire, dive or ground launch SHALL start.
- During the pause, the swarm SHALL return to formation and nothing SHALL hit the player.
- After the pause, the reserve ship SHALL return as the next requirement says.

#### Scenario: Nothing starts while the ship is away
- **WHEN** the regroup pause is running
- **THEN** no hostile fire, dive or ground launch starts and nothing can hit the player

#### Scenario: Regroup
- **WHEN** an unshielded hit costs a life with lives remaining
- **THEN** `playerDestroyed` fires, `regroupStart` fires 0.7 s later and every hostile shot fizzles out, and `playerRespawn` fires 2.3 s after the hit as the reserve ship flies in protected

#### Scenario: Final life
- **WHEN** the last life is lost
- **THEN** `playerDestroyed` fires with `final: true` and the defeat celebration starts as before

### Requirement: Reserve ship return
After the regroup pause, the reserve ship SHALL fly up from the bottom edge with 2 s of blinking protection, and play SHALL resume. Lives, scoring and the loadout rules SHALL be unchanged, and module timers SHALL freeze while the ship is away.

#### Scenario: Timers hold while away
- **WHEN** a life is lost with a power active
- **THEN** the power's timer does not count down until the reserve ship is back in play

### Requirement: Ground homing flight
A homing missile fired at a ground unit SHALL fly a longer arc, 0.95–1.75 s depending on depth. It SHALL climb away from the ship, arc out and dive into the perspective ground plane, shrinking with distance, and impact at the unit's ground position. Air targets SHALL keep their fast direct flight.

#### Scenario: Far ground target
- **WHEN** the salvo targets a ground unit near the horizon
- **THEN** the missile takes about 1.5 s, shrinks as it flies, and destroys the unit on impact

### Requirement: Allied convoy
Allied ground units SHALL hold station in the near ground band beside the ship's depth, in the side bands. They SHALL advance up the ground plane only to engage an incoming demon unit and SHALL fall back afterwards. They SHALL never scroll off the bottom of the screen while active, collide with the player, or block shots.

#### Scenario: Escort
- **WHEN** a demon unit approaches on the left
- **THEN** the left convoy ally advances to engage it and returns to station once the unit is destroyed

## Research and reference traceability

- Master reference index: [plan/reference-register.md](../../../plan/reference-register.md)
- External & sibling source disposition ledger: [plan/research-source-ledger.md](../../../plan/research-source-ledger.md)
- Offline synthetic-imitation JEV swarm policy: [plan/policy.md](../../../plan/policy.md)
- Project-committed UX cheatsheets:
  - [.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md](../../../.tillandsias/cheatsheets/ux/game-flow-and-combat-pacing.md)
  - [.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md](../../../.tillandsias/cheatsheets/ux/arcade-25d-motion-and-transitions.md)
