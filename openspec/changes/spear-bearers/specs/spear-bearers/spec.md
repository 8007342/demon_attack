# Spear-bearers

## ADDED Requirements

### Requirement: Spear-bearers replace hunters in later tours
From route 2 (Easy: route 3), in sectors 2-4 (Easy: 3-4), an elite birth whose wave number plus its elite ordinal in the wave is even SHALL be a spear-bearer. It SHALL keep the elite's hit points and rank, SHALL NOT add a creature to the wave, and its choice SHALL NOT draw from the run's random. Bonus levels and the carrier sector SHALL have none.

#### Scenario: The third tour on Normal
- **WHEN** a Normal run reaches route 2, sector 3, wave 1
- **THEN** the wave's first elite is a spear-bearer and its second a plain hunter, and the roster and its random draws are those of the same wave without bearers

#### Scenario: Easy waits a tour
- **WHEN** an Easy run plays route 2, or route 3 sector 2
- **THEN** no spear-bearer is born

#### Scenario: Never in the opening tours or bonus levels
- **WHEN** a run plays routes 0-1, a bonus level or a carrier sector
- **THEN** no spear-bearer is born

### Requirement: The throw is telegraphed mid-dive
A diving spear-bearer SHALL hold its spear levelled, and once it has come 30 % of the way from where its dive began to the ship's row it SHALL wind up for 0.55 hostile-rate seconds, then throw one spear at the ship's current position. A throw that would leave closer than 120 units above the ship's row SHALL be withheld. It SHALL throw at most once a dive and re-arm back on its station.

#### Scenario: A dive from the formation
- **WHEN** a bearer at y 140 dives on Normal
- **THEN** it winds up at y ≥ 241 with the spear drawn back and a glint on its head, and 0.55 s later one spear flies from its claw toward the ship

#### Scenario: Too close to throw
- **WHEN** a bearer starts a dive at y 360
- **THEN** it throws nothing and keeps its spear for the rest of the dive

#### Scenario: Re-armed
- **WHEN** a bearer that threw its spear is back on its station
- **THEN** it holds a fresh spear

### Requirement: The thrown spear is a hostile shot
The spear SHALL be a hostile projectile that falls at 255 units per second times the tour's speed on the hostile speed grid, costs a life like any hostile shot, and SHALL drift with the wind exactly like every other hostile shot. It SHALL be drawn tip down along its drawn velocity, wind included, with its tip on its hit point.

#### Scenario: A crosswind
- **WHEN** a spear and an ordinary hostile shot fall side by side in a gale
- **THEN** both drift sideways by the same amount, and the spear is drawn leaning with the drift

### Requirement: A spear-bearer fires no triple spread
A spear-bearer SHALL NOT fire the hunter's three-shot spread; the spear SHALL be its own weapon. It MAY still be chosen as the swarm's single random shooter like any creature.

#### Scenario: The attack timer runs out
- **WHEN** a bearer's attack timer runs out in formation
- **THEN** it prepares a dive as a hunter would, and no three-shot spread leaves it

### Requirement: The buckler is knocked away, never refreshed
While a spear-bearer dives, its buckler SHALL absorb hits from the front (any hit except a homing missile, or a splash above the body's middle), one buckler point per damage point, with 2 points for its whole life. At 0 it SHALL be knocked away for good. While it lasts it SHALL replace the thermal dive shield; the dive it is lost in SHALL get none.

#### Scenario: Two hits in a dive
- **WHEN** the player hits a diving bearer twice from below with the standard gun
- **THEN** the first hit flashes the buckler and leaves the creature unhurt, the second knocks the buckler away (it tumbles off) and scores 25 points, and the third hit wounds the creature

#### Scenario: In formation
- **WHEN** the player hits a bearer that is not diving
- **THEN** the hit reaches its body and the buckler is unchanged

#### Scenario: The next dive
- **WHEN** a bearer whose buckler was knocked away dives again
- **THEN** it gets the hunter's 2-point thermal dive shield and no buckler

#### Scenario: A homing missile
- **WHEN** a homing missile meets a diving bearer with its buckler up
- **THEN** the missile's damage reaches the creature and the buckler is unchanged

### Requirement: Lightning stuns a spear-bearer
A bolt SHALL stun a spear-bearer like any creature (storm-lightning). The stun SHALL cancel a wind-up, and while stunned its buckler SHALL absorb nothing.

#### Scenario: Struck while winding up
- **WHEN** a bolt lands on a bearer during its wind-up
- **THEN** it falls stunned, no spear is thrown, and a hit while it falls reaches its body

### Requirement: The throw is announced
A throw SHALL queue the structured event `spearThrow` (data `x`, `y`, `kind`, `throws`) for the radio and music, and the raw sounds `spearGlint` (the wind-up), `spearRelease`, `bucklerClang` and `bucklerOff`. No raw event SHALL share the structured event's name.

#### Scenario: A throw
- **WHEN** a bearer releases its spear
- **THEN** `spearGlint` was heard at the start of the wind-up, `spearRelease` plays and one `spearThrow` event is queued

### Requirement: The gear reads at phone size
The bearer's gear SHALL be drawn over the shipped gargoyle body in its own transform: the buckler (bone rim, iron face, one leaning bone fang) carried at the side or raised in front while diving, and the spear upright, levelled, drawn back with a glint, or gone after the throw. It SHALL use no cyan and no blackbody colours and SHALL NOT cover the rank glyph.

#### Scenario: The review sheet
- **WHEN** `art/contact/spear-bearers.png` is regenerated with `cd tools/spear_bearers && go run . offline`
- **THEN** every state reads on all four species at 40 px, and `go run . check` reports the committed files byte-identical
