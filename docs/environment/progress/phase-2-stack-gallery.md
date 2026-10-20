# Progress: phase 2, the generated Stack Gallery (done 2026-10-20)

[Back to the front page](../../../ENVIRONMENT_PLAN.md)

**In short:** slices 1–4 (corridor, turns, alcoves/collapses/lamps, bake and floor wear), the loose ends closed before phase 3, and slice 5 (galleries on all three R01 doors without overlapping).

---

### Phase 2: generated R02 Stack Gallery (design drafted 2026-10-19; slices 1-4 done)

The design is §5.5, approved by the user 2026-10-19.

**Slice 1 done (2026-10-19): a straight corridor off R01's west door.**

**Try it:** Esc menu → **Visit the stack gallery**, then **Reseed the stack
gallery** (the menu shows the current seed). Or start with
`-- --room=res://rooms/test/reading_room_r02.tscn --gen-seed=7`. In the
editor, open `rooms/test/reading_room_r02.tscn`, select `StackGallery`, and
use **Generate**, **Reseed**, `gen_seed` or **Overlay**. Editing
`gen/grammars/r02_stack_gallery.tres` (e.g. `max_bays`) or
`gen/rules/r02_brick.tres` (wall weights) regenerates live.

| Piece | File |
|---|---|
| Cell grid, edge marks, transforms, layout check, signature | `scripts/gen/cell_grid.gd` |
| Rules: slot + styles → weighted module scenes, with a shape check | `scripts/gen/module_rules.gd`, `module_rule.gd`, `module_choice.gd` → `gen/rules/r02_brick.tres` |
| Grammar base and R02 (length, lamps, dead end or exit) | `scripts/gen/room_grammar.gd`, `stack_gallery_grammar.gd` → `gen/grammars/r02_stack_gallery.tres` |
| Grid → modules: floors, vaults, edges, gables, piers (none on the host's wall line), lamps; picks keyed by slot + grid key | `scripts/gen/room_builder.gd` |
| The room: join, host blockers, build, connectors, safety floor, inherited style groups, resolve, overlay, Generate / Reseed | `scripts/gen/generated_room.gd` |
| R01 + gallery (inherits `reading_room.tscn`, which is untouched) | `rooms/test/reading_room_r02.tscn` |
| Data seeding (writes only missing files) | `tools/seed_gen.gd` |
| Game: visit, reseed, `--gen-seed=N` | `scripts/main.gd` |

**Phase 1 changes:** `RoomTemplate.sockets()` and `KitValidateRoom` stop at a
nested room. `RoomTemplate` gains `style_overrides`, `style_choice()` and
`current_seed()`, which Validate Room now uses for its static picks (unchanged
for authored rooms). A connector with meta `host_closes` closes its whole bay
and its vault end.

**As built, vs §5.5:** generated nodes are unowned rather than internal
(§5.5.1). Host posts don't block cells: R01's pier corbels reach 0.85 m into
the corridor's first cell, and the first run found nothing to place. Lamps sit
at 2.0 m, so `lantern_hanging`'s chain top meets the crown (intrados measured
at 6.01 m); no long-chain lantern is needed. With the default grammar
(6-12 bays, a lamp every 2nd bay, dead end), seed 1 is 10 bays: 67 modules
and 44 sockets (recesses, lamp states, stains, floor wear, seams, soot).

