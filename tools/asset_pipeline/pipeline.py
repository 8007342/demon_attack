#!/usr/bin/env python3
"""Local generative asset pipeline: plan -> ingest -> process -> review -> accept -> pack.

Generation itself is pluggable. The current backend is the Forge `image.generate`
MCP tool, which an agent calls from the queue that `plan` writes. `ingest` then
records the tool's JSON responses. A ComfyUI HTTP backend can replace that step
later without changing anything downstream. Every later stage is deterministic
and offline: the same raws, spec and pipeline version give byte-identical layers.

Run with the project venv:  .cache/asset-venv/bin/python tools/asset_pipeline/pipeline.py <cmd> ...
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

PIPELINE_VERSION = 4
ROOT = Path(__file__).resolve().parents[2]
FAMILIES = Path(__file__).resolve().parent / "families"
WEAR_HEAT = ["#9E1B1B", "#E8430C", "#FF6B1A", "#FFBF1F", "#FFE042", "#FFF8DC"]
SOOT = ["#1E2838", "#263345"]


# ---------------------------------------------------------------- utilities
def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hex_rgb(value: str) -> np.ndarray:
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)


def load_json(path: Path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def save_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def family_spec(name: str) -> dict:
    return json.loads((FAMILIES / f"{name}.json").read_text(encoding="utf-8"))


def out_dir(family: str) -> Path:
    return ROOT / "assets/research/asset-pipeline" / family


def review_dir(family: str) -> Path:
    return ROOT / "web/asset-pipeline-review" / family


def part_by_id(spec: dict) -> dict:
    return {p["id"]: p for p in spec["parts"]}


def part_palette(spec: dict, part: dict) -> list[str]:
    return list(dict.fromkeys(spec["base_palette"] + part["accent"]))


# ---------------------------------------------------------------- colour
def srgb_to_oklab(rgb: np.ndarray) -> np.ndarray:
    c = rgb / 255.0
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                   [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    lms = np.cbrt(lin @ m1.T)
    return lms @ m2.T


def snap_to_palette(rgb: np.ndarray, palette: list[str]) -> np.ndarray:
    pal = np.stack([hex_rgb(p) for p in palette])
    lab = srgb_to_oklab(rgb.reshape(-1, 3))
    pal_lab = srgb_to_oklab(pal)
    idx = np.argmin(((lab[:, None, :] - pal_lab[None, :, :]) ** 2).sum(-1), axis=1)
    return pal[idx].reshape(rgb.shape)


# ---------------------------------------------------------------- processing
def isolate(rgb: np.ndarray) -> tuple[np.ndarray, dict]:
    """Separate one object from a flat generated background (estimated from the border)."""
    h, w, _ = rgb.shape
    b = max(4, w // 64)
    border = np.concatenate([rgb[:b].reshape(-1, 3), rgb[-b:].reshape(-1, 3),
                             rgb[:, :b].reshape(-1, 3), rgb[:, -b:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    # Perceptual distance (OKLab, scaled to roughly 0-255) separates hue shifts such as
    # orange-on-salmon far better than raw RGB distance.
    lab = srgb_to_oklab(rgb.reshape(-1, 3)).reshape(h, w, 3) * 255
    bg_lab = srgb_to_oklab(bg[None, :])[0] * 255
    dist = np.linalg.norm(lab - bg_lab, axis=2)
    border_dist = np.concatenate([dist[:b].ravel(), dist[-b:].ravel(), dist[:, :b].ravel(), dist[:, -b:].ravel()])
    noise = float(np.percentile(border_dist, 90))
    thr = max(otsu(dist), noise * 1.25, 12.0)
    mask = dist > thr
    mask = ndimage.binary_opening(mask, iterations=2)
    mask = ndimage.binary_fill_holes(mask)
    labels, n = ndimage.label(mask)
    total = int(mask.sum())
    largest_share = 0.0
    if n:
        sizes = ndimage.sum(mask, labels, range(1, n + 1))
        biggest = sizes.max()
        largest_share = float(biggest / max(total, 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.25 * biggest]
        mask = np.isin(labels, keep)
    # Drop the 1px fringe that carries background colour into the edge pixels.
    mask = ndimage.binary_erosion(mask, iterations=max(1, w // 256))
    edge = np.concatenate([mask[0], mask[-1], mask[:, 0], mask[:, -1]])
    metrics = {
        "background_rgb": [int(v) for v in bg],
        "background_noise": round(noise, 2),
        "coverage": round(float(mask.mean()), 4),
        "components": int(n),
        "largest_component_share": round(largest_share, 3),
        "touches_border": round(float(edge.mean()), 4),
    }
    return mask, metrics


def otsu(values: np.ndarray) -> float:
    hist, edges = np.histogram(values.ravel(), bins=256)
    centers = (edges[:-1] + edges[1:]) / 2
    weight = np.cumsum(hist)
    mean = np.cumsum(hist * centers)
    total, total_mean = weight[-1], mean[-1]
    w1 = total - weight
    valid = (weight > 0) & (w1 > 0)
    between = np.zeros_like(centers)
    between[valid] = (total_mean * weight[valid] - mean[valid] * total) ** 2 / (weight[valid] * w1[valid])
    return float(centers[np.argmax(between)])


def orient_vertical(rgb: np.ndarray, mask: np.ndarray, bg: list[int]) -> tuple[np.ndarray, np.ndarray, float]:
    """Rotate an elongated object so its long axis is vertical with the narrow end (the muzzle) on top.

    FLUX-schnell ignores negative prompts, so "pointing up" alone still yields diagonal or sideways
    cannons. Objects that are not clearly elongated (major/minor axis ratio below 1.4) stay unchanged."""
    ys, xs = np.nonzero(mask)
    if len(xs) < 32:
        return rgb, mask, 0.0
    cov = np.cov(np.vstack([xs - xs.mean(), ys - ys.mean()]))
    vals, vecs = np.linalg.eigh(cov)
    if vals[1] < (1.4 ** 2) * max(vals[0], 1e-6):
        return rgb, mask, 0.0
    major = vecs[:, 1]
    # Angle that turns the major axis onto the image's vertical (PIL rotates counter-clockwise).
    angle = float(np.degrees(np.arctan2(major[0], major[1])))
    def turn(deg: float) -> tuple[np.ndarray, np.ndarray]:
        if abs(deg) < 0.5:
            return rgb, mask
        img = Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).rotate(
            -deg, resample=Image.BICUBIC, expand=True, fillcolor=tuple(int(v) for v in bg))
        m = Image.fromarray((mask * 255).astype(np.uint8)).rotate(-deg, resample=Image.NEAREST, expand=True)
        return np.asarray(img).astype(np.float64), np.asarray(m) > 127
    out_rgb, out_mask = turn(angle)
    ys, xs = np.nonzero(out_mask)
    span = ys.max() - ys.min() + 1
    band = max(1, span // 5)
    top = out_mask[ys.min():ys.min() + band].sum()
    bottom = out_mask[ys.max() + 1 - band:ys.max() + 1].sum()
    if top > bottom:  # the wider end is up: flip so the muzzle points up
        angle += 180.0
        out_rgb, out_mask = turn(angle)
    angle = (angle + 180.0) % 360.0 - 180.0
    return out_rgb, out_mask, round(angle, 1)


def symmetry_iou(mask: np.ndarray) -> float:
    ys, xs = np.nonzero(mask)
    if not len(xs):
        return 0.0
    crop = mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    mirrored = crop[:, ::-1]
    return float((crop & mirrored).sum() / max((crop | mirrored).sum(), 1))


def to_layer(rgb: np.ndarray, mask: np.ndarray, spec: dict, part: dict) -> tuple[np.ndarray, dict]:
    """Crop, symmetrise, downscale into the part's slot, palette-snap, outline, place on canvas."""
    ys, xs = np.nonzero(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop_rgb = rgb[y0:y1, x0:x1].copy()
    crop_a = mask[y0:y1, x0:x1].copy()
    if part["symmetry"] == "mirror-left":
        half = crop_a.shape[1] // 2
        crop_rgb[:, -half:] = crop_rgb[:, :half][:, ::-1]
        crop_a[:, -half:] = crop_a[:, :half][:, ::-1]
    slot = part["slot"]
    tw, th = slot["w"] - 2, slot["h"] - 2  # 1px outline margin each side
    ch, cw = crop_a.shape
    scale = min(tw / cw, th / ch)
    nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
    if part["symmetry"] == "mirror-left" and nw % 2:
        nw = nw - 1 if nw > 1 else 2
    rgba = np.dstack([crop_rgb, crop_a * 255]).astype(np.uint8)
    small = np.asarray(Image.fromarray(rgba, "RGBA").resize((nw, nh), Image.BOX)).astype(np.float64)
    alpha = small[..., 3] >= 110
    if part["symmetry"] == "mirror-left":
        alpha = alpha | alpha[:, ::-1]
    colours = snap_to_palette(small[..., :3], part_palette(spec, part))
    if part["symmetry"] == "mirror-left":
        half = nw // 2
        colours[:, -half:] = colours[:, :half][:, ::-1]
    # Despeckle: drop isolated pixels, fill pinholes.
    n4 = ndimage.convolve(alpha.astype(int), np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]]), mode="constant")
    alpha = (alpha & (n4 > 0)) | (~alpha & (n4 == 4))
    sprite = np.zeros((nh + 2, nw + 2, 4), dtype=np.uint8)
    sprite[1:-1, 1:-1, :3] = colours.astype(np.uint8)
    sprite[1:-1, 1:-1, 3] = alpha * 255
    opaque = sprite[..., 3] > 0
    ring = ndimage.binary_dilation(opaque, structure=ndimage.generate_binary_structure(2, 1)) & ~opaque
    sprite[ring, :3] = hex_rgb(spec["outline"]).astype(np.uint8)
    sprite[ring, 3] = 255
    # Opaque pixels touching transparency also take the outline colour (the 1px rule).
    canvas = np.zeros((spec["canvas"]["height"], spec["canvas"]["width"], 4), dtype=np.uint8)
    sh, sw = sprite.shape[:2]
    cx = slot["x"] + (slot["w"] - sw) / 2
    cy = slot["y"] + (slot["h"] - sh) / 2
    ox, oy = int(round(cx)), int(round(cy))
    paste(canvas, sprite, ox, oy)
    if part["mirror"]:
        paste(canvas, sprite[:, ::-1], spec["canvas"]["width"] - ox - sw, oy)
    fill = float((sprite[..., 3] > 0).sum() / (slot["w"] * slot["h"]))
    colours_used = len({tuple(p) for p in canvas[canvas[..., 3] > 0][:, :3]})
    return canvas, {"slot_fill": round(fill, 3), "sprite_size": [sw, sh], "palette_colours": colours_used}


