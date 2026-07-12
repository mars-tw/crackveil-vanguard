# Crackveil Vanguard — V2 宣傳截圖監工施工回應

對照：`docs/GROK_REVIEW_V2.md` §2 與其餘 P1。基線 HEAD：`900831c`。日期：2026-07-13。未 commit、未 push。

## 施工裁決（壓縮）

| 項目 | 落地 | 邊界／驗收 |
|---|---|---|
| C1 危機符號 | Boss Phase 2 事件新增熱紅「裂隙過熱｜BOSS PHASE II」短橫幅與危機色溫；三種精英 affix marker 半徑放大約一檔、線寬 `3→4`。 | 複用既有 HUD／Line2D，不加 gameplay 系統；R14 鎖橫幅存在與 heat-red。 |
| C2／C3／C4 拍攝故事 | `PRESSKIT.md`「截圖指南」明訂小隊錨點、每圖 8–15% 地圖主題錨、契約／詞綴／進化因果符號，以及 HUD／負空間比例。 | 空間與小隊缺口以拍攝選幀解，不新增常駐關係線或重資產。 |
| 安全時刻窗 | 寫入 5 個黃金窗與主視覺黑名單：Boss P2 0.5–2.0s、55–95 敵、爆炸煙尾前 40%、精英交火、卡面／結算；禁 ≥120／150 敵封面、臉 crop、腳部、前 20s 空場、全 mint 後期。 | 與既有 `<120` 三層、≥120 兩層 LOD 契約一致。 |
| 三鏡構圖 | L1 主宰對峙、L2 火力語彙、L3 規則張力，加六類硬規則與三個固定檔名。 | 明示 orbit–rail 優先、避開 boomerang–rail 近白雙線。 |
| Debug 截圖模式 | Debug build 按 `F12` 切換，或以 `--screenshot-beauty` 啟動：藏 HUD／虛擬搖桿，切換後新生 Explosion／Death Burst 固定 4 層。再次按 F12 恢復 HUD 與 adaptive LOD。 | `OS.is_debug_build()` 雙重門檻；release 不啟用；不改傷害、敵數、spawn、時間或玩家設定。R14 鎖 normal=3、beauty=4。 |

## 回歸

- Godot 4.7 headless 全專案 parse：PASS；`git diff --check`：PASS。
- 完整非 Stress debug suite：**20/20 PASS**。M1 用真實時鐘，其餘固定 60fps；含 Arena instrumentation、Balance mock、9 人／11 槽 WeaponSmoke 與 R14 新增 press-capture 契約。
- R14 新契約：`R14_PRESS_CAPTURE phase_banner=heat_red adaptive_layers=3 beauty_layers=4`。

## Stress 契約（固定 seed 52002）

| 模式 | 場景 | avg / p95 / max | 契約 |
|---|---|---|---|
| Desktop 1280×720 | 150 敵、80 起始背景彈、2 層 | 50.532 / **78.533** / 134.314 ms | `STRESS_PASS`；`enemy_group_scans=0`；所有 pool `exhausted=0` |
| Mobile 390×844 | 150 敵、80 起始背景彈、2 層 | 46.923 / **70.845** / 95.448 ms | `STRESS_PASS`；`enemy_group_scans=0`；所有 pool `exhausted=0` |

兩者皆回報 `STRESS_PERF_BELOW_60=true`，且輸出標記 `machine_condition=UNSPECIFIED`；只簽 pool／cap／LOD／掃描契約綠，不宣稱本機絕對 60fps。Beauty 預設關閉，未進 Stress 熱路徑。

## Web／pck

- `--headless --export-release "Web" "export/web/index.html"`：PASS。
- `node --check export/web/index.js`：PASS。
- `export/web/index.pck`：**4,659,392 bytes**（4.4435 MiB），相對 V1 記錄 `4,656,272` 為 **+3,120 bytes**。
- SHA-256：`35d641ccb6126deb8c99ed6fe0f387a2ebe77ea4e1782f2174930a6df45d75e5`。

**總結**：V2 §2 已從建議變成可重複 SOP；P1 故事訊號補在既有節點，debug beauty 解決高光難重現，但正式玩家 LOD 與 Stress 契約未放寬。
