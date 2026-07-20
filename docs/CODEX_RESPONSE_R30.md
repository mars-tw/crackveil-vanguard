實作者：Codex（GPT-5）

# R30 PLAYTEST-R1 修正報告

版本：`0.19.1-r30`；基線 HEAD：`a977c25`；分支：`main`。

## 五項修正

1. **R1-01 844×390 HUD 重疊**：橫向矮視口改成 118 px 高的四層 HUD（HP／等級／經驗文字／經驗 bar），並對 mobile landscape 設 24/18/16 px 字級上限。Playwright 進入實際戰鬥後量得相鄰區塊至少 3 px 間距，目視截圖亦無重疊。
2. **R1-02 方向切換種子列裁切**：Web 補 `resize` 與 `orientationchange` hook，延後兩 frame 重排，並在每次重算前清除 row/input/button minimum size。390×844 → 844×390 → 390×844 後 row 右緣 370.5 px，按鈕完整可見。
3. **R1-03 首次簡報雙影／後方 UI 透出**：layer 45 新增全視口不透明 backdrop（alpha 1.00、mouse STOP），panel 亦提高不透明度；契約 layer 25 與 HUD layer 10 不再透出。
4. **R1-04 成就鎖定 tofu**：定位舊字元為 U+25A1 `□`；runtime 改用 UI 子集涵蓋的 U+9396 `鎖`，並重建 Noto Sans CJK TC UI subset，758/758 專案漢字覆蓋。
5. **R1-05 離線 reload 白頁**：採「輕量 navigation fallback」方案。Web shell 顯式註冊 SW，離線 reload 回 `index.offline.html`；頁面清楚說明約 40 MB 遊戲不支援完整離線遊玩。WASM/PCK 不做 install pre-cache。Playwright 驗證 SW activated、offline reload 顯示「裂隙需要連線」。

## 驗證

- Godot 4.7 `--headless --import` 連續兩次：exit 0。
- Godot scene gates：10/10 通過，包含 R14、R29MenuModal、R30PlaytestFix、TrueAnimation、Pool、GameplayCap、Squad/Weapon smoke、EnemyArt、R25Parallax。
- Web gates：R25 Fast3G/4× focal 395.9 ms（預算 ≤3000 ms），TTI delta -48.05%；R22 controls 8 種 viewport；R30 Playwright 844×390／旋轉回直向／SW offline fallback 全通過。
- Art gates：sprite luminance、C2PA 9 masters、R25 parallax 73 checks、R24 art 全通過。沒有產生新 AI 圖。
- `git diff --check`、active 版號掃描、秘密掃描全通過；歷史 evidence 零 diff。

## 版本鏈

- `project.godot`：`0.19.1-r30`，日期 `2026-07-20`。
- `export_presets.cfg` Web cache metadata：`0.19.1-r30`。
- `README.md`、finalizer `RELEASE`、R14 regression baseline、Web offline page：同步 `0.19.1-r30`。
- 前一版完整字串在 active source 中零命中；歷史 R29 報告與 evidence 保留原始紀錄，不覆寫。

## 證據與殘留

- 詳細前後差異、佈局參數與本地截圖 hash：`docs/evidence/r30/R30_BEFORE_AFTER.md`。
- 結構化 PWA／效能結果：`docs/evidence/r30/pwa_cache_verification.json`、`docs/evidence/r30/web_performance.json`。
- 功能殘留：無已知項目。
- 流程殘留：正式部署後截圖由總稽核補入；本輪未 push，且未加入 `docs/audit_openclose/`、`docs/playtest/`。
