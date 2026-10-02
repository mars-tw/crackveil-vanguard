"""Mechanical sprite extraction/packing; never overwrites generated source sheets.

Original RGBA pixels are assigned to their alpha-connected actor, then rendered
at a consistent scale/baseline in playback cells. This is game asset preparation,
not a substitute for missing poses or a repaint of generated artwork.
"""
from __future__ import annotations
from collections import deque
import hashlib
import json
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/sprites/r34_character_atlas.png"
CELL = 128
COLUMNS = 16
ORDER = ["hero_captain", "hero_rift_sniper", "hero_void_weaver", "hero_arc_scout", "hero_echo_singer", "hero_ember_grenadier", "hero_line_mender", "hero_orbit_guard", "hero_pulse_artificer", "hero_shepherd", "enemy_grunt", "enemy_fast", "enemy_tank", "enemy_elite_field", "enemy_elite_split", "enemy_elite_swift", "enemy_boss"]
SHEETS = {
    "hero_sheet_a.png": ["hero_captain", "hero_orbit_guard", "hero_arc_scout"],
    "hero_sheet_b.png": ["hero_void_weaver", "hero_echo_singer", "hero_ember_grenadier"],
    "hero_sheet_c.png": ["hero_rift_sniper", "hero_line_mender", "hero_pulse_artificer"],
    "character_sheet_d.png": ["hero_shepherd", "enemy_grunt", "enemy_fast"],
    "character_sheet_e.png": ["enemy_tank", "enemy_elite_field", "enemy_elite_split"],
    "character_sheet_f.png": ["enemy_elite_swift", "enemy_boss"],
}
PLAYBACK = [0, 0, 1, 1, 2, 3, 4, 5, 2, 3, 4, 5, 6, 6, 7, 7, 8, 0, 9, 9, 9, 10, 10, 10, 11, 11, 11]

def label_actors(image: Image.Image):
    rgba = np.array(image.convert("RGBA"))
    height, width = rgba.shape[:2]
    alpha = rgba[:, :, 3]
    labels = np.zeros((height, width), dtype=np.int32)
    records = []
    label = 0
    for sy, sx in zip(*np.nonzero(alpha >= 96)):
        if labels[sy, sx]:
            continue
        label += 1
        labels[sy, sx] = label
        queue = deque([(int(sx), int(sy))])
        pixels = []
        while queue:
            x, y = queue.popleft()
            pixels.append((x, y))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and not labels[ny, nx] and alpha[ny, nx] >= 96:
                        labels[ny, nx] = label
                        queue.append((nx, ny))
        if len(pixels) >= 350:
            xx, yy = zip(*pixels)
            records.append({"label": label, "bbox": [min(xx), min(yy), max(xx)+1, max(yy)+1], "center": [sum(xx)/len(xx), sum(yy)/len(yy)], "pixels": len(pixels)})
    # Attach antialiased perimeter pixels to an adjacent owned actor, retaining
    # their original RGBA; avoid pulling a neighboring actor from an expanded box.
    for _ in range(2):
        previous = labels.copy()
        for dy, dx in [(-1,0),(1,0),(0,-1),(0,1)]:
            shifted = np.roll(previous, (dy,dx), axis=(0,1))
            if dy == -1: shifted[-1,:] = 0
            if dy == 1: shifted[0,:] = 0
            if dx == -1: shifted[:,-1] = 0
            if dx == 1: shifted[:,0] = 0
            assign = (labels == 0) & (shifted != 0) & (alpha != 0)
            labels[assign] = shifted[assign]
    return rgba, labels, records