def paste(canvas: np.ndarray, sprite: np.ndarray, ox: int, oy: int) -> None:
    h, w = sprite.shape[:2]
    region = canvas[oy:oy + h, ox:ox + w]
    m = sprite[..., 3] > 0
    region[m] = sprite[m]


def judge(part: dict, iso: dict, layer: dict, sym: float) -> tuple[str, float, list[str]]:
    reasons, status = [], "PASS"
    if not 0.02 < iso["coverage"] < 0.75:
        reasons.append(f"isolation failed (object covers {iso['coverage']:.0%} of frame)")
        status = "FAIL"
    if iso["touches_border"] > 0.03:
        reasons.append("object touches the image border (cropped or tiled background)")
        status = "FAIL"
    if iso["largest_component_share"] < 0.5:
        reasons.append("not a single object (largest component under half of the mask)")
        status = "FAIL"
    if iso["background_noise"] > 45 and status != "FAIL":
        reasons.append("background is not flat; matte may be unreliable")
        status = "WARN"
    if part["symmetry"] == "mirror-left" and sym < 0.55 and status != "FAIL":
        reasons.append(f"source is asymmetric (IoU {sym:.2f}); mirroring changed its design")
        status = "WARN"
    if layer["slot_fill"] < 0.2 and status != "FAIL":
        reasons.append("silhouette fills little of its slot")
        status = "WARN"
    score = (
        (1.0 if 0.05 < iso["coverage"] < 0.6 else 0.3)
        + iso["largest_component_share"]
        + (1.0 - min(iso["touches_border"] * 10, 1.0))
        + max(0.0, 1.0 - iso["background_noise"] / 90)
        + (sym if part["symmetry"] == "mirror-left" else 0.5)
        + min(layer["slot_fill"] / 0.6, 1.0)
    ) / 6.0
    if status == "FAIL":
        score *= 0.4
    return status, round(score, 3), reasons


