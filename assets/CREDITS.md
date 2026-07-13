# Asset credits and licenses

`Crackveil Vanguard` is distributed under the repository's MIT license. The
third-party assets below are compatible with that distribution; each source,
license, and in-game derivative is recorded here.

## Kenney Particle Pack 1.1

- Creator/distributor: Kenney Vleugels (Kenney.nl)
- Source: <https://kenney.nl/assets/particle-pack>
- License: Creative Commons Zero 1.0 Universal (CC0 1.0)
- License URL: <https://creativecommons.org/publicdomain/zero/1.0/>
- Upstream notice: "You may use these assets in personal and commercial
  projects. Credit (Kenney or www.kenney.nl) would be nice but is not
  mandatory."
- Changes: twelve transparent sprites were individually cropped, reduced to
  128x128, and color-graded into the rift-cyan and ember-orange palettes.
- Distributed derivatives: every PNG under `assets/vfx/kenney_particle/`.

Source-to-derivative record:

| Kenney source | Distributed derivative |
| --- | --- |
| `fire_01.png` | `burst_fire_ember.png` |
| `fire_02.png` | `burst_fire_cyan.png` |
| `spark_01.png` | `burst_arc_cyan.png` |
| `spark_02.png` | `burst_arc_ember.png` |
| `smoke_09.png` | `smoke_ring_cyan.png` |
| `smoke_10.png` | `smoke_ring_ember.png` |
| `flare_01.png` | `flare_cyan.png` |
| `star_08.png` | `flare_ember.png` |
| `muzzle_01.png` | `level_column_cyan.png` |
| `muzzle_05.png` | `level_column_ember.png` |
| `circle_03.png` | `shockwave_cyan.png` |
| `light_03.png` | `shockwave_ember.png` |

## Kenney audio packs

All files in this section were converted to 44.1kHz, 16-bit mono PCM WAV,
trimmed, faded at the boundaries, and peak-normalized. The AudioManager still
applies its existing player pool, per-cue cooldowns, volume, and pitch limits.

### Impact Sounds 1.0

- Source: <https://kenney.nl/assets/impact-sounds>
- License: CC0 1.0, <https://creativecommons.org/publicdomain/zero/1.0/>
- Upstream notice: "This content is free to use in personal, educational and
  commercial projects."
- `impactGeneric_light_002.ogg` -> `assets/audio/hit.wav`
- `impactPunch_heavy_002.ogg` -> `assets/audio/kill_thump.wav`

### Sci-Fi Sounds 1.0

- Source: <https://kenney.nl/assets/sci-fi-sounds>
- License: CC0 1.0, <https://creativecommons.org/publicdomain/zero/1.0/>
- Upstream notice: "This content is free to use in personal, educational and
  commercial projects."
- `explosionCrunch_000.ogg` -> `assets/audio/explosion.wav`
- `laserSmall_000.ogg` -> `assets/audio/fire.wav`

### Digital Audio

- Source: <https://kenney.nl/assets/digital-audio>
- License: CC0 1.0, <https://creativecommons.org/publicdomain/zero/1.0/>
- Upstream notice: "You may use these assets in personal and commercial
  projects."
- `highUp.ogg` -> `assets/audio/pickup.wav`
- `powerUp1.ogg` -> `assets/audio/upgrade.wav`

### UI Pack 2.0

- Source: <https://kenney.nl/assets/ui-pack>
- License: CC0 1.0, <https://creativecommons.org/publicdomain/zero/1.0/>
- Upstream notice: "This content is free to use in personal, educational and
  commercial projects."
- `tap-b.ogg` -> `assets/audio/ui_click.wav`
- The UI Pack's bright visual skins were evaluated but not distributed because
  they conflict with the game's dark rift interface; only its click sound is used.

## OpenGameArt CC0 animated enemies

All enemy sources in this section are released under Creative Commons Zero
1.0 Universal (CC0 1.0):
<https://creativecommons.org/publicdomain/zero/1.0/>. Attribution is not
required, but the authors, exact source pages, original filenames, hashes, and
distributed derivatives are retained here for provenance.

### Top Down Cultist Creature / Top Down Tentacle Creature

- Author: Sean Noonan
- Sources:
  - <https://opengameart.org/content/top-down-cultist-creature>
  - <https://opengameart.org/content/top-down-tentacle-creature>
- License shown on both source pages: CC0

| Upstream file (SHA-256) | Distributed derivatives |
| --- | --- |
| `roaming_cultist.png` (`88FA37A7AD7E2BCD085EECB29369DE420E3F62286C75A31EB3204E2BF72745C9`) | `enemy_grunt.png` and its generated idle/walk frames |
| `monster_flesh_eye_sheet.png` (`F74F0465E4B413CB1D45F64FA80E7F2F8B0BB5429F53DBC9E24B7DD1BC5BAAD5`) | `enemy_tank.png` and its generated idle/walk frames |
| `monster_flesh_teeth_sheet.png` (`0CB17ED4E2CC68397C50372CCF107AE84F0F65E04B4812E19CE7DB468FAC235B`) | `enemy_boss.png` and its generated idle/walk frames |

### Animated Walk-Cycle Monsters + Hijabi from Eman Quest

- Author: Night Blade
- Source: <https://opengameart.org/content/animated-walk-cycle-monsters-hijabi-from-eman-quest>
- License shown on source page: CC0

| Upstream file (SHA-256) | Distributed derivatives |
| --- | --- |
| `beetle2.png` (`E373EDB2186B96DD93288FA52E5506BD99608C39F33BCC880A1C3D5BCA2F94BA`) | `enemy_fast.png` and its generated idle/walk frames |
| `crystal_2.png` (`4CFB9F8ED288CEB476AA0122D68690C528BD3AD5D3AC50FBFD2B20153C0CCAE5`) | `enemy_elite_split.png` and its generated idle/walk frames |
| `mushroom_9.png` (`8D373D0A5A5CBF54F4CAACA1450BF424AF5A643B0BEDD88090976FAC70A56222`) | `enemy_elite_field.png` and its generated idle/walk frames |
| `crab2.png` (`6418DB574A4E5B5A304C6A1640AAE631AE51E9FDDE3F720E365F853C074E35E9`) | `enemy_elite_swift.png` and its generated idle/walk frames |

Changes to every distributed enemy derivative: selected real source animation
frames were alpha-cleaned, union-cropped, resized onto a transparent 96x96
canvas, luminance-graded to a neutral rift ramp, given a two-pixel dark-plum
outline, and palettized to at most 48 colors. Runtime `body_color` then applies
the existing threat tint: regular enemies remain in the dark red/ember family,
affix elites retain their green/cyan/orange glow coding, and the dedicated Boss
silhouette is enlarged with the existing violet volume glow. Rebuild with
`python tools/process_enemy_cc0_assets.py`; ignored originals remain under
`tools/asset_sources/` and are not included in the game package.

## Other project assets

- The Traditional Chinese UI font is a subset of Noto Sans CJK TC Regular,
  licensed under SIL Open Font License 1.1. See `assets/fonts/OFL.txt`.
- Wasteland-farm ground and decor cuts were adapted from the same author's MIT
  project `pixel-idle-farm-skill`; only the small, game-ready cuts are present.
- Hero character art was produced specifically for this project. Enemy art uses
  the compact CC0 derivatives documented above; unused candidate packs and raw
  archives are not distributed.
