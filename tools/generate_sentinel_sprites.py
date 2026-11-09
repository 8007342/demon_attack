"""Original sentinel and damage-effect atlas (128x64 logical cells, 1x).

    python tools/generate_sentinel_sprites.py

Writes assets/images/sentinel-effects.png: eight 128x64 columns, fourteen
rows (contract in plan/sprite-atlas.md). Rows keep the meaning they had
before the gargoyle redesign so renderer lookups are unchanged.

The two sentinels are large gargoyles posed with tools/gargoyle_rig.py, the
same rig as the ordinary creatures: the shield sentinel is a horned violet
warden, the armoured sentinel a crowned gold colossus. Broad bat-wing
membranes stretch between finger bones and beat through a slow eight-pose
stroke; warning, last-stand charge, tucked-wing rush, stoop-dive and maw
discharge poses are cues on the creature itself. Shapes are authored here;
no source-game sprite or third-party art is used.
"""
from __future__ import annotations

import math

import numpy as np

import gargoyle_rig as G
from sprite_kit import ROOT, Atlas, Canvas

W, H = 128, 64
CX = 64.0
wp = G.wp

KIND = {False: 'warden', True: 'colossus'}
PAL = {
    False: ('gv0', 'gv1', 'gv2', 'gv3'),   # shield sentinel (warden)
    True: ('gg0', 'gg1', 'gg2', 'gg3'),    # armoured sentinel (colossus)
}

# Wing poses (elevation, sweep, forearm, fold, finger curl). The slow heavy
# stroke: 0-3 extended wings drive down, 4-7 the wrists lead a folded
# recovery (span under 70 % of the level pose) and the wings unfold again.
STROKE = [
    wp(40, 4, 8, .1, -18),     # 0 raised
    wp(24, 6, 2, 0, -10),      # 1 opening
    wp(8, 8, -2, 0, 0),        # 2 level, full span
    wp(-16, 12, -6, .04, 10),  # 3 driving
    wp(-36, 14, -8, .18, 18),  # 4 low
    wp(-22, 2, 18, .62, 8),    # 5 recovery: folded, wrist leads
    wp(6, -6, 24, .66, -6),    # 6 rising, still folded
    wp(28, -2, 14, .3, -14),   # 7 unfolding
]
WARNING = [wp(44, 0, 12, .12, -22), wp(47, 0, 14, .12, -24), wp(45, 2, 12, .14, -22), wp(43, 2, 10, .12, -20)]
CHARGE = [wp(58, -4, 24, .3, -26), wp(61, -4, 26, .32, -28), wp(59, -2, 24, .28, -26), wp(62, -4, 28, .32, -30)]
DIVE = [wp(-28, -26, 30, .58, 30), wp(-32, -28, 32, .6, 32), wp(-26, -24, 28, .56, 28), wp(-30, -27, 31, .59, 31)]
RUSH = [wp(-14, -30, 40, .95, 20), wp(-18, -32, 42, .96, 22), wp(-12, -30, 38, .94, 18), wp(-16, -31, 41, .95, 21)]


def _view(pitch=30):
    return G.View(size=(W, H), origin=(64, 30), scale=1.4, pitch=pitch)


