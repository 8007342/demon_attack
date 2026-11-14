"""Flyover refinement pass (checklist 3.4): stage inputs and assemble refined raws.

GPU work (Qwen-Image-Edit-2511 render, BiRefNet matte) goes through studio.run_workflow, one job at a
time; this script only prepares inputs and turns the studio outputs into raws that
tools/flyover_assets.py can ingest. Run with:
  uv run -q --no-project --with numpy --with pillow python -I tools/refine_flyover.py <cmd>

  plan     write <masters>/plan.json (job id, staged input, prompt, seed, matte?) and stage every
           input under /work/tmp/imagegen/refine/flyover/ (sprites flattened on light grey from the
           first-pass 10_/12_ raws; strips and planes copied as they are)
  results  scan <masters>/studio/*/ provenance, pick the newest render (and its matte) per job,
           write the refined raws to <masters>/staged/<job>/ and results.json for
           `flyover_assets.py ingest --results`

Tile seams: strips are rolled by half a tile and planes by half in both axes, so the wrap seam of
the finished tile sits on the raw's outer edges. The edit model repaints each edge on its own, so a
band along those edges is blended back to the first-pass raw (which was continuous across the wrap).
"""
import json
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / "art/families/flyover-backgrounds.json").read_text())
OLD_RAW = Path(os.environ.get("FLYOVER_OLD_RAW", str(ROOT / ".cache/flyover-raw")))
MASTERS = Path(os.environ.get("REFINE_MASTERS",
                              str(Path.home() / ".cache/tillandsias-project/demon-attack/refine-masters/flyover")))
STAGE = Path("/work/tmp/imagegen/refine/flyover")
NEG = "blurry, smooth 3d render, photo, text, watermark, extra limbs, different pose, cropped, background scenery"
SEED0 = 642000
EDGE_BAND = 0.06  # fraction of the raw blended back to the first pass at a wrap edge
GREY = (224, 224, 224)
# Terrain strips stay at first pass: at full denoise the edit model fills the black void lanes that the
# strip alpha is derived from, and at 0.55-0.7 it adds no visible detail (or stray peaks).
SKIP_KINDS = ("strip",)

SPRITE_TAIL = ("Crisp, detailed hand-painted pixel art, clean readable silhouette, sharp surface detail, "
               "small night-lit highlights. Plain flat light grey background, no shadow, no text.")


def jobs():
    out = []
    for sector in SPEC["sectors"]:
        sid = sector["id"]
        for layer in ("mid", "wall"):
            out.append((f"strip/{sid}/{layer}", "strip", sector["layers"][layer]))
        out.append((f"plane/{sid}", "plane", sector["plane"]))
        for p in sector["props"]:
            out.append((f"prop/{sid}/{p['id']}", "prop", p["prompt"]))
        for ri, route in enumerate(sector["routes"]):
            for lm in route["landmarks"]:
                out.append((f"landmark/{sid}/{ri}/{lm['id']}", "landmark", lm["prompt"]))
        for c in sector["creatures"]:
            out.append((f"creature/{sid}/{c['id']}", "creature", c["prompt"]))
    return out


def prompt_for(kind, subject):
    if kind == "strip":
        return ("Refine this into a final high-resolution game texture sheet: the same three vertical canyon-rim "
                f"terrain strips with sheer cliff walls dropping into a black abyss, {subject}. Keep every cliff, "
                "ledge and the black void exactly where they are, same oblique aerial view, same dark night palette. "
                "Crisp, detailed hand-painted pixel art, sharper rock facets, cracks, ledges and scattered stones. "
                "No text, no border.")
    if kind == "plane":
        return ("Refine this into a final high-resolution seamless ground texture: the same " + subject +
                ", same layout of every feature, same flat top-down view and same dark palette. Crisp, detailed "
                "hand-painted pixel art, fine surface grain, sharper crack and crater edges. No text, no border.")
    what = "game prop" if kind == "prop" else ("landmark structure" if kind == "landmark" else "creature sprite")
    return (f"Refine this into a final high-resolution {what}: the same {subject}, same oblique three-quarter "
            "top-down view, same framing, pose, proportions and same dark night palette. " + SPRITE_TAIL)


def flat(jid):
    return jid.replace("/", "__")


