"""Blender 5.1 headless art builder for Crackveil Vanguard R20.1.

Every atlas frame is assembled from separately articulated body parts.  The
Godot physics root and collider never enter this Blender scene.  Run with:

    blender --background --python tools/generate_true_animation_atlas.py

The runtime mirrors the right-facing render for left-facing movement.  The
shared-atlas contract is fixed at idle4/walk8/attack6/hurt3/death6 and attack
frame 2 remains the active impact pose.  R20 keeps that contract while replacing
the R16 blockout forms with 3k-6k-triangle faceted characters, surface-specific
materials, warm-light/cool-shadow vertex ramps, and a selective silhouette pass.
"""

from __future__ import annotations

import math
import shutil
import subprocess
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "sprites" / "true_character_atlas.png"
CELL_PIXELS = 64
COLUMNS = 8
CELL_WORLD = 3.0

ANIMATIONS = (
    ("idle", 4),
    ("walk", 8),
    ("attack", 6),
    ("hurt", 3),
    ("death", 6),
)
FRAMES_PER_CHARACTER = sum(frame_count for _animation, frame_count in ANIMATIONS)

# dark / body / secondary / highlight are the four authored palette slots.
# All three main swatches keep HSV value in the 0.35-0.85 R16 albedo band.
CHARACTERS = (
    {"id": "hero_captain", "kind": "hero", "style": "captain", "weapon": "captain_blade", "palette": ((0.08, 0.25, 0.42, 1), (0.12, 0.58, 0.72, 1), (0.56, 0.76, 0.82, 1), (0.85, 0.48, 0.12, 1)), "skin": (0.78, 0.55, 0.43, 1), "iris": (0.12, 0.68, 0.85, 1), "size": 1.00},
    {"id": "hero_rift_sniper", "kind": "hero", "style": "sniper", "weapon": "rail_rifle", "palette": ((0.16, 0.24, 0.40, 1), (0.18, 0.55, 0.58, 1), (0.66, 0.76, 0.78, 1), (0.72, 0.85, 0.22, 1)), "skin": (0.76, 0.52, 0.40, 1), "iris": (0.68, 0.85, 0.22, 1), "size": 0.98},
    {"id": "hero_void_weaver", "kind": "hero", "style": "weaver", "weapon": "void_staff", "palette": ((0.24, 0.16, 0.42, 1), (0.48, 0.26, 0.65, 1), (0.72, 0.52, 0.78, 1), (0.20, 0.82, 0.85, 1)), "skin": (0.71, 0.48, 0.51, 1), "iris": (0.20, 0.82, 0.85, 1), "size": 0.97},
    {"id": "hero_arc_scout", "kind": "hero", "style": "arc_scout", "weapon": "arc_spear", "palette": ((0.10, 0.35, 0.31, 1), (0.14, 0.64, 0.50, 1), (0.54, 0.80, 0.68, 1), (0.85, 0.38, 0.12, 1)), "skin": (0.77, 0.54, 0.39, 1), "iris": (0.85, 0.38, 0.12, 1), "size": 0.94},
    {"id": "hero_echo_singer", "kind": "hero", "style": "singer", "weapon": "tuning_staff", "palette": ((0.36, 0.22, 0.40, 1), (0.64, 0.40, 0.62, 1), (0.80, 0.67, 0.78, 1), (0.85, 0.73, 0.24, 1)), "skin": (0.79, 0.57, 0.46, 1), "iris": (0.85, 0.73, 0.24, 1), "size": 0.98},
    {"id": "hero_ember_grenadier", "kind": "hero", "style": "grenadier", "weapon": "grenade_launcher", "palette": ((0.40, 0.20, 0.10, 1), (0.68, 0.30, 0.12, 1), (0.82, 0.60, 0.32, 1), (0.85, 0.82, 0.36, 1)), "skin": (0.77, 0.50, 0.35, 1), "iris": (0.85, 0.82, 0.36, 1), "size": 1.02},
    {"id": "hero_line_mender", "kind": "hero", "style": "mender", "weapon": "needle_staff", "palette": ((0.18, 0.34, 0.40, 1), (0.30, 0.64, 0.62, 1), (0.72, 0.80, 0.70, 1), (0.85, 0.64, 0.20, 1)), "skin": (0.75, 0.52, 0.43, 1), "iris": (0.85, 0.64, 0.20, 1), "size": 0.96},
    {"id": "hero_orbit_guard", "kind": "hero", "style": "orbit_guard", "weapon": "orbit_shield", "palette": ((0.24, 0.20, 0.40, 1), (0.42, 0.34, 0.65, 1), (0.72, 0.64, 0.82, 1), (0.22, 0.82, 0.85, 1)), "skin": (0.73, 0.50, 0.40, 1), "iris": (0.22, 0.82, 0.85, 1), "size": 1.04},
    {"id": "hero_pulse_artificer", "kind": "hero", "style": "artificer", "weapon": "pulse_cannon", "palette": ((0.17, 0.31, 0.42, 1), (0.23, 0.58, 0.68, 1), (0.62, 0.76, 0.82, 1), (0.85, 0.38, 0.32, 1)), "skin": (0.78, 0.55, 0.39, 1), "iris": (0.85, 0.38, 0.32, 1), "size": 1.00},
    {"id": "hero_shepherd", "kind": "hero", "style": "shepherd", "weapon": "rift_lantern", "palette": ((0.22, 0.18, 0.42, 1), (0.35, 0.60, 0.65, 1), (0.65, 0.76, 0.82, 1), (0.78, 0.85, 0.85, 1)), "skin": (0.72, 0.49, 0.44, 1), "iris": (0.62, 0.82, 0.85, 1), "size": 0.98},
    {"id": "enemy_grunt", "kind": "enemy", "style": "grunt", "weapon": "club", "palette": ((0.38, 0.12, 0.18, 1), (0.62, 0.20, 0.26, 1), (0.72, 0.38, 0.28, 1), (0.85, 0.52, 0.18, 1)), "skin": (0.54, 0.34, 0.38, 1), "iris": (0.85, 0.52, 0.18, 1), "size": 0.94},
    {"id": "enemy_fast", "kind": "enemy", "style": "fast", "weapon": "claw", "palette": ((0.30, 0.12, 0.40, 1), (0.58, 0.18, 0.68, 1), (0.72, 0.36, 0.74, 1), (0.22, 0.82, 0.85, 1)), "skin": (0.48, 0.28, 0.51, 1), "iris": (0.22, 0.82, 0.85, 1), "size": 0.88},
    {"id": "enemy_tank", "kind": "enemy", "style": "tank", "weapon": "hammer", "palette": ((0.40, 0.18, 0.10, 1), (0.65, 0.28, 0.12, 1), (0.76, 0.48, 0.24, 1), (0.85, 0.72, 0.18, 1)), "skin": (0.55, 0.36, 0.29, 1), "iris": (0.85, 0.72, 0.18, 1), "size": 1.10},
    {"id": "enemy_elite_field", "kind": "enemy", "style": "field", "weapon": "staff", "palette": ((0.28, 0.13, 0.40, 1), (0.50, 0.24, 0.70, 1), (0.68, 0.46, 0.78, 1), (0.24, 0.85, 0.70, 1)), "skin": (0.48, 0.31, 0.55, 1), "iris": (0.24, 0.85, 0.70, 1), "size": 1.02},
    {"id": "enemy_elite_split", "kind": "enemy", "style": "split", "weapon": "axes", "palette": ((0.40, 0.10, 0.20, 1), (0.70, 0.18, 0.38, 1), (0.80, 0.42, 0.48, 1), (0.85, 0.68, 0.16, 1)), "skin": (0.56, 0.29, 0.38, 1), "iris": (0.85, 0.68, 0.16, 1), "size": 1.00},
    {"id": "enemy_elite_swift", "kind": "enemy", "style": "swift", "weapon": "claw", "palette": ((0.10, 0.34, 0.40, 1), (0.14, 0.64, 0.72, 1), (0.42, 0.76, 0.80, 1), (0.78, 0.85, 0.85, 1)), "skin": (0.32, 0.51, 0.57, 1), "iris": (0.78, 0.85, 0.85, 1), "size": 0.92},
    {"id": "enemy_boss", "kind": "enemy", "style": "boss", "weapon": "greatblade", "palette": ((0.34, 0.14, 0.44, 1), (0.64, 0.20, 0.75, 1), (0.82, 0.40, 0.72, 1), (0.85, 0.22, 0.52, 1)), "skin": (0.50, 0.30, 0.56, 1), "iris": (0.85, 0.22, 0.52, 1), "size": 1.14},
)

MESH_VERTICES: list[tuple[float, float, float]] = []
MESH_FACES: list[tuple[int, ...]] = []
MESH_FACE_MATERIALS: list[int] = []
MESH_VERTEX_SHADES: list[tuple[float, float, float, float]] = []
MATERIALS: list[bpy.types.Material] = []
MATERIAL_INDEX: dict[str, int] = {}
CHARACTER_TRIANGLES: dict[str, int] = {}


