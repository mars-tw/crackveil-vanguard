"""Build the labeled hero-10 pose proof from the generated shared atlas."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "assets" / "sprites" / "true_character_atlas.png"
OUTPUT = ROOT / "docs" / "hero10_true_animation_proof.png"
CELL = 64
COLUMNS = 8
HERO_INDEX = 3
STATES = (("idle", 4), ("walk", 8), ("attack", 6), ("hurt", 3), ("death", 6))


def build() -> None:
    atlas = Image.open(ATLAS).convert("RGBA")
    label_width = 88
    canvas = Image.new("RGBA", (label_width + COLUMNS * CELL, len(STATES) * CELL), (7, 10, 20, 255))
    draw = ImageDraw.Draw(canvas)
    base_row = HERO_INDEX * len(STATES)
    for state_index, (state, frame_count) in enumerate(STATES):
        source_y = (base_row + state_index) * CELL
        row = atlas.crop((0, source_y, COLUMNS * CELL, source_y + CELL))
        output_y = state_index * CELL
        canvas.alpha_composite(row, (label_width, output_y))
        draw.text((8, output_y + 8), state.upper(), fill=(220, 240, 255, 255))
        draw.text((8, output_y + 30), f"{frame_count} poses", fill=(120, 190, 225, 255))
        for frame in range(frame_count):
            x = label_width + frame * CELL
            draw.rectangle((x, output_y, x + CELL - 1, output_y + CELL - 1), outline=(72, 130, 166, 180))
            draw.text((x + 4, output_y + 46), str(frame), fill=(238, 248, 255, 230))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(OUTPUT, optimize=True)
    print(f"HERO10_ANIMATION_PROOF {OUTPUT} {canvas.width}x{canvas.height}")


if __name__ == "__main__":
    build()
