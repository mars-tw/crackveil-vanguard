# R30 PLAYTEST-R1 修正前後證據

實作者：Codex（GPT-5）

## 證據邊界

- 修正前依據為 `docs/playtest/PLAYTEST_R1.md` 與其 `docs/playtest/shots/` 截圖；這兩個使用者提供目錄只讀，未修改、未加入本次 commit。
- 本輪不產生新 AI 圖；只修改程序化 UI、字型子集、Web shell 與自動化測試。
- 本地 Playwright 戰鬥截圖寫在被忽略的 `export/r30-844x390-combat.png`，SHA-256 `1e988ba52e8194848d6a4851e873a19f6231876462d96dad5d7ccafb13f4827e`。依任務約定，正式截圖由總稽核部署後補入，不提交本地截圖。

## R1-01：844×390 戰鬥 HUD

修正前：通用 mobile 字級放大到約 33 px，但 HP／等級／經驗仍共用過小的 26 px 垂直間距，造成互壓；經驗文字與 bar 難辨。

修正後：橫向矮視口使用 118 px 高獨立資訊板，將四個可視區塊固定分層，並將 Web/mobile 橫向字級上限設為 HP 24、等級 18、經驗 16。844×390 Playwright 實測座標如下（皆為 canvas 映射後 CSS px）：

| 區塊 | x | y | w | h | 下緣 |
| --- | ---: | ---: | ---: | ---: | ---: |
| HUD panel | 8 | 18 | 320.72 | 118 | 136 |
| HP | 52 | 22 | 128 | 35 | 57 |
| 等級 | 52 | 60 | 51 | 27 | 87 |
| 經驗文字 | 52 | 90 | 236.32 | 24 | 114 |
| 經驗 bar | 52 | 118 | 236.32 | 14 | 132 |

相鄰區塊至少保留 3 px，且全數位於 panel 內。Playwright 已進入實際戰鬥、等待 HUD 穩定後截圖並做矩形不重疊斷言。

## R1-02：方向切換後種子列

修正前：只依賴 viewport `size_changed`，瀏覽器 orientation/CSS canvas 更新有競態；回直向後 row 與子控制的 minimum size 沒有完整重置，右側按鈕被裁。

修正後：Web 同時監聽 `resize` 與 `orientationchange`，收到事件後等待兩個 frame 再重新計算；每次 layout 先清空 row/input/button 的 minimum size。390×844 → 844×390 → 390×844 後實測：

| 區塊 | x | y | w | h | 右緣 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 種子列 | 19.5 | 644 | 351 | 76 | 370.5 |
| 輸入框 | 19.5 | 644 | 187 | 76 | 206.5 |
| 開始按鈕 | 222.5 | 644 | 148 | 76 | 370.5 |

三者都在 390 px 視口內，且 row 寬度未殘留橫向值。

## R1-03：首次簡報遮罩

修正前：簡報 backdrop alpha 0.54、panel alpha 0.90，layer 45 雖高於契約 layer 25 與 HUD layer 10，仍會透出後方標題與 UI，形成雙影。

修正後：簡報建立全視口 `OpaqueBackdrop`，alpha 1.00、mouse filter STOP；panel alpha 提高至 0.96（高對比 0.98）。Godot gate 驗證 layer 45 與 backdrop alpha 1.00，後方契約／HUD 不會透出。

## R1-04：成就鎖定字元

修正前：成就 badge 與 meta unlock 文案使用 U+25A1 `□`，在既有 UI 子集環境被呈現為不可辨 tofu／替代方框。

修正後：改用 UI 字型確定涵蓋的繁中 U+9396 `鎖`，並以 `tools/build_font_subset.py` 重建 OTF/字元清單。重建結果涵蓋 758/758 專案漢字，OTF SHA-256 `7c78541eb68cd6218c28e46434406bda7d07e800a6290fa02aa186009f10d96b`；Godot gate 斷言 badge 不再含 `□` 且顯示 `鎖`。

## R1-05：離線 reload fallback

修正前：Godot export 的 SW registration 受 cross-origin isolation 設定限制而未註冊；已載入後離線 reload 直接白頁。舊離線頁文字也可能讓人誤以為完整遊戲可離線。

修正後：finalizer 在 Web shell 注入唯一、顯式的 `rift-r30-offline-fallback` registration，沿用 Godot worker 對 navigation fetch 的 `index.offline.html` fallback。離線頁明確寫明約 40 MB Web 版不提供完整離線遊玩，只提供輕量「需要連線」提示；WASM/PCK 不在 install pre-cache 清單。Playwright 等到 SW `activated` 後切成 offline 並 reload，取得標題「裂隙需要連線」。

## 驗證摘要

- Godot 4.7 headless import：連續兩次 exit 0。
- Godot scene gates：10/10 通過，含 R14RegressionTest、R29MenuModalTest、R30PlaytestFixTest 與既有 animation/pool/gameplay/smoke/art/parallax gates。
- Web：R25 performance gate 通過（Fast3G/4× focal 395.9 ms，預算 3000 ms；TTI delta -48.05%）、R22 controls 8 種 viewport 完成、R30 Playwright 通過。
- 程序化美術靜態 gates：sprite luminance、C2PA、R25 parallax、R24 art 全通過；C2PA 工具造成的歷史 JSON 欄位重排已精確還原，歷史 evidence 零 diff。
