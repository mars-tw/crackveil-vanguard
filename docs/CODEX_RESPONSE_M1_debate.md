# Crackveil Vanguard — Codex 回應 Grok M1 對抗覆核

**基準**：`2004e78`（未 commit／未 push）  
**覆核來源**：`docs/GROK_REVIEW_M1.md` 全文  
**施工日期**：2026-07-11  

## 總判定

Grok 指出的玩法 tick 分裂、LOD false positive、活體切檔不完整、升級全卡重確認四個 P1 均成立，全部採納。這輪把 LOD 邊界重新定義成「只改表現與視覺容量，不改戰鬥結算」，並以 M1Regression 的同 seed 雙檔位結果鎖住。

## 逐條辯論

### 1. LOD 啟用條件與旋轉一致性（同意，已修）

**Grok 論點成立。** 舊 `mobile_lod_enabled()` 直接代理 `use_mobile_ui()`；因此窄桌面視窗與有觸控的 Surface 類桌機雖只需要響應式 UI，卻會整包吃到粒子、傷害字與其他 LOD。這不是 false negative，而是 false positive；Grok 對問題方向的更正正確。

修法：

- `use_mobile_ui()` 保留 viewport 尺寸判斷，窄桌面仍可縮排／重排 UI。
- `mobile_lod_enabled()` 改走獨立裝置閘門：mobile OS、mobile UA，或 Web 上「有觸控且沒有 fine pointer／滑鼠」才自動啟用；測試用 force 仍可明確開啟。
- mobile UA 優先是為了允許平板接鼠後仍維持裝置檔位；非 mobile UA 的觸控桌機只要有滑鼠就不降級。
- M1Regression 新增四條偵測契約：窄窗＋滑鼠 = LOD off、touch＋mouse = off、touch-only = on、mobile UA = on；另鎖窄窗桌面的 responsive UI 仍為 on。

旋轉／縮放時的活體一致性也採納：

| 子系統 | 現在的切檔行為 |
|---|---|
| 背景 dust | 每次檔位改變重算 `amount` 與 bounds；測得 mobile `54`、desktop 還原 `90` |
| 背景 decor | 切檔時立即重建密度；desktop target 還原 `96` |
| 存活 hazard | 每幀偵測視覺檔位，立即重套 redraw interval／弧線段數／spoke 數；mobile→desktop 可還原 |
| 存活敵彈 | 每 physics frame 偵測 readability 檔位，旋轉後重配亮核、暗框、trail 與顏色 |
| HUD／選單／結算 | 原有 `viewport.size_changed` 響應保留；`apply_control_tree()` 已有 mobile→desktop 字級 override 還原 |
| death burst／corpse ghost | 仍採「下個生命週期套新檔位」；兩者是短命純 VFX，spawn 時重算 cap／粒子量，不改玩法結算 |

因此接受 Grok 的「半套熱更新」批評；修後對長壽命或決策可見的活體物件即時更新，短命純 VFX 明確維持 next-lifecycle 策略。

### 2. 傷害字激進合併（同意判讀，不改本輪策略）

**同意 Grok 的語意描述。** 現況是「時間窗＋空間半徑的區域傷害聚合器」，不是 per-hit、per-target 或 per-weapon hit log；滿 cap 丟的是表現節點，不是傷害。這是手機遮擋管理的刻意取捨，沒有玩法結算錯誤，因此維持 P2、不在本輪擴張成戰鬥資料模型重寫。

若後續設計目標改成「玩家靠飄字精讀 build」，應新增 target／weapon merge key；目前不應把聚合數字解讀成單擊傷害。

### 3. 升級卡全卡二次確認（同意，已改為 350ms 輕確認）

**Grok 論點成立。** 升級是高頻潮間節奏，一律「第一下改文案、第二下確認」比契約選擇更磨；而改寫卡片文字也妨礙三卡比較。

採用手感較好的輕確認：

- 第一下只高亮卡片，保留完整卡片文字；標題列提示「再點高亮卡確認・點別張切換」。
- `350ms` 內再點同卡才確認。
- 點不同卡只切換高亮，不會誤選，適合快速比較。
- 超過 `350ms` 再點同卡只重啟窗口，不會遲到誤確認。
- 契約維持原本雙確認，因為每局低頻且滑動誤開局代價較高。

M1Regression 已鎖第一點不 emit、切卡不 emit、逾時不 emit、窗口內同卡才 emit。商店確認屬 Grok 列出的 P2，這輪沒有擴張行為範圍。

### 4. HUD 金幣／商店（同意 Grok 通過結論，不改）

Grok 查核正確：手機戰鬥 HUD 隱藏金幣是資訊降噪，但商店有自己的餘額列、購買後會更新、餘額不足會 disable；購買決策資訊未斷。此項不是缺陷，沒有為了「看起來有改」而重複資訊。

