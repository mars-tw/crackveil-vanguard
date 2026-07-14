"""Blender 5.1 headless builder for Crackveil Vanguard character animation.

This script builds every atlas frame from separately articulated low-poly body
parts.  It must be executed by Blender, not CPython:

    blender --background --python tools/generate_true_animation_atlas.py

The runtime mirrors the right-facing render for left-facing movement.  Frame
counts are kept in sync with true_animation_library.gd.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "sprites" / "true_character_atlas.png"
CELL_PIXELS = 64
COLUMNS = 8
CELL_WORLD = 2.8

ANIMATIONS = (
    ("idle", 4),
    ("walk", 8),
    ("attack", 6),
    ("hurt", 3),
    ("death", 6),
)

CHARACTERS = (
    ("hero_captain", "hero", "blade", (0.05, 0.20, 0.34, 1.0), (0.12, 0.82, 1.0, 1.0), (0.86, 0.96, 1.0, 1.0), 1.00),
    ("hero_guardian", "hero", "shield", (0.07, 0.18, 0.32, 1.0), (0.20, 0.56, 0.94, 1.0), (1.0, 0.72, 0.18, 1.0), 1.04),
    ("hero_scout", "hero", "spear", (0.06, 0.25, 0.23, 1.0), (0.18, 0.86, 0.62, 1.0), (1.0, 0.45, 0.16, 1.0), 0.94),
    ("enemy_grunt", "enemy", "club", (0.22, 0.04, 0.12, 1.0), (0.86, 0.16, 0.28, 1.0), (1.0, 0.52, 0.18, 1.0), 0.94),
    ("enemy_fast", "enemy", "claw", (0.18, 0.03, 0.24, 1.0), (0.74, 0.16, 0.92, 1.0), (0.35, 0.95, 1.0, 1.0), 0.88),
    ("enemy_tank", "enemy", "hammer", (0.18, 0.08, 0.05, 1.0), (0.76, 0.26, 0.10, 1.0), (1.0, 0.76, 0.20, 1.0), 1.10),
    ("enemy_elite_field", "enemy", "staff", (0.10, 0.04, 0.24, 1.0), (0.45, 0.18, 0.90, 1.0), (0.25, 0.95, 1.0, 1.0), 1.02),
    ("enemy_elite_split", "enemy", "axes", (0.22, 0.03, 0.10, 1.0), (0.95, 0.18, 0.42, 1.0), (1.0, 0.70, 0.18, 1.0), 1.00),
    ("enemy_elite_swift", "enemy", "claw", (0.05, 0.16, 0.22, 1.0), (0.16, 0.74, 0.90, 1.0), (0.74, 0.98, 1.0, 1.0), 0.92),
    ("enemy_boss", "enemy", "greatblade", (0.14, 0.02, 0.22, 1.0), (0.52, 0.10, 0.82, 1.0), (1.0, 0.20, 0.62, 1.0), 1.14),
)

MESH_VERTICES: list[tuple[float, float, float]] = []
MESH_FACES: list[tuple[int, ...]] = []
MESH_FACE_MATERIALS: list[int] = []
MATERIALS: list[bpy.types.Material] = []
MATERIAL_INDEX: dict[str, int] = {}

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
CUBE_VERTICES = tuple(Vector(v) for v in (
    (-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5),
    (-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5),
))
CUBE_FACES = ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7))


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = color
        mat.use_nodes = True
        principled = mat.node_tree.nodes.get("Principled BSDF")
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = 0.72
        principled.inputs["Metallic"].default_value = 0.08
    if name not in MATERIAL_INDEX:
        MATERIAL_INDEX[name] = len(MATERIALS)
        MATERIALS.append(mat)
    return mat


def append_geometry(vertices: tuple[Vector, ...] | list[Vector], faces: tuple[tuple[int, ...], ...] | list[tuple[int, ...]], mat: bpy.types.Material) -> None:
    offset = len(MESH_VERTICES)
    MESH_VERTICES.extend((vertex.x, vertex.y, vertex.z) for vertex in vertices)
    material_index = MATERIAL_INDEX[mat.name]
    for face in faces:
        MESH_FACES.append(tuple(offset + index for index in face))
        MESH_FACE_MATERIALS.append(material_index)


def sphere(_name: str, position: Vector, scale: tuple[float, float, float], mat: bpy.types.Material) -> None:
    vertices = tuple(position + Vector((vertex.x * scale[0], vertex.y * scale[1], vertex.z * scale[2])) for vertex in ICO_VERTICES)
    append_geometry(vertices, ICO_FACES, mat)


def box(_name: str, position: Vector, scale: tuple[float, float, float], mat: bpy.types.Material, angle: float = 0.0) -> None:
    rotation = Matrix.Rotation(angle, 4, "Y")
    vertices = tuple(position + rotation @ Vector((vertex.x * scale[0], vertex.y * scale[1], vertex.z * scale[2])) for vertex in CUBE_VERTICES)
    append_geometry(vertices, CUBE_FACES, mat)


def bone(_name: str, start: Vector, end: Vector, radius: float, mat: bpy.types.Material) -> None:
    delta = end - start
    midpoint = (start + end) * 0.5
    depth = max(delta.length, 0.01)
    rotation = delta.to_track_quat("Z", "Y")
    vertices: list[Vector] = []
    sides = 8
    for z in (-depth * 0.5, depth * 0.5):
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


def pose(animation: str, frame: int, kind: str) -> dict[str, Vector | float]:
    hip = Vector((0.0, 0.0, -0.12))
    chest = Vector((0.03, 0.0, 0.54))
    head = Vector((0.08, -0.01, 1.10))
    shoulder_back = Vector((-0.20, 0.12, 0.65))
    shoulder_front = Vector((0.28, -0.16, 0.65))
    knee_back = Vector((-0.16, 0.12, -0.52))
    knee_front = Vector((0.18, -0.15, -0.52))
    foot_back = Vector((-0.18, 0.12, -1.02))
    foot_front = Vector((0.28, -0.16, -1.02))
    elbow_back = Vector((-0.34, 0.12, 0.26))
    hand_back = Vector((-0.20, 0.12, -0.02))
    elbow_front = Vector((0.45, -0.18, 0.28))
    hand_front = Vector((0.52, -0.20, 0.02))
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
        attack_poses = (
            ((-0.42, 0.92), (-0.64, 0.62), (-0.82, 1.10), -0.08),
            ((-0.58, 1.04), (-0.78, 0.74), (-0.98, 1.28), -0.12),
            ((0.66, 0.54), (0.88, 0.36), (1.20, 0.12), 0.10),
            ((0.72, 0.28), (0.92, 0.10), (1.04, -0.48), 0.13),
            ((0.42, 0.42), (0.56, 0.16), (0.72, -0.28), 0.05),
            ((0.40, 0.34), (0.52, 0.04), (0.70, -0.30), 0.0),
        )
        elbow, hand, tip, lean = attack_poses[frame]
        elbow_front = Vector((elbow[0], -0.18, elbow[1]))
        hand_front = Vector((hand[0], -0.22, hand[1]))
        weapon_tip = Vector((tip[0], -0.26, tip[1]))
        elbow_back = Vector((hand_front.x - 0.26, 0.08, hand_front.z + 0.10))
        hand_back = Vector((hand_front.x - 0.08, 0.02, hand_front.z - 0.06))
        chest.x += lean
        head.x += lean * 1.25
        if frame <= 1:
            hip.z -= 0.10
            knee_front.z -= 0.05
            knee_back.z -= 0.05
        elif frame in (2, 3):
            foot_front.x += 0.26
            knee_front.x += 0.20
    elif animation == "hurt":
        recoil = (0.18, 0.34, 0.22)[frame]
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

    return locals()


def add_weapon(prefix: str, weapon: str, hand_front: Vector, hand_back: Vector, tip: Vector, accent: bpy.types.Material, dark: bpy.types.Material) -> None:
    if weapon == "shield":
        sphere(prefix + "Shield", hand_back + Vector((-0.05, -0.14, 0.06)), (0.34, 0.09, 0.40), accent)
        bone(prefix + "Sword", hand_front, tip, 0.055, dark)
    elif weapon == "axes":
        bone(prefix + "AxeA", hand_front, tip, 0.065, dark)
        box(prefix + "AxeHeadA", tip, (0.18, 0.07, 0.12), accent, 0.35)
        second_tip = hand_back + Vector((-0.34, 0.0, 0.26))
        bone(prefix + "AxeB", hand_back, second_tip, 0.06, dark)
        box(prefix + "AxeHeadB", second_tip, (0.16, 0.07, 0.11), accent, -0.3)
    elif weapon == "claw":
        direction = (tip - hand_front).normalized()
        side = Vector((-direction.z, 0.0, direction.x))
        for index in (-1, 0, 1):
            claw_tip = hand_front + direction * 0.38 + side * index * 0.09
            bone(prefix + f"Claw{index}", hand_front, claw_tip, 0.035, accent)
    else:
        thickness = 0.075 if weapon in ("hammer", "greatblade") else 0.052
        bone(prefix + "WeaponShaft", hand_front, tip, thickness, dark)
        if weapon == "hammer":
            box(prefix + "HammerHead", tip, (0.28, 0.10, 0.16), accent, 0.25)
        elif weapon in ("blade", "greatblade"):
            blade_mid = tip + (tip - hand_front).normalized() * (0.14 if weapon == "blade" else 0.22)
            bone(prefix + "Blade", tip, blade_mid, 0.10 if weapon == "greatblade" else 0.075, accent)
        elif weapon == "club":
            sphere(prefix + "ClubHead", tip, (0.15, 0.10, 0.18), accent)
        elif weapon == "staff":
            sphere(prefix + "StaffCore", tip, (0.14, 0.10, 0.14), accent)
        elif weapon == "spear":
            spear_tip = tip + (tip - hand_front).normalized() * 0.22
            bone(prefix + "SpearTip", tip, spear_tip, 0.085, accent)


def build_character(cell_x: float, cell_z: float, spec: tuple, animation: str, frame: int) -> None:
    char_id, kind, weapon, dark_color, body_color, accent_color, size = spec
    p = pose(animation, frame, kind)
    origin = Vector((cell_x, 0.0, cell_z + 0.05))

    def at(name: str) -> Vector:
        point = p[name]
        return origin + Vector((point.x * size, point.y, point.z * size))

    prefix = f"{char_id}_{animation}_{frame}_"
    dark = material(char_id + "_dark", dark_color)
    body = material(char_id + "_body", body_color)
    accent = material(char_id + "_accent", accent_color)

    # Rear limbs, torso, then front limbs establish a readable three-quarter silhouette.
    bone(prefix + "BackThigh", at("hip") + Vector((-0.10, 0.13, 0.0)), at("knee_back"), 0.105 * size, dark)
    bone(prefix + "BackShin", at("knee_back"), at("foot_back"), 0.09 * size, body)
    bone(prefix + "BackUpperArm", at("shoulder_back"), at("elbow_back"), 0.085 * size, dark)
    bone(prefix + "BackForearm", at("elbow_back"), at("hand_back"), 0.075 * size, body)
    bone(prefix + "Torso", at("hip"), at("chest"), 0.30 * size, body)
    sphere(prefix + "ChestArmor", at("chest") + Vector((0.02, -0.02, -0.08)), (0.34 * size, 0.20, 0.36 * size), dark)
    sphere(prefix + "Head", at("head"), (0.28 * size, 0.22, 0.29 * size), body)
    box(prefix + "Visor", at("head") + Vector((0.15 * size, -0.20, 0.02)), (0.16 * size, 0.035, 0.07 * size), accent, 0.0)
    if kind == "enemy":
        horn_start = at("head") + Vector((-0.10 * size, 0.02, 0.20 * size))
        horn_tip = horn_start + Vector((-0.20 * size, 0.0, 0.20 * size))
        bone(prefix + "Horn", horn_start, horn_tip, 0.045 * size, accent)
    bone(prefix + "FrontThigh", at("hip") + Vector((0.11, -0.16, 0.0)), at("knee_front"), 0.115 * size, body)
    bone(prefix + "FrontShin", at("knee_front"), at("foot_front"), 0.095 * size, accent)
    sphere(prefix + "FrontBoot", at("foot_front") + Vector((0.08 * size, -0.01, 0.0)), (0.16 * size, 0.12, 0.09 * size), dark)
    sphere(prefix + "BackBoot", at("foot_back") + Vector((0.08 * size, 0.0, 0.0)), (0.15 * size, 0.11, 0.08 * size), dark)
    bone(prefix + "FrontUpperArm", at("shoulder_front"), at("elbow_front"), 0.095 * size, body)
    bone(prefix + "FrontForearm", at("elbow_front"), at("hand_front"), 0.08 * size, accent)
    sphere(prefix + "FrontHand", at("hand_front"), (0.10 * size, 0.08, 0.10 * size), body)
    add_weapon(prefix, weapon, at("hand_front"), at("hand_back"), at("weapon_tip"), accent, dark)


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
    scene.render.filter_size = 0.75
    scene.view_settings.look = "AgX - Medium High Contrast"

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
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.045, 0.055, 0.08, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scene.world = world

    sun_data = bpy.data.lights.new("AtlasSun", type="SUN")
    sun_data.energy = 2.2
    sun_data.angle = math.radians(25.0)
    sun = bpy.data.objects.new("AtlasSun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(35.0), math.radians(-20.0), math.radians(-35.0))


def finalize_atlas_mesh() -> None:
    mesh = bpy.data.meshes.new("TrueCharacterAtlasGeometry")
    mesh.from_pydata(MESH_VERTICES, [], MESH_FACES)
    mesh.update()
    for mat in MATERIALS:
        mesh.materials.append(mat)
    for polygon, material_index in zip(mesh.polygons, MESH_FACE_MATERIALS):
        polygon.material_index = material_index
    atlas_object = bpy.data.objects.new("TrueCharacterAtlasGeometry", mesh)
    bpy.context.collection.objects.link(atlas_object)


def build() -> None:
    rows = len(CHARACTERS) * len(ANIMATIONS)
    configure_scene(rows)
    for character_index, spec in enumerate(CHARACTERS):
        for animation_index, (animation, frame_count) in enumerate(ANIMATIONS):
            row = character_index * len(ANIMATIONS) + animation_index
            cell_z = (rows * 0.5 - row - 0.5) * CELL_WORLD
            for frame in range(frame_count):
                cell_x = (frame - COLUMNS * 0.5 + 0.5) * CELL_WORLD
                build_character(cell_x, cell_z, spec, animation, frame)
        print(f"TRUE_ANIMATION_GEOMETRY {spec[0]}", flush=True)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    finalize_atlas_mesh()
    print(f"TRUE_ANIMATION_MESH vertices={len(MESH_VERTICES)} faces={len(MESH_FACES)}", flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "tools" / "true_character_rig.blend"), compress=True)
    bpy.ops.render.render(write_still=True)
    print(f"TRUE_ANIMATION_ATLAS {OUTPUT} {COLUMNS * CELL_PIXELS}x{rows * CELL_PIXELS}")


if __name__ == "__main__":
    build()