def reset_geometry_buffers() -> None:
    """Clear module-owned buffers so evidence renders can reuse this factory."""
    MESH_VERTICES.clear()
    MESH_FACES.clear()
    MESH_FACE_MATERIALS.clear()
    MESH_VERTEX_SHADES.clear()
    MATERIALS.clear()
    MATERIAL_INDEX.clear()
    CHARACTER_TRIANGLES.clear()

PHI = (1.0 + math.sqrt(5.0)) * 0.5
ICO_VERTICES = tuple(
    Vector(vertex).normalized()
    for vertex in (
        (-1, PHI, 0), (1, PHI, 0), (-1, -PHI, 0), (1, -PHI, 0),
        (0, -1, PHI), (0, 1, PHI), (0, -1, -PHI), (0, 1, -PHI),
        (PHI, 0, -1), (PHI, 0, 1), (-PHI, 0, -1), (-PHI, 0, 1),
    )
)
ICO_FACES = (
    (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
    (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
    (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
    (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1),
)


def subdivide_icosphere(levels: int = 2) -> tuple[tuple[Vector, ...], tuple[tuple[int, int, int], ...]]:
    """Return a deterministic faceted sphere with a production-ready outline.

    Two subdivision levels create 320 triangles.  Large enough to stop heads,
    eyes, shoulders, and curved props reading as dice at 64px, while retaining
    the planar facets expected from the stylized low-poly direction.
    """
    vertices = [Vector(vertex) for vertex in ICO_VERTICES]
    faces = [tuple(face) for face in ICO_FACES]
    for _level in range(levels):
        midpoint_cache: dict[tuple[int, int], int] = {}

        def midpoint(first: int, second: int) -> int:
            edge = (min(first, second), max(first, second))
            if edge not in midpoint_cache:
                midpoint_cache[edge] = len(vertices)
                vertices.append(((vertices[first] + vertices[second]) * 0.5).normalized())
            return midpoint_cache[edge]

        refined: list[tuple[int, int, int]] = []
        for first, second, third in faces:
            ab = midpoint(first, second)
            bc = midpoint(second, third)
            ca = midpoint(third, first)
            refined.extend(((first, ab, ca), (second, bc, ab), (third, ca, bc), (ab, bc, ca)))
        faces = refined
    return tuple(vertices), tuple(faces)


MID_ICO_VERTICES, MID_ICO_FACES = subdivide_icosphere(1)
DETAIL_ICO_VERTICES, DETAIL_ICO_FACES = subdivide_icosphere(2)
CUBE_VERTICES = tuple(Vector(v) for v in (
    (-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5),
    (-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5),
))
CUBE_FACES = ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7))


SURFACE_RESPONSE = {
    "skin": (0.66, 0.0),
    "cloth": (0.90, 0.0),
    "leather": (0.72, 0.0),
    "hair": (0.84, 0.0),
    "metal": (0.30, 0.76),
    "lens": (0.24, 0.18),
}

# Standard preserves the authored hue separation, while these modest,
# surface-specific boosts keep pale cloth, skin, and metal readable after the
# final 64px downsample.  They affect only baked vertex color, never geometry.
SURFACE_SATURATION_RESPONSE = {
    "skin": 1.12,
    "cloth": 1.28,
    "leather": 1.32,
    "hair": 1.28,
    "metal": 1.25,
    "lens": 1.18,
}


def _boost_saturation(
    color: tuple[float, float, float, float],
    factor: float,
) -> tuple[float, float, float, float]:
    """Increase linear-RGB chroma around luminance without changing value."""
    red, green, blue, alpha = color
    luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    return (
        max(0.0, min(1.0, luma + (red - luma) * factor)),
        max(0.0, min(1.0, luma + (green - luma) * factor)),
        max(0.0, min(1.0, luma + (blue - luma) * factor)),
        alpha,
    )


def _gradient_swatches(color: tuple[float, float, float, float]) -> tuple[tuple[float, ...], tuple[float, ...]]:
    """Build warm top and cool lower swatches without crushing value range."""
    red, green, blue, alpha = color
    top = (
        min(1.0, red * 1.08 + 0.035),
        min(1.0, green * 1.05 + 0.018),
        min(1.0, blue * 1.00 + 0.006),
        alpha,
    )
    bottom = (
        min(1.0, red * 0.58 + 0.015),
        min(1.0, green * 0.64 + 0.025),
        min(1.0, blue * 0.76 + 0.060),
        alpha,
    )
    return top, bottom


def material(
    name: str,
    color: tuple[float, float, float, float],
    glow: float = 0.0,
    surface: str = "cloth",
) -> bpy.types.Material:
    """Create a surface-specific AO + authored hue-shifted ramp material.

    The ``cv_gradient`` point color is generated for every primitive, so the
    volume ramp is effectively baked into the production mesh and survives the
    sprite render without relying on a Godot runtime shader.
    """
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = color
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        nodes.clear()
        output = nodes.new("ShaderNodeOutputMaterial")
        principled = nodes.new("ShaderNodeBsdfPrincipled")
        vertex = nodes.new("ShaderNodeVertexColor")
        vertex.layer_name = "cv_gradient"
        shaded_output = vertex.outputs["Color"]
        try:
            ao = nodes.new("ShaderNodeAmbientOcclusion")
            ao.inputs["Distance"].default_value = 0.36
            ao.samples = 12
            ao_mix = nodes.new("ShaderNodeMixRGB")
            ao_mix.blend_type = "MULTIPLY"
            ao_mix.inputs[0].default_value = 0.24
            links.new(shaded_output, ao_mix.inputs[1])
            links.new(ao.outputs["Color"], ao_mix.inputs[2])
            shaded_output = ao_mix.outputs[0]
        except Exception:
            pass
        links.new(shaded_output, principled.inputs["Base Color"])
        roughness, metallic = SURFACE_RESPONSE.get(surface, SURFACE_RESPONSE["cloth"])
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = metallic
        emission_color = principled.inputs.get("Emission Color") or principled.inputs.get("Emission")
        emission_strength = principled.inputs.get("Emission Strength")
        if glow > 0.0 and emission_color is not None:
            links.new(shaded_output, emission_color)
            if emission_strength is not None:
                emission_strength.default_value = glow
        links.new(principled.outputs["BSDF"], output.inputs["Surface"])
        top, bottom = _gradient_swatches(color)
        mat["cv_surface"] = surface
        mat["cv_gradient_top"] = top
        mat["cv_gradient_bottom"] = bottom
        saturation_boost = SURFACE_SATURATION_RESPONSE.get(surface, 1.0)
        # This mint secondary is intentionally pale in the R20 model.  At
        # 64px it was the only large color block still falling below S=0.15.
        if name.startswith("hero_line_mender_secondary"):
            saturation_boost *= 1.75
        mat["cv_saturation_boost"] = saturation_boost
    if name not in MATERIAL_INDEX:
        MATERIAL_INDEX[name] = len(MATERIALS)
        MATERIALS.append(mat)
    return mat


def append_geometry(vertices: tuple[Vector, ...] | list[Vector], faces: tuple[tuple[int, ...], ...] | list[tuple[int, ...]], mat: bpy.types.Material) -> None:
    offset = len(MESH_VERTICES)
    MESH_VERTICES.extend((vertex.x, vertex.y, vertex.z) for vertex in vertices)
    z_min = min(vertex.z for vertex in vertices)
    z_max = max(vertex.z for vertex in vertices)
    z_span = max(z_max - z_min, 0.001)
    top = tuple(mat["cv_gradient_top"])
    bottom = tuple(mat["cv_gradient_bottom"])
    for vertex in vertices:
        factor = (vertex.z - z_min) / z_span
        # Keep both ends inside the authored mid-tone range so outline and
        # highlight remain the only extreme values after display conversion.
        factor = 0.10 + factor * 0.90
        shade = tuple(bottom[channel] * (1.0 - factor) + top[channel] * factor for channel in range(4))
        shade = _boost_saturation(shade, float(mat.get("cv_saturation_boost", 1.0)))
        MESH_VERTEX_SHADES.append(shade)
    material_index = MATERIAL_INDEX[mat.name]
    for face in faces:
        MESH_FACES.append(tuple(offset + index for index in face))
        MESH_FACE_MATERIALS.append(material_index)


def sphere(
    _name: str,
    position: Vector,
    scale: tuple[float, float, float],
    mat: bpy.types.Material,
    detail: int = 2,
) -> None:
    if detail >= 2:
        source_vertices, source_faces = DETAIL_ICO_VERTICES, DETAIL_ICO_FACES
    elif detail == 1:
        source_vertices, source_faces = MID_ICO_VERTICES, MID_ICO_FACES
    else:
        source_vertices, source_faces = ICO_VERTICES, ICO_FACES
    vertices = tuple(position + Vector((vertex.x * scale[0], vertex.y * scale[1], vertex.z * scale[2])) for vertex in source_vertices)
    append_geometry(vertices, source_faces, mat)


def box(_name: str, position: Vector, scale: tuple[float, float, float], mat: bpy.types.Material, angle: float = 0.0) -> None:
    rotation = Matrix.Rotation(angle, 4, "Y")
    vertices = tuple(position + rotation @ Vector((vertex.x * scale[0], vertex.y * scale[1], vertex.z * scale[2])) for vertex in CUBE_VERTICES)
    append_geometry(vertices, CUBE_FACES, mat)


def prism(_name: str, points: list[Vector], depth: float, mat: bpy.types.Material) -> None:
    """Extrude an authored x/z silhouette polygon along camera depth."""
    half = depth * 0.5
    vertices = [point + Vector((0.0, -half, 0.0)) for point in points]
    vertices.extend(point + Vector((0.0, half, 0.0)) for point in points)
    count = len(points)
    faces: list[tuple[int, ...]] = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    append_geometry(vertices, faces, mat)


def bone(_name: str, start: Vector, end: Vector, radius: float, mat: bpy.types.Material) -> None:
    tapered_bone(_name, start, end, radius, radius * 0.82, mat)


def tapered_bone(
    _name: str,
    start: Vector,
    end: Vector,
    start_radius: float,
    end_radius: float,
    mat: bpy.types.Material,
) -> None:
    """Build a ten-sided tapered limb/prop with a clean faceted silhouette."""
    delta = end - start
    midpoint = (start + end) * 0.5
    depth = max(delta.length, 0.01)
    rotation = delta.to_track_quat("Z", "Y")
    vertices: list[Vector] = []
    sides = 10
    for z, radius in ((-depth * 0.5, start_radius), (depth * 0.5, end_radius)):
        for index in range(sides):
            angle = math.tau * index / sides
            local = Vector((math.cos(angle) * radius, math.sin(angle) * radius, z))
            vertices.append(midpoint + rotation @ local)
    faces: list[tuple[int, ...]] = []
    for index in range(sides):
        next_index = (index + 1) % sides
        faces.append((index, next_index, sides + next_index, sides + index))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(range(sides, sides * 2)))
    append_geometry(vertices, faces, mat)


