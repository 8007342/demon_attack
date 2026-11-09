"""Original deterministic ship, cannon, muzzle and shot atlas (64x64 grid).

    .cache/asset-venv/bin/python tools/generate_ship_sprites.py

Writes assets/images/ship-weapons.png and ship-weapons.json. Each 64x64
cell is a full layer centred on the ship (logical (32, 32) = ship centre)
and is drawn at 48x48 arena units, so 1 logical px = 0.75 units. Wing
cannons are authored on the LEFT only; the renderer mirrors them for the
right wing so alternating shots kick the side that fired.

Muzzle anchors are fixed by gameplay: the projectile spawn points the
research branch established (ship-parts.json wing_muzzles / nose_muzzle)
are copied unchanged into ship-weapons.json, and the art below is built
around them. The hull silhouette and palette follow the user-selected
hull candidate (hull-I2-820000-0): dark navy delta, long spine, teal
panels.
"""
from __future__ import annotations

import json
import math

from sprite_kit import ROOT, Atlas, Canvas

UNITS_PER_PX = 0.75
C = 32.0


def to_px(units_x, units_y):
    return (C + units_x / UNITS_PER_PX, C + units_y / UNITS_PER_PX)


# Gameplay anchors (arena units from the ship centre). Do not change: they
# are where projectiles spawn (test/wing_cannons_test.dart).
WING_MUZZLES = {'rapid': (-15.5, -10.0), 'powerful': (-17.0, -13.0)}
NOSE_MUZZLE = (0.0, -10.0)
RAPID_M = to_px(*WING_MUZZLES['rapid'])      # (11.3, 18.7)
POWER_M = to_px(*WING_MUZZLES['powerful'])   # (9.3, 14.7)
NOSE_M = to_px(*NOSE_MUZZLE)                 # (32, 18.7)
SPREAD_M = to_px(-5, -8)                     # spread pair spawn (x mirrored)

ROWS = {'hull': 0, 'spread': 1, 'rapid': 2, 'shield': 3, 'powerful': 4, 'large': 5, 'shots': 6, 'homing': 7}
MIR = ((lambda x: x), (lambda x: 64 - x))

HULL_RIM = {'hul2': ('hul3', 'hul1'), 'teal2': ('teal3', 'teal1'), 'hul1': (None, 'hul0')}


def hull(flash=False):
    cv = Canvas()
    for f in MIR:
        # Swept delta wings with teal panels and a wingtip fence.
        cv.poly([(f(29), 31), (f(18), 39), (f(10), 44), (f(8.5), 47.5), (f(12), 49), (f(22), 47), (f(29), 46)], 'hul2')
        cv.poly([(f(27.5), 35), (f(19), 41), (f(13), 45), (f(20), 45), (f(27.5), 43)], 'teal2')
        cv.line((f(26), 38), (f(15), 45), 'teal1')
        cv.rect(min(f(8.5), f(10.5)), 43, 2, 6, 'hul1')  # wingtip fence
        cv.px(f(9.5), 43, 'mint')                        # nav light
        # Canard fins near the nose.
        cv.poly([(f(29.5), 24), (f(25.5), 29), (f(29.5), 29)], 'hul1')
    # Long spine fuselage.
    cv.poly([(32, 17), (34, 20), (35.5, 27), (36.5, 38), (36, 49), (34.5, 53), (29.5, 53), (28, 49), (27.5, 38),
             (28.5, 27), (30, 20)], 'hul2')
    cv.poly([(32, 21), (33.5, 27), (33.5, 47), (30.5, 47), (30.5, 27)], 'hul1')
    # Canopy with a top-left glint.
    cv.ellipse(32, 30.5, 2.2, 4.2, 'cyan')
    cv.rect(31, 28, 1, 2, 'white')
    cv.rect(32, 33, 1, 1, 'sky')
    # Dorsal teal stripe and engine nozzles.
    cv.rect(31.5, 36, 1, 9, 'teal2')
    for x in (29.5, 33):
        cv.rect(x, 50, 2, 3, 'met1')
        cv.rect(x, 53, 2, 1, 'ink2')
    # Nose cannon barrel (the single shooter's muzzle sits on its tip).
    cv.rect(31, NOSE_M[1] - 1, 2, 4, 'met2')
    cv.px(31, NOSE_M[1] - 1, 'met3')
    cv.outline('ink')
    cv.rim(HULL_RIM)
    if flash:
        cv.map_colors({'hul2': 'met3', 'hul1': 'met2', 'teal2': 'white', 'teal1': 'teal3', 'hul3': 'white'})
    return cv


