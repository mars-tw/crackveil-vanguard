# R43 手機內容與操作優化

2026-10-15；遊戲版本 `0.28.0-r43`。本機功能與自動驗證：VERIFIED。計畫：[OPTIM_PLAN_R43.md](OPTIM_PLAN_R43.md)。

## 本輪改進

1. **手機換陣**：保留點按循環，長按 0.35 秒展開三陣形直選。選項同時說明攻守代價，取消不換陣；冷卻仍顯示目前陣形。支援一指搖桿、另一指長按／直選，拖出取消，暫停、旋轉與失焦會收起選單。修正 Web 畫布縮放的觸點換算與觸控合成滑鼠事件干擾。
2. **可玩的短局目標與戰鬥遭遇**：十關各有三枚徽記。實際走位 160 並用過三種陣形、擊敗兩名菁英、擊破 Boss，各完成一項。32 秒預告、38 秒加入該關主題菁英；Boss 真正進入半血階段後預告，兩秒後加入一名護衛。敵人滿池時保留待生成狀態，成功生成才記錄。既有 Boss 招式、真逐幀動畫、命中幀與死亡回收流程保留。
3. **局外收藏與成長**：三十枚徽記首取各給殘響 3／5／8，可購買既有升級；每關三枚集齊增加全隊傷害 1%，上限 5%。存檔保存、防跨局重領；寫入失敗回復獎勵與徽記狀態。主選單「殘響升級」頂端進入分頁收藏，每關有解鎖紀錄。

戰鬥常駐提示會依走位、換陣與擊殺進度改變；暫停「本局」先顯示三項目標。手機直、橫向皆可操作。字型改用 2 倍取樣並重建繁中子集，修正實際 Web 畫面中可重現的模糊字樣；補正暫停目標字級與橫向提示重疊。

## 驗證與證據

| 狀態 | 實際指令／檢查 | 結果與路徑 |
|---|---|---|
| VERIFIED | `python tools/run_r43_checks.py --godot <Godot 4.7 console> --node <node>` | CI 原有 37 場景＋R31EndgameGate＋R42＋R43，共 **40／40**；CI 三支 Node 測試 **3／3**。[逐項命令與 exit code](evidence/r43-mobile/gates/summary.json) |
| VERIFIED | `godot --headless --fixed-fps 60 --path . res://scenes/debug/R43MobileTacticsTest.tscn` | **228 項**檢查；六視口、雙指、取消、真實走位與敵人死亡、Boss 半血事件／兩秒預告、十關設定、滿池、收藏導覽、獎勵買升級、存檔重讀、防重領與寫入失敗回復。[mechanics.json](evidence/r43-mobile/mechanics.json) |
| VERIFIED | 同一 R43 場景以 Godot **4.7.2** 再跑 | **228 項**通過。[相容性紀錄](evidence/r43-mobile/godot-4.7.2-compatibility.txt) |
| VERIFIED | `node tools/test_controls_reachability.mjs` | **8／8** 視口，含 390×844 DPR 3、844×390 DPR 3、平板與矮桌機；按鈕、重疊、暫停／返回、雙指、資源錯誤檢查。[results](evidence/r43-mobile/controls/playwright_results.json) |
| VERIFIED | `node tools/r43_mobile_playtest.cjs before`／`after` | before／after 各 **3／3**；手機使用 Chromium CDP 實際雙指接觸序列，含收藏翻頁／關閉、長按直選與暫停。[after-web.json](evidence/r43-mobile/after-web.json) |
| VERIFIED | `node tools/test_r33_web_smoke.mjs` | 實際快速進場、移動、斬擊與擊殺。[web-smoke.json](evidence/r43-mobile/web-smoke.json) |
| VERIFIED | `python tools/check_sprite_luminance.py`、`verify_r25_c2pa.py`、`check_r37_release_assets.py`、`check_r38_content_assets.py` | 四支素材閘通過；R37 **31／31**，角色亮度／飽和度、歷史來源與十關資產完整。見本目錄四份 `*-gate.txt`／`*-assets.txt` |
| VERIFIED | `python tools/build_font_subset.py` | 本次產物涵蓋 **983／983** 專案繁中字；取樣改善經實際截圖比對。[font-build.txt](evidence/r43-mobile/font-build.txt) |
| VERIFIED | `python tools/check_r43_release.py --previous-version 0.27.0-r42` | 執行期舊版號零命中；秘密掃描採指定正規式、忽略大小寫，包含本機忽略匯出檔，排除 `.git`／`node_modules`；零命中。原生保護欄位相同。[release-audit.json](evidence/r43-mobile/release-audit.json) |

