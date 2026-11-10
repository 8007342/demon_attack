"""Original per-level musical motifs for Demon Attack, as note events.

One source of truth for three consumers:
  * web/audio/generate-midi.py writes the MIDI fallback scores from it,
  * tools/music_guide.py renders it to guide audio that ACE-Step 1.5 re-performs
    (audio-to-audio), so every tier, intro and outro of a level shares the motif,
  * tools/music_guide.py also renders the per-level accent sprites from it.

All riffs, hooks and progressions are written for this game. None quotes or
imitates an existing song or band. Times are in beats of 4/4. Round 3: each
level runs at its own tempo (BPM, battle metal) with symphonic intros and
outros; the marches, alien victory and menu stay at 120 BPM. A loop is
8 bars = 32 beats.

An event is (beat, duration_beats, midi_pitch, velocity 1..127, instrument).
Instruments: kick snare hat ohat crash ride tom china | bass gtr mute chord clean
trem lead lead2 brass choir organ bell timp pad snareroll strings vocalise hey.
For gtr/mute/trem the pitch is the power-chord root (the renderer adds the
fifth and octave); chord plays a full triad given as the root with the quality
in the instrument suffix (chord, chordm).
"""
from __future__ import annotations

BEATS = 32
BARS = 8
TIERS = (1, 2, 3, 4)
ACCENTS = ('dive', 'laststand', 'hatch', 'reinforce', 'breakthrough', 'destroyed', 'gloat', 'respawn')

# Pitches (MIDI): E2 = 40, C2 = 36, F2 = 41.
N = {name: i for i, name in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}
N.update({'Db': 1, 'Eb': 3, 'Gb': 6, 'Ab': 8, 'Bb': 10})


def p(name: str) -> int:
    """'E2' -> 40, 'F#4' -> 66, 'Bb1' -> 34."""
    note, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + N[note]


def seq(text: str, start: float = 0.0, vel: int = 96, inst: str = 'lead'):
    """'E5:1 F#5:.5 G5:.5 -:1' -> events; '-' is a rest, durations in beats."""
    out, t = [], start
    for tok in text.split():
        name, dur = tok.split(':')
        dur = float(dur)
        if name != '-':
            out.append((t, dur * 0.95, p(name), vel, inst))
        t += dur
    return out


# ------------------------------------------------------------------ motifs
# Each level: key, ACE keyscale, a root per eighth note (64 per loop) for the
# rhythm riff, a lead hook over the same 8 bars, and the drum style.
MOTIFS = {
    1: {
        'name': 'Krybor', 'genre': 'punk rock', 'keyscale': 'E minor',
        'summary': 'E5-power-chord downstroke riff with a G-A push into every second bar; '
                   'progression E | E | C | D | E | E | A-G | B; shouted-melody lead hook B-B-A-G-E.',
        # Eighth-note roots, one string per bar.
        'riff': ['E2 E2 E2 E2 E2 E2 G2 A2', 'E2 E2 E2 E2 D2 D2 B1 B1',
                 'C3 C3 C3 C3 C3 C3 D3 D3', 'D3 D3 D3 D3 D3 D3 A2 G2',
                 'E2 E2 E2 E2 E2 E2 G2 A2', 'E2 E2 E2 E2 D2 D2 B1 B1',
                 'A2 A2 A2 A2 G2 G2 G2 G2', 'B1 B1 B1 B1 B1 B1 D2 D#2'],
        'hook': ('B4:1 B4:.5 A4:.5 G4:1 E4:1 '
                 'G4:.5 A4:.5 B4:1 D5:1 B4:1 '
                 'C5:1.5 B4:.5 A4:1 G4:1 '
                 'A4:1 F#4:1 D4:2 '
                 'B4:1 B4:.5 A4:.5 G4:1 E4:1 '
                 'G4:.5 A4:.5 B4:1 D5:1 E5:1 '
                 'E5:1 D5:1 B4:1 G4:1 '
                 'F#4:2 B4:1.5 D#5:.5'),
        'drums': 'punk',
        'chord': 'gtr',
    },
    2: {
        'name': 'Ringfall', 'genre': 'melodic rock', 'keyscale': 'D major',
        'summary': 'Syncopated open-chord riff over D | F#m | G | A | Bm | G | Em | A; '
                   'soaring lead hook A-F#-A, C#-B, rising to F#5 in the second half.',
        'riff': ['D2 D2 D2 D2 D2 D2 D2 E2', 'F#2 F#2 F#2 F#2 F#2 F#2 F#2 F#2',
                 'G2 G2 G2 G2 G2 G2 G2 G2', 'A2 A2 A2 A2 A2 A2 A2 A2',
                 'B1 B1 B1 B1 B1 B1 B1 B1', 'G2 G2 G2 G2 G2 G2 G2 G2',
                 'E2 E2 E2 E2 E2 E2 E2 E2', 'A2 A2 A2 A2 A2 A2 C#3 C#3'],
        'quality': ['', 'm', '', '', 'm', '', 'm', ''],
        'hook': ('A4:2 F#4:1 A4:1 '
                 'C#5:3 B4:1 '
                 'B4:1 D5:1 B4:1 G4:1 '
                 'A4:4 '
                 'F#5:2 E5:1 D5:1 '
                 'D5:2 B4:1 D5:1 '
                 'E5:1 G5:1 F#5:1 E5:1 '
                 'C#5:2 E5:2'),
        'drums': 'rock',
        'chord': 'chord',
    },
    3: {
        'name': 'Ember Moon', 'genre': 'heavy metal', 'keyscale': 'E minor',
        'summary': 'Galloping E pedal riff (eighth + two sixteenths) with a Phrygian F; '
                   'E | E | C-D | E | E | E | F-G | A-B; twin-guitar hook E-F#-G-B in thirds.',
        'riff': ['E2 E2 E2 E2 E2 E2 E2 E2', 'E2 E2 E2 E2 F2 F2 G2 G2',
                 'C3 C3 C3 C3 D3 D3 D3 D3', 'E2 E2 E2 E2 E2 E2 F2 E2',
                 'E2 E2 E2 E2 E2 E2 E2 E2', 'E2 E2 E2 E2 F2 F2 G2 G2',
                 'F2 F2 F2 F2 G2 G2 G2 G2', 'A2 A2 A2 A2 B2 B2 B2 B2'],
        'hook': ('E5:1 F#5:.5 G5:.5 B5:1 G5:1 '
                 'A5:.5 G5:.5 F#5:1 E5:2 '
                 'G5:1 E5:1 A5:1 F#5:1 '
                 'E5:4 '
                 'E5:1 F#5:.5 G5:.5 B5:1 G5:1 '
                 'A5:.5 G5:.5 F#5:1 G5:1 B5:1 '
                 'C6:1 A5:1 D6:1 B5:1 '
                 'C6:1 B5:1 A5:1 F#5:1'),
        'harmony': -3,  # diatonic third below (approximated as -3/-4 semitones)
        'drums': 'metal',
        'chord': 'gtr',
    },
    4: {
        'name': 'The Hollow', 'genre': 'doom metal', 'keyscale': 'C minor',
        'summary': 'Slow drop-C riff C...Eb | Gb-F-C | Eb-Db | C...B, with the Gb tritone as its '
                   'dread; half-time drums; tolling bell/lead motif C-G-Ab-G, Eb-D-C.',
        'riff': ['C2 C2 C2 C2 C2 C2 Eb2 Eb2', 'Gb2 Gb2 F2 F2 C2 C2 C2 C2',
                 'Eb2 Eb2 Eb2 Eb2 Db2 Db2 Db2 Db2', 'C2 C2 C2 C2 C2 C2 B1 B1',
                 'C2 C2 C2 C2 C2 C2 Eb2 Eb2', 'Gb2 Gb2 F2 F2 Eb2 Eb2 Db2 Db2',
                 'Ab1 Ab1 Ab1 Ab1 Ab1 Ab1 Ab1 Ab1', 'G1 G1 G1 G1 G1 G1 Gb1 Gb1'],
        'hook': ('C5:2 G4:1 Ab4:1 '
                 'G4:4 '
                 'Eb5:2 D5:2 '
                 'C5:4 '
                 'C5:2 G4:1 Ab4:1 '
                 'B4:2 C5:2 '
                 'Ab4:2 Eb5:2 '
                 'D5:2 B4:2'),
        'drums': 'doom',
        'chord': 'gtr',
    },
    5: {
        'name': 'The Carrier', 'genre': 'doom-death metal', 'keyscale': 'F minor',
        'summary': 'F | F-Gb-E crawl answered by a low B tritone stab, Db-C, a chromatic Db-D-Eb-E '
                   'climb and a final F-B stab; tremolo-picked and blast-beaten in the later forms.',
        'riff': ['F2 F2 F2 F2 Gb2 Gb2 E2 E2', 'F2 F2 F2 F2 F2 F2 B1 B1',
                 'Db2 Db2 Db2 Db2 C2 C2 C2 C2', 'Gb2 Gb2 Gb2 Gb2 F2 F2 F2 F2',
                 'F2 F2 F2 F2 Gb2 Gb2 E2 E2', 'F2 F2 F2 F2 F2 F2 B1 B1',
                 'Db2 Db2 D2 D2 Eb2 Eb2 E2 E2', 'F2 F2 F2 F2 B1 B1 B1 B1'],
        'hook': ('F5:2 Gb5:1 E5:1 '
                 'F5:3 B4:1 '
                 'Db5:2 C5:2 '
                 'Gb5:2 F5:2 '
                 'Ab5:2 G5:1 Gb5:1 '
                 'F5:3 B5:1 '
                 'Db6:1 D6:1 Eb6:1 E6:1 '
                 'F6:2 B5:2'),
        'drums': 'deathdoom',
        'chord': 'gtr',
    },
}

