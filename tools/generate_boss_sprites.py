"""Generate the boss armada: one gargoyle warship atlas per hull class.

    .cache/asset-venv/bin/python tools/generate_boss_sprites.py [class ...]

Outputs (contract: plan/sprite-atlas.md, "Boss armada atlases"):
  assets/images/boss-<class>.png   one packed atlas per hull class, stored 1x
  lib/game/boss_atlas.dart         generated rect/anchor tables for the scene

Each run of the five-run campaign meets a bigger hull class: a gargoyle
frigate, a cruiser, a battlecruiser, a cathedral battleship and the
dreadnought. Every class is a hard-surface warship first (engine nacelles
with nozzles, plated decks with panel lines, a bridge tower with lit
windows, hangar bays, gun turrets, running lights, a front, a rear and
propulsion) and a demonic gargoyle second (a horned gargoyle figurehead
on the prow whose mouth is the core maw, bat-wing solar sails on finger
bones, carved buttresses and spires, glowing eyes and fissures).

Visual-only scaling. All functional anchors are identical for every class
and match the simulation (lib/game/model.dart): the core maw window
32 x 22 at (0, 25) from the carrier centre, the hangar bays 22 x 16 at
(+-46, 21), the turret pivots at (+-28, 36), the eyes 6.5-20 units off
centre at y -8.5..0, and the solid body x +-78, y -25..43. The bright
"core" layer (the bow: figurehead, glacis, bays, turrets) has the same
footprint in every class; the extra size of the bigger classes is the
darker "superstructure" layer behind it (stern, tower, engines, sails),
drawn in the scene before the creatures as non-solid background hull.

Geometry comes from the rig's hard-surface kit (tools/gargoyle_rig.py:
ShipCam, Hull, WindowRaster: faceted lofts, plates, tubes and spires in a
35-degree 3/4 view with the bow toward the player) plus the gargoyle
volumes (ellipsoids, sphere chains, membrane triangles), z-buffered and
shaded with the same quantised top-left key light onto bounded ramps.
Optional AI detail maps (art/families/carrier/detail/*.png, SDXL +
pixel-art-xl, finished by tools/sprite_pipeline.py) nudge the key-light
value of plating, stone and membrane pixels only.

1 design unit = 2 native px; the scene draws a sprite of w x h px at
w/2 x h/2 arena units. No randomness except fixed tables: same inputs,
same bytes.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gargoyle_rig as G  # noqa: E402
from sprite_kit import Canvas  # noqa: E402

U = 2                      # native px per design unit
PITCH = 35.0
CAM = G.ShipCam(PITCH, U)
SP = CAM.sp
DETAIL = ROOT / 'art/families/carrier/detail'

# Functional anchors (design units from the carrier centre). These are the
# simulation's geometry; test/boss_armada_test.dart checks the atlases.
CORE = (0, 25, 32, 22)          # maw window: centre x, y, width, height
BAY = (46, 21, 22, 16)          # right hangar bay (mirrored: -46)
TURRET = (28, 36)               # barrel pivots (mirrored)
BODY = (78, -25, 43)            # solid body: |dx| < 78, -25 < dy < 43

INK = '#0a0716'
BONE = ('#4a3a2e', '#9a8466', '#d8c69a', '#fff3d6')
FANG = '#fff3d6'
RUBY = '#ff355f'
WHITE = '#fffbe0'
FIRE = ('#9e1b1b', '#e8430c', '#ff6b1a', '#ffbf1f', '#ffe042', '#fffdf7')
CRACK = ('#1a0a10', '#9e1b1b', '#ff6b1a', '#ffbf1f', '#ffe042')
ASH = ('#16141c', '#2e2a34', '#504a58', '#7c7484')
CHAR = ('#0e0b0e', '#1a1418', '#2a2026', '#3a2c30')
ASH_BONE = ('#2a2426', '#4e4644', '#7a706a', '#9a9088')
EMBER_DIM = ('#2a0c0c', '#9e1b1b', '#e8430c')
GLASS = ('#0a1020', '#14243a')

# ---------------------------------------------------------------------------
# Forms (within one fight) and classes (one per run).
# ---------------------------------------------------------------------------
FORMS = [
    dict(  # 0 violet-grey gunmetal, amber eyes, chevron
        hull=('#1a1830', '#34345a', '#5c5e8c', '#9498c4'),
        stone=('#1c1830', '#3a3254', '#625984', '#958cb8'),
        wing=('#140e26', '#251a44', '#3e2f6c', '#57468c'),
        wbone=('#3a3046', '#7a6c7c', '#b4a698', '#d8c69a'),
        trim=('#3a3046', '#7a6c7c', '#b4a698', '#e6d8b4'),
        eye=('#ff9f2e', '#ffd23f', '#7a3a10'), fis=('#4a1424', '#c04a2a', '#ffa040'),
        lit='#ffc45a', rank='chevron'),
    dict(  # 1 bruised plum, magenta fissures, twin bars
        hull=('#1e1028', '#40244e', '#6c4682', '#a682bc'),
        stone=('#24112c', '#4a2457', '#7a4a8e', '#b886c8'),
        wing=('#170a1f', '#2e1240', '#4e2268', '#6e3c88'),
        wbone=('#3e2a3a', '#806678', '#bea494', '#d8c69a'),
        trim=('#3e2a3a', '#806678', '#bea494', '#e6d8b4'),
        eye=('#ff6a3a', '#ffc04a', '#6a1e2a'), fis=('#4a0e2c', '#d0306a', '#ff86b0'),
        lit='#ff9ad0', rank='bars'),
    dict(  # 2 ember-cracked crimson, lava fissures, fang slashes
        hull=('#1c0a12', '#421824', '#76323c', '#b06058'),
        stone=('#200c14', '#4c1a26', '#843440', '#c0645c'),
        wing=('#16080e', '#30101a', '#561c2a', '#7a3036'),
        wbone=('#3e2a26', '#86685a', '#c4a68a', '#d8c69a'),
        trim=('#5a2a12', '#a8521c', '#ff8a2a', '#ffd06a'),
        eye=('#ffbf1f', '#ffe042', '#7a2410'), fis=('#5a1008', '#ff6b1a', '#ffe042'),
        lit='#ffb040', rank='fangs'),
    dict(  # 3 obsidian with a gold crown, gold-veined fissures, star
        hull=('#0c0a16', '#1e1a32', '#3a3458', '#625c8c'),
        stone=('#0e0b18', '#221d36', '#3e3760', '#6c6496'),
        wing=('#0e0a14', '#1e1626', '#34263c', '#4c3a50'),
        wbone=('#3e2108', '#7a4a12', '#c8902a', '#ffd866'),
        trim=('#3e2108', '#7a4a12', '#c8902a', '#ffd866'),
        eye=('#ffd866', '#fffbe0', '#7a4a12'), fis=('#3e2108', '#c8902a', '#fff0a8'),
        lit='#ffe08a', rank='star'),
]

# Hull classes (one per run), all in deck units from the carrier centre.
# ext: canvas (x half-width, top, bottom); waist: hull half-width behind
# the bow (front, rear); E0/Es: deck y of the engine block's front and the
# stern; wb: engine block half-width; dh: deck height; main: (nozzle
# radius, x offsets of the main engines; 0 = one on the centre line);
# pods: outboard engine pods (x, y_front, length, radius); sails: bat-wing
# solar sails (span, attach fraction along the engine block); tower:
# bridge tower (y, levels, half-width, height, spires); turrets: static
# point-defence turrets (x, y) on the engine block; dark: corruption.
CLASSES = [
    dict(key='frigate', title='Gargoyle Frigate', ext=(132, -126, 58), waist=(40, 30), E0=-44, Es=-76, wb=46,
         dh=26, main=(9.5, [18]), pods=[], sails=[(66, .55)],
         tower=dict(y=-30, levels=3, w=22, h=40, spires=1), turrets=[], buttress=1, dark=0.0),
    dict(key='cruiser', title='Brood Cruiser', ext=(160, -152, 60), waist=(44, 32), E0=-56, Es=-100, wb=52,
         dh=28, main=(10.0, [21]), pods=[(80, -44, 40, 8.0)], sails=[(84, .5)],
         tower=dict(y=-36, levels=4, w=26, h=54, spires=3), turrets=[(32, -76)], buttress=2, dark=.12),
    dict(key='battlecruiser', title='Siege Battlecruiser', ext=(184, -180, 62), waist=(48, 34), E0=-68, Es=-128,
         wb=58, dh=30, main=(10.5, [0, 28]), pods=[(88, -50, 48, 9.0), (122, -66, 36, 6.5)], sails=[(104, .42)],
         tower=dict(y=-40, levels=5, w=30, h=68, spires=5), turrets=[(36, -90), (16, -112)], buttress=3, dark=.22),
    dict(key='battleship', title='Cathedral Battleship', ext=(204, -210, 64), waist=(52, 36), E0=-80, Es=-152,
         wb=64, dh=32, main=(11.5, [14, 42]), pods=[(94, -52, 56, 10.0), (130, -70, 44, 7.5)],
         sails=[(118, .38), (74, .9)],
         tower=dict(y=-44, levels=6, w=34, h=84, spires=7), turrets=[(40, -100), (18, -128), (46, -140)],
         buttress=4, dark=.32),
    dict(key='dreadnought', title='Abyssal Dreadnought', ext=(224, -258, 66), waist=(56, 40), E0=-92, Es=-200,
         wb=72, dh=34, main=(13.0, [0, 28, 56]), pods=[(102, -54, 62, 11.0), (140, -72, 50, 8.5),
                                                        (172, -90, 40, 6.5)],
         sails=[(134, .34), (88, .88)],
         tower=dict(y=-50, levels=7, w=38, h=104, spires=9),
         turrets=[(42, -112), (20, -150), (50, -170), (24, -186)], buttress=5, dark=.42),
]

def form_count(k):
    """Forms reachable in run k (Carrier.formCount = min(4, 2 + cycle))."""
    return min(4, 2 + k)


def mix(a, b, t):
    a, b = a.lstrip('#'), b.lstrip('#')
    ca = [int(a[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i + 2], 16) for i in (0, 2, 4)]
    return '#%02x%02x%02x' % tuple(round(x + (y - x) * t) for x, y in zip(ca, cb))


SPACE = '#07060f'


def darken(ramp, t):
    """Darker, more corrupted ramp: each tone eased toward deep space."""
    return tuple(mix(c, SPACE, t * (1 - i * .18)) for i, c in enumerate(ramp))


def backdrop(ramp, t, k=0):
    """Superstructure ramp: lower contrast, pushed toward the sector night
    so the outer hull reads as background (shots pass over it)."""
    r = darken(ramp, t)
    e = .05 * k
    return (mix(r[0], SPACE, .3 + e), mix(r[1], SPACE, .38 + e), mix(r[2], SPACE, .46 + e), mix(r[3], SPACE, .56 + e))


METAL = ('#121020', '#28263a', '#4a4862', '#7c7a96')
NOZZLE = ('#0e0a12', '#1e1822', '#34283a', '#4e3a46')


def materials(k, f, layer, wreck=False):
    F, C = FORMS[f], CLASSES[k]
    d = C['dark']
    if wreck:
        m = {'hull': ASH, 'hull2': (ASH[0], ASH[0], ASH[1], ASH[2]), 'armor': ASH, 'metal': CHAR,
             'stone': ASH, 'wingf': CHAR, 'wbone': ASH_BONE, 'horn': ASH_BONE, 'claw': ASH_BONE,
             'trim': ASH_BONE, 'nozzle': CHAR, 'glass': (CHAR[0], CHAR[0], CHAR[1], CHAR[2])}
        if layer == 'super':
            m = {n: backdrop(r, .25, k) for n, r in m.items()}
        return m
    hull = darken(F['hull'], d)
    m = {'hull': hull, 'hull2': (hull[0], hull[0], hull[1], hull[2]),
         'armor': darken((F['hull'][1], F['hull'][2], F['hull'][3], mix(F['hull'][3], '#ffffff', .3)), d * .6),
         'metal': darken(METAL, d * .5), 'stone': darken(F['stone'], d), 'wingf': darken(F['wing'], d * .8),
         'wbone': darken(F['wbone'], d * .5), 'horn': darken(BONE, d * .4), 'claw': BONE,
         'trim': darken(F['trim'], d * .4), 'nozzle': NOZZLE, 'glass': (GLASS[0], GLASS[0], GLASS[1], '#2a4060')}
    if layer == 'super':
        m = {n: backdrop(r, .0 if n in ('trim', 'horn', 'wbone') else .05, k) for n, r in m.items()}
        m['nozzle'] = NOZZLE
    return m


# ---------------------------------------------------------------------------
# Sheet: one class canvas (carrier centre at the canvas origin).
# ---------------------------------------------------------------------------
class Sheet:
    def __init__(self, k):
        xr, top, bot = CLASSES[k]['ext']
        self.k = k
        self.W, self.H = int(2 * xr * U), int((bot - top) * U)
        self.OX, self.OY = xr * U, -top * U

    def canvas(self):
        return Canvas(self.W, self.H)

    def N(self, p):
        return (p[0] * U + self.OX, p[1] * U + self.OY)

    def poly(self, cv, pts, col):
        cv.poly([self.N(p) for p in pts], col)

    def line(self, cv, a, b, col, width=1):
        cv.line(self.N(a), self.N(b), col, width)

    def path(self, cv, pts, col, width=1):
        for a, b in zip(pts, pts[1:]):
            self.line(cv, a, b, col, width)

    def box(self, cv, x, y, w, h, col):
        cv.rect(x * U + self.OX, y * U + self.OY, w * U, h * U, col)

    def ell(self, cv, cx, cy, rx, ry, col):
        cv.ellipse(cx * U + self.OX, cy * U + self.OY, rx * U, ry * U, col)

    def px(self, cv, x, y, col):
        cv.px(x * U + self.OX, y * U + self.OY, col)

    def masked(self, cv, mask, draw):
        tmp = self.canvas()
        draw(tmp)
        m = tmp.opaque() & mask
        cv.a[m] = tmp.a[m]

    def rasterize(self, hull, mats, tex=True, gap=4.5):
        R = G.WindowRaster(self.W, self.H, (self.OX, self.OY))
        for p in hull.prims:
            if isinstance(p, G.Ellipsoid):
                R.ellipsoid(p)
            elif isinstance(p, G.Sphere):
                R.sphere(p)
            else:
                R.tri(p)
        names = G.shade(R, mats, texture(self, R) if tex else None)
        cv = self.canvas()
        for name in sorted(set(names[names != ''].tolist())):
            cv._paint(names == name, name)
        G.clean_specks_fast(cv, R, names)
        contours(cv, R, gap)
        return cv, R


def S(x, y, h=0.0):
    """Screen position (units) of a ship point (deck coords)."""
    return CAM.screen((x, y, h))


_detail_cache = {}


def detail(name):
    if name not in _detail_cache:
        path = DETAIL / f'{name}.png'
        if path.exists():
            a = np.array(Image.open(path).convert('RGBA')).astype(int)
            lv = np.digitize(a[..., 0], (70, 135, 205))
            off = (lv - 1.5) * .075
            off[a[..., 3] == 0] = 0
            _detail_cache[name] = off
        else:
            _detail_cache[name] = None
    return _detail_cache[name]


def tiled(off, h, w, dx=0, dy=0):
    th, tw = off.shape
    ys = (np.arange(h) + dy) % th
    xs = (np.arange(w) + dx) % tw
    return off[np.ix_(ys, xs)]


PLATING = ('hull', 'hull2', 'armor', 'metal')


def texture(sh, R):
    """Key-light offsets: panel seams in ship space (triplanar: deck panels
    on decks, bulkhead panels on walls), the AI plating greebles tiled over
    plates, AI hide on carved stone and AI leather on the sails."""
    t = np.zeros((R.h, R.w))
    mat = R.mat
    plate = np.isin(mat, PLATING)
    occ = R.z > -1e8
    # Ship-space coordinates and normals of every covered pixel.
    w = R.p3 / U
    T = w @ CAM.R            # world -> true ship (R is orthonormal)
    nS = R.n @ CAM.R
    X, Y, Z = T[..., 0], T[..., 1] * CAM.cp, T[..., 2]
    ax = np.abs(nS)
    deckf = (ax[..., 2] >= ax[..., 1]) & (ax[..., 2] >= ax[..., 0])
    wallf = ~deckf & (ax[..., 1] >= ax[..., 0])
    pw, ph = 12, 7

    def seam(a, b):
        row = np.floor(b / ph)
        sa = (np.floor((a + (row % 2) * pw / 2) * U) % (pw * U)) == 0
        sb = (np.floor(b * U) % (ph * U)) == 0
        return sa | sb

    s = np.where(deckf, seam(X, Y), np.where(wallf, seam(X, Z * 1.3), seam(Y, Z * 1.3)))
    t[plate & occ & s] -= .32
    pl = detail('plating')
    if pl is not None:
        off = tiled(pl, R.h, R.w, 37, 11)
        t[plate & ~s] += off[plate & ~s] * 1.6
    hide = detail('hide')
    stone = mat == 'stone'
    if hide is not None:
        t[stone] += tiled(hide, R.h, R.w)[stone] * 1.4
    else:
        t[stone & (((np.arange(R.w)[None, :] + np.arange(R.h)[:, None] * 3) % 7) == 0)] -= .2
    mb = detail('membrane')
    wing = mat == 'wingf'
    if mb is not None:
        t[wing] += tiled(mb, R.h, R.w)[wing] * 1.6
    horn = mat == 'horn'
    ys, xs = np.mgrid[0:R.h, 0:R.w]
    t[horn & ((ys + xs // 3) % 6 == 0)] -= .3
    return t


def contours(cv, R, gap=4.5):
    z, part = R.z, R.part
    h, w = z.shape
    occ = z > -1e8
    line = np.zeros((h, w), dtype=bool)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        zs = np.full((h, w), -1e9)
        ps = np.full((h, w), '', dtype=object)
        ys0, ys1 = max(0, dy), h + min(0, dy)
        xs0, xs1 = max(0, dx), w + min(0, dx)
        zs[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx] = z[ys0:ys1, xs0:xs1]
        ps[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx] = part[ys0:ys1, xs0:xs1]
        line |= occ & (zs > z + gap) & (ps != part)
    cv._paint(line, INK)


def mir(p, s):
    return (p[0] * s,) + tuple(p[1:])


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# ---------------------------------------------------------------------------
# The bow ("core" layer): identical footprint in every class.
# ---------------------------------------------------------------------------
KEEL = [(0, 48), (26, 46), (50, 40), (70, 29), (84, 12), (86, -2), (58, -22),
        (-58, -22), (-86, -2), (-84, 12), (-70, 29), (-50, 40), (-26, 46)]
BOW_H = 47.0


def glacis(poly, pull):
    out = []
    for x, y in poly:
        s = min(1.0, max(0.0, (y + 6) / 50))
        out.append((x, y - pull * s))
    return out


def build_bow(H, k, f, breath=0.0, flex=0, wreck=False):
    """Armoured ram-bow with the gargoyle figurehead whose mouth is the maw."""
    g = glacis(KEEL, 16)
    H.loft([(KEEL, 0), (KEEL, 12), (g, BOW_H - 3), (G.inset(g, 2.5), BOW_H)], 'hull2', 'bow',
           mats=['hull2', 'hull', 'armor'])
    # Deck armour: two raised plates along the flanks and a keel ridge.
    for s in (-1, 1):
        H.plate([mir(p, s) for p in ((36, -14), (66, -14), (74, 0), (70, 14), (44, 18), (34, 6))],
                BOW_H - 1, BOW_H + 4, 'armor', f'deckplate{s}', bevel=1.6)
        # Bay housings: armoured cheeks around the hangar bays.
        H.plate([mir(p, s) for p in ((34, 26), (60, 24), (66, 32), (58, 40), (36, 42), (30, 34))],
                10, 22, 'hull', f'bayhood{s}', bevel=1.2)
    # Ridged keel roof behind the figurehead: two sloped faces split the
    # key light (lit port side, shaded starboard side).
    roof = [(-12, -20), (12, -20), (12, 12), (-12, 12)]
    H.loft([(roof, BOW_H - 1), (roof, BOW_H + 2), ([(-1, -22), (1, -22), (1, 10), (-1, 10)], BOW_H + 9)],
           'armor', 'ridge', mats=['hull2', 'armor'])
    for s in (-1, 1):
        # Gun-deck trench lines: low dark rails along the deck.
        H.plate([mir(p, s) for p in ((16, -20), (30, -20), (30, -17), (16, -17))], BOW_H - 1, BOW_H + 1.5,
                'metal', f'rail{s}', bevel=.5)
        H.plate([mir(p, s) for p in ((16, -4), (30, -4), (30, -1), (16, -1))], BOW_H - 1, BOW_H + 1.5,
                'metal', f'rail{s}', bevel=.5)
    # Class escalation on the bow: ram spikes, tusks, a second horn crown.
    if k >= 1:
        for s in (-1, 1):
            H.chain([mir((74, 26, 10), s), mir((82, 38, 8), s), mir((86, 48, 6), s)], 2.6, .5, 'horn', f'ram{s}')
    if k >= 2:
        for s in (-1, 1):
            H.chain([mir((84, 2, 20), s), mir((96, 2, 26), s), mir((104, -2, 30), s)], 2.4, .5, 'horn', f'spur{s}')
            H.chain([mir((60, 40, 4), s), mir((62, 50, 0), s)], 2.0, .5, 'horn', f'tusk{s}')
    # Figurehead: a gargoyle head on the prow, looking at the player.
    hc = (0, 22, 56)
    H.ell(hc, (26, 17, 19), 'stone', 'head')
    H.ell((0, 14, 66), (5, 10, 6), 'stone', 'crest')
    for s in (-1, 1):
        H.ell(mir((11.5, 32, 62), s), (11, 4, 4), 'stone', 'brow', G.rot_y(-16 * s) @ G.rot_x(-10))
        H.ell(mir((17, 30, 50), s), (9, 8, 9), 'stone', f'jowl{s}')
        H.ell(mir((22, 26, 40), s), (8, 7, 10), 'stone', f'jowl{s}')
        # Bat ears / fins that breathe (idle life).
        e0, e1 = mir((19, 18, 66), s), mir((30 + breath * 1.5, 10, 76 + breath * 3), s)
        e2 = mir((27 + breath, 4, 64), s)
        H.tri(e0, e1, e2, 'wingf', f'ear{s}', flip=s > 0)
        H.chain([e0, e1], 1.0, .4, 'wbone', f'ear{s}')
    H.ell((0, 33, 50), (10, 6, 7), 'stone', 'snout')
    # Horns: swept back over the deck like a figurehead's crest.
    for s in (-1, 1):
        pts = [mir((12, 20, 70), s), mir((22, 12, 78), s), mir((30, 2, 82), s), mir((33, -8, 84), s)]
        if wreck and s < 0:
            pts = pts[:3]
        H.chain(pts, 3.4, .9 if not (wreck and s < 0) else 2.2, 'horn', f'horn{s}')
        if f >= 2 or k >= 3:
            H.chain([mir((21, 28, 58), s), mir((28, 26, 62), s), mir((34, 20, 64), s)], 2.2, .5, 'horn', f'ramhorn{s}')
    # Dorsal spines (forms 1-2), a gold crown (form 3); `flex` extends one set.
    if f in (1, 2):
        for i, x in enumerate((0, -5.5, 5.5)):
            ext = 1.6 if (flex == 1 and i == 0) or (flex == 2 and i > 0) else 0
            H.chain([(x, 14, 72), (x, 10, 80 + (8 if i == 0 else 6) + ext)], 1.6, .4, 'horn', 'spine')
    if f == 3:
        for i, x in enumerate((0, -6, 6, -11, 11)):
            ext = 1.4 if (flex == 1 and i in (1, 2)) or (flex == 2 and i in (3, 4)) else 0
            H.chain([(x, 16, 71), (x * 1.15, 13, 71 + (12 if i == 0 else 8 if i < 3 else 5) + ext)], 1.9, .45,
                    'trim', 'crown')
        H.ell((0, 16, 71), (13, 3, 2.2), 'trim', 'crown')
    if k >= 4:
        for s in (-1, 1):
            H.chain([mir((14, 8, 74), s), mir((34, 0, 84), s), mir((46, -14, 86), s)], 2.6, .6, 'horn', f'horn2{s}')


EYE_L = [(-20, -8.5), (-13, -6), (-6.5, -3.2), (-7.5, -.2), (-13, -.8), (-19.5, -4.5)]
EYE_CORE_L = [(-18, -7), (-13, -4.8), (-8.5, -2.6), (-9, -1.2), (-13, -2), (-17.6, -4.8)]
BREATH = (0.0, .5, 1.0, .5)
PULSE = (1, 2, 1, 0)
FLEX = (0, 1, 0, 2)


def draw_face(sh, cv, R, F, pulse, wreck=False):
    rim, core, halo = F['eye']
    if wreck:
        rim, core, halo = '#2e2a34', '#504a58', None
    stone = R.mat == 'stone'
    for s in (-1, 1):
        eye = [(x * s, y) for x, y in EYE_L]
        ec = [(x * s, y) for x, y in EYE_CORE_L]
        if pulse == 2 and halo:
            ecx = -12.8 * s
            ring = [(ecx + (x - ecx) * 1.3, -3.6 + (y + 3.6) * 1.9) for x, y in eye]
            sh.masked(cv, stone, lambda t, ring=ring: sh.poly(t, ring, halo))
        sh.poly(cv, [(x, y - .6) for x, y in eye], INK)
        sh.poly(cv, eye, rim)
        if not wreck:
            sh.poly(cv, ec, core if pulse > 0 else rim)
            if pulse == 2:
                sh.poly(cv, [lerp(p, (-12.5 * s, -3), .5) for p in ec], WHITE)
            sh.line(cv, (-13 * s, -5.2), (-13 * s, -1.6), INK, 2)


def draw_emblem(sh, cv, F, f, wreck=False):
    cx, cy, k = 0, -21.5, 1.25
    crest = [(-7, -4), (-4, -1), (0, -3), (4, -1), (7, -4), (5, 2), (0, 5), (-5, 2)]
    inner = [(-5.5, -2.5), (-3.5, 0), (0, -1.5), (3.5, 0), (5.5, -2.5), (4, 1.5), (0, 4), (-4, 1.5)]
    trim = F['trim'] if not wreck else ASH_BONE
    sh.poly(cv, [(cx + x * k, cy + y * k - .5) for x, y in crest], INK)
    sh.poly(cv, [(cx + x * k, cy + y * k) for x, y in inner], trim[2])
    sh.poly(cv, [(cx + x * k * .8, cy + y * k * .8 + .7) for x, y in inner], trim[1])
    sh.ell(cv, cx, cy + 1, 2.0, 1.7, RUBY if not wreck else EMBER_DIM[0])
    if not wreck:
        sh.px(cv, cx, cy + .4, '#ffffff')
    for i in range(f + 1):
        px = cx - f * 1.6 + i * 3.2
        sh.box(cv, px - .5, cy + 6, 1, 1, INK)
        cv.rect((px - .5) * U + sh.OX, (cy + 6) * U + sh.OY, 2, 2, F['eye'][1] if not wreck else ASH[2])


def draw_rank(sh, cv, F, wreck=False):
    """Rank marks on both deck plates (chevron, twin bars, fang slashes,
    star), as on the gargoyles' insignia."""
    light = F['trim'][3] if not wreck else ASH[3]
    mid = F['trim'][2] if not wreck else ASH[2]
    for s in (-1, 1):
        cx, cy = 56 * s, -22
        kind = F['rank']
        if kind == 'chevron':
            for d, col in ((.6, INK), (0, light)):
                sh.path(cv, [(cx - 4, cy - 2 + d), (cx, cy + 2 + d), (cx + 4, cy - 2 + d)], col, 3)
        elif kind == 'bars':
            for yy in (-2, 2):
                sh.box(cv, cx - 4, cy + yy - 1, 8, 2.5, INK)
                sh.box(cv, cx - 3.5, cy + yy - 1, 7, 1.5, '#8a9cc8' if not wreck else mid)
        elif kind == 'fangs':
            for i in (-1, 0, 1):
                sh.line(cv, (cx + i * 3 - 1, cy - 4), (cx + i * 3 + 1.5, cy + 3.5), INK, 4)
                sh.line(cv, (cx + i * 3 - 1, cy - 4), (cx + i * 3 + 1.5, cy + 3.5), light, 2)
        else:
            pts = []
            for i in range(10):
                a = -math.pi / 2 + i * math.pi / 5
                r = 5 if i % 2 == 0 else 2.2
                pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
            sh.poly(cv, [(x, y - .5) for x, y in pts], INK)
            sh.poly(cv, pts, light)
            sh.poly(cv, [(cx + (x - cx) * .6, cy + (y - cy) * .6 + .4) for x, y in pts], mid)
            sh.ell(cv, cx, cy + .3, 1.3, 1.2, RUBY if not wreck else EMBER_DIM[0])


