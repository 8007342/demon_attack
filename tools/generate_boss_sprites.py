"""Generate high-detail 2x2 pixel-art Brood Dreadnought Carrier sprite sheet.

Output: assets/images/boss-carrier.png
Physical dimensions: 1472 x 960 (4 columns x 4 rows of 368 x 240 cells).
Logical dimensions per cell: 184 x 120 pixels, upscaled 2x2 with crisp alpha (0 or 255).
"""
from pathlib import Path
import math
import struct
import zlib

CELL_W, CELL_H = 184, 120
COLS, ROWS = 4, 4
WIDTH = CELL_W * 2 * COLS   # 1472
HEIGHT = CELL_H * 2 * ROWS  # 960
pixels = bytearray(WIDTH * HEIGHT * 4)

OUTLINE = '#131826'
DARK_METAL = '#1c2438'
MID_METAL = '#2f3d5c'
LIGHT_METAL = '#526894'
STEEL_HI = '#8aa2cc'
EYE_GOLD = '#ffd166'
EYE_ORANGE = '#ff9f43'
EYE_GLINT = '#fff3b0'
TEAL_GLOW = '#70f5d5'
TEAL_MID = '#29b8a6'
TEAL_DARK = '#145c63'
CRIMSON_HOT = '#ff5c77'
CRIMSON_MID = '#c92a49'
CRIMSON_DARK = '#691227'
SCORCH_DARK = '#16111c'
SCORCH_MID = '#2c2033'
EMBER_BRIGHT = '#ffae52'

PALETTES = [
    # Col 0: Carrier - Deep Imperial Violet/Indigo
    {
        'base': '#6e5fa8',
        'shadow': '#4a3d7a',
        'deep': '#2e2452',
        'hi': '#9e8fd9',
        'spec': '#cec4f5',
        'trim': '#526894',
        'trim_hi': '#8aa2cc',
        'conduit': '#39dfcc',
        'conduit_hi': '#a8fff0',
    },
    # Col 1: Brood Ark - Royal Brood Magenta
    {
        'base': '#9858b8',
        'shadow': '#643482',
        'deep': '#401d57',
        'hi': '#c98ae8',
        'spec': '#ecc5ff',
        'trim': '#6e5fa8',
        'trim_hi': '#a899e6',
        'conduit': '#70f5d5',
        'conduit_hi': '#c7fff0',
    },
    # Col 2: Siege Carrier - Crimson Siege Carapace
    {
        'base': '#c24e68',
        'shadow': '#802b41',
        'deep': '#4f1626',
        'hi': '#f07d95',
        'spec': '#ffb8c6',
        'trim': '#8f4a1e',
        'trim_hi': '#d88044',
        'conduit': '#ff9f43',
        'conduit_hi': '#fff3b0',
    },
    # Col 3: Brood Flagship - Molten Flagship Gold-Bronze
    {
        'base': '#d88044',
        'shadow': '#8f4a1e',
        'deep': '#54280d',
        'hi': '#ffb070',
        'spec': '#ffe0b5',
        'trim': '#c99b38',
        'trim_hi': '#ffe885',
        'conduit': '#ffd166',
        'conduit_hi': '#ffffff',
    },
]


def _rgb(color):
    return bytes([int(color[i:i + 2], 16) for i in (1, 3, 5)] + [255])


COLOR_CACHE = {}


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


def clear_dot(c, r, x, y):
    if not (0 <= x < CELL_W and 0 <= y < CELL_H):
        return
    px0 = (c * CELL_W + x) * 2
    py0 = (r * CELL_H + y) * 2
    zero = b'\x00\x00\x00\x00'
    for dy in range(2):
        row_off = (py0 + dy) * WIDTH * 4
        for dx in range(2):
            off = row_off + (px0 + dx) * 4
            pixels[off:off + 4] = zero


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


def outlined_pair_poly(c, r, pts, fill_color, outline_color=OUTLINE):
    pair_poly(c, r, pts, fill_color)
    n = len(pts)
    for i in range(n):
        pair_line(c, r, pts[i], pts[(i + 1) % n], outline_color)


