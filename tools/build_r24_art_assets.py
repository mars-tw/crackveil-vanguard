#!/usr/bin/env python3
"""Build the cv R24 weapon/VFX cutouts and menu key-art exports.

The inputs are the Wave-0-calibrated matte-pipeline outputs.  This second pass
is deliberately asset-specific: it removes the measured magenta-matte
complement fringe, keeps anti-aliasing, caps pure-white highlights, and writes
the runtime-sized files plus light/dark/checker evidence.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "R24_art"
PIPELINE_RGBA = EVIDENCE / "rgba"
MASTER_RGBA = EVIDENCE / "rgba_master"
MANUAL_QA = EVIDENCE / "manual_qa"
GENERATED = EVIDENCE / "generated_sources"
ASSET_ROOT = ROOT / "assets" / "art" / "r24"
WEAPON_DIR = ASSET_ROOT / "weapons"
VFX_DIR = ASSET_ROOT / "vfx"
KEYART_DIR = ASSET_ROOT / "keyart"
AFTER_DIR = EVIDENCE / "after"


# The contraction values were selected per asset after inspecting the Wave 0
# four-panel matte heatmaps.  Hard-core VFX tolerate a firmer contraction than
# metal silhouettes; no broad fog or soft glow was requested for this batch.
CUTOUTS = {
    "weapon_main_blade_a": {"kind": "weapon", "contract": 4, "alpha_floor": 6},
    "weapon_main_blade_b": {"kind": "weapon", "contract": 4, "alpha_floor": 6},
    "weapon_far_blade_outbound": {"kind": "weapon", "contract": 5, "alpha_floor": 7},
    "weapon_far_blade_return": {"kind": "weapon", "contract": 5, "alpha_floor": 7},
    "vfx_orbit_impact": {"kind": "vfx", "contract": 8, "alpha_floor": 10},
    "vfx_boomerang_impact": {"kind": "vfx", "contract": 7, "alpha_floor": 9},
    "vfx_orbit_trail": {"kind": "vfx", "contract": 9, "alpha_floor": 12},
    "vfx_boomerang_trail": {"kind": "vfx", "contract": 9, "alpha_floor": 12},
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _shift(array: np.ndarray, dy: int, dx: int) -> np.ndarray:
    height, width = array.shape[:2]
    padding = ((1, 1), (1, 1)) + (((0, 0),) if array.ndim == 3 else ())
    padded = np.pad(array, padding, mode="constant")
    return padded[1 + dy : 1 + dy + height, 1 + dx : 1 + dx + width]


def fill_from_noncontaminated_neighbors(
    rgb: np.ndarray, alpha: np.ndarray, contaminated: np.ndarray
) -> tuple[np.ndarray, int]:
    """Replace complement-colored edge pixels from the nearest valid islands."""

    repaired = rgb.astype(np.float32)
    unresolved = contaminated.copy()
    known = (alpha > 0) & ~unresolved
    iterations = 0
    for iterations in range(1, 33):
        counts = np.zeros(alpha.shape, dtype=np.float32)
        totals = np.zeros((*alpha.shape, 3), dtype=np.float32)
        for dy, dx in ((-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)):
            neighbor_known = _shift(known, dy, dx)
            counts += neighbor_known
            totals += _shift(repaired, dy, dx) * neighbor_known[..., None]
        fillable = unresolved & (counts > 0)
        if not np.any(fillable):
            break
        repaired[fillable] = totals[fillable] / counts[fillable, None]
        known[fillable] = True
        unresolved[fillable] = False
        if not np.any(unresolved):
            break
    return np.clip(repaired, 0, 255).astype(np.uint8), iterations


def repair_cutout(source: Image.Image, contract: int, alpha_floor: int) -> tuple[Image.Image, dict]:
    rgba = np.asarray(source.convert("RGBA"), dtype=np.uint8).copy()
    rgb = rgba[..., :3]
    alpha = rgba[..., 3]

    low = (alpha > 0) & (alpha < 96)
    complement = np.array([0.0, 255.0, 0.0], dtype=np.float32)
    distance = np.linalg.norm(rgb.astype(np.float32) - complement, axis=2)
    saturation = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2).astype(np.int16)
    contaminated = low & (distance < 95.0) & (saturation > 150)
    bad_before = int(np.count_nonzero(contaminated))

    repaired_rgb, iterations = fill_from_noncontaminated_neighbors(rgb, alpha, contaminated)
    adjusted_alpha = np.where(
        alpha <= alpha_floor,
        0,
        np.clip(
            (alpha.astype(np.float32) - float(contract)) * 255.0 / float(255 - contract),
            0,
            255,
        ),
    ).astype(np.uint8)
    # The gold standard forbids weapon/VFX highlights from becoming the scene's
    # absolute white peak.  Capping 8-bit channels at 244 preserves the warm
    # bone material while retaining room for enemy telegraphs and UI text.
    repaired_rgb = np.minimum(repaired_rgb, 244).astype(np.uint8)
    repaired_rgb[adjusted_alpha == 0] = 0
    result = Image.fromarray(np.dstack((repaired_rgb, adjusted_alpha)), "RGBA")
    return result, {
        "complement_pixels_repainted": bad_before,
        "neighbor_fill_iterations": iterations,
        "edge_contract": contract,
        "alpha_floor": alpha_floor,
    }


def checker(size: tuple[int, int], cell: int = 16) -> Image.Image:
    width, height = size
    yy, xx = np.indices((height, width))
    pattern = ((xx // cell + yy // cell) % 2).astype(np.uint8)
    values = np.where(pattern == 0, 58, 92).astype(np.uint8)
    return Image.fromarray(np.dstack((values, values, values)), "RGB")


def composite_on(rgba: Image.Image, background: Image.Image) -> Image.Image:
    canvas = background.convert("RGBA")
    canvas.alpha_composite(rgba)
    return canvas.convert("RGB")


def make_manual_qa(asset_id: str, pipeline: Image.Image, repaired: Image.Image) -> Path:
    thumb_size = (320, 320)
    before = pipeline.resize(thumb_size, Image.Resampling.LANCZOS)
    after = repaired.resize(thumb_size, Image.Resampling.LANCZOS)
    panels = [
        composite_on(before, Image.new("RGB", thumb_size, (5, 13, 31))),
        composite_on(after, Image.new("RGB", thumb_size, (5, 13, 31))),
        composite_on(after, Image.new("RGB", thumb_size, (236, 232, 218))),
        composite_on(after, checker(thumb_size)),
    ]
    sheet = Image.new("RGB", (1280, 356), (12, 16, 25))
    labels = ("PIPELINE / DARK", "RETOUCH / DARK", "RETOUCH / LIGHT", "RETOUCH / CHECKER")
    draw = ImageDraw.Draw(sheet)
    for index, (panel, label) in enumerate(zip(panels, labels)):
        x = index * 320
        sheet.paste(panel, (x, 36))
        draw.text((x + 10, 10), label, fill=(225, 235, 240))
    path = MANUAL_QA / f"{asset_id}_edge_review.png"
    sheet.save(path, "PNG", optimize=True)
    return path


def cover_crop(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def runtime_resize_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    resized = np.asarray(image.resize(size, Image.Resampling.LANCZOS).convert("RGBA"), dtype=np.uint8).copy()
    resized[..., :3] = np.minimum(resized[..., :3], 244)
    resized[resized[..., 3] == 0, :3] = 0
    return Image.fromarray(resized, "RGBA")


def build_keyart() -> list[dict]:
    desktop_source = Image.open(GENERATED / "keyart_desktop_opaque.png").convert("RGB")
    desktop = cover_crop(desktop_source, (1920, 1080))
    desktop_path = KEYART_DIR / "menu_keyart_desktop.png"
    desktop.save(desktop_path, "PNG", optimize=True)

    portrait_source = Image.open(GENERATED / "keyart_mobile_safe_opaque.png").convert("RGB")
    # Reuse only model-produced atmosphere for the outer field: the desktop
    # source is blurred/darkened, then the identity-locked portrait composition
    # is feathered into a 500 px central safety strip.
    backdrop = cover_crop(desktop_source, (1920, 1080)).filter(ImageFilter.GaussianBlur(12))
    backdrop = ImageEnhance.Brightness(backdrop).enhance(0.34)
    mobile = backdrop.convert("RGBA")
    insert_width = 500
    insert_height = round(insert_width * portrait_source.height / portrait_source.width)
    insert = portrait_source.resize((insert_width, insert_height), Image.Resampling.LANCZOS).convert("RGBA")
    insert = ImageEnhance.Brightness(insert).enhance(0.92)
    mask = Image.new("L", insert.size, 255)
    mask_array = np.asarray(mask, dtype=np.uint8).copy()
    feather = 64
    ramp = np.linspace(0, 255, feather, dtype=np.uint8)
    mask_array[:, :feather] = np.minimum(mask_array[:, :feather], ramp[None, :])
    mask_array[:, -feather:] = np.minimum(mask_array[:, -feather:], ramp[::-1][None, :])
    mask = Image.fromarray(mask_array, "L").filter(ImageFilter.GaussianBlur(3))
    # Paste with an external seam mask so the central strip dissolves into the
    # generated wide atmosphere without a visible vertical boundary.
    mobile = backdrop.convert("RGBA")
    cropped_insert = insert.crop((0, 0, insert_width, min(insert_height, 1080)))
    cropped_mask = mask.crop((0, 0, insert_width, cropped_insert.height))
    # The portrait menu occupies the upper half of a 390x844 viewport.  Keep the
    # identity-locked trio below those controls instead of letting button plates
    # cover their silhouettes.
    mobile.paste(cropped_insert, ((1920 - insert_width) // 2, 420), cropped_mask)
    mobile = mobile.convert("RGB")
    mobile_path = KEYART_DIR / "menu_keyart_mobile_safe.png"
    mobile.save(mobile_path, "PNG", optimize=True)

    desktop_evidence = AFTER_DIR / "menu_keyart_desktop_1920x1080.png"
    mobile_crop_evidence = AFTER_DIR / "menu_keyart_mobile_390x844_crop.png"
    desktop.save(desktop_evidence, "PNG", optimize=True)
    cover_crop(mobile, (390, 844)).save(mobile_crop_evidence, "PNG", optimize=True)
    return [
        {
            "id": "menu_keyart_desktop",
            "path": desktop_path.relative_to(ROOT).as_posix(),
            "size": list(desktop.size),
            "sha256": sha256(desktop_path),
            "safe_crop": "desktop-left-ui/right-hero",
        },
        {
            "id": "menu_keyart_mobile_safe",
            "path": mobile_path.relative_to(ROOT).as_posix(),
            "size": list(mobile.size),
            "sha256": sha256(mobile_path),
            "safe_crop": "390x844 centered cover",
            "crop_evidence": mobile_crop_evidence.relative_to(ROOT).as_posix(),
        },
    ]


def main() -> int:
    for directory in (MASTER_RGBA, MANUAL_QA, WEAPON_DIR, VFX_DIR, KEYART_DIR, AFTER_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    if "--keyart-only" in sys.argv[1:]:
        existing_path = EVIDENCE / "asset_build_results.json"
        payload = json.loads(existing_path.read_text(encoding="utf-8"))
        payload["keyart"] = build_keyart()
        existing_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"R24_KEYART_BUILD_PASS keyart={len(payload['keyart'])}")
        print(existing_path)
        return 0

    results = []
    for asset_id, config in CUTOUTS.items():
        source_path = PIPELINE_RGBA / f"{asset_id}.png"
        pipeline = Image.open(source_path).convert("RGBA")
        repaired, repair_metrics = repair_cutout(
            pipeline, int(config["contract"]), int(config["alpha_floor"])
        )
        master_path = MASTER_RGBA / f"{asset_id}.png"
        repaired.save(master_path, "PNG", optimize=True)
        runtime_dir = WEAPON_DIR if config["kind"] == "weapon" else VFX_DIR
        runtime_path = runtime_dir / f"{asset_id}.png"
        runtime_resize_rgba(repaired, (256, 256)).save(runtime_path, "PNG", optimize=True)
        qa_path = make_manual_qa(asset_id, pipeline, repaired)
        results.append(
            {
                "id": asset_id,
                "kind": config["kind"],
                "pipeline_rgba": source_path.relative_to(ROOT).as_posix(),
                "master_rgba": master_path.relative_to(ROOT).as_posix(),
                "runtime": runtime_path.relative_to(ROOT).as_posix(),
                "runtime_size": [256, 256],
                "manual_qa": qa_path.relative_to(ROOT).as_posix(),
                "repair": repair_metrics,
                "sha256": {
                    "master_rgba": sha256(master_path),
                    "runtime": sha256(runtime_path),
                    "manual_qa": sha256(qa_path),
                },
            }
        )

    payload = {
        "schema_version": "cv-r24-art-build.v1",
        "release": "cv R24",
        "cutouts": results,
        "keyart": build_keyart(),
    }
    output = EVIDENCE / "asset_build_results.json"
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"R24_ART_BUILD_PASS cutouts={len(results)} keyart={len(payload['keyart'])}")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
