"""Original low-resolution sentinel and damage frames; standard library only.

Eight columns, ten rows. Each 128x64 cell is authored as 64x32 pixels,
then enlarged exactly 2x. No source game sprites or generated illustrations.
"""
from pathlib import Path
import math
import struct
import zlib

WIDTH, HEIGHT = 1024, 640
pixels = bytearray(WIDTH * HEIGHT * 4)
INK = '#100e2c'
VIOLET = '#a888ff'
GOLD = '#efbd57'
IVORY = '#fff5c9'
CORAL = '#ff786c'
MINT = '#39dfcc'


def dot(c, r, x, y, color):
    if not (0 <= x < 64 and 0 <= y < 32):
        return
    rgb = bytes([int(color[i:i + 2], 16) for i in (1, 3, 5)] + [255])
    for dy in range(2):
        for dx in range(2):
            offset = (((r * 32 + y) * 2 + dy) * WIDTH +
                      (c * 64 + x) * 2 + dx) * 4
            pixels[offset:offset + 4] = rgb


def box(c, r, x, y, w, h, color):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            dot(c, r, xx, yy, color)


def pair(c, r, x, y, w, h, color):
    box(c, r, x, y, w, h, color)
    box(c, r, 64 - x - w, y, w, h, color)


def polygon(c, r, points, color):
    # Fixed pixel-center rasterization, never antialiased path drawing.
    for y in range(32):
        for x in range(64):
            inside = False
            j = len(points) - 1
            for i, (xi, yi) in enumerate(points):
                xj, yj = points[j]
                if (yi > y + .5) != (yj > y + .5):
                    if x + .5 < (xj - xi) * (y + .5 - yi) / (yj - yi) + xi:
                        inside = not inside
                j = i
            if inside:
                dot(c, r, x, y, color)


def paired_poly(c, r, points, color):
    polygon(c, r, points, color)
    polygon(c, r, [(64 - x, y) for x, y in points], color)


def pixel_line(c, r, start, end, color):
    x0, y0 = start
    x1, y1 = end
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(steps + 1):
        t = i / max(1, steps)
        x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
        dot(c, r, x, y, color)
        dot(c, r, 63 - x, y, color)


# Shoulder/elbow/wrist articulation changes the direction of each feather.
# Distinct up, open, level, down, folded and recovery poses form one slow stroke.
WING_POSES = [
    ((17, 12), (3, 1)),
    ((16, 11), (2, 6)),
    ((16, 12), (2, 12)),
    ((16, 14), (5, 22)),
    ((19, 17), (10, 27)),
    ((23, 16), (18, 25)),
    ((20, 13), (10, 19)),
    ((17, 11), (4, 7)),
]