def rotate_point(point: Vector, pivot: Vector, angle: float) -> Vector:
    dx = point.x - pivot.x
    dz = point.z - pivot.z
    return Vector((pivot.x + dx * math.cos(angle) + dz * math.sin(angle), point.y, pivot.z - dx * math.sin(angle) + dz * math.cos(angle)))


def pose(animation: str, frame: int, kind: str, weapon: str) -> dict[str, Vector | float]:
    hip = Vector((0.0, 0.0, -0.14))
    chest = Vector((0.02, 0.0, 0.50))
    head = Vector((0.07, -0.01, 1.11))
    shoulder_back = Vector((-0.30, 0.13, 0.62))
    shoulder_front = Vector((0.34, -0.16, 0.63))
    knee_back = Vector((-0.17, 0.12, -0.55))
    knee_front = Vector((0.19, -0.15, -0.55))
    foot_back = Vector((-0.20, 0.12, -1.04))
    foot_front = Vector((0.30, -0.16, -1.04))
    elbow_back = Vector((-0.43, 0.12, 0.25))
    hand_back = Vector((-0.25, 0.12, -0.02))
    elbow_front = Vector((0.49, -0.18, 0.26))
    hand_front = Vector((0.54, -0.20, -0.02))
    weapon_tip = Vector((0.70, -0.24, -0.30))

    if animation == "idle":
        breath = math.sin(frame * math.tau / 4.0)
        chest.z += breath * 0.035
        head.z += breath * 0.025
        elbow_front.x += breath * 0.05
        hand_front.z -= breath * 0.045
        elbow_back.x -= breath * 0.035
    elif animation == "walk":
        phase = frame * math.tau / 8.0
        stride = math.sin(phase)
        opposite = -stride
        lift_front = max(0.0, math.sin(phase)) * 0.20
        lift_back = max(0.0, math.sin(phase + math.pi)) * 0.20
        foot_front.x += stride * 0.48
        foot_front.z += lift_front
        knee_front.x += stride * 0.25 + 0.10 * (1.0 - abs(stride))
        knee_front.z += lift_front * 0.55
        foot_back.x += opposite * 0.48
        foot_back.z += lift_back
        knee_back.x += opposite * 0.25 + 0.10 * (1.0 - abs(opposite))
        knee_back.z += lift_back * 0.55
        elbow_front.x += opposite * 0.34
        hand_front.x += opposite * 0.52
        hand_front.z += abs(opposite) * 0.08
        elbow_back.x += stride * 0.34
        hand_back.x += stride * 0.50
        hand_back.z += abs(stride) * 0.08
        weapon_tip = hand_front + Vector((0.22 + opposite * 0.15, -0.04, -0.34))
    elif animation == "attack":
        # Two deep anticipation frames, active impact locked to frame 2, then a
        # committed follow-through and two recovery poses.
        attack_poses = (
            ((-0.58, 1.00), (-0.78, 0.88), (-1.05, 1.24), -0.18, -0.15),
            ((-0.68, 1.16), (-0.88, 1.04), (-1.18, 1.34), -0.25, -0.22),
            ((0.74, 0.64), (0.98, 0.42), (1.30, 0.06), 0.24, 0.34),
            ((0.78, 0.30), (0.98, 0.08), (1.12, -0.52), 0.18, 0.30),
            ((0.48, 0.46), (0.62, 0.18), (0.80, -0.30), 0.08, 0.12),
            ((0.40, 0.34), (0.52, 0.04), (0.70, -0.30), 0.00, 0.00),
        )
        elbow, hand, tip, lean, step = attack_poses[frame]
        elbow_front = Vector((elbow[0], -0.18, elbow[1]))
        hand_front = Vector((hand[0], -0.22, hand[1]))
        weapon_tip = Vector((tip[0], -0.26, tip[1]))
        elbow_back = Vector((hand_front.x - 0.28, 0.08, hand_front.z + 0.12))
        hand_back = Vector((hand_front.x - 0.10, 0.02, hand_front.z - 0.06))
        chest.x += lean
        head.x += lean * 1.25
        hip.x += lean * 0.38
        knee_front.x += step * 0.65
        foot_front.x += step
        knee_back.x -= step * 0.25
        foot_back.x -= step * 0.36
        if frame <= 1:
            hip.z -= 0.14
            chest.z -= 0.04
            knee_front.z -= 0.08
            knee_back.z -= 0.08
    elif animation == "hurt":
        recoil = (0.20, 0.38, 0.24)[frame]
        chest.x -= recoil
        head.x -= recoil * 1.55
        head.z -= 0.04 * (frame + 1)
        elbow_front = Vector((0.20 - recoil, -0.18, 0.86))
        hand_front = Vector((0.05 - recoil * 1.4, -0.20, 0.98))
        elbow_back = Vector((-0.36 - recoil, 0.12, 0.72))
        hand_back = Vector((-0.52 - recoil, 0.12, 0.48))
        weapon_tip = hand_front + Vector((0.10, -0.04, -0.45))
        foot_back.x -= 0.16
        knee_back.x -= 0.12
    elif animation == "death":
        angles = (0.0, -0.24, -0.55, -0.92, -1.28, -1.52)
        angle = angles[frame]
        pivot = Vector((-0.18, 0.0, -1.00))
        if frame >= 2:
            hand_front += Vector((0.10 * frame, 0.0, -0.05 * frame))
            hand_back += Vector((-0.08 * frame, 0.0, 0.04 * frame))
            knee_front += Vector((0.08 * frame, 0.0, 0.02 * frame))
        names = {
            "hip": hip, "chest": chest, "head": head,
            "shoulder_back": shoulder_back, "shoulder_front": shoulder_front,
            "knee_back": knee_back, "knee_front": knee_front,
            "foot_back": foot_back, "foot_front": foot_front,
            "elbow_back": elbow_back, "hand_back": hand_back,
            "elbow_front": elbow_front, "hand_front": hand_front,
            "weapon_tip": weapon_tip,
        }
        for key, value in names.items():
            names[key] = rotate_point(value, pivot, angle)
        hip, chest, head = names["hip"], names["chest"], names["head"]
        shoulder_back, shoulder_front = names["shoulder_back"], names["shoulder_front"]
        knee_back, knee_front = names["knee_back"], names["knee_front"]
        foot_back, foot_front = names["foot_back"], names["foot_front"]
        elbow_back, hand_back = names["elbow_back"], names["hand_back"]
        elbow_front, hand_front = names["elbow_front"], names["hand_front"]
        weapon_tip = names["weapon_tip"]

    if kind == "enemy":
        head.z -= 0.10
        chest.z -= 0.04
        shoulder_back.z -= 0.04
        shoulder_front.z -= 0.04

    if animation not in ("attack", "hurt", "death"):
        if weapon in ("void_staff", "tuning_staff", "needle_staff", "rift_lantern", "staff"):
            weapon_tip = hand_front + Vector((0.15, -0.04, 0.92))
        elif weapon == "arc_spear":
            weapon_tip = hand_front + Vector((0.30, -0.04, 1.02))
        elif weapon == "rail_rifle":
            elbow_front = Vector((0.40, -0.18, 0.50))
            hand_front = Vector((0.48, -0.20, 0.40))
            hand_back = Vector((0.05, 0.04, 0.48))
            weapon_tip = hand_front + Vector((0.76, -0.04, 0.14))
        elif weapon in ("grenade_launcher", "pulse_cannon"):
            hand_front.z += 0.24
            elbow_front.z += 0.18
            weapon_tip = hand_front + Vector((0.62, -0.04, 0.08))

    return locals()


