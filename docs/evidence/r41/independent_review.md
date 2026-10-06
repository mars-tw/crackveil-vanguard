# R41 啟動減量獨立覆核

2026-10-06，獨立上下文，同模型。讀取啟動 JS、finalizer、實際 export HTML／Engine API、恢復 UI、project／export 設定及背景／預熱／import diff。只做來源與 Node 語法解析，沒有 GPU、瀏覽器、iPhone 硬體重現或本機整套測試。

**最終結論：下列整合與引用保留問題均已修正並讀回確認，此來源範圍沒有待修的阻擋缺陷。**

## 已發現並解除的 export 問題

初次候選不能判定 bootstrap 整合通過。Finalizer 先將 `mobile_startup.js` 插入 head，再於整份 HTML 替換第一個 `engine.startGame({`，命中的是 helper 內的 Desktop 分支。

讀取當下的 `export/web/index.html:256` 已變成 helper 自己呼叫 `CrackveilMobileStartup.start`，缺少 state；真正 body 啟動點仍呼叫 `engine.startGame({ ... }.onProgress, r41Startup)`。所以手機並未經新的 sequential helper。六段 classic inline script 的 `vm.Script` 語法解析皆成功，但語義 guard 確認：helper 原 Desktop call 消失、出現誤替換 self-call、body 仍用 parallel startGame。單獨 require 原 JS 的 mock PASS 不能驗證此 generated HTML 整合。

Root 已改為定位含 quoted `onProgress` 的唯一 body 啟動 call，保留 helper 的原 Desktop startGame，並加入生成 HTML 的 semantic guards／CI export-step 檢查。此 reviewer 再對真正的最新 HTML 解析：六段 classic script 語法皆有效、helper Desktop call 保留、沒有 self-call、body 為四參數 sequential wrapper、沒有 body 原 direct startGame。

初次另有 failure latch 缺口：recovery 收到啟動期間的 contextlost／unhandledrejection 設定 phase=failed，但 start 的 await 後仍能覆蓋成後續階段。Root 已加入 `state.fail()`／fatal latch，禁止 failed 轉回其他 phase，並於 init／preload await 後與 ready 前 `ensureAlive()`；recovery 同樣使用 fail。已讀回來源與最新 exported helper。Root 的 deferred mock 亦驗證 init 等待時發生 context loss、其後 resolve 仍保持 failed、不下載 pack。這是來源條件驗證，不是 Safari 硬體故障重現。

## 已確認的正確方向

- Mobile helper 使用公開 Engine API：init、preloadFile、start，保留 `--main-pack` 與既有 args；constructor onProgress 先提供回饋，無需依賴 start 的較晚 override。
- 手機 backing canvas 採 CSS 尺寸、上限 921,600 像素，不改瀏覽器 devicePixelRatio。一般 1280×720 mouse desktop 保留 policy 2／startGame；窄觸控視窗有 fallback 分類，iPhone／iPad UA 直接涵蓋。
- Keyart 改為同一外部 URL，取消 HTML base64 重複；project boot image 清空，輸出的小 index.png 不再複製整張原畫。原 master 沒有修改。
- Phone main menu 不初始化被主視覺遮住的 terrain／landmark 腳本。舊 atlas 與已排除的 R24 路徑已移出 gameplay prewarm；EntityFactory 原池量與遊戲邏輯不變。
- 讀取的 import diff 僅背景、keyart、world map、地標採 Lossy WebP／size limit；仍為普通 RAM texture，不是 Basis／VRAM 格式。Actor atlas、FX、原畫、HP、RNG、密度、range、F2 與 shared-frame 規則沒有相關修改。
- EnemyArt fixture 改為驗證當前 R35／R38 shared atlas 與歷史 atlas 不被預熱；原有 walk／attack／hurt／death 及 impact assertions 保留，未以移除姿勢標準來換通過。

## 已修正的 listener 保留

初次覆核指出：window／canvas 的 failure listeners 經 closure 保留已移除的 loader DOM。Root 已新增 cleanup，ready、artwork disconnected 或 failed 時移除 timer、unhandledrejection 與 contextlost listener；失敗時保留 Retry UI。已讀回此修正，resize／orientation listener 留到遊戲期間屬正常 canvas 維護。

恢復 UI 也新增下載 100% 後未 ready 的初始化停滯提示；body call、fatal latch 與 listener cleanup 的來源整合已確認。

## 最終候選與驗證範圍

最新本機候選為 `0.26.3-r41`，PCK `index-2f4a5b104eda.pck`／19,631,328 bytes，完整 SHA-256 `2f4a5b104edab5d5de04d382f8268fb23806489066422d5091ee30213c5f5792`。實際 HTML 為 22,505 bytes，SHA-256 `24f109f4b5a1ebc4b56ff3cdfb285b82857933430655e77472b4b18ee2350bbb`；index.png 為 21,443 bytes。這是修正後的 fresh export，不沿用未修整合的 partial 候選作 after 證據。

已讀回 `targeted_gates.json` 八項相關 Godot gate，全部 exit 0、errors 0；也核對 R41 Node 測試中的 sequential API、Desktop 原路徑、100% 初始化停滯、cleanup、fatal deferred 及 `--html` semantic assertions。此 reviewer 只重做最新 HTML 的唯讀語法／semantic inspection，未重跑這些 gameplay gates，也未啟動 graphics。

Package／HTML 尺寸下降代表傳輸與部分配置減量，不等於已量到 Safari process／GPU 記憶體峰值，也不代表 iPhone 14 已可進入。修正後的 browser pressure 對照及真 iPhone 結果須另行記錄，不能混用未修 partial 數據。