def main():
    assets, evidence = {}, []
    repair_source = ROOT / "assets/art/r34/character_sheet_d-v2.png"
    repair_image = Image.open(repair_source).convert("RGBA")
    repair_rgba, repair_labels, repair_records = label_actors(repair_image)
    repair_records = sorted([r for r in repair_records if r["pixels"] >= 2000], key=lambda r: r["center"][1])
    repair_row = sorted(repair_records[6:12], key=lambda r: r["center"][0])
    shepherd_preparation = repair_row[0]
    for filename, identities in SHEETS.items():
        source = ROOT / "assets/art/r34" / filename
        image = Image.open(source).convert("RGBA")
        rgba, labels, records = label_actors(image)
        # A detached staff/blade in a fallen pose is still part of that actor;
        # join its original pixels to the nearest main body, never repaint it.
        small = [record for record in records if record["pixels"] < 2000]
        bodies = [record for record in records if record["pixels"] >= 2000]
        for accessory in small:
            owner = min(bodies, key=lambda record: (record["center"][0]-accessory["center"][0])**2 + (record["center"][1]-accessory["center"][1])**2)
            distance = ((owner["center"][0]-accessory["center"][0])**2 + (owner["center"][1]-accessory["center"][1])**2)**0.5
            if distance > image.width / 7:
                raise RuntimeError(f"{filename}: unowned accessory requires review")
            labels[labels == accessory["label"]] = owner["label"]
            a, b = owner["bbox"], accessory["bbox"]
            owner["bbox"] = [min(a[0],b[0]),min(a[1],b[1]),max(a[2],b[2]),max(a[3],b[3])]
        records = bodies
        expected = 45 if filename == "character_sheet_e.png" else len(identities) * 12
        if len(records) != expected:
            raise RuntimeError(f"{filename}: {len(records)} main components, expected {expected}; requires visual crop review")
        # Fallen poses sit lower than standing ones; canvas fractions are not
        # action-row boundaries. First associate the visually reviewed identity
        # bands by vertical order, then split each band's two pose rows.
        records.sort(key=lambda rec: rec["center"][1])
        per_identity = 15 if filename == "character_sheet_e.png" else 12
        rows = []
        for actor_index in range(len(identities)):
            group = records[actor_index*per_identity:(actor_index+1)*per_identity]
            first_count = 8 if filename == "character_sheet_e.png" else 6
            first, second = group[:first_count],group[first_count:]
            first.sort(key=lambda rec: rec["center"][0])
            second.sort(key=lambda rec: rec["center"][0])
            rows.extend([first,second])
        for actor_index, identity in enumerate(identities):
            first, second = rows[actor_index*2:actor_index*2+2]
            if filename == "character_sheet_e.png":
                if (len(first),len(second)) != (8,7):
                    raise RuntimeError(f"{identity}: E actual action rows changed")
                # Visually inspected E's 15 poses: 5/6/7 are anticipation,
                # forward strike/recovery; second row 1 recoil, 4/6 falls.
                selected = [first[0],first[1],first[2],first[3],first[4],first[3],first[5],first[6],first[7],second[1],second[4],second[6]]
            else:
                if (len(first),len(second)) != (6,6):
                    raise RuntimeError(f"{identity}: nonuniform action rows {(len(first),len(second))}")
                selected = first + second
            idle_height = max(selected[0]["bbox"][3]-selected[0]["bbox"][1], selected[1]["bbox"][3]-selected[1]["bbox"][1])
            factor = 104.0 / idle_height
            # A single scale for all poses prevents changing body mass on impact.
            widest = max(r["bbox"][2]-r["bbox"][0] for r in selected)
            factor = min(factor, 120.0/widest)
            frames = []
            for pose_index, record in enumerate(selected):
                pose_rgba, pose_labels, pose_image = rgba, labels, image
                if identity == "hero_shepherd" and pose_index == 6:
                    # Only the corrected single-staff preparation enters the
                    # game. The other 35 D poses retain their original pixels.
                    record = shepherd_preparation
                    pose_rgba, pose_labels, pose_image = repair_rgba, repair_labels, repair_image
                x0,y0,x1,y1 = record["bbox"]
                pad = 2
                x0,y0,x1,y1 = max(0,x0-pad),max(0,y0-pad),min(pose_image.width,x1+pad),min(pose_image.height,y1+pad)
                pixels = pose_rgba[y0:y1,x0:x1].copy()
                owned = pose_labels[y0:y1,x0:x1] == record["label"]
                pixels[~owned] = 0
                extracted = Image.fromarray(pixels).resize((max(1,round((x1-x0)*factor)),max(1,round((y1-y0)*factor))),Image.Resampling.LANCZOS)
                frame = Image.new("RGBA",(CELL,CELL))
                # Upright frames share a stable foot baseline. Fallen poses also
                # meet the ground baseline; their folded joints are source art.
                px = round((CELL-extracted.width)/2)
                py = 118-extracted.height
                frame.alpha_composite(extracted,(px,py))
                frames.append(frame)
            assets[identity] = frames
            evidence.append({"id":identity,"source":filename,"source_sha256":hashlib.sha256(source.read_bytes()).hexdigest(),"source_slots":12,"unique_source_components":len(set(r["label"] for r in selected)),"playback_frames":27,"scale":factor,"bounds":[r["bbox"] for r in selected],"pose_6_repair": {"source":repair_source.name,"sha256":hashlib.sha256(repair_source.read_bytes()).hexdigest(),"bounds":shepherd_preparation["bbox"]} if identity=="hero_shepherd" else None})
    atlas = Image.new("RGBA",(CELL*COLUMNS,CELL*((len(ORDER)*27+COLUMNS-1)//COLUMNS)))
    for character_index, identity in enumerate(ORDER):
        for phase_index, pose_index in enumerate(PLAYBACK):
            cell = character_index*27+phase_index
            atlas.alpha_composite(assets[identity][pose_index],((cell%COLUMNS)*CELL,(cell//COLUMNS)*CELL))
    atlas.save(OUT)
    report = ROOT/"docs/evidence/r34/atlas_preparation.json"
    report.write_text(json.dumps({"status":"PACKED_REQUIRES_RUNTIME_VISUAL_QC","cell":CELL,"columns":COLUMNS,"size":atlas.size,"characters":evidence,"source_content":"Original sources retained; connected-actor extraction and frame packing only."},ensure_ascii=False,indent=2),encoding="utf-8")
    print(f"R34_ATLAS_PACKED characters={len(ORDER)} keyposes=12 timing_frames=27 size={atlas.size}")

if __name__ == "__main__":
    main()
