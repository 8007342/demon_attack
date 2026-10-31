#!/usr/bin/env python3
"""Prepare local imagegen outputs as pixel-art review candidates.

This processor is offline: it reads checked-in research PNGs and invokes the
local ImageMagick executable only. It never calls a model or network service.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESEARCH = ROOT / "assets/research/local-image-pipeline"
MANIFEST = RESEARCH / "manifest.json"
WEB_ROOT = ROOT / "web/local-image-review"
WEB_ASSETS = WEB_ROOT / "assets"
LOGICAL_SIZE = 32
DISPLAY_SIZE = 96
PALETTE_LIMIT = 16


def run(*args: str) -> str:
    result = subprocess.run(args, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def identify(path: Path) -> tuple[int, int, str, int]:
    raw = run(
        "magick",
        "identify",
        "-format",
        "%w|%h|%[channels]|%k",
        str(path),
    )
    width, height, channels, colors = raw.split("|", 3)
    return int(width), int(height), channels.lower(), int(colors)


def main() -> int:
    if shutil.which("magick") is None:
        print(
            "ImageMagick is required locally (magick command unavailable); "
            "install it through the Forge package manager and rerun.",
            file=sys.stderr,
        )
        return 2

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    WEB_ASSETS.mkdir(parents=True, exist_ok=True)
    results = []

    for candidate in manifest["candidates"]:
        source = (RESEARCH / candidate["source"]).resolve()
        if RESEARCH.resolve() not in source.parents or not source.is_file():
            raise ValueError(f"Candidate source is missing or outside research root: {source}")

        raw_name = f"{candidate['name']}-source.png"
        preview_name = f"{candidate['name']}-pixel-preview.png"
        raw_output = WEB_ASSETS / raw_name
        preview_output = WEB_ASSETS / preview_name
        shutil.copyfile(source, raw_output)

        width, height, channels, _source_colors = identify(source)
        alpha_present = "a" in channels.replace("gray", "").replace("cmyk", "")

        # A fixed 32x32 sample and hard nearest-neighbor enlargement make the
        # reduction reproducible. This is a review thumbnail, not cleanup.
        run(
            "magick",
            str(source),
            "-strip",
            "-filter",
            "point",
            "-resize",
            f"{LOGICAL_SIZE}x{LOGICAL_SIZE}!",
            "-colors",
            str(PALETTE_LIMIT),
            "-dither",
            "None",
            "-scale",
            f"{DISPLAY_SIZE}x{DISPLAY_SIZE}!",
            "-strip",
            str(preview_output),
        )
        out_width, out_height, out_channels, palette_size = identify(preview_output)
        output_has_alpha = "a" in out_channels.replace("gray", "").replace("cmyk", "")

        reasons = []
        if (width, height) != (512, 512):
            reasons.append("unexpected source dimensions")
        if not alpha_present:
            reasons.append("source has opaque background")
        if output_has_alpha:
            # The current candidates should remain opaque; if future output
            # changes this, alpha itself is not a rejection reason.
            pass
        if palette_size > PALETTE_LIMIT:
            reasons.append("preview exceeds palette limit")
        if not candidate.get("review", "").lower().startswith("accepted"):
            reasons.append(candidate.get("review", "manual review required"))

        results.append(
            {
                "name": candidate["name"],
                "source": f"assets/{raw_name}",
                "preview": f"assets/{preview_name}",
                "source_dimensions": {"width": width, "height": height},
                "source_channels": channels,
                "source_has_alpha": alpha_present,
                "preview_dimensions": {"width": out_width, "height": out_height},
                "logical_cell": {"width": LOGICAL_SIZE, "height": LOGICAL_SIZE},
                "preview_palette_colors": palette_size,
                "palette_limit": PALETTE_LIMIT,
                "resampling": "nearest-neighbor",
                "status": "REJECTED" if reasons else "REVIEW",
                "reasons": reasons,
                "prompt": candidate["prompt"],
                "negative_prompt": candidate["negative_prompt"],
                "model": manifest["generator"]["model"],
                "tier": manifest["generator"]["tier"],
                "backend": manifest["generator"]["backend"],
                "license_metadata": manifest["generator"]["license_metadata"],
                "seed": candidate["seed"],
                "steps": candidate["steps"],
                "sha256": candidate["sha256"],
            }
        )

    background_results = []
    for candidate in manifest.get("background_candidates", []):
        source = (RESEARCH / candidate["source"]).resolve()
        if RESEARCH.resolve() not in source.parents or not source.is_file():
            raise ValueError(f"Background source is missing or outside research root: {source}")
        raw_name = f"{candidate['name']}-source.png"
        current_name = f"{candidate['name']}-current.png"
        preview_name = f"{candidate['name']}-preview.png"
        raw_output = WEB_ASSETS / raw_name
        current_output = WEB_ASSETS / current_name
        preview_output = WEB_ASSETS / preview_name
        shutil.copyfile(source, raw_output)
        current_source = (ROOT / candidate["compare_to"]).resolve()
        if ROOT.resolve() not in current_source.parents or not current_source.is_file():
            raise ValueError(f"Comparison background is missing or outside repository: {current_source}")
        shutil.copyfile(current_source, current_output)
        width, height, channels, _colors = identify(source)
        if (width, height) != (candidate["width"], candidate["height"]):
            raise ValueError(f"Unexpected background dimensions for {candidate['name']}: {width}x{height}")
        # Keep detailed scenery; only resize to a common 2:3 review preview.
        run("magick", str(source), "-strip", "-filter", "point", "-resize", "384x576!", "-strip", str(preview_output))
        background_results.append({
            "name": candidate["name"],
            "location": candidate["location"],
            "source": f"assets/{raw_name}",
            "preview": f"assets/{preview_name}",
            "current": f"assets/{current_name}",
            "current_source": candidate["compare_to"],
            "source_dimensions": {"width": width, "height": height},
            "source_channels": channels,
            "source_has_alpha": "a" in channels.replace("gray", "").replace("cmyk", ""),
            "seed": candidate["seed"],
            "steps": candidate["steps"],
            "model": manifest["generator"]["model"],
            "tier": manifest["generator"]["tier"],
            "backend": manifest["generator"]["backend"],
            "license_metadata": manifest["generator"]["license_metadata"],
            "sha256": candidate["sha256"],
            "prompt": candidate["prompt"],
            "negative_prompt": candidate["negative_prompt"],
            "review": candidate["review"],
        })

    preview_paths = [str(WEB_ASSETS / f"{r['name']}-pixel-preview.png") for r in results]
    atlas = WEB_ROOT / "candidate-atlas.png"
    run(
        "magick",
        "montage",
        *preview_paths,
        "-tile",
        f"{min(4, len(results))}x{(len(results) + 3) // 4}",
        "-geometry",
        f"{DISPLAY_SIZE}x{DISPLAY_SIZE}+8+8",
        "-background",
        "#101522",
        str(atlas),
    )

    report = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "workflow": manifest["workflow"],
        "inference_policy": manifest["inference_policy"],
        "processor": "tools/prepare_local_image_candidates.py",
        "processor_version": 2,
        "local_tool": run("magick", "-version").splitlines()[0],
        "logical_cell_size": LOGICAL_SIZE,
        "palette_limit": PALETTE_LIMIT,
        "atlas": "candidate-atlas.png",
        "candidates": results,
        "background_candidates": background_results,
        "integration_status": manifest["processing"]["integration_status"],
    }
    (WEB_ROOT / "report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"atlas": str(atlas), "candidates": results}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
