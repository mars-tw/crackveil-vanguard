"""Serial Hyper3D Rodin production batch for cv art-r21.

The Blender add-on exposes the Hyper3D text generator over the socket as
``create_rodin_job``.  This is the implementation behind the MCP-facing
``generate_hyper3d_model_via_text`` capability described in the task.
"""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from blender_mcp_client import send_command


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
EVIDENCE = ROOT / "docs" / "evidence" / "art_r21"
MANIFEST_PATH = EVIDENCE / "rodin_manifest.json"
LINE_MENDER_PROMPT = (
    "stylized fantasy game healer hero, line mender, single seamless connected full-body "
    "character in relaxed A-pose, VISIBLE HEAD with kind face, short hair, hood resting DOWN "
    "on shoulders (not covering head), head firmly attached to neck, teal mint healer robes "
    "with amber trim, thread spool at belt, long needle staff, hand-painted stylized textures, "
    "arcane style"
)

HEROES = (
    (
        "rift_sniper",
        "wide-brim hat, long rail rifle, navy/teal coat with lime accents, monocle",
        "navy and teal long coat, lime energy accents, long rail rifle and visible monocle",
    ),
    (
        "void_weaver",
        "flowing violet void hair, lavender veil shawl, crescent moon staff",
        "violet and lavender layered robes with cyan arcane glow",
    ),
    (
        "arc_scout",
        "wind scarf, visor, long arc spear",
        "forest green and mint scout outfit with orange accents",
    ),
    (
        "echo_singer",
        "fan-shaped hair, shoulder resonators, tuning-fork staff",
        "plum and rose performance robes with gold accents",
    ),
    (
        "ember_grenadier",
        "sturdy build, blast pack backpack, grenade rack, launcher",
        "brown and ember demolitions outfit with brass details",
    ),
    (
        "line_mender",
        "hood, thread spool at belt, needle staff",
        "teal and mint healer robes with amber trim",
    ),
    (
        "orbit_guard",
        "fin helmet, round orbit shield, shoulder plates",
        "indigo and lilac armor with cyan arcane glow",
    ),
    (
        "pulse_artificer",
        "goggles on head, tool backpack, pulse cannon gauntlet",
        "blue and steel engineer outfit with coral accents",
    ),
    (
        "rift_shepherd",
        "lantern hood cloak, caged lantern staff",
        "indigo and teal mystic robes with ice-blue glow",
    ),
)


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def prompt_for(description: str, costume: str, attempt: int) -> str:
    prompt = (
        f"stylized fantasy game hero, {description}, single seamless connected full-body "
        "character standing in relaxed A-pose, head firmly attached to neck and shoulders, "
        f"feet planted on ground, one continuous watertight body, {costume}, hand-painted "
        "stylized textures, arcane league of legends style, game character turnaround reference"
    )
    if attempt > 1:
        prompt += (
            ", strict production anatomy correction, torso neck head hips legs boots are fused into "
            "one contiguous manifold hero body, no floating head, no detached feet, no duplicate body, "
            "no separate limbs, accessories held close to hands"
        )
    return prompt


def result_of(response: dict[str, Any]) -> dict[str, Any]:
    if response.get("status") != "success":
        raise RuntimeError(str(response.get("message", response)))
    result = response.get("result")
    if not isinstance(result, dict):
        raise RuntimeError(f"Unexpected MCP result: {result!r}")
    return result


def execute(statement: str) -> dict[str, Any]:
    tools_path = str(TOOLS).replace("\\", "/")
    code = (
        f"import sys, importlib; sys.path.insert(0, {tools_path!r}); "
        "import art_r21_blender_ops as ops; importlib.reload(ops); " + statement
    )
    return result_of(send_command("execute_code", {"code": code}, response_timeout=600.0))


def save_manifest(manifest: dict[str, Any]) -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def poll_until_done(subscription_key: str, hero_id: str) -> list[str]:
    deadline = time.monotonic() + 45 * 60
    while time.monotonic() < deadline:
        result = result_of(send_command(
            "poll_rodin_job_status",
            {"subscription_key": subscription_key},
            response_timeout=120.0,
        ))
        statuses = list(result.get("status_list", []))
        print(f"RODIN_POLL hero={hero_id} statuses={','.join(statuses)}", flush=True)
        if statuses and all(status == "Done" for status in statuses):
            return statuses
        if any(status.lower() in {"failed", "error", "cancelled"} for status in statuses):
            raise RuntimeError(f"Rodin job failed: {statuses}")
        time.sleep(12.0)
    raise TimeoutError(f"Rodin job timed out for {hero_id}")


