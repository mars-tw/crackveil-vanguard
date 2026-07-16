"""Build labelled R20 threeviews and per-hero R16/R20 animation comparisons."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "art_r20"
BEFORE = EVIDENCE / "before" / "true_character_atlas_r16.png"
AFTER = ROOT / "assets" / "sprites" / "true_character_atlas.png"
THREEVIEW = EVIDENCE / "threeview"
COMPARE = EVIDENCE / "before_after"
CELL = 64
COLUMNS = 8
FRAMES_PER_HERO = 27

HEROES = (
    ("hero_captain", "Rift Captain", "command cape / long rift blade", ("#143F6B", "#1E94B8", "#8FC2D1", "#D97A1F")),
    ("hero_rift_sniper", "Rift Sniper", "wide-brim hat / rail rifle / monocle", ("#293D66", "#2E8C94", "#A8C2C7", "#B8D938")),
    ("hero_void_weaver", "Void Weaver", "void hair / veil / crescent staff", ("#3D296B", "#7A42A6", "#B885C7", "#33D1D9")),
    ("hero_arc_scout", "Arc Scout", "wind scarf / visor / long arc spear", ("#19594F", "#24A37F", "#8ACCAE", "#D9611F")),
    ("hero_echo_singer", "Echo Singer", "fan hair / resonators / tuning-fork staff", ("#5C3866", "#A3669E", "#CCABC7", "#D9BA3D")),
    ("hero_ember_grenadier", "Ember Grenadier", "blast pack / grenade rack / launcher", ("#663319", "#AD4C1F", "#D19952", "#D9D15C")),
    ("hero_line_mender", "Line Mender", "hood / thread spool / needle staff", ("#2E5766", "#4CA39E", "#B8CCB3", "#D9A333")),
    ("hero_orbit_guard", "Orbit Guard", "fin helm / orbit shield / shoulder plates", ("#3D3366", "#6B57A6", "#B8A3D1", "#38D1D9")),
    ("hero_pulse_artificer", "Pulse Artificer", "goggles / tool pack / pulse cannon", ("#2B4F6B", "#3B94AD", "#9EC2D1", "#D96152")),
    ("hero_shepherd", "Rift Shepherd", "lantern hood / cloak / caged staff", ("#382E6B", "#5999A6", "#A6C2D1", "#C7D9D9")),
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
    atlas_cell = hero_index * FRAMES_PER_HERO + state_offset + frame_index
    x = (atlas_cell % COLUMNS) * CELL
    y = (atlas_cell // COLUMNS) * CELL
    return atlas.crop((x, y, x + CELL, y + CELL))


def checker(size: tuple[int, int]) -> Image.Image:
    background = Image.new("RGBA", size, "#0B1930")
    draw = ImageDraw.Draw(background)
    step = 16
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill="#102442")
    return background


def build_comparison(hero_index: int, hero_id: str, display_name: str, prop_note: str) -> Path:
    before = Image.open(BEFORE).convert("RGBA")
    after = Image.open(AFTER).convert("RGBA")
    width, height = 690, 318
    card = Image.new("RGB", (width, height), "#071426")
    draw = ImageDraw.Draw(card)
    draw.text((18, 12), display_name, font=font(23, True), fill="#F4F0E7")
    draw.text((18, 42), prop_note, font=font(13), fill="#8BCDE0")
    columns = (("IDLE", 0, 0), ("WALK", 4, 2), ("ATTACK · IMPACT F2", 12, 2))
    scale = 2
    frame_size = CELL * scale
    start_x = 205
    for row, (atlas, version, version_color) in enumerate(((before, "R16", "#6D89A5"), (after, "R20", "#E6B84B"))):
        y = 70 + row * 116
        draw.text((18, y + 28), version, font=font(20, True), fill=version_color)
        for column, (label, offset, frame_index) in enumerate(columns):
            x = start_x + column * 158
            tile = checker((frame_size, frame_size))
            sprite = atlas_frame(atlas, hero_index, offset, frame_index).resize((frame_size, frame_size), Image.Resampling.NEAREST)
            tile.alpha_composite(sprite)
            card.paste(tile.convert("RGB"), (x, y))
            if row == 0:
                text_width = draw.textbbox((0, 0), label, font=font(12, True))[2]
                draw.text((x + (frame_size - text_width) // 2, 55), label, font=font(12, True), fill="#B7C7D9")
    draw.rectangle((0, 0, width - 1, height - 1), outline="#2F6A87", width=2)
    output = COMPARE / f"{hero_id}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    card.save(output, optimize=True)
    return output


def label_threeview(hero_id: str, display_name: str, prop_note: str, palette: tuple[str, ...]) -> None:
    path = THREEVIEW / f"{hero_id}.png"
    image = Image.open(path).convert("RGB")
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle((0, 0, image.width, 70), fill=(4, 12, 25, 220))
    draw.text((24, 12), f"{display_name} · R20 ORTHOGRAPHIC REVIEW", font=font(23, True), fill="#F5F1E8")
    draw.text((24, 42), prop_note, font=font(13), fill="#8ECFE0")
    swatch_x = image.width - 214
    for index, color in enumerate(palette):
        x = swatch_x + index * 46
        draw.rounded_rectangle((x, 17, x + 34, 51), radius=4, fill=color, outline="#D8E7ED", width=1)
    for center, label in zip((288, 720, 1152), ("FRONT", "SIDE", "BACK")):
        bounds = draw.textbbox((0, 0), label, font=font(15, True))
        text_width = bounds[2] - bounds[0]
        draw.rounded_rectangle((center - 54, 670, center + 54, 705), radius=7, fill=(5, 16, 31, 210), outline="#3A7895", width=1)
        draw.text((center - text_width // 2, 678), label, font=font(15, True), fill="#EDE8DD")
    image.save(path, optimize=True)


def main() -> None:
    cards: list[Image.Image] = []
    outputs: list[Path] = []
    for index, (hero_id, display_name, prop_note, palette) in enumerate(HEROES):
        output = build_comparison(index, hero_id, display_name, prop_note)
        outputs.append(output)
        cards.append(Image.open(output).convert("RGB"))
        label_threeview(hero_id, display_name, prop_note, palette)

    margin = 18
    card_width, card_height = cards[0].size
    sheet = Image.new("RGB", (card_width * 2 + margin * 3, card_height * 5 + margin * 6 + 58), "#050F1E")
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 16), "CRACKVEIL VANGUARD · CV ART-R20 · R16 → R20", font=font(27, True), fill="#F2EDE2")
    draw.text((margin, 49), "Each hero: idle / walk / active impact frame 2 · native 64px cells shown at 2×", font=font(14), fill="#78BDD3")
    top = 78
    for index, card in enumerate(cards):
        x = margin + (index % 2) * (card_width + margin)
        y = top + (index // 2) * (card_height + margin)
        sheet.paste(card, (x, y))
    contact_sheet = COMPARE / "all_heroes_r16_vs_r20.png"
    sheet.save(contact_sheet, optimize=True)
    print(f"R20_BEFORE_AFTER cards={len(outputs)} sheet={contact_sheet}")
    print(f"R20_THREEVIEW_LABELS heroes={len(HEROES)} directory={THREEVIEW}")


if __name__ == "__main__":
    main()
