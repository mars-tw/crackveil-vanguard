# R36 獨立遊戲體驗

2026-10-02。最終工作完成並freeze。實作與native驗證另見`docs/PROGRESSION_R36.md`。最終R5 `0.24.0-r36`／`index-080af36b47b8.pck`，所有Chrome contexts關閉；沒有持續跑native遊戲。

## 最終結果

R4修正效能後已真正順序實玩桌機91秒、觸控61秒、iPad UA平板20秒，不錄影取樣；R5另外短驗觸控控件重疊修正、真商店與auto按鈕，再以自然金幣重新購買技能／寵物，錄製真Space5.814秒與WASD／pet／proc影片。R4長局數據不冒稱R5重新跑過長局。

| R4 no-video自然局 | 桌機1280×720 | 觸控844×390／DPR2 | 平板1024×768／iPad UA |
| --- | --- | --- | --- |
| 終點 | 91.365s／2492殺／Lv17 | 61.213s／1506殺 | 20.251s／318殺 |
| HP | 161 | 176.69 | 180 |
| 活動FPS中位／最低 | 57／22 | 59／41 | 60／58 |
| 實走最遠 | 3617world，無硬牆 | 真單指搖桿持續走位 | 真搖桿走位 |
| 付款 | 202→122技能80；122→2寵物120 | 真支付80取得流星雨 | 未要求付費抽取 |
| 真戰鬥收益 | 星雷珠19次F2／152彈；狐25次F2火球／實傷342.55 | 流星雨10次F2／80彈；auto關／手動tap／auto開 | 角色射擊與近戰、自然升級 |

Phone真tap於25.42秒關auto、28.30秒手動技能、31.37秒再開；readonly `auto_upgrade`與`channel.mode`確認變換，最後automatic。桌機自然history看過flame／frost／shield特殊菁英，對應18／46／74秒；沒有注入怪物。Shop、paid三卡、禁用不足金幣、真選第一法術與寵物出戰均存PNG與actionlog，逐張開圖。

R4 no-video與C2錄影run雖用相同Intel ANGLE renderer，但種子、錄影負載與戰鬥時序不同，這不是受控比較，不能由中位15→57估算精確性能提升。較公平的證據是Root的R3同HTML／PCK、seed20261002、同Intel、不錄影、同輸入策略：GL cache OFF→ON平均48.56→58.42、中位53→59；仍因frame／physics時序有不同敵群負載，沒有宣稱完全相同負載。詳見[效能覆核](../R36_PERFORMANCE.md)。仍有短幀下降，不能稱所有設備穩定60；終點後到close前的自然繼續不覆寫本表終點。

## R5 最終觸控修正短驗

R4真圖／Control rect發現summon與auto按鈕互相重疊，且侵入joystick。Root改成橫向一排、位於實際joystick上方；portrait裝備列也上移。新增`R36TouchClearanceTest`實跑headless與native四種touch尺寸844×390、390×844、1024×768、768×1024，joystick／summon／auto／ability／equipment真rect均屏內、pairwise overlap0。曾抓到tablet portrait的equipment／joy重疊，修後重跑PASS；原失敗與最終log／PNG分開保留。

R5真正Web再測phone15.359秒／201殺、tablet15.797秒／203殺：純touch點summon開關／auto反轉再恢復／單指移動；四個互動Control實際WebCSS rect交集0，modal close在屏內。兩設備clearance與modal PNG已開，沒有把native幾何替代Web。R5沒重做R4長局性能測量。

## 最終影片

`docs/evidence/r36/playtest/r36-final-space-pet-proc-12s.mp4`，1280×720／H.264／25fps／解碼11.96秒，R5新錄影。這個新context自然再賺錢，付款80取得流星雨、120取得焰尾靈狐；手動Space實按5.814秒、15次channel impact、流星從4次32彈增加到6次48彈，接著真WASD移動，火狐跟隨且有真F2火球與實傷。

這次手動旋斬的近身range沒有敵人，`channel.hits=0`，沒有把15次動作impact寫成15次命中。R4phone自然局有103次channel impact／121hits，證明自動模式能實際命中；影片只證明實按、動畫、消耗、release、寵物與proc，不偽造近身contact。

