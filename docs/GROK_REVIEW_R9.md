# Crackveil Vanguard — 對抗性設計／程式審查 R9

**審查者**：資深遊戲設計師＋Godot 4 技術總監（對抗式；以工作區 **未提交 R9 變更** 為準，不採信 `CODEX_RESPONSE_R9.md` 語氣）  
**審查對象**：R9 Week A 發布品質衝刺（對照 `docs/GROK_REVIEW_R8.md` §5／§5.5）  
**對照**：`docs/CODEX_RESPONSE_R9.md`、`docs/GROK_REVIEW_R8.md`、HEAD `2bad09b` + working tree  
**方法**：`git diff` 靜態逐項讀碼（`game_manager`／`audio_manager`／UI／武器／CI／回歸）；**只審不改**  
**日期**：2026-07-10  

---

## 執行摘要

| 面向 | 判定 |
|------|------|
| R9-0.1 首局引導＋契約一句話 | **成立** |
| R9-0.2 死亡回饋閉環 | **成立**（殘響去向可讀） |
| R9-0.3 空池保底 3 卡 | **成立**（真空池才觸發；**不誤搶**正常池） |
| R9-0.4 版本／build date 顯示＋CI | **成立**（CI 只注 `build_date`，路徑正確） |
| R9-1.1 AudioManager 池化 12＋六槽＋節流 | **成立**（真池化；開火 70ms／命中 45ms 全域節流有效） |
| R9-1.3 affix toast＋進化金卡 | **成立** |
| 技術債 #2 owner 交疊／死亡清 UI | **主幹成立**（回歸補上 shop→upgrade→victory→death） |
| 保底卡經濟刷 | **可接受灰區 P2**（金幣可重複領；短路超載**不疊傷**只刷時長） |
| 教學／toast 擋輸入與 owner 衝突 | **主幹安全**；toast 預設 `Panel` 可短時攔截點擊（P2） |
| 死亡清 UI 含 game_over | **成立** |
| 死亡停音效 | **未完整**（播 `death`，**無** `stop_all`；短 SFX 實務可接受） |
| 歷輪紅線 | **未破**（無新 group 掃敵、無放寬 cap、Meta 幅度未動） |
| CODEX R9 宣稱 | **高可信**（路徑與文檔對齊；本輪未重跑 headless，以靜態＋回歸碼為準） |
| R9 總判定 | **Week A 清單實質落地，可維持「軟 Go／小圈試玩」**；硬 Go 仍差實機 3 機型與分享鉤子 |

**一句話**：R9 做的是「不要在宣傳片裡卡死／靜音／冷結算」的產品層，而且主幹碼對得上；剩下是經濟灰區、停音完整度與 Week B 可分享性。

狀態標籤：

- **成立**／**部分成立**／**未達設計意圖**／**殘留**／**預存灰區**／**發布缺口**

優先級：

| 等級 | 意義 |
|------|------|
| **P0** | 正確性、軟鎖、UI 謊稱、破 cap |
| **P1** | 體驗閉環、池健康、Web 熱路徑 |
| **P2** | 文案／作弊韌性／體感調校／內容擴充 |

---

## (0) 變更盤點（工作區 vs `2bad09b`）

| 項目 | 實況 |
|------|------|
| HEAD | `2bad09b`（R7 入版） |
| R9 狀態 | **未 commit** working tree |
| 體量（stat） | 19 files 已改 + 新檔 `audio_manager`／`first_run_guide`／`assets/audio/*`／`tools/generate_placeholder_audio.py`／`CODEX_RESPONSE_R9` |
| 宣稱範圍 | Week A P0/P1＋技術債 #2；**未做** hit-stop、Meta 入口完整化、Week B |

主要落點：

| 宣稱 | 主要檔案 |
|------|----------|
| 首局引導 | `scripts/ui/first_run_guide.gd`、`scripts/arena/arena.gd` |
| 契約說明句 | `scripts/ui/contract_screen.gd` |
| GameOver 閉環 | `scripts/ui/game_over_screen.gd`、`game_manager.player_died` summary 欄位 |
| 空池保底 | `game_manager.gd` `FALLBACK_UPGRADE_POOL`／`_build_upgrade_choices` |
| 版本／CI | `project.godot`、`hud.gd`、`.github/workflows/deploy-web.yml` |
| 音效 | `scripts/autoload/audio_manager.gd`、`assets/audio/*.wav`、武器／敵／GM 呼叫點 |
| toast／進化卡 | `game_manager.notify_affix_encounter`、`hud._on_toast_requested`、`level_up_screen` |
| owner 回歸 | `arena._hide_modal_screens`、`r7_regression_test` R9 兩測 |