def basis_from(chest: Vector, head: Vector) -> tuple[Vector, Vector, float]:
    up = (head - chest).normalized()
    right = Vector((up.z, 0.0, -up.x))
    angle = math.atan2(up.x, up.z)
    return right, up, angle


def local_point(base: Vector, right: Vector, up: Vector, x: float, z: float, y: float = 0.0) -> Vector:
    return base + right * x + up * z + Vector((0.0, y, 0.0))


def add_rear_silhouette(prefix: str, style: str, chest: Vector, head: Vector, hip: Vector, shoulder_back: Vector, dark: bpy.types.Material, secondary: bpy.types.Material, accent: bpy.types.Material) -> None:
    right, up, angle = basis_from(chest, head)
    p = lambda base, x, z, y=0.0: local_point(base, right, up, x, z, y)
    if style == "captain":
        prism(prefix + "CommandCape", [p(shoulder_back, -0.16, 0.10, 0.16), p(chest, -0.30, 0.02, 0.16), p(hip, -0.36, -0.70, 0.16), p(hip, 0.02, -0.54, 0.16), p(chest, 0.10, -0.10, 0.16)], 0.08, dark)
        bone(prefix + "HelmCrest", p(head, -0.04, 0.22, 0.02), p(head, -0.22, 0.48, 0.02), 0.055, accent)
    elif style == "sniper":
        box(prefix + "HatBrim", p(head, 0.0, 0.27, -0.01), (0.84, 0.48, 0.075), dark, angle)
        prism(prefix + "HatCrown", [p(head, -0.31, 0.24), p(head, 0.28, 0.24), p(head, 0.19, 0.56), p(head, -0.19, 0.54)], 0.38, secondary)
        prism(prefix + "LongCoat", [p(chest, -0.28, -0.08, 0.15), p(chest, 0.12, -0.06, 0.15), p(hip, 0.08, -0.72, 0.15), p(hip, -0.12, -0.50, 0.15), p(hip, -0.36, -0.74, 0.15)], 0.10, dark)
    elif style == "weaver":
        for side in (-1.0, 1.0):
            start = p(head, side * 0.17, 0.12, 0.10)
            mid = p(chest, side * 0.34, -0.08, 0.12)
            end = p(hip, side * 0.48, -0.45, 0.12)
            bone(prefix + f"VoidTress{side}", start, mid, 0.075, secondary)
            bone(prefix + f"VoidTressTip{side}", mid, end, 0.050, accent)
        prism(prefix + "Veil", [p(head, -0.22, 0.16, 0.16), p(head, 0.20, 0.16, 0.16), p(chest, 0.30, -0.36, 0.16), p(hip, 0.02, -0.28, 0.16), p(chest, -0.30, -0.34, 0.16)], 0.08, dark)
    elif style == "arc_scout":
        prism(prefix + "WindScarf", [p(chest, -0.22, 0.16, 0.14), p(chest, 0.02, 0.08, 0.14), p(chest, -0.48, -0.08, 0.14), p(hip, -0.64, -0.28, 0.14), p(chest, -0.34, 0.02, 0.14)], 0.08, accent)
        for offset in (-0.16, 0.16):
            bone(prefix + f"Antenna{offset}", p(head, offset, 0.22, 0.05), p(head, offset * 1.8, 0.48, 0.05), 0.035, secondary)
    elif style == "singer":
        prism(prefix + "FanHair", [p(head, -0.26, 0.12, 0.14), p(head, 0.16, 0.18, 0.14), p(chest, 0.28, -0.18, 0.14), p(hip, 0.20, -0.62, 0.14), p(hip, -0.26, -0.48, 0.14), p(chest, -0.38, -0.10, 0.14)], 0.12, dark)
        sphere(prefix + "EchoSpeakerRear", p(chest, -0.36, 0.18, 0.10), (0.18, 0.08, 0.18), accent)
        sphere(prefix + "EchoSpeakerFront", p(chest, 0.34, 0.18, 0.10), (0.18, 0.08, 0.18), accent)
    elif style == "grenadier":
        box(prefix + "BlastPack", p(chest, -0.30, -0.02, 0.16), (0.24, 0.18, 0.38), dark, angle)
        bone(prefix + "PackChimney", p(chest, -0.38, 0.26, 0.16), p(head, -0.34, 0.35, 0.16), 0.06, secondary)
        for index in range(3):
            sphere(prefix + f"Grenade{index}", p(chest, -0.32 + index * 0.21, -0.20 - index * 0.02, -0.04), (0.095, 0.07, 0.105), accent)
    elif style == "mender":
        sphere(prefix + "ThreadSpool", p(chest, -0.30, -0.02, 0.16), (0.28, 0.10, 0.28), secondary)
        sphere(prefix + "SpoolCore", p(chest, -0.30, -0.02, 0.05), (0.10, 0.06, 0.10), accent)
        bone(prefix + "LooseThread", p(chest, -0.40, -0.14, 0.18), p(hip, -0.48, -0.58, 0.18), 0.025, accent)
        prism(prefix + "MenderHood", [p(head, -0.30, 0.00, 0.10), p(head, -0.18, 0.32, 0.10), p(head, 0.08, 0.42, 0.10), p(head, 0.30, 0.04, 0.10), p(chest, 0.18, 0.18, 0.10), p(chest, -0.20, 0.16, 0.10)], 0.18, dark)
    elif style == "orbit_guard":
        bone(prefix + "HelmFin", p(head, 0.0, 0.22, 0.04), p(head, -0.12, 0.52, 0.04), 0.065, accent)
        for side in (-1.0, 1.0):
            center = p(chest, side * 0.48, 0.25, 0.08)
            box(prefix + f"OrbitBlade{side}", center, (0.08, 0.08, 0.30), accent, angle + side * 0.35)
    elif style == "artificer":
        box(prefix + "CoilPack", p(chest, -0.30, -0.02, 0.16), (0.25, 0.18, 0.34), dark, angle)
        for side in (-1.0, 1.0):
            bone(prefix + f"CoilFork{side}", p(chest, -0.28, 0.22, 0.16), p(head, -0.20 + side * 0.18, 0.48, 0.16), 0.035, accent)
        box(prefix + "GoggleBand", p(head, 0.0, 0.05, -0.01), (0.32, 0.20, 0.055), secondary, angle)
    elif style == "shepherd":
        prism(prefix + "ShepherdCloak", [p(head, -0.26, 0.12, 0.14), p(head, 0.22, 0.12, 0.14), p(chest, 0.32, -0.10, 0.14), p(hip, 0.20, -0.68, 0.14), p(hip, -0.34, -0.62, 0.14), p(chest, -0.40, -0.10, 0.14)], 0.12, dark)
        prism(prefix + "LanternHood", [p(head, -0.32, -0.02, 0.08), p(head, -0.18, 0.34, 0.08), p(head, 0.02, 0.50, 0.08), p(head, 0.30, 0.02, 0.08), p(chest, 0.20, 0.20, 0.08), p(chest, -0.22, 0.18, 0.08)], 0.18, secondary)