展示影片由同一原WebM的真長按片段6.25秒與後續真移動片段5.75秒剪輯，刪掉中間等待升級選卡，沒有遊戲狀態注入、合成frame或調速；`docs/evidence/r36/playtest/r36-final-space-pet-proc-12s-provenance.json`保存兩段interval與raw錄影，舊同內容`r36-final-video-provenance.json`保留。不能稱它是連續12秒無剪接。Chrome實際播放currentTime前進且沒有media error，`r36-final-space-pet-proc-12s-playback.json`存驗證。也逐格開contact sheet與3秒frame確認人物新姿勢、狐、流星與大量真投射物。原未剪等待與其他歷史影片保留。

R5的phone／tablet／recording contexts新增HTTP response URL記錄，目前沒有400+response與fatal SCRIPT ERROR／ReferenceError／TypeError；既有invalid UID文字路徑fallback若出現另列為warning，不等同fatal。沒有實際聽音，影片無音軌。

## 保留限制

未測實體手機；iPad UA也是Chrome觸控模擬。魔物與爆擊文字密集時仍會蓋住局部細節，石地pattern與地標間距仍可更精緻，少量pose循環可見切換。大量殺怪與gate PASS不能保證使用者喜歡畫面；R5觸控修正、交易與影片以實際覆核範圍為準。

以下保留早期候選失敗紀錄，沒有用最終數據覆寫。

預定實際Chrome／Playwright，readonly `window.__cvR32Runtime`；桌機90秒走位超過1200、看到特殊菁英、自然賺取至少200金幣並真抽技能80與寵物120；觸控橫向60秒、tablet1024×76820秒。真正按B／mouse／touch／WASD，沒有注入錢、HP、技能或寵物。錄製新R36可播放實機片段，不混用R35舊圖。

實體手機、音訊、完整六關真人通關沒有被上述native gate替代。最終只依真正試玩範圍記錄，不保證審美或使用者滿意。

## Candidate2 桌機實玩

網址`?cv_r22_test=1&cv_r32_test=1&r36_revision=2`，`0.24.0-r36`／pack `index-dcf0b907c2dc.pck`。Chrome1280×720，真正WASD走位、mouse、按B，沒有注入金幣、HP或技能；原WebM與actionlog保留。

自然18.64秒已走2533，22.23秒賺243金幣。實點付款80取得星雷珠一級，243→163；再付120取得翠玉靈兔一星，163→43，實際wallet同步；不足金幣按鈕禁用與差額提示清楚。逐張開過shop-before、paid-three-cards、paid120-pet圖。readonlyUI在開啟的pre-layout快照誤報skill Y816／close826，實圖是141／658；QA先依舊座標點到屏外且沒有扣款，保留22秒早停證據。之後依真正PNG觀察座標操作、續同一局，沒有重開／改seed。

終點92.217965秒／2339殺／Lv16／HP164／Gold3250，max_travel2550.93，沒有硬牆；自然history看過flame／frost／shield三種特殊菁英，對應18／46／74秒。星雷珠17次真frame2、136真彈；兔24次frame2、實傷475.605、回復9.8438、磁吸34。

## 未通過：Web效能

同一單context錄影run，25秒後活動history中位FPS15、最低9，終點12；初18秒29、22秒24，不能用native gate或大量殺怪數宣稱爽快。

再跑21.578秒不錄影對照：活動樣本中位57、最低20，特殊菁英／敵群出現後仍下降，不能全歸因錄影。readonly WebGL資訊為`ANGLE Intel Graphics D3D11`／20threads；原生Godot gate用RTX2060，兩者性能不能混用。完整renderer-info與兩段history存`docs/evidence/r36/playtest/`。已回報Root查Web敵群、投射物、地面成本；尚待對應修正hash再測。

商店可視布局已正常；owned UI已補settle完成與children再布局後emit_stats刷新paused HUD座標。這是probe刷新修正，不把它冒稱candidate2已載入。手機／平板之後按新hash驗證CSS尺寸與真支付。

暫存12秒candidate2實錄片段`r36-r2-actual-pet-firepower-12s.mp4`，Chrome播放驗證通過，但低FPS與自然升級遮罩都保留，不能當作流暢展示影片。它沒有取代後續修正版本。
