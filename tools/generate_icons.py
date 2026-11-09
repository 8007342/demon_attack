#!/usr/bin/env python3
"""Generate the Demon Attack app icon set (favicons, PWA, apple-touch, SVG).

Reproducible and deterministic: no randomness, no AI output in the shipped
pixels. The emblem is defined as geometry in art/icons/icon-spec.json and
rasterised at pixel centres onto a small logical grid, then scaled up
nearest-neighbour, so every icon is crisp pixel art. The 16, 32 and 48 px
favicons come from hand-tuned pixel maps (art/icons/badge-*.txt) because a
plain rasterisation of the emblem is muddy at those sizes.

    uv run --with pillow --with numpy python tools/generate_icons.py
    uv run --with pillow --with numpy python tools/generate_icons.py --dump 32
    uv run --with pillow --with numpy python tools/generate_icons.py --sheet out.png

--dump N prints the procedural badge at N px as a pixel map (the starting
point for a hand-tuned map); --sheet writes a review contact sheet.
"""
from __future__ import annotations

import argparse
import io
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / 'art/icons/icon-spec.json').read_text())
PAL = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) for k, v in SPEC['palette'].items()}
GEO = SPEC['geometry']

# One character per palette entry in the hand-tuned pixel maps.
CHARS = {
    '.': None, 'k': 'ink', 'n': 'ink2', 'N': 'night', 'g': 'glow0', 'G': 'glow1',
    'i': 'bone', 't': 'teal', 'm': 'mint', 'c': 'cyan', '1': 'hul1', '2': 'hul2', '3': 'hul3',
    'a': 'vio0', 'b': 'vio1', 'v': 'vio2', 'w': 'vio3', 'r': 'eye', 'o': 'coral',
    'd': 'gol0', 'e': 'gol1', 'y': 'gol2', 'Y': 'gol3',
}
KEY_TO_CHAR = {v: k for k, v in CHARS.items() if v}
SS = 4  # supersamples per axis


# ---------------------------------------------------------------- geometry
def _samples(n: int, scale: float = 1.0, centre=(0.5, 0.5)):
    """Sample coordinates (unit space) for an n x n grid, SS x SS per pixel.

    `scale` < 1 shrinks the emblem about `centre` (used by full-bleed icons).
    """
    o = (np.arange(n * SS) + 0.5) / (n * SS)
    x, y = np.meshgrid(o, o)
    cx, cy = centre
    return (x - cx) / scale + 0.5, (y - cy) / scale + 0.5


def _reduce(mask: np.ndarray, n: int) -> np.ndarray:
    return mask.reshape(n, SS, n, SS).mean(axis=(1, 3)) >= 0.5


def _poly(x, y, pts):
    inside = np.zeros(x.shape, bool)
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        cond = ((yi > y) != (yj > y)) & (x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi)
        inside ^= cond
        j = i
    return inside


def _mirror(pts):
    return [(1 - px, py) for px, py in pts]


def _rounded(x, y, inset, radius):
    lo, hi = inset, 1 - inset
    r = max(radius - inset, 0.001)
    qx = np.clip(x, lo + r, hi - r)
    qy = np.clip(y, lo + r, hi - r)
    return (x >= lo) & (x <= hi) & (y >= lo) & (y <= hi) & ((x - qx) ** 2 + (y - qy) ** 2 <= r * r)


def _half(pts):
    """A right-half outline (top centre to bottom centre) made whole."""
    return list(pts) + _mirror(pts[::-1])[1:-1]


def _horn(spec, steps=48):
    (bx, by), (cx, cy), (tx, ty) = spec['base'], spec['ctrl'], spec['tip']
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        px = (1 - t) ** 2 * bx + 2 * (1 - t) * t * cx + t * t * tx
        py = (1 - t) ** 2 * by + 2 * (1 - t) * t * cy + t * t * ty
        dx = 2 * (1 - t) * (cx - bx) + 2 * t * (tx - cx)
        dy = 2 * (1 - t) * (cy - by) + 2 * t * (ty - cy)
        ln = math.hypot(dx, dy) or 1
        w = spec['width'] * (1 - t) ** 0.8 / 2
        left.append((px - dy / ln * w, py + dx / ln * w))
        right.append((px + dy / ln * w, py - dx / ln * w))
    return left + right[::-1]


