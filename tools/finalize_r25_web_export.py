#!/usr/bin/env python3
"""Copy the R25 focal and synchronize Godot's PWA cache manifest."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE = "0.19.0-r29"
FOCAL_SOURCE = ROOT / "assets" / "art" / "r25" / "r25_web_focal.webp"
FOCAL_HASH = "48393809"
FOCAL_REF = f"r25-web-focal.webp?v={FOCAL_HASH}"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True, help="Godot Web export directory")
    parser.add_argument("--evidence", default="docs/evidence/R25/pwa_cache_verification.json")
    args = parser.parse_args()
    output = Path(args.dir).resolve()
    html = output / "index.html"
    worker = output / "index.service.worker.js"
    if not html.exists() or not worker.exists():
        raise SystemExit(f"missing PWA export files in {output}")
    source_hash = sha256(FOCAL_SOURCE)
    if not source_hash.startswith(FOCAL_HASH):
        raise SystemExit(f"focal hash drifted: {source_hash}")
    focal_output = output / "r25-web-focal.webp"
    shutil.copyfile(FOCAL_SOURCE, focal_output)

    html_text = html.read_text(encoding="utf-8")
    if html_text.count(FOCAL_REF) < 2 or f'content="{RELEASE}"' not in html_text:
        raise SystemExit("exported HTML lacks the R25 focal/content-cache markers")
    inline_marker = "rift-r25-inline-focal"
    if inline_marker not in html_text:
        focal_data = base64.b64encode(FOCAL_SOURCE.read_bytes()).decode("ascii")
        inline_block = (
            f'<div id="{inline_marker}" style="position:fixed;inset:0;z-index:2147483646;background:#04070f">'
            f'<img src="data:image/webp;base64,{focal_data}" alt="" '
            'style="width:100%;height:100%;object-fit:cover" '
            "onload=\"if(!performance.getEntriesByName('rift-r25-main-focal').length)performance.mark('rift-r25-main-focal')\">"
            "<style>@media (orientation:portrait){#rift-r25-inline-focal img{object-fit:contain!important}}"
            "#rift-r25-inline-focal::before{content:'CRACKVEIL VANGUARD';position:absolute;top:12%;left:0;right:0;z-index:1;"
            "text-align:center;color:#dff3ff;font:600 24px/1.3 system-ui,sans-serif;letter-spacing:.14em;"
            "text-shadow:0 2px 12px rgba(0,170,255,.25)}"
            "#rift-r25-inline-focal::after{content:'';position:absolute;left:50%;bottom:15%;z-index:1;width:34px;height:34px;"
            "margin-left:-17px;border:3px solid #2b4a63;border-top-color:#64d8ff;border-radius:50%;"
            "animation:rift-spin 1s linear infinite}"
            "#rift-r29-mb{position:absolute;left:0;right:0;bottom:9.5%;z-index:1;text-align:center;color:#9fd8f2;"
            "font:500 14px/1.5 system-ui,sans-serif;letter-spacing:.05em;text-shadow:0 1px 8px rgba(0,0,0,.85)}</style>"
            '<div id="rift-r29-mb">連線中…</div>'
            "</div><script>addEventListener('DOMContentLoaded',()=>{const f=document.getElementById('rift-r25-inline-focal');"
            "const s=document.getElementById('status');if(!f||!s)return;const mb=document.getElementById('rift-r29-mb');"
            "const timer=setInterval(()=>{"
            "if(!s.isConnected||getComputedStyle(s).display==='none'||window.__cvR22Controls?.main_menu||window.__cvR19Controls?.main_menu){"
            "f.remove();clearInterval(timer);return}"
            # R29 P1-5：掛在既有 #status-progress 更新處，顯示「已載/總量 MB」給行動網路首載體感。
            # R29.1 M1：value/max 均以 Number.isFinite 防護——異常口徑退回引導文案，不得露出 NaN。
            "const p=document.getElementById('status-progress');"
            "if(mb){const mx=p&&p.getAttribute('max')?Number(p.max):NaN;const v=p?Number(p.value):NaN;"
            "if(Number.isFinite(mx)&&mx>0&&Number.isFinite(v)&&v>=0){const t=mx/1048576;"
            "mb.textContent='已載 '+(v/1048576).toFixed(1)+' / '+t.toFixed(1)+' MB'+(t>20?'（行動網路首次載入需時較久）':'')}"
            "else{mb.textContent='連線下載中…'}}"
            "},50)},{once:true})</script>"
        )
        html_text = html_text.replace("<body>", "<body>\n\t\t" + inline_block, 1)
        html.write_text(html_text, encoding="utf-8", newline="\n")
    if "rift-r29-mb" not in html_text:
        raise SystemExit("R29 loading MB counter marker missing from exported HTML")
    worker_text = worker.read_text(encoding="utf-8")
    worker_text, version_count = re.subn(
        r"const CACHE_VERSION = '[^']+';",
        f"const CACHE_VERSION = '{RELEASE}|{FOCAL_HASH}';",
        worker_text,
        count=1,
    )
    required_cached = [
        "index.html",
        "index.js",
        "index.offline.html",
        "index.audio.worklet.js",
        "index.audio.position.worklet.js",
        "index.png",
        "index.manifest.json",
        "index.144x144.png",
        "index.180x180.png",
        "index.512x512.png",
        FOCAL_REF,
    ]
    replacement = "const CACHED_FILES = " + json.dumps(required_cached, ensure_ascii=False, separators=(",", ":")) + ";"
    worker_text, files_count = re.subn(r"const CACHED_FILES = \[[^;]+;", replacement, worker_text, count=1)
    if version_count != 1 or files_count != 1:
        raise SystemExit("unable to patch PWA service worker")
    worker.write_text(worker_text, encoding="utf-8", newline="\n")

    checks = {
        "release": RELEASE,
        "cache_version": f"{RELEASE}|{FOCAL_HASH}",
        "focal_ref": FOCAL_REF,
        "focal_source_sha256": source_hash,
        "focal_export_sha256": sha256(focal_output),
        "loading_mb_marker": "rift-r29-mb",
        "cached_files": required_cached,
        "offline_url": "index.offline.html",
        "old_cache_cleanup": "activate deletes same-prefix caches except current CACHE_NAME",
        "passed": source_hash == sha256(focal_output) and all(name in worker_text for name in required_cached),
    }
    evidence = ROOT / args.evidence
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(json.dumps(checks, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"R25_PWA_CACHE_PASS version={checks['cache_version']} files={len(required_cached)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
