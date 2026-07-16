# Crackveil Vanguard — cv art-r21 Rodin 量產與圖集整合報告

日期：2026-07-16
版本：`v0.16.0-r21`

## 結論

R21 已使用 Blender MCP socket 與 Hyper3D Rodin 完成其餘 9 位英雄，連同既有核准的 Captain 共 10 位，全部通過一體模型 QC、18 骨視覺 rig、`idle4 / walk8 / attack6 / hurt3 / death6` 逐格姿勢渲染、三視圖、亮度／飽和度雙閘門、兩套 Godot 回歸、正式 Web export 與瀏覽器實戰驗收。

沒有使用程序化方塊、膠囊或單張 whole-sprite bobbing 代替角色模型／動畫。Rodin 是模型底；動作由 `root/pelvis/spine/chest/neck/head` 與左右四肢共 18 骨變形，Godot physics root 與 collider 未進入 Blender 視覺 rig。

本輪缺件：**0**。Hyper3D free-trial 沒有耗盡；R21 的 9 位新英雄與 r21.1 補生成的 Line Mender 都在各自第一次生成通過，沒有使用重試額度。

## r21.1 — Line Mender 有頭修正

R21 總稽核發現原始 Line Mender 的袍領上方沒有頭部；64px 白袍輪廓讓舊 QC 的「主體到達全高 72%」條件誤判。本次只重生成 `line_mender`，送入 Rodin 的提示詞明確要求 `VISIBLE HEAD with kind face`、短髮、放下的兜帽及頭頸牢固相連。第一次生成即取得正面清楚可見的臉、頭髮與連續頭頸，沒有消耗第 2／3 次重試。

QC 現在以完整模型最高 **15%** 為頭部區：該區必須有至少 `max(24, 主體 welded vertices × 0.2%)` 的連通頂點群；為排除寬袍領／肩甲冒充頭部，該群寬度還必須不超過全身寬度 42%，並與跨越軀幹區的最大 welded component 相同。新模型為 24,472 vertices／11,658 welded vertices／2 components，主體比例 97.21%；頭部群 `913 >= 24`、寬度比 34.06%、`head_present=true`、`head_connected_to_torso=true`、雙腳落地，PASS。此檢查已寫入 `tools/art_r21_blender_ops.py`，單英雄最多三次的修補入口為：

```text
python tools/generate_art_r21_rodin.py --hero line_mender
```

合格 GLB 為 1,857,752 bytes。只有 Line Mender 重新建立 18 骨 rig、100% manual weight coverage、五態 27 格與正／側／背渲染；[r21.1 三視圖](evidence/art_r21/threeview/hero_line_mender.png) 的正面可直接看到完整臉部。針對性 atlas 合成證明其餘 9 英雄 cells 與 7 敵人 cells 都逐像素不變：

```text
python tools/compose_art_r21_atlas.py --hero hero_line_mender
R21_1_ATLAS_PASS target=hero_line_mender size=512x3712 other_nine_heroes_unchanged=true enemy_rows_unchanged=true
```

全 atlas 雙閘門 17/17 PASS；Line Mender 為 `L=0.6083 / S=0.4286 / 低飽和=8.41% / near-black=4.55%`。`TrueAnimationRegressionTest` 與 `R14RegressionTest` 都是 exit 0，正式 Web export 亦 exit 0；新 `index.pck` 為 6,553,028 bytes。

## 開源技法研究與落地

本輪先完成 [ART_STUDY_R21.md](ART_STUDY_R21.md)，採用 Blender 官方 armature／vertex weight／pose／AgX 文件，實際落地為：空間 weld 後的 topology QC、18 骨 pose pipeline、攻擊三段、暖 key／冷 fill／cyan rim 與 AgX、64px 雙閘門。研究不是獨立文件而已，對應參數已寫入 `tools/art_r21_blender_ops.py` 與 `tools/build_art_r21_rodin_atlas.py`。

## Phase A — Hyper3D Rodin 生成與 QC

socket client：`tools/blender_mcp_client.py`。每個命令都新開 `127.0.0.1:9876` TCP、送一行 JSON、讀一個 JSON response 後關閉；connection refused／reset／timeout 會在 180 秒內重試。此版 addon 的 text-generation 原生 handler 名稱為 `create_rodin_job`，就是 MCP `generate_hyper3d_model_via_text` 背後的 Hyper3D Rodin 實作。

