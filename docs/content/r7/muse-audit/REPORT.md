# Crackveil Vanguard — Apple Guideline 4.3 二進位相似度稽核（唯讀）

- 對象：`rift-survivors`（Godot 4.7 專案，商店名 Crackveil Vanguard，`tw.mars.crackveilvanguard`）
- 比對：`game-store-publisher/native-kit`、`rift-forge-3d`（Unity）、`_共用文件`
- 方法：唯讀讀檔、全文搜尋、SHA-256 比對、解析既有匯出日誌。未執行遊戲、未匯出、未修改任何既有檔案、未連線商店後台。
- 證據時效警告：既有 iOS 匯出產物（`export/native/ios/`、PCK、`ios-export.log`）為 2026-10-15、`sourceVersion 0.27.0-r42`；目前原始碼為 `0.35.0-content-r6`（2026-10-27）。凡「舊匯出已打包」的證據只能證明該次匯出，不能直接證明下一次送審 build；凡「依目前 preset 推斷會打包」者已註明為推斷。最終送審 build 的二進位相似度，在乾淨重匯出並比對前一律為**無法確認**。

## 結論（先讀這段）

1. **沒有找到 Crackveil 與 Rift Forge 3D 之間自有遊戲程式或出貨素材的完全相同檔案。** 跨專案 SHA-256 比對（RS 12,927 檔、RF 450 檔，已排除建置快取）命中的自有內容為零；唯一實質命中是第三方 OFL 授權文本。兩作引擎與語言不同（GDScript 對 C#），檔案層不存在整段程式複製。這表示 4.3 的風險不在「檔案複製」，而在**概念與帳號層的模板觀感**。
2. **正式版確實帶著測試／QA 程式出貨，這是本次最具體、最該先修的問題。** `scripts/debug` 與 `scenes/debug` 本身有被排除（證據充分），但放在出貨目錄的探針沒有被排除：Web 可達性探針、四支 arena 美術探針、QA 存檔分流、HUD 執行期探針、裝置提示覆寫後門都會進 iOS PCK。它們在 iOS 上多半不執行或不改變行為，但程式、參數名與 `__cvR*` 字串都在二進位裡，且顯示開發方式是「測試碼與正式碼同居」。這不必然觸發 Apple 的自動比對，卻是審查回覆中最難解釋、也最容易自己先清掉的一層。
3. **iOS 打包層與同帳號另一款 Godot App（Seven District Reckoning）共用同一套 CI 與不變量。** 引擎二進位、PrivacyInfo、Info.plist 模板、圖示產生方式相同屬 Godot 官方模板層，可接受；但兩款的 PCK 是否除第三方外無自有相同檔案，本次範圍不含該作原始碼，**無法確認**，而這正是 Apple 比對最可能命中的一對。
4. **Capacitor 共用包裝層（native-kit 的 9 款 Web App）不進 Crackveil。** Crackveil 走 Godot 原生匯出，與同帳號最像「重新包裝模板」的證據鏈是分開的。回覆時應主動切清這一刀。
5. **概念層風險專案自己已評為高。** 敵潮＋升級＋Boss＋局外成長與同帳號多款生存／動作產品受眾重疊；差異主張（三陣封隙、活隊員到位）是否已在送審 build 出貨並能被玩家感知，文件不能代替實機證據。

## 優先順序

| 順序 | 事項 | 為什麼先做 |
|---|---|---|
| P0 | 移除或移入 debug 目錄：`web_reachability_probe.gd`、四支 `scripts/arena/*_probe.gd`、`qa_profile.gd` 連同 autoload 呼叫、`mobile_tuning` 的 `*_for_tests` 後門、HUD／世界地圖探針 | 純 QA 程式在正式版，零玩法價值，修改面小且可驗證 |
| P0 | 補 exclude：`release/**,native/**,output/**,.playwright-cli/**` | 已證實驗證 JSON 被打包，屬設定缺口 |
| P0 | 統一 build 號：`export_presets.cfg` 的 version=3、`native/build-config.json` 的 nativeBuild=3 對 CI 驗證器與舊 source-verification 的 build=1 | 避免拿舊的已驗證來源送新版 PCK |
| P1 | 對 Crackveil 與 Seven District 兩款乾淨匯出的 PCK 做檔案清單＋雜湊差異表 | 這是同帳號最可能被 Apple 配對的一組，目前無法確認 |
| P1 | 以送審 build 實機錄影證明三陣封隙等差異已出貨 | 回應 4.3 的 concept 與 binary 指控需要可觀看證據 |
| P2 | 啟動畫面改用本作 key art、移除未用權限的空字串 | 降低模板第一印象，成本低 |

