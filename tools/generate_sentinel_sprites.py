"""Original sentinel and damage-effect atlas (128x64 logical cells, 1x).

    .cache/asset-venv/bin/python tools/generate_sentinel_sprites.py

Writes assets/images/sentinel-effects.png: eight 128x64 columns, fourteen
rows (contract in plan/sprite-atlas.md). Rows 0-9 keep the meaning they had
on the old 64x32 grid so renderer lookups are unchanged; rows 10-13 add hit
flashes, escalated smoke/fire and sentinel weapon fire. Shapes are authored
here; no source-game sprite or third-party art is used.
"""
from __future__ import annotations

import math

from sprite_kit import ROOT, Atlas, Canvas, lerp_pt, polar

W, H = 128, 64
CX = 64.0

PAL = {
    False: ('vio0', 'vio1', 'vio2', 'vio3'),   # shield sentinel
    True: ('gol0', 'gol1', 'gol2', 'gol3'),    # armoured sentinel
}

# (humerus, forearm, primary fan start, fan spread, primary length scale)
# Eight poses: slow heavy stroke; roots, forearms and primaries articulate
# separately so the span stays broad while the segments change direction.
STROKE = [
    (30, 44, 70, 13, 1.00),   # 0 raised
    (18, 24, 44, 12, 1.00),   # 1 opening
    (6, 4, 18, 11, 1.00),     # 2 level, full span
    (-6, -12, -2, 10, 0.98),  # 3 driving
    (-16, -26, -22, 9, 0.92),  # 4 low
    (-8, -10, -48, 7, 0.80),  # 5 recovery, primaries trail
    (8, 14, -40, 7, 0.82),    # 6 rising, wrist leads
    (22, 34, 30, 11, 0.92),   # 7 unfolding
]
WARNING = [(34, 56, 86, 10, 0.96), (36, 60, 92, 10, 0.94), (34, 58, 88, 11, 0.98), (32, 54, 84, 11, 1.0)]
CHARGE = [(40, 70, 100, 8, 0.90), (44, 74, 104, 8, 0.88), (42, 72, 102, 7, 0.92), (46, 76, 106, 7, 0.90)]
DIVE = [(-24, -52, -82, 6, 0.88), (-22, -50, -80, 6, 0.90), (-26, -54, -84, 6, 0.86), (-23, -51, -81, 6, 0.89)]
RUSH = [(-40, -72, -96, 3, 0.70), (-42, -74, -98, 3, 0.68), (-40, -72, -96, 3, 0.72), (-41, -73, -97, 3, 0.69)]

SHOULDER = (55.0, 25.0)
L_HUM, L_FORE = 13.0, 16.0
PRIMARY = (24.0, 25.0, 24.0, 22.0, 19.0, 16.0)


