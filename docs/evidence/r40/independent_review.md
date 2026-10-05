# R40 移動／攻擊朝向最終獨立覆核

2026-10-05，獨立上下文，同模型。核對 Hero、PlayerController、PlayerVisual、ImpactWeaponBase、RiftConstructWeapon 的 production diff，並讀回現有測試紀錄。未改 production source、未執行 GPU／瀏覽器，也未重跑測試。

**結論：此修正範圍未留待修的阻擋缺陷，可凍結來源並進行 root 的 Web 實玩驗證。**

原先牧者在攻擊前搖瞄左，卻被 Hero 的舊 RIGHT lock 蓋回人物朝向；此外 Hero nearest-target 與 Visual locomotion 各自寫朝向，對外 `get_facing_direction()` 又只回上次移動向量。這些入口目前已統一：

- `Hero.get_visual_facing_direction()` 為共用來源：攻擊讀成功起手時的 lock，hurt／death 保留當前 Visual 朝向，其餘讀當前移動輸入，沒有輸入才回上次移動向量。`get_facing_direction()` 指向同一結果；另以 `get_locomotion_facing_direction()` 明確表達移動語義。
- `begin_directional_attack()` 只在真實動畫接受起手後提交 lock 與 Visual facing。起手被 busy／reaction 拒絕時，既有攻擊方向不被改寫。手動拔刀、自動近戰、channel、牧者與新三英雄 Impact 武器都經此入口。
- Captain 的前搖 direction snapshot、F2 cone hit 與 directional FX 保留同一向量；未重新用最近目標覆蓋在途攻擊。普通遠程發射仍只使用自己的射彈方向，沒有新增人物／近戰 lock writer。
- PlayerVisual locomotion 讀 Hero canonical facing；純上下方向不再無條件取消左向鏡像。新局 reset 明確回 RIGHT／unflipped，debug 另提供向量、mirror 與 body rotation，便於驗證。
- PlayerController 先取本 tick 的移動輸入，再處理 Space，避免同一 tick 的左鍵＋攻擊使用過時的 last move。最新 JSON 已包含實際 controller 路由與 frame 2 的驗證。

此 diff 沒有變動 Hero HP、武器範圍／傷害、impact frame、shared atlas 或美術資產，也沒有旋轉人物身體來冒充多向動畫。現有圖片仍是水平鏡像素材；上下／斜向為正確的 logical aim／hit／FX 向量，不能稱為新製八方向人物動畫。

牧者保留原本的魔法規則：F2 在合法原目標／死亡或 generation 變更後的有限 retarget 上部署 construct；活目標移動時，魔法落點仍可追蹤該目標。此項不等同 Captain 的固定方向近戰 cone，也不宣稱所有魔法落點都鎖死。

已讀回證據：

- `targeted_gates.json`：TrueAnimation、CaptainComboChannelR35、AutoChannelR36、CombatR33、CombatPolishR37、R38HeroWeapon 六項 exit 0、errors 0。
- `facing_attack_test.json`：`failures=[]`，四個主軸的手動／自動共 8 組攻擊案例。F2 前方命中、後方傷害 0、活目標換邊不改在途方向、FX 朝向／位置與 lock 一致；恢復後回當前移動方向。另包含移動朝向、牧者與新英雄起手／busy lock、hurt／death／新局 reset，以及 same-frame controller 的 authored frame 2。

此報告是來源與既有 headless 證據覆核，不替接下來的 Web 實玩畫面或公開部署結果背書。

最終候選補註：HUD 的 Web runtime probe 追加 PlayerVisual 的唯讀 `get_debug_state()` 結果，仍限 `cv_r32_test=1` 才發布。此追加不修改 physics、布局、美術或遊戲輸入，只讓體驗員讀到朝向／mirror／frame 資料；未因此重跑相同 gates。Windows 最後體驗候選為 `0.26.2-r40`／`index-d2c78c51f7ce.pck`，完整 SHA-256 `d2c78c51f7ceeff633d063756f90333915b70ea97da0f03749867916d2451a0d`；正式 Linux CI 的包身分另見 `deployment.json`，不混用兩種 export hash。

CI 後續發現（run `37254505333`、head `f269cb5`）：WeaponSmoke 的 formation assertion 失敗，最大誤差 177.67，大於既有上限 92；因此 export／Web smoke／Pages 都被跳過。追查到原先這份有界角色覆核未包含的 `SquadManager.get_formation_world_position():605`，仍以新的 canonical `get_facing_direction()` 作隊形方向，導致隊友錨點跟近戰 aim 旋轉。已回報 root 需改用 locomotion facing，保留原驗收閾值。此 CI 阻擋未解除前，不將前述局部來源覆核結論當成完整發布通過。
