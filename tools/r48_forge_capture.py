#!/usr/bin/env python3
"""R48 B line: export the Web build, serve it locally and run the gear-core capture.

Re-runnable end to end:
  python tools/r48_forge_capture.py --godot <Godot console exe> --appdata <scratch dir>

1. Imports twice and exports the "Web" preset exactly like deploy-web.yml
   (``--export-release "Web"`` then ``finalize_r25_web_export.py``) into
   ``export/r48-forge-web`` (git-ignored, excluded from the pack); the
   finalizer's receipt goes to the scratch folder, not docs/evidence.
2. Serves it on 127.0.0.1 only and runs ``tools/r48_forge_capture.cjs``
   (headless Chromium, software rendering) for desktop 1280x720 and phone
   844x390. Screenshots and the measurement JSON land in docs/content/r48.
3. Deletes the export folder afterwards (``--keep-export`` keeps it).

Godot's APPDATA/LOCALAPPDATA are pointed at ``--appdata`` so editor settings
and user:// saves stay out of the real profile; the Web export template must
be at ``<appdata>/roaming/Godot/export_templates/<version>/``.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPORT = ROOT / "export" / "r48-forge-web"
OUT = ROOT / "docs" / "content" / "r48"


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *args):  # noqa: D401 - keep the console readable
        pass


def run(command: list[str], env: dict[str, str], log: Path) -> None:
    with log.open("a", encoding="utf-8") as stream:
        stream.write("$ " + " ".join(command) + "\n")
        stream.flush()
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        raise SystemExit(f"command failed ({result.returncode}): {' '.join(command)}; see {log}")


def export(godot: Path, env: dict[str, str], scratch: Path) -> None:
    log = scratch / "r48-export.log"
    log.write_text("", encoding="utf-8")
    for _ in range(2):  # deploy-web.yml imports twice so fonts/themes converge
        subprocess.run([str(godot), "--headless", "--import", "--path", "."], cwd=ROOT, env=env, stdout=log.open("a", encoding="utf-8"), stderr=subprocess.STDOUT)
    if EXPORT.exists():
        shutil.rmtree(EXPORT)
    EXPORT.mkdir(parents=True)
    gdignore = EXPORT.parent / ".gdignore"
    if not gdignore.exists():
        gdignore.write_text("", encoding="utf-8")
    run([str(godot), "--headless", "--path", ".", "--export-release", "Web", str(EXPORT / "index.html")], env, log)
    run([sys.executable, "tools/finalize_r25_web_export.py", "--dir", str(EXPORT), "--evidence", str(scratch / "r48-pwa-check.json")], env, log)


def capture(views: list[str], env: dict[str, str], port: int, playwright: str | None, out: Path) -> int:
    server = ThreadingHTTPServer(("127.0.0.1", port), partial(Quiet, directory=str(EXPORT)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        # Godot alone runs on the scratch profile; the browser keeps the
        # machine's installed Playwright Chromium.
        node_env = os.environ.copy()
        node_env.setdefault("PLAYWRIGHT_BROWSERS_PATH", str(Path(os.environ.get("LOCALAPPDATA", "")) / "ms-playwright"))
        node_env["R48_URL"] = f"http://127.0.0.1:{port}/"
        node_env["R48_OUT"] = str(out)
        if playwright:
            node_env["R48_PLAYWRIGHT"] = playwright
        return subprocess.run(["node", "tools/r48_forge_capture.cjs", *views], cwd=ROOT, env=node_env).returncode
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--appdata", required=True, type=Path, help="scratch folder holding roaming/ and local/")
    parser.add_argument("--views", nargs="*", default=["desktop", "phone"])
    parser.add_argument("--port", type=int, default=8148)
    parser.add_argument("--playwright", default=None, help="node_modules with playwright-core (read only)")
    parser.add_argument("--out", type=Path, default=OUT, help="screenshots and forge-capture.json (default docs/content/r48)")
    parser.add_argument("--skip-export", action="store_true")
    parser.add_argument("--keep-export", action="store_true")
    args = parser.parse_args()
    scratch = args.appdata.resolve()
    env = os.environ.copy()
    env["APPDATA"] = str(scratch / "roaming")
    env["LOCALAPPDATA"] = str(scratch / "local")
    for key in ("APPDATA", "LOCALAPPDATA"):
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    args.out.mkdir(parents=True, exist_ok=True)
    try:
        if not args.skip_export:
            export(args.godot, env, scratch)
        code = capture(args.views, env, args.port, args.playwright, args.out.resolve())
    finally:
        if not args.keep_export and EXPORT.exists():
            shutil.rmtree(EXPORT)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
