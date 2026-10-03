"""Mechanically pack original R38 RGBA animation sheets; never paint poses.

Generated PNG originals remain unchanged under assets/art/r38/sources.
Connected-component extraction prevents a long spear crossing a nominal cell
from being clipped or becoming part of the neighboring animation frame.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/art/r38"
SOURCE = ART / "sources"
ACTORS = [
    "hero_solar_lancer", "hero_tide_oracle", "hero_shadow_ronin",
    "enemy_dune_scarab", "enemy_sand_stalker", "enemy_tide_siren",
    "enemy_coral_colossus", "enemy_bloom_wisp", "enemy_clockwork_reaper",
]
PLAYBACK = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5,
            6, 7, 8, 9, 10, 11, 12, 13, 13, 14, 14, 14, 15, 15, 15]
CELL_SIZE = 128
ATLAS_COLUMNS = 16


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def components(alpha: np.ndarray, threshold: int = 8) -> list[dict]:
    """8-connected run-length labels, including antialiased alpha boundaries."""
    parents: list[int] = []
    runs: list[tuple[int, int, int, int]] = []
    previous: list[tuple[int, int, int]] = []

    def find(label: int) -> int:
        while parents[label] != label:
            parents[label] = parents[parents[label]]
            label = parents[label]
        return label

    def merge(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parents[max(ra, rb)] = min(ra, rb)

    for y, row in enumerate(alpha):
        binary = row > threshold
        endpoints = np.flatnonzero(np.diff(np.r_[False, binary, False]))
        current = []
        for x0, x1 in endpoints.reshape(-1, 2):
            x0, x1 = int(x0), int(x1)
            label = len(parents)
            parents.append(label)
            for p0, p1, plabel in previous:
                if p1 >= x0 and p0 <= x1:
                    merge(label, plabel)
            current.append((x0, x1, label))
            runs.append((y, x0, x1, label))
        previous = current
    grouped: dict[int, dict] = {}
    for y, x0, x1, label in runs:
        key = find(label)
        if key not in grouped:
            grouped[key] = {"bbox": [x0, y, x1, y + 1], "pixels": 0, "runs": []}
        item = grouped[key]
        box = item["bbox"]
        box[0], box[1] = min(box[0], x0), min(box[1], y)
        box[2], box[3] = max(box[2], x1), max(box[3], y + 1)
        item["pixels"] += x1 - x0
        item["runs"].append((y, x0, x1))
    return sorted(grouped.values(), key=lambda item: item["pixels"], reverse=True)


def inspect_actor(actor: str) -> dict:
    path = SOURCE / f"{actor}.png"
    image = Image.open(path).convert("RGBA")
    alpha = np.asarray(image)[:, :, 3]
    parts = components(alpha)
    major = [part for part in parts if part["pixels"] >= 4000]
    return {"id": actor, "size": list(image.size),
            "alpha_range": [int(alpha.min()), int(alpha.max())],
            "major_components": [{"bbox": p["bbox"], "pixels": p["pixels"]} for p in major],
            "component_count": len(parts), "major_count": len(major)}


def pack_actor(actor: str) -> tuple[list[Image.Image], dict]:
    path = SOURCE / f"{actor}.png"
    original = Image.open(path).convert("RGBA")
    rgba = np.asarray(original)
    alpha = rgba[:, :, 3]
    parts = components(alpha)
    major = [part for part in parts if part["pixels"] >= 4000]
    if len(major) != 16:
        raise ValueError(f"{actor}: expected 16 separate actor silhouettes, found {len(major)}")
    by_slot: dict[int, dict] = {}
    cell_w, cell_h = original.width / 4, original.height / 4
    for part in major:
        x0, y0, x1, y1 = part["bbox"]
        col = min(3, max(0, int((x0 + x1) * .5 / cell_w)))
        row = min(3, max(0, int((y0 + y1) * .5 / cell_h)))
        slot = row * 4 + col
        if slot in by_slot:
            raise ValueError(f"{actor}: ambiguous connected component assignment at pose {slot}")
        by_slot[slot] = part
    if set(by_slot) != set(range(16)):
        raise ValueError(f"{actor}: incomplete 4x4 component assignment")
    owner = np.full(alpha.shape, -1, dtype=np.int16)
    boxes = np.asarray([by_slot[i]["bbox"] for i in range(16)], dtype=np.float32)

    def closest_box(x: float, y: float) -> int:
        dx = np.maximum(np.maximum(boxes[:, 0] - x, x - boxes[:, 2]), 0)
        dy = np.maximum(np.maximum(boxes[:, 1] - y, y - boxes[:, 3]), 0)
        centers = (boxes[:, :2] + boxes[:, 2:]) * .5
        # Bounding distance respects a long weapon; center resolves only ties.
        distance = dx * dx + dy * dy + np.sum((centers - [x, y]) ** 2, axis=1) * .0001
        return int(np.argmin(distance))

    major_owners = {id(part): slot for slot, part in by_slot.items()}
    for part in parts:
        x0, y0, x1, y1 = part["bbox"]
        slot = major_owners.get(id(part), closest_box((x0 + x1) * .5, (y0 + y1) * .5))
        for y, start, end in part["runs"]:
            owner[y, start:end] = slot
    # Preserve even faint antialias pixels rather than erase their alpha.
    faint_y, faint_x = np.nonzero((alpha > 0) & (owner < 0))
    for y, x in zip(faint_y, faint_x):
        owner[y, x] = closest_box(float(x), float(y))
    crops = []
    crop_boxes = []
    extracted_count = 0
    extracted_alpha = 0
    for slot in range(16):
        ys, xs = np.nonzero(owner == slot)
        box = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        x0, y0, x1, y1 = box
        pixels = rgba[y0:y1, x0:x1].copy()
        pixels[owner[y0:y1, x0:x1] != slot] = 0
        crop = Image.fromarray(pixels, "RGBA")
        crop_boxes.append(box)
        crops.append(crop)
        extracted_count += int(np.count_nonzero(pixels[:, :, 3]))
        extracted_alpha += int(pixels[:, :, 3].sum())
    source_count = int(np.count_nonzero(alpha))
    source_alpha = int(alpha.sum())
    assert source_count == extracted_count and source_alpha == extracted_alpha, actor
    # One scale for all sixteen poses: no apparent breathing/attack zoom.
    scale = min(112 / max(c.width for c in crops), 112 / max(c.height for c in crops))
    frames = []
    for crop in crops:
        size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
        resized = crop.resize(size, Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", (CELL_SIZE, CELL_SIZE))
        frame.alpha_composite(resized, ((CELL_SIZE - size[0]) // 2, 120 - size[1]))
        frames.append(frame)
    hashes = [hashlib.sha256(frame.tobytes()).hexdigest() for frame in frames]
    assert len(set(hashes)) == 16, f"{actor}: duplicated original pose"
    report = {"id": actor, "source": path.relative_to(ROOT).as_posix(), "source_sha256": sha256(path),
              "source_pose_count": 16, "source_pose_boxes": crop_boxes,
              "uniform_actor_scale": scale, "foot_baseline": 120,
              "source_alpha_nonzero": source_count, "extracted_alpha_nonzero": extracted_count,
              "source_alpha_sum": source_alpha, "extracted_alpha_sum": extracted_alpha,
              "unique_original_poses": len(set(hashes)), "walk_unique_poses": len(set(hashes[2:6])),
              "attack_unique_poses": len(set(hashes[6:12])), "impact_source_pose": 8,
              "playback_pose_indices": PLAYBACK, "original_pose_sha256": hashes,
              "icon": f"assets/sprites/{actor}.png"}
    return frames, report


def pack_all() -> dict:
    atlas_rows = (len(ACTORS) * len(PLAYBACK) + ATLAS_COLUMNS - 1) // ATLAS_COLUMNS
    atlas = Image.new("RGBA", (ATLAS_COLUMNS * CELL_SIZE, atlas_rows * CELL_SIZE))
    actors = []
    preview = Image.new("RGBA", (16 * CELL_SIZE, len(ACTORS) * CELL_SIZE))
    for actor_index, actor in enumerate(ACTORS):
        frames, report = pack_actor(actor)
        report["atlas_character_index"] = actor_index
        for pose, frame in enumerate(frames):
            preview.alpha_composite(frame, (pose * CELL_SIZE, actor_index * CELL_SIZE))
        for frame_index, pose_index in enumerate(PLAYBACK):
            cell = actor_index * len(PLAYBACK) + frame_index
            atlas.alpha_composite(frames[pose_index], ((cell % ATLAS_COLUMNS) * CELL_SIZE,
                                                      (cell // ATLAS_COLUMNS) * CELL_SIZE))
        icon_path = ROOT / report["icon"]
        frames[0].save(icon_path, optimize=True)
        report["icon_sha256"] = sha256(icon_path)
        actors.append(report)
    atlas_path = ROOT / "assets/sprites/r38_character_atlas.png"
    atlas.save(atlas_path, optimize=True)
    preview_path = ART / "qa/original_pose_contact_sheet.png"
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    preview.save(preview_path, optimize=True)
    tile_report = []
    for name in ("tile_desert", "tile_coral", "tile_clockwork"):
        path = ART / f"{name}.png"
        tile = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
        tile_report.append({"id": name, "path": path.relative_to(ROOT).as_posix(), "sha256": sha256(path),
                            "edge_mean_rgb_error_x": float(np.abs(tile[:, 0] - tile[:, -1]).mean()),
                            "edge_mean_rgb_error_y": float(np.abs(tile[0] - tile[-1]).mean())})
    manifest = {"revision": "r38", "generation_mode": "built_in_imagegen", "source_originals_preserved": True,
                "packing": "RGBA connected-component crop and uniform resize only; no painted or procedural body poses",
                "atlas": atlas_path.relative_to(ROOT).as_posix(), "atlas_sha256": sha256(atlas_path),
                "atlas_cell_size": CELL_SIZE, "atlas_columns": ATLAS_COLUMNS, "playback_frames_per_actor": 27,
                "original_actor_count": len(actors), "original_pose_count": len(actors) * 16,
                "actors": actors, "tiles": tile_report,
                "landmarks": {"path": "assets/art/r38/landmarks.png", "columns": 4, "rows": 2,
                              "order": ["desert_tomb", "desert_obelisk", "coral_palace", "coral_lighthouse",
                                        "moonflower_tree", "petal_shrine", "clockwork_gate", "gear_tower"],
                              "sha256": sha256(ART / "landmarks.png")}}
    (ART / "source_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inspect-only", action="store_true")
    args = parser.parse_args()
    if args.inspect_only:
        print(json.dumps([inspect_actor(actor) for actor in ACTORS], ensure_ascii=False, indent=2))
    else:
        manifest = pack_all()
        print(json.dumps({"atlas": manifest["atlas"], "actors": manifest["original_actor_count"],
                          "original_poses": manifest["original_pose_count"], "tiles": manifest["tiles"]}, indent=2))


if __name__ == "__main__":
    main()
