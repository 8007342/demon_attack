"""Generate 2x2 pixel-art Starfighter Cockpit HUD & Instrument Sprite Atlas.

Output: assets/images/cockpit-panel.png
Physical dimensions: 512 x 256 (4 columns x 2 rows of 128 x 128 cells).
Logical dimensions per cell: 64 x 64 pixels, upscaled 2x2 with crisp alpha (0 or 255).
"""
from pathlib import Path
import math
import struct
import zlib

CELL_W, CELL_H = 64, 64
COLS, ROWS = 4, 2
WIDTH = CELL_W * 2 * COLS   # 512
HEIGHT = CELL_H * 2 * ROWS  # 256
pixels = bytearray(WIDTH * HEIGHT * 4)

OUTLINE = '#0b101b'
CHARCOAL = '#1b2d3e'
SLATE = '#2e4963'
STEEL = '#4b6e8c'
STEEL_HI = '#87acc9'
TEAL = '#70f5d5'
TEAL_MID = '#39dfcc'
TEAL_DARK = '#16606b'
GOLD = '#f4ca79'
GOLD_HI = '#fff5c9'
GOLD_DARK = '#a36635'
CORAL = '#ff786c'
CRIMSON = '#c92a49'

COLOR_CACHE = {}


def _rgb(color):
    return bytes([int(color[i:i + 2], 16) for i in (1, 3, 5)] + [255])


def dot(c, r, x, y, color):
    if not (0 <= x < CELL_W and 0 <= y < CELL_H):
        return
    rgba = COLOR_CACHE.get(color)
    if rgba is None:
        rgba = _rgb(color)
        COLOR_CACHE[color] = rgba
    px0 = (c * CELL_W + x) * 2
    py0 = (r * CELL_H + y) * 2
    for dy in range(2):
        row_off = (py0 + dy) * WIDTH * 4
        for dx in range(2):
            off = row_off + (px0 + dx) * 4
            pixels[off:off + 4] = rgba


def box(c, r, x, y, w, h, color):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            dot(c, r, xx, yy, color)


def pair_box(c, r, x, y, w, h, color):
    box(c, r, x, y, w, h, color)
    box(c, r, CELL_W - x - w, y, w, h, color)


def pair_dot(c, r, x, y, color):
    dot(c, r, x, y, color)
    dot(c, r, CELL_W - 1 - x, y, color)


def line(c, r, p0, p1, color, thickness=1):
    x0, y0 = p0
    x1, y1 = p1
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t)
        if thickness <= 1:
            dot(c, r, x, y, color)
        else:
            box(c, r, x - thickness // 2, y - thickness // 2, thickness, thickness, color)


def pair_line(c, r, p0, p1, color, thickness=1):
    line(c, r, p0, p1, color, thickness)
    line(c, r, (CELL_W - 1 - p0[0], p0[1]), (CELL_W - 1 - p1[0], p1[1]), color, thickness)


def ring(c, r, cx, cy, r_in, r_out, color, outline=None):
    for y in range(CELL_H):
        for x in range(CELL_W):
            d = math.hypot(x - cx, y - cy)
            if r_in <= d <= r_out:
                if outline and (d < r_in + 1.0 or d > r_out - 1.0):
                    dot(c, r, x, y, outline)
                else:
                    dot(c, r, x, y, color)


def disc(c, r, cx, cy, rad, color, outline=None):
    ring(c, r, cx, cy, 0.0, rad, color, outline=outline)


def polygon(c, r, pts, color):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    min_x = max(0, int(min(xs)))
    max_x = min(CELL_W - 1, int(max(xs)))
    min_y = max(0, int(min(ys)))
    max_y = min(CELL_H - 1, int(max(ys)))
    n = len(pts)
    for y in range(min_y, max_y + 1):
        py = y + 0.5
        for x in range(min_x, max_x + 1):
            px = x + 0.5
            inside = False
            j = n - 1
            for i in range(n):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > py) != (yj > py):
                    if px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                        inside = not inside
                j = i
            if inside:
                dot(c, r, x, y, color)


