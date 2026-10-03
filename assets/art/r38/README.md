# R38 original game art

The built-in ImageGen tool produced nine original actor sheets, three ground
materials and eight environment landmarks. Exact prompts and unmodified PNG
inputs are stored in `sources/`. The two spacing repair prompts and their
preceding source sheets remain beside the accepted versions.

Each actor has sixteen original poses: two idle, four articulated locomotion,
six attacks (anticipation, anticipation, impact, follow-through, recovery,
recovery), two hurt and two death. The impact is source pose 8, which becomes
attack frame 2 in the existing gameplay animation contract.

`tools/build_r38_content_atlas.py` performs RGBA connected-component extraction
and uniform resizing. It never draws or generates body poses. The extraction
retains every nonzero source-alpha pixel exactly once before downscaling; the
source and extracted alpha counts and sums are recorded in
`source_manifest.json`. A single scale per actor keeps pose playback from
changing apparent body size. Long weapons are included in their connected
silhouettes rather than clipped to nominal source grid cells.

The sixteen original images map to the legacy 27-frame playback interface:

```text
idle:   0, 0, 1, 1
walk:   2, 2, 3, 3, 4, 4, 5, 5
attack: 6, 7, 8, 9, 10, 11
hurt:   12, 13, 13
death:  14, 14, 14, 15, 15, 15
```

The external runtime atlas is `assets/sprites/r38_character_atlas.png`, using
128-pixel cells and sixteen columns. Its nine matching idle PNG icons provide
stable existing sprite paths. `TrueAnimationLibrary.EXTERNAL_CHARACTER_INDEX`
keeps these actors separate from the original seventeen-character atlas and
Captain combo extension.

Landmark atlas order (four columns, two rows): desert tomb, desert obelisk,
coral palace, coral lighthouse, moonflower tree, petal shrine, clockwork gate,
gear tower. Runtime ground files are `tile_desert.png`, `tile_coral.png` and
`tile_clockwork.png`.

The ground prompts request tileable materials. Opposite-edge RGB values are
not identical; measured mean errors are recorded in the manifest. This is
explicit source evidence, so a seamlessness claim must use actual wrap-view
inspection rather than the wording of the generation prompt.

## Verification

`R38ArtGate.tscn` checks all nine external actors, 144 unique original poses,
four distinct walk images and six distinct attack images per actor, source
alpha preservation, unmodified legacy registry/atlas identity and the actual
three hero animation events at frame 2. `TrueAnimationRegressionTest.tscn`
checks the original character animation, collision event and recovery routes.
Both passed using Godot 4.7 headless. Native rendered art, Web frame rate and
game balance require their separate integration/playtest lanes.

The original pose contact sheet is
`qa/original_pose_contact_sheet.png`. All nine source sheets and the packed
contact sheet were inspected for distinct limbs, weapon completeness,
consistent identity and visible hurt/death poses.
