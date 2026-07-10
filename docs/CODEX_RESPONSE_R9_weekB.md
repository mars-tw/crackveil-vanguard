# CODEX RESPONSE R9 Week B

範圍：依 Grok R8 §5.2/§5.3 與 Grok R9 Week B 重排，完成可分享層。未 git commit / 未 git push。

## 成就 R9-2.1

新增 `AchievementProgress` autoload，存檔 `user://crackveil_achievements.cfg`，事件驅動，不做每幀輪詢。

成就 10 個：

1. 精英首獵：首次擊殺精英。
2. 武器覺醒：首次完成武器進化。
3. 守門者倒下：首次擊破 Boss。
4. 五人滿編：隊伍達到 5 人。
5. 裂殖目擊：首次遭遇裂殖精英。
6. 磁滯目擊：首次遭遇磁滯精英。
7. 疾閃目擊：首次遭遇疾閃精英。
8. 契約擴展：殘響 lifetime 解鎖契約槽 +1。
9. 五分鐘防線：單局存活 5 分鐘。
10. 殲滅 500：單局擊殺達到 500。

解鎖時排入 toast：「成就解鎖！{名稱}」。HUD toast 改成佇列，避免同時遇到 affix toast 時互相蓋掉。GameOver 顯示本局新解鎖與全成就清單；暫停面板也可看全清單，未解鎖灰態。

## 種子分享 R9-2.2

Arena 隨機局現在也會先產生非零 `current_run_seed`，再 `seed(selected_seed)`，所以每局都有可分享 seed。

- 暫停、GameOver、StageVictory 都有「複製本局種子」，使用 `DisplayServer.clipboard_set(str(seed))`。
- ContractScreen 新增一行 seed UI：輸入框、貼上、用種子開局。
- `GameManager.seed_from_text()` 取最後一段數字；非法或空白回傳 0，Arena fallback 隨機 seed。
- 同 seed 維持既有全域 RNG 基建，契約抽卡、波次、精英 affix、Boss 與掉落都走同一 run seed。

## 設定頁 R9-2.3

暫停面板改為可捲動設定頁：

- 音量 slider、靜音 checkbox：沿用 `AudioManager`，存 `user://crackveil_audio.cfg`。
- 顯示傷害數字：新增 `PlayerSettings`，存 `user://crackveil_settings.cfg`；關閉時 `EntityFactory.spawn_damage_number()` 直接略過 VFX。
- 螢幕震動：設定已存檔；目前專案尚無實作 shake source，保留為偏好開關。
- 重置殘響：按第一次進入確認態，第二次才 `MetaProgress.reset_progress()`。
- 重看教學：透過 `GameManager.guide_replay_requested` 叫回 `FirstRunGuide.force_show()`。
- 複製本局種子與成就清單也放在同面板。

## 色盲友善 R9-2.5

詞綴精英在既有色環外新增 `AffixMarker` Line2D：

- 裂殖 `affix_split`：三角記號。
- 磁滯 `affix_field`：方框記號。
- 疾閃 `affix_swift`：雙箭頭記號。

## cfg 韌性 R9-2.6

- `MetaProgress.load_progress()`：`user://veil_echo.cfg` 缺檔安靜初始化；檔案存在但載入失敗時安全重置並 queue toast「殘響存檔載入失敗，已安全重置。」
- `AchievementProgress.load_progress()`：成就 cfg 同樣缺檔安靜初始化；壞檔安全重置並 queue toast「成就檔載入失敗，已安全重置。」
- `PlayerSettings` 也做相同防線，壞設定檔回預設並提示。

## PRESSKIT R9-2.4

新增根目錄 `PRESSKIT.md`，包含 30 字 pitch、操作、特色、瀏覽器需求、線上網址、截圖位、MIT/第三方共作說明。README 已加連結。

專案版本同步為 `0.9.0-r9-week-b`。

## 驗證

- 字型子集：`python tools/build_font_subset.py`
  - Scanned project files: 99
  - Project Han coverage: 445/445
  - Output font bytes: 1,504,552
- Debug 矩陣：R5/R6/R7Regression、PoolContract、GameplayCap、MobileInput、WeaponSmoke、SquadSmoke、Stress、BalanceMock 全 PASS。
  - R7 新增：`R9_WEEK_B achievements=10 seed_ids=["contract_golden_famine","contract_blood_tax","contract_glass_magnet"] settings=true`
  - Stress：`enemy_group_scans=0`，各 pool `exhausted=0`，`STRESS_PASS`
  - 無 `ERROR:` / `SCRIPT ERROR`；`PoolContractTest` 仍會輸出預期 duplicate-release warning。
- Web export：第二次 `--export-release "Web"` 無 warning/error。
  - `export/web/index.pck`
  - size: 3,130,256 bytes

## pck

已重新匯出 Web build：`export/web/index.pck`。
