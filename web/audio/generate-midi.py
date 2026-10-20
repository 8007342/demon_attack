"""Compose original Standard MIDI Format 0 cues; no third party music/assets."""
from pathlib import Path
import struct
OUT = Path(__file__).parent / 'midi'
OUT.mkdir(exist_ok=True)
PPQ = 96

def vlq(number):
    data = [number & 127]
    while number >> 7:
        number >>= 7
        data.insert(0, (number & 127) | 128)
    return bytes(data)

def write(name, notes, length=32):
    events = [(0, bytes([0xff, 0x51, 3, 7, 0xa1, 0x20]))]  # 120 BPM: shared transition grid
    for beat, duration, pitch, velocity, channel in notes:
        events.extend([(round(beat * PPQ), bytes([0x90 | channel, pitch, velocity])), (round((beat + duration) * PPQ), bytes([0x80 | channel, pitch, 0]))])
    events.sort(key=lambda event: event[0])
    payload, previous = b'', 0
    for tick, event in events:
        payload += vlq(tick - previous) + event
        previous = tick
    payload += vlq(max(0, length * PPQ - previous)) + b'\xff\x2f\x00'
    (OUT / f'{name}.mid').write_bytes(b'MThd' + struct.pack('>IHHH', 6, 0, 1, PPQ) + b'MTrk' + struct.pack('>I', len(payload)) + payload)

for level in range(1, 5):
    notes = []
    roots = [40, 40, 43, 38, 40, 46, 43, 38]
    intervals = [0, 7, 12, 15, 12, 7, 6, 3]
    for bar, root in enumerate(roots):
        for step in range(4):
            notes.append((bar*4 + step, .65, root-12, 60, 1))
        for step in range(4 + level*2):
            beat = bar*4 + step * 4/(4 + level*2)
            notes.append((beat, .19, root + 12 + intervals[(step + bar) % 8], 45 + level*5, 0))
        if level > 1:
            for step in range(8): notes.append((bar*4 + step*.5, .08, 42 if step%2 else 36, 35, 9))
    write(f'level-{level}', notes)
for phase in range(1, 5):
    for cycle in range(2):
        notes = []
        for bar in range(8):
            root = [33, 33, 34, 30, 33, 36, 34, 30][bar]
            pulse_steps = 16 if phase == 4 else 8
            for step in range(pulse_steps):
                beat = bar*4 + step*4/pulse_steps
                notes.append((beat, .18 if phase == 4 else .28, root + (12 if step%2 else 0), 95 if phase == 4 else 85, 1))
                notes.append((beat, .08 if phase == 4 else .12, 36 if step%2==0 else 42, 75 if phase == 4 else 65, 9))
            for step in range(phase*4 + cycle*4):
                notes.append((bar*4 + step*4/(phase*4+cycle*4), .12, root+24+[0, 1, 7, 12, 6, 13, 7, 1][step%8], 65 + phase*5, 0))
            notes.append((bar*4, 3.7, root+12, 30, 2))
        write(f'boss-{phase}-{cycle}', notes)
write('menu', [(beat, 1.6, 52 + [0,7,12,15,12,7,3,7][i%8], 36, 2) for i, beat in enumerate(range(0,32,2))])
write('victory', [(i*.5, .45, 60 + interval, 90, 0) for i, interval in enumerate([0,4,7,12,7,12,16,19])] + [(4,3.8,n,70,2) for n in [48,60,64,67,72]], 8)
write('gameover', [(i, .9, n, 65, 2) for i,n in enumerate([55,54,51,48])] + [(4,3.8,n,45,2) for n in [36,48,51,54]], 8)
# A distinct level-clear phrase celebrates regular sectors without using the
# longer carrier finale. The last bar can repeat while a cutscene finishes.
write('levelclear', [(i*.5, .4, 67 + interval, 84, 0) for i, interval in enumerate([0, 4, 7, 12, 11, 7, 4, 12])] + [(4, 3.9, n, 62, 2) for n in [48, 55, 60, 64, 67]], 8)
travel_notes = []
for bar, chord in enumerate([[48,55,62], [52,59,66], [45,52,60], [50,57,64]]):
    for pitch in chord:
        travel_notes.append((bar*4, 3.95, pitch, 42, 2))
    for step in range(8):
        travel_notes.append((bar*4 + step*.5, .35, chord[step%3]+12, 36 + step*2, 0))
    travel_notes.append((bar*4, 3.8, chord[0]-12, 45, 1))
write('travel', travel_notes, 16)
