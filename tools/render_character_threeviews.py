"""Render R20 front/side/back orthographic review sheets for all ten heroes."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_true_animation_atlas as factory


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "docs" / "evidence" / "art_r20" / "threeview"
HEROES = tuple(spec for spec in factory.CHARACTERS if spec["kind"] == "hero")
VIEW_ROTATIONS = (0.0, -math.pi * 0.5, math.pi)
VIEW_OFFSETS = (-3.0, 0.0, 3.0)


def transform_recent_vertices(start: int, angle: float, x_offset: float) -> None:
    cosine = math.cos(angle)
    sine = math.sin(angle)
    for index in range(start, len(factory.MESH_VERTICES)):
        x, y, z = factory.MESH_VERTICES[index]
        factory.MESH_VERTICES[index] = (
            x * cosine - y * sine + x_offset,
            x * sine + y * cosine,
            z,
        )


def configure_review_scene(output: Path) -> None:
    factory.configure_scene(1)
    scene = bpy.context.scene
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.filepath = str(output)
    scene.render.filter_size = 0.72
    scene.camera.location = (0.0, -40.0, 0.15)
    scene.camera.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    # Blender's orthographic scale is the horizontal span for this 2:1 frame;
    # 10 world units yields a 5-unit vertical span and three non-overlapping
    # full-body review panels.
    scene.camera.data.ortho_scale = 10.0
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (0.018, 0.035, 0.070, 1.0)
    background.inputs["Strength"].default_value = 0.52


def render_hero(spec: dict) -> dict[str, object]:
    factory.reset_geometry_buffers()
    output = OUTPUT_DIR / f"{spec['id']}.png"
    configure_review_scene(output)
    per_view_tris = 0
    for angle, x_offset in zip(VIEW_ROTATIONS, VIEW_OFFSETS):
        vertex_start = len(factory.MESH_VERTICES)
        per_view_tris = factory.build_character(0.0, 0.0, spec, "idle", 0)
        transform_recent_vertices(vertex_start, angle, x_offset)
    factory.finalize_atlas_mesh(f"{spec['id']}_R20_Threeview")
    bpy.ops.render.render(write_still=True)
    print(f"R20_THREEVIEW hero={spec['id']} tris={per_view_tris} output={output}", flush=True)
    return {
        "hero": spec["id"],
        "tris": per_view_tris,
        "views": ["front", "side", "back"],
        "palette": [list(color[:3]) for color in spec["palette"]],
        "surface_materials": ["skin", "cloth", "leather", "metal", "lens"],
        "output": str(output.relative_to(ROOT)).replace("\\", "/"),
    }


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    records = [render_hero(spec) for spec in HEROES]
    manifest = OUTPUT_DIR.parent / "threeview_manifest.json"
    manifest.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"R20_THREEVIEW_MANIFEST {manifest} heroes={len(records)}", flush=True)


if __name__ == "__main__":
    main()