def wing(cv: Canvas, pose, heavy, mirror, alert=False, glow=None):
    d, m, b, l = PAL[heavy]
    a1, a2, fan, spread, scale = pose
    s = SHOULDER if not mirror else (128 - SHOULDER[0], SHOULDER[1])
    e = polar(s, a1, L_HUM, mirror)
    w = polar(e, a2, L_FORE, mirror)
    # Primary feathers fan from the wrist; secondaries hang from the arm.
    tips = [polar(w, fan - k * spread, ln * scale, mirror) for k, ln in enumerate(PRIMARY)]
    secs = []
    for k in range(6):
        root = lerp_pt(s, w, .25 + k * .14)
        drop = a2 - 78 - k * 3 if k > 2 else a1 - 82 - k * 3
        secs.append(polar(root, drop, 13 + k * 1.4, mirror))
    body_edge = (s[0] + (3 if not mirror else -3), s[1] + 12)
    # Covert sheet: one broad surface from shoulder to wrist to the trailing
    # secondaries, so the wing has area, not just bones.
    cv.poly([s, e, w, tips[-1]] + secs[::-1] + [body_edge], 'ink')
    cv.poly([s, e, w, lerp_pt(w, tips[-1], .6)] + [lerp_pt(q, s, .08) for q in secs[::-1]] + [body_edge], m)
    cv.poly([s, e, w, lerp_pt(w, secs[-1], .45), lerp_pt(s, secs[0], .45)], b)
    # Secondary feather edges (segment separation lines).
    for k, q in enumerate(secs):
        root = lerp_pt(s, w, .25 + k * .14)
        cv.line(lerp_pt(root, q, .3), q, d if k % 2 else 'ink2')
    for k, tip in enumerate(tips):
        cv.line(w, tip, 'ink', 4)
    for k, tip in enumerate(tips):
        mid = lerp_pt(w, tip, .55)
        cv.line(w, tip, b if k % 2 == 0 else m, 2)
        cv.line(mid, tip, l if k % 2 == 0 else b)
        if heavy or alert:
            cv.px(tip[0], tip[1], 'ivory' if not alert else ('fire1' if k % 2 else 'eye_r'))
    # Arm: thick armoured leading edge.
    cv.line(s, e, 'ink', 5)
    cv.line(e, w, 'ink', 4)
    cv.line(s, e, m, 3)
    cv.line(e, w, m, 2)
    cv.line(s, e, l)
    if heavy:
        mid = lerp_pt(s, e, .5)
        cv.ellipse(mid[0], mid[1], 3, 2.5, 'gol3')
        cv.ellipse(w[0], w[1], 2, 2, 'met2')
    if glow:
        cv.ellipse(w[0], w[1], 1.6, 1.6, glow)
    return tips


def body(cv: Canvas, heavy, stance=None, frame=0, fire=0):
    d, m, b, l = PAL[heavy]
    alert = stance is not None
    hot = 'eye_r' if stance in ('warning', 'charge') else ('cor2' if stance == 'rush' else None)
    # Tapered feathered abdomen and tail fan.
    cv.poly([(56, 30), (72, 30), (70, 44), (66, 52), (62, 52), (58, 44)], 'ink')
    cv.poly([(58, 31), (70, 31), (68, 43), (65, 50), (63, 50), (60, 43)], m)
    for k in range(5):
        x = 59 + k * 2.5
        cv.line((x, 46), (x + (k - 2) * 1.2, 56), 'ink', 2)
        cv.line((x, 47), (x + (k - 2) * 1.2, 55), b if k % 2 else m)
    # Broad shoulders and chest.
    cv.poly([(49, 25), (55, 20.5), (73, 20.5), (79, 25), (80, 30), (74, 36.5), (54, 36.5), (48, 30)], 'ink')
    cv.poly([(51, 25), (56, 22), (72, 22), (77, 25), (78, 29.5), (73, 35), (55, 35), (50, 29.5)], b)
    cv.ellipse(64, 30.5, 6.5, 4.5, l if not heavy else 'gol3')
    for f in ((lambda x: x), (lambda x: 128 - x)):
        cv.line((f(53), 27), (f(57), 33), m)  # pectoral feather seams
    # Rank insignia on the chest: violet crescent / gold sunburst.
    if heavy:
        cv.ellipse(64, 30, 2.5, 2.5, 'blood')
        for a in range(8):
            ang = a * math.pi / 4
            cv.px(64 + math.cos(ang) * 4, 30 + math.sin(ang) * 4, 'gol1')
    else:
        cv.poly([(60, 29), (64, 32), (68, 29), (66, 31.5), (64, 33), (62, 31.5)], 'vio0')
    # Head with swept horns.
    cv.poly([(58, 14), (61, 10), (67, 10), (70, 14), (70, 20), (67, 24), (61, 24), (58, 20)], 'ink')
    cv.poly([(59.5, 14), (62, 11.5), (66, 11.5), (68.5, 14), (68.5, 19.5), (66, 22.5), (62, 22.5), (59.5, 19.5)], b)
    for f in ((lambda x: x), (lambda x: 128 - x)):
        cv.poly([(f(60), 13), (f(55), 6), (f(54), 2), (f(57), 5), (f(62), 11)], 'ink')
        cv.poly([(f(60), 12), (f(56), 6), (f(55.5), 4), (f(58), 6.5), (f(61.5), 11)], 'ivory')
    if heavy:
        cv.rect(60, 8, 8, 3, 'gol2')  # crowned helm
        cv.rect(62, 5, 4, 3, 'gol3')
        cv.px(63, 6, 'blood'); cv.px(64, 6, 'blood')
    # Eyes and beak.
    eye = hot or 'ivory'
    cv.rect(60.5, 15, 3, 2, eye); cv.rect(64.5, 15, 3, 2, eye)
    cv.px(61.5, 15, 'white' if not hot else 'fire1'); cv.px(65.5, 15, 'white' if not hot else 'fire1')
    beak = 'fire1' if fire == 2 else ('fire2' if fire else 'gol2')
    cv.poly([(62, 19), (66, 19), (64, 24 + (2 if stance in ('dive', 'rush') else 0))], beak)
    if fire == 2:
        cv.rect(63, 21, 2, 2, 'fire0')
    # Talons.
    for f in ((lambda x: x), (lambda x: 128 - x)):
        reach = 4 if stance in ('dive', 'rush') else 0
        cv.line((f(59), 36), (f(57), 40 + reach), 'ink', 2)
        cv.px(f(57), 41 + reach, 'ivory'); cv.px(f(56), 41 + reach, 'ivory')
    # Stance cues on the creature itself (no arrows).
    if stance == 'warning':
        cv.rect(58, 15, 12, 1, 'eye_r' if frame % 2 else 'fire1')
    if stance == 'charge':
        cv.rect(60, 8 - frame % 2, 8, 1, 'cor2')  # crest flares upward
        for f in ((lambda x: x), (lambda x: 128 - x)):
            cv.rect(min(f(52), f(54)), 26 + frame, 2, 4, 'cor2')  # shoulder vents
    if stance == 'rush':
        for f in ((lambda x: x), (lambda x: 128 - x)):
            cv.rect(min(f(50), f(51)), 28 + frame, 1, 6, 'cor2')
        cv.poly([(62, 52), (66, 52), (64, 60 + frame % 2)], 'cor2')


