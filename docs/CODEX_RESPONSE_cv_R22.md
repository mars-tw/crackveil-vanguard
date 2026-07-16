# Crackveil Vanguard R22 收尾報告

版本：`v0.17.0-r22`

## 完成項目

- Stress gate 已改成硬性紅線：乾淨機況需 `avg_fps >= 55`、`p95_ms <= 18`、`min_fps >= 30` 且 R19 baseline delta 不超過 +10%；缺少 `baseline-source` / `machine-condition` 時不再默默 PASS。
- 已新增負向探針佐證：以 `--perf-gate-max-p95-ms=1.0` 故意收緊門檻時，Stress 子行程 `exit 1` 並輸出 `STRESS_FAIL`。
- 390x844 手機直向 HUD / 暫停面板碰撞已修正；Web DPR 版面改取 CSS viewport，Playwright 覆蓋 390x844、844x390、1024x768 與短桌機。
- 牧者已救回設計帶：舊稽核實戰份額約 `0.72%`，R22 後 Arena 儀表為 `15.02%`，BalanceMock 為 `16.51%`。
- 首玩情境教學改成多頁決策導覽，補契約、招募、羈絆、進化、商亭、Boss 與無盡流程。
- 移除「色盲輔助」假宣稱，改為實作並標示 `UI scale` 與 `高對比`。
- 三戰場文案已明確改為「每局依 seed 隨機抽選其一」。
- WebAudio / SFX 補程序化 fallback、alias 與音量設定保存失敗提示，整合現有主音量與靜音設定。

## 平衡數據

- Before：`docs/AUDIT_full.md` 記錄牧者 Arena 實戰約 `14.8 / 2051.1 = 0.72%`。
- After `BalanceMockRun`：`shepherd_weapon_share=0.1651`、`leader_dps_share=0.3904`、`BALANCE_MOCK_PASS`。
- After `ArenaInstrumentationRun`：`shepherd_weapon_share=0.1502`、`leader_dps_share=0.1248`、目標帶 `shepherd=0.08..0.18`、`ARENA_INSTRUMENT_PASS`。
- 壓力診斷 `Hero10BalanceInstrument`：`raw_shepherd_weapon_share=0.0420`、`group_scans=0`、`HERO10_PRESSURE_PASS`；同時揭露定點 AoE 飽和下榴彈 `top_share=0.5142`，保留為診斷警訊而非一般實戰判定。

## Gate 結果

- `R14RegressionTest`：PASS，見 `docs/evidence/R22/r14_regression.txt`。
- `TrueAnimationRegressionTest`：PASS，見 `docs/evidence/R22/true_animation.txt`。
- `StressTest`：PASS，`avg_ms=8.818`、`p95_ms=12.365`、`avg_fps=113.41`，見 `docs/evidence/R22/stress_after.txt`。
- `Stress` 負向門檻：PASS，預期非 0 且實際 `exit=1`，見 `docs/evidence/R22/stress_negative_gate.txt`。
- `Stress --mobile-lod`：PASS，`p95_ms=12.429`，見 `docs/evidence/R22/stress_mobile_lod_probe.txt`。
- `BalanceMockRun` / `ArenaInstrumentationRun` / `Hero10BalanceInstrument`：PASS，見 `docs/evidence/R22/` 對應檔案。
- Web export：PASS，見 `docs/evidence/R22/web_export.txt`。
- 390x844 與多 viewport 控制可達性：PASS，見 `docs/evidence/R22/controls_reachability.txt` 與截圖。
- 秘掃：PASS，零命中，見 `docs/evidence/R22/secret_scan.txt`。
- Gate 總表：`docs/evidence/R22/test_gates.txt`。

## 缺件揭露

- 本輪未新增外部音效檔；WebAudio 缺檔時使用程序化 SFX fallback，現有音量設定會套用到 fallback。
- 本輪未新增角色動畫素材；TrueAnimation gate 仍使用既有 frame-based atlas / impact frame 管線，未以整張圖平移、旋轉、縮放或 bobbing 假裝完成動畫。
- Web export 仍可能出現 Godot 匯出過程的 UID fallback 類警告；本輪 Playwright console 檢查已過濾已知非阻斷雜訊，實際控制可達性與 export 均 PASS。