以下逐項給證據。行號皆為本次讀取的目前原始碼；舊匯出證據已標日期。

---

## 一、正式版會打包進去的內容

### 1.1 iOS preset 的實際規則

`export_presets.cfg` 的 preset.3「iOS Xcode unsigned」（L139-152）：

- `export_filter="all_resources"`（L146）：全專案資源為母集。
- `include_filter="assets/audio/*.wav"`（L147）：在此模式下屬額外納入宣告，不構成白名單。
- `exclude_filter`（L148）排除：`assets/rodin/**`、`export/**`、`scripts/debug/**`、`scenes/debug/**`、數個舊 atlas 與 `assets/art/r34|r35|r36|r38` 的 sources/qa、`assets/art/r24/**`、`assets/art/r25/**`、`tools/**`、`docs/**`、`android/**`。
- `script_export_mode=2`（L152）、`encrypt_pck=false`（L150）：腳本以編譯形式打包；本次以純文字掃描舊 PCK 只能找到路徑表與殘留字串，不能當成完整內容清單（PCK 目錄解析未成功，原因為格式版本與目錄編碼未能以簡易偏移解析，此點不推論）。

依此推斷，iOS 正式版 PCK 會包含：`scenes/**`（除 debug）、`scripts/**`（除 debug）、`resources/**`、`assets/**`（除上列排除）、`web/icons/**`、`native/build-config.json`、`release/**/*.json`（見 1.4）、專案設定與圖示。檔案類型以 Godot 匯入後形式為主（`.gdc/.remap`、`.scn/.res`、`.ctex`、`.sample`、字型資料），舊匯出日誌的 savepack 統計可作旁證：該次共 656 筆，含 `.godot/imported` 223、`scripts` 200、`assets` 154、`scenes` 39、`resources` 29、`web` 5、`native` 1、`release` 2。

### 1.2 已確認被排除：`scripts/debug` 與 `scenes/debug`

- `scripts/debug` 共 89 支 `.gd`、`scenes/debug` 共 88 個 `.tscn`，含歷輪 regression、review、QA hook（`r31_endgame_qa_hook.gd` 需 debug 建置加 `--qa-endgame=r31`，見該檔 L21-26）。
- 舊 `ios-export.log` 全文對 `scripts/debug`、`scenes/debug` 的 savepack 命中數皆為 0；`docs/`、`tools/` 同為 0。此為「排除有生效」的正面證據（限該次匯出）。
- 非 debug 程式未發現 preload `scripts/debug`；QA hook 只被同目錄的 `r31_endgame_gate.gd:12` 引用。因此「debug 目錄被排除」這一項**成立**，但不能延伸為「正式版沒有測試程式」，見下節。

### 1.3 會進正式版的測試／QA／除錯程式（逐項）

#### (a) Web 可達性探針 — 進 PCK，iOS 不執行

`scripts/services/web_reachability_probe.gd`（34 行）：

- L6：非 web 直接 return，所以 iOS 正式版呼叫時不做任何事。
- L33：字串含 `cv_r19_test`、`cv_r22_test` 與 `window.__cvR19Controls/__cvR22Controls`，會隨編譯腳本留在二進位。
- 舊匯出日誌 L183、L535 證實 `.gdc/.remap` 已打包。
- 呼叫端 9 處皆為正式 UI：`contract_screen.gd:544`、`first_run_guide.gd:269`、`hud.gd:1569`、`level_up_screen.gd:152`、`main_menu.gd:1107`、`r4_battle_journal.gd:148`、`r4_build_preparation.gd:357`、`r4_result_screen.gd:393` 等，皆以 preload 常數引用。