def sentinel(heavy, pose, stance=None, frame=0, fire=0):
    cv = Canvas(W, H)
    glow = 'eye_r' if stance in ('warning', 'charge') and frame % 2 else None
    for mirror in (False, True):
        wing(cv, pose, heavy, mirror, alert=stance in ('warning', 'charge'), glow=glow)
    body(cv, heavy, stance, frame, fire)
    cv.outline('ink')
    d, m, b, l = PAL[heavy]
    cv.rim({b: (l, m), m: (b, d)})
    return cv


def flash(cv: Canvas, heavy):
    d, m, b, l = PAL[heavy]
    out = cv.copy()
    out.map_colors({l: 'white', b: 'ivory', m: l, d: b, 'met2': 'white', 'gol3': 'white'})
    return out


# ---------------------------------------------------------------------------
# Shield envelopes and armour layers (row 2).
# ---------------------------------------------------------------------------
def shield_envelope(state):
    cv = Canvas(W, H)
    extent = [58, 50, 42, 34][state]
    for tier in range(3):
        y = 54 + tier * 2
        width = extent - tier * 6
        for x in range(int(CX - width), int(CX + width)):
            if (x // 6 + tier) % 3 != 1 or state == 0:
                cv.rect(x, y, 1, 2, 'mint' if tier == 0 else 'teal1')
    for side in (-1, 1):
        x = CX + side * extent - (1 if side > 0 else 0)
        cv.rect(x, 40 + state * 2, 2, 14 - state * 2, 'mint')
        cv.rect(x - side * 2, 36 + state * 2, 2, 6, 'teal1')
        cv.rect(CX + side * (extent - 4) - 1, 32 + state * 2, 3, 3, 'mint')
        cv.px(CX + side * (extent - 4), 33 + state * 2, 'white')
    return cv


def armor_layer(i):
    """Four armour layers (chest, gorget, shoulders, outer pauldrons):
    shaped metal plates with gold trim and rivets, readable on both the
    violet and the gold sentinel."""
    cv = Canvas(W, H)
    mir = ((lambda x: x), (lambda x: 128 - x))
    if i == 0:
        cv.poly([(58.5, 28.5), (69.5, 28.5), (68.5, 35), (64, 38.5), (59.5, 35)], 'met2')
        cv.line((59.5, 29), (68.5, 29), 'met3')
        cv.line((60, 34.5), (64, 38), 'gol2'); cv.line((68, 34.5), (64, 38), 'gol2')
        cv.px(64, 32, 'gol3')
    elif i == 1:
        cv.poly([(58, 21.5), (70, 21.5), (68.5, 25.5), (59.5, 25.5)], 'met1')
        cv.line((59, 22), (69, 22), 'gol2')
        cv.px(61, 24, 'met3'); cv.px(67, 24, 'met3')
    elif i == 2:
        for f in mir:
            cv.poly([(f(48.5), 24.5), (f(54.5), 20.5), (f(57.5), 26.5), (f(51.5), 29.5)], 'met2')
            cv.line((f(49.5), 24.5), (f(54.5), 21.5), 'met3')
            cv.line((f(51.5), 29), (f(57), 26.5), 'gol2')
            cv.px(f(53), 25, 'gol3')
    else:
        for f in mir:
            cv.poly([(f(41), 23), (f(46.5), 20), (f(48.5), 25), (f(43), 27.5)], 'met1')
            cv.line((f(42), 23), (f(46.5), 21), 'met2')
            cv.px(f(45), 23.5, 'gol2')
    cv.outline('ink')
    return cv


# ---------------------------------------------------------------------------
# Smoke, flame, sparks, destruction.
# ---------------------------------------------------------------------------
def smoke(frame, heavy=False):
    cv = Canvas(W, H)
    dark, mid, light = ('smk0', 'ink2', 'smk1') if heavy else ('smk1', 'smk2', 'smk3')
    for y in range(8, 58):
        rise = 57 - y
        center = CX + round(math.sin((rise + frame * 5) * .21) * (2 + rise / 7))
        radius = 3 + rise // 7 + ((y + frame) % 5 == 0)
        for x in range(int(center - radius), int(center + radius + 1)):
            edge = abs(x - center)
            if y < 20 and (x * 3 + y + frame * 2) % 5 < 2:
                continue  # dissolving dithered top
            if edge >= radius and (x + y + frame) % 3:
                continue
            col = dark if x > center else mid
            if x <= center - radius + 1 and (y + frame) % 3:
                col = light
            cv.px(x, y, col)
    return cv


def flame(frame, big=False):
    cv = Canvas(W, H)
    span = 9 if big else 6
    for x in range(-span, span + 1):
        hgt = [10, 16, 24, 14, 32, 20, 26, 16, 22, 12, 8, 18, 28, 15, 11, 19, 9, 13, 21][(x + span + frame * 3) % 19]
        if big:
            hgt = int(hgt * 1.3)
        col = CX + x
        cv.rect(col, 58 - hgt, 1, hgt, 'fire5')
        cv.rect(col, 60 - hgt, 1, max(1, hgt - 4), 'fire4')
        if abs(x) < span - 2:
            cv.rect(col, 56 - hgt * 2 // 3, 1, hgt * 2 // 3, 'fire3')
        if abs(x) < span // 2:
            cv.rect(col, 54 - hgt // 3, 1, hgt // 3 + 4, 'fire2')
        if abs(x) < 2:
            cv.rect(col, 52, 1, 6, 'fire0')
    # Shed embers.
    for i in range(4):
        cv.px(CX + ((i * 7 + frame * 5) % 15) - 7, 20 - ((i * 9 + frame * 6) % 14), 'fire1')
    return cv


def sparks(frame):
    cv = Canvas(W, H)
    for i in range(8):
        ang = i * math.pi / 4 + (.39 if frame % 2 else 0)
        r0, r1 = 3 + frame * 6, 7 + frame * 7
        cv.line((CX + math.cos(ang) * r0, 32 + math.sin(ang) * r0 * .8),
                (CX + math.cos(ang) * r1, 32 + math.sin(ang) * r1 * .8),
                'ivory' if frame < 2 else 'gol2', 2 if frame < 2 else 1)
    return cv


def debris(frame):
    """Hull plate debris tumbling out of a carrier wound (4 frames)."""
    cv = Canvas(W, H)
    for i in range(6):
        ang = i * math.pi / 3 + frame * .5
        dist = 8 + frame * 7
        x = CX + math.cos(ang) * dist
        y = 32 + math.sin(ang) * dist * .6 + frame * frame
        size = 4 - frame // 2
        cv.poly([(x, y - size), (x + size, y), (x, y + size * .6), (x - size, y)], ['met1', 'met2', 'smk1'][i % 3])
        cv.px(x, y - size + 1, 'fire1' if frame < 2 else 'fire4')
    cv.outline('ink')
    return cv


def destruction(frame, base_pose=STROKE[2]):
    """Wing breakup: feathers separate, fracture and become embers."""
    cv = Canvas(W, H)
    whole = sentinel(False, base_pose)
    if frame == 0:
        return flash(whole, False)
    import numpy as np
    src = whole.a
    ys, xs = np.nonzero(src[..., 3])
    for y, x in zip(ys, xs):
        side = -1 if x < CX else 1
        tier = int(abs(x - CX) // 10)
        if (x // 3 + y // 3 + frame) % (9 - frame) == 0 and frame > 3:
            continue
        dx = side * (frame * (1 + tier) * .9)
        dy = frame * frame * .35 + ((x // 7) % 3) * frame * .6
        nx, ny = int(x + dx), int(y + dy)
        if 0 <= nx < W and 0 <= ny < H:
            col = src[y, x].copy()
            if frame >= 4 and (x + y) % 3 == 0:
                col[:3] = (255, 107, 26)
            if frame >= 6 and (x + y) % 2:
                continue
            cv.a[ny, nx] = col
    if frame < 5:
        r = [0, 6, 10, 13, 12][frame]
        cv.ellipse(CX, 30, r, r * .7, 'fire3')
        cv.ellipse(CX, 30, r * .6, r * .45, 'fire1')
        cv.ellipse(CX, 30, r * .3, r * .22, 'fire0')
    return cv


def muzzle(frame, heavy):
    """Sentinel beak bolt discharge, on the full pose so it can replace the
    hover frame for a beat."""
    pose = STROKE[[2, 2, 3, 2][frame]]
    return sentinel(heavy, pose, fire=[1, 2, 1, 0][frame])


def build():
    a = Atlas(8, 14, W, H)
    for heavy in (False, True):
        r = int(heavy)
        for c in range(8):
            cv = sentinel(heavy, STROKE[c])
            a.put(c, r, cv)
            a.put(c, 10 + r, flash(cv, heavy))
        for f in range(4):
            a.put(f, 6 + r, sentinel(heavy, CHARGE[f], 'charge', f))
            a.put(4 + f, 6 + r, sentinel(heavy, RUSH[f], 'rush', f))
            a.put(f, 8 + r, sentinel(heavy, WARNING[f], 'warning', f))
            a.put(4 + f, 8 + r, sentinel(heavy, DIVE[f], 'dive', f))
            a.put(f + 4 * r, 13, muzzle(f, heavy))
    for s in range(4):
        a.put(s, 2, shield_envelope(s))
        a.put(4 + s, 2, armor_layer(s))
        a.put(s, 3, smoke(s))
        a.put(4 + s, 3, flame(s))
        a.put(s, 5, sparks(s))
        a.put(4 + s, 5, debris(s))
        a.put(s, 12, smoke(s, heavy=True))
        a.put(4 + s, 12, flame(s, big=True))
    for c in range(8):
        a.put(c, 4, destruction(c))
    a.save(ROOT / 'assets/images/sentinel-effects.png')


if __name__ == '__main__':
    build()