def pair_poly(c, r, pts, color):
    polygon(c, r, pts, color)
    polygon(c, r, [(CELL_W - x, y) for x, y in pts], color)


# =============================================================================
# ROW 0, COL 0: STARFIGHTER STEERING YOKE / WHEEL (64x64 logical)
# =============================================================================
def draw_steering_yoke():
    c, r = 0, 0
    cx, cy = 31.5, 31.5

    # Outer rim ring with aerospace open-top/bottom contour cuts
    for y in range(CELL_H):
        for x in range(CELL_W):
            dx = x - cx
            dy = y - cy
            d = math.hypot(dx, dy)
            if 21.0 <= d <= 28.0:
                # Top bridge is slightly thinner so 12-o'clock marker stands out;
                # bottom has open fighter-yoke notch
                if dy > 16 and abs(dx) < 9:
                    continue
                if d < 22.0 or d > 27.0:
                    dot(c, r, x, y, OUTLINE)
                elif abs(dx) >= 15 and abs(dy) <= 16:
                    # Contoured left/right hand grips
                    dot(c, r, x, y, SLATE if d < 25.0 else CHARCOAL)
                else:
                    dot(c, r, x, y, CHARCOAL)

    # Ergonomic thumb rests & teal grip stitching on left/right yoke handles
    pair_poly(c, r, [(6, 20), (14, 18), (15, 26), (13, 42), (6, 40)], OUTLINE)
    pair_poly(c, r, [(7, 21), (13, 19), (14, 26), (12, 41), (7, 39)], SLATE)
    pair_line(c, r, (8, 22), (8, 38), STEEL_HI)
    for sy in range(23, 39, 3):
        pair_dot(c, r, 12, sy, TEAL)
        pair_dot(c, r, 11, sy + 1, TEAL_MID)
    # Top thumb trigger buttons on left/right horns
    pair_box(c, r, 9, 15, 5, 4, OUTLINE)
    pair_box(c, r, 10, 16, 3, 2, CORAL)

    # Horizontal & angled cross-spokes linking grips to central hub
    pair_poly(c, r, [(12, 28), (24, 27), (24, 36), (12, 38)], OUTLINE)
    pair_poly(c, r, [(13, 29), (24, 28), (24, 35), (13, 37)], CHARCOAL)
    pair_line(c, r, (13, 30), (23, 29), STEEL)
    pair_line(c, r, (14, 33), (22, 32), TEAL)

    # Top 12-o'clock center marker in #F4CA79 gold
    box(c, r, 28, 3, 8, 7, OUTLINE)
    box(c, r, 29, 4, 6, 5, GOLD)
    box(c, r, 30, 4, 4, 2, GOLD_HI)

    # Central Krybor Fleet emblem hub
    disc(c, r, cx, cy, 10.5, CHARCOAL, outline=OUTLINE)
    ring(c, r, cx, cy, 7.5, 9.2, STEEL)
    # Gold chevron wing emblem in hub center
    polygon(c, r, [(32, 25), (38, 34), (32, 31), (26, 34)], GOLD)
    line(c, r, (32, 26), (32, 32), GOLD_HI)
    dot(c, r, 32, 28, TEAL)