def ellipse(c, r, cx, cy, rx, ry, color, outline=None):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            dx = (x - cx) / max(0.5, rx)
            dy = (y - cy) / max(0.5, ry)
            d = dx * dx + dy * dy
            if d <= 1.0:
                if outline and d >= 0.76:
                    dot(c, r, x, y, outline)
                else:
                    dot(c, r, x, y, color)


def draw_launch_bay(c, r, cx, cy, w, h, pal, main_bay=False):
    x0 = cx - w // 2
    y0 = cy - h // 2
    # Outer dark armor collar
    box(c, r, x0 - 2, y0 - 2, w + 4, h + 4, OUTLINE)
    box(c, r, x0 - 1, y0 - 1, w + 2, h + 2, pal['trim'])
    box(c, r, x0, y0 - 1, w, 1, pal['trim_hi'])
    # Recessed interior cavern
    box(c, r, x0, y0, w, h, DARK_METAL)
    box(c, r, x0 + 1, y0 + 1, w - 2, h - 2, OUTLINE)
    # Internal vertical guide rails & launch gantry glow
    for gx in range(x0 + 2, x0 + w - 2, 3):
        box(c, r, gx, y0 + 1, 1, h - 2, MID_METAL)
    # Glowing brood launch field inside bay
    inner_glow = pal['conduit'] if main_bay else TEAL_MID
    inner_hi = pal['conduit_hi'] if main_bay else TEAL_GLOW
    box(c, r, x0 + 2, y0 + 2, w - 4, h - 4, TEAL_DARK)
    box(c, r, x0 + 3, y0 + 3, w - 6, max(2, h - 6), inner_glow)
    box(c, r, x0 + 4, y0 + 4, max(2, w - 8), max(1, h - 8), inner_hi)
    # Gantry teeth at top and bottom of bay
    for tx in range(x0 + 2, x0 + w - 2, 4):
        box(c, r, tx, y0, 2, 2, pal['trim_hi'])
        box(c, r, tx, y0 + h - 2, 2, 2, MID_METAL)


def draw_eye_cluster(c, r, pal, phase):
    # Multi-faceted compound sensor eye clusters on left and right brow ridges
    eyes = [
        (68, 52, 4, 3),
        (61, 50, 3, 2),
        (55, 48, 3, 2),
        (74, 55, 3, 2),
    ]
    if phase >= 2:
        eyes.append((49, 46, 2, 2))
    for ex, ey, ew, eh in eyes:
        pair_box(c, r, ex - 1, ey - 1, ew + 2, eh + 2, OUTLINE)
        pair_box(c, r, ex, ey, ew, eh, EYE_ORANGE)
        pair_box(c, r, ex, ey, max(1, ew - 1), max(1, eh - 1), EYE_GOLD)
        pair_dot(c, r, ex + 1, ey, EYE_GLINT)