def cmd_plan():
    STAGE.mkdir(parents=True, exist_ok=True)
    MASTERS.mkdir(parents=True, exist_ok=True)
    plan = []
    for i, (jid, kind, subject) in enumerate(jobs()):
        src = OLD_RAW / jid
        files = sorted(src.glob("*.png"))
        dst = STAGE / f"{flat(jid)}.png"
        if kind in ("strip", "plane"):
            Image.open(files[-1]).convert("RGB").save(dst)
        else:
            rgb = Image.open([f for f in files if f.name.startswith("10_")][0]).convert("RGB")
            al = Image.open([f for f in files if f.name.startswith("12_")][0]).convert("L")
            bg = Image.new("RGB", rgb.size, GREY)
            bg.paste(rgb, (0, 0), al)
            bg.save(dst)
        plan.append({"id": jid, "kind": kind, "input": str(dst), "seed": SEED0 + i,
                     "matte": kind not in ("strip", "plane"), "prompt": prompt_for(kind, subject)})
    (MASTERS / "plan.json").write_text(json.dumps(plan, indent=1) + "\n")
    print(len(plan), "jobs staged in", STAGE)


def edge_blend(new, old, axes):
    """Blend a band along the wrap edges of `new` back to `old` (same size), linear ramp."""
    h, w = new.shape[:2]
    wgt = np.ones((h, w), dtype=np.float32)
    if 0 in axes:
        b = max(1, int(h * EDGE_BAND))
        ramp = np.clip(np.minimum(np.arange(h), np.arange(h)[::-1]) / b, 0, 1)
        wgt *= ramp[:, None]
    if 1 in axes:
        b = max(1, int(w * EDGE_BAND))
        ramp = np.clip(np.minimum(np.arange(w), np.arange(w)[::-1]) / b, 0, 1)
        wgt *= ramp[None, :]
    return (new * wgt[..., None] + old * (1 - wgt[..., None])).astype(np.uint8)


def cmd_results():
    plan = {p["id"]: p for p in json.loads((MASTERS / "plan.json").read_text())}
    by_input = {p["input"]: p["id"] for p in plan.values()}
    renders, mattes = {}, {}
    for prov in sorted((MASTERS / "studio").glob("*/*.png.provenance.json")):
        d = json.loads(prov.read_text())
        png = Path(str(prov)[: -len(".provenance.json")])
        inp = d["inputs"][0]["path"] if d.get("inputs") else ""
        wf = d["workflow"]["path"]
        if wf.endswith("variant-qwen-edit.json") and inp in by_input:
            jid = by_input[inp]
            if jid not in renders or d["at"] > renders[jid][1]["at"]:
                renders[jid] = (png, d)
        elif wf.endswith("matte-birefnet.json"):
            mattes[inp] = (png, d)  # keyed by the studio path of the render it mattes
    results, missing = {}, []
    for jid, p in plan.items():
        if p["kind"] in SKIP_KINDS:
            continue  # kept at first pass (see SKIP_KINDS)
        if jid not in renders:
            missing.append(jid)
            continue
        png, d = renders[jid]
        studio_path = d.get("output_path") or ""
        out = MASTERS / "staged" / jid
        out.mkdir(parents=True, exist_ok=True)
        for f in out.glob("*"):
            f.unlink()
        if p["kind"] in ("strip", "plane"):
            old = Image.open(sorted((OLD_RAW / jid).glob("*.png"))[-1]).convert("RGB")
            new = Image.open(png).convert("RGB").resize(old.size, Image.Resampling.LANCZOS)
            axes = (0,) if p["kind"] == "strip" else (0, 1)
            arr = edge_blend(np.asarray(new, dtype=np.float32), np.asarray(old, dtype=np.float32), axes)
            target = out / "0000_00001_.png"
            Image.fromarray(arr).save(target)
            (out / "0000_00001_.png.provenance.json").write_text(json.dumps(d, indent=1))
            results[jid] = [str(target)]
        else:
            match = [m for k, m in mattes.items() if Path(k).parent.name == png.parent.name]
            if not match:
                missing.append(jid + " (matte)")
                continue
            mpng, md = match[-1]
            rgb = Image.open(png).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
            al = Image.open(mpng).convert("L").resize((1024, 1024), Image.Resampling.LANCZOS)
            rgb.save(out / "10_00001_.png")
            al.convert("RGB").save(out / "12_00001_.png")
            (out / "10_00001_.png.provenance.json").write_text(json.dumps(d, indent=1))
            (out / "12_00001_.png.provenance.json").write_text(json.dumps(md, indent=1))
            master = rgb.convert("RGBA")
            master.putalpha(al)
            mdir = MASTERS / "rgba" / Path(jid).parent
            mdir.mkdir(parents=True, exist_ok=True)
            master.save(mdir / f"{Path(jid).name}.png")
            results[jid] = [str(out / "10_00001_.png"), str(out / "12_00001_.png")]
    (MASTERS / "results.json").write_text(json.dumps(results, indent=1) + "\n")
    print(len(results), "jobs ready;", len(missing), "missing:", ", ".join(missing) or "none")


if __name__ == "__main__":
    {"plan": cmd_plan, "results": cmd_results}[sys.argv[1]]()