def sentinel(c, heavy=False, stance=None):
    r = int(heavy) + (6 if stance in ('charge', 'rush') else
                      8 if stance in ('warning', 'dive') else 0)
    frame = c % 4
    alert = stance is not None
    base = GOLD if heavy else CORAL if stance == 'rush' else VIOLET
    shadow = '#a36635' if heavy else '#5840a3'
    elbow, tip = WING_POSES[c % 8]
    if stance == 'warning':
        elbow = [(17, 9), (18, 8), (19, 8), (20, 10)][frame]
        tip = [(7, 2), (9, 1), (12, 2), (15, 4)][frame]
    elif stance == 'charge':
        elbow = [(15, 10), (15, 8), (16, 7), (17, 8)][frame]
        tip = [(2, 2), (3, 0), (5, 0), (6, 1)][frame]
    elif stance == 'dive':
        # Swept-back falcon wings: shoulders out, sharp wrists high above head.
        elbow = [(19, 13), (20, 12), (21, 12), (20, 13)][frame]
        tip = [(14, 2), (16, 1), (17, 2), (15, 3)][frame]
    elif stance == 'rush':
        elbow = [(23, 12), (24, 12), (24, 13), (23, 13)][frame]
        tip = [(22, 1), (23, 0), (24, 1), (23, 2)][frame]

    # A strong upper arm joins four individually articulated primary feathers.
    paired_poly(c, r, [(27, 12), (elbow[0], elbow[1] - 1),
                      (tip[0], tip[1]), (tip[0] + 1, tip[1] + 3),
                      (elbow[0] + 2, elbow[1] + 4), (27, 20)], INK)
    for tier in range(3, -1, -1):
        root = (26, 12 + tier * 2)
        joint = (elbow[0] + tier, min(27, elbow[1] + tier * 2))
        end = (min(25, tip[0] + tier * 3),
               min(29, tip[1] + tier * (4 if tip[1] < elbow[1] else 2)))
        paired_poly(c, r, [(root[0] + 1, root[1] - 1),
                          (joint[0], joint[1] - 1), (end[0], end[1] - 1),
                          (end[0], end[1] + 2), (joint[0] + 1, joint[1] + 2),
                          (root[0] + 1, root[1] + 2)], INK)
        pixel_line(c, r, root, joint, base)
        pixel_line(c, r, joint, end, base)
        pixel_line(c, r, (joint[0], joint[1] + 1),
                   (end[0] + 1, end[1] + 1), shadow)
        if heavy or stance == 'charge':
            pixel_line(c, r, end, (end[0] + 2, end[1]), IVORY)
        if alert:
            pair(c, r, joint[0], joint[1], 2, 1,
                 IVORY if frame % 2 else CORAL)

    # Horned living head, wide shoulders and a tapered feathered abdomen.
    pair(c, r, 27, 6, 2, 5, INK)
    pair(c, r, 27, 7, 1, 3, base)
    box(c, r, 28, 10, 8, 13, INK)
    box(c, r, 26, 13, 12, 7, INK)
    box(c, r, 29, 11, 6, 10, shadow)
    box(c, r, 28, 13, 8, 5, base)
    box(c, r, 30, 21, 4, 3, base)
    box(c, r, 31, 24, 2, 3, base)
    pair(c, r, 27, 20, 2, 3, base)
    pair(c, r, 28, 14, 3, 2, CORAL if alert else IVORY)
    box(c, r, 31, 17, 2, 2, INK)
    pair(c, r, 29, 19, 1, 2, IVORY)
    if heavy:
        box(c, r, 30, 8, 4, 2, GOLD)
        box(c, r, 31, 6, 2, 3, IVORY)
    if alert:
        box(c, r, 30, 21, 4, 2, IVORY if frame % 2 else CORAL)
    if stance == 'charge':
        box(c, r, 30, 8, 4, 1, CORAL)
        pair(c, r, 27, 4 + frame % 2, 1, 2, IVORY)
        pair(c, r, 28, 24, 2, 3, CORAL)
    elif stance in ('dive', 'rush'):
        # Downward beak and talons complete a predatory silhouette.
        box(c, r, 30, 17, 4, 2, IVORY)
        box(c, r, 31, 19, 2, 3, GOLD)
        pair(c, r, 27, 22, 2, 5 + frame % 2, base)
        pair(c, r, 28, 27 + frame % 2, 1, 2, IVORY)
        box(c, r, 31, 26, 2, 4, CORAL if stance == 'rush' else base)
        if stance == 'rush':
            pair(c, r, 26, 15 + frame, 1, 4, CORAL)


for heavy in (False, True):
    for c in range(8):
        sentinel(c, heavy)