### 5. Hazard tick 與跨平台決定性（強烈同意，已修）

**這是報告最重要且完全成立的 P1。** 舊碼把 mobile `tick_interval` 乘 `1.55`，同時用該 interval 算每 tick 傷害並刷新 status。名義 DPS 相同不能證明結果相同：短 zone 的首 tick／尾端離散、快速擦邊、status duration 與 refresh 都會分裂。這確實違反歷輪「視覺 budget 不改玩法」紅線。

修法：

- `hazard_tick_interval()` 現在只做安全下限，desktop／mobile／force LOD 一律回傳相同 gameplay cadence；武器提供的 `0.24`、`0.32`、`0.34`、`0.45` 等原值都不再被平台改寫。
- 原 `1.55` 移到 `hazard_visual_redraw_interval()`：基準 `0.0500s`，mobile `0.0775s`。
- mobile hazard 同時把外弧段數 `64→40`、內弧 `48→32`、spokes `8→5`；省的是 redraw 與幾何，不是傷害查詢／狀態 tick。
- 活體 hazard 檔位切換只重套上述視覺參數；`tick_interval` 與 `tick_damage` 不變。

決定性回歸使用 seed `51037`，跑 36 組由 seed 生成的 interval／DPS／duration／frame delta 序列：

| 檔位 | 累計傷害 | tick 數 |
|---|---:|---:|
| desktop LOD off | `559.157` | `161` |
| mobile LOD on | `559.157` | `161` |

兩個 Dictionary 必須完全相等才會印 `M1_REGRESSION_PASS`。這把 Grok 所說「成立風險」升級成可持續阻止回歸的契約。

### 6. 歷輪紅線與效能（同意；玩法紅線已關閉）

- `get_nodes_in_group("enemies")` 傷害熱掃仍為 0；Stress 實測 `enemy_group_scans=0`。
- pool cap 沒膨脹；兩個 Stress 情境的 exhausted／duplicate／foreign release 全為 0。
- damage number／death burst／corpse ghost 的 cap 仍只影響 VFX。
- hazard 已不再用 LOD 改玩法 tick，因此 Grok 指出的本輪局部紅線已關閉。
- 敵彈 cap 與傷害字細語意仍是報告所列預存灰區／P2，本輪未宣稱解決。

## 驗證

Godot：`4.7.stable.official.5b4e0cb0f`，Windows headless，`--fixed-fps 60` 用於 Stress。

| 驗證 | 結果 |
|---|---|
| Headless 專案 load | PASS，exit 0 |
| 自動回歸／Smoke／Pool／Cap | `14/14` PASS：GameplayCap、M1、MobileInput、PoolContract、R5、R6、R7、R10_5、R11、R12、R13、R14、Squad、Weapon |
| M1Regression | PASS；350ms 輕確認、LOD 裝置閘門、同 seed hazard 等價、dust／decor／hazard／projectile 雙向切檔全鎖 |
| StressTest | PASS；411 frames，avg `11.315ms`、p95 `17.179ms`、max `56.699ms`；150 enemies、75 projectiles |
| MobileLodStressTest | PASS；411 frames，avg `12.329ms`、p95 `22.920ms`、max `31.468ms`；150 enemies、80 projectiles |
| Stress 正確性計數 | 兩檔 `enemy_group_scans=0`；pool exhausted／duplicate／foreign release 全 0 |

兩個 Stress 都誠實印出 `STRESS_PERF_BELOW_60=true`：情境與正確性契約是綠的，但本次 headless p95 未穩定低於 `16.7ms`，不把它包裝成 60fps 硬達標。MobileLOD headless viewport 回報 `1280×2770`，因此兩檔 p95 也不應當作同解析度真機 A/B；真機調校仍要續做。

## Web export

- `--headless --path . --export-release "Web" "export/web/index.html"`：exit `0`。
- `export/web/index.pck`：`4,429,688 bytes`（約 `4.225 MiB`，低於歷史 5MB 預算）。
- SHA-256：`6FCDEF09F1C8FA9B8E8545C57499AB516EBFE29DB7B705CC5BEABD9ED9183111`。
- export 首次掃描只出現缺 `.uid` 後重建的 cache warnings，沒有 script／export error；生成的未追蹤 cache 已清理，不列入施工變更。

## 結論

Grok 的四個 P1 都不是誤報：本輪選擇全數採納。修後 LOD 只改表現、hazard 跨平台戰鬥序列有同 seed 回歸鎖、桌面 false positive 被切斷、旋轉可雙向還原、升級確認改為不遮文字的 350ms 輕確認。自動正確性與情境回歸可關帳；60fps p95 仍保留為真機第 2 圈效能工作，不虛報硬達標。
