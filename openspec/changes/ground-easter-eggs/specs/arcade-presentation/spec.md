# Ground easter eggs

## ADDED Requirements

### Requirement: One budget grants every easter egg
The game SHALL decide whether a ground easter egg may start through a single budget whose rarity rolls depend
only on the run seed, the egg and a key, with per-egg cooldowns, at most one egg per side band and two on
screen. The operator defaults SHALL be: dances 1 in 3 (cooldown 40 s), light-vehicle jackpots 1 in 8 (20 s),
tree flocks 2 in 5 (12 s), Host jigs 1 in 4 (60 s), critter scatters cooldown 8 s per band.

#### Scenario: Same run, same eggs
- **WHEN** two runs with the same seed ask the budget the same questions at the same times
- **THEN** they get the same answers

#### Scenario: Two on screen
- **WHEN** a flock runs on the left band and a critter scatter on the right
- **THEN** no further egg starts until one of them ends

### Requirement: Eggs stay quiet when it matters
The budget SHALL grant nothing while a ground telegraph or ground missile is on screen, a boss fight runs, the
player is on the last life, the player was just hit, the arrival hint is shown, or the air fight is dense, and
nothing at all under reduced motion. The sector-clear dance SHALL ignore rarity, cooldown and suppression but
not reduced motion.

#### Scenario: Telegraph
- **WHEN** a threat vehicle is telegraphing and a tree is pushed over
- **THEN** no flock is released

### Requirement: Presentation only
Easter eggs SHALL NOT change any simulation state, score, random stream or game event; a run SHALL produce the
same simulation with the eggs enabled and disabled. Nothing an egg draws SHALL enter the central lane below
y 300 or use a signal colour.

#### Scenario: Eggs on and off
- **WHEN** the same scripted run is played with every egg roll granted and with the eggs disabled
- **THEN** score, lives, ground units, allies and the simulation random stream are identical

### Requirement: Victory dances and jigs
A Fleet squad SHALL play its flourish (4 frames at 0.12 s, rippling through the squad) when the budget grants
a dance after it is saved or a skirmish it fought is won, never with a live Host unit within 200 texels or a
totalled ally within 100; a Fleet vehicle with a turret SHALL twirl the turret and hop one texel instead.
Every Fleet squad on screen SHALL dance once at sector clear. A Host squad SHALL jig when the ally it fought
falls back and the budget grants it.

#### Scenario: Saved squad
- **WHEN** the player's missile saves an allied squad and the budget grants a dance
- **THEN** the troopers play their flourish frames while standing, then return to their walk

### Requirement: Light vehicles break up, sometimes with a jackpot
A light Host vehicle destroyed near enough to be seen SHALL break into 5 to 8 of its authored debris pieces
(heavier Host units 3 to 4), with at most 16 pieces on screen, pieces landing short of the lane; under reduced
motion it SHALL show the plain wreck. When the budget grants a jackpot, its turret or head SHALL pop high,
spin in quarter turns, bounce once and land upright, and a crew of two Rubblings SHALL climb out and run off
outward.

#### Scenario: Jackpot
- **WHEN** a Crocket is destroyed at depth 600 and the budget grants the jackpot
- **THEN** its gun piece arcs up, bounces once and lies upright, and two Rubblings climb out and run away
  from the lane

### Requirement: Flocks from falling trees
When a tree or stalk falls and the budget grants a flock, 5 to 9 flyers of the sector's species SHALL burst
from its crown, flap at 10 to 14 frames per second, fly outward and toward the horizon, shrink and fade into
the fog, and be gone within 2.5 s, never entering the lane below y 300 nor rising above y 200.

#### Scenario: Convoy pushes a frost pine
- **WHEN** a convoy vehicle pushes over a frost pine on the left band and the flock is granted
- **THEN** rime moths leave its crown flying up and to the left and vanish before reaching the swarm band

### Requirement: Critters scatter from the troops
When a ground unit comes within 50 texels of a flyover critter and the budget grants a scatter, up to 8
critters of that band SHALL flee toward the outer edge with leap frames and a dust puff per landing, half of
them burrowing after 1 to 1.5 s.

#### Scenario: Squad walks past rock mites
- **WHEN** a demon squad passes within 50 texels of a group of rock mites
- **THEN** the mites leap away from the lane and some of them burrow