# Four conspicuous segmented shield envelopes. Actual model shield durability
# selects the state; depleted shields vanish rather than implying extra health.
for c in range(4):
    extent = [29, 25, 21, 17][c]
    for tier in range(3):
        inset = tier * 3
        width = extent - inset
        y = 27 + tier
        for x in range(32 - width, 32 + width):
            if (x // 4 + tier) % 3 != 1 or c == 0:
                dot(c, 2, x, y, MINT if tier == 0 else '#147c93')
    for side in (-1, 1):
        x = 32 + side * extent
        box(c, 2, x, 20 + c, 1, 7 - c, MINT)
        box(c, 2, x - (1 if side > 0 else -1), 18 + c, 1, 3, '#147c93')
        box(c, 2, 32 + side * (extent - 2), 16 + c, 2, 2, MINT)

# Chest, upper chest, shoulders and outer pauldrons: both sentinel species wear
# meaningful visible armor, with each absorbing layer controlled by simulation.
for layer in range(4):
    c = 4 + layer
    x = [29, 28, 24, 20][layer]
    y = [18, 9, 12, 13][layer]
    w = [3, 4, 4, 4][layer]
    pair(c, 2, x, y, w, 4, INK)
    pair(c, 2, x, y, w, 1, IVORY)
    pair(c, 2, x, y + 1, w - 1, 2, GOLD)
    pair(c, 2, x + 1, y + 3, w - 2, 1, '#a36635')

# Four asymmetric rising plumes: lobe clusters, negative-space curls and
# increasingly sparse dithering replace the old round checkerboard puffs.
for c in range(4):
    for y in range(4, 28):
        rise = 27 - y
        center = 32 + round(math.sin((rise + c * 3) * .42) * (1 + rise / 6))
        radius = 2 + (rise // 6) + ((y + c) % 4 == 0)
        for x in range(center - radius, center + radius + 1):
            edge = abs(x - center)
            if y < 11 and (x * 3 + y + c * 2) % 5 < 2:
                continue
            if edge >= radius and (x + y + c) % 3 != 0:
                continue
            if rise > 12 and edge < 2 and (y + c) % 5 in (0, 1):
                continue
            color = '#302f46' if x > center else '#625b72'
            if x == center - radius + 1 and (y + c) % 3 != 0:
                color = '#888093'
            dot(c, 3, x, y, color)

# Fire tongues, each hand-shaped in vertical strips with a yellow-hot base.
for frame in range(4):
    c = frame + 4
    for x in range(-5, 6):
        height = [5, 8, 12, 7, 16, 10, 13, 8, 11, 6, 4][(x + 5 + frame) % 11]
        box(c, 3, 32 + x, 26 - height, 1, height, '#aa385c')
        box(c, 3, 32 + x, 28 - height, 1, max(1, height - 2), CORAL)
        if abs(x) < 4:
            box(c, 3, 32 + x, 23 - height // 3, 1, 4 + height // 3, GOLD)
        if abs(x) < 2:
            box(c, 3, 32 + x, 24, 1, 3, IVORY)

# Wing breakup, not a generic circular burst: horizontal ribs separate,
# fracture and become square embers across eight discrete destruction frames.
for c in range(8):
    for side in (-1, 1):
        for tier in range(4):
            for fragment in range(3):
                x = 32 + side * (6 + tier * 3 + fragment * 6 + c)
                y = 8 + tier * 3 + (c * c // 7) + (fragment + c) % 3
                length = max(1, 5 - c // 2)
                if c < 6 or (tier + fragment) % 2 == 0:
                    box(c, 4, x, y, length, 1 if c > 3 else 2,
                        [IVORY, GOLD, CORAL, '#aa385c'][min(3, c // 2)])
    if c < 4:
        box(c, 4, 29 + c, 13 + c, 6 - c * 2 if c < 3 else 1, 7 - c,
            IVORY if c < 2 else CORAL)

# Four spark frames followed by supplemental pickup icons.
for c in range(4):
    for i in range(8):
        angle = i * math.pi / 4
        radius = 3 + c * 3
        x = 32 + round(math.cos(angle) * radius)
        y = 16 + round(math.sin(angle) * radius)
        box(c, 5, x, y, 2 if c < 2 else 1, 2 if c < 2 else 1,
            IVORY if c < 2 else GOLD)
# Supplemental pickups replace the retired external small-enemy warning marks.
for c in (4, 5):
    polygon(c, 5, [(32, 1), (47, 9), (47, 23), (32, 31),
                   (17, 23), (17, 9)], INK)
    polygon(c, 5, [(32, 3), (45, 10), (45, 22), (32, 29),
                   (19, 22), (19, 10)], '#245775')
    if c == 4:
        # Powerful: a single heavy gold/ivory slug with doubled shoulders.
        polygon(c, 5, [(32, 6), (38, 13), (35, 13), (35, 24),
                       (29, 24), (29, 13), (26, 13)], GOLD)
        box(c, 5, 31, 11, 2, 11, IVORY)
        pair(c, 5, 24, 16, 2, 5, CORAL)
    else:
        # Large: a wide violet payload, clearly larger than the central slug.
        box(c, 5, 26, 10, 12, 14, VIOLET)
        box(c, 5, 23, 13, 18, 8, VIOLET)
        box(c, 5, 29, 7, 6, 3, IVORY)
        box(c, 5, 29, 13, 6, 8, IVORY)
        pair(c, 5, 21, 17, 2, 2, MINT)

# Dedicated last-stand poses and separate recoverable falcon dives.
for heavy in (False, True):
    for frame in range(4):
        sentinel(frame, heavy, stance='charge')
        sentinel(4 + frame, heavy, stance='rush')
        sentinel(frame, heavy, stance='warning')
        sentinel(4 + frame, heavy, stance='dive')


def chunk(kind, payload):
    return (struct.pack('!I', len(payload)) + kind + payload +
            struct.pack('!I', zlib.crc32(kind + payload)))


raw = b''.join(b'\0' + pixels[y * WIDTH * 4:(y + 1) * WIDTH * 4]
               for y in range(HEIGHT))
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('!IIBBBBB', WIDTH, HEIGHT, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
target = Path(__file__).resolve().parents[1] / 'assets/images/sentinel-effects.png'
target.write_bytes(png)
print(f'Generated {target}: {WIDTH}x{HEIGHT}, {len(png)} bytes')
