# Progress: phase 7, the camp from kit pieces

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../camp-rebuild-approval.md)

**In short:** phase 7 was approved on 2026-10-26 with the recommended
answers, and all four steps are built. The camp is 29 kit pieces baked to
`rooms/camp/camp.tscn`, the same look as the code-built camp at a third of
its GPU time. The game starts there with cooking, foraging and saves working
as before. Its gallery doorway is the door to the Gorge's Overlook and back.
The code-built camp is deleted, and from now on the camp scene is edited by
hand. Committed (9e1346a): phase 7 is complete.

---

## Step 4: the door to the gorge; the old camp retired (built 2026-10-26; committed 9e1346a)

### Try it

Climb to the gallery and walk into the doorway at its back: it glows with
the gorge's light. After the loading panel you're on the Overlook's loggia,
just inside its bronze door, facing the balcony and the gorge. Turn round
and walk into the bronze door: you're back in the gallery, just inside the
doorway, facing the camp. Quit on either side and you resume there.

**Look at** `previews/camp_rebuild/step4/`: the gallery's door
(`camp_gallery_door`), arriving back in the camp (`camp_arrival`), the
Overlook's door (`gorge_loggia_door`) and arriving on the Overlook
(`gorge_arrival`).

### What changed

- **The camp's door** (`rooms/camp/camp.tscn`): the wall that sealed the
  gallery doorway is now `Threshold_gorge`, the same glowing door the
  library's doors to the gorge use. The doorway's floor had been the gorge
  passage's, so the camp now has a stone sill under the door (without it you
  could drop between the gallery's edge and the door).
- **The Overlook's door back** (`tools/bake_overlook.gd`,
  `rooms/gorge/overlook.tscn`): a connector, `SNAP_door_camp`, on the face of
  the bronze door already in the loggia's back wall, and in the Gorge recipe
  that connector is a threshold to "camp". A new Threshold look, "door", draws
  nothing, because the bronze door is already there. The re-baked Overlook
  differs only by that connector.
- **Travel** (`main.gd`): `cross()` now goes from the camp to an area and from
  an area to "camp". Arriving in the camp puts you 2 m inside its door back,
  as an area does.
- **The old camp is retired.** `scripts/world.gd` and its ten passes are
  deleted: `arch_pass`, `art_direction`, `atmosphere`, `benchmark_pass`,
  `camp_composition`, `interior_pass`, `library_dressing`, `organic_pass`,
  `planting_pass` and `set_dressing`, about 2,000 lines. The Esc menu's
  **Visit the old camp** is gone.
- **What the gorge's bake still needs:** the gorge's bake keeps `vista.gd`, as
  the brief said. The five helpers `vista.gd` borrowed from `world.gd` (`box`,
  `light`, `arch`, `lantern`, `interaction`) are now `scripts/gorge_host.gd`,
  unchanged. Built both ways, the gorge comes out identical: the same 7,803
  meshes, 198 lights and node positions. `bake_gorge.gd` takes the camp's
  lighting environment from the baked camp, whose environment differs from
  the gorge's saved one only by its own copy of the colour-grade gradient.
- **The camp is now edited by hand** (Q5). The tools that cut it from the old
  camp (`camp_extract.gd`, `camp_cut.gd`, `bake_camp.gd`,
  `camp_kit_capture.gd`) can't run without it. They were never committed, so
  rather than delete them they're kept in `art_src/kit/camp/retired_tools/`,
  which Godot ignores, as the record of how the camp was made.
- **Tests retired or changed:**
  - **Retired:** `geometry_audit.gd` and `gorge_bank_preview.gd`, which
    checked the old camp's code.
  - **Removed modes:** the `--old` modes of `playtest` and
    `camp_kit_walk_test`, and `camp_frame_capture`'s old-camp modes. The
    capture's balcony view also went, since the balcony is the Gorge's now.
  - **`tests/capture.gd`:** its gorge views (box art, balcony and so on) now
    render in the Gorge area, where the Overlook stands in the balcony's
    place.

### Checks

