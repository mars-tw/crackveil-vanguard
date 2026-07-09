# Crackveil Vanguard

Crackveil Vanguard 是一款原創 2D 俯視角割草生存 Roguelite 原型，使用 Godot 4.x 與 GDScript 製作。

目前專案聚焦在可玩 MVP：小隊英雄、資料驅動武器、敵人大量生成、升級三選一、手機觸控與 PC 鍵盤共存，以及針對大量敵人與投射物的 object pooling / 空間索引優化。

## 特色

- 1 名隊長 + 2 名隊友的小隊核心，可擴充到更多英雄。
- 4 種資料驅動武器：直線子彈、環繞刃、範圍爆炸、雷電鏈。
- 敵人持續從畫面外生成並追擊小隊，含普通、快速、坦克三種參數。
- 經驗、金幣、升級選項、暫停與結算 UI。
- 手機直式 HUD、左下虛擬搖桿、右上暫停按鈕。
- Object pooling、敵人空間索引、VFX cap 與玩法結算解耦。
- 所有 sprite 與 placeholder 皆為本專案原創素材，可自由替換。

## 如何執行

1. 安裝 Godot 4.x。
2. 用 Godot 編輯器開啟本資料夾的 `project.godot`。
3. 按 `F5` 執行主場景 `res://scenes/arena/Arena.tscn`。

Web 匯出方式：

1. 在 Godot 編輯器安裝 Web export templates。
2. 建立 Web export preset。
3. 匯出到 `export/` 或其他不入庫的資料夾。

## 操作

PC：

- `WASD` 或方向鍵：移動隊長。
- `P` 或 `Esc`：暫停 / 繼續。
- 滑鼠點擊：選擇升級卡、按暫停或結算按鈕。

手機 / 觸控：

- 左下虛擬搖桿：拖曳移動隊長，放開歸零。
- 右上暫停按鈕：暫停 / 繼續。
- 觸控點選升級卡與結算按鈕。

鍵盤與觸控輸入可同時存在；桌機預設不顯示虛擬搖桿，手機或觸控環境會顯示。

## 目前完成階段

- 第一階段：可玩 arena 核心迴圈。
- 第二階段：`WeaponData` Resource 化與 MVP 四武器。
- 第三階段：`HeroData` / 小隊跟隨 / 隊友各自攻擊。
- 第四階段：object pooling、pool contract、防 double-release、敵人空間索引。
- 第五階段：原創 sprite 套用、VFX cap、玩法與視覺 cap 解耦。
- 第六階段：手機控制、直式 UI 適配、開源前置文件。

## 已知限制

- 仍是原型，尚未做完整關卡節奏、商店、存檔、成就或音效。
- 武器與英雄資料已 Resource 化，但平衡數值仍是測試值。
- 手機已支援直式觸控操作，但尚未做正式多解析度裝置實機 QA。
- Web 匯出流程尚未固定 CI，自行匯出時需使用本機 Godot export templates。

## 專案結構

```text
assets/
  sprites/              原創 PNG sprite 與 atlas
docs/                   開發複審與對抗式審查文件
resources/
  heroes/               HeroData 資源
  squads/               SquadData 資源
  weapons/              WeaponData 與武器目錄資源
scenes/
  arena/                主遊戲場景
  debug/                smoke / contract / stress 測試場景
  enemies/              敵人場景
  heroes/               英雄場景
  pickups/              掉落物場景
  projectiles/          投射物與爆炸場景
  ui/                   HUD、升級、結算 UI
  vfx/                  傷害數字、死亡特效、雷弧
  weapons/              武器行為場景
scripts/
  arena/                arena 與背景
  autoload/             GameManager、EntityFactory
  debug/                自動驗證腳本
  enemies/              敵人與生成器
  heroes/               Hero、玩家控制、隊友 AI、小隊管理
  pickups/              XP / 金幣拾取
  pooling/              NodePool
  projectiles/          子彈、環繞刃、爆炸
  resources/            WeaponData、HeroData、SquadData
  services/             空間索引、sprite loader
  ui/                   HUD、虛擬搖桿、升級、結算
  vfx/                  視覺特效腳本
  weapons/              BaseWeapon 與四種武器行為
```

## 素材與版權

本專案名稱、程式碼、UI 文案、placeholder 與 `assets/sprites/` 圖像皆為專案原創內容。沒有使用第三方商標、商用遊戲素材或外部版權素材。

## License

MIT License. See [LICENSE](LICENSE).
