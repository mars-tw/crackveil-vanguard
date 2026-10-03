# R38 內容擴充獨立來源覆核

2026-10-03，獨立上下文，同模型。檢查範圍為 10 關、13 位英雄、6 種新普通怪、三種新武器、動畫 registry、世界地圖分章與存檔相容性。未改 gameplay source、未啟動瀏覽器／GPU，也未重跑已通過的整套測試。

## 發現的實質問題

**CI adapter：`scripts/debug/independent_stage_r34_probe.gd` 的六項彈數陣列需擴成十項，root 已修正。**

讀取當下，`:7`／`:8` 的 `BASE_COUNTS` 與 `PHASE_COUNTS` 只有六個元素，`:71`／`:72` 卻已迭代 catalog 的十關；`:87`、`:96`、`:109` 在第七關必定陣列越界。這會使 workflow 中的 `IndependentStageR34Probe` 無法完成，與新內容是否可遊玩無關。

已回報 root，建議保持十關覆核，擴成已由 R38 實體 Boss gate 觀察到的彈數：

- Base：`[12, 7, 9, 10, 12, 15, 15, 12, 12, 16]`
- Phase 2：`[12, 11, 16, 20, 18, 19, 21, 18, 24, 24]`

此 review lane 不修改該測試。root 完成十項陣列更新後已重跑，20 組彈數全部通過、0 SCRIPT ERROR；本次讀回最新來源亦確認兩組陣列均為十項。本項已解除，不留待修問題。

## Gameplay 來源核對

目前未找到需要阻擋交付的新 gameplay 缺陷。

| 範圍 | 來源與核對結果 |
| --- | --- |
| 新武器的傷害時機 | `impact_weapon_base.gd` 先要求真實 `Visual.play_attack()`，pending 時不發射；接到 `attack_impact` 才執行。`player_visual.gd:287` 維持 frame 2 與單次 emission。pending target 使用 weakref＋spawn token，影像失效／死亡／超距時取消或 whiff，不會命中重用後的錯誤怪物。 |
| 長槍與潮汐 | Solar 以射線投影、側向寬度、pierce 上限與跨 lane 單次 hit registry 選擇真實 enemy；Tide 的中心半徑傷害與 slow 只執行一次，pooled explosion 的 damage=0。治療只套用存活 squad member、340 範圍，呼叫真實 `heal()` 並記錄實際回復量。 |
| 回旋刃與追蹤彈 | Shadow／Tide evolve 透過既有 EntityFactory 產生實體 Projectile，source weapon id 保留。`projectile.gd:250` 清 hit registry，`:252–257` 重設 collision mask／monitoring；回旋返場清除舊 hit token registry，追蹤檢查目標 token 與 active 狀態。既有 projectile lifecycle 不依賴靜態畫面或假傷害數字。 |
| 新怪物與池重用 | `enemy.gd:208–216` 的 release、`:345–353` 的 setup 都重設 biome skill、timer、radius、heal、cast／damage／projectile counters。四種 biome 技能由 `:727` 的 frame 2 impact route 執行；bloom heal 拒絕死亡／inactive actor，也不治療 Boss／菁英。珊瑚 slam 的實際 radius 與 `:1359` 的圓形預告一致。Sand stalker 使用既有 dasher，受擊取消與恢復路徑保留。 |
| 關卡怪群與 Boss | 新四關 roster 由 cache 依 `selected_stage_id` 刷新；min_time 與 weight 在抽取和實際 spawn 的三條路徑使用。十種 stage Boss 的 pattern、HP、出現時間與 phase 2 配置來自 catalog；新增四種幾何彈幕有不同 plan，沒有用同一個預設環形彈幕冒充。 |
| 外部動畫 atlas | 三新英雄＋六新怪物用獨立 `EXTERNAL_CHARACTER_INDEX` 與 R38 atlas；cache key 為不同 character id，frame texture 指向正確 atlas。舊 R35 atlas 和 Captain 專用 combo region 保留，不會套到外部角色。新 assets gate核對 9 個 actor 原畫與 atlas SHA；art／hero gates另驗證姿勢與真實 frame 2。 |
| 世界地圖與背景 | 6＋4 分章時，`:385` 將 global stage index 轉為 chapter local index，route 與 cleared markers 只收當章。選取舊／新關能同步切章。背景 registry 有十個 theme，新增 tile 和 landmark pair 0／2／4／6；atlas切換會先清 region，pair＋index%2不越界。 |
| 既有六關存檔 | 原先六個 stage id、campaign／clears、endless_best 與 wallet_gold 欄位維持。`GameManager.gd:248–254` 依 catalog 過濾並保留既有清關 id、無盡紀錄與金幣；新四關不會被六關舊存檔自動標成通關。veil 的 next stage 改為 dunes，forge 才是尾關。這項為來源格式相容性覆核，不宣稱實際真玩家舊存檔已重播。 |

## 歷史測試覆蓋的區分

R14 的實際 roster assertions 已改為 13 選 9、weapon catalog 14。R34 world-map／campaign 和 R35 endless tests 使用 `stages.size()`，部分 log／錯誤文字仍寫 six／6，這是命名過時，並非實際固定六關。`TrueAnimationRegressionTest`、`EnemyArtRegressionTest` 仍有舊十英雄／舊六 ordinary config fixture，應視為舊內容回歸；新英雄與新物種的覆蓋由獨立 R38HeroWeapon／R38Art／R38Content gates 提供，不能將這些歷史 log 當成新內容總數。

已讀回本機現有證據：

- `docs/evidence/r38/content/content_gate.txt`：十 Boss 真實 frame 2／phase 2、六個新普通物種 roster與治療／傷害／射彈、十關清關保存和 forge endless。
- `docs/evidence/r38/map_expansion.txt`：五種 viewport 的 6＋4 分章、十套 bitmap ready、八個穩定地標節點。
- `scripts/debug/r38_hero_weapon_test.gd`：實體三英雄的 frame 2 傷害、AoE／pierce／return collision、canonical升級與進化、治療、下一局乾淨狀態的可執行 assertion。未在此 lane 重跑。

本報告不替 Web FPS、真手機／平板硬體動畫品質或公開部署背書；需採用 root 的最終候選版本實玩與 CI 結果。