def exhaust(frame):
    cv = Canvas()
    ln = [6, 8, 7, 9][frame]
    for x in (30.5, 34):
        cv.poly([(x - 1.5, 54), (x + 1.5, 54), (x, 54 + ln)], 'mint')
        cv.rect(x - .5, 54, 1, ln * .55, 'white')
    if frame % 2:
        cv.px(32, 56 + ln * .4, 'cyan')
    return cv


def nose_flash(frame):
    """Nose cannon fire: barrel kick, then a 4-frame star flash."""
    cv = Canvas()
    x, y = NOSE_M
    r = [5, 7, 4, 2][frame]
    if frame < 3:
        cv.poly([(x, y - r * 1.6), (x + r * .55, y - 1), (x, y + .5), (x - r * .55, y - 1)], 'mint')
        cv.poly([(x - r * .9, y - 1.5), (x, y - 2.5), (x + r * .9, y - 1.5), (x, y - .5)], 'cyan')
        cv.rect(x - 1, y - 3, 2, 2, 'white')
    else:
        cv.px(x - 1, y - 3, 'cyan'); cv.px(x, y - 5, 'mint')
    return cv


# ---------------------------------------------------------------------------
# Modules. Wear: 0 fresh, 1 worn (scorched panels), 2 critical (glowing seams).
# Recoil: kick 2 / kick 1 / settle (barrel shifted down = toward the ship).
# ---------------------------------------------------------------------------
WEAR_COLORS = [None, 'smk1', 'fire3']


def rapid_pod(wear=0, kick=0, heat=0):
    """Left rapid cannon: twin slim barrels on a gold capacitor pod."""
    cv = Canvas()
    mx, my = RAPID_M
    y0 = my + kick
    # Pylon to the wing.
    cv.poly([(mx + 2, 40), (mx + 5, 40), (mx + 7, 44), (mx + 3, 44)], 'hul1')
    # Pod body with gold capacitor rings.
    cv.poly([(mx - 2.5, y0 + 9), (mx + 2.5, y0 + 9), (mx + 3, y0 + 23), (mx + 1.5, y0 + 26), (mx - 1.5, y0 + 26),
             (mx - 3, y0 + 23)], 'hul2')
    for k in range(3):
        cv.rect(mx - 3, y0 + 12 + k * 4, 6, 1, 'gol2' if wear < 2 else ('fire2' if k % 2 else 'gol2'))
    cv.rect(mx - 1, y0 + 22, 2, 2, 'gol3')
    # Twin barrels.
    for bx in (mx - 1.5, mx + .5):
        cv.rect(bx, y0, 1, 10, 'met2')
        cv.px(bx, y0, 'met3')
    if wear >= 1:
        cv.px(mx + 1, y0 + 17, WEAR_COLORS[wear]); cv.px(mx - 2, y0 + 20, WEAR_COLORS[wear])
    if wear >= 2 or heat:
        cv.rect(mx - 1.5, y0 + 6, 3, 2, 'fire2' if heat else 'fire3')
    cv.outline('ink')
    cv.rim({'hul2': ('hul3', 'hul1'), 'gol2': ('gol3', None)})
    return cv


