# Phase 2 design: the generated Stack Gallery (R02)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-19, built** (slices 1–5)

**In short:** a long shelf-lined corridor is generated from a seed and joined
to a door of the Reading Room. Rules in `.tres` files decide its length,
turns, side alcoves, collapses and lamps. A layout you like can be **baked**
into a normal scene. What was built, and how it was checked, is in
[progress/phase-2-stack-gallery.md](progress/phase-2-stack-gallery.md).

---

### 5.5 Phase 2 design: R02 Stack Gallery off R01 (approved 2026-10-19)

R02 in the atlas: a corridor one bay (4 m) wide, any length, one storey plus a
pointed barrel vault. Every bay side is a shelf recess, with the odd side
passage or collapse. Lamps hang every second bay and get rarer with distance.
The atlas plan shows corners, T-junctions, dead-end alcoves and a far arch.

The kit already holds a straight corridor: `floor_4m`, `wall_shelfbay_4m`
(its `recess_library` socket gives shelves, tile panel, sealed door and
collapse), `wall_plain_4m`, `wall_arch_3m`, `vault_bay_4m` (springs from the
4 m wall tops, so it sits at storey 0 here), `wall_gable_4m`, `post_pier` and
`lantern_hanging`. Slice 1 needs **no new Blender modules**. Corners and
junctions need one (slice 2).

#### 5.5.1 The generated room is a `RoomTemplate`

`GeneratedRoom extends RoomTemplate` (`@tool`, `scripts/gen/generated_room.gd`)
holds `grammar: RoomGrammar`, `rules: ModuleRules`, `gen_seed` and a join
(`join_connector: StringName` on its parent room, see 5.5.5). Its `_ready`
first generates, then runs the normal `RoomTemplate` resolve. So everything
phase 1 built works on it unchanged: sockets, room pins, the style group,
claims, Atmosphere, Validate Room, `main.gd`'s room loading and the capture
tools. A baked room (5.5.7) is a plain `RoomTemplate`.

The generated modules go under `Shell`, named by grid key, never by order
(`wall_x-1_z2_W`, `floor_x0_z3`, `post_x1_z2`). Socket paths are then stable
for a given layout, so socket seeds and pins behave as in authored rooms. They
have **no owner** and carry the meta `generated`, so they are never saved:
the scene file holds only the root and its settings. (Internal children, as
sockets use, would hide them from `get_children()`, and with it from the
socket resolve and Validate Room.)

One small phase 1 change: `RoomTemplate.sockets()` and `KitValidateRoom` stop
descending at a nested `RoomTemplate`. A room owns its sockets and modules, not
those of a room placed inside it.

#### 5.5.2 Cell grid and edge marking

`CellGrid` (`scripts/gen/cell_grid.gd`, plain `RefCounted`, data only):

- **Cells** `Vector3i(x, storey, z)` in room-local 4 m units. Cell (x, s, z)
  spans x 4x..4x+4, y 4s.., z -4z..-4z-4 (the kit's cell convention). Each
  cell has a `kind` (`floor` in slice 1; `stair_down`, `collapsed` and `alcove`
  later) and a `run_dir` (the vault's barrel axis).
- **Edges** are keyed once per boundary, `(cell, side)` normalised to the
  lower cell, so neighbours share one record. Each edge gets exactly one mark:

| Mark | Meaning | What is emitted |
|---|---|---|
| `solid` | Room boundary, closed | An EDGE module from `ModuleRules` (shelf bay or plain wall) |
| `opening` | Walkable gap to another cell of *this* room through a wall line (side passage, alcove mouth) | An opening module (`wall_arch_3m`) |
| `door` | A connector edge. `owner = self`: this room emits the opening module and a `SNAP_` marker (an exit for later rooms). `owner = host`: the host room's module already stands there, so nothing is emitted | `self`: opening + connector. `host`: connector only |
| `open` | Interior edge between two cells of the run | Nothing; floor and vault continue |

- **Corners** are derived, not marked: a post goes on every grid corner where
  two marked wall edges meet, except corners on a host's wall line (the host
  already has its pier there).
- **Vault ends** are derived: a cell whose barrel ends at a `solid` or
  `door(self)` edge gets a `gable` there. A `door(host)` edge needs none,
  because the host's wall rises past the vault (R01's walls are 8 m; the
  corridor crown is about 6.4 m). Validate Room learns that rule (5.5.8).
