"""Original low-resolution sentinel and damage frames; standard library only.

Eight columns, eight rows. Each 128x64 cell is authored as 64x32 pixels,
then enlarged exactly 2x. No source game sprites or generated illustrations.
"""
from pathlib import Path
import math
import struct
import zlib

WIDTH, HEIGHT = 1024, 512
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


def sentinel(c, heavy=False, stance=None):
    r = int(heavy) + (6 if stance else 0)
    warning = c >= 4 or stance is not None
    frame = c % 4
    base = GOLD if heavy else CORAL if stance == 'rush' else VIOLET
    shadow = '#a36635' if heavy else '#5840a3'
    # Broad four-tier feather bars, with 1px stair steps at their shoulders.
    # Wing stroke is deliberately held across slow discrete frames.
    lift = [-3, -1, 2, -1][frame] if not warning else [0, 1, 2, 1][frame]
    if stance == 'charge':
        lift = [-6, -7, -8, -7][frame]
    elif stance == 'rush':
        lift = [1, 0, 1, 2][frame]
    for tier in range(4):
        tip = 3 + tier * 4 + (2 if warning else 0)
        if stance == 'rush':
            tip = 16 + tier * 2
        y = 11 + tier * 3 + lift
        pair(c, r, tip, y, 25 - tip, 3, INK)
        pair(c, r, tip + 1, y, 23 - tip, 1, base)
        pair(c, r, tip + 2, y + 1, 22 - tip, 1, shadow)
        pair(c, r, 24, 12 + tier * 2, 3, 3, INK)
        pair(c, r, 24, 12 + tier * 2, 2, 1, base)
        if heavy:
            pair(c, r, tip + 2, y, 3, 1, IVORY)
        if warning and stance != 'rush':
            pair(c, r, 20 - tier, y, 3, 1, CORAL if frame % 2 else IVORY)
        if stance == 'charge':
            pair(c, r, tip + 1, y, 2 + frame % 3, 1, IVORY)
    # Horned head, fanned throat and tapered tail: living creature, not hull.
    pair(c, r, 27, 6, 2, 5, INK)
    pair(c, r, 27, 7, 1, 3, base)
    box(c, r, 28, 10, 8, 13, INK)
    box(c, r, 26, 13, 12, 7, INK)
    box(c, r, 29, 11, 6, 10, shadow)
    box(c, r, 28, 13, 8, 5, base)
    box(c, r, 30, 21, 4, 3, base)
    box(c, r, 31, 24, 2, 3, base)
    pair(c, r, 27, 20, 2, 3, base)
    pair(c, r, 28, 14, 3, 2, CORAL if warning else IVORY)
    box(c, r, 31, 17, 2, 2, INK)
    pair(c, r, 29, 19, 1, 2, IVORY)
    if heavy:
        box(c, r, 30, 8, 4, 2, GOLD)
        box(c, r, 31, 6, 2, 3, IVORY)
    if warning:
        box(c, r, 30, 21, 4, 2, IVORY if frame % 2 else CORAL)
    if stance == 'charge':
        # Raised four-tier wings and a four-step crown ignition communicate
        # an exceptional attack before the silhouette folds for the rush.
        box(c, r, 30, 8, 4, 1, CORAL)
        pair(c, r, 26 - frame, 5, 1, 2, IVORY)
        pair(c, r, 28, 24, 2, 3, CORAL)
    elif stance == 'rush':
        # Narrow folded wings, extended talons and a bright throat make the
        # irreversible downward rush distinct without any external arrow.
        box(c, r, 30, 17, 4, 2, IVORY)
        pair(c, r, 27, 22, 2, 5 + frame % 2, base)
        pair(c, r, 28, 27 + frame % 2, 1, 2, IVORY)
        box(c, r, 31, 26, 2, 4, CORAL)
        pair(c, r, 23, 7 + frame, 1, 3, IVORY)


for heavy in (False, True):
    for c in range(8):
        sentinel(c, heavy)

# Transparent shield states: intact, two successively depleted, final sparks.
# Stepped underside stays symmetric and progresses toward the exposed throat.
for c in range(4):
    extent = [25, 19, 12, 6][c]
    for x in range(32 - extent, 32 + extent):
        distance = abs(x - 31.5)
        y = 29 - int(distance // 7)
        if c < 3 or x % 3 == 0:
            dot(c, 2, x, y, MINT)
    for side in (-1, 1):
        x = 32 + side * extent
        box(c, 2, x, 24 if c < 2 else 27, 1, 2, '#147c93')

# Four nested armor layers. Renderer sheds outside layers before chest plate.
for layer in range(4):
    c = 4 + layer
    x = [28, 24, 19, 12][layer]
    y = [17, 13, 12, 11][layer]
    pair(c, 2, x, y, 3, 3, INK)
    pair(c, 2, x, y, 3, 1, GOLD)
    pair(c, 2, x, y + 1, 2, 1, IVORY)

# Four solid, dithered smoke clusters. No soft alpha, circles or gradients.
for c in range(4):
    for yy in range(-5 - c, 5 + c):
        for xx in range(-5 - c, 6 + c):
            edge = abs(xx) + abs(yy) * .8
            if edge > 7 + c or (c >= 2 and (xx + yy * 3) % 5 == 0):
                continue
            color = '#3b3854' if xx + yy > 1 else '#625b72'
            if (xx * 3 + yy * 7) % 9 == 0:
                color = '#888093'
            dot(c, 3, 32 + xx + c % 2, 16 + yy, color)

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

# Four spark frames; four small symmetric attack markings for ordinary mobs.
for c in range(4):
    for i in range(8):
        angle = i * math.pi / 4
        radius = 3 + c * 3
        x = 32 + round(math.cos(angle) * radius)
        y = 16 + round(math.sin(angle) * radius)
        box(c, 5, x, y, 2 if c < 2 else 1, 2 if c < 2 else 1,
            IVORY if c < 2 else GOLD)
for frame in range(4):
    c = frame + 4
    for x in (18, 43):
        box(c, 5, x, 13, 2, 5, CORAL if frame % 2 else IVORY)
        box(c, 5, x + (-2 if x < 32 else 2), 14, 2, 3, CORAL)

# Dedicated last-stand poses, preserving rows 0–5 exactly.
for heavy in (False, True):
    for frame in range(4):
        sentinel(frame, heavy, stance='charge')
        sentinel(4 + frame, heavy, stance='rush')


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
