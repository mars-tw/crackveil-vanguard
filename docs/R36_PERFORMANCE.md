# R36 實際 Web 效能覆核

2026-10-02，獨立上下文覆核。使用本機 Chrome、正常鍵盤／touch joystick 與真升級點擊，不注入 HP、金幣、敵人或遊戲時間。FPS 測量期間不錄影、不做週期截圖；結束後才存單張場內圖。桌機 CSS／canvas 都是 1280×720、DPR 1，實際 WebGL renderer 為 ANGLE Intel Graphics D3D11。手機為 Chrome 844×390、DPR 2 的觸控模擬，並非實體手機硬體驗收。

| 實測 | active 秒 | Engine FPS 平均／中位數 | 最低／最高 | logical 子彈峰值 | 敵人峰值 |
| --- | ---: | ---: | ---: | ---: | ---: |
| c2 舊包，桌機，不錄影 | 30.23 | 34.13／33 | 23／54 | 舊 probe 無此欄位，visible 50 | 舊 probe 無此欄位 |
| 新 cache 包，桌機，不錄影 | 30.47 | 37.07／37 | 19／54 | 80 | 122 |
| 新 cache 包，手機，不錄影 | 60.00 | 33.10／34 | 9／59 | 115 | 112 |

數字為 active 取樣的 Engine FPS，排除 modal 暫停與前五秒暖機。自然遊玩的種子與升級不同，負載也不同，不能把表格差值視為嚴格同負載提升。手機最末單筆 FPS 為 9；平均值沒有隱藏此筆。桌機、手機都尚未達到穩定 60 FPS。

手機原始檔名 `c2-phone-no-video.json` 沿用起跑標籤，但 runtime 已包含新增物理 counters，確認它下載到 root 原子替換的新包；另保存 `post-cache-phone-no-video.json`，保留原檔與來源欄位。當時 PCK SHA-256：`ca0415a250818fcbbbe5975e392ce80aefe48513b4d135c0096eebe23e2b4e6a`。

## 已修正的確定熱點

`Projectile._physics_process` 原本每枚子彈、每個 physics tick 都呼叫裝置判定，接著透過 JavaScriptBridge 讀 CSS 寬／高與 UA／matchMedia JSON。Friendly cel 身體在各裝置的形狀相同，現在不做每 tick 判定；hostile palette 每 200 ms 檢查一次，仍可因旋轉／輸入裝置改變而刷新。Friendly visible quota 原本就是 static counter，沒有 O(N²) 全場掃描。

Dart 的 polygon 幾何改為每次 setup 建立一次；微小亮頭 30 Hz 更新，位置、速度、碰撞、pierce、命中 registry 仍以原 physics cadence 運行。固定形狀的 missile 保留 Canvas 繪圖命令，不每 tick 重建。Pool release 清掉新幾何與 cache；Explosion 的 LOD 改為每個短 burst generation 判定一次。

Root 另加全局 MobileTuning 短期 cache，移除其他角色／FX 重複的 CSS 和 UA bridge 呼叫。本 lane 沒有減少 volley 12→16→20、傷害、攻擊範圍或邏輯投射物上限。

## 新包的真 counter

| 項目 | 桌機／秒 | 手機／秒 |
| --- | ---: | ---: |
| Engine physics frames | 59.62 | 59.82 |
| 全部 Projectile physics ticks | 3166.58 | 4071.83 |
| Projectile readability checks | 3.65 | 19.67 |
| Dart glint redraw requests | 1312.56 | 1458.86 |
| Enemy spatial queries | 286.03 | 449.69 |

Rates 由未暫停的相鄰 wall-time samples 與累積計數差計算，不以模擬時間假造 Hz。手機／桌機維持約 60 physics Hz，Renderer FPS 仍偏低。

## 剩餘瓶頸的取樣證據

另跑一段 22.82 秒正常遊玩，12 秒後啟 CDP CPU sampler，取樣區間 14.86 秒。這個 profile run 的 FPS 平均 49.43，但敵人峰值 104、logical 子彈峰值 63，負載較低，不能拿來宣稱穩定提升。

`getParameter` self time 合計 5.711 秒，占取樣區間約 38.42%；兩個 stack 都是 `getParameter → blitOffscreenFramebuffer → _emscripten_webgl_do_commit_frame`。WASM self time 合計約 37.51%，idle 約 11.34%，eval 約 0.89%。這支持 WebGL frame commit 的同步 GPU／driver 等待為主要剩餘候選，不支持繼續把低 FPS 歸咎裝置 JSON 查詢。背景 shader 與大型透明 FX 的 fill／backing resolution 還需由 root 做受控 A/B；本報告未假稱 GPU 原因已單獨證實。

## 驗證

`ProjectilePerformanceR36Test` PASS：60 logic ticks、31 tiny-glint redraw、friendly per-tick device checks 0、hostile 200 ms refresh、pool cache 清空。`FirepowerR36Test` PASS：十秒真 40.28 枚／秒、四 lane／兩 row 真傷害、12／16／20、hidden LOD 真命中與 cleanup。`AttackVfxR34PoolTest` PASS：各類十次 reuse，無殘留拖尾，真 damage 保留。原 M1 全套 fixture 已過時，引用刪除的背景 DECOR_POOL_SIZE 而無法 parse，未列作通過，另以新有界 fixture 驗證本次行為。