---

## (1) Week A 七項逐條對抗驗收

### 1.1 R9-0.1 首局引導＋契約一句話

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 掛載 | `arena.gd:53-76` | `start_run` 後 `_attach_first_run_guide()` |
| UI | `first_run_guide.gd:13-73` | layer **45**、`PROCESS_MODE_ALWAYS`、全螢幕 `MOUSE_FILTER_STOP`；文案含 WASD／自動攻擊／三選一 |
| 關閉持久 | `:75-85` | `user://crackveil_guide.cfg` → `guide/disabled` |
| 契約句 | `contract_screen.gd:51-57`、`:199-201` | 「選一條本局規則——它會改變這一局的玩法」 |

#### 與契約／暫停 owner 關係

| 情境 | 結果 | 判定 |
|------|------|------|
| 正常開局 | `start_run` → `_request_contract` 已 `system_pause_owners["contract"]` 再掛引導；layer 45 蓋住契約 25 | **成立**（先教學、再選約） |
| 引導是否自佔 owner | **否**；依賴契約 pause | 主路徑 OK；debug 跳契約時引導**不**停時（預存邊角） |
| 擋手動暫停 | 契約中 `toggle_pause` 本就被擋（`game_manager.gd:996-998`） | **不衝突** |
| 解鎖 Web 音訊 | 開始鈕呼叫 `AudioManager.unlock_audio()`（`first_run_guide.gd:68-69`） | **成立** |

| ID | 命題 | 判定 |
|----|------|------|
| R9-0.1a | 首局半透明引導可關 | **成立** |
| R9-0.1b | 契約說明句 | **成立** |
| R9-0.1c | 不與 owner 互斥邏輯互踩 | **成立**（主路徑） |

---

### 1.2 R9-0.2 死亡回饋閉環

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 摘要欄位 | `game_manager.gd:1040-1054` | 補 `elites_spawned`、`boss_spawned`、`boss_active`、`boss_phase_two_reached` |
| 結算文案 | `game_over_screen.gd:64-141` | 存活評價、擊殺／精英、Boss 階段、契約、殘響去向（可買／累積到 N） |
| CTA | `:58-59`、`:182-188` | 大鈕「再來一局」 |
| 殘響 | `:123-141` + `MetaProgress.get_upgrade_cost`（`meta_progress.gd:150-154`） | 依 held shards 與下一軌成本 |

| ID | 命題 | 判定 |
|----|------|------|
| R9-0.2a | 評價／階段摘要 | **成立** |
| R9-0.2b | 殘響去向可操作敘事 | **成立** |
| R9-0.2c | 再來一局閉環 | **成立**（`restart_requested` → `reload_current_scene`） |

對抗註記（非否決）：評價門檻偏敘事（30／90／180／300s），非平衡斷言；可接受 Demo 級。

---

### 1.3 R9-0.3 升級池耗盡保底

#### 觸發條件（核心對抗）

```text
_build_upgrade_choices:
  pool ← PLAYER + squad/player.build_upgrade_pool
  filtered ← _is_upgrade_available
  choices ← _pick_weighted_choices(filtered, count)
  if choices.is_empty(): return FALLBACK ×3
```

| 位置 | `game_manager.gd:383-397`、`:477-478` |

| 情境 | `choices` | 是否保底 | 判定 |
|------|-----------|----------|------|
| 正常池有卡 | 非空 | **否** | **不誤搶** |
| 池只剩 1–2 張、需求 3 | `_pick_weighted_choices` 回 1–2 張（`while … and not candidates.is_empty()`，`:457`） | **否**（可點即非軟鎖） | **正確：非真空池** |
| filtered 全空 | 空 | **是** | **正確：真空池** |
| 權重全 0 | loop `total_weight<=0` break → 空 | **是** | 邊角合理 |

**結論：真空池（挑完仍 0 張）才觸發；不會在正常可選池時塞保底卡。**

#### 三卡效果與「刷經濟」

| 卡 | 實作 | 可重複？ | 疊加？ |
|----|------|----------|--------|
| 緊急整補 | `heal_members(18)`（`:483-488`） | 是（無 `max_level`） | 治癒量不疊乘 |
| 裂隙拾荒 | `add_gold(8)`（`:489-491`） | **是** | 每選 +8 金，**可刷** |
| 短路超載 | `_apply_temporary_squad_damage(12)`（`:492-494`、`:866-870`） | 是 | `temporary_squad_damage_timer = max(timer, duration)`；傷倍 `get_outgoing_damage_multiplier` 僅 **×1.15 單旗**（`:669-670`）→ **不可疊成 1.15ⁿ** |

