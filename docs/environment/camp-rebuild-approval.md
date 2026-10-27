# Approval brief: the camp, rebuilt from kit pieces

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-26 with the recommended answers** (phase 7) ·
Measurements: `tests/camp_frame_capture.gd`, `previews/camp_rebuild/`

This page is what you're approving. It says why the camp needs rebuilding,
what it costs today, the steps it would be built in, what you can try after
each one, and the choices that need your answer. Nothing has been built yet.

## What this adds, in one paragraph

The camp (the Reading Garden where the game starts: the fire and cooking pot,
the tree through the archive, the garden, the stair to the gallery and the
balcony) is built entirely in code at start-up: about 4,600 lines across 17
scripts make every stone, plant and book one by one. You like its look; it's
slow and it can't be edited. This rebuilds it **from kit pieces**, the way the
gorge was in phase 6 step 1: the same look, made of pieces you can open in
Blender and a baked scene you can open and change in Godot, with the
gameplay (cooking, eating, foraging, field notes, the satchel) moved onto it
unchanged. It also gives the camp its door to the gorge, which was phase 6
step 6.

## What the camp costs today

Measured on this machine (RTX 5090) at the Medium preset, 1080p, the camp by
itself (the gorge view switched off), turning on the spot at six places: the
box-art spawn, the hearth, the archive, the garden, the gallery and the
balcony. The limits are the frame gate's, the same the library's areas pass.

| | The camp today | Limit |
|---|---|---|
| GPU time per frame | 4.35 ms mean, 7.65 ms worst | 3 ms mean, 4 ms worst |
| Frame time (CPU) | 5.04 ms mean (8.3 ms worst once settled) | 4 ms mean, 8 ms worst |
| Draw calls | up to 2,042 | 1,500 |
| Triangles drawn per frame | up to 35.7 million | 3 million |
| Lights casting shadows | 8 | 4 |
| Lights within 35 m | 31 | 50 |
| Building it at start-up | 3.0 s | |

**Where it goes:** the scene itself holds only about 1 million triangles
(0.62 M in merged stone, 0.4 M in 30,000 instanced book parts, leaves and
ferns). It's drawn 35 times over because **seven of the eight shadowed
lights are point lights**, and each redraws everything near it for up to
six shadow views every frame. That's the GPU time, and the shadow views
multiply the draw calls too (the scene has 55 merged stone blocks, 22
instanced sets and a few hundred small separate pieces, each drawn again in
every shadow view it falls in). The 3 s start-up is the code making all of
it.

(The camp's own old gorge view, still built by `vista.gd`, roughly doubles
all of this: 7.3 ms GPU, 3,750 draw calls. Not part of this rebuild; see Q2.)

## What stays

Everything you see and use, as kit versions where the code made them:

- **The look:** the pointed arches and mosaic pier, the paving, the tree
  through the archive, ivy on the arch heads, the rug, bedroll and pack, the
  bookcases, ladders and book stacks, the lanterns, the turquoise planter,
  the warm light hierarchy and haze (`ART_DIRECTION.md`, the box-art framing
  of `Campfire in the Eternal Library.png`).
- **The living parts:** the **glowing mushrooms**, the **water** in the old
  irrigation channel (its shader and ripples), the fire, its sparks and
  smoke, the drifting leaves, plants in their beds and paving joints.
- **The gameplay:** the cooking pot and recipes, eating, foraging (amberroot,
  hearthleaf, shelf mushrooms), field notes, the satchel, the stair to the
  gallery and the balcony; `tests/playtest.gd` keeps passing.

**Pieces:** existing kit pieces wherever one fits (your note): the masonry
stairs, balustrades and newels, pointed arches, piers and columns, floor
tiles, the hanging and oil lamps, books, vases, the bedroll, fire pit, well,
ferns, ivy and moss. Only what the camp alone has gets a new piece, in a new
`kit_camp.blend`, modelled in the same style and materials as the others.

