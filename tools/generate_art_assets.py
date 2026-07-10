from __future__ import annotations

import math
import random
from pathlib import Path

try:
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as exc:
    raise SystemExit(
        "Missing Pillow/numpy. Install with: python -m pip install pillow numpy"
    ) from exc


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art"


def save_rgba(name: str, arr: np.ndarray) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(OUT / name, optimize=True)


def radial_glow(size: int = 192) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2.0
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.5)
    alpha = np.clip(1.0 - dist, 0.0, 1.0) ** 2.65
    core = np.clip(1.0 - dist * 3.2, 0.0, 1.0) ** 0.7
    img = np.zeros((size, size, 4), dtype=np.float32)
    img[..., 0] = 170 + core * 70
    img[..., 1] = 235 + core * 20
    img[..., 2] = 255
    img[..., 3] = alpha * 255
    return img


def ellipse_shadow(size: int = 128) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    cx = (size - 1) / 2.0
    cy = size * 0.58
    dx = (xx - cx) / (size * 0.42)
    dy = (yy - cy) / (size * 0.18)
    dist = dx * dx + dy * dy
    alpha = np.clip(1.0 - dist, 0.0, 1.0) ** 1.6
    img = np.zeros((size, size, 4), dtype=np.float32)
    img[..., 3] = alpha * 150
    return img


def particle_core(size: int = 48) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2.0
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.5)
    alpha = np.clip(1.0 - dist, 0.0, 1.0) ** 3.8
    img = np.zeros((size, size, 4), dtype=np.float32)
    img[..., 0] = 255
    img[..., 1] = 240
    img[..., 2] = 210
    img[..., 3] = alpha * 255
    return img


def nebula(size: int = 512, seed: int = 77) -> np.ndarray:
    rng = np.random.default_rng(seed)
    base = np.zeros((size, size), dtype=np.float32)
    for scale, weight in [(16, 0.38), (32, 0.28), (64, 0.2), (128, 0.14)]:
        small = rng.random((scale, scale), dtype=np.float32)
        img = Image.fromarray((small * 255).astype(np.uint8), "L").resize(
            (size, size), Image.Resampling.BICUBIC
        )
        arr = np.asarray(img, dtype=np.float32) / 255.0
        base += arr * weight
    base = np.clip((base - 0.32) / 0.68, 0.0, 1.0)
    yy, xx = np.mgrid[0:size, 0:size]
    waves = (
        np.sin(xx * 0.021 + yy * 0.014)
        + np.sin(xx * -0.011 + yy * 0.026 + 2.4)
        + np.sin(np.sqrt((xx - 250) ** 2 + (yy - 190) ** 2) * 0.026)
    ) / 3.0
    field = np.clip(base * 0.72 + (waves + 1.0) * 0.18, 0.0, 1.0)
    img = np.zeros((size, size, 4), dtype=np.float32)
    img[..., 0] = 42 + field * 80
    img[..., 1] = 82 + field * 100
    img[..., 2] = 142 + field * 112
    img[..., 3] = field * 150
    return img


def deep_space_gradient(size: int = 512) -> np.ndarray:
    yy, xx = np.mgrid[0:size, 0:size]
    nx = (xx / (size - 1)) * 2.0 - 1.0
    ny = (yy / (size - 1)) * 2.0 - 1.0
    r = np.sqrt(nx * nx + ny * ny)
    diagonal = (nx * -0.35 + ny * 0.65 + 1.0) * 0.5
    energy = np.clip(1.0 - r, 0.0, 1.0) ** 1.4
    img = np.zeros((size, size, 4), dtype=np.float32)
    img[..., 0] = 5 + diagonal * 15 + energy * 18
    img[..., 1] = 9 + diagonal * 18 + energy * 24
    img[..., 2] = 20 + diagonal * 45 + energy * 52
    img[..., 3] = 255
    return img


