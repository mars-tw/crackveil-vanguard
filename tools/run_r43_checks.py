"""Run the actual CI scene list locally, headless, with a reviewable result ledger."""
from pathlib import Path
import argparse
import json
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True)
parser.add_argument("--node", required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / "docs/evidence/r43-mobile/gates"
out.mkdir(parents=True, exist_ok=True)
workflow = (root / ".github/workflows/deploy-web.yml").read_text(encoding="utf-8")
block = workflow.split("scenes=(", 1)[1].split(")", 1)[0]
scenes = re.findall(r"^\s+(\w+)\s*$", block, re.M)
jobs = [(name, [args.godot, "--headless", "--fixed-fps", "60", "--path", ".", f"res://scenes/debug/{name}.tscn"]) for name in scenes]
jobs.append(("R31EndgameGate", [args.godot, "--headless", "--fixed-fps", "60", "--path", ".", "res://scenes/debug/R31EndgameGate.tscn", "--", "--qa-endgame=r31"]))
jobs += [(Path(file).stem, [args.node, "tools/" + file]) for file in ["test_r32_loading_recovery.mjs", "test_r36_webgl_state_cache.cjs", "test_r41_mobile_startup.cjs"]]
results = []
for name, command in jobs:
    try:
        result = subprocess.run(command, cwd=root, capture_output=True, timeout=150, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        output = (result.stdout + result.stderr).decode("utf-8", errors="replace")
        code = result.returncode
    except subprocess.TimeoutExpired as error:
        code, output = -1, str(error)
    output = output.replace("\r\n", "\n").replace("\r", "").rstrip() + "\n"
    (out / f"{name}.txt").write_text(output, encoding="utf-8", newline="\n")
    passed = code == 0 and "SCRIPT ERROR:" not in output
    results.append({"name": name, "command": command, "exit_code": code, "status": "VERIFIED" if passed else "BLOCKED"})
    (out / "summary.json").write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
print(f"TOTAL {sum(row['status']=='VERIFIED' for row in results)}/{len(results)}", flush=True)
raise SystemExit(0 if all(row["status"]=="VERIFIED" for row in results) else 1)
