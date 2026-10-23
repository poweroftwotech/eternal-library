# Phase 5 design: kit breadth (technical)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Plain-language brief:
[phase-5-approval.md](phase-5-approval.md) · Status: **approved 2026-10-22
(Q1–Q12 as recommended)**

The detail behind the approval brief. Section numbers continue
architecture.md §5 (generated rooms), so code comments can cite them as
"phase-5-design.md 5.6.x".

---

### 5.6 Phase 5 design: four new room types (approved 2026-10-22)

**Scope (Q1, recommended):** R03 Hypostyle Stacks, R11 Cistern Archive,
R09 Light-Well Stair and R05 Caravanserai, in that order (Q2). The Overlook
and R10 Chasm Spans move to a later phase (5.6.11).

**Finish line:** each type is added mostly through modules and `.tres`
rules. Measured per step as new GDScript lines outside `tests/` and
`tools/`: R11 ≤ 150, every other type ≤ ~500. All tuning lives in resources.

#### 5.6.1 What the generator assumes today

Phase 2 built the generator around one room type. What is R02-specific:

| Piece | R02 assumption | Phase 5 needs |
|---|---|---|
| `CellGrid.cells` | `kind` ∈ floor, corner, collapsed, alcove; `run` (barrel axis); `bay` | Cell kinds per grammar; a ceiling slot per cell (dome, oculus, open sky); a floor slot per cell (basin, causeway) |
| `RoomBuilder.build` | A barrel vault per cell (cross vault at corners); gables at run ends; posts only at the ends of solid edges | Ceiling and floor slots read from the cell; posts wherever the grammar marks a corner (free-standing columns); arcade edges between open cells; no gables unless asked |
| `ModuleRule.SLOT_SHAPES` | A fixed list of 13 slots | Slots added by data (`edge:arcade`, `cell:dome`, `cell:oculus`, `post:column`, `cell:case`, `landmark` …) |
| Entry | The S side of cell (0,0,0), host door | Unchanged: a hall lays out around its entry cell (it may extend to negative x) |
| `GeneratedRoom` | Wear lanes from the run tree | Unchanged: `RoomGrammar.wear_lanes` already works on any tree of open edges |
| Planning | `AreaPlanner` asks the grammar for a layout at an exit, inside blockers | Unchanged for R03/R11/R05; R09 adds storeys (5.6.6) |

**Step 1 starts by moving these assumptions out of `RoomBuilder` into the
grid**, so the builder only reads what the grammar wrote:

- `cells[c]` gains `floor_slot` and `ceiling_slot` (default `cell:floor`,
  and `cell:ceiling` / `cell:ceiling_cross` as R02 sets them today);
- `grid.posts`: corner key → slot (R02's grammar fills it with the corners
  it gets today);
