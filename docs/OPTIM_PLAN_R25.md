# Crackveil Vanguard Wave 2 R25 優化計畫

日期：2026-07-17  
目標版本：`0.18.0-r25`  
範圍：既有三戰場各 3 層真素材視差（遠景天空／中景地形剪影／近景裝飾），共 9 層；不改角色動畫、關卡、數值或玩法。

## Wave 1 DoD 與殘留

- `assets/art/r24/manifest.json` 存在，R24 runtime cutout 8 張、key art 2 張皆有來源與 SHA-256；`all_art_gates_pass=true`。
- 現行 runtime 素材載入未發現 production placeholder 計數器；R14 現況輸出 `R24_VISUAL_ASSET_CONTRACT cutouts=8 keyart=2` 並通過。
- Wave 1 殘留：R24 manifest 沒有本協定新增要求的逐 master C2PA `softwareAgent` 驗證欄；本輪不追改 R24 圖，但報告必須列出。

## Before 基線（開工前）

| 項目 | Before | R25 after 上限／驗收 |
| --- | --- | --- |
| Godot 版本 | `4.7.stable.official.5b4e0cb0f` | 同版本 |
| R14RegressionTest | exit 0；`R14_REGRESSION_PASS` | exit 0 |
| TrueAnimationRegressionTest | exit 0；`TRUE_ANIMATION_REGRESSION_PASS` | exit 0；角色資產 diff = 0 |
| 滿編 Stress（共享機況原始失敗） | `avg=218.534ms`、`p95=746.723ms`、exit 1；`machine_condition=concurrent_untrusted` | 原始失敗保留；隔離重跑不得放寬 `p95 <=18ms` |
| 最近可信同引擎基線 | R22 evidence：`avg=8.818ms`、`p95=12.365ms` | 只作漂移參考，不替代本輪隔離 after |
| Web build PCK | `8,295,204 bytes` | 記錄 after；首屏互動時間不得退步 >10% |
| Fast 3G／4x CPU 首屏 | 現況 Web export 已建立；數值由 `test_r25_web_performance.mjs` 補入 before JSON | 主視覺焦點 `<=3000ms` 且 interactive delta `<=10%` |
| 新視差 VRAM | 0 | high/med 9 層 `<=64MiB`；low 6 層 `<=32MiB` |

> Stress 現況量測發生在共用 6 線機台高負載期，依協定標註「併發、不可信」。不得以它宣告退化或放行；交付前保留原始失敗並隔離重跑。

## 可命令化驗收

1. `tools/check_r25_parallax_gates.py`：逐檔尺寸、WebP、RGBA VRAM、C2PA master 摘要、manifest hash、中央玩法帶局部對比／雜訊、low 真素材與 3/2 層數量全部硬斷言。
2. 同腳本以 1920×1080、1024×768、390×844 三視口執行 cover/crop 幾何，焦點 bbox 必須完整落在安全區。
3. UI 文字區以背景取樣計算 WCAG contrast，最小值 `>=4.5:1`，輸出 JSON。
4. low/med/high 每主題並排證據圖由確定性腳本產出；low 僅停用近景，仍載入同主題 far + mid 真素材。
5. `tools/test_r25_web_performance.mjs`：Fast 3G（1.6Mbps down／750Kbps up／150ms RTT）與 CDP 4x CPU，寫入 performance mark，主視覺 `<=3s`、interactive 對 before `<=+10%`。
6. CI 同款：`python tools/build_font_subset.py`、`python tools/check_sprite_luminance.py`、Godot Web export；另跑 README 全量 Godot regression、既有 Playwright 控制守門、R25 專項 gates。

## 硬預算設計

- runtime 固定 `1536×768` WebP；每層解壓 `1536×768×4 = 4,718,592 bytes = 4.50MiB`。
- high/med：9 層，共 `42,467,328 bytes = 40.50MiB`。
- low：三主題各 far + mid，共 6 層，`28,311,552 bytes = 27.00MiB`。
- 單層低於 `2048×1024`；runtime 與 master 分離，master 保留原始 C2PA。

## 實作與回滾

- `ArenaBackground` 建立三個獨立視覺 layer root；physics root／collider 不受影響。
- high/med 顯示 far/mid/near；mobile/low 顯示 far/mid，近景關閉。
- runtime 引用使用 `?v=<runtime sha256 前 8 碼>`；`SpriteLoader` 僅在載入時剝除 query，manifest 仍保留完整 hash。
- 回滾：`git revert <R25 commit>`；舊 R24 背景程式與資產由 git 歷史完整恢復。