# Fissures (screen units) on the bow's plating, more per form and class.
FISSURES = [
    [[(-30, -36), (-26, -30), (-29, -24)], [(28, -38), (25, -32), (28, -27)]],
    [[(-66, 6), (-62, 12), (-65, 18)], [(64, 4), (68, 10), (64, 16)], [(-6, -40), (-3, -36)]],
    [[(-40, -2), (-36, 4), (-39, 10)], [(38, -4), (41, 2), (37, 8)], [(0, 40), (-3, 43)]],
    [[(-46, -30), (-40, -32), (-34, -28)], [(34, -28), (40, -32), (46, -30)]],
    [[(-74, -6), (-70, 0)], [(70, -8), (74, -2)], [(-18, 44), (-14, 42)], [(14, 42), (18, 44)]],
]


def draw_fissures(sh, cv, R, F, n, f, wreck=False):
    mask = np.isin(R.mat, ('stone', 'hull', 'hull2', 'armor'))
    paths = [p for k in range(min(n, len(FISSURES))) for p in FISSURES[k]]
    dark, mid, hot = EMBER_DIM if wreck else F['fis']

    def draw(t):
        for path in paths:
            sh.path(t, path, dark, 3)
        for i, path in enumerate(paths):
            lit = hot if (i + f) % 3 else mid
            if wreck:
                lit = mid if (i % 2) else dark
            sh.path(t, path, lit, 1)
    sh.masked(cv, mask, draw)