def regenerate_line_mender() -> None:
    """R21.1 targeted repair; never spends generation quota on other heroes."""
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8")) if MANIFEST_PATH.exists() else {
        "round": "cv art-r21.1",
        "generator": "Hyper3D Rodin via Blender MCP",
        "bbox_condition": [1, 1, 2],
        "heroes": {},
    }
    manifest["round"] = "cv art-r21.1"
    manifest["r21_1_started_at"] = timestamp()
    output = ROOT / "assets" / "rodin" / "hero_line_mender.glb"
    qc_path = EVIDENCE / "qc" / "line_mender.json"
    for attempt in range(1, 4):
        prompt = LINE_MENDER_PROMPT
        if attempt > 1:
            prompt += (
                ", anatomy correction retry: clearly modeled face, skull, hair and neck must occupy "
                "the highest 15 percent of the body and remain fused to the torso, no headless robe"
            )
        print(f"RODIN_R21_1_GENERATE hero=line_mender attempt={attempt}", flush=True)
        generated = result_of(send_command(
            "create_rodin_job",
            {"text_prompt": prompt, "bbox_condition": [1, 1, 2]},
            response_timeout=900.0,
        ))
        task_uuid = str(generated.get("uuid", ""))
        subscription_key = str(generated.get("jobs", {}).get("subscription_key", ""))
        if not task_uuid or not subscription_key:
            raise RuntimeError(f"Rodin response lacks job identifiers: {generated}")
        entry = {
            "status": "polling",
            "attempts": attempt,
            "task_uuid": task_uuid,
            "prompt": prompt,
            "revision": "r21.1",
        }
        manifest.setdefault("heroes", {})["line_mender"] = entry
        save_manifest(manifest)
        poll_until_done(subscription_key, "line_mender")
        execute("ops.clear_scene()")
        imported = result_of(send_command(
            "import_generated_asset",
            {"name": "hero_line_mender_rodin_r21_1", "task_uuid": task_uuid},
            response_timeout=900.0,
        ))
        if not imported.get("succeed"):
            entry.update({"status": "import_error", "error": imported.get("error", str(imported))})
            save_manifest(manifest)
            continue
        execute("ops.qc_and_export('line_mender')")
        qc = json.loads(qc_path.read_text(encoding="utf-8"))
        entry.update({
            "status": "passed" if qc.get("pass") else "qc_failed",
            "qc": str(qc_path.relative_to(ROOT)).replace("\\", "/"),
            "glb": str(output.relative_to(ROOT)).replace("\\", "/") if qc.get("pass") else None,
            "bytes": output.stat().st_size if qc.get("pass") else None,
            "qc_summary": {
                key: qc.get(key) for key in (
                    "mesh_objects", "loose_components", "main_component_ratio",
                    "head_group_vertices", "minimum_head_vertices", "head_group_width_ratio",
                    "head_compact", "head_present",
                    "head_connected_to_torso", "feet_planted", "failure_reasons",
                )
            },
        })
        save_manifest(manifest)
        if qc.get("pass"):
            manifest["r21_1_completed_at"] = timestamp()
            manifest["missing"] = [item for item in manifest.get("missing", []) if item != "line_mender"]
            save_manifest(manifest)
            print(
                f"RODIN_R21_1_PASS hero=line_mender attempt={attempt} "
                f"head_vertices={qc['head_group_vertices']} bytes={output.stat().st_size}",
                flush=True,
            )
            return
        print(f"RODIN_R21_1_QC_REJECT attempt={attempt} reasons={qc['failure_reasons']}", flush=True)
    raise RuntimeError("line_mender failed head-presence QC after 3 Rodin attempts")


