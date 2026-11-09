"""Gargoyle rig: a tiny deterministic 3-D rasteriser for pixel-art creatures.

Each species is a set of volumes (ellipsoids and sphere chains) and bat-wing
membranes (triangle fans between finger bones) in body-local coordinates
(x right, y down, z toward the viewer, 1 unit = 1 logical pixel). A frame is
the rig posed (wing joint angles, body lift, tail sway, head turn), turned
for its flight direction (yaw + roll), tilted by the fixed 3/4 camera pitch,
and rasterised orthographically at logical pixel centres with a z-buffer.
Shading is a quantised top-left-front key light mapped onto bounded palette
ramps; facial features, insignia, weapon mounts and cracks are decals pinned
to 3-D anchor points and drawn only where their own part is visible. So the
same anatomy renders correctly from the left, the front and the right: a
right-banking frame is a real render, not a mirror, and asymmetric details
(damage on one wing, slanted rank marks, tail side, weapon mounts) stay on
the same anatomical side.

No randomness except fixed tables; same inputs, same bytes.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field, replace

import numpy as np

from sprite_kit import Canvas, rgb

# ---------------------------------------------------------------------------
# Math helpers.
# ---------------------------------------------------------------------------


def v(*a):
    return np.array(a, dtype=float)


def norm(a):
    n = np.linalg.norm(a)
    return a / n if n > 1e-9 else a


def rot_x(deg):
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    # Positive tilts the creature's top toward the viewer (y up is -y).
    return np.array([[1, 0, 0], [0, c, s], [0, -s, c]])


def rot_y(deg):
    """Yaw about the body's vertical axis; positive turns the face toward
    screen right (+x)."""
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_z(deg):
    """In-plane roll; positive rotates clockwise on screen (y is down)."""
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def direction(elev, sweep, side):
    """Unit vector from a joint: elev = degrees above horizontal (toward -y),
    sweep = degrees forward (toward +z, the face) from straight outward."""
    e, s = math.radians(elev), math.radians(sweep)
    return v(side * math.cos(e) * math.cos(s), -math.sin(e), math.cos(e) * math.sin(s))


# ---------------------------------------------------------------------------
# Scene primitives (world space after posing).
# ---------------------------------------------------------------------------
@dataclass
class Ellipsoid:
    c: np.ndarray
    r: np.ndarray
    m: np.ndarray  # local->world rotation (columns = local axes)
    mat: str
    part: str


@dataclass
class Sphere:
    c: np.ndarray
    r: float
    mat: str
    part: str


@dataclass
class Tri:
    p: tuple
    mat: str
    part: str
    holes: list = field(default_factory=list)  # [(center3d, radius)]
    flip: bool = False  # mirrored winding (starboard wing)


@dataclass
class Decal:
    """2-D pixel shape pinned to a 3-D anchor; offsets are in the anchor's
    local (ax, ay) axes, projected, so it foreshortens and turns with the
    body. Drawn only where the z-buffer shows one of `parts`."""
    anchor: np.ndarray
    ax: np.ndarray
    ay: np.ndarray
    pixels: list  # [(dx, dy, colour)]
    parts: tuple
    force: bool = False  # draw even if occluded (glows on top)
    mats: tuple = ()     # alternatively: draw where one of these materials shows


# ---------------------------------------------------------------------------
# Rasteriser.
# ---------------------------------------------------------------------------
class Raster:
    def __init__(self, w, h, origin):
        self.w, self.h = w, h
        ys, xs = np.mgrid[0:h, 0:w]
        self.px = xs + .5 - origin[0]
        self.py = ys + .5 - origin[1]
        self.z = np.full((h, w), -1e9)
        self.n = np.zeros((h, w, 3))
        self.p3 = np.zeros((h, w, 3))
        self.mat = np.full((h, w), '', dtype=object)
        self.part = np.full((h, w), '', dtype=object)
        self.back = np.zeros((h, w), dtype=bool)
        self.origin = origin

    def _commit(self, hit, z, n, mat, part, back=None):
        sel = hit & (z > self.z)
        self.z[sel] = z[sel]
        self.n[sel] = n[sel]
        self.p3[sel, 0] = self.px[sel]
        self.p3[sel, 1] = self.py[sel]
        self.p3[sel, 2] = z[sel]
        self.mat[sel] = mat
        self.part[sel] = part
        self.back[sel] = False if back is None else back[sel]

    def sphere(self, s: Sphere):
        r = max(s.r, .72)
        dx, dy = self.px - s.c[0], self.py - s.c[1]
        d2 = dx * dx + dy * dy
        hit = d2 <= r * r
        if not hit.any():
            return
        dz = np.sqrt(np.maximum(r * r - d2, 0))
        z = s.c[2] + dz
        n = np.stack([dx, dy, dz], -1) / r
        self._commit(hit, z, n, s.mat, s.part)

    def ellipsoid(self, e: Ellipsoid):
        minv = e.m.T  # world->local
        o = np.stack([self.px - e.c[0], self.py - e.c[1], np.zeros_like(self.px)], -1)
        ol = (o @ minv.T) / e.r
        dl = (minv @ v(0, 0, 1)) / e.r
        a = dl @ dl
        b = ol @ dl
        c = (ol * ol).sum(-1) - 1
        disc = b * b - a * c
        hit = disc >= 0
        if not hit.any():
            return
        t = (-b + np.sqrt(np.maximum(disc, 0))) / a
        q = ol + t[..., None] * dl  # unit-sphere point
        n = (q / e.r) @ e.m.T
        n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
        z = e.c[2] + t
        self._commit(hit, z, n, e.mat, e.part)

    def tri(self, t: Tri):
        p0, p1, p2 = (np.asarray(p) for p in t.p)
        x0, y0 = p0[0], p0[1]
        x1, y1 = p1[0], p1[1]
        x2, y2 = p2[0], p2[1]
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-6:
            return
        X, Y = self.px, self.py
        l0 = ((y1 - y2) * (X - x2) + (x2 - x1) * (Y - y2)) / den
        l1 = ((y2 - y0) * (X - x2) + (x0 - x2) * (Y - y2)) / den
        l2 = 1 - l0 - l1
        eps = -1e-6
        hit = (l0 >= eps) & (l1 >= eps) & (l2 >= eps)
        if not hit.any():
            return
        z = l0 * p0[2] + l1 * p1[2] + l2 * p2[2]
        if t.holes:
            P = (l0[..., None] * p0 + l1[..., None] * p1 + l2[..., None] * p2)
            for hc, hr in t.holes:
                hit &= ((P - hc) ** 2).sum(-1) > hr * hr
        nrm = norm(np.cross(p1 - p0, p2 - p0))
        if nrm[2] < 0:
            nrm = -nrm
        raw = np.cross(p1 - p0, p2 - p0)[2]
        back = (raw < 0) == t.flip
        n = np.broadcast_to(nrm, X.shape + (3,))
        self._commit(hit, z, n, t.mat, t.part, np.full(X.shape, back))


# ---------------------------------------------------------------------------
# Rig definition.
# ---------------------------------------------------------------------------
@dataclass
class WingPose:
    elev: float      # humerus elevation (deg, + up)
    sweep: float     # humerus sweep (deg, + forward)
    fore: float      # forearm elevation relative to humerus (deg)
    fold: float      # 0 extended .. 1 folded against the body
    curl: float = 0  # finger elevation offset (deg; trails the stroke)


@dataclass
class Pose:
    left: WingPose
    right: WingPose
    lift: int = 0          # body offset in px (negative = up)
    tail: float = 0        # tail sway phase (-1..1)
    legs: float = 0        # leg swing (-1 tucked back .. 1 forward)
    jaw: float = 0         # 0 closed .. 1 wide (fire/angry)
    head_turn: float = 0   # extra head yaw (deg)
    hunch: float = 0       # extra head drop (px), anticipation
    arms: float = 0        # arm reach (0 tucked .. 1 forward strike)


def wp(elev, sweep, fore, fold, curl=0):
    return WingPose(elev, sweep, fore, fold, curl)


@dataclass
class Species:
    name: str
    hide: tuple            # 4 tones dark->light
    wing: tuple            # membrane tones: back-dark, back, front, front-light
    bone: tuple            # wing bone / horn tones (dark, mid, light)
    belly: tuple           # belly plate tones (dark, mid, light)
    scale: float = 1.0
    span: float = 1.0      # wing length multiplier
    bulk: float = 1.0      # shoulder width multiplier
    head: float = 1.0
    eye: str = 'geye'
    origin_y: float = 31


TEAL = Species('teal', ('gt0', 'gt1', 'gt2', 'gt3'), ('gtw0', 'gtw1', 'gtw2', 'gt2'),
               ('bone0', 'bone1', 'bone2'), ('gt1', 'gt2', 'gt3'),
               scale=1.0, span=1.0, bulk=.9, head=1.25)
VIOLET = Species('violet', ('gv0', 'gv1', 'gv2', 'gv3'), ('gvw0', 'gvw1', 'gvw2', 'gv2'),
                 ('met0', 'met1', 'met2'), ('met1', 'met2', 'met3'),
                 scale=1.12, span=.78, bulk=1.4, head=1.0)
CORAL = Species('coral', ('gc0', 'gc1', 'gc2', 'gc3'), ('gcw0', 'gcw1', 'gcw2', 'gc2'),
                ('bone0', 'bone1', 'bone2'), ('gc1', 'gc2', 'gc3'),
                scale=1.0, span=.98, bulk=.85, head=1.08)
GOLD = Species('gold', ('gg0', 'gg1', 'gg2', 'gg3'), ('ggw0', 'ggw1', 'ggw2', 'gg2'),
               ('gg1', 'gg2', 'gg3'), ('gg1', 'gg2', 'gg3'),
               scale=1.0, span=.96, bulk=1.05, head=1.12)
WARDEN = Species('warden', ('gv0', 'gv1', 'gv2', 'gv3'), ('gvw0', 'gvw1', 'gvw2', 'gv2'),
                 ('gv0', 'gv1', 'gv2'), ('met1', 'met2', 'met3'),
                 scale=1.0, span=1.5, bulk=1.25, head=1.05)
COLOSSUS = Species('colossus', ('gg0', 'gg1', 'gg2', 'gg3'), ('ggw0', 'ggw1', 'ggw2', 'gg2'),
                   ('gg1', 'gg2', 'gg3'), ('gg1', 'gg2', 'gg3'),
                   scale=1.0, span=1.46, bulk=1.4, head=1.0)
SPECIES = {'teal': TEAL, 'violet': VIOLET, 'coral': CORAL, 'gold': GOLD, 'warden': WARDEN, 'colossus': COLOSSUS}
MAW_WEAPON = ('teal', 'warden', 'colossus')

LIGHT = norm(v(-.55, -.7, .65))


@dataclass
class View:
    yaw: float = 0       # flight direction turn (deg)
    roll: float = 0      # bank lean (deg)
    pitch: float = 34    # fixed 3/4 camera tilt
    size: tuple = (64, 64)
    origin: tuple = (32, 31)
    scale: float = 1.0


@dataclass
class Damage:
    molt: int = 0
    angry: bool = False
    fire: int = 0        # 0 none, 1 charge, 2 flash
    flare: bool = False  # anticipation eye flare


class Builder:
    """Collects posed primitives in world space for one frame."""

    def __init__(self, view: View, lift, sp=None):
        self.view = view
        s = view.scale * (sp.scale if sp is not None else 1.0)
        self.M = rot_z(view.roll) @ rot_x(view.pitch) @ rot_y(view.yaw)
        self.s = s
        self.lift = lift
        self.prims = []
        self.decals = []

    def W(self, p):
        """Body-local point -> world (screen-centred) point."""
        q = self.M @ (np.asarray(p, float) * self.s)
        q[1] += self.lift
        return q

    def Wd(self, d):
        return self.M @ np.asarray(d, float)

    def ell(self, c, r, mat, part, local_rot=None):
        m = self.M @ (local_rot if local_rot is not None else np.eye(3))
        self.prims.append(Ellipsoid(self.W(c), np.asarray(r, float) * self.s, m, mat, part))

    def sph(self, c, r, mat, part):
        self.prims.append(Sphere(self.W(c), r * self.s, mat, part))

    def chain(self, pts, r0, r1, mat, part, step=.45):
        """Tapered tube through local points (sphere chain)."""
        pts = [np.asarray(p, float) for p in pts]
        seg = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
        total = sum(seg) or 1
        acc = 0
        for i, L in enumerate(seg):
            n = max(1, int(L / step))
            for k in range(n + (1 if i == len(seg) - 1 else 0)):
                t = k / n
                p = pts[i] + (pts[i + 1] - pts[i]) * t
                r = r0 + (r1 - r0) * ((acc + L * t) / total)
                self.sph(p, r, mat, part)
            acc += L

    def tri(self, a, b, c, mat, part, holes=(), flip=False):
        self.prims.append(Tri((self.W(a), self.W(b), self.W(c)), mat, part,
                              [(self.W(h), r * self.s) for h, r in holes], flip))

    def decal(self, anchor, ax, ay, pixels, parts, force=False, mats=()):
        self.decals.append(Decal(self.W(anchor), self.Wd(ax), self.Wd(ay), pixels, parts, force, mats))


# ---------------------------------------------------------------------------
# Anatomy.
# ---------------------------------------------------------------------------
def lerp(a, b, t):
    return np.asarray(a, float) + (np.asarray(b, float) - np.asarray(a, float)) * t


def ry_local(deg):
    return rot_y(deg)


def build_wing(B: Builder, sp: Species, side, w: WingPose, tears, mat_prefix='wing'):
    """Bat wing: humerus, forearm, thumb claw, three long fingers; membrane
    panels between fingers and from the last finger to the flank, with a
    scalloped, notched trailing edge. side -1 = the creature's port wing
    (screen left in the neutral view)."""
    k = sp.span * .92
    P = rot_x(-B.view.pitch)  # wings beat in the camera plane

    def pdir(a, sweep=0.0):
        a, sw = math.radians(a), math.radians(sweep)
        return P @ v(side * math.cos(a) * math.cos(sw), -math.sin(a) * math.cos(sw), math.sin(sw))

    root = v(side * 3.4 * sp.bulk, -6.2, -3.2)
    ah = w.elev
    elbow = root + pdir(ah, w.sweep) * 6.6 * k * (1 - .1 * w.fold)
    af = ah + w.fore - 128 * w.fold
    wrist = elbow + pdir(af, w.sweep * .6 - 25 * w.fold) * 8.6 * k * (1 - .28 * w.fold)
    fl = (13.6, 15.4, 12.6)
    tips = []
    for i, L in enumerate(fl):
        a = af - (6 + 31 * i) * (1 - .35 * w.fold) - 18 * w.fold + w.curl * (.6 + .3 * i)
        tips.append(wrist + pdir(a, w.sweep * .3 - 12 * w.fold - 4 * i) * L * k * (1 - .45 * w.fold))
    hip = v(side * 3.6, 7.5, -2.4)
    flank = v(side * 4.2, 1.5, -3.4)
    # Membrane panels; the trailing edges scallop toward the bones.
    def scallop(a, b, depth=.26):
        m = lerp(a, b, .5)
        return lerp(m, wrist, depth)

    front = 'wingf'
    panels = [(wrist, tips[0], tips[1]), (wrist, tips[1], tips[2])]
    holes = tears_for(side, tears, wrist, tips, elbow, hip)
    for i, (a, b, c) in enumerate(panels):
        s = scallop(b, c)
        B.tri(a, b, s, front, f'wing{side}', holes, side > 0)
        B.tri(a, s, c, front, f'wing{side}', holes, side > 0)
    # Inner panel from the last finger to the flank and hip.
    s2 = scallop(tips[2], hip, .22)
    for tri in ((wrist, tips[2], s2), (wrist, s2, hip), (wrist, hip, flank),
                (wrist, flank, elbow), (elbow, flank, root)):
        B.tri(*tri, front, f'wing{side}', holes, side > 0)
    # Leading edge membrane (propatagium) root->wrist.
    lead = lerp(root, wrist, .5) + v(0, -1.0, 1.4)
    B.tri(root, elbow, lead, front, f'wing{side}', (), side > 0)
    B.tri(elbow, wrist, lead, front, f'wing{side}', (), side > 0)
    # Bones over the membrane.
    bone = 'wbone'
    B.chain([root, elbow], 1.25, 1.0, bone, f'arm{side}')
    B.chain([elbow, wrist], 1.0, .85, bone, f'arm{side}')
    for t in tips:
        B.chain([wrist, t], .78, .72, 'wfinger', f'wing{side}')
    # Thumb hook at the wrist.
    thumb = wrist + pdir(af + 70, 20) * 2.4
    B.chain([wrist, thumb], .9, .72, 'claw', f'arm{side}')
    return dict(root=root, elbow=elbow, wrist=wrist, tips=tips)


def tears_for(side, tears, wrist, tips, elbow, hip):
    """Membrane holes and trailing-edge notches. Every gargoyle has a couple
    of ragged notches; molts punch more holes, more on the port wing."""
    out = []
    # Base raggedness: a notch at each scallop.
    out.append((lerp(lerp(tips[0], tips[1], .5), wrist, .05), 1.3))
    out.append((lerp(lerp(tips[2], hip, .45), wrist, .06), 1.4))
    n = tears if side < 0 else max(0, tears - 1)
    spots = [(0, .62, 2.1), (1, .55, 2.3), (2, .5, 2.4), (0, .35, 1.8), (1, .92, 2.6), (2, .95, 2.8)]
    for i in range(n):
        f, t, r = spots[i % len(spots)]
        a = tips[f] if f < 2 else tips[2]
        b = tips[f + 1] if f < 2 else hip
        out.append((lerp(wrist, lerp(a, b, .5), t + .1), r + .25 * (i // 3)))
    return out


def head_rot(turn):
    return rot_y(turn)


def build_creature(sp: Species, pose: Pose, view: View, dmg: Damage, elite_level=0, wings_on=True):
    B = Builder(view, pose.lift, sp)
    side_l, side_r = -1, 1
    tears = [0, 2, 4, 6][dmg.molt]
    wings = {}
    if wings_on:
        for side, w in ((side_l, pose.left), (side_r, pose.right)):
            wings[side] = build_wing(B, sp, side, w, tears)
    H = sp.hide
    bulk = sp.bulk
    name = sp.name
    # --- torso (hunched: chest forward, heavy shoulders, hump behind head) --
    if name == 'coral':
        torso = dict(pelvis=(0, 6.5, -2.5), chest=(0, -2, 1.2), hump=(0, -4.5, -2.2))
    else:
        torso = dict(pelvis=(0, 7, -1.5), chest=(0, -2.5, 1), hump=(0, -4.2, -2.6))
    B.ell(torso['pelvis'], (3.8 * bulk, 3.4, 3.4), 'hide', 'body')
    B.ell((0, 2.8, .2), (4.3 * bulk, 4.6, 3.7), 'hide', 'body')
    B.ell((0, 3.3, 2.4), (2.9 * bulk, 3.8, 1.9), 'belly', 'body')
    B.ell(torso['chest'], (6.0 * bulk, 4.2, 4.3), 'hide', 'body')
    B.ell(torso['hump'], (5.6 * bulk, 3.8, 3.6), 'hide', 'body')
    for s in (-1, 1):
        B.sph((s * 6.2 * bulk, -4.2, .2), 3.0 * min(bulk, 1.2), 'hide', 'body')
    # --- legs: thighs, shins, clawed feet dangling below ----------------------
    sw = pose.legs
    for s in (-1, 1):
        hip = v(s * 2.8, 8, -.8)
        knee = v(s * 4.4, 9.6, 3.2 + 1.0 * sw)
        ankle = v(s * 3.6, 11.8, -3.0 + 1.8 * sw)
        B.chain([hip, knee], 2.1, 1.6, 'hide', 'leg')
        B.chain([knee, ankle], 1.3, 1.0, 'hide', 'leg')
        for t in (-1, 0, 1):
            toe = ankle + v(s * .6 + t * 1.1, 1.9, -.8)
            B.chain([ankle, toe], .8, .72, 'claw', 'leg')
    # --- tail with a barb ----------------------------------------------------
    ts = pose.tail
    if name == 'coral':
        tail = [(0, 8, -4), (1 * ts, 11, -7.5), (2.5 * ts + 1.5, 14.5, -8.5), (4 * ts + 3.5, 17.2, -6),
                (5 * ts + 5, 18.6, -2.5)]
        r0, r1 = 1.6, .9
    elif name == 'violet':
        tail = [(0, 8.5, -3.5), (1.2 * ts, 11.5, -6), (2 * ts + 2, 14, -6), (3 * ts + 3.5, 15.5, -3.5)]
        r0, r1 = 1.8, 1.1
    else:
        tail = [(0, 8.5, -3.5), (1.3 * ts, 11.5, -6.5), (2.6 * ts + 2.2, 14.5, -6.8), (3.6 * ts + 4.4, 16.4, -4)]
        r0, r1 = 1.3, .8
    if not (name == 'coral' and dmg.molt >= 3):
        B.chain(tail, r0, r1, 'hide', 'tail')
        tip = np.asarray(tail[-1], float)
        prev = np.asarray(tail[-2], float)
        d = norm(tip - prev)
        barb_c = tip + d * 1.8
        if name == 'coral' and dmg.molt < 2:
            # Stinger: the coral weapon mount.
            B.chain([tip, tip + d * 3.4], 1.3, .72, 'claw', 'tail')
            B.sph(tip + d * 1.4, 1.1, 'mount_hot' if dmg.fire else 'mount', 'tail')
        else:
            side_v = norm(np.cross(d, v(0, 0, 1)))
            for sgn in (-1, 1):
                B.tri(tip, barb_c + d * 1.6, barb_c + side_v * sgn * 2.2 - d * .6, 'barb', 'tail')
    else:
        B.sph(tail[0], 1.4, 'hide', 'tail')
    # --- arms with clawed hands ---------------------------------------------
    reach = pose.arms
    for s in (-1, 1):
        sh = v(s * 6.0 * bulk, -3.2, 1.8)
        el = v(s * 7.6 * bulk, 1.2 + -2 * reach, 3.8 + 2 * reach)
        hand = v(s * 5.2 * bulk, 3.0 - 2.5 * reach, 7.0 + 2.5 * reach)
        B.chain([sh, el], 2.0 * min(bulk, 1.2), 1.5, 'hide', f'farm{s}')
        B.chain([el, hand], 1.5 * min(bulk, 1.15), 1.2, 'hide', f'farm{s}')
        if name == 'violet':
            B.sph(hand, 2.0, 'hide', f'farm{s}')  # heavy fists
        for t in (-1, 0, 1):
            claw = hand + v(s * (.4 + .5 * t), 1.9, 1.3 + .3 * t)
            B.chain([hand, claw], .8, .72, 'claw', f'farm{s}')
        if name == 'gold':
            # Orbs held in each claw: the elder's weapon mounts.
            B.sph(hand + v(0, .8, 1.6), 1.9, 'mount_hot' if dmg.fire else 'orb', f'farm{s}')
    # --- head -----------------------------------------------------------------
    hr = rot_y(pose.head_turn)
    hs = sp.head
    hc = v(0, -6.6 + pose.hunch, 5.4)
    if name == 'violet':
        hc = v(0, -5.4 + pose.hunch, 5.0)  # sunk between the shoulders
    if name == 'coral':
        hc = v(0, -5.8 + pose.hunch, 6.4)

    def H3(p):
        return hc + hr @ (np.asarray(p, float) * hs)

    B.sph(lerp(hc, v(0, -4.5, 1.5), .5), 2.6, 'hide', 'head')  # neck
    B.ell(H3((0, 0, 0)), np.array((4.0, 3.5, 3.6)) * hs, 'hide', 'head', hr)
    # Heavy brow and a short muzzle with a jutting lower jaw.
    B.ell(H3((0, -1.6, 2.2)), np.array((3.7, 1.3, 1.6)) * hs, 'hide', 'head', hr)
    snout_len = 2.6 if name == 'coral' else 2.0
    B.ell(H3((0, 1.4, 2.6 + snout_len * .5)), np.array((2.7, 1.8, snout_len)) * hs, 'hide', 'head', hr)
    B.ell(H3((0, 2.9 + pose.jaw * .8, 2.4 + snout_len * .3)), np.array((2.5, 1.1, snout_len * .9)) * hs,
          'hide', 'head', hr)
    # Pointed ears.
    for s in (-1, 1):
        B.chain([H3((s * 3.2, -1.2, -.4)), H3((s * 5.6, -3.6, -1.6))], 1.1, .72, 'hide', 'head')
    build_horns(B, sp, H3, dmg.molt)
    face = dict(H3=H3, hr=hr, hs=hs, snout=snout_len)
    build_face(B, sp, face, pose, dmg)
    build_insignia(B, sp, dmg, wings)
    if elite_level:
        build_elite(B, sp, H3, elite_level)
    return B, wings, face


def build_elite(B, sp, H3, level):
    """Elite armour, shed one level per hit: 4 gorget + gold-trimmed
    pauldrons, 3 crest spikes, 2 side helm plates, 1 the gold double-chevron
    brow rank mark (always kept)."""
    hs = sp.head
    if level >= 4:
        B.ell(v(0, -3.6, 4.2), (3.6, 1.6, 1.8), 'eplate', 'body')
        for s in (-1, 1):
            B.ell(v(s * 6.6 * sp.bulk, -5.4, .8), (2.8, 1.7, 2.6), 'eplate', 'body')
            B.sph(v(s * 6.6 * sp.bulk, -6.8, 1.2), 1.0, 'crown', 'body')
    if level >= 3:
        for x in (-1.4, 0, 1.4):
            B.chain([H3((x, -2.6, .2)), H3((x * 1.4, -5.2 + abs(x) * .6, -1.0))], 1.0, .72, 'crown', 'head')
    if level >= 2:
        for s in (-1, 1):
            B.ell(H3((s * 3.3, .4, 1.2)), np.array((1.0, 2.0, 1.8)) * hs, 'eplate', 'head')
    chevron = [(x, y, 'gg3' if y < 1 else 'gg2') for y, xs in ((0, (-2, 2)), (1, (-1, 1)), (1, (-2, 2)), (2, (-1, 1)))
               for x in xs] + [(0, 1, 'gg3'), (0, 2, 'gg2')]
    B.decal(H3((0, -2.6, 3.0)), v(1, 0, 0), v(0, 1, 0), chevron, ('head',), force=True)


def build_horns(B, sp, H3, molt):
    name = sp.name
    hm = 'horn'
    for s in (-1, 1):
        port = s < 0
        if name == 'teal':
            # Curled ram horns: out, up, back, then hooking forward.
            pts = [(s * 2.0, -2.8, .6), (s * 4.0, -5.2, .2), (s * 6.2, -6.4, -1.0), (s * 7.6, -5.2, -1.8),
                   (s * 7.4, -3.2, -1.2), (s * 6.4, -2.4, .2)]
            cut = {1: 6 if port else 6, 2: 5 if port else 6, 3: 4 if port else 5}.get(molt, 6)
            B.chain([H3(p) for p in pts[:cut]], 1.6, .8, hm, 'head')
        elif name == 'violet':
            # Short thick horns with riveted metal caps.
            pts = [(s * 2.4, -2.6, .4), (s * 4.0, -4.6, -.2), (s * 4.6, -6.0, -1.2)]
            n = 3 if molt < (2 if port else 3) else 2
            B.chain([H3(p) for p in pts[:n]], 1.7, 1.15, hm, 'head')
            if n == 3:
                B.sph(H3(pts[2]), 1.25, 'cap', 'head')
        elif name == 'coral':
            # Long swept-back predator horns.
            pts = [(s * 2.0, -2.4, .4), (s * 3.8, -4.0, -1.6), (s * 5.4, -5.4, -4.2), (s * 6.6, -6.4, -7.4), (s * 7.2, -6.6, -10.0)]
            n = 5 if molt < (1 if port else 2) else 3
            B.chain([H3(p) for p in pts[:n]], 1.45, .72, hm, 'head')
        else:
            # Elder: back-swept horns behind a crown.
            pts = [(s * 2.4, -2.2, -.6), (s * 4.6, -3.4, -2.2), (s * 5.8, -5.4, -3.0), (s * 5.4, -7.2, -2.2)]
            n = 4 if molt < (2 if port else 3) else 3
            B.chain([H3(p) for p in pts[:n]], 1.3, .72, hm, 'head')
    if name in ('gold', 'colossus'):
        # Crown band with three tines and a ruby.
        tines = [(-2.2, 3.4 - .6 * (molt >= 1)), (0, 4.4 - (molt >= 2) * 2), (2.2, 3.4 - (molt >= 3) * 2.2)]
        for x, ht in tines:
            B.chain([H3((x, -3.0, 1.0)), H3((x * 1.1, -3.0 - ht, .6))], 1.0, .72, 'crown', 'head')
        B.ell(H3((0, -2.9, .8)), np.array((3.4, .9, 3.0)) * sp.head, 'crown', 'head')


def _shape(rows, colours):
    """ASCII pixel shape -> [(dx, dy, colour)], centred on the '+'/'*' origin
    row/col (first occurrence of an origin marker, else the centre)."""
    oy = ox = None
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in '+*' and oy is None:
                oy, ox = y, x
    if oy is None:
        oy, ox = len(rows) // 2, len(rows[0]) // 2
    out = []
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in colours:
                out.append((x - ox, y - oy, colours[ch]))
            elif ch == '*':
                out.append((x - ox, y - oy, colours['*']))
    return out


def build_face(B, sp, face, pose, dmg):
    H3, hr, hs, snout = face['H3'], face['hr'], face['hs'], face['snout']
    ax = hr @ v(1, 0, 0)
    ay = v(0, 1, 0)
    hot = dmg.angry or dmg.flare
    eye = 'eye_r' if hot else sp.eye
    core = 'fire1' if hot else 'gglow'
    # Eyes: 2x2 glowing eyes in dark slanted sockets under the brow.
    for s in (-1, 1):
        a = H3((s * 1.8, -.2, 3.4))
        inner, outer = (0, -1) if s < 0 else (-1, 0)
        o2 = outer + (-1 if s < 0 else 1)
        px = [(x, -1, 'gink') for x in range(-2, 2)] + [(o2, 0, 'gink'), (o2, 1, 'gink')]
        px += [(inner, 0, core), (outer, 0, eye), (inner, 1, eye), (outer, 1, eye if not dmg.flare else 'fire1')]
        if dmg.angry:
            px += [(inner, 0, 'gink'), (outer, 0, eye), (inner, 1, core)]
        B.decal(a, ax, ay, px, ('head',))
    # Snarling maw with fangs; the teal throat emitter glows inside it.
    open_ = 2 if (dmg.angry or pose.jaw > .3 or (sp.name in MAW_WEAPON and dmg.fire)) else 1
    m = H3((0, 2.3 + pose.jaw * .4, 2.6 + snout * .75))
    w = 3 if sp.name in ('violet', 'coral') else 2
    inside = 'fire5'
    if sp.name in MAW_WEAPON and dmg.fire:
        inside = 'fire0' if dmg.fire == 2 else 'fire1'
    px = [(dx, 0, 'gink') for dx in range(-w, w + 1)]
    px += [(-w + 1, 0, 'fang'), (w - 1, 0, 'fang')]  # upper fangs
    if open_ > 1:
        px += [(dx, 1, inside) for dx in range(-w + 1, w)] + [(-w, 1, 'gink'), (w, 1, 'gink')]
        px += [(-w + 1, 1, 'fang'), (w - 1, 1, 'fang'), (0, 2, 'gink')] + [(dx, 2, 'gink') for dx in range(-w + 1, w)]
        px += [(-w + 2, 2, 'fang'), (w - 2, 2, 'fang')]  # lower fangs
    else:
        px += [(-w + 1, 1, 'fang'), (w - 1, 1, 'fang')]
    if sp.name in MAW_WEAPON and dmg.fire:
        px += [(0, -1, 'fire1'), (-1, 1 + open_, 'fire2'), (1, 1 + open_, 'fire2'), (0, 1 + open_, 'fire1')]
    B.decal(m, ax, ay, px, ('head',), force=bool(sp.name in MAW_WEAPON and dmg.fire))
    # Nostrils / brow ridge highlight.
    B.decal(H3((0, -1.9, 3.8)), ax, ay, [(-1, 0, sp.hide[3]), (1, 0, sp.hide[3])], ('head',))
    if sp.name == 'gold':
        # Elder beard: a short forked tuft under the jaw.
        B.decal(H3((0, 3.9, 3.0)), ax, ay, [(-1, 0, 'gg1'), (0, 0, 'gg2'), (1, 0, 'gg1'), (-1, 1, 'gg1'),
                                             (1, 1, 'gg1'), (-1, 2, 'gg0'), (1, 2, 'gg0')], ('head', 'body'))
        B.decal(H3((0, -3.0, 3.6)), ax, ay, [(0, 0, 'blood'), (1, 0, 'blood')], ('head',))


def build_insignia(B, sp, dmg, wings):
    """Rank marks on the chest (and violet pauldron cannons)."""
    ax, ay = v(1, 0, 0), v(0, 1, 0)
    chest = v(0, -1.0, 5.0)
    name = sp.name
    if name == 'teal':
        px = _shape(['i...i', '.i+i.', '..i..'], {'i': 'ivory', '+': 'ivory'})
        B.decal(chest + v(0, .4, 0), ax, ay, px, ('body',))
    elif name == 'violet':
        # Steel chest plate with twin lilac bars; shoulder barb cannons.
        B.ell(v(0, -1.6, 3.2), (4.8, 3.6, 2.2), 'plate', 'body')
        px = [(dx, dy, 'gv3') for dx in range(-2, 3) for dy in (-1, 1)]
        B.decal(v(0, -1.2, 5.4), ax, ay, px, ('body',))
        for s in (-1, 1):
            B.ell(v(s * 6.6, -5.8, .6), (3.0, 1.8, 2.6), 'plate', 'body')
            base = v(s * 7.4, -5.0, 2.4)
            B.chain([base, base + v(s * .4, 1.2, 2.4)], 1.0, .9, 'barrel', 'body')
            B.sph(base + v(s * .4, 1.2, 2.6), .9, 'mount_hot' if dmg.fire else 'muzzle', 'body')
    elif name == 'coral':
        # Three fang slashes across the chest (slanted, always the same way).
        px = []
        for k in range(3):
            for t in range(3):
                px.append((-2 + k * 2 + (1 if t == 0 else 0) - 0, -1 + t, 'gc3'))
        B.decal(chest, ax, ay, px, ('body',))
    elif name == 'warden':
        # Steel breastplate with a violet crescent rank mark.
        B.ell(v(0, -1.4, 3.4), (4.6, 3.6, 2.0), 'plate', 'body')
        px = _shape(['c...c', 'cc+cc', '.ccc.'], {'c': 'gv1', '+': 'gv1'})
        B.decal(v(0, -1.6, 5.4), ax, ay, px, ('body',))
    elif name == 'colossus':
        # Gold breastplate with a ruby sunburst.
        B.ell(v(0, -1.2, 3.6), (4.4, 3.6, 1.8), 'crown', 'body')
        px = _shape(['r.r.r', '.rrr.', 'rr+rr', '.rrr.', 'r.r.r'], {'r': 'blood', '+': 'ivory'})
        B.decal(v(0, -1.2, 5.4), ax, ay, px, ('body',))
    else:
        # Ruby star jewel on a gold breastplate.
        B.ell(v(0, -1.2, 3.6), (3.8, 3.2, 1.6), 'crown', 'body')
        px = _shape(['.r.', 'r+r', '.r.'], {'r': 'blood', '+': 'ivory'})
        B.decal(v(0, -1.0, 5.3), ax, ay, px, ('body',))
    # Molt cracks with glowing fissures on the stony hide.
    if dmg.molt:
        glow = 'fire1' if dmg.angry else 'fire2'
        zig = [(0, 0), (1, 1), (1, 2), (2, 3), (1, 4), (2, 5)]
        cracks = [((-3.4, -3.4, 4.0), zig[:4], 1), ((3.0, 0.6, 3.8), [(0, 0), (-1, 1), (-1, 2), (-2, 3), (-1, 4)], 2),
                  ((-4.6, -5.4, 1.5), [(0, 0), (1, 0), (2, 1), (3, 1)], 2), ((-1.0, 3.6, 3.2), zig, 3),
                  ((5.0, -4.6, 1.6), [(0, 0), (-1, 1), (-1, 2), (-2, 2)], 3)]
        mats = ('hide', 'belly', 'plate', 'crown')
        for anchor, path, stage in cracks:
            if stage > dmg.molt:
                continue
            px = []
            for i, (x, y) in enumerate(path):
                px += [(x - 1, y, 'gink'), (x, y, glow if i % 3 else 'fire0'), (x + 1, y, 'fire3')]
            B.decal(v(*anchor), ax, ay, px, (), mats=mats)
        # The fissured stone glows through at the core on the last molt.
        if dmg.molt >= 3:
            B.decal(v(0, 2.4, 4.6), ax, ay, [(0, 0, 'fire1'), (-1, 0, 'fire2'), (1, 0, 'fire2'), (0, 1, 'fire2')],
                    (), mats=mats)


# ---------------------------------------------------------------------------
# Materials: palette ramps per species.
# ---------------------------------------------------------------------------
def materials(sp: Species, dmg: Damage):
    hide = sp.hide
    wing = sp.wing
    if dmg.angry:
        wing = ('hot0', 'hot0', 'hot1', 'hot2')
    mats = {
        'hide': hide,
        'belly': (hide[1], sp.belly[0], sp.belly[1], sp.belly[2]),
        'wingf': wing,
        'wbone': (sp.bone[0], sp.bone[1], sp.bone[2], sp.bone[2]),
        'wfinger': (sp.bone[0], sp.bone[0], sp.bone[1], sp.bone[1]),
        'claw': ('bone0', 'bone1', 'fang', 'fang'),
        'horn': ('bone0', 'bone1', 'bone2', 'fang'),
        'cap': ('met0', 'met1', 'met2', 'met3'),
        'plate': ('met0', 'met1', 'met2', 'met3'),
        'barrel': ('met0', 'met0', 'met1', 'met2'),
        'crown': ('gg0', 'gg1', 'gg2', 'gg3'),
        'eplate': ('met0', 'met1', 'met2', 'met3'),
        'barb': (hide[0], hide[1], hide[2], hide[3]) if sp.name != 'coral' else ('bone0', 'bone1', 'bone2', 'fang'),
        'orb': ('vio1', 'vio2', 'vio3', 'white'),
        'muzzle': ('ink2', 'ink2', 'met1', 'met1'),
        'mount': ('blood', 'blood', 'eye_r', 'eye_r'),
        'mount_hot': ('fire3', 'fire2', 'fire1', 'fire0'),
    }
    if sp.name == 'violet':
        mats['wbone'] = ('gv0', 'gv1', 'gv2', 'gv2')
        mats['wfinger'] = ('gv0', 'gv0', 'gv1', 'gv1')
    if sp.name == 'gold':
        mats['wbone'] = ('gg0', 'gg1', 'gg2', 'gg3')
        mats['wfinger'] = ('gg0', 'gg0', 'gg1', 'gg2')
    return mats


THRESH = (.22, .5, .8)


def shade(R: Raster, mats, texture=None):
    """Quantised key light -> palette names per pixel."""
    out = np.full((R.h, R.w), '', dtype=object)
    lam = np.clip((R.n * LIGHT).sum(-1), 0, 1)
    val = .18 + .82 * lam
    if texture is not None:
        val = val + texture
    for name, ramp in mats.items():
        m = R.mat == name
        if not m.any():
            continue
        tone = np.digitize(val, THRESH)
        if name == 'wingf':
            # Back faces (the underside seen during the upstroke) stay darker.
            tone = np.where(R.back, (val > .55).astype(int), 2 + (val > .78).astype(int))
        cols = np.array(ramp, dtype=object)[np.clip(tone, 0, 3)]
        out[m] = cols[m]
    return out


def render(sp: Species, pose: Pose, view: View, dmg: Damage, texture_fn=None, outline='gink',
           elite_level=0, wings_on=True):
    B, wings, face = build_creature(sp, pose, view, dmg, elite_level, wings_on)
    return rasterize(B, sp, view, dmg, texture_fn, outline)


def rasterize(B, sp, view, dmg, texture_fn=None, outline='gink'):
    w, h = view.size
    R = Raster(w, h, view.origin)
    for p in B.prims:
        if isinstance(p, Ellipsoid):
            R.ellipsoid(p)
        elif isinstance(p, Sphere):
            R.sphere(p)
        else:
            R.tri(p)
    tex = texture_fn(R) if texture_fn else None
    names = shade(R, materials(sp, dmg), tex)
    cv = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            n = names[y, x]
            if n:
                cv.px(x, y, n)
    _clean_specks(cv, R, names)
    _contours(cv, R)
    _decals(cv, R, B.decals)
    cv.outline(outline)
    return cv, R, B


def _clean_specks(cv, R, names):
    """Replace single isolated tone pixels inside a material with their
    neighbours' majority tone (pixel-art cleanup)."""
    h, w = names.shape
    src = names.copy()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            n = src[y, x]
            if not n:
                continue
            neigh = [src[y - 1, x], src[y + 1, x], src[y, x - 1], src[y, x + 1]]
            if n in neigh:
                continue
            same_mat = [c for c, (yy, xx) in zip(neigh, ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)))
                        if c and R.mat[yy, xx] == R.mat[y, x]]
            if len(same_mat) >= 3:
                best = max(set(same_mat), key=same_mat.count)
                cv.px(x, y, best)


def _contours(cv, R):
    """Dark contour where a nearer part overlaps a farther one: drawn on the
    far side so the near shape keeps its full silhouette."""
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
        gap = occ & (zs > z + 2.6) & (ps != part)
        line |= gap
    ys, xs = np.nonzero(line)
    for y, x in zip(ys, xs):
        if R.mat[y, x] in ('claw', 'horn', 'fang'):
            cv.px(x, y, 'gink')
        else:
            cv.px(x, y, 'gink')


def _decals(cv, R, decals):
    for d in decals:
        for dx, dy, col in d.pixels:
            p = d.anchor + v(dx, dy, 0)
            x = int(math.floor(p[0] + R.origin[0]))
            y = int(math.floor(p[1] + R.origin[1]))
            if not (0 <= x < R.w and 0 <= y < R.h):
                continue
            if d.force or R.part[y, x] in d.parts or (d.mats and R.mat[y, x] in d.mats):
                cv.px(x, y, col)
