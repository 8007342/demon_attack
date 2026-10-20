"""Original deterministic Demon Attack artwork; Python standard library only."""
from pathlib import Path
import math
import struct
import zlib

SIZE = 512
HEIGHT = 1280
pixels = bytearray(SIZE * HEIGHT * 4)
OUTLINE = '#100e2c'


def dot(x, y, color):
    if not (0 <= x < 256 and 0 <= y < HEIGHT // 2):
        return
    rgb = tuple(int(color[i:i + 2], 16) for i in (1, 3, 5))
    for dy in range(2):
        for dx in range(2):
            offset = ((y * 2 + dy) * SIZE + x * 2 + dx) * 4
            pixels[offset:offset + 4] = bytes((*rgb, 255))


def polygon(col, row, points, color):
    # Scan-convert at logical pixel centers, then enlarge exactly 2x.
    for y in range(32):
        for x in range(32):
            inside = False
            j = len(points) - 1
            for i, (xi, yi) in enumerate(points):
                xj, yj = points[j]
                if (yi > y + .5) != (yj > y + .5):
                    if x + .5 < (xj - xi) * (y + .5 - yi) / (yj - yi) + xi:
                        inside = not inside
                j = i
            if inside:
                dot(col * 32 + x, row * 32 + y, color)


def box(c, r, x, y, w, h, color):
    polygon(c, r, [(x, y), (x + w, y), (x + w, y + h), (x, y + h)], color)


def demon(c, r, frame, angry, kind=None, molt=0):
    species = r if kind is None else kind
    colors = ['#39dfcc', '#a888ff', '#ff786c', '#efbd57']
    molts = [
        ['#51d4ac', '#8bd47d', '#d7c968'],
        ['#bb87d3', '#d980ab', '#ed9984'],
        ['#f99b78', '#f3b26e', '#ebcc75'],
        ['#e7ab73', '#e79b8d', '#ed8fa7'],
    ]
    base = '#ffbd53' if angry else molts[species][molt - 1] if molt else colors[species]
    shadow = ['#147c93', '#5840a3', '#aa385c', '#a36635'][species]
    lift = [-5, -2, 3, -1][frame]
    # Bent fingered wings with scalloped lower edges. Each flap changes silhouette.
    left = [(14, 13), (10, 11 + lift), (4, 7 + lift), (1, 11 + lift),
            (3 + molt, 21 + lift - molt), (6, 18 + lift),
            (8, 22 + lift - molt), (11, 19), (14, 21)]
    polygon(c, r, left, OUTLINE)
    polygon(c, r, [(32 - x, y) for x, y in left], OUTLINE)
    inner = [(13, 14), (9, 13 + lift), (4, 10 + lift), (4, 17 + lift),
             (7, 16 + lift), (9, 19 + lift), (12, 17), (14, 19)]
    polygon(c, r, inner, base)
    polygon(c, r, [(32 - x, y) for x, y in inner], base)
    polygon(c, r, [(11, 11), (12, 6 - species % 2 + molt), (16, 10), (20, 6 + molt),
                   (21, 12), (23, 18), (20, 24), (18, 24), (16, 29),
                   (14, 25), (11, 24), (9, 18)], OUTLINE)
    polygon(c, r, [(13, 12), (13, 9), (16, 12), (19, 9), (19, 13),
                   (21, 18), (18, 24), (16, 26), (14, 23), (11, 18)], shadow)
    box(c, r, 13, 13, 6, 7, base)
    if species == 1:
        polygon(c, r, [(12 + molt, 14), (16, 11 + molt), (20, 14), (16, 18)], '#d7c3ff')
    if species == 2:
        polygon(c, r, [(14, 20), (16, 27 - molt), (18, 20)], '#ffc2a4')
    if species == 3:
        box(c, r, 15, 6 + molt, 2, 6 - molt, base)
        box(c, r, 12, 4 + molt * 2, 2, max(1, 5 - molt), base)
        box(c, r, 18, 4 + molt, 2, 5 - molt, base)
    if molt:
        # Shed carapace reveals a luminous belly; asymmetrical cracks grow with damage.
        polygon(c, r, [(14, 18), (18, 18), (19, 21 + molt),
                       (16, 23 + molt), (13, 21)], '#ffd6a4')
        box(c, r, 13, 12, 1, 2 + molt, OUTLINE)
        box(c, r, 12, 13 + molt, 2, 1, OUTLINE)
        if molt >= 2:
            polygon(c, r, [(8, 14 + lift), (11, 16 + lift), (9, 19 + lift)], OUTLINE)
            polygon(c, r, [(24, 13 + lift), (22, 16 + lift), (25, 17 + lift)], OUTLINE)
        if molt >= 3:
            box(c, r, 18, 11, 2, 3, OUTLINE)
            polygon(c, r, [(4, 10 + lift), (7, 13 + lift), (4, 15 + lift)], OUTLINE)
    eye = '#ff355f' if angry else '#fff5c9'
    box(c, r, 12, 15 + (1 if angry else 0), 3, 2, eye)
    box(c, r, 17, 15 + (1 if angry else 0), 3, 2, eye)
    box(c, r, 14, 20, 4, 1, OUTLINE)
    box(c, r, 14, 21, 1, 2, '#ffffff')
    box(c, r, 17, 21, 1, 2, '#ffffff')
    if angry:
        box(c, r, 14, 12, 1, 3, '#ffefb2')
        box(c, r, 18, 19, 1, 4, '#ff355f')


for row in range(4):
    for col in range(8):
        demon(col, row, col % 4, col >= 4)

for kind in range(4):
    for molt in range(1, 4):
        row = 8 + kind * 3 + molt - 1
        for col in range(8):
            demon(col, row, col % 4, col >= 4, kind=kind, molt=molt)

for c in range(4):
    polygon(c, 4, [(16, 3), (21, 15), (28, 22), (28, 27), (19, 24),
                   (13, 24), (4, 27), (4, 22), (11, 15)], OUTLINE)
    polygon(c, 4, [(16, 6), (19, 17), (25, 23), (18, 21), (14, 21),
                   (7, 23), (13, 17)], '#70dfed')
    box(c, 4, 15, 12, 2, 8, '#f5fbff')
    box(c, 4, 14, 18, 4, 5, '#4868b7')
    polygon(c, 4, [(14, 24), (18, 24), (16, 27 + c)], '#ffae58')
    box(c, 4, 15, 24, 2, 2 + c % 2, '#fff4b8')

def icon(c, r, kind):
    polygon(c, r, [(16, 3), (28, 10), (28, 22), (16, 29), (4, 22), (4, 10)], OUTLINE)
    polygon(c, r, [(16, 5), (26, 11), (26, 21), (16, 27), (6, 21), (6, 11)], '#245775')
    color = ['#8af3de', '#ffca62', '#a99aff', '#ff658b'][kind]
    if kind == 0:
        for x in (10, 16, 22):
            polygon(c, r, [(x, 9), (x + 3, 15), (x + 1, 15), (x + 1, 23),
                           (x - 1, 23), (x - 1, 15), (x - 3, 15)], color)
    elif kind == 1:
        polygon(c, r, [(17, 7), (10, 17), (15, 17), (13, 25), (23, 13), (17, 13)], color)
    elif kind == 2:
        polygon(c, r, [(16, 8), (24, 11), (23, 20), (16, 25), (9, 20), (8, 11)], color)
        polygon(c, r, [(16, 11), (21, 13), (20, 19), (16, 22), (12, 19), (11, 13)], '#245775')
    else:
        polygon(c, r, [(8, 11), (11, 8), (15, 8), (16, 11), (18, 8), (22, 8),
                       (25, 11), (25, 16), (16, 25), (7, 16)], color)

for c in range(4, 8):
    icon(c, 4, c - 4)

for c in range(8):
    radius = [3, 6, 10, 13, 12, 10, 7, 4][c]
    points = []
    for i in range(24):
        angle = i * math.pi / 12
        length = radius if i % 2 == 0 else radius * .5
        points.append((16 + math.cos(angle) * length, 16 + math.sin(angle) * length))
    polygon(c, 5, points, '#ff6a56' if c < 5 else '#b64c78')
    if c < 5:
        polygon(c, 5, [(16, 16 - radius * .7), (16 + radius * .6, 16),
                       (16, 16 + radius * .7), (16 - radius * .6, 16)], '#ffd273')
        box(c, 5, 14, 14, 4, 4, '#fff8dd')
    for i in range(5):
        x = 3 + (i * 7 + c * 3) % 26
        y = 3 + (i * 11 + c * 5) % 26
        box(c, 5, x, y, 1, 1, '#ffc784')

for c in range(4):
    color = ['#7063a8', '#9862b8', '#be596f', '#d2844c'][c]
    polygon(c, 6, [(1, 9), (5, 14), (8, 5), (12, 11), (16, 7), (20, 11),
                   (24, 5), (27, 14), (31, 9), (29, 23), (24, 27), (8, 27), (3, 23)], OUTLINE)
    polygon(c, 6, [(3, 13), (6, 17), (9, 9), (12, 14), (16, 11), (20, 14),
                   (23, 9), (26, 17), (29, 13), (27, 22), (23, 25), (9, 25), (5, 22)], color)
    polygon(c, 6, [(7, 17), (14, 19), (13, 22), (8, 21)], '#ffcc72')
    polygon(c, 6, [(25, 17), (18, 19), (19, 22), (24, 21)], '#ffcc72')
    box(c, 6, 13, 23, 6, 3, OUTLINE)
    box(c, 6, 15, 23, 2, 2, '#ff697f')
    for x in range(7, 26, 6):
        box(c, 6, x, 25, 2, 2, '#87eadc')
for c in range(4, 8):
    icon(c, 6, c - 4)

for c in range(8):
    if c < 4:
        box(c, 7, 0, 0, 32, 32, '#10182d')
        box(c, 7, 0, 0, 32, 1, '#3c5271')
        box(c, 7, 0, 0, 1, 32, '#3c5271')
        for y in range(5, 32, 6):
            for x in range(5, 32, 6):
                box(c, 7, x, y, 1, 1, '#325268')
        box(c, 7, 5, 3, 8 + c * 2, 1, '#4d9eaa')
    else:
        for i in range(8):
            angle = i * math.pi / 4
            length = 3 + (c - 4) * 3
            x, y = 16 + int(math.cos(angle) * length), 16 + int(math.sin(angle) * length)
            box(c, 7, x, y, 2, 2, '#ffe6a1')


def chunk(kind, payload):
    return struct.pack('!I', len(payload)) + kind + payload + struct.pack('!I', zlib.crc32(kind + payload))


raw = b''.join(b'\0' + pixels[y * SIZE * 4:(y + 1) * SIZE * 4] for y in range(HEIGHT))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!IIBBBBB', SIZE, HEIGHT, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
target = Path(__file__).resolve().parents[1] / 'assets/images/combat.png'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(png)
print(f'Generated {target}: {SIZE}x{HEIGHT} RGBA, {len(png)} bytes')