# ---------------------------------------------------------------- wear
def derive_wear(layer: np.ndarray, spec: dict, part: dict, state: str) -> np.ndarray:
    """Deterministic fresh/worn/critical variants derived from one accepted layer."""
    if state == "fresh":
        return layer.copy()
    out = layer.copy()
    rng = np.random.default_rng(int(hashlib.sha256(f"{spec['family']}:{part['id']}".encode()).hexdigest()[:8], 16))
    opaque = out[..., 3] > 0
    outline = np.all(out[..., :3] == hex_rgb(spec["outline"]).astype(np.uint8), axis=2)
    interior = opaque & ~outline
    ys, xs = np.nonzero(interior)
    if not len(ys):
        return out
    order = rng.permutation(len(ys))
    # Worn: dulled plating and soot flecks.
    dull = order[: max(1, len(order) * 18 // 100)]
    out[ys[dull], xs[dull], :3] = (out[ys[dull], xs[dull], :3] * 0.62).astype(np.uint8)
    soot = order[len(dull): len(dull) + max(2, len(order) // 25)]
    for i, k in enumerate(soot):
        out[ys[k], xs[k], :3] = hex_rgb(SOOT[i % 2]).astype(np.uint8)
    pal = part_palette(spec, part)
    out[interior, :3] = snap_to_palette(out[interior, :3].astype(np.float64), pal + SOOT).astype(np.uint8)
    if state == "worn":
        return out
    # Critical: accent pixels run hot along the thermal ramp, hottest at the muzzle end.
    accent = [hex_rgb(a) for a in part["accent"]] or [hex_rgb("#39DFCC"), hex_rgb("#70F5D5")]
    is_accent = np.zeros(interior.shape, bool)
    for a in accent:
        is_accent |= np.all(np.abs(layer[..., :3].astype(int) - a.astype(int)) < 2, axis=2)
    hot = interior & is_accent
    top, bottom = ys.min(), ys.max()
    rows = np.arange(out.shape[0])[:, None].repeat(out.shape[1], 1)
    heat = 1.0 - (rows - top) / max(bottom - top, 1)
    lum = layer[..., :3].astype(np.float64) @ np.array([0.3, 0.59, 0.11]) / 255
    # Force-field hardware must never run warm (style guide), so parts may carry their own ramp.
    ramp = part.get("critical_ramp", WEAR_HEAT)
    level = np.clip((0.55 * heat + 0.45 * lum) * (len(ramp) - 1), 0, len(ramp) - 1).round().astype(int)
    for i, colour in enumerate(ramp):
        sel = hot & (level == i)
        out[sel, :3] = hex_rgb(colour).astype(np.uint8)
    cracks = order[-max(2, len(order) // 30):]
    out[ys[cracks], xs[cracks], :3] = hex_rgb(ramp[0]).astype(np.uint8)
    return out


# ---------------------------------------------------------------- commands
def cmd_plan(args) -> None:
    spec = family_spec(args.family)
    tier = spec["generation"]["tiers"][args.tier]
    wanted = set(args.parts.split(",")) if args.parts else None
    queue = []
    for index, part in enumerate(spec["parts"]):
        if wanted and part["id"] not in wanted:
            continue
        queue.append({
            "family": spec["family"], "part": part["id"], "tier": args.tier,
            "prompt": f"{part['prompt']}, {spec['style_prompt']}",
            "negative_prompt": f"{part['negative']}, {spec['style_negative']}",
            "width": part.get("gen_size", {}).get("width", tier["width"]),
            "height": part.get("gen_size", {}).get("height", tier["height"]), "steps": tier["steps"],
            "seed": spec["generation"]["seed_base"] + index * 10 + args.round,
            "count": spec["generation"]["count_per_part"],
        })
    path = out_dir(args.family) / f"queue-{args.tier}.json"
    save_json(path, {"backend": "forge-mcp image.generate", "created": now(), "requests": queue})
    print(json.dumps({"queue": str(path.relative_to(ROOT)), "requests": len(queue)}, indent=2))


def cmd_ingest(args) -> None:
    spec = family_spec(args.family)
    base = out_dir(args.family)
    queue = load_json(base / f"queue-{args.tier}.json", None)
    if queue is None:
        sys.exit(f"run `plan --tier {args.tier}` first")
    by_seed = {r["seed"]: r for r in queue["requests"]}
    runs = load_json(base / "runs.json", {"family": spec["family"], "images": []})
    known = {img["sha256"] for img in runs["images"]}
    added = 0
    for response in json.loads(Path(args.results).read_text(encoding="utf-8")):
        request = by_seed.get(response["seed"])
        if request is None or response.get("tier") != args.tier:
            sys.exit(f"response seed {response['seed']} / tier {response.get('tier')} not in queue {args.tier}")
        for i, image in enumerate(response["images"]):
            src = Path(image["path"])
            digest = sha256(src)
            if digest in known:
                continue
            rel = Path("raw") / request["part"] / f"{args.tier}-s{response['seed']}-{i}.png"
            (base / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, base / rel)
            runs["images"].append({
                "id": f"{request['part']}-{args.tier}-{response['seed']}-{i}",
                "part": request["part"], "file": str(rel), "sha256": digest,
                "tier": response["tier"], "model": response["model"], "licence": response.get("licence"),
                "backend": response.get("backend"), "seed": response["seed"], "batch_index": i,
                "steps": response["steps"], "width": image["width"], "height": image["height"],
                "has_alpha": image.get("has_alpha"), "elapsed_s": response.get("elapsed_s"),
                "prompt": request["prompt"], "negative_prompt": request["negative_prompt"],
                "generator": "Forge image.generate (stable-diffusion.cpp, local)", "ingested": now(),
            })
            known.add(digest)
            added += 1
    save_json(base / "runs.json", runs)
    print(json.dumps({"added": added, "total": len(runs["images"])}))


def cmd_process(args) -> None:
    spec = family_spec(args.family)
    base = out_dir(args.family)
    parts = part_by_id(spec)
    runs = load_json(base / "runs.json", {"images": []})
    results = []
    for image in runs["images"]:
        part = parts[image["part"]]
        rgb = np.asarray(Image.open(base / image["file"]).convert("RGB")).astype(np.float64)
        mask, iso = isolate(rgb)
        if part.get("orient") == "vertical" and mask.sum() >= 16:
            rgb, mask, iso["rotated_deg"] = orient_vertical(rgb, mask, iso["background_rgb"])
        sym = symmetry_iou(mask)
        entry = {"id": image["id"], "part": part["id"], "tier": image["tier"], "model": image["model"],
                 "raw": image["file"], "isolation": iso, "source_symmetry": round(sym, 3)}
        if mask.sum() < 16:
            entry.update(status="FAIL", score=0.0, reasons=["nothing separable from the background"], layer=None)
        else:
            layer, info = to_layer(rgb, mask, spec, part)
            status, score, reasons = judge(part, iso, info, sym)
            rel = Path("candidates") / part["id"] / f"{image['id']}.png"
            (base / rel).parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(layer, "RGBA").save(base / rel, optimize=True)
            mask_rel = Path("candidates") / part["id"] / f"{image['id']}-mask.png"
            Image.fromarray((mask * 255).astype(np.uint8)).resize((128, 128), Image.NEAREST).save(base / mask_rel)
            entry.update(status=status, score=score, reasons=reasons, layer=str(rel), mask=str(mask_rel), **info)
        results.append(entry)
    save_json(base / "candidates.json", {"family": spec["family"], "pipeline_version": PIPELINE_VERSION,
                                         "processed": now(), "candidates": results})
    summary = {}
    for r in results:
        summary.setdefault(r["part"], {}).setdefault(r["status"], 0)
        summary[r["part"]][r["status"]] += 1
    print(json.dumps(summary, indent=2))


def picks(spec: dict, base: Path) -> dict:
    """Accepted candidate per part; otherwise the best-scoring non-failing one (marked provisional)."""
    cands = load_json(base / "candidates.json", {"candidates": []})["candidates"]
    accepted = load_json(base / "selections.json", {"selections": {}})["selections"]
    chosen = {}
    for part in spec["parts"]:
        pid = part["id"]
        if pid in accepted:
            match = next((c for c in cands if c["id"] == accepted[pid]["candidate"]), None)
            if match and match.get("layer"):
                chosen[pid] = {**match, "provisional": False}
                continue
        pool = sorted((c for c in cands if c["part"] == pid and c.get("layer") and c["status"] != "FAIL"),
                      key=lambda c: -c["score"])
        if pool:
            chosen[pid] = {**pool[0], "provisional": True}
    return chosen


def load_layer(base: Path, cand: dict) -> np.ndarray:
    return np.asarray(Image.open(base / cand["layer"]).convert("RGBA"))


def dock(spec: dict, layers: dict) -> dict:
    """Slide modules until they touch the hull: wing parts move inward, nose parts move down.

    The overlap is one pixel, so a module always reads as bolted on, whatever the hull's silhouette."""
    if "hull" not in layers:
        return layers
    hull = layers["hull"][..., 3] > 0
    width = spec["canvas"]["width"]
    out = dict(layers)
    for part in spec["parts"]:
        pid, mode = part["id"], part.get("dock")
        if pid not in layers or not mode:
            continue
        layer = layers[pid]
        if mode == "inward":
            left = layer.copy()
            left[:, width // 2:] = 0
            for shift in range(width // 2):
                moved = np.roll(left, shift, axis=1)
                if (moved[..., 3] > 0)[hull].any() or shift == width // 2 - 1:
                    break
            moved[:, width // 2:] = 0
            docked = moved.copy()
            mirror = moved[:, ::-1]
            m = mirror[..., 3] > 0
            docked[m] = mirror[m]
        else:  # down
            for shift in range(spec["canvas"]["height"] // 2):
                moved = np.roll(layer, shift, axis=0)
                if (moved[..., 3] > 0)[hull].any():
                    break
            docked = moved
        out[pid] = docked
    return out


def composite(spec: dict, layers: dict, enabled: list[str]) -> np.ndarray:
    layers = dock(spec, layers)
    canvas = np.zeros((spec["canvas"]["height"], spec["canvas"]["width"], 4), dtype=np.uint8)
    for pid in spec["layer_order"]:
        if pid in enabled and pid in layers:
            paste(canvas, layers[pid], 0, 0)
    return canvas


def save_scaled(arr: np.ndarray, path: Path, scale: int, bg: str | None = "#0B1220") -> None:
    img = Image.fromarray(arr, "RGBA")
    img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    if bg:
        back = Image.new("RGBA", img.size, bg)
        back.alpha_composite(img)
        img = back
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def loadouts(spec: dict) -> list[list[str]]:
    nose = [None, "spread", "large"]
    wing = [None, "rapid", "powerful"]
    combos = []
    for n, w, s in itertools.product(nose, wing, [False, True]):
        combos.append(["hull"] + [p for p in (n, w) if p] + (["shield"] if s else []))
    return combos


def cmd_review(args) -> None:
    spec = family_spec(args.family)
    base = out_dir(args.family)
    web = review_dir(args.family)
    if web.exists():
        shutil.rmtree(web)
    (web / "img").mkdir(parents=True)
    data = load_json(base / "candidates.json", None)
    if data is None:
        sys.exit("run `process` first")
    runs = {r["id"]: r for r in load_json(base / "runs.json", {"images": []})["images"]}
    chosen = picks(spec, base)
    selections = load_json(base / "selections.json", {"selections": {}})["selections"]
    groups = spec.get("slot_groups", {})
    group_of = {pid: g for g, members in groups.items() for pid in members}
    # The selected ship: every human-accepted part, at most one per slot group (nose, wing).
    selected = {}
    for part in spec["parts"]:
        pid = part["id"]
        cand = chosen.get(pid)
        if not cand or cand["provisional"]:
            continue
        if pid in group_of and any(group_of.get(o) == group_of[pid] for o in selected):
            continue
        selected[pid] = load_layer(base, cand)
    if "hull" not in selected and "hull" in chosen:
        selected["hull"] = load_layer(base, chosen["hull"])

    def on_selected_ship(part_id: str, layer: np.ndarray) -> tuple[np.ndarray, list[str]]:
        """Candidate layer swapped into the selected ship, replacing whatever shares its slot."""
        layers = {pid: lay for pid, lay in selected.items()
                  if pid != part_id and (part_id not in group_of or group_of.get(pid) != group_of[part_id])}
        layers[part_id] = layer
        return composite(spec, layers, list(layers)), sorted(p for p in layers if p != part_id)

    cards = []
    for c in data["candidates"]:
        raw_thumb = web / "img" / f"{c['id']}-raw.png"
        Image.open(base / c["raw"]).convert("RGB").resize((192, 192), Image.LANCZOS).save(raw_thumb)
        card = {**{k: c[k] for k in ("id", "part", "tier", "model", "status", "score", "reasons")},
                "raw": f"img/{raw_thumb.name}", "seed": runs[c["id"]]["seed"], "prompt": runs[c["id"]]["prompt"],
                "isolation": c["isolation"], "symmetry": c["source_symmetry"]}
        if c.get("layer"):
            layer = load_layer(base, c)
            save_scaled(layer, web / "img" / f"{c['id']}-layer.png", 4)
            shutil.copyfile(base / c["mask"], web / "img" / f"{c['id']}-mask.png")
            context, with_parts = on_selected_ship(c["part"], layer)
            save_scaled(context, web / "img" / f"{c['id']}-context.png", 4)
            contexts = [{"label": "on selected ship", "parts": with_parts, "file": f"img/{c['id']}-context.png"}]
            if group_of.get(c["part"]) == "nose":
                # Nose modules show on both ship modes: the single shooter (no powerups, nose fire)
                # and the wing shooter (wing cannons fitted by a powerup).
                bare = {"hull": selected["hull"], c["part"]: layer} if "hull" in selected else {c["part"]: layer}
                contexts = [{"label": "single shooter", "parts": sorted(p for p in bare if p != c["part"]),
                             "file": f"img/{c['id']}-single.png"}]
                save_scaled(composite(spec, bare, list(bare)), web / "img" / f"{c['id']}-single.png", 4)
                wing = next((pid for pid in groups.get("wing", []) if pid in selected), None)
                if wing:
                    armed = {**bare, wing: selected[wing]}
                    save_scaled(composite(spec, armed, list(armed)), web / "img" / f"{c['id']}-wing.png", 4)
                    contexts.append({"label": "wing shooter", "parts": sorted(p for p in armed if p != c["part"]),
                                     "file": f"img/{c['id']}-wing.png"})
            card.update(layer=f"img/{c['id']}-layer.png", mask=f"img/{c['id']}-mask.png",
                        context=f"img/{c['id']}-context.png", contexts=contexts, context_parts=with_parts,
                        slot_fill=c["slot_fill"],
                        palette_colours=c["palette_colours"])
        card["picked"] = chosen.get(c["part"], {}).get("id") == c["id"]
        cards.append(card)
    # Loadout and wear sheets from the current picks.
    sheets = {}
    layers = {pid: load_layer(base, cand) for pid, cand in chosen.items()}
    combos = [lo for lo in loadouts(spec) if all(p in layers for p in lo)]
    if combos:
        tiles = [composite(spec, layers, lo) for lo in combos]
        save_sheet(tiles, web / "loadouts.png", cols=6, scale=3)
        sheets["loadouts"] = {"file": "loadouts.png", "labels": [" + ".join(lo[1:]) or "bare hull" for lo in combos]}
        wear_rows = []
        for lo in (["hull", "spread", "rapid", "shield"], ["hull", "large", "powerful", "shield"]):
            if all(p in layers for p in lo):
                for state in spec["wear_states"]:
                    worn = {p: (derive_wear(layers[p], spec, part_by_id(spec)[p], state) if p != "hull" else layers[p])
                            for p in lo}
                    wear_rows.append(composite(spec, worn, lo))
        if wear_rows:
            save_sheet(wear_rows, web / "wear.png", cols=3, scale=4)
            sheets["wear"] = {"file": "wear.png", "labels": spec["wear_states"]}
    current = ROOT / "assets/images/combat.png"
    if current.exists():
        Image.open(current).crop((0, 4 * 64, 64, 5 * 64)).resize((192, 192), Image.NEAREST).save(web / "current-ship.png")
    ship_modes = []
    if selected:
        save_scaled(composite(spec, selected, list(selected)), web / "selected-ship.png", 4)
        if "hull" in selected:
            save_scaled(selected["hull"], web / "ship-single.png", 4)
            ship_modes.append({"label": "single shooter (no powerups)", "file": "ship-single.png", "parts": ["hull"]})
            wing = next((pid for pid in groups.get("wing", []) if pid in selected), None)
            if wing:
                armed = {"hull": selected["hull"], wing: selected[wing]}
                save_scaled(composite(spec, armed, list(armed)), web / "ship-wing.png", 4)
                ship_modes.append({"label": "wing shooter (powerup fitted)", "file": "ship-wing.png",
                                   "parts": ["hull", wing]})
    save_json(web / "report.json", {
        "family": spec["family"], "description": spec["description"], "generated": now(),
        "pipeline_version": PIPELINE_VERSION, "canvas": spec["canvas"],
        "picks": {pid: {"id": c["id"], "provisional": c["provisional"]} for pid, c in chosen.items()},
        "sheets": sheets, "candidates": cards, "parts": [p["id"] for p in spec["parts"]],
        "slot_groups": groups,
        "accepted": {pid: selections[pid] for pid in selections},
        "selected_ship": {"file": "selected-ship.png", "parts": sorted(selected), "modes": ship_modes} if selected else None,
        "retired_tiers": load_json(base / "runs.json", {}).get("retired_tiers", []),
        "progress": {"accepted": sum(1 for p in spec["parts"] if p["id"] in selections), "total": len(spec["parts"])},
    })
    index = Path(__file__).resolve().parent / "review.html"
    shutil.copyfile(index, web / "index.html")
    print(json.dumps({"review": str(web.relative_to(ROOT)), "candidates": len(cards),
                      "picks": {k: v["id"] + (" (provisional)" if v["provisional"] else "") for k, v in chosen.items()}},
                     indent=2))


def save_sheet(tiles: list[np.ndarray], path: Path, cols: int, scale: int) -> None:
    h, w = tiles[0].shape[:2]
    rows = (len(tiles) + cols - 1) // cols
    pad = 4
    sheet = Image.new("RGBA", (cols * (w * scale + pad) + pad, rows * (h * scale + pad) + pad), "#0B1220")
    for i, t in enumerate(tiles):
        img = Image.fromarray(t, "RGBA").resize((w * scale, h * scale), Image.NEAREST)
        sheet.alpha_composite(img, (pad + (i % cols) * (w * scale + pad), pad + (i // cols) * (h * scale + pad)))
    sheet.save(path, optimize=True)


def cmd_accept(args) -> None:
    spec = family_spec(args.family)
    base = out_dir(args.family)
    cands = {c["id"]: c for c in load_json(base / "candidates.json", {"candidates": []})["candidates"]}
    cand = cands.get(args.candidate)
    if cand is None or cand["part"] != args.part or not cand.get("layer"):
        sys.exit(f"{args.candidate} is not a processed candidate for part {args.part}")
    sel = load_json(base / "selections.json", {"family": spec["family"], "selections": {}})
    sel["selections"][args.part] = {"candidate": args.candidate, "by": args.by, "at": now(), "note": args.note}
    save_json(base / "selections.json", sel)
    print(json.dumps(sel["selections"][args.part]))


def cmd_withdraw(args) -> None:
    """Withdraw a part's acceptance; the decision is kept in the selection history."""
    spec = family_spec(args.family)
    base = out_dir(args.family)
    sel = load_json(base / "selections.json", {"family": spec["family"], "selections": {}})
    current = sel["selections"].pop(args.part, None)
    if current is None:
        sys.exit(f"{args.part} has no accepted candidate")
    sel.setdefault("withdrawn", []).append({**current, "part": args.part, "withdrawn_at": now(), "reason": args.note})
    save_json(base / "selections.json", sel)
    print(json.dumps({"withdrawn": args.part, "candidate": current["candidate"]}))


def cmd_retire(args) -> None:
    """Drop every raw image and candidate from the given tiers (they stay in Git history)."""
    spec = family_spec(args.family)
    base = out_dir(args.family)
    tiers = set(args.tiers.split(",")) if args.tiers else set()
    seeds = {int(v) for v in args.seeds.split(",")} if args.seeds else set()
    if not tiers and not seeds:
        sys.exit("give --tiers and/or --seeds")
    accepted = load_json(base / "selections.json", {"selections": {}})["selections"]
    runs = load_json(base / "runs.json", {"family": spec["family"], "images": []})
    blocked = [s["candidate"] for s in accepted.values()
               if any(f"-{t}-" in s["candidate"] for t in tiers) or any(f"-{x}-" in s["candidate"] for x in seeds)]
    if blocked:
        sys.exit(f"accepted candidates come from a retired tier: {', '.join(blocked)}")
    keep, removed = [], 0
    for image in runs["images"]:
        if image["tier"] in tiers or image["seed"] in seeds:
            for path in (base / image["file"], base / "candidates" / image["part"] / f"{image['id']}.png",
                         base / "candidates" / image["part"] / f"{image['id']}-mask.png"):
                path.unlink(missing_ok=True)
            removed += 1
        else:
            keep.append(image)
    runs["images"] = keep
    runs["retired_tiers"] = sorted(set(runs.get("retired_tiers", [])) | tiers)
    runs["retired_seeds"] = sorted(set(runs.get("retired_seeds", [])) | seeds)
    save_json(base / "runs.json", runs)
    for tier in tiers:
        (base / f"queue-{tier}.json").unlink(missing_ok=True)
    print(json.dumps({"removed": removed, "remaining": len(keep), "retired_tiers": runs["retired_tiers"],
                      "retired_seeds": runs["retired_seeds"]}))


def cmd_pack(args) -> None:
    spec = family_spec(args.family)
    base = out_dir(args.family)
    chosen = picks(spec, base)
    missing = [p["id"] for p in spec["parts"] if p["id"] not in chosen]
    if missing:
        sys.exit(f"no usable candidate for: {', '.join(missing)}")
    provisional = [pid for pid, c in chosen.items() if c["provisional"]]
    if provisional and not args.provisional:
        sys.exit(f"parts without a human acceptance: {', '.join(provisional)} (use `accept`, or --provisional for a preview build)")
    scale = spec["canvas"]["pixel_scale"]
    w, h = spec["canvas"]["width"] * scale, spec["canvas"]["height"] * scale
    states = spec["wear_states"]
    atlas = Image.new("RGBA", (w * len(states), h * len(spec["parts"])), (0, 0, 0, 0))
    rows = {}
    docked = dock(spec, {pid: load_layer(base, c) for pid, c in chosen.items()})
    for r, part in enumerate(spec["parts"]):
        layer = docked[part["id"]]
        for col, state in enumerate(states):
            variant = derive_wear(layer, spec, part, state)
            atlas.alpha_composite(Image.fromarray(variant, "RGBA").resize((w, h), Image.NEAREST), (col * w, r * h))
        rows[part["id"]] = r
    # Muzzle of each wing module (left side, logical px from the ship centre). Wing cannons fire
    # alternately left/right from these points; the right muzzle mirrors the left.
    muzzles = {}
    half_w, half_h = spec["canvas"]["width"] / 2, spec["canvas"]["height"] / 2
    for pid in spec.get("slot_groups", {}).get("wing", []):
        opaque = docked[pid][..., 3] > 0
        opaque[:, spec["canvas"]["width"] // 2:] = False
        ys, xs = np.nonzero(opaque)
        if len(ys):
            top = ys.min()
            row = xs[ys == top]
            muzzles[pid] = {"x": round(float(row.mean()) + 0.5 - half_w, 1), "y": round(float(top) - half_h, 1)}
    # Nose muzzle: top of the hull's centre column, where single shots leave.
    nose_muzzle = None
    hull_alpha = docked["hull"][..., 3] > 0
    cx = spec["canvas"]["width"] // 2
    column = np.nonzero(hull_alpha[:, cx - 1:cx + 1].any(axis=1))[0]
    if len(column):
        nose_muzzle = {"x": 0.0, "y": round(float(column.min()) - half_h, 1)}
    target = ROOT / "assets/images" / f"{spec['family']}-parts.png"
    atlas.save(target, optimize=True)
    meta = {
        "family": spec["family"], "pipeline_version": PIPELINE_VERSION, "packed": now(),
        "cell": {"width": w, "height": h}, "logical": spec["canvas"], "wear_states": states,
        "rows": rows, "layer_order": spec["layer_order"], "provisional": bool(provisional),
        "wing_muzzles": muzzles, "nose_muzzle": nose_muzzle,
        "sources": {pid: {"candidate": c["id"], "tier": c["tier"], "model": c["model"], "provisional": c["provisional"]}
                    for pid, c in chosen.items()},
    }
    save_json(ROOT / "assets/images" / f"{spec['family']}-parts.json", meta)
    save_json(base / "pack.json", {**meta, "atlas": str(target.relative_to(ROOT)), "atlas_sha256": sha256(target)})
    print(json.dumps({"atlas": str(target.relative_to(ROOT)), "provisional": provisional}, indent=2))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan"); p.add_argument("--family", default="ship"); p.add_argument("--tier", default="I0")
    p.add_argument("--parts")
    p.add_argument("--round", type=int, default=0, choices=range(10),
                   help="alternative round: adds 0-9 to each part's seed so new rounds never reuse seeds")
    p.set_defaults(fn=cmd_plan)
    p = sub.add_parser("ingest"); p.add_argument("--family", default="ship"); p.add_argument("--tier", default="I0")
    p.add_argument("--results", required=True); p.set_defaults(fn=cmd_ingest)
    p = sub.add_parser("process"); p.add_argument("--family", default="ship"); p.set_defaults(fn=cmd_process)
    p = sub.add_parser("review"); p.add_argument("--family", default="ship"); p.set_defaults(fn=cmd_review)
    p = sub.add_parser("accept"); p.add_argument("--family", default="ship"); p.add_argument("part")
    p.add_argument("candidate"); p.add_argument("--by", default="human"); p.add_argument("--note", default="")
    p.set_defaults(fn=cmd_accept)
    p = sub.add_parser("withdraw"); p.add_argument("--family", default="ship"); p.add_argument("part")
    p.add_argument("--note", default=""); p.set_defaults(fn=cmd_withdraw)
    p = sub.add_parser("retire"); p.add_argument("--family", default="ship")
    p.add_argument("--tiers", help="comma-separated tiers to drop, e.g. I0,I1")
    p.add_argument("--seeds", help="comma-separated generation seeds to drop (a rejected prompt round)")
    p.set_defaults(fn=cmd_retire)
    p = sub.add_parser("pack"); p.add_argument("--family", default="ship")
    p.add_argument("--provisional", action="store_true"); p.set_defaults(fn=cmd_pack)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
