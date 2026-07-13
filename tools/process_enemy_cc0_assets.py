"""Build the compact CC0 enemy animation subset used by the game.

Raw OpenGameArt downloads intentionally live in the gitignored
``tools/asset_sources`` directory.  Only the cropped, outlined and palettized
96px derivatives produced here are distributed under ``assets/sprites``.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "tools" / "asset_sources"
SPRITE_ROOT = ROOT / "assets" / "sprites"
FRAME_ROOT = SPRITE_ROOT / "generated"
CANVAS_SIZE = 96
CONTENT_SIZE = 86
PALETTE_COLORS = 48

# A high-value neutral ramp lets Enemy.body_color keep the existing threat
# palette at runtime.  The plum outline ties the pixel sources to Crackveil's
# existing dark-rift silhouettes.
THEME_SHADOW = (70, 44, 60)
THEME_MID = (205, 178, 178)
THEME_HIGHLIGHT = (255, 244, 222)
THEME_OUTLINE = (18, 5, 24, 244)


@dataclass(frozen=True)
class EnemyJob:
    source: str
    columns: int
    rows: int
    cells: tuple[tuple[int, int], ...]
    smooth_resize: bool = False


# Eman Quest sheets contain three-frame directional rows; the first row is the
# front-facing walk used by the existing horizontal flip system.  Sean
# Noonan's two sheets are eight-frame top-down cycles laid out row-major (the
# ninth grid cell is empty).
JOBS: dict[str, EnemyJob] = {
    "enemy_grunt": EnemyJob(
        "cultist.png", 3, 3, ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1))
    ),
    "enemy_fast": EnemyJob(
        "eman_beetle2.png", 3, 1, ((0, 0), (1, 0), (2, 0), (1, 0))
    ),
    "enemy_tank": EnemyJob(
        "tentacle_eye.png",
        3,
        3,
        ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)),
        True,
    ),
    "enemy_elite_split": EnemyJob(
        "eman_crystal.png", 3, 4, ((0, 0), (1, 0), (2, 0), (1, 0))
    ),
    "enemy_elite_field": EnemyJob(
        "eman_mushroom.png", 3, 4, ((0, 0), (1, 0), (2, 0), (1, 0))
    ),
    "enemy_elite_swift": EnemyJob(
        "eman_crab.png", 3, 4, ((0, 0), (1, 0), (2, 0), (1, 0))
    ),
    "enemy_boss": EnemyJob(
        "tentacle_teeth.png",
        3,
        3,
        ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)),
        True,
    ),
}


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 8 else 0)
    return alpha.getbbox() or (0, 0, image.width, image.height)


def extract_cells(source: Image.Image, job: EnemyJob) -> list[Image.Image]:
    if source.width % job.columns or source.height % job.rows:
        raise ValueError(
            f"Source grid is not integral: {job.source} {source.size} / "
            f"{job.columns}x{job.rows}"
        )
    cell_width = source.width // job.columns
    cell_height = source.height // job.rows
    cells: list[Image.Image] = []
    for column, row in job.cells:
        cells.append(
            source.crop(
                (
                    column * cell_width,
                    row * cell_height,
                    (column + 1) * cell_width,
                    (row + 1) * cell_height,
                )
            )
        )
    return cells


def union_bbox(frames: list[Image.Image]) -> tuple[int, int, int, int]:
    boxes = [alpha_bbox(frame) for frame in frames]
    left = min(box[0] for box in boxes)
    top = min(box[1] for box in boxes)
    right = max(box[2] for box in boxes)
    bottom = max(box[3] for box in boxes)
    margin = 2
    return (
        max(0, left - margin),
        max(0, top - margin),
        min(frames[0].width, right + margin),
        min(frames[0].height, bottom + margin),
    )


def color_grade(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A").point(lambda value: 0 if value < 8 else value)
    luminance = ImageOps.autocontrast(image.convert("L"), cutoff=1)
    graded = ImageOps.colorize(
        luminance,
        black=THEME_SHADOW,
        mid=THEME_MID,
        white=THEME_HIGHLIGHT,
        blackpoint=0,
        midpoint=142,
        whitepoint=255,
    ).convert("RGBA")
    graded.putalpha(alpha)
    return graded


def normalize_frame(
    frame: Image.Image,
    crop_box: tuple[int, int, int, int],
    smooth_resize: bool,
) -> Image.Image:
    cropped = frame.crop(crop_box)
    scale = min(CONTENT_SIZE / cropped.width, CONTENT_SIZE / cropped.height)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resampling = Image.Resampling.LANCZOS if smooth_resize else Image.Resampling.NEAREST
    resized = cropped.resize(size, resampling)
    graded = color_grade(resized)

    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    position = ((CANVAS_SIZE - size[0]) // 2, (CANVAS_SIZE - size[1]) // 2)
    alpha = Image.new("L", canvas.size, 0)
    alpha.paste(graded.getchannel("A"), position)
    expanded = alpha.filter(ImageFilter.MaxFilter(5))
    outline_alpha = ImageChops.subtract(expanded, alpha)
    outline = Image.new("RGBA", canvas.size, THEME_OUTLINE)
    outline.putalpha(ImageChops.multiply(outline_alpha, Image.new("L", canvas.size, THEME_OUTLINE[3])))
    canvas.alpha_composite(outline)
    canvas.alpha_composite(graded, position)

    # Palettize deterministically, then return to RGBA so Godot sees ordinary
    # transparency instead of relying on a palette transparency index.
    return canvas.quantize(
        colors=PALETTE_COLORS,
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True, compress_level=9)


def build() -> None:
    missing = [job.source for job in JOBS.values() if not (SOURCE_ROOT / job.source).is_file()]
    if missing:
        raise FileNotFoundError(
            "Missing ignored CC0 sources under tools/asset_sources: " + ", ".join(sorted(missing))
        )

    for base_name, job in JOBS.items():
        source = Image.open(SOURCE_ROOT / job.source).convert("RGBA")
        raw_frames = extract_cells(source, job)
        crop_box = union_bbox(raw_frames)
        frames = [normalize_frame(frame, crop_box, job.smooth_resize) for frame in raw_frames]

        for stale in FRAME_ROOT.glob(f"{base_name}_idle_*.png"):
            stale.unlink()
        for stale in FRAME_ROOT.glob(f"{base_name}_walk_*.png"):
            stale.unlink()

        idle_frames = (frames[1], frames[0])
        save_png(idle_frames[0], SPRITE_ROOT / f"{base_name}.png")
        for index, frame in enumerate(idle_frames):
            save_png(frame, FRAME_ROOT / f"{base_name}_idle_{index}.png")
        for index, frame in enumerate(frames):
            save_png(frame, FRAME_ROOT / f"{base_name}_walk_{index}.png")

        output_paths = [SPRITE_ROOT / f"{base_name}.png"]
        output_paths.extend(sorted(FRAME_ROOT.glob(f"{base_name}_*.png")))
        total_bytes = sum(path.stat().st_size for path in output_paths)
        print(
            f"{base_name}: source={job.source} frames={len(frames)} "
            f"canvas={CANVAS_SIZE}x{CANVAS_SIZE} bytes={total_bytes}"
        )


if __name__ == "__main__":
    build()
