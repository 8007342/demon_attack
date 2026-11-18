# Arcade presentation

## ADDED Requirements

### Requirement: Storms stay under the general-flash threshold
Every storm SHALL cause at most three general flashes in any second, SHALL keep every whole-screen wash and cloud glow under a 10 % step of relative luminance over any backdrop, SHALL keep the bright bolt to a narrow column, and SHALL blink its tell marker and the zapped ship at no more than 3 Hz (WCAG 2.3.1).

#### Scenario: Luminance step
- **WHEN** the strongest wash and cloud glow of a regular storm and of Stormfront are blended over every grey backdrop from black to white
- **THEN** no relative-luminance step reaches 0.10

#### Scenario: Flash rate
- **WHEN** a regular storm runs for 15 minutes at the fastest hostile rate
- **THEN** no two bolts land within the same second, and the tell marker and the ship's zap flicker never light more than three times in a second

### Requirement: Reduced flashing
A reduced-flashing setting SHALL follow the system's reduced motion and SHALL also be asked for with `?flash=low` in the page address. With it, storms SHALL draw no whole-screen wash and no cloud glow, the tell's leader and marker SHALL be steady, and the zapped ship SHALL not flicker; the tells and bolts SHALL still be drawn.

#### Scenario: A storm with reduced flashing
- **WHEN** a regular storm strikes with reduced flashing on
- **THEN** the wash is zero on every frame, the ship never flickers, and the bolts still fall and stun

### Requirement: Demons flap against the wind
A creature holding its place in a lateral wind of about 0.3 of full strength or more SHALL be drawn with authored wind-flap frames: the upwind wing beating deeper and higher, the downwind wing shallow and swept back, the body leaning into the wind. Diving, telling, firing and stunned creatures SHALL keep their own frames. The frames SHALL come from the same rig, palette and damage variants as the combat atlas.

#### Scenario: Side follows the wind
- **WHEN** the wind blows to the right at 0.8 of full strength over a flying drone
- **THEN** its cell is a wind-flap cell of the right-blowing side, and with the wind blowing left the left-blowing side

#### Scenario: The upwind wing is higher
- **WHEN** the raised-wing frames of every species are read from the wind-flap atlas
- **THEN** the upwind wing's top is higher than the downwind wing's for both wind sides

#### Scenario: Calm or diving
- **WHEN** the wind is under the threshold, or the creature dives or tells a dive
- **THEN** its ordinary combat-atlas cell is drawn

### Requirement: Weather gallery shows storms and wind flaps
The gallery's weather page SHALL show a regular sector's lightning storm, a storm in a gale, and the wind-flap frames of every species for both wind sides.

#### Scenario: Weather page
- **WHEN** the gallery's weather page opens
- **THEN** it has a thunderstorm tile, a storm and gale tile and an animated wind-flap sheet beside the rain and wind tiles