def add_enemy_silhouette(prefix: str, style: str, chest: Vector, head: Vector, hip: Vector, dark: bpy.types.Material, secondary: bpy.types.Material, accent: bpy.types.Material) -> None:
    right, up, angle = basis_from(chest, head)
    p = lambda base, x, z, y=0.0: local_point(base, right, up, x, z, y)
    # Every enemy carries asymmetrical torn clothing and a readable wound.
    prism(prefix + "TornSkirt", [p(hip, -0.30, 0.12, 0.14), p(hip, 0.30, 0.12, 0.14), p(hip, 0.25, -0.36, 0.14), p(hip, 0.02, -0.22, 0.14), p(hip, -0.12, -0.42, 0.14), p(hip, -0.32, -0.24, 0.14)], 0.10, dark)
    if style in ("grunt", "swift"):
        prism(prefix + "RagScarf", [p(chest, -0.22, 0.18, 0.14), p(chest, 0.16, 0.12, 0.14), p(chest, -0.34, -0.02, 0.14), p(hip, -0.62, -0.18, 0.14), p(chest, -0.38, 0.06, 0.14)], 0.08, secondary)
    if style in ("fast", "swift"):
        for index in range(3):
            start = p(chest, -0.22, 0.18 - index * 0.20, 0.12)
            end = p(chest, -0.48 - index * 0.08, 0.34 - index * 0.22, 0.12)
            bone(prefix + f"BackQuill{index}", start, end, 0.045, accent)
    if style == "tank":
        for side in (-1.0, 1.0):
            box(prefix + f"SlabPauldron{side}", p(chest, side * 0.36, 0.18, 0.04), (0.26, 0.20, 0.20), secondary, angle + side * 0.20)
        box(prefix + "BrokenBackplate", p(chest, -0.16, -0.02, 0.12), (0.36, 0.18, 0.38), dark, angle)
    if style == "field":
        prism(prefix + "FieldMantle", [p(chest, -0.42, 0.18, 0.12), p(chest, 0.42, 0.18, 0.12), p(hip, 0.22, -0.34, 0.12), p(hip, -0.10, -0.20, 0.12), p(hip, -0.34, -0.44, 0.12)], 0.12, secondary)
        for side in (-1.0, 1.0):
            bone(prefix + f"FieldAntler{side}", p(head, side * 0.12, 0.20, 0.06), p(head, side * 0.35, 0.48, 0.06), 0.045, accent)
    if style == "split":
        for side in (-1.0, 1.0):
            base = p(head, side * 0.12, 0.18, 0.04)
            fork = p(head, side * 0.32, 0.42, 0.04)
            bone(prefix + f"SplitHorn{side}", base, fork, 0.055, secondary)
            bone(prefix + f"SplitHornFork{side}", fork, p(head, side * 0.46, 0.52, 0.04), 0.040, accent)
    if style == "boss":
        prism(prefix + "BossMantle", [p(head, -0.32, -0.04, 0.14), p(head, 0.30, -0.04, 0.14), p(chest, 0.48, -0.12, 0.14), p(hip, 0.34, -0.72, 0.14), p(hip, 0.02, -0.52, 0.14), p(hip, -0.42, -0.76, 0.14), p(chest, -0.52, -0.12, 0.14)], 0.14, dark)
        for side in (-1.0, 0.0, 1.0):
            base = p(head, side * 0.16, 0.18, 0.04)
            tip = p(head, side * 0.36, 0.58 - abs(side) * 0.08, 0.04)
            bone(prefix + f"CrownHorn{side}", base, tip, 0.065, accent)
    # The wound lives on the camera-facing chest, independent of hit flash.
    bone(prefix + "WoundSlashA", p(chest, -0.16, 0.12, -0.24), p(chest, 0.14, -0.10, -0.24), 0.035, accent)
    bone(prefix + "WoundSlashB", p(chest, -0.08, 0.18, -0.245), p(chest, 0.20, -0.04, -0.245), 0.025, accent)


def add_face(
    prefix: str,
    head: Vector,
    chest: Vector,
    skin: bpy.types.Material,
    sclera: bpy.types.Material,
    iris: bpy.types.Material,
    pupil: bpy.types.Material,
    brow: bpy.types.Material,
    enemy: bool,
) -> None:
    right, up, _angle = basis_from(chest, head)
    y = -0.292
    eye_z = 0.045 if not enemy else 0.018
    for side in (-1.0, 1.0):
        eye = local_point(head, right, up, side * 0.105, eye_z, y)
        sphere(prefix + f"EyeWhite{side}", eye, (0.088, 0.032, 0.064), sclera, 1)
        iris_center = eye + Vector((0.010 if enemy else 0.016, -0.036, -0.002))
        sphere(prefix + f"Iris{side}", iris_center, (0.047, 0.018, 0.046), iris, 1)
        pupil_center = iris_center + Vector((0.006, -0.020, 0.0))
        sphere(prefix + f"Pupil{side}", pupil_center, (0.020, 0.010, 0.025), pupil, 1)
        brow_center = local_point(head, right, up, side * 0.105, eye_z + 0.105, y - 0.018)
        brow_start = brow_center - right * 0.072 + up * (0.024 * side if enemy else 0.012 * side)
        brow_end = brow_center + right * 0.072 - up * (0.024 * side if enemy else 0.012 * side)
        bone(prefix + f"Brow{side}", brow_start, brow_end, 0.021, brow)
    # A projected nose and mouth preserve a complete face after 64px minification.
    sphere(prefix + "Nose", local_point(head, right, up, 0.155, -0.055, y - 0.012), (0.052, 0.024, 0.067), skin, 1)
    mouth_center = local_point(head, right, up, 0.095, -0.175, y - 0.018)
    bone(prefix + "Mouth", mouth_center - right * 0.060, mouth_center + right * 0.055, 0.014, brow)


def add_head_design(
    prefix: str,
    style: str,
    head: Vector,
    chest: Vector,
    hair: bpy.types.Material,
    dark: bpy.types.Material,
    secondary: bpy.types.Material,
    accent: bpy.types.Material,
    lens: bpy.types.Material,
) -> None:
    """Author hairstyle and face-bound role cues before the skin volume."""
    right, up, _angle = basis_from(chest, head)
    p = lambda x, z, y=0.0: local_point(head, right, up, x, z, y)
    # Offset into positive camera depth: the cap frames rather than masks skin.
    cap_scale = (0.335, 0.255, 0.305)
    if style in ("weaver", "singer"):
        cap_scale = (0.365, 0.275, 0.355)
    sphere(prefix + "HairCap", p(-0.025, 0.105, 0.055), cap_scale, hair)

    if style == "captain":
        bone(prefix + "CaptainDiadem", p(-0.25, 0.15, -0.27), p(0.27, 0.15, -0.27), 0.035, accent)
        sphere(prefix + "CaptainTempleGuard", p(-0.29, -0.01, -0.03), (0.07, 0.04, 0.16), secondary, 1)
    elif style == "sniper":
        # One cold optic gives the face a readable asymmetrical focal point.
        sphere(prefix + "SniperMonocle", p(0.105, 0.045, -0.32), (0.092, 0.025, 0.082), lens, 1)
        bone(prefix + "SniperMonocleArm", p(0.18, 0.09, -0.30), p(0.29, 0.19, -0.20), 0.018, secondary)
    elif style == "weaver":
        sphere(prefix + "VoidBindi", p(0.0, 0.19, -0.31), (0.045, 0.018, 0.060), accent, 1)
        for side in (-1.0, 1.0):
            bone(prefix + f"VoidFaceTress{side}", p(side * 0.24, 0.12, -0.08), p(side * 0.33, -0.29, -0.03), 0.052, hair)
    elif style == "arc_scout":
        bone(prefix + "ScoutVisorBand", p(-0.25, 0.075, -0.29), p(0.27, 0.075, -0.29), 0.035, dark)
        sphere(prefix + "ScoutVisor", p(0.10, 0.055, -0.32), (0.17, 0.025, 0.080), lens, 1)
    elif style == "singer":
        for side in (-1.0, 1.0):
            sphere(prefix + f"SingerHairCoil{side}", p(side * 0.31, 0.02, 0.00), (0.13, 0.11, 0.16), hair, 1)
        bone(prefix + "SingerCirclet", p(-0.24, 0.16, -0.27), p(0.26, 0.16, -0.27), 0.026, accent)
    elif style == "grenadier":
        bone(prefix + "GrenadierGoggleBand", p(-0.26, 0.09, -0.29), p(0.28, 0.09, -0.29), 0.030, dark)
        for side in (-1.0, 1.0):
            sphere(prefix + f"GrenadierLens{side}", p(side * 0.105, 0.07, -0.33), (0.088, 0.024, 0.070), lens, 1)
    elif style == "mender":
        bone(prefix + "MenderHairNeedle", p(-0.20, 0.28, 0.0), p(0.25, 0.39, 0.0), 0.024, accent)
    elif style == "orbit_guard":
        bone(prefix + "GuardHelmBrow", p(-0.27, 0.12, -0.28), p(0.29, 0.12, -0.28), 0.046, secondary)
        sphere(prefix + "GuardForeheadCore", p(0.0, 0.20, -0.32), (0.060, 0.024, 0.075), accent, 1)
    elif style == "artificer":
        bone(prefix + "ArtificerGoggleBand", p(-0.27, 0.10, -0.29), p(0.29, 0.10, -0.29), 0.032, dark)
        for side in (-1.0, 1.0):
            sphere(prefix + f"ArtificerLens{side}", p(side * 0.105, 0.08, -0.33), (0.082, 0.024, 0.068), lens, 1)
    elif style == "shepherd":
        bone(prefix + "ShepherdHairLock", p(-0.12, 0.25, -0.21), p(0.08, -0.10, -0.30), 0.040, hair)
        sphere(prefix + "ShepherdBrowRune", p(0.12, 0.17, -0.32), (0.038, 0.018, 0.055), accent, 1)


