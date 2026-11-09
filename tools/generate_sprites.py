"""Original deterministic combat atlas (64x64 logical grid, stored 1x).

    python tools/generate_sprites.py

Writes assets/images/combat.png (2048 x 2560: thirty-two 64x64 columns,
nine rows per gargoyle species, then four shared rows). The layout is the
contract in plan/sprite-atlas.md and is mirrored by lib/game/sprite_atlas.dart.

Creatures are demonic gargoyles posed with tools/gargoyle_rig.py: a small 3-D
rig (hide volumes, bat-wing membranes between finger bones, horns, clawed
hands and feet, barbed tail) rasterised at logical pixel centres with a
quantised key light onto the bounded palette, a 1 px outline and depth
contours. Every flight frame exists for three directions (banking left,
neutral 3/4, banking right) as real renders, so asymmetric details (damage on
the port wing, slanted rank marks, the tail, weapon mounts) stay on the same
anatomical side. No source-game sprite, screenshot or third-party art is used.

Optional AI detail (tools/sprite_pipeline.py): art/families/sprites/detail/
<species>[-m<k>].png, a four-level luminance map finished from the committed
ComfyUI keyframes, nudges the key-light value of hide pixels (stony,
leathery texture). It never changes a silhouette, a face, an insignia or a
palette.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

import gargoyle_rig as G
from sprite_kit import ROOT, Atlas, Canvas

COLS, ROWS = 32, 40
SPECIES = ('teal', 'violet', 'coral', 'gold')
SPECIES_ROWS = 9
SHARED_ROW = 36
DETAIL_DIR = ROOT / 'art/families/sprites/detail'
wp = G.wp

# ---------------------------------------------------------------------------
# Frame tables. Wing poses: (elevation, sweep, forearm, fold, finger curl).
# The flap cycle is a downstroke (0-3: extended wings drive down, the body
# lifts) and an upstroke (4-7: wrists lead, the wings fold and rise, the
# body drops). LIFT is the whole-body offset in logical px; the Dart lookup
# mirrors it (CombatAtlas.flightLift) to align elite overlays.
# ---------------------------------------------------------------------------
FLAP = [
    wp(55, 5, 10, .12, -20),   # 0 top: raised, unfolding
    wp(30, 8, 0, 0, -10),      # 1 driving down
    wp(6, 10, -4, 0, 0),       # 2 level, full span
    wp(-22, 16, -8, .05, 12),  # 3 driving low, fingers trailing up
    wp(-42, 18, -10, .2, 20),  # 4 bottom
    wp(-24, 4, 14, .42, 10),   # 5 recovery: wrist leads, folded
    wp(8, -6, 22, .5, -6),     # 6 rising folded
    wp(38, -2, 18, .32, -16),  # 7 unfolding near the top
]
FLAP_LIFT = [0, -1, -2, -2, -1, 0, 1, 1]
GLIDE = [wp(16, 4, -8, 0, -4), wp(10, 6, -6, 0, 2)]
GLIDE_LIFT = [0, 1]
LIFT = FLAP_LIFT + GLIDE_LIFT        # flight frame -> lift (10 entries)
DIRS = (-1, 0, 1)                    # left, neutral, right
YAW, ROLL = 38, 12
COCKED = [wp(70, 0, 16, .15, -24), wp(66, 2, 20, .2, -28)]
DIVE = [wp(30, -18, 16, .5, 26), wp(22, -20, 20, .56, 30)]
DIVE_PITCH = 52
FIRE_LIFT = [0, 0, -1, 0]
ANTICIPATION_LIFT = [0, 0, -1, -1]
VARIANTS = ('intact', 'm1', 'm2', 'm3', 'angry')


def damage(variant, fire=0, flare=False):
    if variant == 'angry':
        return G.Damage(molt=2, angry=True, fire=fire, flare=flare)
    molt = 0 if variant == 'intact' else int(variant[1])
    return G.Damage(molt=molt, fire=fire, flare=flare)


def flight_pose(frame, d):
    """Flight frame 0-9 (8 flap + 2 glide) for direction d. Turning frames
    are asymmetric: the inner wing (toward the turn) beats shallower and
    folds more, the outer wing reaches further, the tail trails outward and
    the head leads into the turn."""
    w = FLAP[frame] if frame < 8 else GLIDE[frame - 8]
    lift = LIFT[frame]
    phase = math.sin(2 * math.pi * (frame % 8) / 8)
    tail = .5 * phase if d == 0 else -.8 * d + .25 * phase
    left, right = w, w
    if d:
        inner = G.WingPose(w.elev * .7 - 6, w.sweep - 6, w.fore, min(1, w.fold + .14), w.curl)
        outer = G.WingPose(w.elev * 1.08 + 4, w.sweep + 6, w.fore, max(0, w.fold - .06), w.curl)
        left, right = (inner, outer) if d < 0 else (outer, inner)
    legs = -.6 if frame >= 8 else .3 * phase
    return G.Pose(left, right, lift=lift, tail=tail, legs=legs, head_turn=8 * d)


def view(d, pitch=34):
    return G.View(yaw=YAW * d, roll=ROLL * d, pitch=pitch)


# ---------------------------------------------------------------------------
# AI shading detail (four-level luminance map on the 64-grid).
# ---------------------------------------------------------------------------
_detail_cache = {}


def _detail(name):
    if name not in _detail_cache:
        path = DETAIL_DIR / f'{name}.png'
        _detail_cache[name] = np.array(Image.open(path).convert('RGBA')) if path.exists() else None
    return _detail_cache[name]


def texture(species, molt, lift):
    layer = _detail(f'{species}-m{molt}') if molt else None
    if layer is None:
        layer = _detail(species)
    if layer is None:
        return None
    lv = np.digitize(layer[..., 0], [70, 135, 205]).astype(float)
    valid = layer[..., 3] > 0
    # Fixed to the body: shift by the frame's lift so bobbing keeps texture.
    lv = np.roll(lv, lift, axis=0)
    valid = np.roll(valid, lift, axis=0)

    def fn(R):
        t = np.where(valid, (lv - 1.5) * .07, 0.0)
        return np.where(R.mat == 'hide', t, 0.0)
    return fn


def render(species, pose, vw, dmg, elite_level=0, wings_on=True):
    sp = G.SPECIES[species]
    cv, _, _ = G.render(sp, pose, vw, dmg, texture(species, dmg.molt, pose.lift),
                        elite_level=elite_level, wings_on=wings_on)
    return cv


# ---------------------------------------------------------------------------
# Hit flash: every ramp steps toward white; the outline stays.
# ---------------------------------------------------------------------------
def _flash_map(species):
    sp = G.SPECIES[species]
    m = {}
    for ramp in (sp.hide, sp.wing[:3], ('bone0', 'bone1', 'bone2', 'fang'), ('met0', 'met1', 'met2', 'met3'),
                 ('gg0', 'gg1', 'gg2', 'gg3'), ('hot0', 'hot1', 'hot2'), sp.belly):
        for i, c in enumerate(ramp):
            m[c] = ramp[min(len(ramp) - 1, i + 2)] if i + 2 < len(ramp) else ('ivory' if i < len(ramp) - 1 else 'white')
    m[sp.hide[3]] = 'white'
    m[sp.hide[2]] = 'ivory'
    m['gink'] = 'gink'
    return m


def highlight(cv: Canvas, species):
    out = cv.copy()
    out.map_colors(_flash_map(species))
    return out


# ---------------------------------------------------------------------------
# Death: flash, glowing fissures, then the stone body shatters into tumbling
# chunks, a core burst, embers and dust.
# ---------------------------------------------------------------------------
def death_frames(species):
    whole = render(species, flight_pose(2, 0), view(0), damage('m3'))
    frames = [highlight(whole, species)]
    seams = whole.copy()
    for (a, b) in (((27, 26), (30, 36)), ((37, 25), (34, 37)), ((29, 18), (33, 22)), ((20, 22), (26, 25)),
                   ((44, 22), (38, 26))):
        seams.line(a, b, 'fire1')
    frames.append(seams)
    src = whole.a
    ys, xs = np.nonzero(src[..., 3])
    for k in range(6):  # frames 2..7
        cv = Canvas()
        t = (k + 1) / 6
        for y, x in zip(ys, xs):
            cx, cy = x // 5, y // 5  # 5x5 stone chunks drift apart
            ang = ((cx * 37 + cy * 61) % 360) * math.pi / 180
            spd = 6 + ((cx * 13 + cy * 7) % 9)
            dx = math.cos(ang) * spd * t + (x - 32) * .35 * t
            dy = math.sin(ang) * spd * t * .6 + 14 * t * t
            if k >= 3 and (cx + cy + k) % 3 == 0:
                continue
            if k >= 5 and (x + y) % 2:
                continue
            nx, ny = int(x + dx), int(y + dy)
            if 0 <= nx < 64 and 0 <= ny < 64:
                col = src[y, x].copy()
                if k >= 2 and (cx + cy) % 2 == 0:
                    col[:3] = (255, 107, 26) if k < 4 else (74, 68, 88)
                cv.a[ny, nx] = col
        r = [5, 9, 12, 12, 9, 0][k]
        if r:
            cv.ellipse(32, 30, r, r * .85, 'fire3' if k > 1 else 'fire2')
            cv.ellipse(32, 30, r * .62, r * .52, 'fire1')
            cv.ellipse(32, 30, r * .3, r * .26, 'fire0')
        if k >= 3:
            for i in range(6):  # dust puffs
                a = i * math.pi / 3 + .2
                px, py = 32 + math.cos(a) * (8 + k * 2), 30 + math.sin(a) * (6 + k) - k * 2
                cv.ellipse(px, py, 3 - (k - 3) * .5, 2.5 - (k - 3) * .5, 'smk1' if k < 5 else 'smk0')
                cv.px(px - 1, py - 1, 'smk2')
        frames.append(cv)
    return frames


# ---------------------------------------------------------------------------
# Elite overlays: the armour pixels a render gains over the same pose
# without armour (wings omitted so the plates never paint over a wing).
# ---------------------------------------------------------------------------
def elite_overlay(species, pose, vw, level):
    pose = G.Pose(pose.left, pose.right, lift=0, tail=pose.tail, legs=pose.legs, head_turn=pose.head_turn)
    plain = render(species, pose, vw, damage('intact'), wings_on=False)
    armed = render(species, pose, vw, damage('intact'), elite_level=level, wings_on=False)
    out = Canvas()
    diff = (armed.a != plain.a).any(-1) & (armed.a[..., 3] > 0)
    out.a[diff] = armed.a[diff]
    return out


FIT_REPORT = []


def check_fit_margin(cv, where):
    """Records frames whose silhouette touches the cell border (clipped)."""
    a = cv.a[..., 3] > 0
    if a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
        FIT_REPORT.append(where)


def species_block(atlas: Atlas, k, sp):
    r0 = k * SPECIES_ROWS
    put = atlas.put

    class _Fit:
        def put(self, c, r, cv):
            check_fit_margin(cv, (sp, c, r))
            put(c, r, cv)
    atlas = _Fit()
    # Rows 0-4: flight sets (10 frames x 3 directions) per damage variant.
    for vi, variant in enumerate(VARIANTS):
        dm = damage(variant)
        for di, d in enumerate(DIRS):
            for f in range(10):
                cv = render(sp, flight_pose(f, d), view(d), dm)
                atlas.put(di * 10 + f, r0 + vi, cv)
                if f % 2 == 0 and f < 8:
                    slot = vi * 12 + di * 4 + f // 2
                    atlas.put(slot % 32, r0 + 5 + slot // 32, highlight(cv, sp))
    # Row 7: actions.
    a = r0 + 7
    for i in range(4):  # anticipation: wings cocked high, eyes flare
        pose = G.Pose(COCKED[i // 2], COCKED[i // 2], lift=ANTICIPATION_LIFT[i], legs=-.4)
        atlas.put(i, a, render(sp, pose, view(0), G.Damage(flare=(i % 2 == 1))))
    for i in range(4):  # weapon fire: charge, flash, recoil, settle
        fire = [1, 2, 1, 0][i]
        pose = G.Pose(FLAP[2], FLAP[2], lift=FIRE_LIFT[i], jaw=.6 if fire else 0)
        atlas.put(4 + i, a, render(sp, pose, view(0), G.Damage(fire=fire)))
        w = FLAP[[2, 3, 2, 1][i]]
        pose = G.Pose(w, w, lift=0, jaw=.8)
        atlas.put(8 + i, a, render(sp, pose, view(0), damage('angry', fire=fire)))
    for i, fr in enumerate(death_frames(sp)):
        atlas.put(12 + i, a, fr)
    dive_cells = []
    for vi, variant in enumerate(VARIANTS):
        for i in range(2):
            pose = G.Pose(DIVE[i], DIVE[i], lift=0, legs=-1, tail=.3 * (1 - 2 * i), jaw=.5)
            cv = render(sp, pose, view(0, DIVE_PITCH), damage(variant))
            atlas.put(20 + vi * 2 + i, a, cv)
            if vi == 0:
                dive_cells.append(cv)
    for i, cv in enumerate(dive_cells):
        atlas.put(30 + i, a, highlight(cv, sp))
    # Row 8: elite armour overlays (direction x level; dive x level).
    e = r0 + 8
    for di, d in enumerate(DIRS):
        for lvl in range(4):
            atlas.put(di * 4 + lvl, e, elite_overlay(sp, flight_pose(8, d), view(d), 4 - lvl))
    for lvl in range(4):
        pose = G.Pose(DIVE[0], DIVE[0], lift=0, legs=-1, tail=.3)
        atlas.put(12 + lvl, e, elite_overlay(sp, pose, view(0, DIVE_PITCH), 4 - lvl))


# ---------------------------------------------------------------------------
# Shared rows: explosions, sparks, pickups and fallbacks.
# ---------------------------------------------------------------------------
def explosion(k, large=False):
    cv = Canvas()
    radius = [5, 11, 17, 22, 25, 23, 19, 14][k]
    if large:
        radius = [6, 13, 19, 24, 27, 26, 23, 19][k]
    pts = []
    for i in range(24):
        a = i * math.pi / 12 + k * .13
        ln = radius if i % 2 == 0 else radius * (.55 + .1 * (i % 3))
        pts.append((32 + math.cos(a) * ln, 32 + math.sin(a) * ln))
    if k < 5:
        cv.poly(pts, 'fire3' if not large else 'amber')
        cv.ellipse(32, 32, radius * .7, radius * .7, 'fire2')
        cv.ellipse(32, 32, radius * .45, radius * .45, 'fire1')
        cv.ellipse(32, 32, radius * .22, radius * .22, 'fire0')
    else:
        # Ring breaks into a dithered crimson shell and drifting embers.
        m = cv.ellipse_mask(32, 32, radius, radius) & ~cv.ellipse_mask(32, 32, radius - 3, radius - 3)
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            if (x + y + k) % 2 == 0:
                cv.px(x, y, 'fire5' if k < 7 else 'smk1')
    for i in range(10):
        a = i * 2 * math.pi / 10 + k * .4
        d = radius + 2 + (i % 3) * 2
        cv.rect(int(32 + math.cos(a) * d), int(32 + math.sin(a) * d), 1 + (i % 2 and k < 4), 1, 'fire1' if k < 5 else 'fire4')
    return cv


def sparks(k, color='fire1'):
    cv = Canvas()
    for i in range(8):
        a = i * math.pi / 4 + (.39 if k % 2 else 0)
        r0, r1 = 3 + k * 4, 6 + k * 5
        cv.line((32 + math.cos(a) * r0, 32 + math.sin(a) * r0), (32 + math.cos(a) * r1, 32 + math.sin(a) * r1),
                color if k < 3 else 'fire3')
    if k == 0:
        cv.ellipse(32, 32, 3, 3, 'fire0')
    return cv


def impact(k):
    """Player-shot impact flash on a creature (4 frames)."""
    cv = Canvas()
    r = [3, 6, 8, 9][k]
    cv.poly([(32, 32 - r), (33.5, 30.5), (32 + r, 32), (33.5, 33.5), (32, 32 + r), (30.5, 33.5), (32 - r, 32), (30.5, 30.5)],
            'mint' if k < 3 else 'sky')
    if k < 2:
        cv.ellipse(32, 32, 2.5 - k, 2.5 - k, 'white')
    return cv


def enemy_muzzle(k):
    """Warm creature weapon flash, drawn at a weapon mount (4 frames)."""
    cv = Canvas()
    r = [3, 5, 4, 2][k]
    cv.poly([(32, 32 - r * .6), (32 + r, 32), (32, 32 + r * 1.6), (32 - r, 32)], 'fire3')
    cv.ellipse(32, 32 + r * .3, r * .55, r * .7, 'fire1')
    if k < 2:
        cv.ellipse(32, 32, 1.2, 1.2, 'fire0')
    return cv


def badge(kind):
    cv = Canvas()
    hexa = [(32, 8), (52, 19), (52, 43), (32, 55), (12, 43), (12, 19)]
    cv.poly(hexa, 'ink')
    cv.poly([(32, 11), (49, 21), (49, 41), (32, 52), (15, 41), (15, 21)], 'sky')
    cv.poly([(32, 11), (49, 21), (32, 31), (15, 21)], 'deep')
    if kind == 'spread':
        for x in (22, 32, 42):
            cv.poly([(x, 17), (x + 5, 27), (x + 2, 27), (x + 2, 44), (x - 2, 44), (x - 2, 27), (x - 5, 27)], 'mint')
    elif kind == 'rapid':
        cv.poly([(35, 14), (21, 34), (31, 34), (27, 50), (44, 26), (34, 26)], 'gol2')
        cv.line((34, 16), (24, 32), 'gol3')
    elif kind == 'shield':
        cv.poly([(32, 15), (46, 21), (44, 37), (32, 48), (20, 37), (18, 21)], 'vio2')
        cv.poly([(32, 20), (41, 24), (40, 35), (32, 42), (24, 35), (23, 24)], 'sky')
        cv.line((32, 20), (32, 42), 'vio3')
    elif kind == 'heart':
        cv.poly([(16, 22), (22, 16), (29, 16), (32, 21), (35, 16), (42, 16), (48, 22), (48, 31), (32, 48), (16, 31)], 'eye_r')
        cv.rect(20, 21, 4, 3, 'white')
    elif kind == 'powerful':
        cv.rect(26, 18, 12, 26, 'cor2')
        cv.rect(28, 14, 8, 4, 'cor3')
        cv.rect(29, 22, 2, 18, 'cor0'); cv.rect(33, 22, 2, 18, 'cor0')
        cv.rect(24, 40, 16, 5, 'met2')
    elif kind == 'large':
        cv.ellipse(32, 30, 11, 13, 'amber')
        cv.ellipse(32, 28, 6, 7, 'fire1')
        cv.rect(26, 41, 12, 5, 'met2')
    cv.outline('ink')
    cv.rim({'sky': ('cyan', None)})
    return cv


def fallback_ship(frame):
    cv = Canvas()
    cv.poly([(32, 6), (37, 26), (54, 42), (54, 50), (38, 46), (26, 46), (10, 50), (10, 42), (27, 26)], 'hul2')
    cv.poly([(32, 10), (35, 28), (48, 41), (36, 40), (28, 40), (16, 41), (29, 28)], 'teal2')
    cv.rect(30, 22, 4, 14, 'ivory')
    cv.rect(29, 36, 6, 8, 'hul1')
    cv.poly([(28, 47), (36, 47), (32, 52 + frame * 2)], 'fire2')
    cv.rect(31, 47, 2, 3 + frame % 2, 'fire0')
    cv.outline('ink')
    return cv


def fallback_carrier(form):
    cv = Canvas()
    color = ['vio1', 'vio2', 'cor1', 'gol1'][form]
    cv.poly([(2, 18), (10, 28), (16, 10), (24, 22), (32, 14), (40, 22), (48, 10), (54, 28), (62, 18),
             (58, 46), (48, 54), (16, 54), (6, 46)], color)
    for f in ((lambda x: x), (lambda x: 64 - x)):
        cv.poly([(f(14), 34), (f(28), 38), (f(26), 44), (f(16), 42)], 'gol2')
    cv.rect(26, 46, 12, 6, 'ink2')
    cv.rect(30, 46, 4, 4, 'eye_r')
    for x in range(14, 52, 12):
        cv.rect(x, 50, 4, 4, 'mint')
    cv.outline('ink')
    return cv




def build(atlas: Atlas):
    for k, sp in enumerate(SPECIES):
        species_block(atlas, k, sp)
    # Shared rows (unchanged content, moved below the species blocks).
    s = SHARED_ROW
    for k in range(8):
        atlas.put(k, s, explosion(k))
        atlas.put(8 + k, s, explosion(k, large=True))
    for k in range(4):
        atlas.put(k, s + 1, sparks(k))
        atlas.put(4 + k, s + 1, impact(k))
        atlas.put(8 + k, s + 1, enemy_muzzle(k))
        atlas.put(12 + k, s + 1, sparks(k, 'mint'))
    for i, kind in enumerate(('spread', 'rapid', 'shield', 'heart', 'powerful', 'large')):
        atlas.put(i, s + 2, badge(kind))
    for f in range(4):
        atlas.put(f, s + 3, fallback_ship(f))
        atlas.put(4 + f, s + 3, fallback_carrier(f))


if __name__ == '__main__':
    atlas = Atlas(COLS, ROWS)
    build(atlas)
    if FIT_REPORT:
        print('frames touching the cell border:', len(FIT_REPORT), [w for w in FIT_REPORT if not (w[2] % 9 == 7 and 12 <= w[1] < 20)])
    atlas.save(ROOT / 'assets/images/combat.png')
