# Progress: the R01 weathering slice (done 2026-10-19)

[Back to the front page](../../../ENVIRONMENT_PLAN.md)

**In short:** making R01 look old. Fallen books land on the real floor, debris along wall bases, plants, stain decals, open wooden stairs.

---

### Next: the weathering slice (planned 2026-10-19, after step 5)

0. ~~**Spill lands on the floor that is there**~~ (done 2026-10-19). Three
   cases turned out to be wrong, not one: spill sank 0.15 m into gallery
   slabs, intersected stairs, and **floated 4 m up** in front of upper recesses
   with nothing in front (reading room bay 4). That last one no check had
   caught.
   - **Runtime:** `ShelfFill` rests each spilled book in front of the wall
     face on the first collision surface below it. It waits two physics
     frames so the room's bodies are registered, then casts from the top of
     the spill zone, so spill can land under furniture but never on top of
     tall things. Books inside the recess stay put. Child meshes named
     `*__spill*` settle the same way: `recess_shelves_broken` rev 3 splits its
     two floor boards out as `__spill_a` / `__spill_b`, with b moved 0.15 m
     forward. The random draw order is unchanged, so existing seeds keep
     their layout.
   - **Validate Room:** `SocketSet.spill_bounds` (new) separates the settling
     zone from the rigid `slot_bounds`. The recess slot is now just the recess
     depth; the spill zone is the 0.6 m band up to 1.35 m in front. Validate
     Room probes the spill zone straight down against the modules' collision
     triangles (host included: the iwan's alcove floor counts). It warns if a
     column has nothing to land on, or if a probe starts inside another solid
     (odd crossings on an upward ray), e.g. a pier standing in the zone.
   - **Verified:** `tests/spill_settle_test.gd` (6 checks) pins all 16
     reading-room recesses to collapsed. Every settled book rests on the
     surface right under it, probed independently: 114 on the hall floor, 115
     on gallery slabs, 75 on stairs, and 51 dropped a storey from bay-4 upper
     recesses. The broken boards settle too. `validate_room_test` now has 21
     checks: the reading room has **no warnings** (was 9), the graybox keeps
     its two genuine ones (its side galleries run into the end-wall recess), a
     table over the zone is fine, a pier in it is reported, and a missing
     floor is reported. Every other gate passes. GPU:
     `previews/reading_room_collapsed_{gallery,recesses}.png` show books lying
     on the gallery. The dropped books in the dark bay-4 corner didn't read in
     a capture (checked numerically only), and books on the stair rest on its
     walkable ramp, so they may sit up to ~0.1 m off a tread edge. The user
     checked a collapsed upper recess in the editor: the spill lands right.

Agreed scope: only the parts that existing tools carry, so phase 3's
`AgeRules` can later just shift their weights. Order:

1. ~~**Edge scatter**~~ (done 2026-10-19, first with debris; plants are item 2).
   - **`EDGE_SCATTER` mode** (`VariantSocket`): items along local +X for
     `edge_length`, up to `edge_depth` out into the room, `scatter_spacing`
     apart, with random yaw. Picks without a scene leave gaps, so the set's
     weights set the density. `SCATTER`'s random draw order is unchanged, so
     tables keep their layout.
   - **Generic settle** (`settle`, `settle_max_drop`) for scatter modes: after
     two physics frames each item rests on the surface below, or is removed
     if nothing is within reach. Seams in front of upper walls sit on the
     gallery (4.15) and never float.
   - **First candidates:** `debris_rubble` and `debris_brick` (dressing
     family, 36 modules) in `kit/sockets/seam_debris.tres` (nothing 6,
     rubble 2, fallen brick 1).
   - **Seam sockets:** `SOCKET_seam_debris` on `wall_plain_4m` (from 0.85 m,
     2.3 m long, clear of the corner piers) and on both iwan flanks. The
     importer reads `edge_scatter`, `edge_length`, `edge_depth`, `settle` and
     `settle_max_drop`. The upgrade pass in `kit_add_r01.py` now also keeps
     script-owned markers in sync (position and properties), so retuning a
     socket reaches an existing `.blend`.
   - **Validate Room:** an `EDGE_SCATTER` slot is the strip the items can
     reach (the line plus an item footprint, room side only). Settling
     sockets get the spill-style probe ("items would rest inside X"), with
     nothing-below allowed by design. Sockets pinned to a scene-less entry
     are skipped.
   - **Reading room:** the four plain walls hidden behind the stairs have
     their seams pinned to "nothing" (`build_reading_room.gd`
     `pin_hidden_seams()`, patched in place). It validates with no warnings
     again, and now has 38 sockets (10 seams).
   - **Verified:** `socket_modes_test` has 71 checks: items on the strip,
     spacing, gaps, determinism, and settling on the floor (0.00), on a
     gallery slab one storey up (4.15), and removed over nothing. Kit test
     463, room 28, validate room 21, spill 6, atmosphere 32, room playtest
     11, camp playtest 43, and all three 240-frame gates are clean.
     `previews/reading_room_seams.png` (capture option `seams` pins every
     seam to rubble) shows chips along the wall base on the floor. The user
     checked the seams in the editor; the rubble is small and subtle by design.
2. ~~**Plants as dressing**~~ (done 2026-10-19).
   - **Swaying foliage:** `shaders/kit_foliage.gdshader` is the prototype's
     wind shader on engine `TIME`, so no script drives it. The card library
     materials (`tree_leaf`, `leaf`, `ivy_leaf`, `fern`) are now
     ShaderMaterials on it (`tools/seed_foliage.gd`; additive, keeps UIDs),
     so the iwan's reading tree sways too. The prototype's own materials are
     untouched.
   - **Plants** (dressing family, 40 modules): `plant_crack_tuft` (grass
     blades over a moss line, as in the prototype), `plant_moss_cushion`,
     `plant_fern`, and `plant_ivy_hang`, which drapes over a rail top and
     hangs 0.12 m out on the hall side. Cards use the `add_card()` helper in
     `kit_blender.py`.
   - **Sets:** the wall-base seam set keeps its name `seam_debris` (renaming
     would churn socket names and room pins) and now holds what gathers at a
     wall base: crack tuft 2, moss 1.5, fern 1, plus the debris. Its slot is
     0.4 m tall for the fern. New `rail_growth` (nothing 5, ivy 2) as a
     non-settling `EDGE_SCATTER` on every gallery rail: `gallery_slab_4m`,
     both corner slabs and `gallery_end_12m`. Sockets stay 0.65 m from slab
     ends that meet a wall and clear of corner newels; Validate Room found
     both (graybox end walls, the reading room's west newel).
   - **Verified:** `socket_modes_test` has 86 checks (set contents, rail
     socket on the rail top, ivy pinned and hanging down the gallery edge,
     and plant cards using the swaying material). Kit test 493, room 28 (now
     43 sockets incl. 5 rails), validate room 21 (the reading room has no
     warnings), spill 6, atmosphere 32, both playtests and the prototype
     atmosphere test pass, and all three 240-frame gates are clean. GPU
     (capture option `growth`): `previews/reading_room_growth_{seam,gallery,end_gallery}.png`
     show ferns at the wall base and ivy trailing over both galleries'
     balustrades. **Caveats:** at hall distance the ivy is a modest accent,
     and it trails over the balustrade rather than below the slab; longer
     strands would read more. The user checked the plants in the editor. **Not done:**
     the root clump for collapsed recesses (deferred, it needs a recess
     candidate change; done in polish B item 6).
3. ~~**Decals**~~ (done 2026-10-19).
   - **Maps:** 8 pixel decal maps in `assets/textures/decals/`, written by a
     `decals` pass in `tools/pixel_materials_ext.gd` (`-- decals` runs only
     that pass). They follow the px rules: 32 tx/m, small palettes, Bayer
     dithering, and alpha in 5 dithered steps, so edges stay texel steps.
     - Walls, 40 × 80 px (1.25 × 2.5 m): two water stains (seep in at the top,
       drips, tide line, salt bloom at the foot) and damp with a moss cushion.
     - Floors, 40 px (1.25 m): two cracks, with the groove in a normal map
       because floor decals spin, plus a dried puddle and moss.
     - Lamps: one soot plume, 1.25 m, so a lamp 1 m out clears the wall line.
     - Imported lossless with mipmaps; the normal maps are flagged as normal
       maps. `rendering/textures/decals/filter` is nearest-mipmap-anisotropic.
   - **Only architecture takes decals:** render layer 20
     (`KitModule.DECAL_LAYER`, named `decal_receivers`) is added at import to
     the meshes of edge, cell and post modules. Every decal's `cull_mask` is
     that layer alone, so rugs, tables, lanterns, books and plants never take
     a stain (the GPU captures show a clean rug over cracked cells).
     `normal_fade` is 0.8, so faces turned away don't smear.
   - **Scenes and sets** (`tools/seed_sockets.gd`, additive): `kit/decals/*.tscn`
     is a Node3D with a Decal child.
     - `wall_stains`: nothing 3, water stain 2, water stain b 2, damp and moss 1.5.
     - `floor_wear`: nothing 4, crack 2, crack b 2, damp patch 1.5, moss 1.
     - `lamp_soot`: soot 3, faint soot 2 (same map at 55%), nothing 1.
     - New `SocketSet` flags: `slot_is_item` (the slot is one item; Validate Room
       widens it by a SCATTER socket's `scatter_extent`, so one set serves sockets
       of any size) and `decals`.
   - **Sockets** (`kit_add_r01.py` ADD_MARKERS, which now sync rotation too):
     - Wall sockets on `wall_plain_4m` and `wall_gable_12m` are turned -90° about
       X, so the socket's Y comes out of the wall and Z points up. SCATTER places
       0-2 items with the new `VariantSocket.scatter_spin` off (imported from
       `scatter_spin`). The scene turns the Decal half a turn so the image top is up.
     - `floor_4m` gets a spun SCATTER (0-2).
     - Lanterns get a REPLACE socket turned half a turn, projecting up from the
       chain top: 4.0 m in the gallery slab for `lantern_hanging`, 14.6 m at the
       vault crown for `lantern_cluster`.
   - **Validate Room** (decal sets): a decal is meant for one surface, the
     facing surface nearest the socket's plane. It warns when the box a socket's
     decals can cover also reaches a facing architecture surface of another
     module more than 0.1 m off that plane, such as a crack climbing a stair
     tread or a stain over a pier face. Facing uses the collision triangles'
     outward normal (`-(b-a)×(c-a)`), dot ≥ 0.6. It caught the soot plume
     catching lintel undersides in the wall line, then a gallery-end corbel; the
     plume was shrunk to 1.25 m and the hanging socket moved up to the chain top.
     The graybox has one more known warning (a side-gallery baluster stands in
     front of its upper plain end wall).
   - **Reading room:** 75 sockets, adding 10 wall stain, 15 floor and 7 soot
     sockets. It validates with no warnings. No pins were needed: the
     stair-covered walls show their stains above the stair.
   - **Verified:**
     - Headless: `socket_modes_test` 149 checks (sets and flags; every decal on
       the decal layer at 32 tx/m; wall stain upright, projecting into the wall
       at mid-wall; floor crack down with a normal map; soot up at the chain
       top; architecture meshes on the layer, furniture and dressing not).
       `validate_room_test` 22 (new: a floor raised 0.12 m into a cell's reach
       is reported). Kit test 498 (graybox 35 sockets), room 28, spill 6,
       atmosphere 32, room playtest 11, camp playtest 43 and the prototype
       atmosphere test pass. All three 240-frame gates are clean.
     - GPU: the capture option `decals` pins stains, cracks and soot, and
       `nodecals` pins all three to nothing (for image_diff). New views `soot`
       and `crown`. Files: `previews/reading_room_decals_{entrance,end_gallery,seam,soot}.png`
       and `reading_room_weathered_{end_gallery,table}.png` (default seed).
   - **Caveats:**
     - The first stain colour vanished on lamp-lit sandstone (as in vista slice
       8), so the body palette is now near-black umber at 40-85% alpha. The
       stains read as streaks with tide lines, but they're modest at hall distance.
     - Chandelier soot lands on the dark tiled crown and doesn't register
       (image_diff stays at noise). It's honest, but invisible.
     - Under the galleries the camera sits inside the plume, so the soot reads
       as darker wood, not a plume shape.
     - Changing `tools/kit_import.gd` doesn't reimport unchanged `.glb` files.
       Delete their `.godot/imported/<name>.glb-*` caches and run `--import`
       twice (done here for the decal layer).
4. ~~**Open wooden stair**~~ (done 2026-10-19), built as a stair *look*.
   - **Decision (user):** the stair look is a variant you cycle in the editor,
     like the recesses, not a separate module. A first cut made
     `stair_gallery_8m_open` and `_open_r` as twin modules; they were never
     committed and are gone.
   - **Socket:** `stair_gallery_8m` and `_r` lost their built-in steps mesh
     and gained `SOCKET_stair_style` (REPLACE) mid-footprint: Blender
     (4.0, 0.95, 0), Godot (4, 0, -0.95). The module keeps everything a
     route needs: the walkable ramp collision, the balustrade and the foot and
     head snaps. A pick never changes collision, snaps or validation. Both
     looks are symmetric across the lane, so `_r` turns its socket half a turn
     (`STAIR_TURN`) instead of needing mirrored candidates.
   - **Candidates** (`kit_add_dressing.py`, dressing family; kit 42 modules):
     - `stair_steps_masonry`: the old 20 stone steps.
     - `stair_steps_open`: two sloped wooden stringers (8 cm thick, 0.3 m
       deep, top edge 8 cm above the nosings, foot on the floor) and twenty
       5 cm treads with a 3 cm nosing and open risers.
     - Set `stair_style`: masonry 2, open wood 1, so the seed varies generated
       rooms. No slot bounds: the module owns its footprint, and the steps
       have always run past the pier at the stair's middle.
   - **Upgrade:** `kit_add_r01.py` gained `REMOVE_MODULES` (deletes a module
     with its children) and removes the two `__steps` meshes. `stair()` adds
     the socket on fresh builds. Stale `.glb` and wrapper files of deleted
     modules have to be removed by hand: the export doesn't delete them.
   - **Reading room:** both stairs are pinned to masonry (two lines added to
     `socket_pins`; `build_reading_room.gd` gets `pin_masonry_stairs()` for
     fresh builds), so it looks as before. An image_diff of the `table` view
     against the item 3 preview gives mean 0.21 (noise floor 0.14). To try
     the wooden look, select a stair and use **Next candidate** or the
     Sockets panel. The four stair-hidden wall seams stay pinned bare.
   - **Gotcha:** re-saving `reading_room.tscn` from a headless script
     strips every UID, the scene's own included (`get_resource_uid` is -1
     headless). The pins were added as text instead.
   - **Verified:**
     - `kit_test` 524: neither stair carries steps of its own; each has one
       stair_style socket mid-footprint; both looks fill the footprint
       (x 0..8, z -1.6..-0.3) on both stairs and start at the foot snap.
     - `reading_room_test` 56: the full audit runs as saved and again with both
       stairs pinned to open wood, with the capsule climbing both.
     - `validate_room_test` 23: clean with open wood. `socket_modes_test` 153
       (set contents).
     - Spill 6, atmosphere 32, room playtest 11, camp playtest 43, the
       prototype atmosphere test, the two-process pin persistence gate and all
       three 240-frame gates pass.
     - GPU (capture option `open_stairs` pins open wood, view `west_stair`):
       `previews/reading_room_open_stairs_{west_stair,entrance}.png`.
   - **Caveats:**
     - The collision is the solid ramp wedge for both looks, on purpose. Under
       the open stair it looks walkable but is blocked. A walk-under version
       would need a sloped-slab ramp and headroom rules.
     - Wall seams behind a stair don't follow its look. Making them follow
       (filled behind open wood) would need the stair to tell the seam sockets
       its pick, so it's left for later.
     - The candidates are dressing (layer 1 only), so floor decals don't mark
       stone steps.

**The weathering slice is complete (items 0-4).**

Deferred, on purpose: a material-level wear/grime shader and age-driven
overgrowth (phase 3, `AgeRules`); floor-cell garden sockets and the R05
courtyard (phase 5); stair *layout* variants as seeded sub-assemblies
(phase 2, with stair cells in generators).

**Known issues to keep in mind:**
- Saving a `kit/dressing/*.tscn` from the editor while a `ShelfFill` has run
  will store its generated MultiMesh in the file. Harmless, but it bloats the
  file; consider clearing `multimesh` before saving, or not exporting it.
- `VariantSocket` instances are internal children, so they don't appear in the
  Scene dock. That's intended (never saved), but it may surprise you.