def add_costume_front(
    prefix: str,
    style: str,
    chest: Vector,
    hip: Vector,
    shoulder_back: Vector,
    shoulder_front: Vector,
    dark: bpy.types.Material,
    body: bpy.types.Material,
    secondary: bpy.types.Material,
    accent: bpy.types.Material,
    metal: bpy.types.Material,
    leather: bpy.types.Material,
) -> None:
    """Layer role-specific costume geometry on the camera-facing body planes."""
    right, up, _angle = basis_from(hip, chest)
    p = lambda base, x, z, y=-0.22: local_point(base, right, up, x, z, y)
    bone(prefix + "WaistBelt", p(hip, -0.31, 0.10), p(hip, 0.31, 0.10), 0.040, leather)
    sphere(prefix + "BeltClasp", p(hip, 0.02, 0.10, -0.255), (0.072, 0.025, 0.065), accent, 1)

    if style == "captain":
        for side, shoulder in ((-1.0, shoulder_back), (1.0, shoulder_front)):
            sphere(prefix + f"CaptainPauldron{side}", shoulder + Vector((side * 0.025, -0.02, 0.015)), (0.20, 0.16, 0.17), metal, 1)
        bone(prefix + "CaptainChestChevronA", p(chest, -0.22, 0.12), p(chest, 0.02, -0.13), 0.032, accent)
        bone(prefix + "CaptainChestChevronB", p(chest, 0.02, -0.13), p(chest, 0.24, 0.12), 0.032, accent)
    elif style == "sniper":
        bone(prefix + "SniperBandolier", p(chest, -0.25, 0.25), p(hip, 0.26, -0.02), 0.055, leather)
        for index in range(3):
            box(prefix + f"SniperCell{index}", p(chest, -0.10 + index * 0.13, -0.02, -0.255), (0.09, 0.055, 0.16), metal, -0.08)
    elif style == "weaver":
        sphere(prefix + "WeaverCollar", p(chest, 0.0, 0.24), (0.34, 0.12, 0.12), secondary, 1)
        for side in (-1.0, 1.0):
            bone(prefix + f"WeaverRune{side}", p(chest, side * 0.12, 0.05), p(hip, side * 0.20, 0.02), 0.026, accent)
    elif style == "arc_scout":
        sphere(prefix + "ScoutShoulderPlate", shoulder_back + Vector((-0.03, -0.03, 0.01)), (0.19, 0.13, 0.16), metal, 1)
        bone(prefix + "ScoutHarness", p(chest, -0.20, 0.19), p(hip, 0.18, 0.00), 0.048, leather)
    elif style == "singer":
        sphere(prefix + "SingerCollar", p(chest, 0.0, 0.24), (0.34, 0.12, 0.13), secondary, 1)
        sphere(prefix + "SingerResonator", p(chest, 0.02, -0.04, -0.275), (0.12, 0.035, 0.14), accent, 1)
    elif style == "grenadier":
        sphere(prefix + "GrenadierPauldron", shoulder_back + Vector((-0.04, -0.03, 0.01)), (0.23, 0.15, 0.19), metal, 1)
        bone(prefix + "GrenadierHarnessA", p(chest, -0.24, 0.21), p(hip, 0.18, 0.00), 0.055, leather)
        bone(prefix + "GrenadierHarnessB", p(chest, 0.24, 0.21), p(hip, -0.18, 0.00), 0.055, leather)
    elif style == "mender":
        prism(prefix + "MenderApron", [p(chest, -0.21, 0.05), p(chest, 0.21, 0.05), p(hip, 0.26, -0.38), p(hip, -0.23, -0.43)], 0.07, secondary)
        bone(prefix + "MenderThreadMarkA", p(chest, -0.13, 0.08, -0.28), p(hip, 0.15, -0.22, -0.28), 0.024, accent)
        bone(prefix + "MenderThreadMarkB", p(chest, 0.13, 0.08, -0.28), p(hip, -0.15, -0.22, -0.28), 0.024, accent)
    elif style == "orbit_guard":
        for side, shoulder in ((-1.0, shoulder_back), (1.0, shoulder_front)):
            sphere(prefix + f"GuardPauldron{side}", shoulder + Vector((side * 0.035, -0.02, 0.02)), (0.24, 0.17, 0.20), metal, 1)
        sphere(prefix + "GuardChestCore", p(chest, 0.02, -0.02, -0.28), (0.13, 0.035, 0.15), accent, 1)
    elif style == "artificer":
        bone(prefix + "ArtificerHarness", p(chest, -0.24, 0.20), p(hip, 0.19, -0.01), 0.052, leather)
        for index in range(3):
            box(prefix + f"ArtificerTool{index}", p(hip, -0.20 + index * 0.18, -0.08, -0.26), (0.08, 0.05, 0.22 - index * 0.025), metal, 0.10 * (index - 1))
    elif style == "shepherd":
        sphere(prefix + "ShepherdClasp", p(chest, 0.0, 0.23, -0.26), (0.11, 0.035, 0.11), accent, 1)
        bone(prefix + "ShepherdCloakTrimL", p(chest, -0.28, 0.12), p(hip, -0.27, -0.34), 0.030, secondary)
        bone(prefix + "ShepherdCloakTrimR", p(chest, 0.28, 0.12), p(hip, 0.27, -0.34), 0.030, secondary)


