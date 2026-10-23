# Progress: phase 5, kit breadth

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../phase-5-approval.md), [technical](../phase-5-design.md)

**In short:** steps 1 to 3 are done and committed (the cistern's water is being
brightened). A new area, the Lower Stacks, starts in a
generated Hypostyle hall: a grid of bays under small tiled domes on twisted
columns, freestanding bookcases between them, and clear aisles from every
door to a landmark under an oculus. Generated galleries lead off its doors.
In step 2 the hall grows to 10 × 10 bays, with brass lamp clusters and the
odd collapsed bay, and it still runs at the base-spec frame target. In step
3 one gallery leads to a flooded cistern: a causeway to a sealed bronze door,
shallows you wade at half speed, deep water that stops you, and platforms of
book crates, under the Reading Garden's water.

---

## Step 3: the Cistern Archive (done 2026-10-23, walked in the game by you and committed; the water too dark, being worked on)

**Try it:** Esc → **Walk the Lower Stacks** (or `-- --area=lower_stacks
--area-seed=1`). One of the galleries off the hall leads to the cistern
(19 seeds in 20 have one; seed 2 doesn't).

- Walk the causeway from the door to the sealed bronze door at the far end,
  a lantern on each side of it. The door doesn't open.
- Step off the causeway anywhere: its sides slope into the water. In the
  shallows (the water's surface 0.4 m below the causeway, the bed 0.9 m
  down) you wade at half speed.
- Deep bays (the bed 2 m down) stop you at their edge.
- Timber platforms of book crates stand in the water between the piers.
  You can't climb onto them.
- Lanterns hang over the causeway and out over the water every second bay.

Pictures (seed 1, Medium, 1920 × 1080): `previews/p5_step3/r11_1_*.png`
(entry, door, across, wading, platform).

**Built:**

| Piece | File |
|---|---|
| Nine new kit pieces: the shallow and deep water bays (each carries its water surface; the deep one a wall only the player meets), the causeway (a 1.6 m path whose sides slope into the shallows), a quay, the wall below the floor along the water, a square brick pier standing in the water, a plain brick dome, the platform of book crates, and the sealed bronze door with its two lanterns | `tools/kit_add_r03.py`, `art_src/kit/kit_hall.blend` |
| The water is the Reading Garden's water (`shaders/water.gdshader`: pixel ripples, the bed seen through it, darker with depth), held still | `kit/materials/cistern_water.tres` |
| Import rules: a `*wade_stop` collision goes on a new physics layer only the player meets (8, `player_blockers`); a water piece's floor is marked for wading; the water's surface casts no shadow | `tools/kit_import.gd`, `project.godot` |
| `CisternGrammar` (extends the hall's): the causeway, shallow and deep bays (the bays beside the causeway always shallow; any shallow bay you couldn't wade to made deep), platforms off the bays along the walls, the sealed door, the wall below the floor, lanterns on a lattice; each bay keeps its floor height | `scripts/gen/cistern_grammar.gd`, `gen/grammars/r11_cistern.tres`, `gen/rules/r11_cistern.tres` |
| The player wades at `wade_speed_factor` (0.5) on a water floor, and collides with the deep-water walls | `scripts/player.gd` |
| The Lower Stacks grows one cistern off a gallery (`room_count` 5–7; recipe version 3) | `gen/recipes/lower_stacks.tres` |
| Small shared changes: a cell's floor can run across the room (`floor_run`); each grow entry numbers its own rooms (`cistern_1`); a generated room's safety floor is 2.5 m down (it reached under the cistern beside a gallery); Validate Room ignores walls only the player meets | `room_builder.gd`, `area_planner.gd`, `generated_room.gd`, `kit_validate_room.gd` |

**"Little new code":** the cistern's grammar is 128 lines (99 without
comments and blank lines); the shared changes above, wading included, are
about 30 more. Under the 150-line target.

**What changed from the design, and why:**

- **No WaterPlane node.** Each water piece carries its own surface, and the
  wading check is a mark on the floor's collision, so there is no water
  area to keep in step with the room.
- **Two depths, not a depth per bay.** The player can't climb steps, only
  slopes, so the beds are at two fixed heights the causeway's sides reach:
  shallow (0.9 m, you wade) and deep (2 m, blocked).
- **No kerbs on the causeway:** they would stop you wading in.
- **The causeway's sides slope at 37 degrees.** The first try (42) was too
  steep: the test capsule stalled at the lip.
- **Platforms are blocked**, like the hall's bookcases, and stand only
  between the piers, not in the bays along the walls (the wall recesses'
  spilled books would land on them).
