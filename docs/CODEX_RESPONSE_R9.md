# Codex Response R9 Week A

對照：`docs/GROK_REVIEW_R8.md` §5 與 §5.5 Week A。  
範圍：只做本輪指定的 P0/P1 發布品質項與技術債 #2；未做 R9-1.2 hit-stop、R9-1.4 Meta 入口完整化與 Week B 項。

## 七項實作

1. **R9-0.1 首局引導（P0）**
   - 新增首局半透明引導層：移動 WASD/方向鍵/左下搖桿、武器自動攻擊、吃藍色寶石後三選一升級。
   - 「不再顯示」寫入 `user://crackveil_guide.cfg`。
   - 契約畫面新增說明：「選一條本局規則——它會改變這一局的玩法」。

2. **R9-0.2 死亡回饋閉環（P0）**
   - GameOver 改為存活評價、擊殺/精英/Boss 階段摘要、契約、本局殘響去向提示。
   - 殘響提示會依目前碎片與下一個 Meta 軌成本顯示「下局開局可購買」或「累積到 N 可購買」。
   - 主按鈕改為較大的「再來一局」。

3. **R9-0.3 升級池耗盡軟鎖保底（P0）**
   - 空升級池改給 3 張通用保底卡：
     - 緊急整補：全隊回復 18 HP。
     - 裂隙拾荒：立刻 +8 金幣。
     - 短路超載：全隊傷害 +15%，持續 12 秒。
   - 保底卡不會觸發隨機商店，選完必定解除 upgrade pause。
   - R7RegressionTest 新增 `R9_UPGRADE_FALLBACK choices=3 gold_delta=8`。

4. **R9-0.4 版本顯示（P0）**
   - `project.godot` 新增 `config/version="0.9.0-r9-week-a"` 與 `config/build_date="2026-07-10"`。
   - HUD 右下角顯示 `v0.9.0-r9-week-a  2026-07-10`。
   - CI `deploy-web.yml` 在匯出前注入當日 `config/build_date`。

5. **R9-1.1 六槽音效佔位（P1）**
   - 新增 `tools/generate_placeholder_audio.py`，用程式合成 6 個短 WAV，無外部素材。
   - 新增 `AudioManager` autoload，使用 12 個 `AudioStreamPlayer` 池化播放。
   - 六槽：開火、命中、升級、契約/Meta 購買、精英出現、玩家死亡。
   - 開火全域節流 70 ms；命中節流 45 ms；精英/死亡也有冷卻。
   - Web 首次手勢：HUD 顯示「點擊開始」，`AudioManager` 首次 key/mouse/touch/joypad 事件解鎖。
   - 暫停面板新增音量與靜音，設定存 `user://crackveil_audio.cfg`。

6. **R9-1.3 詞綴/進化可讀性（P1）**
   - 每局首次遭遇各 affix 顯示 1.5 秒 toast：
     - 裂殖精英——死亡時分裂！
     - 力場精英——靠近會緩速！
     - 迅捷精英——高速衝刺突入！
   - 進化卡新增【武器進化】標記與金色強調卡面。

7. **技術債 #2（P1）**
   - GameManager 避免在商店/契約/勝利期間開升級 modal；累積 XP 會在 modal 關閉後再消化。
   - StageVictory/GameOver 顯示前由 Arena wrapper 清掉其他 modal。
   - R7RegressionTest 新增商店→升級→勝利→死亡 UI/owner 回歸：
     - `R9_MODAL_OWNER_CLEANUP owners=["game_over"] gameover_visible=true`。

## 音效合成與大小

合成策略：22,050 Hz、mono、16-bit PCM WAV；fire 用方波/正弦短 transient，hit 用噪音+低頻，upgrade/contract 用上行和聲，elite/death 用低頻+噪音 envelope。

檔案大小：

| 檔案 | bytes |
|---|---:|
| `fire.wav` | 3,350 |
| `hit.wav` | 2,468 |
| `upgrade.wav` | 9,746 |
| `contract.wav` | 10,628 |
| `elite.wav` | 15,038 |
| `death.wav` | 18,566 |
| **合計** | **59,796** |

## 驗證

- Headless 載入：`--headless --path . --quit`，無 `ERROR:` / `SCRIPT ERROR`。
- 字型子集：Project Han coverage `412/412`，輸出字型 `1,499,292 bytes`。
- Debug 矩陣：R5/R6/R7Regression、PoolContract、GameplayCap、MobileInput、WeaponSmoke、SquadSmoke、Stress、BalanceMock 全 PASS，無 `ERROR:` / `SCRIPT ERROR`。
- Stress：`enemy_group_scans=0`，`STRESS_PASS`；仍有既有 `STRESS_PERF_BELOW_60=true`。
- Web 匯出：`--export-release "Web" "export/web/index.html"` 無錯。
- 最終 Web `index.pck`：`3,102,532 bytes`。

## 與 R8 清單差異

- 已完成 Week A 指定：首局引導、死亡閉環、空升級池保底、六槽音效、版本/build 顯示、affix toast、進化卡強調。
- R9-2.3 只做音量/靜音最小版，未做傷害字、螢幕震動、重置 Meta。
- R9-1.2 hit-stop/螢幕震、R9-1.4 暫停 Meta 三軌入口、Week B 成就/種子/Press kit/實機三機型未納入本輪。
- 未放寬任何 cap，未新增 group 掃描，未改 Meta 幅度政策。
