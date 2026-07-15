# Crackveil Vanguard 開源版全面稽核（oss-audit）

- 日期：2026-07-15（Asia/Taipei）
- Repo：`mars-tw/crackveil-vanguard`
- 本地資料夾：`rift-survivors`（已確認名稱不同不影響 remote 與公開網址）
- 稽核基準：`75b3d7a`（執行本輪 commit 前）
- 範圍限制：只修改開源文件、repo 衛生、Web 匯出 meta 與部署設定；未修改遊戲程式邏輯或素材內容。

## 逐項檢查結果

| # | 檢查項目 | 結果 | 修正／證據 |
| --- | --- | --- | --- |
| 1 | README 全面翻新 | PASS | 重寫 [`README.md`](../README.md)：加入遊戲簡介、正確線上遊玩網址、CI badge、10 位英雄與真姿勢動畫、r16 角色藝術、UI 修復、四組羈絆、桌機／手機操作、3 張既有證據圖、技術棧、Godot 4.7 本地開發、字型子集、regression 與 Web 匯出指引。 |
| 2 | LICENSE | PASS（原已正確） | [`LICENSE`](../LICENSE) 為完整 MIT License，`Copyright (c) 2026 mars-tw`；不需修改。 |
| 3 | CREDITS／第三方授權 | PASS | 新增根目錄 [`CREDITS.md`](../CREDITS.md)，逐項列出來源、授權與用途：Noto Sans CJK TC／OFL、3000-traditional-hanzi／MIT、pixel-idle-farm-skill／MIT、Kenney 五個 CC0 包、OpenGameArt 三個 CC0 來源項目。同步補強 [`assets/CREDITS.md`](../assets/CREDITS.md) 的總表連結與缺少的字型、字集、農場素材來源。 |
| 4 | Repo 衛生 | PASS | 補強 [`.gitignore`](../.gitignore) 的 Godot／export／Python／測試報告／編輯器暫存規則；刪除 117 個根目錄 log、4 個 Python cache 與既有 `export/`；移除誤入版控的 `.pyc`。63 份既有 `docs/**/*.md` 的 Markdown 相對連結檢查零失效。 |
| 5 | OG meta／封面 | PASS | [`export_presets.cfg`](../export_presets.cfg) 新增 `og:url`、`og:image` 與 Twitter card，網址均為 `https://mars-tw.github.io/crackveil-vanguard/`；[部署 workflow](../.github/workflows/deploy-web.yml) 複製既有 `assets/art/cover.png` 為公開的 `public/cover.png`。實際 Web release 匯出後逐字核對 meta 成功。 |
| 6 | 版本一致性 | PASS | [`project.godot`](../project.godot) 與 README 均為 `0.14.0-r16`；未改專案版號。 |
| 7 | 功能 sanity | PASS | Godot `4.7.stable.official.5b4e0cb0f` headless 執行 R14RegressionTest 與 TrueAnimationRegressionTest，兩者 exit code 均為 0 且出現指定 PASS marker。未修改遊戲邏輯。 |

## Repo 衛生清理紀錄

所有項目均在刪除前列出。保留 `.godot/` 本機 editor cache，也保留 `tools/asset_sources/` 內的上游來源素材本體；只移除該來源目錄中的 `__pycache__`。

### 既有匯出產物（8 檔，46,207,475 bytes）

```text
export/web/index.audio.position.worklet.js
export/web/index.audio.worklet.js
export/web/index.html
export/web/index.js
export/web/index.pck
export/web/index.png
export/web/index.png.import
export/web/index.wasm
```

### Python cache（4 檔）

```text
tools/__pycache__/build_font_subset.cpython-312.pyc
tools/asset_sources/baseline_5d082e4/tools/__pycache__/build_font_subset.cpython-312.pyc
tools/asset_sources/candidate_assets_baselinecode/tools/__pycache__/build_font_subset.cpython-312.pyc
tools/asset_sources/candidate_enemy_art_ab/tools/__pycache__/build_font_subset.cpython-312.pyc
```

第一項原本受 git 追蹤，本輪自版控移除；其餘位於已忽略的素材來源目錄。

