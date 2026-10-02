#!/usr/bin/env python3
"""Repair stale script/shader links using their committed Godot UID sidecars."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r'(\[ext_resource[^\n]*?\buid=")([^"]+)("[^\n]*?\bpath="res://)([^"]+)("[^\n]*\])')

def main() -> None:
    updated = []
    for suffix in ("*.tscn", "*.tres"):
        for source in ROOT.rglob(suffix):
            if any(part in {".godot", "export", "exports", ".audit-tmp"} for part in source.relative_to(ROOT).parts):
                continue
            contents = source.read_text(encoding="utf-8")
            def replace(match):
                sidecar = ROOT / (match[4] + ".uid")
                if not sidecar.is_file():
                    return match[0]
                uid = sidecar.read_text(encoding="utf-8").strip()
                if not re.fullmatch(r"uid://[a-z0-9]+", uid):
                    return match[0]
                return match[1] + uid + match[3] + match[4] + match[5]
            repaired = LINK.sub(replace, contents)
            if repaired != contents:
                source.write_text(repaired, encoding="utf-8", newline="\n")
                updated.append(source.relative_to(ROOT).as_posix())
    print(f"RESOURCE_UID_SYNC repaired_files={len(updated)}")
    for path in updated:
        print(path)

if __name__ == "__main__":
    main()