原始資料在 `docs/evidence/r36/performance/`：三份 no-video JSON／場內 PNG、完整 `.cpuprofile` 與 `cpu-profile-summary.json`、三份回歸 log。自然遊玩各有一筆未識別 URL 的 HTTP 404，未觀察到 gameplay SCRIPT_ERROR；404 沒有被移除或冒稱已修。

## R3 歷史候選：GL frame-commit cache A/B

Root 在 Web shell 加三項 GL state cache：SCISSOR_TEST、DRAW_FRAMEBUFFER_BINDING、READ_FRAMEBUFFER_BINDING，仍將實際 bind／enable／disable／draw 交給原生 WebGL。Create／delete 追蹤 framebuffer，context restore 重新同步。這個方向符合 [MDN 避免同步 WebGL 查詢的建議](https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices#avoid_blocking_api_calls_in_production)。Godot 官方 4.7 Web source 已指定 `antialias=false` 與 `explicitSwapControl=true`，因此本次沒有虛構可切換的 offscreen framebuffer 專案旗標；見 [官方 source](https://github.com/godotengine/godot/blob/4.7-stable/platform/web/display_server_web.cpp#L1056)。

同一 R3 HTML／PCK，依序一個 Chrome game 進行。透過真 main menu seed 輸入與 Enter 使用 run_seed `20261002`，正常走位／選第一張升級卡，不錄影、不降低世界 FOV、UI 或 backing resolution，GPU preference 都關閉以維持同一 Intel renderer。原生 GL 比對只在 FPS 測量結束後執行。

| R3 實測 | active 秒 | FPS 平均／中位數 | 最低／最高 | logical 子彈／敵人峰值 | GL native verification |
| --- | ---: | ---: | ---: | ---: | --- |
| 桌機 cache OFF、preference OFF | 30.65 | 48.56／53 | 24／60 | 85／122 | cache 未安裝 |
| 桌機 cache ON、preference OFF | 30.48 | 58.42／59 | 39／60 | 64／95 | 三項全相符，cachedQueries 4530 |
| 手機 cache ON、preference OFF | 60.47 | 55.29／59 | 19／60 | 105／108 | 三項全相符，cachedQueries 7112 |

桌機兩段均 CSS／canvas 1280×720、DPR 1；手機 CSS 844×390、canvas 1688×780、DPR 2。全部為 ANGLE Intel Graphics D3D11，沒有改成 SwiftShader 或假稱測到獨顯／實體手機。相同 seed 與輸入策略仍會因 frame／physics 時序產生不同的戰鬥負載，不能把平均 FPS 差值當成精確的單因素提升百分比。GL cache 版本接近 60 FPS，但手機仍有 19 FPS 的尖峰，尚非穩定 60+ 驗收。

桌機 process monitor 平均 33.57→15.02 ms，physics 20.72→17.81 ms；draw calls 平均 605→657，沒有用刪減繪圖／火力換數字。手機平均 process 19.89 ms、physics 24.02 ms、draw calls 614；實際 engine physics rate 59.74 Hz、projectile physics ticks 4007.37／秒、spatial queries 334.69／秒。

R3 可重現識別：PCK `index-65f6a6f3bcb5.pck`，完整 PCK SHA-256 `65f6a6f3bcb590a26afddac87e1fab900e513b7a211a82520d4611167070834d`；HTML SHA-256 `17ce0ad63ade5c09c4a27dd0b7147feb7bd10667cce275c254920790f872e3be`；inline shim SHA-256 `3aa6455f00e44b85f1c4e943e3a7ea92872c795c99d6f5dc466127993db7669c`。Source raw SHA `99543dc86933b1db31881dbc1ac1e3f6949c89276754ca731dfeb57ff79ac8b4` 與 inline 不同，只因 source 正文後一個 LF，而 inline 正文前一個 LF、後兩個 LF；正文逐 byte 完全相同，trim 後 SHA 都是 `9b672b8823463e031dea6fe4a4b8a49787c31c0273e3c0cdf6752ce91604a991`，實際兩邊 CRLF count 都為 0。

資料：`r3-gl-off-pref-off-desktop.json/png`、`r3-gl-on-pref-off-desktop.json/png`、`r3-gl-on-pref-off-phone.json/png`、`r3-shim-source-reconciliation.json`。額外 strict mock 1000 次合法 commit 保留三項狀態、native hot reads 只有起始 3 次；foreign／deleted FBO 與 restore 亦正確。Mock 沒有被當成實際 GPU 測試，實際畫面測量結束後的 native verify 則有獨立記錄。

以上都是 R3 歷史候選。Root 的關卡／召喚修正與下一份 final PCK 尚待重新 QA，這些結果不宣稱驗過未匯出的版本。