## The finish line

The camp is a baked scene of kit pieces that looks like today's camp side by
side (the box-art comparison passes from the spawn), plays the same
(`playtest` passes), passes the frame gate by itself at the base spec, and
leads into the Gorge through a door. The old camp code is retired.

## The four steps

| Step | What you can try | How it's checked |
|---|---|---|
| **1. One corner, to settle the look** | The hearth corner (fire, pot, rug, bedroll, the left bookcase and ladder) rebuilt from kit pieces, shown next to today's from the same spots. The list of every camp element and the piece that will make it (existing, or new in `kit_camp.blend`). | Pictures side by side; the corner's triangles and draw calls against today's. |
| **2. The whole camp, baked** | Esc → **Walk the new camp**: the whole Reading Garden from kit pieces, baked to `rooms/camp/camp.tscn` (yours to change in Godot), glowing mushrooms, water, fire and leaves in. The old camp stays the start until you approve. | Box-art comparison from the spawn; side-by-side pictures at the six places above; the frame measurement again. |
| **3. Gameplay moved** | The new camp is where the game starts: cook, eat, forage, read your notes, climb to the gallery and balcony. Saves carry over. | `playtest` against the new camp; the persistence gate; the frame gate, the camp by itself. |
| **4. The door to the gorge; the old code retired** | The camp's door to the gorge (Q2) and the Gorge's door back. `world.gd` and the camp's passes are deleted (the gorge's bake keeps `vista.gd` and the helpers it borrows). | A save-and-resume through the door, as step 5's; every camp test. |

## Not in this

- **The gorge's frame cost.** No frame testing in the gorge until after its
  clean-up pass (your call). If the camp shows the gorge (Q2), that cost is
  counted then.
- **New gameplay** in the camp, and changes to its layout beyond what the
  4 m kit grid needs where it doesn't show.

## Decisions for you

| | Question | Recommended | Alternative | Why |
|---|---|---|---|---|
| **Q1** | Where does this go in the plan? | **Its own phase (7)**; phase 6 ends with the gorge clean-up pass as its step 6; the navigation map moves to phase 8. | It replaces phase 6 step 6 (the camp link) as a bigger step. | It's the size of a phase (four steps, a new kit), and the clean-up you asked for belongs to the gorge's phase. |
| **Q2** | How does the camp meet the gorge? | **A closed door:** the balcony belongs to the Gorge area (its Overlook already starts there); the camp's gallery doorway onto it is a threshold with a loading panel, as step 5's doors. The camp never draws the gorge, so its frame cost is the camp's alone. | **Open:** the camp's balcony shows the baked gorge and its stair is the door. | Closed keeps each area's cost its own and measured apart, and the box-art view is still yours from the Overlook. Open keeps today's walk out onto the balcony from the camp, at the gorge's cost on top of the camp's. |
| **Q3** | How close to today's look? | **The same look,** piece for piece, letting things snap to the 4 m kit grid only where you can't tell. | Use the rebuild to change the layout where kit pieces read better. | You like the look; matching first keeps the comparison honest. |
| **Q4** | Shadowed lights? | **At most four:** the fire, the garden's spot, and the two lanterns nearest the hearth; the rest light without shadows, as the library's lamps do. | Keep all eight, with shadows fading out by distance. | Shadowed point lights are most of today's GPU time. |
| **Q5** | Generated or hand-made? | **Made once by a bake tool from a layout file, then edited by hand** (like the caravanserai's bakes); no grammar, since there's one camp. | Hand-placed in the Godot editor from the start. | A tool can place the 3,000 small things (books, paving, plants) where today's code does; the scene is yours after that. |
| **Q6** | When does the old camp go? | **When you approve step 2's look** it stays on the Esc menu for comparison, and is deleted in step 4. | Delete it as soon as the new one starts the game (step 3). | You can check anything against the original until the end. |

## Approval

Answer the questions (or say "as recommended"), and step 1 starts.
