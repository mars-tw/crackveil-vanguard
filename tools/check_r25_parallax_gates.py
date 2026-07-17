#!/usr/bin/env python3
"""CI-equivalent command gates for the Wave 2 R25 parallax delivery."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "assets" / "art" / "r25" / "parallax" / "manifest.json"
OUTPUT_PATH = ROOT / "docs" / "evidence" / "R25" / "parallax_gate_results.json"
VIEWPORTS = ((1920, 1080), (1024, 768), (390, 844))
LAYERS = ("far", "mid", "near")
THEMES = ("rift_void", "wasteland_farm", "ember_rift")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def srgb_luminance(rgb: np.ndarray) -> np.ndarray:
    linear = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    return linear[..., 0] * 0.2126 + linear[..., 1] * 0.7152 + linear[..., 2] * 0.0722


def contrast_ratio(foreground_lum: float, background_lum: np.ndarray) -> np.ndarray:
    high = np.maximum(foreground_lum, background_lum)
    low = np.minimum(foreground_lum, background_lum)
    return (high + 0.05) / (low + 0.05)


def check(condition: bool, name: str, detail: dict, results: list[dict]) -> None:
    results.append({"name": name, "passed": bool(condition), **detail})


def safe_crop_result(focus: list[float], viewport: tuple[int, int]) -> dict:
    width, height = viewport
    overscan = 1.08
    max_offset_x = width * (0.022 + 0.095 * 0.12)
    max_offset_y = height * (0.022 + 0.095 * 0.12)
    left = (width - width * overscan) * 0.5 + focus[0] * width * overscan - max_offset_x
    top = (height - height * overscan) * 0.5 + focus[1] * height * overscan - max_offset_y
    right = (width - width * overscan) * 0.5 + (focus[0] + focus[2]) * width * overscan + max_offset_x
    bottom = (height - height * overscan) * 0.5 + (focus[1] + focus[3]) * height * overscan + max_offset_y
    normalized = [left / width, top / height, right / width, bottom / height]
    passed = left >= width * 0.08 and top >= height * 0.08 and right <= width * 0.92 and bottom <= height * 0.92
    return {"viewport": [width, height], "worst_case_focus_edges_norm": normalized, "passed": passed}


def main() -> int:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    results: list[dict] = []
    assets = manifest["assets"]
    by_theme_layer = {(item["theme"], item["layer"]): item for item in assets}
    check(len(assets) == 9 and len(by_theme_layer) == 9, "asset_count", {"count": len(assets)}, results)
    check(len({item["prompt_id"] for item in assets}) == 9, "prompt_id_uniqueness", {}, results)

    arena_source = (ROOT / "scripts" / "arena" / "arena_background.gd").read_text(encoding="utf-8")
    total_vram = 0
    low_vram = 0
    layer_rows = []
    for item in assets:
        runtime = ROOT / item["runtime"]
        master = ROOT / item["master"]
        with Image.open(runtime) as opened:
            width, height = opened.size
            fmt = opened.format
            rgba = np.asarray(opened.convert("RGBA"), dtype=np.float32) / 255.0
        decoded = width * height * 4
        total_vram += decoded
        if item["layer"] in ("far", "mid"):
            low_vram += decoded
        layer_rows.append(
            {
                "id": item["id"],
                "dimensions": [width, height],
                "formula": f"{width}x{height}x4",
                "decoded_vram_bytes": decoded,
                "decoded_vram_mib": round(decoded / 1048576, 3),
                "file_bytes": runtime.stat().st_size,
            }
        )
        check(
            width <= 2048 and height <= 1024 and fmt == "WEBP",
            f"dimensions_format:{item['id']}",
            {"dimensions": [width, height], "format": fmt},
            results,
        )
        check(
            runtime.stat().st_size < decoded,
            f"compressed_disk_size:{item['id']}",
            {"file_bytes": runtime.stat().st_size, "decoded_bytes": decoded},
            results,
        )
        check(
            sha256(runtime) == item["runtime_sha256"] and sha256(master) == item["master_sha256"],
            f"hash_match:{item['id']}",
            {},
            results,
        )
        expected_ref = f"res://{item['runtime']}?v={item['runtime_sha256'][:8]}"
        check(
            item["runtime_ref"] == expected_ref and expected_ref in arena_source,
            f"content_hash_ref:{item['id']}",
            {"runtime_ref": item["runtime_ref"]},
            results,
        )
        c2pa = item["c2pa"]
        check(
            c2pa["embedded_master"] and c2pa["passed"] and c2pa["validation_state"] == "Valid"
            and c2pa["softwareAgent"]["name"] == "gpt-image"
            and str(c2pa["softwareAgent"]["version"]).startswith("2."),
            f"c2pa:{item['id']}",
            {"state": c2pa["validation_state"], "softwareAgent": c2pa["softwareAgent"]},
            results,
        )
        rgb = rgba[..., :3]
        variance = float(np.var(rgb))
        alpha = rgba[..., 3]
        if item["layer"] in ("mid", "near"):
            alpha_range = float(alpha.max() - alpha.min())
            check(alpha_range >= 0.95, f"alpha_range:{item['id']}", {"range": alpha_range}, results)
        check(variance >= 0.0005, f"non_solid_asset:{item['id']}", {"rgb_variance": variance}, results)

    check(total_vram <= 64 * 1048576, "desktop_vram_budget", {"bytes": total_vram, "mib": total_vram / 1048576}, results)
    check(low_vram <= 32 * 1048576, "mobile_vram_budget", {"bytes": low_vram, "mib": low_vram / 1048576}, results)
    check(manifest["runtime_policy"]["low"] == ["far", "mid"], "low_quality_true_two_layer_policy", {}, results)

    focus = manifest["runtime_policy"]["central_gameplay_band_norm"]
    safe_crop = [safe_crop_result(focus, viewport) for viewport in VIEWPORTS]
    check(all(item["passed"] for item in safe_crop), "safe_crop_all_viewports", {"viewports": safe_crop}, results)

    gameplay_metrics = []
    text_metrics = []
    for theme in THEMES:
        high_path = ROOT / "docs" / "evidence" / "R25" / "quality" / f"{theme}_high.webp"
        low_path = ROOT / "docs" / "evidence" / "R25" / "quality" / f"{theme}_low.webp"
        high = np.asarray(Image.open(high_path).convert("RGB"), dtype=np.float32) / 255.0
        low = np.asarray(Image.open(low_path).convert("RGB"), dtype=np.float32) / 255.0
        height, width = high.shape[:2]
        x0, y0, fw, fh = focus
        central = high[round(y0 * height):round((y0 + fh) * height), round(x0 * width):round((x0 + fw) * width)]
        central_lum = srgb_luminance(central)
        dx = np.abs(np.diff(central_lum, axis=1))
        dy = np.abs(np.diff(central_lum, axis=0))
        edge_density = float(((dx[:dy.shape[0], :] > 0.08) | (dy[:, :dx.shape[1]] > 0.08)).mean())
        p05, p95 = np.percentile(central_lum, [5, 95])
        metric = {
            "theme": theme,
            "luminance_std": float(central_lum.std()),
            "luminance_p95_p05": float(p95 - p05),
            "edge_density": edge_density,
        }
        metric["passed"] = metric["luminance_std"] <= 0.085 and metric["luminance_p95_p05"] <= 0.24 and edge_density <= 0.035
        gameplay_metrics.append(metric)
        check(float(np.var(low)) >= 0.0005, f"low_quality_real_material:{theme}", {"rgb_variance": float(np.var(low))}, results)
        for region_index, region in enumerate(manifest["runtime_policy"]["text_regions_norm"]):
            rx, ry, rw, rh = region
            pixels = high[round(ry * height):round((ry + rh) * height), round(rx * width):round((rx + rw) * width)]
            # Runtime HUD labels use an existing near-black panel/scrim; assert the
            # resulting composited contrast rather than assuming bare text on art.
            scrim_rgb = pixels * 0.12 + np.array([6, 10, 24], dtype=np.float32) / 255.0 * 0.88
            ratios = contrast_ratio(1.0, srgb_luminance(scrim_rgb))
            metric = {
                "theme": theme,
                "region": region_index,
                "minimum_ratio": float(ratios.min()),
                "p01_ratio": float(np.percentile(ratios, 1)),
                "passed": bool(ratios.min() >= 4.5),
            }
            text_metrics.append(metric)
    check(all(item["passed"] for item in gameplay_metrics), "central_gameplay_band_readability", {"themes": gameplay_metrics}, results)
    check(all(item["passed"] for item in text_metrics), "wcag_text_contrast", {"minimum_required": 4.5, "regions": text_metrics}, results)

    quality_files = [
        ROOT / "docs" / "evidence" / "R25" / "quality" / f"{theme}_{quality}.webp"
        for theme in THEMES for quality in ("low", "medium", "high")
    ]
    viewport_files = [
        ROOT / "docs" / "evidence" / "R25" / "quality" / f"{theme}_{label}.webp"
        for theme in THEMES for label in ("desktop_1920x1080", "tablet_1024x768", "mobile_390x844")
    ]
    check(all(path.exists() and path.stat().st_size > 0 for path in quality_files), "quality_evidence_low_medium_high", {"files": len(quality_files)}, results)
    check(all(path.exists() and path.stat().st_size > 0 for path in viewport_files), "viewport_evidence_three_sizes", {"files": len(viewport_files)}, results)

    passed = all(item["passed"] for item in results)
    output = {
        "schema": "rift-r25-parallax-gates.v1",
        "passed": passed,
        "summary": {"checks": len(results), "passed": sum(1 for item in results if item["passed"]), "failed": sum(1 for item in results if not item["passed"])},
        "vram_table": layer_rows,
        "vram_totals": {
            "desktop_high_bytes": total_vram,
            "desktop_high_mib": total_vram / 1048576,
            "mobile_low_bytes": low_vram,
            "mobile_low_mib": low_vram / 1048576,
        },
        "results": results,
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"R25_PARALLAX_GATES_{'PASS' if passed else 'FAIL'} checks={output['summary']['checks']} failed={output['summary']['failed']}")
    if not passed:
        for item in results:
            if not item["passed"]:
                print(f"FAIL {item['name']}: {json.dumps(item, ensure_ascii=False)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
