# R38 關卡與魔物內容

StageCatalog、EnemySpawner、Enemy 與新的 R38EnemyCatalog 提供以下可玩的地區與物種。

| 次序／ID | 關卡／theme | Boss／pattern | 出場秒／HP | 真彈幕 base→半血 |
| --- | --- | --- | --- | --- |
| 7／dunes | 曜砂王陵／sunken_dunes | 曜砂巨甲／dune_barrage | 180／4800 | 三列定向砂彈 15→21 |
| 8／tide | 珊潮遺都／tidal_ruins | 深潮歌后／tidal_spiral | 195／5400 | 雙臂旋轉水彈 12→18 |
| 9／bloom | 月華靈森／moonbloom_grove | 萬花靈主／bloom_petals | 210／6000 | 六瓣配對月華 12→24，真 impact 支援普通友軍 |
| 10／forge | 時輪工坊／clockwork_forge | 時輪收割者／gear_cross | 225／6800 | 四軸快慢齒輪交叉 16→24 |

原六關與其攻擊幾何保留；`get_next_stage_id("veil")` 現在接 dunes，forge 是最後一關。Boss 名稱與出場時間沿既有 `record_boss_spawn`，死亡與傳說裝備沿既有真 death pose／loot finalization／record_boss_kill 路徑，Endless 使用既有通關檔案與 launch API。

六種新魔物使用獨立的 `enemy_<id>.png` sprite identity；外部 registry 已註冊 `r38_character_atlas.png`，每種有 16 原創姿勢映射為 27 格播放時序，impact frame 2 對應 authored source pose 8，舊 atlas 保留：

| ID | 名稱 | 真行為 |
| --- | --- | --- |
| dune_scarab | 曜砂甲蟲 | 重甲、高 HP 的近身追擊 |
| sand_stalker | 砂影獵手 | 真蓄勢、突進、收招；接觸攻擊仍 impact 生效 |
| tide_siren | 深潮歌妖 | 第 2 幀四發前後短扇 |
| coral_colossus | 珊瑚巨衛 | 第 2 幀半徑 145 的近身震擊，地面預告圈與實際半徑一致 |
| bloom_wisp | 月華靈火 | 第 2 幀在 260 內治療最多六個普通友軍，每個最多 12 HP；排除自己、Boss、菁英、死亡者 |
| clockwork_reaper | 時輪刃衛 | 第 2 幀五發定向齒輪扇 |

四張新地圖有各自 weighted roster，regular、opening pack、harvest pack 都真選到該 roster 的角色。舊六關維持原權重與 harvest_grunt ID。Weighted selection 的 stage／roster 只在 stage ID 改變時更新，避免每個生怪 roll 反覆 deep-copy 同一個 StageCatalog；分裂、菁英和 Boss 的原 cap 與生命週期保留。新 Boss 半血增援也使用對應新區域的物種。

`get_harvest_debug_state` 新增 `biome_roster` 和 `regular_spawn_counts`，後者只在真 acquire 成功後增加。Enemy `get_biome_debug_state` 提供 `skill/casts/damage_hits/healing/projectiles_fired/radius/timer`；healing 累加實際增加的 HP，不把空施法算治療。Pool release／setup 清掉全部新技能與 counter，Boss 的舊 plan/count 也在 release 清除。

驗收 scene：`res://scenes/debug/R38ContentTest.tscn`。先檢查六張素材存在且動畫 identity 已註冊，缺任一種就明確 fail，沒有以舊圖假通過。之後驗四個 weighted roster 的真 opening／harvest／regular spawn、四種新技能的第 2 幀／真 HP 變化／真 shot counts、全部十種 Boss 的 base／phase2、真死亡後的傳說 UID claim、十關通關存檔、forge 的真 Endless Arena launch。Fixture 使用 persistent runner、隔離全部 save paths 與 20 秒 watchdog。

完整 `R38ContentTest` 已 PASS，exit 0、約 2.57 秒 wall time，原始紀錄為 `docs/evidence/r38/content/content_gate.txt`。四個區域各真生成 27 隻 opening／harvest／regular 角色；珊瑚震擊實際造成一個 Hero 命中，靈火讓普通友軍 HP 10→22，歌妖與刃衛實發四／五枚。十個 Boss 的 base 與半血實際命中 hook 都記錄 `[2, 2]`，原 attack source FPS 維持 12。每個 Boss 在設定時間前 0.01 秒沒有生成，實際 Spawner process 到時間才生成，中文名字一致；十個死亡動畫後都真 claim 傳說 UID、通關檔案 10／10，最後真 launch 工坊 Endless Arena。

第一次整合測試抓到扇形角度的 typed ternary Array runtime 問題，已改成明確 PackedFloat32Array；最終 log 沒有 SCRIPT_ERROR。測試的 frame_changed 在 shared animation 的 impact hook 前發出，因此精確幀紀錄保留該次 frame 值、延後核對 impact serial，避免把下一幀當成命中幀；production 的時序未放寬。

這是受控 headless fixture，並非十張地圖的自然全程遊玩。四個新地區另完成真正 Chrome 選關與戰鬥，結果見 [發布報告](R38_RELEASE_REPORT.md) 與 [實玩摘要](evidence/r38/playtest_summary.json)。