所有生成皆採 `[1,1,2]` bbox（API 規定整數且每軸至少 1），逐一執行 generate → poll 直到 6/6 `Done` → import → `execute_code` QC → selected GLB export。

| 英雄 | GLB bytes | mesh | weld 後 loose parts | 主體比例 | 頭／腳 | 結果 |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| Captain（既有核准） | 1,643,160 | 1 | 1 | 100.00% | PASS / PASS | PASS |
| Rift Sniper | 1,903,264 | 1 | 5 | 99.07% | PASS / PASS | PASS |
| Void Weaver | 1,882,044 | 1 | 1 | 100.00% | PASS / PASS | PASS |
| Arc Scout | 1,826,472 | 1 | 1 | 100.00% | PASS / PASS | PASS |
| Echo Singer | 1,999,932 | 1 | 1 | 100.00% | PASS / PASS | PASS |
| Ember Grenadier | 2,158,648 | 1 | 1 | 100.00% | PASS / PASS | PASS |
| Line Mender（r21.1） | 1,857,752 | 1 | 2 | 97.21% | PASS / PASS | PASS |
| Orbit Guard | 1,853,980 | 1 | 1 | 100.00% | PASS / PASS | PASS |
| Pulse Artificer | 2,150,304 | 1 | 1 | 100.00% | PASS / PASS | PASS |
| Rift Shepherd | 1,934,976 | 1 | 1 | 100.00% | PASS / PASS | PASS |

Rift Sniper 的 4 個額外 component 只有 15–38 welded vertices，為單片鏡／服裝微件；最大 component 同時覆蓋頭頂到雙腳且佔 99.07%。R21 原始 Line Mender 的舊檢查把高袍領誤當頭部；r21.1 模型的第二 component 為手持道具／飾件，最大連續身體佔 97.21%，最高 15% 的 913 點頭部群與軀幹相連。逐件 bbox 與 component 明細位於 `docs/evidence/art_r21/qc/`；生成 manifest 位於 [rodin_manifest.json](evidence/art_r21/rodin_manifest.json)。

## Phase B — rig、逐格姿勢、圖集

每個模型建立 18 骨 armature。Blender automatic heat weights 對 Rodin 的高密度 seam topology 都回傳 0% 有效覆蓋，因此沒有假稱 automatic 成功；十位全部改用最近兩個 deform-bone segments 的正規化 manual fallback，最小單骨權重 0.72，最終逐頂點 coverage **100%**。詳細 automatic error、骨名、vertex／polygon 數與 rigged GLB bytes 位於 [rig_manifest.json](evidence/art_r21/rig_manifest.json)。可稽核 rigged GLB 保存在 gitignored `export/art_r21_rigged/`。

270 個英雄 frame 由骨架 pose 真實渲染：

- idle 4：chest、head、左右 upper arm 呼吸差異。
- walk 8：左右 thigh／shin 與反向 upper arm 交替，非物件平移。
- attack 6：frame 0–1 anticipation、frame 2 active impact、frame 3 follow-through、frame 4–5 recovery；Godot 命中仍鎖 frame 2。
- hurt 3：spine/chest 後仰、head／雙臂 recoil。
- death 6：root 骨倒地加四肢失衡，最終 frame 以 deformed bbox framing，沒有裁切或 whole-sprite 假動畫。

正式燈光為暖色 area key、冷色 fill、cyan rim、AgX Medium High Contrast。先以 128px 渲染，再縮到 native 64px cell。Atlas 保持 **512×3712**、8 columns、27 cells／character；只覆寫前 270 個十英雄 cells。7 種敵人的 189 cells 前後 SHA256 都是 `cb933c06b662bdde3f466404c7334def09f11620b80de63a1603d7deff28f08b`，逐像素相同。

## 雙閘門

`python tools/check_sprite_luminance.py --json-output docs/evidence/art_r21/color_metrics_r21.json` exit `0`，17/17 PASS。門檻：平均亮度 `0.30–0.75`、平均 HSV 飽和度 `>=0.32`、低飽和像素 `<20%`；既有 near-black `<35%` 亦保留。

