#!/usr/bin/env python3
"""Verify the untouched R25 imagegen masters with the official c2pa-python SDK."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import c2pa


ROOT = Path(__file__).resolve().parents[1]
MASTER_DIR = ROOT / "docs" / "evidence" / "R25" / "masters"
RAW_DIR = ROOT / "docs" / "evidence" / "R25" / "c2pa" / "raw"
SUMMARY_PATH = ROOT / "docs" / "evidence" / "R25" / "c2pa_verification.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect_codes(node: Any, key: str) -> list[str]:
    if not isinstance(node, dict):
        return []
    entries = node.get(key, [])
    if not isinstance(entries, list):
        return []
    return sorted(
        str(entry.get("code", ""))
        for entry in entries
        if isinstance(entry, dict) and entry.get("code")
    )


def verify(path: Path) -> dict[str, Any]:
    with c2pa.Reader(path) as reader:
        payload = json.loads(reader.json())
        validation_state = str(reader.get_validation_state())
        sdk_valid = bool(reader.is_valid)
        embedded = bool(reader.is_embedded())

    active_label = str(payload.get("active_manifest", ""))
    active = payload.get("manifests", {}).get(active_label, {})
    created_action: dict[str, Any] | None = None
    for assertion in active.get("assertions", []):
        if not isinstance(assertion, dict) or assertion.get("label") != "c2pa.actions.v2":
            continue
        for action in assertion.get("data", {}).get("actions", []):
            if isinstance(action, dict) and action.get("action") == "c2pa.created":
                created_action = action
                break

    software_agent = (created_action or {}).get("softwareAgent", {})
    agent_name = str(software_agent.get("name", ""))
    agent_version = str(software_agent.get("version", ""))
    normalized_agent = f"{agent_name} {agent_version}".strip()

    active_results = payload.get("validation_results", {}).get("activeManifest", {})
    success_codes = collect_codes(active_results, "success")
    failure_codes = collect_codes(active_results, "failure")
    informational_codes = collect_codes(active_results, "informational")
    required_codes = {"claimSignature.validated", "assertion.dataHash.match"}
    passed = all(
        (
            embedded,
            sdk_valid,
            validation_state.lower() == "valid",
            bool(active_label),
            agent_name == "gpt-image",
            agent_version.startswith("2."),
            required_codes.issubset(success_codes),
        )
    )

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    (RAW_DIR / f"{path.stem}.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return {
        "master": path.relative_to(ROOT).as_posix(),
        "sha256": sha256(path),
        "embedded": embedded,
        "validation_state": validation_state,
        "sdk_valid": sdk_valid,
        "softwareAgent": {
            "name": agent_name,
            "version": agent_version,
            "normalized": normalized_agent,
        },
        "digitalSourceType": str((created_action or {}).get("digitalSourceType", "")),
        "signature": active.get("signature_info", {}),
        "required_success_codes": sorted(required_codes),
        "success_codes": success_codes,
        "informational_codes": informational_codes,
        "failure_codes": failure_codes,
        "passed": passed,
    }


def main() -> int:
    masters = sorted(MASTER_DIR.glob("*_master.png"))
    if len(masters) != 9:
        raise SystemExit(f"R25_C2PA_FAIL expected=9 actual={len(masters)}")
    records = [verify(path) for path in masters]
    summary = {
        "schema": "rift-r25-c2pa-verification.v1",
        "sdk": "c2pa-python",
        "expected_softwareAgent": {"name": "gpt-image", "version_prefix": "2."},
        "masters": records,
        "all_passed": all(record["passed"] for record in records),
    }
    SUMMARY_PATH.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY_PATH.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    for record in records:
        print(
            "R25_C2PA_MASTER "
            f"file={Path(record['master']).name} "
            f"agent={record['softwareAgent']['normalized']} "
            f"state={record['validation_state']} pass={str(record['passed']).lower()}"
        )
    if not summary["all_passed"]:
        print(f"R25_C2PA_FAIL summary={SUMMARY_PATH.relative_to(ROOT).as_posix()}")
        return 1
    print(f"R25_C2PA_PASS masters=9 summary={SUMMARY_PATH.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
