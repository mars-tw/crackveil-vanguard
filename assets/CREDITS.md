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

## Other project assets

- The Traditional Chinese UI font is a subset of Noto Sans CJK TC Regular,
  licensed under SIL Open Font License 1.1. See `assets/fonts/OFL.txt`.
- Wasteland-farm ground and decor cuts were adapted from the same author's MIT
  project `pixel-idle-farm-skill`; only the small, game-ready cuts are present.
- Hero and enemy character art was produced specifically for this project and
  is not replaced by the stylistically different Kenney character packs.
