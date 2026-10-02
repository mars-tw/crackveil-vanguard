# R37 公開發布前的檔案與 CI 稽核

2026-10-02，獨立上下文，同模型。未登入帳號、推送、部署、啟動瀏覽器或 GPU。

稽核起點為 `main`／`faa09fd`；R32～R36 尚未提交。起始狀態共 55 個已追蹤變更、2,764 個未追蹤檔案，其中 docs 約 2,370 筆。不能直接把整個工作目錄全部加入公開 commit。

## 確定的 CI 阻擋與修正

| 項目 | 原始證據 | 處理方式 |
| --- | --- | --- |
| Web smoke 要求過期版本 | `tools/test_r33_web_smoke.mjs:26` 固定要求 `0.23.0-r35`，與目前 project／export／finalizer 的 `0.24.0-r36` 不符。 | 已回報 root。root 負責改為讀取 project.godot 的期望版本；此 review lane 未改該檔。 |
| 必要的 WebGL runtime JS 被忽略 | `.gitignore:18` 的 `*.js` 忽略 `web/webgl_state_cache.js`；`git ls-files web` 沒有該檔。`test_r36_webgl_state_cache.cjs:2` require 它，finalizer 也會讀取它。 | 已回報 root。必須加入精確 ignore exception 並 stage 該 runtime 檔；不只在本機 export 可讀到便算完成。 |
| R25 gate 要求目前背景使用舊素材 | `check_r25_parallax_gates.py:64/:109` 要求 9 個 R25 hash refs 出現在目前 `arena_background.gd`；現在該檔只有 R36 extends，9 項一定失敗。 | 依 root 指派已改 workflow，保留 9 份 R25 master 的 C2PA archive gate，改以新 `check_r37_release_assets.py` 檢查目前 runtime。舊 parallax 工具仍保留作歷史驗證。 |

新 portable gate 已實跑：`R37_RELEASE_ASSETS_PASS checks=31 failed=0`、exit 0。只使用 Python 標準函式庫、由 script 自己解析 repo root，沒有 Windows 路徑或額外執行環境相依。

檢查涵蓋 11 份實玩版本 runtime SHA-256、3 份 Web 相依檔、R35／R36 共 9 份來源 manifest 的 hash 與 bytes、寵物原畫 hash／36 個不同姿勢、project／finalizer／export meta 三處 release marker、所有 script／shader 的 `.uid` 配對，以及 workflow 的 28 個 regression scene。

## 必須一起提交的檔案

- 現有已追蹤的程式／weapon resource／font／project／export／workflow 變更，不能只提交 R36 的新檔。
- `scripts/`、`scenes/` 的新 gameplay 與 CI scene/script，及相鄰 `.gd.uid`／`.gdshader.uid`。起始有 66 份未追蹤 UID；不要把它們誤認為 `.godot` cache。
- 新 gameplay 包含 loot/equipment、stage/world map、critical、combat feedback/presentation、新 FX catalog、R36 loop background/topology、特殊菁英、skill/pet/director/shop/minimap。`scenes/pets/CompanionPet.tscn`、`scenes/ui/WorldMap.tscn`、`SummonShopScreen.tscn` 也要包含。
- Runtime bitmap：R33 keyart、R34 world_map、R35 character atlas／skill FX atlas、R36 四張 tile 與 landmarks、pet_atlas、critical_impact.wav，以及其 `.import` 設定。
- 歷史 CI fixture 仍讀取 `scripts/arena/r34_world_background.gd` 與六張 R34 map；所以 **從 Web export 排除原圖不代表從 Git 刪除**。R33 SVG／R33與R34 atlas 也仍有舊資產重建／fixture 相依，若保留相關 script 就一起 stage。
- Source provenance：R35／R36 `sources/` 與 JSON manifest，pet original／prompt／pose_manifest；新 release asset gate 必讀這些原畫。它們可排除遊戲 PCK，但在 source repo 必須存在。
- CI 新工具：`check_r37_release_assets.py`、`test_r32_loading_recovery.mjs`、`test_r36_webgl_state_cache.cjs`、修正後的 Web smoke；finalizer 與 `web/loading_recovery.mjs`／`web/webgl_state_cache.js`。

推薦 root 先 stage 已追蹤變更，再按 `scripts`、`scenes`、`resources`、完整必要 `assets` 與明列的 CI tools/web 檔分批 stage；最後讀 staged manifest。文件與證據另外挑選，避免 `git add .` 或 `git add docs`。

## 公開範圍、體積與可攜性

唯一超過 80 MiB 的非 export/cache 檔為 `docs/evidence/r35/playtest/video/page@6e55334bf1cd5ded57b9d486421b7046.webm`：88,954,903 bytes（約 84.8 MiB）。R36 另有約 45.6 MiB、30.3 MiB 的原始錄影。這些不影響 build，建議保留本機，只提交選定短版實玩影片／截圖與摘要。

`docs/evidence/` 有大量過程截圖、控制器 action history、舊失敗 log、CPU profile；發布不需要全部提交。`.audit-tmp` 與 credentials／機器設定也不應入庫。保留過去 R25 已追蹤的 9 個 master 與 quality 圖即可供 archive gate 使用，無需重複加入歷史 bulk。

公開前 root 尚需確認的文件清理：

- `assets/art/r35/source_manifest.json`、`assets/art/r36/source_manifest.json`、`assets/pets/r36/pose_manifest.json` 原本含本機 `C:\Users\...` 來源與 atlas 路徑。它們不是憑證，但公開 metadata 應改為 repo 相對位置與 imagegen 來源識別。新 portable gate 已使用 `name`＋repo root 定位，不依賴這些本機路徑。
- `docs/playtest/R36_PLAYTEST.md:20` 的「效能覆核」連結是本機 C:/ 位置；公開 docs 要改為相對連結。
- README 原本仍說未公開、提供 127.0.0.1 預覽，R37 發布完成後需指向已確認的 Pages URL，保留本機預覽作開發說明即可。
- 新增的 local Playwright controller／preview／perf tools 多份硬編碼另一個本機專案的 node_modules。它們**不在 CI 執行路徑**，不是 build 阻擋；可留本機，或改成 `UI_CAPTURE_PLAYWRIGHT`／`UI_CAPTURE_CHROME` 後再提供公開重跑方式。

`check_sprite_luminance.py` 仍預設舊 64px `true_character_atlas.png`，不能代表目前 R35 成人角色 atlas 的美術驗收。現有角色動畫、FX、R36 scene gates 與實玩證據仍要保留；後續若要顏色量測，需配合目前 128px layout 重新定義，不能把舊色彩 gate 的 PASS 當新角色品質證明。

## Export 與 PWA 核對

目前 export filter 保留 R35 atlas、R36 tiles／landmarks、寵物 atlas、world map；排除 debug scenes、舊 atlas、raw sheets、source／QA。新音效由 wav include filter 提供。finalizer 以實際 PCK hash 命名 mainPack，GL script hash 也納入 service-worker cache identity；focal、manifest、offline page、worklet references 都採相對 URL，可保留 GitHub Pages 的 repository 子路徑。

`R25`／`R33` 留在工具名、focal performance mark、預設 evidence 路徑屬歷史命名；影響發布的是實際 release marker、mainPack hash 與 runtime source存在，不能只因名字舊就刪除。發布仍需 root 在選擇性 staged manifest／乾淨 checkout 上重跑 gate、export/finalizer、Web smoke，並以實際 GitHub workflow／Pages 結果判定完成。本報告不宣稱已公開部署。
