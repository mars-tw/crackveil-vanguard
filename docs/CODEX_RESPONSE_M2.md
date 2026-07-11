# Crackveil Vanguard — Codex 回應 M2

基準：`5aa1a45`；Godot 4.7 stable；日期：2026-07-11。未 commit、未 push。

## 結論

M2 完成。Stress 現在固定 seed、固定實際畫布、先預熱再量測，並在結尾列出所有 `>20ms` 幀與對應事件。尖峰主因不是 pool 擴容、精英/Boss 或音效，而是同幀大量擊殺造成的掉落／死亡表現、敵人與投射物回補，加上敵人 reacquire 時重建 `SpriteFrames`；另有首輪資源／記憶體暖機干擾。

### Stress 前後（411 measured frames）

M1 前值取自 `docs/CODEX_RESPONSE_M1_debate.md` 的同機 headless 記錄。M2 後值使用 seed `52002`、桌面 `1280×720`、mobile LOD `390×844`、180 幀 warm-up 的最終隔離重跑。

| 情境 | M1 p95 / max | M2 p95 / max | 變化 |
|---|---:|---:|---:|
| Desktop Stress | 17.179 / 56.699 ms | **14.552 / 24.282 ms** | p95 -15.3%；max -57.2% |
| Mobile LOD Stress | 22.920 / 31.468 ms | **14.949 / 24.338 ms** | p95 -34.8%；max -22.7% |

兩檔最終都只記到 2 個 `>20ms` 幀，pool exhausted／duplicate／foreign release 皆為 0。`STRESS_PERF_BELOW_60=true` 仍誠實保留，因 max 仍高於 16.7ms；不宣稱已達「每一幀 60fps」。

## 尖峰處理

- Stress 固定 seed `52002`，並把 `content_scale_size` 明確鎖為桌面 `1280×720`、手機 `390×844`；修掉舊 mobile headless 實際渲染 `1280×2770` 的失真基準。
- 180 幀 warm-up 後才開始 411 幀量測；輸出 pool 數、紋理 cache、音效 runtime、進化預熱數，以及每個 `>20ms` 幀的 spawn wave／擊殺／精英／Boss／紋理首用事件。
- 戰鬥常用紋理與敵我走路幀預熱；Web 音效仍由 `AudioManager` 啟動時整批載入，headless 明確回報 `audio_runtime=false`。
- 敵人的 `SpriteFrames` 依 sprite path 共用快取，不再每次 pool reacquire 重建資源。
- 常規 XP／金幣掉落改為 deterministic physics FIFO，每 physics frame 6 組；滿 queue 時直接結算，不吞玩法結果。
- 死亡殘影／爆散改為純視覺 FIFO，每 frame 5 組，queue cap 72；Stress 最終 queue drops = 0。
- Stress 補怪／補彈由單幀 24／8 降為 6／4；既有 pool 預配數不膨脹。
- 多次擊殺／拾取的 HUD stats signal 同幀合併為一次 deferred emit；數值仍立即更新。

## 390×844 手機美術 pass

- 戰場：手機 CanvasModulate 改為冷青 `0.82/0.86/0.98`，壓低偏亮螢幕的綠／紅飽和感，保留裂隙高光與角色辨識。
- Web 響應式：Browser QA 找到 `aspect=expand` 把 CSS 390×844 變成 Godot 1280×2770，導致 UI 縮在左上；現在 Web CanvasLayer 以實際 CSS 視窗排版並補償邏輯縮放，戰場世界座標不變。
- 標題：直式雙行 LOGO、中央主操作、種子列與縱向裂紋視線軸重新平衡；390×844 實際 Web 畫面目視通過。
- 升級卡：標準青、質變紫、進化金三層；進化 4px 金框＋較強光暈，質變加明確標籤。
- 契約卡：依卡位使用青／紫／橙／綠高影響框，增加「裂隙契約 · I/II/III/IV」層級；Web 字級鎖定，避免 Canvas 補償後二次放大重疊。
- 技能鈕：深色半透明玻璃、亮邊、冷卻環；按下 0.9x、放開 back-ease 回彈。
- 搖桿：雙層玻璃底、內弧高光、旋鈕亮斑；按壓 0.92x 動畫，熱區仍維持 1.24x。
- 首次教學也套用 Web CSS 座標補償，避免在手機中央縮成小窗。

## Grok M1 P2 清理

- 商店不可逆購買：手機改為同卡兩次點擊確認，補上「普通升級有保護、商店反而無保護」的反置。
- 傷害數字仍明確維持「區域傷害聚合器」而非 hit log；合併目標由第一個符合者改成半徑內最近者，降低跨敵跳併，不改傷害結算。

## 回歸與字型

- `M1RegressionTest`：PASS
- `M2RegressionTest`：PASS（色階、390 menu、卡片層級、玻璃控制、商店確認、SpriteFrames cache、分幀 budget）
- R5、R6、R7、R10_5、R11、R12、R13、R14：PASS
- PoolContract、GameplayCap、MobileInput、Weapon/Squad smoke、Orbit repro：PASS
- 字型重建：專案漢字 `560/560`；指定新增字串全覆蓋；OTF `1,517,152 bytes`。
- 決定性：hazard gameplay tick 仍固定 0.240；LOD 只改 visual redraw。掉落 FIFO 每 physics tick 固定 6 組，順序固定，overflow 直接結算。

## Web 匯出

- `export/web/index.pck`
- 大小：**4,458,264 bytes**（低於既有 5MB 預算）
- SHA-256：`e9e301487abcff1b88b0fc43f9d3870425b4be3c6592a5acef3d710cc4625ed6`

