# Crackveil Vanguard 全面稽核報告

稽核日期：2026-07-16
稽核版本：專案 0.14.3-r19（Godot 4.7.stable）
稽核原則：只讀程式、場景、資源、文件與既有證據；只執行既有測試；未修改任何遊戲程式、素材或測試檔。

## 稽核範圍與方法

- 已讀 AGENTS.md、README.md、project.godot、export_presets.cfg、核心流程、英雄／武器／羈絆資源、敵人、動畫、UI、存檔、響應式程式及 docs 設計／驗收資料。
- 以 Godot 4.7 headless 實跑 R7RegressionTest、R14RegressionTest、TrueAnimationRegressionTest、PoolContractTest、GameplayCapTest、SquadSmokeTest、WeaponSmokeTest、EnemyArtRegressionTest、Hero10ClosureTest、BalanceMockRun、Hero10BalanceInstrument、ArenaInstrumentationRun、StressTest。功能測試皆 exit 0；壓測另輸出明確效能失敗訊號，詳見下文。
- 視覺／視口採目前匯出物及 R19 證據：docs/evidence/R19_controls/、docs/hero10_true_animation_proof.png、docs/art_r16_enemy_proof.png、docs/evidence/art_r16/web_battle_rift_void.png。線上 URL 與本機 URL 的直接瀏覽器載入均被本稽核環境 Chrome 安全政策拒絕，故無法獨立重跑線上部署的 console/network；部署快取或 GitHub Pages 與工作樹不一致不在本報告保證範圍。既有 Playwright 證據的 pageErrors 為空，不等同本次重新驗證線上 console。
- 嚴重度：P0＝阻擋或一眼即壞；P1＝明顯拉低完成度、留存或可用性；P2＝打磨、風險或測試／文件債。

## 1. 遊戲可玩性

### P0

- 無阻擋級發現；主選單→教學→契約→戰鬥→升級／商店→Boss→結算的主循環成立。

### P1

- **[P1] 裂隙牧者實戰輸出遠低於設計預算。** ArenaInstrumentationRun 實跑 16.01 秒、滿 9 人且全進化，牧者只造成約 14.8 / 2051.1＝0.72% 總傷害；設計對未進化中期的目標已是 8–12%，進化後是 12–16%。證據：docs/DESIGN_hero10.md:141-150、scripts/debug/arena_instrumentation_run.gd:5,185-243；重現：headless 執行 res://scenes/debug/ArenaInstrumentationRun.tscn，讀 ARENA_INSTRUMENT_DAMAGE_BY_SOURCE 與 ARENA_INSTRUMENT_SHEPHERD_SHARE。建議修法：先提高裂傀有效接敵率／投放位置／tick 覆蓋，再調傷害或壽命；把 12–16% 進化後份額做成硬門檻。
- **[P1] 11 武器的平衡檢查沒有抓住極端分布。** 150 個靜止敵人的飽和情境中，榴彈約占 52.1% 總傷害，裂傀約 1.37%，其餘多在 1–9%；測試仍 PASS，因為只要求碎裂傷害大於零及 group scan 為零。此情境偏袒定點 AoE，不能直接宣判榴彈在所有實戰都過強，但證明目前沒有可用的跨武器平衡門檻。證據：scripts/debug/hero10_balance_instrument.gd:5-24,108-174；重現：執行 res://scenes/debug/Hero10BalanceInstrument.tscn，比較 HERO10_BALANCE_DAMAGE_BY_SOURCE。建議修法：增加移動群、單體 Boss、散兵三種情境，按武器角色設份額區間，超界回傳非零 exit。
- **[P1] 擊敗唯一 Boss 後沒有下一戰場或第二段目標，「繼續無盡」只解除暫停。** 三個戰場主題由 seed 在開局選一次；勝利後不換主題、不重設階段、不再生成新 Boss。證據：scripts/arena/run_theme.gd:3-23、scripts/arena/arena.gd:167-180、scripts/autoload/game_manager.gd:1507-1554、scripts/ui/stage_victory_screen.gd:79-86。建議修法：實作三段 stage progression；若不做，將產品文案改成「每局抽選一種戰場，Boss 後可無盡」。
- **[P1] 10 名英雄中至少 4 名的被動 ID 沒有實際消費者。** arc_scout/scout、line_mender/support、orbit_guard/guard、pulse_artificer/blast 的資源文案標示「預留」，專案沒有相應被動執行分支，與已有專屬分支的其他英雄完成度不對稱。證據：resources/heroes/arc_scout.tres:19-21、line_mender.tres:19-21、orbit_guard.tres:19-21、pulse_artificer.tres:19-21、scripts/weapons/base_weapon.gd:117-138、docs/DESIGN_hero10.md:300-312。建議修法：替四個 ID 接上可測、可顯示的被動；若本版不做，移除被動欄與完整定位暗示。