建議：整檔刪除並移除 9 處呼叫；版面量測改由 Web 端外部測試（Playwright 讀 canvas/DOM 幾何或截圖比對）。這是功能純觀測、玩家零感知的程式，沒有保留在正式版的理由。專案自己的 `docs/store/SHARED_ASSETS_AUDIT.md` 已記載其為內部觀測工具，與本結論一致。

#### (b) HUD 執行期探針（`cv_r32_test`）— 進 PCK，iOS 只走到早退

`scripts/ui/hud.gd`：

- `_on_stats_changed`（L1835-1836）每次統計變化都呼叫 `_publish_runtime_probe`。
- L1884 非 web 早退；iOS 到此為止。但 L1888 的 `cv_r32_test` 參數、L1893-1940 把 FPS、效能監控、玩家座標與多個 `get_debug_state()` 組裝成 payload、L1941 寫 `window.__cvR32Runtime` 的整段程式都在正式版。
- 連帶地，正式程式中共有 13 處 `get_debug_state()` 定義（heroes、pets、services、ui、vfx、weapons 等），部分被正式功能使用（如 `r36_minimap.gd:44,48` 讀 topology 狀態），部分純供探針。應逐一分：正式在用的改為正式命名的狀態 API；只供測試的隨探針移除。

建議：刪除 `_publish_runtime_probe` 與 `runtime_probe_checked/enabled`（L124-125）及呼叫點；效能數據改在開發建置以引擎監控量測。

#### (c) 世界地圖探針（`cv_r22_test`）— 進 PCK，iOS 不執行

`scripts/ui/world_map.gd:74-75` 在 web 時讀 `cv_r22_test` 設定 `probe_enabled`，`_publish_probe`（L503-505）再寫 `window.__cvR34WorldMap`。iOS 不執行 eval，但參數與 `get_debug_state()`（L489）在正式版。建議與 (a)(b) 一併刪除，版面驗證移到 Web 外部測試。

#### (d) QA 存檔分流 `CV_QA_PROFILE` — 進 PCK，iOS 會執行（行為通常不變）

這是唯一「在 iOS 正式版會實際執行」的 QA 路徑：

- `scripts/services/qa_profile.gd:5-10`：無 debug 守衛地讀 `OS.get_environment("CV_QA_PROFILE")`，有值時把存檔改到 `user://qa_<profile>_...`。
- 五個 autoload 在啟動／存檔時呼叫：`achievement_progress.gd:66`、`audio_manager.gd:83`、`game_manager.gd:262`、`meta_progress.gd:75`、`player_settings.gd:17`。
- iOS 上環境變數一般為空，結果等於原路徑，所以玩家行為不變；但「依環境變數切換存檔位置」的測試分流邏輯在每個正式玩家裝置上執行，且變數名明文在二進位。

建議：正式版讓 autoload 直接用原 `SAVE_PATH`；測試隔離改由測試在啟動前備份／還原 `user://`，或使用測試專用建置。次佳作法是加 `OS.is_debug_build()` 守衛，但仍留字串，不如刪除乾淨。

#### (e) 存檔故障注入 — 在正式版，但正式版不觸發

`scripts/autoload/meta_progress.gd:70-71` 的 `debug_save_fault` 欄位與 L486、L497 的分支，受 `is_debug_build()` 且 `CV_QA_PROFILE` 非空雙守衛；設定端只在已被排除的 `scripts/debug/content_r3_test.gd`。結論：程式在、行為不在。建議把故障注入移出正式 autoload，改由測試替身包裝寫入層。

#### (f) Arena 美術探針四支 — 進 PCK，不被實例化

