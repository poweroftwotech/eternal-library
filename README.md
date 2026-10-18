# The Eternal Library — Reading Garden v0.11

> **Art direction work starts in [ART_DIRECTION.md](ART_DIRECTION.md).** v0.11 adds pixel-art
> materials at 32 texels/m (`tools/pixel_materials.py`), a lighting/grade pass
> (`scripts/art_direction.gd`), a concept-matched capture mode and a comparison tool.

A playable first-person exploration and cooking prototype. This version focuses
on the campfire view into the Reading Garden, using the concept image as an art
direction reference. All previews are actual Godot Forward+ viewport captures.

## Living atmosphere and music in v0.10

- The hearth light changes position, colour and energy with a bounded, layered
  flicker. The nearby reflected contribution follows it, and both cast shadows.
- Lantern light varies subtly inside each globe. Garden daylight drifts gently.
- Tree, ivy and fern vertices bend in a breeze; their actual shadow geometry
  bends too. Wind, light and ripples share a deterministic atmosphere clock.
- Channel water is now a non-metallic, translucent film over a visible bed and
  small stones. Fine moving normals replace the large opaque reflective blobs.
- The small cascade is a quieter transparent sheet instead of bright stripes.
- The old hum is replaced by `A Quiet Page`, an original 96-second synthesized
  tar-inspired piece: paired strings, plectrum transients, modal melodic
  phrases, neutral-second inflections and gentle ornaments. It is not a sampled
  tar performance or a transcription of a classical radif piece.
- Controls & settings → Music toggles the new loop.

`previews/atmosphere_v010.mp4` contains actual engine frames at 12 fps, with a
campfire view followed by a water close-up. The software-rendered preview is
not a GPU performance benchmark. Individual frames are also included.

## Previous uneven paving and planted garden pass in v0.9

This pass replaces the camp paving with individually built flagstones. Their
outlines, chipped shoulders, shallow hollows, tilt and colour vary; selected
stones are two separate solids with a narrow irregular fracture. Continuous
convex collision surfaces span the small fractures so the character can walk
across them. Garden paths and water margins use the same stone construction.

Rock beds now have irregular rounded forms with moss-tinted upper faces.
Ferns, shrubs and roots gather around these outcrops. Scattered rubble and
isolated fern placement have been removed. The tree crown is taller and less
uniform, book heights and leaning/stacking vary more, and trailing ivy breaks
up the rear gallery. A close-up capture mode, `paving`, shows the new geometry.

This is another step toward the concept. Major room proportions and many
procedural assets are retained; the prototype does not yet match every aspect
of the concept's density, natural forms or material quality.

The previous v0.9 paving treatment remains in this build.

## Previous campfire benchmark in v0.8

- A wider arrival view includes the provision table, hearth, rug and both arches.
- Focused warm daylight and local garden mist contrast with firelight and a cool archive.
- Thick clipped paving has deeper joints, worn edges and coarse mineral colour variation.
- Entrance arches have separate face stones; piers have projecting worn courses.
- New original PBR maps distinguish stone, iron, patterned ceramics and woven textiles.
- Lanterns have shaped bases and caps, glass globes, guard rails and hanging loops.
- The cooking pot has a physical rolled rim and rivets; charcoal, sparks and steam enrich the hearth.
- Book bindings have raised bands, cover lips and gilt cartouches.
- The tree has a curved trunk and more articulated branches; plants gather along margins.
- A local reflection probe adds surroundings to reflective surfaces; water ripples are subtler.

The look remains a work in progress. In particular, shelves and vegetation still
show procedural repetition, and the garden is flatter and less organically
layered than the concept. This is the first benchmark pass, not a claim of an
exact concept match. No AI-generated image is used as a scene backdrop.

The v0.8 preview images are superseded by this build's v0.9 captures.
Older exterior images are retained as references and are named accordingly.
`tools/benchmark_materials.py` regenerates the new original material maps;
Python is required only to regenerate assets, not to open or play the game.

## The exterior in v0.7

Eight overlapping library banks replace the separate tall rectangular towers.
Every short tier changes its footprint, width, depth, orientation and position.
Broad projecting ledges alternate with setbacks, creating faceted cliff faces
and connected collections. No bank uses an uninterrupted tall facade shaft.
The district is roughly half the previous width and depth; its smaller gorge
brings the bridges, terraces, reading galleries and waterfall landings closer.

Book arcades have actual stone arch frames and inset book shelves rather than
relying on the old repeating building-facade texture. Narrow galleries carry
rails, lamps, banners, red pavilions and static robed scale figures. Six bridges
cross at different depths and heights. Their landings are faceted platforms.
Four animated cascades descend through the gorge into local spray mist. A wide
terraced sanctuary with a domed rotunda closes the view at the rear.

The bent, book-lined enclosure and continuous rock ceiling are also smaller.
Rock pendants and low overhangs sit above the buildings. Local amber pools,
cool mineral-vault fill, cast shadows, SSAO and fog support their depth.

The interior art pass, reachable balcony, physical guards and complete
exploration → gathering → cooking → eating loop are preserved.

## Open and play

1. Install the standard Godot 4.6.1 editor.
2. Extract the complete ZIP into a writable folder.
3. Import `project.godot`, allow the textures to import, then press **F5**.