def powerful_pod(wear=0, kick=0, heat=0):
    """Left powerful cannon: one long heavy barrel, coral heat vents."""
    cv = Canvas()
    mx, my = POWER_M
    y0 = my + kick
    cv.poly([(mx + 3, 41), (mx + 7, 41), (mx + 9, 45), (mx + 4, 45)], 'hul1')
    # Breech block.
    cv.poly([(mx - 3.5, y0 + 16), (mx + 3.5, y0 + 16), (mx + 4, y0 + 29), (mx + 2, y0 + 32), (mx - 2, y0 + 32),
             (mx - 4, y0 + 29)], 'hul2')
    for k in range(3):
        cv.rect(mx - 4, y0 + 19 + k * 3, 2, 1, 'cor2' if wear < 2 else 'fire2')
        cv.rect(mx + 2, y0 + 19 + k * 3, 2, 1, 'cor2' if wear < 2 else 'fire2')
    # Long barrel with a muzzle brake.
    cv.rect(mx - 1, y0 + 2, 2, 15, 'met2')
    cv.rect(mx - .5, y0 + 3, 1, 13, 'met1')
    cv.rect(mx - 2, y0, 4, 3, 'met1')
    cv.px(mx - 2, y0, 'met3')
    if wear >= 1:
        cv.px(mx + 1, y0 + 26, WEAR_COLORS[wear]); cv.px(mx - 2, y0 + 12, WEAR_COLORS[wear])
    if wear >= 2 or heat:
        cv.rect(mx - 1, y0 + 8, 2, 4, 'fire2' if heat else 'cor2')
    cv.outline('ink')
    cv.rim({'hul2': ('hul3', 'hul1'), 'met2': ('met3', None)})
    return cv


def spread_module(wear=0, kick=0, heat=0):
    """Cyan prism side-emitters flanking the nose (both sides authored)."""
    cv = Canvas()
    sx, sy = SPREAD_M
    for side, f in enumerate(MIR):
        x = f(sx) if side == 0 else 64 - sx
        tilt = -1 if side == 0 else 1
        y = sy + kick
        cv.poly([(x - 2, y + 3), (x + 2, y + 3), (x + 2.5, y + 10), (x - 2.5, y + 10)], 'hul2')
        cv.poly([(x - 1.5 + tilt, y - 1), (x + 1.5 + tilt, y - 1), (x + 1.5, y + 4), (x - 1.5, y + 4)], 'mint')
        cv.px(x - .5 + tilt, y - 1, 'white')
        cv.rect(x - 2, y + 6, 4, 1, 'cyan' if wear < 2 else 'fire3')
        if wear >= 1:
            cv.px(x + 1, y + 8, WEAR_COLORS[wear])
    if heat:
        for f in MIR:
            cv.px(f(sx), sy + 1, 'fire1')
    cv.outline('ink')
    cv.rim({'hul2': ('hul3', 'hul1'), 'mint': ('white', 'cyan')})
    return cv


def large_module(wear=0, kick=0, heat=0):
    """Amber broad shell launchers on the wing roots (both sides)."""
    cv = Canvas()
    for f in MIR:
        y = 26 + kick
        x = f(23.5)
        cv.poly([(x - 3, y + 4), (x + 3, y + 4), (x + 3.5, y + 13), (x - 3.5, y + 13)], 'hul2')
        cv.ellipse(x, y + 3, 3, 3.5, 'amber')
        cv.ellipse(x - .5, y + 2, 1.4, 1.4, 'fire1')
        cv.rect(x - 3.5, y + 9, 7, 1, 'amber' if wear < 2 else 'fire3')
        if wear >= 1:
            cv.px(x + 2, y + 11, WEAR_COLORS[wear])
        if heat:
            cv.px(x, y + 3, 'fire0')
    cv.outline('ink')
    cv.rim({'hul2': ('hul3', 'hul1'), 'amber': ('fire1', 'fire3')})
    return cv


def shield_emitter(wear=0, kick=0, heat=0):
    """Violet dorsal emitter dome with a mast."""
    cv = Canvas()
    cv.ellipse(32, 41, 3.5, 2.5, 'vio1')
    cv.ellipse(32, 40.5, 2.2, 1.6, 'vio2')
    cv.px(31, 40, 'vio3')
    cv.rect(31.5, 35, 1, 4, 'met2')
    cv.px(31.5, 34, 'vio3' if wear < 2 else 'fire2')
    for f in MIR:
        cv.rect(min(f(26), f(27)), 42, 2, 2, 'vio1')
        cv.px(f(26.5), 42, 'vio2' if wear < 2 else 'fire3')
    if wear >= 1:
        cv.px(34, 42, WEAR_COLORS[wear])
    cv.outline('ink')
    return cv