# Victory: one fleet fanfare shared by level clear, carrier victory and the
# campaign finale (longer and bigger each time). C major, march at 120 BPM.
FANFARE = ('G4:.75 G4:.25 C5:1 E5:1 G5:1 '
           'C6:2 G5:1 E5:1 '
           'F5:1 A5:1 G5:1 E5:1 '
           'D5:2 G4:1 G4:1 '
           'C5:.75 C5:.25 E5:1 G5:1 C6:1 '
           'A5:2 G5:1 F5:1 '
           'E5:1 G5:1 D5:1 B4:1 '
           'C5:4')
FANFARE_ROOTS = ['C', 'C', 'F', 'G', 'C', 'F', 'C', 'C']  # one chord per bar (bar 7: C-G)

# Alien victory (game over): a twisted, triumphant march in E Phrygian dominant.
ALIEN = ('E5:1 F5:1 G#5:2 '
         'B5:1 C6:1 B5:1 G#5:1 '
         'A5:1.5 G#5:.5 F5:1 E5:1 '
         'F5:4 '
         'E5:1 F5:1 G#5:2 '
         'D6:1 C6:1 B5:1 C6:1 '
         'B5:1 A5:1 G#5:1 F5:1 '
         'E5:4')
ALIEN_ROOTS = ['E', 'E', 'A', 'F', 'E', 'D', 'F', 'E']