### 根目錄測試／效能 log（117 檔，1,325,601 bytes）

<details>
<summary>展開逐檔清單</summary>

```text
anim_perf_editor_check.log
anim_perf_enemy_art.log
anim_perf_final_desktop_run1.log
anim_perf_final_desktop_run2.log
anim_perf_final_desktop_run3.log
anim_perf_final_editor.log
anim_perf_final_main_smoke.log
anim_perf_final_mobile_run1.log
anim_perf_final_mobile_run2.log
anim_perf_final_mobile_run3.log
anim_perf_final_suite_ArenaInstrumentationRun.log
anim_perf_final_suite_BalanceMockRun.log
anim_perf_final_suite_EnemyArtRegressionTest.log
anim_perf_final_suite_GameplayCapTest.log
anim_perf_final_suite_M1RegressionTest.log
anim_perf_final_suite_M2RegressionTest.log
anim_perf_final_suite_M3RegressionTest.log
anim_perf_final_suite_M4RegressionTest.log
anim_perf_final_suite_MobileInputSmokeTest.log
anim_perf_final_suite_OrbitBladeHitRepro.log
anim_perf_final_suite_PoolContractTest.log
anim_perf_final_suite_R10_5RegressionTest.log
anim_perf_final_suite_R11RegressionTest.log
anim_perf_final_suite_R12RegressionTest.log
anim_perf_final_suite_R13RegressionTest.log
anim_perf_final_suite_R14RegressionTest.log
anim_perf_final_suite_R5RegressionTest.log
anim_perf_final_suite_R6RegressionTest.log
anim_perf_final_suite_R7RegressionTest.log
anim_perf_final_suite_SquadSmokeTest.log
anim_perf_final_suite_TrueAnimationRegressionTest.log
anim_perf_final_suite_WeaponSmokeTest.log
anim_perf_probe_desktop.log
anim_perf_probe_hidden_all_draw.log
anim_perf_probe_hidden_draw.log
anim_perf_probe_hurt_coalesce.log
anim_perf_probe_static_pose.log
anim_perf_probe2_desktop.log
anim_perf_profiling_probe.log
anim_perf_r11_debug.log
anim_perf_r11_stability_run1.log
anim_perf_r11_stability_run2.log
anim_perf_r11_stability_run3.log
anim_perf_r11_stability2_run1.log
anim_perf_r11_stability2_run2.log
anim_perf_r11_stability2_run3.log
anim_perf_retry_ArenaInstrumentationRun.log
anim_perf_retry_R11RegressionTest.log
anim_perf_retry_R5RegressionTest.log
anim_perf_retry2_R11RegressionTest.log
anim_perf_retry2_R5RegressionTest.log
anim_perf_retry3_R11RegressionTest.log
anim_perf_retry3_R5RegressionTest.log
anim_perf_same_machine_head_parent.log
anim_perf_suite_ArenaInstrumentationRun.log
anim_perf_suite_BalanceMockRun.log
anim_perf_suite_EnemyArtRegressionTest.log
anim_perf_suite_GameplayCapTest.log
anim_perf_suite_M1RegressionTest.log
anim_perf_suite_M2RegressionTest.log
anim_perf_suite_M3RegressionTest.log
anim_perf_suite_M4RegressionTest.log
anim_perf_suite_MobileInputSmokeTest.log
anim_perf_suite_OrbitBladeHitRepro.log
anim_perf_suite_PoolContractTest.log
anim_perf_suite_R10_5RegressionTest.log
anim_perf_suite_R11RegressionTest.log
anim_perf_suite_R12RegressionTest.log
anim_perf_suite_R13RegressionTest.log
anim_perf_suite_R14RegressionTest.log
anim_perf_suite_R5RegressionTest.log
anim_perf_suite_R6RegressionTest.log
anim_perf_suite_R7RegressionTest.log
anim_perf_suite_SquadSmokeTest.log
anim_perf_suite_TrueAnimationRegressionTest.log
anim_perf_suite_WeaponSmokeTest.log
anim_perf_true_animation.log
anim_perf_web_export.log
anim_perf_web_node_check.log
godot_hero10_parse.log
hero10_old_version_scan.log
hero10_r14_final.log
hero10_secret_scan.log
hero10_stress.log
hero10_stress_ab.log
hero10_stress_debug.log
hero10_stress_final.log
hero10_stress_rerun.log
hero10_true_final.log
hero10_weapon_final.log
hero10_web_export.log
hero10_web_export_final.log
m3_asset_regression.log
m3_m2_smoke.log
m3_stress_desktop.log
m3_stress_mobile.log
m3_suite_ArenaInstrumentationRun.log
m3_suite_BalanceMockRun.log
m3_suite_GameplayCapTest.log
m3_suite_M1RegressionTest.log
m3_suite_M2RegressionTest.log
m3_suite_M3RegressionTest.log
m3_suite_MobileInputSmokeTest.log
m3_suite_OrbitBladeHitRepro.log
m3_suite_PoolContractTest.log
m3_suite_R10_5RegressionTest.log
m3_suite_R11RegressionTest.log
m3_suite_R12RegressionTest.log
m3_suite_R13RegressionTest.log
m3_suite_R14RegressionTest.log
m3_suite_R5RegressionTest.log
m3_suite_R6RegressionTest.log
m3_suite_R7RegressionTest.log
m3_suite_SquadSmokeTest.log
m3_suite_WeaponSmokeTest.log
m3_web_export.log
tools_m3_import.log
```