- `grid.gables`: edge key → true (R02's grammar fills it as today);
- `ModuleRule.slot` becomes a free string checked against the module's
  shape by a prefix (`edge:`, `cell:`, `post:`, anything else = FREE).

**Regression guard:** for R02 seeds 1–50, `GeneratedRoom.module_signature()`
(every module name, scene and transform) is identical before and after.
`r02_route_test`, `r02_bake_test`, `area_route_test` and `stream_test` all
stay green, and the baked west gallery is untouched.

#### 5.6.2 R03 Hypostyle Stacks: `HypostyleGrammar`

**Layout** (`gen/grammars/r03_hypostyle.tres`; every number below is an
export):

1. **Size.** Width and depth in bays from `size_min`..`size_max` (Q5:
   6..10). The planner offers its blockers; the grammar tries sizes from
   the seed's pick down to `size_min` until the rectangle fits. The entry
   door is on the S wall near the middle (offset by the seed, at most one
   bay off centre).
2. **Doors.** `exit_count` (0–3) more doors on the other walls, never
   opposite the entry in a straight line (the sightline rule, 2.1). The
   planner can grow rooms from them, as from a gallery's exit.
3. **Landmark.** The centre 1 × 1 or 3 × 3 bays (`landmark_size`, odd).
   One cell prop in slot `landmark` (Q6: great lamp, reading tree,
   catalogue desk; a `SocketSet`, so its weights are tunable). The ceiling
   above it is `cell:oculus`.
4. **Aisles.** From every door, a straight run of open cells toward the
   landmark, with one dog-leg allowed (`aisle_bend_chance`). Then
   `cross_aisles` straight runs from wall to wall. Aisle cells never hold a
   case.
5. **Cases.** Every other cell holds a freestanding bookcase
   (`cell:case`) with chance `case_density`. A flood fill from the entry
   then checks every open cell is reachable; a case that seals one off is
   removed.
6. **Columns.** A `post:column` on every interior grid corner. Perimeter
   corners take `post:engaged` (a half column against the wall).
7. **Arches and domes.** Every edge between two hall cells is
   `edge:arcade` (a spandrel arch springing from the columns); every cell's
   ceiling is `cell:dome` (four tile patterns through a `SocketSet` on the
   dome module), except the oculus.
8. **Walls.** The perimeter is `edge:solid` / `edge:recess`, from
   `r03_brick.tres`: shelf recesses, as in R02.
9. **Step 2 additions.** `lamp_cluster_every` (lamps hang from dome
   centres on a lattice), `collapse_chance` (a bay of rubble, its dome
   missing, never on an aisle), sizes up to 10 × 10.

**Checks** (`tests/r03_layout_test.gd`, seeds 1–20, headless): the
rectangle fits inside the blockers; every door's aisle reaches the
landmark; every open cell is reachable from the entry; no case touches a
door cell; the same seed gives the same layout; at least `case_density`
± 0.1 of the non-aisle cells hold a case.

**Route** (`tests/r03_route_test.gd`): the real player capsule walks from
the entry along every aisle to the landmark and out of every door, with
`body_test_motion`, as `r02_route_test` does.

#### 5.6.3 Batching repeated modules (step 2)

A 10 × 10 hall has 100 domes, 121 columns, 100 floors, about 180 arcade
arches and 40–60 cases: roughly 550 modules, several meshes each. Each
`MeshInstance3D` is its own draw call in Forward+, and the per-view budget
is 1,500 (architecture §8.2).

Step 1 measures the real number on an 8 × 8 hall. If it goes over 600 draws
in view (what leaves room for a neighbouring room and the HUD), step 2 adds
**batched building**:

- a `ModuleRule` gets `batch: bool`. `RoomBuilder` builds a batched rule's
  modules off the tree as usual, then moves each `(mesh, material)` pair
  into one `MultiMeshInstance3D` per room, with per-instance transforms;
- collision stays per module (static bodies are cheap), and a batched
  module's empty wrapper keeps its name, so sockets and save ids keep their
  paths;
- a module with sockets, lights or anchors is never batched (its rule
  can't set `batch`; `ModuleRules.check()` reports it);
- shadows: one multimesh casts like its parts; the light budget is unchanged.

Gate: `area_walk_capture --gate` on a Lower Stacks walk that crosses the
largest hall (10 × 10): draw calls ≤ 1,500, and the base-spec frame
targets (Q7 of phase 4).

**Outcome (step 2, 2026-10-23): not built.** Step 1 measured 43–109 draw
calls a view in a 7 × 7 hall, and the gate on a 10 × 10 hall peaks at 443
in all passes: Godot 4.7's Forward+ renderer already merges repeated meshes.
The gate passes without batching ([progress](progress/phase-5-kit-breadth.md)).

#### 5.6.4 R11 Cistern Archive: `CisternGrammar extends HypostyleGrammar`

The hall's layout with these overrides (`gen/grammars/r11_cistern.tres`,
styles `brick`, `cistern`; `gen/rules/r11_cistern.tres`):

- **Floor:** every cell's floor slot is `cell:basin` (a floor 1.1 m down,
  with walls down to it at the room's edge), except the causeway and
  platforms.
- **Causeway:** the entry aisle continues to a door on the far wall: slot
  `cell:causeway` (a raised path at floor level with low kerbs). The far
  door is `edge:vault_door` (a sealed bronze door; a STATE socket: sealed,
  forced, open, all impassable in phase 5).
- **Platforms:** `cell:platform` in place of cases (a timber deck above the
  waterline with crates of books).
- **Piers:** the rules map `post:column` to square brick piers for the
  `cistern` style; the domes become plain brick domes. No new layout code.
- **Water:** one `WaterPlane` node per room at `water_level` (−0.4 m, an
  export), with the existing `kit/materials/water.tres`, and an `Area3D` on
  physics layer 7 (`water`).
- **Wading (Q10):** inside the water area the player moves at
  `wade_speed_factor` (0.5). Cells whose basin is deeper than
  `max_wade_depth` (0.9 m) get an invisible blocking box on the player's
  layer only, so you stop at their edge. Water depth is per cell
  (`depth_noise` from the seed, between 0.3 and 1.1 m).

New code: the subclass (overrides of `_floor_slot`, `_case_slot`, the
causeway pass), `WaterPlane` (about 60 lines), and the player's wade check.
Target ≤ 150 lines.

#### 5.6.5 New kit pieces

Seeded by new Blender scripts (`tools/kit_add_r03.py` and so on, the way
`kit_add_r01.py` seeded R01's), after which the `.blend` files are edited by
hand. Families follow architecture §3.2:

| Step | File | Modules |
|---|---|---|
| 1 | `kit_vaults.blend` | `dome_cell_4m` (tile socket: 4 patterns), `oculus_cell_4m`, `arcade_arch_4m` (spandrel, one per edge) |
| 1 | `kit_columns.blend` | `post_column_twisted`, `post_column_engaged`, `case_freestanding_4m` (two shelf faces, SHELF_FILL sockets) |
| 1 | `kit_dressing.blend` | `landmark_great_lamp`, `landmark_reading_tree`, `landmark_catalogue_desk` (with an `ANCHOR_` for a future librarian) |
| 2 | `kit_dressing.blend` | `rubble_bay_4m` (collapsed dome debris) |
| 3 | `kit_water.blend` | `basin_cell_4m`, `basin_edge_4m`, `causeway_cell_4m`, `platform_cell_4m`, `post_pier_brick`, `dome_brick_4m`, `wall_vault_door_4m` |
| 4 | `kit_vertical.blend` | per radius (8 m and 12 m): `ring_wall_seg`, `ring_wall_seg_recess`, `ring_wall_exit` (a 3 m arch over two segments), `ring_gallery_seg`, `ring_balustrade_seg`, `ring_stair_seg`, `ring_oculus_cap`, `ring_floor` |
| 5 | `kit_court.blend` | `court_cell_bay` (ground), `court_cell_bay_upper`, `court_corner_stair`, `court_pishtaq_gate`, `court_hearth_platform`, `court_well`, `court_parapet_4m`, `lantern_string`, `cavern_ceiling_patch` |

All world-triplanar at 32 tx/m, collision from `-col` meshes, on the 4 m
grid except the ring pieces (5.6.6).

#### 5.6.6 R09 Light-Well Stair: `RingGrammar` and the first multi-storey room

**Off the grid.** A ring is laid out by angle, not by cell edge. Its
pieces are FREE-shaped modules placed by `RingGrammar` directly (the
escape hatch architecture §11 allows for organic layouts). Two fixed radii
(Q8): 8 m (18 segments of 20°, chord 2.78 m) and 12 m (24 segments of 15°,
chord 3.13 m). One storey is 4 m (Q7).

**Layout** (`gen/grammars/r09_lightwell.tres`): `radius` (8 or 12),
`levels` (Q9: 3–6), `handedness`, `exit_levels` (which levels have an exit,
at least the top and the entry level), `recess_chance` per wall segment,
`collapse_chance` per gallery segment (never on the stair's landing),
`lamp_every_segments`.

- Each level: a ring of wall segments (plain, recess, or an exit arch
  spanning two segments), a gallery slab ring with a balustrade on its
  inner edge, and lamps under the gallery.
- The stair: one tread segment per angular step hugging the wall, rising
  4 m per full turn (0.22 m per 20° segment at 8 m radius: about 6°, an
  easy climb). Each level's landing is the gallery slab where the stair
  meets it.
- The bottom: a floor disc with a shallow pool under the oculus; the top:
  `ring_oculus_cap` with a pale light shaft (a SpotLight3D and a fog
  volume).

**Plan cells.** The ring reserves the square of cells around its radius
(4 × 4 cells for 8 m, 6 × 6 for 12 m) on every storey it spans. Its
connectors carry their storey, so `AreaPlanner` grows rooms off upper exits
on those storeys. The 3D overlap check already rejects two rooms in one
cell on one storey (phase 4, 8.1.9).

**Visibility.** You can see across the shaft into every exit on every
level, so the planner adds every room joined to a ring to the ring's
visible set (a rule for "vertical rooms", flagged on the grammar). With up
to 6 levels, that can be 6 live galleries while you're in the ring. Step 4
measures it against the frame budget; if it's too many, the far side's
galleries stream as stand-ins later (not phase 5), and the cap is
`exit_levels ≤ 4`.

**Safety.** The balustrade has collision; a safety floor sits under the
bottom (AGENTS.md §6); the capsule route climbs the whole stair and walks
out of every exit (`tests/r09_route_test.gd`).

**Validate Room** assumes grid modules. Ring modules are FREE, so it skips
its edge-gap check for them, and `RingGrammar.check()` verifies instead that
the segments close the circle and the stair's treads meet each landing.

**Floor wear** stays on storey 0 only (the wear map is one 2D texture).
Upper galleries get none. Per-storey wear is a later item.

#### 5.6.7 R05 Caravanserai: `CourtyardGrammar` plus bake

A template, in the atlas's words: three sizes of the same plan.

- `CourtyardGrammar` (`gen/grammars/r05_court_5x5.tres` and later
  `_3x3`, `_7x5`): a ring of `court_cell_bay` edges facing the court on two
  storeys, a corner stair in two corners, the gate (`court_pishtaq_gate`)
  on the entry wall, the hearth platform at the centre, and the well
  off-centre. The court cells have `ceiling_slot` = none: the court is open
  to a `cavern_ceiling_patch` 14 m up, dark rock lit by the hearth.
- **Cell contents** are a socket on each cell bay (`court_cell_contents`
  set: bedroll, stable, storeroom, spice stall, ruin, empty) and the hearth
  is a socket (fire pit, brazier ring, tannur oven), so a caravanserai's
  feel is all `SocketSet` weights.
- **Bake:** each size is generated once and baked into
  `rooms/baked/caravanserai_5x5.tscn` with the phase 2 bake tool, then
  finished by hand, as the west gallery was. It's a scene room in the
  plan, so it keeps its seed and its saved changes.
- **Q12:** the hearth is a place, not the cooking pot. An `ANCHOR_sit`
  ring around it is ready for travellers.
- **The Lower Stacks** start here from step 5: the caravanserai is the
  recipe's root (pinned), with the hall, cistern and light-well beyond its
  gates.

#### 5.6.8 The Lower Stacks recipe (`gen/recipes/lower_stacks.tres`)

A second `AreaRecipe`, id `lower_stacks`, on the Esc menu as **Walk the
Lower Stacks** and reachable with `--area=lower_stacks`. Its own
`AreaPlacement` envelope, its own save bucket, its own atmosphere (a
cooler, deeper grade than the wing).

| Step | Root | Slots and growth |
|---|---|---|
| 1–2 | R03 hall | R02 galleries grow from its doors (1–3), then more galleries |
| 3 | R03 hall | + one R11 cistern off a gallery |
| 4 | R03 hall | + one R09 light-well off a gallery; galleries grow from its upper exits |
| 5 | R05 caravanserai (pinned) | the hall off the gate; the rest as above |

`recipe_version` goes up at each step. Changes saved in the Lower Stacks
during review may go stale between steps (kept, counted, never applied, as
8.1.6 says). The library wing doesn't change.

#### 5.6.9 Gates (every step)

| Gate | Checks |
|---|---|
| Layout tests (per type) | 5.6.2's list for R03 and R11; ring closure and landings for R09; court symmetry and gate placement for R05; 20 seeds each, headless |
| Route tests (per type) | The real player capsule (radius 0.35, height 1.8) walks every aisle, the causeway, the stair to every level, every court cell and both corner stairs, with `body_test_motion` |
| `area_plan_test`, `area_route_test`, `stream_test` | Run on both recipes (the wing and the Lower Stacks); the recess check from b88fd74 covers the new rooms |
| `area_walk_capture --gate` | A Lower Stacks walk at the base spec (Medium, 1080p): GPU ≤ 4 ms and CPU ≤ 8 ms per frame, draw calls ≤ 1,500, shadowed lights ≤ 4 |
| Persistence | `persist_gate.sh`'s two area processes also run on the Lower Stacks: a change in the hall and one on an upper light-well level survive a restart |
| GPU captures | Each new type from its atlas viewpoint, compared side by side with the atlas mock; you review the look before the next step |
| "Little new code" | The step's report lists new GDScript lines per type (5.6, finish line) |
| Existing | Every gate from phases 0–4, unchanged |

#### 5.6.10 Risks

- **Draw calls in big halls** (5.6.3). Mitigation: measure in step 1,
  batch in step 2. If batching isn't enough, Q5's cap drops to 8 × 8.
- **A tall shaft and the bounce light (SDFGI).** SDFGI's cascades are
  sized for the wing; a 24 m shaft with a light shaft from the top may
  leak or flicker. Mitigation: step 4's captures look for it; the fallback
  is a `VoxelGI` volume for the ring (a look change, shown to you first).
- **Water cost at the base spec.** `kit/materials/water.tres` is a plain
  alpha-blended material (alpha 0.82, no refraction), cheap on its own, but
  a 40 m sheet of transparency over a lit basin adds overdraw, and
  reflections of the lamps would want a reflection probe. Mitigation: the
  frame gate covers the cistern; if it's over, the basin floor goes darker
  and the water becomes opaque with a probe (a look change, shown first).
- **Off-grid pieces and the tools.** The Kit dock and Validate Room are
  grid tools. Ring pieces are placed only by the grammar in phase 5; the
  dock lists them but doesn't snap them.
- **The vault-shortening fix (b88fd74) scales a module**, which
  architecture §3.1 forbids. It's safe for world-mapped materials and is
  limited to clearance at recesses. If a new type's modules use UV-mapped
  materials (doors, boats), they must not be shortened. `_clear_recesses`
  only touches CELL modules, and none of phase 5's UV-mapped pieces are
  cells.

#### 5.6.11 What moves out: the Overlook and R10 (a later phase)

They need, in order: a cavern **area type** (open sky of rock, facades on
its walls, frontage slots, §2.1); **thresholds** so you can walk between
the wing and a cavern area; **stand-ins** for far facades and far rooms;
then porting `vista.gd`, `cavern.gd`, `vista_cliff.gd`, `vista_foreground.gd`
and `vista_light.gd` (about 1,660 lines) into kit modules and an R10 path solver, gated by pixel comparison
against the box-art-matched captures (`tests/compare_vista.gd`,
`previews/vista_v022.png`). That's a phase of its own, with its own
approval brief.
