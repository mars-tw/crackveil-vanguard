"""Build the small, game-ready M3 subset from ignored Kenney source packs.

Requires Pillow, numpy and soundfile. Raw archives are intentionally kept under
tools/asset_sources/ and are not distributed with the game.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import soundfile as sf
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "tools" / "asset_sources"
PARTICLE_ROOT = SOURCE_ROOT / "particle" / "PNG (Transparent)"
VFX_OUTPUT = ROOT / "assets" / "vfx" / "kenney_particle"
AUDIO_OUTPUT = ROOT / "assets" / "audio"

CYAN = ((0, 20, 31), (40, 221, 255), (224, 253, 255))
EMBER = ((48, 8, 0), (255, 91, 25), (255, 241, 168))

# Twelve distinct source sprites: each is cropped, resized, and color-graded.
VFX_JOBS = {
    "burst_fire_ember.png": ("fire_01.png", EMBER),
    "burst_fire_cyan.png": ("fire_02.png", CYAN),
    "burst_arc_cyan.png": ("spark_01.png", CYAN),
    "burst_arc_ember.png": ("spark_02.png", EMBER),
    "smoke_ring_cyan.png": ("smoke_09.png", CYAN),
    "smoke_ring_ember.png": ("smoke_10.png", EMBER),
    "flare_cyan.png": ("flare_01.png", CYAN),
    "flare_ember.png": ("star_08.png", EMBER),
    "level_column_cyan.png": ("muzzle_01.png", CYAN),
    "level_column_ember.png": ("muzzle_05.png", EMBER),
    "shockwave_cyan.png": ("circle_03.png", CYAN),
    "shockwave_ember.png": ("light_03.png", EMBER),
}

# output: (source, maximum seconds, normalized peak dBFS)
AUDIO_JOBS = {
    "hit.wav": (SOURCE_ROOT / "impact" / "Audio" / "impactGeneric_light_002.ogg", 0.16, -4.0),
    "kill_thump.wav": (SOURCE_ROOT / "impact" / "Audio" / "impactPunch_heavy_002.ogg", 0.48, -2.0),
    "explosion.wav": (SOURCE_ROOT / "scifi" / "Audio" / "explosionCrunch_000.ogg", 0.80, -1.5),
    "fire.wav": (SOURCE_ROOT / "scifi" / "Audio" / "laserSmall_000.ogg", 0.24, -4.0),
    "pickup.wav": (SOURCE_ROOT / "digital" / "Audio" / "highUp.ogg", 0.44, -4.0),
    "upgrade.wav": (SOURCE_ROOT / "digital" / "Audio" / "powerUp1.ogg", 1.00, -2.5),
    "ui_click.wav": (SOURCE_ROOT / "ui" / "Sounds" / "tap-b.ogg", 0.08, -5.0),
}


def _crop_alpha(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 3 else 0).getbbox()
    if bbox is None:
        return image
    left, top, right, bottom = bbox
    margin = max(4, int(max(right - left, bottom - top) * 0.06))
    return image.crop(
        (
            max(0, left - margin),
            max(0, top - margin),
            min(image.width, right + margin),
            min(image.height, bottom + margin),
        )
    )


def _color_grade(image: Image.Image, palette: tuple[tuple[int, int, int], ...]) -> Image.Image:
    pixels = np.asarray(image.convert("RGBA"), dtype=np.float32)
    luminance = (
        pixels[..., 0] * 0.2126 + pixels[..., 1] * 0.7152 + pixels[..., 2] * 0.0722
    ) / 255.0
    shadow, mid, highlight = (np.asarray(color, dtype=np.float32) for color in palette)
    low_t = np.clip(luminance * 2.0, 0.0, 1.0)[..., None]
    high_t = np.clip((luminance - 0.5) * 2.0, 0.0, 1.0)[..., None]
    rgb = shadow + (mid - shadow) * low_t
    rgb = rgb + (highlight - rgb) * high_t
    output = np.concatenate((np.clip(rgb, 0, 255), pixels[..., 3:4]), axis=-1).astype(np.uint8)
    return Image.fromarray(output, "RGBA")


def build_vfx() -> None:
    VFX_OUTPUT.mkdir(parents=True, exist_ok=True)
    for output_name, (source_name, palette) in VFX_JOBS.items():
        image = _crop_alpha(Image.open(PARTICLE_ROOT / source_name).convert("RGBA"))
        image.thumbnail((120, 120), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        canvas.alpha_composite(image, ((128 - image.width) // 2, (128 - image.height) // 2))
        _color_grade(canvas, palette).save(VFX_OUTPUT / output_name, optimize=True)


def _trim_and_convert(source: Path, max_seconds: float, peak_db: float) -> np.ndarray:
    audio, sample_rate = sf.read(source, dtype="float32", always_2d=True)
    if sample_rate != 44_100:
        raise ValueError(f"Expected 44.1 kHz Kenney source, got {sample_rate}: {source}")
    mono = audio.mean(axis=1)
    threshold = max(float(np.max(np.abs(mono))) * 0.008, 1e-4)
    active = np.flatnonzero(np.abs(mono) >= threshold)
    if active.size:
        pad = int(sample_rate * 0.012)
        mono = mono[max(0, int(active[0]) - pad) : min(len(mono), int(active[-1]) + pad + 1)]
    mono = mono[: int(sample_rate * max_seconds)]
    fade = min(int(sample_rate * 0.006), len(mono) // 2)
    if fade > 0:
        mono[:fade] *= np.linspace(0.0, 1.0, fade, endpoint=True)
        mono[-fade:] *= np.linspace(1.0, 0.0, fade, endpoint=True)
    peak = float(np.max(np.abs(mono))) if mono.size else 0.0
    target_peak = math.pow(10.0, peak_db / 20.0)
    if peak > 1e-6:
        mono *= target_peak / peak
    return np.clip(mono, -1.0, 1.0)


def build_audio() -> None:
    AUDIO_OUTPUT.mkdir(parents=True, exist_ok=True)
    for output_name, (source, max_seconds, peak_db) in AUDIO_JOBS.items():
        audio = _trim_and_convert(source, max_seconds, peak_db)
        sf.write(AUDIO_OUTPUT / output_name, audio, 44_100, subtype="PCM_16")


if __name__ == "__main__":
    build_vfx()
    build_audio()
    print(f"Built {len(VFX_JOBS)} VFX textures and {len(AUDIO_JOBS)} sound effects.")
