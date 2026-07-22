# R31 終局路徑驗證證據

## Hook 與隔離

`scripts/debug/r31_endgame_qa_hook.gd` 只有在以下兩項同時成立時授權：

1. `OS.is_debug_build()` 為 true。
2. Godot user args 含 `--qa-endgame=r31`。

正式 Web preset 另以 `exclude_filter` 排除 `scripts/debug/**` 與 `scenes/debug/**`。本機 release export 完成後，對 `index.pck` 搜尋 hook marker、hook 路徑、gate 場景與兩個 debug 目錄皆為零命中。因此玩家端不只有「無入口」，而是根本拿不到這組 QA 資源。

## 終局流程

- 接近 Boss：hook 將既有 `GameManager.elapsed_time` 推進到 `EnemySpawner.boss_time`，再由原 `_process()` 門檻生成 `veil_gatekeeper`；未直接設定 `boss_spawned` 作假。
- 瀕死／敗北：hook 只把隊長設成 1 HP 並清除測試阻礙；gate 透過 `take_damage()` 套用致命 impact，等待英雄逐格 death animation 結束後才收到 `player_died()` 與敗北結算。
- 勝利：Boss 先由既有 spawner 生成，再透過 `take_damage()` 進入 hurt/death 流程；gate 等待 Boss 逐格 death animation 完成後才驗證 `record_boss_kill()` 與勝利結算。

敗北結算實例中的「再來一局」與「回主選單」按鈕均可見、未 disabled、可接收滑鼠／觸控。gate 同時驗證兩個 UI signal 已連到 Arena runtime handler，並在隔離 handler 後實際觸發各按鈕 signal。未發現結算 UI 文案、按鈕或流程缺陷，故沒有修改 production UI。

## 本機 QA 存檔隔離修正

開發中首版 gate 的結束清理曾把三個 autoload 存檔 helper 切回預設路徑並以 `reset=true` 寫入。複核後立即移除；final gate 僅使用 `r31_*_test.cfg`，並在執行前後比對三個預設存檔時間戳，結果為 `default_saves_unchanged=3`。

本機檢查顯示 `crackveil_settings.cfg` 與 `veil_echo.cfg` 是首版 QA 執行時新建；`crackveil_achievements.cfg` 原已存在但被首版清理重寫，目錄中沒有可用備份，因此無法證明其先前旗標狀態。這不影響 repository 或正式 Web runtime，但列為本輪本機資料殘留風險，不以猜測內容回填。

## 證據索引

- `gate_outputs.txt`：雙 import、11/11 scene gates、hook 拒絕與 save isolation。
- `release_isolation.txt`：release export、PCK 排除掃描與 SHA-256。
- `pwa_cache_verification.json`：R31 release/cache version 與 PWA finalizer 結果。
- `version_secret_checks.txt`：active 版本鏈、秘密掃描、diff/evidence 檢查。