def fang(sh, cv, x, y, w, length, down, col=FANG):
    sgn = 1 if down else -1
    sh.poly(cv, [(x - w / 2 - .5, y), (x + w / 2 + .5, y), (x, y + sgn * (length + .8))], INK)
    sh.poly(cv, [(x - w / 2, y), (x + w / 2, y), (x, y + sgn * length)], col)
    sh.line(cv, (x - w / 4, y + sgn * .3), (x - w / 8, y + sgn * length * .6), '#ffffff' if col == FANG else BONE[3])


def draw_openings(sh, cv, ramp, horn, lit, wreck=False):
    """The maw lip (an armoured frame with fangs) and both hangar bays
    (hazard-striped frames with a lit header and bay lights). Windows stay
    transparent for the scene's core and bay overlays."""
    cx, cy, w, h = CORE
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
    lip = [(x0 - 4.5, y0 - 1), (x0 - 1, y0 - 4.5), (x1 + 1, y0 - 4.5), (x1 + 4.5, y0 - 1), (x1 + 4.5, y1 + 1),
           (x1 + 1, y1 + 4.5), (x0 - 1, y1 + 4.5), (x0 - 4.5, y1 + 1)]
    sh.poly(cv, [(x, y - .5) for x, y in lip], INK)
    sh.poly(cv, [(cx + (x - cx) * .97, cy + (y - cy) * .95) for x, y in lip], ramp[1])
    sh.line(cv, (x0 - 1, y0 - 3.6), (x1 + 1, y0 - 3.6), ramp[3], 2)
    sh.line(cv, (x0 - 3.4, y0), (x0 - 3.4, y1), ramp[2], 2)
    sh.line(cv, (x1 + 3.4, y0), (x1 + 3.4, y1), ramp[0], 2)
    sh.line(cv, (x0, y1 + 3.4), (x1, y1 + 3.4), ramp[0], 2)
    for bx in (x0 - 3.4, x1 + 3.4):
        for by in (y0 + 3, y1 - 3):
            sh.box(cv, bx - .5, by - .5, 1, 1, ramp[3] if not wreck else ASH[2])
    for sx in (-1, 1):
        fang(sh, cv, cx + sx * (w / 2 + 2.2), y0 - 1.5, 2.6, 4.6, True, horn[3])
        fang(sh, cv, cx + sx * (w / 2 + 2.2), y1 + 1.5, 2.2, 3.4, False, horn[2])
    cv.a[int(y0 * U + sh.OY):int(y1 * U + sh.OY), int(x0 * U + sh.OX):int(x1 * U + sh.OX)] = 0
    for s in (-1, 1):
        vx, vy, vw, vh = BAY
        vx *= s
        a0, a1, b0, b1 = vx - vw / 2, vx + vw / 2, vy - vh / 2, vy + vh / 2
        rim = [(a0 - 3, b0 - 4), (a1 + 3, b0 - 4), (a1 + 3, b1 + 2.5), (a0 - 3, b1 + 2.5)]
        sh.poly(cv, [(x, y - .5) for x, y in rim], INK)
        sh.poly(cv, [(vx + (x - vx) * .96, vy + (y - vy) * .94) for x, y in rim], ramp[1])
        # Header with bay lights, hazard chevrons along the sill.
        sh.box(cv, a0 - 2, b0 - 3.5, vw + 4, 2.5, ramp[0])
        for i in range(5):
            lx = a0 + 1 + i * (vw - 2) / 4
            sh.box(cv, lx - .5, b0 - 2.8, 1, 1, (lit if (i + (s > 0)) % 2 == 0 else '#5ef0d8') if not wreck else ASH[1])
        for i in range(int(vw / 3) + 2):
            hx = a0 - 2 + i * 3
            col = ('#e8b030' if i % 2 == 0 else INK) if not wreck else (ASH[2] if i % 2 == 0 else ASH[0])
            sh.poly(cv, [(hx, b1 + .4), (hx + 1.5, b1 + .4), (hx + 2.5, b1 + 2), (hx + 1, b1 + 2)], col)
        sh.line(cv, (a0 - 2.4, b0 - 1), (a0 - 2.4, b1), ramp[2], 2)
        sh.line(cv, (a1 + 2.4, b0 - 1), (a1 + 2.4, b1), ramp[0], 2)
        cv.a[int(b0 * U + sh.OY):int(b1 * U + sh.OY), int(a0 * U + sh.OX):int(a1 * U + sh.OX)] = 0