- **The bronze door has no states yet** (sealed, forced, open); it is
  simply sealed.
- **The cistern is a dead end** off a gallery: no side doors, so no quays
  are used yet (the piece is ready for one).
- **The pieces are in `kit_hall.blend`** with the hall's, not a new
  `kit_water.blend`.
- **The cistern is pinned** (always live once the Lower Stacks is, like the
  hall). It is a column hall of its own, 2,000 nodes against a gallery's 700,
  and joining the scene in one frame cost 5–6 ms, which put the frame gate
  over its 8 ms limit by up to 0.8 ms on that frame in all three runs. A grow
  entry can now be pinned (`AreaGrow.pinned`). The light-well (step 4) will be
  as big; it will need a room's entry spread over frames instead.
- **A big room's modules are built a frame's budget at a time while it
  streams** (`RoomBuilder.plan()` then `place()`; `GeneratedRoom`'s
  `begin_planned_modules` / `build_planned_step`). Every gallery still comes
  out module for module the same (`gen_signature_test`).
- **Generated rooms' safety floors are 2.5 m down** (they were 0.25 m down,
  and reached 4 m under the cistern beside a gallery, holding the capsule
  above the shallows).
- **The recess check in `area_route_test` tests vertices, not just bounds**:
  a gallery fern behind the cistern's wall was flagged only by its box.

**Found on the way: step 2's lamp clusters had the plain lantern's light.**
The cluster piece was first imported before its "cluster" light (brighter,
8.5 m) was picked up, and nothing re-imported it, so in step 2's pictures
and frame gate each cluster lit like one lantern. It's re-imported now (the
light comes from the import, so a fresh checkout gets it right); this step's
frame gate ran with the real cluster lights.

**Gates:**

- `r11_layout_test` (new): 19 cisterns as the planner lays them out and 20
  standalone. **7,874 checks pass.** The causeway runs entry to far wall;
  the sealed door is in line with the entry; the bays beside the causeway are
  shallow; every open bay can be waded to; deep bays and platforms are
  blocked; no platform along the walls.
- `r11_route_test` (new): in the Lower Stacks' cisterns (seeds 1–5 but 2,
  which has none) every bay's floor is at its height; a capsule like the
  player's walks the causeway to the sealed door, which blocks, wades a tour
  of every open bay with its feet on the bed, and can't walk into any deep
  bay or platform; the real player walks the causeway at 3.7 m/s and wades
  at 1.85 m/s. **37 checks pass.**
- **The frame gate** on the Lower Stacks seed 90 (the 10 × 10 hall, a
  cistern, 7 rooms, 464 m): **three runs in a row pass.** Worst frame
  7.4–7.8 ms (limit 8), mean 1.5 ms; GPU worst 2.2–2.5 ms; 471 draw calls;
  shadowed lights 2; lights in reach 48 (limit 48). Before the cistern was
  pinned, all three runs failed by one frame (8.1–10.3 ms) as it streamed in.
