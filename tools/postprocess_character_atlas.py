"""Apply the R20 selective external outline to each 64px atlas cell.

The outline is computed per cell, never across the full atlas, so neighboring
animation frames cannot bleed into one another.  Only transparent pixels next
to the rendered silhouette are filled; internal face, cloth, and prop details
keep their authored lighting instead of receiving a noisy all-edge treatment.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageFilter


CELL = 64
OUTLINE_RGBA = (12, 18, 34, 224)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", required=True, type=Path)
    return parser.parse_args()


def outline_cell(cell: Image.Image) -> Image.Image:
    cell = cell.convert("RGBA")
    alpha = cell.getchannel("A")
    expanded = alpha.filter(ImageFilter.MaxFilter(3))
    exterior = ImageChops.subtract(expanded, alpha)
    exterior = ImageEnhance.Brightness(exterior).enhance(0.88)
    outline = Image.new("RGBA", cell.size, OUTLINE_RGBA)
    outline.putalpha(exterior)
    return Image.alpha_composite(outline, cell)


def process(atlas_path: Path) -> None:
    atlas = Image.open(atlas_path).convert("RGBA")
    if atlas.width % CELL or atlas.height % CELL:
        raise ValueError(f"atlas dimensions {atlas.size} are not divisible by {CELL}")
    result = Image.new("RGBA", atlas.size, (0, 0, 0, 0))
    for y in range(0, atlas.height, CELL):
        for x in range(0, atlas.width, CELL):
            cell = atlas.crop((x, y, x + CELL, y + CELL))
            result.alpha_composite(outline_cell(cell), (x, y))
    temporary = atlas_path.with_suffix(".r20-outline.tmp.png")
    result.save(temporary, optimize=True)
    temporary.replace(atlas_path)
    print(f"R20_SELECTIVE_OUTLINE atlas={atlas_path} cell={CELL} rgba={OUTLINE_RGBA}")


if __name__ == "__main__":
    process(parse_args().atlas)
