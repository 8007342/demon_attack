# Arcade presentation

## ADDED Requirements

### Requirement: Reduced effects setting
The title and pause menus SHALL offer one "Reduced effects" setting with three states, Auto (the system's reduced motion), On and Off, remembered per device. When it resolves on, the game SHALL draw reduced flashing, every reduced-motion look and the LITE eye-candy budgets, keeping telegraphs and gameplay readable. `?flash=low` SHALL still force reduced flashing whatever the setting.

#### Scenario: On
- **WHEN** the setting is On and the system does not ask for reduced motion
- **THEN** storms draw no wash and no cloud glow, the zapped ship never flickers, nothing shakes, and rain, wind, motes and explosion sprites stay within the LITE budget (0.35, 0.35, 0.5, 14), with no sparks, blur or emergence frames, while hatch lurkers and pulse rings keep the tier's own

#### Scenario: Auto follows the system
- **WHEN** the setting is Auto and the system asks for reduced motion
- **THEN** the calm look is on and widgets see `disableAnimations`; with Off they do not, and with `?flash=low` flashing stays reduced

#### Scenario: Remembered
- **WHEN** the player picks On and reloads the page
- **THEN** the setting is On again

### Requirement: Reduced effects is rendering only
The Reduced effects setting SHALL never change the game's rules, timing or simulation state. The model's reduced motion and the flight distance the ground units ride SHALL follow the system setting alone.

#### Scenario: Identical runs
- **WHEN** two runs of one seed are stepped for 150 seconds through combat and a sector change, one with the setting On and one Off
- **THEN** the model state and the events are identical on every compared frame

### Requirement: Low-power note
When the frame-budget governor has stepped down to LITE by itself, the pause menu's row SHALL say so ("AUTO (LOW-POWER)") without switching the setting on.

#### Scenario: A struggling device
- **WHEN** sustained slow frames step the governor down to LITE with the setting on Auto
- **THEN** the row reads `REDUCED EFFECTS: AUTO (LOW-POWER)` and the setting stays Auto
