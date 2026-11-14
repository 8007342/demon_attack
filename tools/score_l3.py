#!/usr/bin/env python3
"""L3 Ember Moon: the full 96-bar multitrack arrangement for the real-instrument pilot.

Source of truth for the notes is tools/music_motifs.py (the L3 riff, hook and
progression) and art/music/campaign.json (the shared campaign theme and the six
sections). This file arranges them into one 96-bar score with real parts (drums,
bass, two rhythm guitars, lead and harmony guitars, clean guitar, choir, organ,
brass, strings, timpani), so every adaptive cue can later be cut from one
arrangement and one mix (plan/audio-studio/music-requirements.md, sections 4.3
and 7). Everything here is original writing for this game.

Python, standard library only: the motifs live in a Python module. One process,
no workers. Deterministic: the same inputs give byte-identical files.

Run:  python3 -I tools/score_l3.py [--out art/music/scores/l3-ember-moon]
Out:  full.mid (SMF type 1, one track per part, conductor track with tempo,
      key and section markers), parts/<part>.mid (conductor + one part, for a
      per-part SFZ render), score.json (sections, chords per bar, parts, hashes).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import music_motifs as motifs  # noqa: E402

LEVEL = 3
BARS = 96
PPQ = 480
BAR_SAMPLES = motifs.BAR_SAMPLES[LEVEL]          # 64000 at 48 kHz
BPM = motifs.BPM[LEVEL]                          # 180.0 exactly
SR = 48000
p = motifs.p

# ------------------------------------------------------------------ form
SECTIONS = [  # (id, first bar, bars), 0-indexed bars, matches campaign.json
    ('opening', 0, 8), ('theme-a', 8, 24), ('answer-b', 32, 16),
    ('contrast-c', 48, 16), ('developed-recap', 64, 24), ('outgoing', 88, 8),
]
BLOCKS = [  # finer 8-bar rehearsal marks inside the sections
    (0, 'opening: organ, choir, clean theme; war drums from bar 5'),
    (8, 'A1: gallop riff, campaign theme on lead'),
    (16, 'A2: gallop riff, level hook'),
    (24, 'A3: hook in twin thirds, choir, double kick'),
    (32, 'B1: 3-3-2 push, theme call (lead) and answer (brass)'),
    (40, 'B2: double kick, twin-lead development'),
    (48, 'C1: half-time breakdown, choir sings the theme augmented'),
    (56, 'C2: gallop returns, guitar solo'),
    (64, 'R1: recap, hook in thirds over choir and organ'),
    (72, 'R2: brass and choir anthem (augmented theme), lead answers'),
    (80, 'R3: climax, everything, double kick'),
    (88, 'outgoing: thins out, final Em hit, G held for the L3->L4 bridge'),
]

# Chords: one or two per bar (name, beats). The riff progression comes from the
# motif: E | E | C-D | E | E | E | F-G | A-B.
RIFF_CHORDS = [[('Em', 4)], [('Em', 4)], [('C', 2), ('D', 2)], [('Em', 4)],
               [('Em', 4)], [('Em', 4)], [('F', 2), ('G', 2)], [('Am', 2), ('B', 2)]]
B_CHORDS = [[(c, 4)] for c in ('C', 'D', 'Em', 'Em', 'Am', 'C', 'B', 'B',
                               'C', 'D', 'Em', 'G', 'Am', 'F', 'B', 'B')]
C1_CHORDS = [[(c, 4)] for c in ('Em', 'F', 'Em', 'F', 'Am', 'C', 'B', 'B')]
OUT_CHORDS = RIFF_CHORDS[:4] + [[('C', 4)], [('D', 4)], [('Em', 4)], [('Em', 4)]]
CHORDS = (RIFF_CHORDS * 4            # opening + theme A (bars 0..31)
          + B_CHORDS                 # 32..47
          + C1_CHORDS + RIFF_CHORDS  # 48..63
          + RIFF_CHORDS * 3          # 64..87
          + OUT_CHORDS)              # 88..95
assert len(CHORDS) == BARS
TRIADS = {'Em': ('E', 'G', 'B'), 'C': ('C', 'E', 'G'), 'D': ('D', 'F#', 'A'), 'F': ('F', 'A', 'C'),
          'G': ('G', 'B', 'D'), 'Am': ('A', 'C', 'E'), 'B': ('B', 'D#', 'F#')}
PC = motifs.N


def chord_at(bar: int, beat: float = 0.0) -> str:
    t = 0.0
    for name, beats in CHORDS[bar]:
        if beat < t + beats:
            return name
        t += beats
    return CHORDS[bar][-1][0]


def root_pitch(name: str, low: int) -> int:
    """Lowest pitch >= low whose pitch class is the chord root."""
    pc = PC[TRIADS[name][0]]
    return low + (pc - low) % 12


def voicing(name: str, low: int, top: int | None = None) -> list[int]:
    """Close triad voicing at or above `low` (root position)."""
    r = root_pitch(name, low)
    out = []
    for n in TRIADS[name]:
        q = r + (PC[n] - r) % 12
        out.append(q)
    if top is not None:
        out = [q for q in out if q <= top] or out
    return out


# ------------------------------------------------------------------ scales and harmony
E_MINOR = [PC[n] for n in ('E', 'F#', 'G', 'A', 'B', 'C', 'D')]
E_HARMONIC = [PC[n] for n in ('E', 'F#', 'G', 'A', 'B', 'C', 'D#')]


def third_below(pitch: int, chord: str) -> int:
    """Diatonic third below in E minor (harmonic minor over B, Phrygian F over F)."""
    scale = list(E_HARMONIC if chord == 'B' else E_MINOR)
    if chord == 'F':
        scale[1] = PC['F']
    pc = pitch % 12
    if pc not in scale:  # chromatic note: a plain minor third
        return pitch - 3
    i = scale.index(pc)
    target = scale[(i - 2) % 7]
    return pitch - ((pc - target) % 12)


def diatonic_up(pitch: int, steps: int) -> int:
    """Walk `steps` degrees up the E natural minor scale from a diatonic pitch."""
    k = E_MINOR.index(pitch % 12)
    for _ in range(steps):
        pitch += (E_MINOR[(k + 1) % 7] - E_MINOR[k % 7]) % 12
        k += 1
    return pitch


# ------------------------------------------------------------------ events
# Event: (beat, dur, pitch, vel, part). Beats are absolute from bar 0.
EV: list[tuple[float, float, int, int, str]] = []


def add(beat, dur, pitch, vel, part):
    EV.append((float(beat), float(dur), int(pitch), max(1, min(127, int(vel))), part))


def line(text: str, bar: int, part: str, vel: int = 100, gate: float = .95, bars: int | None = None):
    """'E5:1 F#5:.5 -:1' starting at `bar`; asserts it fills whole bars."""
    t = bar * 4.0
    start = t
    for tok in text.split():
        name, dur = tok.split(':')
        d = float(dur)
        if name != '-':
            add(t, d * gate, p(name), vel, part)
        t += d
    length = t - start
    assert abs(length / 4 - round(length / 4)) < 1e-9, (text, length)
    if bars is not None:
        assert round(length / 4) == bars, (text, length, bars)
    return t


def theme(bar: int, part: str, degree_root: str, octave: int, vel: int, scale_mult: float = 1.0,
          chord_aware: bool = False):
    """The campaign theme (degrees 1-3-5-4, rhythm 1.5-.5-1-1) on any E-minor degree."""
    r = p(degree_root + str(octave))
    t = bar * 4.0
    for step, dur in zip((0, 2, 4, 3), (1.5, .5, 1, 1)):
        add(t, dur * scale_mult * .95, diatonic_up(r, step), vel, part)
        t += dur * scale_mult
    return t


# GM drum map
KICK, SNARE, HAT, OHAT, CRASH, CRASH2, RIDE, BELL, CHINA = 36, 38, 42, 46, 49, 57, 51, 53, 52
TOM_HI, TOM_MID, TOM_LO, TOM_FLOOR = 48, 45, 43, 41


def drums(bar: int, style: str, vel: int = 112, crash: bool | None = None, fill: str | None = None):
    b0 = bar * 4
    d = 'drums'
    if crash or (crash is None and bar % 2 == 0):
        add(b0, 2, CRASH if bar % 4 == 0 else CRASH2, vel, d)
    if style == 'gallop':
        for i in range(4):
            add(b0 + i, .2, KICK, vel, d)
            add(b0 + i + .5, .15, KICK, vel - 14, d)
            add(b0 + i + .75, .15, KICK, vel - 14, d)
            add(b0 + i, .4, RIDE, vel - 26 + (8 if i % 2 == 0 else 0), d)
        add(b0 + 1, .3, SNARE, vel + 6, d)
        add(b0 + 3, .3, SNARE, vel + 6, d)
    elif style == 'double':
        for k in range(16):
            add(b0 + k * .25, .15, KICK, vel - (0 if k % 4 == 0 else 10), d)
        for i in range(4):
            add(b0 + i, .4, CHINA if i % 2 else BELL, vel - 20, d)
        add(b0 + 1, .3, SNARE, vel + 8, d)
        add(b0 + 3, .3, SNARE, vel + 8, d)
    elif style == 'push332':
        for k in (0, 1.5, 3):
            add(b0 + k, .25, KICK, vel, d)
            add(b0 + k, 1, CRASH2 if k else CRASH, vel - 12, d)
        for k in (.5, 1, 2, 2.5, 3.5):
            add(b0 + k, .15, KICK, vel - 18, d)
        for i in range(8):
            add(b0 + i * .5, .2, HAT, vel - 30 + (10 if i % 2 == 0 else 0), d)
        add(b0 + 1, .3, SNARE, vel + 6, d)
        add(b0 + 3, .3, SNARE, vel + 6, d)
    elif style == 'halftime':
        add(b0, .3, KICK, vel, d)
        add(b0 + 1.5, .2, KICK, vel - 16, d)
        add(b0 + 2, .4, SNARE, vel + 8, d)
        for i in range(4):
            add(b0 + i, .5, RIDE, vel - 30, d)
    elif style == 'war':  # tribal war drums: floor/low toms, no cymbals
        for i in range(8):
            add(b0 + i * .5, .3, TOM_FLOOR if i % 2 == 0 else TOM_LO, vel - (0 if i % 4 == 0 else 22), d)
        add(b0, .3, KICK, vel, d)
        add(b0 + 2, .3, KICK, vel - 10, d)
    elif style == 'none':
        pass
    if fill == 'toms':  # beat 4: snare + toms down
        EV[:] = [e for e in EV if not (e[4] == d and b0 + 3 <= e[0] < b0 + 4 and e[2] not in (KICK,))]
        for k, tom in enumerate((SNARE, TOM_HI, TOM_MID, TOM_LO, TOM_FLOOR, TOM_FLOOR, TOM_LO, TOM_FLOOR)):
            add(b0 + 3 + k * .125, .12, tom, vel - 4 + k, d)
    elif fill == 'roll':  # whole-bar snare roll, crescendo
        EV[:] = [e for e in EV if not (e[4] == d and b0 <= e[0] < b0 + 4 and e[2] in (SNARE, HAT, RIDE))]
        for k in range(16):
            add(b0 + k * .25, .12, SNARE, 60 + k * 4, d)
    elif fill == 'answer':  # war-march tom answer on beat 4
        EV[:] = [e for e in EV if not (e[4] == d and b0 + 3 <= e[0] < b0 + 4 and e[2] in (SNARE, RIDE, HAT))]
        for k, tom in enumerate((TOM_MID, TOM_MID, TOM_LO, TOM_FLOOR)):
            add(b0 + 3 + k * .25, .2, tom, vel, d)


# Rhythm guitars: open power chords on one channel, palm mutes on another
# (parts 'gtrL'/'gtrL-pm', 'gtrR'/'gtrR-pm'), written as real notes: root,
# fifth, octave. Riff roots come from the motif (E2 pedal, C3/D3 up top).
RIFF = motifs.riff_roots(LEVEL)   # 64 eighth-note roots, 8 bars


ROOT_LOG: list[tuple[float, float, int, int, str]] = []  # (beat, dur, root, vel, part) for sketches


def power(beat, dur, root, vel, side, mute=False):
    part = f'gtr{side}' + ('-pm' if mute else '')
    ROOT_LOG.append((float(beat), float(dur), int(root), int(vel), part))
    notes = (root, root + 7) if mute else (root, root + 7, root + 12)
    for q in notes:
        add(beat, dur, q, vel - (6 if q != root else 0), part)


def guitars_gallop(bar: int, vel: int = 110, sides=('L', 'R')):
    j = bar % 8
    for side in sides:
        for beat in range(4):
            i = j * 8 + beat * 2
            t = bar * 4 + beat
            power(t, .45, RIFF[i], vel + (6 if beat == 0 else 0), side)
            power(t + .5, .2, RIFF[i + 1], vel - 12, side, mute=True)
            power(t + .75, .2, RIFF[i + 1], vel - 12, side, mute=True)


def guitars_chug(bar: int, vel: int, sides=('L', 'R'), sixteenths=False):
    step = .25 if sixteenths else .5
    for side in sides:
        for k in range(int(4 / step)):
            t = bar * 4 + k * step
            power(t, step * .8, root_pitch(chord_at(bar, k * step), 40), vel + (8 if k * step % 1 == 0 else 0), side, mute=True)


def guitars_push332(bar: int, vel: int = 112):
    for side in ('L', 'R'):
        for k in range(8):
            t = bar * 4 + k * .5
            r = root_pitch(chord_at(bar, k * .5), 40)
            if k in (0, 3, 6):
                power(t, 1.4 if k < 6 else .9, r, vel + 4, side)
        # sixteenth palm mutes under the held chords keep the motor running
        for k in (2, 5, 7):
            t = bar * 4 + k * .5
            r = root_pitch(chord_at(bar, k * .5), 40)
            power(t, .2, r, vel - 14, side, mute=True)
            power(t + .25, .2, r, vel - 14, side, mute=True)


def guitars_hold(bar: int, vel: int, beats: float = 4, sides=('L', 'R')):
    t = 0.0
    for name, b in CHORDS[bar]:
        if t >= beats:
            break
        for side in sides:
            power(bar * 4 + t, min(b, beats - t) * .97, root_pitch(name, 40), vel, side)
        t += b


def bass_gallop(bar: int, vel: int = 104):
    j = bar % 8
    for beat in range(4):
        i = j * 8 + beat * 2
        t = bar * 4 + beat
        low = lambda r: r - 12 if r >= 40 else r  # noqa: E731
        add(t, .45, low(RIFF[i]), vel + (6 if beat == 0 else 0), 'bass')
        add(t + .5, .2, low(RIFF[i + 1]), vel - 10, 'bass')
        add(t + .75, .2, low(RIFF[i + 1]), vel - 10, 'bass')


def bass_eighths(bar: int, vel: int = 102):
    for k in range(8):
        add(bar * 4 + k * .5, .45, root_pitch(chord_at(bar, k * .5), 28), vel + (6 if k % 2 == 0 else 0), 'bass')


def bass_hold(bar: int, vel: int = 96, beats: float = 4):
    t = 0.0
    for name, b in CHORDS[bar]:
        if t >= beats:
            break
        add(bar * 4 + t, min(b, beats - t) * .97, root_pitch(name, 28), vel, 'bass')
        t += b


def pad(bar: int, part: str, low: int, vel: int, add_top: int | None = None):
    t = 0.0
    for name, b in CHORDS[bar]:
        for q in voicing(name, low):
            add(bar * 4 + t, b * .98, q, vel, part)
        if add_top is not None:
            add(bar * 4 + t, b * .98, root_pitch(name, add_top), vel - 6, part)
        t += b


def clean_arp(bar: int, vel: int = 72):
    """Eighth-note arpeggio: root, fifth, octave, tenth, octave, fifth, ..."""
    t = 0.0
    for name, b in CHORDS[bar]:
        r = root_pitch(name, 52)
        third = 3 if name.endswith('m') else 4
        shape = [0, 7, 12, 12 + third, 19, 12 + third, 12, 7]
        for k in range(int(b * 2)):
            add(bar * 4 + t + k * .5, .9, r + shape[k % 8], vel - (0 if k % 4 == 0 else 8), 'clean')
        t += b


def timp_roll(bar: int, beats: float, vel0: int, vel1: int, pitch: int = 40):
    steps = int(beats * 6)
    for k in range(steps):
        add(bar * 4 + (4 - beats) + k / 6, .16, pitch, vel0 + (vel1 - vel0) * k // max(1, steps - 1), 'timpani')


def timp_hit(bar: int, beat: float = 0, vel: int = 112, pitch: int | None = None):
    if pitch is None:
        pitch = root_pitch(chord_at(bar, beat), 40)
        if pitch > 50:
            pitch -= 12
    add(bar * 4 + beat, 1.5, pitch, vel, 'timpani')


def harmonise(part_from: str, part_to: str, bar0: int, bar1: int, vel_drop: int = 10):
    for b, d, q, v, part in list(EV):
        if part == part_from and bar0 * 4 <= b < bar1 * 4:
            bar = int(b // 4)
            add(b, d, third_below(q, chord_at(bar, b - bar * 4)), v - vel_drop, part_to)


HOOK = motifs.MOTIFS[LEVEL]['hook']   # the level's 8-bar twin-guitar hook


# ------------------------------------------------------------------ arrangement
def compose():
    EV.clear()
    ROOT_LOG.clear()
    # --- opening (bars 0-7): clean, symphonic; war drums enter at bar 4
    for bar in range(8):
        pad(bar, 'organ', 52, 50 + bar * 3)
        pad(bar, 'strings', 64, 40 + bar * 4)
        clean_arp(bar, 66 + bar * 2)
        if bar >= 2:
            pad(bar, 'choir', 64, 44 + bar * 4)
        if bar >= 4:
            bass_hold(bar, 86 + bar * 2)
            drums(bar, 'war', 84 + bar * 5, crash=False)
    # The theme on the clean guitar, answered a degree higher.
    theme(0, 'lead-clean', 'E', 5, 84)
    line('G5:2 E5:2', 1, 'lead-clean', 80)
    theme(2, 'lead-clean', 'C', 5, 84)   # over C-D
    line('E5:4', 3, 'lead-clean', 80)
    theme(4, 'lead-clean', 'E', 5, 92)
    theme(5, 'lead-clean', 'G', 5, 92)
    line('A5:2 B5:2', 6, 'lead-clean', 96)
    line('C6:2 B5:2', 7, 'lead-clean', 96)
    timp_roll(3, 4, 50, 100)
    timp_hit(4, 0, 112)
    guitars_chug(6, 88)
    guitars_chug(7, 96, sixteenths=True)
    drums(7, 'none', fill='roll')
    timp_roll(7, 2, 70, 118)

    # --- theme A (bars 8-31)
    for bar in range(8, 32):
        guitars_gallop(bar, 108 + (4 if bar >= 24 else 0))
        bass_gallop(bar, 102 + (4 if bar >= 24 else 0))
        style = 'double' if bar in (30, 31) else 'gallop'
        drums(bar, style, 112 + (4 if bar >= 24 else 0),
              fill='toms' if bar in (15, 23, 31) else ('answer' if bar % 2 == 1 else None))
    timp_hit(8, 0, 118)
    # A1: the campaign theme states the level, then rises.
    line('E5:1.5 G5:.5 B5:1 A5:1 '
         'G5:1 F#5:1 E5:2 '
         'C5:1.5 E5:.5 G5:1 F#5:1 '
         'E5:4 '
         'E5:1.5 G5:.5 B5:1 A5:1 '
         'B5:1.5 D6:.5 C6:1 B5:1 '
         'A5:2 B5:2 '
         'C6:2 B5:2', 8, 'lead', 104, bars=8)
    # A2: the level hook. A3: the hook in twin thirds, choir enters.
    line(HOOK, 16, 'lead', 106, bars=8)
    line(HOOK, 24, 'lead', 110, bars=8)
    harmonise('lead', 'lead2', 24, 32)
    for bar in range(24, 32):
        pad(bar, 'choir', 64, 84)
        pad(bar, 'organ', 52, 74)

    # --- answer B (bars 32-47)
    for bar in range(32, 48):
        if bar in (38, 39):
            guitars_chug(bar, 112, sixteenths=True)
            bass_eighths(bar, 106)
        else:
            guitars_push332(bar, 112)
            bass_eighths(bar, 104)
        if bar < 40:
            drums(bar, 'push332', 112, crash=False, fill='toms' if bar == 39 else None)
        else:
            drums(bar, 'double', 116, fill='toms' if bar in (43, 47) else None)
    timp_hit(32, 0, 118)
    timp_hit(40, 0, 120)
    # B1: theme call on lead, answer on brass, lead run into B2.
    line('G5:1.5 E5:.5 G5:1 C6:1 '
         'A5:1.5 F#5:.5 A5:1 D6:1 '
         'B5:1 A5:.5 G5:.5 F#5:1 G5:1 '
         'E5:4', 32, 'lead', 108, bars=4)
    line('A4:1.5 C5:.5 E5:1 D5:1 '
         'E5:1.5 G5:.5 E5:1 C5:1 '
         'D#5:1.5 F#5:.5 B5:2 '
         'B4:4', 36, 'brass', 104, bars=4)
    line('-:2 B4:.25 C5:.25 D#5:.25 E5:.25 F#5:.25 G5:.25 A5:.25 B5:.25',
         39, 'lead', 104, bars=1)
    # B2: twin-lead development of the call.
    line('G5:1.5 E5:.5 G5:1 C6:1 '
         'A5:1.5 F#5:.5 A5:1 D6:1 '
         'B5:1 A5:.5 G5:.5 F#5:1 G5:1 '
         'B5:1.5 D6:.5 B5:1 G5:1 '
         'C6:1.5 B5:.5 A5:1 E5:1 '
         'F5:1.5 A5:.5 C6:1 B5:1 '
         'B5:1 A5:.5 G5:.5 F#5:1 D#5:1 '
         'B5:4', 40, 'lead', 112, bars=8)
    harmonise('lead', 'lead2', 40, 48)
    for bar in range(40, 48):
        pad(bar, 'strings', 64, 80)
        add(bar * 4, .5, root_pitch(chord_at(bar), 52), 110, 'brass')        # stab on 1
        add(bar * 4, .5, root_pitch(chord_at(bar), 52) + 7, 104, 'brass')

    # --- contrast C (bars 48-63)
    # C1 (48-55): the dark reduction. War drums, clean arps, organ; the choir
    # sings the theme augmented (3-1-2-2 beats), B against F as the dread.
    for bar in range(48, 56):
        pad(bar, 'organ', 52, 56)
        clean_arp(bar, 62)
        bass_hold(bar, 76)
        if bar < 52:
            drums(bar, 'war', 78, crash=False)
        else:
            drums(bar, 'halftime', 92, crash=bar == 52)
            guitars_hold(bar, 90)
    line('E4:3 G4:1 B4:2 A4:2 '
         'B4:3 A4:1 G4:2 F4:2 '
         'A4:3 C5:1 E5:2 D5:2 '
         'D#5:4 B4:4', 48, 'choir', 72, gate=.98, bars=8)
    harmonise('choir', 'choir', 48, 56, vel_drop=14)
    timp_hit(48, 0, 116)
    timp_roll(55, 4, 60, 118, pitch=47)
    drums(55, 'none', fill='roll')
    # C2 (56-63): gallop returns under a written guitar solo.
    for bar in range(56, 64):
        guitars_gallop(bar, 104, sides=('L', 'R'))
        bass_gallop(bar, 100)
        drums(bar, 'gallop', 110, fill='toms' if bar == 63 else ('answer' if bar % 2 == 1 else None))
    line('E5:.5 G5:.5 B5:.5 E6:.5 D6:.5 B5:.5 G5:.5 B5:.5 '
         'A5:.5 B5:.5 G5:.5 E5:.5 F5:1 G5:1 '
         'E5:.25 F#5:.25 G5:.25 E5:.25 C6:1 D6:.25 C6:.25 B5:.25 A5:.25 F#5:1 '
         'B5:1.5 A5:.25 G5:.25 E5:2 '
         'B5:.25 A5:.25 G5:.25 F#5:.25 A5:.25 G5:.25 F#5:.25 E5:.25 '
         'G5:.25 F#5:.25 E5:.25 D5:.25 F#5:.25 E5:.25 D5:.25 B4:.25 '
         'E5:2 F5:1 G5:1 '
         'A5:.25 G5:.25 F5:.25 G5:.25 A5:.25 C6:.25 B5:.25 A5:.25 '
         'G5:.25 F#5:.25 G5:.25 A5:.25 B5:.25 D6:.25 C6:.25 B5:.25 '
         'C6:1 E6:1 D#6:1 F#6:1', 56, 'lead', 108, gate=.9, bars=8)
    timp_hit(56, 0, 114)

    # --- developed recap (bars 64-87)
    for bar in range(64, 88):
        guitars_gallop(bar, 112)
        bass_gallop(bar, 106)
        if bar >= 80 or bar in (70, 71):
            drums(bar, 'double', 118, fill='toms' if bar in (71, 87) else None)
        else:
            drums(bar, 'gallop', 116, fill='toms' if bar == 79 else ('answer' if bar % 2 == 1 else None))
        pad(bar, 'organ', 52, 80)
    # R1: hook in thirds over choir.
    line(HOOK, 64, 'lead', 112, bars=8)
    harmonise('lead', 'lead2', 64, 72)
    for bar in range(64, 72):
        pad(bar, 'choir', 64, 88)
    # R2: the anthem. Brass and choir sing the augmented theme; the lead
    # answers in the second half with the rising A1 line.
    anthem = ('E4:3 G4:1 B4:2 A4:2 '
              'G4:3 C5:1 D5:2 B4:2 '
              'E4:3 G4:1 B4:2 A4:2 '
              'A4:2 B4:2 C5:2 D#5:2')
    line(anthem, 72, 'brass', 112, gate=.97, bars=8)
    line(anthem, 72, 'choir', 96, gate=.98, bars=8)
    harmonise('choir', 'choir', 72, 80, vel_drop=12)
    line('E5:1.5 G5:.5 B5:1 A5:1 '
         'B5:1.5 D6:.5 C6:1 B5:1 '
         'A5:2 B5:2 '
         'C6:2 B5:2', 76, 'lead', 112, bars=4)
    for bar in range(72, 80):
        pad(bar, 'strings', 64, 88)
    # R3: climax. Hook in thirds, brass theme stabs, choir and strings.
    line(HOOK, 80, 'lead', 118, bars=8)
    harmonise('lead', 'lead2', 80, 88)
    for bar in range(80, 88):
        pad(bar, 'choir', 64, 100, add_top=72)
        pad(bar, 'strings', 64, 96)
        if bar % 2 == 0:
            theme(bar, 'brass', 'E' if bar % 8 in (0, 4) else ('C' if bar % 8 == 2 else 'A'), 4, 116)
    for bar in (64, 72, 80):
        timp_hit(bar, 0, 122)
    timp_roll(87, 2, 80, 124)

    # --- outgoing (bars 88-95): thin out, final Em hit, G held for the bridge
    for bar in (88, 89):
        guitars_gallop(bar, 98)
        bass_gallop(bar, 100)
        drums(bar, 'gallop', 100, fill='answer' if bar == 89 else None)
    for bar in (90, 91):
        guitars_hold(bar, 94)
        bass_hold(bar, 96)
        drums(bar, 'halftime', 90, crash=True)
    for bar in (92, 93):
        clean_arp(bar, 70 - (bar - 92) * 6)
        bass_hold(bar, 84)
        drums(bar, 'war', 92 - (bar - 92) * 12, crash=False)
    line('E5:3 G5:1 B5:2 A5:2 '
         'G5:4 E5:4', 88, 'lead', 104, gate=.97, bars=4)
    for bar in range(88, 96):
        pad(bar, 'organ', 52, 66 - (bar - 88) * 3)
        pad(bar, 'strings', 64, 66 - (bar - 88) * 4)
        if bar >= 90:
            pad(bar, 'choir', 64, 70 - (bar - 90) * 4)
    # Final hit on bar 94 (Em, everyone), ringing; bar 95 holds G on top.
    guitars_hold(94, 116, beats=4)
    bass_hold(94, 110)
    add(94 * 4, 4, CRASH, 120, 'drums')
    add(94 * 4, 4, CHINA, 110, 'drums')
    add(94 * 4, .3, KICK, 124, 'drums')
    timp_hit(94, 0, 124, pitch=40)
    timp_roll(95, 4, 70, 40, pitch=40)
    for part, q, v in (('organ', p('G4'), 74), ('choir', p('G4'), 70), ('strings', p('G5'), 66),
                       ('organ', p('E3'), 70), ('strings', p('B4'), 60)):
        add(94 * 4, 7.9, q, v, part)


# ------------------------------------------------------------------ parts, humanise, MIDI
PARTS = [  # name, channel (0-based; 9 = GM drums), GM program, role, render hint
    ('drums', 9, 0, 'drum kit (GM map)', 'SFZ drum kit (Karoryfer big-rusty or unruly drums)'),
    ('bass', 0, 33, 'bass guitar, fingered/picked', 'SFZ bass (meatbass or growlybass) -> saturate'),
    ('gtrL', 1, 30, 'rhythm guitar left, open power chords', 'DI guitar SFZ -> amp/cab (NAM in batch 2; saturate+EQ now), pan L'),
    ('gtrL-pm', 2, 28, 'rhythm guitar left, palm mutes', 'same chain as gtrL, palm-mute articulation'),
    ('gtrR', 3, 30, 'rhythm guitar right, open power chords', 'second take, pan R'),
    ('gtrR-pm', 4, 28, 'rhythm guitar right, palm mutes', 'same chain as gtrR'),
    ('lead', 5, 29, 'lead guitar', 'lead tone, delay + plate'),
    ('lead2', 6, 29, 'harmony guitar (diatonic thirds below the lead)', 'lead tone, panned opposite'),
    ('lead-clean', 7, 27, 'clean lead (opening theme)', 'clean guitar, chorus + hall'),
    ('clean', 8, 27, 'clean arpeggios', 'clean guitar, chorus + hall'),
    ('choir', 10, 52, 'choir aahs (SATB pad and augmented theme)', 'VCSL choir'),
    ('organ', 11, 19, 'church organ', 'VCSL organ'),
    ('brass', 12, 61, 'brass section (answers, anthem, stabs)', 'VCSL brass'),
    ('strings', 13, 48, 'string ensemble pad', 'VCSL strings'),
    ('timpani', 14, 47, 'timpani', 'VCSL timpani'),
]
PART = {name: (ch, prog) for name, ch, prog, _, _ in PARTS}
RANGES = {'bass': (28, 60), 'gtrL': (40, 79), 'gtrR': (40, 79), 'gtrL-pm': (40, 74), 'gtrR-pm': (40, 74),
          'lead': (59, 92), 'lead2': (55, 89), 'lead-clean': (59, 88), 'clean': (52, 84),
          'choir': (55, 84), 'organ': (36, 84), 'brass': (52, 84), 'strings': (55, 91), 'timpani': (38, 55)}
# Humanise in ticks and velocity, per part; double-tracked guitars differ.
HUMAN = {'drums': (4, 4), 'bass': (6, 5), 'gtrL': (8, 5), 'gtrL-pm': (8, 5), 'gtrR': (10, 6), 'gtrR-pm': (10, 6),
         'lead': (10, 6), 'lead2': (12, 6), 'lead-clean': (12, 6), 'clean': (12, 7), 'choir': (16, 4),
         'organ': (0, 0), 'brass': (12, 6), 'strings': (16, 4), 'timpani': (8, 6)}
SEED = 'l3-ember-moon-v1'


def humanised():
    out = []
    for part, _, _, _, _ in PARTS:
        rng = random.Random(f'{SEED}:{part}')
        jt, jv = HUMAN[part]
        evs = sorted((e for e in EV if e[4] == part), key=lambda e: (e[0], e[2]))
        for b, d, q, v, _ in evs:
            t0 = round(b * PPQ)
            # Downbeats stay tight so the bar grid can be sliced cleanly.
            j = 0 if (t0 % (4 * PPQ) == 0) else rng.randint(-jt, jt)
            t0 = max(0, t0 + j)
            t1 = max(t0 + 10, round((b + d) * PPQ) + j)
            vel = max(1, min(127, v + (rng.randint(-jv, jv) if jv else 0)))
            out.append((t0, t1, q, vel, part))
    return out


def dedupe(notes):
    """No overlapping notes of the same pitch on a part: trim the earlier one."""
    out = []
    last = {}
    for n in sorted(notes, key=lambda n: (n[4], n[2], n[0], -n[1])):
        key = (n[4], n[2])
        if key in last:
            prev = out[last[key]]
            if n[0] == prev[0]:   # exact duplicate onset: keep the louder
                if n[3] > prev[3]:
                    out[last[key]] = n
                continue
            if prev[1] > n[0]:
                out[last[key]] = (prev[0], max(prev[0] + 5, n[0] - 2), prev[2], prev[3], prev[4])
        last[key] = len(out)
        out.append(n)
    return out


def vlq(n):
    data = [n & 127]
    while n >> 7:
        n >>= 7
        data.insert(0, (n & 127) | 128)
    return bytes(data)


def track(events, end_tick):
    events = sorted(events, key=lambda e: (e[0], e[1]))
    payload, prev = b'', 0
    for tick, _order, data in events:
        payload += vlq(tick - prev) + data
        prev = tick
    payload += vlq(max(0, end_tick - prev)) + b'\xff\x2f\x00'
    return b'MTrk' + struct.pack('>I', len(payload)) + payload


def meta_text(kind, text):
    raw = text.encode('utf-8')
    return bytes([0xff, kind]) + vlq(len(raw)) + raw


def conductor(end_tick):
    tempo = round(60_000_000 / BPM)
    ev = [(0, 0, meta_text(0x03, 'conductor: L3 Ember Moon')),
          (0, 1, bytes([0xff, 0x51, 3]) + tempo.to_bytes(3, 'big')),
          (0, 2, bytes([0xff, 0x58, 4, 4, 2, 24, 8])),
          (0, 3, bytes([0xff, 0x59, 2, 1, 1]))]          # 1 sharp, minor: E minor
    for name, bar, bars in SECTIONS:
        ev.append((bar * 4 * PPQ, 4, meta_text(0x06, f'{name} (bars {bar + 1}-{bar + bars})')))
    for bar, text in BLOCKS:
        ev.append((bar * 4 * PPQ, 5, meta_text(0x01, f'bar {bar + 1}: {text}')))
    return track(ev, end_tick)


def part_track(name, notes, end_tick):
    ch, prog = PART[name]
    ev = [(0, 0, meta_text(0x03, name))]
    if ch != 9:
        ev.append((0, 1, bytes([0xc0 | ch, prog])))
    # Note-offs sort before note-ons at the same tick.
    for t0, t1, q, v, part in notes:
        if part != name:
            continue
        ev.append((t0, 3, bytes([0x90 | ch, q, v])))
        ev.append((t1, 2, bytes([0x80 | ch, q, 0])))
    return track(ev, end_tick)


def smf(tracks):
    return b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), PPQ) + b''.join(tracks)


def check(notes):
    end = BARS * 4 * PPQ
    problems = []
    for t0, t1, q, v, part in notes:
        if not (0 <= t0 < end and t1 <= end + 4 * PPQ):
            problems.append(f'{part}: note at tick {t0} outside 96 bars')
        lo, hi = RANGES.get(part, (0, 127))
        if part != 'drums' and not lo <= q <= hi:
            problems.append(f'{part}: pitch {q} outside {lo}-{hi} at bar {t0 // (4 * PPQ) + 1}')
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, default=ROOT / 'art/music/scores/l3-ember-moon')
    args = ap.parse_args()
    compose()
    notes = dedupe(humanised())
    problems = check(notes)
    if problems:
        print('\n'.join(problems[:40]), file=sys.stderr)
        sys.exit(1)
    end_tick = BARS * 4 * PPQ + 4 * PPQ  # one bar of ring-out after bar 96 for the tails
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / 'parts').mkdir(exist_ok=True)
    full = smf([conductor(end_tick)] + [part_track(n, notes, end_tick) for n, *_ in PARTS])
    (args.out / 'full.mid').write_bytes(full)
    files = {'full.mid': hashlib.sha256(full).hexdigest()}
    parts_meta = []
    for name, ch, prog, role, hint in PARTS:
        data = smf([conductor(end_tick), part_track(name, notes, end_tick)])
        rel = f'parts/{name}.mid'
        (args.out / rel).write_bytes(data)
        files[rel] = hashlib.sha256(data).hexdigest()
        mine = [n for n in notes if n[4] == name]
        bars_used = sorted({n[0] // (4 * PPQ) for n in mine})
        parts_meta.append({'part': name, 'channel': ch + 1, 'gm_program': prog + 1, 'role': role,
                           'render_hint': hint, 'notes': len(mine),
                           'pitch_range': [min(n[2] for n in mine), max(n[2] for n in mine)] if mine else None,
                           'bars_playing': len(bars_used), 'file': rel})
    chords = [' '.join(f'{c}' for c, _ in CHORDS[b]) for b in range(BARS)]
    meta = {
        'schema': 'demon-attack.score/v1', 'level': LEVEL, 'name': 'Ember Moon', 'key': 'E minor',
        'bpm': BPM, 'time_signature': '4/4', 'bars': BARS, 'bar_samples': BAR_SAMPLES, 'sample_rate': SR,
        'samples': BARS * BAR_SAMPLES, 'seconds': BARS * BAR_SAMPLES / SR, 'ppq': PPQ,
        'ring_out_bars': 1, 'humanise_seed': SEED,
        'sections': [{'id': s, 'first_bar': b + 1, 'bars': n} for s, b, n in SECTIONS],
        'rehearsal_marks': [{'bar': b + 1, 'text': t} for b, t in BLOCKS],
        'chords_per_bar': chords,
        'parts': parts_meta, 'files': files,
        'source': 'tools/music_motifs.py (L3 riff, hook), art/music/campaign.json (theme, sections), '
                  'tools/score_l3.py (arrangement)',
        'notes': 'Power chords are written as notes (root, fifth, octave; palm mutes root+fifth on their own '
                 'channel). Downbeats are not humanised so bars slice cleanly. Bar 96 holds G on top for the '
                 'L3->L4 bridge pivot (Em -> G -> G7 -> Cm).',
    }
    (args.out / 'score.json').write_text(json.dumps(meta, indent=2) + '\n')
    total = len(notes)
    print(f'{args.out}: 96 bars, {len(PARTS)} parts, {total} notes, {meta["seconds"]:.3f} s at {BPM:g} BPM')


if __name__ == '__main__':
    main()
