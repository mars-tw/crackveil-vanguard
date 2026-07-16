"""Blender-side operations used through the Blender MCP execute_code handler."""

from __future__ import annotations

import json
from collections import deque
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector


ROOT = Path(r"C:\Users\digimkt\Desktop\遊戲\rift-survivors")


def clear_scene() -> None:
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    # Direct datablock removal also catches hidden/non-selectable leftovers;
    # select_all + delete does not.
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)
    print("R21_SCENE_CLEARED")


def _mesh_components(obj: bpy.types.Object) -> list[dict[str, object]]:
    # glTF duplicates vertices at UV/material/hard-normal seams.  Weld only
    # coincident positions in a temporary BMesh before evaluating topology, so
    # authored seams do not masquerade as thousands of loose components.
    working = bmesh.new()
    working.from_mesh(obj.data)
    bmesh.ops.transform(working, matrix=obj.matrix_world, verts=working.verts)
    working.verts.ensure_lookup_table()
    if working.verts:
        low = Vector((min(v.co.x for v in working.verts), min(v.co.y for v in working.verts), min(v.co.z for v in working.verts)))
        high = Vector((max(v.co.x for v in working.verts), max(v.co.y for v in working.verts), max(v.co.z for v in working.verts)))
        weld_distance = max((high - low).length * 1e-5, 1e-7)
        bmesh.ops.remove_doubles(working, verts=list(working.verts), dist=weld_distance)
    working.verts.ensure_lookup_table()
    unseen = set(working.verts)
    components: list[dict[str, object]] = []
    while unseen:
        start = unseen.pop()
        members = [start]
        queue = deque([start])
        while queue:
            vertex = queue.popleft()
            for edge in vertex.link_edges:
                neighbor = edge.other_vert(vertex)
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    members.append(neighbor)
                    queue.append(neighbor)
        points = [vertex.co for vertex in members]
        low = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
        high = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
        center = (low + high) * 0.5
        components.append({
            "vertices": len(members),
            "bbox_min": [round(value, 5) for value in low],
            "bbox_max": [round(value, 5) for value in high],
            "center": [round(value, 5) for value in center],
            "extent": [round(value, 5) for value in high - low],
        })
    working.free()
    return sorted(components, key=lambda component: int(component["vertices"]), reverse=True)


def qc_current(asset_id: str) -> dict[str, object]:
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        return {"asset": asset_id, "pass": False, "failure": "no mesh imported"}
    components: list[dict[str, object]] = []
    vertex_total = 0
    polygon_total = 0
    for obj in mesh_objects:
        object_components = _mesh_components(obj)
        for component in object_components:
            component["object"] = obj.name
        components.extend(object_components)
        vertex_total += len(obj.data.vertices)
        polygon_total += len(obj.data.polygons)
    components.sort(key=lambda component: int(component["vertices"]), reverse=True)
    welded_vertex_total = sum(int(component["vertices"]) for component in components)
    lows = [Vector(component["bbox_min"]) for component in components]
    highs = [Vector(component["bbox_max"]) for component in components]
    overall_low = Vector((min(v.x for v in lows), min(v.y for v in lows), min(v.z for v in lows)))
    overall_high = Vector((max(v.x for v in highs), max(v.y for v in highs), max(v.z for v in highs)))
    extent = overall_high - overall_low
    height = max(extent.z, 1e-6)
    width = max(extent.x, 1e-6)
    main = components[0]
    main_low = Vector(main["bbox_min"])
    main_high = Vector(main["bbox_max"])
    main_ratio = int(main["vertices"]) / max(welded_vertex_total, 1)

    # A separate hat or weapon is allowed, but the largest connected body must
    # span from the planted-foot zone into the head/neck zone.  This flags the
    # visibly broken Rodin cases without rejecting intentional props.
    main_reaches_feet = main_low.z <= overall_low.z + height * 0.12
    main_reaches_head = main_high.z >= overall_low.z + height * 0.72
    bottom_points: list[Vector] = []
    threshold = overall_low.z + height * 0.07
    for obj in mesh_objects:
        bottom_points.extend(
            obj.matrix_world @ vertex.co
            for vertex in obj.data.vertices
            if (obj.matrix_world @ vertex.co).z <= threshold
        )
    bottom_span = (max(point.x for point in bottom_points) - min(point.x for point in bottom_points)) if bottom_points else 0.0
    feet_planted = bool(bottom_points) and bottom_span >= width * 0.16
    separated_large_parts = sum(int(component["vertices"]) >= welded_vertex_total * 0.02 for component in components)
    passed = bool(
        len(mesh_objects) == 1
        and main_ratio >= 0.50
        and main_reaches_feet
        and main_reaches_head
        and feet_planted
    )
    failure_reasons: list[str] = []
    if len(mesh_objects) != 1:
        failure_reasons.append(f"expected one mesh object, got {len(mesh_objects)}")
    if main_ratio < 0.50:
        failure_reasons.append(f"main connected body only {main_ratio:.1%} of vertices")
    if not main_reaches_head:
        failure_reasons.append("largest body does not reach head/neck zone")
    if not main_reaches_feet:
        failure_reasons.append("largest body does not reach planted-foot zone")
    if not feet_planted:
        failure_reasons.append("bottom silhouette does not show planted bilateral feet")
    return {
        "asset": asset_id,
        "pass": passed,
        "mesh_objects": len(mesh_objects),
        "vertices": vertex_total,
        "welded_vertices": welded_vertex_total,
        "polygons": polygon_total,
        "loose_components": len(components),
        "large_components": separated_large_parts,
        "main_component_ratio": round(main_ratio, 4),
        "main_reaches_head": main_reaches_head,
        "main_reaches_feet": main_reaches_feet,
        "feet_planted": feet_planted,
        "bbox_min": [round(value, 5) for value in overall_low],
        "bbox_max": [round(value, 5) for value in overall_high],
        "bbox_extent": [round(value, 5) for value in extent],
        "failure_reasons": failure_reasons,
        "components": components[:24],
    }


def qc_and_export(asset_id: str) -> dict[str, object]:
    report = qc_current(asset_id)
    qc_path = ROOT / "docs" / "evidence" / "art_r21" / "qc" / f"{asset_id}.json"
    qc_path.parent.mkdir(parents=True, exist_ok=True)
    qc_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if report["pass"]:
        output = ROOT / "assets" / "rodin" / f"hero_{asset_id}.glb"
        output.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH":
                obj.select_set(True)
                bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(
            filepath=str(output),
            export_format="GLB",
            use_selection=True,
            export_animations=False,
        )
        report["export"] = str(output)
        report["export_bytes"] = output.stat().st_size
        qc_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("R21_QC " + json.dumps(report, ensure_ascii=False))
    return report


def qc_glb(asset_id: str, filename: str) -> dict[str, object]:
    """QC an approved/preexisting GLB without rewriting the source file."""
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets" / "rodin" / filename))
    report = qc_current(asset_id)
    report["source"] = f"assets/rodin/{filename}"
    report["source_bytes"] = (ROOT / "assets" / "rodin" / filename).stat().st_size
    qc_path = ROOT / "docs" / "evidence" / "art_r21" / "qc" / f"{asset_id}.json"
    qc_path.parent.mkdir(parents=True, exist_ok=True)
    qc_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("R21_QC_SOURCE " + json.dumps(report, ensure_ascii=False))
    return report