| 防護 | 位置 | 行為 |
|------|------|------|
| 選完必解 pause | `apply_upgrade` + 回歸 | `waiting_for_upgrade=false`、release `upgrade` |
| 保底不開隨機商店 | `:420` `not was_fallback and randf()<0.1` | **成立** |
| 記帳 | `_register_upgrade_pick` 要求 `max_level>0`（`:435-438`） | 保底無 max → **永不耗盡**（設計使然） |

| ID | 等級 | 觀察 |
|----|------|------|
| R9-E1 | P2 | 長無盡空池後可每級 +8 金刷商店；**非殘響刷 Meta**，但屬經濟灰區。建議後續：保底金每局上限／遞減，或 `max_level` 記帳。 |
| R9-E2 | — | 短路超載**不可疊傷** — 對抗問題「可疊？」答案：**否**，只 refresh 12s。 |

| ID | 命題 | 判定 |
|----|------|------|
| R9-0.3a | 真空池才保底 | **成立** |
| R9-0.3b | 3 卡＋解暫停 | **成立** |
| R9-0.3c | 不誤搶正常池 | **成立** |
| R9-0.3d | 經濟不可刷 | **部分成立**（傷安全；金可重複領） |

回歸：`r7_regression_test.gd:530-570` `R9_UPGRADE_FALLBACK` — 以 null squad + 灌滿 `PLAYER_UPGRADE_POOL` 模擬空池；**簡化但路徑同源**。

---

### 1.4 R9-0.4 版本顯示＋CI 注入

#### 證據鏈

| 層 | 位置 | 行為 |
|----|------|------|
| 專案 | `project.godot:11-12` | `config/version="0.9.0-r9-week-a"`、`config/build_date="2026-07-10"` |
| HUD | `hud.gd:116-121`、`:242-253`、`:423-426` | 右下 `v{version}  {build_date}`；`ProjectSettings.get_setting("application/config/…")` |
| CI | `deploy-web.yml:99-124` | Export **前** Python 覆寫／插入 `config/build_date="YYYY-MM-DD"`；失敗 `SystemExit` |
| Autoload | `project.godot` | `AudioManager=*` 一併登錄 |

| 檢查 | 結果 |
|------|------|
| 注入鍵名是否對齊 Godot 檔案格式 | **是**（`config/build_date=` 在 `[application]` 段） |
| 僅 date、不改 version | **是**（合理；version 仍手維） |
| 是否污染 git | CI workspace 暫改、不 commit | **OK** |
| 本機 local 預設 | 缺鍵時 HUD `"local"` | **OK** |

| ID | 命題 | 判定 |
|----|------|------|
| R9-0.4a | HUD 顯示 | **成立** |
| R9-0.4b | CI build_date 注入正確 | **成立** |

---

### 1.5 R9-1.1 六槽音效＋池化＋節流

#### 池化（對抗「每發 new」）

| 層 | 位置 | 行為 |
|----|------|------|
| 建池 | `audio_manager.gd:111-120` | `_ready` 一次建 **12** 個 `AudioStreamPlayer` 子節點 |
| 取得 | `:134-143` | 先找 `not playing`；全忙則 round-robin `stop` 重用 |
| 播放 | `:76-94` | `play_sfx` **從不** `AudioStreamPlayer.new()` |
| 串流 | `:123-131` | 六槽 WAV 預載 Dictionary |
| Headless | `:39-42`、`:180-181` | headless 跳過池建，避免測試噪音 |

**判定：真池化，不每發 new。成立。**

#### 節流（高射速＋多英雄）

| sfx | cooldown | 位置 |
|-----|----------|------|
| fire | **0.07s (70ms)** | `SFX_COOLDOWNS` `:18-24`；`_cooldown_ready` 全域 `last_play_msec` `:146-154` |
| hit | **0.045s (45ms)** | 同上 |
| elite／death | 0.8s／1.0s | 防連發 |

呼叫點：

- 開火：`linear_bullet_weapon.gd:47-48`（**每輪開火一次**，非每彈）、`chain_lightning_weapon.gd:18-19`、`explosion_weapon.gd:29-30`
- 命中：`enemy.gd:460-461`（`take_damage`）
- 升級／契約／死亡／精英：GM／spawner／contract UI