### P2

- **[P2] 滿編後升級池太寬，進化規劃受 RNG 支配。** 每把武器可貢獻傷害、冷卻、投射數、質變與進化卡，9 人／11 武器再混入角色與招募選項，每級只抽 3 張。證據：scripts/heroes/squad_manager.gd:217-314,323-327、scripts/autoload/game_manager.gd:744-793。建議修法：提供重抽、武器鎖定或「接近進化」保底，並記錄卡池命中率。
- **[P2] 長局沒有背景音樂，主要靠 16 個短 SFX 支撐。** 證據：scripts/autoload/audio_manager.gd:9-25,98-117，專案無 BGM／music 播放路徑。建議修法：至少加入戰鬥 loop 與 Boss 層，另設音樂音量。

### 已驗證通過

- 10 選 9、開局 3 人、4 組羈絆與 11 武器都存在；resources/squads/default_squad.tres:15-19。WeaponSmokeTest 實跑顯示 9 人與 11 武器皆觸發。
- R7RegressionTest 實跑涵蓋契約、詞綴、六項進化、殘響 round-trip、成就、種子、設定與 modal owner，輸出 R7_REGRESSION_PASS。

## 2. 畫質

### P0

- 無。動畫鐵律已達成，沒有以整張平面角色浮動冒充走路／攻擊。

### P1

- **[P1] 大型環刃／迴旋刃遮蔽小型角色與敵群，實戰層級失衡。** web_battle_rift_void.png 中高亮藍刃遠大於角色，且與冷藍背景同色域，近身敵、命中來源與隊形易被蓋掉；環刃使用 207×212 圖與 sprite_scale 1.56。證據：檢視 docs/evidence/art_r16/web_battle_rift_void.png；resources/weapons/orbit_blades.tres:17-18。建議修法：縮小主刃 20–30%、降低非前景刃 alpha／glow，提高敵我輪廓優先層，僅在命中幀短暫放大。

### P2

- **[P2] 動畫正確但角色畫面占比偏小，1080p 與手機難看清肢體姿勢。** atlas 單格 64×64，程式按約 body_radius×3.1 顯示。證據：scripts/animation/true_animation_library.gd:4-14、scripts/player/player_visual.gd:163-175；檢視 docs/hero10_true_animation_proof.png 與 docs/evidence/R19_controls/390x844_touch_controls.png。建議修法：手機採較近 camera zoom／較大角色顯示，維持 collider 與視覺根分離。
- **[P2] 1920×1080 主選單過度集中左側，大片背景沒有資訊焦點。** 證據：docs/evidence/R19_controls/1920x1080_main_menu.png、scripts/ui/main_menu.gd:100-140。建議修法：改中央／三分構圖，加入英雄主視覺或動態裂隙焦點。

### 已驗證通過

- 英雄／敵人逐幀狀態為 idle 4、walk 8、attack 6、hurt 3、death 6；walk 有接觸腳幀，attack 第 2 幀才 impact，hurt／death 獨立。證據：scripts/animation/true_animation_library.gd:4-14,30-48,75-88、scripts/player/player_visual.gd:71-103,190-242、scripts/enemies/enemy.gd:436-476,649-702,1223-1240。
- 物理根、碰撞與視覺分離：scenes/player/Player.tscn:10-20。TrueAnimationRegressionTest 實跑輸出 heroes=10 unique_cells=10 poses=4/8/6/3/6 impact_frame=2 duplicate_hits=0 並 PASS。

## 3. 玩家適應性

### P0

- 無阻擋級發現；首次進局至少會顯示裝置對應的移動、主動技、自動攻擊與升級說明。

### P1

