"""Build R20.1/R21 and multi-pose evidence sheets at native 64px."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "art_r21"
BEFORE = EVIDENCE / "before" / "true_character_atlas_r20_1.png"
AFTER = ROOT / "assets" / "sprites" / "true_character_atlas.png"
BEFORE_METRICS = EVIDENCE / "before" / "color_metrics_r20_1.json"
AFTER_METRICS = EVIDENCE / "color_metrics_r21.json"
OUTPUT = EVIDENCE / "before_after"
CELL = 64
COLUMNS = 8
FRAMES = 27
HEROES = (
    ("hero_captain", "Rift Captain"), ("hero_rift_sniper", "Rift Sniper"),
    ("hero_void_weaver", "Void Weaver"), ("hero_arc_scout", "Arc Scout"),
    ("hero_echo_singer", "Echo Singer"), ("hero_ember_grenadier", "Ember Grenadier"),
    ("hero_line_mender", "Line Mender"), ("hero_orbit_guard", "Orbit Guard"),
    ("hero_pulse_artificer", "Pulse Artificer"), ("hero_shepherd", "Rift Shepherd"),
)


def font(size: int, bold: bool = False):
    path = Path("C:/Windows/Fonts/seguisb.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf")
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def frame(atlas: Image.Image, hero: int, offset: int) -> Image.Image:
    cell = hero * FRAMES + offset
    x, y = (cell % COLUMNS) * CELL, (cell // COLUMNS) * CELL
    return atlas.crop((x, y, x + CELL, y + CELL))


def tile(sprite: Image.Image, scale: int = 2) -> Image.Image:
    size = CELL * scale
    output = Image.new("RGBA", (size, size), "#07172B")
    draw = ImageDraw.Draw(output)
    draw.ellipse((5, 12, size - 5, size - 3), fill="#0D2945")
    output.alpha_composite(sprite.resize((size, size), Image.Resampling.NEAREST))
    return output


def metrics(path: Path) -> dict[str, dict[str, object]]:
    return {record["character"]: record for record in json.loads(path.read_text(encoding="utf-8"))}


def main() -> None:
    before, after = Image.open(BEFORE).convert("RGBA"), Image.open(AFTER).convert("RGBA")
    old, new = metrics(BEFORE_METRICS), metrics(AFTER_METRICS)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    cards: list[Image.Image] = []
    samples = (("IDLE", 0), ("WALK", 6), ("IMPACT F2", 14))
    for index, (hero_id, name) in enumerate(HEROES):
        card = Image.new("RGB", (720, 300), "#050F1E")
        draw = ImageDraw.Draw(card)
        draw.text((16, 10), name, font=font(22, True), fill="#F2F6F8")
        for col, (label, _offset) in enumerate(samples):
            draw.text((205 + col * 162, 40), label, font=font(12, True), fill="#8EDCF2")
        for row, (atlas, version, data, color) in enumerate(((before, "R20.1", old, "#AFC2D5"), (after, "R21 RODIN", new, "#62E2B3"))):
            y = 62 + row * 116
            record = data[hero_id]
            draw.text((16, y + 24), version, font=font(16, True), fill=color)
            draw.text((16, y + 49), f"L {record['average_luminance']:.3f}  S {record['average_saturation']:.3f}", font=font(12), fill="#B7C5D3")
            draw.text((16, y + 68), f"low-S {record['low_saturation_ratio']:.1%}", font=font(12), fill="#B7C5D3")
            for col, (_label, offset) in enumerate(samples):
                card.paste(tile(frame(atlas, index, offset)).convert("RGB"), (195 + col * 162, y))
        draw.rectangle((0, 0, 719, 299), outline="#286B89", width=2)
        card.save(OUTPUT / f"{hero_id}.png", optimize=True)
        cards.append(card)
    sheet = Image.new("RGB", (1476, 1590), "#030A16")
    draw = ImageDraw.Draw(sheet)
    draw.text((18, 14), "CRACKVEIL VANGUARD — CV ART-R21 — R20.1 vs HYPER3D RODIN", font=font(26, True), fill="#F2F6F8")
    for index, card in enumerate(cards):
        sheet.paste(card, (18 + (index % 2) * 738, 72 + (index // 2) * 306))
    sheet.save(OUTPUT / "all_heroes_r20_1_vs_r21.png", optimize=True)

    pose_offsets = (("IDLE", 0), ("WALK A", 6), ("WALK B", 10), ("ANTICIPATE", 13), ("IMPACT F2", 14), ("HURT", 19), ("DEATH", 26))
    pose_sheet = Image.new("RGB", (1020, 1510), "#030A16")
    draw = ImageDraw.Draw(pose_sheet)
    draw.text((18, 12), "CV ART-R21 — 18-BONE POSE REGRESSION SHEET", font=font(25, True), fill="#F2F6F8")
    for col, (label, _offset) in enumerate(pose_offsets):
        draw.text((128 + col * 126, 55), label, font=font(12, True), fill="#8EDCF2")
    for row, (_hero_id, name) in enumerate(HEROES):
        y = 84 + row * 140
        draw.text((12, y + 50), name, font=font(14, True), fill="#DFEAF2")
        for col, (_label, offset) in enumerate(pose_offsets):
            pose_sheet.paste(tile(frame(after, row, offset)).convert("RGB"), (120 + col * 126, y))
    pose_sheet.save(EVIDENCE / "animation_pose_sheet.png", optimize=True)
    print("R21_EVIDENCE_PASS heroes=10 comparisons=10 pose_samples=70")


if __name__ == "__main__":
    main()
