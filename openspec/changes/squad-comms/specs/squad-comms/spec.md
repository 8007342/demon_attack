# Squad comms

## ADDED Requirements

### Requirement: Shared read-only event vocabulary
The page SHALL take the model's string events once per frame and publish them through one `GameEventObserver` as `GameEvent`s. Each raw event keeps its name; a raw `name:payload` event exposes its payload. The observer SHALL add derived events read from public model state. It SHALL never write to the model.

#### Scenario: A new model event plugs in by name
- **WHEN** the model emits `allyUnderAttack:2,140`
- **THEN** listeners receive a `GameEvent` named `allyUnderAttack` with payload `2,140`, and the comms director plays a ground-squad help call without code changes

#### Scenario: Observation is side-effect free
- **WHEN** the observer runs every frame of a played wave
- **THEN** the model's checkpoint, demons, shots and clock are identical to a run without it

### Requirement: Paced, prioritized callouts
Every trigger SHALL have a priority (0–10), a cooldown and a queue time-to-live. At most two messages SHALL be on the call at once, one human voice and one demon voice. A non-critical human line SHALL wait for a quiet gap after the previous one. A line of priority 8 or higher SHALL interrupt a lower, non-critical line of the same side. Lines that wait past their time-to-live SHALL be dropped. Ground-squad calls SHALL stay below the gameplay-critical warnings.

#### Scenario: A critical warning cuts chatter
- **WHEN** a pilot is mid-sentence on a weapon-pickup remark and the sentinel's dive tell begins
- **THEN** the remark stops and the dive warning plays at once

#### Scenario: No spam
- **WHEN** reinforcements arrive twice within the trigger's cooldown
- **THEN** only the first arrival is announced

### Requirement: Rotating cast with a constant anchor
Each run SHALL seed a lineup of fleet officers and ground troopers around the Fleet Admiral. The pick SHALL be deterministic for its seed, SHALL avoid the previous run's lineup when possible, and SHALL be kept on resume. Speakers on the call SHALL rotate by sector, falling back to the lineup, then the Admiral, then a guest.

#### Scenario: Fallback speaker
- **WHEN** nobody on this sector's call has a line for a trigger
- **THEN** a teammate from this run's lineup patches in before any guest does

#### Scenario: Different runs, different voices
- **WHEN** two runs start with different seeds
- **THEN** their pilots and ground troopers differ, while the Admiral speaks in both

### Requirement: Video-call layouts
On a viewport whose margins beside the 500-px cabinet are at least 150 px wide, two call tiles SHALL stand on each side and SHALL never overlap the cabinet. Elsewhere, active messages SHALL stack in at most two strips inside the 94-px HUD band. The strips SHALL stay clear of the HUD buttons and SHALL never reach the arena, the player ship or the low arena.

#### Scenario: Phone portrait
- **WHEN** a pilot line and a demon grunt are active on a 390 × 844 screen
- **THEN** both strips sit inside the HUD band, and a third waiting line shows as a `+1` pip

#### Scenario: Wide desktop
- **WHEN** four callers have spoken on a 1440 × 900 screen
- **THEN** four tiles show the air squad on the left and the ground link and brood intercept on the right, beside the shared arena

### Requirement: Demon grunts zoom in
A demon officer's line SHALL be an unintelligible creature grunt. It SHALL be subtitled with original brood glyphs and a fleet SIGINT gloss of its intent. While the officer grunts, the portrait SHALL zoom in, filling the side margin on wide screens and with a small pop inside the strip on phones. With reduced motion, the zoom SHALL apply without shake or static flicker.

#### Scenario: Reduced motion
- **WHEN** the platform requests reduced motion and an officer grunts
- **THEN** the tile enlarges without shake and the static transitions become plain fades

### Requirement: Allies never die
Lines SHALL never speak of death or grief. A downed player ship, or an allied unit knocked out (`allyRetreated`, alias `allyLost`), SHALL be described as totalled and returning to base.

#### Scenario: Ground unit knocked out
- **WHEN** the model reports `allyLost`
- **THEN** a ground trooper says a line like "I'm totalled! Going back to base!"

### Requirement: Fleet intact celebration
When no player ship and no allied unit was lost, the observer SHALL emit `flawlessSector` at a sector clear, `flawlessVictory` at a carrier victory (for that tour) and `flawlessRun` at run completion (only for runs observed from their start). The call SHALL chain lines from different crew members, show a fleet-intact banner and play a stinger. The music bridge MAY cue on the same events.

#### Scenario: Clean tour
- **WHEN** the carrier falls and no ship or ally was lost in the tour
- **THEN** the Admiral and other crew members celebrate in sequence, and the banner reads FLEET INTACT

### Requirement: Voice playback
Voice clips SHALL play through the music engine's AudioContext and master gain, so they honor mute and pause. The music SHALL duck while anyone speaks, and at most two voices SHALL sound at once. A voice toggle next to the sound button SHALL silence the voices while keeping the subtitles.

#### Scenario: Ducking
- **WHEN** a callout plays during a level cue
- **THEN** the music gain ramps down under the voice and recovers shortly after the voice ends
