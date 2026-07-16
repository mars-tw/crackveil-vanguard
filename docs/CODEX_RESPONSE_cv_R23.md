# Crackveil Vanguard R23 P2 清理輪

## 結論

R23 完成小輪 P2 清理：三組零引用死資產已從 `assets/sprites/` 刪除，Web `index.pck` 從 `6,570,852` bytes 降至 `5,713,152` bytes，淨減 `857,700` bytes。R14、TrueAnimation、Web export 均 exit 0。

本輪未改 R21/R22 美術輸出、TrueAnimation atlas、角色動畫邏輯或匯出證據圖。

## 已完成

- 刪除 `hero_guardian.png`、`hero_scout.png`、`_atlas_all.png` 及各自 `.import`。
- 保持 `export_filter="all_resources"` 不變；因檔案未移入 `res://docs/archive`，不需新增 archive exclude。
- 掃描 runtime 路徑與新 export：`hero_guardian`、`hero_scout`、`_atlas_all` 在 export log 與 pck binary 均 0 命中。
- 版本 bump：`project.godot` 與 README 更新到 `0.17.0-r23`；R14 版本鎖同步 r23。
- README 測試章補上 Pool、GameplayCap、Squad、Weapon、EnemyArt 等權威 debug 入口，關閉「只列 R14/TrueAnimation」的文件快項。
- `SquadSmokeTest.tscn` 改指向 `scripts/debug/squad_smoke_test.gd` wrapper，避免 Squad/Weapon 兩個場景在報表上完全指向同一腳本。

## P2 順掃結果

已安全處理：

- `GROK_ASSET_AUDIT.md` P2-01：`_atlas_all.png` 死資產移出打包路徑。
- `AUDIT_full.md` README 測試章不完整：已補測試入口。
- `AUDIT_full.md` SquadSmoke/WeaponSmoke 同腳本：已拆成獨立 scene script path，兩入口均 pass。

已確認前輪已處理，R23 不重動：

- `ConfigFile.save()` 回傳值：`player_settings.gd`、`audio_manager.gd`、`first_run_guide.gd` 已檢查 error 並 `printerr`/toast。
- Web 自動化漏 console/request failure：`tools/test_controls_reachability.mjs` 已監聽 `console`、`requestfailed`，並有白名單。
- 雙指觸控 E2E：同檔已有 `exerciseTwoFingerTouch()`。

留待後續：

- BGM/PWA/主選單資訊架構/教學入口/種子錯誤 UI/永久資料管理位置/升級池 RNG/手機角色視覺比例等，均牽涉 UX、產品決策或較大玩法面，未納入 R23 小輪。

## Gate

- `R14RegressionTest`：exit 0，`R14_REGRESSION_PASS`。
- `TrueAnimationRegressionTest`：exit 0，`TRUE_ANIMATION_REGRESSION_PASS`，`heroes=10 unique_cells=10 poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0`。
- `SquadSmokeTest`：exit 0，`WEAPON_SMOKE_PASS`。
- `WeaponSmokeTest`：exit 0，`WEAPON_SMOKE_PASS`。
- Web export：exit 0，`export/web/index.html`、`.js`、`.wasm`、`.pck` 產出成功。
- pck：`6,570,852 -> 5,713,152` bytes，delta `-857,700` bytes。
- 秘掃：高風險 token/私鑰 regex 掃描 0 命中；`gitleaks`、`trufflehog`、`git-secrets`、`detect-secrets` 本機未安裝。

Evidence: `docs/evidence/R23/test_gates.txt`。

