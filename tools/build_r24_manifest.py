#!/usr/bin/env python3
"""Assemble the auditable cv R24 runtime asset manifest."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "docs" / "evidence" / "R24_art"
OUTPUT = ROOT / "assets" / "art" / "r24" / "manifest.json"


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> int:
    matte = read_json(EVIDENCE / "matte_manifest.json")
    build = read_json(EVIDENCE / "asset_build_results.json")
    manual = read_json(EVIDENCE / "manual_retouch_log.json")
    gates = read_json(EVIDENCE / "art_gate_summary.json")
    minutes = {row["id"]: row["actual_minutes"] for row in manual["assets"]}
    prompt_ids = {row["id"]: row["prompt_id"] for row in matte["samples"]}

    cutouts = []
    for row in build["cutouts"]:
        asset_id = row["id"]
        source = EVIDENCE / "generated_sources" / f"{asset_id}_opaque.png"
        normalized = EVIDENCE / "masters_opaque" / f"{asset_id}.png"
        mask = EVIDENCE / "masks" / f"{asset_id}_mask.png"
        master = ROOT / row["master_rgba"]
        runtime = ROOT / row["runtime"]
        cutouts.append(
            {
                "id": asset_id,
                "kind": row["kind"],
                "prompt_id": prompt_ids[asset_id],
                "manual_edge_minutes_actual": minutes[asset_id],
                "source_opaque": rel(source),
                "normalized_opaque": rel(normalized),
                "matte_mask": rel(mask),
                "master_rgba": row["master_rgba"],
                "runtime_rgba": row["runtime"],
                "manual_qa": row["manual_qa"],
                "sha256": {
                    "source_opaque": sha256(source),
                    "normalized_opaque": sha256(normalized),
                    "matte_mask": sha256(mask),
                    "master_rgba": sha256(master),
                    "runtime_rgba": sha256(runtime),
                },
            }
        )

    keyart = []
    for row in build["keyart"]:
        key_id = row["id"]
        source_name = (
            "keyart_desktop_opaque.png"
            if key_id == "menu_keyart_desktop"
            else "keyart_mobile_safe_opaque.png"
        )
        source = EVIDENCE / "generated_sources" / source_name
        runtime = ROOT / row["path"]
        keyart.append(
            {
                **row,
                "prompt_id": "R24-K01" if key_id == "menu_keyart_desktop" else "R24-K02",
                "identity_lock_references": [
                    "docs/evidence/art_r21/threeview/hero_captain.png",
                    "docs/evidence/art_r21/threeview/hero_orbit_guard.png",
                    "docs/evidence/art_r21/threeview/hero_rift_sniper.png",
                ],
                "source_opaque": rel(source),
                "sha256": {
                    "source_opaque": sha256(source),
                    "runtime_rgb": sha256(runtime),
                },
            }
        )

    generation = matte["generation"]
    payload = {
        "schema_version": "cv-r24-runtime-manifest.v1",
        "release": "cv R24",
        "game_version": "0.17.1-r24",
        "date": "2026-07-17",
        "model_slugs": {
            "generation_requested": generation["requested_model_slug"],
            "generation_actual": generation["actual_model_slug"],
            "generation_provenance": generation["provenance_slug"],
            "background_removal": generation["matte_model_slug"],
            "calibration_pipeline": generation["pipeline_slug"],
        },
        "prompt_record": "docs/evidence/R24_art/prompts/R24_PROMPTS.md",
        "manual_retouch_log": "docs/evidence/R24_art/manual_retouch_log.json",
        "gate_summary": "docs/evidence/R24_art/art_gate_summary.json",
        "all_art_gates_pass": bool(gates["pass"]),
        "cutouts": cutouts,
        "keyart": keyart,
        "integration": {
            "orbit_blades": "resources/weapons/orbit_blades.tres",
            "boomerang": "resources/weapons/rift_shield_boomerang.tres",
            "projectile_rendering": [
                "scripts/projectiles/orbit_projectile.gd",
                "scripts/projectiles/projectile.gd",
                "scripts/vfx/death_burst.gd",
            ],
            "main_menu": "scripts/ui/main_menu.gd",
        },
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"R24_MANIFEST_PASS cutouts={len(cutouts)} keyart={len(keyart)} "
        f"models={generation['actual_model_slug']}+{generation['matte_model_slug']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