def _build(heavy, pose, stance=None, frame=0, fire=0, wings_on=True, pitch=30):
    sp = G.SPECIES[KIND[heavy]]
    dmg = G.Damage(angry=stance in ('charge', 'rush'), flare=stance == 'warning' and frame % 2 == 1, fire=fire)
    B, wings, face = G.build_creature(sp, pose, _view(pitch), dmg, wings_on=wings_on)
    ax, ay = G.v(1, 0, 0), G.v(0, 1, 0)
    # Stance cues stay on the creature itself (no arrows or detached marks).
    if stance == 'warning':
        band = 'eye_r' if frame % 2 else 'fire1'
        B.decal(face['H3']((0, -.4, 3.4)), ax, ay, [(x, 0, band) for x in range(-4, 4)], (), force=True)
        for side, w in wings.items():
            B.decal(w['wrist'], ax, ay, [(0, 0, band), (1, 0, band), (0, 1, band), (1, 1, band)], (), force=True)
    if stance == 'charge':
        for s in (-1, 1):  # shoulder vents flare, crest burns upward
            B.decal(G.v(s * 6.6 * sp.bulk, -4.0, 2.2), ax, ay,
                    [(0, y, 'cor2' if y % 2 else 'fire1') for y in range(-1, 3 + frame % 2)], (), force=True)
        B.decal(face['H3']((0, -3.4, .6)), ax, ay, [(0, -y, 'fire1' if y < 2 else 'cor2') for y in range(3 + frame % 2)]
                + [(-1, -1, 'cor2'), (1, -1, 'cor2')], (), force=True)
    if stance == 'rush':
        for s in (-1, 1):
            B.decal(G.v(s * 7.0 * sp.bulk, -2.0, 1.0), ax, ay, [(0, y + frame % 2, 'cor2') for y in range(5)], (), force=True)
        B.decal(G.v(0, 10.0, -2.0), ax, ay, [(x, y, 'cor2') for y in range(3) for x in range(-1 + y // 2, 2 - y // 2)]
                + [(0, 3 + frame % 2, 'fire1')], (), force=True)
    return B, sp, dmg


def sentinel(heavy, pose, stance=None, frame=0, fire=0, pitch=30):
    if not isinstance(pose, G.Pose):
        pose = G.Pose(pose, pose, lift=0, tail=.4 * math.sin(frame * 1.3), legs=-.8 if stance in ('dive', 'rush') else 0,
                      jaw=.6 if (fire or stance in ('charge', 'rush')) else 0)
    B, sp, dmg = _build(heavy, pose, stance, frame, fire, pitch=pitch)
    cv, _, _ = G.rasterize(B, sp, _view(pitch), dmg)
    return cv


def flash(cv: Canvas, heavy):
    sp = G.SPECIES[KIND[heavy]]
    d, m, b, l = PAL[heavy]
    out = cv.copy()
    mapping = {l: 'white', b: 'ivory', m: l, d: b, 'met2': 'white', 'met1': 'met3', 'gg3': 'white',
               sp.wing[0]: sp.wing[1], sp.wing[1]: sp.wing[2], sp.wing[2]: b, 'bone1': 'bone2', 'bone2': 'white'}
    out.map_colors(mapping)
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
    """Four armour layers (chest plate, gorget, shoulder plates, outer
    pauldrons): metal with gold trim on the gargoyle's body, rendered by the
    rig in the hover pose (the body holds still through the stroke, so the
    plates stay aligned) and kept as the pixels each plate adds."""
    pose = G.Pose(STROKE[2], STROKE[2], lift=0)
    heavy = False

    def body(with_layer):
        B, sp, dmg = _build(heavy, pose, wings_on=False)
        if with_layer:
            bulk = sp.bulk
            if i == 0:
                B.ell(G.v(0, 3.0, 5.0), (4.6, 3.2, 1.8), 'eplate', 'body')
                B.sph(G.v(0, 4.4, 6.6), .9, 'crown', 'body')
            elif i == 1:
                B.ell(G.v(0, -5.8, 2.6), (8.0, 1.7, 2.6), 'eplate', 'body')
                for s in (-1, 1):
                    B.sph(G.v(s * 5.6, -6.4, 4.4), .9, 'crown', 'body')
            elif i == 2:
                for s in (-1, 1):
                    B.ell(G.v(s * 7.4 * bulk, -5.4, 1.4), (3.4, 2.2, 3.4), 'eplate', 'body')
                    B.sph(G.v(s * 7.4 * bulk, -7.4, 2.0), 1.0, 'crown', 'body')
            else:
                for s in (-1, 1):
                    B.ell(G.v(s * 9.4 * bulk, -.6, 3.6), (2.2, 3.2, 2.4), 'eplate', 'body')
                    B.sph(G.v(s * 9.6 * bulk, 1.8, 5.4), .9, 'crown', 'body')
        cv, _, _ = G.rasterize(B, sp, _view(), dmg)
        return cv

    plain, armed = body(False), body(True)
    out = Canvas(W, H)
    diff = (armed.a != plain.a).any(-1) & (armed.a[..., 3] > 0)
    out.a[diff] = armed.a[diff]
    return out


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
    """Sentinel maw bolt discharge, on the full pose so it can replace the
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
            a.put(4 + f, 6 + r, sentinel(heavy, RUSH[f], 'rush', f, pitch=44))
            a.put(f, 8 + r, sentinel(heavy, WARNING[f], 'warning', f))
            a.put(4 + f, 8 + r, sentinel(heavy, DIVE[f], 'dive', f, pitch=48))
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
