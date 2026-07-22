實作者：Codex（GPT-5）

# R31 終局路徑自動化驗證報告

版本：`0.19.2-r31`；基線 HEAD：`d49a662`；分支：`main`。

## Hook 設計與正式建置隔離

新增 `scripts/debug/r31_endgame_qa_hook.gd`，支援 `near_boss`、`near_death`、`victory` 三條 QA 路徑。授權同時要求 debug executable 與 Godot user arg `--qa-endgame=r31`；未帶參數實跑會 exit 1。

Web release preset 排除 `scripts/debug/**`、`scenes/debug/**`。本機實際 `--export-release Web` 後，`index.pck` 對 hook marker、hook 檔名、R31 gate 場景與 debug 目錄逐項掃描皆為零命中。正式玩家無法取得或觸發 hook。

Hook 沒有直接偽造結算旗標：Boss 走既有 spawner 時間門檻；敗北走英雄 `take_damage()`、逐格死亡動畫完成、`player_died()`；勝利走 Boss `take_damage()`、逐格 hurt/death、`record_boss_kill()`。

## 新增 gate 與結果

新增 `scenes/debug/R31EndgameGate.tscn` 與 `scripts/debug/r31_endgame_gate.gd`，驗證：

- Boss runtime instance 於 180.0 秒門檻出現，`boss_spawned/boss_active` 同步。
- 英雄致命 impact 後先播放逐格死亡，再顯示「任務失敗」。
- 「再來一局」（重試）與「回主選單」按鈕可見、可輸入、signal 已接 Arena handler，且兩者實際可觸發。
- Boss 致命 impact 後先播放逐格死亡，再顯示「階段勝利」與擊破文案。
- release preset 隔離規則及授權 truth table。

輸出：`R31_ENDGAME_GATE_PASS boss=spawned defeat=visible retry=triggered main_menu=triggered victory=visible web_hook=excluded`。

## 結算 UI 裁決

未發現 production 結算 UI 缺陷。敗北標題、epilogue、重試與回主選單皆存在且可用；勝利標題與擊破文案正常。沒有為了 gate 改寫 UI 或放寬既有斷言。

## 完整驗證

- Godot 4.7 `--headless --import` 連續兩次：exit 0。
- 現行 scene gates 11/11：R14、R29MenuModal、R30PlaytestFix、R31Endgame、TrueAnimation、PoolContract、GameplayCap、Squad/Weapon smoke、EnemyArt、R25Parallax 全綠。
- Hook 負向 gate：缺少 user arg 時 exit 1；release truth table 不允許授權。
- Web release export/finalizer：`R31_PWA_FALLBACK_PASS`；PCK debug 資源掃描零命中。
- Active 版本鏈的前版完整字串零命中；歷史 R30 報告與 evidence 保留。
- 高信心秘密前綴與 private-key header 掃描：零命中。
- `git diff --check`：通過；既有 `docs/evidence/` 無修改。

## 版本鏈

- `project.godot`：`0.19.2-r31`，日期 `2026-07-22`。
- `README.md`、Web cache metadata、offline page、finalizer `RELEASE`/預設 evidence、R14 regression baseline：皆同步 `0.19.2-r31`。
- CI regression gate 加入 R31 場景與必要 QA user arg。

## 證據、提交與殘留風險

證據位於 `docs/evidence/r31/`；歷史 evidence 未覆寫。File-scoped commit hash 以最終回報為準；不 push。

開發中首版 gate 的結束清理曾重寫本機三個預設 Godot 存檔。此副作用已從 gate 移除，final gate 實跑確認預設檔時間戳 3/3 不變。兩個預設檔是該次 QA 新建；既存 `crackveil_achievements.cfg` 沒有備份，先前旗標狀態無法證明，列為本機資料殘留風險。正式程式與 release 包未包含這段 gate 清理。

其餘殘留：本輪只完成本機 release export，依限制未 push／未部署；部署後仍應用正式 Pages artifact 再做一次玩家端 smoke test。
