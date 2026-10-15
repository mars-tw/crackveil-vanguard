"""Verify release strings, unchanged store counters, and the requested secret scan."""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--previous-version", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / "docs/evidence/r43-mobile"
head = lambda name: subprocess.check_output(["git", "show", "HEAD:" + name], cwd=root).decode("utf-8")
version = re.search(r'^config/version="([^"]+)"', (root / "project.godot").read_text(encoding="utf-8"), re.M).group(1)
before = json.loads(head("native/build-config.json"))
after = json.loads((root / "native/build-config.json").read_text(encoding="utf-8"))
protected = all(after[key] == value for key, value in before.items() if key != "sourceVersion")
native_presets = (root / "export_presets.cfg").read_text(encoding="utf-8").split("[preset.1]", 1)[1] == head("export_presets.cfg").split("[preset.1]", 1)[1]
old_runtime = []
tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode("utf-8").split("\0")
for name in tracked:
    if not name or Path(name).parts[0] in {"docs", ".github"}:
        continue
    file = root / name
    if file.suffix in {".md", ".py", ".gd", ".tscn", ".cfg", ".godot", ".json", ".mjs", ".cjs"} and args.previous_version in file.read_text(encoding="utf-8", errors="replace"):
        old_runtime.append(name)

# Stream all repository files including ignored local exports; never read any
# path outside this root. Only .git and node_modules are excluded as requested.
pattern = re.compile(rb"sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}")
secret_hits = []
scanned = 0
for directory, dirs, files in os.walk(root):
    dirs[:] = [name for name in dirs if name not in {".git", "node_modules"}]
    for name in files:
        file = Path(directory) / name
        if file.is_symlink():
            raise RuntimeError("Review symlink scope before scanning: " + str(file.relative_to(root)))
        tail = b""
        with file.open("rb") as stream:
            while block := stream.read(65536):
                chunk = tail + block
                # ASCII lowercasing preserves grep -i semantics and allows the
                # regex engine's literal-prefix scan on large local exports.
                if pattern.search(chunk.lower()):
                    secret_hits.append(str(file.relative_to(root)))
                    break
                tail = chunk[-128:]
        scanned += 1
result = {"version":version, "nativeBuild":after["nativeBuild"], "nativeVersion":after["nativeVersion"], "sourceVersion":after["sourceVersion"], "protected_native_config_unchanged":protected, "ios_android_preset_sections_unchanged":native_presets, "old_runtime_version_hits":old_runtime, "secret_scan_files":scanned, "secret_scan_hit_paths":secret_hits}
result["status"] = "VERIFIED" if protected and native_presets and after["sourceVersion"] == version and not old_runtime and not secret_hits else "BLOCKED"
(out / "release-audit.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False))
raise SystemExit(0 if result["status"] == "VERIFIED" else 1)