| 對抗情境 | 結果 |
|----------|------|
| 5 英雄同時射 | 全域 fire id 共用 70ms → 最多 ~14 次/秒音訊事件 | **有效** |
| 多彈扇形 | 單次 `_fire_at` 只 `play_sfx` 一次 | **更省** |
| 軌道武器 | `orbit_weapon.gd` **無** fire sfx | 六槽覆蓋「開火」語意以彈射／鏈／爆為主；軌道是持續環，可接受佔位缺口（P2） |
| 滿場 hit | 45ms 全域 | **有效** |

#### 暫停音量／Web 解鎖

| 項 | 位置 | 判定 |
|----|------|------|
| 音量／靜音存檔 | `user://crackveil_audio.cfg`；`hud` 暫停面板 slider／checkbox | **成立** |
| Web 點擊開始 | `hud` `audio_prompt_button` + `AudioManager._input` 手勢 | **成立** |
| `PROCESS_MODE_ALWAYS` | 暫停中仍可播 UI 音／調音量 | **成立** |

| ID | 命題 | 判定 |
|----|------|------|
| R9-1.1a | 12 池化不每發 new | **成立** |
| R9-1.1b | 開火／命中節流有效 | **成立** |
| R9-1.1c | 六槽素材存在 | **成立**（`assets/audio` 六 WAV，合計 ~60KB 對齊宣稱） |
| R9-1.1d | 暫停音量／靜音 | **成立**（R9-2.3 最小版） |

---

### 1.6 R9-1.3 詞綴 toast＋進化卡強調

| 層 | 位置 | 行為 |
|----|------|------|
| 首次 | `game_manager.gd:1125-1129`、`seen_affix_toasts` 開局 clear `:227` | 每 affix 每局一次 |
| 觸發 | `enemy_spawner.gd:189-190` | spawn elite 時 |
| 顯示 | `hud.gd:411-420` | 1.5s、`create_timer(1.5, true)` process_always |
| 進化 | `level_up_screen.gd:64-70`、`:89-114` | `【武器進化】` + 金框 `StyleBoxFlat` |

#### toast 是否擋輸入／owner

| 檢查 | 結果 |
|------|------|
| 是否 `system_pause_owners` | **否** |
| 全螢幕擋操作 | **否**（頂部約 48px 條） |
| `Panel` 預設 `mouse_filter` | **STOP**（未顯式 IGNORE）→ 1.5s 內可能吃掉條帶內點擊 | **P2 灰區** |
| 與契約／暫停 | 不搶 owner；契約全螢幕本就 STOP | **不衝突** |

| ID | 命題 | 判定 |
|----|------|------|
| R9-1.3a | 首次 affix toast | **成立** |
| R9-1.3b | 進化金卡 | **成立** |
| R9-1.3c | 不擋主流程輸入 | **主幹成立**（條帶攔截 P2） |

---

### 1.7 技術債 #2：owner 交疊＋死亡清 UI

#### 升級 vs 商店／契約／勝利

| 機制 | 位置 | 行為 |
|------|------|------|
| 延遲升級 | `_can_request_level_up` `:498-506` | shop／contract／victory／death 期間不開 upgrade modal |
| XP 累積後消化 | `add_xp` while + `_close_shop`／`apply_contract`／`continue_after_stage_victory` 呼叫 `_try_request_pending_level_up` | **成立** |
| Boss 殺清 wait | `record_boss_kill` `:1087-1090` | 清 upgrade／shop／contract flags + `system_pause_owners` 後只掛 `stage_victory` |
| Arena 清 UI | `arena.gd:61-89` | victory／game_over 前 `_hide_modal_screens` |

#### 回歸

`r7_regression_test.gd:573-637`：

1. 開店 → owner=`shop`  
2. `add_xp` **不**開 upgrade  
3. skip 店 → 才開 upgrade  
4. `record_boss_kill` → 只 `stage_victory`，level-up UI 隱藏  
5. `player_died` → 只 `game_over`，其他 modal 隱藏  

打印：`R9_MODAL_OWNER_CLEANUP owners=["game_over"] gameover_visible=true`

| ID | 命題 | 判定 |
|----|------|------|
| R9-T2a | 店中不開升級 | **成立** |
| R9-T2b | 勝利／死亡清 UI | **成立** |
| R9-T2c | 覆蓋優於 R8 僅契約 vs 暫停 | **成立**（本輪補齊） |

---

## (2) 空池保底觸發正確性（專節）