# =============================================================================
# ROW 0, COL 1: DUAL GUN TURRET GIMBAL MOUNT (64x64 logical)
# =============================================================================
def draw_turret_gimbal():
    c, r = 1, 0
    cx, cy = 31.5, 36.0

    # Gimbal azimuth rotation ring with degree notches
    ring(c, r, cx, cy, 18.0, 23.0, CHARCOAL, outline=OUTLINE)
    for deg in range(0, 360, 30):
        rad = math.radians(deg)
        x0 = round(cx + math.cos(rad) * 19)
        y0 = round(cy + math.sin(rad) * 19)
        x1 = round(cx + math.cos(rad) * 22)
        y1 = round(cy + math.sin(rad) * 22)
        line(c, r, (x0, y0), (x1, y1), TEAL if deg % 90 == 0 else STEEL_HI)

    # Twin plasma barrels extending forward (upward to y=4) with recoil dampers
    for bx in (23, 37):
        # Outer barrel shroud & recoil springs
        box(c, r, bx - 1, 6, 6, 26, OUTLINE)
        box(c, r, bx, 7, 4, 24, SLATE)
        box(c, r, bx + 1, 7, 2, 24, STEEL_HI)
        # Recoil damper rings
        for ry in (14, 18, 22):
            box(c, r, bx - 1, ry, 6, 2, CHARCOAL)
            box(c, r, bx, ry, 4, 1, GOLD)
        # Glowing plasma muzzle flash port at barrel tip (y=3..7)
        box(c, r, bx - 1, 3, 6, 5, OUTLINE)
        box(c, r, bx, 4, 4, 3, TEAL)
        box(c, r, bx + 1, 3, 2, 3, GOLD_HI)

    # Armored turret breach & cupola housing
    disc(c, r, cx, cy, 14.5, SLATE, outline=OUTLINE)
    disc(c, r, cx, cy + 1, 10.5, CHARCOAL, outline=OUTLINE)
    # Plasma feed coils inside turret dome
    pair_box(c, r, 24, 31, 4, 10, TEAL_DARK)
    pair_box(c, r, 25, 32, 2, 8, TEAL)
    box(c, r, 30, 29, 4, 12, GOLD)
    box(c, r, 31, 30, 2, 10, GOLD_HI)


