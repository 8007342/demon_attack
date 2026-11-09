#!/usr/bin/env python3
"""Reproducible ComfyUI pipeline for the oblique flyover parallax backgrounds.

Everything is driven by ``art/families/flyover-backgrounds.json`` (prompts,
seeds, sizes, layer luminance caps) and the API-format workflows under
``art/workflows/backgrounds/``.  Stages:

  palettes   derive a bounded palette per sector from its painted sky
  layouts    seeded, vertically tileable layout sheets + seam mask (img2img inputs)
  jobs       write the generation queue (one entry per ComfyUI run)
  run        execute the queue directly against a ComfyUI HTTP endpoint (optional;
             agents normally run each job through studio.run_workflow instead)
  ingest     copy raw outputs out of ephemeral /work/tmp and record provenance
  process    pixel finish: grid downscale, palette quantise, luminance caps,
             procedural tileable alpha/cliff faces, sprite crops, creature frames
  pack       atlases (assets/images/flyover-*.png) + lib/game/flyover_atlas.dart
  contact    labelled contact sheet of every final asset

``all`` runs palettes, layouts, jobs, process, pack and contact (no GPU).
Every random choice is seeded from the spec, so reruns give identical bytes for
identical raw inputs.  Requires Pillow + NumPy (see plan/asset-pipeline.md).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC_PATH = ROOT / "art/families/flyover-backgrounds.json"
PALETTE_DIR = ROOT / "art/palettes"
RUNS_PATH = ROOT / "art/families/flyover-runs.json"
WORK = Path(os.environ.get("FLYOVER_WORK", "/work/tmp/imagegen/flyover"))
# Raw generations are large: keep them outside the checkout (FLYOVER_RAW).
RAW = Path(os.environ.get("FLYOVER_RAW", str(ROOT / ".cache/flyover-raw")))
ASSETS = ROOT / "assets/images"
DART_OUT = ROOT / "lib/game/flyover_atlas.dart"
CONTACT_OUT = ROOT / "art/contact/flyover-contact.png"
# Shipped strip layers: far ridges (drawn rotated along the horizon) and the
# slim broken side walls.  The ground plane is a separate 2-D seamless tile.
LAYERS = ("mid", "wall")
VOID = (7, 11, 22)


def spec() -> dict:
    return json.loads(SPEC_PATH.read_text())


def stable_seed(*parts) -> int:
    digest = hashlib.sha256("/".join(str(p) for p in parts).encode()).digest()
    return int.from_bytes(digest[:4], "big")


def luma(rgb) -> float:
    r, g, b = (c / 255 for c in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


# --------------------------------------------------------------------------
# Palettes
# --------------------------------------------------------------------------


def cmd_palettes(_args) -> None:
    PALETTE_DIR.mkdir(parents=True, exist_ok=True)
    for sector in spec()["sectors"]:
        img = Image.open(ROOT / sector["painting"]).convert("RGB")
        small = img.resize((256, 384), Image.Resampling.BOX)
        q = small.quantize(colors=40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        raw = q.getpalette()[: 40 * 3]
        counts = sorted(q.getcolors(), reverse=True)
        cols = [tuple(raw[i * 3 : i * 3 + 3]) for _, i in counts]
        # Guarantee near-black anchors and deep shadows.
        cols += [VOID, (12, 16, 30), (18, 22, 40)]
        uniq = sorted(set(cols), key=luma)
        out = {"sector": sector["id"], "source": sector["painting"],
               "colors": ["#%02X%02X%02X" % c for c in uniq]}
        (PALETTE_DIR / f"flyover-{sector['id']}.json").write_text(json.dumps(out, indent=1) + "\n")
        print("palette", sector["id"], len(uniq))


def load_palette(sector_id: str) -> np.ndarray:
    data = json.loads((PALETTE_DIR / f"flyover-{sector_id}.json").read_text())
    return np.array([[int(h[i : i + 2], 16) for i in (1, 3, 5)] for h in data["colors"]], dtype=np.float32)


def quantise(rgb: np.ndarray, palette: np.ndarray, cap: float, lift: float = 1.0, chroma: float = 1.0) -> np.ndarray:
    """Normalise brightness under the layer's luminance cap, then snap to the
    sector palette restricted to colours that respect the cap."""
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32) / 255
    hi = float(np.percentile(lum, 97)) if lum.size else 1
    scale = min(2.2, cap / max(hi, 1e-3)) * lift
    adj = np.clip(rgb * scale, 0, 255)
    pl = palette @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32) / 255
    # Chroma cap: saturated reds/oranges are reserved for hostile fire and
    # re-entry plasma, so scenery uses the muted end of the sector palette.
    pc = (palette.max(1) - palette.min(1)) / 255
    allowed = palette[(pl <= cap + 0.02) & (pc <= chroma)]
    if len(allowed) < 8:
        allowed = palette[np.argsort(pl)[:8]]
    flat = adj.reshape(-1, 3)
    # Weighted RGB distance in a perceptual-ish space.
    w = np.array([0.30, 0.59, 0.11], dtype=np.float32) + 0.3
    d = (((flat[:, None, :] - allowed[None, :, :]) ** 2) * w).sum(-1)
    idx = d.argmin(1)
    return allowed[idx].reshape(rgb.shape).astype(np.uint8)


# --------------------------------------------------------------------------
# Layouts (img2img inputs) and procedural, tileable bank masks
# --------------------------------------------------------------------------


def tile_noise(seed: int, w: int, h: int, cells=(6, 16)) -> np.ndarray:
    """Value noise that wraps vertically (period h) — seamless strips."""
    rng = np.random.default_rng(seed)
    cx, cy = cells
    grid = rng.random((cy, cx + 1)).astype(np.float32)
    ys = np.arange(h) / h * cy
    xs = np.arange(w) / w * cx
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    g00 = grid[y0 % cy][:, x0]
    g01 = grid[y0 % cy][:, np.minimum(x0 + 1, cx)]
    g10 = grid[(y0 + 1) % cy][:, x0]
    g11 = grid[(y0 + 1) % cy][:, np.minimum(x0 + 1, cx)]
    return (g00 * (1 - fx) + g01 * fx) * (1 - fy) + (g10 * (1 - fx) + g11 * fx) * fy


def bank_contour(sector_id: str, layer: str, variant: int, h: int, cfg: dict) -> np.ndarray:
    """Integer bank edge per logical row; periodic in h so strips tile."""
    rng = np.random.default_rng(stable_seed("contour", sector_id, layer, variant))
    y = np.arange(h)
    edge = np.full(h, float(cfg["base_width"]))
    norm = 0.0
    for k in (1, 2, 3, 5, 8):
        a = rng.uniform(0.35, 1.0) / math.sqrt(k)
        edge += cfg["amplitude"] * a * np.sin(2 * math.pi * (k * y / h + rng.random()))
        norm += a
    edge = cfg["base_width"] + (edge - cfg["base_width"]) / max(norm, 1) * 1.6
    # Promontories: a few periodic bumps give landmarks/creatures ledges.
    for _ in range(2 + variant % 2):
        c = rng.integers(0, h)
        width = rng.integers(10, 22)
        dist = np.minimum(np.abs(y - c), h - np.abs(y - c))
        edge += np.where(dist < width, (1 - dist / width) * rng.uniform(4, 9), 0)
    # Stepped terraces read as pixel art rather than a smooth curve.
    edge = np.round(edge / 2) * 2
    return np.clip(edge, 8, 62).astype(int)


FACE_DEPTH = {"mid": 4, "wall": 5}


def bank_masks(edge: np.ndarray, layer: str, w: int = 64):
    h = len(edge)
    xs = np.arange(w)[None, :]
    top = xs < edge[:, None]
    d = FACE_DEPTH[layer]
    face = np.zeros_like(top)
    for k in range(1, d + 1):
        face |= np.roll(top, k, axis=0)
    face &= ~top
    rim = top & ~np.roll(top, -1, axis=1)
    rim[:, -1] = top[:, -1]
    return top, face, rim


def broken_edge(top: np.ndarray, seed: int) -> np.ndarray:
    """Break a bank's inner edge: bite holes out of it and scatter detached
    boulders beyond it, so a slim wall reads as a crumbling rim rather than a
    solid column.  Periodic vertically like everything else."""
    h, w = top.shape
    rng = np.random.default_rng(seed)
    out = top.copy()
    ys, xs = np.mgrid[0:h, 0:w]
    edge = np.array([np.where(r)[0].max() + 1 if r.any() else 0 for r in top])
    for _ in range(14):
        cy = int(rng.integers(0, h))
        cx = int(edge[cy]) + int(rng.integers(-5, 1))
        r = float(rng.uniform(1.5, 3.5))
        dy = np.minimum(np.abs(ys - cy), h - np.abs(ys - cy))
        out &= ~((dy ** 2 + (xs - cx) ** 2) <= r * r)
    for _ in range(16):
        cy = int(rng.integers(0, h))
        cx = int(edge[cy]) + int(rng.integers(2, 9))
        r = float(rng.uniform(1.2, 2.8))
        dy = np.minimum(np.abs(ys - cy), h - np.abs(ys - cy))
        out |= (dy ** 2 + ((xs - cx) * 1.3) ** 2) <= r * r
    return out


def layer_masks(sector_id, layer, v, lh, lw, cfg):
    edge = bank_contour(sector_id, layer, v, lh, cfg)
    top, face, rim = bank_masks(edge, layer, lw)
    if cfg.get("broken"):
        top = broken_edge(top, stable_seed("broken", sector_id, layer, v))
        face = np.zeros_like(top)
        for k in range(1, FACE_DEPTH[layer] + 1):
            face |= np.roll(top, k, axis=0)
        face &= ~top
        rim = top & ~np.roll(top, -1, axis=1)
    return top, face, rim


def cmd_layouts(_args) -> None:
    s = spec()
    st = s["strip"]
    lw, lh = st["logical"]
    n = st["variants"]
    sx = st["sheet_px"][0] // (lw * n)
    (WORK / "inputs").mkdir(parents=True, exist_ok=True)
    # Bank interiors are filled with texture cut from the sector's own painted
    # world (its horizon band for ridges, its foreground for terrain/ground),
    # so img2img inherits that sector's materials, colours and identity.
    bands = {"mid": (0.74, 0.97), "wall": (0.70, 1.0)}
    for sector in s["sectors"]:
        painting = np.asarray(Image.open(ROOT / sector["painting"]).convert("RGB")).astype(np.float32)
        ph, pw = painting.shape[:2]
        for layer in LAYERS:
            cfg = s["layers"][layer]
            b0, b1 = bands[layer]
            band = painting[int(ph * b0) : int(ph * b1)]
            sheet = np.zeros((lh * sx, lw * n * sx, 3), dtype=np.float32)
            sheet[:] = VOID
            for v in range(n):
                rng = np.random.default_rng(stable_seed("texture", sector["id"], layer, v))
                bw = lw * sx
                x0 = int(rng.integers(0, pw - bw))
                tile = band[:, x0 : x0 + bw]
                # Stack the band, alternating vertical flips, to fill the strip.
                reps = []
                k = 0
                while sum(r.shape[0] for r in reps) < lh * sx:
                    reps.append(tile if k % 2 == 0 else tile[::-1])
                    k += 1
                tex = np.concatenate(reps, axis=0)[: lh * sx]
                tex = tex * min(3.0, 0.30 / max(1e-3, float((tex @ np.array([0.2126, 0.7152, 0.0722])).mean() / 255)))
                top, face, rim = layer_masks(sector["id"], layer, v, lh, lw, cfg)
                up = lambda m: np.kron(m, np.ones((sx, sx), dtype=bool))
                block = np.zeros((lh * sx, bw, 3), dtype=np.float32)
                block[:] = VOID
                block[up(top)] = tex[up(top)]
                block[up(face)] = tex[up(face)] * 0.35
                block[up(rim)] = np.minimum(tex[up(rim)] * 1.6 + 20, 255)
                sheet[:, v * bw : (v + 1) * bw] = block
            img = Image.fromarray(np.clip(sheet, 0, 255).astype(np.uint8))
            img.save(WORK / "inputs" / f"{sector['id']}-{layer}-layout.png")
    W, H = st["sheet_px"]
    band = st["seam_band_px"]
    mask = np.zeros((H, W), dtype=np.uint8)
    mask[H // 2 - band // 2 : H // 2 + band // 2] = 255
    Image.fromarray(mask).convert("RGB").save(WORK / "inputs" / "seam-mask.png")
    Image.fromarray(mask.T.copy()).convert("RGB").save(WORK / "inputs" / "seam-mask-v.png")
    plane_layouts(s)
    print("layouts ->", WORK / "inputs")


def plane_layouts(s) -> None:
    """Ground-plane img2img inputs: the sector painting's foreground band,
    mirrored into a square so the generator starts from that world's
    materials; the workflow then makes it seamless in x and y."""
    W, H = s["plane"]["sheet_px"]
    for sector in s["sectors"]:
        painting = np.asarray(Image.open(ROOT / sector["painting"]).convert("RGB")).astype(np.float32)
        ph, pw = painting.shape[:2]
        band = painting[int(ph * 0.72) :]
        band = np.asarray(Image.fromarray(band.astype(np.uint8)).resize((W // 2, band.shape[0] * W // 2 // pw),
                                                                        Image.Resampling.BOX)).astype(np.float32)
        row = np.concatenate([band, band[:, ::-1]], axis=1)
        reps, k = [], 0
        while sum(r.shape[0] for r in reps) < H:
            reps.append(row if k % 2 == 0 else row[::-1])
            k += 1
        tex = np.concatenate(reps, axis=0)[:H]
        tex = tex * min(3.0, 0.26 / max(1e-3, float((tex @ np.array([0.2126, 0.7152, 0.0722])).mean() / 255)))
        Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8)).save(WORK / "inputs" / f"{sector['id']}-plane-layout.png")


# --------------------------------------------------------------------------
# Jobs, HTTP backend and ingest
# --------------------------------------------------------------------------


def job_list() -> list[dict]:
    s = spec()
    st = s["strip"]
    jobs = []
    neg = s["negative_prompt"]
    for si, sector in enumerate(s["sectors"]):
        base = sector["seed"]
        for li, layer in enumerate(LAYERS):
            seed = base + li * 10
            jobs.append({
                "id": f"strip/{sector['id']}/{layer}",
                "kind": "strip",
                "workflow": st["workflow"],
                "inputs": {"init_image": str(WORK / "inputs" / f"{sector['id']}-{layer}-layout.png"),
                           "mask": str(WORK / "inputs" / "seam-mask.png")},
                "strength": st["strength"],
                "overrides": {
                    "prompt": f"{s['style_prompt']}, vertical canyon rim terrain strips with sheer cliff walls dropping into a black abyss, {sector['layers'][layer]}",
                    "negative_prompt": neg,
                    "$node:12.seed": seed,
                    "$node:22.seed": seed + 1,
                    "$node:22.denoise": st["seam_strength"],
                },
            })
        pl = s["plane"]
        jobs.append({
            "id": f"plane/{sector['id']}",
            "kind": "plane",
            "workflow": pl["workflow"],
            "inputs": {"init_image": str(WORK / "inputs" / f"{sector['id']}-plane-layout.png"),
                       "mask": str(WORK / "inputs" / "seam-mask.png"),
                       "mask_v": str(WORK / "inputs" / "seam-mask-v.png")},
            "strength": pl["strength"],
            "overrides": {
                "prompt": f"{s['style_prompt']}, {sector['plane']}",
                "negative_prompt": neg,
                "$node:12.seed": base + 50,
                "$node:22.seed": base + 51,
                "$node:32.seed": base + 52,
                "$node:22.denoise": pl["seam_strength"],
                "$node:32.denoise": pl["seam_strength"],
            },
        })
        for pi, prop in enumerate(sector["props"]):
            jobs.append(_sprite_job(s, sector, f"prop/{sector['id']}/{prop['id']}", prop["prompt"], base + 100 + pi, s["landmark_prompt"]))
        for ri, route in enumerate(sector["routes"]):
            for li, lm in enumerate(route["landmarks"]):
                jobs.append(_sprite_job(s, sector, f"landmark/{sector['id']}/{ri}/{lm['id']}", lm["prompt"], base + 200 + ri * 10 + li + lm.get("seed_offset", 0) * 1000, s["landmark_prompt"], lm.get("negative_extra")))
        for ci, cr in enumerate(sector["creatures"]):
            jobs.append(_sprite_job(s, sector, f"creature/{sector['id']}/{cr['id']}", cr["prompt"], base + 400 + ci, s["creature_prompt"]))
    return jobs


def _sprite_job(s, sector, jid, prompt, seed, kind_prompt, negative_extra=None):
    return {
        "id": jid,
        "kind": jid.split("/")[0],
        "workflow": s["sprite"]["workflow"],
        "inputs": {},
        "overrides": {
            "prompt": f"pixel art, {kind_prompt}, {prompt}, dark night palette, crisp pixels, transparent background",
            # Wrecked hulls, transports and flagships are legitimate sprite
            # subjects; only the terrain strips forbid spacecraft.
            "negative_prompt": s["negative_prompt"].replace("spaceship, airplane, ", "")
            + (f", {negative_extra}" if negative_extra else ""),
            "seed": seed,
        },
    }


def cmd_jobs(args) -> None:
    jobs = job_list()
    out = Path(args.out) if args.out else WORK / "jobs.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(jobs, indent=1))
    print(f"{len(jobs)} jobs -> {out}")


def _http_json(url, data=None):
    req = urllib.request.Request(url, data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def _upload(url, path: Path) -> str:
    boundary = "----flyover" + hashlib.md5(str(path).encode()).hexdigest()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{path.name}\"\r\n"
            f"Content-Type: image/png\r\n\r\n").encode() + path.read_bytes() + \
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--{boundary}--\r\n".encode()
    req = urllib.request.Request(url + "/upload/image", data=body,
                                 headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["name"]


def bind_workflow(job: dict, uploaded: dict) -> dict:
    wf = json.loads((ROOT / job["workflow"]).read_text())
    for nid, node in wf.items():
        title = node.get("_meta", {}).get("title", "")
        ins = node["inputs"]
        if title == "$prompt":
            ins["text"] = job["overrides"]["prompt"]
        elif title == "$negative_prompt":
            ins["text"] = job["overrides"]["negative_prompt"]
        elif title == "$seed" and "seed" in job["overrides"]:
            ins["seed"] = job["overrides"]["seed"]
        elif title == "$strength" and "strength" in job:
            ins["denoise"] = job["strength"]
        if node["class_type"] == "LoadImage" and str(ins.get("image", "")).startswith("$"):
            ins["image"] = uploaded[ins["image"][1:]]
    for key, val in job["overrides"].items():
        if key.startswith("$node:"):
            nid, inp = key[6:].split(".")
            wf[nid]["inputs"][inp] = val
    return wf


def cmd_run(args) -> None:
    """Direct ComfyUI HTTP backend: same jobs, same workflows, same seeds."""
    url = args.url.rstrip("/")
    jobs = json.loads(Path(args.jobs or WORK / "jobs.json").read_text())
    results = {}
    for job in jobs:
        if args.only and not job["id"].startswith(tuple(args.only.split(","))):
            continue
        uploaded = {k: _upload(url, Path(v)) for k, v in job["inputs"].items()}
        wf = bind_workflow(job, uploaded)
        pid = _http_json(url + "/prompt", {"prompt": wf})["prompt_id"]
        while True:
            hist = _http_json(url + f"/history/{pid}")
            if pid in hist:
                break
            time.sleep(2)
        paths = []
        dest = WORK / "http" / job["id"].replace("/", "__")
        shutil.rmtree(dest, ignore_errors=True)
        dest.mkdir(parents=True, exist_ok=True)
        for node_out in hist[pid]["outputs"].values():
            for im in node_out.get("images", []):
                q = urllib.parse.urlencode({"filename": im["filename"], "subfolder": im["subfolder"], "type": im["type"]})
                p = dest / im["filename"]
                with urllib.request.urlopen(url + "/view?" + q) as r:
                    p.write_bytes(r.read())
                paths.append(str(p))
        (dest / "job.json").write_text(json.dumps(job, indent=1))
        results[job["id"]] = sorted(paths)
        print(job["id"], len(paths))
    out = Path(args.results or WORK / "results.json")
    old = json.loads(out.read_text()) if out.exists() else {}
    old.update(results)
    out.write_text(json.dumps(old, indent=1))


def cmd_ingest(args) -> None:
    """results.json: {job id: [output paths]} (from studio.run_workflow or run)."""
    if args.results:
        results = json.loads(Path(args.results).read_text())
    else:  # everything the HTTP backend has downloaded so far
        results = {d.name.replace("__", "/"): [str(p) for p in d.glob("*.png")]
                   for d in sorted((WORK / "http").iterdir()) if d.is_dir()}
    jobs = {j["id"]: j for j in job_list()}
    runs = json.loads(RUNS_PATH.read_text()) if RUNS_PATH.exists() else {}
    for jid, paths in results.items():
        if jid not in jobs:  # outputs of a job the spec no longer contains
            print("skip stale", jid)
            continue
        dest = RAW / jid
        shutil.rmtree(dest, ignore_errors=True)
        dest.mkdir(parents=True, exist_ok=True)
        entry = {"workflow": jobs[jid]["workflow"], "overrides": jobs[jid]["overrides"],
                 "strength": jobs[jid].get("strength"), "outputs": []}
        for p in sorted(paths):
            p = Path(p)
            # Keep the studio's SaveImage node id prefix (e.g. 10_ rgb / 12_ alpha).
            target = dest / p.name
            shutil.copyfile(p, target)
            prov = Path(str(p) + ".provenance.json")
            models = []
            if prov.exists():
                try:
                    models = [m.get("file", m) if isinstance(m, dict) else m
                              for m in json.loads(prov.read_text()).get("models", [])]
                except Exception:
                    pass
            if not models:
                wf = json.loads((ROOT / jobs[jid]["workflow"]).read_text())
                models = sorted({v for n in wf.values() for k, v in n["inputs"].items()
                                 if k in ("ckpt_name", "lora_name") and isinstance(v, str)})
                if any(n["class_type"] == "LayeredDiffusionApply" for n in wf.values()):
                    models += ["layer_xl_transparent_conv.safetensors", "vae_transparent_decoder.safetensors"]
            entry["outputs"].append({"file": p.name, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                                     "models": models})
        runs[jid] = entry
    RUNS_PATH.write_text(json.dumps(dict(sorted(runs.items())), indent=1) + "\n")
    print("ingested", len(results))


# --------------------------------------------------------------------------
# Processing
# --------------------------------------------------------------------------


def raw_files(jid: str) -> list[Path]:
    d = RAW / jid
    return sorted(d.glob("*.png")) if d.exists() else []


def process_strips(s, sector, pal) -> dict:
    st = s["strip"]
    lw, lh = st["logical"]
    n = st["variants"]
    out = {}
    for layer in LAYERS:
        cfg = s["layers"][layer]
        files = raw_files(f"strip/{sector['id']}/{layer}")
        if not files:
            print("missing strip", sector["id"], layer)
            continue
        img = Image.open(files[-1]).convert("RGB").resize((lw * n, lh), Image.Resampling.BOX)
        arr = np.asarray(img).astype(np.float32)
        # The workflow rolled the sheet by half its height to repaint the seam.
        arr = np.roll(arr, -lh // 2, axis=0)
        lum = arr @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32) / 255
        q = quantise(arr, pal, cfg["luma_cap"], chroma=cfg.get("chroma_cap", 1.0))
        strips = []
        for v in range(n):
            top, face, _ = layer_masks(sector["id"], layer, v, lh, lw, cfg)
            layout = top | face
            # Alpha follows the generated cliffs (non-void pixels) but stays
            # inside a dilated layout and fills the layout's interior, so the
            # bank always reaches the screen edge and never the central lane.
            solid = lum[:, v * lw : (v + 1) * lw] > 0.085
            if cfg.get("broken"):
                # Slim walls keep their detached boulders; only specks go.
                alpha_m = (solid & _dilate(layout, 2)) | _erode(layout, 3)
                alpha_m = _drop_specks(alpha_m, 6)
            else:
                alpha_m = (solid & _dilate(layout, 3)) | _erode(layout, 6)
                alpha_m = _keep_left_connected(alpha_m)
            block = q[:, v * lw : (v + 1) * lw].astype(np.float32)
            # Inner rim: one-pixel lit lip where the top surface meets the drop.
            rim = alpha_m & ~np.roll(alpha_m, -1, axis=1)
            rim[:, -1] = alpha_m[:, -1]
            block[rim] = np.minimum(block[rim] * 1.25 + 4, 255)
            alpha = alpha_m.astype(np.uint8) * int(255 * cfg["alpha"])
            rgba = np.dstack([np.clip(block, 0, 255).astype(np.uint8), alpha])
            rgba[alpha == 0] = 0
            real_edge = [int(np.where(row)[0].max()) + 1 if row.any() else 0 for row in alpha_m]
            strips.append({"rgba": rgba, "edge": real_edge})
        out[layer] = strips
    return out


def _drop_specks(m: np.ndarray, min_px: int) -> np.ndarray:
    """Remove 4-connected components smaller than min_px (vertical wrap)."""
    h, w = m.shape
    seen = np.zeros_like(m)
    out = m.copy()
    for y0 in range(h):
        for x0 in range(w):
            if not m[y0, x0] or seen[y0, x0]:
                continue
            stack, comp = [(y0, x0)], []
            seen[y0, x0] = True
            while stack:
                y, x = stack.pop()
                comp.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = (y + dy) % h, x + dx
                    if 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(comp) < min_px:
                for y, x in comp:
                    out[y, x] = False
    return out


def process_plane(s, sector, pal):
    """Ground plane: 2-D seamless tile, un-rolled in x and y, quantised dark."""
    files = raw_files(f"plane/{sector['id']}")
    if not files:
        print("missing plane", sector["id"])
        return None
    n = s["plane"]["logical"]
    arr = np.asarray(Image.open(files[-1]).convert("RGB").resize((n, n), Image.Resampling.BOX)).astype(np.float32)
    arr = np.roll(np.roll(arr, -n // 2, axis=0), -n // 2, axis=1)
    # Macro tile: repeat the seamless tile and modulate it with smooth,
    # periodic low-frequency light so the receding plane does not show a
    # regular grid of identical tiles toward the horizon.
    reps = s["plane"].get("macro", 4)
    big = np.tile(arr, (reps, reps, 1))
    N = n * reps
    rng = np.random.default_rng(stable_seed("macro", sector["id"]))
    yy, xx = np.mgrid[0:N, 0:N] / N
    mod = np.zeros((N, N))
    for fx, fy in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (3, 2), (2, 3)):
        mod += rng.uniform(.4, 1) / (fx + fy) * np.sin(2 * np.pi * (fx * xx + fy * yy + rng.random()))
    mod /= np.abs(mod).max()
    big = big * (1 + s["plane"].get("macro_amp", .4) * mod)[..., None]
    q = quantise(big, pal, s["plane"]["luma_cap"], chroma=s["plane"]["chroma_cap"])
    return np.dstack([q, np.full(q.shape[:2], 255, dtype=np.uint8)])


def _dilate(m: np.ndarray, r: int) -> np.ndarray:
    out = m.copy()
    for _ in range(r):
        grown = out.copy()
        grown |= np.roll(out, 1, 0) | np.roll(out, -1, 0)  # vertical wrap: strips tile
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def _erode(m: np.ndarray, r: int) -> np.ndarray:
    out = m.copy()
    for _ in range(r):
        shrunk = out & np.roll(out, 1, 0) & np.roll(out, -1, 0)
        shrunk[:, 1:] &= out[:, :-1]
        shrunk[:, :-1] &= out[:, 1:]
        out = shrunk
    return out


def _keep_left_connected(m: np.ndarray) -> np.ndarray:
    """Drop floating islands: keep pixels 4-connected to the outer (left) edge."""
    keep = np.zeros_like(m)
    keep[:, 0] = m[:, 0]
    while True:
        grown = keep.copy()
        grown |= np.roll(keep, 1, 0) | np.roll(keep, -1, 0)
        grown[:, 1:] |= keep[:, :-1]
        grown[:, :-1] |= keep[:, 1:]
        grown &= m
        if (grown == keep).all():
            return keep
        keep = grown


def alpha_bbox(a: np.ndarray, thr=128):
    ys, xs = np.where(a >= thr)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def load_sprite_raw(jid):
    files = raw_files(jid)
    # studio.run_workflow names outputs by SaveImage node id (10_/12_);
    # the HTTP backend keeps the workflow's filename prefixes.
    rgb = [f for f in files if f.name.startswith(("10_", "sprite-rgb"))]
    al = [f for f in files if f.name.startswith(("12_", "sprite-alpha"))]
    if not rgb or not al:
        return None
    return Image.open(rgb[0]).convert("RGB"), Image.open(al[0]).convert("L")


def process_sprite(jid, target_h, pal, cap, max_w=None, chroma=1.0):
    loaded = load_sprite_raw(jid)
    if loaded is None:
        print("missing sprite", jid)
        return None
    rgb, al = loaded
    a = np.asarray(al)
    # Keep the largest solid area only: drop stray specks LayerDiffuse leaves.
    bb = alpha_bbox(a, 140)
    if bb is None:
        return None
    x0, y0, x1, y1 = bb
    rgb = rgb.crop(bb)
    al = al.crop(bb)
    h = target_h
    w = max(3, round((x1 - x0) / (y1 - y0) * h))
    if max_w and w > max_w:
        h = max(3, round(h * max_w / w))
        w = max_w
    rgb_s = np.asarray(rgb.resize((w, h), Image.Resampling.BOX)).astype(np.float32)
    al_s = np.asarray(al.resize((w, h), Image.Resampling.BOX))
    q = quantise(rgb_s, pal, cap, lift=1.0, chroma=chroma)
    alpha = np.where(al_s >= 120, 255, 0).astype(np.uint8)
    # Despeckle isolated alpha pixels.
    nb = sum(np.roll(np.roll(alpha > 0, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    alpha[(alpha > 0) & (nb <= 1)] = 0
    rgba = np.dstack([q, alpha])
    rgba[alpha == 0] = 0
    return rgba


def outline(rgba: np.ndarray, pal: np.ndarray) -> np.ndarray:
    """One-pixel outline in the palette's darkest colour, so tiny creatures
    separate from the bank texture without being brightened."""
    a = rgba[..., 3] > 0
    padded = np.zeros((rgba.shape[0] + 2, rgba.shape[1] + 2, 4), dtype=np.uint8)
    padded[1:-1, 1:-1] = rgba
    pa = np.zeros(padded.shape[:2], dtype=bool)
    pa[1:-1, 1:-1] = a
    ring = (np.roll(pa, 1, 0) | np.roll(pa, -1, 0) | np.roll(pa, 1, 1) | np.roll(pa, -1, 1)) & ~pa
    dark = pal[np.argmin(pal.sum(1))].astype(np.uint8)
    padded[ring, :3] = dark
    padded[ring, 3] = 255
    # Faint rim light: outline pixels lit from the upper left (the style
    # guide's key light) take a muted light palette colour.
    pl = pal @ np.array([0.2126, 0.7152, 0.0722]) / 255
    pc = (pal.max(1) - pal.min(1)) / 255
    ok = (pl <= 0.58) & (pc <= 0.34)
    cand = np.where(ok)[0]
    light = pal[cand[np.argmax(pl[cand])]].astype(np.uint8) if len(cand) else dark
    lit = ring & (np.roll(pa, 1, 0) | np.roll(pa, 1, 1)) & ~(np.roll(pa, -1, 0) | np.roll(pa, -1, 1))
    padded[lit, :3] = light
    return padded


def creature_frames(base: np.ndarray, gait: str) -> list[np.ndarray]:
    """Discrete pixel frames from one generated creature pose.

    0-3 walk/crawl cycle, 4-5 duck (flattened, eyes hidden), 6-7 burrow/hide
    (sinking into a dirt mound)."""
    h, w, _ = base.shape
    pad = 2
    canvas = lambda: np.zeros((h + pad, w + 2, 4), dtype=np.uint8)
    frames = []
    legs = max(2, h // 3)
    for f in range(4):
        c = canvas()
        bob = 1 if (gait == "walk" and f % 2 == 1) else 0
        body = base.copy()
        if gait == "crawl":
            # Peristaltic crawl: columns ripple by one pixel.
            body = np.zeros_like(base)
            for x in range(w):
                dy = 1 if ((x // 2 + f) % 4) < 2 else 0
                if dy:
                    body[1:, x] = base[:-1, x]
                else:
                    body[:, x] = base[:, x]
            c[pad - 1 : pad - 1 + h, 1 : 1 + w] = body
        else:
            c[pad - bob : pad - bob + h - legs, 1 : 1 + w] = base[: h - legs]
            lower = base[h - legs :]
            half = w // 2
            shift = 1 if f in (1, 2) else -1
            if gait == "burrow":
                shift = 1 if f % 2 else 0
            left = np.roll(lower[:, :half], shift, axis=1)
            right = np.roll(lower[:, half:], -shift, axis=1)
            c[pad + h - legs : pad + h, 1 : 1 + half] = left
            c[pad + h - legs : pad + h, 1 + half : 1 + w] = right
        frames.append(c)
    dark = base[..., :3].astype(np.float32)
    for f in range(2):
        c = canvas()
        sh = max(2, int(h * (0.62 if f == 0 else 0.45)))
        squashed = np.asarray(Image.fromarray(base).resize((w + 2, sh), Image.Resampling.NEAREST))
        sq = squashed.copy()
        sq[..., :3] = (sq[..., :3] * 0.72).astype(np.uint8)
        c[h + pad - sh : h + pad, 0 : w + 2] = sq
        frames.append(c)
    mound = np.array([0, 0, 0, 0], dtype=np.uint8)
    for f in range(2):
        c = canvas()
        visible = max(1, int(h * (0.5 if f == 0 else 0.15)))
        c[h + pad - visible : h + pad, 1 : 1 + w] = base[:visible]
        # dirt mound rim from the creature's darkest opaque colour
        op = base[..., 3] > 0
        if op.any():
            darkest = base[op][np.argmin(base[op][:, :3].sum(1))]
            mound = darkest.copy()
        c[h + pad - 1, 0 : w + 2] = mound
        c[h + pad - 2, 2 : w] = mound
        frames.append(c)
    return frames


def cmd_process(_args) -> dict:
    s = spec()
    result = {"sectors": []}
    for si, sector in enumerate(s["sectors"]):
        pal = load_palette(sector["id"])
        sec = {"id": sector["id"], "strips": process_strips(s, sector, pal),
               "plane": process_plane(s, sector, pal),
               "props": [], "landmarks": [], "creatures": []}
        for prop in sector["props"]:
            r = process_sprite(f"prop/{sector['id']}/{prop['id']}", prop["h"], pal, 0.34, max_w=30, chroma=0.36)
            if r is not None:
                sec["props"].append({"id": prop["id"], "rgba": r})
        for ri, route in enumerate(sector["routes"]):
            for lm in route["landmarks"]:
                r = process_sprite(f"landmark/{sector['id']}/{ri}/{lm['id']}", round(lm["h"] * s["sprite"].get("landmark_scale", 1.0)), pal, 0.40, max_w=62, chroma=0.42)
                if r is not None:
                    sec["landmarks"].append({"id": lm["id"], "route": ri, "rgba": r})
        for cr in sector["creatures"]:
            r = process_sprite(f"creature/{sector['id']}/{cr['id']}", cr["h"], pal, 0.42, max_w=cr["h"] + 5, chroma=0.34)
            if r is not None:
                r = outline(r, pal)
                sec["creatures"].append({"id": cr["id"], "gait": cr["gait"], "frames": creature_frames(r, cr["gait"])})
        result["sectors"].append(sec)
    return result


# --------------------------------------------------------------------------
# Packing
# --------------------------------------------------------------------------


def shelf_pack(items, width):
    """Deterministic shelf packing, tallest first; returns positions and height."""
    order = sorted(range(len(items)), key=lambda i: (-items[i].shape[0], i))
    x = y = shelf = 0
    pos = [None] * len(items)
    for i in order:
        h, w = items[i].shape[:2]
        if x + w + 1 > width:
            x = 0
            y += shelf + 1
            shelf = 0
        pos[i] = (x, y)
        x += w + 1
        shelf = max(shelf, h)
    return pos, y + shelf


def cmd_pack(args) -> None:
    s = spec()
    data = cmd_process(args)
    st = s["strip"]
    lw, lh = st["logical"]
    n = st["variants"]
    dart_sectors = []
    sprite_items, sprite_meta = [], []
    creature_items, creature_meta = [], []
    for si, sec in enumerate(data["sectors"]):
        # Columns 0..n-1 are left banks; n..2n-1 are their mirrors for the
        # right bank (Canvas.drawAtlas cannot flip, and one call per layer
        # keeps the runtime batched).
        sheet = np.zeros((lh * len(LAYERS), lw * n * 2, 4), dtype=np.uint8)
        edges = []
        for li, layer in enumerate(LAYERS):
            strips = sec["strips"].get(layer, [])
            layer_edges = []
            for v, strip in enumerate(strips):
                sheet[li * lh : (li + 1) * lh, v * lw : (v + 1) * lw] = strip["rgba"]
                sheet[li * lh : (li + 1) * lh, (n + v) * lw : (n + v + 1) * lw] = strip["rgba"][:, ::-1]
                layer_edges.append(strip["edge"])
            edges.append(layer_edges)
        Image.fromarray(sheet, "RGBA").save(ASSETS / f"flyover-{sec['id']}.png", optimize=True)
        if sec["plane"] is not None:
            # Palette PNG: the tile only uses the sector palette (<= 43 colours).
            Image.fromarray(sec["plane"][..., :3], "RGB").convert("P", palette=Image.Palette.ADAPTIVE, colors=256).save(ASSETS / f"flyover-{sec['id']}-ground.png", optimize=True)
        dart_sectors.append({"id": sec["id"], "edges": edges})
        for p in sec["props"]:
            sprite_items.append(p["rgba"])
            sprite_meta.append((si, -1, p["id"]))
        for lm in sec["landmarks"]:
            sprite_items.append(lm["rgba"])
            sprite_meta.append((si, lm["route"], lm["id"]))
        for ci, cr in enumerate(sec["creatures"]):
            # Frames facing right, then the same frames mirrored (facing left).
            strip = np.concatenate(cr["frames"] + [f[:, ::-1] for f in cr["frames"]], axis=1)
            creature_items.append(strip)
            creature_meta.append((si, cr["id"], cr["gait"], cr["frames"][0].shape[1], cr["frames"][0].shape[0], len(cr["frames"])))
    pos, height = shelf_pack(sprite_items, 512)
    atlas = np.zeros((height, 512, 4), dtype=np.uint8)
    for item, (x, y) in zip(sprite_items, pos):
        h, w = item.shape[:2]
        atlas[y : y + h, x : x + w] = item
    Image.fromarray(atlas, "RGBA").save(ASSETS / "flyover-props.png", optimize=True)
    cw = max(i.shape[1] for i in creature_items)
    ch = sum(i.shape[0] + 1 for i in creature_items)
    catlas = np.zeros((ch, cw, 4), dtype=np.uint8)
    cy = 0
    cpos = []
    for item in creature_items:
        h, w = item.shape[:2]
        catlas[cy : cy + h, :w] = item
        cpos.append(cy)
        cy += h + 1
    Image.fromarray(catlas, "RGBA").save(ASSETS / "flyover-creatures.png", optimize=True)
    write_dart(s, dart_sectors, sprite_items, sprite_meta, pos, creature_meta, cpos)
    contact(data, s)
    print("packed", len(sprite_items), "sprites", len(creature_items), "creatures")


def write_dart(s, sectors, items, meta, pos, cmeta, cpos):
    lw, lh = s["strip"]["logical"]
    lines = [
        "// GENERATED by tools/flyover_assets.py pack — do not edit by hand.",
        "// Source: art/families/flyover-backgrounds.json and art/workflows/backgrounds/.",
        "",
        "/// One sprite inside assets/images/flyover-props.png (logical pixels).",
        "class FlyoverSprite {",
        "  const FlyoverSprite(this.sector, this.route, this.id, this.x, this.y, this.w, this.h);",
        "  final int sector, route;",
        "  final String id;",
        "  final int x, y, w, h;",
        "}",
        "",
        "/// One creature row inside assets/images/flyover-creatures.png.",
        "class FlyoverCreature {",
        "  const FlyoverCreature(this.sector, this.id, this.gait, this.y, this.w, this.h, this.frames);",
        "  final int sector;",
        "  final String id, gait;",
        "  final int y, w, h, frames;",
        "}",
        "",
        "abstract final class FlyoverAtlas {",
        f"  static const stripWidth = {lw}, stripHeight = {lh}, variants = {s['strip']['variants']};",
        "  static const layers = ['mid', 'near', 'ground'];",
        "  static const layerSpeeds = [" + ", ".join(str(s["layers"][l]["speed"]) for l in LAYERS) + "];",
        "  /// Widest bank per layer (logical px): strips are drawn cropped to it.",
        "  static const layerWidths = [" + ", ".join(
            str(min(lw, 1 + max([max(e) for sec in sectors for e in sec["edges"][li]] or [lw])))
            for li in range(len(LAYERS))) + "];",
        "  static const sectors = [" + ", ".join(f"'{x['id']}'" for x in sectors) + "];",
        "  /// Bank edge (logical x) for each sector/layer/variant/row; strips are left banks.",
        "  static const edges = <List<List<String>>>[",
    ]
    for sec in sectors:
        lines.append("    [")
        for layer_edges in sec["edges"]:
            enc = ", ".join("r'" + "".join(chr(48 + e) for e in edge) + "'" for edge in layer_edges)
            lines.append(f"      [{enc}],")
        lines.append("    ],")
    lines.append("  ];")
    lines.append("  static const sprites = <FlyoverSprite>[")
    for (si, route, sid), item, (x, y) in zip(meta, items, pos):
        h, w = item.shape[:2]
        lines.append(f"    FlyoverSprite({si}, {route}, '{sid}', {x}, {y}, {w}, {h}),")
    lines.append("  ];")
    lines.append("  static const creatures = <FlyoverCreature>[")
    for (si, cid, gait, w, h, nf), y in zip(cmeta, cpos):
        lines.append(f"    FlyoverCreature({si}, '{cid}', '{gait}', {y}, {w}, {h}, {nf}),")
    lines.append("  ];")
    lines.append("}")
    DART_OUT.write_text("\n".join(lines) + "\n")


def landmark_sheet(data) -> None:
    """Route identity review: rows = sectors, columns = routes (two landmarks
    each) followed by the sector's props and first creature frames, 3x."""
    cell_w, cell_h = 140, 80
    sheet = np.zeros((cell_h * len(data["sectors"]), cell_w * 5 + 330, 4), dtype=np.uint8)
    sheet[..., :3] = (14, 16, 26)
    sheet[..., 3] = 255

    def put(sp, x, y):
        h, w = sp.shape[:2]
        h, w = min(h, sheet.shape[0] - y), min(w, sheet.shape[1] - x)
        if h <= 0 or w <= 0:
            return
        a = sp[:h, :w, 3:4] / 255
        sheet[y : y + h, x : x + w, :3] = (sp[:h, :w, :3] * a + sheet[y : y + h, x : x + w, :3] * (1 - a)).astype(np.uint8)

    for si, sec in enumerate(data["sectors"]):
        for route in range(5):
            x = route * cell_w + 2
            for lm in [l for l in sec["landmarks"] if l["route"] == route]:
                put(lm["rgba"], x, si * cell_h + cell_h - 2 - lm["rgba"].shape[0])
                x += lm["rgba"].shape[1] + 3
            sheet[si * cell_h : (si + 1) * cell_h, route * cell_w, :3] = (40, 44, 60)
        x = 5 * cell_w + 2
        for p in sec["props"]:
            put(p["rgba"], x, si * cell_h + 4)
            x += p["rgba"].shape[1] + 2
        x = 5 * cell_w + 2
        for cr in sec["creatures"]:
            for f in cr["frames"]:
                put(f, x, si * cell_h + cell_h - 2 - f.shape[0])
                x += f.shape[1] + 1
    img = Image.fromarray(sheet, "RGBA").convert("RGB")
    img = img.resize((img.width * 3, img.height * 3), Image.Resampling.NEAREST)
    img.save(CONTACT_OUT.with_name("flyover-landmarks.png"), optimize=True)


