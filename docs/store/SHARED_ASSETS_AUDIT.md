# 程式、素材與模板稽核

2026-10-15；EXECUTED。工具：`python tools/audit_r44_store.py`。逐 repo 掃描數、原始命中與雜湊比對結果：`../evidence/r44-store/shared-assets.json`。只讀其他資料夾，沒有寫入或提交其他 repo。

## 方法與限制

以本 repo 已追蹤的遊戲程式、場景、資源、UI、字型、點陣圖、向量圖與音檔為母集，對其他 repo 已追蹤的同類檔案按大小過濾，再比 SHA-256。排除 docs、build、node_modules、Unity Library／Temp；不把報告或建置快取當成遊戲素材。零個相同檔案雜湊，不等於風格沒有相似，也不等於已分析最終二進位或所有未追蹤素材。

實際涵蓋：暴風啟示錄、灰燼護航、無盡塔防、裂潮卡牌、陽光農場、村莊攻防、七期、Rift Forge 3D、交通學院、小小列車長、鐵道學校、飛行學校。夜行列車本地只有重製企劃資料夾，沒有可辨識的遊戲 git repo；該作的逐檔比對為 BLOCKED，不填零重複。

## 逐項處理

| 本作檔案／組件 | 與哪款重複或相似 | 處理方式與狀態 |
|---|---|---|
| `scripts/heroes/squad_manager.gd`、`scripts/services/formation_relay.gd` | 已掃描 repo 沒有相同已追蹤檔案；「敵潮」概念仍與暴風、灰燼接近 | VERIFIED：新增真實隊員到位封隙，具體區隔見 DIFFERENTIATION；沒有把改名當新玩法 |
| `assets/fonts/default_theme.tres`、`scripts/ui/main_menu.gd`、`scripts/ui/hud.gd` | 無檔案雜湊重複。暴風 `src/styles.css` 同有暗底、淺藍；無盡塔防有三元素色，但屬塔防 UI | VERIFIED：本作保留幻想石庭、裂隙原畫及隊伍戰鬥；出擊入口改為三陣封隙，場內以楔、環、三散點和三色對應操作。這些是向量操作標記，沒有冒充新人物美術 |
| `assets/fonts/NotoSansCJKtc-Regular-UI-Subset.otf` | 暴風／交通教育產品也使用 Noto 字族；本作子集位元組無重複 | VERIFIED：標準第三方 Noto 字型，保留授權，不為避重複換成難讀字；本作內嵌離線字型，並未載入其 Google Fonts CSS |
| `web/icons/icon_512x512.png` 及 144／180 圖示 | 已掃描 repo 沒有相同雜湊 | VERIFIED：實際檢視為本作裂隙與英雄圖，不是 Godot 預設圖示；未重生圖示 |
| `assets/art/r33/r33_keyart.png`、`tools/finalize_r25_web_export.py` 的載入主視覺 | 無相同遊戲資產；Godot Web loader 的標準引擎殼屬第三方 | VERIFIED：保留本作主視覺／載入進度／失敗重試；沒有沿用別款封面或宣稱標準 loader 原創 |
| `assets/audio/*.wav`、`assets/audio/r42_battle_loop.ogg`、`scripts/autoload/audio_manager.gd` | 無相同已追蹤音檔雜湊；灰燼 `src/audio.js` 使用 Web Audio 合成，並非本作 Godot 音檔或播放碼 | VERIFIED：沿用本作音色與既有音樂來源；三陣封隙完成使用本作 upgrade 音效，沒有新增來源不明聲音 |
| `scripts/animation/*`、英雄與敵人 atlas | 無相同已追蹤資產雜湊 | VERIFIED：真逐幀／碰撞根分離回歸照跑；無單圖晃動、無新增程序方塊角色 |
| `scripts/services/web_reachability_probe.gd` | 本作內部自動測試觀測工具，不是公開除錯面板 | VERIFIED：一般網址不發布測試物件；指定 QA query 才輸出唯讀幾何；沒有遠端控制／玩家資料上傳 |
| `scripts/debug/**`、`scenes/debug/**` | 本 repo 歷史測試與工具，不屬玩家內容 | VERIFIED：Web、Android、iOS 的現有 export exclude 均排除；新增 R44 測試沿用排除範圍，未改原生 preset |
| `scripts/heroes/hero.gd`、`scripts/resources/hero_data.gd` | 原預設「未命名英雄」是本作通用佔位文字 | VERIFIED：改為「裂隙隊員」；有效英雄仍顯示其正式名稱，沒有修改角色資料或測試斷言 |
| `scripts/resources/weapon_data.gd`、`scripts/weapons/base_weapon.gd` | 原預設「未命名武器」 | VERIFIED：改為「裂隙武裝」，有效武器仍用正式名稱 |
| `scripts/autoload/game_manager.gd` | 原預設 Boss 英文 `VEIL GATEKEEPER` | VERIFIED：改為「裂隙守關者」，關卡 Boss 的正式名稱不受影響 |
| GameManager 與主選單教學文案 | 原「開局先選契約」不符合快速出擊 | VERIFIED：說明種子出擊才選契約；開局說明改成實際三陣封隙步驟 |
| Godot 4.7、GDScript、Noto／既有 CC0 素材庫 | 標準第三方元件；Rift Forge 3D 是 Unity，其他多為 Web 技術棧 | 保留並在既有 CREDITS／LICENSE 中追溯；原始庫相同不等於可聲稱完全不共用第三方內容 |

原始文字掃描中的 `sample_rate`、`texture_samples` 是音訊／繪圖變數，LineEdit 的 `placeholder_text` 是有效輸入提示；不屬可見的 Sample 佔位文案。只存在開發註解的 placeholder 也沒有當作玩家內容。沒有找到 Lorem、敬請期待或待實作的公開入口。標準英文品牌、Boss、HP、Lv. 等遊戲慣用縮寫仍保留。

當次唯讀的塔防 `src/store-identity.css` 已有「三才陣」與三元素識別。因此「三種、三色、陣法」都不能單獨當成本作與同帳號的差異；本作必須靠活隊員的實際移動、朝向與到位判定來成立。其他線路仍在變動，這項只描述讀取當時的本機檔案。

## 素材增量

本輪沒有新點陣美術、音樂或模型生成，未呼叫圖像服務。`ART_MANIFEST_R44.json` 記錄空的新生成清單與向量 UI 用途，以及八個既有 PNG 的來源／出貨路徑和相同 SHA-256。這八圖原先受 R24 目錄排除規則影響，現在原樣複製至 `assets/art/r44-runtime/`，原檔保留；其既有生成來源為 `assets/art/r24/manifest.json` 的 gpt-image-2，沒有冒稱本輪重生。現有角色、敵人、地圖與圖示已存在，沒有以幾何物體替代角色或地圖。若後續要重製角色／封面，須另取得生成紀錄，不能把向量陣記算成已完成插畫。

## 未完成

- BLOCKED：夜行列車遊戲原始碼比對、最終簽署 IPA／AAB 的跨產品二進位比對。
- BLOCKED：多人實機 beta 對識別度的回饋。零檔案重複無法回答 Apple 是否認為體驗仍同質。
- 本次兄弟 repo 均可能正被其他線路修改，清冊是這次讀取的本機快照，不能宣稱其最終版本已被驗證。