def add_weapon(
    prefix: str,
    weapon: str,
    hand_front: Vector,
    hand_back: Vector,
    tip: Vector,
    dark: bpy.types.Material,
    secondary: bpy.types.Material,
    accent: bpy.types.Material,
    metal: bpy.types.Material | None = None,
    leather: bpy.types.Material | None = None,
) -> None:
    metal = metal or secondary
    leather = leather or dark
    delta = tip - hand_front
    direction = delta.normalized() if delta.length > 0.001 else Vector((0.0, 0.0, 1.0))
    side = Vector((-direction.z, 0.0, direction.x))
    angle = math.atan2(direction.x, direction.z)
    if weapon == "orbit_shield":
        shield_center = hand_back + Vector((-0.10, -0.13, 0.08))
        sphere(prefix + "OrbitShield", shield_center, (0.40, 0.08, 0.46), metal)
        sphere(prefix + "ShieldCore", shield_center + Vector((0.04, -0.09, 0.0)), (0.18, 0.035, 0.20), accent, 1)
        bone(prefix + "GuardBlade", hand_front, tip, 0.060, metal)
        bone(prefix + "GuardBladeEdge", tip, tip + direction * 0.20, 0.095, accent)
    elif weapon == "rift_lantern":
        bone(prefix + "LanternBrace", hand_back, hand_front, 0.045, metal)
        bone(prefix + "LanternStaff", hand_front, tip, 0.052, leather)
        core = tip + direction * 0.04
        sphere(prefix + "LanternCore", core, (0.17, 0.10, 0.19), accent, 1)
        for index in (-1, 1):
            cage_start = core + side * index * 0.19 + direction * 0.17
            cage_end = core + side * index * 0.19 - direction * 0.17
            bone(prefix + f"LanternCage{index}", cage_start, cage_end, 0.034, metal)
        bone(prefix + "LanternCrossbar", core - side * 0.23, core + side * 0.23, 0.032, metal)
        bone(prefix + "LanternVane", core - direction * 0.14, core - direction * 0.34 + side * 0.09, 0.038, accent)
    elif weapon == "rail_rifle":
        bone(prefix + "RailBarrel", hand_front, tip + direction * 0.12, 0.055, accent)
        box(prefix + "RailReceiver", hand_front + direction * 0.24, (0.13, 0.12, 0.30), metal, angle)
        bone(prefix + "RailStock", hand_front, hand_back - direction * 0.16, 0.090, leather)
        box(prefix + "RailScope", hand_front + direction * 0.28 + side * 0.13, (0.075, 0.07, 0.16), accent, angle)
    elif weapon == "void_staff":
        bone(prefix + "VoidStaff", hand_front, tip, 0.052, leather)
        crown = tip + direction * 0.08
        bone(prefix + "CrescentA", crown, crown + direction * 0.18 + side * 0.20, 0.055, secondary)
        bone(prefix + "CrescentB", crown, crown + direction * 0.18 - side * 0.20, 0.055, secondary)
        sphere(prefix + "VoidKnot", crown + direction * 0.16, (0.12, 0.08, 0.12), accent)
    elif weapon == "arc_spear":
        bone(prefix + "ArcSpearShaft", hand_front, tip, 0.048, leather)
        spear_tip = tip + direction * 0.27
        bone(prefix + "ArcSpearTip", tip, spear_tip, 0.080, accent)
        bone(prefix + "ArcSpearForkA", tip, tip + direction * 0.12 + side * 0.14, 0.040, secondary)
        bone(prefix + "ArcSpearForkB", tip, tip + direction * 0.12 - side * 0.14, 0.040, secondary)
    elif weapon == "tuning_staff":
        bone(prefix + "HymnStaff", hand_front, tip, 0.052, metal)
        cross = tip + direction * 0.06
        bone(prefix + "TuningCross", cross - side * 0.18, cross + side * 0.18, 0.042, secondary)
        bone(prefix + "TuningForkA", cross - side * 0.18, cross - side * 0.18 + direction * 0.26, 0.045, accent)
        bone(prefix + "TuningForkB", cross + side * 0.18, cross + side * 0.18 + direction * 0.26, 0.045, accent)
    elif weapon == "grenade_launcher":
        bone(prefix + "LauncherBarrel", hand_front, tip, 0.115, metal)
        box(prefix + "LauncherMuzzle", tip, (0.16, 0.13, 0.16), metal, angle)
        sphere(prefix + "GrenadeDrum", hand_front + direction * 0.18 - side * 0.14, (0.16, 0.10, 0.17), accent, 1)
        bone(prefix + "LauncherBrace", hand_back, hand_front + direction * 0.18, 0.055, metal)
    elif weapon == "needle_staff":
        bone(prefix + "NeedleStaff", hand_front, tip, 0.046, leather)
        bone(prefix + "Needle", tip, tip + direction * 0.32, 0.045, accent)
        sphere(prefix + "NeedleSpool", tip - direction * 0.06, (0.15, 0.08, 0.15), secondary, 1)
        bone(prefix + "ThreadTail", tip - side * 0.14, tip - side * 0.30 - direction * 0.10, 0.024, accent)
    elif weapon == "pulse_cannon":
        bone(prefix + "CannonBrace", hand_back, hand_front, 0.065, metal)
        bone(prefix + "PulseCannon", hand_front, tip, 0.135, metal)
        sphere(prefix + "PulseMuzzle", tip, (0.18, 0.12, 0.18), accent, 1)
        for offset in (0.22, 0.46):
            sphere(prefix + f"PulseCoil{offset}", hand_front + direction * offset, (0.15, 0.105, 0.07), secondary, 1)
    elif weapon == "axes":
        bone(prefix + "AxeA", hand_front, tip, 0.065, leather)
        box(prefix + "AxeHeadA", tip, (0.20, 0.08, 0.13), accent, angle + 0.35)
        second_tip = hand_back + Vector((-0.34, 0.0, 0.26))
        bone(prefix + "AxeB", hand_back, second_tip, 0.060, leather)
        box(prefix + "AxeHeadB", second_tip, (0.18, 0.08, 0.12), secondary, angle - 0.30)
    elif weapon == "claw":
        for index in (-1, 0, 1):
            claw_tip = hand_front + direction * 0.42 + side * index * 0.10
            bone(prefix + f"Claw{index}", hand_front, claw_tip, 0.035, accent)
    else:
        thickness = 0.082 if weapon in ("hammer", "greatblade") else 0.052
        bone(prefix + "WeaponShaft", hand_front, tip, thickness, leather)
        if weapon == "hammer":
            box(prefix + "HammerHead", tip, (0.32, 0.12, 0.18), metal, angle + 0.25)
            box(prefix + "BrokenHammerFace", tip + side * 0.18, (0.13, 0.14, 0.16), accent, angle - 0.15)
        elif weapon in ("captain_blade", "greatblade"):
            length = 0.42 if weapon == "captain_blade" else 0.54
            blade_mid = tip + direction * length
            bone(prefix + "Blade", tip, blade_mid, 0.11 if weapon == "greatblade" else 0.085, metal)
            bone(prefix + "BladeGlow", tip + direction * 0.04, blade_mid, 0.045, accent)
            bone(prefix + "BladeGuard", hand_front - side * 0.14, hand_front + side * 0.14, 0.045, accent)
        elif weapon == "club":
            sphere(prefix + "ClubHead", tip, (0.17, 0.11, 0.20), secondary)
            for spike in (-1.0, 1.0):
                bone(prefix + f"ClubSpike{spike}", tip, tip + side * spike * 0.20 + direction * 0.08, 0.035, accent)
        elif weapon == "staff":
            sphere(prefix + "StaffCore", tip, (0.15, 0.10, 0.15), accent)
            bone(prefix + "StaffForkA", tip, tip + direction * 0.20 + side * 0.12, 0.045, secondary)
            bone(prefix + "StaffForkB", tip, tip + direction * 0.20 - side * 0.12, 0.045, secondary)


def build_character(cell_x: float, cell_z: float, spec: dict, animation: str, frame: int) -> int:
    face_start = len(MESH_FACES)
    char_id = spec["id"]
    kind = spec["kind"]
    style = spec["style"]
    weapon = spec["weapon"]
    size = spec["size"]
    p = pose(animation, frame, kind, weapon)
    origin = Vector((cell_x, 0.0, cell_z + 0.05))

    def at(name: str) -> Vector:
        point = p[name]
        return origin + Vector((point.x * size, point.y, point.z * size))

    prefix = f"{char_id}_{animation}_{frame}_"
    dark_color, body_color, secondary_color, accent_color = spec["palette"]
    dark = material(char_id + "_dark_cloth", dark_color, surface="cloth")
    leather = material(char_id + "_dark_leather", dark_color, surface="leather")
    hair = material(char_id + "_hair", dark_color, surface="hair")
    body = material(char_id + "_body_cloth", body_color, surface="cloth")
    secondary = material(char_id + "_secondary_cloth", secondary_color, surface="cloth")
    metal = material(char_id + "_secondary_metal", secondary_color, surface="metal")
    accent = material(char_id + "_highlight", accent_color, 0.22, surface="metal")
    lens = material(char_id + "_lens", accent_color, 0.16, surface="lens")
    skin = material(char_id + "_skin", spec["skin"], surface="skin")
    sclera = material("face_sclera", (0.88, 0.88, 0.82, 1.0), surface="skin")
    iris = material(char_id + "_iris", spec["iris"], 0.12, surface="lens")
    brow = material("face_brow", (0.075, 0.055, 0.070, 1.0), surface="hair")

    if kind == "hero":
        add_rear_silhouette(prefix, style, at("chest"), at("head"), at("hip"), at("shoulder_back"), dark, secondary, accent)
    else:
        add_enemy_silhouette(prefix, style, at("chest"), at("head"), at("hip"), dark, secondary, accent)

    # Articulated rear limbs, torso, then front limbs establish a readable
    # three-quarter silhouette.  No whole-sprite transform is used.
    tapered_bone(prefix + "BackThigh", at("hip") + Vector((-0.11, 0.13, 0.0)), at("knee_back"), 0.145 * size, 0.105 * size, dark)
    tapered_bone(prefix + "BackShin", at("knee_back"), at("foot_back"), 0.105 * size, 0.080 * size, body)
    tapered_bone(prefix + "BackUpperArm", at("shoulder_back"), at("elbow_back"), 0.125 * size, 0.085 * size, dark)
    tapered_bone(prefix + "BackForearm", at("elbow_back"), at("hand_back"), 0.090 * size, 0.072 * size, body)
    sphere(prefix + "BackHand", at("hand_back"), (0.105 * size, 0.085, 0.105 * size), skin, 1)

    torso_mid = (at("hip") + at("chest")) * 0.5 + Vector((0.0, 0.02, 0.03))
    sphere(prefix + "TailoredTorso", torso_mid, (0.34 * size, 0.225, 0.39 * size), body)
    sphere(prefix + "Waist", at("hip") + Vector((0.0, 0.015, 0.08)), (0.27 * size, 0.205, 0.25 * size), dark)
    sphere(prefix + "ChestArmor", at("chest") + Vector((0.02, -0.025, -0.06)), (0.40 * size, 0.235, 0.34 * size), metal if kind == "hero" else secondary)

    if kind == "hero":
        add_head_design(prefix, style, at("head"), at("chest"), hair, dark, secondary, accent, lens)
    sphere(prefix + "Head", at("head"), (0.345 * size, 0.275, 0.345 * size), skin)
    add_face(prefix, at("head"), at("chest"), skin, sclera, iris, brow, brow, kind == "enemy")
    if kind == "enemy" and style not in ("split", "field", "boss"):
        right, up, _angle = basis_from(at("chest"), at("head"))
        horn_start = local_point(at("head"), right, up, -0.12 * size, 0.20 * size, 0.02)
        horn_tip = local_point(at("head"), right, up, -0.34 * size, 0.45 * size, 0.02)
        bone(prefix + "BrokenHorn", horn_start, horn_tip, 0.045 * size, accent)
    tapered_bone(prefix + "FrontThigh", at("hip") + Vector((0.12, -0.16, 0.0)), at("knee_front"), 0.155 * size, 0.112 * size, body)
    sphere(prefix + "FrontKnee", at("knee_front"), (0.125 * size, 0.11, 0.12 * size), metal if kind == "hero" else secondary, 1)
    tapered_bone(prefix + "FrontShin", at("knee_front"), at("foot_front"), 0.112 * size, 0.082 * size, secondary)
    sphere(prefix + "FrontBoot", at("foot_front") + Vector((0.10 * size, -0.015, 0.0)), (0.19 * size, 0.145, 0.105 * size), leather)
    sphere(prefix + "BackBoot", at("foot_back") + Vector((0.09 * size, 0.0, 0.0)), (0.18 * size, 0.135, 0.095 * size), leather)
    tapered_bone(prefix + "FrontUpperArm", at("shoulder_front"), at("elbow_front"), 0.135 * size, 0.095 * size, body)
    sphere(prefix + "FrontElbow", at("elbow_front"), (0.105 * size, 0.09, 0.105 * size), secondary, 1)
    tapered_bone(prefix + "FrontForearm", at("elbow_front"), at("hand_front"), 0.100 * size, 0.078 * size, secondary)
    sphere(prefix + "FrontHand", at("hand_front"), (0.115 * size, 0.095, 0.115 * size), skin, 1)
    if kind == "hero":
        add_costume_front(
            prefix,
            style,
            at("chest"),
            at("hip"),
            at("shoulder_back"),
            at("shoulder_front"),
            dark,
            body,
            secondary,
            accent,
            metal,
            leather,
        )
    add_weapon(prefix, weapon, at("hand_front"), at("hand_back"), at("weapon_tip"), dark, secondary, accent, metal, leather)

    triangles = sum(max(1, len(face) - 2) for face in MESH_FACES[face_start:])
    if animation == "idle" and frame == 0:
        CHARACTER_TRIANGLES[char_id] = triangles
    return triangles


