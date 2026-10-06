# R41 載入與負載量測

新版在這台 Windows Chrome 完成冷載入、正常開局與二十秒自然戰鬥，未出現 page crash、WebGL context loss 或 script error。啟動順序已實際走到 ready，畫布與記憶體負載下降；CPU 長任務這次較多，不能宣稱所有效能都變好，也不能據此宣稱實體手機當機已修復。

同一 Chrome 154／Intel D3D11，手機模擬 844×390、觸控、原生 DPR 3、Windows UA；沒有改 navigator、硬體節流、路由替代、生命、RNG、敵人位置或時間。新 context 使用冷 HTTP cache，允許正常 service worker 安裝。載入時間是 localhost 結果，不是公網手機下載時間。全部 Chrome 已關閉。

最終候選版為 `0.26.3-r41`，PCK `index-2f4a5b104eda.pck`（SHA-256 `2f4a5b104edab5d5de04d382f8268fb23806489066422d5091ee30213c5f5792`），HTML SHA-256 `24f109f4b5a1ebc4b56ff3cdfb285b82857933430655e77472b4b18ee2350bbb`。Menu 與戰鬥結束的 startup.phase 都是 ready，實際 transitions 為 loading_engine → loading_pack → initializing → ready；loading_pack 確實出現，沒有舊候選版停在 loading_engine 的空紀錄。公用 Engine 呼叫順序另由發布 HTML semantic guard 覆核。

| 指標 | R40 基準 | R41 最終候選版 |
|---|---:|---:|
| CSS 視窗／原生 DPR | 844×390／3 | 844×390／3 |
| 實際 canvas／drawing buffer | 2532×1170 | 844×390 |
| Backing pixels／CSS pixels | 9 倍 | 1 倍 |
| 冷載入到選單 | 3.095 秒 | 3.209 秒 |
| 載入最長 longtask | 2,572 ms | 2,727 ms |
| Start／戰鬥 longtask 數／總時長 | 3／1,024 ms | 44／5,077 ms |
| 選單 Chrome instance 私有 commit | 1,014,439,936 B | 713,392,128 B |
| 六次採樣的私有 commit 最大值 | 1,326,526,464 B | 1,147,924,480 B |
| 最後 GPU process 私有 commit | 583.3 MiB | 454.6 MiB |
| 選單 Wasm 線性容量 | 83,689,472 B | 58,064,896 B |
| Arena Wasm 線性容量 | 150,405,120 B | 167,444,480 B |
| 採樣 JS heap 最大值 | 26,839,676 B | 31,344,348 B |

這次選單私有 commit 約低 29.7%，採樣最大值約低 13.5%；這些是同一桌機上的描述性比較，不能當成所有手機的固定改善幅度。Wasm 是已配置容量，未量到實際活用量；process commit 不是 GPU VRAM。JS heap、ArrayBuffer、Wasm 與 process memory 有重疊，不能相加。六次稀疏採樣也不是連續 peak 或 leak 證據。

自然遊玩的負載並不完全相等。基準 seed `3940845419`、Lv5、羈絆 0；最終 seed `1918429631`、Lv6，已有「燼脈聯爆、星盾和聲」兩個羈絆。完整隊伍 count／roster 未發布於當時 probe，標記 **NOT MEASURED**。Leader 武器 IDs 都是 arc_chain、orbit_blades、riftline_emitter；Hero 的 debug registry 只遍歷自己的 weapon_order，不能據此說整隊武器相同。

最後 leader Riftline 的基礎輪發都是 12，基準累計 768 發／37.45 發每秒，最終 720 發／35.95 發每秒，projectiles_rejected 都是 0。Presentation 最後 active 都是 2，但 channel 為 0→1、peak 為 8→9、累計 emitted 為 113→137。最後活敵數是 122→102，logical projectile 為 42→47。這些差異足以限制 CPU／longtask 的直接歸因。最終 physics 63.2 ms、process 55.8 ms 是單一末尾 snapshot，不能換算成穩定 FPS。

Spawner 的 world_view 診斷 rect 尺寸兩次都是 1277.049×590.1639；actual CanvasScale／logicalViewport 未發布，標記 **NOT MEASURED**，不把這個 rect 當成完整 FOV 等價證明。Root 沒有修改 Camera、Range 或 cadence；本次 Web 只核對實際 CSS／buffer 與正常操作。

實圖不是空白，角色、魔物、地標與中文字都有顯示，未觀察到缺材質或 tofu 字。1× CSS backing 在 DPR 3 螢幕上放大，較基準柔，不能說仍保留原本 Retina 銳利度。七個可見選單按鈕都至少 44 CSS px。直式觸控只在先前 partial HTML 做過一次：實際 buffer 390×844、搖桿位移 65 world px、manual held 生效、全部放開後 held／pending 為假；最終 bootstrap 修正後依範圍沒有重跑直式測試。

發布證據：[baseline.json](baseline.json)、[after.json](after.json)、[最終實玩圖](after.png)。舊 HTML `c190c649` 的 partial JSON 與圖片僅保留於本機，其 startup 沒有 ready，不能和最終候選版混稱。完整 raw 留於本機 `.audit-tmp`；沒有為比較再開新局或 GPU 測試。