- **[P1] 首次教學只講 4 件基本操作，沒教本作的決策層。** 契約、招募時機、9 人上限、隊長死亡即全滅、羈絆效果、進化前置、商亭、Boss 時點都未出現；關閉後立即面對契約三選一。證據：scripts/ui/first_run_guide.gd:53-60,120-124、scripts/arena/arena.gd:65-72、scripts/autoload/game_manager.gd:981-1008。建議修法：以首次契約、招募、羈絆、進化、商店、Boss 分段觸發情境教學，暫停頁保留索引。
- **[P1] 無障礙設定不足，且 README 宣稱的「色盲輔助」沒有對應開關或模式。** 玩家設定只有傷害數字、螢幕震動、搖桿大小、強制搖桿；缺字級、對比、色盲模式、降低閃光、控制重綁。證據：README.md:27、scripts/autoload/player_settings.gd:7-10,28-40，執行碼無 colorblind／色盲功能。建議修法：先更正文案；再加入高對比／色盲調色盤、特效強度、UI scale、鍵位重綁，並做 CVD 模擬。

### P2

- **[P2] 手機橫向教學內文硬降到 12px、勾選 13px。** 證據：scripts/ui/first_run_guide.gd:166-172。建議修法：橫向採捲動或分頁，正文維持至少 16px 等效尺寸並支援 UI scale。
- **[P2] 主選單沒有「玩法／教學」入口，必須開始一局後再由暫停選單重看。** 證據：scripts/ui/main_menu.gd:110-140、scripts/ui/hud.gd:541-551。建議修法：主選單加入玩法頁，先解釋隊長、契約、招募、羈絆與進化。

## 4. BUG

### P0

- 本輪未重現 P0 功能性 bug。既有 headless 功能測試均 exit 0，未看到 SCRIPT ERROR。

### P1

- **[P1] 壓測 PASS 判定會吞掉明確效能失敗。** 本次 150 敵＋80 投射物＋9 英雄實跑為 avg_ms=37.228（26.86 FPS）、p95_ms=53.884、min_fps=11.89、相對 R19 基線 +147.73%、within_plus_10=false；程式只印 STRESS_PERF_BELOW_60=true 後仍輸出 STRESS_PASS。設計明定平均 frame 不得比基線差逾 10%。證據：scripts/debug/stress_test.gd:395-471、docs/DESIGN_hero10.md:337-350,363-373；重現：執行 res://scenes/debug/StressTest.tscn。建議修法：provenance 齊全時把 avg_ms、p95、最低 FPS 超界改為 _fail()；provenance 為 UNSPECIFIED 時標 INCONCLUSIVE，禁止 PASS。

### P2

- **[P2] 多個存檔寫入忽略 ConfigFile.save() 回傳值，失敗會靜默發生。** Web 私密模式、配額滿或儲存被封鎖時，畫面仍像保存成功。證據：scripts/autoload/player_settings.gd:34-40、scripts/autoload/audio_manager.gd:196-200、scripts/ui/first_run_guide.gd:104-107。建議修法：檢查 error code、顯示持久化失敗提示，加入不可寫 user:// 回歸。
- **[P2] SquadSmokeTest 與 WeaponSmokeTest 是兩個名稱指向同一腳本。** 兩場景都載入 scripts/debug/weapon_smoke_test.gd，報表易把一次能力算成兩項。證據：scenes/debug/SquadSmokeTest.tscn:1-6、scenes/debug/WeaponSmokeTest.tscn:1-6。建議修法：合併名稱，或讓 Squad 專驗編隊／死亡／招募邊界，Weapon 專驗 11 武器命中與進化。
- **[P2] Web 自動化只監聽 pageerror，一般 console.error／資源載入錯誤可能漏掉。** 證據：tools/test_controls_reachability.mjs:105-108,176-177。建議修法：另監聽 console、requestfailed、HTTP 4xx/5xx 與 Godot stderr，白名單後將新增錯誤設失敗。

### 已驗證通過

- R7RegressionTest 的 Meta 存取、購買、重載／重置，以及成就、種子、設定 round-trip 實跑通過。PoolContractTest 的 duplicate release 警告是刻意驗證並被安全忽略。
- 敵人 _start_attack() 只啟動動畫，第 2 幀才開 hitbox 並驗距離；死亡碰撞先停用，動畫完才回收。證據：scripts/enemies/enemy.gd:436-476,683-751,1223-1240。