| 英雄 | 平均 L | 平均 S | 低飽和 | 結果 |
| --- | ---: | ---: | ---: | --- |
| Captain | 0.3081 | 0.8155 | 4.74% | PASS |
| Rift Sniper | 0.3111 | 0.6428 | 8.99% | PASS |
| Void Weaver | 0.5373 | 0.4925 | 11.13% | PASS |
| Arc Scout | 0.6233 | 0.4076 | 17.36% | PASS |
| Echo Singer | 0.3156 | 0.5518 | 5.54% | PASS |
| Ember Grenadier | 0.4727 | 0.3968 | 19.03% | PASS |
| Line Mender | 0.6083 | 0.4286 | 8.41% | PASS |
| Orbit Guard | 0.3612 | 0.6124 | 2.77% | PASS |
| Pulse Artificer | 0.4831 | 0.4926 | 14.06% | PASS |
| Rift Shepherd | 0.4001 | 0.6695 | 5.40% | PASS |

十英雄加權：`L=0.4538 / S=0.5330 / 低飽和=10.70%`。全 atlas 加權：`L=0.3991 / S=0.5021 / 低飽和=7.53%`。機器可讀資料：[color_metrics_r21.json](evidence/art_r21/color_metrics_r21.json)。

## 視覺證據

- [R20.1 vs R21 十英雄 native 64px 對比](evidence/art_r21/before_after/all_heroes_r20_1_vs_r21.png)：每位英雄 idle、walk、attack impact frame 2 與 L／S 數據。
- [18 骨多姿勢總覽](evidence/art_r21/animation_pose_sheet.png)：每英雄 idle、walk A/B、anticipation、impact、hurt、death。
- 三視圖：位於 `docs/evidence/art_r21/threeview/`，10/10 皆有正／側／背 Hyper3D 模型證據。
- [正式 Web export 戰鬥截圖](evidence/art_r21/web_battle_r21.png)：本機 HTTP 載入正式 `export/web`，seed 6、裂隙契約 I、戰鬥第 7 秒，版本角標 `v0.16.0-r21`。

## 回歸與 Web export

Godot 4.7 stable：

```text
TrueAnimationRegressionTest exit 0
TRUE_ANIMATION_PLAYER heroes=10 unique_cells=10 poses=4/8/6/3/6 impact_frame=2
TRUE_ANIMATION_REGRESSION_PASS

R14RegressionTest exit 0
R14_HERO10 roster=10/9 weapons=11 construct_cap=6 targets=2 bonds=4 impact=frame2
R14_REGRESSION_PASS
```

正式 Web export exit `0`：

| 檔案 | bytes |
| --- | ---: |
| `index.html` | 6,352 |
| `index.js` | 279,815 |
| `index.pck` | 6,553,028 |
| `index.wasm` | 39,509,339 |

瀏覽器完成主選單 → 首次簡報 → 契約 → 實戰。console 只有既有 invalid UID 後自動使用 text path 的 warnings，沒有載入或戰鬥失敗。

## PCK／repo 體積策略與重建

10 個 Rodin GLB 合計約 19.3 MB，是本機可重建的 production source，不是 runtime asset。repo 沒有 `.gitattributes`／LFS 設定；為避免直接放大 git history，`.gitignore` 排除 `assets/rodin/*.glb`，`assets/rodin/.gdignore` 阻止 Godot import。`export_presets.cfg` 另明列 `exclude_filter="assets/rodin/**,export/**"`，避免 Rodin 與 270 張中間 frame 進 PCK。

最終 `index.pck` 已二進位掃描：`assets/rodin`、GLB 檔名、`art_r21_frames`、`00_idle_00.png` 全部 **0 命中**；只有 `assets/sprites/true_character_atlas.png` 與十張 64px hero reference 進遊戲。

部署前秘密掃描使用永久規則中的兩組 pattern，排除 `.git` 與 build output 後結果為 **0 命中**；`git diff --check` 亦為 exit `0`。

重建方式：開啟 Blender 5.1 與 blender-mcp addon socket 9876，完整 R21 使用既有全批次命令；r21.1 單英雄修補則依序執行 `python tools/generate_art_r21_rodin.py --hero line_mender`、`tools/blender_mcp_client.py execute_code --code-file tools/build_art_r21_rodin_atlas.py --code-call "build_one('line_mender')"`、`python tools/compose_art_r21_atlas.py --hero hero_line_mender`。所有 Hyper3D 提示詞、bbox、QC 與 pose 參數都在版控腳本與 manifest 中。

## 揭露

- 缺件：無。
- 額度：未耗盡；R21 的 9/9 新英雄與 r21.1 Line Mender 補生成都第一次通過。
- Automatic weights：10/10 heat weighting 無有效 coverage；已逐件揭露並使用 100% coverage 的 manual nearest-two-bone fallback。
- GLB：本機保留但 gitignored；可依上節完整重建。
- 未 push；僅建立本地繁中 commit。
