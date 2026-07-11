from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
OUT = SPRITES / "generated"
HERO_MAX_DIMENSION = 112
ENEMY_MAX_DIMENSION = 96
FRAME_PADDING = 10
PALETTE_COLORS = 96

HEROES = [
    "hero_captain",
    "hero_guardian",
    "hero_scout",
]
ENEMIES = [
    "enemy_grunt",
    "enemy_fast",
    "enemy_tank",
]


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        return (0, 0, image.width, image.height)
    return bbox


def paste_part(canvas: Image.Image, source: Image.Image, box: tuple[int, int, int, int], dx: int, dy: int, shear: float = 0.0) -> None:
    part = source.crop(box)
    if abs(shear) > 0.001:
        part = part.transform(
            part.size,
            Image.Transform.AFFINE,
            (1.0, shear, -shear * part.height * 0.5, 0.0, 1.0, 0.0),
            resample=Image.Resampling.BICUBIC,
        )
    canvas.alpha_composite(part, (box[0] + dx, box[1] + dy))


def body_lean(image: Image.Image, lean: float, y_anchor: float) -> Image.Image:
    return image.transform(
        image.size,
        Image.Transform.AFFINE,
        (1.0, lean, -lean * y_anchor, 0.0, 1.0, 0.0),
        resample=Image.Resampling.BICUBIC,
    )


def make_hero_frame(source: Image.Image, frame_index: int) -> Image.Image:
    bbox = alpha_bbox(source)
    left, top, right, bottom = bbox
    width = right - left
    height = bottom - top
    mid_x = left + width // 2
    hip_y = top + int(height * 0.58)
    knee_y = top + int(height * 0.72)
    lean_table = [-0.020, 0.026, 0.020, -0.026]
    vertical_table = [1, -1, 0, -1]
    foot_table = [
        (-7, 4, 7, -3),
        (4, -3, -6, 4),
        (7, 3, -7, -3),
        (-4, -3, 6, 4),
    ]
    left_dx, left_dy, right_dx, right_dy = foot_table[frame_index % len(foot_table)]
    lean = lean_table[frame_index % len(lean_table)]
    body_dy = vertical_table[frame_index % len(vertical_table)]

    canvas = Image.new("RGBA", source.size, (0, 0, 0, 0))
    lower = (left, hip_y, right, bottom)
    upper = (left, top, right, min(bottom, hip_y + 12))
    left_leg = (left, knee_y, mid_x + 8, bottom)
    right_leg = (mid_x - 8, knee_y, right, bottom)

    paste_part(canvas, source, lower, 0, 1, 0.0)
    paste_part(canvas, source, left_leg, left_dx, left_dy, -0.05 if left_dx < 0 else 0.05)
    paste_part(canvas, source, right_leg, right_dx, right_dy, -0.05 if right_dx < 0 else 0.05)

    body = Image.new("RGBA", source.size, (0, 0, 0, 0))
    paste_part(body, source, upper, 0, body_dy, 0.0)
    body = body_lean(body, lean, top + height * 0.5)
    canvas.alpha_composite(body)
    return canvas


def make_idle_frame(source: Image.Image, frame_index: int) -> Image.Image:
    bbox = alpha_bbox(source)
    left, top, right, bottom = bbox
    height = bottom - top
    dy = -1 if frame_index == 1 else 0
    lean = 0.008 if frame_index == 1 else 0.0
    canvas = Image.new("RGBA", source.size, (0, 0, 0, 0))
    paste_part(canvas, source, (left, top, right, bottom), 0, dy, 0.0)
    if abs(lean) > 0.0:
        canvas = body_lean(canvas, lean, top + height * 0.55)
    return canvas


def make_enemy_frame(source: Image.Image, frame_index: int) -> Image.Image:
    bbox = alpha_bbox(source)
    left, top, right, bottom = bbox
    height = bottom - top
    lean = -0.035 if frame_index % 2 == 0 else 0.035
    dx = -3 if frame_index % 2 == 0 else 3
    dy = 1 if frame_index % 2 == 0 else 0
    canvas = Image.new("RGBA", source.size, (0, 0, 0, 0))
    paste_part(canvas, source, (left, top, right, bottom), dx, dy, 0.0)
    return body_lean(canvas, lean, top + height * 0.55)


def padded_union_bbox(images: list[Image.Image], padding: int) -> tuple[int, int, int, int]:
    if not images:
        return (0, 0, 1, 1)
    left = images[0].width
    top = images[0].height
    right = 0
    bottom = 0
    for image in images:
        bbox = alpha_bbox(image)
        left = min(left, bbox[0])
        top = min(top, bbox[1])
        right = max(right, bbox[2])
        bottom = max(bottom, bbox[3])
    return (
        max(0, left - padding),
        max(0, top - padding),
        min(images[0].width, right + padding),
        min(images[0].height, bottom + padding),
    )


def prepare_frame(image: Image.Image, crop_box: tuple[int, int, int, int], max_dimension: int) -> Image.Image:
    cropped = image.crop(crop_box)
    largest_side = max(cropped.size)
    if largest_side > max_dimension:
        scale = max_dimension / float(largest_side)
        size = (
            max(1, round(cropped.width * scale)),
            max(1, round(cropped.height * scale)),
        )
        cropped = cropped.resize(size, Image.Resampling.LANCZOS)
    return cropped


def save_frame(image: Image.Image, name: str, crop_box: tuple[int, int, int, int], max_dimension: int) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    prepared = prepare_frame(image, crop_box, max_dimension)
    quantized = prepared.quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    )
    quantized.save(OUT / name, optimize=True)


def build() -> None:
    for name in HEROES:
        source = Image.open(SPRITES / f"{name}.png").convert("RGBA")
        frames: dict[str, Image.Image] = {}
        for index in range(2):
            frames[f"{name}_idle_{index}.png"] = make_idle_frame(source, index)
        for index in range(4):
            frames[f"{name}_walk_{index}.png"] = make_hero_frame(source, index)
        crop_box = padded_union_bbox(list(frames.values()), FRAME_PADDING)
        for file_name, frame in frames.items():
            save_frame(frame, file_name, crop_box, HERO_MAX_DIMENSION)

    for name in ENEMIES:
        source = Image.open(SPRITES / f"{name}.png").convert("RGBA")
        frames: dict[str, Image.Image] = {f"{name}_idle_0.png": source}
        for index in range(2):
            frames[f"{name}_walk_{index}.png"] = make_enemy_frame(source, index)
        crop_box = padded_union_bbox(list(frames.values()), FRAME_PADDING)
        for file_name, frame in frames.items():
            save_frame(frame, file_name, crop_box, ENEMY_MAX_DIMENSION)

    for path in sorted(OUT.glob("*.png")):
        print(f"{path.relative_to(ROOT)} {path.stat().st_size} bytes")


if __name__ == "__main__":
    build()
