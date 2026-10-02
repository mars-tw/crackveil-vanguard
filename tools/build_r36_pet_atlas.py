"""Pack original ImageGen RGBA components; never redraw the source sprites."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from build_r34_character_atlas import label_actors

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/pets/r36/pet_sheet_original.png"
OUT = ROOT / "assets/pets/r36/pet_atlas.png"


def main():
    rgba, labels, records = label_actors(Image.open(SOURCE).convert("RGBA"))
    bodies = [r for r in records if r["pixels"] >= 2000]
    if len(bodies) != 36:
        raise RuntimeError(f"Expected 36 complete original animal poses, got {len(bodies)}")
    bodies.sort(key=lambda r: r["center"][1])
    rows = [sorted(bodies[i:i+6], key=lambda r: r["center"][0]) for i in range(0, 36, 6)]
    poses = [pose for row in rows for pose in row]
    atlas = Image.new("RGBA", (768, 768))
    details = []
    for family, name in enumerate(["fire_fox", "thunder_bird", "spirit_rabbit"]):
        actor = poses[family*12:family*12+12]
        factor = 112 / max(max(r["bbox"][2]-r["bbox"][0]+4, r["bbox"][3]-r["bbox"][1]+4) for r in actor)
        for index, record in enumerate(actor):
            x0, y0, x1, y1 = record["bbox"]
            x0, y0 = max(0, x0-2), max(0, y0-2)
            x1, y1 = min(rgba.shape[1], x1+2), min(rgba.shape[0], y1+2)
            crop = rgba[y0:y1, x0:x1].copy()
            crop[labels[y0:y1, x0:x1] != record["label"]] = 0
            image = Image.fromarray(crop).resize((max(1, round((x1-x0)*factor)), max(1, round((y1-y0)*factor))), Image.Resampling.LANCZOS)
            cell = family*12+index
            atlas.alpha_composite(image, (cell%6*128+(128-image.width)//2, cell//6*128+118-image.height))
            details.append({"pet":name,"pose":index,"cell":cell,"original_component":record["label"],"bbox":record["bbox"],"original_pixels":record["pixels"]})
    atlas.save(OUT)
    manifest = {"source":str(SOURCE),"source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),"atlas":str(OUT),"layout":"6x6 cells128, 12 original keyposes per pet","source_unchanged":True,"poses":details}
    (OUT.parent / "pose_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"result":"R36_PET_ATLAS_PACKED","poses":36,"source_unchanged":True,"atlas":str(OUT)}))


if __name__ == "__main__":
    main()