def configure_scene(rows: int) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = COLUMNS * CELL_PIXELS
    scene.render.resolution_y = rows * CELL_PIXELS
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.filepath = str(OUTPUT)
    scene.render.use_file_extension = True
    scene.render.filter_size = 0.62
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    # R20's 6.98 total sun energy plus AgX/+0.85 EV pushed 64px mid-tones into
    # highlight desaturation.  R20.1 uses Standard for palette fidelity,
    # reduces the four-light total to 2.43, then restores display brightness
    # with exposure after the colored surfaces have separated.
    scene.view_settings.exposure = 1.30
    scene.view_settings.gamma = 1.0

    camera_data = bpy.data.cameras.new("AtlasCamera")
    camera = bpy.data.objects.new("AtlasCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0.0, -40.0, 0.0)
    camera.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = rows * CELL_WORLD
    camera_data.lens = 50
    scene.camera = camera

    world = bpy.data.worlds.new("AtlasWorld") if bpy.data.worlds.get("AtlasWorld") is None else bpy.data.worlds["AtlasWorld"]
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.070, 0.095, 0.15, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.18
    scene.world = world

    key_data = bpy.data.lights.new("AtlasKey", type="SUN")
    key_data.energy = 1.10
    key_data.angle = math.radians(24.0)
    key_data.color = (1.0, 0.72, 0.46)
    key = bpy.data.objects.new("AtlasKey", key_data)
    bpy.context.collection.objects.link(key)
    key.rotation_euler = (math.radians(32.0), math.radians(-18.0), math.radians(-38.0))

    fill_data = bpy.data.lights.new("AtlasFill", type="SUN")
    fill_data.energy = 0.38
    fill_data.angle = math.radians(30.0)
    fill_data.color = (0.32, 0.62, 0.90)
    fill = bpy.data.objects.new("AtlasFill", fill_data)
    bpy.context.collection.objects.link(fill)
    fill.rotation_euler = (math.radians(48.0), math.radians(18.0), math.radians(42.0))

    rim_data = bpy.data.lights.new("AtlasRim", type="SUN")
    rim_data.energy = 0.75
    rim_data.angle = math.radians(16.0)
    rim_data.color = (0.30, 0.72, 1.0)
    rim = bpy.data.objects.new("AtlasRim", rim_data)
    bpy.context.collection.objects.link(rim)
    rim.rotation_euler = (math.radians(-42.0), math.radians(35.0), math.radians(145.0))

    bounce_data = bpy.data.lights.new("AtlasBounce", type="SUN")
    bounce_data.energy = 0.20
    bounce_data.angle = math.radians(38.0)
    bounce_data.color = (0.58, 0.72, 0.78)
    bounce = bpy.data.objects.new("AtlasBounce", bounce_data)
    bpy.context.collection.objects.link(bounce)
    bounce.rotation_euler = (math.radians(110.0), math.radians(-10.0), math.radians(12.0))


def finalize_atlas_mesh(name: str = "TrueCharacterAtlasGeometry") -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(MESH_VERTICES, [], MESH_FACES)
    mesh.update()
    gradient = mesh.color_attributes.new(name="cv_gradient", type="FLOAT_COLOR", domain="POINT")
    for entry, shade in zip(gradient.data, MESH_VERTEX_SHADES):
        entry.color = shade
    for mat in MATERIALS:
        mesh.materials.append(mat)
    for polygon, material_index in zip(mesh.polygons, MESH_FACE_MATERIALS):
        polygon.material_index = material_index
    atlas_object = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(atlas_object)
    return atlas_object


def save_hero_references(rows: int) -> None:
    """Crop each hero idle frame into its unique Godot resource key."""
    atlas = bpy.data.images.load(str(OUTPUT), check_existing=False)
    source_pixels = list(atlas.pixels)
    for character_index, spec in enumerate(CHARACTERS):
        if spec["kind"] != "hero":
            continue
        atlas_cell = character_index * FRAMES_PER_CHARACTER
        source_x = (atlas_cell % COLUMNS) * CELL_PIXELS
        atlas_row = atlas_cell // COLUMNS
        source_y = int(atlas.size[1]) - (atlas_row + 1) * CELL_PIXELS
        cropped_pixels: list[float] = []
        for y in range(CELL_PIXELS):
            row_start = ((source_y + y) * int(atlas.size[0])) * 4
            for x in range(CELL_PIXELS):
                pixel_start = row_start + (source_x + x) * 4
                cropped_pixels.extend(source_pixels[pixel_start:pixel_start + 4])
        reference_path = ROOT / "assets" / "sprites" / f"{spec['id']}.png"
        reference = bpy.data.images.new(f"{spec['id']}_reference", width=CELL_PIXELS, height=CELL_PIXELS, alpha=True)
        reference.pixels.foreach_set(cropped_pixels)
        reference.file_format = "PNG"
        reference.filepath_raw = str(reference_path)
        reference.save()
        bpy.data.images.remove(reference)
        print(f"TRUE_ANIMATION_REFERENCE {reference_path} {CELL_PIXELS}x{CELL_PIXELS}", flush=True)
    bpy.data.images.remove(atlas)


def build() -> None:
    reset_geometry_buffers()
    total_cells = len(CHARACTERS) * FRAMES_PER_CHARACTER
    rows = math.ceil(total_cells / COLUMNS)
    bpy.context.preferences.filepaths.save_version = 0
    configure_scene(rows)
    for character_index, spec in enumerate(CHARACTERS):
        state_offset = 0
        for animation, frame_count in ANIMATIONS:
            for frame in range(frame_count):
                atlas_cell = character_index * FRAMES_PER_CHARACTER + state_offset + frame
                column = atlas_cell % COLUMNS
                row = atlas_cell // COLUMNS
                cell_x = (column - COLUMNS * 0.5 + 0.5) * CELL_WORLD
                cell_z = (rows * 0.5 - row - 0.5) * CELL_WORLD
                build_character(cell_x, cell_z, spec, animation, frame)
            state_offset += frame_count
        print(f"TRUE_ANIMATION_GEOMETRY {spec['id']}", flush=True)

    for spec in CHARACTERS:
        triangles = CHARACTER_TRIANGLES[spec["id"]]
        print(f"R20_CHARACTER_BUDGET {spec['id']} tris={triangles}", flush=True)
        if spec["kind"] == "hero" and not 3000 <= triangles <= 6000:
            raise RuntimeError(f"{spec['id']} triangle budget {triangles} outside 3000-6000")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    finalize_atlas_mesh()
    print(f"TRUE_ANIMATION_MESH vertices={len(MESH_VERTICES)} faces={len(MESH_FACES)}", flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "tools" / "true_character_rig.blend"), compress=True)
    bpy.ops.render.render(write_still=True)
    python_executable = shutil.which("python") or shutil.which("python3")
    if python_executable is None:
        raise RuntimeError("system Python is required for the selective 64px outline pass")
    subprocess.run(
        [python_executable, str(ROOT / "tools" / "postprocess_character_atlas.py"), "--atlas", str(OUTPUT)],
        check=True,
    )
    print(f"TRUE_ANIMATION_ATLAS {OUTPUT} {COLUMNS * CELL_PIXELS}x{rows * CELL_PIXELS}")
    save_hero_references(rows)


if __name__ == "__main__":
    build()
