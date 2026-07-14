"""Build R16 old/new pose and pure-silhouette acceptance proofs."""

from __future__ import annotations

import argparse
import io
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "assets" / "sprites" / "true_character_atlas.png"
OUTPUT = ROOT / "docs" / "art_r16_character_atlas_proof.png"
SILHOUETTE_OUTPUT = ROOT / "docs" / "art_r16_silhouette_proof.png"
ENEMY_OUTPUT = ROOT / "docs" / "art_r16_enemy_proof.png"
BASELINE_REF = "28c22c89fdb9e07884895dbafe9e73df887d8719"
CELL = 64
STATE_COUNT = 5
FRAME_COUNTS = (4, 8, 6, 3, 6)
STATE_FRAME_OFFSETS = (0, 4, 12, 18, 21)
FRAMES_PER_CHARACTER = sum(FRAME_COUNTS)
HERO_IDS = (
    "hero_captain",
    "hero_rift_sniper",
    "hero_void_weaver",
    "hero_arc_scout",
    "hero_echo_singer",
    "hero_ember_grenadier",
    "hero_line_mender",
    "hero_orbit_guard",
    "hero_pulse_artificer",
    "hero_shepherd",
)
ENEMY_IDS = (
    "enemy_grunt",
    "enemy_fast",
    "enemy_tank",
    "enemy_elite_field",
    "enemy_elite_split",
    "enemy_elite_swift",
    "enemy_boss",
)
OLD_HERO_INDEX = {
    "hero_captain": 0,
    "hero_rift_sniper": 0,
    "hero_void_weaver": 2,
    "hero_arc_scout": 2,
    "hero_echo_singer": 2,
    "hero_ember_grenadier": 1,
    "hero_line_mender": 2,
    "hero_orbit_guard": 1,
    "hero_pulse_artificer": 1,
    "hero_shepherd": 3,
}
POSES = (("IDLE", 0, 0), ("WALK", 1, 2), ("ATTACK", 2, 2))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--before-ref", default=BASELINE_REF)
    return parser.parse_args()


