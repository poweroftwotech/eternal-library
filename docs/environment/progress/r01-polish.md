# Progress: the R01 polish slice (done 2026-10-19)

[Back to the front page](../../../ENVIRONMENT_PLAN.md)

**In short:** three groups. A: stairs (railings, walking under them, space claims, a stone build). B: growth where it grows (vines, new growth sets, root clumps). C: surface relief and floor wear in the kit materials.

---

### Next: the R01 polish slice (planned 2026-10-19, before phase 2)

**Why now:** the user's call. Getting the first room right makes later rooms
cheaper, because every fix lands in the kit, the sockets and the material
maps that R02 and later rooms reuse. None of the items below were in the plan
before. The phase 3 "wear/grime shader" is a different thing: that is
age-driven change over game time, not static surface relief. Each item is
reviewed in the editor before the next one starts.

**A. Stairs** (done 2026-10-19)
1. ~~**Masonry railing for the masonry look.**~~
   - The stair modules (`stair_gallery_8m`/`_r`, rev 2) now carry no visible
     mesh. They keep a walkable ramp slab, an invisible rail strip on the open
     edge (`__rail-colonly`, handrail height) and the snaps.
   - Each look brings its railing. Masonry: a sloped parapet, 0.2 m thick on
     the open edge, 0.85 m above the nosings, with a coping and a foot newel,
     all in `arch_stone` like the steps (rev 3: a brick body was tried first
     and didn't match the steps). Open wood keeps the wooden posts and
     handrail, moved over from the module.
   - The railing sits on the open side, so the looks aren't symmetric any
     more. The reversed stair's socket uses a mirrored set, `stair_style_r`
     (`stair_steps_masonry_r`, `stair_steps_open_r`), with the same labels
     and order, so a pin means the same look on either stair. The half-turn
     socket from item 4 is gone.
2. ~~**Walk under the open stair.**~~
   - The ramp is a 0.3 m slab (measured vertically) with the same top surface
     as before. The masonry look adds `__fill-colonly` under the slab (a
     dressing candidate with collision), so masonry stays solid.
   - Open wood has no collision of its own. Under its high end the capsule
     walks to the wall.
3. ~~**Claims.**~~
   - Candidates carry `CLAIM_` empties (Blender property `claim_size`).
     `kit_import` turns them into Marker3D nodes (group `kit_claim`, meta
     `claim_box` in Godot axes).
   - `RoomTemplate.resolve_sockets()` ends with `apply_claims()`: every other
     socket drops items whose origin is in a claim
     (`VariantSocket.claims()` / `release_claimed()`). A pending settle now
     checks a resolve counter, so a claim removal doesn't cancel the settle.
     In the editor, a socket change inside a room re-resolves the whole room,
     so claims follow the pick.
   - Masonry claims the whole 8 m wall base behind it (0.6 m high). Open wood
     claims its 1.6 m low end, where nothing fits under the slab.
   - Validate Room works the picks out statically (pin first, else the room's
     preview seed) and skips probe points and slots inside other sockets'
     claims.
   - The four "nothing" pins on the hidden seams and `pin_hidden_seams()` are
     gone.
   - **Verified:**
     - `kit_test` 572 (each stair and look: no own mesh, slab open underneath,
       socket set and placement, footprint, foot snap, railing on the open
       edge, collision only under masonry, one claim each).
     - `reading_room_test` 62 (both looks: routes, masonry solid underneath,
       capsule walks under both open stairs to the wall, seams behind the
       stairs cleared by masonry and present with open wood).
     - `validate_room_test` 25 (claims: 8 m for masonry, 1.6 m for open; the
       room validates clean either way).
     - `socket_modes_test` 157, spill 6, atmosphere 32, room playtest 11,
       camp playtest 43, the prototype atmosphere test, pin persistence and
       all three 240-frame gates pass.
     - GPU: `previews/reading_room_stair_{masonry,open}_{west_stair,stair}.png`.
   - **Caveat:** dressing candidates aren't on the decal layer, so the stone
     stair takes no floor decals (unchanged from item 4).
1b. ~~**A stone balustrade, not a solid parapet**~~ (user review 2026-10-19,
   done the same day).
   - `stair_steps_masonry(_r)` rev 4 (`kit_add_dressing.py`): the parapet and
     coping are replaced by `__plinth` (sloped, floor to 0.18 m above the
     nosings), `__balusters` (18 turned columns, one per tread, the prototype
     gallery's lathe profile with radii x0.85, sunk 7 cm into plinth and rail),
     `__handrail` (0.8-0.92 m above the nosings, flat over the top tread) and
     `__newels` (foot and head: square shaft, overhanging cap, ball finial).
     All in `arch_stone`. Collision is unchanged (module rail strip + fill).
   - Only the balustrade is kept. The solid parapet (rev 3) is in git history
     if a third look is ever wanted.
   - **Verified:** `kit_test` 588 (new: masonry has balusters, handrail and
     newels and no parapet; 18 separate balusters clear of the newels; newels
     at both ends; on the open edge), `reading_room_test` 62,
     `validate_room_test` 25, `socket_modes_test` 157, all three 240-frame gates.
   - GPU: `previews/reading_room_stair_balustrade_{stair,west_stair,stair_foot}.png`
     (new capture view `stair_foot`).
   - **Caveat:** the world-triplanar `arch_stone` map puts its mortar lines
     across the balusters as dark bands. It reads as turned rings at play
     distance; a plain-stone variant would need a separate material.

1c. **Masonry galleries on an arcade** (user request 2026-10-19). The
   galleries get a masonry look with the stair's stone balustrade. The heavy
   stone platform has to read as carried. The user chose an arcade on columns
   over wall-only arches.
   - **Look socket:** `gallery_style` on `gallery_slab_4m`,
     `_open_end`, `_open_start` and `gallery_end_12m` (masonry, wood). As
     with the stairs, the modules keep only collision (`__slab-colonly`,
     `__rail-colonly`, renamed in place so hand edits survive), and each look
     brings its visuals. Wood is today's slab and balustrade. Masonry is a
     stone slab, the stone balustrade (plinth, balusters on a 0.4 m pitch,
     handrail, corner newels) and the **arcade**: one arch per span along the
     open edge, brick spandrels and `arch_stone` voussoirs.
   - **Supports:** two new post modules stand at every column point.
     `post_gallery_column` carries one transverse arch to its wall and
     `post_gallery_column_corner` carries two, one to each wall. Both have a
     `gallery_support(_corner)` socket (masonry: column and arches with a wall
     respond; wood: nothing). The column is 0.5 m square at base and abacus
     with a turned shaft, centred 1.4 m from the wall line. All arches spring
     at 1.85 m (capsule 1.75 m). The arcade reaches 3.55 m: 4 m bays are
     round, shorter spans pointed. The transverse arches are stilted to
     3.3 m, so the pier corbels stay buried in their spandrels.
   - **One build per room:** `SocketSet.style_group`. Sets in a group share
     their entry order (0 masonry, 1 wood). The room picks one index per
     group from its seed, and every unpinned socket in the group takes it, so
     a gallery run never mixes stone and wood. stair_style(_r) joins the
     group. Pins still win. Validate Room follows the same rule.
   - **Stair heads:** a masonry stair's solid end carries the arcade's last
     arch. Its look gets a `head` claim, so the column placed there is cleared.
     An open wood stair keeps the column.
   - **Reading Room:** 8 support points: corners (1.4, -1.4) and (10.6, -1.4);
     sides x 1.4 / 10.6 at z -4 and -8; end wall x 4 and 8 at z -1.4
     (clear of the entrance arch). The galleries and supports are pinned to
     masonry. The stairs keep their pins (west masonry, east open wood).
   - **Done 2026-10-19.** How it landed:
     - Candidates in `kit_add_dressing.py`: `gallery_{wood,masonry}_{slab,
       open_end,open_start,end}` and `gallery_column(_corner)`. The masonry
       spandrels are brick, with `arch_stone` voussoir rings 2 cm proud. The
       stone slab is `floor_stone` with an `arch_stone` cornice on the edge.
       Spandrels and columns have collision. The arcade's 4 m bays come out
       round (crown 3.53 m). The 2.6 m spans and the wall arms are k 0.75
       arches stilted to 3.55 / 3.3 m.
     - `post_gallery_column(_corner)` are `free` modules whose origin is on the
       wall line (or the corner of two wall lines), so they sit on the grid like
       piers. The socket stands 1.4 m out. They draw nothing of their own.
     - The gallery modules' `__slab-col` / `__rail-col` were renamed in place
       to `-colonly` (`kit_add_r01.py` `RENAME`; `kit_seed_walls.py` seeds the
       new names). The masonry stairs are rev 5 with the `head` claim.
     - Style group: `SocketSet.style_group`, `RoomTemplate.style_picks()`,
       `VariantSocket.resolve(seed, room_pin, style_pick)`, and
       `KitValidateRoom._pick_of` follows it. Precedence: room pin, socket
       pin, group pick, own roll. `seed_sockets.gd` makes the six sets and
       puts all eight in `gallery_build` (masonry 2, wood 1).
     - Reading Room: 8 column points as text in the `.tscn`; the 5 gallery
       looks and 8 supports are pinned to masonry. The stairs keep their pins
       (west masonry, east open wood: an editor change by the user, committed
       with 1b), so the east stair-head column stands and the west one is
       claimed. `build_reading_room.gd` places the same 8 points, and
       `pin_masonry()` pins the whole group (checked with a fresh build to
       `user://`: 15 pins, KitValidate clean).
   - **Verified:**
     - `kit_test` 779 (new: each gallery module draws nothing but corbels and
       keeps its collision; set, group and order; wood without collision;
       masonry arcade spans the column points on the column line from 1.85 to
       3.85 m; supports on the wall line with the column 0-1.85 m and arches
       reaching the wall; masonry stairs claim 2 boxes).
     - `reading_room_test` 71: the first pass now pins both stairs to masonry
       explicitly. New: through the west and east arcades to the wall, under
       the end arcade to the entrance, and the stair-head columns are claimed
       by masonry and kept with open wood.
     - `validate_room_test` 25 (claim spans 0.6, 0.6, 8, 8).
     - `socket_modes_test` 196 (new sets; 12 seeds each build all 15 group
       sockets alike, both builds occur, and a pin beats the group).
     - Spill 6, room atmosphere 32, room playtest 11, camp playtest 43,
       prototype atmosphere 9, two-process pin persistence, and all three
       240-frame gates pass.
     - GPU: `previews/reading_room_masonry_gallery_{end_gallery,entrance,gallery,
       arcade,under_gallery,stair}.png`. New capture views: `arcade` and
       `under_gallery`.
   - **Caveats:**
     - Along the wall, the walkway under a gallery narrows to about 0.65 m at
       each column (base to pier or respond). The test capsule (radius 0.35)
       can't pass and the player (0.32) barely fits. Recesses are reached
       through the arcade instead.
     - The old `stair` capture view now stands beside the x 8 column, so it's
       mostly column. Use `arcade` or `entrance` for that side.
     - The wood look reproduces the old geometry, but it wasn't image-diffed
       against the pre-1c previews.
     - The `rail_growth` ivy still hangs on the stone handrails (item 4 removes
       those sockets).
     - **Fixed after review (user playtest):** the west slab over the side door
       (z -8..-4) walked as an invisible slab. Its look socket sits at the
       module origin, on the wall line at the stair head, which was the corner
       of the masonry stair's `under` claim, so the claim cleared the look and
       left the collision. `stair_claim()` now starts 0.1 m off the wall line
       (the seams it hides are 0.3 m out). Stair candidates are masonry rev 6
       and open rev 3. `reading_room_test` 73 adds "every gallery draws its
       look" in both stair passes; it fails on the old exports and names that
       slab. Capture: `previews/reading_room_1c_fix_arcade.png`.
     - Gotcha (again): new socket sets must exist before `kit_walls.glb`
       imports. After seeding, delete the module's `.godot/imported/<name>.glb-*`
       files and run `--import`, or the socket comes in without its set.

**A is complete (items 1-3, 1b, 1c).** Next session: B (growth), starting with item 4.

**B. Growth where it grows (matching the prototype's Reading Garden, `previews/garden_v011.png`)**
4. **No vines on the wooden gallery rails.** The `rail_growth` sockets are
   removed from the gallery modules. The set stays for reuse elsewhere.
   - **Done 2026-10-19.** `kit_add_r01.py` has a new `REMOVE_MARKERS` list
     (module, marker name prefix) that deleted the four `SOCKET_rail_growth__*`
     markers from `kit_walls.blend`. The ADD_MARKERS entries, the fresh-build
     markers and `rail_socket()` are gone, and `kit_seed_walls.py` no longer
     seeds one. `seed_sockets.gd` still makes `rail_growth`.
   - **Verified:** `kit_test` 775 (graybox 35 sockets), `reading_room_test`
     71 (no rail sockets), `validate_room_test` 25, `socket_modes_test` 195
     (the old rail-ivy check now asserts that no gallery module carries
     `rail_growth`), and all three 240-frame gates. The `growth` capture
     option pins ferns only. GPU: `previews/reading_room_b4_{entrance,
     gallery,end_gallery}.png` show bare balustrades. The garden's
     balustrade ivy comes back through `parapet_growth` (item 5).
5. **New growth sockets and candidates** (dressing family, swaying foliage
   material). They're built like the prototype's `arch_head_ivy`,
   `pier_ivy` and clinging `vine()`: a thin vine tube that traces the stone,
   dense ivy leaf clumps, and long hanging strands.
   - **`arch_growth`** over arches: `wall_arch_3m` (side doors, entrance) and
     the iwan arch. The vine follows the extrados, with clumps near the apex
     and strands hanging into the opening. Picks: nothing, light, heavy.
   - **`cornice_growth`**, an EDGE_SCATTER along the line where the walls meet
     the vault (the tile band at 8 m on the side walls). Curtains of ivy hang
     from the springing line, the "between ceiling and walls" look.
   - **`parapet_growth`** on the masonry stair parapet. The socket is pitched
     to the stair slope, and strands grow from a crack in the coping and hang
     down the open face. Only the masonry look carries it.
   - **Done 2026-10-19.** How it landed:
     - Candidates in `kit_add_dressing.py` (`growth_*`): `leaf` cards on
       `ivy_leaf` (swaying), a `vine` tube (`kit_blender.add_tube`, new
       `vine` library material from the px map), plus `clump`, `strand` and
       `clinging` helpers. `growth_arch_{3m,iwan}_{light,heavy}` trace the
       extrados (`arch_point` follows `arch_outline`). Counts and reach scale
       with the span. `growth_cornice_{short,long}` are 3 or 4 strand
       curtains. `growth_parapet_strands` and `growth_parapet_stair(_r)` are
       2-4 strands from a crack.
     - Sets (`seed_sockets.gd`): `arch_growth` and `arch_growth_iwan`
       (REPLACE: nothing 3, light 2, heavy 1; one set per arch size, like the
       stair looks), `cornice_growth` (nothing, short, long curtain),
       `parapet_growth` and `parapet_growth_stair(_r)` (nothing 4, strands 2).
       Their slots keep clear of the piers and the gallery soffit (3 m arches
       stop at 3.8 m, strands at 2.2 m above the floor).
     - Sockets (`kit_add_r01.py` ADD_MARKERS): `wall_arch_3m` and the iwan at
       the arch centre on the room face. The cornice sockets are on
       `vault_hall_12m`, not the wall modules, so they exist only where a
       hall vault springs (a lower-storey wall top is under the gallery). They
       sit at both springing lines and are turned so the strip runs along the
       bay, 1.35-2.65 m in, clear of the piers. Copings: the four gallery
       modules and both stairs on the handrail centre line, 0.35 m clear of
       walls and neighbouring lanes. The stair sockets are pitched with the
       slope (27.4 deg); their candidates are built level and turned back by
       the pitch, so strands hang plumb.
     - **Masonry gate:** a candidate can't carry sockets (spawned looks are
       internal children and `RoomTemplate.sockets()` doesn't see them). So
       the coping sockets live on the modules with the new
       `VariantSocket.needs_look = "masonry"` (Blender property `needs_look`):
       the socket spawns nothing unless a sibling socket picked an entry with
       that label. `RoomTemplate.resolve_sockets` resolves gated sockets after
       the rest. A module previewed on its own re-resolves gated siblings
       after its look changes, and `KitValidateRoom` skips the slot check when
       the look's pick (pin, group or roll) isn't masonry.
   - **Verified:** `kit_test` 851 (graybox 42 sockets; the iwan has arch
     growth), `reading_room_test` 71 (3 + 1 arches, 10 cornices, 7 copings),
     `validate_room_test` 25 (the room is clean with masonry and with open
     stairs), `socket_modes_test` 244 (new `check_growth`: every candidate is
     swaying ivy with a vine where it clings; masonry gives strands and wood
     none; stair strands hang plumb, under 0.75 m wide in world; the cornice
     sockets face the hall from 8 m), spill 6, room atmosphere 32, room
     playtest 11, and all three 240-frame gates.
   - GPU: `previews/reading_room_b5_growth_{entrance,gallery,end_gallery,iwan,
     west_stair,side_arch}.png` (capture option `growth` pins every growth
     socket to its heaviest pick; new view `side_arch`) and
     `reading_room_b5_{entrance,gallery}.png` (the default roll).
   - **Against `garden_v011.png`:** the iwan head, the coping strands and the
     cornice curtains read like the garden's arch ivy and gallery trailing ivy.
   - **Caveats:**
     - The ivy is darker than the garden's because lamplight is not daylight.
     - The leaves have no per-leaf tint (the prototype varies the colour per
       leaf; there are no vertex colours in the kit glTF yet).
     - The 3 m arches under a gallery can't grow above their apex (soffit at
       3.85 m), so their clumps stay on the haunches.
     - The default roll is sparse by design (weights favour nothing).
6. **Root clump for collapsed recesses** (the loose end from item 2). Roots
   push through the broken recess and creep over the fallen boards, using the
   same vine tube.
   - **Check:** GPU captures from the hall and the galleries, compared against
     `garden_v011.png` for density and how the growth reads. The validator
     covers the new slots.
   - **Done 2026-10-19.** The roots are part of the collapsed candidate's
     boards module, `recess_shelves_broken` (rev 5, rebuilt in place). A
     gnarled clump of six stubs bursts from a crack in the recess back above
     the top board. Two roots run down the back wall, over the top board and
     down the shelf fronts to the floor. A third creeps along the dropped
     board, downhill, and off its low end. They use `add_tube` with tapering
     radii and a new `wander` helper (subdivided, jittered along the wall),
     on `bark` like the prototype's garden roots (the `root` map read as
     striped rope). The runs over the two floor boards are part of those
     boards' `__spill` meshes (second material), so ShelfFill settles each
     root with its board onto a gallery slab or a stair. `board_top` and
     `dropped_top` keep the runs on the board surfaces.
   - **Verified:** `socket_modes_test` 246 (new: the collapsed fill has a
     bark root mesh and both spill boards carry wood + bark), `kit_test` 855,
     `reading_room_test` 71, `validate_room_test` 25 (the candidate still
     fits its slot and spill), spill 6, room atmosphere 32, room playtest 11,
     and all three 240-frame gates. GPU (capture option `collapse`):
     `previews/reading_room_b6_collapse_{roots,recesses,gallery}.png`, with
     a new close view `roots` on the lower west recess.
   - **Caveats:**
     - In an upper recess the spill boards (and their roots) rise 0.15 m onto
       the gallery slab, while the in-recess roots stay on the recess floor.
       So there is a small step at the slab edge, as the boards already had.
     - At hall distance the roots are a quiet accent; they read up close.
     - The floor runs are hard to see behind the book spill.

**B is complete (items 4-6).** Next: C (surface relief, items 7-9) or phase 2.

**C. Surface relief (shader-only: no collision change, no extra polygons)**
7. **Kit-only material maps.** The room maps (`brick`, `arch_stone`,
   `floor_stone`, `vault_plaster`) come from `tools/pixel_materials.py`, which
   needs Python and numpy, and the prototype shares them. The ashlar,
   flagstone and mottled generators get ported to the GDScript generator
   (`pixel_materials_ext.gd`) as kit variants (`*_kit`), so the prototype
   stays pixel-identical. Same palettes, texel scale and dithering.
   - **Done 2026-10-19.** `kit_room()` in `pixel_materials_ext.gd` writes
     `brick_kit`, `arch_stone_kit`, `floor_stone_kit` and `vault_plaster_kit`
     with `ashlar_kit`, `flagstones_kit` and `mottled_kit`, line-for-line
     ports of the .py generators (same palettes, parameters, Bayer dithering
     at 0.35, normals at strength 2). Godot's RNG isn't numpy's, so the block
     and flag layouts differ but read the same. Brick tiles at 72 texels
     (2.25 m, `uv1_scale` 0.444) so its 9-texel courses close; the .py's 64
     leaves a stray unjointed row at every 2 m seam. The four
     `kit/materials/*.tres` now load the `_kit` maps; the `.import` files copy
     the originals' settings (lossless, mipmaps, normal-map flag). Re-running
     the generator leaves every existing map byte-identical.
   - **Verified:** prototype `capture.gd` concept/paving/archive against the
     pre-change captures: mean diff 0.24/0.17/0.01 against run-to-run noise
     0.37/0.13/0.01 (within noise). `kit_test` 855, `reading_room_test` 73,
     `validate_room_test` 25, `socket_modes_test` 246, all three 240-frame
     gates. GPU: `previews/reading_room_c_{before,c7}_{relief_floor,
     relief_wall,arcade,vault,entrance}.png` (new views `relief_floor` and
     `relief_wall` in `reading_room_capture.gd`, which now also prints frame
     time over 240 frames, vsync off). Frame time 1.6-1.9 ms before and after.
   - **Caveat:** no relief yet, by design: the kit maps reproduce the flat
     look so item 8 starts from a like-for-like base.
8. **Relief baked into normal and roughness.** Pixel rule: each texel keeps
   one flat colour; relief comes through light.
   - **Flagstones:** each stone tilted a few degrees, with dished wear at
     centres, chipped arrises, deeper joints and a few sunken or raised stones.
   - **Brick and ashlar:** per-block bulge or inset, recessed mortar,
     spalled faces.
   - **Plaster:** low-frequency trowel undulation.
   - **Roughness:** polished walking lines down the hall and around the
     tables, glossier at the joints where damp collects, matte where dry.
     Lantern light then gives the specular glints the room lacks.
   - Higher `normal_scale` for the kit materials. Damp floor decals get an
     ORM map (lower roughness), so damp patches catch the light.
   - **Done 2026-10-19 (walking lines moved to item 9).** All relief comes
     from a second RNG (`seed + 11`), so the item 7 albedo is unchanged.
     - **Flagstones:** each stone tilts 1.7-4 degrees in a random direction,
       is dished 0.08-0.3 at the centre, and one in ten sinks (one in fourteen
       rises). Joints sit deeper (-0.25), arrises are rounded and chipped
       where a 2-texel noise passes 0.72. Roughness: joints 0.42-0.52 (damp),
       arrises 0.6-0.7, chipped arrises 0.95, faces 0.8-0.95 polished down by
       up to 0.45 in the worn dish.
     - **Brick and arch stone:** each block bulges up to 0.3 or sits up to
       0.12 inset (a dome falling to 0 at the arrises), mortar is recessed to
       -0.1, arrises are rounded and 5-texel spalls (noise > 0.74) are cut
       0.2 deep. Roughness: mortar 0.9+, spalls and chips 0.97, faces ±0.05
       per block, smoother on proud crowns.
     - **Plaster:** a 0.5 m (16-texel) two-octave swell at 3x the grain, with
       the crests smoother than the hollows (±0.1 roughness).
     - The four kit materials go from `normal_scale` 0.55 to 1.0.
     - `damp_floor_orm.png` (written by `damp_floor()`): AO 1, metal 0,
       roughness 0.05-0.3 in the patch (wettest at the centre) and 0.7 on the
       salt rim. `kit/decals/damp_floor.tscn` sets it as `texture_orm`.
   - **Verified:** prototype concept/paving/archive mean diff 0.23/0.13/0.004
     (noise 0.37/0.13/0.01). Every existing map and decal stays
     byte-identical. `kit_test` 855, `reading_room_test` 73,
     `validate_room_test` 25, `socket_modes_test` 246, all three 240-frame
     gates. GPU: `previews/reading_room_c_c8_{relief_floor,relief_wall,
     arcade,vault,entrance,relief_damp}.png` against `_c7_` / `_before_`,
     and `reading_room_c_c8_damp.png` (new capture option `damp`, new view
     `relief_damp` on the floor-wear socket at (10, -2)). Frame time is
     unchanged: 1.63-1.95 ms before and after.
   - **Caveats:**
     - **Walking lines:** they can't go in a tiling map, because the map
       repeats every 2 m wherever the floor is. Polished paths down the hall
       and around the tables need world position, so they move to item 9's
       world-space roughness. For now the polish is per stone (the worn
       dish).
     - **Glints:** specular glints are rare. Lanterns hang at the walls or
       stand on the floor, so few views put a light opposite the camera. The
       relief shows mostly as per-stone shading and darker joints.
     - **Vault:** the vault swell is soft at hall distance, because the
       vault is lit steeply from below.
     - **Damp decal:** the gloss is hard to see in the captures. The decal
       blends its ORM by its albedo alpha (0.25-0.5 in the patch), so the
       salt rim reads more than the sheen.
9. **Optional macro variation.** If tiling still shows: a kit ShaderMaterial
   (world triplanar like now) that adds world-space tint and roughness
   variation, snapped to the 32 tx/m grid so it stays pixel-art.
   - **Done 2026-10-19, with the walking lines from item 8.**
     - **Shader:** `shaders/kit_px_world.gdshader` is a hand port of the
       StandardMaterial3D world-triplanar path (same tangent frame,
       `vec3(1, -1, 1)` flip, nearest-mipmap-anisotropic sampling, roughness
       from R, specular 0.65). The four kit `.tres` are now ShaderMaterials
       with the same maps and `uv1_scale`. With the extras off it matches
       item 8 within noise (mean diff 0.27-0.44).
     - **Macro tint and roughness:** value noise at 1.5 m and 5 m, read at
       the centre of each 32 tx/m texel. It is quantised to ±4 steps with a
       4x4 Bayer on the face's texel grid, so a texel stays one flat colour.
       Darker steps lean warm. Strength ±0.12 on brick, arch stone and
       floor, ±0.08 on the vault plaster. A third noise varies roughness by
       ±0.12 (±0.08 on the vault).
     - **Walking lines:** `FloorWear` (`scripts/world/floor_wear.gd`) bakes
       an R8 wear map at 32 tx/m on `_ready` (67 ms for R01's 12 x 20 m). It
       hands the map to the shader through three new project shader globals,
       `kit_wear_map`, `kit_wear_rect` and `kit_wear_y`. The map holds
       authored polylines with weights, plus a lighter ring around each
       `ring_nodes` footprint (the four tables), broken up by noise and
       dithered to 4 steps. `floor_stone` (`wear_strength` 1) blends toward
       roughness 0.3 and darkens 5 % on full wear, on up-facing texels inside
       the rect and the y range only, so the galleries stay unworn. A room
       without a FloorWear has no wear (the rect stays zero), and leaving the
       tree clears it.
     - **R01's paths:** both lanes beside the rug (x 4 and 8), the entrance
       and iwan aprons, spurs to both side doors around the tables, and both
       stair feet.
   - **Verified:**
     - `reading_room_test` 79 (new: the wear map is baked, both lanes are
       worn, there's no wear mid-rug, and `floor_stone` takes wear),
       `kit_test` 855, `validate_room_test` 25, `socket_modes_test` 246,
       and all three 240-frame gates.
     - Prototype mean diff 0.23/0.12/0.004 (noise 0.37/0.13/0.01).
     - GPU: `previews/reading_room_c_c9_{relief_floor,relief_wall,arcade,
       vault,entrance,relief_damp,relief_lane}.png`, plus
       `reading_room_c_c9_relief_lane_nowear.png` (same view, wear off). New
       view: `relief_lane`.
     - Frame time 1.66-1.99 ms (item 8: 1.63-1.95), about +0.03 ms.
   - **Caveats:**
     - **Wear look:** worn lanes read as smoother and slightly darker, with
       an odd glint, not as a bright sheen. Glints need a lantern opposite
       the camera, and few views have one.
     - **Macro tint:** it is subtle at hall distance. It shows most on the
       vault and on long brick runs.
     - **FloorWear limits:** paths are authored per room (phase 2 will need
       to generate them from connectors and furniture). The room may move
       but not turn, and only one room's wear is live at a time. (Phase 2
       slice 4 lifts the last two, and generated rooms get their lanes from
       the grammar.)
     - **Editor:** wear only shows at runtime; the editor viewport has none.
   - Parallax is out for now: `StandardMaterial3D` height maps don't work
     with world triplanar. A custom triplanar parallax shader is a later
     option if relief is still too flat.
   - **Check:** before/after GPU captures with grazing lantern light (floor,
     walls, vault), and image_diff of the prototype (must stay within noise).
     Frame time is reported.

**Suggested order:** A (stairs: 1, 2, 3), then B (growth: 4, 5, 6), then C
(relief: 7, 8, 9). C is independent, so it can move first if the flat look
matters most. Phase 2 (generated R02) starts after this slice.

**The R01 polish slice is complete (A, B, C).**

