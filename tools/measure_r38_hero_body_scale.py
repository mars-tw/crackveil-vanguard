"""Read-only alpha measurements of the frames PlayerVisual actually displays."""
import json
import re
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
NEW = {"solar_lancer": 0, "tide_oracle": 1, "shadow_ronin": 2}
OLD = {"rift_captain": 0, "orbit_guard": 7, "arc_scout": 3}

def measure(actor, index, atlas_path):
    atlas = Image.open(ROOT / atlas_path).convert("RGBA")
    scale_text = (ROOT / f"resources/heroes/{actor}.tres").read_text(encoding="utf-8")
    scale = float(re.search(r"sprite_scale\s*=\s*([\d.]+)", scale_text)[1])
    art_size = 105 if actor == "rift_captain" else 80
    samples = []
    for frame_index in range(12):
        cell = index * 27 + frame_index
        rgba = np.asarray(atlas.crop(((cell % 16) * 128, (cell // 16) * 128,
                                     (cell % 16 + 1) * 128, (cell // 16 + 1) * 128)))
        alpha = rgba[:, :, 3] >= 96
        ys, xs = np.nonzero(alpha)
        bbox = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        # A narrow opaque spear/staff can enlarge full-alpha bounds. Measure the
        # dense body rows in a strip around the most occupied column as well.
        center_x = int(np.argmax(alpha.sum(axis=0)))
        strip = alpha[:, max(0, center_x - 9): min(128, center_x + 10)]
        body_rows = np.flatnonzero(strip.sum(axis=1) >= 4)
        body_height = int(body_rows[-1] - body_rows[0] + 1)
        height = bbox[3] - bbox[1]
        samples.append({"frame": frame_index, "alpha_bbox": bbox, "dense_body_height": body_height,
                        "body_logical_px": round(body_height * art_size / 128 * scale, 2),
                        "alpha_logical_px": round(height * art_size / 128 * scale, 2)})
    return {"actor": actor, "resource_scale": scale, "art_size": art_size,
            "dense_body_method": "alpha>=96; most-occupied column +/-9px; rows >=4 opaque pixels; excludes thin staff fringe",
            "body_logical_range": [min(s["body_logical_px"] for s in samples), max(s["body_logical_px"] for s in samples)],
            "alpha_logical_range": [min(s["alpha_logical_px"] for s in samples), max(s["alpha_logical_px"] for s in samples)],
            "frames": samples}

if __name__ == "__main__":
    result = {"formula": "PlayerVisual: art_size / 128 * HeroData.sprite_scale; camera/CSS can further change screen size",
              "new": [measure(a, i, "assets/sprites/r38_character_atlas.png") for a, i in NEW.items()],
              "old": [measure(a, i, "assets/sprites/r35_character_atlas.png") for a, i in OLD.items()]}
    print(json.dumps(result, ensure_ascii=False, indent=2))
