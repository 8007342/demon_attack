"""Generate the gargoyle war-ark carrier atlas on its native grid.

    .cache/asset-venv/bin/python tools/generate_boss_sprites.py

Output: assets/images/boss-carrier.png, 1472 x 2640: four columns x eleven
rows of 368 x 240 cells, stored 1x (the PNG pixel is the logical pixel).
The scene draws each cell at 184 x 120 arena units ("design units", 2 native
px each), unchanged in size and placement since the mechanical hull.

The hull, its wing sails, horns, talons and spout heads are built from the
same deterministic 3-D rig as the gargoyles and sentinels
(tools/gargoyle_rig.py: ellipsoids, sphere chains and bat-wing membrane
triangles, z-buffered, quantised top-left key light, contour and outline
passes). Faces, the emblem, rank carvings, fissures, jaws and vents are
pixel decals in design units. Optional AI shading detail
(art/families/carrier/detail/*.png, finished by tools/sprite_pipeline.py from
SDXL + pixel-art-xl sources) nudges the key-light value of stone and
membrane pixels, exactly as the gargoyle hide maps do.

Rows (contract: plan/sprite-atlas.md):
 0     hull forms, idle frame 0 (col = form)
 1     talon poses (closed, half, flared, clamped) with chimney soul-fire
 2     spout-head turrets, four breathing frames
 3     0 cracked stone, 1 split stone with broken chunks, 2/3 petrified
       debris (left wing shard, right horn and masonry)
 4     maw jaws at openness 0, 1/3, 2/3, 1 (fanged stone shutters)
 5     left clawed vent at openness 0, 1/2, 1, then petrified lock
       (mirrored for the right vent)
 6     petrified, charred wreck of each form
 7-9   hull forms, idle frames 1-3 (wing-sail breath, eye pulse, spine
       twitch, fissure flicker)
 10    0/1 flicker frames of damage stages 1/2, 2/3 critical stage frames

No randomness except fixed tables; same inputs, same bytes.
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

CW, CH = 368, 240
COLS, ROWS = 4, 11
U = 2                      # native px per design unit
OX, OY = CW / 2, CH / 2    # cell centre = carrier centre
DETAIL = ROOT / 'art/families/carrier/detail'

INK = '#0a0716'            # gargoyle outline (sprite_kit 'gink')
BONE = ('#4a3a2e', '#9a8466', '#d8c69a', '#fff3d6')
FANG = '#fff3d6'
RUBY = '#ff355f'
WHITE = '#fffbe0'

# ---------------------------------------------------------------------------
# Forms: the corruption escalates from violet-grey stone through bruised
# plum and ember-cracked crimson to a crowned obsidian-and-gold final form.
# ---------------------------------------------------------------------------
FORMS = [
    dict(  # 0 Carrier: weathered violet-grey stone, amber eyes
        stone=('#1c1830', '#3a3254', '#625984', '#958cb8'),
        wing=('#140e26', '#251a44', '#3e2f6c', '#57468c'),
        wbone=('#3a3046', '#7a6c7c', '#b4a698', '#d8c69a'),
        horn=BONE, trim=('#3a3046', '#7a6c7c', '#b4a698', '#e6d8b4'),
        eye=('#ff9f2e', '#ffd23f', '#7a3a10'), fis=('#4a1424', '#c04a2a', '#ffa040'),
        rank='chevron', prow=.6),
    dict(  # 1 Brood Ark: bruised plum stone, magenta fissures
        stone=('#24112c', '#4a2457', '#7a4a8e', '#b886c8'),
        wing=('#170a1f', '#2e1240', '#4e2268', '#6e3c88'),
        wbone=('#3e2a3a', '#806678', '#bea494', '#d8c69a'),
        horn=BONE, trim=('#3e2a3a', '#806678', '#bea494', '#e6d8b4'),
        eye=('#ff6a3a', '#ffc04a', '#6a1e2a'), fis=('#4a0e2c', '#d0306a', '#ff86b0'),
        rank='bars', prow=.85),
    dict(  # 2 Siege Ark: ember-cracked crimson basalt, lava fissures
        stone=('#200c14', '#4c1a26', '#843440', '#c0645c'),
        wing=('#16080e', '#30101a', '#561c2a', '#7a3036'),
        wbone=('#3e2a26', '#86685a', '#c4a68a', '#d8c69a'),
        horn=('#3a2a22', '#8a7058', '#ccb48a', '#fff3d6'), trim=('#5a2a12', '#a8521c', '#ff8a2a', '#ffd06a'),
        eye=('#ffbf1f', '#ffe042', '#7a2410'), fis=('#5a1008', '#ff6b1a', '#ffe042'),
        rank='fangs', prow=1.0),
    dict(  # 3 Flagship: obsidian with a gold crown, gold-veined fissures
        stone=('#0e0b18', '#221d36', '#3e3760', '#6c6496'),
        wing=('#0e0a14', '#1e1626', '#34263c', '#4c3a50'),
        wbone=('#3e2108', '#7a4a12', '#c8902a', '#ffd866'),
        horn=('#2a2238', '#4e4466', '#c8902a', '#ffd866'), trim=('#3e2108', '#7a4a12', '#c8902a', '#ffd866'),
        eye=('#ffd866', '#fffbe0', '#7a4a12'), fis=('#3e2108', '#c8902a', '#fff0a8'),
        rank='star', prow=1.1),
]
# Petrified, charred wreck ramps.
ASH = ('#16141c', '#2e2a34', '#504a58', '#7c7484')
CHAR = ('#0e0b0e', '#1a1418', '#2a2026', '#3a2c30')
ASH_BONE = ('#2a2426', '#4e4644', '#7a706a', '#9a9088')
EMBER_DIM = ('#2a0c0c', '#9e1b1b', '#e8430c')
SPOUT = ('#1a1626', '#363048', '#5e5678', '#9088ac')
JAW = ('#16121f', '#2c2538', '#4a4060', '#6e6488')

# Damage effects ramp (cracks and exposed glowing interior).
CRACK = ('#1a0a10', '#9e1b1b', '#ff6b1a', '#ffbf1f', '#ffe042')

# Idle cycle: wing-sail breath, eye pulse (0 dim, 1 lit, 2 flare), spine
# twitch set (0 none, 1 first set, 2 second set).
BREATH = (0.0, .5, 1.0, .5)
PULSE = (1, 2, 1, 0)
TWITCH = (0, 1, 0, 2)


# ---------------------------------------------------------------------------
# Rig plumbing (native px; design units scaled by U).
# ---------------------------------------------------------------------------
class Raster(G.Raster):
    """The gargoyle raster with window-limited spheres (hundreds of bone
    and horn spheres per frame at 368 x 240)."""

    def sphere(self, s):
        r = max(s.r, .72)
        cx, cy = s.c[0] + self.origin[0], s.c[1] + self.origin[1]
        x0, x1 = max(0, int(cx - r - 1)), min(self.w, int(cx + r + 2))
        y0, y1 = max(0, int(cy - r - 1)), min(self.h, int(cy + r + 2))
        if x1 <= x0 or y1 <= y0:
            return
        sl = (slice(y0, y1), slice(x0, x1))
        dx, dy = self.px[sl] - s.c[0], self.py[sl] - s.c[1]
        d2 = dx * dx + dy * dy
        hit = d2 <= r * r
        if not hit.any():
            return
        dz = np.sqrt(np.maximum(r * r - d2, 0))
        z = s.c[2] + dz
        sel = hit & (z > self.z[sl])
        if not sel.any():
            return
        n = np.stack([dx, dy, dz], -1) / r
        self.z[sl][sel] = z[sel]
        self.n[sl][sel] = n[sel]
        p3 = self.p3[sl]
        p3[sel, 0] = self.px[sl][sel]
        p3[sel, 1] = self.py[sl][sel]
        p3[sel, 2] = z[sel]
        self.mat[sl][sel] = s.mat
        self.part[sl][sel] = s.part
        self.back[sl][sel] = False


class Scene:
    def __init__(self):
        self.prims = []

    @staticmethod
    def P(p):
        return np.array([p[0] * U, p[1] * U, p[2] * U], float)

    def ell(self, c, r, mat, part, rot=None):
        m = rot if rot is not None else np.eye(3)
        self.prims.append(G.Ellipsoid(self.P(c), np.asarray(r, float) * U, m, mat, part))

    def sph(self, c, r, mat, part):
        self.prims.append(G.Sphere(self.P(c), r * U, mat, part))

    def chain(self, pts, r0, r1, mat, part, step=.5):
        pts = [np.asarray(p, float) for p in pts]
        seg = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
        total = sum(seg) or 1
        acc = 0
        for i, L in enumerate(seg):
            n = max(1, int(L / step))
            for k in range(n + (1 if i == len(seg) - 1 else 0)):
                t = k / n
                p = pts[i] + (pts[i + 1] - pts[i]) * t
                self.sph(p, r0 + (r1 - r0) * ((acc + L * t) / total), mat, part)
            acc += L

    def tri(self, a, b, c, mat, part, holes=(), flip=False):
        self.prims.append(G.Tri((self.P(a), self.P(b), self.P(c)), mat, part,
                                [(self.P(h), r * U) for h, r in holes], flip))


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mir(p, s):
    return (p[0] * s,) + tuple(p[1:])


_detail_cache = {}


def detail(name):
    """Four-level AI luminance map -> key-light offsets (0 where absent)."""
    if name not in _detail_cache:
        path = DETAIL / f'{name}.png'
        if path.exists():
            a = np.array(Image.open(path).convert('RGBA')).astype(int)
            lv = np.digitize(a[..., 0], (70, 135, 205))  # placeholder greys 40/100/170/240
            off = (lv - 1.5) * .075
            off[a[..., 3] == 0] = 0
            _detail_cache[name] = off
        else:
            _detail_cache[name] = None
    return _detail_cache[name]


MASONRY = ('shoulder', 'haunch', 'chimney', 'buttress', 'belly')


def texture(R):
    """Key-light offsets: AI hide detail on carved stone, AI masonry on the
    bastions, chimneys, buttresses and belly (procedural courses when the
    map is absent), AI membrane leather on the sails, rings on horns."""
    t = np.zeros((R.h, R.w))
    stone = (R.mat == 'stone') | (R.mat == 'stone_dk')
    part = R.part.astype(str)
    mason = np.zeros(stone.shape, dtype=bool)
    for name in MASONRY:
        mason |= np.char.startswith(part, name)
    mason &= stone
    ys, xs = np.mgrid[0:R.h, 0:R.w]
    hide, ms, mb = detail('hide'), detail('masonry'), detail('membrane')
    if hide is not None:
        t[stone & ~mason] += hide[stone & ~mason] * 1.3
    if ms is not None:
        t[mason] += ms[mason] * 2.4
    else:
        course = (ys + 3) // 12
        seam = ((ys + 3) % 12 == 0) | (((xs + course * 9) % 22) == 0)
        t[mason & seam] -= .42
    wing = R.mat == 'wingf'
    if mb is not None:
        t[wing] += mb[wing] * 1.6
    horn = R.mat == 'horn'
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


def rasterize(scene, mats, tex=True):
    R = Raster(CW, CH, (OX, OY))
    for p in scene.prims:
        if isinstance(p, G.Ellipsoid):
            R.ellipsoid(p)
        elif isinstance(p, G.Sphere):
            R.sphere(p)
        else:
            R.tri(p)
    names = G.shade(R, mats, texture(R) if tex else None)
    cv = Canvas(CW, CH)
    for name in sorted(set(names[names != ''].tolist())):
        cv._paint(names == name, name)
    G._clean_specks(cv, R, names)
    contours(cv, R)
    return cv, R


# ---------------------------------------------------------------------------
# 2-D decal helpers in design units.
# ---------------------------------------------------------------------------
def N(p):
    return (p[0] * U + OX, p[1] * U + OY)


def dpoly(cv, pts, color):
    cv.poly([N(p) for p in pts], color)


def dline(cv, a, b, color, width=1):
    """Native-resolution line, `width` native px."""
    cv.line(N(a), N(b), color, width)


def dpath(cv, pts, color, width=1):
    for a, b in zip(pts, pts[1:]):
        dline(cv, a, b, color, width)


def dbox(cv, x, y, w, h, color):
    cv.rect(x * U + OX, y * U + OY, w * U, h * U, color)


def dell(cv, cx, cy, rx, ry, color):
    cv.ellipse(cx * U + OX, cy * U + OY, rx * U, ry * U, color)


def masked(cv, mask, draw):
    tmp = Canvas(CW, CH)
    draw(tmp)
    m = tmp.opaque() & mask
    cv.a[m] = tmp.a[m]


# ---------------------------------------------------------------------------
# Hull.
# ---------------------------------------------------------------------------
def wing(S, s, breath, holes=(), spines=0, twitch=0):
    """Folded bat-membrane sail along the flank: the arm arches over the
    bastion like a gothic vault, three long finger bones fall along the
    flank and the scalloped membrane hangs between them. Breath lifts the
    wrist and spreads the fingers a little."""
    root = (s * 34, -20, -9)
    elbow = (s * 57, -40 - breath, -11)
    wrist = (s * 81, -31 - 1.5 * breath, -13)
    tips = [(s * (91 + .3 * breath), -1 + 1.2 * breath, -13),
            (s * (86 + .6 * breath), 19 + 1.6 * breath, -13),
            (s * (72 + .6 * breath), 29 + 1.4 * breath, -12)]
    hip = (s * 52, 26, -10)
    flank = (s * 40, 0, -10)

    def scallop(a, b, d=.24):
        return lerp(lerp(a, b, .5), wrist, d)

    pts = [wrist] + tips
    part = f'wing{s}'
    for a, b in ((tips[0], tips[1]), (tips[1], tips[2])):
        sc = scallop(a, b)
        S.tri(wrist, a, sc, 'wingf', part, holes, s > 0)
        S.tri(wrist, sc, b, 'wingf', part, holes, s > 0)
    sc = scallop(tips[2], hip, .2)
    for t in ((wrist, tips[2], sc), (wrist, sc, hip), (wrist, hip, flank),
              (wrist, flank, elbow), (elbow, flank, root)):
        S.tri(*t, 'wingf', part, holes, s > 0)
    S.chain([root, elbow], 2.6, 2.1, 'wbone', f'arm{s}')
    S.chain([elbow, wrist], 2.1, 1.7, 'wbone', f'arm{s}')
    for t in tips:
        S.chain([wrist, t], 1.35, .8, 'wbone', part)
    # Thumb hook at the wrist.
    S.chain([wrist, (s * 83, -38 - breath, -12), (s * 81, -41 - breath, -12)], 1.4, .5, 'claw', f'arm{s}')
    # Spines along the forearm (twitching: set 1 = first spine, 2 = others).
    for i in range(spines):
        f = .25 + i * .25
        base = lerp(elbow, wrist, f)
        tw = 1.6 if (twitch == 1 and i % 2 == 0) or (twitch == 2 and i % 2 == 1) else 0
        tip = (base[0] + s * (1.5 + tw), base[1] - 6 + abs(tw) * .3, base[2])
        S.chain([base, tip], 1.1, .35, 'horn', f'arm{s}')
    return dict(root=root, elbow=elbow, wrist=wrist, tips=tips)


def horn_chain(S, pts, r0, r1, part='horn', mat='horn'):
    S.chain(pts, r0, r1, mat, part)


def build_hull(form, breath=0.0, twitch=0, wreck=False):
    S = Scene()
    F = FORMS[form]
    spines = (2, 3, 3, 3)[form]
    for s in (-1, 1):
        holes = []
        if wreck:
            holes = [(mir((70, 6, -13), s), 3.6 + form * .3), (mir((80, 16, -13), s), 2.6),
                     (mir((60, 18, -11), s), 2.4)]
        else:
            # Ragged notches at the scallops, like every gargoyle.
            holes = [(mir((86, 14, -13), s), 1.3), (mir((76, 27, -12), s), 1.4)]
        wing(S, s, breath, holes, spines if not wreck else 1, twitch)

    for s in (-1, 1):
        # Bastion shoulders and haunches: carved masonry.
        S.ell(mir((39, -5, 0), s), (17, 17, 9), 'stone', f'shoulder{s}', G.rot_z(-12 * s))
        S.ell(mir((44, 19, -1), s), (16, 13, 8), 'stone', f'haunch{s}')
        # Carved shoulder pauldron ridge.
        S.ell(mir((40, -17, 5), s), (14, 3.4, 4), 'stone', f'ridge{s}', G.rot_z(-14 * s))
        # Gothic flying buttress on the outer shoulder with a pinnacle.
        S.chain([mir((57, 14, 1), s), mir((62, 0, 1), s), mir((59, -14, 2), s), mir((50, -21, 4), s)],
                2.8, 2.0, 'stone', f'buttress{s}')
        S.chain([mir((62, 0, 2), s), mir((64, -8, 2), s), mir((65, -15, 2), s)], 2.2, .5, 'stone', f'buttress{s}')
        # Two chimney pinnacles (open tops: the soul-fire of row 1 rises here).
        # Gothic chimney pinnacles: tapered stacks with a ringed cap.
        S.chain([mir((30, -18, 5), s), mir((30, -34, 5), s)], 4.6, 3.2, 'stone', f'chimney{s}')
        S.chain([mir((48, -16, 3), s), mir((48, -30, 3), s)], 4.0, 2.8, 'stone', f'chimney{s}')
        S.ell(mir((30, -34.5, 6), s), (4.4, 1.6, 3), 'trim', f'cap{s}')
        S.ell(mir((48, -30.5, 4), s), (3.8, 1.5, 3), 'trim', f'cap{s}')
        # Horned prows: down-swept bone horns from the haunches.
        k = F['prow'] if not wreck else F['prow'] * .6
        S.chain([mir((58, 22, 2), s), mir((58 + 7 * k, 28 + 3 * k, 2), s), mir((58 + 10 * k, 36 + 6 * k, 1), s)],
                2.6, .6, 'horn', f'prow{s}')
        # Bone keel ribs under the jowls.
        S.chain([mir((34, 30, 3), s), mir((24, 38, 5), s), mir((14, 41, 6), s)], 1.8, 1.2, 'wbone', f'rib{s}')

    # Underside belly between the bastions.
    S.ell((0, 28, -3), (42, 10, 8), 'stone_dk', 'belly')
    # Central gargoyle head-fortress.
    S.ell((0, -13, 4), (24, 22, 14), 'stone', 'head')
    # Sagittal crest and angry V brows over the eyes.
    S.ell((0, -27, 12), (4, 9, 4), 'stone', 'crest')
    for s in (-1, 1):
        S.ell(mir((11.5, -9.5, 15), s), (11, 3.6, 5), 'stone', 'brow', G.rot_z(20 * s))
        S.ell(mir((20, -1, 11), s), (7, 4, 5), 'stone', 'cheek', G.rot_z(-25 * s))
    for s in (-1, 1):
        S.ell(mir((16, 9, 9), s), (12, 12, 9), 'stone', f'jowl{s}')
        # Tusks flanking the maw.
        S.chain([mir((18, 12, 14), s), mir((19, 17, 15), s), mir((17.5, 22, 15), s)], 1.9, .6, 'claw', f'tusk{s}')
    S.ell((0, 5, 16), (11, 9, 9), 'stone', 'snout')
    S.ell((0, 38, 5), (19, 6, 7), 'stone', 'chin')

    # Horns: lyre horns from the crown of the head.
    broken = wreck
    for s in (-1, 1):
        pts = [mir((9, -31, 9), s), mir((15, -41, 8), s), mir((20, -50, 6), s), mir((16, -58, 4), s)]
        if broken and s < 0:
            pts = pts[:3]
        horn_chain(S, pts, 3.4, .9 if not (broken and s < 0) else 2.2, f'horn{s}')
        if form >= 2:
            # Ram curls at the temples.
            horn_chain(S, [mir((19, -14, 14), s), mir((24, -18, 14), s), mir((28, -24, 13), s)], 2.2, .5, f'ram{s}')
    # Dorsal spines (form 1-2) or a gold crown (form 3) between the horns.
    if form in (1, 2):
        for i, (x, h) in enumerate(((0, 9), (-5.5, 7), (5.5, 7))):
            tw = 1.4 if (twitch == 1 and i == 0) or (twitch == 2 and i > 0) else 0
            S.chain([(x, -33, 8), (x + (tw if x >= 0 else -tw), -33 - h, 7)], 1.6, .4, 'horn', 'spine')
    if form == 3:
        for i, (x, h) in enumerate(((0, 13), (-6, 9), (6, 9), (-11, 6), (11, 6))):
            tw = 1.0 if (twitch == 1 and i in (1, 2)) or (twitch == 2 and i in (3, 4)) else 0
            S.chain([(x, -32, 9), (x * 1.15 + (tw if x >= 0 else -tw), -32 - h, 8)], 1.9, .45, 'trim', 'crown')
        S.ell((0, -32, 9), (13, 2.2, 3), 'trim', 'crown')
    # Shoulder spines that twitch on every form.
    for s in (-1, 1):
        for i, x in enumerate((38, 42)):
            tw = 1.5 if (twitch == 1 and i == 0) or (twitch == 2 and i == 1) else 0
            base = mir((x, -20, 6), s)
            S.chain([base, mir((x + 1 + tw, -27, 5), s)], 1.3, .35, 'horn', f'shoulder{s}')

    if wreck:
        mats = {'stone': ASH, 'stone_dk': (ASH[0], ASH[0], ASH[1], ASH[2]), 'wingf': CHAR,
                'wbone': ASH_BONE, 'horn': ASH_BONE, 'claw': ASH_BONE, 'trim': ASH_BONE}
    else:
        st = F['stone']
        mats = {'stone': st, 'stone_dk': (st[0], st[0], st[1], st[2]), 'wingf': F['wing'],
                'wbone': F['wbone'], 'horn': F['horn'], 'claw': BONE, 'trim': F['trim']}
    return S, mats


# Fissure tables (design units): glowing cracks are the hull's light, with
# more of them on each corrupted form.
FISSURES = [
    [[(-25, -27), (-21, -21), (-24, -15)], [(23, -29), (20, -23), (23, -18)],
     [(-53, -10), (-49, -4), (-52, 3)], [(51, -12), (55, -5), (51, 1)]],
    [[(-23, 5), (-19, 11)], [(19, 11), (23, 5)], [(-40, 20), (-34, 24), (-30, 32)], [(30, 32), (35, 26), (40, 22)],
     [(-6, -30), (-3, -26)]],
    [[(-60, 8), (-56, 14), (-59, 20)], [(56, 10), (60, 16), (57, 22)], [(-30, -6), (-27, -12), (-30, -18)],
     [(28, -16), (31, -10), (27, -4)], [(0, 30), (-4, 34), (2, 38)]],
    [[(-46, -16), (-40, -18), (-34, -14)], [(34, -14), (40, -18), (46, -16)]],
]


def draw_fissures(cv, R, F, form, f, wreck=False):
    stone = (R.mat == 'stone') | (R.mat == 'stone_dk')
    paths = [p for k in range(form + 1) for p in FISSURES[k]]
    dark, mid, hot = EMBER_DIM if wreck else F['fis']

    def draw(t):
        for i, path in enumerate(paths):
            dpath(t, path, dark, 3)
        for i, path in enumerate(paths):
            lit = hot if (i + f) % 3 else mid
            if wreck:
                lit = mid if (i % 2) else dark
            dpath(t, path, lit, 1)
    masked(cv, stone, draw)


EYE_L = [(-20, -8.5), (-13, -6), (-6.5, -3.2), (-7.5, -.2), (-13, -.8), (-19.5, -4.5)]
EYE_CORE_L = [(-18, -7), (-13, -4.8), (-8.5, -2.6), (-9, -1.2), (-13, -2), (-17.6, -4.8)]


def draw_face(cv, R, F, pulse, wreck=False):
    rim, core, halo = F['eye']
    if wreck:
        rim, core, halo = '#2e2a34', '#504a58', None
    stone = R.mat == 'stone'
    for s in (-1, 1):
        eye = [(x * s, y) for x, y in EYE_L]
        ec = [(x * s, y) for x, y in EYE_CORE_L]
        if pulse == 2 and halo:
            # Flare: the brow underside and cheeks catch the eye light.
            ecx = -12.8 * s
            ring = [(ecx + (x - ecx) * 1.3, -3.6 + (y + 3.6) * 1.9) for x, y in eye]
            masked(cv, stone, lambda t, ring=ring: dpoly(t, ring, halo))
        dpoly(cv, [(x, y - .6) for x, y in eye], INK)
        dpoly(cv, eye, rim)
        if not wreck:
            dpoly(cv, ec, core if pulse > 0 else rim)
            if pulse == 2:
                dpoly(cv, [lerp(p, (-12.5 * s, -3), .5) for p in ec], WHITE)
            # Slit pupil.
            dline(cv, (-13 * s, -5.2), (-13 * s, -1.6), INK, 2)
    # Nostrils breathing faint smoke-glow.
    for s in (-1, 1):
        dell(cv, 3.6 * s, 6, 1.6, 1.1, INK)
        if not wreck:
            cv.px(3.6 * s * U + OX - (1 if s < 0 else 0), 6 * U + OY, F['fis'][1] if pulse else F['fis'][0])


def draw_emblem(cv, F, form, wreck=False):
    cx, cy, k = 0, -23.5, 1.35
    crest = [(-7, -4), (-4, -1), (0, -3), (4, -1), (7, -4), (5, 2), (0, 5), (-5, 2)]
    inner = [(-5.5, -2.5), (-3.5, 0), (0, -1.5), (3.5, 0), (5.5, -2.5), (4, 1.5), (0, 4), (-4, 1.5)]
    trim = F['trim'] if not wreck else ASH_BONE
    dpoly(cv, [(cx + x * k, cy + y * k - .5) for x, y in crest], INK)
    dpoly(cv, [(cx + x * k, cy + y * k) for x, y in inner], trim[2])
    dpoly(cv, [(cx + x * k * .8, cy + y * k * .8 + .7) for x, y in inner], trim[1])
    dell(cv, cx, cy + 1, 2.0, 1.7, RUBY if not wreck else EMBER_DIM[0])
    if not wreck:
        cv.px(cx * U + OX, (cy + .4) * U + OY, '#ffffff')
    # One rank pip per form, lit like the eyes.
    for i in range(form + 1):
        px = cx - form * 1.6 + i * 3.2
        dbox(cv, px - .5, cy + 6.5, 1, 1, INK)
        cv.rect((px - .5) * U + OX, (cy + 6.5) * U + OY, 2, 2, F['eye'][1] if not wreck else ASH[2])


def draw_rank(cv, F, form, wreck=False):
    """Rank carvings on both bastions, matching the gargoyle insignia:
    chevron (teal), twin bars (violet), fang slashes (coral), star jewel
    (gold)."""
    light = F['trim'][3] if not wreck else ASH[3]
    mid = F['trim'][2] if not wreck else ASH[2]
    for s in (-1, 1):
        cx, cy = 40 * s, -7
        kind = F['rank']
        if kind == 'chevron':
            for d, col in ((.6, INK), (0, light)):
                dpath(cv, [(cx - 4, cy - 2 + d), (cx, cy + 2 + d), (cx + 4, cy - 2 + d)], col, 3)
        elif kind == 'bars':
            for yy in (-2, 2):
                dbox(cv, cx - 4, cy + yy - 1, 8, 2.5, INK)
                dbox(cv, cx - 3.5, cy + yy - 1, 7, 1.5, '#8a9cc8' if not wreck else mid)
        elif kind == 'fangs':
            for i in (-1, 0, 1):
                dline(cv, (cx + i * 3 - 1, cy - 4), (cx + i * 3 + 1.5, cy + 3.5), INK, 4)
                dline(cv, (cx + i * 3 - 1, cy - 4), (cx + i * 3 + 1.5, cy + 3.5), light, 2)
        else:
            pts = []
            for i in range(10):
                a = -math.pi / 2 + i * math.pi / 5
                r = 5 if i % 2 == 0 else 2.2
                pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
            dpoly(cv, [(x, y - .5) for x, y in pts], INK)
            dpoly(cv, pts, light)
            dpoly(cv, [(cx + (x - cx) * .6, cy + (y - cy) * .6 + .4) for x, y in pts], mid)
            dell(cv, cx, cy + .3, 1.3, 1.2, RUBY if not wreck else EMBER_DIM[0])


def draw_chimney_mouths(cv, F, wreck=False):
    for s in (-1, 1):
        for x, top, w in ((30, -36.2, 3.6), (48, -32.2, 3.0)):
            dell(cv, x * s, top + 1.3, w, 1.3, INK)
            dell(cv, x * s, top + 1.6, w * .6, .7, (F['fis'][1] if not wreck else EMBER_DIM[0]))


def hull_frame(form, f, wreck=False):
    S, mats = build_hull(form, BREATH[f], TWITCH[f], wreck)
    cv, R = rasterize(S, mats)
    F = FORMS[form]
    draw_fissures(cv, R, F, form, f, wreck)
    draw_chimney_mouths(cv, F, wreck)
    draw_face(cv, R, F, PULSE[f], wreck)
    draw_emblem(cv, F, form, wreck)
    draw_rank(cv, F, form, wreck)
    draw_openings(cv, ASH if wreck else F['stone'], ASH_BONE if wreck else F['horn'])
    if wreck:
        char_wreck(cv, R, form)
        cv = bake_wreck_parts(cv)
    cv.outline(INK)
    return cv


def ashify(cv):
    """Petrify a part canvas: luminance onto the ash ramp, ink kept, any red
    glow reduced to a dying ember."""
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


def bake_wreck_parts(hull):
    """The falling wreck has no live overlays: talons, spout heads, sealed
    jaws and petrified vents are baked into it in ash, and the maw is a dark
    cavity with a dying ember."""
    cv = ashify(talons_frame(3, fire=False))
    over(cv, hull)
    over(cv, ashify(spouts_frame(0)))
    vent = ashify(vent_frame(3))
    over(cv, vent)
    flipped = vent.copy()
    flipped.flip_x()
    over(cv, flipped)
    x0, y0 = int((CORE[0] - CORE[2] / 2) * U + OX), int((CORE[1] - CORE[3] / 2) * U + OY)
    cv.a[y0:y0 + CORE[3] * U, x0:x0 + CORE[2] * U] = 0
    dbox(cv, CORE[0] - CORE[2] / 2, CORE[1] - CORE[3] / 2, CORE[2], CORE[3], INK)
    dell(cv, CORE[0], CORE[1], 5, 3, EMBER_DIM[0])
    dell(cv, CORE[0], CORE[1], 2.4, 1.4, EMBER_DIM[1])
    over(cv, ashify(jaws_frame(1)))
    return cv


def char_wreck(cv, R, form):
    """Blast craters with ember rims and soot on the petrified hull."""
    body = cv.opaque()
    craters = [(-30, -14, 3.2), (26, -2, 3.6), (-46, 14, 3.0), (48, -12, 2.8), (6, -36, 2.4), (-62, -6, 2.6),
               (64, 8, 2.4)][:4 + form]
    ys, xs = np.mgrid[0:CH, 0:CW]
    ux, uy = (xs + .5 - OX) / U, (ys + .5 - OY) / U
    for cx, cy, r in craters:
        d = ((ux - cx) / r) ** 2 + ((uy - cy) / (r * .8)) ** 2
        cv._paint((d <= 1.6) & (d > 1) & body, EMBER_DIM[2] if (cx > 0) else EMBER_DIM[1])
        cv._paint((d <= 1) & body, INK)
    # Soot streaks rising from the craters (dithered, hard pixels).
    soot = ((xs + ys) % 4 == 0) & body & (uy < 0) & ((np.abs(ux) % 23) < 6)
    cv._paint(soot & ~cv.is_color(INK), ASH[0])


# ---------------------------------------------------------------------------
# Row 1: talons and chimney soul-fire.
# ---------------------------------------------------------------------------
TALON_POSES = [  # (curl, spread) per column: closed, half, flared, clamped
    (.75, .2), (.45, .55), (.15, 1.0), (1.0, 0.0)]
FLAME_H = (8, 14, 20, 18)


def talons_frame(c, fire=True):
    curl, spread = TALON_POSES[c]
    S = Scene()
    for s in (-1, 1):
        sh = mir((34, 26, -2), s)
        wr = mir((36 + 4 * spread, 40, -1), s)
        S.chain([sh, wr], 4.2, 3.4, 'stone', f'arm{s}')
        S.ell(wr, (5.2, 4.2, 4), 'stone', f'hand{s}')
        for i in range(3):
            a = math.radians(-50 + i * 50) * (.4 + .9 * spread) + math.radians(90)
            dx, dy = math.cos(a) * s, math.sin(a)
            p1 = (wr[0] + dx * 7, wr[1] + dy * 7, 0)
            # Curl bends the talon back toward the body's centre line.
            ca = a + math.radians(70 * curl) * (-1 if i == 0 else 1)
            p2 = (p1[0] + math.cos(ca) * s * 5, p1[1] + math.sin(ca) * 5, 0)
            S.chain([wr, p1], 1.8, 1.4, 'stone', f'hand{s}')
            S.chain([p1, p2], 1.3, .35, 'claw', f'claw{s}{i}')
    neutral = ('#1c1828', '#3a3450', '#625a7c', '#8e86aa')
    cv, R = rasterize(S, {'stone': neutral, 'claw': BONE}, tex=False)
    # Soul-fire from the four chimney pinnacles: stepped pixel flame tongues
    # in the thermal ramp, heights flickering per frame.
    if not fire:
        cv.outline(INK)
        return cv
    h = FLAME_H[c]
    fire = ('#9e1b1b', '#e8430c', '#ff6b1a', '#ffbf1f', '#ffe042', '#fffdf7')
    for s in (-1, 1):
        for x, base, scale in ((30, -35, 1.0), (48, -31, .8)):
            hh = h * scale * (1.0 if (c + (x == 48)) % 2 else .85)
            x0 = x * s
            for layer, (wf, col) in enumerate(((1.0, fire[0]), (.8, fire[2]), (.55, fire[3]), (.3, fire[5]))):
                top = base - hh * (1 - layer * .16)
                w = 3.6 * wf
                lean = .6 * ((c % 2) * 2 - 1) * s
                dpoly(cv, [(x0 - w, base), (x0 - w * .8 + lean * .3, (base + top) / 2), (x0 + lean, top),
                           (x0 + w * .8 + lean * .3, (base + top) / 2), (x0 + w, base)], col)
            # Rising embers.
            for k in range(2):
                ey = base - hh - 3 - k * 4 - c
                cv.rect((x0 + (k * 2 - 1) * s * 1.5) * U + OX, ey * U + OY, 2, 2, fire[4 - k])
    cv.outline(INK)
    return cv


# ---------------------------------------------------------------------------
# Row 2: spout-head turrets (the overlay barrels pivot at (+-28, 36)).
# ---------------------------------------------------------------------------
def spouts_frame(c):
    glow = [('#4a1424', '#9e1b1b'), ('#9e1b1b', '#ff6b1a'), ('#ff6b1a', '#ffe042'), ('#9e1b1b', '#ff6b1a')][c]
    S = Scene()
    for s in (-1, 1):
        S.ell(mir((28, 32, 10), s), (6.5, 5.2, 5), 'stone', f'spout{s}')
        S.ell(mir((28, 36, 12), s), (4.2, 3, 4), 'stone', f'snout{s}')
        for hs in (-1, 1):
            S.chain([mir((28 + hs * 4, 28.5, 10), s), mir((28 + hs * 7.5, 25.5, 9), s), mir((28 + hs * 8, 22.5, 8), s)],
                    1.3, .4, 'claw', f'spouthorn{s}')
    cv, R = rasterize(S, {'stone': SPOUT, 'claw': BONE}, tex=False)
    for s in (-1, 1):
        cx = 28 * s
        dell(cv, cx, 37.2, 3.2, 1.9, INK)
        dell(cv, cx, 37.2, 2.3, 1.2, glow[0])
        dell(cv, cx, 37.0, 1.2, .6, glow[1])
        for es in (-1, 1):
            dbox(cv, cx + es * 2.4 - .5, 31, 1.5, 1, INK)
            cv.rect((cx + es * 2.4 - .5) * U + OX, 31 * U + OY + 1, 2, 1, glow[1])
        # Fangs at the mouth corners.
        for fs in (-1, 1):
            dpoly(cv, [(cx + fs * 2.6, 35.6), (cx + fs * 1.4, 35.6), (cx + fs * 2.0, 38.0)], FANG)
    cv.outline(INK)
    return cv


# ---------------------------------------------------------------------------
# Row 3 / 10: damage overlays (stone cracking, broken chunks, widening
# fissures) on the head and bastions, which do not move with the breath.
# ---------------------------------------------------------------------------
CRACKS_1 = [[(-34, -18), (-30, -12), (-33, -6), (-29, 0)], [(31, -20), (28, -13), (32, -6)],
            [(-8, -36), (-11, -30), (-9, -26)], [(44, 6), (48, 12), (45, 18)], [(-50, 8), (-46, 14)]]
CRACKS_2 = [[(-22, 2), (-26, 8), (-23, 14)], [(20, 0), (25, 6), (22, 12)], [(-56, -12), (-60, -4)],
            [(54, -14), (58, -6), (55, 0)], [(12, -36), (9, -30)], [(-38, 24), (-34, 30)]]
CHUNKS_2 = [(-36, -24, 3.2, 2.4), (52, 2, 2.8, 2.2), (14, -30, 2.4, 2.0)]
CHUNKS_3 = [(-58, 4, 3.4, 2.6), (34, -26, 3.0, 2.4), (-18, -32, 2.6, 2.0), (44, 24, 3.0, 2.2), (-44, 26, 2.6, 2.0)]


def crack(cv, path, width, glow, flick=0):
    dpath(cv, path, CRACK[0], width + 2)
    dpath(cv, path, CRACK[1 + (flick % 2)], width)
    if width >= 3:
        dpath(cv, path, glow, max(1, width - 2))


def chunk(cv, cx, cy, rx, ry, hot):
    """A chunk broken out of the stone: a jagged cavity showing the glowing
    interior, its chipped rim lit by it."""
    pts = []
    for i in range(7):
        a = i * 2 * math.pi / 7 + .4
        r = 1.0 if i % 2 == 0 else .72
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    dpoly(cv, [(x, y) for x, y in pts], CRACK[0])
    dpoly(cv, [(cx + (x - cx) * .72, cy + (y - cy) * .72 + .2) for x, y in pts], CRACK[1])
    dpoly(cv, [(cx + (x - cx) * .4, cy + (y - cy) * .4 + .3) for x, y in pts], hot)


def damage_frame(stage, flick):
    cv = Canvas(CW, CH)
    hot = CRACK[3] if flick else CRACK[4]
    if stage == 1:
        for i, p in enumerate(CRACKS_1):
            crack(cv, p, 1, hot, flick + i)
    elif stage == 2:
        for i, p in enumerate(CRACKS_1):
            crack(cv, p, 3, hot, flick + i)
        for i, p in enumerate(CRACKS_2):
            crack(cv, p, 1, hot, flick + i)
        for ch in CHUNKS_2:
            chunk(cv, *ch, hot)
    else:
        for i, p in enumerate(CRACKS_1):
            crack(cv, p, 5, hot, flick + i)
        for i, p in enumerate(CRACKS_2):
            crack(cv, p, 3, hot, flick + i)
        for ch in CHUNKS_2:
            chunk(cv, ch[0], ch[1], ch[2] * 1.3, ch[3] * 1.3, hot)
        for ch in CHUNKS_3:
            chunk(cv, *ch, hot)
        # Membrane rents in both sails.
        for s in (-1, 1):
            for cx, cy, r in ((74, 8, 3.0), (64, 20, 2.4), (84, 18, 1.8)):
                dell(cv, cx * s, cy, r, r * .8, INK)
                dell(cv, cx * s, cy, r * .55, r * .45, CRACK[1] if flick else CRACK[0])
    return cv


def debris_frame(side):
    """Petrified debris for the falling wreck: a broken wing shard (left)
    and a snapped horn with a masonry block (right)."""
    S = Scene()
    if side < 0:
        wrist, tips = (-62, -24, 0), [(-80, 8, 0), (-66, 26, 0), (-44, 30, 0)]
        S.tri(wrist, tips[0], tips[1], 'wingf', 'w', [((-68, 10, 0), 3)])
        S.tri(wrist, tips[1], tips[2], 'wingf', 'w')
        for t in tips:
            S.chain([wrist, t], 1.6, .9, 'wbone', 'b')
        S.chain([(-40, -34, 1), wrist], 2.4, 2.0, 'wbone', 'b')
    else:
        S.chain([(40, -20, 2), (52, -30, 2), (62, -26, 2), (64, -14, 2)], 4, 1.5, 'horn', 'h')
        S.ell((52, 18, 0), (14, 11, 9), 'stone', 's')
        S.ell((30, 6, 0), (8, 7, 6), 'stone', 's2')
    cv, R = rasterize(S, {'stone': ASH, 'wingf': CHAR, 'wbone': ASH_BONE, 'horn': ASH_BONE}, tex=False)
    body = cv.opaque()
    if side < 0:
        masked(cv, body, lambda t: (dpath(t, [(-62, -24), (-70, -10), (-64, 4)], CRACK[1], 2),
                                    dpath(t, [(-40, -34), (-42, -30)], CRACK[2], 3)))
    else:
        masked(cv, body, lambda t: (dpath(t, [(42, 10), (50, 16), (46, 26)], CRACK[0], 3),
                                    dpath(t, [(42, 10), (50, 16), (46, 26)], CRACK[2], 1),
                                    dpath(t, [(64, -14), (63, -16)], CRACK[3], 3)))
    cv.outline(INK)
    return cv


# ---------------------------------------------------------------------------
# Row 4: maw jaws (scene: core window 32 x 22 at (0, 25)).
# ---------------------------------------------------------------------------
CORE = (0, 25, 32, 22)
SIDE = (-46, 21, 22, 16)


def stone_slab(cv, x0, y0, x1, y1, ramp, lit_top=True):
    """A shutter slab of carved stone: lit top edge, shadowed lower edge,
    two chiselled courses."""
    if y1 - y0 <= .4 or x1 - x0 <= 0:
        return
    dbox(cv, x0, y0, x1 - x0, y1 - y0, ramp[1])
    if lit_top:
        dbox(cv, x0, y0, x1 - x0, min(1, y1 - y0), ramp[2])
    if y1 - y0 > 2:
        dbox(cv, x0, y1 - 1, x1 - x0, 1, ramp[0])
    for k in (1,):
        yy = y0 + (y1 - y0) * k / 2
        if y1 - y0 > 5:
            dline(cv, (x0 + 1, yy), (x1 - 1.5, yy), ramp[0])


def fang(cv, x, y, w, length, down, col=FANG):
    """A fang with an ink edge; `down` points it toward +y."""
    sgn = 1 if down else -1
    dpoly(cv, [(x - w / 2 - .5, y), (x + w / 2 + .5, y), (x, y + sgn * (length + .8))], INK)
    dpoly(cv, [(x - w / 2, y), (x + w / 2, y), (x, y + sgn * length)], col)
    dline(cv, (x - w / 4, y + sgn * .3), (x - w / 8, y + sgn * length * .6), '#ffffff' if col == FANG else BONE[3])


def draw_openings(cv, ramp, horn=BONE):
    """The carved stone lip of the maw and the rims of both vents, in the
    form's own stone (they belong to the hull; rows 4 and 5 hold only the
    moving jaws and talons). Windows stay transparent for the scene's core
    and vent overlays."""
    cx, cy, w, h = CORE
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - h / 2, cy + h / 2
    lip = [(x0 - 4.5, y0 - 1), (x0 - 1, y0 - 4.5), (x1 + 1, y0 - 4.5), (x1 + 4.5, y0 - 1), (x1 + 4.5, y1 + 1),
           (x1 + 1, y1 + 4.5), (x0 - 1, y1 + 4.5), (x0 - 4.5, y1 + 1)]
    dpoly(cv, [(x, y - .5) for x, y in lip], INK)
    dpoly(cv, [(cx + (x - cx) * .97, cy + (y - cy) * .95) for x, y in lip], ramp[1])
    dline(cv, (x0 - 1, y0 - 3.6), (x1 + 1, y0 - 3.6), ramp[3], 2)
    dline(cv, (x0 - 3.4, y0), (x0 - 3.4, y1), ramp[2], 2)
    dline(cv, (x1 + 3.4, y0), (x1 + 3.4, y1), ramp[0], 2)
    dline(cv, (x0, y1 + 3.4), (x1, y1 + 3.4), ramp[0], 2)
    for sx in (-1, 1):
        fang(cv, cx + sx * (w / 2 + 2.2), y0 - 1.5, 2.6, 4.6, True, horn[3])
        fang(cv, cx + sx * (w / 2 + 2.2), y1 + 1.5, 2.2, 3.4, False, horn[2])
    cv.a[int(y0 * U + OY):int(y1 * U + OY), int(x0 * U + OX):int(x1 * U + OX)] = 0
    for s in (-1, 1):
        vx, vy, vw, vh = SIDE
        vx *= s
        a0, a1, b0, b1 = vx - vw / 2, vx + vw / 2, vy - vh / 2, vy + vh / 2
        rim = [(a0 - 3, b0 - 1), (a0 - 1, b0 - 3), (a1 + 1, b0 - 3), (a1 + 3, b0 - 1), (a1 + 3, b1 + 1),
               (a1 + 1, b1 + 3), (a0 - 1, b1 + 3), (a0 - 3, b1 + 1)]
        dpoly(cv, [(x, y - .5) for x, y in rim], INK)
        dpoly(cv, [(vx + (x - vx) * .96, vy + (y - vy) * .93) for x, y in rim], ramp[1])
        dline(cv, (a0 - 1, b0 - 2.3), (a1 + 1, b0 - 2.3), ramp[3], 2)
        dline(cv, (a0, b1 + 2.0), (a1, b1 + 2.0), ramp[0], 2)
        for sx in (a0 + 3.5, a1 - 3.5):
            lean = .6 * s
            dpoly(cv, [(sx - 2, b0 - 2.5), (sx + 2, b0 - 2.5), (sx + lean, b0 - 7.5)], INK)
            dpoly(cv, [(sx - 1.4, b0 - 2.7), (sx + 1.4, b0 - 2.7), (sx + lean * .8, b0 - 6.8)], horn[1])
            dline(cv, (sx - .6, b0 - 3), (sx + lean * .3, b0 - 6), horn[2])
        cv.a[int(b0 * U + OY):int(b1 * U + OY), int(a0 * U + OX):int(a1 * U + OX)] = 0


def jaws_frame(c):
    """Fanged stone jaws over the maw: the upper jaw rises and the lower jaw
    drops into the carved lip as the scene's door openness grows."""
    cv = Canvas(CW, CH)
    cx, cy, w, h = CORE
    x0, x1 = cx - w / 2, cx + w / 2
    y0, y1 = cy - h / 2, cy + h / 2
    k = c / 3
    hh = (h / 2) * (1 - k)
    up_y1, lo_y0 = y0 + hh, y1 - hh
    stone_slab(cv, x0, y0, x1, up_y1, JAW)
    stone_slab(cv, x0, lo_y0, x1, y1, JAW, lit_top=True)
    # Fangs on the leading edges: four big ones above, three below, with
    # small ones between, interlocking when sealed; open, only stubs show.
    big = 6.4 if c < 3 else 3.2
    small = 2.8 if c < 3 else 1.6
    for i, fx in enumerate((-12.5, -4.5, 4.5, 12.5)):
        fang(cv, cx + fx, up_y1 - .2, 3.4, big, True)
    for fx in (-8.5, 0, 8.5):
        fang(cv, cx + fx, up_y1 - .2, 2.0, small, True)
    for fx in (-8.5, 0, 8.5):
        fang(cv, cx + fx, lo_y0 + .2, 3.2, big * .85, False, BONE[2])
    for fx in (-13, 13):
        fang(cv, cx + fx, lo_y0 + .2, 2.0, small, False, BONE[2])
    if c == 0:
        # Sealed: an ember rune glows between the fangs (the old lock pip).
        dbox(cv, cx - 1.5, cy - 1, 3, 2, INK)
        dbox(cv, cx - 1, cy - .5, 2, 1, '#ff355f')
    return cv


