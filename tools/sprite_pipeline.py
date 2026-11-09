"""Reproducible sprite pipeline: ComfyUI keyframes -> palette detail -> atlases.

    .cache/asset-venv/bin/python tools/sprite_pipeline.py all        # everything
    .cache/asset-venv/bin/python tools/sprite_pipeline.py keyframes  # GPU: SDXL + pixel-art-xl
    .cache/asset-venv/bin/python tools/sprite_pipeline.py edits      # GPU: Qwen-Image-Edit molts
    .cache/asset-venv/bin/python tools/sprite_pipeline.py finish     # CPU: matte, grid, palette
    .cache/asset-venv/bin/python tools/sprite_pipeline.py atlases    # CPU: deterministic packers
    .cache/asset-venv/bin/python tools/sprite_pipeline.py sheets     # CPU: review contact sheets
    .cache/asset-venv/bin/python tools/sprite_pipeline.py screens    # CPU: in-engine review sheets
                                                     #   (after flutter test test/gargoyle_review_test.dart)

Stages and files (all committed except the GPU cache):

1. keyframes: art/workflows/sprites/keyframe-sdxl-pixel.json is queued on the
   project's ComfyUI studio ($COMFYUI_URL, default http://studio:8188) once
   per species with the fixed seed/prompt in art/families/sprites/prompts.json
   (count candidates, seed, seed+1, ...). Raw 1024 px outputs land in
   $SPRITE_PIPELINE_CACHE (default ~/.cache/demon-attack/sprite-pipeline,
   outside the repo); the selected candidate (art/families/sprites/
   selections.json) is kept as a 256 px nearest copy under
   art/sprites/sources/keyframes/. The carrier's hide, masonry and membrane
   candidates (art/workflows/sprites/carrier-texture-sdxl.json,
   art/families/carrier/prompts.json) are kept as selected crops under
   art/sprites/sources/carrier/.
2. edits: art/workflows/sprites/variant-qwen-edit.json turns the selected
   keyframe into three molt variants (prompts.json molt_edit), kept under
   art/sprites/sources/molts/.
3. finish: colour-key matte from the white border, crop to the creature,
   then the head/torso window is sampled onto the 64-grid body box and
   reduced to a four-level luminance map: art/families/sprites/detail/
   <species>[-m<k>].png. The gargoyle rig (tools/gargoyle_rig.py) uses those
   levels to nudge the key-light value of hide pixels before it quantises
   them onto the palette ramp, so AI texture adds stony, leathery shading
   while silhouettes, faces, insignia, outlines and palette stay authored and
   aligned across every frame. The carrier crops are high-passed and
   quantised the same way into art/families/carrier/detail/.
4. atlases: tools/generate_sprites.py (combat), generate_ship_sprites.py,
   generate_sentinel_sprites.py, generate_boss_sprites.py, plus
   art/families/sprites/palette.json from sprite_kit.PALETTE. Pure
   functions of their inputs: same inputs, same bytes.
5. sheets: contact sheets under art/sprites/review/ for human review.
6. screens (not part of offline/all): composes the in-engine review frames
   that test/gargoyle_review_test.dart renders into .cache/gargoyle-review/
   into art/sprites/review/in-engine-*.png.

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
from sprite_kit import PALETTE, PALETTE_RGB  # noqa: E402,F401

# Hide box on the 64-grid covering the gargoyle's head, shoulders and torso
# in the neutral 3/4 view (tools/gargoyle_rig.py, origin (32, 31)).
BODY_BOX = (20, 14, 44, 52)


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
            print('keyframe', out)
    keep_selected()
    carrier_keyframes()


# ---------------------------------------------------------------------------
# Carrier war-ark shading detail (art/families/carrier).
# ---------------------------------------------------------------------------
CAR = ART / 'families/carrier'
CAR_SRC = SRC / 'carrier'
CAR_CELL = (368, 240)


def carrier_keyframes():
    """SDXL + pixel-art-xl candidates for the carrier's hide, masonry and
    membrane detail; the selected crops (selections.json) are kept, box
    sampled to one 368 x 240 cell, under art/sprites/sources/carrier/."""
    spec = load(CAR / 'prompts.json')
    for name, item in spec['items'].items():
        for i in range(item['count']):
            seed = item['seed'] + i
            out = CACHE / 'carrier' / f'{name}-{seed}.png'
            if out.exists():
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(run_workflow(ROOT / spec['workflow'], seed, item['prompt'], spec['negative'])[0])
            print('carrier keyframe', out)
    for detail, sel in load(CAR / 'selections.json')['detail'].items():
        raw = CACHE / 'carrier' / f"{sel['item']}-{sel['seed']}.png"
        if raw.exists():
            CAR_SRC.mkdir(parents=True, exist_ok=True)
            Image.open(raw).convert('RGB').crop(tuple(sel['crop'])).resize(CAR_CELL, Image.BOX).save(
                CAR_SRC / f'{detail}.png', optimize=True)


def _box_blur(a, r):
    """Separable box blur (edge-clamped), numpy only."""
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(a, pad, mode='edge'), axis=axis)
        n = a.shape[axis]
        a = (np.take(c, range(2 * r + 1, 2 * r + 1 + n), axis=axis) - np.take(c, range(0, n), axis=axis)) / (2 * r + 1)
    return a


def carrier_finish():
    """Four-level high-passed luminance maps (fine stone, masonry and
    membrane texture without the source's own lighting) at the carrier's
    native cell size; generate_boss_sprites.py maps level -> key-light
    offset."""
    sel = load(CAR / 'selections.json', {'detail': {}})['detail']
    for detail in sel:
        src = CAR_SRC / f'{detail}.png'
        if not src.exists():
            continue
        rgb = np.array(Image.open(src).convert('RGB')).astype(float)
        lum = rgb @ np.array([.3, .59, .11])
        hp = lum - _box_blur(lum, 9)
        q = np.quantile(hp, [.2, .55, .85])
        lv = np.digitize(hp, q)
        greys = np.array([40, 100, 170, 240], dtype=np.uint8)
        out = np.zeros(lum.shape + (4,), dtype=np.uint8)
        out[..., :3] = greys[lv][..., None]
        out[..., 3] = 255
        save_detail(out, CAR / 'detail' / f'{detail}.png')


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
            out = FAM / 'detail' / f'{species}-m{molt}.png'
            if m.exists():
                save_detail(detail_map(m), out)
            elif out.exists():
                out.unlink()  # no molt source: the molt reuses the intact hide map
    carrier_finish()


def save_detail(arr, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, 'RGBA').save(path, optimize=True)
    print('detail', path.relative_to(ROOT))


def palette_json():
    out = {'schema': 'tillandsias.palette/v1', 'name': 'demon-attack-combat',
           'colours': list(dict.fromkeys(PALETTE.values()))}
    (FAM / 'palette.json').write_text(json.dumps(out, indent=1) + '\n')


def atlases():
    palette_json()
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
        sheet('combat.png', 64, 64, list(range(k * 9, k * 9 + 9)), 2, f'combat-{sp}.png')
    sheet('combat.png', 64, 64, [36, 37, 38, 39], 2, 'combat-shared.png', cols=16)
    # Directional flight frames: per species the left / neutral / right
    # flight sets (0-3 downstroke, 4-7 upstroke, 8-9 glide) of the intact
    # and molt-3 rows, at 3x.
    im = Image.open(ROOT / 'assets/images/combat.png').convert('RGBA')
    s = Image.new('RGBA', (10 * 192, 24 * 144), bg)
    for k in range(4):
        for vi, v in enumerate((0, 3)):
            for d in range(3):
                y = (k * 6 + vi * 3 + d) * 144
                r = (k * 9 + v) * 64
                for f in range(10):
                    c = (d * 10 + f) * 64
                    cell = im.crop((c, r + 8, c + 64, r + 56)).resize((192, 144), Image.NEAREST)
                    s.alpha_composite(cell, (f * 192, y))
    s.save(REVIEW / 'combat-directions.png', optimize=True)
    print('sheet', (REVIEW / 'combat-directions.png').relative_to(ROOT))
    sheet('ship-weapons.png', 64, 64, list(range(7)), 2, 'ship-weapons.png')
    sheet('sentinel-effects.png', 128, 64, list(range(14)), 1, 'sentinel-effects.png')
    sheet('boss-carrier.png', 368, 240, list(range(11)), 1, 'boss-carrier.png')
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


def screens():
    """In-engine review: the phone-size frames rendered by
    test/gargoyle_review_test.dart, composed at 2x."""
    src = ROOT / '.cache/gargoyle-review'
    groups = {'in-engine-motion-damage.png': ['motion', 'damage'],
              'in-engine-sectors.png': [f'sector-{i}' for i in range(1, 6)]}
    for out, names in groups.items():
        ims = [Image.open(src / f'{n}.png').convert('RGBA') for n in names if (src / f'{n}.png').exists()]
        if not ims:
            continue
        w, h = ims[0].size
        s = Image.new('RGBA', (len(ims) * (w * 2 + 8) - 8, h * 2), (0, 0, 0, 255))
        for i, im in enumerate(ims):
            s.paste(im.resize((w * 2, h * 2), Image.NEAREST), (i * (w * 2 + 8), 0))
        s.save(REVIEW / out, optimize=True)
        print('sheet', (REVIEW / out).relative_to(ROOT))
    carrier_screens()


def carrier_screens():
    """The war-ark in engine (test/carrier_review_test.dart writes
    .cache/carrier-review/): every form shielded and with the jaws open, the
    jaw cycle, damage escalation (1x crops of the carrier band), then the
    falling wreck and the carrier beside gargoyles and a sentinel over the
    Carrier sector (full phone frames)."""
    src = ROOT / '.cache/carrier-review'
    if not (src / 'form-0-shield.png').exists():
        return
    rows = [[f'form-{f}-shield' for f in range(4)], [f'form-{f}-open' for f in range(4)],
            [f'jaw-{k}' for k in range(4)], [f'damage-{k}' for k in range(1, 5)]]
    box = (0, 110, 360, 300)
    w, h = box[2] - box[0], box[3] - box[1]
    s = Image.new('RGBA', (4 * w + 12, len(rows) * h + 4 * (len(rows) - 1)), (0, 0, 0, 255))
    for r, names in enumerate(rows):
        for c, n in enumerate(names):
            s.paste(Image.open(src / f'{n}.png').convert('RGBA').crop(box), (c * (w + 4), r * (h + 4)))
    s.save(REVIEW / 'in-engine-carrier.png', optimize=True)
    print('sheet', (REVIEW / 'in-engine-carrier.png').relative_to(ROOT))
    names = ['world-phone', 'world-final-phone', 'wreck-0-1', 'wreck-3-2']
    ims = [Image.open(src / f'{n}.png').convert('RGBA') for n in names]
    w, h = ims[0].size
    s = Image.new('RGBA', (len(ims) * (w + 4) - 4, h), (0, 0, 0, 255))
    for i, im in enumerate(ims):
        s.paste(im, (i * (w + 4), 0))
    s.save(REVIEW / 'in-engine-carrier-world.png', optimize=True)
    print('sheet', (REVIEW / 'in-engine-carrier-world.png').relative_to(ROOT))


STAGES = {'keyframes': keyframes, 'edits': edits, 'finish': finish, 'atlases': atlases, 'sheets': sheets,
          'screens': screens}

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
