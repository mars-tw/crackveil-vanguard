# Apple 4.3／4.2.6 回覆草稿（Crackveil Vanguard，R42）

> 草稿狀態：PREPARED，尚未送出。送出前需確認：
> 1. 第 4 題的外部 beta 回饋要換成**真實收到**的 TestFlight／Google 封閉測試回饋（目前 0 則，不能捏造）。
> 2. R42 已打包成新 iOS build，且 App Review Notes 與實機錄影都對應同一個 build。
> 3. 第 7、9 題對 AI 輔助工具的說明是照實陳述，送出前由開發者本人確認措辭。

---

Hello App Review team,

Thank you for the detailed feedback. Since the previous submission we made a substantial gameplay change (version 0.27.0-r42, described below). Here are our answers to each question.

**1. What the app does and the problem it solves**
Crackveil Vanguard is a single-player, offline action-strategy game in which the player commands a whole squad of 3 to 9 heroes rather than a single character. The core decision is not only where to move but how the squad is arranged. With one button the player switches between three formations in real time: Wedge Assault (heroes push ahead to the flanks: more damage, more damage taken), Guardian Ring (heroes surround the captain: less damage taken, less damage dealt) and Skirmish Spread (heroes fan out widely: larger pickup radius and faster movement). Switching has a cooldown, so the player has to read each wave, elite or boss pattern and pick the right formation at the right time. Which heroes you recruit determines which bonds are active, and each bond resonates with one formation (for example, Ember Pulse plus Wedge, or Star Shield plus Ring, which adds healing). The game gives players who like real-time action a short-session (10 to 15 minute) tactical squad-management experience that plays well on a phone held in either orientation.

**2. Intended users**
Players aged 12 and over who like short real-time action sessions with tactical decisions, especially mobile players who want a squad-tactics game that can be played one-handed in landscape or portrait, without accounts, ads or network access.

**3. Need or gap addressed**
Most auto-attack survival games on the App Store control a single character, and their depth comes only from picking upgrades. Crackveil Vanguard's moment-to-moment decision is squad formation: positioning, risk and reward trade-offs, and bond-formation synergies that change how the same roster plays. It also has a 10-stage world map with stage-specific elites and bosses, real frame-by-frame animation for 13 heroes, and equipment that changes squad stats. All content is original.

**4. Beta testing and feedback applied**
[待填：只能寫真實回饋。目前狀態如下，送出前更新]
Before this submission the game went through 41 documented internal playtest and revision rounds; each round's report is kept in the project repository. Examples of issues found and fixed in those rounds: the mobile joystick and skill buttons covered the battlefield (round 39: controls moved to the screen corners), character facing flipped during attacks (round 40), and mobile startup memory was too high (round 41). An external TestFlight group with a public link is now open, and an Android closed test is running in parallel. [送出前補上：外部測試人數、具體回饋例子、對應修改。]

**5. Standalone product or suite?**
Crackveil Vanguard is a standalone product. Our developer account also lists other games, but they are different genres built on different codebases: a children's driving/train/flight learning game (web technology), a farming RPG, a card battler, a tower-defense game, a real-time strategy game, a 3D third-person story game, and others. None of them is a squad-formation action game. We have also decided not to resubmit several of our other titles that overlap with apps already on our account.

**6. Could this be delivered inside another app on the account?**
No. No other app on the account shares its genre, engine project, controls or content. Its squad, formation, bond, hero and stage systems make up the whole product, and they would not fit as an add-on to any of our other apps.

**7. Shared code, frameworks or assets with other apps on the account**
The app is its own Godot 4.7 project. It shares no game code, scenes or art assets with our other apps. Shared standard third-party components only: the Godot Engine (MIT) and the Noto Sans CJK font (SIL OFL). Part of the code and some of the original 2D art were produced with AI-assisted tools under the developer's direction; the developer designed, reviewed, edited and integrated everything, and the source-image provenance is kept in the repository.

**8. Shared codebase, SDK or content library with third-party apps**
No. Apart from the open-source Godot Engine and the Noto font listed above, the app contains no third-party SDK, template, analytics or ads library.

**9. Built for a client, partner or third party?**
No. The app was conceived, built and published by the account holder as our own original product. It was not made from a commercial template or by an app-generation service for someone else.

---

## App Review Notes（英文，隨 build 附上）

What changed in 0.27.0-r42 (substantial gameplay change): a new real-time Squad Formation system. Tap the "陣形" button (above the slash button on iPhone) to cycle Wedge Assault → Guardian Ring → Skirmish Spread. Squad members visibly move to their new positions, and the formation changes damage dealt, damage taken, pickup radius and speed. Recruited hero pairs form bonds that resonate with a specific formation. Four heroes received passives tied to formations. A tutorial hint appears 6 seconds into the first battle.
How to review: Main menu → 開始出擊 (Start) → move with the bottom-left joystick → tap 陣形 to switch formation → level up and recruit heroes → defeat the stage boss. No account, purchase or network connection is required.
