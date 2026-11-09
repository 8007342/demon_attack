"""Reproducible sprite pipeline: ComfyUI keyframes -> palette detail -> atlases.

    .cache/asset-venv/bin/python tools/sprite_pipeline.py all        # everything
    .cache/asset-venv/bin/python tools/sprite_pipeline.py keyframes  # GPU: SDXL + pixel-art-xl
    .cache/asset-venv/bin/python tools/sprite_pipeline.py edits      # GPU: Qwen-Image-Edit molts
    .cache/asset-venv/bin/python tools/sprite_pipeline.py finish     # CPU: matte, grid, palette
    .cache/asset-venv/bin/python tools/sprite_pipeline.py atlases    # CPU: deterministic packers
    .cache/asset-venv/bin/python tools/sprite_pipeline.py sheets     # CPU: review contact sheets

Stages and files (all committed except the GPU cache):

1. keyframes: art/workflows/sprites/keyframe-sdxl-pixel.json is queued on the
   project's ComfyUI studio ($COMFYUI_URL, default http://studio:8188) once
   per species with the fixed seed/prompt in art/families/sprites/prompts.json
   (count candidates, seed, seed+1, ...). Raw 1024 px outputs land in
   $SPRITE_PIPELINE_CACHE (default ~/.cache/demon-attack/sprite-pipeline,
   outside the repo); the selected candidate (art/families/sprites/
   selections.json) is kept as a 256 px nearest copy under
   art/sprites/sources/keyframes/.
2. edits: art/workflows/sprites/variant-qwen-edit.json turns the selected
   keyframe into three molt variants (prompts.json molt_edit), kept under
   art/sprites/sources/molts/.
3. finish: colour-key matte from the white border, crop to the creature,
   then the head/torso window is sampled onto the 64-grid body box and
   reduced to a four-level luminance map: art/families/sprites/detail/
   <species>[-m<k>].png. The atlas generator maps those levels onto the ramp
   of whichever frame it draws (intact, molt, angry, flash), so AI texture
   adds shading detail while silhouettes, eyes, insignia, outlines and
   palette stay authored and aligned across every frame.
4. atlases: tools/generate_sprites.py (combat), generate_ship_sprites.py,
   generate_sentinel_sprites.py, generate_boss_sprites.py. Pure functions of
   their inputs: same inputs, same bytes.
5. sheets: contact sheets under art/sprites/review/ for human review.

The GPU stages are optional for rebuilding atlases: the committed sources
and detail maps are the inputs of record. Re-running keyframes with the same
seeds on the same models reproduces the candidates (ComfyUI is
deterministic per seed on a given GPU/driver; provenance JSON beside each
raw output records model hashes).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art'
FAM = ART / 'families/sprites'
SRC = ART / 'sprites/sources'
REVIEW = ART / 'sprites/review'
CACHE = Path(os.environ.get('SPRITE_PIPELINE_CACHE', Path.home() / '.cache/demon-attack/sprite-pipeline'))
COMFY = os.environ.get('COMFYUI_URL', 'http://studio:8188')
PY = sys.executable

sys.path.insert(0, str(ROOT / 'tools'))
from sprite_kit import PALETTE_RGB  # noqa: E402

# Head/torso box on the 64-grid (generate_sprites.HEAD/TORSO bounds).
BODY_BOX = (25, 12, 40, 50)


def load(path, default=None):
    return json.loads(Path(path).read_text()) if Path(path).exists() else default


# ---------------------------------------------------------------------------
# ComfyUI HTTP client (the same API studio.run_workflow drives).
# ---------------------------------------------------------------------------
def _set_titled(wf, title, key, value):
    for node in wf.values():
        if node.get('_meta', {}).get('title') == title:
            node['inputs'][key] = value


def _upload(path: Path) -> str:
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{path.name}"\r\n'
            f'Content-Type: image/png\r\n\r\n').encode() + path.read_bytes() + \
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n--{boundary}--\r\n'.encode()
    req = urllib.request.Request(f'{COMFY}/upload/image', body,
                                 {'Content-Type': f'multipart/form-data; boundary={boundary}'})
    return json.loads(urllib.request.urlopen(req, timeout=60).read())['name']


def run_workflow(workflow: Path, seed: int, prompt=None, negative=None, image: Path | None = None) -> list[bytes]:
    wf = json.loads(workflow.read_text())
    _set_titled(wf, '$seed', 'seed', seed)
    if prompt is not None:
        for key in ('text', 'prompt'):
            for node in wf.values():
                if node.get('_meta', {}).get('title') == '$prompt' and key in node['inputs']:
                    node['inputs'][key] = prompt
    if negative is not None:
        for node in wf.values():
            if node.get('_meta', {}).get('title') == '$negative_prompt':
                k = 'text' if 'text' in node['inputs'] else 'prompt'
                node['inputs'][k] = negative
    if image is not None:
        name = _upload(image)
        for node in wf.values():
            if node['class_type'] == 'LoadImage' and str(node['inputs'].get('image', '')).startswith('$'):
                node['inputs']['image'] = name
    for node in wf.values():
        node.pop('_meta', None)
    req = urllib.request.Request(f'{COMFY}/prompt', json.dumps({'prompt': wf, 'client_id': 'sprite-pipeline'}).encode(),
                                 {'Content-Type': 'application/json'})
    pid = json.loads(urllib.request.urlopen(req, timeout=60).read())['prompt_id']
    for _ in range(1800):
        hist = json.loads(urllib.request.urlopen(f'{COMFY}/history/{pid}', timeout=60).read())
        if pid in hist and hist[pid].get('outputs'):
            out = []
            for node_out in hist[pid]['outputs'].values():
                for im in node_out.get('images', []):
                    q = urllib.parse.urlencode({k: im[k] for k in ('filename', 'subfolder', 'type')})
                    out.append(urllib.request.urlopen(f'{COMFY}/view?{q}', timeout=60).read())
            return out
        time.sleep(1)
    raise TimeoutError(f'ComfyUI prompt {pid} did not finish')


# ---------------------------------------------------------------------------
# Stages.
# ---------------------------------------------------------------------------
def keyframes():
    spec = load(FAM / 'prompts.json')
    kf = spec['keyframe']
    for species, item in kf['species'].items():
        for i in range(kf['count']):
            seed = item['seed'] + i
            out = CACHE / 'keyframes' / f'{species}-{seed}.png'
            if out.exists():
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            png = run_workflow(ROOT / kf['workflow'], seed, f"{spec['style']}, {item['prompt']}", spec['negative'])[0]
            out.write_bytes(png)
            print('keyframe', out.relative_to(ROOT))
    keep_selected()


def selected(species):
    sel = load(FAM / 'selections.json', {})['keyframes'][species]
    return sel['seed']


def keep_selected():
    for species in ('teal', 'violet', 'coral', 'gold'):
        seed = selected(species)
        raw = CACHE / 'keyframes' / f'{species}-{seed}.png'
        if raw.exists():
            dst = SRC / 'keyframes' / f'{species}.png'
            dst.parent.mkdir(parents=True, exist_ok=True)
            Image.open(raw).convert('RGB').resize((256, 256), Image.NEAREST).save(dst, optimize=True)


def edits():
    spec = load(FAM / 'prompts.json')['molt_edit']
    for species in ('teal', 'violet', 'coral', 'gold'):
        src = CACHE / 'keyframes' / f'{species}-{selected(species)}.png'
        if not src.exists():
            src = SRC / 'keyframes' / f'{species}.png'
        for molt, prompt in spec['prompts'].items():
            dst = SRC / 'molts' / f'{species}-m{molt}.png'
            if dst.exists():
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            png = run_workflow(ROOT / spec['workflow'], spec['seed'] + int(molt), prompt, '', image=src)[0]
            raw = CACHE / 'molts' / dst.name
            raw.parent.mkdir(parents=True, exist_ok=True)
            raw.write_bytes(png)
            Image.open(raw).convert('RGB').resize((256, 256), Image.NEAREST).save(dst, optimize=True)
            print('molt', dst.relative_to(ROOT))


def matte(rgb: np.ndarray) -> np.ndarray:
    """Foreground mask: flood the near-white/near-border colour from the
    edges (colour key), keep the largest connected component."""
    from scipy import ndimage
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]).astype(int)
    key = np.median(border, axis=0)
    dist = np.abs(rgb.astype(int) - key).sum(-1)
    bg = dist < 60
    lab, n = ndimage.label(bg)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    background = np.isin(lab, list(edge))
    fg = ~background
    lab, n = ndimage.label(fg)
    if n > 1:
        sizes = ndimage.sum(fg, lab, range(1, n + 1))
        fg = lab == (1 + int(np.argmax(sizes)))
    return ndimage.binary_fill_holes(fg)


def detail_map(path: Path) -> np.ndarray:
    """4-level luminance detail on the 64-grid body box (RGBA, palette greys
    are placeholders: the atlas maps level -> ramp tone)."""
    rgb = np.array(Image.open(path).convert('RGB'))
    fg = matte(rgb)
    ys, xs = np.nonzero(fg)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    # Head/torso window: central 34% of the creature's width (wings excluded),
    # from the top of the head to 80% of its height.
    cx = (x0 + x1) / 2
    half = (x1 - x0) * .17
    wx0, wx1 = int(cx - half), int(cx + half)
    wy0, wy1 = y0, int(y0 + (y1 - y0) * .8)
    crop = rgb[wy0:wy1, wx0:wx1].astype(float)
    mask = fg[wy0:wy1, wx0:wx1]
    bx0, by0, bx1, by1 = BODY_BOX
    w, h = bx1 - bx0, by1 - by0
    lum = crop @ np.array([.3, .59, .11])
    # Majority/mean sampling onto the grid (box filter), masked.
    out = np.zeros((64, 64, 4), dtype=np.uint8)
    levels = np.zeros((h, w))
    valid = np.zeros((h, w), dtype=bool)
    for gy in range(h):
        for gx in range(w):
            sy0, sy1 = int(gy * crop.shape[0] / h), int((gy + 1) * crop.shape[0] / h)
            sx0, sx1 = int(gx * crop.shape[1] / w), int((gx + 1) * crop.shape[1] / w)
            m = mask[sy0:sy1, sx0:sx1]
            if m.mean() > .5:
                levels[gy, gx] = lum[sy0:sy1, sx0:sx1][m].mean()
                valid[gy, gx] = True
    if valid.any():
        v = levels[valid]
        q = np.quantile(v, [.2, .55, .85])
        lv = np.digitize(levels, q)  # 0..3
        greys = np.array([[40, 40, 40], [100, 100, 100], [170, 170, 170], [240, 240, 240]], dtype=np.uint8)
        block = np.zeros((h, w, 4), dtype=np.uint8)
        block[..., :3] = greys[lv]
        block[..., 3] = np.where(valid, 255, 0)
        out[by0:by1, bx0:bx1] = block
    return out


def finish():
    for species in ('teal', 'violet', 'coral', 'gold'):
        src = SRC / 'keyframes' / f'{species}.png'
        if src.exists():
            save_detail(detail_map(src), FAM / 'detail' / f'{species}.png')
        for molt in (1, 2, 3):
            m = SRC / 'molts' / f'{species}-m{molt}.png'
            if m.exists():
                save_detail(detail_map(m), FAM / 'detail' / f'{species}-m{molt}.png')


def save_detail(arr, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, 'RGBA').save(path, optimize=True)
    print('detail', path.relative_to(ROOT))


def atlases():
    for tool in ('generate_sprites.py', 'generate_ship_sprites.py', 'generate_sentinel_sprites.py',
                 'generate_boss_sprites.py'):
        subprocess.run([PY, str(ROOT / 'tools' / tool)], check=True)


def sheets():
    REVIEW.mkdir(parents=True, exist_ok=True)
    bg = (24, 20, 48, 255)

    def sheet(atlas, cw, ch, rows, scale, out, cols=None):
        im = Image.open(ROOT / 'assets/images' / atlas).convert('RGBA')
        n = cols or im.width // cw
        s = Image.new('RGBA', (n * cw * scale, len(rows) * ch * scale), bg)
        for i, r in enumerate(rows):
            for c in range(n):
                cell = im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)).resize((cw * scale, ch * scale), Image.NEAREST)
                s.alpha_composite(cell, (c * cw * scale, i * ch * scale))
        s.save(REVIEW / out, optimize=True)
        print('sheet', (REVIEW / out).relative_to(ROOT))

    for k, sp in enumerate(('teal', 'violet', 'coral', 'gold')):
        sheet('combat.png', 64, 64, list(range(k * 7, k * 7 + 7)), 2, f'combat-{sp}.png')
    sheet('combat.png', 64, 64, [28, 29, 30, 31], 2, 'combat-shared.png')
    sheet('ship-weapons.png', 64, 64, list(range(7)), 2, 'ship-weapons.png')
    sheet('sentinel-effects.png', 128, 64, list(range(14)), 1, 'sentinel-effects.png')
    sheet('boss-carrier.png', 368, 240, list(range(7)), 1, 'boss-carrier.png')
    # AI sources beside their finished detail maps.
    tiles = []
    for sp in ('teal', 'violet', 'coral', 'gold'):
        row = []
        for name in (f'keyframes/{sp}.png', f'molts/{sp}-m1.png', f'molts/{sp}-m2.png', f'molts/{sp}-m3.png'):
            p = SRC / name
            row.append(Image.open(p).convert('RGBA').resize((128, 128), Image.NEAREST) if p.exists() else None)
        for name in (f'{sp}.png', f'{sp}-m1.png', f'{sp}-m2.png', f'{sp}-m3.png'):
            p = FAM / 'detail' / name
            row.append(Image.open(p).convert('RGBA').resize((128, 128), Image.NEAREST) if p.exists() else None)
        tiles.append(row)
    s = Image.new('RGBA', (8 * 128, 4 * 128), bg)
    for y, row in enumerate(tiles):
        for x, t in enumerate(row):
            if t is not None:
                s.alpha_composite(t, (x * 128, y * 128))
    s.save(REVIEW / 'ai-sources-and-detail.png', optimize=True)
    print('sheet', (REVIEW / 'ai-sources-and-detail.png').relative_to(ROOT))


STAGES = {'keyframes': keyframes, 'edits': edits, 'finish': finish, 'atlases': atlases, 'sheets': sheets}

if __name__ == '__main__':
    arg = sys.argv[1] if len(sys.argv) > 1 else 'all'
    if arg == 'all':
        for name in ('keyframes', 'edits', 'finish', 'atlases', 'sheets'):
            STAGES[name]()
    elif arg == 'offline':
        for name in ('finish', 'atlases', 'sheets'):
            STAGES[name]()
    else:
        STAGES[arg]()
