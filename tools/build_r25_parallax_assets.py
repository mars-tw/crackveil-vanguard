#!/usr/bin/env python3
"""Build deterministic R25 runtime parallax assets from verified imagegen masters."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "R25"
MASTERS = EVIDENCE / "masters"
RGBA = EVIDENCE / "processed_rgba"
RUNTIME = ROOT / "assets" / "art" / "r25" / "parallax"
QUALITY = EVIDENCE / "quality"
WIDTH = 1536
HEIGHT = 768
VRAM_BYTES = WIDTH * HEIGHT * 4

THEMES = ("rift_void", "wasteland_farm", "ember_rift")
LAYERS = ("far", "mid", "near")
PROMPT_IDS = {
    "rift_void_far": "R25-P01",
    "rift_void_mid": "R25-P02",
    "rift_void_near": "R25-P03",
    "wasteland_farm_far": "R25-P04",
    "wasteland_farm_mid": "R25-P05",
    "wasteland_farm_near": "R25-P06",
    "ember_rift_far": "R25-P07",
    "ember_rift_mid": "R25-P08",
    "ember_rift_near": "R25-P09",
}
PARALLAX_FACTORS = {"far": 0.025, "mid": 0.055, "near": 0.095}
REFERENCE_HASHES = {
    "menu_keyart_desktop": "6d254015fd1154fd78da68c829cb54a5252dad91753e7e60fd6efcaa55d03113",
    "ground_void_stone": "be757188ff99cd575742a52626a003c88ddf61ba5ebceab3333a8c8ca2270c80",
    "farm_ruined_barn": "b304e16fe2c19cc554ef99043e8ed8ee7a667aa1283e834ee9bd3dc113e2ffd9",
    "ember_lava_crack": "6b58a2d0fb9a94a1cbe795e8395e9bc6b5583b1aa7e48c77c01e6b052d97d57",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_path(theme: str, layer: str) -> Path:
    if layer == "far":
        return MASTERS / f"{theme}_{layer}_master.png"
    return RGBA / f"{theme}_{layer}_rgba.png"


def build_layer(theme: str, layer: str) -> tuple[Path, list[str]]:
    source = source_path(theme, layer)
    with Image.open(source) as opened:
        image = opened.convert("RGB" if layer == "far" else "RGBA")
        image = image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    steps = [
        "Pillow Image.Resampling.LANCZOS resize 1774x887 -> 1536x768",
    ]
    if layer == "far":
        image = image.filter(ImageFilter.GaussianBlur(radius=0.55))
        image = ImageEnhance.Color(image).enhance(0.88)
        image = ImageEnhance.Brightness(image).enhance(0.52)
        steps.extend(
            [
                "GaussianBlur radius=0.55 for gameplay-band noise control",
                "Color saturation x0.88",
                "Brightness x0.52 for HUD contrast",
            ]
        )
    elif layer == "mid":
        rgb = ImageEnhance.Brightness(image.convert("RGB")).enhance(0.78)
        rgb.putalpha(image.getchannel("A"))
        image = rgb
        steps.extend(
            [
                "Imagegen-skill chroma removal retained as alpha source",
                "RGB brightness x0.78; alpha unchanged",
            ]
        )
    else:
        rgb = ImageEnhance.Brightness(image.convert("RGB")).enhance(0.84)
        rgb.putalpha(image.getchannel("A"))
        image = rgb
        steps.extend(
            [
                "Imagegen-skill chroma removal retained as alpha source",
                "RGB brightness x0.84; alpha unchanged",
            ]
        )

    RUNTIME.mkdir(parents=True, exist_ok=True)
    output = RUNTIME / f"{theme}_{layer}.webp"
    image.save(output, "WEBP", quality=86, method=6, exact=True)
    steps.append("Pillow WebP quality=86 method=6 exact=true")
    return output, steps


def composite(theme: str, layer_names: tuple[str, ...], near_opacity: float = 1.0) -> Image.Image:
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), (4, 7, 15, 255))
    for layer in layer_names:
        with Image.open(RUNTIME / f"{theme}_{layer}.webp") as opened:
            image = opened.convert("RGBA")
        if layer == "near" and near_opacity < 1.0:
            alpha = image.getchannel("A").point(lambda value: round(value * near_opacity))
            image.putalpha(alpha)
        canvas.alpha_composite(image)
    return canvas


def write_quality_evidence() -> None:
    QUALITY.mkdir(parents=True, exist_ok=True)
    for theme in THEMES:
        variants = {
            "low": composite(theme, ("far", "mid")),
            "medium": composite(theme, ("far", "mid", "near"), 0.72),
            "high": composite(theme, ("far", "mid", "near")),
        }
        for quality, image in variants.items():
            image.convert("RGB").save(QUALITY / f"{theme}_{quality}.webp", "WEBP", quality=84, method=6)
        high = variants["high"].convert("RGB")
        for label, size in (("desktop_1920x1080", (1920, 1080)), ("tablet_1024x768", (1024, 768)), ("mobile_390x844", (390, 844))):
            high.resize(size, Image.Resampling.LANCZOS).save(
                QUALITY / f"{theme}_{label}.webp", "WEBP", quality=82, method=6
            )


def write_boot_splash() -> Path:
    source = QUALITY / "rift_void_high.webp"
    output = ROOT / "assets" / "art" / "r25" / "r25_boot_splash.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as opened:
        splash = opened.convert("RGB").resize((640, 360), Image.Resampling.LANCZOS)
    splash = splash.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    splash.save(output, "PNG", optimize=True, compress_level=9)
    return output


def write_web_focal() -> Path:
    source = QUALITY / "rift_void_high.webp"
    output = ROOT / "assets" / "art" / "r25" / "r25_web_focal.webp"
    with Image.open(source) as opened:
        focal = opened.convert("RGB").resize((640, 360), Image.Resampling.LANCZOS)
    focal.save(output, "WEBP", quality=68, method=6)
    return output


def main() -> int:
    c2pa_path = EVIDENCE / "c2pa_verification.json"
    c2pa = json.loads(c2pa_path.read_text(encoding="utf-8"))
    c2pa_by_master = {Path(item["master"]).name: item for item in c2pa["masters"]}
    assets = []
    for theme in THEMES:
        for layer in LAYERS:
            master = MASTERS / f"{theme}_{layer}_master.png"
            output, steps = build_layer(theme, layer)
            runtime_hash = sha256(output)
            c2pa_item = c2pa_by_master[master.name]
            assets.append(
                {
                    "id": f"{theme}_{layer}",
                    "theme": theme,
                    "layer": layer,
                    "role": {"far": "far_sky", "mid": "mid_terrain_silhouette", "near": "near_decoration"}[layer],
                    "prompt_id": PROMPT_IDS[f"{theme}_{layer}"],
                    "model_slug": "gpt-image-2",
                    "master": master.relative_to(ROOT).as_posix(),
                    "master_sha256": sha256(master),
                    "runtime": output.relative_to(ROOT).as_posix(),
                    "runtime_sha256": runtime_hash,
                    "runtime_ref": f"res://{output.relative_to(ROOT).as_posix()}?v={runtime_hash[:8]}",
                    "format": "WebP",
                    "dimensions": [WIDTH, HEIGHT],
                    "decoded_vram_bytes": VRAM_BYTES,
                    "parallax_factor": PARALLAX_FACTORS[layer],
                    "safe_focus_bbox_norm": [0.22, 0.21, 0.56, 0.58],
                    "c2pa": {
                        "embedded_master": c2pa_item["embedded"],
                        "validation_state": c2pa_item["validation_state"],
                        "passed": c2pa_item["passed"],
                        "softwareAgent": c2pa_item["softwareAgent"],
                        "signature_alg": c2pa_item["signature"]["alg"],
                        "issuer": c2pa_item["signature"]["issuer"],
                    },
                    "postprocess": steps,
                }
            )

    write_quality_evidence()
    boot_splash = write_boot_splash()
    web_focal = write_web_focal()
    manifest = {
        "schema": "rift-r25-parallax-manifest.v1",
        "round": "R25",
        "release": "0.18.0-r25",
        "generator": "OpenAI built-in imagegen",
        "model_slug": "gpt-image-2",
        "prompt_manifest": "docs/evidence/R25/prompts/R25_PARALLAX_PROMPTS.md",
        "style_board": "docs/evidence/R25/style_board.md",
        "reference_hashes": REFERENCE_HASHES,
        "c2pa_verification": "docs/evidence/R25/c2pa_verification.json",
        "boot_splash": {
            "runtime": boot_splash.relative_to(ROOT).as_posix(),
            "runtime_sha256": sha256(boot_splash),
            "dimensions": [640, 360],
            "source_layers": ["rift_void_far", "rift_void_mid", "rift_void_near"],
            "postprocess": ["R25 high-quality composite", "LANCZOS resize 1536x768 -> 640x360", "128-color indexed PNG", "PNG optimize=true compress_level=9"],
        },
        "web_focal": {
            "runtime": web_focal.relative_to(ROOT).as_posix(),
            "runtime_sha256": sha256(web_focal),
            "dimensions": [640, 360],
            "source_layers": ["rift_void_far", "rift_void_mid", "rift_void_near"],
            "postprocess": ["R25 high-quality composite", "LANCZOS resize 1536x768 -> 640x360", "WebP quality=68 method=6"],
        },
        "runtime_policy": {
            "high": ["far", "mid", "near"],
            "medium": ["far", "mid", "near"],
            "low": ["far", "mid"],
            "central_gameplay_band_norm": [0.22, 0.21, 0.56, 0.58],
            "text_regions_norm": [[0.02, 0.02, 0.32, 0.16], [0.68, 0.02, 0.30, 0.16]],
            "content_hash_query": "?v=<sha256-first-8>",
        },
        "budgets": {
            "per_layer_max_dimensions": [2048, 1024],
            "desktop_high_vram_limit_bytes": 67108864,
            "mobile_low_vram_limit_bytes": 33554432,
            "desktop_high_vram_bytes": VRAM_BYTES * 9,
            "mobile_low_vram_bytes": VRAM_BYTES * 6,
        },
        "assets": assets,
    }
    manifest_path = RUNTIME / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (EVIDENCE / "source_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"R25_PARALLAX_BUILD_PASS assets={len(assets)} high_vram={VRAM_BYTES * 9} low_vram={VRAM_BYTES * 6}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