# =============================================================================
# ROW 0: 4 EVOLUTION FORMS OF THE BROOD DREADNOUGHT CARRIER (184x120 logical)
# =============================================================================
def draw_carrier_hull(c):
    r = 0
    pal = PALETTES[c]
    phase = c

    # 1. Phase-specific evolution extremities behind main hull
    if phase >= 1:
        # Twin dorsal ark horns & broader upper shoulder bulkheads
        horn_pts = [(64, 24), (54, 8), (60, 6), (72, 20)]
        outlined_pair_poly(r=r, c=c, pts=horn_pts, fill_color=pal['shadow'])
        pair_line(c, r, (56, 8), (68, 20), pal['hi'])
        shoulder_ark = [(22, 34), (48, 20), (54, 30), (16, 48)]
        outlined_pair_poly(c, r, shoulder_ark, pal['deep'])

    if phase >= 2:
        # Heavy forward siege prows & quad outer wing tips
        siege_prow = [(32, 74), (24, 96), (34, 98), (44, 78)]
        outlined_pair_poly(c, r, siege_prow, pal['trim'])
        pair_line(c, r, (26, 94), (34, 76), pal['trim_hi'])
        quad_tip = [(14, 56), (2, 68), (8, 74), (24, 66)]
        outlined_pair_poly(c, r, quad_tip, pal['shadow'])
        pair_line(c, r, (4, 68), (18, 58), pal['hi'])

    if phase >= 3:
        # Flagship crown spires & heavy golden bastion trim fins
        crown_center = [(86, 18), (92, 3), (98, 18)]
        polygon(c, r, crown_center, pal['trim_hi'])
        line(c, r, (86, 18), (92, 3), OUTLINE)
        line(c, r, (98, 18), (92, 3), OUTLINE)
        line(c, r, (92, 5), (92, 17), EYE_GLINT)
        crown_side = [(74, 20), (70, 6), (78, 10), (82, 20)]
        outlined_pair_poly(c, r, crown_side, pal['trim'])
        pair_line(c, r, (71, 8), (77, 18), pal['trim_hi'])

    # 2. Swept armored outer wing-pylons (x=4..56, y=28..88)
    wing_outer = [
        (52, 28),
        (18, 36),
        (4 + (0 if phase >= 2 else 4), 52),
        (10, 78),
        (28, 86),
        (50, 76),
    ]
    outlined_pair_poly(c, r, wing_outer, pal['deep'])

    wing_plate = [
        (52, 31),
        (22, 38),
        (9, 52),
        (15, 73),
        (30, 80),
        (50, 72),
    ]
    outlined_pair_poly(c, r, wing_plate, pal['shadow'])

    wing_upper_bevel = [
        (50, 33),
        (24, 39),
        (13, 51),
        (20, 60),
        (48, 52),
    ]
    pair_poly(c, r, wing_upper_bevel, pal['base'])
    pair_line(c, r, (24, 39), (49, 33), pal['hi'])
    pair_line(c, r, (14, 51), (24, 39), pal['spec'])

    # Ribbed intake grilles on outer wing pylons
    for gy in range(46, 68, 4):
        pair_box(c, r, 22, gy, 16, 2, OUTLINE)
        pair_box(c, r, 23, gy + 1, 14, 1, pal['conduit'] if gy % 8 == 6 else MID_METAL)

    # Wingtip navigation beacons
    pair_box(c, r, 7, 50, 4, 6, OUTLINE)
    pair_box(c, r, 8, 51, 2, 4, CRIMSON_HOT if phase >= 2 else TEAL_GLOW)
    pair_dot(c, r, 8, 51, '#ffffff')

    # 3. Dorsal brood-spire towers (top silhouette y=12..34)
    outer_spire = [(46, 30), (52, 15), (60, 18), (62, 32)]
    outlined_pair_poly(c, r, outer_spire, pal['shadow'])
    pair_line(c, r, (53, 17), (49, 29), pal['hi'])

    inner_spire = [(66, 26), (72, 11), (80, 14), (82, 26)]
    outlined_pair_poly(c, r, inner_spire, pal['base'])
    pair_line(c, r, (73, 13), (69, 25), pal['spec'])
    # Spire energy nodes
    pair_box(c, r, 73, 16, 3, 5, OUTLINE)
    pair_box(c, r, 74, 17, 1, 3, pal['conduit_hi'])

    # 4. Main central carapace & armored upper hull (x=36..148, y=20..88)
    hull_body = [
        (92, 16),
        (62, 22),
        (38, 36),
        (32, 60),
        (36, 84),
        (62, 92),
        (92, 94),
    ]
    outlined_pair_poly(c, r, hull_body, pal['deep'])

    # Mid-carapace armored deck
    carapace_mid = [
        (92, 20),
        (65, 25),
        (43, 38),
        (38, 58),
        (42, 78),
        (66, 86),
        (92, 88),
    ]
    outlined_pair_poly(c, r, carapace_mid, pal['shadow'])

    # Beveled upper carapace armor plates with specular ridge highlights
    upper_dome = [
        (92, 23),
        (68, 28),
        (48, 40),
        (46, 54),
        (68, 62),
        (92, 64),
    ]
    outlined_pair_poly(c, r, upper_dome, pal['base'])
    pair_line(c, r, (92, 24), (68, 29), pal['spec'])
    pair_line(c, r, (68, 29), (49, 40), pal['hi'])

    # Tiered dorsal ridge chevrons
    for tier in range(3):
        ty = 28 + tier * 9
        tw = 22 - tier * 3
        chev = [
            (92, ty),
            (92 - tw, ty + 5),
            (92 - tw + 3, ty + 8),
            (92, ty + 4),
        ]
        outlined_pair_poly(c, r, chev, pal['hi'] if tier == 0 else pal['base'])
        pair_line(c, r, (92, ty + 1), (92 - tw + 2, ty + 5), pal['spec'])

    # Recessed panel seams and rivets across carapace
    pair_line(c, r, (56, 36), (52, 68), OUTLINE)
    pair_line(c, r, (57, 36), (53, 68), pal['hi'])
    for ry in range(38, 66, 5):
        pair_dot(c, r, 55, ry, pal['spec'])
        pair_dot(c, r, 60, ry, pal['spec'])

    # Flagship / Siege golden bastion shoulder trim
    if phase >= 2:
        bastion_trim = [(42, 38), (64, 26), (66, 30), (44, 42)]
        pair_poly(c, r, bastion_trim, pal['trim_hi'] if phase == 3 else pal['trim'])
        pair_line(c, r, (42, 38), (64, 26), OUTLINE)

    # 5. Glowing plasma conduits leading from dorsal spires to central core
    pair_line(c, r, (74, 22), (82, 42), OUTLINE, thickness=3)
    pair_line(c, r, (82, 42), (86, 58), OUTLINE, thickness=3)
    pair_line(c, r, (74, 22), (82, 42), pal['conduit'])
    pair_line(c, r, (82, 42), (86, 58), pal['conduit_hi'])

    pair_line(c, r, (54, 44), (76, 54), OUTLINE, thickness=3)
    pair_line(c, r, (54, 44), (76, 54), pal['conduit'])

    # 6. Multi-faceted compound sensor eye clusters on brow ridges
    draw_eye_cluster(c, r, pal, phase)

    # 7. Ventral plasma diffuser fins along lower hull between bays
    for fx in (66, 72, 112, 118):
        box(c, r, fx - 2, 82, 4, 14, OUTLINE)
        box(c, r, fx - 1, 83, 2, 12, pal['trim'])
        box(c, r, fx - 1, 84, 1, 10, pal['conduit'])

    # Outer ventral stabilizing keels
    keel = [(28, 82), (22, 98), (30, 98), (36, 84)]
    outlined_pair_poly(c, r, keel, pal['trim'])
    pair_line(c, r, (24, 96), (30, 84), pal['trim_hi'])

    # 8. Three recessed launch bay frames along lower hull:
    # Left Auxiliary Bay (x = 46), Center Main Bay (x = 92), Right Auxiliary Bay (x = 138)
    draw_launch_bay(c, r, 46, 76, 20, 14, pal, main_bay=False)
    draw_launch_bay(c, r, 138, 76, 20, 14, pal, main_bay=False)
    draw_launch_bay(c, r, 92, 78, 30, 18, pal, main_bay=True)

    # Central brood core housing arch above Center Main Bay
    ellipse(c, r, 92, 60, 12, 8, pal['deep'], outline=OUTLINE)
    ellipse(c, r, 92, 60, 9, 6, pal['conduit'], outline=OUTLINE)
    ellipse(c, r, 92, 60, 5, 3, pal['conduit_hi'])
    box(c, r, 90, 59, 4, 2, '#ffffff')