def contact(data, s) -> None:
    landmark_sheet(data)
    """Contact sheet: per sector row, strips (tiled twice) + sprites + creature frames, 2x."""
    rows = []
    lw, lh = s["strip"]["logical"]
    for sec in data["sectors"]:
        parts = []
        for layer in LAYERS:
            for strip in sec["strips"].get(layer, []):
                parts.append(np.concatenate([strip["rgba"], strip["rgba"]], axis=0))
        if sec.get("plane") is not None:
            # A crop of the ground macro tile, stacked twice to show its seam.
            row2 = sec["plane"][:192, :384]
            parts.append(np.concatenate([row2, row2], axis=0))
        sprites =[p["rgba"] for p in sec["props"]] + [l["rgba"] for l in sec["landmarks"]]
        for cr in sec["creatures"]:
            sprites.append(np.concatenate(cr["frames"], axis=1))
        H = lh * 2
        x = 0
        width = sum(p.shape[1] + 2 for p in parts) + 360
        row = np.zeros((H, width, 4), dtype=np.uint8)
        row[..., :3] = (18, 20, 30)
        row[..., 3] = 255
        for p in parts:
            h, w = p.shape[:2]
            a = p[..., 3:4] / 255
            row[:h, x : x + w, :3] = (p[..., :3] * a + row[:h, x : x + w, :3] * (1 - a)).astype(np.uint8)
            x += w + 2
        sx, sy, shelf = x + 4, 0, 0
        for sp in sprites:
            h, w = sp.shape[:2]
            if sx + w > width:
                sx, sy = x + 4, sy + shelf + 2
                shelf = 0
            if sy + h > H:
                break
            a = sp[..., 3:4] / 255
            row[sy : sy + h, sx : sx + w, :3] = (sp[..., :3] * a + row[sy : sy + h, sx : sx + w, :3] * (1 - a)).astype(np.uint8)
            sx += w + 2
            shelf = max(shelf, h)
        rows.append(row)
    W = max(r.shape[1] for r in rows)
    sheet = np.zeros((sum(r.shape[0] + 4 for r in rows), W, 4), dtype=np.uint8)
    sheet[..., 3] = 255
    y = 0
    for r in rows:
        sheet[y : y + r.shape[0], : r.shape[1]] = r
        y += r.shape[0] + 4
    img = Image.fromarray(sheet, "RGBA")
    img = img.resize((img.width * 2, img.height * 2), Image.Resampling.NEAREST)
    CONTACT_OUT.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(CONTACT_OUT, optimize=True)
    print("contact ->", CONTACT_OUT)


def cmd_all(args) -> None:
    cmd_palettes(args)
    cmd_layouts(args)
    cmd_jobs(args)
    cmd_pack(args)


def main(argv=None) -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("palettes")
    sub.add_parser("layouts")
    j = sub.add_parser("jobs")
    j.add_argument("--out")
    r = sub.add_parser("run")
    r.add_argument("--url", default=os.environ.get("COMFY_URL", "http://studio:8188"))
    r.add_argument("--jobs")
    r.add_argument("--results")
    r.add_argument("--only", help="job id prefix filter, e.g. strip/krybor")
    i = sub.add_parser("ingest")
    i.add_argument("--results", help="results JSON; default: scan the HTTP backend downloads")
    sub.add_parser("process")
    sub.add_parser("pack")
    a = sub.add_parser("all")
    a.add_argument("--out")
    args = p.parse_args(argv)
    {"palettes": cmd_palettes, "layouts": cmd_layouts, "jobs": cmd_jobs, "run": cmd_run,
     "ingest": cmd_ingest, "process": cmd_process, "pack": cmd_pack, "all": cmd_all}[args.cmd](args)


if __name__ == "__main__":
    main()