def clear_windows(sh, cv):
    """The maw and bay windows are transparent in every bow frame (the
    scene draws the core glow, bay interiors, jaws and doors there)."""
    for cx, cy, w, h in (CORE, BAY, (-BAY[0],) + BAY[1:]):
        cv.a[int((cy - h / 2) * U + sh.OY):int((cy + h / 2) * U + sh.OY),
             int((cx - w / 2) * U + sh.OX):int((cx + w / 2) * U + sh.OX)] = 0


def draw_portholes(sh, cv, R, lit, wreck=False):
    """Lit portholes along the bow skirt and the deck plates: the clean,
    readable 'it is a ship' cue of the original flat carrier."""
    mask = np.isin(R.mat, ('hull', 'hull2', 'armor'))
    on = lit if not wreck else EMBER_DIM[0]

    def draw(t):
        for x in list(range(-74, -60, 4)) + list(range(60, 76, 4)):
            y = 30 - abs(x) * .2 + (abs(x) - 60) * 1.0
            sh.box(t, x - .5, y, 1.5, 1, INK)
            sh.box(t, x - .5, y, 1, 1, on)
        for x in (-44, -38, 38, 44):
            sh.box(t, x - .5, 42.5 - (abs(x) - 38) * .2, 1.5, 1, INK)
            sh.box(t, x - .5, 42.5 - (abs(x) - 38) * .2, 1, 1, on)
        for s in (-1, 1):
            for i in range(4):
                x, y = s * (44 + i * 5), -30 + i * 2.6
                sh.box(t, x - .5, y, 2, 1, INK)
                sh.box(t, x, y, 1, 1, on if i % 2 == 0 or wreck else '#5ef0d8')
    sh.masked(cv, mask, draw)


