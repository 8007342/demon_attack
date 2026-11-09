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
0 idle, 1 blink, 2 talkA, 3 talkB, 4 talkC, 5 talkD ('oo'), 6 shout,
7 grunt (demon roar / human alarm), 8 happy (demon gloat), 9 worried
(demon alarmed snarl), 10 tilt left, 11 tilt right.

Qwen-Image-Edit makes blink, shout, grunt, happy and worried from the picked
keyframe. Each edit is registered to the idle frame by an integer shift and
composited only inside the face box (eyes for blink), so the body never
jitters; talk frames reveal the shout mouth row by row inside the mouth box;
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


def base(cid, name, grid):
    """Source (already head-cropped at 2x) -> logical grid, palette-snapped,
    binary alpha, no outline yet."""
    src = Image.open(SRC / f'{cid}-{name}.png').convert('RGBA').resize((grid, grid), Image.BOX)
    arr = np.array(src)
    alpha = arr[..., 3] > 110
    out = np.zeros((grid, grid, 4), np.uint8)
    out[alpha, :3] = snap(arr[..., :3])[alpha]
    out[alpha, 3] = 255
    return out


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


def register(idle, edit, r=4):
    """Integer shift of an edit that best matches idle (Qwen may drift a pixel or two)."""
    best = (None, 0, 0)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            score = diff(idle, shift(edit, dx, dy)).sum()
            if best[0] is None or score < best[0]:
                best = (score, dx, dy)
    return shift(edit, best[1], best[2])


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


def composite(idle, edit, region):
    """Take the edit's pixels only where they differ inside the region box
    (dilated by a pixel), the rest of the frame stays idle."""
    x0, y0, x1, y1 = region
    box = np.zeros(idle.shape[:2], bool)
    box[max(0, y0):y1, max(0, x0):x1] = True
    m = dilate(diff(idle, edit) & box, 1) & box
    out = idle.copy()
    out[m] = edit[m]
    return out


def blend_mouth(idle, shout, box, amount, round_shape=False):
    """Talk frame: the shout mouth (inside its tight box) squashed to
    `amount` of its height (and, for 'oo', 60 % of its width) with
    nearest-neighbour row/column picks, centred on the box; only pixels that
    differ from idle are painted, so skin around the mouth stays put."""
    x0, y0, x1, y1 = box
    h, w = y1 - y0, x1 - x0
    th = max(1, int(round(h * amount)))
    tw = max(1, int(round(w * (0.6 if round_shape else 1.0))))
    oy = y0 + (h - th) // 2
    ox = x0 + (w - tw) // 2
    out = idle.copy()
    for i in range(th):
        sy = y0 + min(h - 1, int((i + .5) * h / th))
        for j in range(tw):
            sx = x0 + min(w - 1, int((j + .5) * w / tw))
            px = shout[sy, sx]
            if px[3] and np.abs(px.astype(int) - idle[sy, sx].astype(int)).sum() > 90:
                out[oy + i, ox + j] = px
    return out


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


def frames_for(cid, grid=None):
    """The twelve frames of one character, in CommsFrame order."""
    grid = grid or load(SPEC)['grid']
    idle = base(cid, 'key', grid)
    ed = {}
    for name in EDIT_FRAMES:
        ed[name] = register(idle, base(cid, name, grid)) if (SRC / f'{cid}-{name}.png').exists() else idle
    mouth, eyes = face_boxes(cid, idle, ed['blink'], ed['shout'], grid)
    # The face region for expressions: eyes (with brows) down to below the mouth.
    pad = grid // 16
    face = [min(eyes[0], mouth[0]) - pad, eyes[1] - pad * 2, max(eyes[2], mouth[2]) + pad, mouth[3] + pad]
    blink_f = composite(idle, ed['blink'], [eyes[0] - 1, eyes[1] - 1, eyes[2] + 1, eyes[3] + 1])
    shout = composite(idle, ed['shout'], face)
    talk = [blend_mouth(idle, shout, mouth, a) for a in (0.35, 0.65, 1.0)]
    oo = blend_mouth(idle, shout, mouth, 0.8, round_shape=True)
    grunt = composite(idle, ed['grunt'], face) if kind(cid) == 'human' else ed['grunt']
    happy = composite(idle, ed['happy'], face)
    worried = composite(idle, ed['worried'], face)
    pivot = min(grid - 1, mouth[3] + (mouth[3] - eyes[1]) // 2)
    deg = load(SPEC).get('tilt_degrees', 4)
    frames = [idle, blink_f, *talk, oo, shout, grunt, happy, worried,
              tilt(idle, pivot, -deg), tilt(idle, pivot, deg)]
    return [finish_frame(f) for f in frames], mouth, eyes


def finish():
    """Print the derived face boxes (logical 128 grid) for review."""
    for cid in cast_ids():
        if not (SRC / f'{cid}-key.png').exists():
            continue
        _, mouth, eyes = frames_for(cid)
        print(cid, 'mouth', mouth, 'eyes', eyes)


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
        frames, mouth, eyes = frames_for(cid, g)
        meta[cid] = {'mouth': mouth, 'eyes': eyes}
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
""")


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
    w = label_w + n * (g * z + 4) + 2 * (s + 6)
    h = 20 + len(ids) * (g * z + 6)
    img = Image.new('RGBA', (w, h), (16, 14, 44, 255))
    draw = ImageDraw.Draw(img)
    for c, name in enumerate(spec['frames']):
        draw.text((label_w + c * (g * z + 4) + 4, 4), name, fill=(160, 200, 220, 255))
    draw.text((label_w + n * (g * z + 4) + 2, 4), f'{s}px', fill=(160, 200, 220, 255))
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
        for k, col in enumerate((0, 7)):
            cell = small.crop((col * s, r * s, (col + 1) * s, (r + 1) * s))
            x = label_w + n * (g * z + 4) + 4 + k * (s + 4)
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


STAGES = {
    'keyframes': keyframes, 'edits': edits, 'matte': matte, 'ingest': ingest,
    'finish': finish, 'pack': pack, 'sheet': sheet, 'candidates': candidates,
}


def main(argv):
    stage = argv[0] if argv else 'offline'
    only = argv[1].split(',') if len(argv) > 1 else None
    if stage == 'offline':
        pack(); sheet()
    elif stage == 'all':
        keyframes(); edits(); matte(); ingest(); pack(); sheet()
    elif stage in ('keyframes', 'edits', 'matte', 'ingest', 'candidates'):
        STAGES[stage](only)
    else:
        STAGES[stage]()


if __name__ == '__main__':
    main(sys.argv[1:])
