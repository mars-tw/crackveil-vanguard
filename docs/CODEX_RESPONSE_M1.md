# M1 手機體驗優化回報

狀態：已完成實作、回歸、字型重跑與 Web release 匯出。未 git commit / push。

## 工學參數

- 手機 camera：一般 `1.56`，threat zoom `1.36`；桌面維持 `1.28 / 1.12`。
- 搖桿：直式預設半徑約 `94px`，橫式約 `78px`；熱區倍率 `1.24`。
- 技能鈕：直式 `92x92px`，橫式 `84x84px`；右下 safe bottom + 24/18px。
- 暫停鈕：上緣 safe top，直式 `104x76px`，遠離右下技能熱區。
- 結算主按鈕：手機直式把 `繼續無盡` / `再來一局` 移到最下方拇指帶。

## 可讀性與 HUD

- 技能鈕新增冷卻環；冷卻中保留淡 radial fill，外圈顯示剩餘比例，ready 時完整綠圈。
- 手機敵彈改為橘亮核心 + 深色外緣，trail alpha 提高。
- 手機 hazard telegraph 新增粗暗邊與更粗主輪廓：外圈 7px 暗邊 / 4.5px 主邊。
- 手機傷害字：cap `30`，merge radius `82`，merge age `0.34s`，字級 cap `20px`。
- 手機 HUD 戰鬥中只留 HP、等級/XP、時間、擊殺；金幣/殘響進暫停頁 run stats。
- COMBO / toast / milestone 位置上移到安全中上區，避開左右下拇指遮擋。

## Mobile LOD

Mobile LOD 自動由 mobile/touch/narrow viewport 或測試 force setting 啟用；桌面檔位不變。

| 項目 | Desktop | Mobile LOD |
| --- | --- | --- |
| Death burst particles | 1.0x | 0.6x |
| Damage number cap | 48 | 30 |
| Hazard tick interval | 0.24s base | 0.372s base |
| Corpse ghost live cap | 24 | 12 |
| Death burst live cap | 20 | 12 |
| Background redraw | 0.08s | 0.14s |
| Background decor target | 96 | 69 |
| Background ambient lines | 18 | 8 |

StressTest p95：

| 情境 | avg ms | p95 ms | p95 FPS | 備註 |
| --- | ---: | ---: | ---: | --- |
| Desktop LOD off | 13.177 | 31.197 | 32.05 | `mobile_lod=false` |
| Mobile LOD on | 7.837 | 15.331 | 65.23 | `mobile_lod=true` |

p95 改善：`31.197ms -> 15.331ms`，約 `-50.9%`。兩者 pool exhausted / duplicate / foreign release 皆為 0。`STRESS_PERF_BELOW_60=true` 仍會因 max spike/min FPS 判定印出，但 mobile LOD 的 p95 已回到 60fps 內。

## 流程摩擦

- 升級卡手機首點改為確認狀態，第二點才選取。
- 契約卡手機同樣新增首點確認，避免滑動/誤觸直接開局。
- 契約 / 升級卡手機間距提高到 26px horizontal / 22px vertical。
- 教學與結算按鈕維持 `MobileTuning.touch_target()` 下限；M1Regression 鎖矩形。

## 回歸

已通過：

- Headless project load。
- `PoolContractTest`
- `GameplayCapTest`
- `MobileInputSmokeTest`
- `WeaponSmokeTest`
- `SquadSmokeTest`
- `BalanceMockRun`
- `ArenaInstrumentationRun`
- `OrbitBladeHitRepro`
- R5 / R6 / R7 / R10_5 / R11 / R12 / R13 / R14 regression。
- `M1RegressionTest`
- `StressTest`
- `MobileLodStressTest`

`ArenaInstrumentationRun` 同步修正短窗檢查：所有滿編武器仍必須 trigger；穩定輸出武器必須有 DPS。`echo_hymn` 屬輔助/近身 pulse，16 秒固定路線可能 trigger 但未命中，因此不再錯誤要求短窗 DPS。

## 字型與 Web

- `python tools/build_font_subset.py`：PASS。
  - Project Han coverage：`534/534`。
  - Output font bytes：`1,517,152`。
- Web release export：PASS。
  - `export/web/index.pck`：`4,420,376` bytes。
  - `export/web/index.js`：`node --check` PASS。