def vent_frame(c):
    """Left clawed vent: three stone talon fingers clench across the vent
    from its outer edge and draw back into the rim as it opens; the final
    form petrifies it shut."""
    cv = Canvas(CW, CH)
    cx, cy, w, h = SIDE
    x0, x1 = cx - w / 2, cx + w / 2
    y0, y1 = cy - h / 2, cy + h / 2
    if c == 3:
        # Petrified lock: a stone plug carved with a cross rune and an ember
        # lock eye, bone studs at the corners.
        stone_slab(cv, x0, y0, x1, y1, ('#1c1828', '#3a3450', '#625a7c', '#8e86aa'))
        dline(cv, (x0 + 1.5, y0 + 1.5), (x1 - 2, y1 - 2), '#1c1828', 3)
        dline(cv, (x1 - 2, y0 + 1.5), (x0 + 1.5, y1 - 2), '#1c1828', 3)
        dell(cv, cx - .5, cy - .5, 2.6, 2.2, INK)
        dell(cv, cx - .5, cy - .5, 1.7, 1.3, '#ff274e')
        cv.px((cx - .5) * U + OX - 1, (cy - .5) * U + OY - 1, '#ffc7af')
        for bx in (x0 + 1.2, x1 - 2.2):
            for by in (y0 + 1.2, y1 - 2.2):
                dbox(cv, bx, by, 1, 1, BONE[2])
        return cv
    k = c / 2
    L = (w - 3.5) * (1 - k) + 2.5 * k
    band = h / 3
    stone = ('#2a2230', '#5a4c58', '#8a7c7c', '#b4a698')  # bone-stone talons
    for i in range(3):
        fy0 = y0 + i * band + .3
        fy1 = fy0 + band - .6
        my = (fy0 + fy1) / 2
        fx1 = x0 + L
        # Finger: a tapering bone-stone digit with a knuckle crease.
        th = (fy1 - fy0) * .22
        top = [(x0 - .5, fy0 - .5), (fx1 - 1, fy0 + th - .5), (fx1 + .8, my), (fx1 - 1, fy1 - th + .5),
               (x0 - .5, fy1 + .5)]
        dpoly(cv, top, INK)
        dpoly(cv, [(x0, fy0), (fx1 - 1, fy0 + th), (fx1 + .4, my), (fx1 - 1, fy1 - th), (x0, fy1)], stone[1])
        dline(cv, (x0, fy0 + .3), (fx1 - 1.5, fy0 + th + .3), stone[2], 2)
        dline(cv, (x0, fy1 - .3), (fx1 - 1.5, fy1 - th - .3), stone[0])
        if L > 8:
            kx = x0 + L * .45
            dline(cv, (kx, fy0 + .8), (kx + .6, fy1 - .8), stone[0], 2)
            dline(cv, (kx - .6, fy0 + 1), (kx - .3, my), stone[3])
        if c < 2:
            # Hooked talon at the fingertip, curling down over the next band.
            tx = fx1
            dpoly(cv, [(tx - 1.8, fy0 + th - .6), (tx + 2.6, my - .4), (tx + 1.6, fy1 + 3.0), (tx - .8, fy1 - th + .4)],
                  INK)
            dpoly(cv, [(tx - 1.2, fy0 + th - .1), (tx + 2.0, my - .1), (tx + 1.2, fy1 + 2.3), (tx - .8, fy1 - th)], FANG)
            dline(cv, (tx - .6, fy0 + th + .4), (tx + 1.0, my), '#ffffff')
    return cv