def frame(atlas: Image.Image, character_index: int, state_index: int, frame_index: int, packed: bool = True) -> Image.Image:
    if packed:
        atlas_cell = character_index * FRAMES_PER_CHARACTER + STATE_FRAME_OFFSETS[state_index] + frame_index
        x = (atlas_cell % 8) * CELL
        y = (atlas_cell // 8) * CELL
    else:
        x = frame_index * CELL
        y = (character_index * STATE_COUNT + state_index) * CELL
    return atlas.crop((x, y, x + CELL, y + CELL))


def baseline_atlas(ref: str) -> Image.Image:
    payload = subprocess.check_output(
        ["git", "show", f"{ref}:assets/sprites/true_character_atlas.png"],
        cwd=ROOT,
    )
    return Image.open(io.BytesIO(payload)).convert("RGBA")


def draw_pose_proof(before: Image.Image, after: Image.Image) -> None:
    label_width = 154
    header_height = 42
    row_height = CELL + 10
    canvas = Image.new("RGBA", (label_width + len(POSES) * CELL * 2, header_height + len(HERO_IDS) * row_height), (7, 14, 29, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((8, 7), "CV ART-R16  |  OLD / NEW  |  NATIVE 64PX", fill=(226, 239, 250, 255))
    for pose_index, (pose_name, _state, _frame) in enumerate(POSES):
        x = label_width + pose_index * CELL * 2
        draw.text((x + 8, 7), pose_name, fill=(109, 214, 239, 255))
        draw.text((x + 8, 23), "OLD", fill=(153, 164, 180, 255))
        draw.text((x + CELL + 8, 23), "NEW", fill=(255, 197, 91, 255))
    for hero_index, hero_id in enumerate(HERO_IDS):
        y = header_height + hero_index * row_height
        draw.text((8, y + 12), hero_id.removeprefix("hero_"), fill=(225, 234, 245, 255))
        draw.text((8, y + 33), f"new atlas row {hero_index}", fill=(91, 142, 174, 255))
        for pose_index, (_pose_name, state_index, frame_index) in enumerate(POSES):
            x = label_width + pose_index * CELL * 2
            old_pose = frame(before, OLD_HERO_INDEX[hero_id], state_index, frame_index, packed=False)
            new_pose = frame(after, hero_index, state_index, frame_index)
            canvas.alpha_composite(old_pose, (x, y))
            canvas.alpha_composite(new_pose, (x + CELL, y))
            draw.rectangle((x, y, x + CELL - 1, y + CELL - 1), outline=(51, 73, 102, 255))
            draw.rectangle((x + CELL, y, x + CELL * 2 - 1, y + CELL - 1), outline=(118, 102, 51, 255))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUTPUT, optimize=True)
    print(f"ART_R16_POSE_PROOF {OUTPUT} {canvas.width}x{canvas.height}")


def black_silhouette(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result.putalpha(alpha)
    return result


def draw_silhouette_proof(after: Image.Image) -> None:
    label_width = 154
    header_height = 34
    row_height = CELL + 8
    canvas = Image.new("RGBA", (label_width + CELL * 2, header_height + len(HERO_IDS) * row_height), (218, 223, 226, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((8, 8), "PURE BLACK SILHOUETTES", fill=(18, 26, 34, 255))
    draw.text((label_width + 10, 8), "IDLE", fill=(18, 26, 34, 255))
    draw.text((label_width + CELL + 7, 8), "IMPACT", fill=(18, 26, 34, 255))
    for hero_index, hero_id in enumerate(HERO_IDS):
        y = header_height + hero_index * row_height
        draw.text((8, y + 24), hero_id.removeprefix("hero_"), fill=(18, 26, 34, 255))
        idle = black_silhouette(frame(after, hero_index, 0, 0))
        impact = black_silhouette(frame(after, hero_index, 2, 2))
        canvas.alpha_composite(idle, (label_width, y))
        canvas.alpha_composite(impact, (label_width + CELL, y))
        draw.rectangle((label_width, y, label_width + CELL - 1, y + CELL - 1), outline=(142, 151, 158, 255))
        draw.rectangle((label_width + CELL, y, label_width + CELL * 2 - 1, y + CELL - 1), outline=(142, 151, 158, 255))
    canvas.save(SILHOUETTE_OUTPUT, optimize=True)
    print(f"ART_R16_SILHOUETTE_PROOF {SILHOUETTE_OUTPUT} {canvas.width}x{canvas.height}")


def draw_enemy_proof(after: Image.Image) -> None:
    poses = (("IDLE", 0, 0), ("IMPACT", 2, 2), ("HURT", 3, 1), ("DEATH", 4, 5))
    label_width = 154
    header_height = 34
    row_height = CELL + 8
    canvas = Image.new("RGBA", (label_width + len(poses) * CELL, header_height + len(ENEMY_IDS) * row_height), (7, 14, 29, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((8, 8), "R16 ENEMY REBUILD", fill=(226, 239, 250, 255))
    for pose_index, (pose_name, _state, _frame) in enumerate(poses):
        draw.text((label_width + pose_index * CELL + 7, 8), pose_name, fill=(255, 197, 91, 255))
    for enemy_offset, enemy_id in enumerate(ENEMY_IDS):
        y = header_height + enemy_offset * row_height
        draw.text((8, y + 24), enemy_id.removeprefix("enemy_"), fill=(225, 234, 245, 255))
        character_index = len(HERO_IDS) + enemy_offset
        for pose_index, (_pose_name, state_index, frame_index) in enumerate(poses):
            x = label_width + pose_index * CELL
            pose_image = frame(after, character_index, state_index, frame_index)
            canvas.alpha_composite(pose_image, (x, y))
            draw.rectangle((x, y, x + CELL - 1, y + CELL - 1), outline=(82, 94, 118, 255))
    canvas.save(ENEMY_OUTPUT, optimize=True)
    print(f"ART_R16_ENEMY_PROOF {ENEMY_OUTPUT} {canvas.width}x{canvas.height}")


def main() -> None:
    args = parse_args()
    before = baseline_atlas(args.before_ref)
    after = Image.open(ATLAS).convert("RGBA")
    draw_pose_proof(before, after)
    draw_silhouette_proof(after)
    draw_enemy_proof(after)


if __name__ == "__main__":
    main()