既有控制測試原先以快速出擊等待契約，但快速出擊從 R33 已略過契約。本輪改走既有「種子出擊」測契約；所有原有契約、教學、尺寸與重疊斷言保留。快速出擊另由 Web smoke 驗證。選單探針改在字型與容器排版完成後發布，避免拿前一輪寬度判斷重疊。

截圖均由**無頭 Chromium 實際算圖**取得，沒有啟動可見視窗，也沒有以原生 headless 幾何結果冒充截圖：

- [390×844 before](evidence/r43-mobile/before-390x844-battle.png)／[after](evidence/r43-mobile/after-390x844-battle.png)／[陣形直選](evidence/r43-mobile/after-390x844-formation.png)／[目標](evidence/r43-mobile/after-390x844-objectives.png)。
- [844×390 before](evidence/r43-mobile/before-844x390-battle.png)／[after](evidence/r43-mobile/after-844x390-battle.png)／[陣形直選](evidence/r43-mobile/after-844x390-formation.png)／[目標](evidence/r43-mobile/after-844x390-objectives.png)。
- [1366×600 before](evidence/r43-mobile/before-1366x600-battle.png)／[after](evidence/r43-mobile/after-1366x600-battle.png)；收藏頁另有三視口 `after-*-collection.png`。

## 原生、素材與提交範圍

- 原生 `nativeVersion=1.0.0`、`nativeBuild=3` 保留；Android 兩個 preset 的 version/code 與 iOS application/version 均未改。原生設定只更新 `sourceVersion`，export preset 只更新 Web cache 版本。沒有重新匯出原生包、操作商店、push 或部署。
- 沒有新增人物／地圖點陣素材或音樂。沿用既有具臉部、四肢姿勢、hurt／death 的角色與六種菁英資產；沒有程序化方塊替代物，也沒有聲稱使用新的圖像模型。
- 本輪測試產生的舊輪追蹤報表回復原樣；起始未追蹤檔案保留，不納入提交。新增證據集中於 `docs/evidence/r43-mobile/`。

## 未完成、風險與缺件

- **BLOCKED：實機證據**。本輪只有本機無頭驗證，未取得 iOS／Android 實機多指、瀏海安全區、長時間溫升與穩定性證據。
- **BLOCKED：出貨效能閘**。同機有其他線路，本輪未取得乾淨條件下三跑 p95。R41RuntimeBudgetTest 只證明配置規則，不代表通過效能出貨閘；任何並發數字均只能標「並發載量測，僅供參考」。
- **BLOCKED：獨立對話覆核**。DevSpace `chatgpt_list_workers` 回傳 `Internal error`，沒有可驗收的獨立回覆；未繞過確認、開啟瀏覽器送工作或冒稱另一模型已審查。
- 新護衛提高單局壓力，徽記提供額外早期殘響與最高 5% 成長。既有平衡／戰鬥回歸通過；仍欠多日留存與實機長局難度評估。
- 本輪功能沒有待補的圖／音檔。全新 Boss 造型與新配樂未製作，未列為完成項目。

繁中文案依 mode 2 直接套用：原「三種戰場每局隨機抽選其一」已落後十關選關流程，改為十關選擇、戰術目標與收藏說明；原冷卻只顯示數字會失去目前陣形資訊，改成「陣形名稱＋秒數」。
