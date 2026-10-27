# R8 交付：MUSE 原創向量美術與大型陣形徽章

版本 **0.37.0-content-r8**，基準 `c8db615`（R7，獨立 Claude 7.9／嚴重 0）。圖片由 MUSE（Meta muse-code CLI）產生原創 SVG，Claude Code 接線與驗收。只在本機提交，沒有送審或修改商店。

使用者指示：「讓 MUSE CLI 做圖片，我不要點陣圖」。本輪新增美術全部是純向量 SVG（不嵌點陣圖、不含文字、無濾鏡與外部連結），取代專案預設的 gpt-image-2 點陣產線；`assets/ui/r8_vector/MANIFEST.json` 記明產生工具。

## 玩家可見的變化

| 面向 | 已落地 | 玩家看得到的地方 |
|---|---|---|
| 向量框飾 | 「裂開的古石＋金色封印＋青色符文」九宮格框：大面板（整備、結算、升級面板）、卡片（升級卡）、按鈕（主選單按鈕、戰鬥通知框）。中央透明，疊在原底色上，點擊與版面不變；取代 R7 程式線稿 | 01、03、12、13、14、20 |
| 大型陣形徽章 | 危險區徽章改為 64px 向量圖示（楔形三箭、圓陣四盾環、散兵三點連線），字級 16→20；接受兩種陣形時並排兩個徽章；目前陣形不對時，徽章外套紅色斷續外環並脈動 | 04、05、06、08、16 |
| 封隙與指標 | 封隙中央、畫面外指標改用同一套徽章；封合成功改用向量封印徽記擴散 | 18、19、21 |

不改任何戰鬥數值。

## 素材

`assets/ui/r8_vector/`：`panel_frame.svg`（192，九宮格邊距 48）、`card_frame.svg`（96，24）、`button_frame.svg`（64，16）、`seal_emblem.svg`、`badge_wedge.svg`、`badge_ring.svg`、`badge_scatter.svg`、`badge_wrong_ring.svg`，每檔 0.7～5.5 KB。MUSE 只寫入該資料夾，未改其他檔案（已核對）。

## 實際驗證

- **完整原生 CI 54／54**（47 場景＋3 Node＋R5～R8 單元）；`verify_content_r8.py ci` 1700 checks／0 failures。
- **R8 單元 35／35**：8 張 SVG 皆無 image／base64／text／外部連結／filter／CSS 且 ≤12 KB；三種框各用對應九宮格與邊距、中央不填、不吃點擊；危險區徽章與錯陣外環載入、尺寸 ≥56px；封印與指標使用向量徽記。R5 18、R6 25、R7 18 仍綠。
- **Web 真輸入**：整備、8 組視口×字級、暫停 3×3、突擊與護送自然通關、第四敗與第五局全部通過。
- 來源清單 661 檔，SHA-256 `05dfc33b6a910ceb442d699060dd95d867d81d06a044e2738c8804e617ebedf7`；release PCK `920559d93a76a468508243ecc3e5d478201503ad96b9cb90c48098cf754a6cee`；review PCK `cc93254a3e32518e0facdbfee53d195be91d9bdc58a91dc986cddbc97165c11f`。
- 15 張審查圖逐張實看。

## 15 張審查圖

| 檔名 | 內容 |
|---|---|
| 01-crew-overview-max-portrait | 320×568 最大字級整備：MUSE 向量面板框，收益／代價完整 |
| 03-specialization-short-desktop | 1366×600 整備：向量面板框＋選後站位圖 |
| 04-assault-front-active | 正面攻勢：危險區 64px 楔形向量徽章＋「需楔形」 |
| 05-escort-front-active | 護送正面：兩個徽章並排「可用楔形／圓陣」 |
| 06-assault-pincer-active | 包抄：兩側圓陣徽章，封隙中央徽章 |
| 08-assault-artillery-active | 遠射：散兵徽章 |
| 12-assault-victory | 突擊通關支援頁：向量面板框、卡片頭像 |
| 13-escort-victory | 直式護送通關 |
| 14-fourth-real-defeat-fixture | 第四敗受控結算：向量面板框（與通關同一套藍金框，失敗只在底色邊線改紅）、輸出長條 |
| 16-pincer-wrong-badges | 錯陣時徽章紅環＋提示一致 |
| 17-switch-burst-ring | 換陣瞬間 |
| 18-ring-protect-correct | 對陣結果 |
| 19-seal-success-emblem | 封合成功用向量封印 |
| 20-levelup-vector-cards | 升級畫面向量框 |
| 21-equipment-and-seal-badge | 裝備說明＋封隙徽章 |

## 已知限制

- 主選單與 HUD 其餘元件（血條、任務列、技能按鈕）仍是原本的扁平樣式，未全面換框。
- 1366×600 時左側「第 N 道」地面標籤偶爾壓到陣形按鈕區（R7 評審輕微項，未處理）。
- 乾淨機況 p95、實體裝置、真人試玩：**BLOCKED**。GPT 評審待 Codex 用量恢復（2026-11-02 14:07）。
- Apple 重送前的二進位讀回、七期 PCK 比對、TestFlight 回饋與使用者同意仍未完成。

## 獨立評審結果

獨立 Claude 評審：**7.9／10，嚴重問題 0**（全文 [`CONTENT_REVIEW_R8_CLAUDE.md`](content/CONTENT_REVIEW_R8_CLAUDE.md)）。分項：戰鬥手感 7.6、陣形決策 8.2、成長節奏 7.6、介面與手機 7.7、美術一致性 7.6。4.3 判斷：大概率不會被當成換皮，送審第一張截圖要避免只放滿屏怪物。輕微問題 8 條（框角壓到面板標題首字、徽章說明字被危險框線劃過、升級卡斷行、地面標籤壓到陣形按鈕、任務列與通知重複、已換陣後封隙紅叉殘留、單人頁長條等長、封隙徽章顯示所需陣形易被誤讀為目前陣形）列為下一輪項目。GPT 評審待補；雙模型平均 ≥9 尚未達成。