def bow_frame(sh, k, f, idle, wreck=False):
    H = G.Hull(CAM)
    build_bow(H, k, f, BREATH[idle], FLEX[idle], wreck)
    cv, R = sh.rasterize(H, materials(k, f, 'core', wreck))
    F = FORMS[f]
    ramp = materials(k, f, 'core', wreck)['armor']
    horn = materials(k, f, 'core', wreck)['horn']
    draw_fissures(sh, cv, R, F, f + 1 + k // 2, idle, wreck)
    draw_portholes(sh, cv, R, F['lit'] if PULSE[idle] or True else F['lit'], wreck)
    draw_face(sh, cv, R, F, PULSE[idle], wreck)
    draw_emblem(sh, cv, F, f, wreck)
    draw_rank(sh, cv, F, wreck)
    draw_openings(sh, cv, ramp, horn, F['lit'], wreck)
    if wreck:
        char_wreck(sh, cv, k, core=True)
        cv = bake_wreck_parts(sh, cv, k, f)
    cv.outline(INK)
    if not wreck:
        clear_windows(sh, cv)
    return cv


# ---------------------------------------------------------------------------
# The superstructure: waist, engine block, pods, tower, sails (darker,
# background layer drawn behind the creatures).
# ---------------------------------------------------------------------------
def engine_list(k):
    """Every engine as (x, y_front, y_rear, h, radius, kind) with kind
    'main' (clustered in the stern block) or 'pod' (outboard nacelle)."""
    C = CLASSES[k]
    out = []
    rm, xs = C['main']
    hm = C['dh'] * .55
    for x in xs:
        for s in ((1,) if x == 0 else (-1, 1)):
            out.append((x * s, C['Es'] + 6, C['Es'] - 2, hm, rm, 'main'))
    for x, yf, L, r in C['pods']:
        for s in (-1, 1):
            out.append((x * s, yf, yf - L, C['dh'] + 4, r, 'pod'))
    return sorted(out)


def nozzles(k):
    """Engine nozzle exits: (screen x, screen y, radius), left to right."""
    out = []
    for x, yf, yr, h, r, kind in engine_list(k):
        sx, sy = S(x, yr - r * 1.0, h + r * .55)
        out.append((round(sx, 2), round(sy, 2), r))
    return sorted(out)


def build_super(H, k, f, wreck=False):
    C = CLASSES[k]
    E0, Es, wb, dh = C['E0'], C['Es'], C['wb'], C['dh']
    w0, w1 = C['waist']
    # Waist: the hull narrows behind the hammerhead bow.
    waist = [(w0, -10), (w0 + 2, -22), (w1, E0 + 8), (-w1, E0 + 8), (-w0 - 2, -22), (-w0, -10)]
    H.loft([(waist, 0), (waist, dh - 5), (G.inset(waist, 3.5), dh)], 'hull', 'waist', mats=['hull2', 'armor'])
    # Engine block: the broad stern that carries the main engines.
    blk = [(wb * .8, E0 + 10), (wb, E0 - 2), (wb, Es + 10), (wb - 8, Es + 2), (-wb + 8, Es + 2), (-wb, Es + 10),
           (-wb, E0 - 2), (-wb * .8, E0 + 10)]
    H.loft([(blk, 0), (blk, dh + 1), (G.inset(blk, 4), dh + 6)], 'hull', 'block', mats=['hull2', 'armor'])
    # Dorsal keel ridge down the block: a sloped roof splits the key light.
    rw = 8 + k * 2
    roof = [(-rw, E0 - 2), (rw, E0 - 2), (rw, Es + 10), (-rw, Es + 10)]
    H.loft([(roof, dh + 5), (roof, dh + 8), ([(-1, E0 - 4), (1, E0 - 4), (1, Es + 12), (-1, Es + 12)], dh + 15 + k)],
           'armor', 'keel', mats=['hull2', 'armor'])
    # Deck courses on the block and the waist.
    n = max(2, int((E0 - Es) / 16))
    for i in range(n):
        y0 = E0 - 6 - (E0 - Es - 12) * i / n
        y1 = y0 - (E0 - Es - 12) / n * .78
        for s in (-1, 1):
            H.plate([mir(p, s) for p in ((6, y0), (wb - 10, y0), (wb - 12, y1), (6, y1))], dh + 5, dh + 8,
                    'armor', f'course{i}{s}', bevel=1.2)
    for i in range(max(1, int(-E0 / 22))):
        y0 = -16 - i * 20
        for s in (-1, 1):
            H.plate([mir(p, s) for p in ((8, y0), (w0 - 8, y0), (w0 - 10, y0 - 14), (8, y0 - 14))], dh - 1, dh + 2,
                    'armor', f'wcourse{i}{s}', bevel=1)
    # Radiator vents along the block flanks.
    for s in (-1, 1):
        for i in range(n * 2):
            y = E0 - 6 - (E0 - Es - 16) * (i + .5) / (n * 2)
            H.plate([(s * (wb - 3), y + 1.2), (s * (wb + 2), y + 1.2), (s * (wb + 2), y - 1.2), (s * (wb - 3), y - 1.2)],
                    dh * .3, dh + 2, 'metal', f'fin{i}{s}', bevel=.6)
    # Engines.
    for e, (x, yf, yr, h, r, kind) in enumerate(engine_list(k)):
        s = 1 if x >= 0 else -1
        part = f'eng{e}'
        if kind == 'pod':
            # Wing pylon from the block to the pod.
            ym = (yf + yr) / 2
            H.plate([(s * (wb - 6), ym + 8), (x, ym + 4), (x, ym - 10), (s * (wb - 6), ym - 8)], h - 6, h - 2, 'hull2',
                    f'pylon{e}', bevel=1)
            H.tube((x, yf, h), (x, yr, h), r * .9, r, 'metal', part, sides=8)
            H.tube((x, yf + 3, h), (x, yf, h), r * .55, r * .9, 'metal', part, sides=8)
            for b in range(1, 3):
                yb = yf + (yr - yf) * b / 3
                H.tube((x, yb + 1.4, h), (x, yb - 1.4, h), r * 1.1, r * 1.1, 'armor', f'band{e}{b}', sides=8)
            # Gargoyle intake: a horned stone head at the pod's front.
            H.ell((x, yf + 2, h + r * .3), (r * .78, r * .62, r * .72), 'stone', f'intake{e}')
            for hs in (-1, 1):
                H.chain([(x + hs * r * .45, yf, h + r * .85), (x + hs * r * .8, yf - r * .7, h + r * 1.6)], r * .2,
                        r * .06, 'horn', f'intake{e}')
        else:
            # Main engine housing set into the stern of the block.
            H.plate([(x - r * 1.25, yf + 4), (x + r * 1.25, yf + 4), (x + r * 1.25, yr + 2), (x - r * 1.25, yr + 2)],
                    0, h + r * 1.1, 'metal', f'housing{e}', bevel=1.4)
        # Flared nozzle bell with a heat band.
        H.tube((x, yr, h + (r * .55 if kind == 'main' else 0)), (x, yr - r * 1.0, h + r * .55), r * .92, r * 1.18,
               'nozzle', f'nozzle{e}', sides=10)
    # Bridge tower: stacked gothic tiers with spires and buttresses.
    T = C['tower']
    ty, tw, th, lv = T['y'], T['w'], T['h'], T['levels']
    hcur = dh
    for i in range(lv):
        ww = tw * (1 - i / (lv + 1.5))
        dd = 12 * (1 - i / (lv + 2)) + 4
        hn = dh + th * (i + 1) / lv
        poly = [(-ww, ty + dd), (ww, ty + dd), (ww + 3, ty), (ww, ty - dd), (-ww, ty - dd), (-ww - 3, ty)]
        H.plate(poly, hcur - 1, hn, 'hull' if i % 2 == 0 else 'armor', f'tier{i}', bevel=1.8)
        hcur = hn
    H.plate([(-tw * .42, ty + 6), (tw * .42, ty + 6), (tw * .38, ty - 4), (-tw * .38, ty - 4)], hcur - 1, hcur + 5,
            'glass', 'bridge', bevel=1)
    # Sensor mast and antenna.
    H.tube((tw * .3, ty - 2, hcur + 4), (tw * .3, ty - 2, hcur + 22 + k * 3), 1.0, .4, 'metal', 'mast', sides=6)
    spires = T['spires']
    for i in range(spires):
        o = i - (spires - 1) / 2
        sx = o * (tw * 1.6 / max(1, spires - 1)) if spires > 1 else 0
        tall = th * (.5 - abs(o) * .07) + 10
        base_h = dh + th * max(.3, 1 - abs(o) * .22)
        if wreck and i % 2 == 0:
            tall *= .45
        H.tube((sx, ty - 3, base_h - 4), (sx, ty - 3, base_h + tall), 3.4 - abs(o) * .25, .3,
               'stone', f'spire{i}', sides=6)
    # Flying buttresses from the waist to the tower, with pinnacles.
    for b in range(C['buttress']):
        yb = ty + 10 - b * 14
        for s in (-1, 1):
            p0 = mir((w0 - 4 - b * 2, yb + 6, dh), s)
            p1 = mir((w0 * .7, yb, dh + th * .4), s)
            p2 = mir((tw * .85, yb - 6, dh + th * .55 - b * 3), s)
            H.chain([p0, p1, p2], 2.4, 1.6, 'stone', f'buttress{b}{s}')
            H.tube(p0, (p0[0], p0[1], p0[2] + 14), 2.6, .3, 'stone', f'pinnacle{b}{s}', sides=6)
    # Point-defence turrets on the engine block.
    for t, (x, y) in enumerate(C['turrets']):
        for s in (-1, 1):
            X = x * s
            h = dh + 7
            H.plate([(X - 6, y + 5), (X + 6, y + 5), (X + 7, y), (X + 6, y - 5), (X - 6, y - 5), (X - 7, y)], h - 2,
                    h + 2, 'armor', f'dturret{t}{s}', bevel=1.2)
            H.ell((X, y, h + 2), (5, 4, 3), 'metal', f'dturret{t}{s}')
            for bx in (-1.6, 1.6):
                H.tube((X + bx, y + 1, h + 3.5), (X + bx + s * 5, y + 6, h + 5), .8, .7, 'metal', f'dturret{t}{s}', sides=6)
    # Bat-wing solar sails on finger bones, rooted on the block's flanks.
    for si, (span, frac) in enumerate(C['sails']):
        ya = E0 + (Es - E0) * frac
        root = (wb - 2, ya + 8, dh)
        wrist = (wb + span * .55, ya - span * .42, dh + 10)
        tips = [(wb + span, ya - span * .1, dh + 6), (wb + span * .92, ya + span * .22, dh + 4),
                (wb + span * .62, ya + span * .36, dh + 2)]
        for s in (-1, 1):
            rt, wr = mir(root, s), mir(wrist, s)
            tp = [mir(t, s) for t in tips]
            part = f'sail{si}{s}'
            holes = []
            if wreck:
                holes = [(lerp(wr, tp[0], .55), span * .09), (lerp(wr, tp[1], .6), span * .07),
                         (lerp(wr, tp[2], .5), span * .06)]
            pts = [tp[0], tp[1], tp[2], rt]
            for a, b in zip(pts, pts[1:]):
                sc = lerp(lerp(a, b, .5), wr, .22)
                H.tri(wr, a, sc, 'wingf', part, holes, s > 0)
                H.tri(wr, sc, b, 'wingf', part, holes, s > 0)
            H.chain([rt, lerp(rt, wr, .5), wr], 3.0, 2.2, 'wbone', f'arm{si}{s}', step=.8)
            for t in tp:
                H.chain([wr, t], 1.6, .8, 'wbone', part, step=.8)
            H.chain([wr, (wr[0] + 4 * s, wr[1] - 8, wr[2] + 4)], 1.8, .4, 'claw', f'arm{si}{s}')
            for i in range(2 + k // 2):
                b = lerp(rt, wr, .25 + i * .2)
                H.chain([b, (b[0] + 1.5 * s, b[1] - 7, b[2] + 3)], 1.2, .35, 'horn', f'arm{si}{s}')
    # Stern horns on the block's corners.
    for s in (-1, 1):
        H.chain([mir((wb - 4, Es + 4, dh + 4), s), mir((wb + 2, Es - 6, dh + 12), s),
                 mir((wb - 2, Es - 14, dh + 20), s)], 3.0, .6, 'horn', f'sternhorn{s}')


def super_frame(sh, k, f, wreck=False):
    H = G.Hull(CAM)
    build_super(H, k, f, wreck)
    mats = materials(k, f, 'super', wreck)
    cv, R = sh.rasterize(H, mats, gap=3.5)
    F = FORMS[f]
    C = CLASSES[k]
    T = C['tower']
    lit = mix(mix(F['lit'], '#ff3048', k * .2), SPACE, .15) if not wreck else EMBER_DIM[0]
    mask = np.isin(R.mat, ('hull', 'armor', 'glass', 'hull2'))

    def windows(t):
        for i in range(T['levels']):
            ww = T['w'] * (1 - i / (T['levels'] + 1.5))
            dd = 12 * (1 - i / (T['levels'] + 2)) + 4
            hn = C['dh'] + T['h'] * (i + .55) / T['levels']
            n = max(2, int(ww / 4))
            for j in range(-n + 1, n, 2):
                x, y = S(j * ww / n, T['y'] + dd, hn)
                sh.box(t, x - .5, y - .5, 1, 1.5, lit if (i + j) % 3 else '#5ef0d8')
        for j in range(-4, 5):
            x, y = S(j * T['w'] * .085, T['y'] + 6, C['dh'] + T['h'] + 2.5)
            sh.box(t, x - .5, y - .5, 1, 1, '#5ef0d8' if not wreck else EMBER_DIM[0])
        # Portholes along the waist and block walls.
        w0, w1 = C['waist']
        for yy in range(-24, int(C['E0']) + 6, -8):
            fr = (yy + 10) / (C['E0'] + 18)
            ww = w0 + (w1 - w0) * fr
            for s in (-1, 1):
                x, y = S(ww * s, yy, C['dh'] * .5)
                sh.box(t, x - .5, y, 1, 1, lit)
        for yy in range(int(C['E0']) - 10, int(C['Es']) + 10, -7):
            for s in (-1, 1):
                x, y = S(C['wb'] * s, yy, C['dh'] * .6)
                if (yy // 7) % 3:
                    sh.box(t, x - .5, y, 1, 1, lit)
    sh.masked(cv, mask, windows)
    if not wreck:
        # Glowing eyes on the gargoyle-head intakes of the engine pods.
        for x, yf, yr, h, r, kind in engine_list(k):
            if kind != 'pod':
                continue
            for es in (-1, 1):
                ex, ey = S(x + es * r * .32, yf + 2 + r * .45, h + r * .62)
                sh.box(cv, ex - .75, ey - .75, 1.5, 1, INK)
                sh.box(cv, ex - .5, ey - .5, 1, 1, F['eye'][0] if k < 3 else RUBY)
        # Heat glow on the nozzle bells' rims (the exits face away).
        nz = (R.mat == 'nozzle') & ~cv.is_color(INK)
        above = np.zeros_like(nz)
        above[1:] = nz[:-1]
        rim = nz & ~above
        rim2 = np.zeros_like(nz)
        rim2[1:] = rim[:-1]
        cv._paint(rim2 & nz, FIRE[0])
        cv._paint(rim, FIRE[2])
    fis = F['fis'] if not wreck else EMBER_DIM
    smask = np.isin(R.mat, ('hull', 'hull2', 'armor', 'stone'))

    def cracks(t):
        n = 2 + k * 2 + f
        for i in range(n):
            a = (i * 2.399) % (2 * math.pi)
            x0 = math.cos(a) * C['wb'] * (.3 + (i * .618) % .6)
            y0 = C['E0'] + (C['Es'] - C['E0']) * ((i * .37) % .9) + 8
            pts = [S(x, y, C['dh'] + 6) for x, y in ((x0, y0), (x0 + 3, y0 + 4), (x0 + 1, y0 + 8), (x0 + 4, y0 + 11))]
            sh.path(t, pts, fis[0], 3)
            sh.path(t, pts, fis[1] if i % 2 else fis[2], 1)
    sh.masked(cv, smask, cracks)
    if wreck:
        char_wreck(sh, cv, k, core=False)
    cv.outline(INK)
    return cv


def fire_points(k):
    """Hull points for flames, breaches and the wreck's chain explosions:
    engines, the tower and the sail roots (units)."""
    C = CLASSES[k]
    pts = []
    for x, yf, yr, h, r, kind in engine_list(k):
        pts.append(S(x, (yf + yr) / 2, h + r))
    T = C['tower']
    pts.append(S(0, T['y'], C['dh'] + T['h'] * .6))
    for span, frac in C['sails']:
        ya = C['E0'] + (C['Es'] - C['E0']) * frac
        for s in (-1, 1):
            pts.append(S(s * (C['wb'] + span * .25), ya - span * .1, C['dh'] + 4))
    return [(round(x, 1), round(y, 1)) for x, y in pts]


def running_lights(k):
    """(x, y, kind): 0 port red, 1 starboard green, 2 white strobe,
    3 amber bow marker."""
    C = CLASSES[k]
    out = []
    span, frac = C['sails'][0]
    ya = C['E0'] + (C['Es'] - C['E0']) * frac
    x, y = S(C['wb'] + span, ya - span * .1, C['dh'] + 6)
    out += [(-round(x, 1), round(y, 1), 0), (round(x, 1), round(y, 1), 1)]
    T = C['tower']
    x, y = S(T['w'] * .3, T['y'] - 2, C['dh'] + T['h'] + 22 + k * 3)
    out.append((round(x, 1), round(y, 1), 2))
    for s in (-1, 1):
        out.append((s * 84.0, 6.0, 3))
    x, y = S(C['wb'] - 4, C['Es'] + 4, C['dh'] + 6)
    out += [(-round(x, 1), round(y, 1), 2), (round(x, 1), round(y, 1), 2)]
    return out


# ---------------------------------------------------------------------------
# Wreck.
# ---------------------------------------------------------------------------
def char_wreck(sh, cv, k, core):
    body = cv.opaque()
    if core:
        craters = [(-30, -26, 3.2), (26, -12, 3.6), (-62, 8, 3.0), (60, -16, 2.8), (6, -42, 2.4), (-48, -30, 2.6),
                   (70, 6, 2.4)][:4 + min(k, 3)]
    else:
        C = CLASSES[k]
        craters = []
        for i, (x, y) in enumerate(fire_points(k)):
            craters.append((x + (i % 3 - 1) * 4, y + 3, 3.0 + (i % 3) * .8))
        craters = craters[:6 + 2 * k]
    ys, xs = np.mgrid[0:sh.H, 0:sh.W]
    ux, uy = (xs + .5 - sh.OX) / U, (ys + .5 - sh.OY) / U
    for cx, cy, r in craters:
        d = ((ux - cx) / r) ** 2 + ((uy - cy) / (r * .8)) ** 2
        cv._paint((d <= 1.6) & (d > 1) & body, EMBER_DIM[2] if (cx > 0) else EMBER_DIM[1])
        cv._paint((d <= 1) & body, INK)
    soot = ((xs + ys) % 4 == 0) & body & ((np.abs(ux) % 23) < 6)
    cv._paint(soot & ~cv.is_color(INK), ASH[0])


def ashify(cv):
    out = cv.copy()
    o = cv.opaque()
    rgb = cv.a[..., :3].astype(int)
    lum = (rgb[..., 0] * 3 + rgb[..., 1] * 6 + rgb[..., 2]) // 10
    ink = cv.is_color(INK)
    hot = o & (rgb[..., 0] > 200) & (rgb[..., 1] < 120)
    for i, (lo, hi) in enumerate(((0, 50), (50, 95), (95, 150), (150, 999))):
        out._paint(o & ~ink & (lum >= lo) & (lum < hi), ASH[i])
    out._paint(hot, EMBER_DIM[1])
    return out


def over(dst, src):
    m = src.opaque()
    dst.a[m] = src.a[m]


def bake_wreck_parts(sh, hull, k, f):
    """The falling wreck has no live overlays: turrets, sealed jaws and
    sealed bays are baked in ash, the maw is a dark cavity."""
    cv = hull
    over(cv, ashify(turret_frame(sh, k, f, 0)))
    vent = ashify(vent_frame(sh, 3))
    over(cv, vent)
    flipped = mirror(sh, vent)
    over(cv, flipped)
    x0, y0 = int((CORE[0] - CORE[2] / 2) * U + sh.OX), int((CORE[1] - CORE[3] / 2) * U + sh.OY)
    cv.a[y0:y0 + CORE[3] * U, x0:x0 + CORE[2] * U] = 0
    sh.box(cv, CORE[0] - CORE[2] / 2, CORE[1] - CORE[3] / 2, CORE[2], CORE[3], INK)
    sh.ell(cv, CORE[0], CORE[1], 5, 3, EMBER_DIM[0])
    sh.ell(cv, CORE[0], CORE[1], 2.4, 1.4, EMBER_DIM[1])
    over(cv, ashify(jaws_frame(sh, k, 1)))
    return cv


def mirror(sh, cv):
    """Mirror about the carrier centre's x (not the canvas centre)."""
    out = sh.canvas()
    xs = np.arange(sh.W)
    src = np.round(2 * sh.OX - 1 - xs).astype(int)
    ok = (src >= 0) & (src < sh.W)
    out.a[:, xs[ok]] = cv.a[:, src[ok]]
    return out


# ---------------------------------------------------------------------------
# Overlays: turrets, jaws, bay doors, damage, debris, engine plumes.
# ---------------------------------------------------------------------------
def turret_frame(sh, k, f, c):
    """Gun turrets under the chin: an armoured dome with a gargoyle face
    plate whose eyes and muzzle glow breathe (the scene's tracking barrels
    pivot at the muzzle)."""
    glow = [('#4a1424', '#9e1b1b'), ('#9e1b1b', '#ff6b1a'), ('#ff6b1a', '#ffe042'), ('#9e1b1b', '#ff6b1a')][c]
    H = G.Hull(CAM)
    tx, ty = TURRET
    for s in (-1, 1):
        # Ship point whose screen position is the pivot at h = 6.
        base = (tx * s, ty + 6 * SP, 6)
        H.plate([(tx * s - 7, ty + 2), (tx * s + 7, ty + 2), (tx * s + 8, ty + 8), (tx * s - 8, ty + 8)], 0, 5,
                'armor', f'tbase{s}', bevel=1.2)
        H.ell(base, (6.5, 5.5, 5), 'metal', f'tdome{s}')
        for hs in (-1, 1):
            H.chain([(tx * s + hs * 4, ty + 2, 10), (tx * s + hs * 7, ty - 2, 13), (tx * s + hs * 8, ty - 5, 14)], 1.2,
                    .35, 'horn', f'thorn{s}')
    m = materials(k, f, 'core')
    cv, R = sh.rasterize(H, {'armor': m['armor'], 'metal': m['metal'], 'horn': m['horn']}, tex=False)
    for s in (-1, 1):
        cx = tx * s
        sh.ell(cv, cx, ty + .6, 3.0, 1.9, INK)
        sh.ell(cv, cx, ty + .6, 2.1, 1.2, glow[0])
        sh.ell(cv, cx, ty + .4, 1.1, .6, glow[1])
        for es in (-1, 1):
            sh.box(cv, cx + es * 2.6 - .5, ty - 4.2, 1.5, 1, INK)
            cv.rect((cx + es * 2.6 - .5) * U + sh.OX, (ty - 4.2) * U + sh.OY + 1, 2, 1, glow[1])
        for fs in (-1, 1):
            sh.poly(cv, [(cx + fs * 2.6, ty - .8), (cx + fs * 1.4, ty - .8), (cx + fs * 2.0, ty + 1.6)], FANG)
    cv.outline(INK)
    return cv


def clip(sh, cv, x0, y0, x1, y1):
    """Keep only the pixels inside a functional window (units)."""
    a0, a1 = int(round(x0 * U + sh.OX)), int(round(x1 * U + sh.OX))
    b0, b1 = int(round(y0 * U + sh.OY)), int(round(y1 * U + sh.OY))
    keep = np.zeros(cv.a.shape[:2], dtype=bool)
    keep[b0:b1, a0:a1] = True
    cv.a[~keep] = 0
    return cv


def slab(sh, cv, x0, y0, x1, y1, ramp, lit_top=True):
    if y1 - y0 <= .4 or x1 - x0 <= 0:
        return
    sh.box(cv, x0, y0, x1 - x0, y1 - y0, ramp[1])
    if lit_top:
        sh.box(cv, x0, y0, x1 - x0, min(1, y1 - y0), ramp[2])
    if y1 - y0 > 2:
        sh.box(cv, x0, y1 - 1, x1 - x0, 1, ramp[0])
    if y1 - y0 > 5:
        yy = (y0 + y1) / 2
        sh.line(cv, (x0 + 1, yy), (x1 - 1.5, yy), ramp[0])
        for rx in (x0 + 2, x1 - 3):
            sh.box(cv, rx, y0 + 1.5, .5, .5, ramp[3])


def jaws_frame(sh, k, c):
    """Fanged blast jaws over the maw: armoured leaves with riveted plates;
    the upper jaw rises and the lower drops as the door opens."""
    cv = sh.canvas()
    ramp = darken(('#16121f', '#2c2538', '#4a4060', '#6e6488'), CLASSES[k]['dark'] * .5)
    cx, cy, w, h = CORE
    x0, x1 = cx - w / 2, cx + w / 2
    y0, y1 = cy - h / 2, cy + h / 2
    t = c / 3
    hh = (h / 2) * (1 - t)
    up_y1, lo_y0 = y0 + hh, y1 - hh
    slab(sh, cv, x0, y0, x1, up_y1, ramp)
    slab(sh, cv, x0, lo_y0, x1, y1, ramp)
    big = 6.4 if c < 3 else 3.2
    small = 2.8 if c < 3 else 1.6
    for fx in (-12.5, -4.5, 4.5, 12.5):
        fang(sh, cv, cx + fx, up_y1 - .2, 3.4, big, True)
    for fx in (-8.5, 0, 8.5):
        fang(sh, cv, cx + fx, up_y1 - .2, 2.0, small, True)
    for fx in (-8.5, 0, 8.5):
        fang(sh, cv, cx + fx, lo_y0 + .2, 3.2, big * .85, False, BONE[2])
    for fx in (-13, 13):
        fang(sh, cv, cx + fx, lo_y0 + .2, 2.0, small, False, BONE[2])
    if c == 0:
        sh.box(cv, cx - 1.5, cy - 1, 3, 2, INK)
        sh.box(cv, cx - 1, cy - .5, 2, 1, RUBY)
    return clip(sh, cv, x0, y0, x1, y1)


def vent_frame(sh, c):
    """Left hangar bay door: three armoured slats with clawed tips retract
    into the outer frame as the bay opens; the final form seals the bay
    with a rune-locked plate (drawn mirrored for the right bay)."""
    cv = sh.canvas()
    cx, cy, w, h = BAY
    cx = -cx
    x0, x1 = cx - w / 2, cx + w / 2
    y0, y1 = cy - h / 2, cy + h / 2
    if c == 3:
        slab(sh, cv, x0, y0, x1, y1, ('#1c1828', '#3a3450', '#625a7c', '#8e86aa'))
        sh.line(cv, (x0 + 1.5, y0 + 1.5), (x1 - 2, y1 - 2), '#1c1828', 3)
        sh.line(cv, (x1 - 2, y0 + 1.5), (x0 + 1.5, y1 - 2), '#1c1828', 3)
        sh.ell(cv, cx - .5, cy - .5, 2.6, 2.2, INK)
        sh.ell(cv, cx - .5, cy - .5, 1.7, 1.3, '#ff274e')
        cv.px((cx - .5) * U + sh.OX - 1, (cy - .5) * U + sh.OY - 1, '#ffc7af')
        for bx in (x0 + 1.2, x1 - 2.2):
            for by in (y0 + 1.2, y1 - 2.2):
                sh.box(cv, bx, by, 1, 1, BONE[2])
        return cv
    t = c / 2
    L = (w - 3.5) * (1 - t) + 2.5 * t
    band = h / 3
    ramp = ('#1e1a2a', '#4a4660', '#7a7894', '#b0aec4')
    for i in range(3):
        fy0 = y0 + i * band + .3
        fy1 = fy0 + band - .6
        my = (fy0 + fy1) / 2
        fx1 = x0 + L
        sh.poly(cv, [(x0 - .5, fy0 - .5), (fx1, fy0 - .5), (fx1 + .8, my), (fx1, fy1 + .5), (x0 - .5, fy1 + .5)], INK)
        sh.poly(cv, [(x0, fy0), (fx1 - .5, fy0), (fx1 + .3, my), (fx1 - .5, fy1), (x0, fy1)], ramp[1])
        sh.line(cv, (x0, fy0 + .3), (fx1 - 1, fy0 + .3), ramp[2], 2)
        sh.line(cv, (x0, fy1 - .3), (fx1 - 1, fy1 - .3), ramp[0])
        if L > 8:
            for j in range(int(L // 5)):
                sh.box(cv, x0 + 2 + j * 5, my - .3, .5, .5, ramp[3])
            hz = x0 + L - 4
            sh.poly(cv, [(hz, fy0 + .6), (hz + 1.4, fy0 + .6), (hz + 2.4, my), (hz + 1, my)], '#e8b030')
        if c < 2:
            tx = fx1
            sh.poly(cv, [(tx - 1.8, fy0 + .4), (tx + 2.6, my - .4), (tx + 1.6, fy1 + (3.0 if i < 2 else .25)), (tx - .8, fy1 - .4)], INK)
            sh.poly(cv, [(tx - 1.2, fy0 + .9), (tx + 2.0, my - .1), (tx + 1.2, fy1 + (2.3 if i < 2 else .1)), (tx - .8, fy1 - .9)], FANG)
            sh.line(cv, (tx - .6, fy0 + 1.4), (tx + 1.0, my), '#ffffff')
    return clip(sh, cv, x0, y0, x1, y1)


CRACKS_1 = [[(-34, -30), (-30, -24), (-33, -18), (-29, -12)], [(31, -32), (28, -25), (32, -18)],
            [(-8, -44), (-11, -38), (-9, -34)], [(66, -4), (70, 2), (67, 8)], [(-64, -2), (-60, 4)]]
CRACKS_2 = [[(-22, -40), (-26, -34), (-23, -28)], [(20, -42), (25, -36), (22, -30)], [(-72, 10), (-76, 18)],
            [(52, -24), (56, -16), (53, -10)], [(12, -44), (9, -38)], [(-50, 30), (-46, 36)]]
CHUNKS_2 = [(-40, -28, 3.2, 2.4), (62, -10, 2.8, 2.2), (14, -36, 2.4, 2.0)]
CHUNKS_3 = [(-70, 4, 3.4, 2.6), (40, -34, 3.0, 2.4), (-20, -38, 2.6, 2.0), (70, 16, 3.0, 2.2), (-56, 32, 2.6, 2.0)]


def crack(sh, cv, path, width, glow, flick=0):
    sh.path(cv, path, CRACK[0], width + 2)
    sh.path(cv, path, CRACK[1 + (flick % 2)], width)
    if width >= 3:
        sh.path(cv, path, glow, max(1, width - 2))


def chunk(sh, cv, cx, cy, rx, ry, hot):
    pts = []
    for i in range(7):
        a = i * 2 * math.pi / 7 + .4
        r = 1.0 if i % 2 == 0 else .72
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    sh.poly(cv, pts, CRACK[0])
    sh.poly(cv, [(cx + (x - cx) * .72, cy + (y - cy) * .72 + .2) for x, y in pts], CRACK[1])
    sh.poly(cv, [(cx + (x - cx) * .4, cy + (y - cy) * .4 + .3) for x, y in pts], hot)


def damage_frame(sh, stage, flick, mask):
    """Bow damage: cracked plating, then torn plates over the glowing
    interior, then gaping breaches; clipped to the bow silhouette."""
    cv = sh.canvas()
    hot = CRACK[3] if flick else CRACK[4]
    if stage >= 1:
        for i, p in enumerate(CRACKS_1):
            crack(sh, cv, p, (1, 3, 5)[stage - 1], hot, flick + i)
    if stage >= 2:
        for i, p in enumerate(CRACKS_2):
            crack(sh, cv, p, 1 if stage == 2 else 3, hot, flick + i)
        for ch in CHUNKS_2:
            k = 1.0 if stage == 2 else 1.3
            chunk(sh, cv, ch[0], ch[1], ch[2] * k, ch[3] * k, hot)
    if stage >= 3:
        for ch in CHUNKS_3:
            chunk(sh, cv, *ch, hot)
    cv.a[~mask] = 0
    return cv


def breach_frame(stage, flick):
    """A small burning breach for the superstructure (placed by the scene
    on the class's fire points): 3 stages x 2 flicker frames, 24 x 16."""
    w, h = 48, 32
    cv = Canvas(w, h)
    hot = CRACK[3] if flick else CRACK[4]
    r = (5, 8, 11)[stage - 1]
    pts = []
    for i in range(9):
        a = i * 2 * math.pi / 9 + .3 + flick * .2
        rr = r * (1.0 if i % 2 == 0 else .62)
        pts.append((w / 2 + math.cos(a) * rr * 1.5, h / 2 + math.sin(a) * rr))
    cv.poly(pts, CRACK[0])
    cv.poly([(w / 2 + (x - w / 2) * .7, h / 2 + (y - h / 2) * .7) for x, y in pts], CRACK[1])
    cv.poly([(w / 2 + (x - w / 2) * .4, h / 2 + (y - h / 2) * .4) for x, y in pts], hot)
    for i in range(stage + 1):
        a = i * 2.2 + flick
        cv.line((w / 2, h / 2), (w / 2 + math.cos(a) * r * 2.1, h / 2 + math.sin(a) * r * 1.3), CRACK[1], 1)
    cv.outline(INK)
    return cv


def debris_frames(sh, k):
    """Wreck debris tumbling from the fall: a torn sail shard, a snapped
    horn with a plate, nacelle sections (more for bigger classes)."""
    out = []
    mats = {'hull': ASH, 'armor': ASH, 'metal': CHAR, 'wingf': CHAR, 'wbone': ASH_BONE, 'horn': ASH_BONE,
            'stone': ASH, 'nozzle': CHAR}
    for i in range(2 + k):
        H = G.Hull(CAM)
        kind = i % 3
        if kind == 0:
            wr, tips = (-10, -20, 0), [(-30, 8, 0), (-14, 24, 0), (8, 22, 0)]
            H.tri(wr, tips[0], tips[1], 'wingf', 'w', [((-18, 6, 0), 3)])
            H.tri(wr, tips[1], tips[2], 'wingf', 'w')
            for t in tips:
                H.chain([wr, t], 1.6, .9, 'wbone', 'b')
        elif kind == 1:
            H.chain([(-12, 0, 4), (0, -10, 8), (10, -6, 10), (12, 4, 12)], 4, 1.5, 'horn', 'h')
            H.plate([(-10, 4), (8, 4), (10, 16), (-8, 18)], 0, 6, 'hull', 'p', bevel=1.2)
        else:
            H.tube((0, 14, 6), (0, -12, 6), 7, 7.5, 'metal', 'n', sides=8)
            H.tube((0, -12, 6), (0, -18, 6), 7, 8.5, 'nozzle', 'z', sides=8)
        cv, R = sh.rasterize(H, mats, tex=False)
        body = cv.opaque()
        sh.masked(cv, body, lambda t: (sh.path(t, [(-8, -6), (-2, 2), (-6, 10)], CRACK[1], 2),
                                       sh.path(t, [(-8, -6), (-2, 2), (-6, 10)], CRACK[3], 1)))
        cv.outline(INK)
        out.append(cv)
    return out


def plume_frame(r, level, flick):
    """An engine plume rising from a nozzle of radius r (units): stepped
    thermal layers (crimson, orange, amber, white core) with shock diamonds.
    Canvas origin: the nozzle exit at the bottom centre."""
    L = (2.4 * r + 8, 3.8 * r + 14, 5.4 * r + 20)[level] * (1.0 if flick == 0 else .9)
    wu = r * .82
    w, h = int(math.ceil(wu * 2 + 4)) * U, int(math.ceil(L + 4)) * U
    cv = Canvas(w, h)
    ox, oy = w / 2, h - 2 * U

    def P(x, y):
        return (ox + x * U, oy - y * U)

    # A straight jet column that tapers late: crimson sheath, orange,
    # amber, yellow, a white-hot core leaving the nozzle.
    for layer, (wf, lf, col) in enumerate(((1.0, 1.0, FIRE[0]), (.84, .9, FIRE[1]), (.68, .78, FIRE[2]),
                                           (.5, .64, FIRE[3]), (.32, .5, FIRE[4]), (.16, .34, FIRE[5]))):
        ww = wu * wf
        top = L * lf
        jag = (1 if (layer + flick) % 2 else -1) * .5
        cv.poly([P(-ww, 0), P(-ww, top * .42), P(-ww * .8 + jag, top * .64), P(-ww * .45, top * .84),
                 P(jag * .5, top), P(ww * .45, top * .84), P(ww * .8 - jag, top * .64), P(ww, top * .42),
                 P(ww, 0)], col)
    # Shock diamonds along the core.
    for i in range(1 + level):
        yy = L * (.2 + i * .22) + flick * 1.2
        d = max(1.0, wu * .3)
        cv.poly([P(0, yy - d * 1.6), P(d, yy), P(0, yy + d * 1.6), P(-d, yy)], FIRE[5] if i % 2 == 0 else FIRE[4])
    # Ember sparks above the tip.
    for i in range(2):
        cv.rect(ox + (i * 2 - 1) * U * (1 + flick), oy - (L + 1 + i * 1.5) * U, 2, 2, FIRE[4 - i])
    return cv


# ---------------------------------------------------------------------------
# Packing and outputs.
# ---------------------------------------------------------------------------
def crop(cv):
    o = cv.opaque()
    ys, xs = np.nonzero(o)
    if len(xs) == 0:
        return None, 0, 0
    x0, x1 = (xs.min() // 2) * 2, xs.max() + 1
    y0, y1 = (ys.min() // 2) * 2, ys.max() + 1
    x1 += x1 % 2
    y1 += y1 % 2
    return cv.a[y0:y1, x0:x1].copy(), x0, y0


class Packer:
    def __init__(self, width):
        self.width = width
        self.items = []

    def add(self, name, arr, dx, dy):
        """dx, dy: top-left of the sprite in design units from its anchor."""
        self.items.append(dict(name=name, a=arr, dx=dx, dy=dy))
        return len(self.items) - 1

    def pack(self):
        """Skyline bottom-left packing, tallest first (deterministic)."""
        order = sorted(range(len(self.items)), key=lambda i: (-self.items[i]['a'].shape[0],
                                                              -self.items[i]['a'].shape[1], i))
        sky = [(0, 0, self.width)]  # (x, y, width) segments
        height = 0
        for i in order:
            h, w = self.items[i]['a'].shape[:2]
            best = None
            for j in range(len(sky)):
                x = sky[j][0]
                if x + w > self.width:
                    break
                y, span, k = 0, 0, j
                while span < w:
                    y = max(y, sky[k][1])
                    span += sky[k][2]
                    k += 1
                if best is None or (y + h, x) < (best[0] + h, best[1]):
                    best = (y, x)
            y, x = best
            self.items[i]['x'], self.items[i]['y'] = x, y
            height = max(height, y + h)
            # Raise the skyline under the placed item.
            new = []
            for sx, sy, sw in sky:
                a0, a1 = sx, sx + sw
                if a1 <= x or a0 >= x + w:
                    new.append((sx, sy, sw))
                    continue
                if a0 < x:
                    new.append((a0, sy, x - a0))
                if a1 > x + w:
                    new.append((x + w, sy, a1 - x - w))
            new.append((x, y + h, w))
            new.sort()
            merged = []
            for seg in new:
                if merged and merged[-1][1] == seg[1] and merged[-1][0] + merged[-1][2] == seg[0]:
                    merged[-1] = (merged[-1][0], seg[1], merged[-1][2] + seg[2])
                else:
                    merged.append(seg)
            sky = merged
        img = np.zeros((height, self.width, 4), dtype=np.uint8)
        for it in self.items:
            a = it['a']
            h, w = a.shape[:2]
            img[it['y']:it['y'] + h, it['x']:it['x'] + w] = a
        img[..., 3] = np.where(img[..., 3] > 0, 255, 0)
        return img


def put_layer(pk, sh, name, cv):
    a, x0, y0 = crop(cv)
    return pk.add(name, a, (x0 - sh.OX) / U, (y0 - sh.OY) / U)


def patch(base, frame):
    """Idle frame as a patch over idle frame 0: the bbox of the changed
    pixels, or the whole frame when a pixel would have to turn transparent."""
    diff = np.any(base.a != frame.a, axis=-1)
    lost = diff & base.opaque() & ~frame.opaque()
    if lost.any() or not diff.any():
        return frame, False
    ys, xs = np.nonzero(diff)
    out = Canvas(frame.w, frame.h)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    out.a[y0:y1, x0:x1] = frame.a[y0:y1, x0:x1]
    # Keep only opaque pixels of the frame inside the box.
    return out, True


def build_class(k):
    C = CLASSES[k]
    sh = Sheet(k)
    pk = Packer(2048)
    rec = dict(key=C['key'], title=C['title'], forms=form_count(k))
    nf = form_count(k)
    rec['super'] = [put_layer(pk, sh, f'super{f}', super_frame(sh, k, f)) for f in range(nf)]
    sw = super_frame(sh, k, nf - 1, wreck=True)
    if k >= 2:
        # Bigger hulls snap in two as they fall.
        left, right = sw.copy(), sw.copy()
        cut = int(sh.OX)
        ys = np.arange(sh.H)
        jag = (np.abs(((ys // 6) % 4) - 2) * 3).astype(int)
        for y in range(sh.H):
            left.a[y, cut + jag[y] - 3:] = 0
            right.a[y, :cut + jag[y] - 3] = 0
        rec['superWreck'] = [put_layer(pk, sh, 'superwreckL', left), put_layer(pk, sh, 'superwreckR', right)]
    else:
        rec['superWreck'] = [put_layer(pk, sh, 'superwreck', sw)]
    rec['hull'] = []
    bow_mask = None
    for f in range(nf):
        frames = [bow_frame(sh, k, f, i) for i in range(4)]
        m = frames[0].opaque()
        bow_mask = m if bow_mask is None else (bow_mask & m)
        row = [put_layer(pk, sh, f'hull{f}i0', frames[0])]
        for i in range(1, 4):
            p, ok = patch(frames[0], frames[i])
            row.append(put_layer(pk, sh, f'hull{f}i{i}' + ('p' if ok else ''), p))
        rec['hull'].append(row)
        rec.setdefault('hullPatch', []).append([False] + [pk.items[j]['name'].endswith('p') for j in row[1:]])
    rec['hullWreck'] = put_layer(pk, sh, 'hullwreck', bow_frame(sh, k, nf - 1, 0, wreck=True))
    rec['turrets'] = [put_layer(pk, sh, f'turret{c}', turret_frame(sh, k, nf - 1 if k >= 3 else 0, c))
                      for c in range(4)]
    rec['jaws'] = [put_layer(pk, sh, f'jaw{c}', jaws_frame(sh, k, c)) for c in range(4)]
    rec['vents'] = [put_layer(pk, sh, f'vent{c}', vent_frame(sh, c)) for c in range(4)]
    rec['damage'] = [[put_layer(pk, sh, f'dmg{s}{fl}', damage_frame(sh, s, fl, bow_mask)) for fl in (0, 1)]
                     for s in (1, 2, 3)]
    rec['breach'] = []
    for s in (1, 2, 3):
        row = []
        for fl in (0, 1):
            cv = breach_frame(s, fl)
            row.append(pk.add(f'breach{s}{fl}', cv.a.copy(), -cv.w / 2 / U, -cv.h / 2 / U))
        rec['breach'].append(row)
    rec['debris'] = []
    for i, cv in enumerate(debris_frames(sh, k)):
        a, x0, y0 = crop(cv)
        w, h = a.shape[1], a.shape[0]
        rec['debris'].append(pk.add(f'debris{i}', a, -w / 2 / U, -h / 2 / U))
    radii = sorted({e[4] for e in engine_list(k)})
    rec['plumes'] = []
    for r in radii:
        sizes = []
        for lvl in range(3):
            fr = []
            for fl in (0, 1):
                cv = plume_frame(r, lvl, fl)
                a = cv.a.copy()
                fr.append(pk.add(f'plume{r}-{lvl}{fl}', a, -cv.w / 2 / U, -(cv.h - 2 * U) / U))
            sizes.append(fr)
        rec['plumes'].append(sizes)
    rec['engines'] = [(x, y, radii.index(r)) for x, y, r in nozzles(k)]
    rec['lights'] = running_lights(k)
    rec['fire'] = fire_points(k)
    img = pk.pack()
    rec['pk'] = pk
    rec['size'] = (img.shape[1], img.shape[0])
    target = ROOT / f'assets/images/boss-{C["key"]}.png'
    Image.fromarray(img, 'RGBA').save(target, optimize=True)
    # Visual extent (units) of everything drawn for this class.
    ext = [1e9, 1e9, -1e9, -1e9]
    for it in pk.items:
        if it['name'].startswith(('super', 'hull')) and 'wreck' not in it['name']:
            h, w = it['a'].shape[:2]
            ext = [min(ext[0], it['dx']), min(ext[1], it['dy']), max(ext[2], it['dx'] + w / U),
                   max(ext[3], it['dy'] + h / U)]
    rec['extent'] = ext
    print(f'Generated {target.relative_to(ROOT)}: {img.shape[1]}x{img.shape[0]} '
          f'({img.shape[0] * img.shape[1] * 4 / 2 ** 20:.1f} MiB RGBA)')
    return rec


def dart_sprite(pk, i):
    it = pk.items[i]
    h, w = it['a'].shape[:2]
    return f"BossSprite({it['x']}, {it['y']}, {w}, {h}, {it['dx']:g}, {it['dy']:g})"


def write_dart(recs):
    L = ['// GENERATED by tools/generate_boss_sprites.py - do not edit by hand.',
         '// Contract: plan/sprite-atlas.md, "Boss armada atlases".',
         '',
         '/// One sprite in a boss atlas: its source rect (px, stored 1x) and the',
         '/// top-left of its destination in arena units from its anchor (the',
         '/// carrier centre; a nozzle exit for plumes; the sprite centre for',
         '/// breaches and debris). It is drawn at w / 2 x h / 2 units.',
         'class BossSprite {',
         '  const BossSprite(this.x, this.y, this.w, this.h, this.dx, this.dy);',
         '  final int x, y, w, h;',
         '  final double dx, dy;',
         '}',
         '',
         '/// One hull class (one per run) and its atlas.',
         'class BossHull {',
         '  const BossHull({',
         '    required this.key,',
         '    required this.title,',
         '    required this.asset,',
         '    required this.width,',
         '    required this.height,',
         '    required this.forms,',
         '    required this.superstructure,',
         '    required this.superWreck,',
         '    required this.hull,',
         '    required this.hullPatch,',
         '    required this.hullWreck,',
         '    required this.turrets,',
         '    required this.jaws,',
         '    required this.vents,',
         '    required this.damage,',
         '    required this.breach,',
         '    required this.debris,',
         '    required this.plumes,',
         '    required this.engines,',
         '    required this.lights,',
         '    required this.fire,',
         '    required this.extent,',
         '  });',
         '  final String key, title, asset;',
         '  final int width, height, forms;',
         '  /// Background layer per form (stern, tower, engines, sails).',
         '  final List<BossSprite> superstructure;',
         '  /// Falling superstructure: one piece, or left and right halves.',
         '  final List<BossSprite> superWreck;',
         '  /// Bright bow per form: idle frames 0-3 (1-3 may be patches over 0).',
         '  final List<List<BossSprite>> hull;',
         '  final List<List<bool>> hullPatch;',
         '  final BossSprite hullWreck;',
         '  final List<BossSprite> turrets, jaws, vents, debris;',
         '  /// Bow damage stage 1-3 x two flicker frames.',
         '  final List<List<BossSprite>> damage, breach;',
         '  /// Engine plumes: [nozzle size][thrust level 0-2][flicker 0-1].',
         '  final List<List<List<BossSprite>>> plumes;',
         '  /// Nozzle exits (x, y units from the centre) and their plume size.',
         '  final List<(double, double, int)> engines;',
         '  /// Running lights: 0 port red, 1 starboard green, 2 strobe, 3 amber.',
         '  final List<(double, double, int)> lights;',
         '  /// Points for superstructure fires, breaches and wreck explosions.',
         '  final List<(double, double)> fire;',
         '  /// Visual extent (left, top, right, bottom) of the live hull, units.',
         '  final (double, double, double, double) extent;',
         '}',
         '',
         'abstract final class BossAtlas {',
         '  /// Functional anchors (units from the carrier centre), identical for',
         '  /// every class and equal to the simulation geometry.',
         f'  static const coreWindow = (x: {CORE[0]:.1f}, y: {CORE[1]:.1f}, w: {CORE[2]:.1f}, h: {CORE[3]:.1f});',
         f'  static const bayWindow = (x: {BAY[0]:.1f}, y: {BAY[1]:.1f}, w: {BAY[2]:.1f}, h: {BAY[3]:.1f});',
         f'  static const turretPivot = (x: {TURRET[0]:.1f}, y: {TURRET[1]:.1f});',
         f'  static const solidBody = (halfWidth: {BODY[0]:.1f}, top: {BODY[1]:.1f}, bottom: {BODY[2]:.1f});',
         '  static const classes = <BossHull>[']
    for r in recs:
        pk = r['pk']
        sp = lambda i: dart_sprite(pk, i)  # noqa: E731
        L.append('    BossHull(')
        L.append(f"      key: '{r['key']}',")
        L.append(f"      title: '{r['title']}',")
        L.append(f"      asset: 'boss-{r['key']}.png',")
        L.append(f"      width: {r['size'][0]},")
        L.append(f"      height: {r['size'][1]},")
        L.append(f"      forms: {r['forms']},")
        L.append('      superstructure: [' + ', '.join(sp(i) for i in r['super']) + '],')
        L.append('      superWreck: [' + ', '.join(sp(i) for i in r['superWreck']) + '],')
        L.append('      hull: [')
        for row in r['hull']:
            L.append('        [' + ', '.join(sp(i) for i in row) + '],')
        L.append('      ],')
        L.append('      hullPatch: [' + ', '.join('[' + ', '.join('true' if b else 'false' for b in row) + ']'
                                               for row in r['hullPatch']) + '],')
        L.append(f"      hullWreck: {sp(r['hullWreck'])},")
        for name in ('turrets', 'jaws', 'vents', 'debris'):
            L.append(f'      {name}: [' + ', '.join(sp(i) for i in r[name]) + '],')
        for name in ('damage', 'breach'):
            L.append(f'      {name}: [' + ', '.join('[' + ', '.join(sp(i) for i in row) + ']' for row in r[name]) + '],')
        L.append('      plumes: [')
        for size in r['plumes']:
            L.append('        [' + ', '.join('[' + ', '.join(sp(i) for i in lv) + ']' for lv in size) + '],')
        L.append('      ],')
        L.append('      engines: [' + ', '.join(f'({x:g}, {y:g}, {s})' for x, y, s in r['engines']) + '],')
        L.append('      lights: [' + ', '.join(f'({x:g}, {y:g}, {s})' for x, y, s in r['lights']) + '],')
        L.append('      fire: [' + ', '.join(f'({x:g}, {y:g})' for x, y in r['fire']) + '],')
        e = r['extent']
        L.append(f'      extent: ({e[0]:g}, {e[1]:g}, {e[2]:g}, {e[3]:g}),')
        L.append('    ),')
    L += ['  ];', '}', '']
    (ROOT / 'lib/game/boss_atlas.dart').write_text('\n'.join(L))


def main():
    only = [a for a in sys.argv[1:] if not a.startswith('-')]
    recs = []
    for k, C in enumerate(CLASSES):
        if only and C['key'] not in only:
            continue
        recs.append(build_class(k))
    if not only:
        write_dart(recs)
        total = sum(r['size'][0] * r['size'][1] * 4 for r in recs)
        print(f'Armada atlases: {total / 2 ** 20:.1f} MiB RGBA in all; one class is resident at a time.')


if __name__ == '__main__':
    main()