This is editable source. The included assets need no downloads, plugins,
account, API key or Python installation to play. Forward+ requires a suitable
Vulkan, Direct3D 12 or Metal graphics device. Performance on your computer has
not been benchmarked. Compatibility mode removes some of the visual effects.

## Controls

| Input | Action |
|---|---|
| WASD / arrows | Walk |
| Mouse | Look |
| E | Gather, use the pot, examine the overlook |
| Shift | Run |
| Space | Jump |
| J | Field notes and route hints |
| Escape | Menu / close panel |
| Mouse or 1–9 | Choose a menu or cooking option |
| F11 | Fullscreen |

The menu includes sensitivity, inverted look, music and a confirmed
restart. The lower icons show mushrooms, roots and herbs in your inventory.

## Things to try

- Inspect the cookware, provisions, woven cloth, pottery, fruit and books.
- Follow the irrigation channel to the reading garden and cool damp archive.
- Climb the stair east of the tree. The lit arch behind the upper gallery leads
  through a vaulted passage to the guarded balcony.
- Look along the compact gorge, then down through the bridges and up toward
  the enclosed roof. Walk along the balcony to see overlapping ledges.
- Gather amberroot near water, hearthleaf in the garden and mushrooms in the
  archive. Approach a patch and look down until the E prompt appears.
- One root plus one herb makes broth; one mushroom makes a roast. Eat a meal
  to restore nourishment and warmth.

Two patches of each ingredient permit several preparations. Harvested patches
stay depleted until the outing restarts. Decorative provisions are set dressing.
Cooking is menu-based. The distant district and tiny figures remain scenery.

## Visual direction

Original low-resolution textures use noise, normal-map relief and roughness
variation, with mipmaps for distant surfaces. Stone arches, tier caps, faceted
bank walls, bridge spandrels and dome ribs are actual meshes. Books and arcade
frames use shared instance batches. A separate exterior light layer preserves
the camp/garden lighting; mesh merging retains those light layers.

The architectural direction is fictional and Persian-inspired. The Camrus box
art guides the compact chasm composition, dense inhabitation, warm/cool colour
and projecting terraces. No concept painting is used as a scene background.
The original v0.5 warm camp, garden vault and lightwell, cool archive, fitted
stonework, cookware, fruit, books, ivy and planting details remain in place.

## Editing

| File | Responsibility |
|---|---|
| `scripts/vista.gd` | Compact gorge, changing tier footprints, book arcades, sanctuary, bridges, enclosure, balcony |
| `scripts/atmosphere.gd` | Animated lights, wind materials, ripples and streambed |
| `scripts/organic_pass.gd` | v0.9 sculpted paving, fractures, rock forms, clustered planting and trailing ivy |
| `scripts/benchmark_pass.gd` | v0.8 local lighting, masonry, camp details, reflection and planting |
| `scripts/world.gd` | Interior layout, lighting, camp, stairs and gatherables |
| `scripts/interior_pass.gd` | Interior vault, lightwell, mouldings and planted joints |
| `scripts/library_dressing.gd` | Full-height interior collections and art |
| `scripts/set_dressing.gd` | Tree, plants, stones, roof detail and provisions |
| `scripts/asset_factory.gd` | Geometry, materials, merging and instancing |
| `scripts/main.gd` | Inventory, recipes, eating, menus and discovery |
| `scripts/player.gd` | Walking, camera, collision and interaction ray |
| `scripts/hud.gd` | HUD and cooking/notes panels |
| `assets/textures/` | Included original material maps and alpha cards |
| `shaders/` | Irrigation water, waterfall and atmospheric effects |
| `tests/` | Gameplay, geometry and actual viewport captures |
| `tools/` | Optional original texture generators |

The scene builds at startup. Inspect Godot's Remote scene tree while running.
The layout lives in the builder scripts. Static meshes merge by material and
light layer. Dynamic and harvestable geometry remains separate.

## Checks and captures

```sh
godot --headless --editor --import --quit
godot --headless --script res://tests/geometry_audit.gd
godot --headless --script res://tests/playtest.gd
```

Visual capture requires a graphics display:

```sh
godot --script res://tests/capture.gd -- /absolute/path/balcony.png balcony
```

Modes include `paving`, `camp`, `garden`, `archive`, `gallery`, `cooking`, `balcony`,
`vista_depth`, `vista_roof`, `ceiling` and `detail`. The lower-terrace capture
uses an elevated review position at approximately jump height. All images in
`previews/` are actual Godot viewport captures. Exterior reference views from v0.7 have
`_v07_reference` in their names. See `VALIDATION.txt` for evidence.

Music regeneration uses `tools/compose_tar.py` (Python, NumPy, SciPy), then FFmpeg to convert the WAV to Ogg Vorbis. The generator and original score are included.

Optional texture regeneration requires Python, Pillow and NumPy. Run, in order:
`build_materials.py`, `enrich_materials.py`, `detail_materials.py`,
`patina_materials.py`, `interior_materials.py`, `generate_exterior.py`, then
`gorge_shelves.py`, then `benchmark_materials.py`.
All resulting PNG maps are included for ordinary play.