def rift_cracks(size: int = 512, seed: int = 11) -> np.ndarray:
    rng = random.Random(seed)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)

    def branch(points: list[tuple[float, float]], depth: int) -> None:
        width = max(1, 5 - depth)
        color = (84, 238, 255, max(40, 175 - depth * 38))
        draw.line(points, fill=color, width=width, joint="curve")
        if depth >= 3:
            return
        for px, py in points[1:-1:2]:
            if rng.random() < 0.58:
                angle = rng.uniform(-2.4, 2.4)
                length = rng.uniform(38, 92) / (depth + 1)
                end = (px + math.cos(angle) * length, py + math.sin(angle) * length)
                mid = ((px + end[0]) * 0.5 + rng.uniform(-18, 18), (py + end[1]) * 0.5 + rng.uniform(-18, 18))
                branch([(px, py), mid, end], depth + 1)

    for _ in range(7):
        x = rng.uniform(-40, size + 40)
        y = rng.uniform(-20, size + 20)
        angle = rng.uniform(-0.9, 0.9) + math.pi * 0.26
        points: list[tuple[float, float]] = []
        for step in range(rng.randint(4, 7)):
            points.append((x, y))
            x += math.cos(angle + rng.uniform(-0.55, 0.55)) * rng.uniform(48, 96)
            y += math.sin(angle + rng.uniform(-0.55, 0.55)) * rng.uniform(48, 96)
        branch(points, 0)

    blurred = glow.filter(ImageFilter.GaussianBlur(7))
    img.alpha_composite(blurred)
    img.alpha_composite(glow)
    return np.asarray(img, dtype=np.uint8)


def vignette(width: int = 1024, height: int = 1024) -> np.ndarray:
    yy, xx = np.mgrid[0:height, 0:width]
    nx = (xx / (width - 1)) * 2.0 - 1.0
    ny = (yy / (height - 1)) * 2.0 - 1.0
    dist = np.sqrt(nx * nx + ny * ny)
    alpha = np.clip((dist - 0.42) / 0.58, 0.0, 1.0) ** 1.55
    img = np.zeros((height, width, 4), dtype=np.float32)
    img[..., 0] = 2
    img[..., 1] = 4
    img[..., 2] = 11
    img[..., 3] = alpha * 180
    return img


def ui_panel(size: int = 96) -> np.ndarray:
    img = Image.new("RGBA", (size, size), (9, 16, 34, 216))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((1, 1, size - 2, size - 2), radius=8, outline=(72, 231, 255, 210), width=2)
    draw.rounded_rectangle((5, 5, size - 6, size - 6), radius=5, outline=(157, 108, 255, 72), width=1)
    for i in range(10):
        alpha = int(70 * (1.0 - i / 10.0))
        draw.line((10 + i * 7, 2, 24 + i * 7, size - 3), fill=(79, 234, 255, alpha), width=1)
    return np.asarray(img, dtype=np.uint8)


def icon(kind: str, size: int = 64) -> np.ndarray:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if kind == "health":
        fill = (255, 92, 112, 255)
        draw.ellipse((10, 12, 34, 36), fill=fill)
        draw.ellipse((30, 12, 54, 36), fill=fill)
        draw.polygon([(8, 28), (56, 28), (32, 58)], fill=fill)
        draw.line((18, 34, 28, 34, 32, 25, 38, 43, 46, 43), fill=(255, 230, 210, 210), width=3)
    elif kind == "xp":
        fill = (91, 235, 255, 255)
        draw.polygon([(32, 5), (54, 26), (45, 58), (19, 58), (10, 26)], fill=fill)
        draw.line((32, 5, 32, 58), fill=(245, 255, 255, 180), width=2)
        draw.line((12, 26, 52, 26), fill=(245, 255, 255, 140), width=2)
    elif kind == "gold":
        draw.ellipse((8, 12, 56, 52), fill=(255, 190, 64, 255), outline=(255, 246, 170, 255), width=3)
        draw.arc((18, 20, 46, 44), 210, 520, fill=(130, 72, 20, 210), width=4)
    return np.asarray(img.filter(ImageFilter.GaussianBlur(0.15)), dtype=np.uint8)


def main() -> None:
    save_rgba("radial_glow.png", radial_glow())
    save_rgba("ellipse_shadow.png", ellipse_shadow())
    save_rgba("particle_core.png", particle_core())
    save_rgba("nebula_layer.png", nebula())
    save_rgba("deep_space_gradient.png", deep_space_gradient())
    save_rgba("rift_cracks.png", rift_cracks())
    save_rgba("vignette.png", vignette())
    save_rgba("ui_panel_9slice.png", ui_panel())
    save_rgba("icon_health.png", icon("health"))
    save_rgba("icon_xp.png", icon("xp"))
    save_rgba("icon_gold.png", icon("gold"))
    for path in sorted(OUT.glob("*.png")):
        print(f"{path.relative_to(ROOT)} {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
