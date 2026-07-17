#!/usr/bin/env python3
"""Check cv R24 alpha, brightness, saturation, palette, and size contracts."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "R24_art"

CUTOUTS = {
    "weapon_main_blade_a": ROOT / "assets/art/r24/weapons/weapon_main_blade_a.png",
    "weapon_main_blade_b": ROOT / "assets/art/r24/weapons/weapon_main_blade_b.png",
    "weapon_far_blade_outbound": ROOT / "assets/art/r24/weapons/weapon_far_blade_outbound.png",
    "weapon_far_blade_return": ROOT / "assets/art/r24/weapons/weapon_far_blade_return.png",
    "vfx_orbit_impact": ROOT / "assets/art/r24/vfx/vfx_orbit_impact.png",
    "vfx_boomerang_impact": ROOT / "assets/art/r24/vfx/vfx_boomerang_impact.png",
    "vfx_orbit_trail": ROOT / "assets/art/r24/vfx/vfx_orbit_trail.png",
    "vfx_boomerang_trail": ROOT / "assets/art/r24/vfx/vfx_boomerang_trail.png",
}
KEYART = {
    "menu_keyart_desktop": ROOT / "assets/art/r24/keyart/menu_keyart_desktop.png",
    "menu_keyart_mobile_safe": ROOT / "assets/art/r24/keyart/menu_keyart_mobile_safe.png",
}


def color_metrics(path: Path, rgba: bool) -> dict:
    with Image.open(path) as opened:
        image = opened.convert("RGBA")
        actual_mode = opened.mode
        actual_size = list(opened.size)
    array = np.asarray(image, dtype=np.uint8)
    visible = array[..., 3] > 8 if rgba else np.ones(array.shape[:2], dtype=bool)
    rgb = array[..., :3][visible].astype(np.float32) / 255.0
    luminance = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    maximum = rgb.max(axis=1)
    minimum = rgb.min(axis=1)
    saturation = np.divide(
        maximum - minimum,
        maximum,
        out=np.zeros_like(maximum),
        where=maximum > 0,
    )
    cold_cyan = (
        (rgb[:, 1] > 0.45)
        & (rgb[:, 2] > 0.45)
        & (rgb[:, 0] < 0.35)
        & (saturation > 0.45)
    )
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "mode": actual_mode,
        "size": actual_size,
        "mean_luminance": round(float(luminance.mean()), 6),
        "p99_luminance": round(float(np.quantile(luminance, 0.99)), 6),
        "mean_saturation": round(float(saturation.mean()), 6),
        "low_saturation_fraction": round(float(np.mean(saturation < 0.2)), 6),
        "cold_cyan_fraction": round(float(cold_cyan.mean()), 6),
    }


def load_gate(asset_id: str, suffix: str) -> dict:
    path = EVIDENCE / "gates" / f"{asset_id}_{suffix}.json"
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    rows = []
    passed = True
    for asset_id, path in CUTOUTS.items():
        metrics = color_metrics(path, rgba=True)
        alpha_master = load_gate(asset_id, "manual")
        alpha_runtime = load_gate(asset_id, "runtime")
        size_pass = metrics["size"] == [256, 256] and metrics["mode"] == "RGBA"
        brightness_pass = (
            0.30 <= metrics["mean_luminance"] <= 0.78
            and metrics["p99_luminance"] <= 0.97
        )
        saturation_pass = (
            metrics["mean_saturation"] >= 0.32
            and metrics["cold_cyan_fraction"] <= 0.02
        )
        row_pass = (
            bool(alpha_master["pass"])
            and bool(alpha_runtime["pass"])
            and size_pass
            and brightness_pass
            and saturation_pass
        )
        rows.append(
            {
                "id": asset_id,
                "profile": "cutout",
                "pass": row_pass,
                "alpha_master_pass": bool(alpha_master["pass"]),
                "alpha_runtime_pass": bool(alpha_runtime["pass"]),
                "asset_contract_pass": size_pass,
                "brightness_gate_pass": brightness_pass,
                "saturation_palette_gate_pass": saturation_pass,
                "metrics": metrics,
            }
        )
        passed &= row_pass

    for asset_id, path in KEYART.items():
        metrics = color_metrics(path, rgba=False)
        contract_pass = metrics["size"] == [1920, 1080] and metrics["mode"] == "RGB"
        brightness_pass = (
            0.025 <= metrics["mean_luminance"] <= 0.35
            and metrics["p99_luminance"] <= 0.90
        )
        saturation_pass = (
            metrics["mean_saturation"] >= 0.40
            and metrics["cold_cyan_fraction"] <= 0.03
        )
        row_pass = contract_pass and brightness_pass and saturation_pass
        rows.append(
            {
                "id": asset_id,
                "profile": "opaque_rgb_keyart",
                "pass": row_pass,
                "alpha_gate": "not_applicable: §8.1 requires pure backgrounds as RGB PNG/WebP",
                "asset_contract_pass": contract_pass,
                "brightness_gate_pass": brightness_pass,
                "saturation_palette_gate_pass": saturation_pass,
                "metrics": metrics,
            }
        )
        passed &= row_pass

    crop = EVIDENCE / "after" / "menu_keyart_mobile_390x844_crop.png"
    with Image.open(crop) as opened:
        mobile_crop_pass = opened.size == (390, 844)
    passed &= mobile_crop_pass
    payload = {
        "schema_version": "cv-r24-art-gates.v1",
        "release": "cv R24",
        "pass": passed,
        "thresholds": {
            "cutout_brightness": "mean 0.30..0.78 and p99 <= 0.97",
            "cutout_saturation_palette": "mean HSV saturation >= 0.32 and cold-cyan fraction <= 0.02",
            "keyart_brightness": "mean 0.025..0.35 and p99 <= 0.90",
            "keyart_saturation_palette": "mean HSV saturation >= 0.40 and cold-cyan fraction <= 0.03",
        },
        "mobile_safe_crop_pass": mobile_crop_pass,
        "assets": rows,
    }
    output = EVIDENCE / "art_gate_summary.json"
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"R24_ART_GATES_{'PASS' if passed else 'FAIL'} "
        f"cutouts={len(CUTOUTS)} keyart={len(KEYART)} mobile_crop={str(mobile_crop_pass).lower()}"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
