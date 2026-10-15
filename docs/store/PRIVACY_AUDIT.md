# 隱私與政策核對

2026-10-15；遊戲來源碼查核 VERIFIED；已送審二進位／線上宣告一致性 BLOCKED。

## 實際行為

- 沒有帳號登入、廣告、第三方分析、追蹤 SDK、購買 SDK、通訊錄、位置、相機或麥克風功能。
- 原生遊戲的關卡、音樂、字型與圖像都在本機套件；存檔是 `user://` 下的 campaign、殘響、封隙紀錄、設定、成就及寵物。本機進度不是伺服器帳號，不做跨裝置同步。
- 掃描 `scripts/`、`resources/`、`web/` 的 HTTPRequest／HTTPClient／WebSocket／ENet／TCP／fetch／XMLHttpRequest／sendBeacon／shell_open；沒有遊戲向外傳資料或開外部連結的路徑。掃描原始清冊在 `../evidence/r44-store/shared-assets.json`。
- Web 測試會從 **127.0.0.1** 下載 loader、WASM、PCK、圖示與主視覺，並註冊同來源 service worker；用途是載入遊戲，並非分析資料。實際 reviewer path 的 request 清單／外部請求數由測試驗證。公開 Web 主機若自行記錄 IP，不在原生「無收集」結論內。
- 遊戲的英文品牌／Godot 控制台網址不是網路請求；測試 probe 只在指定 QA query 下輸出狀態，沒有公開除錯面板或上傳功能。

## iOS

`export/native/ios/PrivacyInfo.xcprivacy` 確實存在並能以 plist 解析：`NSPrivacyTracking=false`；列有 FileTimestamp（DDA9.1、C617.1）、SystemBootTime（35F9.1）、DiskSpace（E174.1、85F4.1）。解析結果與 SHA-256：`../evidence/r44-store/native-privacy.json`。

這是**既有本機產物**。旁邊的 `ios-verification.json` 指向 sourceVersion `0.27.0-r42`、nativeBuild 3，狀態是 Xcode source created、not compiled，且 physicalDeviceTested=false。它不能證明 Apple 正在審查的簽署包和這份 manifest 相同，更不能說 R44 已送達 Apple。Godot 引擎使用的 required-reason API 也需在最終 archive 確認，而非只看 GDScript。

本次沒改 iOS preset 的原生版本／build、沒重新匯出包；`native/build-config.json` 只更新 sourceVersion，nativeBuild 保留 3。[Apple 隱私清單說明](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) 是後續 archive 核對依據；未驗收的 required-reason 使用不填成完成。

## Android／Google Play

兩個 Android preset 的 INTERNET、ACCESS_NETWORK_STATE、RECORD_AUDIO、READ_EXTERNAL_STORAGE、WRITE_EXTERNAL_STORAGE 均為 false。既有 Android verification 是 build 3 的未簽署舊來源匯出，沒有本輪重新打包或實機證明。

依目前遊戲來源的 `DATA_SAFETY_DRAFT.json` 是「不收集、不分享資料，無帳號／廣告」。這只是本機草稿；沒有進入 Play Console，也沒有已發布表單的當次讀回，故線上宣告是否一致仍 BLOCKED。[Google 官方資料安全說明](https://support.google.com/googleplay/android-developer/answer/10787469) 要求包括 SDK 在內的實際行為一致，後續須針對最終簽署 AAB 核對。

## native-kit 唯讀結果與缺件

檢視 `../game-store-publisher/native-kit/apps/`，有其他 Web／Capacitor 遊戲，沒有 crackveil-vanguard 專屬 app 資料夾；本作走 repo 自己的 Godot 原生匯出工具。不能把別款 Capacitor 的 PrivacyInfo 拷進來當本作驗證，也沒有修改 native-kit。

| 狀態 | 缺件 |
|---|---|
| BLOCKED | 正在審查的 build 3 已簽署 IPA、archive 內 manifest 與本地來源對照，以及最終 SDK／required-reason API 清單 |
| BLOCKED | Google Play 已發布資料安全表單與最終 AAB 的對照讀回 |
| BLOCKED | iPhone／iPad／Android 飛航模式冷啟動、背景中斷、儲存空間不足的實機紀錄 |
| VERIFIED | 本輪沒有讀取 `.secrets`、加入金鑰、SDK、網路請求或追蹤；沒有對外寫入 |

本作不是兒童教育分類產品，無外部連結、評分請求或付款入口。沒有因比較表提到其他兒童 App 而套用其家長關卡流程。

**離線範圍：** Godot 原生內容全在本機，功能回歸在沒有遊戲伺服器的 headless Arena 執行；Web 目前只快取外殼／離線說明，沒有快取全部 PCK／WASM，首次或重新載入仍需網路。未把 Web 的離線說明頁算成「離線可玩」，原生實機飛航驗證仍待補。