| 問題 | 答案 | 證據 |
|------|------|------|
| 真空池才觸發？ | **是** | `choices.is_empty()` 才 `_build_fallback_upgrade_choices`（`:395-397`） |
| 會誤搶正常池？ | **否** | 有任何可加權選中的卡 → choices 非空 → 不進保底 |
| 少於 3 張時？ | 回 1–2 張正常卡，**不**混保底 | `_pick_weighted_choices` 耗盡 candidates 即停 |
| 實戰何時空？ | 個人 max + 武器數值 max + 質變／進化耗盡 + 滿編無招募 | R8 已標長無盡灰區；本輪閉環 |

**專節判定：觸發條件正確。**

---

## (3) 死亡清 UI 回歸：game_over 與音效

### 3.1 UI／owner

| 步驟 | 位置 | 結果 |
|------|------|------|
| flags | `player_died` `:1024-1031` | `is_game_over`、清 wait、**含** `stage_victory_pending=false`、清 owners |
| pause | `:1036` | 唯一 owner `game_over` |
| UI | `arena._on_game_over_requested` `:61-63` | hide 其他 modal → `show_summary` |
| 回歸斷言 | `r7:623-630` | 他 modal 不可見、game_over 可見 |

**判定：涵蓋 game_over 顯示與他 modal 清除 — 成立。**

### 3.2 音效停止

| 預期（對抗） | 實況 |
|--------------|------|
| 播死亡音 | `play_sfx("death")` `:1037-1038` — **有** |
| 停 fire／hit／elite 殘響 | AudioManager **無** `stop_all`／死亡時未遍歷 `players.stop()` | **無** |
| 池玩家 process | 父節點 `PROCESS_MODE_ALWAYS` → 暫停中音仍可播完 | 短 WAV（fire 75ms 級）實務可接受 |

| ID | 等級 | 結論 |
|----|------|------|
| R9-D1 | P2 | 死亡閉環 UI **完整**；音效「停止」僅部分成立（有 death、無強制 mute／stop 池）。若 Web 上長精英音與結算重疊感明顯，再補 `stop_gameplay_sfx()`。 |

**專節判定：UI 回歸成立；音效停止 = 部分成立。**

---

## (4) 歷輪紅線快檢

| 紅線 | R9 | 證據 |
|------|-----|------|
| 命中 token／傷害契約 | 維持 | 未改主結算，只加 hit sfx |
| max_enemies 150 | 維持 | 未動 spawner cap |
| 武器熱路徑 group 掃敵 | 維持 0 預期 | 武器只加 `play_sfx`；無 `get_nodes_in_group` |
| 池化子彈／爆炸 | 維持 | 未改 EntityFactory 熱路徑 |
| Meta 幅度政策 | 維持 | 未改 TRACKS 數值 |
| 決定性 seed | 維持 | affix toast 不吃額外 RNG |
| 新 P0 軟鎖 | **未發現** | 空池反而解鎖 |

---

## (5) CODEX R9 宣稱 vs 對抗結論

| 宣稱 | 對抗結論 |
|------|----------|
| 七項 Week A 落地 | **成立**（靜態證據鏈完整） |
| 保底不開商店、解 pause | **成立** |
| 12 池 + 節流 | **成立** |
| owner 回歸 | **成立**（碼在；本輪未重跑 binary） |
| 未做 hit-stop／Meta 入口／Week B | **屬實** |
| 未放寬 cap／group／Meta | **屬實** |
| 全 debug PASS／Web 匯出 | **未本輪複跑** → 標 **宣稱待複跑**（非否決；回歸碼已擴） |

---

## (6) 發現清單（只標不修）

| ID | 等級 | 項目 | 說明 |
|----|------|------|------|
| R9-E1 | P2 | 保底金幣可每級重刷 | 無 max_level；長無盡商店經濟灰區 |
| R9-D1 | P2 | 死亡未 stop 池內 SFX | 僅播 death |
| R9-T1 | P2 | toast `Panel` 預設 STOP | 頂部 1.5s 可能吃點擊；建議 `MOUSE_FILTER_IGNORE` |
| R9-G1 | P2 | 引導不自管 pause | 依賴契約；debug 跳約邊角 |
| R9-A1 | P2 | 軌道武器無 fire sfx | 六槽「開火」未覆蓋 orbit |
| R9-R1 | P2 | 空池回歸 null squad | 未灌滿真實武器池；邏輯同源但覆蓋偏簡 |
| R9-V1 | P2 | CI 不注 version | 只 date；version 手維 OK |

