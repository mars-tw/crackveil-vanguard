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


def _mesh_components(obj: bpy.types.Object, overall_low_z: float, height: float) -> list[dict[str, object]]:
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
        top_threshold = overall_low_z + height * 0.85
        top_members = {vertex for vertex in members if vertex.co.z >= top_threshold}
        top_groups: list[dict[str, object]] = []
        unseen_top = set(top_members)
        while unseen_top:
            top_start = unseen_top.pop()
            top_group = [top_start]
            top_queue = deque([top_start])
            while top_queue:
                vertex = top_queue.popleft()
                for edge in vertex.link_edges:
                    neighbor = edge.other_vert(vertex)
                    if neighbor in unseen_top:
                        unseen_top.remove(neighbor)
                        top_group.append(neighbor)
                        top_queue.append(neighbor)
            top_points = [vertex.co for vertex in top_group]
            top_low = Vector((min(point.x for point in top_points), min(point.y for point in top_points), min(point.z for point in top_points)))
            top_high = Vector((max(point.x for point in top_points), max(point.y for point in top_points), max(point.z for point in top_points)))
            top_groups.append({
                "vertices": len(top_group),
                "bbox_min": [round(value, 5) for value in top_low],
                "bbox_max": [round(value, 5) for value in top_high],
                "extent": [round(value, 5) for value in top_high - top_low],
            })
        top_profiles: list[dict[str, object]] = []
        for fraction in (0.85, 0.90, 0.95, 0.98):
            profile_points = [vertex.co for vertex in members if vertex.co.z >= overall_low_z + height * fraction]
            if profile_points:
                profile_low = Vector((min(point.x for point in profile_points), min(point.y for point in profile_points), min(point.z for point in profile_points)))
                profile_high = Vector((max(point.x for point in profile_points), max(point.y for point in profile_points), max(point.z for point in profile_points)))
                profile_extent = profile_high - profile_low
            else:
                profile_extent = Vector((0.0, 0.0, 0.0))
            top_profiles.append({
                "height_fraction": fraction,
                "vertices": len(profile_points),
                "extent": [round(value, 5) for value in profile_extent],
            })
        components.append({
            "vertices": len(members),
            "bbox_min": [round(value, 5) for value in low],
            "bbox_max": [round(value, 5) for value in high],
            "center": [round(value, 5) for value in center],
            "extent": [round(value, 5) for value in high - low],
            "top_zone_vertices": len(top_members),
            "top_zone_groups": sorted(top_groups, key=lambda group: int(group["vertices"]), reverse=True)[:8],
            "top_profiles": top_profiles,
        })
    working.free()
    return sorted(components, key=lambda component: int(component["vertices"]), reverse=True)


def qc_current(asset_id: str) -> dict[str, object]:
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not mesh_objects:
        return {"asset": asset_id, "pass": False, "failure": "no mesh imported"}
    all_points = [
        obj.matrix_world @ vertex.co
        for obj in mesh_objects
        for vertex in obj.data.vertices
    ]
    overall_low = Vector((min(v.x for v in all_points), min(v.y for v in all_points), min(v.z for v in all_points)))
    overall_high = Vector((max(v.x for v in all_points), max(v.y for v in all_points), max(v.z for v in all_points)))
    extent = overall_high - overall_low
    height = max(extent.z, 1e-6)
    width = max(extent.x, 1e-6)
    top_zone_start = overall_low.z + height * 0.85

    components: list[dict[str, object]] = []
    vertex_total = 0
    polygon_total = 0
    for obj in mesh_objects:
        object_components = _mesh_components(obj, overall_low.z, height)
        for component in object_components:
            component["object"] = obj.name
        components.extend(object_components)
        vertex_total += len(obj.data.vertices)
        polygon_total += len(obj.data.polygons)
    components.sort(key=lambda component: int(component["vertices"]), reverse=True)
    welded_vertex_total = sum(int(component["vertices"]) for component in components)
    main = components[0]
    main_low = Vector(main["bbox_min"])
    main_high = Vector(main["bbox_max"])
    main_ratio = int(main["vertices"]) / max(welded_vertex_total, 1)

    # A tall staff or hood must not make a headless robe pass.  The highest 15%
    # of the complete model must contain a non-trivial vertex group belonging
    # to the same welded connected component as the torso.  Connectivity of
    # that component proves there is a mesh path from the head zone to torso.
    head_group = max(main.get("top_zone_groups", []), key=lambda group: int(group["vertices"]), default=None)
    head_group_vertices = int(head_group["vertices"]) if head_group else 0
    minimum_head_vertices = max(24, int(int(main["vertices"]) * 0.002))
    head_group_width = float(head_group["extent"][0]) if head_group else 0.0
    head_group_width_ratio = head_group_width / width
    # A broad shoulder/collar shelf can populate the top slice of a headless
    # robe.  A head candidate must therefore be compact relative to the whole
    # body silhouette, not merely non-empty.
    head_compact = head_group_width_ratio <= 0.42
    head_present = head_group_vertices >= minimum_head_vertices and head_compact
    torso_reached = main_low.z <= overall_low.z + height * 0.70 and main_high.z >= overall_low.z + height * 0.70
    head_connected_to_torso = head_present and torso_reached

    main_reaches_feet = main_low.z <= overall_low.z + height * 0.12
    main_reaches_head = main_high.z >= top_zone_start
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
        and head_present
        and head_connected_to_torso
        and feet_planted
    )
    failure_reasons: list[str] = []
    if len(mesh_objects) != 1:
        failure_reasons.append(f"expected one mesh object, got {len(mesh_objects)}")
    if main_ratio < 0.50:
        failure_reasons.append(f"main connected body only {main_ratio:.1%} of vertices")
    if not main_reaches_head:
        failure_reasons.append("largest body does not reach the highest 15% head zone")
    if head_group_vertices < minimum_head_vertices:
        failure_reasons.append(
            f"highest 15% has no head vertex group on main body "
            f"({head_group_vertices} < {minimum_head_vertices} vertices)"
        )
    if head_group_vertices >= minimum_head_vertices and not head_compact:
        failure_reasons.append(
            f"highest 15% group is too broad for a head ({head_group_width_ratio:.1%} of body width)"
        )
    if head_present and not head_connected_to_torso:
        failure_reasons.append("head-zone vertex group is not connected to torso")
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
        "head_zone_fraction": 0.15,
        "head_zone_min_z": round(top_zone_start, 5),
        "head_group_vertices": head_group_vertices,
        "minimum_head_vertices": minimum_head_vertices,
        "head_group_width_ratio": round(head_group_width_ratio, 4),
        "head_compact": head_compact,
        "head_present": head_present,
        "head_connected_to_torso": head_connected_to_torso,
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