**Verified:**
- `tests/r02_route_test.gd`, 304 checks. The rules check (and a floor
  offered for a wall is caught). Then for each of seeds 1-20:
  - the layout check, lengths within 6-12, and the lamp count;
  - Validate Room clean (no errors or warnings) and KitValidate on the
    corridor, R01 still error-free with exactly its own 106 sockets;
  - regenerating gives the same build, and the entry meets R01's west door
    face to face;
  - floor collision under every cell, both side walls block in every bay,
    the dead end blocks;
  - a capsule walks from R01 to the end of the corridor and back.

  Across the 20 seeds, at least 18 builds differ (the test's bar), and all
  7 lengths from 6 to 12 occur.
- `room_playtest` 18 (new: `main` boots R01 + gallery at seed 3, and the real
  player walks from the spawn to the end of the 12-bay gallery and back,
  never below the floor; the menu offers a reseed).
- `kit_test` 855, `reading_room_test` 79, `socket_modes_test` 246,
  `validate_room_test` 25, spill 6, room atmosphere 32, camp playtest 43,
  prototype atmosphere 9, and two-process pin persistence all pass.
- 240-frame gates clean: camp, graybox, R01, the R01 + R02 scene, and `main`
  with `--room=… --gen-seed=7`.
- GPU (`tests/r02_capture.gd`, views door / corridor / back / joint / plan,
  an `overlay` option): `previews/r02_s1_{door,corridor,back,joint,
  plan_overlay,corridor_seed7}.png`.

**Caveats:**
- **Joint:** looking up at the vault end against R01, the R01 shelf-bay back
  reads as a thicker end wall with a ledge, not a stray box. No joint lining
  is needed for now.
- **Light:** the corridor is darker than R01, with near-black floors between
  lamps and dark recesses. Lamps hang at the crown and light the vault more
  than the shelves. That suits the atlas's "darkness says how far out you
  are", but the teal fills and lamp falloff (slice 3) should be judged
  together with it.
- **No transverse ribs:** the vault is one smooth barrel. The atlas mock has
  a rib at every bay, and the kit has no rib module yet.
- **Overlay:** the `plan` capture is from 30 m up, so labels are small. It's
  meant for the editor viewport.
- **Found in R01, not caused by this slice:**
  - From the hall, R01's west door bay is reached only through a ~0.65 m gap
    between the reading table (x 2.3) and the gallery columns at x 1.4 (z -4
    and -8). The player (radius 0.32) passes, and the playtest now walks that
    gap, but it is tight. Moving the tables 0.5 m toward the rug, or widening
    the aisle, would fix it.
  - Validate Room on R01 *in the tree* (sockets spawned) warns twice that the
    corner recesses' slots run into the spawned corner columns. Run on an
    unresolved instance (as `validate_room_test` does), it's clean. The
    editor's Validate room button probably shows those two warnings.

**Slice 2 done (2026-10-19): turns and `max_straight_bays`.** This meets the
phase 2 done-when: walking from R01 into a generated gallery works, changing
`max_straight_bays` and pressing Generate visibly changes the corridor, and the
route audit passes on 20 seeds.

**Try it:** in `rooms/test/reading_room_r02.tscn`, select `StackGallery`, open
its grammar and set `max_straight_bays` to 2. The corridor regenerates as a
zigzag. Seed 5 runs 6 bays straight at the default and becomes a 7-bay U at 2.

- **`vault_cross_4m`** (`tools/kit_add_r02.py`, additive like `kit_add_r01.py`;
  catalog 66 modules). A groin vault built as four sectors of
  `vault_bay_4m`'s pointed barrel (same profile, k 0.6, crown 6.01 m). They
  meet on exact diagonal creases, each sector is smooth-shaded on its own, and
  each face is capped. Every side shows the barrel's end arch, so it meets a
  barrel on any side and takes `wall_gable_4m` on a closed one. Tagged
  `cross`.
- **Grammar** (`StackGalleryGrammar`): new knobs `max_straight_bays` 6,
  `min_straight_bays` 2 and `turn_chance` 0.35.
  - The walk turns left or right once a stretch reaches the maximum, and
    may turn after the minimum. The turning bay becomes a `corner` cell
    (slot `cell:ceiling_cross`).
  - A run never places a cell beside one of its own (except the cells it
    joins) or beside the host, so every wall has the corridor on one side
    only.
  - A run never ends on a corner. A forced turn there takes one extra bay
    if `max_bays` allows.
  - Up to 8 walks are tried (sub-seeds), keeping the first that reaches the
    rolled length, else the longest.
  - `StackGalleryGrammar.stretches(grid)` reports the straight stretch
    lengths.
- **Inner corners:** where two shelf bays meet at a turn's inner corner, a
  recess back (0.55 m behind its wall line) reached into the other's recess
  slot. Validate Room warned on every turn. The grammar now asks for slot
  `edge:solid_corner` there (`CellGrid.set_edge(..., slot)`; RoomBuilder
  falls back to the mark's slot when no rule has it), and `r02_brick.tres`
  fills it with `wall_plain_4m`.
- **Host doors stay clear:** the bay outside each of the host's other
  connectors is a blocker, so a run can't pass in front of R01's entrance or
  east door. Seed 12 first doubled back along R01's south side, past the
  entrance.
- **Validate Room:** a ceiling module tagged `cross` ends on every side, so
  it needs a gable (or a vault beyond) on all four.
- `tools/seed_gen.gd` is additive for rules now: it adds rules only for slots
  the file doesn't cover (it added `cell:ceiling_cross` and
  `edge:solid_corner`; your weights stay).

**Verified:**
- `r02_route_test`, now following the path through every bay and round each
  corner. Per seed:
  - stretches within `min`/`max_straight_bays` (the last may stop short);
  - a groin vault on every corner and a vault crown at 6.0 m over every
    cell;
  - every solid side of every cell blocks.

  Also: most seeds turn at least once. At seed 5, `max_straight_bays` 6 → 2
  changes the build, gives stretches ≤ 2 with ≥ 2 corners, validates clean,
  and back at 6 is the same build. All 20 seeds pass: 349 checks, 0 failures.
- `room_playtest` 18: the real player now steers bay by bay round the
  corners of seed 3 and back.
- `kit_test` 865, `reading_room_test` 79, `socket_modes_test` 246,
  `validate_room_test` 25, spill 6, room atmosphere 32, camp playtest 43,
  prototype atmosphere 9, pin persistence, and the 240-frame gates (camp,
  graybox, R01, R01 + R02, `main` at seed 12).
- GPU (`r02_capture.gd`, new views `corner`, `groin` and `plan_wide`, option
  `straight=N`): `previews/r02_s2_{corner,groin,plan_s1,plan_s5,
  plan_s5_straight2}.png`.

**Caveats:**
- **Creases:** in lamplight the groin vault's diagonal creases are soft: the
  plaster is lit from the crown lamp, so the sectors shade alike. It reads as a
  vault with arched sides more than as a crisp groin. Ribs (not in the kit)
  would sharpen it.
- **Dark turns:** the turn itself is dark when the corner has no lamp: the
  lamp rule is by bay count, not by corner.
- **Zigzags:** with low `max_straight_bays` the run can box itself in, and a
  2-bay zigzag grows a U or a spiral. All 8 tries may end short of the rolled
  length, with a warning. It has stayed within `min_bays` in every case
  checked.
- **Plan captures** show the shape only. The overlay labels are too small
  from 46 m; read them in the editor.

**Slice 3 done (2026-10-19): features.** Side passages into alcoves,
collapsed bays, lamp falloff with a lamp on every corner, an `exit` end with
its connector, and cool fills.

**Try it:** Esc menu → **Visit the stack gallery** and reseed, or start with
`-- --room=res://rooms/test/reading_room_r02.tscn --gen-seed=4` (a collapsed
bay just before the exit) or `--gen-seed=7` (three alcoves). In the editor,
select `StackGallery` and turn on **Overlay**: cell labels now show `alcove`,
`collapsed` and each lamp's state. The knobs are on
`gen/grammars/r02_stack_gallery.tres`, in the Inspector groups **Features**,
**Lamps** and **Cool fills** (§5.5.4); edits regenerate live.

- **Side passages** (`side_passage_chance` 0.11 per bay side): a plain solid
  side wall of a straight bay becomes an `opening` edge (the first use of that
  mark, filled by `wall_arch_3m`). Behind it is a one-cell `alcove` whose
  barrel runs out from the bay, with gables at the arch and at the back wall.
  The alcove's side walls ask for `edge:solid_corner` (plain), its back wall
  for `edge:solid` (shelves and the other recess picks). An alcove is placed
  only if nothing of the room, and nothing of the host, is beside it.
  `alcove_lamp_chance` 0.6, as in the atlas mock.
- **Collapsed bays** (`collapse_chance` 0.08 per bay): a straight bay whose
  two side walls are both plain solid walls (no alcove, door or inner corner).
  They ask for the new slot `edge:recess` (shelf bay only) and are pinned to
  "collapsed" (fallen books and broken boards). A `rubble_strip` lies along
  each wall (slot `dressing:rubble`).
- **Pins from the grammar:** `CellGrid.pins` maps a module node name to an
  entry label. `GeneratedRoom` turns it into `RoomTemplate.generated_pins`
  (new, never saved), which `resolve_sockets`, `style_choice` and Validate
  Room read through `RoomTemplate.pin_for()`. The user's `socket_pins` still
  win. So the grammar never reaches inside a socket (§5.5.6).
- **Lamps:** a lamp on every `lamp_every_bays`-th bay and on every corner
  (`lamp_on_corners`), plus alcove lamps. Each lamp's state is rolled from
  `lamp_lit_by_distance` (a `Curve`, 0.9 at the entry to 0.35 at 12 bays)
  and pinned: lit, otherwise failing (`lamp_failing_share` 0.3) or dark.
- **Exit end:** `end_kind` is now `exit` in `r02_stack_gallery.tres` (R02
  connects areas; the atlas mock ends in a warm arch). The exit goes straight
  on if a room could be built beyond, else to either side of the last bay,
  else the run ends in a dead end with a warning. The cell beyond is kept
  free (no alcove takes it). It has an arch, a gable, `SNAP_exit_<edge>` and,
  until phase 4 joins a room there, an `exit_glow` stub (slot `stub:exit`):
  a warm emissive card 1.4 m beyond the wall, a warm shadowed light that
  throws the arch into the last bay, and a blocker. `dead_end` still works.
- **Cool fills:** a shadowless teal `OmniLight3D` (colour 0.36/0.62/0.64,
  energy 0.6, range 7 m, 4.6 m up) on every 3rd bay of the run, under the
  room's `Lights` group. They stay out of `kit_light`, so Atmosphere doesn't
  sway them. Where the lamps are dark this is the only light, so the far
  corridor goes teal.
- **New data** (`tools/seed_gen.gd`, still additive): rules `edge:recess`,
  `dressing:rubble` and `stub:exit` in `r02_brick.tres`; the grammar's curve;
  `kit/sockets/collapse_rubble.tres` (rubble 3, fallen brick 2); and two
  Godot-only modules in `gen/modules/`: `rubble_strip.tscn` (a FREE
  `KitModule` on the wall line with a SCATTER socket, 10-16 pieces, 0.55-1.15 m
  out from the wall) and `exit_glow.tscn`. Rubble goes through a socket
  because KitValidate requires every module to keep scale 1, 90° turns and
  the 0.5 m grid.
- **Helpers:** `CellGrid.run_order()` (the run without alcoves),
  `alcoves_of()`, `tour()` (the run with a step into each alcove and back),
  `door_transform()`. `GeneratedRoom.bay_count()` counts the run only.
  `StackGalleryGrammar.stretches()` ignores alcoves.

**Verified:**
- `r02_route_test`, 435 checks, 0 failures. Per seed, on top of slices 1-2:
  - every alcove is one arch off a straight bay into a closed, gabled cell
    with nothing else beside it;
  - every collapsed bay's two recesses show "collapsed", with ≥ 5 rubble
    pieces at each;
  - lamps on every 2nd bay and every corner, each lamp state as the grammar
    pinned it;
  - the expected number of cool, shadowless fills;
  - one exit on the last bay: connector on the door, pointing out, the cell
    beyond free, the glow stub present;
  - every solid side and the exit block the capsule; floor collision under
    every cell, alcoves included;
  - the capsule walks from R01 round every corner, into every alcove and
    out, to the end and back.

  Across the 20 seeds: 16 of 20 seeds have an alcove,
  3 have a collapsed bay (seeds 4, 5, 20), and 78% of lamps within 3 bays
  of the entry are lit against 43% from 8 bays on (the test prints this). With
  `end_kind` dead_end (seed 3), the far end is a wall and gable, validates
  clean and blocks.
- `room_playtest` 18: the real player at seed 3 now also walks into both of
  its alcoves and out.
- `kit_test` 865, `reading_room_test` 79, `socket_modes_test` 246,
  `validate_room_test` 25, spill 6, room atmosphere 32, camp playtest 43,
  prototype atmosphere 9, two-process pin persistence, and the 240-frame
  gates (camp, graybox, R01, R01 + R02, `main` at seed 4) all pass, with no
  errors or warnings.
- GPU (`r02_capture.gd`, new views found from the layout on any seed:
  `alcove`, `collapsed`, `exit`, `falloff`): `previews/r02_s3_{alcove (seed 7),
  collapsed (seed 4), exit (seed 3), falloff (seed 7), plan_s7}.png`.

**Caveats:**
- **Exit glow** is a flat card: it reads as a warm room beyond from inside
  the corridor, but from above (the plan capture) it's a bare orange quad
  outside the shell. It goes when phase 4 joins a room there. The first
  version blew out to white close up; the emission is now 0.65.
- **Rubble** pieces are small (about 0.4 m), so a collapse reads mostly
  through the recess's fallen books and boards, with rubble as scattered
  stones, not a heap. There is no hole in the vault.
- **Dark foreground:** in a stretch whose lamps are dark, the floor near the
  camera is close to black under the teal fills (the `falloff` capture's
  bottom edge). That is the "how far out you are" effect, but it brushes
  ART_DIRECTION's "never let the foreground go black"; raise `fill_energy`
  if it reads too dark in play.
- **Alcove frequency:** 0.11 per side gives about two alcoves a seed (more
  than the atlas mock's look), because most sides fit. Lower the knob if the
  corridor feels porous.
- Alcove backs take the normal `edge:solid` roll, so one may end in a sealed
  door or tile panel (seed 7's first alcove has a sealed door).

**Slice 4 done (2026-10-19): bake to scene, and generated floor wear.**
Design in §5.5.10.

**Try it:**
- **Bake:** in `rooms/test/reading_room_r02.tscn`, select `StackGallery`
  and press **Bake to scene**. It writes
  `rooms/baked/stack_gallery_west_<seed>.tscn`, an ordinary room you can
  open and edit. Headless:
  `godot --headless --path . --script res://tools/bake_room.gd -- - 7`
  also writes `…_7_in_host.tscn` (R01 with the baked gallery), which the
  game plays with `-- --room=res://rooms/baked/stack_gallery_west_7_in_host.tscn`.
  The repo has seed 7 baked as an example.
- **Wear:** play the R01 + gallery scene. A polished lane runs from R01's
  west door spur down the gallery, cuts across each turn, and branches into
  every alcove. It is busier near R01 than far out. Tune it in the grammar's
  **Floor wear** group.

| Piece | File |
|---|---|
| Bake: a plain `RoomTemplate` of owned module instances, pins and style picks kept, host scene writer | `scripts/gen/room_baker.gd` |
| **Bake to scene** button; generated `FloorWear` from `grid.wear` | `scripts/gen/generated_room.gd` |
| Headless bake | `tools/bake_room.gd` |
| Lanes for any grammar (tree from the entry door, main lane, spurs, browse marks, stray, corner cut, traffic falloff) | `scripts/gen/room_grammar.gd` (`wear_lanes`), `CellGrid.wear` |
| One shared world-space wear map from every live `FloorWear` | `scripts/world/floor_wear.gd` |
| `style_pins` (saved style group picks) | `scripts/world/room_template.gd` |
| Example bake (seed 7) | `rooms/baked/stack_gallery_west_7.tscn`, `…_7_in_host.tscn` |

**As built, vs §5.5.10:**
- **Bake:** modules are instantiated with `GEN_EDIT_STATE_INSTANCE`. Without
  it, `pack()` writes every property of every instance (49 KB instead of
  25 KB for seed 7). The baked file has no `uid=` on its ext_resources, as
  with any scene packed headless. The editor adds them on its first save.
  The safety floor's shape is now named `Shape`, so the baked file has no
  auto-generated names.
- **Shared map:** `FloorWear.texture` is gone. Tests and tools read
  `FloorWear.map_image` / `wear_at(world point)`, and `rebuild_now()` forces
  a rebuild in the same frame. Seed 7 joined to R01 gives a 45 × 31 m map
  built in 113 ms (R01 alone took 67 ms before). It is rebuilt once at load,
  not per frame.

**Verified:**
- `tests/r02_bake_test.gd`, 105 checks. For seeds 7 (alcoves), 4 (a
  collapsed bay), 1 and 12 (turns) and 3 with `end_kind` dead_end, the
  baked scene, loaded under a fresh R01 where the generated room was:
  - is a plain `RoomTemplate` with the same `room_id` and seed;
  - has the same world transform, module list (name, scene, position),
    socket picks and counts (42-82 sockets), connectors (with
    `host_closes`), fills, safety floor and shared wear map;
  - validates clean (Validate Room and KitValidate), and R01 beside it
    keeps its 106 sockets;
  - has no node marked generated, no auto-named node, and no spawned socket
    content in the file;
  - and its `_in_host` scene loads as R01 with the same gallery.
- **Persistence, two processes:** `r02_bake_test -- save` bakes seed 7, and
  `-- load` in a fresh process checks it against a new live build (20
  checks).
- `r02_route_test`, 526 checks, 0 failures (20 seeds; the wear map rebuilds in up to 129 ms). New per seed: wear crosses
  every bay and alcove, and both sides of R01's west wall; there is none
  0.5 m off any solid side wall of a straight bay; mean lane wear within
  2 bays of R01 beats that from 9 bays on; and regenerating gives the same
  lanes.
- `reading_room_test` 79 (reads the shared map now; both lanes worn, none
  mid-rug), `kit_test` 865, `validate_room_test` 25, `socket_modes_test`
  246, spill 6, room atmosphere 32, camp playtest 43, prototype atmosphere
  9, `room_playtest` 18, and two-process pin persistence all pass.
- 240-frame gates clean: camp, graybox, R01, R01 + R02, the baked
  `stack_gallery_west_7_in_host.tscn`, and `main` with `--gen-seed=4` and
  with `--room=` the baked scene. The editor opens
  `reading_room_r02.tscn` headless without errors.
- GPU, after `--import` (`r02_capture.gd`: new views `wear` and
  `wear_alcove`, option `scene=` to capture a baked scene from the live
  room's camera, option `wearmap=` to save the shared map):
  - Before/after pairs `previews/r02_s4_{before,after}_{wear_s7,wear_s3,
    wear_alcove_s7,door_s7,falloff_s7,r01_relief_lane}.png`. On the gallery
    floor the mean diff is 0.09-0.31, all of it on the lane: amplified 10×,
    it is a band down the run that cuts across the far turn.
  - `previews/r02_s4_wearmap_s7.png` (the shared map: R01's lanes and table
    rings, and the gallery's lane with alcove spurs and browse marks) and
    `r02_s4_plan_s7.png`.
  - Baked vs live, same camera (`r02_s4_baked_{door,wear_alcove}_s7.png`):
    mean diff 0.24-0.76 on the door view, inside live-to-live noise (0.80),
    and 0.008 on the alcove.

**Caveats:**
- **Wear is subtle in the gallery.** It's the same `floor_stone` effect as
  in R01 (smoother, 5 % darker, a glint toward a lamp), and the gallery is
  dark, so at normal exposure the lane is close to invisible. It shows as
  a faint sheen where a lit lamp hangs over the lane. Making it read would
  mean a stronger `wear_roughness` or darkening in `kit_px_world`, which
  changes R01 too. That's a look decision, not done here.
- **R01's wear speckle changed once:** the noise lattice is world-anchored
  now. R01's lanes are where they were, but the dithered speckle along them
  is rearranged (`r01_relief_lane` mean diff 0.47 against noise of about
  0.4).
- **One y band:** the shared map has one height band (the union of the live
  `y_range`s). Rooms stacked on different floors over the same x/z would
  share wear. Phase 4 needs a band per floor.
- **A baked room is a snapshot.** It doesn't follow later grammar or rules
  edits. Regenerating means baking again (and losing hand edits).
- **Editor:** wear still only shows at runtime.

**Next:** phase 2 is complete (slices 1-4). Next on the §10 roadmap is
phase 3 (props and persistence). Phase 4's "one baked room" can use this
bake.

### Loose ends after phase 2 (done 2026-10-20)

Five caveats left open by polish 1c and phase 2. They're closed before phase 3.

1. **Walkway past the gallery columns.** The pinch was between two bases: the
   pier base (±0.48) and the column plinth (±0.28), 0.64 m apart. Now the
   `post_pier_corbel` base is ±0.42 (rev 2) and the column plinth is
   `COL_BASE` ±0.24 (`gallery_column(_corner)` rev 2), so the gap is 0.74 m.
   The test capsule (r 0.35) now walks along both walls past the z -4
   column. `COL_Y` stays 1.4: moving the column out would have narrowed the
   hall aisle.
2. **R01's west door aisle.** The reading tables moved 0.5 m toward the rug
   (x 3.5 / 8.5; free modules stay on the 0.5 m grid, so 0.25 wasn't
   allowed). The aisle between the column bases and a table is 1.16 m (it was
   0.66). Each table now stands 0.2 m from the rug, so the strip beside the
   rug is too narrow to show wear. R01's two walking lanes now run down the
   outer aisles (x 2.2 / 9.8). The side-door and stair-foot spurs join them
   there. The route test walks the aisle into each side door bay, and the
   playtest follows it.
3. **Stair capture.** The `stair` view starts at (6, 1.7, -2.4), clear of
   the x 8 column. The `relief_lane` view looks down the new west aisle.
4. **In-tree Validate Room warnings.** These weren't false positives. The
   corner column's second arch, the one to the side wall, landed in the mouth
   of the bay-0 shelf recess. Each corner column now has one arch, to the end
   wall, continuing the side arcade's line. The east corner uses
   `post_gallery_column_corner_r`, whose socket is turned -90 degrees so its
   arch also reaches the end wall. Both corners share the
   `gallery_support_corner` set. `validate_room_test` now also validates R01
   in the tree, with its sockets spawned, and it's clean.
5. **Gallery wear strength: decided to leave it.** The R02 gallery is dark
   by design (lamp falloff). Darkening is a percentage of an already dark
   floor, so even 3x the current 5 % wouldn't read. The only cue that does
   read in the dark is the sheen under a lit lamp, which is there already.
   A stronger value would change R01's tuned lanes too. So `wear_strength`,
   `wear_roughness` and the 5 % tint stay shared and unchanged. Revisit if
   the gallery's lighting changes.

**Gates:**
- kit_test: 880 checks
- validate_room_test: 26 checks
- reading_room_test: 87 checks
- room_playtest: 18 checks
- socket_modes_test: 246 checks
- r02_route_test: 526 checks
- r02_bake_test: 105 checks
- the 240-frame headless run

All pass.

GPU captures: `previews/reading_room_le_{stair,under_gallery,arcade,relief_lane,entrance}.png`.

**Caveat:** the 0.74 m walkway still leaves the player (r 0.32) only 5 cm a
side. It's passable, not roomy. Widening it further means a deeper gallery
lane (`GAL_Y1`), which would change every gallery module.

### Phase 2 slice 5: galleries on every R01 door (done 2026-10-20)

R01 has three doors (west, east, entrance). Until now a `GeneratedRoom` kept
out of its host's modules and the bays outside the host's other doors, but
not out of other rooms under the same host. Two galleries could grow into
each other. This slice closes that before phase 3.

**Design note (written before coding):**

- **Siblings.** A sibling is any other `RoomTemplate` under the same host:
  a live `GeneratedRoom` or a baked room from `rooms/baked`. The search walks
  down from the host and stops at each room it finds, so rooms joined to a
  gallery's own exit (phase 4) aren't siblings.
- **What a sibling blocks.** It blocks the same two things the host does:
  - its kit modules' mesh bounds (free dressing and posts left out, as for
    the host)
  - the bay outside each of its own doors, except its entry (that bay is the
    host), so its exit stays free for the room that will join there.

  Live and baked siblings are read the same way, from their placed modules.
  So baking a sibling doesn't change the rooms built around it. The grammar's
  neighbour rule (no cell beside a blocked cell) already keeps one empty bay
  between two rooms. No wall is shared or doubled, so nothing z-fights.
- **Order.** A baked sibling is fixed, so it always blocks. Live siblings
  claim space one after another, in the order of their `join_connector`
  under the host's `Connectors`. For R01 that's entrance, west, east. A room
  with no join connector comes after every joined one, and node name breaks
  ties. A room sees only the live siblings that come before it. Before it
  reads them, it generates any of them that hasn't been built yet. So the
  result depends on seeds and that order, not on tree order or on which
  `_ready` runs first.
- **Not boxed in.** Every room already keeps the bay outside each of the
  host's other doors free. That alone wasn't enough: in the first full run,
  the entrance and west galleries wrapped round three-door seed 7's east
  door and stopped its run at one bay. So a host door with a sibling joined
  (a live room by its `join_connector`, a baked one by its entry on the
  connector) keeps a strip of `OCCUPIED_DOOR_BAYS` (3) bays clear straight
  out, with the neighbour rule's margin round it. A later room still has no
  hard guarantee of `min_bays`. Doors with no room joined keep one bay, so a
  lone gallery is unchanged. (Decided by the user 2026-10-20, over
  re-running earlier rooms with other walks.)
- **Single galleries are unchanged.** With no siblings the blockers are the
  same as before, so a lone gallery gives the same build for the same seed.
  With siblings, even the first room to claim can differ from its solo
  build, because it keeps the deeper strip clear at the other occupied doors.
- **Editor.** When a room regenerates, it asks the live siblings after it to
  regenerate too.

**Built:**

| Piece | File |
|---|---|
| Sibling rooms, their blockers, and the claim order (`sibling_rooms`, `claim_key`, `_room_blockers`) | `scripts/gen/generated_room.gd` |
| Layout check wording: "overlaps the host or a sibling room" | `scripts/gen/cell_grid.gd` |
| R01 with galleries on all three doors (seeds 1 / 101 / 201) | `rooms/test/reading_room_r02_three.tscn` |
| Route audit on every door, plus the three-door case | `tests/r02_route_test.gd` |
| Capture option `three`, views `plan_three` and `entrance` | `tests/r02_capture.gd` |

- **Single galleries are unchanged.** With no siblings, the blockers are the
  same as before. The bake test's saved seed 7 still matches, and so does
  the live east gallery in `Multrooms-test1.tscn` (seed 6547) against its
  solo build. The baked west gallery there doesn't reach it.
- **`_ready` builds only if nothing has yet.** A later sibling may already
  have built an earlier one on demand.

**Gates (all pass):**
- `r02_route_test`, 2321 checks, 0 failures (about 25 min). The 20-seed
  audit now runs on all three doors: west, east and entrance. Then the
  three-door case, with seeds s, s + 100 and s + 200, checks:
  - no gallery in, beside or past the exit of another
  - layout check and `min_bays` for every gallery
  - Validate Room on every gallery
  - floor, vault and walls closed in every gallery
  - every route walked from R01 and back
  - the same builds with the galleries in reverse tree order

  A sibling changed a later gallery in 11 of 20 seeds. Built alone, the
  three would clash in 7 of 20. User args `doors=` and `seeds=` run part of
  the test.
- `kit_test` 880, `validate_room_test` 26, `reading_room_test` 87,
  `room_playtest` 18, `r02_bake_test` 105.
- 240-frame headless runs: main, `reading_room_r02.tscn`,
  `reading_room_r02_three.tscn` and `Multrooms-test1.tscn`.
- GPU (after `--import`):
  - `previews/r02_s5_three_plan_overlay_s{2,7}.png` and
    `r02_s5_three_plan_{s2,s7}.png`: plan views, all three galleries apart.
    Seed 7 was the boxed-in case: the east gallery stopped at one bay
    before the deeper strip, and runs 6 bays now.
  - `r02_s5_three_entrance_s2.png`: from R01's hall out of the entrance
    arch.
  - `r02_s5_three_door_s2.png`: the west door, unchanged.

**Caveats:**
- **No hard length guarantee for a later room.** The strip makes a boxed-in
  first bay unlikely, but not impossible: the run can still stop under
  `min_bays`. The grammar then warns, and the 20 audited seeds never hit it.
- **One level of siblings only.** Rooms joined to a gallery's own exit
  (phase 4) don't block, and aren't blocked by, R01's other galleries.
- **Editor:** a later sibling regenerates on a deferred call after an
  earlier one changes. For one frame it can show the old build.
- **Plan captures are mirrored:** in the `plan_three` view, east is on the
  left.

