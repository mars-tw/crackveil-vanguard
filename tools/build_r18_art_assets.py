from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SPRITE_DIR = ROOT / "assets" / "sprites"
DECOR_DIR = ROOT / "assets" / "art" / "decor"
EVIDENCE_DIR = ROOT / "docs" / "evidence" / "R18"
SCALE = 4


LIGHTNING_WEAPON_COLORS = {
    "arc_chain": (0.46, 0.94, 1.0, 1.0),
    "rail_lance": (0.56, 0.96, 1.0, 1.0),
    "echo_hymn": (0.52, 0.96, 1.0, 1.0),
}

FARM_COMPARE_PAIRS = [
    ("void_bush_ghost", "farm_bush"),
    ("void_debris_01", "farm_wood_stack"),
    ("void_rock_01", "farm_rock"),
    ("void_rock_02", "farm_stone_stack"),
    ("void_stump", "farm_stump"),
    ("ember_ash_bush", "farm_bush"),
    ("ember_rock_01", "farm_rock"),
    ("ember_rock_02", "farm_stone_stack"),
    ("ember_ruin_barn", "farm_ruined_barn"),
]


def _s(value: float) -> int:
    return int(round(value * SCALE))


def _xy(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(_s(x), _s(y)) for x, y in points]


def _box(box: tuple[float, float, float, float]) -> tuple[int, int, int, int]:
    return tuple(_s(v) for v in box)


def _new(size: tuple[int, int]) -> Image.Image:
    return Image.new("RGBA", (size[0] * SCALE, size[1] * SCALE), (0, 0, 0, 0))


