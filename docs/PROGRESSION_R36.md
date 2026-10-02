# R36 金幣召喚、四法術與永久寵物

2026-10-02，progression lane。實作於18:18:55＋08:00 freeze；真正Web試玩另記`docs/playtest/R36_PLAYTEST.md`，不把本頁native fixture當自然遊玩。

## 已完成

- 技能抽取80遊戲金幣，三選一，至少一張未滿級的真法術；法術位的有效候選等機率。其他兩張為目前合法武器／數值升級，戰術75%／質變25%，一池耗盡轉另一合法池；連續四次沒有質變卡，第五次保底（有合法質變時）。UI顯示當下機率、保底與具體提升。
- 流星雨8枚真拋物線爆破、星雷珠8顆追蹤彈、霜晶槍12支穿透彈、追影刃10把回旋刃，均由現在隊長的真正`visual.attack_impact`觸發，檢查frame2與2.8–4秒冷卻。每種當局最高五級，重複提升真傷與施放速度。現有Hero／Weapon腳本沒有被此lane改寫。
- 寵物抽取120金幣，有效候選等機率，第三／第六等每第三抽優先未取得寵物。最多三個出戰槽：焰尾靈狐範圍火球、星雷羽鷹三段連鎖、翠玉靈兔最低血量治療與經驗磁吸／靈光攻擊。寵物與星級跨局存檔，下一局自動出戰。
- 重複寵物升一星，最多五：傷害與回復倍率`1 + 0.35 × (星數−1)`、施放速度倍率`1 + 0.08 × (星數−1)`。UI顯示當前基礎傷害與間隔；滿星候選排除，全滿星禁抽，不支付空獎勵。
- Director獨立seed RNG，不用global rand／loot RNG。request不扣款、不發獎；Root GameManager處理wallet實付與refund，token只commit一次，paid關閉自動選第0張，不能免費重抽。

## 接口

`CoinSummonDirector.setup(arena,seed)`；setup前設`save_path`，整合端用campaign路徑衍生`*_pets.cfg`。`preview_cost(kind)`、`can_draw(kind)->{ok,reason}`、`request_draw(kind)->{ok,draw_id,kind,cost,choice_options,pet,reason}`、`mark_paid(id)`、`commit_draw(id,index)->{ok,option/pet,message}`、`cancel_draw(id)`、`grant_skill(skill_id)`、`get_debug_state()`。取消僅接受未paid的pending；失敗存檔回滾收藏、次數、保底與RNG，讓Root退錢。

獨立只讀覆核後另修：`commit_draw`必須paid=true才發獎；寵物存檔先成功寫.tmp再same-volume rename替換，失敗不覆寫舊完整收藏；UI直接使用`changed(state)` payload，避免同事件再重建合法pool／odds。最終`summon-transaction-final.txt`重跑完整回歸通過（另測未付token拒絕）。

`SummonShopScreen.show_shop(director)`、`show_result(result)`、`hide_shop()`、`clear_result()`；訊號`draw_requested(kind)`、`choice_selected(draw_id,index)`、`closed`。自身不扣金幣，不自由apply GM；已付pending重開可恢復三張卡。debug包含CSS尺寸與`controls.skill_draw/pet_draw/close/choices/scroll`真正Control幾何供Web實點。

## 真素材

使用內建imagegen，沒有CLI/API fallback；來源存`assets/pets/r36/pet_sheet_original.png`，透明alpha0約49.95%。彩色preview底是alpha RGB，原圖沒有被改成背景。6×6共36個原始動作，每個動物12個keyposes：idle2、walk4、attack4、hurt1、death1；不是24/27幅獨特原畫，也沒有單張bob冒充走路。

`tools/build_r36_pet_atlas.py`只隔離原始RGBA components與packing，不重畫原圖，輸出`assets/pets/r36/pet_atlas.png`（768×768、128cell）與`pose_manifest.json`。狐狸嘴、鳥翼與兔四肢有真正變姿；Fox火口跨固定格邊界，CC提取保全口部及火焰，未混鄰格。已逐圖開灰底atlas。sprite按foot基準落地，陰影僅為地面裝飾；loop世界不把寵物夾在canonical4096邊界。火狐火球預暖兩個AnimatedSprite物件反覆使用。

最終生成prompt存`assets/pets/r36/pet_sheet.prompt.txt`。這是新寵物原畫，沒有替換R34/R35主角或地圖資產。

## 驗證

`R36SummonRegressionTest`使用真正Root商店Button signal與處理器，native／headless實跑，campaign/wallet、pet、meta、settings、achievement五類存檔隔離。最終`docs/evidence/r36/progression/summon-final.txt`：exit0、無SCRIPT ERROR。

- 無錢與空池不扣款、不消耗RNG；global randi序列不受抽取影響。
- 真按抽技能80只扣一次；再按、舊token、舊choice都不能重複發獎；paidClose交第一張。
- fixture五次pet抽滿三槽，雷鳥三星、狐狸與兔各一星；真正下一局自動重生並保留星級，當局技能清空。
- 真pet attack第2格才影響技能：狐AOE實傷84、鳥三星三目標實傷83.09、兔實傷16／回復7。回收再用火球節點，角色attack會完整收招，沒有frame2後立即取消動畫。
- 真Hero F2各產生8／8／12／10顆實projectile。各法術solo又測延遲真傷：流星764、雷珠66、霜槍428、影刃444，沒有只spawn圖樣。
- native 1280×720、844×390、390×844、1024×768四尺寸：已付三卡、文字底部與真正close bounds均通過，四張PNG存`docs/evidence/r36/ui/`並開圖。portrait可上下scroll；landscape直接顯示三卡，paid時收起抽取概率區，不讓卡片藏到第一屏下。
- 修過初版wrapped label在width0估minheight832、把Panel／close擠出畫面的問題；兩processframes後再clamp，文字高度由實際minsize適配。Web使用`MOBILE.apply_web_canvas_scale`與`ui_layout_size`，不把native四size通過冒稱Web手機也已通過。
- 真Web又發現paused HUD仍保留pre-layout座標；settle後等children布局，再emit_stats刷新readonly controls。已離線解包ca041的GDSC101／zstd identifier表確認`emit_stats`實編入，證據`ca041-pack-geometry-refresh.json`，沒有因此開新遊戲或注入狀態。

## 限制

技能是當局效果；寵物與wallet永久。寵物目前hurt／death各一幅原畫，只有idle／walk／attack採多幅真姿勢；沒有宣稱完整6/6/6/3/3美術已完成。實體手機與聲音尚未驗證，Web實玩需對應候選hash，畫面觀感不保證使用者滿意。