`scripts/arena/r33_art_probe.gd`、`r34_art_probe.gd`、`r34_composition_probe.gd`、`r34_final_storm_probe.gd` 位於出貨目錄，其場景在已被排除的 `scenes/debug`，非 debug 程式未發現引用，故 iOS 正式版不會執行；但舊匯出日誌 L457-462、L626-630 證實四支皆打包，且內容是寫證據圖到 `res://docs/evidence/...`、設定 `forced_run_seed`、`set_device_hints_override_for_tests` 等純 QA 行為（`r34_final_storm_probe.gd:21,24`）。

建議：移入 `scripts/debug` 與場景同置，或刪除改以 `tools/` 無頭腳本重現。這是「場景排除了、腳本卻留在隔壁」的典型漏網。

#### (g) 裝置提示覆寫後門 — 在正式版，無正式呼叫端

`scripts/services/mobile_tuning.gd:61-63` 的 `set_device_hints_override_for_tests` 與 L291-292 的 `set_force_mobile_lod_for_tests`（設定鍵 `crackveil/debug/force_mobile_lod`，L17）為公開靜態函式，`_runtime_device_hints`（L492-493）優先採用 override。正式呼叫端搜尋結果僅 debug 測試與 (f) 的探針；iOS 出貨流程不會啟用。建議刪除兩函式與 override 分支，測試改用既有 `device_hints` 參數注入（如 `layout_tier(..., device_hints)`，L66）。

#### (h) 已受 debug 守衛者 — 在正式版，不執行，可接受但建議收斂

- 截圖美化模式：`hud.gd:213,307,2499-2501`、`entity_factory.gd:568`、`game_manager.gd:252-254`，皆需 `OS.is_debug_build()`。
- 債券除錯 print：`squad_manager.gd:896-897`，debug 才印。
- `--run-seed`：`arena.gd:254-268` **無 debug 守衛**，正式版會解析啟動參數；但它同時是玩家種子出擊的正式路徑（`main_menu.gd:717-728` 的種子輸入、`arena.gd:202-206` 種子重開），性質與 QA 參數不同。iOS 一般無啟動參數而走隨機。建議保留玩法、移除 cmdline 解析只留 UI 輸入，或在審查文件中明示其為玩家功能。

#### (i) 任務點名的 `cv_r5_pause_layout` — 無法確認

以 `cv_r5`、`pause_layout` 全文搜尋 `scripts` 與 `scenes`，命中數為 0；找到的同族參數只有 `cv_r19_test/cv_r22_test`（探針，L33）、`cv_r22_test`（world_map:75）、`cv_r32_test`（hud:1888）。`cv_r5_pause_layout` 可能屬舊版、其他分支或其他專案，本次證據不足，**無法確認**，不寫成已移除。若送審 build 非目前 commit，請提供該 build 的 PCK 或 commit 再查。

### 1.4 排除清單的缺口：`release/`、`native/` 等被打包

舊匯出日誌 L422-424 證實 `res://native/build-config.json`、`res://release/android/verification.json`、`res://release/ios/source-verification.json` 進了 PCK。原因直接：exclude 未列 `release/**`、`native/**`。同理未列的 `output/**`、`.playwright-cli/**`、`.github/**` 是否打包**無法確認**（無匯入紀錄者通常不打包，此為推斷）；但 `.json` 已證實會被掃入。建議四個 preset 一併補上這些排除，並在每次匯出後檢查 savepack 清單中不得出現 `release/`、`output/`、`docs/`、`tools/`。

`web/` 方面，舊日誌只見 `web/icons` 四圖（L98-111,666），符合 `project.godot:14` 以 `icon_512x512.png` 為專案圖示的預期；`offline.html`、JS 檔未見於 savepack，是否因非資源而不打包無法確認。建議明示排除 `web/*.html,web/*.js,web/*.mjs`、只留 `web/icons/**`。

---

## 二、與比對對象共用的程式或素材

### 2.1 完全相同（SHA-256）

比對範圍：RS 排除 `.git/.godot/.audit-tmp/export/output/release/android/.playwright-cli`，NK 排除 `node_modules/__pycache__` 與各 App 的 android/ios 產生目錄，RF 排除 `Library/build/Logs/.git` 等。結果：

