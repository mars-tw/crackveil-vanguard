"""Rig and render the ten Hyper3D Rodin heroes for cv art-r21 in Blender 5.1.

This file is executed inside Blender through the MCP ``execute_code`` command.
The physics/collider root remains in Godot; this armature is a visual production
rig only.  Every animation frame is a real bone pose.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


ROOT = Path(r"C:\Users\digimkt\Desktop\遊戲\rift-survivors")
FRAME_ROOT = ROOT / "export" / "art_r21_frames"
THREEVIEW_RAW = ROOT / "export" / "art_r21_threeview_raw"
RIGGED_ROOT = ROOT / "export" / "art_r21_rigged"
RIG_REPORT = ROOT / "docs" / "evidence" / "art_r21" / "rig_manifest.json"

HEROES = (
    ("captain", "hero_captain", "hero_captain.glb"),
    ("rift_sniper", "hero_rift_sniper", "hero_rift_sniper.glb"),
    ("void_weaver", "hero_void_weaver", "hero_void_weaver.glb"),
    ("arc_scout", "hero_arc_scout", "hero_arc_scout.glb"),
    ("echo_singer", "hero_echo_singer", "hero_echo_singer.glb"),
    ("ember_grenadier", "hero_ember_grenadier", "hero_ember_grenadier.glb"),
    ("line_mender", "hero_line_mender", "hero_line_mender.glb"),
    ("orbit_guard", "hero_orbit_guard", "hero_orbit_guard.glb"),
    ("pulse_artificer", "hero_pulse_artificer", "hero_pulse_artificer.glb"),
    ("rift_shepherd", "hero_shepherd", "hero_rift_shepherd.glb"),
)
ANIMATIONS = (("idle", 4), ("walk", 8), ("attack", 6), ("hurt", 3), ("death", 6))
BONE_NAMES = (
    "root", "pelvis", "spine", "chest", "neck", "head",
    "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R",
    "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R",
)


def clear_scene() -> None:
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)
    for datablocks in (bpy.data.materials, bpy.data.images):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def import_and_normalize(path: Path, runtime_id: str) -> tuple[bpy.types.Object, float, dict[str, object]]:
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in {path}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
    if len(meshes) > 1:
        bpy.ops.object.join()
        meshes = [bpy.context.object]
    mesh = meshes[0]
    mesh.name = runtime_id + "_mesh"
    mesh.data.name = runtime_id + "_mesh"
    low, high = bounds([mesh])
    offset = Vector((-(low.x + high.x) * 0.5, -(low.y + high.y) * 0.5, -low.z))
    mesh.location += offset
    bpy.context.view_layer.update()
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    low, high = bounds([mesh])
    height = high.z - low.z
    if height <= 0.01:
        raise RuntimeError(f"Invalid hero height for {runtime_id}: {height}")
    return mesh, height, {
        "source": str(path.relative_to(ROOT)).replace("\\", "/"),
        "vertices": len(mesh.data.vertices),
        "polygons": len(mesh.data.polygons),
        "bbox_extent": [round(value, 5) for value in high - low],
        "height": round(height, 5),
    }


def create_rig(height: float, runtime_id: str) -> bpy.types.Object:
    data = bpy.data.armatures.new(runtime_id + "_armature")
    rig = bpy.data.objects.new(runtime_id + "_rig", data)
    bpy.context.collection.objects.link(rig)
    rig.show_in_front = True
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name: str, head: tuple[float, float, float], tail: tuple[float, float, float], parent: str | None = None, connected: bool = False) -> None:
        item = data.edit_bones.new(name)
        item.head = Vector(head) * height
        item.tail = Vector(tail) * height
        if parent:
            item.parent = data.edit_bones[parent]
            item.use_connect = connected

    bone("root", (0, 0, 0.015), (0, 0, 0.43))
    bone("pelvis", (0, 0, 0.43), (0, 0, 0.53), "root", True)
    bone("spine", (0, 0, 0.53), (0, 0, 0.66), "pelvis", True)
    bone("chest", (0, 0, 0.66), (0, 0, 0.78), "spine", True)
    bone("neck", (0, 0, 0.78), (0, 0, 0.84), "chest", True)
    bone("head", (0, 0, 0.84), (0, 0, 0.98), "neck", True)
    for side, sign in (("L", 1.0), ("R", -1.0)):
        bone(f"upper_arm.{side}", (0.07 * sign, 0, 0.75), (0.255 * sign, 0, 0.68), "chest")
        bone(f"forearm.{side}", (0.255 * sign, 0, 0.68), (0.405 * sign, -0.005, 0.59), f"upper_arm.{side}", True)
        bone(f"hand.{side}", (0.405 * sign, -0.005, 0.59), (0.49 * sign, -0.015, 0.56), f"forearm.{side}", True)
        bone(f"thigh.{side}", (0.085 * sign, 0, 0.44), (0.09 * sign, 0, 0.245), "pelvis")
        bone(f"shin.{side}", (0.09 * sign, 0, 0.245), (0.085 * sign, 0, 0.075), f"thigh.{side}", True)
        bone(f"foot.{side}", (0.085 * sign, 0, 0.075), (0.085 * sign, -0.11, 0.035), f"shin.{side}", True)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def coverage(mesh: bpy.types.Object) -> tuple[float, int]:
    deform_indices = {group.index for group in mesh.vertex_groups if group.name in BONE_NAMES}
    weighted = sum(any(item.group in deform_indices and item.weight > 1e-5 for item in vertex.groups) for vertex in mesh.data.vertices)
    return weighted / max(len(mesh.data.vertices), 1), weighted


def point_segment_distance(point: Vector, start: Vector, end: Vector) -> float:
    delta = end - start
    if delta.length_squared < 1e-12:
        return (point - start).length
    t = max(0.0, min(1.0, (point - start).dot(delta) / delta.length_squared))
    return (point - (start + delta * t)).length


def manual_bind(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    mesh.vertex_groups.clear()
    deform_bones = [bone for bone in rig.data.bones if bone.name != "root"]
    groups = {bone.name: mesh.vertex_groups.new(name=bone.name) for bone in deform_bones}
    segments = [(bone.name, bone.head_local.copy(), bone.tail_local.copy()) for bone in deform_bones]
    for vertex in mesh.data.vertices:
        distances = sorted((point_segment_distance(vertex.co, start, end), name) for name, start, end in segments)
        first_distance, first_name = distances[0]
        second_distance, second_name = distances[1]
        if first_distance + second_distance < 1e-8:
            first_weight = 1.0
        else:
            first_weight = second_distance / (first_distance + second_distance)
        first_weight = max(0.72, min(1.0, first_weight))
        groups[first_name].add([vertex.index], first_weight, "REPLACE")
        groups[second_name].add([vertex.index], 1.0 - first_weight, "REPLACE")
    modifier = mesh.modifiers.get("R21 Armature") or mesh.modifiers.new("R21 Armature", "ARMATURE")
    modifier.object = rig
    mesh.parent = rig


def bind(mesh: bpy.types.Object, rig: bpy.types.Object) -> dict[str, object]:
    for modifier in list(mesh.modifiers):
        if modifier.type == "ARMATURE":
            mesh.modifiers.remove(modifier)
    mesh.vertex_groups.clear()
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    method = "automatic"
    error = ""
    try:
        bpy.ops.object.parent_set(type="ARMATURE_AUTO", keep_transform=True)
        ratio, weighted = coverage(mesh)
        if ratio < 0.985:
            raise RuntimeError(f"automatic coverage {ratio:.2%}")
    except Exception as exception:
        error = str(exception)
        method = "manual_nearest_bone_segments"
        manual_bind(mesh, rig)
        ratio, weighted = coverage(mesh)
    return {
        "method": method,
        "automatic_error": error,
        "coverage": round(ratio, 5),
        "weighted_vertices": weighted,
        "bone_count": len(rig.data.bones),
        "bones": list(BONE_NAMES),
    }


def reset_pose(rig: bpy.types.Object) -> None:
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.rotation_quaternion.identity()
        pose_bone.location = (0, 0, 0)
        pose_bone.scale = (1, 1, 1)


def rotate_global(rig: bpy.types.Object, name: str, axis: tuple[float, float, float], degrees: float) -> None:
    pose_bone = rig.pose.bones[name]
    rest = pose_bone.bone.matrix_local.to_quaternion()
    local_axis = rest.inverted() @ Vector(axis)
    pose_bone.rotation_quaternion = Quaternion(local_axis, math.radians(degrees)) @ pose_bone.rotation_quaternion


def set_pose(rig: bpy.types.Object, animation: str, frame: int, height: float) -> dict[str, float]:
    reset_pose(rig)
    audit: dict[str, float] = {}

    def turn(name: str, axis: tuple[float, float, float], degrees: float) -> None:
        if abs(degrees) > 0.001:
            rotate_global(rig, name, axis, degrees)
            audit[name] = round(degrees, 3)

    if animation == "idle":
        breath = math.sin(frame * math.tau / 4.0)
        turn("chest", (1, 0, 0), 2.8 * breath)
        turn("upper_arm.L", (0, 0, 1), 2.2 * breath)
        turn("upper_arm.R", (0, 0, 1), -2.2 * breath)
        turn("head", (0, 1, 0), 1.8 * breath)
    elif animation == "walk":
        phase = frame * math.tau / 8.0
        stride = math.sin(phase)
        lift_l = max(0.0, stride)
        lift_r = max(0.0, -stride)
        turn("thigh.L", (1, 0, 0), 34 * stride)
        turn("thigh.R", (1, 0, 0), -34 * stride)
        turn("thigh.L", (0, 1, 0), 10 * stride)
        turn("thigh.R", (0, 1, 0), -10 * stride)
        turn("shin.L", (1, 0, 0), -30 * lift_l)
        turn("shin.R", (1, 0, 0), -30 * lift_r)
        turn("upper_arm.L", (1, 0, 0), -26 * stride)
        turn("upper_arm.R", (1, 0, 0), 26 * stride)
        turn("forearm.L", (1, 0, 0), -12 * abs(stride))
        turn("forearm.R", (1, 0, 0), -12 * abs(stride))
        turn("chest", (0, 0, 1), -5 * stride)
    elif animation == "attack":
        anticipation = ((-8, -38, 28), (-14, -58, 45))
        active = ((16, 72, -52), (12, 88, -65))
        recovery = ((7, 38, -28), (1, 9, -7))
        root_angle, arm_angle, forearm_angle = (anticipation + active + recovery)[frame]
        turn("root", (0, 1, 0), root_angle)
        turn("spine", (0, 1, 0), root_angle * 0.55)
        turn("upper_arm.L", (0, 1, 0), arm_angle)
        turn("upper_arm.R", (0, 1, 0), arm_angle * 0.86)
        turn("upper_arm.L", (0, 0, 1), -arm_angle * 0.22)
        turn("upper_arm.R", (0, 0, 1), arm_angle * 0.22)
        turn("forearm.L", (0, 1, 0), forearm_angle)
        turn("forearm.R", (0, 1, 0), forearm_angle * 0.9)
        turn("thigh.L", (0, 1, 0), -root_angle * 0.72)
        turn("thigh.R", (0, 1, 0), root_angle * 0.42)
    elif animation == "hurt":
        recoil = (12.0, 25.0, 15.0)[frame]
        turn("root", (1, 0, 0), -recoil * 0.35)
        turn("spine", (1, 0, 0), -recoil)
        turn("chest", (0, 1, 0), -recoil * 0.55)
        turn("head", (1, 0, 0), recoil * 0.45)
        turn("upper_arm.L", (0, 1, 0), -recoil * 1.15)
        turn("upper_arm.R", (0, 1, 0), recoil * 1.15)
    elif animation == "death":
        angle = (0.0, 16.0, 38.0, 62.0, 79.0, 88.0)[frame]
        # With the three-quarter camera this local/global conversion falls in
        # the screen plane when authored around world X; world Y foreshortens
        # the body into camera depth on the final collapse frames.
        turn("root", (1, 0, 0), angle)
        turn("spine", (1, 0, 0), -min(angle, 30) * 0.35)
        turn("head", (0, 1, 0), -min(angle, 45) * 0.28)
        turn("upper_arm.L", (0, 0, 1), min(angle, 58) * 0.55)
        turn("upper_arm.R", (0, 0, 1), -min(angle, 58) * 0.65)
        turn("thigh.L", (1, 0, 0), min(angle, 48) * 0.50)
        turn("thigh.R", (1, 0, 0), -min(angle, 48) * 0.32)
        rig.pose.bones["root"].location.x = -height * 0.0025 * frame * frame
        audit["root_translate_x"] = round(rig.pose.bones["root"].location.x, 5)
    bpy.context.view_layer.update()
    return audit


def look_at(camera: bpy.types.Object, target: Vector) -> None:
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()


def deformed_bounds(mesh: bpy.types.Object) -> tuple[Vector, Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh.evaluated_get(depsgraph)
    evaluated_mesh = evaluated.to_mesh()
    try:
        points = [evaluated.matrix_world @ vertex.co for vertex in evaluated_mesh.vertices]
        low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
        high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
        return low, high
    finally:
        evaluated.to_mesh_clear()


def frame_camera(camera: bpy.types.Object, mesh: bpy.types.Object, height: float, animation: str) -> None:
    if animation == "death":
        low, high = deformed_bounds(mesh)
        target = (low + high) * 0.5
        camera.data.ortho_scale = height * 1.45
    else:
        target = Vector((0, 0, height * 0.48))
        camera.data.ortho_scale = height * 1.30
    camera.location = target + Vector((height * 1.55, -height * 3.6, height * 0.70))
    look_at(camera, target)


def configure_scene(height: float) -> tuple[bpy.types.Object, list[bpy.types.Object]]:
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.resolution_percentage = 100
    scene.render.filter_size = 0.65
    scene.view_settings.view_transform = "AgX"
    for look in ("AgX - Medium High Contrast", "AgX - Medium High Contrast", "Medium High Contrast", "None"):
        try:
            scene.view_settings.look = look
            break
        except Exception:
            continue
    scene.view_settings.exposure = 1.0
    scene.view_settings.gamma = 1.0
    world = bpy.data.worlds.get("R21World") or bpy.data.worlds.new("R21World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.025, 0.045, 0.075, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.16
    scene.world = world

    camera_data = bpy.data.cameras.new("R21Camera")
    camera = bpy.data.objects.new("R21Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = height * 1.30
    camera.location = (height * 1.55, -height * 3.6, height * 1.18)
    look_at(camera, Vector((0, 0, height * 0.48)))
    scene.camera = camera

    lights: list[bpy.types.Object] = []
    for name, location, color, energy, size in (
        ("R21WarmKey", (-2.4, -3.5, 4.2), (1.0, 0.67, 0.40), 520.0, 3.2),
        ("R21CoolFill", (3.2, -2.0, 2.0), (0.28, 0.58, 1.0), 270.0, 4.2),
        ("R21CyanRim", (1.2, 3.2, 3.5), (0.20, 0.72, 1.0), 430.0, 2.4),
    ):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.color = color
        data.shape = "DISK"
        data.size = size
        obj = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(obj)
        obj.location = Vector(location) * height
        obj.rotation_euler = (Vector((0, 0, height * 0.5)) - obj.location).to_track_quat("-Z", "Y").to_euler()
        lights.append(obj)
    return camera, lights


def render_animation(runtime_id: str, mesh: bpy.types.Object, rig: bpy.types.Object, height: float, camera: bpy.types.Object) -> dict[str, object]:
    scene = bpy.context.scene
    scene.render.resolution_x = 128
    scene.render.resolution_y = 128
    scene.render.film_transparent = True
    frame_camera(camera, mesh, height, "idle")
    output_dir = FRAME_ROOT / runtime_id
    output_dir.mkdir(parents=True, exist_ok=True)
    pose_audit: dict[str, object] = {}
    linear_index = 0
    for animation, frame_count in ANIMATIONS:
        pose_audit[animation] = []
        for frame in range(frame_count):
            audit = set_pose(rig, animation, frame, height)
            frame_camera(camera, mesh, height, animation)
            output = output_dir / f"{linear_index:02d}_{animation}_{frame:02d}.png"
            scene.render.filepath = str(output)
            bpy.ops.render.render(write_still=True)
            pose_audit[animation].append(audit)
            linear_index += 1
    reset_pose(rig)
    return {"frames": linear_index, "pose_audit": pose_audit}


def render_threeviews(runtime_id: str, rig: bpy.types.Object, mesh: bpy.types.Object, height: float, camera: bpy.types.Object) -> list[str]:
    reset_pose(rig)
    scene = bpy.context.scene
    scene.render.resolution_x = 320
    scene.render.resolution_y = 320
    scene.render.film_transparent = False
    low, high = bounds([mesh])
    span = max(high.x - low.x, high.y - low.y, high.z - low.z)
    camera.data.ortho_scale = span * 1.18
    target = Vector((0, 0, height * 0.50))
    output_dir = THREEVIEW_RAW / runtime_id
    output_dir.mkdir(parents=True, exist_ok=True)
    outputs: list[str] = []
    for label, location in (
        ("front", (0, -height * 4.0, height * 0.52)),
        ("side", (-height * 4.0, 0, height * 0.52)),
        ("back", (0, height * 4.0, height * 0.52)),
    ):
        camera.location = Vector(location)
        look_at(camera, target)
        output = output_dir / f"{label}.png"
        scene.render.filepath = str(output)
        bpy.ops.render.render(write_still=True)
        outputs.append(str(output.relative_to(ROOT)).replace("\\", "/"))
    scene.render.film_transparent = True
    return outputs


def export_rigged(runtime_id: str, mesh: bpy.types.Object, rig: bpy.types.Object) -> Path:
    RIGGED_ROOT.mkdir(parents=True, exist_ok=True)
    output = RIGGED_ROOT / f"{runtime_id}_rigged.glb"
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True, export_animations=False)
    return output


def render_current_pose_test(runtime_id: str, animation: str, frame: int, output_name: str) -> None:
    mesh = bpy.data.objects[runtime_id + "_mesh"]
    rig = bpy.data.objects[runtime_id + "_rig"]
    camera = bpy.data.objects["R21Camera"]
    low, high = bounds([mesh])
    height = high.z - low.z
    set_pose(rig, animation, frame, height)
    frame_camera(camera, mesh, height, animation)
    scene = bpy.context.scene
    scene.render.resolution_x = 128
    scene.render.resolution_y = 128
    scene.render.film_transparent = True
    scene.render.filepath = str(ROOT / "export" / output_name)
    bpy.ops.render.render(write_still=True)
    print(f"R21_POSE_TEST {animation}_{frame} {scene.render.filepath}")


def build_all() -> None:
    FRAME_ROOT.mkdir(parents=True, exist_ok=True)
    THREEVIEW_RAW.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    for art_id, runtime_id, filename in HEROES:
        print(f"R21_RIG_START hero={runtime_id}", flush=True)
        clear_scene()
        mesh, height, record = import_and_normalize(ROOT / "assets" / "rodin" / filename, runtime_id)
        rig = create_rig(height, runtime_id)
        record.update({"art_id": art_id, "runtime_id": runtime_id})
        record["binding"] = bind(mesh, rig)
        camera, _lights = configure_scene(height)
        record.update(render_animation(runtime_id, mesh, rig, height, camera))
        record["threeviews"] = render_threeviews(runtime_id, rig, mesh, height, camera)
        rigged = export_rigged(runtime_id, mesh, rig)
        record["rigged_glb"] = str(rigged.relative_to(ROOT)).replace("\\", "/")
        record["rigged_bytes"] = rigged.stat().st_size
        records.append(record)
        RIG_REPORT.parent.mkdir(parents=True, exist_ok=True)
        RIG_REPORT.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(
            f"R21_RIG_PASS hero={runtime_id} method={record['binding']['method']} "
            f"coverage={record['binding']['coverage']:.2%} frames={record['frames']}",
            flush=True,
        )
    print(f"R21_RIG_BATCH_PASS heroes={len(records)} frames={sum(r['frames'] for r in records)}", flush=True)


def rerender_all_from_rigged() -> None:
    rendered = 0
    for _art_id, runtime_id, _filename in HEROES:
        clear_scene()
        bpy.ops.import_scene.gltf(filepath=str(RIGGED_ROOT / f"{runtime_id}_rigged.glb"))
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
        if not meshes or len(rigs) != 1:
            raise RuntimeError(f"{runtime_id}: rigged import expected mesh/armature, got {len(meshes)}/{len(rigs)}")
        # Blender's glTF armature export can add a tiny Icosphere helper for a
        # custom bone shape.  The production body is unambiguously the largest
        # mesh; remove helpers before rendering.
        mesh, rig = max(meshes, key=lambda obj: len(obj.data.vertices)), rigs[0]
        for helper in meshes:
            if helper != mesh:
                bpy.data.objects.remove(helper, do_unlink=True)
        mesh.name = runtime_id + "_mesh"
        rig.name = runtime_id + "_rig"
        low, high = bounds([mesh])
        height = high.z - low.z
        camera, _lights = configure_scene(height)
        result = render_animation(runtime_id, mesh, rig, height, camera)
        rendered += int(result["frames"])
        print(f"R21_RERENDER_PASS hero={runtime_id} frames={result['frames']}", flush=True)
    print(f"R21_RERENDER_BATCH_PASS heroes={len(HEROES)} frames={rendered}", flush=True)


if __name__ == "__main__":
    build_all()