## 5. 說明

### P0

- 無阻擋級說明錯誤。

### P1

- **[P1] README 版本落後目前專案。** README 顯示 0.14.2-r18，實際 project.godot 與 R19 畫面為 0.14.3-r19。證據：README.md:10、project.godot:11、docs/evidence/R19_controls/1920x1080_main_menu.png。建議修法：版本由單一 build metadata 產生，發布時自動更新 README 與部署頁。
- **[P1] 11 把武器的進化條件沒有在遊戲內提前說明。** 條件皆含 run level 7、指定質變 1–2 級與武器傷害 3 級，但 UI 只在全滿後把進化卡放進池，玩家無法規劃。證據：scripts/resources/weapon_data.gd:92-191,260-272、scripts/heroes/squad_manager.gd:294-314、scripts/ui/level_up_screen.gd:75-99,181-190。建議修法：暫停「本局」顯示每把武器的進化配方與即時進度。
- **[P1] 羈絆只顯示名稱與啟用數，沒有倍率或生效對象。** 證據：scripts/ui/hud.gd:1240-1242；完整效果在 scripts/heroes/squad_manager.gd:42-131，未被 HUD 展開。建議修法：羈絆名稱可點／觸控展開，顯示條件、成員、精確效果、死亡失效狀態；招募卡預覽羈絆變化。

### P2

- **[P2] README 的「橫越三種異變戰場」易被理解成單局三關，實作是每 seed 選一種。** 證據：README.md:8,26、scripts/arena/run_theme.gd:3-23。建議修法：若不做三段關卡，改成「每局進入三種戰場之一」。
- **[P2] README 測試章只列 R14 與 TrueAnimation，與實際 debug 場景不一致。** 證據：README.md:92-99，相對 scenes/debug/ 的 R7、Stress、Balance、Pool、GameplayCap 等。建議修法：列權威測試入口、預期輸出及硬門檻，避免把資訊型 PASS 當品質通過。
- **[P2] 種子輸入沒有格式提示或錯誤回饋，無效字串默默回到隨機 seed。** 證據：scripts/ui/main_menu.gd:126-140、scripts/debug/r7_regression_test.gd:670-684。建議修法：顯示可接受格式，解析失敗時保留欄位並提示。

## 6. 選單

### P0

- 無死鎖級問題；主選單側欄、商店離開、勝利／失敗結算返回均有按鈕。

### P1

- **[P1] 進行中的一局無法由暫停選單放棄並回主選單。** 暫停只有設定、成就、本局、複製種子、重看教學、重置殘響與繼續；回主選單只在死亡或 Boss 勝利結算。玩家若想換 seed，只能故意死或重載頁面。證據：scripts/ui/hud.gd:398-588、scripts/ui/game_over_screen.gd:90-103、scripts/ui/stage_victory_screen.gd:74-87。建議修法：加入「放棄本局→確認→結算／回主選單」，明示是否保留本局進度。
- **[P1] 390×844 暫停面板與仍可見的暫停按鈕實際相交 20px。** R19 probe 的按鈕 y=26–102，面板 y=82–762；測試只點中心，所以仍 PASS。證據：docs/evidence/R19_controls/playwright_results.json:809-837、scripts/ui/hud.gd:872-890。建議修法：面板開啟時隱藏／停用外部暫停鈕，或讓面板從其下方開始；測試加入 rect intersection 斷言。

### P2

- **[P2] 「重置殘響」放在暫停「本局」頁，資訊架構不合理。** 它是永久進度破壞操作，雖有二次按壓確認，仍不應與本局統計並列。證據：scripts/ui/hud.gd:570-588,1685-1713。建議修法：移到主選單資料管理，以 modal 顯示將刪除項目。
- **[P2] 寬螢幕主選單把種子與主要 CTA 並列，沒有新手／進階分層。** 證據：scripts/ui/main_menu.gd:105-140、docs/evidence/R19_controls/1920x1080_main_menu.png。建議修法：主 CTA 保留開始，種子出擊移入進階面板並加入玩法入口。

## 7. 全平台 UX

### P0

- 無法確認 P0；既有 R19 證據中已探測按鈕中心均在 viewport 內且可命中 Godot canvas。

### P1