def shield_bubble(stage, frame):
    """Hex-segmented force bubble. stage 0 healthy mint, 1 degrading gold,
    2 critical red. Segments blink by frame; no gradients, no vectors."""
    cv = Canvas()
    col = ['mint', 'gol2', 'eye_r'][stage]
    inner = ['teal1', 'gol1', 'blood'][stage]
    rx, ry = 31.5, 26.5
    for i in range(36):
        a = i * 2 * math.pi / 36
        if stage == 2 and (i + frame) % 5 == 0:
            continue  # critical: gaps flicker through the ring
        x = 32 + math.cos(a) * rx
        y = 32 + math.sin(a) * ry
        cv.rect(math.floor(x - .5), math.floor(y - .5), 2, 2, col)
        if (i + frame * 3) % 9 == 0:
            cv.px(x, y, 'white')
    # Inner hex lattice dots.
    for gy in range(-3, 4):
        for gx in range(-5, 6):
            x = 32 + gx * 5 + (2.5 if gy % 2 else 0)
            y = 32 + gy * 7
            if ((x - 32) / (rx - 4)) ** 2 + ((y - 32) / (ry - 4)) ** 2 < 1 and (gx + gy + frame) % 3 == 0:
                cv.px(x, y, inner)
    return cv


MODULES = {
    'spread': spread_module, 'rapid': rapid_pod, 'shield': shield_emitter,
    'powerful': powerful_pod, 'large': large_module,
}


def muzzle_flash(kind, frame):
    cv = Canvas()
    if kind in ('rapid', 'powerful'):
        x, y = RAPID_M if kind == 'rapid' else POWER_M
        hot = 'gol2' if kind == 'rapid' else 'cor2'
        r = [5, 7, 5, 2][frame] * (1.0 if kind == 'rapid' else 1.3)
        if frame < 3:
            cv.poly([(x, y - r * 1.8), (x + r * .6, y - 1), (x, y + .5), (x - r * .6, y - 1)], hot)
            cv.poly([(x - r, y - 2), (x, y - 3), (x + r, y - 2), (x, y - 1)], 'fire1')
            cv.rect(x - 1, y - 4, 2, 3, 'white')
            if kind == 'rapid':  # twin barrels: a second small spark
                cv.px(x + 1, y - 2, 'white')
        else:
            cv.px(x, y - 4, hot); cv.px(x - 1, y - 7, 'smk2'); cv.px(x + 1, y - 9, 'smk1')
    elif kind == 'spread':
        for side in (0, 1):
            x = SPREAD_M[0] if side == 0 else 64 - SPREAD_M[0]
            y = SPREAD_M[1]
            d = -1 if side == 0 else 1
            r = [4, 5, 3, 1][frame]
            if frame < 3:
                cv.poly([(x + d * r, y - r * 1.4), (x + 1, y), (x - 1, y)], 'mint')
                cv.px(x + d, y - 2, 'white')
            else:
                cv.px(x + d * 2, y - 3, 'cyan')
    elif kind == 'large':
        for x in (23.5, 40.5):
            r = [4, 6, 4, 2][frame]
            if frame < 3:
                cv.ellipse(x, 27, r * .7, r * .7, 'amber')
                cv.ellipse(x, 27, r * .4, r * .4, 'fire1')
            else:
                cv.px(x, 25, 'smk2')
    else:  # shield: emitter pulse
        r = [3, 5, 7, 8][frame]
        cv.poly([(32, 39 - r), (32 + r, 40), (32, 41 + r * .4), (32 - r, 40)], 'vio2' if frame < 2 else 'vio1')
        cv.clear(cv.ellipse_mask(32, 40, max(0, r - 2), max(0, r - 2) * .6))
    return cv


