"""Shared 64-grid pixel-art kit for the combat, ship and sentinel atlases.

Everything is rasterised at logical pixel centres onto a small RGBA canvas
(one array element = one logical pixel) and written to the atlas at exactly
1x: the PNG cell *is* the logical grid. No antialiasing, no resampling other
than nearest-neighbour, and every colour snaps to the bounded PALETTE below.

Deterministic: no randomness except `random.Random(seed)` passed in by
callers, so regenerating produces identical bytes.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

# --------------------------------------------------------------------------
# Bounded palette (authoritative list; plan/sprite-atlas.md mirrors it).
# --------------------------------------------------------------------------
PALETTE = {
    # outlines and darks
    'ink': '#100e2c', 'ink2': '#1c1a40', 'night': '#2b2a55',
    # teal species ramp
    'teal0': '#0f4f5e', 'teal1': '#147c93', 'teal2': '#39dfcc', 'teal3': '#a6fff0',
    # violet species ramp
    'vio0': '#3a2a78', 'vio1': '#5840a3', 'vio2': '#a888ff', 'vio3': '#e0d4ff',
    # coral species ramp
    'cor0': '#6e1e3c', 'cor1': '#aa385c', 'cor2': '#ff786c', 'cor3': '#ffc2a4',
    # gold species ramp
    'gol0': '#6b3f1e', 'gol1': '#a36635', 'gol2': '#efbd57', 'gol3': '#fff0a8',
    # molt body tones (exposed under-carapace), 3 per species
    'mt1': '#51d4ac', 'mt2': '#8bd47d', 'mt3': '#d7c968',
    'mv1': '#bb87d3', 'mv2': '#d980ab', 'mv3': '#ed9984',
    'mc1': '#f99b78', 'mc2': '#f3b26e', 'mc3': '#ebcc75',
    'mg1': '#e7ab73', 'mg2': '#e79b8d', 'mg3': '#ed8fa7',
    # flesh / glow / eyes
    'belly': '#ffd6a4', 'ivory': '#fff5c9', 'white': '#ffffff',
    'eye_r': '#ff355f', 'blood': '#c4203f',
    # armour metal
    'met0': '#2b3355', 'met1': '#4a5680', 'met2': '#8a9cc8', 'met3': '#d8e2ff',
    # thermal fire ramp (style guide re-entry colours)
    'fire0': '#fffdf7', 'fire1': '#ffe042', 'fire2': '#ffbf1f', 'fire3': '#ff6b1a',
    'fire4': '#e8430c', 'fire5': '#9e1b1b', 'fire6': '#3b171d',
    # angry membrane ramp
    'hot0': '#7a2414', 'hot1': '#c4501c', 'hot2': '#ffbd53',
    # friendly energy (player shots, shields)
    'mint': '#70f5d5', 'cyan': '#6edcff', 'sky': '#245775', 'deep': '#163a52',
    'amber': '#ffad53', 'heat': '#ff786c',
    # smoke
    'smk0': '#2a2638', 'smk1': '#4a4458', 'smk2': '#7a7290', 'smk3': '#b4acc4',
    # hull (player ship)
    'hul0': '#141c30', 'hul1': '#24304c', 'hul2': '#3c4c70', 'hul3': '#6c80a8',
    # gargoyle creatures (2026-11 round 2): darker, saturated hide ramps,
    # membrane ramps, horn/bone, glowing eyes and a deeper outline
    'gink': '#0a0716',
    'gt0': '#082a33', 'gt1': '#0f5a63', 'gt2': '#16958a', 'gt3': '#5fd8bc',
    'gtw0': '#0c2236', 'gtw1': '#163c55', 'gtw2': '#1f6c78',
    'gv0': '#24164e', 'gv1': '#4a2fa0', 'gv2': '#9070ff', 'gv3': '#cdb8ff',
    'gvw0': '#1e1440', 'gvw1': '#3a2678', 'gvw2': '#6a4cd0',
    'gc0': '#4a0e24', 'gc1': '#9a2040', 'gc2': '#f25a64', 'gc3': '#ffa08a',
    'gcw0': '#2e0a1e', 'gcw1': '#5e1638', 'gcw2': '#b8385a',
    'gg0': '#3e2108', 'gg1': '#7a4a12', 'gg2': '#c8902a', 'gg3': '#ffd866',
    'ggw0': '#2a1a10', 'ggw1': '#4a2c1a', 'ggw2': '#8a5a2e',
    'bone0': '#4a3a2e', 'bone1': '#9a8466', 'bone2': '#d8c69a', 'fang': '#fff3d6',
    'geye': '#ffd23f', 'gglow': '#fffbe0',
}


def rgb(name_or_hex: str) -> tuple[int, int, int]:
    h = PALETTE.get(name_or_hex, name_or_hex)
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


PALETTE_RGB = np.array([rgb(v) for v in PALETTE.values()], dtype=np.int32)


class Canvas:
    """A logical-pixel RGBA canvas. Colours are palette names or #hex."""

    def __init__(self, w: int = 64, h: int = 64):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)
        ys, xs = np.mgrid[0:h, 0:w]
        self._cx = xs + .5
        self._cy = ys + .5

    # -- primitives ---------------------------------------------------------
    def _paint(self, mask, color):
        r, g, b = rgb(color)
        self.a[mask] = (r, g, b, 255)

    def clear(self, mask):
        self.a[mask] = 0

    def poly_mask(self, pts):
        inside = np.zeros((self.h, self.w), dtype=bool)
        n = len(pts)
        for i in range(n):
            x0, y0 = pts[i - 1]
            x1, y1 = pts[i]
            if y0 == y1:
                continue
            cond = (y1 > self._cy) != (y0 > self._cy)
            xint = (x0 - x1) * (self._cy - y1) / (y0 - y1) + x1
            inside ^= cond & (self._cx < xint)
        return inside

    def poly(self, pts, color):
        self._paint(self.poly_mask(pts), color)

    def ellipse_mask(self, cx, cy, rx, ry):
        return ((self._cx - cx) / max(rx, .01)) ** 2 + ((self._cy - cy) / max(ry, .01)) ** 2 <= 1

    def ellipse(self, cx, cy, rx, ry, color):
        self._paint(self.ellipse_mask(cx, cy, rx, ry), color)

    def rect(self, x, y, w, h, color):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        if x1 > x0 and y1 > y0:
            r, g, b = rgb(color)
            self.a[y0:y1, x0:x1] = (r, g, b, 255)

    def px(self, x, y, color):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            r, g, b = rgb(color)
            self.a[y, x] = (r, g, b, 255)

    def erase(self, x, y):
        x, y = int(math.floor(x)), int(math.floor(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = 0

    def line(self, p0, p1, color, width=1):
        (x0, y0), (x1, y1) = p0, p1
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5) + 1
        for i in range(steps + 1):
            t = i / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            if width == 1:
                self.px(x, y, color)
            else:
                off = (width - 1) / 2
                self.rect(math.floor(x - off), math.floor(y - off), width, width, color)

    def opaque(self):
        return self.a[..., 3] > 0

    def is_color(self, color):
        r, g, b = rgb(color)
        return (self.a[..., 3] > 0) & (self.a[..., 0] == r) & (self.a[..., 1] == g) & (self.a[..., 2] == b)

    def recolor(self, src, dst, mask=None):
        m = self.is_color(src)
        if mask is not None:
            m &= mask
        self._paint(m, dst)

    # -- finishing passes ---------------------------------------------------
    def outline(self, color='ink', diagonal=False):
        """Adds a 1px outline around the opaque silhouette (outside)."""
        o = self.opaque()
        grow = np.zeros_like(o)
        grow[1:, :] |= o[:-1, :]
        grow[:-1, :] |= o[1:, :]
        grow[:, 1:] |= o[:, :-1]
        grow[:, :-1] |= o[:, 1:]
        if diagonal:
            grow[1:, 1:] |= o[:-1, :-1]
            grow[1:, :-1] |= o[:-1, 1:]
            grow[:-1, 1:] |= o[1:, :-1]
            grow[:-1, :-1] |= o[1:, 1:]
        self._paint(grow & ~o, color)

    def rim(self, ramps):
        """Top-left key light: for each (base -> light, shadow) ramp, base
        pixels with an outline/transparent neighbour above-left get the light
        tone and those with one below-right get the shadow tone."""
        o = self.opaque()
        ink = self.is_color('ink') | ~o
        up = np.zeros_like(o); up[1:, :] = ink[:-1, :]
        left = np.zeros_like(o); left[:, 1:] = ink[:, :-1]
        down = np.zeros_like(o); down[:-1, :] = ink[1:, :]
        right = np.zeros_like(o); right[:, :-1] = ink[:, 1:]
        for base, (light, shadow) in ramps.items():
            m = self.is_color(base)
            if shadow:
                self._paint(m & (down | right) & ~(up | left), shadow)
            if light:
                self._paint(m & (up | left) & ~(down | right), light)

    def mirror_left_to_right(self, x_split=None):
        """Copies columns [0, split) mirrored onto [w - split, w)."""
        s = self.w // 2 if x_split is None else x_split
        self.a[:, self.w - s:] = self.a[:, :s][:, ::-1]

    def flip_x(self):
        self.a = self.a[:, ::-1].copy()

    def shift(self, dx, dy):
        out = np.zeros_like(self.a)
        h, w = self.h, self.w
        xs0, xs1 = max(0, -dx), min(w, w - dx)
        ys0, ys1 = max(0, -dy), min(h, h - dy)
        out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = self.a[ys0:ys1, xs0:xs1]
        self.a = out

    def paste(self, other: 'Canvas', dx=0, dy=0):
        src = other.a
        h, w = src.shape[:2]
        for y in range(h):
            ty = y + dy
            if not 0 <= ty < self.h:
                continue
            row = src[y]
            m = row[:, 3] > 0
            for x in np.nonzero(m)[0]:
                tx = x + dx
                if 0 <= tx < self.w:
                    self.a[ty, tx] = row[x]

    def copy(self) -> 'Canvas':
        c = Canvas(self.w, self.h)
        c.a = self.a.copy()
        return c

    def map_colors(self, mapping: dict):
        """Simultaneous palette swap {src: dst}."""
        masks = {s: self.is_color(s) for s in mapping}
        for s, m in masks.items():
            self._paint(m, mapping[s])

    def rotated(self, degrees, cx=None, cy=None) -> 'Canvas':
        """Nearest-neighbour rotation about (cx, cy) on the logical grid."""
        cx = self.w / 2 if cx is None else cx
        cy = self.h / 2 if cy is None else cy
        t = math.radians(degrees)
        c, s = math.cos(t), math.sin(t)
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        X, Y = xs + .5 - cx, ys + .5 - cy
        sx = np.floor(c * X + s * Y + cx).astype(int)
        sy = np.floor(-s * X + c * Y + cy).astype(int)
        ok = (sx >= 0) & (sx < self.w) & (sy >= 0) & (sy < self.h)
        out = Canvas(self.w, self.h)
        out.a[ok] = self.a[sy[ok], sx[ok]]
        return out

    def snap_palette(self):
        o = self.opaque()
        pix = self.a[o][:, :3].astype(np.int32)
        if len(pix):
            d = ((pix[:, None, :] - PALETTE_RGB[None, :, :]) ** 2).sum(-1)
            self.a[o, :3] = PALETTE_RGB[d.argmin(1)].astype(np.uint8)
        self.a[..., 3] = np.where(self.a[..., 3] >= 128, 255, 0)


class Atlas:
    def __init__(self, cols, rows, cell_w=64, cell_h=64):
        self.cols, self.rows, self.cw, self.ch = cols, rows, cell_w, cell_h
        self.img = np.zeros((rows * cell_h, cols * cell_w, 4), dtype=np.uint8)

    def put(self, col, row, canvas: Canvas):
        assert canvas.w == self.cw and canvas.h == self.ch, (canvas.w, canvas.h)
        canvas.snap_palette()
        self.img[row * self.ch:(row + 1) * self.ch, col * self.cw:(col + 1) * self.cw] = canvas.a

    def save(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.img, 'RGBA').save(path, optimize=True)
        print(f'Generated {path.relative_to(ROOT)}: {self.img.shape[1]}x{self.img.shape[0]} RGBA')


def polar(origin, angle_deg, length, mirror=False):
    """Point at `length` from origin. angle 0 = outward (left for the left
    wing), positive = upward."""
    a = math.radians(angle_deg)
    dx = -math.cos(a) * length
    if mirror:
        dx = -dx
    return (origin[0] + dx, origin[1] - math.sin(a) * length)


def lerp(a, b, t):
    return a + (b - a) * t


def lerp_pt(p, q, t):
    return (lerp(p[0], q[0], t), lerp(p[1], q[1], t))
