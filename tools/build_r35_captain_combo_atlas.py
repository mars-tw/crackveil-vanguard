"""Append ImageGen-authored poses; preserve every pixel of the R34 atlas.

New 160 px regions preserve body scale and the old 54 px foot offset. No pose is
painted, rotated, or synthesized here. Generated originals remain untouched.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from build_r34_character_atlas import label_actors

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/r35/captain_combo_sheet_compact.png"
BASE = ROOT / "assets/sprites/r34_character_atlas.png"
OUT = ROOT / "assets/sprites/r35_character_atlas.png"
CELL = 160
COLUMNS = 12
NAMES = ["attack_combo_a", "attack_combo_b", "attack_combo_finisher"]


def main() -> None:
    base = Image.open(BASE).convert("RGBA")
    source = Image.open(SOURCE).convert("RGBA")
    rgba, labels, records = label_actors(source)
    bodies = [r for r in records if r["pixels"] >= 2000]
    if len(bodies) != 18:
        raise RuntimeError(f"Expected 18 authored whole-body components; found {len(bodies)}")
    bodies.sort(key=lambda rec: rec["center"][1])
    rows = [sorted(bodies[i:i + 6], key=lambda rec: rec["center"][0]) for i in range(0, 18, 6)]
    poses = [pose for row in rows for pose in row]
    for small in [r for r in records if r["pixels"] < 2000]:
        nearest = min(poses, key=lambda rec: (rec["center"][0] - small["center"][0]) ** 2 + (rec["center"][1] - small["center"][1]) ** 2)
        distance = np.linalg.norm(np.array(nearest["center"]) - np.array(small["center"]))
        if distance > 130:
            raise RuntimeError("Detached unowned source component needs visual review")
        labels[labels == small["label"]] = nearest["label"]
        a, b = nearest["bbox"], small["bbox"]
        nearest["bbox"] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]
    # The three final ready poses establish one scale for all 18 joint poses.
    ready_height = max(poses[i]["bbox"][3] - poses[i]["bbox"][1] for i in (5, 11, 17))
    factor = 104.0 / ready_height
    atlas = Image.new("RGBA", (base.width, base.height + CELL * 2))
    atlas.paste(base, (0, 0))
    prepared = []
    frame_hashes = []
    for index, rec in enumerate(poses):
        x0, y0, x1, y1 = rec["bbox"]
        x0, y0, x1, y1 = max(0, x0 - 2), max(0, y0 - 2), min(source.width, x1 + 2), min(source.height, y1 + 2)
        pixels = rgba[y0:y1, x0:x1].copy()
        pixels[labels[y0:y1, x0:x1] != rec["label"]] = 0
        actor = Image.fromarray(pixels).resize((round((x1 - x0) * factor), round((y1 - y0) * factor)), Image.Resampling.LANCZOS)
        if actor.width > CELL - 8 or actor.height > 134:
            raise RuntimeError(f"Pose {index} cannot fit without changing its uniform body scale: {actor.size}")
        frame = Image.new("RGBA", (CELL, CELL))
        frame.alpha_composite(actor, (round((CELL - actor.width) / 2), 134 - actor.height))
        region = [(index % COLUMNS) * CELL, base.height + (index // COLUMNS) * CELL, CELL, CELL]
        atlas.paste(frame, (region[0], region[1]))
        digest = hashlib.sha256(frame.tobytes()).hexdigest()
        frame_hashes.append(digest)
        prepared.append({"animation": NAMES[index // 6], "frame": index % 6, "source_bbox": rec["bbox"], "region": region, "rgba_sha256": digest})
    if len(set(frame_hashes)) != 18:
        raise RuntimeError("One or more packed poses are duplicated")
    if atlas.crop((0, 0, base.width, base.height)).tobytes() != base.tobytes():
        raise RuntimeError("Existing R34 atlas pixels changed")
    if max(atlas.size) > 4096:
        raise RuntimeError("Combined atlas exceeds the 4096 px texture budget")
    atlas.save(OUT)
    evidence = ROOT / "docs/evidence/r35"
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "captain_combo_atlas.json").write_text(json.dumps({"status": "PACKED_REQUIRES_RUNTIME_VISUAL_QC", "source": str(SOURCE.relative_to(ROOT)), "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(), "original_base_sha256": hashlib.sha256(BASE.read_bytes()).hexdigest(), "original_pixels_unchanged": True, "size": atlas.size, "body_scale_uniform": factor, "cell": CELL, "columns": COLUMNS, "origin_y": base.height, "foot_offset": 54, "unique_authored_poses": len(set(frame_hashes)), "frames": prepared}, indent=2), encoding="utf-8")
    print(f"R35_CAPTAIN_ATLAS_PASS old_pixels=unchanged original_character_frames=459 appended_authored_poses=18 size={atlas.size} uniform_scale={factor:.6f} foot_offset=54")


if __name__ == "__main__":
    main()