</details>

## 驗證結果

### R14RegressionTest

```text
R14_HERO10 roster=10/9 weapons=11 construct_cap=6 targets=2 bonds=4 impact=frame2
R13_UI_SPACING viewports=1920x1080,1024x768,390x844 gap>=8 touch>=44
R14_REGRESSION_PASS
exit code: 0
```

### TrueAnimationRegressionTest

```text
TRUE_ANIMATION_PLAYER heroes=10 unique_cells=10 hero=rift_shepherd poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0
TRUE_ANIMATION_SHEPHERD impact_spawn=frame2 anticipation_spawn=0 whiff_damage=0 whiff_spawn=0 recovery=full cap=6 pool_errors=0
TRUE_ANIMATION_ENEMY impact_delayed=true whiff_damage=0 hurt_knockback=true death_delayed=true lod=6/3/1.5/freeze shared_ticker=true
TRUE_ANIMATION_REGRESSION_PASS
exit code: 0
```

### Web release 與 meta

```text
Godot 4.7 --headless --path . --export-release Web export/web/index.html
WEB_EXPORT_EXIT=0
GODOT_THREADS_ENABLED=false
og:url=https://mars-tw.github.io/crackveil-vanguard/
og:image=https://mars-tw.github.io/crackveil-vanguard/cover.png
twitter:image=https://mars-tw.github.io/crackveil-vanguard/cover.png
WEB_EXPORT_META_PASS
```

驗證產物已再次刪除，`export/` 未留在工作區。

### 文件、格式、秘密與範圍

```text
git diff --check: PASS
docs Markdown relative links: PASS（零失效）
README/project version: 0.14.0-r16 / 0.14.0-r16
tracked temp files after commit scope: zero
grep secret scan excluding .git: zero matches（exit 1，GNU grep 的零命中狀態）
```

秘密掃描命令：

```text
grep -rniIE --exclude-dir=.git "sk-proj-[A-Za-z0-9_-]{20}|sk-[a-z0-9]{40}" .
```

`-I` 只讓 grep 將二進位檔視為無匹配；文字檔掃描範圍仍僅排除 `.git`。最終單一根目錄掃描於 6.15 秒完成，零命中。

## 最終變更範圍

```text
.github/workflows/deploy-web.yml
.gitignore
CREDITS.md
README.md
assets/CREDITS.md
docs/CODEX_RESPONSE_oss_audit.md
export_presets.cfg
tools/__pycache__/build_font_subset.cpython-312.pyc (deleted)
```

未變更 `scripts/`、`scenes/`、`resources/`、`project.godot` 或任何素材檔內容；本輪不 push。