- **Reserved cells:** the generator never places a cell where the host's
  CELL or EDGE module meshes reach more than 0.6 m into it. That covers the
  host's own cells and the iwan's 3.3 m back. Posts are left out: their
  corbels reach 0.85 m into every neighbouring cell by design.

#### 5.5.3 `ModuleRules` (`gen/rules/*.tres`)

Data, edited in the Inspector. `ModuleRules` holds `Array[ModuleRule]`; a rule is:

| Field | Example |
|---|---|
| `slot` | `edge:solid`, `edge:opening`, `edge:door`, `gable`, `cell:floor`, `cell:ceiling`, `post`, `lamp` |
| `styles` | `[brick]` (all must be in the room's styles; empty = any) |
| `choices` | `Array[ModuleChoice]`: a module scene (drag from `kit/modules/`) and a weight |

The first rule whose slot and styles match wins, and the pick is weighted and
seeded per grid key (5.5.6). A rule may only list modules whose `KitModule`
shape fits the slot (EDGE for edges and gables, CELL for floors and ceilings,
POST for posts). `ModuleRules.check(catalog)` reports a misfit, and
`gen_rules_test` runs it on every rules file.

`gen/rules/r02_brick.tres`, first version:

| Slot | Choices |
|---|---|
| `edge:solid` | `wall_shelfbay_4m` 8, `wall_plain_4m` 2 |
| `edge:opening`, `edge:door` | `wall_arch_3m` 1 |
| `gable` | `wall_gable_4m` 1 |
| `cell:floor` | `floor_4m` 1 |
| `cell:ceiling` | `vault_bay_4m` 1 (turned to the cell's `run_dir`) |
| `post` | `post_pier` 1 |
| `lamp` | `lantern_hanging` 1 |

The grammar decides *what* each edge is. The rules decide *which module* fills
it. So "more shelves, fewer blank walls" is a rules edit, and "more side
passages" is a grammar edit.

#### 5.5.4 The R02 grammar: `StackGalleryGrammar extends RoomGrammar`

`gen/grammars/r02_stack_gallery.tres`. `RoomGrammar` is the base (`styles`,
`rules`, `generate(grid, rng_for) -> void`), with one subclass per room type.

| Knob | Default | Slice | Effect |
|---|---|---|---|
| `min_bays` / `max_bays` | 6 / 12 | 1 | Total cells on the main run |
| `styles` | `[brick]` | 1 | Selects `ModuleRules` rules |
| `lamp_every_bays` | 2 | 1 | A lamp on every Nth bay's centre line |
| `end_kind` | dead end | 1 | Far end: `dead_end` (solid wall and gable) or `exit` (`door(self)` with a connector for a later room) |
| `max_straight_bays` | 6 | 2 | The longest straight stretch before a turn |
| `min_straight_bays` | 2 | 2 | No turn sooner than this after the last one |
| `turn_chance` | 0.5 | 2 | Chance to turn at each allowed bay |
| `side_passage_chance` | 0.11 | 3 | Per bay side: an `opening` into a one-cell dead-end alcove |
| `collapse_chance` | 0.08 | 3 | Per bay: a `collapsed` cell (rubble dressing; both recesses pinned to collapsed) |
| `lamp_lit_by_distance` | `Curve`, 0.9 at the entry to 0.35 at 12 bays | 3 | Lamp `lit` chance by bay count from the entry: the darkness says how far out you are |
| `alcove_lamp_chance`, `lamp_on_corners`, `lamp_failing_share` | 0.6, on, 0.3 | 3 (as built) | A lamp in an alcove; a lamp on every corner; of the unlit lamps, the share that flicker rather than go dark |
| `fill_every_bays`, `fill_colour`, `fill_energy`, `fill_range`, `fill_height` | 3, teal, 0.6, 7 m, 4.6 m | 3 (as built) | Cool shadowless fills, the teal archive light |
| `branch_chance` | 0 | later | T-junction off the main run (needs `vault_cross_4m`, like corners) |

`max_straight_bays` is a hard rule: the walk turns (left or right, whichever
fits) once it reaches that many straight bays. If neither side fits, the run
ends there.

#### 5.5.5 Joining to R01

R01's connectors (`rooms/authored/reading_room.tscn`, `Connectors`, group
`room_connector`): `SNAP_entrance` (6, 0, 0), `SNAP_door_west` (0, 0, -6),
`SNAP_door_east` (12, 0, -6). Each is centred on a 4 m bay edge, and its -Z
points out of the room.

- **The generated room's own frame** follows the edge-module convention. The
  entry edge runs from (0, 0, 0) to (4, 0, 0), and the room grows into -Z. Its
  `SNAP_entry` sits at (2, 0, 0), with -Z pointing out (back toward the host).
- **Join:** the room is placed so `SNAP_entry` meets the host connector face
  to face (same point, opposite facing). Because both connectors sit at a bay
  midpoint, the corridor's 4 m grid lands on R01's grid, and Validate Room's
  grid checks hold in both frames. The entry edge is marked `door(host)`.
- **The pair as a scene:** `rooms/test/reading_room_r02.tscn` *inherits*
  `reading_room.tscn` and adds one `StackGallery` (`GeneratedRoom`) child with
  `join_connector = "SNAP_door_west"`. `reading_room.tscn` itself is not
  touched. The root is still R01's `RoomTemplate`, so `main.gd` loads it as it
  is (spawn, HUD name, Atmosphere). Phase 4's `AreaRecipe` replaces this
  scene.
- **Style inheritance:** `GeneratedRoom.inherit_style_groups` (default
  `[gallery_build]`). The joined room takes the host's resolved pick for those
  groups (a new `style_overrides`, checked after pins and before the room's own
  roll), so stone galleries in R01 mean stone stairs in a generated room that
  has any. R02 slices 1-3 have no group sockets, so this is wiring only.
- **Light:** the corridor's `Atmosphere` defers to R01's environment (it
  already does when one exists). One environment per scene until phase 4. The
  atlas's teal corridor light comes from cool fills placed by the grammar
  later, not from a second environment.
- **Safety:** the corridor gets its own `TempSafetyFloor` under its cell
  bounds, as AGENTS.md requires (R01's 60 m one ends 24 m west of its wall).

#### 5.5.6 Sockets, seeds and the style group in a generated room

- `gen_seed`: at runtime `hash(area_seed, room_id)` once areas exist. Until
  then it is the exported `gen_seed`, which the game menu can override.
- **Every decision has its own key:** `hash(gen_seed, "layout")` for the walk,
  and `hash(gen_seed, "edge", key)`, `("cell", key)`, `("lamp", key)` for picks.
  Changing one wall's rule doesn't reshuffle the others.
- **Socket resolve** is exactly R01's: `RoomTemplate.resolve_sockets(gen_seed)`
  after the build, keyed by socket path (stable, from 5.5.1). Recesses, lamp
  states, wall stains, floor wear and seam debris all come with the modules.
- **Style group:** rolled once per generated room from its own seed, as in
  R01, unless inherited (5.5.5). Grammar features that place group sockets
  later (a stair-down bay using `stair_gallery_8m`) then match the rest of
  the room.
- **Grammar-driven picks** go through `socket_pins` on the generated room.
  A collapsed cell pins its two recesses to `collapsed`; a lamp beyond the
  falloff pins `dark`. So the grammar never reaches inside a socket.

#### 5.5.7 `GeneratorPreview` (editor)

§5.3 described a separate node. A simpler fit: the buttons live **on
`GeneratedRoom`**, and any scene can hold a `GeneratedRoom` with no join to
preview a grammar on its own.

- **Generate** rebuilds from the current grammar, rules and seed. **Reseed**
  rolls a new seed. Changing a grammar or rules `.tres` (its `changed`
  signal) regenerates live, so editing `max_straight_bays` updates the
  viewport.
- **Overlay** (checkbox): cell outlines at floor level and each edge as a
  coloured bar (solid grey, opening teal, door gold, open hidden), drawn as
  an internal unshaded `ImmediateMesh`, like `KitModule`'s outline. Labels
  show the bay index and lamp picks.
- **Bake to scene** writes `rooms/baked/<room_id>_<seed>.tscn`: a plain
  `RoomTemplate` with owned module instances, the same `room_id`,
  `preview_seed` and `socket_pins`, so it resolves to the same picks. From
  there it is an authored room.
- **Step** (stage by stage) is deferred until a rule needs debugging.

#### 5.5.8 Validation

- **Generator check** (`CellGrid.check()`, run after every generate, warnings
  in the Output panel): every cell has a floor and a ceiling, every boundary
  edge is `solid` or `door`, no reserved cell is used, and the run is
  connected from the entry.
- **Validate Room** runs on the generated room as on R01 (the Kit dock button
  works on the selected `GeneratedRoom` too). One new rule: a vault end on a
  `door(host)` edge counts as closed when its connector carries
  `meta host_closes_vault`.
- **Route audit, 20 seeds** (`tests/r02_route_test.gd`): for seeds 1-20 it
  builds R01 plus the joined corridor in memory and checks:
  - the capsule (radius 0.35, height 1.8, `body_test_motion`) goes from R01's
    spawn through the west door, down every cell centre to the far end, and
    back;
  - a floor ray hits under every cell centre;
  - pushes through every `solid` edge are blocked;
  - no overlap with R01, and KitValidateRoom has no errors;
  - the same seed gives the same module list, and different seeds differ.

  From slice 2 it also checks that every straight run is ≤ `max_straight_bays`,
  and that changing it changes the layout.
- **Playtest:** `tests/room_playtest.gd` gains a pass with the real `main.tscn`
  player walking from R01 into the corridor (one seed). Gates per step:
  AGENTS.md's 240-frame runs (camp, graybox, R01, the R01+R02 scene),
  `kit_test`, `reading_room_test`, `validate_room_test`, `socket_modes_test`,
  the new tests, and GPU captures (`tests/r02_capture.gd`).

#### 5.5.9 Slices (each one user-visible, reviewed before the next)

1. **A straight corridor off R01's west door, walkable and reseedable.**
   `CellGrid`, `ModuleRules` + `r02_brick.tres`, `RoomGrammar` +
   `StackGalleryGrammar` (length, lamps, dead end), `GeneratedRoom` (join,
   build, resolve), Generate/Reseed/Overlay, `reading_room_r02.tscn`. Esc menu
   → **Visit the stack gallery** and **Reseed the stack gallery** (or
   `-- --room=… --gen-seed=N`). Route audit on 20 seeds. Captures: looking
   down the corridor from the door, back toward R01, and the overlay.
2. **Turns and `max_straight_bays`.** A new cell module `vault_cross_4m` (a
   groin vault for corners, later T and cross) via an additive
   `tools/kit_add_r02.py`. Corner piers and gables follow. The phase 2
   done-when is met here: change `max_straight_bays`, press Generate, and the
   corridor visibly changes; the audit passes on 20 seeds.
3. **Features:** side passages into alcoves, collapsed bays, lamp falloff, an
   `exit` end with its connector, cool fills.
4. **Bake to scene**, plus generated `FloorWear` lanes (from connectors down the
   run, replacing R01's single-room limit) if slice 3 shows the floor too even.

**Risks to check in slice 1:**
- R01's upper west bay 1 is a shelf bay whose back sticks out 0.25 m past the
  wall line, at 4-8 m. That is inside the corridor's vault end. The capture
  will show whether it reads as a thicker end wall or as a box. The fallback is
  a joint lining module.
- `lantern_hanging`'s chain is 1 m (made to hang from a gallery soffit). Under
  the corridor vault it must hang from the crown, so it is placed at
  crown − 1 m. If the glass then sits too high, slice 1 adds a long-chain
  lantern.
- The corridor's walls meet R01's wall at the joint corners, where R01's
  shelf-bay backs reach 0.25 m out. They overlap inside solid wall only; the
  z-fight audit checks this.

#### 5.5.10 Slice 4 design: bake to scene and generated floor wear (2026-10-19)

**Bake to scene.** `RoomBaker.bake(room: GeneratedRoom, path) -> Error`
(`scripts/gen/room_baker.gd`) writes the live build as a plain
`RoomTemplate` scene:

- **Root:** a `RoomTemplate` named like the generated node, with the same
  `room_id` and `display_name`, `preview_seed` = the seed it was built from,
  and the generated node's transform relative to its parent. Instancing the
  baked scene under the host in place of the `GeneratedRoom` therefore lands
  it on the join. The meta `baked_from` records the grammar, rules, seed and
  module count.
- **Same picks:** socket seeds hash `(seed, room_id, socket path)`, and every
  module keeps its grid-key name under the same group, so socket paths and
  seeds match. `socket_pins` = the grammar's `generated_pins` merged with the
  room's own `socket_pins` (the user's win), so collapsed recesses and lamp
  states are saved as ordinary pins. The host's inherited style groups are
  saved in a new `RoomTemplate.style_pins` (`{group: entry}`, checked after
  `style_overrides` and before the room's own roll), which authored rooms can
  use too.
- **Content:** each module is re-instantiated from its scene and owned by the
  root, so the file references kit scenes. Socket spawns are internal, so
  they aren't saved and the baked room resolves them itself on `_ready`. The
  connectors (with their `snap_kind` and `host_closes` metas), cool fills,
  `TempSafetyFloor` and the room's `FloorWear` are duplicated and owned.
  Nothing carries the `generated` meta, so a baked room is never cleared.
- **Where:** `rooms/baked/<room_id>_<seed>.tscn`. From the editor, the
  **Bake to scene** button on `GeneratedRoom`. Headless:
  `tools/bake_room.gd -- <scene> <seed> [out]`, which also writes
  `<out>_in_host.tscn`, the host scene with the generated node swapped for
  the baked one, so the baked room can be played (`--room=`).
- **Check:** for a baked seed, the live and baked rooms have the same module
  signature, the same socket picks, the same connectors and fills, and the
  same wear map, and Validate Room is clean on both. GPU captures of both
  from one view are compared with `image_diff`.

**Generated FloorWear lanes.** Lanes are grid data, like fills and props:

- **`FloorWear` becomes one shared map.** Every live `FloorWear` feeds one
  world-space wear map, so the host's wear and a joined room's wear are live
  together. This replaces the polish C "one room at a time" limit. Each
  wear's paths and table rings are moved to world x/z before stamping, so a
  `FloorWear` may now turn (the gallery is turned 90° off R01). The map
  covers the union of the live rects, snapped to whole metres. Its noise
  lattice (one value per 0.25 m) and its Bayer dither are anchored to world
  texels, so overlapping rooms agree and a room's wear doesn't change when
  another joins. Building the map costs in proportion to the stamped area,
  not the rect. It is rebuilt once per frame after a wear enters or leaves.
  R01's paths are unchanged; its noise pattern changes once, because the
  lattice is now world-anchored. Limit: one y band (the union of the live
  `y_range`s), so rooms stacked on different floors over the same x/z would
  share wear. Phase 4 needs a band per floor.
- **`RoomGrammar.wear_lanes(grid, seed)`** is on the base class, so every
  grammar gets lanes. It fills `grid.wear` with `{points, weight}` in room
  x/z:
  - The cells form a tree from the entry door, through `open` and `opening`
    edges. The **main lane** runs from 0.4 m outside the entry door (meeting
    the host's door spur; R01's west spur ends 0.3 m inside its wall) through
    the cells to the exit door and 0.4 m past it. With no exit, it runs to the
    deepest cell and stops `wear_stop` short of its far wall.
  - **Spurs** run from each branch cell into the cells off the main lane
    (alcoves) and stop `wear_stop` short of the back wall.
  - **Browse marks:** at every dead-end stop, a short cross stroke for
    turning round at the shelves.
  - **Points:** each cell's lane point is moved sideways by up to
    `wear_wander`, from `hash(seed, "wear", cell)`, so the lane meanders. A
    turn is cut across: the corner cell's point becomes two points
    `wear_corner_cut` before and after its centre.
  - **Traffic falls off:** a point's weight goes from `wear_entry_weight`
    (1.0) to `wear_far_weight` (0.45) at `wear_far_bays` (12) bays from the
    entry. Spurs and browse marks take `wear_spur_weight` (0.6) of that.
    Busy near the reading room, faint far out, like the lamps.
- **`GeneratedRoom`** adds a generated `FloorWear` covering its cells, with
  1 m to spare and whole metres, and `y_range` set to the ground storey.
- **Knobs** on `RoomGrammar` (Inspector group **Floor wear**):
  `wear_lanes_enabled`, `wear_entry_weight`, `wear_far_weight`,
  `wear_far_bays`, `wear_spur_weight`, `wear_wander` (0.3 m),
  `wear_corner_cut` (0.8 m), `wear_stop` (1.0 m), and `wear_half_width`
  (0.32 m: the corridor's single lane is a little wider than R01's paired
  lanes).
- **Checks** (route test, every seed): wear on the lane in every run cell,
  on the joint (on both sides of R01's west wall), in every alcove; none
  within 0.5 m of a side wall; near bays more worn than far bays; and the
  same seed gives the same lanes. reading_room_test reads the shared map.
  GPU: the same floor views before and after.