**無新 P0。**

---

## (7) 剩餘發布缺口重排（Week B 建議）

對照 R8 §5.5，Week A 已吃掉：引導、死亡閉環、空池、六槽音、版本、toast／進化、owner 債。  
音量／靜音已最小落地 → 原 R9-2.3 降級為「設定頁剩餘項」。

### 7.1 建議優先序（對外硬 Go 導向）

| 序 | 原 ID | 項目 | 新優先 | 理由 |
|----|-------|------|--------|------|
| 1 | R9-1.5 | **實機行動／直式 UI 3 機型** | **P1 → Week B-1** | 硬 Go 條件；Web 流量主力 |
| 2 | R9-2.2 | **種子複製分享** | **P2↑ 準 P1** | 零內容成本最高分享鉤子；seed 基建已有 |
| 3 | R9-2.1 | **本地成就 8 個＋結算彈出** | P2 | 延長回訪；可與死亡閉環同屏 |
| 4 | R9-2.3 餘 | **設定頁完整化**（傷害字／震動／重置 Meta） | P2 | 音量已有；重置 Meta 降客服成本 |
| 5 | R9-1.4 | **暫停／GO 顯示 Meta 三軌** | P1 殘 | 進度可讀；可併設定頁 |
| 6 | R9-1.2 | hit-stop／螢幕震 | P1 體感 | 不擋軟 Go；抬「手感產品」感 |
| 7 | R9-2.4 | Press kit 一頁 | P2 | 宣傳物料 |
| 8 | R9-2.8 | BGM loop 1 條 | P2 | 片感；可選 |
| 9 | R9-E1 等 | 保底金上限／toast IGNORE／死亡 stop_sfx | P2 打磨 | 防灰區與小糙點 |
| 10 | R9-2.6／B6 | cfg 韌性、裂殖文案 | P2 | 延後 |

### 7.2 Week B 建議切片

```text
Week B-1（硬 Go 前）
  • 實機 3 機型：契約／暫停／GO 按鈕 ≥44px、直式安全區
  • 種子「複製本局」按鈕（暫停或 GO）
  • （建議）toast mouse_filter IGNORE + 死亡 stop 池 SFX

Week B-2（宣傳升級）
  • 本地成就 8 + GO 彈「解鎖」
  • 設定：傷害字／震動／重置 Meta + 暫停顯示三軌等級
  • Press kit；可選 BGM
  • 保底金每局上限（若無盡長測確認可刷店）
```

### 7.3 Go／No-Go（R9 後更新）

| 門檻 | 條件 | R9 後狀態 |
|------|------|-----------|
| 軟 Go（小圈） | P0 全綠 + R5–R7 回歸綠 + group_scans=0 | **傾向達標**（待本機複跑確認綠） |
| 硬 Go（公開宣傳） | 軟 Go + 音效 + 引導 + 死亡閉環 + **實機 3 場無軟鎖** | **差實機驗證**；功能項大致齊 |
| 宣傳放量 | 硬 Go + 成就或種子 + 已知問題清單 | **未達**（Week B） |

---

## (8) 總表

| ID | 項目 | CODEX | R9 對抗 |
|----|------|-------|---------|
| 0.1 | 首局引導＋契約句 | 做 | **成立** |
| 0.2 | 死亡閉環 | 做 | **成立** |
| 0.3 | 空池保底 | 做 | **成立**（金可刷 P2） |
| 0.4 | 版本／CI date | 做 | **成立** |
| 1.1 | 六槽＋池化＋節流 | 做 | **成立** |
| 1.3 | toast＋進化金 | 做 | **成立** |
| T2 | owner／死亡清 UI | 做 | **成立** |
| — | 死亡停音 | （未強調） | **部分成立** |
| — | 紅線 | 未破 | **未破** |

---

## (9) 一句話結案

R9 Week A **經得起對抗覆核**：空池保底觸發條件正確且不誤搶正常池；AudioManager **真池化**且開火／命中全域節流在多英雄下有效；死亡 UI／owner 清理由回歸碼覆蓋；版本 CI 注入路徑正確；教學與 toast **不**破壞契約／暫停 owner 主幹。  

殘留是 **保底金幣可重複領**、**死亡未強制 stop SFX**、toast 點擊攔截等 P2，以及 Week B 的 **實機 UI／種子分享／成就**。  

**R9 總判：發布品質衝刺達標，可宣告軟 Go 級「可信可玩 Demo」；硬 Go 請用實機三機型與分享鉤子收尾，不要再開大系統。**
