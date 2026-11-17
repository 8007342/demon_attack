# Squad comms

## MODIFIED Requirements

### Requirement: Voice playback
Voice clips SHALL play through the music engine's AudioContext and master gain, so they honor mute and pause. While a voice plays the music SHALL duck a few dB (mix-balance), and the director SHALL keep one voice on the channel. A voice toggle next to the sound button SHALL silence the voices while keeping the subtitles.

#### Scenario: Ducking
- **WHEN** a callout plays during a level cue
- **THEN** the music ducks 3 dB (1.5 dB for a demon line or a clip under 1 s) from the clip's first sample and returns after its last