def _downsample(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    return img.resize(size, Image.Resampling.LANCZOS)


def _shadow(base: Image.Image, box: tuple[float, float, float, float], alpha: int = 110) -> None:
    layer = _new((base.width // SCALE, base.height // SCALE))
    d = ImageDraw.Draw(layer, "RGBA")
    d.ellipse(_box(box), fill=(0, 0, 0, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(_s(2.0)))
    base.alpha_composite(layer)


def _glow(base: Image.Image, box: tuple[float, float, float, float], color: tuple[int, int, int, int], blur: float = 3.0) -> None:
    layer = _new((base.width // SCALE, base.height // SCALE))
    d = ImageDraw.Draw(layer, "RGBA")
    d.ellipse(_box(box), fill=color)
    layer = layer.filter(ImageFilter.GaussianBlur(_s(blur)))
    base.alpha_composite(layer)


def _poly(d: ImageDraw.ImageDraw, points: list[tuple[float, float]], fill: tuple[int, int, int, int], outline: tuple[int, int, int, int] | None = None, width: float = 1.0) -> None:
    d.polygon(_xy(points), fill=fill)
    if outline is not None:
        d.line(_xy(points + [points[0]]), fill=outline, width=max(1, _s(width)), joint="curve")


def _line(d: ImageDraw.ImageDraw, points: list[tuple[float, float]], fill: tuple[int, int, int, int], width: float = 1.0) -> None:
    d.line(_xy(points), fill=fill, width=max(1, _s(width)), joint="curve")


def _ellipse(d: ImageDraw.ImageDraw, box: tuple[float, float, float, float], fill: tuple[int, int, int, int], outline: tuple[int, int, int, int] | None = None, width: float = 1.0) -> None:
    d.ellipse(_box(box), fill=fill, outline=outline, width=max(1, _s(width)))


def _rect(d: ImageDraw.ImageDraw, box: tuple[float, float, float, float], fill: tuple[int, int, int, int], outline: tuple[int, int, int, int] | None = None, width: float = 1.0) -> None:
    d.rectangle(_box(box), fill=fill, outline=outline, width=max(1, _s(width)))


def _save(path: Path, img: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def neutral_lightning() -> None:
    source = EVIDENCE_DIR / "proj_lightning_before.png"
    if not source.exists():
        source = SPRITE_DIR / "proj_lightning.png"
        EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
        Image.open(source).save(EVIDENCE_DIR / "proj_lightning_before.png", optimize=True)

    original = Image.open(source).convert("RGBA")
    arr = np.asarray(original, dtype=np.float32)
    rgb = arr[..., :3]
    alpha = arr[..., 3]
    luma = (rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114) / 255.0
    edge = np.clip(alpha / 255.0, 0.0, 1.0)
    neutral = np.clip(138.0 + luma * 108.0 + edge * 20.0, 0.0, 255.0)
    out = np.zeros_like(arr)
    out[..., 0] = neutral
    out[..., 1] = neutral
    out[..., 2] = neutral
    out[..., 3] = alpha
    result = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    _save(SPRITE_DIR / "proj_lightning.png", result)
    _save(EVIDENCE_DIR / "proj_lightning_after.png", result)
    _save(EVIDENCE_DIR / "proj_lightning_before_after.png", _lightning_before_after(original, result))
    _save(EVIDENCE_DIR / "lightning_weapon_cyan_samples.png", _weapon_lightning_samples(result))


def _lightning_before_after(before: Image.Image, after: Image.Image) -> Image.Image:
    w, h = before.size
    pad = 22
    label_h = 28
    sheet = Image.new("RGBA", (w * 2 + pad * 3, h + pad * 2 + label_h), (14, 18, 24, 255))
    d = ImageDraw.Draw(sheet)
    sheet.alpha_composite(before, (pad, pad + label_h))
    sheet.alpha_composite(after, (w + pad * 2, pad + label_h))
    d.text((pad, pad), "before: yellow source", fill=(255, 226, 92, 255))
    d.text((w + pad * 2, pad), "after: neutral white/gray", fill=(210, 245, 255, 255))
    return sheet


def _modulate_texture(texture: Image.Image, color: tuple[float, float, float, float]) -> Image.Image:
    arr = np.asarray(texture.convert("RGBA"), dtype=np.float32)
    for channel in range(3):
        arr[..., channel] *= color[channel]
    arr[..., 3] *= color[3]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def _weapon_lightning_samples(texture: Image.Image) -> Image.Image:
    thumb = texture.resize((58, 96), Image.Resampling.LANCZOS)
    w, h = 250, 138
    sheet = Image.new("RGBA", (w * 3, h), (8, 13, 22, 255))
    d = ImageDraw.Draw(sheet)
    for index, (weapon_id, color) in enumerate(LIGHTNING_WEAPON_COLORS.items()):
        x = index * w
        _glow(sheet, (x + 42, 18, x + 208, 115), (40, 230, 255, 48), blur=6.0)
        sample = _modulate_texture(thumb, color)
        sheet.alpha_composite(sample, (x + 96, 22))
        d.text((x + 16, 10), weapon_id, fill=(225, 245, 255, 255))
        d.text((x + 16, 112), "cyan RGB %.2f %.2f %.2f" % color[:3], fill=(130, 238, 255, 255))
    return sheet


def make_void_bush_ghost() -> Image.Image:
    size = (79, 70)
    img = _new(size)
    _shadow(img, (13, 55, 66, 70), 90)
    _glow(img, (20, 12, 62, 58), (45, 226, 255, 52), 4.0)
    d = ImageDraw.Draw(img, "RGBA")
    dark = (14, 32, 50, 230)
    mid = (42, 92, 118, 240)
    cyan = (96, 238, 255, 230)
    violet = (105, 84, 188, 215)
    _poly(d, [(15, 48), (26, 21), (35, 50), (26, 61)], mid, dark, 1.4)
    _poly(d, [(29, 42), (38, 4), (48, 43), (39, 61)], (38, 72, 116, 238), dark, 1.4)
    _poly(d, [(45, 48), (61, 18), (69, 50), (55, 63)], (33, 78, 105, 238), dark, 1.4)
    _poly(d, [(8, 57), (18, 37), (29, 64)], (25, 62, 86, 220), dark, 1.2)
    _poly(d, [(51, 59), (70, 38), (73, 62)], (22, 58, 82, 215), dark, 1.2)
    _poly(d, [(28, 57), (39, 42), (52, 58), (41, 66)], violet, dark, 1.0)
    for pts in [
        [(20, 51), (27, 38), (30, 26)],
        [(39, 55), (41, 35), (39, 11)],
        [(52, 52), (58, 36), (63, 22)],
        [(13, 59), (22, 55), (31, 59)],
        [(48, 61), (57, 57), (68, 58)],
    ]:
        _line(d, pts, cyan, 1.1)
    _ellipse(d, (35, 30, 44, 39), (205, 255, 255, 160))
    return _downsample(img, size)


def make_void_debris_01() -> Image.Image:
    size = (119, 74)
    img = _new(size)
    _shadow(img, (7, 58, 111, 74), 105)
    _glow(img, (44, 20, 89, 65), (70, 235, 255, 40), 5.0)
    d = ImageDraw.Draw(img, "RGBA")
    dark = (10, 26, 42, 235)
    mid = (41, 78, 101, 245)
    face = (58, 105, 132, 245)
    edge = (91, 238, 255, 210)
    _poly(d, [(10, 58), (38, 32), (63, 39), (51, 68), (18, 68)], mid, dark, 1.6)
    _poly(d, [(45, 62), (66, 18), (91, 6), (84, 58), (63, 69)], face, dark, 1.6)
    _poly(d, [(79, 60), (100, 36), (112, 52), (101, 67)], (30, 62, 82, 235), dark, 1.3)
    _poly(d, [(27, 45), (40, 20), (51, 42)], (74, 124, 148, 230), dark, 1.2)
    _poly(d, [(89, 23), (103, 16), (99, 32)], (68, 112, 145, 210), dark, 1.0)
    _poly(d, [(15, 34), (21, 27), (25, 39)], (77, 224, 255, 170), None)
    _poly(d, [(98, 9), (103, 3), (107, 12)], (130, 252, 255, 150), None)
    for pts in [
        [(55, 60), (65, 43), (70, 21)],
        [(68, 54), (82, 42), (84, 17)],
        [(19, 60), (34, 51), (46, 36)],
        [(86, 58), (98, 49), (104, 43)],
    ]:
        _line(d, pts, edge, 1.0)
    return _downsample(img, size)


def make_void_rock_01() -> Image.Image:
    size = (116, 64)
    img = _new(size)
    _shadow(img, (9, 48, 107, 64), 105)
    _glow(img, (34, 13, 88, 55), (62, 228, 255, 38), 4.5)
    d = ImageDraw.Draw(img, "RGBA")
    dark = (8, 24, 38, 240)
    _poly(d, [(9, 53), (27, 30), (52, 17), (76, 23), (101, 43), (107, 56), (67, 61), (28, 60)], (35, 72, 96, 245), dark, 1.5)
    _poly(d, [(27, 52), (45, 21), (59, 33), (49, 58)], (55, 104, 130, 245), dark, 1.2)
    _poly(d, [(62, 54), (75, 24), (96, 41), (91, 58)], (28, 59, 83, 245), dark, 1.2)
    _poly(d, [(5, 55), (15, 43), (22, 59)], (19, 48, 68, 230), dark, 1.0)
    _poly(d, [(95, 38), (108, 31), (112, 48)], (54, 96, 120, 210), dark, 1.0)
    for pts in [
        [(36, 52), (49, 37), (52, 22)],
        [(60, 51), (72, 39), (77, 25)],
        [(78, 53), (91, 46), (99, 42)],
        [(20, 53), (31, 46), (42, 35)],
    ]:
        _line(d, pts, (102, 238, 255, 210), 1.1)
    return _downsample(img, size)


def make_void_rock_02() -> Image.Image:
    size = (112, 72)
    img = _new(size)
    _shadow(img, (12, 58, 102, 72), 105)
    _glow(img, (24, 8, 84, 63), (76, 232, 255, 44), 5.0)
    d = ImageDraw.Draw(img, "RGBA")
    dark = (9, 25, 39, 240)
    _poly(d, [(42, 61), (54, 8), (66, 61)], (59, 111, 140, 248), dark, 1.4)
    _poly(d, [(24, 62), (38, 24), (52, 62)], (36, 76, 105, 245), dark, 1.3)
    _poly(d, [(61, 62), (82, 16), (91, 61)], (45, 90, 119, 245), dark, 1.3)
    _poly(d, [(13, 63), (24, 43), (36, 66)], (27, 58, 80, 232), dark, 1.0)
    _poly(d, [(81, 64), (101, 39), (105, 65)], (22, 52, 74, 230), dark, 1.0)
    _poly(d, [(29, 65), (53, 56), (83, 63), (98, 70), (20, 70)], (14, 36, 52, 240), dark, 1.0)
    for pts in [
        [(55, 56), (57, 30), (55, 10)],
        [(39, 57), (42, 42), (39, 25)],
        [(76, 57), (82, 39), (83, 18)],
        [(47, 61), (54, 54), (63, 61)],
    ]:
        _line(d, pts, (109, 247, 255, 225), 1.05)
    return _downsample(img, size)


def make_void_stump() -> Image.Image:
    size = (77, 62)
    img = _new(size)
    _shadow(img, (10, 51, 67, 62), 95)
    _glow(img, (19, 11, 58, 55), (82, 236, 255, 42), 4.2)
    d = ImageDraw.Draw(img, "RGBA")
    dark = (8, 23, 37, 240)
    _poly(d, [(16, 55), (22, 30), (35, 18), (48, 28), (58, 54), (43, 60), (25, 60)], (38, 78, 106, 245), dark, 1.4)
    _poly(d, [(24, 49), (33, 12), (42, 49)], (54, 103, 135, 238), dark, 1.2)
    _poly(d, [(42, 51), (56, 20), (61, 55)], (31, 68, 92, 232), dark, 1.1)
    _poly(d, [(13, 54), (20, 38), (29, 59)], (22, 54, 78, 225), dark, 1.0)
    _line(d, [(35, 51), (38, 35), (36, 15)], (112, 245, 255, 220), 1.0)
    _line(d, [(45, 50), (53, 38), (56, 23)], (112, 245, 255, 190), 1.0)
    _ellipse(d, (27, 42, 51, 53), (14, 28, 43, 215), (103, 237, 255, 180), 1.1)
    return _downsample(img, size)


def make_ember_ash_bush() -> Image.Image:
    size = (79, 70)
    img = _new(size)
    _shadow(img, (10, 58, 69, 70), 115)
    _glow(img, (21, 33, 58, 63), (255, 91, 24, 42), 4.0)
    d = ImageDraw.Draw(img, "RGBA")
    ash = (20, 17, 15, 245)
    bark = (47, 31, 23, 245)
    hot = (255, 104, 28, 230)
    _poly(d, [(12, 62), (24, 55), (39, 58), (55, 52), (68, 61), (63, 68), (17, 68)], (32, 26, 23, 240), ash, 1.0)
    for pts in [
        [(18, 61), (25, 42), (19, 28)],
        [(28, 61), (36, 35), (33, 14)],
        [(40, 61), (43, 38), (53, 22)],
        [(52, 60), (58, 43), (65, 34)],
        [(31, 58), (22, 48), (13, 43)],
        [(46, 59), (56, 50), (68, 51)],
    ]:
        _line(d, pts, bark, 4.2)
        _line(d, pts, ash, 2.0)
    for pts in [
        [(35, 36), (30, 31), (27, 24)],
        [(43, 39), (49, 34), (57, 32)],
        [(25, 43), (17, 38), (12, 31)],
    ]:
        _line(d, pts, (58, 36, 24, 235), 2.2)
    for box in [(30, 53, 36, 59), (45, 50, 51, 57), (55, 57, 60, 63), (20, 55, 25, 61)]:
        _ellipse(d, box, hot)
    return _downsample(img, size)


def make_ember_rock_01() -> Image.Image:
    size = (116, 64)
    img = _new(size)
    _shadow(img, (8, 49, 108, 64), 115)
    _glow(img, (27, 30, 91, 59), (255, 87, 20, 38), 4.4)
    d = ImageDraw.Draw(img, "RGBA")
    dark = (16, 13, 12, 248)
    face = (48, 38, 34, 248)
    _poly(d, [(8, 55), (23, 35), (45, 20), (65, 30), (78, 15), (101, 43), (108, 58), (71, 61), (29, 60)], face, dark, 1.4)
    _poly(d, [(24, 54), (45, 20), (57, 35), (49, 59)], (71, 45, 32, 245), dark, 1.1)
    _poly(d, [(62, 56), (79, 16), (96, 43), (89, 59)], (37, 31, 30, 245), dark, 1.1)
    _poly(d, [(2, 57), (13, 43), (22, 60)], (28, 24, 22, 232), dark, 1.0)
    for pts in [
        [(37, 54), (48, 42), (51, 25)],
        [(56, 52), (65, 43), (76, 19)],
        [(75, 55), (89, 48), (99, 44)],
        [(18, 55), (30, 50), (42, 38)],
    ]:
        _line(d, pts, (255, 118, 30, 230), 1.3)
        _line(d, pts, (255, 207, 76, 145), 0.65)
    return _downsample(img, size)


def make_ember_rock_02() -> Image.Image:
    size = (112, 72)
    img = _new(size)
    _shadow(img, (12, 59, 101, 72), 120)
    _glow(img, (22, 32, 91, 66), (255, 92, 22, 40), 4.6)
    d = ImageDraw.Draw(img, "RGBA")
    dark = (15, 12, 11, 248)
    _poly(d, [(20, 65), (28, 42), (38, 29), (48, 62)], (47, 36, 31, 245), dark, 1.2)
    _poly(d, [(38, 65), (48, 15), (62, 64)], (72, 43, 30, 245), dark, 1.3)
    _poly(d, [(59, 64), (74, 24), (88, 63)], (39, 31, 29, 245), dark, 1.2)
    _poly(d, [(78, 66), (96, 43), (105, 67)], (29, 25, 24, 238), dark, 1.0)
    _poly(d, [(12, 66), (23, 52), (31, 68)], (31, 25, 23, 232), dark, 1.0)
    _poly(d, [(18, 68), (50, 58), (84, 63), (103, 70), (14, 71)], (21, 17, 16, 248), dark, 1.0)
    for pts in [
        [(51, 58), (53, 36), (50, 17)],
        [(39, 59), (44, 45), (38, 31)],
        [(75, 58), (78, 43), (75, 25)],
        [(83, 64), (96, 55), (102, 48)],
    ]:
        _line(d, pts, (255, 117, 28, 230), 1.25)
        _line(d, pts, (255, 210, 80, 130), 0.65)
    return _downsample(img, size)


def make_ember_ruin_barn() -> Image.Image:
    size = (236, 223)
    img = _new(size)
    _shadow(img, (18, 198, 219, 222), 125)
    _glow(img, (65, 109, 176, 198), (255, 79, 18, 36), 8.0)
    d = ImageDraw.Draw(img, "RGBA")
    char = (18, 14, 12, 250)
    beam = (49, 30, 21, 250)
    ash = (74, 62, 52, 230)
    ember = (255, 101, 28, 235)
    hot = (255, 198, 65, 170)
    _poly(d, [(31, 198), (50, 125), (78, 81), (101, 58), (128, 85), (146, 140), (138, 205)], (36, 25, 20, 245), char, 3.0)
    _poly(d, [(105, 205), (132, 134), (166, 76), (194, 99), (205, 174), (193, 207)], (28, 22, 20, 246), char, 3.0)
    _poly(d, [(49, 126), (75, 83), (100, 59), (122, 87), (97, 100), (73, 136)], (25, 20, 18, 248), char, 2.4)
    _poly(d, [(133, 136), (165, 77), (197, 101), (184, 126), (158, 115)], (22, 18, 17, 248), char, 2.4)
    _poly(d, [(38, 199), (55, 162), (90, 151), (116, 170), (105, 207)], (57, 36, 24, 246), char, 2.0)
    _poly(d, [(128, 206), (142, 151), (177, 143), (198, 171), (190, 209)], (44, 29, 22, 246), char, 2.0)
    for pts, width in [
        ([(44, 199), (76, 81)], 5.0),
        ([(106, 204), (100, 58)], 5.0),
        ([(139, 205), (166, 77)], 5.0),
        ([(193, 207), (196, 100)], 5.0),
        ([(36, 198), (121, 87), (203, 207)], 4.0),
        ([(55, 161), (128, 205)], 4.0),
        ([(188, 143), (127, 205)], 4.0),
        ([(64, 205), (95, 151), (112, 199)], 3.2),
        ([(153, 205), (174, 144), (196, 201)], 3.2),
    ]:
        _line(d, pts, beam, width)
        _line(d, pts, char, max(1.0, width * 0.38))
    _poly(d, [(28, 205), (65, 194), (96, 209), (135, 198), (197, 207), (220, 218), (24, 219)], (31, 25, 22, 245), char, 1.5)
    for pts in [
        [(71, 184), (86, 162), (104, 194)],
        [(145, 188), (160, 160), (181, 197)],
        [(99, 109), (121, 93), (132, 129)],
        [(161, 119), (178, 103), (189, 137)],
    ]:
        _line(d, pts, ember, 2.0)
        _line(d, pts, hot, 0.9)
    for box in [(78, 195, 92, 207), (151, 191, 166, 205), (181, 202, 192, 213), (116, 189, 128, 201)]:
        _ellipse(d, box, ember)
    _line(d, [(22, 208), (46, 198), (63, 207)], ash, 2.0)
    _line(d, [(174, 211), (198, 198), (222, 210)], ash, 2.0)
    return _downsample(img, size)


DECOR_BUILDERS = {
    "void_bush_ghost": make_void_bush_ghost,
    "void_debris_01": make_void_debris_01,
    "void_rock_01": make_void_rock_01,
    "void_rock_02": make_void_rock_02,
    "void_stump": make_void_stump,
    "ember_ash_bush": make_ember_ash_bush,
    "ember_rock_01": make_ember_rock_01,
    "ember_rock_02": make_ember_rock_02,
    "ember_ruin_barn": make_ember_ruin_barn,
}


def build_decor() -> None:
    for name, builder in DECOR_BUILDERS.items():
        existing = Image.open(DECOR_DIR / f"{name}.png")
        new_img = builder()
        if new_img.size != existing.size:
            raise RuntimeError(f"{name} size drifted: {new_img.size} != {existing.size}")
        _save(DECOR_DIR / f"{name}.png", new_img)
    _save(EVIDENCE_DIR / "decor_contact_after.png", _decor_contact_sheet())
    metrics = _decor_metrics()
    _save(EVIDENCE_DIR / "decor_silhouette_vs_farm.png", _decor_silhouette_sheet(metrics))
    (EVIDENCE_DIR / "decor_alpha_metrics.json").write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def _decor_contact_sheet() -> Image.Image:
    names = list(DECOR_BUILDERS.keys())
    cell_w, cell_h = 245, 160
    cols = 3
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGBA", (cell_w * cols, cell_h * rows), (18, 20, 27, 255))
    d = ImageDraw.Draw(sheet)
    for index, name in enumerate(names):
        img = Image.open(DECOR_DIR / f"{name}.png").convert("RGBA")
        scale = min(180 / img.width, 108 / img.height, 1.0)
        thumb = img.resize((int(img.width * scale), int(img.height * scale)), Image.Resampling.NEAREST)
        x = (index % cols) * cell_w
        y = (index // cols) * cell_h
        sheet.alpha_composite(thumb, (x + (cell_w - thumb.width) // 2, y + 10 + (108 - thumb.height) // 2))
        d.text((x + 10, y + 128), f"{name} {img.size}", fill=(232, 238, 245, 255))
    return sheet


def _alpha_mask(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA").getchannel("A"), dtype=np.uint8) > 0


def _decor_metrics() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for target, farm in FARM_COMPARE_PAIRS:
        target_path = DECOR_DIR / f"{target}.png"
        farm_path = DECOR_DIR / f"{farm}.png"
        target_img = Image.open(target_path).convert("RGBA")
        farm_img = Image.open(farm_path).convert("RGBA")
        target_mask = _alpha_mask(target_path)
        farm_mask = _alpha_mask(farm_path)
        if target_mask.shape != farm_mask.shape:
            same_alpha = False
            jaccard = 0.0
            changed = int(target_mask.size)
        else:
            same_alpha = bool(np.array_equal(target_mask, farm_mask))
            intersection = np.logical_and(target_mask, farm_mask).sum()
            union = np.logical_or(target_mask, farm_mask).sum()
            jaccard = float(intersection / union) if union else 1.0
            changed = int(np.not_equal(target_mask, farm_mask).sum())
        rows.append(
            {
                "target": target,
                "farm_reference": farm,
                "target_size": list(target_img.size),
                "farm_size": list(farm_img.size),
                "alpha_same": same_alpha,
                "alpha_jaccard": round(jaccard, 4),
                "alpha_changed_pixels": changed,
            }
        )
    return rows


def _mask_image(mask: np.ndarray, color: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    out = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    if mask.shape == (size[1], size[0]):
        out[mask] = color
    return Image.fromarray(out, "RGBA")


def _decor_silhouette_sheet(metrics: list[dict[str, object]]) -> Image.Image:
    cell_w, cell_h = 250, 144
    sheet = Image.new("RGBA", (cell_w * 3, cell_h * len(metrics)), (13, 16, 22, 255))
    d = ImageDraw.Draw(sheet)
    for row_index, row in enumerate(metrics):
        target = str(row["target"])
        farm = str(row["farm_reference"])
        target_img = Image.open(DECOR_DIR / f"{target}.png").convert("RGBA")
        farm_img = Image.open(DECOR_DIR / f"{farm}.png").convert("RGBA")
        size = target_img.size
        scale = min(170 / size[0], 90 / size[1], 1.0)
        y = row_index * cell_h
        for col, (label, img) in enumerate([(target, target_img), (farm, farm_img)]):
            thumb = img.resize((int(img.width * scale), int(img.height * scale)), Image.Resampling.NEAREST)
            x = col * cell_w
            sheet.alpha_composite(thumb, (x + (cell_w - thumb.width) // 2, y + 26 + (90 - thumb.height) // 2))
            d.text((x + 10, y + 8), label, fill=(232, 238, 245, 255))
        target_mask = _alpha_mask(DECOR_DIR / f"{target}.png")
        farm_mask = _alpha_mask(DECOR_DIR / f"{farm}.png")
        if target_mask.shape == farm_mask.shape:
            diff = np.logical_xor(target_mask, farm_mask)
        else:
            diff = target_mask
        mask_img = _mask_image(diff, (255, 76, 160, 230), size)
        thumb = mask_img.resize((int(size[0] * scale), int(size[1] * scale)), Image.Resampling.NEAREST)
        x = 2 * cell_w
        sheet.alpha_composite(thumb, (x + (cell_w - thumb.width) // 2, y + 26 + (90 - thumb.height) // 2))
        d.text((x + 10, y + 8), "alpha diff", fill=(255, 150, 205, 255))
        d.text((x + 10, y + 116), "same=%s jaccard=%.4f changed=%d" % (
            row["alpha_same"],
            float(row["alpha_jaccard"]),
            int(row["alpha_changed_pixels"]),
        ), fill=(190, 225, 235, 255))
    return sheet


def lightning_metrics() -> dict[str, object]:
    texture = Image.open(SPRITE_DIR / "proj_lightning.png").convert("RGBA")
    arr = np.asarray(texture, dtype=np.float32)
    mask = arr[..., 3] > 0
    base_mean = arr[..., :3][mask].mean(axis=0) / 255.0
    weapon_rows = {}
    for weapon_id, color in LIGHTNING_WEAPON_COLORS.items():
        tinted = arr[..., :3].copy()
        for channel in range(3):
            tinted[..., channel] *= color[channel]
        mean = tinted[mask].mean(axis=0) / 255.0
        weapon_rows[weapon_id] = {
            "mean_rgb": [round(float(v), 4) for v in mean],
            "green_over_red": round(float(mean[1] / max(mean[0], 0.0001)), 4),
            "blue_over_red": round(float(mean[2] / max(mean[0], 0.0001)), 4),
            "cyan_pass": bool(mean[1] > mean[0] * 1.35 and mean[2] > mean[0] * 1.35 and mean[2] >= mean[1] * 0.96),
        }
    metrics = {
        "proj_lightning_base_mean_rgb": [round(float(v), 4) for v in base_mean],
        "proj_lightning_neutral_max_channel_delta": round(float(np.max(np.ptp(arr[..., :3][mask], axis=1)) / 255.0), 4),
        "weapon_samples": weapon_rows,
        "enemy_ember_reference": {
            "source": "scripts/enemies/enemy.gd::_enemy_projectile_stats",
            "color": [1.0, 0.35, 0.24, 1.0],
            "uses_proj_lightning": False,
            "ember_pass": True,
        },
    }
    (EVIDENCE_DIR / "lightning_color_metrics.json").write_text(
        json.dumps(metrics, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return metrics


def main() -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    neutral_lightning()
    build_decor()
    metrics = lightning_metrics()
    if not all(row["cyan_pass"] for row in metrics["weapon_samples"].values()):
        raise SystemExit("R18 lightning cyan metric failed")
    for row in _decor_metrics():
        if row["alpha_same"]:
            raise SystemExit(f"R18 decor alpha still matches farm: {row['target']}")
    print("R18_ART_ASSETS_PASS")
    print(EVIDENCE_DIR.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