- `area_route_test` 383 checks and `stream_test` 80 checks (both areas;
  the cistern's walks wade, and the walk reaches the gallery it grows from),
  `area_plan_test` 246, `r03_layout_test` 11,001, `r03_route_test` 46;
  `persist_gate.sh` **all nine processes pass**.
- Every earlier gate passes: `gen_signature_test` 103 (every gallery
  unchanged after the builder split), `kit_test` 1,219 (the deep-water walls
  on layer 8), `prop_test` 51 (the player also meets layer 8),
  `r02_route_test` 2,321, `r02_bake_test` 105, `book_test` 27,
  `room_playtest` 31, `reading_room_test` 87, `validate_room_test` 26,
  `socket_modes_test` 246, `age_test` 20, camp `playtest` 43,
  `atmosphere_test` 9, `room_atmosphere_test` 32; 240-frame runs clean for
  the camp, `--area=library` and `--area=lower_stacks`.

**Caveats, for your review:**

- **The water's ripples are still.** The Reading Garden animates its water
  from its own atmosphere script, which the Lower Stacks doesn't run; in the
  cistern the ripples are frozen (still water suits a cistern, but a slow
  shimmer would need a small driver).
- **The cistern is dark away from its lanterns**, as the atlas has it; the
  water shows mostly as glints and near the lanterns.
- **Changes you saved in the Lower Stacks while walking step 2 went stale**
  (the recipe is version 3 now): kept in the save, never applied, as the
  phase 4 design says.
- The bronze door has no states yet, and the cistern has no side doors.

---

## Step 2: the big hall (done 2026-10-23, walked in the game by you and committed)

**Try it:** Esc → **Walk the Lower Stacks**, then Esc → **Reseed the Lower
Stacks** until you get a big hall (each side is 6–10 bays, so a full 10 × 10
comes up about one time in 25). Or start the game with
`-- --area=lower_stacks --area-seed=90` (10 × 10, great lamp) or
`--area-seed=68` (10 × 10, catalogue desk, four collapsed bays).

- **Lamp clusters:** a big lantern with three small ones on a brass crown
  hangs from every third dome, counted both ways from the landmark. Single
  lanterns still hang over the aisles and the walk round the walls where no
  cluster hangs.
- **Collapsed bays:** about one bay in 16 off the aisles has lost its dome.
  A heap of masonry, brick and tile fills the bay and you can't climb it;
  look up and you see the broken foot of the dome and the dark brick shaft
  it left. A collapsed bay is never on an aisle, on the walk round the
  walls or by the landmark, and never cuts another bay off.
- **The landmark** is one of three (great lamp, reading tree, catalogue
  desk), picked by the seed (step 1 already had this).

Pictures (Medium, 1920 × 1080), seeds 90 and 68: `previews/p5_step2/r03_<seed>_*.png`
(entry, diagonal, aisle, domes, landmark, and the new collapse and cluster
views).

**Built:**

| Piece | File |
|---|---|
| Three new kit pieces, added to `kit_hall.blend` by the seed script: the lamp cluster (one light for its four lanterns), the fallen dome (the slab's ring, a broken stub of the dome and the shaft, closed at 9.6 m) and the rubble heap (one box of collision 1.2 m high) | `tools/kit_add_r03.py`, `art_src/kit/kit_hall.blend` |
| A warm "cluster" light (a little brighter and wider than a lantern, no shadow) | `tools/kit_import.gd` |
| The hall's rules map the three new slots (`lamp:cluster`, `cell:dome_fallen`, `dressing:rubble_heap`) | `gen/rules/r03_hall.tres` |
| `HypostyleGrammar`: sizes up to 10 (`size_max`), `lamp_cluster_every` (3), `collapse_chance` (0.06); the check that no bay is cut off now covers heaps as well as bookcases. Bays a walk must go round (a case, a heap, the landmark) are marked "blocked" | `scripts/gen/hypostyle_grammar.gd` |
| The plan keeps each room's blocked bays, so walks in the tests go round them | `scripts/world/area_plan.gd`, `scripts/world/area_planner.gd` |
| The shared test route starts in any root room: R01's door spots as before, or a generated root's first bay, through its bays to the door | `tests/area_tour.gd` |
| `stream_test`, `area_route_test` and `area_plan_test` run on both areas; `area_walk_capture` takes `--area=`; `persist_gate.sh` adds the Lower Stacks' save and load processes (nine in all) | `tests/` |

**Gates:**

- `r03_layout_test`: 40 halls. **11,001 checks pass.** 55 collapsed bays in
  31 of the 40 halls, 274 clusters, the widest hall 10 bays; 69% of the free
  bays hold a bookcase (`case_density` 70%).
- `r03_route_test`: as step 1, and walking into any collapsed bay from any
  neighbouring bay is blocked. **46 checks pass.**
- **The frame gate** (`area_walk_capture --gate`, Medium, 1080p) on the
  Lower Stacks seed 90 (a 10 × 10 hall, 6 rooms, 392 m walked): **four runs
  in a row pass.** Worst frame 6.0–6.7 ms (limit 8), mean 1.3 ms (limit 4);
  GPU worst 1.8–2.1 ms (limit 4); **draw calls at most 443** (limit 1,500);
  shadowed lights 2 (limit 4); lights in reach 48 (limit 48). Seed 274
  (another 10 × 10 hall, 528 m) also passes: worst frame 6.6 ms, 483 draw
  calls, 39 lights in reach.
- `stream_test` 80 checks, `area_route_test` 358 checks and `area_plan_test`
  246 checks, both areas; `persist_gate.sh` **all nine processes pass**
  (the Lower Stacks pair: a book pulled from a hall shelf, a book dropped and
  a lamp tended in the farthest gallery, ten years let pass; all back after
  a restart).
- Every earlier gate passes: `gen_signature_test` 103 (every gallery
  unchanged), `kit_test` 1,101, `r02_bake_test` 105, `book_test` 27,
  `prop_test` 51, `room_playtest` 31, `reading_room_test` 87,
  `validate_room_test` 26, `socket_modes_test` 246, `age_test` 20, camp
  `playtest` 43, `atmosphere_test` 9, `room_atmosphere_test` 32,
  `r02_route_test` 2,321; 240-frame runs clean for the camp,
  `--area=library` and `--area=lower_stacks`.

**Batching (design 5.6.3) isn't needed.** A 10 × 10 hall peaks at 443 draw
calls in all passes, under a third of the budget: Godot 4.7's renderer
already merges repeated meshes. The batching step was left out; the design's
fallback (capping the hall at 8 × 8) isn't needed either.

**"Little new code":** the hall's grammar grew by 46 lines (383 in all, 293
without comments and blank lines). The shared changes are 5 lines (the plan
keeps blocked bays) plus 2 for a new upload statistic in the floor wear.

**What changed from the design, and why:**

- **No batching** (above).
- **A collapsed bay can't be entered.** The design said "a bay of rubble";
  the heap fills the bay, so the walk round it is checked like a bookcase's.
- **Clusters replace single lamps** where both would hang, and none hangs
  over a collapsed bay, so a big hall has about as many lights as before
  (the lights-in-reach limit is 48).
- **The frame gate no longer charges the test's own light count to the
  game.** It counts every light in reach by walking every node in the area
  each 15th frame; in a 640-module hall that walk took up to 5 ms and showed
  up as a slow frame. It is now timed and taken off the frame it lands in.
- **The persistence test records a dropped book as the save does:** where
  it lies at quit (the root room) or as its room's unload stored it (the far
  gallery). Before, it was recorded straight after the drop, and a book
  still settling against the clutter at a wall's foot then failed.

