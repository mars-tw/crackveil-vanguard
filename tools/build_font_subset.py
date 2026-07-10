#!/usr/bin/env python3
"""Build the embedded UI font subset for Crackveil Vanguard."""

from __future__ import annotations

import argparse
import csv
import io
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.request import urlopen

from fontTools.ttLib import TTFont


PROJECT_EXTENSIONS = {".gd", ".tscn", ".tres", ".godot"}
EXCLUDED_DIRS = {".git", ".godot", "export", "exports", "build", "dist"}

FONT_SOURCE_URL = (
    "https://raw.githubusercontent.com/notofonts/noto-cjk/Sans2.004/"
    "Sans/OTF/TraditionalChinese/NotoSansCJKtc-Regular.otf"
)
SAFETY_CHARS_URL = (
    "https://raw.githubusercontent.com/agj/3000-traditional-hanzi/"
    "855200d72670b8053096b6d706906d2cad265dbe/output/notes.tsv"
)
SAFETY_SOURCE_LABEL = (
    "agj/3000-traditional-hanzi notes.tsv @ "
    "855200d72670b8053096b6d706906d2cad265dbe"
)


def is_han(ch: str) -> bool:
    codepoint = ord(ch)
    return (
        0x3400 <= codepoint <= 0x4DBF
        or 0x4E00 <= codepoint <= 0x9FFF
        or 0xF900 <= codepoint <= 0xFAFF
    )


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urlopen(url, timeout=60) as response:
        destination.write_bytes(response.read())


def default_source_font() -> Path:
    env_path = os.environ.get("CRACKVEIL_FONT_SOURCE")
    if env_path:
        return Path(env_path)
    return Path(tempfile.gettempdir()) / "crackveil-font-source" / "NotoSansCJKtc-Regular.otf"


def scan_project_han_chars(project_root: Path) -> tuple[set[str], int]:
    chars: set[str] = set()
    scanned_files = 0

    for path in project_root.rglob("*"):
        if any(part in EXCLUDED_DIRS for part in path.parts):
            continue
        if not path.is_file() or path.suffix not in PROJECT_EXTENSIONS:
            continue

        scanned_files += 1
        text = path.read_text(encoding="utf-8", errors="ignore")
        chars.update(ch for ch in text if is_han(ch))

    return chars, scanned_files


def load_safety_chars(limit: int, cache_path: Path) -> list[str]:
    if not cache_path.exists():
        download(SAFETY_CHARS_URL, cache_path)

    text = cache_path.read_text(encoding="utf-8")
    chars: list[str] = []
    seen: set[str] = set()

    for row in csv.reader(io.StringIO(text), delimiter="\t"):
        if not row:
            continue
        ch = row[0].strip()
        if len(ch) == 1 and is_han(ch) and ch not in seen:
            seen.add(ch)
            chars.append(ch)
        if len(chars) >= limit:
            break

    if len(chars) < limit:
        raise RuntimeError(f"Only loaded {len(chars)} safety chars; expected {limit}.")

    return chars


def builtin_symbols() -> set[str]:
    chars = {chr(codepoint) for codepoint in range(0x20, 0x7F)}
    # Latin-1 Supplement（±、°、×、÷ 等），R11 實測 ±20° 豆腐後補上
    chars.update(chr(codepoint) for codepoint in range(0xA0, 0x100))
    # General Punctuation（——、‘’、“”、…、‧ 等），R9 實測 U+2014 破折號豆腐後補上
    chars.update(chr(codepoint) for codepoint in range(0x2000, 0x2070))
    chars.update(chr(codepoint) for codepoint in range(0x3000, 0x3040))
    chars.update(chr(codepoint) for codepoint in range(0xFF01, 0xFF5F))
    return chars


def font_codepoints(font_path: Path) -> set[int]:
    font = TTFont(font_path)
    codepoints: set[int] = set()
    for table in font["cmap"].tables:
        codepoints.update(table.cmap.keys())
    font.close()
    return codepoints


def run_pyftsubset(source_font: Path, output_font: Path, chars_file: Path) -> None:
    output_font.parent.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        "-m",
        "fontTools.subset",
        str(source_font),
        f"--output-file={output_font}",
        f"--text-file={chars_file}",
        "--layout-features=*",
        "--glyph-names",
        "--symbol-cmap",
        "--legacy-cmap",
        "--notdef-glyph",
        "--notdef-outline",
        "--recommended-glyphs",
        "--name-IDs=*",
        "--name-legacy",
        "--name-languages=*",
        "--no-hinting",
    ]
    subprocess.run(command, check=True)


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=repo_root)
    parser.add_argument("--source-font", type=Path, default=default_source_font())
    parser.add_argument(
        "--output-font",
        type=Path,
        default=repo_root / "assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf",
    )
    parser.add_argument(
        "--chars-output",
        type=Path,
        default=repo_root / "assets/fonts/NotoSansCJKtc-Regular-UI-Subset.chars.txt",
    )
    parser.add_argument("--safety-limit", type=int, default=2800)
    # R9：補 General Punctuation 後 1,503,160 bytes，上限調至 1.55MB（守門防失控用意不變）
    parser.add_argument("--max-size-bytes", type=int, default=1_550_000)
    parser.add_argument(
        "--check-chars",
        default="載暴距引跳雷鏈過磁回收",
        help="Characters to verify in the generated subset.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    source_font = args.source_font.resolve()
    output_font = args.output_font.resolve()
    chars_output = args.chars_output.resolve()

    if not source_font.exists():
        print(f"Downloading source font: {FONT_SOURCE_URL}")
        download(FONT_SOURCE_URL, source_font)

    cache_path = (
        Path(tempfile.gettempdir())
        / "crackveil-font-source"
        / "traditional-3000-855200d7-notes.tsv"
    )
    safety_chars = load_safety_chars(args.safety_limit, cache_path)
    project_chars, scanned_files = scan_project_han_chars(project_root)

    all_chars = builtin_symbols()
    all_chars.update(project_chars)
    all_chars.update(safety_chars)

    sorted_chars = "".join(sorted(all_chars))
    chars_output.parent.mkdir(parents=True, exist_ok=True)
    chars_output.write_text(sorted_chars + "\n", encoding="utf-8")

    run_pyftsubset(source_font, output_font, chars_output)

    covered = font_codepoints(output_font)
    missing = [ch for ch in args.check_chars if ord(ch) not in covered]
    if missing:
        raise RuntimeError(f"Generated subset is missing required chars: {''.join(missing)}")

    output_size = output_font.stat().st_size
    if output_size > args.max_size_bytes:
        raise RuntimeError(
            f"Generated subset is {output_size} bytes; max is {args.max_size_bytes} bytes."
        )

    project_han_in_output = sum(1 for ch in project_chars if ord(ch) in covered)
    total_han = sum(1 for ch in all_chars if is_han(ch))

    print(f"Scanned project files: {scanned_files}")
    print(f"Project Han chars: {len(project_chars)}")
    print(f"Safety chars: {len(set(safety_chars))} ({SAFETY_SOURCE_LABEL})")
    print(f"Subset input codepoints: {len(all_chars)}")
    print(f"Subset input Han chars: {total_han}")
    print(f"Project Han coverage: {project_han_in_output}/{len(project_chars)}")
    print(f"Check chars covered: {args.check_chars}")
    print(f"Output font: {output_font}")
    print(f"Output font bytes: {output_size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
