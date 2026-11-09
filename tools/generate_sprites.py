"""Original deterministic combat atlas (64x64 logical grid, stored 1x).

    .cache/asset-venv/bin/python tools/generate_sprites.py

Writes assets/images/combat.png. Layout is the contract in
plan/sprite-atlas.md: sixteen 64x64 columns; seven rows per species (four
species), then shared effect, pickup and fallback rows. Every creature is
rasterised at pixel centres on the 64-grid with a bounded palette, a 1px ink
outline and a top-left rim light. No source-game sprite, screenshot or
third-party art is used; shapes are authored here from first principles.

Optional AI detail (tools/sprite_pipeline.py): when
art/families/sprites/detail/<species>.png exists (a palette-finished 64x64
head/torso layer produced by the committed ComfyUI workflows), its pixels
inside the species' body mask replace the procedural body shading. The
silhouette, wings, eyes and insignia always come from this file so every
frame stays aligned.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

from sprite_kit import ROOT, Atlas, Canvas, lerp_pt, polar

COLS, ROWS = 16, 32
SPECIES = ('teal', 'violet', 'coral', 'gold')
RAMP = {
    'teal': ('teal0', 'teal1', 'teal2', 'teal3'),
    'violet': ('vio0', 'vio1', 'vio2', 'vio3'),
    'coral': ('cor0', 'cor1', 'cor2', 'cor3'),
    'gold': ('gol0', 'gol1', 'gol2', 'gol3'),
}
MOLT = {
    'teal': ('mt1', 'mt2', 'mt3'),
    'violet': ('mv1', 'mv2', 'mv3'),
    'coral': ('mc1', 'mc2', 'mc3'),
    'gold': ('mg1', 'mg2', 'mg3'),
}
DETAIL_DIR = ROOT / 'art/families/sprites/detail'

# ---------------------------------------------------------------------------
# Wing kinematics. Angles in degrees: 0 = straight out, +90 = straight up.
# (humerus, forearm, [4 finger angles], finger length scale, membrane reach)
# Eight poses make one articulated down/up stroke: roots, forearms and
# fingers move separately (the downstroke leads with the wrist, the upstroke
# trails folded fingers) so the silhouette changes each frame.
# ---------------------------------------------------------------------------
STROKE = [
    (62, 70, (88, 66, 44, 22), 0.92),     # 0 top: raised, fingers fanned up
    (40, 42, (62, 40, 18, -6), 1.00),     # 1 early down
    (18, 14, (34, 12, -12, -38), 1.00),   # 2 level: full span
    (-4, -14, (8, -16, -38, -62), 0.98),  # 3 driving down
    (-22, -36, (-22, -42, -62, -82), 0.90),  # 4 bottom: narrowest
    (-8, -20, (-46, -64, -80, -96), 0.72),  # 5 recovery: wrist leads, folded
    (20, 26, (-20, -42, -62, -82), 0.74),  # 6 rising, fingers trailing
    (46, 56, (52, 26, 0, -26), 0.86),     # 7 unfolding near the top
]
COCKED = [(52, 66, (104, 84, 64, 44), 0.96), (48, 60, (98, 78, 58, 38), 1.0)]
DIVE = [(-28, -46, (-56, -72, -88, -104), 0.96), (-22, -40, (-50, -66, -82, -98), 1.0)]
FIRE_POSE = STROKE[2]

SHOULDER = (27.0, 30.0)
HIP = (29.0, 44.0)
L_HUMERUS, L_FOREARM = 5.0, 6.5
FINGERS = (12.5, 16.0, 14.5, 11.5)


def wing_points(pose, mirror=False, droop=0.0):
    a1, a2, fingers, scale = pose
    s = SHOULDER if not mirror else (64 - SHOULDER[0], SHOULDER[1])
    h = HIP if not mirror else (64 - HIP[0], HIP[1])
    e = polar(s, a1, L_HUMERUS, mirror)
    w = polar(e, a2, L_FOREARM * (0.85 + 0.15 * scale), mirror)
    tips = [polar(w, fa - droop, fl * scale, mirror) for fa, fl in zip(fingers, FINGERS)]
    return s, e, w, tips, h


def scallop(w, p, q, depth=0.3):
    m = lerp_pt(p, q, .5)
    return lerp_pt(m, w, depth)


def draw_wing(cv: Canvas, pose, ramp, mirror=False, tears=0, membrane=None, rng_seed=0):
    dark, mid, base, light = ramp
    mem_a, mem_b = membrane or (mid, base)
    s, e, w, tips, h = wing_points(pose, mirror)
    # Inner membrane (plagiopatagium) from the last finger back to the hip.
    cv.poly([s, e, w, tips[3], scallop(w, tips[3], h, .14), h], mem_a)
    # Finger panels alternate tone so each digit reads at phone size.
    for i in range(3):
        cv.poly([w, tips[i], scallop(w, tips[i], tips[i + 1], .16), tips[i + 1]], mem_b if i % 2 == 0 else mem_a)
    # Leading-edge propatagium.
    cv.poly([s, lerp_pt(s, e, .5), e, w, tips[0], lerp_pt(e, tips[0], .5)], mem_b)
    # Bones: thick arm, thin fingers, claw at the wrist.
    cv.line(s, e, 'ink2', 2)
    cv.line(e, w, 'ink2', 2)
    for t in tips:
        cv.line(w, t, dark)
    cv.line(s, e, light)  # leading-edge highlight on the arm
    cv.px(w[0], w[1] - 1, 'ivory')  # wrist thumb claw
    # Battle tears: holes punched between fingers and notched trailing edges.
    for k in range(tears):
        i = (k + rng_seed) % 3
        hole = lerp_pt(w, scallop(w, tips[i], tips[i + 1], .3), .62 + .08 * (k % 2))
        r = 1.2 + 0.4 * (k // 3)
        cv.clear(cv.ellipse_mask(hole[0], hole[1], r, r))
        notch = scallop(w, tips[(i + 1) % 4], h if i == 2 else tips[(i + 2) % 4], .05)
        cv.clear(cv.ellipse_mask(notch[0], notch[1], 1.6, 1.6))


# ---------------------------------------------------------------------------
# Bodies. Each species: silhouette, armour, rank insignia, weapon mount.
# A narrow skull with a pointed chin sits on a broader chest; wings attach at
# the shoulders so the membranes dominate the silhouette.
# ---------------------------------------------------------------------------
HEAD = [(27.5, 15), (30, 12.5), (34, 12.5), (36.5, 15), (38.5, 19), (37.5, 24), (35, 28), (32, 30.5),
        (29, 28), (26.5, 24), (25.5, 19)]
TORSO = [(26, 30), (29, 27.5), (35, 27.5), (38, 30), (39, 35), (37.5, 41), (35, 46), (32, 48),
         (29, 46), (26.5, 41), (25, 35)]
MIR = ((lambda x: x), (lambda x: 64 - x))


def body_mask(cv: Canvas):
    return cv.poly_mask(HEAD) | cv.poly_mask(TORSO)


def horns(cv, species, molt, ramp):
    dark, mid, base, light = ramp
    if species == 'teal':
        # Curled ram horns: sweep out, up, then hook back in.
        pts = [(29, 15), (26, 12), (24, 8), (24.5, 4.5), (27, 3), (26.5, 6), (27, 9), (30, 13)]
        for f in MIR:
            cv.poly([(f(x), y) for x, y in pts], 'ivory')
            cv.line((f(25), 7), (f(26.5), 11), 'belly')
        if molt >= 1:
            cv.clear(cv.ellipse_mask(25.5, 3.5, 2.2, 1.5))
        if molt >= 2:
            cv.clear(cv.ellipse_mask(38.5, 3.5, 2.2, 1.5))
        if molt >= 3:
            cv.clear(cv.ellipse_mask(24.5, 6.5, 1.8, 1.6))
    elif species == 'violet':
        # Short armoured horns with riveted metal caps.
        for f in MIR:
            cv.poly([(f(29), 15), (f(26), 10), (f(26.5), 6.5), (f(30.5), 12.5)], 'met2')
            cv.poly([(f(26), 10), (f(26.5), 6.5), (f(28), 9)], 'met3')
        if molt >= 2:
            cv.clear(cv.ellipse_mask(26.5, 7, 2, 2.2))
        if molt >= 3:
            cv.clear(cv.ellipse_mask(37.5, 7.5, 2, 2.5))
    elif species == 'coral':
        # Long swept-back predator horns.
        pts = [(29, 15), (24, 11), (19, 8.5), (15, 9), (19, 11.5), (24, 14.5), (28.5, 17.5)]
        for f in MIR:
            cv.poly([(f(x), y) for x, y in pts], 'cor3')
            cv.line((f(18), 9.5), (f(23), 12), 'ivory')
        if molt >= 1:
            cv.clear(cv.ellipse_mask(15.5, 9.5, 2.2, 2))
        if molt >= 2:
            cv.clear(cv.ellipse_mask(48.5, 9.5, 2.5, 2))
        if molt >= 3:
            cv.clear(cv.ellipse_mask(19, 10, 2, 2))
    else:
        # Elder crown: three tines with a ruby at the band.
        heights = [6, 9, 6]
        for i, cx in enumerate((28.5, 32, 35.5)):
            top = 13 - heights[i] + (molt if i != 1 else max(0, molt - 1) * 2)
            if molt >= 3 and i == 2:
                top = 11
            cv.poly([(cx - 2, 13.5), (cx, top), (cx + 2, 13.5)], 'gol3')
            cv.px(cx - .5, top + 1.5, 'white')
        cv.poly([(27, 12), (37, 12), (37.5, 15), (26.5, 15)], 'gol2')
        cv.rect(27, 12, 10, 1, 'gol3')
        cv.px(31.5, 13, 'blood'); cv.px(32, 13, 'blood')


def draw_body(cv: Canvas, species, molt=0, angry=False, fire=0, ramp=None, flare=False, elite=False):
    dark, mid, base, light = ramp
    body = MOLT[species][molt - 1] if molt else base
    # Talons and arms first so the torso overlaps their roots.
    for f in MIR:
        cv.poly([(f(29), 45), (f(27.5), 50.5), (f(30.5), 50.5), (f(31), 46)], mid)
        cv.px(f(27.5), 51, 'ivory'); cv.px(f(29.5), 51, 'ivory')
        cv.poly([(f(26.5), 32), (f(23.5), 37), (f(24.5), 41.5), (f(26.5), 40), (f(27.5), 34)], mid)
        cv.px(f(23.5), 41.5, 'ivory'); cv.px(f(25), 42.5, 'ivory')
    if species == 'coral':
        # Segmented whip tail ending in a stinger emitter (its weapon mount).
        if molt < 3:
            tail = [(30.5, 45), (33.5, 45), (35, 51), (37, 55.5), (35, 59), (32.5, 55), (31, 50)]
            cv.poly(tail, mid)
            for y in (49, 52, 55):
                cv.line((32, y), (34.5, y + .5), dark)
            if molt < 2:
                cv.poly([(34, 57.5), (36.5, 62), (38.5, 57)], 'ivory')
                cv.px(36, 59, 'fire1' if fire else 'blood')
        else:
            cv.poly([(30.5, 45), (33.5, 45), (34, 50), (31, 50)], mid)
            cv.px(32, 50, 'blood')
    cv.poly(TORSO, body)
    cv.poly(HEAD, body)
    # Lower torso and jaw in the mid tone give volume under the top-left key.
    cv.poly([(27, 41), (29.5, 45.5), (32, 47.5), (34.5, 45.5), (37, 41), (32, 44)], mid)
    cv.poly([(29.5, 27.5), (32, 30), (34.5, 27.5), (32, 29)], mid)
    cv.line((32, 15), (32, 18), light)  # brow ridge
    horns(cv, species, molt, ramp)

    # Armour and rank insignia on the chest.
    if species == 'teal':
        cv.poly([(28.5, 32), (35.5, 32), (36, 37), (32, 41), (28, 37)], light if not molt else body)
        cv.poly([(29.5, 33.5), (32, 36), (34.5, 33.5), (34.5, 35.5), (32, 38), (29.5, 35.5)], 'ivory')
    elif species == 'violet':
        cv.poly([(27, 30.5), (37, 30.5), (37.5, 38), (32, 42.5), (26.5, 38)], 'met1')
        cv.poly([(27.5, 31), (36.5, 31), (36.5, 32.5), (27.5, 32.5)], 'met2')
        cv.rect(29, 35, 6, 1, 'vio3'); cv.rect(29, 37, 6, 1, 'vio3')  # twin bars
        cv.px(27.5, 31, 'met3')
        # Pauldrons with downward barb cannons (weapon mounts).
        for f in MIR:
            cv.poly([(f(23.5), 28.5), (f(27.5), 26.5), (f(29), 30.5), (f(25), 32.5)], 'met2')
            cv.px(f(25.5), 28, 'met3')
            x = min(f(24), f(25))
            cv.rect(x, 32, 2, 4, 'met1')
            cv.rect(x, 36, 2, 1, 'fire1' if fire else 'ink2')
    elif species == 'coral':
        cv.poly([(28.5, 31.5), (35.5, 31.5), (36, 36.5), (32, 40.5), (28, 36.5)], 'cor3' if not molt else body)
        for k in range(3):  # three fang-slash marks
            cv.line((29.5 + k * 2.2, 33), (30.7 + k * 2.2, 37), 'cor0')
    else:
        cv.poly([(28, 31), (36, 31), (37, 37), (32, 42), (27, 37)], 'gol3' if not molt else body)
        cv.poly([(32, 33), (34, 36), (32, 39), (30, 36)], 'blood')  # star jewel
        cv.px(32, 35, 'ivory')
        cv.poly([(29.5, 26.5), (32, 32), (34.5, 26.5), (32, 28.5)], mid)  # beard
        for f in MIR:  # orbs held in each claw: the elder's weapon mounts
            cv.ellipse(f(24), 42.5, 1.7, 1.7, 'fire1' if fire else 'vio2')
            cv.px(f(24) - .5, 41.5, 'white')

    # Molt damage: cracks and an exposed glowing belly grow with each stage.
    if molt:
        cv.poly([(29.5, 39), (34.5, 39), (35.5, 42 + molt), (32, 44.5 + molt * .7), (28.5, 42)], 'belly')
        cv.line((28, 31), (29.5, 35 + molt), 'ink')
        cv.line((29.5, 35 + molt), (28, 38 + molt), 'ink')
        if molt >= 2:
            cv.line((36.5, 30), (35, 35), 'ink')
            cv.line((35, 35), (36.5, 38), 'blood')
            cv.line((28, 17), (29.5, 21), 'ink')
        if molt >= 3:
            cv.line((36.5, 16), (34.5, 21), 'ink')
            cv.line((33, 42), (31, 46), 'blood')

    # Face: slanted brows, glowing eyes, fanged mouth (teal's throat emitter).
    hot = angry or flare
    eye = 'eye_r' if hot else 'ivory'
    ey = 19 if not angry else 20
    for side, f in enumerate(MIR):
        # Dark slanted socket with a 2x2 glowing eye and a bright pupil glint.
        cv.poly([(f(26.5), ey - 1.5), (f(31.5), ey + (1 if angry else 0)), (f(31), ey + 2.5), (f(27), ey + 2)], 'ink')
        x0 = 28 if side == 0 else 34
        cv.rect(x0, ey + .5, 2, 2, eye)
        cv.px(x0 + (1 if side == 0 else 0), ey + .5, 'fire1' if hot else 'white')
    my = 25
    open_ = 2 if (angry or (species == 'teal' and fire)) else 1
    cv.rect(29.5, my, 5, open_ + 1, 'ink')
    if species == 'teal' and fire:
        cv.rect(30.5, my, 3, open_, 'fire0' if fire == 2 else 'fire1')
    for x in (30, 34):
        cv.px(x, my + open_ + .5, 'white')
    for x in (31, 33):
        cv.px(x, my, 'white')
    if angry:
        cv.px(26.5, 23, 'blood'); cv.px(37.5, 22, 'blood')

SPECIES_RIM = {}
for sp, (d, m, b, l) in RAMP.items():
    SPECIES_RIM[sp] = {b: (l, m), m: (b, d)}


def creature(species, pose, molt=0, angry=False, fire=0, flare=False, raise_body=0):
    ramp = RAMP[species]
    cv = Canvas()
    membrane = ('hot1', 'hot2') if angry else None
    tears = [0, 2, 4, 6][molt]
    for mirror in (False, True):
        draw_wing(cv, pose, ramp, mirror, tears=tears if not mirror else max(0, tears - 1),
                  membrane=membrane, rng_seed=1 if mirror else 0)
    draw_body(cv, species, molt, angry, fire, ramp, flare)
    apply_detail(cv, species, molt, angry)
    cv.outline('ink')
    rim = dict(SPECIES_RIM[species])
    if angry:
        rim.update({'hot2': ('ivory', 'hot1'), 'hot1': (None, 'hot0')})
    if molt:
        rim[MOLT[species][molt - 1]] = (ramp[3], ramp[1])
    cv.rim(rim)
    if raise_body:
        cv.shift(0, -raise_body)
    return cv


_detail_cache = {}


def apply_detail(cv: Canvas, species, molt, angry):
    """Blends an AI-finished detail layer (if committed) into the head/torso
    interior, keeping the authored silhouette, eyes and insignia on top."""
    path = DETAIL_DIR / f'{species}.png'
    if not path.exists():
        return
    if species not in _detail_cache:
        _detail_cache[species] = np.array(Image.open(path).convert('RGBA'))
    layer = _detail_cache[species]
    mask = body_mask(cv) & (layer[..., 3] > 0)
    # Only texture pixels of the plain body colour; keep eyes, plates, marks.
    ramp = RAMP[species]
    body = MOLT[species][molt - 1] if molt else ramp[2]
    mask &= cv.is_color(body)
    cv.a[mask] = layer[mask]


def highlight(cv: Canvas, species):
    """Hit-flash variant: every ramp jumps toward white; ink outline stays."""
    d, m, b, l = RAMP[species]
    mapping = {l: 'white', b: 'ivory', m: l, d: b, 'ink2': 'night',
               'belly': 'white', 'met1': 'met3', 'met2': 'white', 'met0': 'met2',
               'hot2': 'white', 'hot1': 'ivory', 'hot0': 'hot2'}
    for mt in MOLT[species]:
        mapping[mt] = 'ivory'
    out = cv.copy()
    out.map_colors(mapping)
    return out


# ---------------------------------------------------------------------------
# Death sequence: hit-white, seams glow, wings shear off, core burst, shreds.
# ---------------------------------------------------------------------------
def death_frames(species):
    ramp = RAMP[species]
    frames = []
    whole = creature(species, STROKE[2], molt=3)
    frames.append(highlight(whole, species))
    seams = whole.copy()
    for (a, b) in (((27, 31), (30, 40)), ((37, 30), (34, 41)), ((26, 18), (31, 24)), ((38, 17), (33, 25))):
        seams.line(a, b, 'fire1')
    seams.recolor('belly', 'fire0')
    frames.append(seams)
    # Pieces: left wing, right wing, body, drawn separately so they can drift.
    def piece(which):
        cv = Canvas()
        if which in ('L', 'R'):
            draw_wing(cv, STROKE[3 if which == 'L' else 1], ramp, which == 'R', tears=5)
        else:
            draw_body(cv, species, 3, True, 0, ramp)
        cv.outline('ink')
        cv.rim(SPECIES_RIM[species])
        return cv
    L, R, B = piece('L'), piece('R'), piece('B')
    for k in range(6):  # frames 2..7
        cv = Canvas()
        t = k / 5
        if k < 4:
            lw = L.rotated(-12 * (k + 1), 25, 30); lw.shift(-2 * (k + 1), 1 + 2 * k)
            rw = R.rotated(12 * (k + 1), 39, 30); rw.shift(2 * (k + 1), 2 * k)
            cv.paste(lw); cv.paste(rw)
        if k < 2:
            b = B.copy(); b.shift(0, k)
            cv.paste(b)
        # Core burst grows then breaks into embers.
        r = [5, 9, 12, 13, 12, 10][k]
        if k < 4:
            cv.ellipse(32, 36, r, r * .85, 'fire3' if k > 1 else 'fire2')
            cv.ellipse(32, 36, r * .65, r * .55, 'fire1')
            cv.ellipse(32, 36, r * .35, r * .3, 'fire0')
            for i in range(8):
                a = i * math.pi / 4 + k * .3
                cv.line((32 + math.cos(a) * r, 36 + math.sin(a) * r * .85),
                        (32 + math.cos(a) * (r + 3), 36 + math.sin(a) * (r + 3) * .85), 'fire1')
        # Membrane shreds and bone bits fly outward and fall.
        for i in range(10):
            a = i * 2 * math.pi / 10 + 0.4
            dist = 6 + 26 * t
            x = 32 + math.cos(a) * dist
            y = 36 + math.sin(a) * dist * .8 + 10 * t * t
            col = [ramp[1], ramp[2], 'ivory', ramp[0], 'fire3'][i % 5]
            if k >= 4 and i % 2:
                col = 'smk1' if k == 5 else 'fire4'
            size = 2 if (i % 3 and k < 4) else 1
            cv.rect(int(x), int(y), size, size + (1 if i % 4 == 0 else 0), col)
        if k >= 3:
            for i in range(6):  # smoke puffs
                a = i * math.pi / 3 + 0.2
                cx, cy = 32 + math.cos(a) * (8 + k * 2), 34 + math.sin(a) * (6 + k) - k * 2
                cv.ellipse(cx, cy, 3 - (k - 3) * .5, 2.5 - (k - 3) * .5, 'smk1' if k < 5 else 'smk0')
                cv.px(cx - 1, cy - 1, 'smk2')
        if k < 4:
            cv.outline('ink')
        frames.append(cv)
    return frames


# ---------------------------------------------------------------------------
# Elite overlays: shoulder plates that follow each wing pose; helm and chest
# armour at four integrity levels; rank insignia (gold double chevron).
# ---------------------------------------------------------------------------
def elite_wing_plates(pose):
    cv = Canvas()
    for mirror in (False, True):
        s, e, w, tips, h = wing_points(pose, mirror)
        mid = lerp_pt(s, e, .5)
        cv.ellipse(mid[0], mid[1], 2.6, 2.2, 'gol2')
        cv.px(mid[0] - 1, mid[1] - 1, 'gol3')
        cv.ellipse(w[0], w[1], 1.6, 1.6, 'met2')
        cv.px(w[0], w[1], 'met3')
    cv.outline('ink')
    return cv


def elite_armor(level):
    """level 4 = full, 1 = nearly stripped. Transparent outside the plates."""
    cv = Canvas()
    if level >= 1:
        # Rank insignia: gold double chevron on the brow, always visible.
        for k in range(2):
            cv.poly([(28, 15 + k * 2.5), (32, 17.5 + k * 2.5), (36, 15 + k * 2.5), (36, 16.5 + k * 2.5),
                     (32, 19 + k * 2.5), (28, 16.5 + k * 2.5)], 'gol3' if k == 0 else 'gol2')
    if level >= 2:
        # Side helm plates.
        for f in ((lambda x: x), (lambda x: 64 - x)):
            cv.poly([(f(24), 16), (f(26), 13), (f(27), 22), (f(25), 25)], 'met2')
            cv.px(f(25), 15, 'met3')
    if level >= 3:
        # Elite horn caps / crest spikes.
        for f in ((lambda x: x), (lambda x: 64 - x)):
            cv.poly([(f(28), 12), (f(26), 4), (f(30), 11)], 'gol2')
            cv.px(f(27), 6, 'gol3')
    if level >= 4:
        # Gorget and belly plate.
        cv.poly([(27, 41), (37, 41), (35, 47), (29, 47)], 'met1')
        cv.rect(29, 43, 6, 1, 'gol2')
    cv.outline('ink')
    return cv


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
        r0 = k * 7
        for f in range(8):
            atlas.put(f, r0, creature(sp, STROKE[f]))
            atlas.put(8 + f, r0, creature(sp, STROKE[f], angry=True))
            atlas.put(f, r0 + 5, highlight(creature(sp, STROKE[f]), sp))
            for molt in (1, 2, 3):
                c = creature(sp, STROKE[f], molt=molt)
                atlas.put(f, r0 + molt, c)
                atlas.put(8 + f, r0 + molt, highlight(c, sp))
            atlas.put(f, r0 + 6, elite_wing_plates(STROKE[f]))
        # Anticipation (dive warning): wings cocked high, eyes flaring.
        for i in range(4):
            atlas.put(i, r0 + 4, creature(sp, COCKED[i // 2], flare=(i % 2 == 1), raise_body=i // 2))
        for i in range(4):
            atlas.put(4 + i, r0 + 4, creature(sp, DIVE[i % 2]))
        # Weapon fire: charge, flash, recoil, settle.
        for i in range(4):
            atlas.put(8 + i, r0 + 4, creature(sp, FIRE_POSE, fire=[1, 2, 1, 0][i], raise_body=[0, 0, 1, 0][i]))
        for i in range(4):
            atlas.put(12 + i, r0 + 4, creature(sp, STROKE[[2, 3, 2, 1][i]], angry=True, fire=[1, 2, 1, 0][i]))
        for i, fr in enumerate(death_frames(sp)):
            atlas.put(8 + i, r0 + 5, fr)
        for lvl in range(4):
            atlas.put(8 + lvl, r0 + 6, elite_armor(4 - lvl))
    # Shared rows.
    for k in range(8):
        atlas.put(k, 28, explosion(k))
        atlas.put(8 + k, 28, explosion(k, large=True))
    for k in range(4):
        atlas.put(k, 29, sparks(k))
        atlas.put(4 + k, 29, impact(k))
        atlas.put(8 + k, 29, enemy_muzzle(k))
        atlas.put(12 + k, 29, sparks(k, 'mint'))
    for i, kind in enumerate(('spread', 'rapid', 'shield', 'heart', 'powerful', 'large')):
        atlas.put(i, 30, badge(kind))
    for f in range(4):
        atlas.put(f, 31, fallback_ship(f))
        atlas.put(4 + f, 31, fallback_carrier(f))


if __name__ == '__main__':
    atlas = Atlas(COLS, ROWS)
    build(atlas)
    atlas.save(ROOT / 'assets/images/combat.png')
