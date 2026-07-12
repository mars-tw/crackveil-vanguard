# Crackveil Vanguard — M4 畫面強化深度輪

基線：`37f19c2`。Godot `4.7.stable.official`、Web/GL Compatibility、2026-07-12。未 commit、未 push。

## 各項落點

1. **爆炸／命中合成**
   - `explosion_area.gd`：池內單節點改為核心閃光 → 主爆形 → 衝擊環 → 煙環／碎片的四層時序；面積、升級層級、進化會放大合成。
   - `death_burst.gd`：同一 `death_burst` pool 新增 `elite_death`、`boss_phase`、`boss_death` 三套 preset；普通命中仍沿用共用 preset。
   - `entity_factory.gd`：延續 M2 prewarm/pool/cap；Desktop 4 層，Mobile LOD 2 層（主形＋衝擊環，關閉核心柔光、煙、碎片）。
   - 未增加貼圖；重組既有 12 張 Kenney Particle Pack CC0，故 `assets/CREDITS.md` 的來源／衍生表不需變更。

2. **11 個裝備槽的武器辨識**
   - `weapon_data.gd` 把 `visual_level` / `evolved_visual` 傳入彈體與效果；每級約增加 4.5–7% 光暈／軌跡／爆炸尺寸，進化再增加 24–28%。
   - 固定語言：裂線＝青色細長直束；雷鏈＝白紫鋸齒；榴彈＝橘色拋物拖曳；狙擊＝長青色貫通軌；飛彈＝薄荷彈芯＋灰煙尾；迴旋盾＝寬冰藍刃；脈衝＝橘色多層花爆；虛空網＝紫色區域；Echo＝金色光柱／連線；Orbit＝冰藍旋刃。
   - Stress 的 11 槽含隊長與線癒者共用裂線原型，因此是 10 套武器形語言、11 個實際裝備槽。

3. **Boss 戲劇化**
   - `enemy.gd`：Boss 專用雙層 additive 體積光、加大底影、階段二加速脈動；兩層光只在 Boss acquire 時建立，不污染 220 隻普通敵人的 pool 熱路徑。
   - 二階觸發池化 `boss_phase` 全場環、背景反色閃與全場衝擊波；Boss 死亡使用獨立 `boss_death` 合成。
   - Boss 環彈改 Kenney flare 專屬紋理、白紫彈芯與脈動光暈，不再共用普通紅彈。

4. **場景光影氛圍**
   - `arena.gd`：隊長掛持久預載的徑向 additive 柔光，Desktop 620px、Mobile 390px。
   - `arena_background.gd`：vignette Desktop alpha `0.72`；餘燼主題偶發火星雨、虛空主題裂隙微光脈衝；Mobile 關閉瞬時主題層。

5. **UI 微打磨**
   - `level_up_screen.gd`：卡片依序 80ms 滑入＋Back ease；hover/focus 微抬；行動裝置二次確認卡使用循環發光邊框。
   - `game_over_screen.gd`、`stage_victory_screen.gd`：存活時間、等級、擊殺、精英、金幣、殘響 0.85–0.90 秒 ease-out 滾動計數。

## Stress 前後

同機、同 seed `52002`、180 warm-up、411 measured frames、`--fixed-fps 60`。本輪施工前環境明顯慢於 M3 留檔（M3 留檔 Desktop/Mobile p95 為 `14.574/13.940ms`），所以簽核使用同一輪同機 A/B，不混用歷史機器狀態。

| 情境 | M4 施工前 p95 / max | M4 完工 p95 / max | p95 |
| --- | ---: | ---: | ---: |
| Desktop 1280×720 | 51.012 / 76.168 ms | **30.940 / 45.917 ms** | -39.35% |
| Mobile LOD 390×844 | 27.581 / 38.034 ms | **27.356 / 38.577 ms** | -0.82% |

兩檔 `STRESS_PASS`；150 enemies、80 background projectiles、11 武器槽皆有 trigger；`enemy_group_scans=0`；所有 pool exhausted / duplicate / foreign release = 0。兩檔仍誠實輸出 `STRESS_PERF_BELOW_60=true`，不把 headless 尖峰包裝成 60fps 真機達標。

## 回歸、字型、Web

- 最終程式全套 debug：**20/20 PASS**（M1/M2/M3/M4、R5/R6/R7/R10.5/R11/R12/R13/R14、PoolContract、GameplayCap、MobileInput、Weapon/Squad、Orbit repro、Arena instrumentation、Balance mock）。
- M4Regression 鎖定四層／兩層 LOD、三套死亡 preset、爆炸四層、武器成長 stats、Boss 雙光／專屬環彈、卡片 tween 與結算 count-up。
- 字型：掃描 152 檔，專案漢字 **562/562**；OTF `1,517,152 bytes`。
- Web export / `node --check export/web/index.js`：PASS。
- 本機瀏覽器：主選單 → 首跑說明 → 契約卡 → 實戰皆可進入；Canvas 正常縮放，無 `SCRIPT ERROR`。仍只有專案既有 missing-UID text-path fallback warning。

## pck

- M3：`4,625,856 bytes`
- M4：**`4,649,456 bytes`**
- 增量：**`23,600 bytes`（0.0225 MiB）**；低於 +1MiB 預算，尚餘 `1,024,976 bytes`。
- SHA-256：`e817167e8c385a5e5531447b00cdb6b40688c5120e6cba57ed0d8aeb4b9d273e`
