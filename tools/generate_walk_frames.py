"""Compatibility entry point for the true Blender articulation pipeline.

The previous implementation affine-skewed one flat PNG.  That is intentionally
gone: every pose now comes from separately articulated Blender body parts.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BLENDER = Path(os.environ.get("BLENDER_EXE", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"))
BUILDER = ROOT / "tools" / "generate_true_animation_atlas.py"
ATLAS = ROOT / "assets" / "sprites" / "true_character_atlas.png"
PROOF = ROOT / "docs" / "true_animation_pose_proof.png"
CELL = 64
STATE_ROWS = {"idle": 0, "walk": 1, "attack": 2, "hurt": 3, "death": 4}
CHARACTER_ROWS = {"hero_captain": 0, "enemy_grunt": 3}


def crop(atlas: Image.Image, character: str, state: str, frame: int) -> Image.Image:
    row = CHARACTER_ROWS[character] * 5 + STATE_ROWS[state]
    return atlas.crop((frame * CELL, row * CELL, (frame + 1) * CELL, (row + 1) * CELL))


def build_pose_proof() -> None:
    atlas = Image.open(ATLAS).convert("RGBA")
    samples = (
        ("hero_captain", "idle", 0),
        ("hero_captain", "walk", 1),
        ("hero_captain", "walk", 5),
        ("hero_captain", "attack", 0),
        ("hero_captain", "attack", 2),
        ("hero_captain", "hurt", 1),
        ("enemy_grunt", "walk", 1),
        ("enemy_grunt", "walk", 5),
        ("enemy_grunt", "attack", 0),
        ("enemy_grunt", "attack", 2),
        ("enemy_grunt", "hurt", 1),
        ("enemy_grunt", "death", 5),
    )
    proof = Image.new("RGBA", (len(samples) * 96, 112), (13, 18, 29, 255))
    draw = ImageDraw.Draw(proof)
    for index, (character, state, frame) in enumerate(samples):
        pose_image = crop(atlas, character, state, frame).resize((88, 88), Image.Resampling.NEAREST)
        proof.alpha_composite(pose_image, (index * 96 + 4, 2))
        draw.text((index * 96 + 4, 94), f"{state} {frame}", fill=(235, 242, 255, 255))
    PROOF.parent.mkdir(parents=True, exist_ok=True)
    proof.save(PROOF, optimize=True)

    # Static acceptance: opposing walk poses and anticipation/impact/hurt must
    # have material pixel differences, not just identical copied frames.
    comparisons = (
        (("hero_captain", "walk", 1), ("hero_captain", "walk", 5)),
        (("hero_captain", "attack", 0), ("hero_captain", "attack", 2)),
        (("hero_captain", "attack", 2), ("hero_captain", "hurt", 1)),
        (("enemy_grunt", "walk", 1), ("enemy_grunt", "walk", 5)),
        (("enemy_grunt", "attack", 0), ("enemy_grunt", "attack", 2)),
        (("enemy_grunt", "hurt", 1), ("enemy_grunt", "death", 5)),
    )
    for first, second in comparisons:
        difference = ImageChops.difference(crop(atlas, *first), crop(atlas, *second))
        changed_bbox = difference.getbbox()
        if changed_bbox is None:
            raise RuntimeError(f"Pose frames are identical: {first} / {second}")


def main() -> None:
    if not BLENDER.exists():
        raise FileNotFoundError(f"Blender 5.1 not found: {BLENDER}")
    subprocess.run(
        [str(BLENDER), "--background", "--python", str(BUILDER)],
        cwd=ROOT,
        check=True,
    )
    build_pose_proof()
    print(f"TRUE_ANIMATION_PROOF {PROOF.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