# =============================================================================
# ROW 0, COL 2: COCKPIT SHIP HULL TELEMETRY SILHOUETTE (64x64 logical)
# =============================================================================
def draw_ship_telemetry():
    c, r = 2, 0
    cx, cy = 31.5, 31.5

    # Outer tactical shield envelope ring (dashed cyan/teal)
    for deg in range(0, 360, 6):
        if (deg // 6) % 3 == 0:
            continue
        rad = math.radians(deg)
        px = round(cx + math.cos(rad) * 28)
        py = round(cy + math.sin(rad) * 28)
        dot(c, r, px, py, TEAL if deg % 36 == 0 else TEAL_DARK)

    # Blueprint starfighter chassis silhouette
    # Swept delta wings
    wing_pts = [(32, 14), (8, 42), (10, 49), (26, 44), (32, 46)]
    pair_poly(c, r, wing_pts, TEAL_DARK)
    pair_line(c, r, (32, 14), (8, 42), TEAL)
    pair_line(c, r, (8, 42), (10, 49), TEAL)
    pair_line(c, r, (10, 49), (26, 44), TEAL)

    # Forward fuselage & nose cone
    fuselage = [(32, 6), (25, 22), (24, 48), (32, 52)]
    pair_poly(c, r, fuselage, CHARCOAL)
    pair_line(c, r, (32, 6), (25, 22), TEAL)
    pair_line(c, r, (25, 22), (24, 48), STEEL_HI)

    # Canopy & weapon hardpoints
    polygon(c, r, [(32, 15), (28, 26), (32, 32), (36, 26)], TEAL_MID)
    line(c, r, (32, 16), (32, 30), GOLD_HI)
    # Wing hardpoint nodes
    pair_box(c, r, 16, 34, 4, 6, GOLD)
    pair_box(c, r, 17, 35, 2, 4, GOLD_HI)
    # Twin engine thruster cores
    pair_box(c, r, 26, 49, 4, 6, CORAL)
    pair_box(c, r, 27, 50, 2, 4, GOLD_HI)


# =============================================================================
# ROW 0, COL 3: COCKPIT TILT / GYRO HORIZON INDICATOR RING (64x64 logical)
# =============================================================================
def draw_gyro_horizon():
    c, r = 3, 0
    cx, cy = 31.5, 31.5

    # Precision outer bezel ring with degree ticks
    ring(c, r, cx, cy, 24.0, 29.5, CHARCOAL, outline=OUTLINE)
    for deg in range(0, 360, 15):
        rad = math.radians(deg)
        inner = 21.0 if deg % 45 == 0 else 23.0
        x0 = round(cx + math.cos(rad) * inner)
        y0 = round(cy + math.sin(rad) * inner)
        x1 = round(cx + math.cos(rad) * 28.0)
        y1 = round(cy + math.sin(rad) * 28.0)
        col = GOLD if deg in (0, 180, 270) else (TEAL if deg % 45 == 0 else STEEL_HI)
        line(c, r, (x0, y0), (x1, y1), col)

    # Artificial horizon pitch ladder bars inside ring
    line(c, r, (12, 32), (24, 32), TEAL, thickness=2)
    line(c, r, (40, 32), (52, 32), TEAL, thickness=2)
    for pitch_y, w in [(22, 6), (27, 4), (37, 4), (42, 6)]:
        pair_line(c, r, (32 - w - 3, pitch_y), (32 - 3, pitch_y), STEEL_HI)
        pair_dot(c, r, 32 - w - 3, pitch_y + (1 if pitch_y < 32 else -1), STEEL_HI)

    # Center aircraft reference chevron
    line(c, r, (26, 34), (32, 30), GOLD, thickness=2)
    line(c, r, (32, 30), (38, 34), GOLD, thickness=2)
    dot(c, r, 32, 30, GOLD_HI)


# =============================================================================
# ROW 1, COLS 0..3: 4 FRAMES OF THRUSTER/CAPACITOR PLASMA FLOW & BEZEL CORNERS
# =============================================================================
def draw_plasma_and_bezel(c):
    r = 1
    # Corner structural bezel brackets (top-left, top-right, bottom-left, bottom-right)
    bezel_col = CORAL if c == 3 else STEEL
    bezel_hi = GOLD_HI if c == 3 else TEAL
    for sy in (0, 1):
        y_flip = (CELL_H - 1) if sy else 0
        ydir = -1 if sy else 1
        for sx in (0, 1):
            x_flip = (CELL_W - 1) if sx else 0
            xdir = -1 if sx else 1
            for i in range(14):
                for t in range(4):
                    dot(c, r, x_flip + xdir * i, y_flip + ydir * t, bezel_col)
                    dot(c, r, x_flip + xdir * t, y_flip + ydir * i, bezel_col)
            # Corner rivet & status LED
            dot(c, r, x_flip + xdir * 4, y_flip + ydir * 4, bezel_hi)
            dot(c, r, x_flip + xdir * 5, y_flip + ydir * 4, bezel_hi)

    # Central horizontal & vertical capacitor plasma conduit flow (animated with frame `c`)
    box(c, r, 10, 22, 44, 20, OUTLINE)
    box(c, r, 12, 24, 40, 16, CHARCOAL)

    # Animated plasma wave pulses inside conduit
    for x in range(14, 50):
        wave = math.sin((x + c * 6) * 0.35) * 4.0
        wy = round(32 + wave)
        box(c, r, x, 26, 1, 12, TEAL_DARK)
        box(c, r, x, wy - 2, 1, 5, GOLD if c == 3 else TEAL_MID)
        box(c, r, x, wy - 1, 1, 3, CORAL if c == 3 else TEAL)
        dot(c, r, x, wy, GOLD_HI)

    # Vertical capacitor ribs
    for rx in range(18, 50, 8):
        box(c, r, rx, 23, 2, 18, SLATE)
        dot(c, r, rx, 24, STEEL_HI)
        dot(c, r, rx, 39, STEEL_HI)


draw_steering_yoke()
draw_turret_gimbal()
draw_ship_telemetry()
draw_gyro_horizon()
for frame_col in range(4):
    draw_plasma_and_bezel(frame_col)


def chunk(kind, payload):
    return (struct.pack('!I', len(payload)) + kind + payload +
            struct.pack('!I', zlib.crc32(kind + payload)))


raw = b''.join(b'\0' + pixels[y * WIDTH * 4:(y + 1) * WIDTH * 4]
               for y in range(HEIGHT))
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('!IIBBBBB', WIDTH, HEIGHT, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
target = Path(__file__).resolve().parents[1] / 'assets/images/cockpit-panel.png'
target.write_bytes(png)
print(f'Generated {target}: {WIDTH}x{HEIGHT}, {len(png)} bytes')
