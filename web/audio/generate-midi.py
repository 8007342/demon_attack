"""Compose the original Standard MIDI Format 0 fallback cues from the per-level
motifs in tools/music_motifs.py (the same notes the recorded cues are
re-performed from); no third-party music or assets.

Run: python3 web/audio/generate-midi.py
"""
from pathlib import Path
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))
import music_motifs as motifs  # noqa: E402

OUT = Path(__file__).parent / 'midi'
OUT.mkdir(exist_ok=True)
PPQ = 96
# The fallback synthesizer voices channel 9 as percussion, 1 as sawtooth,
# 2 as sine and the rest as square waves.
CHANNEL = {'bass': 1, 'gtr': 1, 'mute': 1, 'chord': 1, 'chordm': 1, 'trem': 1, 'clean': 2,
           'lead': 0, 'lead2': 0, 'brass': 0, 'choir': 2, 'organ': 2, 'bell': 2, 'pad': 2, 'strings': 2, 'vocalise': 0}
DRUMS = {'kick': 36, 'snare': 38, 'snareroll': 38, 'hat': 42, 'ohat': 46, 'crash': 49, 'ride': 51, 'china': 52, 'tom': 45, 'timp': 41, 'hey': 39}
# Keep the fallback light: only the parts that carry the motif and the pulse.
SKIP = {'hat', 'ohat', 'ride', 'china', 'crash', 'choir', 'organ', 'pad', 'lead2', 'strings'}


def vlq(number):
    data = [number & 127]
    while number >> 7:
        number >>= 7
        data.insert(0, (number & 127) | 128)
    return bytes(data)


def write(name, notes, length=32, bpm=120.0):
    # Tempo meta: microseconds per quarter note at the cue's own tempo (each
    # level has its own; marches and menu 120). The browser fallback schedules
    # by beats on the cue's grid; the meta keeps the files right elsewhere.
    tempo = round(60_000_000 / bpm)
    events = [(0, bytes([0xff, 0x51, 3]) + tempo.to_bytes(3, 'big'))]
    for beat, duration, pitch, velocity, channel in notes:
        events.extend([(round(beat * PPQ), bytes([0x90 | channel, pitch, velocity])), (round((beat + duration) * PPQ), bytes([0x80 | channel, pitch, 0]))])
    events.sort(key=lambda event: (event[0], event[1][0] & 0xf0 == 0x90))
    payload, previous = b'', 0
    for tick, event in events:
        payload += vlq(tick - previous) + event
        previous = tick
    payload += vlq(max(0, length * PPQ - previous)) + b'\xff\x2f\x00'
    (OUT / f'{name}.mid').write_bytes(b'MThd' + struct.pack('>IHHH', 6, 0, 1, PPQ) + b'MTrk' + struct.pack('>I', len(payload)) + payload)


def convert(events):
    notes = []
    for beat, duration, pitch, velocity, inst in events:
        if inst in SKIP:
            continue
        if inst in DRUMS:
            notes.append((beat, min(duration, .12), DRUMS[inst], min(127, velocity), 9))
        else:
            notes.append((beat, duration, pitch, min(127, velocity), CHANNEL[inst]))
    return notes


names = [f'l{level}-{part}' for level in range(1, 6) for part in ('t1', 't2', 't3', 't4', 'intro', 'outro')]
names += ['levelclear', 'victory', 'finale', 'levelclear-fleet', 'finale-fleet', 'alienwin']
for name in names:
    events, beats = motifs.cue_events(name)
    write(name, convert(events), beats, motifs.bpm_of(name))
write('menu', [(beat, 1.6, 52 + [0, 7, 12, 15, 12, 7, 3, 7][i % 8], 36, 2) for i, beat in enumerate(range(0, 32, 2))])
# The cackle's fallback: falling staccato "ha" figures.
write('cackle', [(i * .4, .18, 76 - 2 * i, 90, 0) for i in range(9)] + [(3.6, 1.5, 58, 90, 0), (0, 3.5, 40, 70, 1)], 8)