**Caveats, for your review:**

- **The collapsed bays are dark.** The shaft over a fallen dome is unlit,
  so from the floor it reads as a black hole in the ceiling, and the heap
  under it is hard to make out (`r03_*_collapse.png`). A faint cold light in
  the shaft, like the oculus's, would show both; it adds a light per
  collapsed bay. You walked it and chose to keep them dark.
- **Lights in reach hit the limit (48) once** on seed 90, where most lamps
  rolled lit. GPU time there was 2 ms of 4. If a bigger hall goes over, the
  first knob is `lamp_every_bays` along the walls.
- **One run of the frame gate on seed 90 failed** before the four that
  passed, by one 8.5 ms frame a moment after a gallery loaded (the same spot
  measured 6.0–6.2 ms in every other run). It's the kind of single slow frame
  the RTX 3060 estimate (twice the dev machine's CPU time) is sensitive to,
  so a frame gate on a real base-spec machine is still worth doing.
- **Found while testing, not fixed:** a book pulled from a shelf can keep
  rocking against the clutter at a wall's foot for a while after it lands,
  so its saved angle can differ by a few degrees from where it first came to
  rest. It's from phase 3's book physics, not this step.
- Big halls are rare by chance (one in 25 is 10 × 10). If you want big
  halls more often, the knob is `size_min` in `gen/grammars/r03_hypostyle.tres`.

## Step 1: a hall of columns (done 2026-10-22, walked in the game by you and committed)

**Try it:** Esc → **Walk the Lower Stacks** (or start the game with
`-- --area=lower_stacks`). You start in the hall's entry bay, facing in.

- Walk to the centre: every door's aisle leads straight there. The landmark
  is a great lamp, a reading tree or a catalogue desk, picked by the seed.
- Walk round the walls: the outer ring of bays is always clear, with shelf
  recesses in the walls as in the galleries.
- The bookcases have books on both faces. Pull one, as in the Reading Room.
- Leave through any door into a gallery.
- Esc → **Reseed the Lower Stacks** for another hall (6 × 6 to 8 × 8 bays).

Pictures (seed 1, Medium, 1920 × 1080): `previews/p5_step1/r03_1_*.png`
(entry, diagonal, aisle, domes, landmark).

**Built:**

| Piece | File |
|---|---|
| The builder follows the grid: a cell's floor and ceiling slots, its gables, a slot on an open edge (an arcade), posts on any corner (columns), and dressing placed in the shell (the upper wall band). Unset, everything falls back to the gallery's old behaviour | `scripts/gen/room_builder.gd`, `scripts/gen/cell_grid.gd` |
| Rule slots are free names; a slot's module shape comes from its prefix (`edge:`, `cell:`, `post:`, else free) | `scripts/gen/module_rule.gd`, `module_rules.gd` |
| `HypostyleGrammar`: the hall's size (fitted beside its neighbours), doors (one per wall, none in line with the entry), aisles to the landmark, the clear walk along the walls, bookcases (any that would cut a bay off are taken out again), columns, arcades, domes and the oculus, lamps over the aisles and the wall walk, and worn lanes along the aisles | `scripts/gen/hypostyle_grammar.gd`, `gen/grammars/r03_hypostyle.tres`, `gen/rules/r03_hall.tres` |
| 13 new kit pieces, seeded by a Blender script into a new `kit_hall.blend` (yours to edit from now on): twisted column, hall pier and pier top, arcade arch, upper wall band, two domes (tiled, plaster), the oculus (with a cold light), a lantern on a chain from a dome, the freestanding bookcase, the landmark plinth, the great lamp and the catalogue desk | `tools/kit_add_r03.py`, `art_src/kit/kit_hall.blend` |
| Socket sets: the bookcase's books (full, sparse) and the landmark (great lamp, reading tree — the Reading Room's iwan tree — or catalogue desk) | `kit/sockets/case_library.tres`, `kit/sockets/hall_landmark.tres`, `kit/dressing/case_books_*.tscn` |
| A generated room can be an area's root: its entry is an exit like the others, and a visit starts in its first bay | `scripts/world/area_planner.gd`, `scripts/world/area.gd` |
| The Lower Stacks recipe, on the Esc menu, with the menu's areas and reseed generalised | `gen/recipes/lower_stacks.tres`, `scripts/main.gd` |
| A freestanding bookcase's books can be pulled (the shelf reach box works in front of a divider as well as behind a wall line) | `scripts/world/shelf_fill.gd` |