# =============================================================================
# ROW 1: ARTICULATED SIEGE MANDIBLES & DORSAL THRUSTER PLUMES
# =============================================================================
def draw_mandibles_and_thrusters(c):
    r = 1
    pal = PALETTES[c]
    # Dorsal retro-thruster nozzles & plumes at top (y = 2..26)
    thruster_xs = [56, 76, 108, 128]
    plume_heights = [8, 14, 20, 18][c]
    overdrive = (c == 3)
    outer_col = CRIMSON_HOT if overdrive else TEAL_MID
    mid_col = EMBER_BRIGHT if overdrive else TEAL_GLOW
    core_col = '#ffffff'

    for tx in thruster_xs:
        # Armored thruster nozzle collar
        box(c, r, tx - 6, 18, 12, 7, OUTLINE)
        box(c, r, tx - 5, 19, 10, 5, MID_METAL)
        box(c, r, tx - 3, 19, 6, 2, STEEL_HI)
        # Plume flame rising upward from y=18
        top_y = max(1, 18 - plume_heights)
        plume_poly = [
            (tx - 4, 18),
            (tx - 6 if c >= 2 else tx - 3, (18 + top_y) // 2),
            (tx, top_y),
            (tx + 6 if c >= 2 else tx + 3, (18 + top_y) // 2),
            (tx + 4, 18),
        ]
        polygon(c, r, plume_poly, outer_col)
        inner_poly = [
            (tx - 2, 18),
            (tx, top_y + 3),
            (tx + 2, 18),
        ]
        polygon(c, r, inner_poly, mid_col)
        line(c, r, (tx, 18), (tx, top_y + 5), core_col, thickness=2)

    if overdrive:
        # Crimson overdrive side heat vents
        for vy in (36, 44, 52):
            pair_box(c, r, 30, vy, 14, 4, OUTLINE)
            pair_box(c, r, 31, vy + 1, 12, 2, CRIMSON_HOT)
            pair_box(c, r, 33, vy + 1, 8, 1, EYE_GLINT)

    # Articulated Siege Mandibles (lower flanks & jaw pincers y = 68..116)
    # Poses:
    # c=0: closed/neutral pose
    # c=1: half-open pose
    # c=2: wide-flared attack/roar pose
    # c=3: locked/clamped heavy siege pose
    if c == 0:
        jaw_outer = [(58, 76), (48, 94), (66, 112), (78, 110), (66, 94), (68, 78)]
        jaw_inner = [(60, 79), (52, 93), (67, 108), (74, 107), (63, 93), (65, 80)]
        tooth_pts = [((64, 92), (70, 95)), ((66, 99), (73, 101))]
    elif c == 1:
        jaw_outer = [(56, 76), (38, 94), (52, 114), (64, 112), (54, 94), (66, 78)]
        jaw_inner = [(58, 79), (42, 93), (53, 110), (60, 109), (51, 93), (63, 80)]
        tooth_pts = [((52, 92), (60, 94)), ((54, 100), (62, 102))]
    elif c == 2:
        jaw_outer = [(52, 74), (20, 90), (26, 114), (40, 112), (38, 92), (62, 78)]
        jaw_inner = [(54, 77), (25, 90), (29, 110), (37, 109), (35, 91), (59, 80)]
        tooth_pts = [((36, 90), (46, 94)), ((34, 99), (44, 103))]
    else:
        jaw_outer = [(60, 76), (52, 96), (76, 115), (90, 114), (74, 96), (70, 78)]
        jaw_inner = [(62, 79), (56, 95), (77, 111), (86, 110), (71, 95), (67, 80)]
        tooth_pts = [((71, 94), (80, 96)), ((75, 102), (84, 104))]

    # Mount hinge housing
    pair_box(c, r, 50, 70, 18, 10, OUTLINE)
    pair_box(c, r, 52, 72, 14, 6, MID_METAL)
    pair_box(c, r, 54, 73, 10, 3, STEEL_HI)

    # Mandible blades
    outlined_pair_poly(c, r, jaw_outer, pal['shadow'])
    pair_poly(c, r, jaw_inner, pal['base'])
    pair_line(c, r, jaw_inner[0], jaw_inner[1], pal['spec'])
    pair_line(c, r, jaw_inner[1], jaw_inner[2], pal['hi'])

    # Serrated plasma-heated inner teeth
    for p0, p1 in tooth_pts:
        pair_line(c, r, p0, p1, OUTLINE, thickness=3)
        pair_line(c, r, p0, p1, EYE_GOLD if c < 2 else CRIMSON_HOT, thickness=2)
        pair_dot(c, r, p1[0], p1[1], '#ffffff')


# =============================================================================
# ROW 2: ANIMATED SUB-COMPONENTS (TURRETS, CORE & SHUTTERS)
# =============================================================================
def draw_turrets_core_shutters(c):
    r = 2
    pal = PALETTES[c]

    if c < 3:
        # Cols 0..2: Dual-barrel ventral plasma turrets (left/center/right angle)
        # + pulsing brood core frames 0..2
        angle_dx = [-8, 0, 8][c]

        # Pulsing Brood Core at center (cx=92, cy=58)
        core_rx = [14, 17, 20][c]
        core_ry = [10, 12, 14][c]
        ellipse(c, r, 92, 58, core_rx + 3, core_ry + 3, OUTLINE)
        ellipse(c, r, 92, 58, core_rx, core_ry, CRIMSON_MID if c == 2 else TEAL_DARK)
        ellipse(c, r, 92, 58, core_rx - 3, core_ry - 2, EYE_ORANGE if c == 2 else TEAL_MID)
        ellipse(c, r, 92, 58, core_rx - 6, core_ry - 4, EYE_GOLD if c == 2 else TEAL_GLOW)
        ellipse(c, r, 92, 58, max(3, core_rx - 10), max(2, core_ry - 7), '#ffffff')

        # Radiating energy veins around core
        for i in range(8):
            ang = i * math.pi / 4 + c * 0.25
            vx0 = round(92 + math.cos(ang) * (core_rx - 2))
            vy0 = round(58 + math.sin(ang) * (core_ry - 2))
            vx1 = round(92 + math.cos(ang) * (core_rx + 8))
            vy1 = round(58 + math.sin(ang) * (core_ry + 6))
            line(c, r, (vx0, vy0), (vx1, vy1), OUTLINE, thickness=3)
            line(c, r, (vx0, vy0), (vx1, vy1), EYE_GOLD if i % 2 == 0 else TEAL_GLOW)

        # Dual-barrel ventral plasma turrets at left (x=46) and right (x=138), y=76
        for tx in (46, 138):
            # Armored turret cupola
            ellipse(c, r, tx, 76, 11, 9, MID_METAL, outline=OUTLINE)
            ellipse(c, r, tx, 75, 8, 6, LIGHT_METAL)
            box(c, r, tx - 4, 72, 8, 2, STEEL_HI)
            # Twin barrels angled by angle_dx
            for barrel_off in (-3, 3):
                bx0 = tx + barrel_off
                by0 = 78
                bx1 = bx0 + angle_dx
                by1 = 98
                line(c, r, (bx0, by0), (bx1, by1), OUTLINE, thickness=4)
                line(c, r, (bx0, by0), (bx1, by1), LIGHT_METAL, thickness=2)
                # Glowing muzzle tip
                ellipse(c, r, bx1, by1, 3, 3, EYE_ORANGE, outline=OUTLINE)
                dot(c, r, bx1, by1, '#ffffff')
    else:
        # Col 3: Heavy armored bay shutter doors & hydraulic lock clamps
        # Left Aux Bay Shutter (x=46, y=76), Main Bay Shutter (x=92, y=78), Right Aux Bay Shutter (x=138, y=76)
        shutters = [
            (46, 76, 22, 16),
            (92, 78, 32, 20),
            (138, 76, 22, 16),
        ]
        for sx, sy, sw, sh in shutters:
            x0 = sx - sw // 2
            y0 = sy - sh // 2
            box(c, r, x0 - 2, y0 - 2, sw + 4, sh + 4, OUTLINE)
            box(c, r, x0, y0, sw, sh, MID_METAL)
            # Interlocking horizontal blast door leaves
            mid_y = sy
            box(c, r, x0, y0, sw, sh // 2 - 1, LIGHT_METAL)
            box(c, r, x0, mid_y + 1, sw, sh // 2 - 1, DARK_METAL)
            box(c, r, x0, mid_y - 1, sw, 2, OUTLINE)
            # Hazard chevrons & hydraulic lock clamps
            for hx in range(x0 + 3, x0 + sw - 3, 5):
                box(c, r, hx, mid_y - 3, 3, 2, EYE_GOLD)
                box(c, r, hx, mid_y + 2, 3, 2, CRIMSON_HOT)
            # Side hydraulic clamps
            box(c, r, x0 - 3, sy - 4, 4, 8, OUTLINE)
            box(c, r, x0 - 2, sy - 3, 2, 6, STEEL_HI)
            box(c, r, x0 + sw - 1, sy - 4, 4, 8, OUTLINE)
            box(c, r, x0 + sw, sy - 3, 2, 6, STEEL_HI)


# =============================================================================
# ROW 3: PROGRESSIVE BATTLE DAMAGE & DESTRUCTION WRECKAGE
# =============================================================================
def draw_damage_and_wreckage(c):
    r = 3
    if c == 0:
        # Col 0: Cracked carapace & scorched hull fissures (moderate damage)
        fissures = [
            [(64, 32), (72, 44), (68, 56), (78, 66)],
            [(118, 30), (110, 44), (116, 54), (104, 68)],
            [(40, 48), (52, 58), (44, 70)],
            [(142, 46), (130, 58), (138, 70)],
        ]
        for path in fissures:
            for i in range(len(path) - 1):
                line(c, r, path[i], path[i + 1], SCORCH_DARK, thickness=5)
                line(c, r, path[i], path[i + 1], CRIMSON_DARK, thickness=3)
                line(c, r, path[i], path[i + 1], EMBER_BRIGHT, thickness=1)
        # Scorch craters
        for cx, cy, rad in [(58, 44, 5), (124, 48, 6), (88, 38, 5), (96, 72, 6)]:
            ellipse(c, r, cx, cy, rad, rad - 1, SCORCH_DARK, outline=OUTLINE)
            ellipse(c, r, cx, cy, rad - 2, rad - 3, CRIMSON_HOT)
            dot(c, r, cx, cy, EYE_GLINT)

    elif c == 1:
        # Col 1: Shattered armor plates & exposed glowing rib-core (critical damage)
        ellipse(c, r, 92, 58, 32, 22, SCORCH_DARK, outline=OUTLINE)
        ellipse(c, r, 92, 58, 26, 17, CRIMSON_DARK)
        ellipse(c, r, 92, 58, 20, 12, CRIMSON_HOT)
        ellipse(c, r, 92, 58, 12, 7, EYE_GOLD)
        # Structural metallic ribs across exposed core cavern
        for rx in (-18, -10, -3, 3, 10, 18):
            line(c, r, (92 + rx, 40), (92 + rx // 2, 76), OUTLINE, thickness=3)
            line(c, r, (92 + rx, 40), (92 + rx // 2, 76), MID_METAL, thickness=1)
        # Jagged radiating plasma fractures
        for ang_deg in (20, 55, 125, 160, 205, 240, 300, 335):
            ang = math.radians(ang_deg)
            p0 = (round(92 + math.cos(ang) * 20), round(58 + math.sin(ang) * 14))
            p1 = (round(92 + math.cos(ang) * 52), round(58 + math.sin(ang) * 34))
            line(c, r, p0, p1, SCORCH_DARK, thickness=4)
            line(c, r, p0, p1, CRIMSON_HOT, thickness=2)
            line(c, r, p0, p1, EYE_GLINT, thickness=1)

    elif c == 2:
        # Col 2: Detached left wing/mandible wreckage chunk + spinning armor shrapnel
        pal = PALETTES[2]
        chunk_pts = [(14, 42), (48, 28), (68, 46), (62, 78), (30, 88), (10, 66)]
        polygon(c, r, chunk_pts, pal['deep'])
        for i in range(len(chunk_pts)):
            line(c, r, chunk_pts[i], chunk_pts[(i + 1) % len(chunk_pts)], OUTLINE, thickness=2)
        inner_chunk = [(20, 46), (46, 34), (60, 48), (54, 72), (32, 80)]
        polygon(c, r, inner_chunk, pal['shadow'])
        # Molten torn edge on right side of left wing chunk
        line(c, r, (48, 28), (68, 46), CRIMSON_HOT, thickness=3)
        line(c, r, (68, 46), (62, 78), EMBER_BRIGHT, thickness=2)
        # Detached mandible piece & spinning armor shrapnel
        shrapnel = [
            [(88, 30), (102, 24), (108, 38), (92, 42)],
            [(122, 48), (138, 42), (144, 56), (128, 60)],
            [(82, 74), (98, 68), (104, 86), (86, 92)],
            [(134, 76), (154, 70), (150, 90), (132, 88)],
        ]
        for s_pts in shrapnel:
            polygon(c, r, s_pts, pal['base'])
            for i in range(len(s_pts)):
                line(c, r, s_pts[i], s_pts[(i + 1) % len(s_pts)], OUTLINE)
            dot(c, r, s_pts[0][0] + 3, s_pts[0][1] + 2, EYE_GOLD)

    else:
        # Col 3: Detached right wing/mandible wreckage chunk + core meltdown fissure overlay
        pal = PALETTES[3]
        chunk_pts = [(170, 42), (136, 28), (116, 46), (122, 78), (154, 88), (174, 66)]
        polygon(c, r, chunk_pts, pal['deep'])
        for i in range(len(chunk_pts)):
            line(c, r, chunk_pts[i], chunk_pts[(i + 1) % len(chunk_pts)], OUTLINE, thickness=2)
        inner_chunk = [(164, 46), (138, 34), (124, 48), (130, 72), (152, 80)]
        polygon(c, r, inner_chunk, pal['shadow'])
        line(c, r, (136, 28), (116, 46), CRIMSON_HOT, thickness=3)
        line(c, r, (116, 46), (122, 78), EYE_GOLD, thickness=2)

        # Core meltdown supernova fissure overlay centered at (74, 60)
        ellipse(c, r, 74, 60, 24, 18, CRIMSON_HOT, outline=OUTLINE)
        ellipse(c, r, 74, 60, 16, 12, EYE_GOLD)
        ellipse(c, r, 74, 60, 9, 6, '#ffffff')
        for i in range(12):
            ang = i * math.pi / 6
            x1 = round(74 + math.cos(ang) * (36 if i % 2 == 0 else 24))
            y1 = round(60 + math.sin(ang) * (28 if i % 2 == 0 else 18))
            line(c, r, (74, 60), (x1, y1), EYE_GOLD if i % 2 == 0 else CRIMSON_HOT, thickness=2)
            dot(c, r, x1, y1, '#ffffff')


for col in range(4):
    draw_carrier_hull(col)
    draw_mandibles_and_thrusters(col)
    draw_turrets_core_shutters(col)
    draw_damage_and_wreckage(col)


def chunk(kind, payload):
    return (struct.pack('!I', len(payload)) + kind + payload +
            struct.pack('!I', zlib.crc32(kind + payload)))


raw = b''.join(b'\0' + pixels[y * WIDTH * 4:(y + 1) * WIDTH * 4]
               for y in range(HEIGHT))
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('!IIBBBBB', WIDTH, HEIGHT, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
target = Path(__file__).resolve().parents[1] / 'assets/images/boss-carrier.png'
target.write_bytes(png)
print(f'Generated {target}: {WIDTH}x{HEIGHT}, {len(png)} bytes')
