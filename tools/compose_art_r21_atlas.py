"""Compose Rodin hero renders into the fixed shared atlas; preserve enemies."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / "docs" / "evidence" / "art_r21" / "before" / "true_character_atlas_r20_1.png"
OUTPUT = ROOT / "assets" / "sprites" / "true_character_atlas.png"
FRAME_ROOT = ROOT / "export" / "art_r21_frames"
THREEVIEW_RAW = ROOT / "export" / "art_r21_threeview_raw"
THREEVIEW = ROOT / "docs" / "evidence" / "art_r21" / "threeview"
MANIFEST = ROOT / "docs" / "evidence" / "art_r21" / "atlas_manifest.json"
CELL = 64
COLUMNS = 8
FRAMES = 27
HEROES = (
    "hero_captain", "hero_rift_sniper", "hero_void_weaver", "hero_arc_scout", "hero_echo_singer",
    "hero_ember_grenadier", "hero_line_mender", "hero_orbit_guard", "hero_pulse_artificer", "hero_shepherd",
)
LABELS = ("FRONT", "SIDE", "BACK")


def character_cells(image: Image.Image, first_cell: int, count: int) -> bytes:
    payload = bytearray()
    for cell in range(first_cell, first_cell + count):
        x = (cell % COLUMNS) * CELL
        y = (cell // COLUMNS) * CELL
        payload.extend(image.crop((x, y, x + CELL, y + CELL)).tobytes())
    return bytes(payload)


def digest(image: Image.Image) -> str:
    return hashlib.sha256(image.tobytes()).hexdigest()


def grade(frame: Image.Image, runtime_id: str) -> Image.Image:
    # AgX is retained in Blender.  This mild display-referred grade compensates
    # the 128->64 reduction without replacing authored texture colors.
    color_factor = 1.22 * {
        "hero_ember_grenadier": 1.18,
        "hero_arc_scout": 1.25,
    }.get(runtime_id, 1.0)
    brightness_factor = 1.10 * {
        "hero_captain": 1.32,
        "hero_rift_sniper": 1.18,
    }.get(runtime_id, 1.0)
    frame = ImageEnhance.Color(frame).enhance(color_factor)
    frame = ImageEnhance.Brightness(frame).enhance(brightness_factor)
    return frame


def compose_threeview(runtime_id: str, revision: str = "R21") -> str:
    panels = [Image.open(THREEVIEW_RAW / runtime_id / f"{label.lower()}.png").convert("RGB") for label in LABELS]
    sheet = Image.new("RGB", (1000, 370), "#061224")
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(sheet)
    try:
        title_font = ImageFont.truetype("C:/Windows/Fonts/seguisb.ttf", 22)
        label_font = ImageFont.truetype("C:/Windows/Fonts/seguisb.ttf", 16)
    except OSError:
        title_font = label_font = ImageFont.load_default()
    draw.text((20, 10), f"CV ART-{revision}  {runtime_id.replace('_', ' ').upper()}  /  HYPER3D RODIN", font=title_font, fill="#EAF4FF")
    for index, (label, panel) in enumerate(zip(LABELS, panels)):
        x = 20 + index * 326
        sheet.paste(panel.resize((300, 300), Image.Resampling.LANCZOS), (x, 50))
        draw.text((x + 116, 348), label, font=label_font, fill="#75D6EE")
    THREEVIEW.mkdir(parents=True, exist_ok=True)
    output = THREEVIEW / f"{runtime_id}.png"
    sheet.save(output, optimize=True)
    return str(output.relative_to(ROOT)).replace("\\", "/")


def compose_one(runtime_id: str = "hero_line_mender") -> None:
    """Replace one hero's cells while proving every other atlas cell is untouched."""
    if runtime_id not in HEROES:
        raise ValueError(f"Unknown R21 runtime hero: {runtime_id}")
    before = Image.open(OUTPUT).convert("RGBA")
    atlas = before.copy()
    hero_index = HEROES.index(runtime_id)
    paths = sorted((FRAME_ROOT / runtime_id).glob("*.png"))
    if len(paths) != FRAMES:
        raise RuntimeError(f"{runtime_id}: expected {FRAMES} renders, got {len(paths)}")
    for frame_index, path in enumerate(paths):
        sprite = grade(Image.open(path).convert("RGBA"), runtime_id).resize((CELL, CELL), Image.Resampling.LANCZOS)
        cell = hero_index * FRAMES + frame_index
        x = (cell % COLUMNS) * CELL
        y = (cell // COLUMNS) * CELL
        atlas.paste((0, 0, 0, 0), (x, y, x + CELL, y + CELL))
        atlas.alpha_composite(sprite, (x, y))
    first_cell = hero_index * FRAMES
    reference = atlas.crop((
        (first_cell % COLUMNS) * CELL,
        (first_cell // COLUMNS) * CELL,
        (first_cell % COLUMNS + 1) * CELL,
        (first_cell // COLUMNS + 1) * CELL,
    ))
    reference.save(ROOT / "assets" / "sprites" / f"{runtime_id}.png", optimize=True)
    threeview = compose_threeview(runtime_id, "R21.1")

    other_before = character_cells(before, 0, first_cell) + character_cells(
        before, first_cell + FRAMES, len(HEROES) * FRAMES - first_cell - FRAMES
    )
    other_after = character_cells(atlas, 0, first_cell) + character_cells(
        atlas, first_cell + FRAMES, len(HEROES) * FRAMES - first_cell - FRAMES
    )
    enemy_before = character_cells(before, len(HEROES) * FRAMES, 7 * FRAMES)
    enemy_after = character_cells(atlas, len(HEROES) * FRAMES, 7 * FRAMES)
    if other_before != other_after:
        raise RuntimeError("non-target hero atlas cells changed")
    if enemy_before != enemy_after:
        raise RuntimeError("enemy atlas rows changed")
    atlas.save(OUTPUT, optimize=True)

    report = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    records = [record for record in report.get("heroes", []) if record.get("hero") != runtime_id]
    records.append({"hero": runtime_id, "frames": FRAMES, "threeview": threeview, "revision": "r21.1"})
    order = {hero: index for index, hero in enumerate(HEROES)}
    records.sort(key=lambda record: order.get(str(record.get("hero")), len(HEROES)))
    report.update({
        "atlas": str(OUTPUT.relative_to(ROOT)).replace("\\", "/"),
        "size": list(atlas.size),
        "heroes": records,
        "enemy_first_cell": len(HEROES) * FRAMES,
        "enemy_cell_count": 7 * FRAMES,
        "enemy_sha256_before": hashlib.sha256(enemy_before).hexdigest(),
        "enemy_sha256_after": hashlib.sha256(enemy_after).hexdigest(),
        "enemies_pixel_identical": True,
        "r21_1_target": runtime_id,
        "other_nine_heroes_pixel_identical": True,
    })
    MANIFEST.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"R21_1_ATLAS_PASS target={runtime_id} size={atlas.width}x{atlas.height} "
        "other_nine_heroes_unchanged=true enemy_rows_unchanged=true"
    )


def main() -> None:
    before = Image.open(BASELINE).convert("RGBA")
    atlas = before.copy()
    enemy_before = character_cells(before, len(HEROES) * FRAMES, 7 * FRAMES)
    records: list[dict[str, object]] = []
    for hero_index, runtime_id in enumerate(HEROES):
        paths = sorted((FRAME_ROOT / runtime_id).glob("*.png"))
        if len(paths) != FRAMES:
            raise RuntimeError(f"{runtime_id}: expected {FRAMES} renders, got {len(paths)}")
        for frame_index, path in enumerate(paths):
            sprite = Image.open(path).convert("RGBA")
            sprite = grade(sprite, runtime_id).resize((CELL, CELL), Image.Resampling.LANCZOS)
            cell = hero_index * FRAMES + frame_index
            x = (cell % COLUMNS) * CELL
            y = (cell // COLUMNS) * CELL
            atlas.paste((0, 0, 0, 0), (x, y, x + CELL, y + CELL))
            atlas.alpha_composite(sprite, (x, y))
        reference = atlas.crop((
            (hero_index * FRAMES % COLUMNS) * CELL,
            (hero_index * FRAMES // COLUMNS) * CELL,
            (hero_index * FRAMES % COLUMNS + 1) * CELL,
            (hero_index * FRAMES // COLUMNS + 1) * CELL,
        ))
        reference.save(ROOT / "assets" / "sprites" / f"{runtime_id}.png", optimize=True)
        records.append({"hero": runtime_id, "frames": FRAMES, "threeview": compose_threeview(runtime_id)})
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT, optimize=True)
    enemy_after = character_cells(atlas, len(HEROES) * FRAMES, 7 * FRAMES)
    enemies_unchanged = enemy_before == enemy_after
    report = {
        "atlas": str(OUTPUT.relative_to(ROOT)).replace("\\", "/"),
        "size": list(atlas.size),
        "heroes": records,
        "enemy_first_cell": len(HEROES) * FRAMES,
        "enemy_cell_count": 7 * FRAMES,
        "enemy_sha256_before": hashlib.sha256(enemy_before).hexdigest(),
        "enemy_sha256_after": hashlib.sha256(enemy_after).hexdigest(),
        "enemies_pixel_identical": enemies_unchanged,
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if not enemies_unchanged:
        raise RuntimeError("enemy atlas rows changed")
    print(f"R21_ATLAS_PASS size={atlas.width}x{atlas.height} heroes=10 enemy_rows_unchanged=true")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--hero", choices=("all", "hero_line_mender"), default="all")
    args = parser.parse_args()
    compose_one(args.hero) if args.hero != "all" else main()
