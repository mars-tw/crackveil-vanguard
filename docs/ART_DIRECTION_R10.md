# Crackveil Vanguard R10 Art Direction

## Core Look

R10 moves the game from a black grid arena into a cracked interdimensional void. The screen should read as deep blue-violet space first, then cyan and violet rift energy, then ember-orange danger accents. The game is still a dense survival action game, so every effect is subordinate to combat readability.

## Color System

- Void base: `#050914`, `#0A1024`, `#15102D`
- Rift cyan: `#4FEAFF`, `#7DF7FF`
- Rift violet: `#9D6CFF`, `#C184FF`
- Ember danger: `#FF7A3D`, `#FFB84D`
- Enemy body: desaturated crimson and magenta so enemies stay hostile without matching loot.
- Elite/Boss accents: ring and marker colors must differ by shape as well as hue.
- UI panel base: blue-black translucent surfaces with cyan borders and violet focus light.

## Shape Language

- Rift world: broken diagonals, branching cracks, thin energy filaments, soft radial haze.
- Heroes: clean compact silhouettes, pale cyan aura, stable circular shadow.
- Enemies: heavier, warmer silhouettes with smaller aura; elites use explicit geometric markers.
- Loot: jewel/coin silhouettes with tiny halo and bobbing motion; no pickup should compete with elite markers.
- UI: 8 px radius or less, crisp cyan stroke, dense layout, no oversized marketing cards.

## Light Rules

Only high-information objects glow:

- Rift cracks and major background energy seams.
- Player squad aura and weapon projectiles.
- XP gems, gold coins, and temporary reward flashes.
- Elite/Boss rings, markers, kill bursts, and active hazard telegraphs.

Glow is implemented with shared additive sprites because the web compatibility renderer does not provide reliable 2D environment glow. Normal enemies get a restrained low-alpha glow; elites and bosses get larger rings and higher alpha. Background glow must never exceed combat foreground contrast.

## Readability Iron Laws

Contrast priority is:

1. Player squad and incoming danger
2. Enemies by threat tier
3. Projectiles and hit feedback
4. Pickups
5. Background

Rules:

- Every character and pickup has a ground shadow so it does not float into the background.
- Enemy threat is encoded by size, color, glow radius, and shape marker, not color alone.
- Projectile trails are capped by projectile pool count and kept short; enemy bullets remain ember-orange so they are not confused with player cyan shots.
- Particles are pooled or attached to pooled nodes. No per-hit free-floating allocations.
- At 150 enemies, normal enemy glow must be weaker than elite/Boss rings, and pickup halos must stay below enemy opacity.
- The vignette darkens corners only; it must not cover HUD or hide edge threats.

## UI Style

- Panels: deep translucent blue-black fill, 8 px radius, 1-2 px rift-cyan border, subtle shadow.
- Buttons/cards: same base surface, cyan normal border, brighter cyan hover/focus, violet pressed fill.
- Evolution/rare emphasis: ember border with warm text, but no full orange screen wash.
- HUD: compact backed strip, icon-led values, XP bar with dark trough and cyan fill.
- Font sizes: HUD 14-24, modal titles 28-34, cards 18-20, dense settings text 14-16.
- Text color: off-white main, pale cyan titles, muted blue-gray secondary. Disabled text is gray-blue, not pure gray.

## Performance Budget

- Reuse the same glow, particle, shadow, and UI textures with tint changes.
- Background is layered but coarse: texture draws and a capped dust particle node, not thousands of entities.
- Death bursts use the existing pooled `death_burst` nodes.
- Projectile trails are children of pooled projectile nodes and disappear on pool release.
- StressTest must remain green, with avg/p95 checked against the R9 baseline before sign-off.
