# Asset provenance and direction

All texture maps, interface icons, geometry and shader source in this milestone
were created for The Eternal Library prototype. No third-party art pack, model,
font pack, music recording or plugin is bundled. Godot is installed separately
and has its own license.

The deterministic material generator creates 128-pixel material maps with
coherent mortar, grain, wear, geometric tilework and woven-pattern features.
Normal/roughness maps support the deliberately visible texel scale. Alpha
cards supply leaves, grass, fire and steam. Lighting is calculated in Godot;
the environment is not painted into a background image.

Architecture, cookware, books, plants and camping objects are generated from
original mesh-building routines. They are replaceable assets, with the current
layout authored in world coordinates. Upper stacks imply scale beyond the
small playable area. The architectural vocabulary is Iranian-inspired and
fictional, not an archaeological reconstruction.

The quiet ambient waveform was created for the original prototype from
original sustained tones. It can be muted in the settings menu. It is a
temporary atmosphere layer, not a finished soundscape or musical score.

The System Shock remake reference guides the broad combination of contemporary
lighting with deliberate retro texture density. No System Shock assets,
characters, interface graphics, logos, textures or source code are used.

Version 0.3 adds original 256-pixel stone, cave, moss, fruit, pomegranate,
copper, vine and cloth maps, plus ivy, fern, tree-leaf, lamp-window and dapple
cards. The optional `enrich_materials.py` generator creates these assets.
Continuous tubes form tree branches, ivy tendrils, stone ribs and bridge arches.
The library district and cavern are three-dimensional geometry, with instanced
window cards, emissive materials, dynamic lights and transparent waterfall
shaders. There are no downloaded models or art packs in the district.

Version 0.4 adds original granular pigment, mineral flecks, chipped patina,
normal and roughness maps, geometric mosaics, a dense shelf atlas, a collection
facade atlas with a separate lamp-emission mask, and three woven tree/bird wall
hangings. The atlases are procedural artwork, not baked screenshots. Nearby
shelves retain individual 3D books; distant surfaces use the atlases with 3D
columns, cornices, terraces, windows and bridges. The full generator order is
listed in README.md.

Version 0.5 adds original interior maps for sedimentary floor stone, limestone,
hearth stone, vault plaster, grout, soot-dark cookware, glazed ceramics, leather,
food, soft steam, dapple and feathered planting beds. Original mesh routines
produce clipped/chamfered stones, bent fronds, leaning books and spine bands,
turned balusters, the interior vault and its star-shaped glazed lantern.
The facade atlas assets are retained from v0.4; v0.6 rebuilds the vista layout, architecture, lighting and enclosure.
The source, meshes and material maps remain editable and replaceable.


## v0.6 exterior additions

`tools/generate_exterior.py` creates the original low-resolution faience and
stylised winged guardian relief with albedo, normal and roughness maps. These
are procedural artwork, not scans or copied concept imagery. All new exterior
geometry is built in `scripts/vista.gd`. The foundation art guides composition
and colour; no concept painting is placed behind the balcony.

Distant windows use local-axis scaling when rotated, preventing the side-facing
facade cards from becoming abnormally wide or thin. Exterior variants of gold,
dome and window materials do not change the interior material calibration.
Waterfall ribbons use the dedicated animated spatial shader. Local ellipsoid
fog volumes add spray and depth; the cavern roof is actual geometry.


## v0.7 compact gorge

The bank footprints, horizontal terrace extrusions, shared U-shaped arcade
frames, shelf insets, changing profiles and sanctuary rotunda are original
procedural meshes in `scripts/vista.gd`. The old library-facade atlas is retained
as a historical project asset but is not used to skin the new gorge banks.
They use actual masonry frames, existing book maps, glazed faience and stone.
The smaller enclosure follows a bent perimeter rather than a rectangle.
The Camrus box art is reference only and is not bundled as scene scenery.

`tools/gorge_shelves.py` fits the original book atlas into the pointed openings,
retaining normal and roughness maps. The inset artwork is alpha-masked and
mipmapped. A restrained warm material contribution approximates reflected
reading light in the shaded shelf recesses.


## v0.8 campfire benchmark

Original generated geometry: benchmark_pass.gd and revised world.gd,
asset_factory.gd and set_dressing.gd. New material source:
tools/benchmark_materials.py (NumPy and Pillow). Pixel-scale colour is designed
separately from normal/roughness maps. Geometry remains editable GDScript;
there are no externally licensed model packs or painted screenshot backdrops.

Run benchmark_materials.py last when rebuilding the older material generators.
The new pass deliberately overrides several shared stone maps. The exterior
layout is retained but shared stone and book materials also affect that area.


## v0.9 stones and organic garden

All new meshes are original procedural geometry in scripts/organic_pass.gd.
Flagstone surfaces have physical shoulders and hollows; fractured stones are
separate solids. Collision bridges narrow visual cracks. Rock beds use varied
ellipsoid rings with faceted normals and moss-tinted upper faces. The existing
material maps are reused. No new downloaded assets or image backdrops.


## v0.10 atmosphere, water and original music

New wind, water and cascade shaders and atmosphere.gd are original code.
The music, A Quiet Page, is an original synthesized composition generated by
compose_tar.py with fixed seed 101072. The included JSON score describes the
notes. No external recordings, song melodies or instrument samples are used.
Paired-string and skin-body timbre references:
https://www.metmuseum.org/art/collection/search/502242
https://www.britishmuseum.org/collection/object/W_Eu1972-01-16
The music is an approximation inspired by tar, not an authentic recorded
performance or a reproduction of a named gusheh. Playback asset is a looped
96-second stereo Ogg Vorbis stream at 44.1 kHz. The old hum asset is removed.
