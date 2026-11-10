#!/usr/bin/env python3
"""Squad comms portraits: ComfyUI keyframes -> edits -> matte -> 96-grid frames -> atlases.

    PY=$SCRATCH/venv/bin/python   # pillow + numpy + scipy, outside the checkout
    $PY tools/comms_portraits.py keyframes   # GPU: SDXL + pixel-art-xl (+ IP-Adapter style ref)
    $PY tools/comms_portraits.py edits       # GPU: Qwen-Image-Edit-2511 shout / grunt frames
    $PY tools/comms_portraits.py matte       # GPU: BiRefNet alpha for every picked image
    $PY tools/comms_portraits.py ingest      # keep picked + matted sources (256 px RGBA) in art/comms/sources/
    $PY tools/comms_portraits.py finish      # CPU: sources -> 96-grid palette frames (8 per character)
    $PY tools/comms_portraits.py pack        # CPU: atlases + lib/comms/comms_portraits.dart
    $PY tools/comms_portraits.py sheet       # CPU: labelled review sheet art/contact/comms-portraits.png
    $PY tools/comms_portraits.py offline     # finish + pack + sheet from committed sources (no GPU)
    $PY tools/comms_portraits.py all         # everything

Inputs of record: art/comms/cast.json (looks, order), art/comms/portraits.json
(prompts, seeds, picks, face boxes) and art/comms/sources/*.png. Raw GPU
outputs go to $COMMS_PORTRAIT_CACHE (default ~/.cache/demon-attack/comms-portraits,
outside the repo). Every CPU stage is a pure function of the committed
sources: same inputs, same bytes.

Frames per atlas row (lib/comms/comms_types.dart CommsFrame):
0 idle, 1 blink, 2 talkA (slightly open), 3 talkB (half), 4 talkC (open),
5 talkD ('oo'), 6 shout, 7 grunt (demon roar / human alarm), 8 happy (demon
gloat), 9 worried (demon alarmed snarl), 10 tilt left, 11 tilt right,
12 talkWide, 13 talkEe (teeth).

Qwen-Image-Edit makes blink, shout, grunt, happy and worried from the picked
keyframe. Each edit is registered to the idle frame by an integer shift and
composited only inside the face box (eyes for blink), so the body never
jitters; talk frames are drawn on the idle lips (seam and corners measured
per character), anchored so the opening sits exactly on the mouth;
tilts shear the rows above the neck. Every frame then gets the combat
sprites' top-left rim light and a 1 px ink outline.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CAST = ROOT / 'art/comms/cast.json'
SPEC = ROOT / 'art/comms/portraits.json'
SRC = ROOT / 'art/comms/sources'
ATLAS = ROOT / 'assets/images/comms-portraits.png'
ATLAS_SMALL = ROOT / 'assets/images/comms-portraits-small.png'
DART = ROOT / 'lib/comms/comms_portraits.dart'
SHEET = ROOT / 'art/contact/comms-portraits.png'
CACHE = Path(os.environ.get('COMMS_PORTRAIT_CACHE', Path.home() / '.cache/demon-attack/comms-portraits'))
COMFY = os.environ.get('COMFYUI_URL', 'http://studio:8188')

sys.path.insert(0, str(ROOT / 'tools'))
from sprite_kit import PALETTE  # noqa: E402

# Portrait extension of the combat palette: skin, hair, uniform and backdrop
# ramps in the same muted-ink language (outline is always the combat ink).
PORTRAIT_EXTRA = {
    'skin0': '#4a2a26', 'skin1': '#7a4a3a', 'skin2': '#b27858', 'skin3': '#e3aa80', 'skin4': '#ffd2aa',
    'skin5': '#3a2420', 'skin6': '#5e3a2c', 'skin7': '#8a5a40', 'skin8': '#a86e4c', 'skin9': '#c48a64',
    'skinA': '#d89c74', 'skinB': '#f0c09a',
    'hair0': '#2a1e1e', 'hair1': '#5a3a2a', 'hair2': '#a8582e', 'hair3': '#d89a48', 'hair4': '#9aa0b0',
    'oliv0': '#2a3424', 'oliv1': '#46553a', 'oliv2': '#6e7f52', 'oliv3': '#a0ad78',
    'navy0': '#18203c', 'navy1': '#283a66', 'navy2': '#40609a',
    'grn0': '#1e5a3a', 'grn1': '#3ec46a', 'grn2': '#b4ff8a',
    'crim0': '#3a0f1e', 'crim1': '#6e1a2e', 'crim2': '#a8283e', 'crim3': '#e0405a',
    'bone0': '#8a7a62', 'bone1': '#c8b894', 'bone2': '#efe2c0',
}


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


PAL = {**PALETTE, **PORTRAIT_EXTRA}
PAL_NAMES = list(PAL)
PAL_RGB = np.array([hex_rgb(v) for v in PAL.values()], dtype=np.float64)
INK = np.array(hex_rgb(PALETTE['ink']), dtype=np.uint8)


def load(path, default=None):
    return json.loads(Path(path).read_text()) if Path(path).exists() else default


def cast_ids():
    return [c['id'] for c in load(CAST)['cast']]


def character(cid):
    return next(c for c in load(CAST)['cast'] if c['id'] == cid)


def kind(cid):
    return 'demon' if character(cid)['side'] == 'demon' else 'human'


# ---------------------------------------------------------------------------
# ComfyUI HTTP client (the same API studio.run_workflow drives).
# ---------------------------------------------------------------------------
def _upload(path: Path) -> str:
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{path.name}"\r\n'
            f'Content-Type: image/png\r\n\r\n').encode() + path.read_bytes() + \
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n--{boundary}--\r\n'.encode()
    req = urllib.request.Request(f'{COMFY}/upload/image', body,
                                 {'Content-Type': f'multipart/form-data; boundary={boundary}'})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())['name']


def run_workflow(workflow: Path, seed: int, prompt=None, negative=None, images: dict | None = None) -> list[bytes]:
    wf = json.loads(workflow.read_text())
    for node in wf.values():
        title = node.get('_meta', {}).get('title')
        inputs = node['inputs']
        if title == '$seed':
            inputs['seed'] = seed
        if title == '$prompt' and prompt is not None:
            inputs['text' if 'text' in inputs else 'prompt'] = prompt
        if title == '$negative_prompt' and negative is not None:
            inputs['text' if 'text' in inputs else 'prompt'] = negative
        if node['class_type'] == 'LoadImage' and str(inputs.get('image', '')).startswith('$'):
            inputs['image'] = _upload(images[inputs['image'][1:]])
    for node in wf.values():
        node.pop('_meta', None)
    req = urllib.request.Request(f'{COMFY}/prompt', json.dumps({'prompt': wf, 'client_id': 'comms-portraits'}).encode(),
                                 {'Content-Type': 'application/json'})
    pid = json.loads(urllib.request.urlopen(req, timeout=60).read())['prompt_id']
    for _ in range(3600):
        hist = json.loads(urllib.request.urlopen(f'{COMFY}/history/{pid}', timeout=60).read())
        if pid in hist:
            status = hist[pid].get('status', {})
            if status.get('status_str') == 'error':
                raise RuntimeError(json.dumps(status)[:2000])
            if hist[pid].get('outputs'):
                out = []
                for node_out in hist[pid]['outputs'].values():
                    for im in node_out.get('images', []):
                        q = urllib.parse.urlencode({k: im[k] for k in ('filename', 'subfolder', 'type')})
                        out.append(urllib.request.urlopen(f'{COMFY}/view?{q}', timeout=60).read())
                return out
        time.sleep(1)
    raise TimeoutError(f'ComfyUI prompt {pid} did not finish')


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def record(path: Path, **meta):
    """Provenance sidecar beside each raw output."""
    meta['sha256'] = sha(path.read_bytes())
    path.with_suffix('.json').write_text(json.dumps(meta, indent=1))


# ---------------------------------------------------------------------------
# GPU stages.
# ---------------------------------------------------------------------------
def prompt_for(cid):
    spec = load(SPEC)['keyframe']
    c = character(cid)
    extra = load(SPEC)['picks'].get(cid, {}).get('extra')
    return f"{spec['style']}, {spec[kind(cid)]}, {c['look']}" + (f', {extra}' if extra else '')


def picked_seed(cid):
    spec = load(SPEC)
    return spec['picks'].get(cid, {}).get('seed', spec['keyframe']['seeds'][cid])


def keyframe_path(cid, seed):
    return CACHE / 'keyframes' / f'{cid}-{seed}.png'


def keyframes(only=None):
    spec = load(SPEC)['keyframe']
    for cid in cast_ids():
        if only and cid not in only:
            continue
        pick = load(SPEC)['picks'].get(cid, {})
        first = pick.get('seed_base', spec['seeds'][cid])
        seeds = [first + i for i in range(pick.get('count', spec['count']))]
        style = pick.get('style_ref')
        for seed in seeds + ([pick['seed']] if pick.get('seed') and pick['seed'] not in seeds else []):
            out = keyframe_path(cid, seed)
            if out.exists():
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            if style:
                ref = keyframe_path(style, picked_seed(style))
                wf = ROOT / spec['style_workflow']
                png = run_workflow(wf, seed, prompt_for(cid), spec['negative'], {'style': ref})[0]
            else:
                wf = ROOT / spec['workflow']
                png = run_workflow(wf, seed, prompt_for(cid), spec['negative'])[0]
            out.write_bytes(png)
            record(out, workflow=str(wf.relative_to(ROOT)), seed=seed, prompt=prompt_for(cid),
                   negative=spec['negative'], style_ref=style, models=spec['models'])
            print('keyframe', out.name, flush=True)


def edit_path(cid, frame):
    return CACHE / 'edits' / f'{cid}-{picked_seed(cid)}-{frame}.png'


EDIT_FRAMES = ('blink', 'shout', 'grunt', 'happy', 'worried')


def base_path(cid):
    """The picked keyframe, or its `base_edit` (a Qwen edit that fixes age or
    colour while keeping the design) when portraits.json names one."""
    key = keyframe_path(cid, picked_seed(cid))
    if load(SPEC)['picks'].get(cid, {}).get('base_edit'):
        return key.with_name(f'{key.stem}-base.png')
    return key


def edits(only=None):
    spec = load(SPEC)['edit']
    for cid in cast_ids():
        if only and cid not in only:
            continue
        pick = load(SPEC)['picks'].get(cid, {})
        src = base_path(cid)
        if pick.get('base_edit') and not src.exists():
            key = keyframe_path(cid, picked_seed(cid))
            text = f"Keep exactly the same character design, pose, framing, pixel art style and flat grey background. {pick['base_edit']}"
            seed = pick.get('base_seed', spec['seed'] + 9)
            src.write_bytes(run_workflow(ROOT / spec['workflow'], seed, text, '', {'input': key})[0])
            record(src, workflow=spec['workflow'], seed=seed, prompt=text, source=key.name, models=spec['models'])
            print('base', src.name, flush=True)
        for n, frame in enumerate(EDIT_FRAMES):
            out = edit_path(cid, frame)
            if out.exists():
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            seed = pick.get(f'{frame}_seed', spec['seed'] + n)
            text = f"{spec['keep']} {pick.get(f'{frame}_prompt', spec['prompts'][kind(cid)][frame])}"
            png = run_workflow(ROOT / spec['workflow'], seed, text, '', {'input': src})[0]
            out.write_bytes(png)
            record(out, workflow=spec['workflow'], seed=seed, prompt=text, source=src.name, models=spec['models'])
            print('edit', out.name, flush=True)


def matte_path(image: Path):
    return CACHE / 'mattes' / image.name


def picked_images(cid):
    return [('key', base_path(cid))] + [(f, edit_path(cid, f)) for f in EDIT_FRAMES]


def matte(only=None):
    spec = load(SPEC)['matte']
    for cid in cast_ids():
        if only and cid not in only:
            continue
        for _, image in picked_images(cid):
            out = matte_path(image)
            if out.exists() or not image.exists():
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            png = run_workflow(ROOT / spec['workflow'], 0, images={'input': image})[0]
            out.write_bytes(png)
            print('matte', out.name, flush=True)


def head_crop(alpha: np.ndarray, pad=0.03, keep=0.8):
    """Square head-and-shoulders crop (full-res pixels) from the keyframe alpha."""
    a = alpha > 128
    ys, xs = np.nonzero(a)
    top, bottom = int(ys.min()), int(ys.max()) + 1
    head = a[top:top + max(8, (bottom - top) // 3)]
    hx = np.nonzero(head.any(0))[0]
    cx = int((hx.min() + hx.max()) / 2)
    n = alpha.shape[0]
    side = min(n, int((bottom - top) * keep))
    y0 = int(np.clip(top - (bottom - top) * pad, 0, n - side))
    x0 = int(np.clip(cx - side // 2, 0, alpha.shape[1] - side))
    return (x0, y0, x0 + side, y0 + side)


def ingest(only=None):
    """Keep each picked image with its alpha, cropped to the head box of the
    keyframe and stored at 2x the logical grid (adaptive 160-colour PNG)."""
    SRC.mkdir(parents=True, exist_ok=True)
    size = 2 * load(SPEC)['grid']
    for cid in cast_ids():
        if only and cid not in only:
            continue
        key = base_path(cid)
        crop = load(SPEC)['picks'].get(cid, {}).get('crop') or \
            head_crop(np.array(Image.open(matte_path(key)).convert('L')),
                      keep=load(SPEC)['picks'].get(cid, {}).get('keep', 0.8))
        for name, image in picked_images(cid):
            if not image.exists():
                continue
            rgb = Image.open(image).convert('RGB')
            alpha = Image.open(matte_path(image)).convert('L').resize(rgb.size, Image.BILINEAR) \
                if matte_path(image).exists() else Image.new('L', rgb.size, 255)
            rgba = rgb.copy()
            rgba.putalpha(alpha)
            rgba = rgba.crop(tuple(crop)).resize((size, size), Image.BOX)
            rgba.quantize(160, method=Image.Quantize.FASTOCTREE).save(SRC / f'{cid}-{name}.png', optimize=True)
            print('source', f'{cid}-{name}.png', crop)
    record_runs()


def record_runs():
    """Provenance of every ingested image (from the raw-output sidecars):
    art/comms/portrait-runs.json."""
    path = ROOT / 'art/comms/portrait-runs.json'
    runs = load(path, {})
    for cid in cast_ids():
        entry = {}
        key = keyframe_path(cid, picked_seed(cid))
        chain = [('keyframe', key)]
        if base_path(cid) != key:
            chain.append(('base', base_path(cid)))
        chain += [(f, edit_path(cid, f)) for f in EDIT_FRAMES]
        for name, image in chain:
            side = image.with_suffix('.json')
            if side.exists():
                meta = json.loads(side.read_text())
                entry[name] = {k: meta.get(k) for k in ('workflow', 'seed', 'prompt', 'source', 'sha256')}
        if entry:
            entry['matte'] = load(SPEC)['matte']['workflow']
            runs[cid] = entry
    path.write_text(json.dumps(runs, indent=1) + '\n')


# ---------------------------------------------------------------------------
# CPU stages: deterministic from art/comms/sources/.
# ---------------------------------------------------------------------------
def snap(rgb: np.ndarray) -> np.ndarray:
    """Nearest palette colour, luminance-weighted distance."""
    flat = rgb.reshape(-1, 3).astype(np.float64)
    w = np.array([0.30, 0.59, 0.11]) * 3
    d = (((flat[:, None, :] - PAL_RGB[None, :, :]) ** 2) * w).sum(-1)
    return PAL_RGB[d.argmin(1)].reshape(rgb.shape).astype(np.uint8)


def shift(img, dx, dy):
    out = np.zeros_like(img)
    h, w = img.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = img[ys, xs]
    return out


def diff(a, b):
    both = (a[..., 3] > 0) | (b[..., 3] > 0)
    d = np.abs(a.astype(int) - b.astype(int)).sum(-1) > 90
    return d & both


def dilate(mask, n=1):
    m = mask.copy()
    for _ in range(n):
        g = m.copy()
        g[1:] |= m[:-1]
        g[:-1] |= m[1:]
        g[:, 1:] |= m[:, :-1]
        g[:, :-1] |= m[:, 1:]
        m = g
    return m


def largest_box(mask):
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return None
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]


def lum(img):
    return img[..., :3].astype(np.float64) @ np.array([.3, .59, .11])


def component_near(mask, x, y):
    """Bounding box of the connected component of mask closest to (x, y)."""
    from scipy import ndimage
    lab, n = ndimage.label(mask)
    if n == 0:
        return None
    best, best_d = None, None
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if len(ys) < 3:
            continue
        d = np.min((xs - x) ** 2 + (ys - y) ** 2)
        if best_d is None or d < best_d:
            best, best_d = i, d
    return largest_box(lab == best) if best else None


def face_boxes(cid, idle, blink, shout, grid):
    """Eye box from the blink edit's difference and mouth box from the dark
    opening of the shout edit, both searched near the centre column (the
    crop is centred on the head); portraits.json picks may override either.
    Boxes are in logical px of a 128 grid in portraits.json."""
    pick = load(SPEC)['picks'].get(cid, {})
    scale = grid / 128
    cx = grid // 2
    eyes = pick.get('eyes')
    mouth = pick.get('mouth')
    if eyes:
        eyes = [round(v * scale) for v in eyes]
    else:
        m = diff(idle, blink)
        m[int(grid * .70):] = False
        m[: int(grid * .15)] = False
        m[:, : cx - int(grid * .30)] = False
        m[:, cx + int(grid * .30):] = False
        rows = m.sum(1)
        if rows.max() == 0:
            eyes = [cx - grid * 22 // 128, grid * 48 // 128, cx + grid * 22 // 128, grid * 58 // 128]
        else:
            peak = int(rows.argmax())
            band = m.copy()
            band[: max(0, peak - grid // 16)] = False
            band[peak + grid // 16:] = False
            eyes = largest_box(band)
    if mouth:
        mouth = [round(v * scale) for v in mouth]
    else:
        region = np.zeros(idle.shape[:2], bool)
        top = eyes[3] + grid // 32
        region[top: eyes[3] + int(grid * .36), cx - int(grid * .2): cx + int(grid * .2)] = True
        opening = diff(idle, shout) & (lum(shout) < lum(idle) - 30) & region
        box = component_near(opening, cx, eyes[3] + grid // 5)
        if box is None or (box[3] - box[1]) < 2:
            box = [cx - grid // 14, eyes[3] + grid // 8, cx + grid // 14, eyes[3] + grid // 5]
        # Lips and teeth around the opening.
        pad = max(1, grid // 64)
        mouth = [box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad]
    clamp = lambda b: [int(np.clip(v, 0, grid)) for v in b]  # noqa: E731
    return clamp(mouth), clamp(eyes)


def tilt(img, pivot_y, degrees):
    """Lean the head by shearing every row above the neck pivot; rows keep
    their pixel clusters intact (no rotation resampling)."""
    t = np.tan(np.radians(degrees))
    out = img.copy()
    for y in range(pivot_y):
        dx = int(round((pivot_y - y) * t))
        if dx:
            row = np.zeros_like(img[y])
            if dx > 0:
                row[dx:] = img[y, :-dx]
            else:
                row[:dx] = img[y, -dx:]
            out[y] = row
    return out


def rim(frame):
    """Top-left rim light (the combat sprites' rule): silhouette pixels whose
    upper or left neighbour is empty step toward ivory, snapped."""
    a = frame[..., 3] > 0
    edge = np.zeros_like(a)
    edge[1:] |= a[1:] & ~a[:-1]
    edge[:, 1:] |= a[:, 1:] & ~a[:, :-1]
    edge[0] |= a[0]
    edge[:, 0] |= a[:, 0]
    out = frame.copy()
    if edge.any():
        ivory = np.array(hex_rgb(PALETTE['ivory']), np.float64)
        lit = frame[edge, :3].astype(np.float64) * 0.6 + ivory * 0.4
        out[edge, :3] = snap(lit[None])[0]
    return out


def outline(frame: np.ndarray) -> np.ndarray:
    """1 px ink outline outside the silhouette."""
    a = frame[..., 3] > 0
    ring = dilate(a, 1) & ~a
    out = frame.copy()
    out[ring, :3] = INK
    out[ring, 3] = 255
    return out


def finish_frame(frame):
    return outline(rim(frame))


def raw(cid, name, grid):
    """Source (head-cropped at 2x) -> logical grid as unsnapped float RGB and
    binary alpha, after the character's optional `tone` (gamma, contrast)."""
    src = Image.open(SRC / f'{cid}-{name}.png').convert('RGBA').resize((grid, grid), Image.BOX)
    arr = np.array(src).astype(np.float64)
    rgb, alpha = arr[..., :3], arr[..., 3] > 110
    # Fill small enclosed matte holes (BiRefNet misses); keep real gaps.
    from scipy import ndimage
    lab, n = ndimage.label(ndimage.binary_fill_holes(alpha) & ~alpha)
    fill = np.zeros_like(alpha)
    for i in range(1, n + 1):
        hole = lab == i
        if hole.sum() <= grid * grid // 400:
            fill |= hole
    if fill.any():
        _, (iy, ix) = ndimage.distance_transform_edt(~alpha, return_indices=True)
        rgb = rgb.copy()
        rgb[fill] = rgb[iy[fill], ix[fill]]      # nearest opaque colour
        alpha = alpha | fill
    tone =load(SPEC)['picks'].get(cid, {}).get('tone')
    if tone:
        rgb = 255 * (rgb / 255) ** tone.get('gamma', 1.0)
        mid = tone.get('mid', 110.0)
        rgb = np.clip(mid + (rgb - mid) * tone.get('contrast', 1.0), 0, 255)
    return rgb, alpha


def to_rgba(rgb, alpha):
    """Snap a whole frame once: the palette lookup is per pixel and
    deterministic, so a pixel whose RGB is unchanged keeps its exact colour."""
    out = np.zeros(rgb.shape[:2] + (4,), np.uint8)
    out[alpha, :3] = snap(rgb)[alpha]
    out[alpha, 3] = 255
    return out


def best_shift(idle, edit, r=4):
    """Integer shift of a snapped edit that best matches the snapped idle."""
    best = (None, 0, 0)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            score = diff(idle, shift(edit, dx, dy)).sum()
            if best[0] is None or score < best[0]:
                best = (score, dx, dy)
    return best[1], best[2]


def shift_raw(rgb, alpha, dx, dy):
    a4 = np.concatenate([rgb, alpha[..., None].astype(np.float64)], -1)
    s = shift(a4, dx, dy)
    return s[..., :3], s[..., 3] > .5


def feather(shape, box, ramp):
    """Weight 1 deep inside the box, falling linearly to 0 at its edge over
    `ramp` px; exactly 0 outside the box."""
    h, w = shape
    x0, y0, x1, y1 = box
    ys, xs = np.mgrid[0:h, 0:w] + .5
    d = np.minimum(np.minimum(xs - x0, x1 - xs), np.minimum(ys - y0, y1 - ys))
    return np.clip(d / max(ramp, 1e-6), 0, 1)


def blend(base_rgb, top_rgb, weight):
    w = weight[..., None]
    out = base_rgb * (1 - w) + top_rgb * w
    # Exactly the base where the weight is 0, so those pixels snap identically.
    out[weight <= 0] = base_rgb[weight <= 0]
    return out


def talk_layer(idle_rgb, shout_rgb, box, amount, width=1.0, ramp=1.5):
    """The shout mouth squashed about the centre of the mouth box to
    `amount` of its height (and `width` of its width), as an RGB layer and a
    weight map: 1 inside the squashed band, ramping to 0 at its edges and at
    the box edge; 0 outside the box."""
    x0, y0, x1, y1 = box
    h, w = y1 - y0, x1 - x0
    cy, cx = y0 + h / 2, x0 + w / 2
    layer = idle_rgb.copy()
    weight = np.zeros(idle_rgb.shape[:2])
    half_h, half_w = max(.5, h * amount / 2), max(.5, w * width / 2)
    for y in range(y0, y1):
        t = (y + .5 - cy) / half_h
        if abs(t) > 1:
            continue
        sy = int(np.clip(cy + t * h / 2, y0, y1 - 1))
        wy = np.clip((1 - abs(t)) * half_h / ramp, 0, 1)
        for x in range(x0, x1):
            u = (x + .5 - cx) / half_w
            if abs(u) > 1:
                continue
            sx = int(np.clip(cx + u * w / 2, x0, x1 - 1))
            wx = np.clip((1 - abs(u)) * half_w / ramp, 0, 1)
            layer[y, x] = shout_rgb[sy, sx]
            weight[y, x] = wy * wx
    return layer, weight * feather(weight.shape, box, ramp)


# --------------------------------------------------------------- talk mouths
# v4: the talk frames are drawn, not squashed from the shout edit. Each
# character's idle lips are measured once (the seam between the lips and the
# two corners; `picks.<id>.lips` = [left, seam, right] overrides), and every
# talk shape is drawn anchored on them: the upper lip lifts a little, the jaw
# drops the rest, so the opening always sits exactly on the portrait's own
# mouth. Colours come from the character's own pixels (lips and skin from
# idle, mouth interior, tongue and teeth from the shout edit).

# Talk shapes in CommsFrame order: (frame, name, height and width relative
# to the lip width, share of the opening above the seam, profile exponent
# (0.5 = ellipse, lower = flatter), upper teeth, lower teeth, tongue).
TALK_SHAPES = [
    (2, 'slight', .07, .80, .35, .60, False, False, False),
    (3, 'half', .15, .86, .30, .55, True, False, False),
    (4, 'open', .25, .90, .27, .50, True, False, True),
    (12, 'wide', .36, .96, .25, .45, True, True, True),
    (5, 'oo', .26, .46, .32, .50, False, False, False),
    (13, 'ee', .13, 1.0, .40, .30, True, True, False),
]
TALK_FRAMES = [s[0] for s in TALK_SHAPES]


def dark_line_rows(L, x0, x1, y0, y1):
    """Per row: how much darker the row is than the rows two above and two
    below it, over columns x0..x1 (a horizontal lip seam scores high)."""
    rows = {}
    for y in range(max(2, y0), min(L.shape[0] - 2, y1)):
        seg = L[y, x0:x1]
        around = (L[y - 2, x0:x1] + L[y + 2, x0:x1]) / 2
        rows[y] = float(np.mean(np.clip(around - seg, 0, None)))
    return rows


def lip_geometry(cid, idle_rgb, alpha, shout_rgb, mouth_box, eyes, grid):
    """Seam row, corners and colours of the idle mouth (logical grid)."""
    pick = load(SPEC)['picks'].get(cid, {})
    scale = grid / 128
    L = idle_rgb @ np.array([.3, .59, .11])
    bx0, by0, bx1, by1 = mouth_box
    cx = (bx0 + bx1) // 2
    if pick.get('lips'):
        left, seam, right = [int(round(v * scale)) for v in pick['lips']]
    else:
        half = max(3, (bx1 - bx0) // 3)
        lo = eyes[3] + max(2, grid // 20)
        hi = min(grid - 3, (by0 + by1) // 2 + 1)
        rows = dark_line_rows(L, cx - half, cx + half, lo, hi)
        seam = max(rows, key=rows.get) if rows else (by0 + by1) // 2
        # Corners: walk out from the centre along the seam while the row is
        # darker than its neighbours above and below.
        def dark(x):
            return (L[seam - 2, x] + L[seam + 2, x]) / 2 - min(L[seam, x], L[seam - 1, x], L[seam + 1, x]) > 10
        left = right = cx
        misses = 0
        while left > bx0 - grid // 16 and misses < 2:
            left -= 1
            misses = 0 if dark(left) else misses + 1
        left += misses
        misses = 0
        while right < bx1 + grid // 16 and misses < 2:
            right += 1
            misses = 0 if dark(right) else misses + 1
        right -= misses
        if right - left < grid // 8:
            left, right = cx - grid // 10, cx + grid // 10
        # Smile lines and stubble can extend the dark seam: the mouth is at
        # most a little wider than the shout edit's opening.
        cap = int(round((bx1 - bx0) * 1.05))
        if right - left + 1 > cap:
            mid = (left + right) / 2
            left, right = int(round(mid - cap / 2)), int(round(mid + cap / 2)) - 1
    width = right - left + 1
    cx = (left + right + 1) / 2
    ut = max(1, int(round(width * .08)))
    lt = max(2, int(round(width * .11)))

    def median(img, mask):
        pts = img[mask & alpha]
        return np.median(pts, 0) if len(pts) else None

    ys, xs = np.mgrid[0:grid, 0:grid]
    band = (np.abs(xs + .5 - cx) < width * .3)
    lip = median(idle_rgb, band & (ys > seam) & (ys <= seam + lt))
    lip_up = median(idle_rgb, band & (ys < seam) & (ys >= seam - ut))
    skin = median(idle_rgb, band & (ys > seam + lt + 1) & (ys <= seam + lt + 4))
    box = (xs >= bx0) & (xs < bx1) & (ys >= by0) & (ys < by1) & alpha
    sh = shout_rgb[box]
    sl = sh @ np.array([.3, .59, .11])
    dark = np.median(sh[sl <= np.percentile(sl, 20)], 0) if len(sh) else np.array([40, 16, 24.])
    sat = sh.max(1) - sh.min(1)
    teeth_pts = sh[(sl >= np.percentile(sl, 88)) & (sat < 70)] if len(sh) else []
    teeth = np.median(teeth_pts, 0) if len(teeth_pts) else np.array([236, 228, 214.])
    pink = sh[(sh[:, 0] > sh[:, 1] + 40) & (sh[:, 0] > sh[:, 2] + 20) & (sl > 70) & (sl < 170)] if len(sh) else []
    tongue = np.median(pink, 0) if len(pink) > 3 else np.array([200, 80, 96.])
    if kind(cid) == 'demon':
        dark = np.minimum(dark, np.array([70, 20, 34.]))
    fallback = np.median(idle_rgb[band & (ys >= seam - 4) & (ys <= seam + 4) & alpha], 0)
    return {
        'cx': cx, 'seam': seam, 'left': left, 'right': right, 'width': width, 'ut': ut, 'lt': lt,
        'lip': lip if lip is not None else fallback, 'lip_up': lip_up if lip_up is not None else fallback,
        'skin': skin if skin is not None else fallback, 'dark': dark, 'teeth': teeth, 'tongue': tongue,
    }


def draw_mouth(idle_rgb, alpha, geo, shape, demon):
    """One talk shape drawn on a copy of the idle RGB; returns (rgb, mask of
    changed pixels). Everything outside the mask is idle's exact RGB."""
    _f, name, hf, wf, lift, p, top_teeth, low_teeth, tongue = shape
    grid = idle_rgb.shape[0]
    out = idle_rgb.copy()
    mask = np.zeros(alpha.shape, bool)
    w = geo['width']
    h = max(2.0 if name != 'slight' else 1.4, hf * w)
    hw = max(2.0, wf * w / 2)
    cx, seam = geo['cx'], geo['seam'] + .5
    ut = geo['ut'] + (1 if name == 'oo' else 0)
    lt = geo['lt'] + (1 if name == 'oo' else 0)

    def put(x, y, colour):
        if 0 <= x < grid and 0 <= y < grid and alpha[y, x]:
            out[y, x] = colour
            mask[y, x] = True

    if name == 'oo':
        # Pursed lips: the idle seam beyond the rounded opening closes up
        # into lip colour, so the mouth reads narrower.
        for x in range(geo['left'], geo['right'] + 1):
            if abs(x + .5 - cx) >= hw - .5:
                for y in range(geo['seam'] - 1, geo['seam'] + 2):
                    put(x, y, geo['lip'] if y > geo['seam'] - 1 else geo['lip_up'])
    for x in range(int(np.floor(cx - hw - 1)), int(np.ceil(cx + hw + 1))):
        u = (x + .5 - cx) / hw
        if abs(u) >= 1:
            continue
        prof = (1 - u * u) ** p
        top = seam - lift * h * prof
        bot = seam + (1 - lift) * h * prof
        open_px = [y for y in range(grid) if top <= y + .5 < bot]
        if not open_px:
            # The very corners: a 1 px crease on the seam.
            put(x, geo['seam'], geo['dark'] * .8 + geo['lip'] * .2)
            continue
        y_top, y_bot = open_px[0], open_px[-1]
        span = y_bot - y_top + 1
        for y in open_px:
            colour = geo['dark']
            k = y - y_top
            if tongue and span >= 4 and y_bot - y < max(1, round(span * .38)) and abs(u) < .72:
                colour = geo['tongue']
            if top_teeth and span >= 3 and k < max(1, round(span * .22)) and abs(u) < (.8 if not demon else .9):
                colour = geo['teeth']
            if low_teeth and span >= 4 and y_bot - y < max(1, round(span * .18)) and abs(u) < .7:
                colour = geo['teeth']
            if demon and top_teeth and span >= 4 and abs(abs(u) - .55) < .12 and k < span * .55:
                colour = geo['teeth']          # upper fangs
            if demon and low_teeth and span >= 5 and abs(abs(u) - .3) < .1 and y_bot - y < span * .45:
                colour = geo['teeth']          # lower fangs
            put(x, y, colour)
        # The character's own lips move apart: the idle upper lip rows slide
        # up above the opening and the lower lip rows (with the chin shading
        # right under them) slide down below it, so the lips keep their
        # pixel shading; a flat lip colour only where the shape needs more.
        s0 = geo['seam']
        for k in range(ut + 1):
            y_src, y_dst = s0 - 1 - k, y_top - 1 - k
            if y_dst < y_src and 0 <= y_src < grid:
                put(x, y_dst, idle_rgb[y_src, x] if name != 'oo' else geo['lip_up'])
        drop = y_bot - s0
        for k in range(lt + 2):
            y_src, y_dst = s0 + 1 + k, y_bot + 1 + k
            if drop > 0 and 0 <= y_src < grid and 0 <= y_dst < grid:
                put(x, y_dst, idle_rgb[y_src, x] if name != 'oo' or k >= lt else geo['lip'])
        edge = lt + 2
        if name in ('open', 'wide') and abs(u) < .8:
            # The dropped jaw's soft shadow under the lower lip.
            y = y_bot + 1 + edge
            if 0 <= y < grid and alpha[y, x]:
                put(x, y, idle_rgb[y, x] * .82)
    return out, mask


def talk_frames(cid, idle_rgb, alpha, shout_rgb, mouth_box, eyes, grid):
    """All talk shapes of a character: {frame: rgb}, the box holding every
    changed pixel, and the lip geometry."""
    geo = lip_geometry(cid, idle_rgb, alpha, shout_rgb, mouth_box, eyes, grid)
    demon = kind(cid) == 'demon'
    frames, union = {}, np.zeros(alpha.shape, bool)
    for shape in TALK_SHAPES:
        rgb, mask = draw_mouth(idle_rgb, alpha, geo, shape, demon)
        frames[shape[0]] = rgb
        union |= mask
    box = largest_box(union) or list(mouth_box)
    return frames, box, geo


def boxes_for(cid, grid):
    """Snapped idle + registered raw edits, and the fixed eye, mouth and face
    boxes shared by every frame of the character."""
    idle_rgb, alpha = raw(cid, 'key', grid)
    idle = to_rgba(idle_rgb, alpha)
    edits = {}
    for name in EDIT_FRAMES:
        if not (SRC / f'{cid}-{name}.png').exists():
            edits[name] = (idle_rgb, alpha)
            continue
        rgb, a = raw(cid, name, grid)
        dx, dy = best_shift(idle, to_rgba(rgb, a))
        edits[name] = shift_raw(rgb, a, dx, dy)
    snapped = {k: to_rgba(*v) for k, v in edits.items()}
    mouth, eyes = face_boxes(cid, idle, snapped['blink'], snapped['shout'], grid)
    pad = grid // 16
    face = [min(eyes[0], mouth[0]) - pad, eyes[1] - pad * 2, max(eyes[2], mouth[2]) + pad, mouth[3] + pad]
    face = [int(np.clip(v, 0, grid)) for v in face]
    return idle_rgb, alpha, edits, mouth, eyes, face


def frames_for(cid, grid=None):
    """The twelve frames of one character, in CommsFrame order.

    Frames 0 and 2-6 differ only inside the fixed face box and frame 1 only
    inside the eye box: every composite is blended in RGB with a weight that
    is exactly 0 outside its box, then the whole frame is snapped once and
    keeps the idle alpha, so rim light and outline are identical outside."""
    grid = grid or load(SPEC)['grid']
    idle_rgb, alpha, ed, mouth, eyes, face = boxes_for(cid, grid)
    shape = idle_rgb.shape[:2]
    wf = feather(shape, face, max(2, grid // 32))
    eye_box = [eyes[0] - 2, eyes[1] - 2, eyes[2] + 2, eyes[3] + 2]
    frames = [to_rgba(idle_rgb, alpha),
              to_rgba(blend(idle_rgb, ed['blink'][0], feather(shape, eye_box, 2)), alpha)]
    shout_rgb = blend(idle_rgb, ed['shout'][0], wf)
    talk, talk_box, geo = talk_frames(cid, idle_rgb, alpha, ed['shout'][0], mouth, eyes, grid)
    for f in (2, 3, 4, 5):
        frames.append(to_rgba(talk[f], alpha))
    frames.append(to_rgba(shout_rgb, alpha))
    if kind(cid) == 'human':
        frames.append(to_rgba(blend(idle_rgb, ed['grunt'][0], wf), alpha))
    else:
        frames.append(to_rgba(*ed['grunt']))          # the roar may move the whole head
    for name in ('happy', 'worried'):
        frames.append(to_rgba(blend(idle_rgb, ed[name][0], wf), alpha))
    pivot = min(grid - 1, mouth[3] + (mouth[3] - eyes[1]) // 2)
    deg = load(SPEC).get('tilt_degrees', 4)
    frames += [tilt(frames[0], pivot, -deg), tilt(frames[0], pivot, deg)]
    frames += [to_rgba(talk[12], alpha), to_rgba(talk[13], alpha)]
    lips = {'left': int(geo['left']), 'seam': int(geo['seam']), 'right': int(geo['right'])}
    face = [min(face[0], talk_box[0]), min(face[1], talk_box[1]), max(face[2], talk_box[2]), max(face[3], talk_box[3])]
    return [finish_frame(f) for f in frames], talk_box, eyes, face, lips


def small_box(box, g, s):
    """A big-grid box mapped onto the small grid, grown by the BOX filter's
    footprint, so small pixels outside it only see unchanged big pixels."""
    k = g / s
    return [max(0, int(np.floor(box[0] / k)) - 1), max(0, int(np.floor(box[1] / k)) - 1),
            min(s, int(np.ceil(box[2] / k)) + 1), min(s, int(np.ceil(box[3] / k)) + 1)]


def outside_equal(a, b, box):
    m = np.ones(a.shape[:2], bool)
    x0, y0, x1, y1 = box
    m[y0:y1, x0:x1] = False
    return bool((a[m] == b[m]).all())


def check(atlas=None, small=None):
    """For every character: the talk frames (2-5, 12, 13) equal frame 0
    outside the mouth box, the shout outside the face box and the blink
    outside the eye box, in both atlases."""
    spec = load(SPEC)
    g, s = spec['grid'], spec['small']
    big = np.array(Image.open(ATLAS)) if atlas is None else atlas
    sm = np.array(Image.open(ATLAS_SMALL)) if small is None else small
    faces = load(ROOT / 'art/comms/portrait-faces.json', {})
    failures = []
    for row, cid in enumerate(cast_ids()):
        if cid not in faces:
            failures.append(f'{cid}: no faces entry')
            continue
        face, eyes, mouth = faces[cid]['face'], faces[cid]['eyes'], faces[cid]['mouth']
        eye_box = [eyes[0] - 2, eyes[1] - 2, eyes[2] + 2, eyes[3] + 2]
        for atlas_px, cell, scale in ((big, g, False), (sm, s, True)):
            cells = [atlas_px[row * cell:(row + 1) * cell, c * cell:(c + 1) * cell] for c in range(len(spec['frames']))]
            fb = small_box(face, g, s) if scale else face
            eb = small_box(eye_box, g, s) if scale else eye_box
            mb = small_box(mouth, g, s) if scale else mouth
            label = f'{cid} {cell}px'
            if not outside_equal(cells[0], cells[6], fb):
                failures.append(f'{label} shout differs outside the face box')
            for c in TALK_FRAMES:
                if not outside_equal(cells[0], cells[c], mb):
                    failures.append(f'{label} talk frame {c} differs outside the mouth box')
            if not outside_equal(cells[0], cells[1], eb):
                failures.append(f'{label} blink differs outside the eye box')
    print('outside-box identity:', 'OK for', len(cast_ids()), 'characters x 2 atlases' if not failures else f'{len(failures)} failures')
    for f in failures:
        print('  ', f)
    return not failures


def finish():
    """Print the derived face boxes (logical 128 grid) for review."""
    for cid in cast_ids():
        if not (SRC / f'{cid}-key.png').exists():
            continue
        _, mouth, eyes, face, lips = frames_for(cid)
        print(cid, 'mouth', mouth, 'lips', lips, 'eyes', eyes, 'face', face)


def pack():
    ids = cast_ids()
    spec = load(SPEC)
    g, s, n = spec['grid'], spec['small'], len(spec['frames'])
    big = np.zeros((g * len(ids), g * n, 4), np.uint8)
    small = np.zeros((s * len(ids), s * n, 4), np.uint8)
    meta = {}
    for row, cid in enumerate(ids):
        if not (SRC / f'{cid}-key.png').exists():
            print('missing sources for', cid)
            continue
        frames, mouth, eyes, face, lips = frames_for(cid, g)
        meta[cid] = {'mouth': mouth, 'lips': lips, 'eyes': eyes, 'face': face}
        for col, f in enumerate(frames):
            big[row * g:(row + 1) * g, col * g:(col + 1) * g] = f
            small[row * s:(row + 1) * s, col * s:(col + 1) * s] = small_frame(f, s)
    for arr, path in ((big, ATLAS), (small, ATLAS_SMALL)):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(arr, 'RGBA').save(path, optimize=True)
        print('atlas', path.relative_to(ROOT), arr.shape[1], 'x', arr.shape[0], path.stat().st_size, 'bytes')
    (ROOT / 'art/comms/portrait-faces.json').write_text(json.dumps(meta, indent=1) + '\n')
    rows = '\n'.join(f"  '{cid}': {i}," for i, cid in enumerate(ids))
    DART.write_text(f"""// GENERATED by tools/comms_portraits.py pack. Do not edit.

/// Large atlas: one row per character, CommsFrame.count cells of [commsPortraitCell] px.
const commsPortraitImage = 'assets/images/comms-portraits.png';

/// Half-size atlas for the phone overlay, cells of [commsPortraitSmallCell] px.
const commsPortraitSmallImage = 'assets/images/comms-portraits-small.png';
const commsPortraitCell = {g};
const commsPortraitSmallCell = {s};
const commsPortraitRows = <String, int>{{
{rows}
}};
""" + pack_backdrops())


def small_frame(frame, grid):
    """Area-downsample a finished frame, then snap back to the palette."""
    arr = frame.astype(np.float64)
    a = arr[..., 3:4] / 255
    pre = np.concatenate([arr[..., :3] * a, arr[..., 3:4]], -1).round().astype(np.uint8)
    small = np.array(Image.fromarray(pre, 'RGBA').resize((grid, grid), Image.BOX)).astype(np.float64)
    alpha = small[..., 3] > 120
    rgb = small[..., :3] / np.maximum(small[..., 3:4] / 255, 1e-6)
    out = np.zeros((grid, grid, 4), np.uint8)
    out[alpha, :3] = snap(np.clip(rgb, 0, 255))[alpha]
    out[alpha, 3] = 255
    return out


def sheet(zoom=2):
    """Labelled review sheet: every frame at 2x, plus the small idle at 1x."""
    ids = cast_ids()
    spec = load(SPEC)
    big = Image.open(ATLAS)
    small = Image.open(ATLAS_SMALL)
    g, s, z, n = spec['grid'], spec['small'], zoom, len(spec['frames'])
    label_w = 120
    bd = Image.open(BACKDROPS) if BACKDROPS.exists() else None
    bspec = bd_spec()
    bw, bh = bspec['size']
    index = {v['id']: i for i, v in enumerate(bspec['variants'])}
    w = label_w + (n + 1) * (g * z + 4) + 2 * (s + 6)
    h = 20 + len(ids) * (g * z + 6)
    img = Image.new('RGBA', (w, h), (16, 14, 44, 255))
    draw = ImageDraw.Draw(img)
    for c, name in enumerate(spec['frames']):
        draw.text((label_w + c * (g * z + 4) + 4, 4), name, fill=(160, 200, 220, 255))
    draw.text((label_w + n * (g * z + 4) + 4, 4), 'on backdrop', fill=(160, 200, 220, 255))
    draw.text((label_w + (n + 1) * (g * z + 4) + 2, 4), f'{s}px', fill=(160, 200, 220, 255))
    for r, cid in enumerate(ids):
        c = character(cid)
        y = 20 + r * (g * z + 6)
        draw.text((4, y + 4), c['name'], fill=(240, 240, 200, 255))
        draw.text((4, y + 18), c['rank'], fill=(140, 180, 200, 255))
        draw.text((4, y + 32), cid, fill=(120, 120, 160, 255))
        for col in range(n):
            cell = big.crop((col * g, r * g, (col + 1) * g, (r + 1) * g)).resize((g * z, g * z), Image.NEAREST)
            x = label_w + col * (g * z + 4)
            img.paste((30, 40, 64, 255), (x, y, x + g * z, y + g * z))
            img.alpha_composite(cell, (x, y))
        if bd is not None:
            i = index[bspec['assign'][cid]]
            br, bc = divmod(i, bspec['columns'])
            ox, oy = bc * bw + (bw - g) // 2, br * bh + (bh - g) // 2
            tile = bd.crop((ox, oy, ox + g, oy + g)).convert('RGBA')
            tile.alpha_composite(big.crop((0, r * g, g, (r + 1) * g)))
            x = label_w + n * (g * z + 4)
            img.alpha_composite(tile.resize((g * z, g * z), Image.NEAREST), (x, y))
        for k, col in enumerate((0, 7)):
            cell = small.crop((col * s, r * s, (col + 1) * s, (r + 1) * s))
            x = label_w + (n + 1) * (g * z + 4) + 4 + k * (s + 4)
            img.paste((30, 40, 64, 255), (x, y, x + s, y + s))
            img.alpha_composite(cell, (x, y))
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    img.convert('RGB').save(SHEET, optimize=True)
    print('sheet', SHEET.relative_to(ROOT))


def candidates(cid_list=None):
    """Review sheet of raw keyframe candidates (to choose picks)."""
    spec = load(SPEC)['keyframe']
    ids = cid_list or cast_ids()
    tiles = []
    for cid in ids:
        row = sorted((CACHE / 'keyframes').glob(f'{cid}-*.png'))
        tiles.append((cid, row))
    n = max(len(r) for _, r in tiles)
    t = 256
    img = Image.new('RGB', (n * (t + 4) + 80, len(tiles) * (t + 4)), (20, 20, 30))
    d = ImageDraw.Draw(img)
    for y, (cid, row) in enumerate(tiles):
        d.text((4, y * (t + 4) + 4), cid, fill=(255, 255, 255))
        for x, p in enumerate(row):
            img.paste(Image.open(p).convert('RGB').resize((t, t), Image.BOX), (80 + x * (t + 4), y * (t + 4)))
            d.text((84 + x * (t + 4), y * (t + 4) + 4), p.stem.split('-')[-1], fill=(255, 255, 0))
    out = CACHE / 'candidates.png'
    img.save(out)
    print(out)


# ---------------------------------------------------------------------------
# Backdrops: dim interiors drawn behind each portrait.
# ---------------------------------------------------------------------------
BACKDROPS = ROOT / 'assets/images/comms-backdrops.png'


def bd_spec():
    return load(SPEC)['backdrops']


def bd_path(vid, seed):
    return CACHE / 'backdrops' / f'{vid}-{seed}.png'


def bd_seed(variant):
    return bd_spec()['picks'].get(variant['id'], variant['seed'])


def backdrops(only=None):
    """GPU: `count` candidates per backdrop variant."""
    spec = bd_spec()
    for v in spec['variants']:
        if only and v['id'] not in only:
            continue
        prompt = f"{spec['style']}, {v['prompt']}"
        for seed in [v['seed'] + i for i in range(spec['count'])]:
            out = bd_path(v['id'], seed)
            if out.exists():
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(run_workflow(ROOT / spec['workflow'], seed, prompt, spec['negative'])[0])
            record(out, workflow=spec['workflow'], seed=seed, prompt=prompt, negative=spec['negative'],
                   models=load(SPEC)['keyframe']['models'])
            print('backdrop', out.name, flush=True)


def ingest_backdrops(only=None):
    """Keep each picked backdrop at 2x its logical size (adaptive 160-colour PNG)."""
    spec = bd_spec()
    w, h = spec['size']
    runs_path = ROOT / 'art/comms/portrait-runs.json'
    runs = load(runs_path, {})
    for v in spec['variants']:
        if only and v['id'] not in only:
            continue
        raw_png = bd_path(v['id'], bd_seed(v))
        if not raw_png.exists():
            continue
        img = Image.open(raw_png).convert('RGB').resize((2 * w, 2 * h), Image.BOX)
        img.quantize(160, method=Image.Quantize.FASTOCTREE).save(SRC / f"backdrop-{v['id']}.png", optimize=True)
        side = raw_png.with_suffix('.json')
        if side.exists():
            meta = json.loads(side.read_text())
            runs.setdefault('_backdrops', {})[v['id']] = {k: meta.get(k) for k in ('workflow', 'seed', 'prompt', 'sha256')}
        print('source', f"backdrop-{v['id']}.png")
    runs_path.write_text(json.dumps(runs, indent=1) + '\n')


def backdrop_frame(vid):
    """Source -> logical size, desaturated and dimmed so its brightest
    pixels stay under `luminance_cap` of white, snapped to the palette."""
    spec = bd_spec()
    w, h = spec['size']
    rgb = np.array(Image.open(SRC / f'backdrop-{vid}.png').convert('RGB').resize((w, h), Image.BOX)).astype(np.float64)
    y = lum(rgb)[..., None]
    rgb = y + (rgb - y) * spec['saturation']
    peak = np.percentile(lum(rgb), 99.5)
    cap = spec['luminance_cap'] * 255
    if peak > cap:
        rgb = rgb * (cap / peak)
    out = np.zeros((h, w, 4), np.uint8)
    out[..., :3] = snap(np.clip(rgb, 0, 255))
    out[..., 3] = 255
    return out


def pack_backdrops():
    spec = bd_spec()
    w, h = spec['size']
    cols = spec['columns']
    variants = spec['variants']
    rows = -(-len(variants) // cols)
    atlas = np.zeros((rows * h, cols * w, 4), np.uint8)
    for i, v in enumerate(variants):
        if not (SRC / f"backdrop-{v['id']}.png").exists():
            print('missing backdrop source', v['id'])
            continue
        r, c = divmod(i, cols)
        atlas[r * h:(r + 1) * h, c * w:(c + 1) * w] = backdrop_frame(v['id'])
    Image.fromarray(atlas, 'RGBA').save(BACKDROPS, optimize=True)
    print('atlas', BACKDROPS.relative_to(ROOT), atlas.shape[1], 'x', atlas.shape[0], BACKDROPS.stat().st_size, 'bytes')
    index = {v['id']: i for i, v in enumerate(variants)}
    of = '\n'.join(f"  '{cid}': {index[spec['assign'][cid]]}," for cid in cast_ids())
    names = '\n'.join(f"  '{v['id']}'," for v in variants)
    return f"""
/// Dim interiors behind the portraits: [commsBackdropColumns] per row, each
/// [commsBackdropSize] logical px, wider than the portrait cell for parallax.
const commsBackdropImage = 'assets/images/comms-backdrops.png';
const commsBackdropSize = (w: {w}, h: {h});
const commsBackdropColumns = {cols};
const commsBackdropNames = <String>[
{names}
];

/// Backdrop index of every character.
const commsBackdropOf = <String, int>{{
{of}
}};
"""


def bd_candidates(only=None):
    spec = bd_spec()
    vs = [v for v in spec['variants'] if not only or v['id'] in only]
    tw, th = 320, 256
    n = spec['count']
    img = Image.new('RGB', (n * (tw + 4) + 110, len(vs) * (th + 4)), (20, 20, 30))
    d = ImageDraw.Draw(img)
    for y, v in enumerate(vs):
        d.text((4, y * (th + 4) + 4), v['id'], fill=(255, 255, 255))
        for x in range(n):
            p = bd_path(v['id'], v['seed'] + x)
            if p.exists():
                img.paste(Image.open(p).convert('RGB').resize((tw, th), Image.BOX), (110 + x * (tw + 4), y * (th + 4)))
                d.text((114 + x * (tw + 4), y * (th + 4) + 4), str(v['seed'] + x), fill=(255, 255, 0))
    out = CACHE / 'bd-candidates.png'
    img.save(out)
    print(out)


STAGES = {
    'keyframes': keyframes, 'edits': edits, 'matte': matte, 'ingest': ingest,
    'finish': finish, 'pack': pack, 'sheet': sheet, 'candidates': candidates, 'check': check,
    'backdrops': backdrops, 'bdingest': ingest_backdrops, 'bdcandidates': bd_candidates,
}


def main(argv):
    stage = argv[0] if argv else 'offline'
    only = argv[1].split(',') if len(argv) > 1 else None
    if stage == 'offline':
        pack(); sheet(); check()
    elif stage == 'all':
        keyframes(); edits(); matte(); ingest(); backdrops(); ingest_backdrops(); pack(); sheet(); check()
    elif stage in ('keyframes', 'edits', 'matte', 'ingest', 'candidates', 'backdrops', 'bdingest', 'bdcandidates'):
        STAGES[stage](only)
    else:
        STAGES[stage]()


if __name__ == '__main__':
    main(sys.argv[1:])