- **[P1] 390×844 直式手機頂部 HUD 仍明顯互相侵入。** 截圖可見 HP／等級／XP 與右側 M / S / J2 快捷列擠在同區；程式把快捷列固定為 x≈332–378、y=110 起，XP bar 最寬可到 x≈366。「點得到」不等於「看得清」。證據：docs/evidence/R19_controls/390x844_touch_controls.png、scripts/ui/hud.gd:822-827,1049-1078。建議修法：直式將快捷設定收成單一齒輪或移入暫停，HUD 改兩列 grid，對所有 HUD rect 做不相交驗證。
- **[P1] 滿編高壓情境在本次稽核機器上平均僅 26.86 FPS，跨裝置效能目標未達。** 411 個量測 frame 全超過 20ms，p95 約 18.56 FPS、最低約 11.89 FPS；provenance 與 machine condition 都是 UNSPECIFIED，不能當跨機絕對基準，但足以否定「已證明穩定 60 FPS」。證據：重現 res://scenes/debug/StressTest.tscn；scripts/debug/stress_test.gd:6-38,139-163,395-471。建議修法：建立固定硬體／瀏覽器基線，profile explosion、damage number、動畫與空間查詢；桌機 60 FPS、手機另設 30/45 FPS LOD 硬門檻。
- **[P1] 近期「全視口可達」驗證不足以支持全平台結論。** 矩陣只有 4 個非觸控桌機與 1 個 390×844 直式觸控；觸控 maxTouchPoints=1、DPR 固定 1。斷言只查可見、高度、中心在畫面及中心命中 canvas，沒查互相重疊、捲動、平板 coarse pointer、手機橫向、旋轉、安全區、雙指搖桿＋技能；暫停與 HUD 相交因此漏網。證據：tools/test_controls_reachability.mjs:19-25,50-75,91-177、docs/evidence/R19_controls/playwright_results.json:707-715。建議修法：加入 844×390、1024×768 touch、1366×600 coarse、DPR 2/3、瀏海 safe-area、旋轉；同時拖搖桿並按技能，驗 rect intersection 與 scroll 到底。

### P2

- **[P2] Web 匯出關閉 PWA，沒有安裝／離線啟動。** 證據：export_presets.cfg:31-35。建議修法：若定位含手機長期遊玩，啟用 PWA、版本 cache 與更新提示；若不支援離線，README 明示。
- **[P2] 搖桿程式有 finger index 與動態中心，但自動化未驗第二指是否被 UI／canvas 手勢攔截。** 證據：scripts/ui/virtual_joystick.gd:27-60,73-93、tools/test_controls_reachability.mjs:93-99,150-166。建議修法：加入「持續左移＋同時按主動技＋放開技能後仍移動」的 E2E，並在 Android Chrome／iPad Safari 實機各驗一次。

### 已驗證通過

- R19 證據矩陣的 1920×1080、1440×780、1366×600、1280×640、390×844 中，主選單、設定側欄、教學、契約、HUD 暫停及繼續的中心皆可達；桌機未誤顯搖桿，390×844 有搖桿與技能鍵。證據：docs/CODEX_RESPONSE_cv_R19_controls.md:26-41、docs/evidence/R19_controls/playwright_results.json。
- 搖桿依 viewport／方向調半徑並追蹤 active touch index；390×844 的搖桿與技能鍵沒有相交。證據：scripts/ui/virtual_joystick.gd:27-93、docs/evidence/R19_controls/playwright_results.json:798-807,869-877。

## 最該優先修的 Top 5

1. **把效能紅線變成真正失敗門檻並處理滿編壓測。** 26.86 FPS 還能 STRESS_PASS，會讓後續內容在錯誤安全感上繼續增重。
2. **修 390×844 頂部 HUD 與暫停面板碰撞，擴充真觸控矩陣。** 這是最直接、可見且與「近期已硬化」承諾衝突的 UX 問題。
3. **重做 10 英雄／11 武器平衡驗收。** 先救牧者 0.72% 實戰份額，再用移動群、Boss、散兵約束極端分布。
4. **補齊首玩說明與無障礙。** 把契約、招募、隊長死亡、羈絆、進化、商店做成情境教學；修正不存在的色盲輔助宣稱並加入 UI scale／高對比。
5. **明確化三戰場產品承諾。** 最佳解是 Boss 後換場與階段進程；若短期不做，立即改成「每局抽選其一」。
