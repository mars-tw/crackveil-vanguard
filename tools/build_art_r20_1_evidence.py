"""Build the ten-hero R20/R20.1 native-64px color comparison."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "art_r20_1"
BEFORE = EVIDENCE / "before" / "true_character_atlas_r20.png"
AFTER = ROOT / "assets" / "sprites" / "true_character_atlas.png"
BEFORE_METRICS = EVIDENCE / "before" / "color_metrics_r20.json"
AFTER_METRICS = EVIDENCE / "color_metrics_r20_1.json"
COMPARE = EVIDENCE / "before_after"
CELL = 64
COLUMNS = 8
FRAMES_PER_CHARACTER = 27

HEROES = (
    ("hero_captain", "Rift Captain", "blue / cyan / steel"),
    ("hero_rift_sniper", "Rift Sniper", "navy / teal / lime"),
    ("hero_void_weaver", "Void Weaver", "violet / lavender / cyan"),
    ("hero_arc_scout", "Arc Scout", "forest / mint / orange"),
    ("hero_echo_singer", "Echo Singer", "plum / rose / gold"),
    ("hero_ember_grenadier", "Ember Grenadier", "brown / ember / brass"),
    ("hero_line_mender", "Line Mender", "teal / mint / amber"),
    ("hero_orbit_guard", "Orbit Guard", "indigo / lilac / cyan"),
    ("hero_pulse_artificer", "Pulse Artificer", "blue / steel / coral"),
    ("hero_shepherd", "Rift Shepherd", "indigo / teal / ice"),
)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        Path("C:/Windows/Fonts/seguisb.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
    )
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def atlas_frame(atlas: Image.Image, hero_index: int, state_offset: int, frame_index: int) -> Image.Image:
    cell_index = hero_index * FRAMES_PER_CHARACTER + state_offset + frame_index
    x = (cell_index % COLUMNS) * CELL
    y = (cell_index // COLUMNS) * CELL
    return atlas.crop((x, y, x + CELL, y + CELL))


def battle_tile() -> Image.Image:
    tile = Image.new("RGBA", (CELL * 2, CELL * 2), "#07172B")
    draw = ImageDraw.Draw(tile)
    draw.ellipse((6, 10, 122, 126), fill="#0D2945")
    draw.line((0, 102, 54, 78, 128, 94), fill="#126687", width=2)
    draw.line((18, 0, 38, 44, 20, 80), fill="#184E76", width=2)
    return tile


def load_metrics(path: Path) -> dict[str, dict[str, object]]:
    return {record["character"]: record for record in json.loads(path.read_text(encoding="utf-8"))}


def hero_summary(metrics: dict[str, dict[str, object]]) -> tuple[float, float, float]:
    records = [metrics[hero_id] for hero_id, _name, _palette in HEROES]
    visible = sum(int(record["visible_pixels"]) for record in records)
    return tuple(
        sum(float(record[key]) * int(record["visible_pixels"]) for record in records) / visible
        for key in ("average_luminance", "average_saturation", "low_saturation_ratio")
    )


def build_card(
    hero_index: int,
    hero_id: str,
    display_name: str,
    palette_note: str,
    before: Image.Image,
    after: Image.Image,
    before_metrics: dict[str, dict[str, object]],
    after_metrics: dict[str, dict[str, object]],
) -> Image.Image:
    card = Image.new("RGB", (690, 318), "#050F1E")
    draw = ImageDraw.Draw(card)
    draw.text((18, 12), display_name, font=font(23, True), fill="#F3F0E8")
    draw.text((18, 42), palette_note, font=font(13), fill="#81CBE2")
    samples = (("IDLE", 0, 0), ("WALK", 4, 2), ("IMPACT F2", 12, 2))
    for row, (atlas, label, color, metrics) in enumerate((
        (before, "R20 / PALE", "#AAB8C8", before_metrics[hero_id]),
        (after, "R20.1 / COLOR", "#5DE1BA", after_metrics[hero_id]),
    )):
        y = 70 + row * 116
        draw.text((18, y + 20), label, font=font(17, True), fill=color)
        draw.text(
            (18, y + 49),
            f"L {float(metrics['average_luminance']):.3f}  S {float(metrics['average_saturation']):.3f}",
            font=font(12),
            fill="#AFC0D2",
        )
        draw.text(
            (18, y + 68),
            f"low-S {float(metrics['low_saturation_ratio']):.1%}",
            font=font(12),
            fill="#AFC0D2",
        )
        for column, (sample_label, state_offset, frame_index) in enumerate(samples):
            x = 205 + column * 158
            tile = battle_tile()
            sprite = atlas_frame(atlas, hero_index, state_offset, frame_index).resize(
                (CELL * 2, CELL * 2), Image.Resampling.NEAREST
            )
            tile.alpha_composite(sprite)
            card.paste(tile.convert("RGB"), (x, y))
            if row == 0:
                bounds = draw.textbbox((0, 0), sample_label, font=font(12, True))
                draw.text((x + (CELL * 2 - (bounds[2] - bounds[0])) // 2, 55), sample_label, font=font(12, True), fill="#C5D2E0")
    draw.rectangle((0, 0, card.width - 1, card.height - 1), outline="#246483", width=2)
    return card


def main() -> None:
    before = Image.open(BEFORE).convert("RGBA")
    after = Image.open(AFTER).convert("RGBA")
    before_metrics = load_metrics(BEFORE_METRICS)
    after_metrics = load_metrics(AFTER_METRICS)
    cards: list[Image.Image] = []
    COMPARE.mkdir(parents=True, exist_ok=True)
    for hero_index, (hero_id, display_name, palette_note) in enumerate(HEROES):
        card = build_card(hero_index, hero_id, display_name, palette_note, before, after, before_metrics, after_metrics)
        card.save(COMPARE / f"{hero_id}.png", optimize=True)
        cards.append(card)

    before_luma, before_saturation, before_low = hero_summary(before_metrics)
    after_luma, after_saturation, after_low = hero_summary(after_metrics)
    margin = 18
    card_width, card_height = cards[0].size
    sheet = Image.new("RGB", (card_width * 2 + margin * 3, card_height * 5 + margin * 6 + 82), "#030B17")
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 14), "CRACKVEIL VANGUARD - CV ART-R20.1 - COLOR RESTORATION", font=font(27, True), fill="#F3F0E8")
    draw.text(
        (margin, 49),
        f"10 heroes / native 64px / R20: L {before_luma:.3f}, S {before_saturation:.3f}, low-S {before_low:.1%}"
        f"  ->  R20.1: L {after_luma:.3f}, S {after_saturation:.3f}, low-S {after_low:.1%}",
        font=font(14),
        fill="#72CBE6",
    )
    top = 96
    for index, card in enumerate(cards):
        x = margin + (index % 2) * (card_width + margin)
        y = top + (index // 2) * (card_height + margin)
        sheet.paste(card, (x, y))
    output = COMPARE / "all_heroes_r20_vs_r20_1.png"
    sheet.save(output, optimize=True)
    print(f"R20_1_BEFORE_AFTER heroes={len(cards)} output={output}")


if __name__ == "__main__":
    main()