def deploy(kind, frame):
    """Power-up transition: wireframe sparkle -> half -> full with a flash."""
    full = MODULES[kind](0)
    cv = full.copy()
    o = cv.opaque()
    if frame == 0:
        # Only the outline, in mint, with scattered sparkles.
        ink = cv.is_color('ink')
        cv.a[:] = 0
        cv._paint(ink, 'mint')
        for i, (y, x) in enumerate(zip(*o.nonzero())):
            if i % 7 == 0:
                cv.px(x, y, 'white')
    elif frame == 1:
        ys = o.nonzero()[0]
        cut = ys.min() + (ys.max() - ys.min()) * .5 if len(ys) else 0
        import numpy as np
        rows = np.arange(64)[:, None] < cut
        cv.a[rows.repeat(64, 1) & o] = 0
        cv.recolor('ink', 'mint')
    elif frame == 2:
        cv.map_colors({'hul2': 'met3', 'hul1': 'met2', 'met2': 'white'})
    return cv


def detached(kind):
    """The spent module, critical and centred, for the tumbling FallingPart."""
    cv = MODULES[kind](2)
    o = cv.opaque()
    ys, xs = o.nonzero()
    if len(xs):
        cx, cy = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2
        cv.shift(int(round(32 - cx)), int(round(32 - cy)))
    return cv


def heat_overlay(kind):
    cv = MODULES[kind](2, heat=1)
    o = cv.opaque()
    keep = cv.is_color('fire2') | cv.is_color('fire3') | cv.is_color('fire1') | cv.is_color('fire0')
    cv.a[o & ~keep] = 0
    return cv


# ---------------------------------------------------------------------------
# Shots (centred at 32,32; same 0.75 units/px).
# ---------------------------------------------------------------------------
def shot(kind, frame):
    cv = Canvas()
    f = frame
    if kind == 'ordinary':
        cv.rect(31, 24, 2, 14, 'mint')
        cv.rect(31, 24, 2, 3 + f, 'white')
        cv.rect(30, 34, 4, 5 + f, 'teal1')
        cv.px(31, 41 + f, 'teal1')
    elif kind == 'rapid':
        cv.poly([(32.5, 21), (35, 28), (33, 28), (34.5, 36), (29.5, 26.5), (31.5, 26.5)], 'gol2')
        cv.rect(31.5, 23, 1, 4, 'white')
        cv.rect(31, 35, 2, 3 + f * 2, 'gol1')
        cv.outline('ink')
    elif kind == 'powerful':
        cv.rect(29.5, 24, 5, 15, 'cor2')
        cv.rect(31, 22, 2, 14, 'ivory')
        cv.rect(28.5, 36, 7, 3, 'cor1')
        cv.rect(31, 39, 2, 4 + f * 2, 'fire3')
        cv.outline('ink')
    elif kind == 'large':
        cv.ellipse(32, 31, 5.5, 7, 'amber')
        cv.ellipse(32, 29, 3, 4, 'fire1')
        cv.rect(31, 26, 2, 2, 'white')
        cv.rect(31, 38, 2, 4 + f * 2, 'fire3')
        cv.outline('ink')
    elif kind == 'spread':
        cv.poly([(32, 26), (35, 31), (32, 36), (29, 31)], 'mint')
        cv.poly([(32, 28), (33.5, 31), (32, 34), (30.5, 31)], 'white' if f == 0 else 'cyan')
    elif kind == 'hostile':
        cv.poly([(32, 27), (35.5, 31), (35, 37), (32, 39), (29, 37), (28.5, 31)], 'cor2')
        cv.rect(31, 29 + f, 2, 4, 'ivory')
        cv.outline('blood')
    elif kind == 'sentinel':
        cv.rect(29.5, 22, 5, 15, 'eye_r')
        cv.rect(27, 29, 2.5, 8, 'cor2'); cv.rect(34.5, 29, 2.5, 8, 'cor2')
        cv.rect(31, 25 + f, 2, 13, 'ivory')
        cv.rect(31, 38, 2, 3, 'eye_r')
        cv.outline('ink')
    elif kind == 'impact':
        r = [5, 8][f]
        cv.poly([(32, 32 - r), (33.5, 30.5), (32 + r, 32), (33.5, 33.5), (32, 32 + r * .6), (30.5, 33.5), (32 - r, 32),
                 (30.5, 30.5)], 'mint' if f == 0 else 'cyan')
        if f == 0:
            cv.rect(31, 31, 2, 2, 'white')
    return cv