# ---------------------------------------------------------------------------
# Atlas.
# ---------------------------------------------------------------------------
def main():
    img = np.zeros((CH * ROWS, CW * COLS, 4), dtype=np.uint8)

    def put(col, row, cv):
        a = cv.a.copy()
        a[..., 3] = np.where(a[..., 3] > 0, 255, 0)
        img[row * CH:(row + 1) * CH, col * CW:(col + 1) * CW] = a

    for form in range(4):
        for f in range(4):
            put(form, 0 if f == 0 else 6 + f, hull_frame(form, f))
        put(form, 6, hull_frame(form, 0, wreck=True))
    for c in range(4):
        put(c, 1, talons_frame(c))
        put(c, 2, spouts_frame(c))
        put(c, 4, jaws_frame(c))
        put(c, 5, vent_frame(c))
    put(0, 3, damage_frame(1, 0))
    put(1, 3, damage_frame(2, 0))
    put(2, 3, debris_frame(-1))
    put(3, 3, debris_frame(1))
    put(0, 10, damage_frame(1, 1))
    put(1, 10, damage_frame(2, 1))
    put(2, 10, damage_frame(3, 0))
    put(3, 10, damage_frame(3, 1))
    target = ROOT / 'assets/images/boss-carrier.png'
    Image.fromarray(img, 'RGBA').save(target, optimize=True)
    print(f'Generated {target}: {img.shape[1]}x{img.shape[0]}')


if __name__ == '__main__':
    main()