| 命中 | 分類 | 說明 |
|---|---|---|
| RS `assets/fonts/OFL.txt` ＝ RF `Assets/_Project/Resources/Fonts/OFL.txt` | 第三方標準 | 字型本體不同（RS 子集 1.5 MB、RF 全版 5.7 MB），僅授權文本相同。可接受。 |
| RS `LICENSE` ＝ NK `apps/storm-apocalypse/web/LICENSE` | 第三方標準 | MIT 範本 1,064 bytes。repo 層相同，未證明進 PCK。可接受。 |
| RS `tools/asset_sources/particle/*.png` 6 檔 ＝ NK 塔防 `web/assets/particles/kenney-*.png` | 第三方標準 | Kenney Particle Pack（CC0）。命中在 RS 的 `tools/`，已被排除；RS 出貨圖為加工後的 `assets/vfx/kenney_particle`，雜湊不同。可接受，需保留來源紀錄。 |
| 空檔／1-byte `.gitkeep` 類命中數筆 | 無意義 | 0 或 1 byte 檔案的雜湊碰撞不具證據力，不列為共用。 |
| NK `unity-prepared/rift-forge-3d` ＝ RF 本體大量檔案 | 自有（同一款副本） | 含 Unity 標準檔與 RF 自有 `GameBootstrap.cs` 等。此為 RF 的隔離準備副本，不是 Crackveil 內容；風險是誤送審，見建議。 |

**自有遊戲程式與出貨素材的完全相同命中：RS 對 RF 為零；RS 對 NK 各 App 的出貨內容為零**（NK 命中皆在 `tools/asset_sources` 原始素材庫或 LICENSE）。此結論限檔案層；編譯後 bytecode/IL 的相似度未分析，該層為無法確認。

專案既有 `docs/store/SHARED_ASSETS_AUDIT.md`（2026-10-15）的結論與本次獨立比對一致（其母集與排除規則略有不同，且自述不含最終二進位），可互相旁證但不互相取代。

### 2.2 內容近似（非雜湊）

- **程式結構**：RS 非 debug `.gd` 共 115 檔、約 1,794 個函式；RF 為 20 餘支 C#。同名者僅引擎慣例（`_ready/_process` 對 Unity 生命週期）與通用詞，不構成程式複製證據。`get_debug_state` 等命名是 RS 內部一致性，不是跨作共用。
- **概念**：兩作同屬「裂隙」命名的動作生存：RS 為 2D 俯視小隊（隊長加活隊員、三陣封隙、羈絆、十戰場），RF 為 3D 單人（完美閃避反擊、鍛印、鍛造委託）。專案 `DIFFERENTIATION.md` 自評與同帳號暴風、灰燼、夜行列車在敵潮受眾重疊、4.3 風險高，此自評與本次觀察一致。概念近似是本次 4.3 的主要實質風險，解法在產品與證據，不在程式改名。
- **產線流程**：`_共用文件` 的 `HYBRID_ART_PIPELINE.md`、`VISUAL_REFRESH_PLAN.md` 為多款共用的美術治理、prompt 模板與 QA 閘門。此為流程共用，未證明出貨素材因此相同；但若多款以同一 prompt 模板與色票產圖，視覺近似的機率上升，審查回覆不應聲稱各作美術完全獨立產生，應改以各作最終出貨圖的雜湊與來源 manifest 說明。

---

## 三、iOS 打包層：native-kit 會放什麼進 Crackveil

### 3.1 Crackveil 實際走的路（Godot 專用，與 Capacitor 分開）