**Gates:**

- `gen_signature_test` (new): every R02 gallery, 50 standalone and every
  gallery of library wings 1–10 (102 rooms), comes out module for module,
  rotation included, as before the builder changed. **103 checks pass.**
- `r03_layout_test` (new): 20 halls as the planner lays them out and 20
  standalone. **1,788 checks pass.** 69% of the bays off the aisles hold a
  bookcase (`case_density` 70%).
- `r03_route_test` (new): the real player capsule walks every clear bay of
  five halls and out through every door into the gallery beyond; every
  bookcase can be passed along both sides and none walked through; the hall
  validates clean. **44 checks pass.**
- Every earlier gate passes: `area_plan_test` 145, `area_route_test` 203,
  `stream_test` 40, `r02_route_test` 2,321, `r02_bake_test` 105,
  `book_test` 27, `prop_test` 51, `room_playtest` 31, `reading_room_test`
  87, `validate_room_test` 26, `kit_test` 1,060 (it caught the domes
  without collision at first; their ceiling slabs now have it),
  `socket_modes_test` 246, `age_test` 20, camp `playtest` 43; 240-frame
  runs clean for the camp, `--area=library` and `--area=lower_stacks`.

**The draw-call measurement (design 5.6.3):** a 7 × 7 hall costs 43–109
draw calls a view (450–930 objects): Godot 4.7's Forward+ renderer already
merges repeated meshes. A 10 × 10 hall should stay well under the 1,500
budget, so **step 2's batching probably isn't needed**; step 2 will confirm
it on the largest hall with the frame gate.

**"Little new code":** the hall's own code is 337 lines (260 without
comments). The one-time changes to shared code (builder, rules, planner,
menu) are 61 lines.

**What changed from the design, and why:**

- **R02's grammar didn't change.** The builder's new options all default to
  what it did before, which is safer than rewriting the gallery grammar,
  and the signature test proves nothing moved.
- **One Blender file for the hall** (`kit_hall.blend`) instead of separate
  vaults and columns files.
- **The walk along the walls** (`wall_aisle`, on by default): bookcases
  stood where wall recesses spill books and rubble, and the atlas plan has
  that walk anyway.
- **Lamps over the wall walk too:** with lamps only on the aisles, the
  corners and wall recesses were nearly black.
- **The reading tree is the Reading Room's iwan tree**, reused as is.

**Caveats, for your review:**

- **Look review (2026-10-22, your choices; settled and committed):** the columns read as stacked
  blocks, so they now have 8 flutes turning a third of a turn up the shaft
  (rev 3: rev 2 turned half a turn with deeper flutes and looked busy up
  close, so you asked for it softened). The plaster domes were dark, so they now
  use a paler plaster (`kit/materials/dome_plaster.tres`, through a new
  `albedo_scale` on the kit shader, 1 for every other material) with a tile
  band at the foot. Both pieces were remade in place by
  `tools/kit_add_r03.py` (column rev 3, dome rev 2). Before and after: `previews/p5_step1/` and
  `previews/p5_look/`.
- The Lower Stacks' galleries are ordinary R02 galleries with the wing's
  look and the wing's atmosphere; a deeper look for the Lower Stacks is
  later.
- ~~`stream_test`, the frame gate and the persistence gate still walk only the
  library wing~~: done in step 2; they walk the Lower Stacks too.
