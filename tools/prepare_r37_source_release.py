#!/usr/bin/env python3
"""Select game sources, reproducible assets and concise release evidence."""
from pathlib import Path
import argparse
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_TOOLS = {
    "build_critical_impact_audio.py", "build_r33_ruins.mjs", "build_r34_character_atlas.py",
    "build_r35_captain_combo_atlas.py", "build_r36_pet_atlas.py", "pack_r35_skill_fx.gd",
    "preview_r35_skill_fx.gd", "test_r35_skill_fx_catalog.gd", "test_r32_loading_recovery.mjs",
    "test_r33_web_smoke.mjs", "test_r36_webgl_state_cache.cjs", "check_r37_release_assets.py",
    "sync_resource_uids.py", "r37_perf_compare.cjs", "prepare_r37_source_release.py",
    "build_r38_content_atlas.py", "check_r38_content_assets.py", "measure_r38_hero_body_scale.py", "r38_map_playtest.cjs",
    "test_r41_mobile_startup.cjs",
}
PUBLIC_DOCS = {
    "docs/COMBAT_R32.md", "docs/PROGRESSION_R32.md", "docs/PROGRESSION_R36.md",
    "docs/R32_OPTIMIZATION_REPORT.md", "docs/R33_ART.md", "docs/R33_COMBAT.md",
    "docs/R33_REWORK_REPORT.md", "docs/R34_MAP_ART.md", "docs/R34_REWORK_REPORT.md",
    "docs/R35_CAPTAIN_COMBAT.md", "docs/R35_REWORK_REPORT.md", "docs/R36_FIREPOWER.md",
    "docs/R36_PERFORMANCE.md", "docs/R36_REWORK_REPORT.md", "docs/R37_COMBAT_PERFORMANCE.md",
    "docs/R37_RELEASE_REPORT.md", "docs/REVIEW_R32.md", "docs/REVIEW_R34_STAGE.md",
    "docs/playtest/R36_PLAYTEST.md", "docs/playtest/R37_PLAYTEST.md",
    "docs/evidence/r33/art/r33_keyart_prompt.txt",
    "docs/evidence/r36/native_latest/space_large_cyclone.png",
    "docs/evidence/r36/native_latest/east_landmark.png",
    "docs/evidence/r36/final_world_map.jpg",
    "docs/R38_RELEASE_REPORT.md", "docs/R38_STAGES_ENEMIES.md", "docs/PROGRESSION_R38.md",
    "docs/R39_MOBILE_HUD.md",
    "docs/R40_FACING_ATTACK.md",
    "docs/R41_IPHONE_LOADING.md",
}

def git_paths(arguments):
    return subprocess.check_output(["git", *arguments, "-z"], cwd=ROOT, stderr=subprocess.DEVNULL).decode("utf-8").strip("\0").split("\0")

def wanted(path):
    parts = Path(path).parts
    if path.startswith(("scripts/", "scenes/", "resources/")):
        return True
    if path.startswith("assets/"):
        return "qa" not in parts and Path(path).suffix not in {".log", ".webm", ".mp4"}
    if path.startswith("web/"):
        return path in {"web/webgl_state_cache.js", "web/loading_recovery.mjs", "web/mobile_startup.js"}
    if path.startswith("tools/"):
        return Path(path).name in PUBLIC_TOOLS
    if path in PUBLIC_DOCS:
        return True
    if path.startswith("docs/evidence/r37/"):
        return Path(path).name in {"gameplay.png", "manual-gameplay.png", "release_audit.md", "final_verification.json", "gates.json", "asset_gate.json", "performance_summary.json", "combat_polish.txt", "world_polish.txt", "hud_clearance.txt", "clean_web_smoke.json", "clean_asset_gate.json"}
    if path.startswith("docs/evidence/r38/"):
        return Path(path).name in {"gates.json", "independent_review.md", "playtest_summary.json", "hero_scale_playtest.json", "input_trace.json", "clean_build.json", "clean_web_smoke.json", "final_verification.json", "dunes.png", "tide.png", "bloom.png", "forge.png", "new_heroes.png", "new_hero_recruit.png", "public_content.jpg"}
    if path.startswith("docs/evidence/r39/"):
        return Path(path).name in {"after_summary.json", "summon_single_check.json", "AFTER_REVIEW.md", "mobile_hud_test.json", "independent_review.md", "targeted_gates.json", "phone-before.png", "phone-after.png", "phone-after-portrait.png"}
    if path.startswith("docs/evidence/r40/"):
        return Path(path).name in {"facing_attack_test.json", "after_summary.json", "independent_review.md", "targeted_gates.json", "after-move.png", "after-attack.png"}
    if path.startswith("docs/evidence/r41/"):
        return Path(path).name in {"ASSET_ALLOC_AUDIT.md", "MEASUREMENT_REPORT.md", "independent_review.md", "asset_budget_baseline.json", "import_budget_after.json", "targeted_gates.json", "baseline.json", "after.json", "after.png", "pwa_cache_verification.json"}
    if path in {"docs/evidence/r38-hero-body-scale-before.json", "docs/evidence/r38-hero-body-scale-after.json"}:
        return True
    return False

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", action="store_true")
    args = parser.parse_args()
    changed = git_paths(["diff", "--name-only"])
    staged = git_paths(["diff", "--cached", "--name-only"])
    new = git_paths(["ls-files", "--others", "--exclude-standard"])
    selected = sorted(set(p for p in changed + staged if p) | set(p for p in new if p and wanted(p)))
    oversized = [p for p in selected if (ROOT/p).is_file() and (ROOT/p).stat().st_size > 80*1048576]
    private = [p for p in selected if ".audit-tmp" in Path(p).parts or p.startswith(".env") or "credentials" in p.lower()]
    if oversized or private:
        raise SystemExit(json.dumps({"oversized": oversized, "private": private}))
    output = ROOT/"export/r37-release-manifest.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"selected": selected, "count":len(selected), "new_files_omitted": [p for p in new if p and p not in selected]}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    pathspec = output.with_suffix(".pathspec")
    pathspec.write_bytes(b"\0".join(p.encode("utf-8") for p in selected)+b"\0")
    if args.stage:
        subprocess.run(["git","add",f"--pathspec-from-file={pathspec}","--pathspec-file-nul"],cwd=ROOT,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    print(f"R37_SOURCE_MANIFEST files={len(selected)} omitted_new={sum(bool(p) and p not in selected for p in new)} staged={args.stage}")

if __name__ == "__main__":
    main()
