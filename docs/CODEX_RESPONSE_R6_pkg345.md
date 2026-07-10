# CODEX_RESPONSE_R6_pkg345

日期：2026-07-10  
範圍：R6 路線圖包 3-5（精英詞綴、武器進化、Meta 殘響）

## 包 3：精英詞綴

1. `affix_split`：裂殖精英
   - 視覺：綠色 tint + `AffixRing`。
   - 行為：死亡時嘗試裂出 2 隻 `affix_split_spawnling`。
   - 紅線：使用既有 enemy pool；生成前用 `EntityFactory.get_enemy_active_count()` 夾住 `death_spawn_cap`。若精英死亡時已在硬 cap 邊界，只生成可容納數量，不突破 150。

2. `affix_field`：磁滯力場精英
   - 視覺：青色大半徑 `AffixRing`，半徑 128。
   - 行為：每 0.12s 對範圍內隊員套 0.2s、22% movement slow。
   - 紅線：不掃 `heroes` group；只讀 `GameManager.squad_manager.get_members()` 小陣列。

3. `affix_swift`：疾閃精英
   - 視覺：橘色 tint + ring，體型略小。
   - 行為：精英切成既有 `dasher` AI，dash speed 465，HP 較低但突進壓力更高。
   - 紅線：復用既有 dasher 狀態機，不新增 per-frame instantiate。

## 包 4：四把武器進化

所有進化都接在 `WeaponData.modifier_levels`，id 為 `evo_*`，升級三選一中以 weight 8 出現，選過後由 modifier 阻止再次出現。條件是該武器質變滿層 + run level 7。

1. 裂線發射器 -> `evo_rift_fan`「裂隙扇編」
   - 條件：`riftline_fork` Lv2。
   - 行為：射擊改成 3-5 發扇形；命中後裂片由 2 片改為 -30/0/+30 三向裂片。
   - 預算：裂片仍走 `fork_projectile` pool + cap 48。

2. 星環飛刀 -> `evo_shear_halo`「剪界星環」
   - 條件：`orbit_resonance` Lv1。
   - 行為：星環半徑脈動，命中除易傷外再套 slow。
   - 預算：不生新節點，只改 orbit projectile 既有運算。

3. 脈衝爆花 -> `evo_ember_well`「餘燼井」
   - 條件：`pulse_embers` Lv1。
   - 行為：餘燼 hazard 延長為 2.0s、低頻 tick，並對井內敵人套 slow。
   - 預算：仍走 `hazard_zone` pool + cap 8 + LRU。

4. 裂弧雷鏈 -> `evo_overload_nova`「超載新星」
   - 條件：`chain_overload` Lv1。
   - 行為：末端爆炸改為新星，並向附近最多 3 個未命中目標補放短弧。
   - 預算：查詢走 `EnemySpatialIndex.get_enemies_in_radius()`；VFX 走 `lightning_arc`/`explosion` pool。

## 包 5：Meta 殘響

新增 `MetaProgress` autoload，存檔為 `user://veil_echo.cfg`。結算發放採「目前結算應得總量 - 本局已發量」的 delta，避免 Boss 階段勝利後繼續遊戲造成重複領取。

三軌小升級：

1. `echo_vitality`「裂隙韌性」：每階 +2% 最大 HP，最多 5 階。
2. `echo_magnetism`「回收餘波」：每階 +6 拾取範圍，最多 5 階。
3. `echo_focus`「共鳴火花」：每階 +1.5% 全隊傷害，最多 5 階。

解鎖：

1. 累積 60 碎片：契約候選 +1。
2. 累積 120 碎片：第一次升級候選 +1。

碎片公式：`floor(gold_earned * 0.25) + floor(kills / 20) + floor(level / 3) + elites_killed * 2 + boss_killed ? 8 : 0`，30 秒以上保底 1。使用 `gold_earned`，不懲罰商店消費。

## 和 Grok 設計不同處

- 專案目前沒有獨立主選單；Meta 局外購買與狀態放在開局契約畫面，HUD 顯示持有碎片，結算顯示本次新增與本局累計。
- `affix_split` 在硬 cap 滿載時會裁切小體數量，不為了保證 2 隻而突破 150。
- Meta 解鎖採 lifetime shards 門檻，不另設大型永久數值或複雜 hub。
- 視覺採 tint/ring 佔位，沒有新增 bitmap 粒子素材。

## 驗證

- Headless load：零錯。
- `R5RegressionTest`：PASS。
- `R6RegressionTest`：PASS。
- `R7RegressionTest`：PASS。
  - split：可用 cap 時 2 spawnlings；cap=4 時 active=4。
  - field/swift：slow_timer=0.20；swift dash=465.0。
  - evolution：四個 `evo_*` 全部觸發且一次性。
  - Meta：roundtrip shards=53，reset_ok=true。
- `BalanceMockRun`：PASS。
  - 進化觸發時間 104s。
  - 精英詞綴分布：split 2、field 1、swift 1。
  - Boss phase two 195s，Boss kill 210s。
- 全 debug scene：PASS。
  - GameplayCapTest、MobileInputSmokeTest、PoolContractTest、SquadSmokeTest、WeaponSmokeTest、StressTest。
  - Stress：avg 6.940ms、p95 13.916ms、max 30.032ms；`enemy_group_scans=0`；所有 pool exhausted=0。
- Web export：成功，無 script/export error。`export/web/index.pck` = 3,045,932 bytes。

## 紅線檢查

- `spawn_token` 命中表未改。
- cap 不吞玩法：split 小體裁切在 cap 內；fork/hazard/lightning/explosion 全走既有 pool/cap。
- 武器熱路徑無 group 掃描：進化分支使用既有 spatial index 或既有 orbit overlap 節奏。
- Web 單執行緒預算：無新 runtime scene instantiate；新增 UI 僅在契約/結算。
- 決定性 seed：affix roll 和進化選項沿用 Godot RNG/既有 run seed。