# ------------------------------------------------------------------ drums
def drums(style: str, tier: int, bars: int = BARS, fill_last: bool = True):
    """Drum events per style and intensity tier (1 calm .. 4 peril)."""
    ev = []
    for bar in range(bars):
        b0 = bar * 4
        last = fill_last and bar == bars - 1
        if bar % 4 == 0 and tier >= 2:
            ev.append((b0, 2, 49, 110, 'crash'))
        if style == 'punk':
            if tier == 1:
                for i in range(8):
                    ev.append((b0 + i * .5, .25, 42, 70, 'hat'))
                ev += [(b0, .5, 36, 100, 'kick'), (b0 + 2, .5, 36, 95, 'kick'), (b0 + 1, .5, 38, 85, 'snare'), (b0 + 3, .5, 38, 85, 'snare')]
            elif tier == 2:
                for i in range(8):
                    ev.append((b0 + i * .5, .25, 42, 85, 'hat'))
                ev += [(b0, .5, 36, 110, 'kick'), (b0 + 1.5, .5, 36, 95, 'kick'), (b0 + 2, .5, 36, 105, 'kick'),
                       (b0 + 1, .5, 38, 105, 'snare'), (b0 + 3, .5, 38, 105, 'snare')]
            else:
                # Punk "oom-pah" skank: kick on every beat, snare on every off-beat.
                for i in range(4):
                    ev.append((b0 + i, .5, 36, 112, 'kick'))
                    ev.append((b0 + i + .5, .5, 38, 108, 'snare'))
                    ev.append((b0 + i, .5, 51 if tier == 3 else 49, 80 if tier == 3 else 70, 'ride' if tier == 3 else 'crash'))
                if tier == 4:
                    for i in range(16):
                        ev.append((b0 + i * .25, .2, 42, 60, 'hat'))
        elif style == 'rock':
            hats = 8 if tier < 3 else 16
            for i in range(hats):
                ev.append((b0 + i * 4 / hats, .2, 42 if tier < 4 else 51, 70 + (10 if i % (hats // 4) == 0 else 0), 'hat' if tier < 4 else 'ride'))
            kicks = [0, 2] if tier == 1 else [0, 1.5, 2, 2.5] if tier < 4 else [0, .5, 1.5, 2, 2.5, 3.5]
            ev += [(b0 + k, .5, 36, 105, 'kick') for k in kicks]
            ev += [(b0 + s, .5, 38, 80 if tier == 1 else 108, 'snare') for s in (1, 3)]
        elif style == 'metal':
            if tier == 1:
                ev += [(b0 + i * .5, .2, 42, 70, 'hat') for i in range(8)]
                ev += [(b0, .5, 36, 100, 'kick'), (b0 + 2.5, .5, 36, 90, 'kick'), (b0 + 1, .5, 38, 90, 'snare'), (b0 + 3, .5, 38, 90, 'snare')]
            else:
                # Gallop kicks follow the riff (8th + two 16ths), double bass at tier 4.
                for i in range(4):
                    if tier == 4:
                        ev += [(b0 + i + k * .25, .2, 36, 100, 'kick') for k in range(4)]
                    else:
                        ev += [(b0 + i, .25, 36, 104, 'kick'), (b0 + i + .5, .2, 36, 78, 'kick'), (b0 + i + .75, .2, 36, 78, 'kick')]
                    ev.append((b0 + i, .4, 51 if tier < 4 else 49, 80, 'ride' if tier < 4 else 'crash'))
                ev += [(b0 + 1, .5, 38, 112, 'snare'), (b0 + 3, .5, 38, 112, 'snare')]
                if tier >= 3:
                    ev += [(b0 + i * .5 + .25, .2, 42, 60, 'hat') for i in range(8)]
        elif style == 'doom':
            if tier <= 2:
                # Half time: kick on 1, snare on 3, sparse floor toms.
                ev += [(b0, 1, 36, 112, 'kick'), (b0 + 2, 1, 38, 112 if tier == 2 else 85, 'snare')]
                ev += [(b0 + i, .5, 42 if tier == 2 else 51, 65, 'hat' if tier == 2 else 'ride') for i in range(4)]
                if tier == 1 and bar % 2 == 1:
                    ev += [(b0 + 3, .5, 41, 90, 'tom'), (b0 + 3.5, .5, 41, 80, 'tom')]
                if tier == 2:
                    ev.append((b0 + 1.5, .5, 36, 90, 'kick'))
            elif tier == 3:
                ev += [(b0, .5, 36, 112, 'kick'), (b0 + 1.5, .5, 36, 100, 'kick'), (b0 + 2.5, .5, 36, 100, 'kick'), (b0 + 1, .5, 38, 112, 'snare'), (b0 + 3, .5, 38, 112, 'snare')]
                ev += [(b0 + i, .6, 51, 75, 'ride') for i in range(4)]
            else:
                ev += [(b0 + k * .25, .2, 36, 100, 'kick') for k in range(16)]
                ev += [(b0 + 1, .5, 38, 115, 'snare'), (b0 + 3, .5, 38, 115, 'snare')]
                ev += [(b0 + i, .6, 49 if i % 2 == 0 else 52, 85, 'crash' if i % 2 == 0 else 'china') for i in range(4)]
        elif style == 'deathdoom':
            if tier == 1:
                ev += [(b0, 1, 36, 115, 'kick'), (b0 + 2, 1, 38, 112, 'snare'), (b0 + 2, 1, 36, 100, 'kick')]
                ev += [(b0 + i, .6, 51, 70, 'ride') for i in range(4)]
                if bar % 2 == 1:
                    ev += [(b0 + 3 + k * .25, .25, 45 - 2 * k, 95, 'tom') for k in range(4)]
            elif tier == 2:
                ev += [(b0 + k * .5, .4, 36, 108, 'kick') for k in range(8)]
                ev += [(b0 + 1, .5, 38, 115, 'snare'), (b0 + 3, .5, 38, 115, 'snare')]
                ev += [(b0 + i, .6, 52, 80, 'china') for i in range(4)]
            elif tier == 3:
                ev += [(b0 + k * .25, .2, 36, 102, 'kick') for k in range(16)]
                ev += [(b0 + 1, .5, 38, 118, 'snare'), (b0 + 3, .5, 38, 118, 'snare')]
                ev += [(b0 + i * .5, .4, 51, 75, 'ride') for i in range(8)]
            else:
                # Blast beat: kick and snare alternate on sixteenths with the ride.
                for k in range(16):
                    ev.append((b0 + k * .25, .2, 36 if k % 2 == 0 else 38, 105, 'kick' if k % 2 == 0 else 'snare'))
                    ev.append((b0 + k * .25, .2, 51, 70, 'ride'))
                ev += [(b0 + i, .8, 49, 95, 'crash') for i in (0, 2)]
        elif style == 'march':
            # Bass drum on every beat, snare drags and rolls, cymbal crashes.
            ev += [(b0 + i, .5, 36, 100, 'kick') for i in range(4)]
            ev += [(b0 + 1, .4, 38, 100, 'snare'), (b0 + 3, .4, 38, 100, 'snare'),
                   (b0 + 2.75, .2, 38, 75, 'snare'), (b0 + 3.5, .25, 38, 80, 'snare')]
            if bar % 2 == 0:
                ev.append((b0, 2, 49, 105, 'crash'))
        if last and style != 'march' and tier >= 2:
            # Turnaround fill on beat 4.
            ev = [e for e in ev if not (e[0] >= b0 + 3 and e[4] in ('snare', 'hat', 'ride', 'tom'))]
            ev += [(b0 + 3 + k * .25, .25, (38, 45, 43, 41)[k], 100 + 4 * k, 'snare' if k == 0 else 'tom') for k in range(4)]
    return ev


def snare_roll(start: float, beats: float, vel0: int = 50, vel1: int = 115):
    steps = int(beats * 8)
    return [(start + i / 8, .12, 38, int(vel0 + (vel1 - vel0) * i / max(1, steps - 1)), 'snareroll') for i in range(steps)]


# ------------------------------------------------------------------ parts
def riff_roots(level: int):
    roots = []
    for bar in MOTIFS[level]['riff']:
        roots += [p(n) for n in bar.split()]
    return roots  # 64 eighth-note roots


def bar_roots(level: int):
    """The first riff root of every bar: the progression."""
    return [p(bar.split()[0]) for bar in MOTIFS[level]['riff']]


def rhythm(level: int, tier: int, bars: int = BARS):
    m = MOTIFS[level]
    roots = riff_roots(level)
    ev = []
    style = m['drums']
    inst = m['chord']
    for i in range(bars * 8):
        r = roots[i % 64]
        t = i * .5
        bar = (i // 8) % BARS
        accent = i % 8 == 0
        if style == 'punk':
            # Downstroked eighths; tier 1 palm-muted roots, tier 2+ open chords.
            ev.append((t, .45, r, 110 if accent else 96, 'mute' if tier == 1 else 'gtr'))
        elif style == 'rock':
            q = m['quality'][bar]
            if tier == 1:
                # Arpeggiated chord: root, fifth, octave, third.
                arp = [0, 7, 12, 16 if q == '' else 15, 12, 7, 12, 19][i % 8]
                ev.append((t, .9, r + 12 + arp, 80, 'clean'))
            else:
                # Syncopated chord pushes: 1, 2&, 3, 4& with eighth chugs between.
                pos = i % 8
                if pos in (0, 3, 4, 7):
                    ev.append((t, 1.4 if pos in (0, 4) else .45, r, 112 if pos in (0, 4) else 100, 'chord' + q))
                else:
                    ev.append((t, .4, r, 85, 'mute'))
        elif style == 'metal':
            if tier == 1:
                ev.append((t, .4, r, 90 if accent else 80, 'mute'))
            else:
                # Gallop: eighth + two sixteenths on each beat.
                if i % 2 == 0:
                    ev += [(t, .45, r, 115 if accent else 108, 'gtr'), (t + .5, .2, roots[(i + 1) % 64], 96, 'mute'), (t + .75, .2, roots[(i + 1) % 64], 96, 'mute')]
        elif style == 'doom':
            # Notes sustain until the riff moves.
            if i % 2 == 0 and (i == 0 or roots[i % 64] != roots[(i - 1) % 64] or i % 8 == 0):
                j = i + 1
                while j < bars * 8 and roots[j % 64] == r and j % 8 != 0:
                    j += 1
                dur = (j - i) * .5
                if tier >= 4:
                    ev.append((t, dur, r, 115, 'trem'))
                else:
                    ev.append((t, dur * .98, r, 112, 'gtr'))
        elif style == 'deathdoom':
            if i % 2 == 0 and (i == 0 or roots[i % 64] != roots[(i - 1) % 64] or i % 8 == 0):
                j = i + 1
                while j < bars * 8 and roots[j % 64] == r and j % 8 != 0:
                    j += 1
                dur = (j - i) * .5
                ev.append((t, dur * .98, r, 115, 'trem' if tier >= 3 else 'gtr'))
    return ev


def bass(level: int, tier: int, bars: int = BARS):
    roots = riff_roots(level)
    style = MOTIFS[level]['drums']
    ev = []
    for i in range(bars * 8):
        r = roots[i % 64] - 12 if roots[i % 64] >= 40 else roots[i % 64]
        t = i * .5
        if style in ('doom', 'deathdoom') and tier < 3:
            if i % 4 == 0:
                ev.append((t, 1.9, r, 105, 'bass'))
        elif style == 'rock' and tier == 1:
            if i % 2 == 0:
                ev.append((t, .9, r, 95, 'bass'))
        else:
            ev.append((t, .45, r, 100 if i % 2 == 0 else 90, 'bass'))
    return ev


def hook(level: int, tier: int, bars: int = BARS, inst: str | None = None):
    m = MOTIFS[level]
    ev = [e for e in seq(m['hook'], inst=inst or 'lead', vel=100) if e[0] < bars * 4]
    if tier >= 4 and m.get('harmony'):
        ev += [(b, d, pitch + (m['harmony'] if (pitch % 12) in (4, 7, 11) else m['harmony'] - 1), v - 10, 'lead2') for b, d, pitch, v, _ in ev]
    elif tier >= 4:
        ev += [(b, d, pitch - 12, v - 15, 'lead2') for b, d, pitch, v, _ in ev]
    return ev


def pads(level: int, tier: int, bars: int = BARS):
    """Choir/organ/bell colour for the darker levels."""
    style = MOTIFS[level]['drums']
    ev = []
    roots = bar_roots(level)
    for bar in range(bars):
        r = roots[bar % BARS] + 24
        b0 = bar * 4
        if style == 'doom':
            if tier == 1:
                pass
            else:
                ev += [(b0, 3.9, r, 70, 'organ'), (b0, 3.9, r + 3, 60, 'organ'), (b0, 3.9, r + 7, 60, 'organ')]
            if tier >= 3:
                ev += [(b0, 3.9, r + 12, 70, 'choir'), (b0, 3.9, r + 15, 60, 'choir')]
        elif style == 'deathdoom':
            ev += [(b0, 3.9, r + 12, 75, 'choir'), (b0, 3.9, r + 15, 65, 'choir'), (b0, 3.9, r + 19 if bar % 2 else r + 18, 60, 'choir')]
            if tier >= 2:
                ev += [(b0, 3.9, r, 70, 'organ'), (b0, 3.9, r + 6 if bar % 2 else r + 7, 55, 'organ')]
            if bar % 2 == 0:
                ev.append((b0, 4, r + 24, 80, 'bell'))
    return ev


# ------------------------------------------------------------------ round 3: battle metal
# Per-level tempo (BPM). Each level's cues (intro, tiers, outro, accents) run
# on that level's own grid; the marches, alien victory, cackle and menu keep 120.
BPM_NOMINAL = {1: 170, 2: 160, 3: 180, 4: 150, 5: 190}
# Every cue is whole bars, so a level's grid is defined by an integer number
# of samples per bar at 48 kHz; the exact tempo follows from it (L1 169.996,
# L5 189.999 BPM; the others are exact). Loops then wrap sample-exactly on the
# same grid the player schedules (web/audio/demon-audio.js uses these values).
BAR_SAMPLES = {lvl: round(4 * 60 * 48000 / bpm) for lvl, bpm in BPM_NOMINAL.items()}
BPM = {lvl: 4 * 60 * 48000 / bar for lvl, bar in BAR_SAMPLES.items()}

# Drum/arrangement style per level (round 3).
BATTLE = {1: 'battlepunk', 2: 'powermetal', 3: 'battle', 4: 'doombattle', 5: 'blackened'}


def bpm_of(name: str) -> float:
    """Exact tempo of a cue: the level's for l<n>-*, 120 for everything else."""
    if name.startswith('l') and len(name) > 2 and name[1].isdigit() and name[2] == '-':
        return BPM[int(name[1])]
    return 120


def kick16(b0, vel=100):
    return [(b0 + k * .25, .15, 36, vel - (0 if k % 4 == 0 else 12), 'kick') for k in range(16)]


def battle_drums(level: int, tier: int, bars: int = BARS, fill_last: bool = True):
    """Battle/power-metal drums: every tier drives; density rises with the tier."""
    style = BATTLE[level]
    ev = []
    for bar in range(bars):
        b0 = bar * 4
        last = fill_last and bar == bars - 1
        ev.append((b0, 2, 49, 115, 'crash'))
        if style == 'battlepunk':
            if tier <= 2:
                # Fast skank: kick on every beat, snare on every off-beat.
                for i in range(4):
                    ev += [(b0 + i, .3, 36, 115, 'kick'), (b0 + i + .5, .3, 38, 112, 'snare')]
                ev += [(b0 + i * .5, .2, 42, 75, 'hat') for i in range(8)]
                if tier == 2:
                    ev += [(b0 + i + .75, .15, 36, 95, 'kick') for i in range(4)]
            elif tier == 3:
                ev += kick16(b0, 108)
                ev += [(b0 + s, .3, 38, 118, 'snare') for s in (1, 3)]
                ev += [(b0 + i * .5, .3, 49 if i % 2 == 0 else 51, 85, 'crash' if i % 2 == 0 else 'ride') for i in range(8)]
            else:
                for k in range(16):  # blast beat
                    ev.append((b0 + k * .25, .15, 36 if k % 2 == 0 else 38, 110, 'kick' if k % 2 == 0 else 'snare'))
                ev += [(b0 + i, .6, 49, 100, 'crash') for i in range(4)]
        elif style == 'powermetal':
            if tier == 1:
                ev += [(b0 + k * .5, .2, 36, 108, 'kick') for k in range(8)]
            else:
                ev += kick16(b0, 110)
            ev += [(b0 + s, .3, 38, 118, 'snare') for s in (1, 3)]
            ev += [(b0 + i * .5, .2, 42 if tier < 3 else 51, 80, 'hat' if tier < 3 else 'ride') for i in range(8)]
            if tier >= 3:
                ev += [(b0 + 2, 1, 49, 105, 'crash')]
        elif style == 'battle':
            if tier <= 3:
                # Gallop kicks under the gallop riff: eighth + two sixteenths per beat.
                for i in range(4):
                    ev += [(b0 + i, .2, 36, 115, 'kick'), (b0 + i + .5, .15, 36, 100, 'kick'), (b0 + i + .75, .15, 36, 100, 'kick')]
            else:
                ev += kick16(b0, 112)
            ev += [(b0 + s, .3, 38, 120, 'snare') for s in (1, 3)]
            ev += [(b0 + i, .5, 49 if tier >= 2 else 51, 90, 'crash' if tier >= 2 else 'ride') for i in range(4)]
            if bar % 2 == 1:  # war-march tom answer
                ev += [(b0 + 3 + k * .25, .2, (45, 45, 43, 41)[k], 112, 'tom') for k in range(4)]
        elif style == 'doombattle':
            if tier == 1:
                # War march: floor-tom eighths, snare on 3, kick on 1.
                ev += [(b0 + k * .5, .3, 41, 100 + (15 if k % 2 == 0 else 0), 'tom') for k in range(8)]
                ev += [(b0, .5, 36, 120, 'kick'), (b0 + 2, .5, 38, 120, 'snare')]
            elif tier == 2:
                ev += kick16(b0, 105)
                ev += [(b0 + 2, .5, 38, 120, 'snare')]
                ev += [(b0 + k * .5, .3, 41, 95, 'tom') for k in range(8)]
            else:
                ev += kick16(b0, 112)
                ev += [(b0 + s, .3, 38, 120, 'snare') for s in (1, 3)]
                ev += [(b0 + i * .5, .3, 49 if i % 2 == 0 else 52, 90, 'crash' if i % 2 == 0 else 'china') for i in range(8 if tier == 4 else 4)]
        elif style == 'blackened':
            if tier == 1:
                ev += [(b0 + k * .5, .3, 41, 110, 'tom') for k in range(8)]
                ev += kick16(b0, 100)
                ev += [(b0 + s, .3, 38, 115, 'snare') for s in (1, 3)]
            else:
                for k in range(16):  # blast beat
                    ev.append((b0 + k * .25, .15, 36 if k % 2 == 0 else 38, 112, 'kick' if k % 2 == 0 else 'snare'))
                if tier >= 3:
                    ev += kick16(b0, 95)
                ev += [(b0 + i, .6, 49 if i % 2 == 0 else 52, 100, 'crash' if i % 2 == 0 else 'china') for i in range(4)]
        if last:
            ev = [e for e in ev if not (e[0] >= b0 + 2 and e[4] in ('snare', 'hat', 'ride', 'tom'))]
            ev += [(b0 + 2 + k * .25, .2, (38, 38, 45, 45, 43, 43, 41, 41)[k], 100 + 3 * k, 'snare' if k < 2 else 'tom') for k in range(8)]
    return ev


def battle_rhythm(level: int, tier: int, bars: int = BARS):
    """Distorted rhythm guitars on the level's riff roots, battle-metal picking."""
    style = BATTLE[level]
    roots = riff_roots(level)
    q = MOTIFS[level].get('quality', [''] * BARS)
    ev = []
    for i in range(bars * 8):
        r = roots[i % 64]
        t = i * .5
        bar = (i // 8) % BARS
        accent = i % 8 == 0
        if style == 'battlepunk':
            # Sixteenth downpicking from tier 3, eighths below.
            if tier >= 3:
                ev += [(t, .22, r, 115 if accent else 104, 'gtr'), (t + .25, .2, r, 98, 'mute')]
            else:
                ev.append((t, .45, r, 116 if accent else 106, 'gtr'))
        elif style == 'powermetal':
            if i % 2 == 0 and tier >= 2:
                ev += [(t, .45, r, 115, 'chord' + q[bar]), (t + .5, .2, r, 98, 'mute'), (t + .75, .2, r, 98, 'mute')]
            elif tier == 1:
                ev.append((t, .45, r, 112 if accent else 102, 'gtr'))
        elif style == 'battle':
            if i % 2 == 0:
                ev += [(t, .45, r, 118 if accent else 110, 'gtr'), (t + .5, .2, roots[(i + 1) % 64], 100, 'mute'), (t + .75, .2, roots[(i + 1) % 64], 100, 'mute')]
        elif style == 'doombattle':
            if tier == 1:
                if i % 4 == 0:
                    ev.append((t, 1.9, r, 118, 'gtr'))
            elif tier == 2:
                ev += [(t, .45, r, 112 if accent else 104, 'gtr')]
            else:
                ev += [(t, .22, r, 112, 'gtr' if accent else 'mute'), (t + .25, .2, r, 100, 'mute')]
        elif style == 'blackened':
            if i % 2 == 0:
                j = i + 1
                while j < bars * 8 and roots[j % 64] == r and j % 8 != 0 and j - i < 4:
                    j += 1
                ev.append((t, (j - i) * .5 * .98, r, 118, 'trem'))
    return ev


def battle_bass(level: int, tier: int, bars: int = BARS):
    roots = riff_roots(level)
    ev = []
    for i in range(bars * 8):
        r = roots[i % 64] - 12 if roots[i % 64] >= 40 else roots[i % 64]
        t = i * .5
        if BATTLE[level] in ('battle', 'powermetal') and tier >= 2 and i % 2 == 0:
            ev += [(t, .45, r, 105, 'bass'), (t + .5, .2, r, 95, 'bass'), (t + .75, .2, r, 95, 'bass')]
        elif BATTLE[level] in ('battle', 'powermetal') and tier >= 2:
            continue
        else:
            ev.append((t, .45, r, 105 if i % 2 == 0 else 95, 'bass'))
    return ev


def battle_lead(level: int, tier: int, bars: int = BARS):
    """The level's hook as a lead guitar; harmonised in thirds at tier 4 (and
    tier 3 for the power-metal and battle levels)."""
    ev = [e for e in seq(MOTIFS[level]['hook'], inst='lead', vel=108) if e[0] < bars * 4]
    if tier >= 4 or (tier == 3 and BATTLE[level] in ('powermetal', 'battle')):
        ev += [(b, d, pt + (-4 if pt % 12 in (4, 7, 11) else -3), v - 8, 'lead2') for b, d, pt, v, _ in ev]
    return ev


def hey_chants(level: int, tier: int, bars: int = BARS):
    """Gang shouts ("hey!") as rhythmic texture on the phrase ends."""
    ev = []
    for bar in range(bars):
        b0 = bar * 4
        if bar % 4 == 3 or (tier >= 4 and bar % 2 == 1):
            ev += [(b0 + 2, .4, 62, 115, 'hey'), (b0 + 3, .4, 62, 120, 'hey')]
    return ev


def battle_pads(level: int, tier: int, bars: int = BARS):
    """Choir/strings/organ above the band for the epic levels and peak tiers."""
    style = BATTLE[level]
    roots = bar_roots(level)
    ev = []
    for bar in range(bars):
        r = roots[bar % BARS] + 24
        b0 = bar * 4
        minor = MOTIFS[level].get('quality', ['m'] * BARS)[bar % BARS] != '' or style != 'powermetal'
        third = 3 if minor else 4
        if tier >= 4 or style in ('doombattle', 'blackened') or (style == 'powermetal' and tier >= 3):
            ev += [(b0, 3.9, r + 12, 78, 'choir'), (b0, 3.9, r + 12 + third, 70, 'choir'), (b0, 3.9, r + 19, 68, 'choir')]
        if tier >= 3 and style in ('powermetal', 'battle', 'doombattle'):
            ev += [(b0, 3.9, r, 70, 'strings'), (b0, 3.9, r + 7, 64, 'strings')]
        if style == 'blackened' and tier >= 2:
            ev += [(b0, 3.9, r, 70, 'organ'), (b0, 3.9, r + 6 if bar % 2 else r + 7, 60, 'organ')]
    return ev


def tier_events(level: int, tier: int):
    """The whole 8-bar battle loop for one intensity tier (1 is already battle music)."""
    ev = battle_drums(level, tier) + battle_rhythm(level, tier) + battle_bass(level, tier)
    if tier >= 3 or (tier == 2 and BATTLE[level] in ('powermetal', 'battle')):
        ev += battle_lead(level, tier)
    elif tier == 2:
        ev += [e for e in battle_lead(level, tier) if e[0] >= 16]
    if tier >= 2:
        ev += hey_chants(level, tier)
    ev += battle_pads(level, tier)
    return sorted(ev)


def orchestral_hit(b, root, vel=118):
    """Brass + strings stab, timpani and crash on one downbeat."""
    return [(b, .9, root + 24 + k, vel - 10, 'brass') for k in (0, 7, 12)] + \
           [(b, .5, root + 12 + k, vel - 15, 'strings') for k in (0, 7, 12, 15)] + \
           [(b, .9, root, vel, 'timp'), (b, 2, 49, vel, 'crash'), (b, .5, 36, vel, 'kick')]


def intro_events(level: int):
    """Symphonic arrival, 4 bars at the level's tempo: orchestral hits on the
    progression, choir and strings, a wordless soprano vocalise singing the
    hook in augmentation; the band enters in bar 3 and rolls into the battle.
    Loops its last bar until play begins."""
    roots = bar_roots(level)
    hook_notes = seq(MOTIFS[level]['hook'])
    ev = []
    for bar in range(4):
        r = roots[bar]
        b0 = bar * 4
        ev += orchestral_hit(b0, r)
        ev += [(b0, 3.9, r + 24 + k, 72, 'strings') for k in (0, 7, 12)]
        ev += [(b0, 3.9, r + 36 + k, 74, 'choir') for k in (0, 3, 7)]
    # Vocalise: the hook's first phrase at half speed, an octave up where needed.
    for b, d, pt, v, _ in hook_notes:
        if b < 8:
            pitch = pt if pt >= 67 else pt + 12
            ev.append((b * 2, d * 2 * .95, pitch, 92, 'vocalise'))
    # Band from bar 3: sustained chords and double kick, toms into the downbeat.
    for bar in (2, 3):
        b0 = bar * 4
        ev += [(b0, 1.9, roots[bar], 115, 'gtr'), (b0 + 2, 1.9, roots[bar], 112, 'gtr')]
        ev += kick16(b0, 100)
        ev += [(b0 + 1, .3, 38, 115, 'snare'), (b0 + 3, .3, 38, 115, 'snare')]
    ev += [(14 + k * .25, .2, (45, 45, 43, 43, 41, 41, 38, 38)[k], 105 + 2 * k, 'tom' if k < 6 else 'snare') for k in range(8)]
    ev += snare_roll(15, 1, 70, 120)
    ev += [(b, d, pt - 12 if pt >= 40 else pt, v, 'bass') for b, d, pt, v, _ in [(i * 4, 3.9, roots[i], 100, '') for i in range(4)]]
    return sorted(ev)


def outro_events(level: int):
    """Symphonic travel after the level, 4 bars at its tempo (loops): strings
    and choir on the progression, the vocalise sings the hook, half-time band."""
    roots = bar_roots(level)
    ev = []
    for bar in range(4):
        r = roots[bar]
        b0 = bar * 4
        ev += [(b0, 3.9, r + 24 + k, 76, 'strings') for k in (0, 7, 12, 15)]
        ev += [(b0, 3.9, r + 36 + k, 70, 'choir') for k in (0, 3, 7)]
        ev += [(b0, 3.9, r, 108, 'gtr'), (b0, 3.9, r - 12 if r >= 40 else r, 98, 'bass')]
        ev += [(b0, .5, 36, 112, 'kick'), (b0 + 2, .5, 38, 112, 'snare'), (b0 + 1.5, .3, 36, 95, 'kick')]
        ev += [(b0 + i * .5, .2, 51, 70, 'ride') for i in range(8)]
        if bar % 2 == 0:
            ev.append((b0, 2, 49, 105, 'crash'))
    for b, d, pt, v, _ in seq(MOTIFS[level]['hook']):
        if b < 8:
            ev.append((b * 2, d * 2 * .95, pt if pt >= 67 else pt + 12, 88, 'vocalise'))
    return sorted(ev)


def accent_events(level: int, accent: str):
    """Short accents in the level's motif and instrumentation. Same role and
    shape on every level; each sounds within ~3 beats of its slot."""
    m = MOTIFS[level]
    roots = bar_roots(level)
    tonic = roots[0]
    hook_notes = [e[2] for e in seq(m['hook'])]
    lead = 'lead'
    if accent == 'dive':
        a, b, c = hook_notes[:3]
        ev = [(0, .25, a, 112, lead), (.25, .25, b, 112, lead), (.5, .9, c + 12 if c + 12 <= 96 else c, 118, lead),
              (0, .45, tonic, 118, 'gtr'), (0, .2, 38, 112, 'snare'), (.25, .2, 38, 104, 'snare')]
    elif accent == 'laststand':
        ev = [(0, 1, tonic, 118, 'trem'), (1, 1, tonic + 1, 120, 'trem'), (1, 1.5, 49, 118, 'crash')]
        ev += snare_roll(0, 1, 60, 120)
        ev += [(1, 1, hook_notes[0] + 1, 112, lead)]
    elif accent == 'hatch':
        ev = [(0, 1.5, tonic, 120, 'gtr'), (0, 1.5, tonic + 6, 112, 'gtr'), (0, 1.8, tonic + 36, 92, 'bell'),
              (0, 1.8, tonic + 24, 84, 'choir'), (0, 1.8, tonic + 30, 78, 'choir'), (0, .5, 36, 120, 'kick'), (0, 1.5, 52, 104, 'china')]
    elif accent == 'reinforce':
        ev = [(0, .45, tonic, 118, 'gtr'), (.5, .9, roots[2], 118, 'gtr'), (0, 1, 49, 115, 'crash'), (0, .3, 36, 118, 'kick'),
              (.5, .3, 36, 115, 'kick'), (.5, .3, 38, 115, 'snare'), (1, .4, 62, 118, 'hey')]
    elif accent == 'breakthrough':
        ev = [(0, .4, tonic, 118, 'gtr'), (.5, .4, tonic + 1, 118, 'gtr'), (1, .4, tonic, 118, 'gtr'), (1.5, .9, tonic + 1, 120, 'gtr'),
              (1.5, .9, hook_notes[0] + 12 if hook_notes[0] + 12 <= 96 else hook_notes[0], 112, lead), (0, 1, 49, 112, 'crash')]
        ev += [(k * .25, .2, (45, 43, 41, 43, 45, 43)[k], 105, 'tom') for k in range(6)]
        ev += [(t, .3, 36, 115, 'kick') for t in (0, .5, 1, 1.5)]
    elif accent == 'destroyed':
        # The player's ship is hit: one low orchestral hit, then the music drops.
        ev = orchestral_hit(0, tonic - 12 if tonic >= 36 else tonic, 124)
        ev += [(0, 2.2, tonic, 124, 'gtr'), (0, 2.2, tonic - 12 if tonic >= 36 else tonic, 110, 'bass'), (0, 2, 52, 110, 'china')]
    elif accent == 'gloat':
        # Demonic gloat while the fleet regroups: low choir sliding a tritone
        # down to the tonic over a dissonant organ cluster.
        ev = [(0, 1, tonic + 30, 96, 'choir'), (1, 1.6, tonic + 24, 100, 'choir'), (0, 2.6, tonic + 12, 82, 'organ'),
              (0, 2.6, tonic + 13, 74, 'organ'), (0, 2.6, tonic + 18, 74, 'organ'), (0, .9, tonic + 6, 110, 'trem'), (1, 1.6, tonic, 116, 'trem'),
              (1, .9, tonic, 110, 'timp')]
    elif accent == 'respawn':
        # Heroic re-entry: a one-beat snare roll into a crash, the hook's first
        # three notes rising, tonic power chord to the fifth.
        a, b, c = hook_notes[:3]
        ev = snare_roll(0, 1, 60, 122)
        ev += [(1, 1.5, 49, 120, 'crash'), (1, .9, tonic, 120, 'gtr'), (2, 1, tonic + 7, 120, 'gtr'), (1, .45, 36, 120, 'kick'),
               (1, .45, a, 114, lead), (1.5, .45, b, 116, lead), (2, 1, c + 12 if c + 12 <= 96 else c, 120, lead),
               (1, 1.8, tonic + 36, 80, 'vocalise')]
    else:
        raise ValueError(accent)
    if BATTLE[level] == 'powermetal':
        ev = [(b, d, pt, v, 'chord' if i == 'gtr' else i) for b, d, pt, v, i in ev]
    return sorted(ev)


def fanfare_events(kind: str, fleet: bool = False):
    """Fleet march: levelclear = bars 1-2 (+ the C cadence), victory = bars 1-4 +
    cadence, finale = all 8 bars with choir and timpani."""
    bars = {'levelclear': 3, 'victory': 5, 'finale': 9}[kind]
    melody = seq(FANFARE, vel=110, inst='brass')
    if kind == 'levelclear':
        melody = [e for e in melody if e[0] < 8] + [(8, 3.8, p('C5'), 110, 'brass')]
        roots = ['C', 'C', 'C']
    elif kind == 'victory':
        melody = [e for e in melody if e[0] < 16] + [(16, 3.8, p('C5'), 110, 'brass')]
        roots = FANFARE_ROOTS[:4] + ['C']
    else:
        melody = melody + [(32, 3.8, p('C6'), 115, 'brass')]
        roots = FANFARE_ROOTS + ['C']
    ev = snare_roll(0, 1, 50, 100) if kind != 'levelclear' else []
    ev += melody
    ev += [(b, d, pitch - 12, v - 15, 'brass') for b, d, pitch, v, _ in melody]  # octave doubling
    ev += drums('march', 2, bars=bars)
    for bar, root in enumerate(roots):
        r = p(root + '3')
        ev += [(bar * 4, 3.9, r - 12, 100, 'bass'), (bar * 4 + 2, 1.9, r - 5, 90, 'bass')]
        ev += [(bar * 4, 3.8, r + k, 75, 'brass') for k in (0, 4, 7)]
        if kind != 'levelclear':
            ev += [(bar * 4, .9, r - 12, 100, 'timp'), (bar * 4 + 2, .9, r - 5, 90, 'timp')]
        if kind == 'finale':
            ev += [(bar * 4, 3.9, r + 12 + k, 70, 'choir') for k in (0, 4, 7)]
    ev += snare_roll((bars - 1) * 4 - 1, 1, 60, 120)
    if fleet:
        ev += fleet_layers(melody, roots, bars)
    return sorted(ev), bars * 4


def fleet_layers(melody, roots, bars):
    """The whole fleet survived: the same march, bigger. A trumpet descant a
    third/sixth above the tune, a trombone counterline, and a drum corps
    (stacked snares with rudiment flourishes, tenor drums, cymbal line)."""
    ev = []
    for b, d, pitch, v, _ in melody:
        # Descant: a diatonic third above (major third on C/F/G, minor elsewhere), up an octave on long notes.
        third = 4 if pitch % 12 in (0, 5, 7) else 3
        ev.append((b, d, pitch + third + (12 if d >= 1.9 else 0), v - 5, 'brass'))
    for bar, root in enumerate(roots):
        r = p(root + '3')
        b0 = bar * 4
        # Trombone counterline: root, fifth, sixth, fifth in half notes / quarters.
        ev += [(b0, 1.9, r - 12, 100, 'brass'), (b0 + 2, .95, r - 5, 95, 'brass'), (b0 + 3, .95, r - 3, 95, 'brass')]
        # Drum corps: sixteenth-note snare line with accents, flams on 2 and 4,
        # a paradiddle-diddle flourish into every bar, tenors answering.
        for k in range(16):
            accent = k % 4 == 0
            ev.append((b0 + k * .25, .1, 38, 105 if accent else 70, 'snareroll'))
        ev += [(b0 + 1 - .03, .05, 38, 80, 'snare'), (b0 + 3 - .03, .05, 38, 80, 'snare')]
        ev += [(b0 + 3 + k / 6, .1, 38, 85 + 5 * k, 'snareroll') for k in range(6)]  # sextuplet flourish
        ev += [(b0 + 2 + k * .5, .3, (45, 43, 41, 43)[k], 105, 'tom') for k in range(4)]
        ev += [(b0, 2, 49, 115, 'crash'), (b0 + 2, 1.5, 52, 95, 'china')]
    return ev


def alien_events():
    """Aliens win: twisted triumphant march (8 bars, loops)."""
    ev = seq(ALIEN, vel=105, inst='lead')
    ev += [(b, d, pitch - 12, v - 15, 'choir') for b, d, pitch, v, _ in seq(ALIEN)]
    ev += drums('march', 2)
    for bar, root in enumerate(ALIEN_ROOTS):
        r = p(root + '2')
        major = root == 'E'
        ev += [(bar * 4 + k * .5, .45, r, 105, 'gtr') for k in range(8)]
        ev += [(bar * 4, 3.9, r - 12 if r >= 40 else r, 100, 'bass')]
        ev += [(bar * 4, 3.9, r + 24 + k, 65, 'organ') for k in ((0, 4, 7) if major else (0, 3, 7))]
        ev += [(bar * 4, .9, r, 100, 'timp'), (bar * 4 + 2, .9, r + 7, 90, 'timp')]
    return sorted(ev)


def cue_events(name: str):
    """(events, beats) for any cue name used by the player."""
    if name.startswith('l') and '-' in name and name[1].isdigit():
        level = int(name[1])
        part = name.split('-', 1)[1]
        if part.startswith('t'):
            return tier_events(level, int(part[1])), BEATS
        if part == 'intro':
            return intro_events(level), 16
        if part == 'outro':
            return outro_events(level), 16
    if name in ('levelclear', 'victory', 'finale'):
        return fanfare_events(name)
    if name in ('levelclear-fleet', 'finale-fleet'):
        # Same bars as the base cue, so the player can switch on a bar line in place.
        return fanfare_events(name.split('-')[0], fleet=True)
    if name == 'alienwin':
        return alien_events(), BEATS
    raise KeyError(name)