# ---------------------------------------------------------------------------
# Homing missiles (row 7): wing pylons with up to three missiles, the missile
# in flight with a cyan exhaust, the lock-on reticle, launch flashes, the
# pylon deploy, the jettisoned pylon and the pickup badge.
# Launch order (model): left outer, right outer, left inner.
# ---------------------------------------------------------------------------
HOMING_SLOTS = ((17.5, 41), (46.5, 41), (21, 43))


def _rack_missile(cv, x, y):
    cv.rect(x - 1, y - 4, 2, 8, 'met3')
    cv.px(x - 1, y - 5, 'mint')
    cv.px(x, y - 5, 'mint')
    cv.px(x - 2, y + 2, 'hul2')
    cv.px(x + 1, y + 2, 'hul2')
    cv.px(x - 1, y + 4, 'cyan')


def homing_rack(loaded, heat=0):
    cv = Canvas()
    for f in MIR:
        cv.rect(min(f(16), f(22)), 46, 6, 2, 'hul1')  # pylon under the wing
        cv.px(f(19), 46, 'teal2')
    for i, (x, y) in enumerate(HOMING_SLOTS):
        if i >= 3 - loaded:
            _rack_missile(cv, x, y)
    cv.outline('ink')
    cv.rim({'hul1': ('hul2', 'hul0'), 'met3': ('white', 'met2')})
    return cv


def homing_missile(frame):
    """In flight, pointing up, centred at (32, 32)."""
    cv = Canvas()
    cv.rect(30.5, 25, 3, 11, 'met3')
    cv.rect(31, 23, 2, 2, 'mint')
    cv.px(31, 22, 'white')
    cv.rect(32.5, 26, 1, 9, 'met2')
    for f in MIR:
        cv.poly([(f(30.5), 31), (f(28), 36), (f(30.5), 35)], 'hul2')
    flame = 4 + frame * 2
    cv.rect(30.5, 36, 3, flame, 'cyan')
    cv.rect(31, 36, 2, flame - 2, 'white')
    cv.px(31.5, 36 + flame, 'mint')
    cv.outline('ink')
    return cv


def homing_reticle(frame):
    cv = Canvas()
    r = 11 if frame == 0 else 9
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = 32 + sx * r, 32 + sy * r
            cv.rect(min(x, x - sx * 5), y - (1 if sy > 0 else 0), 5, 2, 'mint')
            cv.rect(x - (1 if sx > 0 else 0), min(y, y - sy * 5), 2, 5, 'mint')
    cv.rect(31, 31, 2, 2, 'white' if frame else 'cyan')
    for d in (-5, 4):
        cv.px(32 + d, 32, 'cyan')
        cv.px(32, 32 + d, 'cyan')
    return cv


def homing_launch_flash(frame):
    cv = homing_rack(0)
    cv.a[:] = 0
    for f in MIR:
        x = f(19)
        r = 4 - frame
        cv.ellipse(x, 40, r, r + 1, 'cyan')
        cv.ellipse(x, 40, r - 1.5, r - 1, 'white')
    return cv


def homing_badge():
    cv = Canvas()
    cv.ellipse(32, 32, 20, 20, 'ink2')
    cv.ellipse(32, 32, 18, 18, 'deep')
    for i in range(32):
        a = i * 2 * math.pi / 32
        cv.rect(math.floor(32 + math.cos(a) * 19 - .5), math.floor(32 + math.sin(a) * 19 - .5), 2, 2,
                'mint' if i % 4 else 'white')
    for x, y in ((25, 34), (32, 30), (39, 34)):
        cv.rect(x - 1.5, y - 7, 3, 11, 'met3')
        cv.rect(x - 1, y - 9, 2, 2, 'mint')
        cv.rect(x - 1.5, y + 4, 3, 3, 'cyan')
    cv.outline('ink')
    return cv


