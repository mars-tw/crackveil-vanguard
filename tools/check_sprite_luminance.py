"""R20.1 luminance and saturation gate for the true-character atlas.

Only visible pixels participate in the measurement.  Each character owns five
64px rows (idle/walk/attack/hurt/death); unused frame slots remain transparent.
The command exits non-zero when any character leaves either approved band.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ATLAS = ROOT / "assets" / "sprites" / "true_character_atlas.png"
CELL = 64
COLUMNS = 8
STATE_COUNT = 5
FRAME_COUNTS = (4, 8, 6, 3, 6)
FRAMES_PER_CHARACTER = sum(FRAME_COUNTS)
AVERAGE_MIN = 0.30
AVERAGE_MAX = 0.75
NEAR_BLACK_LUMA = 0.10
NEAR_BLACK_MAX = 0.35
AVERAGE_SATURATION_MIN = 0.32
LOW_SATURATION = 0.15
LOW_SATURATION_MAX = 0.20
CHARACTER_IDS = (
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
    "enemy_grunt",
    "enemy_fast",
    "enemy_tank",
    "enemy_elite_field",
    "enemy_elite_split",
    "enemy_elite_swift",
    "enemy_boss",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", type=Path, default=DEFAULT_ATLAS)
    parser.add_argument("--json-output", type=Path)
    return parser.parse_args()


def measure(atlas_path: Path) -> tuple[list[dict[str, object]], list[str]]:
    atlas = Image.open(atlas_path).convert("RGBA")
    expected_rows = (len(CHARACTER_IDS) * FRAMES_PER_CHARACTER + COLUMNS - 1) // COLUMNS
    expected_size = (COLUMNS * CELL, expected_rows * CELL)
    failures: list[str] = []
    if atlas.size != expected_size:
        failures.append(f"atlas size {atlas.size} != {expected_size}")

    records: list[dict[str, object]] = []
    for index, character_id in enumerate(CHARACTER_IDS):
        visible_luma: list[float] = []
        visible_saturation: list[float] = []
        for frame_offset in range(FRAMES_PER_CHARACTER):
            atlas_cell = index * FRAMES_PER_CHARACTER + frame_offset
            x0 = (atlas_cell % COLUMNS) * CELL
            y0 = (atlas_cell // COLUMNS) * CELL
            block = atlas.crop((x0, y0, x0 + CELL, y0 + CELL))
            for red, green, blue, alpha in block.get_flattened_data():
                if alpha <= 8:
                    continue
                visible_luma.append((0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255.0)
                maximum = max(red, green, blue)
                minimum = min(red, green, blue)
                visible_saturation.append(0.0 if maximum == 0 else (maximum - minimum) / maximum)
        if not visible_luma:
            failures.append(f"{character_id}: no visible pixels")
            average = 0.0
            near_black = 1.0
            average_saturation = 0.0
            low_saturation = 1.0
        else:
            average = sum(visible_luma) / len(visible_luma)
            near_black = sum(value < NEAR_BLACK_LUMA for value in visible_luma) / len(visible_luma)
            average_saturation = sum(visible_saturation) / len(visible_saturation)
            low_saturation = sum(value < LOW_SATURATION for value in visible_saturation) / len(visible_saturation)
        passed = (
            AVERAGE_MIN <= average <= AVERAGE_MAX
            and near_black < NEAR_BLACK_MAX
            and average_saturation >= AVERAGE_SATURATION_MIN
            and low_saturation < LOW_SATURATION_MAX
        )
        if not passed:
            failures.append(
                f"{character_id}: avg={average:.4f} (required {AVERAGE_MIN:.2f}-{AVERAGE_MAX:.2f}), "
                f"near_black={near_black:.2%} (required <{NEAR_BLACK_MAX:.0%}), "
                f"avg_saturation={average_saturation:.4f} (required >={AVERAGE_SATURATION_MIN:.2f}), "
                f"low_saturation={low_saturation:.2%} (required <{LOW_SATURATION_MAX:.0%})"
            )
        records.append({
            "character": character_id,
            "visible_pixels": len(visible_luma),
            "average_luminance": round(average, 4),
            "near_black_ratio": round(near_black, 4),
            "average_saturation": round(average_saturation, 4),
            "low_saturation_ratio": round(low_saturation, 4),
            "pass": passed,
        })
    return records, failures


def main() -> None:
    args = parse_args()
    records, failures = measure(args.atlas)
    print(
        "SPRITE_COLOR_GATE avg_luminance=0.30-0.75 near_black_luma<0.10 "
        "near_black_ratio<35% avg_saturation>=0.32 low_saturation<0.15 ratio<20%"
    )
    for record in records:
        print(
            "SPRITE_COLOR character={character} visible={visible_pixels} "
            "avg_luminance={average_luminance:.4f} near_black={near_black_ratio:.2%} "
            "avg_saturation={average_saturation:.4f} low_saturation={low_saturation_ratio:.2%} "
            "pass={pass}".format(**record)
        )
    for scope, scoped_records in (("heroes", records[:10]), ("atlas", records)):
        visible_total = sum(int(record["visible_pixels"]) for record in scoped_records)
        weighted = {
            key: sum(float(record[key]) * int(record["visible_pixels"]) for record in scoped_records) / visible_total
            for key in ("average_luminance", "near_black_ratio", "average_saturation", "low_saturation_ratio")
        }
        print(
            f"SPRITE_COLOR_SUMMARY scope={scope} characters={len(scoped_records)} visible={visible_total} "
            f"avg_luminance={weighted['average_luminance']:.4f} near_black={weighted['near_black_ratio']:.2%} "
            f"avg_saturation={weighted['average_saturation']:.4f} "
            f"low_saturation={weighted['low_saturation_ratio']:.2%}"
        )
    if args.json_output is not None:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if failures:
        for failure in failures:
            print("SPRITE_COLOR_FAIL " + failure)
        raise SystemExit(1)
    print(f"SPRITE_COLOR_PASS characters={len(records)}")


if __name__ == "__main__":
    main()
