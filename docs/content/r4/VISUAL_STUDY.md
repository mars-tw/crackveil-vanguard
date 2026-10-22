# R4 視覺研究與實作選擇

本輪只調既有素材與呈現層，不複製外部程式或資產。

Mindustry 的目標、選取與範圍標記先畫較深的粗邊，再畫細的識別色，並以角標／圓圈／虛線表達用途。R4 應用在唯一暖金隊長雙角標、冰藍職責符號與珊瑚敵招方向線，減少高亮填色遮住人物。[Drawf 原始碼](https://github.com/Anuken/Mindustry/blob/master/core/src/mindustry/graphics/Drawf.java)

Godot 容器會管理其子控制項位置；手動配置與容器最小尺寸混用會在 resize 後互相覆蓋。本輪把固定操作列與有限張資料卡分開，先測最短手機，避免長文把按鈕撐出畫面。[官方 Containers 文件](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html)

CanvasLayer 的層序獨立於一般節點 z_index。世界識別標記與模態介面分層，沿用專案 CSS／實體畫布換算，不能只以 Dummy 的幾何當 DPR3 畫面證據。[官方 CanvasLayer 文件](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html)

已實看既有 r36 地標圖集：月門、雙塔、祭壇與王座具有不同真輪廓。各攻勢採既有不同地標，不以換地板顏色或加標語代替。人物維持原始真逐幀與獨立物理根。