| Test | Result |
|---|---|
| `persist_test` camp_cross, camp_back (new, in `persist_gate.sh`, now 16 processes) | pass. Each runs in its own process after camp_save and camp_load. In the first, you resume in the gallery, step into its doorway and arrive in the Gorge just inside the Overlook's door back, facing in, on the loggia's floor. In the second, you resume there, turn round, walk into the bronze door on foot, and arrive in the gallery 2 m inside the doorway, facing in, with the amberroot still in the satchel. |
| `persist_test` door_save, door_cross, door_back (the Gorge's doors to the Lower Stacks) | pass |
| `playtest` | 33 checks pass. The doorway check is now that walking in reaches the door to the Gorge. |
| `camp_kit_walk_test` | 17 checks, 0 failures. With no game to travel, the door's wall holds you in the doorway. |
| `gorge_network_test`, `area_plan_test` | 790 and 266 checks, 0 failures |
| Every script in `scripts/`, `tests/`, `tools/` loaded | 160 compile, none fail |
| Frame measurement (Medium, 1080p) | GPU 1.43 ms mean, 2.31 worst; frame 2.06 mean, 3.00 worst; draw calls 1,282; triangles 2.64 M; 33 lights in reach, 4 shadowed: every limit passes |
| 240-frame run of the game with no arguments | clean |

### Caveats

- **The camp's doorway glows a flat blue**, like the library's doors to the
  gorge. You no longer see out onto the balcony and the gorge from the
  gallery as you could in the old camp (Q2's closed door). The view is the
  Overlook's, one step through.
- **The gorge bake itself wasn't re-run.** The host was checked against
  `world.gd` by building the gorge's code both ways, which came out
  identical, and the environment it now reads matches the saved one.
- **Not run:** the full persistence gate's other runs (the reading room and
  the years), the frame gate in the Gorge (left until its clean-up, as you
  asked), the box-art comparison.

---

## Step 3: gameplay moved (built 2026-10-26; walked once, 3 reports fixed)

### Your walk: three reports (2026-10-26)

Retaken in `previews/camp_rebuild/walk3/`.

| Report | Fix |
|---|---|
| 18-32-53: the stair's railing clips into the end posts at its foot | The newels now stand on the balustrades' middle line (they were 0.19 m outboard, so the rail ran past their sides). Each stair run stops at the newels' faces, and the foot newels are 0.15 m taller, so the rail meets each post's side under its cap (`tools/bake_camp.gd` `_balustrades`). |
| 18-33-18: the same at the stair's top | The same fix. The top newels are on the gallery balustrade's line, and the gallery run west of the stair now ends inside its newel. |
| 18-33-50: the gallery stops short of the west wall (a fall) | The gallery slab, the brick face and mosaic band under it now run to the west wall (x -9.1; they stopped at -7.2, `scripts/world.gd`), and a short balustrade closes the edge to the wall. The gallery and garden pieces were cut again. `tests/camp_kit_walk_test.gd` now walks to the wall and checks the edge holds you (17 checks). |

### Try it

Start the game: you're in the camp from kit pieces, by the fire. Cook,
eat, forage (amberroot, hearthleaf, shelf mushrooms), read your notes, climb
to the gallery. Quit and start again: you're back where you were. Esc →
**Visit the old camp (code-built, until it's retired)** goes to the old one
for comparison (Q6); from there Esc → **Return to the camp**.

### What changed

- **The start** (`main.gd`): "camp" is now `rooms/camp/camp.tscn`; the
  code-built camp is `main.OLD_CAMP` ("camp:code"), on the Esc menu until
  step 4. Saves keep `scene` = "camp", so an old save resumes in the new camp.
- **Interactions baked in:** the cooking pot and the six patches are in the
  scene (`Interactions`), their ids and titles saved
  (`scripts/interactable.gd` exports them). `CampRoom` has the old camp's
  `gatherables` and `harvest()`, so `main.gd`'s cooking, foraging, warmth by
  the fire and zone names work unchanged.
- **Your last report** (16-58-08): the narrow bookcase right of the archive
  arch is gone; the pier beside the arch shows
  (`previews/camp_rebuild/walk2/`).

### Checks

| Test | Result |
|---|---|
| `playtest` (the game's start: the new camp) | 32 checks pass: arrival on the floor, walking, menus block movement, the pot and a patch by the ray, harvesting once, cooking and eating both recipes, the stair to the gallery, the doorway holds, the ceilings and roof seams closed, the tree's trunk, the field notes |
| `playtest -- --old` (the code-built camp) | 44 checks pass, its own (gorge view, merging, balcony) included |
| `persist_test` camp_save, camp_load (new, in `persist_gate.sh`) | pass, each its own process: gather amberroot, stand in the gallery, quit; resume in the new camp in the gallery, the root still in the satchel |
| `camp_kit_walk_test` | 13 checks, 0 failures |
| Frame measurement | GPU 1.42 ms mean, 2.56 worst; draw calls 1,321; triangles 2.64 M; four shadowed lights: every limit passes |
| 240-frame run of the game with no arguments | clean (starts in the new camp) |

### Caveats

- **Box-art comparison from the spawn:** the rug region now passes (0.90,
  was 0.83) and the archive is closer (0.84), but the **left foreground
  fell to 0.73** (was 0.97): the angled bookcase you asked to remove filled
  that part of the frame. If you want it back within ±15%, a lamp or some
  dressing there would do it; say so.
- **Harvested patches refill on a restart**, as in the old camp (they were
  never saved); the satchel is.

---

## Step 2: the whole camp, baked (built 2026-10-26; walked twice, 13 reports fixed; you said it looks good)

### Your walk: twelve reports (2026-10-26)

**Look at:** `previews/camp_rebuild/walk1/<report id>.png`, each of your
views retaken in the re-baked camp (your screenshots are in `reports/`).

The fixes are made in the old camp's code and the camp re-cut and re-baked
from it, so the old camp (still the game's start) changed the same way.

| Report | You said | Now |
|---|---|---|
| 16-22-09 | two styles of bookshelf: make the camp's as simple as the other rooms', still floor to ceiling | every camp bookcase (`asset_factory.shelf`) is now built as the library's case panels are: a painted face of books behind wooden shelves, brass trim; same sizes, floor to ceiling. Thousands of separate books gone |
| 16-23-52 | floating bollards and railing: use the ones made for other rooms | the gallery's posts, thin rail and guard are gone; the Overlook's balustrade (balusters on a plinth, rail) runs along its edge, square newels with limestone caps at the ends |
| 16-24-21 | fill this section in: the player can't get there | the space under the gallery is solid: a brick face with a sandstone base and a mosaic band |
| 16-24-41 | the two arches on the left aren't needed; fill in the section and simplify what's covered | the three small arches and their balusters under the gallery are gone (filled as above); what was behind them is left out of the pieces (`camp_drop`) |
| 16-25-22, 16-25-43 | banners offset, clipping into the wall | the archive wall's hangings hung into its piers: now two, centred between the piers |
| 16-26-06 | the ladder faces the wrong way | every camp ladder leaned out from its case; they now lean back against it |
| 16-26-16 | remove the extra bookshelf and ladder in front; the ladder on the left leans the wrong way | the angled bookcase (with its ladder and ivy) by the planter is gone; the other ladder leans in, as above |
| 16-27-17 | another entrance, so the camp can join other areas | a pointed doorway in the front wall (where a bookcase stood), with the glowing exit every area's unjoined doorway has, and a connector (`SNAP_exit_front`) for joining an area there later |
| 16-27-53 | the water should flow from a pipe or hole in the wall, so the gaps round it close | the channel now starts at a culvert under the gallery: a low arched opening in the brick face with a limestone lintel, the water flowing out of it |
| 16-28-41 | the middle trim cuts into the skylight | the middle stone rib of the vault moved clear of the lantern |
| 16-29-37 | remove the shelves at the top: floor to ceiling or nothing | the high shelves with nothing under them are gone: the band over the front arches, and those over the archive wall |

**Checks after the fixes:** `camp_kit_walk_test` 13/0 (with the new
balustrades and the filled space); the old camp's `playtest` 43/0 (its count
of wall collections lowered to match: 11 case panels, 5 hangings);
240-frame runs clean in both camps; the textures kept uncompressed.

**What it costs now** (the same measurement): GPU 1.31 ms mean, 2.41 worst;
frame 1.94 ms mean, 3.13 worst; draw calls up to 1,325; **triangles up to
2.64 million, now within the 3 million** (the simpler bookcases); four
shadowed lights; builds in 0.45 s. **Every limit of the frame gate passes.**

**How it was kept from shifting:** the camp places most small things by a
seeded random sequence; removing the bookcases' books or the angled case
would have moved everything placed after them. They still draw the same
numbers, so the rest of the camp stands where it did.

### Try it

Esc → **Walk the new camp (kit pieces)**. You start at the box-art framing
by the fire, as in the old camp. Esc → **Return to the camp (the code-built
one)** goes back. The old camp is still where the game starts (step 3
moves the start).

Not there yet (step 3): cooking, eating, foraging and the field notes'
interactions, and the HUD's warmth by the fire works but nothing else of
the camp's gameplay. The gallery's doorway onto the passage is walled for
now: the passage and balcony stand on the gorge's floor, which the camp no
longer draws (Q2); step 4 makes the doorway the door to the Gorge.

**Look at:** `previews/camp_rebuild/baked/` against
`previews/camp_rebuild/corner_today_same/` (today's camp, no gorge view):
the same eight views, plus `concept_framing.png` (the box-art camera).

### What's in it

- **29 pieces** (`art_src/kit/camp/pieces.json`): the nine of step 1; the
  floors of the hall, garden and archive; the tree; the channel's stones; the
  stair; the gallery; the archive's floor with its glowing mushrooms, moss
  mounds and rotting log; the garden's beds and rocks; the arch wall; the
  archive; the lightwell; the back wall and upper stacks; the hall's west,
  east and front walls and roof; the hall's clutter; the passage's
  dressing; and a catch-all (two small meshes). All cut as in step 1.
- **The living parts**, taken from the old camp as it builds
  (`tools/bake_camp.gd`): the environment (fog, grade, glow), 31 lights, the
  fire's flames and sparks, the drifting leaves, 24 steam and flame cards,
  the three water surfaces (channel, upstream pool, cascade), the six
  gatherables' plants, three reflection probes.
- **Four shadowed lights (Q4):** the fire, the garden's light, and the
  lanterns on the provisions slab and on the book stack. The other four that
  cast shadows (two lanterns, two fills) light without them.
- **`CampRoom`** (`scripts/camp/camp_room.gd`) keeps them moving as the old
  camp's clock did: the fire's flicker and drift, the lanterns breathing,
  the garden light's sway, the leaves' wind and the water's ripples (the
  kit pieces' leaves included), the steam rising.

### What it costs

The frame measurement of the brief, the same six places, Medium, 1080p:

| | Today's camp (no gorge) | The new camp | Limit |
|---|---|---|---|
| GPU time per frame | 4.35 ms mean, 7.65 worst | **1.46 ms mean, 2.71 worst** | 3, 4 |
| Frame time (CPU) | 5.04 ms mean | **2.11 ms mean, 3.37 worst** | 4, 8 |
| Draw calls | up to 2,042 | **up to 1,428** | 1,500 |
| Triangles drawn per frame | up to 35.7 million | **up to 3.9 million** | 3 million |
| Lights casting shadows | 8 | **4** | 4 |
| Lights within 35 m | 31 | 31 | 50 |
| Building it at start-up | 3.0 s | **0.48 s** | |

Everything is within the limits but the triangles (3.9 of 3 million): the
pieces still carry the code's fine detail (the rug's fringe, the garden's
vines, the pomegranate's seeds). Simplifying those in Blender is step 3's
work, before the frame gate.

### How close it is

- **Box-art comparison** from the box-art camera: the same as today's camp,
  region for region (whole frame 1.00, hero arch 1.00, hearth 1.04, left
  foreground 0.97); the two regions today's camp already misses are a little
  closer (right archive 0.74, was 0.70; rug 0.83, was 0.81).
- **Pictures:** 5–15% of pixels differ by more than 8 of 255 from today's.
  Two causes, both checked: the four lights that no longer cast shadows
  (the deep shelves look fuller: with every shadow kept, the left wall
  differs by 1.8%), and things in motion (the garden light's dapple, the
  leaves, the water) caught at another moment. Swapping all 29 pieces into
  the old camp instead differs by 1–4%, so the pieces themselves match.

### Checks

| Test | Result |
|---|---|
| `camp_kit_walk_test` (new) | 13 checks, 0 failures: the capsule walks from the spawn round the hearth through the garden arch, from the hall up the stair to the gallery and its doorway, and into the archive, on the pieces' collision; the doorway holds. The same routes pass in today's camp |
| `playtest` (the old camp) | 43 checks pass |
| `kit_test` | 3,294 checks, 0 failures |
| 240-frame runs | clean in the new camp and the old |

### Caveats

- **The leaves sway from the moment the camp loads**, as before; pictures
  taken a few frames apart differ there.
- **Re-baking overwrites `rooms/camp/camp.tscn`.** Once you change the
  scene by hand, edit it there (or in the pieces), not by re-running the
  bake.
- **Texture compression:** the new camp materials referenced one more
  texture (`earth_patch`), kept uncompressed as in step 1.

---

## Step 1: one corner, to settle the look (built 2026-10-26; you settled the look)

### Look at

`previews/camp_rebuild/corner_today_same/` (today's camp) and
`previews/camp_rebuild/corner_kit/` (the kit pieces in it), the same eight
views, by name: `camp_spawn` (the box-art framing), `camp_hearth`,
`camp_hearth_back`, `camp_planter`, `camp_left_wall`, `camp_garden`,
`camp_archive`, `camp_gallery`. Both without the gorge view. Retake them with

```
godot --path . --resolution 1600x900 --script res://tests/camp_kit_capture.gd -- <out dir> --from=res://previews/camp_rebuild/poses/ --no-gorge [--old]
```

You can also open `art_src/kit/kit_camp.blend` in Blender: each piece is a
module (`M_camp_hearth` and so on), and `tools/export_kit.bat kit_camp.blend`
brings your edits into the game, as with the other kits.

### How the pieces are made

The camp's shapes (lathed lanterns and bowls, chipped hearth stones, the
cauldron, the books) were made by code with random wear, so modelling them
again would lose the look. Instead each piece is **cut out of the built
camp**:

1. `art_src/kit/camp/pieces.json` lists the pieces: a name, where the piece
   stands (its foot and turn) and the boxes it takes from the camp.
2. `tools/camp_extract.gd` builds the old camp, takes everything in each
   piece's boxes (`tools/camp_cut.gd`: meshes, instanced books and leaves,
   static collision; not the animated flames, steam and gatherables, nor
   lights, particles or water) and writes it to
   `art_src/kit/camp/src/<piece>.glb`, one mesh per material, collision as
   convex hulls. It copies the camp's materials into the kit's library as
   `kit/materials/camp_*.tres` (the leaves' wind material as
   `camp_foliage_<kind>`).
3. `tools/kit_add_camp.py` brings each into `kit_camp.blend` as a module;
   after that the `.blend` is the source (a piece already there is left
   alone unless named).
4. `tools/export_kit.bat kit_camp.blend` exports them to
   `kit/modules/camp/` like every kit (it now keeps a camp piece's colour
   attribute: the books' and leaves' colours).

### How close it is

Pixels that differ by more than 8 of 255, kit pieces against today's camp:

| View | Differ | Mostly |
|---|---|---|
| spawn (box-art framing) | 1.1% | leaves swaying (see caveats) |
| hearth | 1.5% | the same |
| behind the hearth | 8.9% | the planter's leaves close to the camera |
| planter | 4.2% | its leaves' sway |
| left wall | 1.1% | |
| garden, gallery | 2.5%, 4.2% | leaves in the wind |
| archive | 0.0% | |

The shapes, materials and colours come through Blender unchanged; what
differs is where the leaves are in their sway.

### The pieces

| Piece | What it is | Triangles |
|---|---|---|
| `camp_hearth` | ring of chipped stones, logs, charcoal, embers, cauldron with stew, ladle | 46,072 |
| `camp_provisions` | the two mosaic-clad slabs, bowls of fruit, roots, the pomegranate, herbs, cloth, crockery, the lantern on the slab | 67,516 |
| `camp_lantern_books` | the lantern on its book stack, the travelling books | 3,374 |
| `camp_planter` | the turquoise planter and its shrub | 5,972 |
| `camp_bookcase` | the angled bookcase, its ladder, ivy, rolled sheets, the bed beside it | 18,298 |
| `camp_rug` | the rug and its fringe | 61,442 |
| `camp_bedroll`, `camp_pack`, `camp_mug` | | 1,536, 1,512, 1,152 |

### Every camp element and what will make it (for step 2)

Cut pieces keep today's look exactly; "kit" means an existing piece from
another kit, put side by side with today's before it replaces anything
(your note: masonry bollards and the like).

| Element | Made by today | Step 2 |
|---|---|---|
| Hearth corner (above) | `world.gd` build_camp, `camp_composition`, `set_dressing` provisions, `benchmark_pass` detail | **done** (step 1) |
| Paving, broken slabs, garden paths, earth | `organic_pass`, `interior_pass` | cut, as floor pieces about 4 m square |
| Walls, plinths, dado, cornices, tile trim | `world.gd` architecture, `set_dressing` stonework | cut |
| Pointed arches, centre pier with its mosaic panel, voussoirs, entrance piers | `world.gd` arch, `arch_pass`, `benchmark_pass` masonry, `interior_pass` surrounds | cut |
| Roof, beams, brackets, vault and lightwell lantern | `world.gd`, `set_dressing` roof, `interior_pass` vault | cut |
| Stair to the gallery and its rail | `world.gd` build_stairs | **kit candidate:** the masonry stair (`stair_steps_masonry`) and the Overlook's balustrade and newels; cut if they don't match |
| Gallery slab, posts and railing | `world.gd` | **kit candidate:** the balustrade and square newels from the gorge's kits; cut otherwise |
| Bookcases and shelves (walls, archive, upper stacks), ladders | asset_factory shelf and ladder | cut (the camp's own freestanding cases) |
| Collections, case panels, hangings | `library_dressing` | cut |
| The tree through the archive | `organic_pass` and others | cut, its leaves in the wind material |
| Irrigation channel stones, upstream lip | `world.gd`, `interior_pass` water detail | cut |
| **Water** (channel, upstream pool, cascade) | water and cascade shaders | kept as they are, in the bake |
| Planting beds, kerbs, rocks, ferns, ivy, joint tufts | `planting_pass`, `organic_pass`, `arch_pass` ivy | cut, leaves in the wind materials |
| **Glowing mushrooms** (archive fungi on moss mounds, rotting log) | `camp_composition` archive fungi | cut, with their glow material; their lights in the bake |
| Gatherables (amberroot, hearthleaf, shelf mushrooms) | `world.gd` | kept as interactions in the bake, their visuals as small pieces |
| Bench, vase, still lifes, lying books, rolled sheets | various | cut |
| Fire, embers, steam, flame cards, drifting leaves | particles and animated cards | kept as they are, in the bake |
| Lights, fog, grade | `world.gd` lighting, `benchmark_pass`, `art_direction`, `atmosphere` | the bake's layout; at most four shadowed lights (Q4) |

### Checks

| Test | Result |
|---|---|
| `kit_test` | 3,294 checks, 0 failures (the new camp family included) |
| `camp_kit_capture` | the pieces load and stand in place in today's camp; pictures above |

### Caveats

- **Triangles.** Cut pieces carry the code's detail as it was: the rug's
  fringe is 160 little cylinders (61,000 triangles), the pomegranate's seeds
  24,000, the embers 20,000. Not the frame's main cost (the shadowed lights
  are), but now they're in Blender they can be simplified in step 2 without
  a visible change.
- **Draw calls.** Each piece draws once per material (up to 17); today's
  camp merges everything by material. Step 2's bake batches the pieces.
- **The leaves' wind.** The pieces' leaves use copies of the camp's wind
  materials, which the camp's clock doesn't drive yet, so in these pictures
  they're still. Step 2 drives them from the camp's clock.
- **Texture compression.** Saving the camp's materials into the kit made Godot
  switch nine of their textures (books, ceramics, the rug's relief) to
  compressed video-memory formats, which would change how the camp looks;
  their import settings now keep them as they were.
- **Frame numbers** from these mixed scenes aren't meaningful (old camp plus
  new pieces); step 2 measures the whole baked camp.