def build():
    a = Atlas(16, 8)
    a.put(0, 0, hull())
    a.put(1, 0, hull(flash=True))
    for i in range(4):
        a.put(2 + i, 0, exhaust(i))
        a.put(6 + i, 0, nose_flash(i))
    for kind, row in ROWS.items():
        if kind in ('hull', 'shots', 'homing'):
            continue
        make = MODULES[kind]
        for wear in range(3):
            a.put(wear, row, make(wear))
        if kind == 'shield':
            # Bubble: 3 healthy shimmer, 2 degrading, 2 critical frames.
            for i in range(3):
                a.put(3 + i, row, shield_bubble(0, i))
            for i in range(2):
                a.put(6 + i, row, shield_bubble(1, i))
                a.put(8 + i, row, shield_bubble(2, i))
        else:
            for i, kick in enumerate((2, 1, 0)):
                a.put(3 + i, row, make(0, kick=kick, heat=1 if i < 2 else 0))
            for i in range(4):
                a.put(6 + i, row, muzzle_flash(kind, i))
        for i in range(4):
            a.put(10 + i, row, deploy(kind, i))
        a.put(14, row, detached(kind))
        a.put(15, row, heat_overlay(kind) if kind != 'shield' else muzzle_flash('shield', 1))
    for i, kind in enumerate(('ordinary', 'rapid', 'powerful', 'large', 'spread', 'hostile', 'sentinel', 'impact')):
        for f in range(2):
            a.put(i * 2 + f, 6, shot(kind, f))
    h = ROWS['homing']
    for loaded in range(4):
        a.put(3 - loaded, h, homing_rack(loaded))
    for f in range(2):
        a.put(4 + f, h, homing_missile(f))
        a.put(6 + f, h, homing_reticle(f))
        a.put(8 + f, h, homing_launch_flash(f))
    full = homing_rack(3)
    for i in range(4):
        cv = full.copy()
        if i == 0:
            ink = cv.is_color('ink')
            cv.a[:] = 0
            cv._paint(ink, 'mint')
        elif i == 1:
            cv.recolor('ink', 'mint')
        elif i == 2:
            cv.map_colors({'hul1': 'met3', 'met3': 'white'})
        a.put(10 + i, h, cv)
    spent = homing_rack(0)
    spent.a[:, 32:] = 0  # one empty pylon, centred, for the jettison debris
    ys, xs = spent.opaque().nonzero()
    spent.shift(int(round(32 - (xs.min() + xs.max() + 1) / 2)), int(round(32 - (ys.min() + ys.max() + 1) / 2)))
    a.put(14, h, spent)
    a.put(15, h, homing_badge())
    a.save(ROOT / 'assets/images/ship-weapons.png')
    meta = {
        'family': 'ship-weapons',
        'generator': 'tools/generate_ship_sprites.py',
        'cell': {'width': 64, 'height': 64},
        'logical': {'width': 64, 'height': 64, 'pixel_scale': 1},
        'arena_size': 48,
        'rows': ROWS,
        'columns': {
            'hull': {'hull': 0, 'hit_flash': 1, 'exhaust': [2, 5], 'nose_flash': [6, 9]},
            'module': {'wear': [0, 2], 'recoil': [3, 5], 'muzzle_flash': [6, 9], 'deploy': [10, 13],
                       'detached': 14, 'heat': 15},
            'shield': {'wear': [0, 2], 'bubble_healthy': [3, 5], 'bubble_degrading': [6, 7],
                       'bubble_critical': [8, 9], 'deploy': [10, 13], 'detached': 14, 'pulse': 15},
            'shots': {'ordinary': [0, 1], 'rapid': [2, 3], 'powerful': [4, 5], 'large': [6, 7],
                      'spread': [8, 9], 'hostile': [10, 11], 'sentinel': [12, 13], 'impact': [14, 15]},
            'homing': {'rack_loaded_3_to_0': [0, 3], 'missile': [4, 5], 'reticle': [6, 7],
                       'launch_flash': [8, 9], 'deploy': [10, 13], 'detached': 14, 'badge': 15},
        },
        'mirrored_left_only': ['rapid', 'powerful'],
        'wing_muzzles': {k: {'x': v[0], 'y': v[1]} for k, v in WING_MUZZLES.items()},
        'nose_muzzle': {'x': NOSE_MUZZLE[0], 'y': NOSE_MUZZLE[1]},
    }
    path = ROOT / 'assets/images/ship-weapons.json'
    path.write_text(json.dumps(meta, indent=2) + '\n')
    print(f'Generated {path.relative_to(ROOT)}')


if __name__ == '__main__':
    build()
