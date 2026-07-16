# Crackveil Vanguard cv R22 全面優化計畫

日期：2026-07-16
目標版本：v0.17.0-r22
依據：`game-optimization-round` 固定派工技能、`AGENTS.md`、`docs/AUDIT_full.md`、`docs/GROK_REVIEW_hero10.md`
施工限制：R21 角色美術剛完成，本輪不改角色美術資產與真動畫資產。

## R22 驗收主線

1. 效能紅線改成硬失敗門檻：`StressTest` 在乾淨/指定機況下若 `avg_fps < 55`、`p95_ms > 18`、`avg_ms` 較基線惡化超界或 `min_fps` 過低，必須輸出失敗並以非 0 exit 結束；不得再在 26.86 FPS 類情境印 `STRESS_PASS`。
2. 滿編壓測場景需包含 9 人、10 英雄池、11 武器、牧者、全進化/高載狀態，並保留 spatial query、pool、爆炸/傷害數字等關鍵量測。
3. 390x844 直式手機 HUD 改版：頂部血量/等級/XP 與右側快捷列不得侵入；暫停面板開啟時不得與外部暫停鈕相交或同時可操作。
4. 控制可達性測試擴充為真觸控矩陣：至少包含 390x844、844x390、1024x768、1366x600 等視口與 touch/coarse pointer 形態，加入 rect intersection、捲動與雙指搖桿+技能檢查。
5. 10 英雄/11 武器平衡驗收重做：用 BalanceMock/ArenaInstrumentation 輸出前後值，特別把裂隙牧者實戰份額從 0.72% 拉回設計帶，並防止榴彈等單一來源極端壟斷。
6. 首玩情境教學補齊：契約、招募、隊長死亡即全滅、羈絆、進化、商店/Boss 節點應有可回看教學；主選單/暫停頁能進入玩法索引。
7. 無障礙承諾修正：若未完成色盲模式就移除宣稱；本輪至少加入 UI scale 與高對比設定，並把設定接入 HUD/教學/主要 modal。
8. 三戰場產品承諾短期明確化：README 與遊戲內文案改成「每局從三種戰場隨機抽選其一，Boss 後可無盡」，避免暗示單局三關進程。
9. 技能/回饋面向補輕量音訊：若既有音效不足，加入程序化 WebAudio/AudioStreamGenerator 後備音效，覆蓋攻擊命中、升級、招募、受傷、Boss、UI，並整合音量設定。

## 八大面向逐項計畫

### 1. 美術
- 不改 R21 角色美術；保留角色真動畫與色彩雙閘門。
- 檢查本輪 UI/教學/高對比調整不破壞既有視覺層級。

### 2. 按鈕
- 修正 390x844 暫停鈕/面板幾何碰撞。
- 所有新增教學、設定與玩法索引按鈕維持 44px 以上命中區。
- RWD/觸控矩陣加入按鈕矩形不相交斷言。

### 3. 選單
- 暫停頁補玩法/教學入口與 UI scale/高對比設定。
- 主選單標示三戰場短期承諾，避免「橫越三種戰場」誤導。
- 新增或調整 modal 必須可關閉、返回鈕可見。

### 4. 人物
- 不變更 R21 人物資產。
- 平衡儀表納入 10 英雄實戰份額，避免人物定位只停留在美術完成。

### 5. 地圖模型
- 保留現有三主題戰場素材；短期以產品文案明確「每局抽選其一」。
- 選單顯示目前將隨機抽選戰場，不承諾 Boss 後換場。

### 6. 技能
- 補足技能回饋音效與音量設定。
- 牧者/11 武器平衡輸出用儀表約束，不只檢查有無命中。

### 7. 角色樣子
- 不改 R21 角色圖；跑既有 TrueAnimation 與美術相關回歸確認未退化。
- 高對比設定只調 UI/可讀性，不重新染角色。

### 8. 動作流暢度
- 保持真幀動畫、impact frame 與 hurt/death 回歸。
- `TrueAnimationRegressionTest` 必須 exit 0。

## 固定品質閘門

- `R14RegressionTest` exit 0。
- `TrueAnimationRegressionTest` exit 0。
- 新 `StressTest` 紅線 exit 0，且在低於閾值時能 exit 非 0。
- 控制可達性/真觸控矩陣 exit 0，包含 390x844 與 844x390。
- 平衡儀表 exit 0，報告牧者與 11 武器前後值。
- Web export 成功。
- 版本 bump 到 `v0.17.0-r22`，舊版號 grep 歸零。
- 秘密掃描零命中：排除 `.git`、`node_modules`、export/build 產物。
- before/after 證據與三視口截圖寫入 `docs/evidence/R22/`。
- 完成 `docs/CODEX_RESPONSE_cv_R22.md`。
- 本地 commit，繁中訊息，不 push。

## 預期證據

- `docs/evidence/R22/stress_before_after.txt`
- `docs/evidence/R22/balance_before_after.txt`
- `docs/evidence/R22/controls_results.json`
- `docs/evidence/R22/390x844_hud_after.png`
- `docs/evidence/R22/844x390_touch_after.png`
- `docs/evidence/R22/1366x600_after.png`
- `docs/evidence/R22/web_export.txt`
- `docs/evidence/R22/secret_scan.txt`
- `docs/evidence/R22/test_gates.txt`
