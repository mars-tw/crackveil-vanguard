#!/usr/bin/env python3
"""Verify the shipped R36 art and release wiring on a clean, portable checkout.

R25 masters retain their separate C2PA archive gate. This gate validates the
current loop-world assets rather than requiring obsolete parallax references
inside the current Arena background implementation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# Fingerprints of the frozen runtime assets that were actually played and
# reviewed for this release. Asset replacements require an explicit update.
RUNTIME_SHA256 = {
    "assets/art/r33/r33_keyart.png": "04c40aa03c257a251aa42e4a1758445acd25b88427de3c68a951b971087049bd",
    "assets/art/r34/world_map.png": "178e0204d09bfd445804809a7cc17e7bf33c0142aefac0d57c11bac440cf4f0a",
    "assets/sprites/r35_character_atlas.png": "5160884e9065812b791c21552f959bbbc47cc2efc7df826a2b7150c4ce01426f",
    "assets/art/r35/r35_skill_fx_atlas.png": "521f307b2755b7351e083aee9b62c60a7643b419944f9467ec97403ee45efa61",
    "assets/art/r36/tile_stone.png": "41c15b8d3aeb00dad48a363d4725559a7e911f915132f124616e14734f220971",
    "assets/art/r36/tile_grass.png": "fc94c79271949880f74c39c7ef4b583cac0d48673dd4e47f0ba4455d07b2cecf",
    "assets/art/r36/tile_basalt.png": "1d5f705a34c1951939abe7ab74ebb84cb737c7fede0253eeda06b23a5678e246",
    "assets/art/r36/tile_frost.png": "edd466ef080f92d1f99a06a7aab463e25599fef28aebb124456f3439017b043a",
    "assets/art/r36/landmarks.png": "f705cc48b91a0e5e3359166514221703af5a898ebb242b4070cd56b7f4d48767",
    "assets/pets/r36/pet_atlas.png": "0b086f97619ae2769bc1c1b0e7f91ec4840e8075a50a635be8788cd437fbee87",
    "assets/audio/critical_impact.wav": "730995d49cf96080aad02aa55159c92bf5d111813c8e69244e58a1270365ce66",
}
REQUIRED_WEB_FILES = ("web/webgl_state_cache.js", "web/loading_recovery.mjs", "web/offline.html")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(project_root: Path) -> list[dict]:
    checks: list[dict] = []

    def check(ok: bool, name: str, detail: str = "") -> None:
        checks.append({"name": name, "passed": bool(ok), "detail": detail})

    for relative, expected in RUNTIME_SHA256.items():
        path = project_root / relative
        actual = sha256(path) if path.is_file() else "missing"
        check(actual == expected, "runtime_hash:" + relative, actual)

    for relative in REQUIRED_WEB_FILES:
        path = project_root / relative
        check(path.is_file() and path.stat().st_size > 0, "web_dependency:" + relative)

    # Historical absolute origin paths are provenance metadata, never the
    # filesystem lookup mechanism. Resolve source names within this repo.
    for revision in ("r35", "r36"):
        relative = f"assets/art/{revision}/source_manifest.json"
        try:
            records = json.loads((project_root / relative).read_text(encoding="utf-8"))
            check(isinstance(records, list) and len(records) == (4 if revision == "r35" else 5), "manifest_shape:" + relative)
            for record in records:
                name = str(record["name"])
                safe_name = Path(name).name == name and not any(c in name for c in "/\\")
                source = project_root / f"assets/art/{revision}/sources" / name
                expected = str(record["sha256"]).lower()
                actual = sha256(source) if safe_name and source.is_file() else "missing"
                check(safe_name and actual == expected and source.stat().st_size == int(record["bytes"]), f"source_manifest_hash:{revision}/{name}", actual)
        except (OSError, ValueError, KeyError, TypeError) as error:
            check(False, "manifest_read:" + relative, str(error))

    try:
        pets = json.loads((project_root / "assets/pets/r36/pose_manifest.json").read_text(encoding="utf-8"))
        source = project_root / "assets/pets/r36/pet_sheet_original.png"
        actual = sha256(source) if source.is_file() else "missing"
        check(actual == str(pets["source_sha256"]).lower(), "pet_source_manifest_hash", actual)
        poses = pets["poses"]
        identities = {(str(pose["pet"]), int(pose["pose"])) for pose in poses}
        check(len(poses) == 36 and len(identities) == 36 and all(sum(pet == name for pet, _ in identities) == 12 for name in ("fire_fox", "thunder_bird", "spirit_rabbit")), "pet_original_poses", f"poses={len(poses)} distinct={len(identities)}")
    except (OSError, ValueError, KeyError, TypeError) as error:
        check(False, "pet_manifest_read", str(error))

    try:
        project = (project_root / "project.godot").read_text(encoding="utf-8")
        finalizer = (project_root / "tools/finalize_r25_web_export.py").read_text(encoding="utf-8")
        preset = (project_root / "export_presets.cfg").read_text(encoding="utf-8")
        project_match = re.search(r'^config/version="([^"]+)"', project, re.M)
        finalizer_match = re.search(r'^RELEASE = "([^"]+)"', finalizer, re.M)
        version = project_match.group(1) if project_match else "missing"
        check(finalizer_match is not None and version == finalizer_match.group(1) and f'<meta name=\\"rift-cache-version\\" content=\\"{version}\\"' in preset, "release_markers_match", version)
        check('extends "res://scripts/arena/r36_loop_world_background.gd"' in (project_root / "scripts/arena/arena_background.gd").read_text(encoding="utf-8"), "current_loop_world_entrypoint")
    except OSError as error:
        check(False, "release_wiring_read", str(error))

    # Godot 4.4+ script/shader UIDs must travel with their source files.
    uid_missing = [path.relative_to(project_root).as_posix() for path in (project_root / "scripts").rglob("*") if path.suffix in (".gd", ".gdshader") and not Path(str(path) + ".uid").is_file()]
    check(not uid_missing, "script_shader_uid_pairs", ",".join(uid_missing))
    workflow = (project_root / ".github/workflows/deploy-web.yml").read_text(encoding="utf-8")
    match = re.search(r"scenes=\((.*?)\)", workflow, re.S)
    scenes = re.findall(r"^\s*([A-Za-z0-9]+)\s*$", match.group(1), re.M) if match else []
    missing_scenes = [name for name in scenes if not (project_root / f"scenes/debug/{name}.tscn").is_file()]
    check(bool(scenes) and not missing_scenes, "ci_scene_files_present", f"scenes={len(scenes)} missing={missing_scenes}")
    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=ROOT)
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()
    checks = validate(args.project_root.resolve())
    passed = all(item["passed"] for item in checks)
    for item in checks:
        if not item["passed"]:
            print(f"R37_RELEASE_ASSET_FAIL {item['name']} {item['detail']}")
    print(f"R37_RELEASE_ASSETS_{'PASS' if passed else 'FAIL'} checks={len(checks)} failed={sum(not item['passed'] for item in checks)}")
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps({"passed": passed, "checks": checks}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
