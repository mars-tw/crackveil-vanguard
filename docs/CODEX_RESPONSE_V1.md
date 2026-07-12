# Crackveil Vanguard — V1 視覺監工施工回應

對照：`docs/GROK_REVIEW_V1.md` 全文，依 §4 排序施工。基線 HEAD：`040ac2c`。日期：2026-07-13。未 commit、未 push。

## 裁決（壓縮）

| 項目 | 施工 | 驗收 |
|---|---|---|
| 爆炸曲線 | Explosion／Death／Boss Line2D ring 統一 `ease=1-(1-t)^2.5`；alpha 改 `(1-t^1.6)×k`。第 3 層煙視覺壽命為主體 `1.42×`，主形先收、煙尾續留；2 層 LOD 不延壽。 | M4 regression 鎖「早段位移 > 尾段位移」與煙跨主體壽命；無新貼圖／節點／粒子。 |
| 武器色分離 | 冰青簇拉為飽和 cyan（裂線）、深 periwinkle（軌道）、淡冰寬刃（迴旋）、近白狙擊（rail）；Void Net 壓深紫，避開 Boss 熱洋紅。trail 再以細長／近白細線／寬淡刃分形。 | 軌道–rail RGB 距離鎖 `>0.35`（舊約 0.13）。 |
| 敵我／色盲 | 普通敵彈沿用既有 glow，改為全平台 normal-blend 深輪廓；亮 ember 芯＋暗 silhouette 為第二通道。玩家 ember 武器仍是 additive，Boss ring 保留 flare／洋紅。 | M4 regression 鎖敵彈深輪廓；不只靠紅綠色相，紅弱／綠弱仍可按明暗與輪廓辨敵我。 |
| Boss 光階 | 外層直徑 `5.1→5.85r`、alpha `0.22–0.38`；內核 `2.35→1.95r`、alpha `0.68–0.90`。各層改用自身 base scale，不再耦合 ThreatGlow。Phase 2 外層轉熱紫、內核紅熱 `(1,.16,.30)`；反相呼吸與 Mobile 單光保留。 | M4 regression 鎖 alpha 階梯、二階紅熱與 Mobile 單光。 |
| 命中微反饋 | 所有 `take_damage()` 路徑（彈道／軌道／鏈／區域／Echo）收斂到同一 `0.08s` 暖白閃＋`0.10s` squash；連續命中用 `max` 保留脈衝，不重置成更短。 | M4 regression 鎖統一時長；無額外 burst／相機震動成本。 |

## 回歸

- Godot 4.7 headless load：PASS，無 parse/load error。
- 完整 debug suite：**20/20 PASS**。M1 的 350ms 真實確認窗以自然時鐘跑；其餘固定 60fps。含 9 人／11 槽 WeaponSmoke、Arena instrumentation、Balance mock。
- 擴充 `m4_regression_test.gd`：曲線、煙尾、色距、敵彈 silhouette、Boss 光階／Phase 2、命中時長均有契約。
- `git diff --check`：PASS。

## 效能（誠實邊界）

契約未改：seed `52002`、180 warm-up、411 measured、150 enemies、80 背景 projectile；Stress 實際仍為 `composite_layers=2`，故本輪第 3 層煙延壽完全不進滿場熱路徑；Boss 光亦不在此 scenario。

本輪**未能取得可與 M4_fix `16.961/14.918ms` 對比的乾淨機況**：清除本輪殘留 Godot 後，空載 CPU 20 秒中位仍約 `29%`（M4_fix 記錄為約 `8.1–15.3%`），存在範圍外 Claude／音訊／遠端／擷取程序，不擅自終止。預熱已達 Desktop/Mobile p95 `78.259/70.167ms`，故正式數字明確標記 `contaminated_external_load_CPU29pct`，不得冒充回退：

| 模式 | p95 三次 (ms) | 中位 | avg 中位 | max 中位 | 契約 |
|---|---|---:|---:|---:|---|
| Desktop | 77.864 / 75.005 / 78.487 | **77.864** | 50.702 | 125.440 | `STRESS_PASS`；絕對效能不可比 |
| Mobile | 70.788 / 70.082 / 71.156 | **70.788** | 46.852 | 96.771 | `STRESS_PASS`；絕對效能不可比 |

結論：pool／cap／LOD／玩法契約全綠，且本輪新增電影感不進 150 敵兩層熱路徑；但「乾淨機況不回退」的數字簽核仍應在 CPU 回到 M4_fix 區間後補跑，不能以這批污染值宣告達標。

## Web／pck

- `--headless --export-release "Web" "export/web/index.html"`：PASS。
- `node --check export/web/index.js`：PASS。
- `export/web/index.pck`：**4,656,272 bytes**（4.4406 MiB），相對 M4_fix `+4,240 bytes`。
- SHA-256：`ce2397bb998bb264ec2ea929166a9a3f5289483954d5cc6344fa18629912a910`。

**總結**：§4 順位 1–4 已以純參數／既有節點完成；常態 3 層、高壓 2 層、Desktop feature 4 層與 Mobile 裁減均未放寬。唯一未簽核項是外部負載下無法取得的乾淨絕對 p95。