def emblem_masks(n: int, scale: float = 1.0) -> dict[str, np.ndarray]:
    x, y = _samples(n, scale)
    s = GEO['ship']
    horn = _horn(GEO['horn'])
    raw = {
        'hull': _poly(x, y, s['hull']),
        'wings': _poly(x, y, s['wing']) | _poly(x, y, _mirror(s['wing'])),
        'canopy': _poly(x, y, s['canopy']),
        'flame': _poly(x, y, s['flame']),
        'horns': _poly(x, y, horn) | _poly(x, y, _mirror(horn)),
        'head': _poly(x, y, _half(GEO['head'])) | _poly(x, y, GEO['ears'])
                | _poly(x, y, _mirror(GEO['ears'])),
        'brow': _poly(x, y, _half(GEO['brow'])),
        'eyes': _poly(x, y, GEO['eyes']) | _poly(x, y, _mirror(GEO['eyes'])),
        'mouth': _poly(x, y, GEO['mouth']),
        'fangs': _poly(x, y, GEO['fang']) | _poly(x, y, _mirror(GEO['fang'])),
    }
    m = {k: _reduce(v, n) for k, v in raw.items()}
    m['ship'] = m['hull'] | m['wings']
    m['crest'] = m['horns'] | m['head']
    return m


def _shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = \
        m[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return out


def _dilate(m, r=1, diagonal=True):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if (dx or dy) and (diagonal or abs(dx) + abs(dy) <= r) and dx * dx + dy * dy <= r * r + r:
                out |= _shift(m, dx, dy)
    return out


# --------------------------------------------------------------- painting
def paint_emblem(grid: np.ndarray, n: int, scale: float, field: np.ndarray) -> None:
    """Paint crescent, eyes, glow and ship into `grid` (array of palette keys)."""
    m = emblem_masks(n, scale)
    ship = m['ship'] | m['flame']
    cr = m['crest']
    # Cyan glow: a stepped halo around the whole emblem, brighter round the ship.
    gr = max(1, round(GEO['glow_radius'] * n * scale))
    grid[_dilate(cr | ship, gr) & field] = 'glow0'
    grid[_dilate(ship, gr) & field & ~cr] = 'glow1'
    grid[_dilate(cr | ship, 1, diagonal=False) & field & ~_dilate(ship, gr)] = 'glow1'
    # Gargoyle head, lit from above: highlight on upward faces, shade below.
    hd = m['head']
    grid[hd] = 'vio2'
    grid[hd & ~_shift(hd, 0, 1)] = 'vio3'
    below = hd & ~_shift(hd, 0, -1)
    grid[hd & ~_shift(hd, 0, -max(2, n // 24)) & ~below] = 'vio1'
    grid[below] = 'vio0'
    # Bone horns, separated from the head by a dark seam.
    hn = m['horns'] & ~hd
    grid[hn] = 'vio3'
    grid[hn & ~_shift(hn, 0, 1)] = 'bone'
    grid[hn & ~_shift(hn, 0, -1)] = 'vio1'
    grid[hn & _dilate(hd, 1, diagonal=False)] = 'ink'
    # Furrowed brow, deep sockets, burning eyes and a fanged mouth.
    grid[(m['brow'] | _dilate(m['eyes'], 1, diagonal=False)) & hd] = 'vio0'
    grid[m['brow'] & ~_shift(m['brow'], 0, 1) & hd] = 'vio3'
    grid[m['mouth'] & hd] = 'ink'
    grid[m['fangs']] = 'bone'
    grid[m['eyes']] = 'eye'
    grid[m['eyes'] & ~_shift(m['eyes'], 0, 1)] = 'coral'
    # Starfighter with a dark outline so it separates from crescent and glow.
    outline = _dilate(ship, 1, diagonal=False) & ~ship
    grid[outline] = 'ink'
    grid[m['wings']] = 'teal'
    grid[m['wings'] & ~_shift(m['wings'], 0, 1)] = 'mint'
    grid[m['hull']] = 'hul2'
    hull_l = m['hull'] & ~_shift(m['hull'], 1, 0)
    hull_r = m['hull'] & ~_shift(m['hull'], -1, 0)
    grid[hull_l] = 'hul3'
    grid[hull_r] = 'hul1'
    grid[m['canopy']] = 'cyan'
    grid[m['canopy'] & ~_shift(m['canopy'], 0, 1)] = 'mint'
    grid[m['flame']] = 'teal'
    grid[m['flame'] & _shift(m['hull'], 0, 1)] = 'mint'


def render_badge(n: int) -> np.ndarray:
    x, y = _samples(n)
    tile = _reduce(_rounded(x, y, 0, GEO['tile_radius']), n)
    inner = _reduce(_rounded(x, y, GEO['rim'], GEO['tile_radius']), n)
    field = _reduce(_rounded(x, y, GEO['rim'] + GEO['rim_gap'], GEO['tile_radius']), n)
    grid = np.full((n, n), '', dtype=object)
    grid[tile] = 'gol2'
    grid[tile & ~_shift(tile, 0, 1)] = 'gol3'
    grid[tile & ~_shift(tile, 0, -1)] = 'gol1'
    grid[inner] = 'ink'
    paint_emblem(grid, n, 1.0, field)
    return grid


def render_full_bleed(n: int, ring: float) -> np.ndarray:
    x, y = _samples(n)
    d2 = (x - 0.5) ** 2 + (y - 0.5) ** 2
    rw = GEO['rim'] * ring / 0.5
    ring_m = _reduce((d2 <= ring ** 2) & (d2 > (ring - rw) ** 2), n)
    field = _reduce(d2 <= (ring - rw - GEO['rim_gap'] * ring / 0.5) ** 2, n)
    grid = np.full((n, n), 'ink', dtype=object)
    grid[_reduce(d2 <= (ring + rw * 0.6) ** 2, n) & ~ring_m] = 'ink2'
    grid[ring_m] = 'gol2'
    grid[ring_m & ~_shift(ring_m, 0, 1) & (np.arange(n)[:, None] < n / 2)] = 'gol3'
    grid[ring_m & ~_shift(ring_m, 0, -1) & (np.arange(n)[:, None] > n / 2)] = 'gol1'
    # The emblem is drawn at a scale that fits it inside the ring.
    paint_emblem(grid, n, ring / 0.5 * 0.82, field)
    return grid


def render_monochrome(n: int) -> np.ndarray:
    m = emblem_masks(n, 0.8)
    shape = (m['crest'] | m['ship'] | m['flame']) & ~m['eyes']
    shape &= ~(_dilate(m['ship'], 1, diagonal=False) & ~m['ship'] & m['crest'])
    grid = np.full((n, n), '', dtype=object)
    grid[shape] = 'white'
    return grid


def load_map(path: Path) -> np.ndarray:
    """A pixel map, one character per pixel (see CHARS); '#' lines are comments.

    A map whose rows are half as wide as it is tall holds the left half only;
    it is mirrored, swapping the hull's lit and shaded sides (3 <-> 1).
    """
    rows = [r for r in path.read_text().splitlines() if r and not r.startswith('#')]
    if all(len(r) * 2 == len(rows) for r in rows):
        rows = [r + r[::-1].translate(str.maketrans('31', '13')) for r in rows]
    grid = np.array([[CHARS[ch] or '' for ch in r] for r in rows], dtype=object)
    assert grid.shape[0] == grid.shape[1], f'{path} is not square'
    return grid


def dump_map(grid: np.ndarray) -> str:
    return '\n'.join(''.join(KEY_TO_CHAR.get(k, '.') for k in row) for row in grid)


def to_image(grid: np.ndarray, size: int) -> Image.Image:
    n = grid.shape[0]
    arr = np.zeros((n, n, 4), np.uint8)
    for key in set(grid.flat):
        if not key:
            continue
        colour = (255, 255, 255) if key == 'white' else PAL[key]
        arr[grid == key] = (*colour, 255)
    img = Image.fromarray(arr, 'RGBA')
    return img if size == n else img.resize((size, size), Image.NEAREST)


def badge(size: int, grid_n: int | None = None) -> Image.Image:
    tuned = SPEC['hand_tuned'].get(str(size))
    if tuned and grid_n is None:
        return to_image(load_map(ROOT / tuned), size)
    return to_image(render_badge(grid_n or size), size)


# ---------------------------------------------------------------- writers
def png_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, 'PNG', optimize=True)
    return buf.getvalue()


def write_ico(path: Path, images: list[Image.Image]) -> None:
    """ICO with PNG-compressed entries (supported by every current browser)."""
    blobs = [png_bytes(im) for im in images]
    out = struct.pack('<HHH', 0, 1, len(images))
    offset = 6 + 16 * len(images)
    for im, blob in zip(images, blobs):
        w = im.width % 256
        out += struct.pack('<BBBBHHII', w, w, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    path.write_bytes(out + b''.join(blobs))


def svg_layer(grid: np.ndarray, cls: str) -> str:
    """One <path> per colour, built from horizontal runs of pixels."""
    n = grid.shape[0]
    paths = []
    for key in sorted({k for k in grid.flat if k}):
        d = []
        for yy in range(n):
            xx = 0
            while xx < n:
                if grid[yy, xx] == key:
                    start = xx
                    while xx < n and grid[yy, xx] == key:
                        xx += 1
                    d.append(f'M{start} {yy}h{xx - start}v1h{start - xx}z')
                else:
                    xx += 1
        paths.append(f'<path fill="{SPEC["palette"][key]}" d="{"".join(d)}"/>')
    return f'<g class="{cls}" transform="scale({64 / n:.6f})">{"".join(paths)}</g>'


def write_svg(path: Path) -> None:
    """Pixel-exact SVG: the 64-grid emblem, swapping to the hand-tuned 16, 32
    and 48 px maps when it is drawn at those sizes (media queries inside an
    SVG image match the image's own viewport, in CSS px)."""
    layers = [svg_layer(render_badge(64), 'p64')]
    style = ['.p16,.p32,.p48{display:none}']
    lo = 0
    for size in (16, 32, 48):
        layers.append(svg_layer(load_map(ROOT / SPEC['hand_tuned'][str(size)]), f'p{size}'))
        hi = size + 8
        style.append(f'@media (min-width:{lo}px) and (max-width:{hi - 0.02}px)'
                     f'{{.p{size}{{display:inline}}.p64{{display:none}}}}')
        lo = hi
    path.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" '
        'shape-rendering="crispEdges">'
        f'<title>Demon Attack</title><style>{"".join(style)}</style>{"".join(layers)}</svg>\n')


def build() -> list[Path]:
    written = []
    for out in SPEC['outputs']:
        path = ROOT / out['path']
        path.parent.mkdir(parents=True, exist_ok=True)
        kind = out['kind']
        if kind == 'ico':
            write_ico(path, [badge(s) for s in out['sizes']])
        elif kind == 'svg':
            write_svg(path)
        else:
            size, n = out['size'], out.get('grid')
            if kind == 'badge':
                img = badge(size, n)
            elif kind == 'full_bleed':
                img = to_image(render_full_bleed(n, out['ring']), size)
            else:
                img = to_image(render_monochrome(n), size)
            assert img.size == (size, size)
            img.save(path, 'PNG', optimize=True)
        written.append(path)
    return written


def contact_sheet(dest: Path) -> None:
    """Every icon on light and dark strips, natural size and zoomed."""
    icons = ROOT / 'web/icons'
    rows = [
        ('16', badge(16)), ('32', badge(32)), ('48', badge(48)),
        ('180 apple', Image.open(icons / 'apple-touch-icon.png')),
        ('192', Image.open(icons / 'Icon-192.png')),
        ('512', Image.open(icons / 'Icon-512.png')),
        ('maskable 512', Image.open(icons / 'Icon-maskable-512.png')),
        ('mono 512', Image.open(icons / 'Icon-monochrome-512.png')),
    ]
    bgs = [(255, 255, 255), (222, 225, 230), (53, 54, 58), (32, 33, 36)]
    W = 1500
    sheet = Image.new('RGB', (W, 1640), (128, 128, 128))
    # Row 1: tab-bar sizes at 1x and 4x on each background.
    xo = 0
    for bg in bgs:
        strip = Image.new('RGB', (W // 4, 300), bg)
        x = 10
        for label, im in rows[:3]:
            strip.paste(im, (x, 10), im)
            z = im.resize((im.width * (4 if im.width < 48 else 2),) * 2, Image.NEAREST)
            strip.paste(z, (x, 70), z)
            x += z.width + 12
        sheet.paste(strip, (xo, 0))
        xo += W // 4
    # Row 2: large icons at 256 px, plus a circle-masked and a squircle-masked maskable.
    big = [im.convert('RGBA').resize((256, 256), Image.NEAREST) for _, im in rows[3:]]
    mask_c = Image.new('L', (256, 256), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask_c).ellipse((0, 0, 255, 255), fill=255)
    mask_s = Image.new('L', (256, 256), 0)
    ImageDraw.Draw(mask_s).rounded_rectangle((0, 0, 255, 255), radius=60, fill=255)
    mk = big[3].copy()
    circ = Image.new('RGBA', (256, 256)); circ.paste(mk, (0, 0), mask_c)
    sq = Image.new('RGBA', (256, 256)); sq.paste(mk, (0, 0), mask_s)
    big += [circ, sq]
    for row, bg in enumerate([bgs[0], bgs[3]]):
        strip = Image.new('RGB', (W, 660), bg)
        for i, im in enumerate(big):
            strip.paste(im, (10 + (i % 4) * 300 + (i // 4) * 0, 10 + (i // 4) * 320), im)
        sheet.paste(strip, (0, 310 + row * 665))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--dump', type=int, help='print the procedural badge at N px as a pixel map')
    ap.add_argument('--sheet', type=Path, help='also write a review contact sheet here')
    args = ap.parse_args()
    if args.dump:
        print(dump_map(render_badge(args.dump)))
        return
    for p in build():
        print(p.relative_to(ROOT))
    if args.sheet:
        contact_sheet(args.sheet)
        print(args.sheet)


if __name__ == '__main__':
    main()