- 專案內：`tools/export_mobile.py --target ios` 以官方 Godot 4.7.2 匯出 Xcode 專案（`native/README.md`、`native/build-config.json`：Godot 4.7.2、build 3、Xcode 名 `CrackveilVanguard`）。
- NK 內：`ci_godot_ios_export.sh` 只服務兩款 Godot App（L14-17 白名單：Crackveil 與 Seven District），流程為來源雜湊驗證、模擬器建置、簽署匯出 IPA；`ci_verify_godot_ios.py` 強制兩款相同的不變量（47 個來源檔、build 1、PrivacyInfo 三類代碼、PCK 須為 GDPC）。
- NK 的 `apps/` 下 9 款為 Capacitor Web 包裝，**無 Crackveil 目錄**；`configure_app.mjs` 產生的 `MarsGameNative` host、白底（`#ffffff`）設定、`install_icons.mjs` 的白底 splash 與單圖產多尺寸、`configure_ios.mjs` 的 iOS 15.4 與 PrivacyInfo 連結，皆不進 Crackveil。此點基於目錄與腳本參照；已上架 IPA 未比對，商店端封裝無法確認。

### 3.2 進 Crackveil 且多款相同的打包內容

以舊匯出產物 `export/native/ios/` 與 `release/ios/source-verification.json`（47 檔逐檔 SHA）為證：

| 內容 | 相同層級 | 說明 |
|---|---|---|
| `libgodot.a`（約 189 MB）、MoltenVK、camera xcframework | Godot 引擎 | 同版 Godot 4.7.2 的任何 iOS App 皆同。第三方標準，可接受。 |
| `dummy.cpp/.h/.swift`、`Launch Screen.storyboard` 結構、`export_options.plist` 形式 | Godot 模板 | 模板預設；storyboard 背景色對應本作 `project.godot:17`，屬本作設定。 |
| `PrivacyInfo.xcprivacy` 三類 required-reason | Godot 模板＋CI 強制 | `ci_verify_godot_ios.py:23-27` 對兩款 Godot App 寫死相同代碼。可接受，不要為避比對更動。 |
| `CrackveilVanguard-Info.plist` 欄位 | Godot 模板 | 橫向、全螢幕、空的相機／相簿／麥克風描述字串等為模板預設；bundle id、版本為本作值。未用權限留空字串是模板痕跡，建議由匯出設定移除。 |
| AppIcon 多尺寸、splash@2x/@3x | 單圖產生 | 由本作 `icon_512x512.png` 產生，圖案為本作；產生方式與其他 Godot App 相同屬正常。splash 目前為純色加預設圖，第一印象與模板相同，建議換本作 key art。 |

### 3.3 版本不一致（送審前必須處理）

- `export_presets.cfg:157-158`：short_version 1.0.0、version（build）3。
- `native/build-config.json:8-9`：1.0.0／build 3。
- `ci_verify_godot_ios.py:105,132` 與 `release/ios/source-verification.json`：build 1。
- `export/native/ios-verification.json`：build 3 但 sourceVersion 為舊的 `0.27.0-r42`。

四處不一致代表「已驗證來源」與「目前要送的來源」不是同一包。是否導致 CI 實際失敗無法確認（未執行），但以舊 build 的驗證紀錄送新版 PCK，是審查與自家稽核都站不住的缺口。送審前以單一真源重產全部紀錄。

---

## 四、建議（原始碼層可執行，不含改名／混淆）

### P0 — 送審前先清掉正式版的 QA 程式

1. 刪除 `scripts/services/web_reachability_probe.gd` 與 9 處 UI 的 preload/publish；版面量測移到 Web 外部測試。
2. 刪除 `hud.gd` 的 `_publish_runtime_probe`、`world_map.gd` 的 probe 分支；`get_debug_state` 逐一改為正式狀態 API 或隨測試移除（`r36_minimap` 在用者保留並改正式命名與欄位）。
3. 四支 `scripts/arena/*_probe.gd` 移入 `scripts/debug` 或刪除，改以 `tools/` 無頭腳本重現。
4. 刪除 `scripts/services/qa_profile.gd`，五個 autoload 改回原存檔路徑；存檔故障注入移出 `meta_progress.gd`，改由測試替身。
5. 刪除 `mobile_tuning.gd` 的 `set_device_hints_override_for_tests`、`set_force_mobile_lod_for_tests` 與 override 分支；測試改用參數注入。
6. `exclude_filter` 四個 preset 補 `release/**,native/**,output/**,.playwright-cli/**,.github/**` 與 `web/*.html,web/*.js,web/*.mjs`（保留 `web/icons/**`）；匯出後以 savepack 清單驗證零命中再打包。