def main() -> None:
    manifest: dict[str, Any] = {
        "round": "cv art-r21",
        "generator": "Hyper3D Rodin via Blender MCP",
        "bbox_condition": [1, 1, 2],
        "started_at": timestamp(),
        "heroes": {},
        "quota_exhausted": False,
        "missing": [],
    }
    if MANIFEST_PATH.exists():
        previous = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        manifest["heroes"].update(previous.get("heroes", {}))
    for hero_id, description, costume in HEROES:
        output = ROOT / "assets" / "rodin" / f"hero_{hero_id}.glb"
        qc_path = EVIDENCE / "qc" / f"{hero_id}.json"
        if output.exists() and qc_path.exists():
            qc = json.loads(qc_path.read_text(encoding="utf-8"))
            if qc.get("pass"):
                manifest["heroes"][hero_id] = {
                    **manifest["heroes"].get(hero_id, {}),
                    "status": "passed",
                    "attempts": manifest["heroes"].get(hero_id, {}).get("attempts", 1),
                    "task_uuid": manifest["heroes"].get(hero_id, {}).get("task_uuid", "preexisting-session"),
                    "qc": str(qc_path.relative_to(ROOT)).replace("\\", "/"),
                    "glb": str(output.relative_to(ROOT)).replace("\\", "/"),
                    "bytes": output.stat().st_size,
                }
                print(f"RODIN_SKIP hero={hero_id} reason=existing_pass", flush=True)
                save_manifest(manifest)
                continue
        passed = False
        for attempt in (1, 2):
            prompt = prompt_for(description, costume, attempt)
            print(f"RODIN_GENERATE hero={hero_id} attempt={attempt}", flush=True)
            response = send_command(
                "create_rodin_job",
                {"text_prompt": prompt, "bbox_condition": [1, 1, 2]},
                response_timeout=900.0,
            )
            try:
                generated = result_of(response)
            except Exception as error:
                generated = {"error": str(error)}
            error_text = json.dumps(generated, ensure_ascii=False)
            if generated.get("error") or generated.get("statusCode"):
                manifest["heroes"][hero_id] = {
                    "status": "generation_error",
                    "attempts": attempt,
                    "error": error_text,
                    "prompt": prompt,
                }
                quota_words = ("quota", "credit", "free trial", "limit", "insufficient", "exhaust")
                if any(word in error_text.lower() for word in quota_words):
                    manifest["quota_exhausted"] = True
                    print(f"RODIN_QUOTA_EXHAUSTED hero={hero_id} error={error_text}", flush=True)
                    break
                print(f"RODIN_GENERATION_ERROR hero={hero_id} error={error_text}", flush=True)
                continue
            task_uuid = str(generated.get("uuid", ""))
            subscription_key = str(generated.get("jobs", {}).get("subscription_key", ""))
            if not task_uuid or not subscription_key:
                manifest["heroes"][hero_id] = {
                    "status": "generation_error",
                    "attempts": attempt,
                    "error": "missing task uuid or subscription key",
                    "response": generated,
                    "prompt": prompt,
                }
                continue
            manifest["heroes"][hero_id] = {
                "status": "polling",
                "attempts": attempt,
                "task_uuid": task_uuid,
                "prompt": prompt,
            }
            save_manifest(manifest)
            poll_until_done(subscription_key, hero_id)
            execute("ops.clear_scene()")
            imported = result_of(send_command(
                "import_generated_asset",
                {"name": f"hero_{hero_id}_rodin", "task_uuid": task_uuid},
                response_timeout=900.0,
            ))
            if not imported.get("succeed"):
                manifest["heroes"][hero_id].update({
                    "status": "import_error",
                    "error": imported.get("error", str(imported)),
                })
                save_manifest(manifest)
                continue
            execute(f"ops.qc_and_export({hero_id!r})")
            qc = json.loads(qc_path.read_text(encoding="utf-8"))
            manifest["heroes"][hero_id].update({
                "status": "passed" if qc.get("pass") else "qc_failed",
                "qc": str(qc_path.relative_to(ROOT)).replace("\\", "/"),
                "glb": str(output.relative_to(ROOT)).replace("\\", "/") if output.exists() else None,
                "bytes": output.stat().st_size if output.exists() else None,
                "qc_summary": {
                    key: qc.get(key)
                    for key in (
                        "mesh_objects", "loose_components", "main_component_ratio",
                        "main_reaches_head", "main_reaches_feet", "feet_planted",
                        "failure_reasons",
                    )
                },
            })
            save_manifest(manifest)
            if qc.get("pass"):
                print(
                    f"RODIN_PASS hero={hero_id} components={qc['loose_components']} "
                    f"main={qc['main_component_ratio']:.2%} bytes={output.stat().st_size}",
                    flush=True,
                )
                passed = True
                break
            print(f"RODIN_QC_REJECT hero={hero_id} reasons={qc['failure_reasons']}", flush=True)
        if not passed:
            manifest["missing"].append(hero_id)
        if manifest["quota_exhausted"]:
            remaining = [item[0] for item in HEROES if item[0] not in manifest["heroes"]]
            manifest["missing"].extend(remaining)
            break
    manifest["missing"] = sorted(set(manifest["missing"]))
    manifest["completed_at"] = timestamp()
    save_manifest(manifest)
    print(
        f"RODIN_BATCH_DONE passed={sum(v.get('status') == 'passed' for v in manifest['heroes'].values())} "
        f"missing={','.join(manifest['missing']) or 'none'} quota_exhausted={manifest['quota_exhausted']}",
        flush=True,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--hero", choices=("all", "line_mender"), default="all")
    args = parser.parse_args()
    regenerate_line_mender() if args.hero == "line_mender" else main()