### P0 — 版本真源統一

7. 以 `export_presets.cfg` 為準統一 build 號，重產 `source-verification.json` 並讓 `ci_verify_godot_ios.py` 的期望值同步；不要以 build 1 的舊驗證紀錄送 build 3 的 PCK。

### P1 — 證明差異，而非宣稱差異

8. 對 Crackveil 與 Seven District 各做一次乾淨 iOS 匯出，產出 PCK 檔案清單與 SHA-256 差異表：除 Godot 引擎、Noto/OFL、Kenney CC0 等第三方外，自有檔案應零相同；此表附於 App Review 回覆。本次因該作原始碼不在範圍，此項目前無法確認，是回覆前最大的證據缺口。
9. 以送審 build 實機錄影：主選單第一分鐘、三陣封隙的隊員到位判定、羈絆觸發、一個完整戰場與 Boss。文件（`DIFFERENTIATION.md`）自評風險高且指出合併與否為產品待決事項；若同帳號敵潮生存款不止一款，認真評估合併為一款多模式或下架較弱者，比再送一款同類型更能回應 4.3 的「minor differences」指控。

### P2 — 降低模板第一印象（不更動引擎）

10. Launch storyboard 的 splash 換成本作 key art；Info.plist 未使用的相機／相簿／麥克風權限由 Godot 匯出設定移除，不要留空字串。
11. NK 文件明標 `unity-prepared/rift-forge-3d` 為 RF 本體副本、禁止作為獨立 App 送審；每款送審前以雜湊清單確認來源目錄唯一。

### 明確不建議

- 不改函式名、不加無用程式、不混淆字串來「騙比對」：對 Apple 的自動與人工審查都無效，且讓自家稽核失效。本報告所有建議皆為刪除 QA 程式、收斂測試面與補證據。

## 無法確認清單

1. `cv_r5_pause_layout` 是否曾存在於送審 build（目前原始碼命中 0）。
2. Crackveil 與 Seven District Reckoning 兩款 PCK 的實際相似度（該作原始碼不在範圍）。
3. 目前原始碼（0.35.0-content-r6）乾淨匯出後的最終 PCK 清單與已送審 IPA 的二進位相似度（未匯出、未取得 IPA；舊 PCK 為 2026-10-15）。
4. 編譯後 GDScript bytecode 與他作二進位的演算法相似度（本次僅檔案雜湊與字串層）。
5. `release/` 內 AAB/APK/ZIP 等未匯入檔案是否被打包（僅 `.json` 已證實）。
6. NK Capacitor 9 款已上架 IPA 的實際封裝是否與本地 `apps/` 一致（未連線商店、未取得 IPA）。
7. 同帳號其餘各款（12 款）與 Crackveil 的逐款比對（僅比對任務指定的三個對象；專案自有稽核文件提及的其餘各款結論為其自述，本次未獨立複驗，夜行列車在該文件亦標為 BLOCKED）。

## 附錄：方法與關鍵證據索引

- Preset：`rift-survivors/export_presets.cfg:139-171`；專案：`project.godot:9-17,21-26`。
- 舊匯出清單：`export/native/ios-export.log`（savepack 656 筆；探針 L183,457-462,535,626-630；漏包 L422-424；debug/docs/tools 零命中）。
- 舊來源驗證：`release/ios/source-verification.json`（47 檔、PCK SHA、圖示逐檔 SHA）；版本矛盾見 `export/native/ios-verification.json`。
- 打包腳本：`native-kit/ci_godot_ios_export.sh:14-17,241-252`、`ci_verify_godot_ios.py:20-27,102-138`、`configure_app.mjs`、`install_icons.mjs`、`host-entry.mjs`。
- 逐項結構化結果見同目錄 `findings.json`。
