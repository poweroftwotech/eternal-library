# Phase 6 technical design: the Overlook and the Chasm Spans (§5.7)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Plain-language brief: [phase-6-approval.md](phase-6-approval.md) · Status: **approved 2026-10-25 (Q2: rebuild from kit pieces)**

The detail behind the brief. Section numbers (§5.7.x) are stable once code
cites them. Architecture references are to [architecture.md](architecture.md).

## 5.7.1 What exists

- **The gorge scenery** is built by code when the camp loads:
  `scripts/world.gd` makes `Vista.new(self, art)` and calls `build()`.
  `vista.gd` (903 lines) builds the balcony, eight banks of stepped
  towers with facades (`bank`, `facades`, `arcade`), six aqueducts
  (`bridge`), four cascades, the sanctum, then `cavern.gd` (the vault,
  stalactites, throat spurs, mist floor), `vista_foreground.gd` (the
  rock-cut stair, lamassu), `vista_cliff.gd` (the cliff and loggia under the
  balcony) and `vista_light.gd` (lamp clusters, haze, the sanctum's glow).
  It draws through the camp's `Factory` (`art.box`, `art.mat`, merged
  static groups) and calls back into `world` (`world.light`,
  `world.add_child`). Later camp passes (`art_direction.gd` and others)
  touch some of its materials.
- **Render layers:** balcony 1 (the interior's light layer), gorge 2,
  enclosure 4, so the gorge's lights never reach the camp.
- **No walking collision** beyond the balcony's blocks (`solid` = true) and
  guards. The far geometry has none.
- **The box-art gate:** `tests/compare_vista.gd` with the `vista_concept`
  capture mode and `tools/capture_vista.bat`.
- **Areas** (phase 4–5): `AreaRecipe` → `AreaPlanner` (3D cell plan, rooms
  joined by connectors, a tree) → `Area` (builds, streams, light budget).
  **Travel** (`main.travel`) saves, shows the dark loading panel and
  reloads into another area or the camp; the save keeps the area, the room
  and the player's position.

## 5.7.2 The gorge from kit pieces (step 1; Q2)

A new recipe `gen/recipes/gorge.tres`, id `gorge`, on the Esc menu as
**Walk the Gorge** (Q1). Its scenery is a **baked scene**,
`rooms/baked/gorge.tscn`, made once by a generator and then yours to edit.

- **The layout as data.** What `vista.build()` hard-codes moves to
  `gen/gorge/gorge_layout.tres` (`GorgeLayout`): the eight banks (centre,
  radii, top, seed, turn), the sanctum, the six aqueducts (ends, width,
  falls, tiers), the cascades, the enclosure path, the mist volumes. The
  numbers are today's, so the composition is the same.
- **`GorgeGrammar`** (`scripts/gen/gorge_grammar.gd`) lays the layout out in
  kit pieces. Each bank gets its own frame (its centre, turned by its
  `turn`), and its tiers are stepped notched rectangles on that frame's 4 m
  grid, as `tower_outline` makes them, but with whole-bay sides and tier
  heights of 2 or 3 storeys (8 or 12 m; the seed picks, as today's random
  8.3–11.7 m). On each tier: facade bays on every face toward the gorge
  (the module mix by position hash: `FACADE_*` fractions as today), corner
  piers, a deck on exposed tops with a deck edge (fascia, gold band,
  balustrade, lamps, streak and moss variants by hash) or a crowned edge
  (merlons, worn variants by hash) on the top tier; terrace dressing on
  occupied tiers (figures, cypress pairs, pavilions, banners) as today.
  Crowned banks get Persian towers (tower wall and band pieces, a crown,
  a carpet), the sightline rule kept (`blocks_gate_sightline`). Aqueducts
  are runs of 12 m arcade bays (3 bays wide) in their own frame along the
  line between their ends, upper and lower tiers and piers; the sanctum is
  bank tiers plus its landmark pieces (rotunda, portal, columns, hangings).
- **What stays generated, once.** `cavern.gd` (vault, stalactites, spurs,
  throats, iwans, mist floor), the waterfall ribbons and cascades,
  `vista_light.gd` (lamp clusters, haze, the sanctum's glow, the vault
  bounce), the far enclosure's window rows: their code runs **at bake
  time**, and what it makes is saved into the scene (meshes as `.res`
  under `rooms/baked/gorge/`, lights and mist as nodes). The camp keeps
  running the original code until step 6.
- **The bake.** `tools/bake_gorge.gd`: lays out the grammar, runs the
  generated parts, writes `rooms/baked/gorge.tscn` with the kit pieces as
  instances (grouped per bank, so a bank can be edited or deleted as one),
  the generated parts under `Cavern/`, `Water/`, `Lights/`, and the
  balcony and `PlayerSpawn`. Re-baking overwrites; hand edits go in after
  the last bake, as with the other baked rooms.
- **Batching.** The scene keeps every piece as its own instance for
  editing. When it loads, `KitBatcher` (`scripts/world/kit_batcher.gd`)
  turns repeated pieces into one `MultiMeshInstance3D` per mesh and
  material (as `art.batch_mesh` does today), so 600+ facade bays cost tens
  of draw calls, not thousands. Pieces under a node marked `no_batch` stay
  as they are.
- **The look.** Pictures from the same spots as the camp's view, side by
  side, and `compare_vista` from the balcony. Halfway, one bank (the near
  left, bank 1) rebuilt next to today's for your review before the other
  seven are converted.
- **In the area.** The baked gorge is the recipe's `scenery` scene
  (`AreaRecipe.scenery`, new): instanced once when the area loads, never
  streamed, not part of the plan (it occupies no cells). Its solid masses
  are exported as keep-out boxes (`GorgeScenery.keep_out`, from the bake's
  tier footprints) that the planner treats as blockers, so no span runs
  through a tower. Its lights are on layer 2, outside `LightBudget`'s
  rooms (§5.7.8).
- **The Overlook root** (step 2): `rooms/gorge/overlook.tscn`, the balcony,
  its guards and the rock-cut stair as kit pieces (the balcony rebuilt to
  the same shapes), ending on a cliff ledge with a `SNAP_exit` at its far
  end. Its `PlayerSpawn` is where the camp's balcony view starts.
- **Atmosphere.** The camp's environment (fog, grade, SDFGI) as the
  recipe's `AreaAtmosphere`, so the view matches `vista_concept`.

## 5.7.3 Frontage slots

Where walkable pieces may meet the cliffs: `gen/gorge/frontage.tres`, a list
of `FrontageSlot` (area-frame transform on a cliff face, -Z out over the
gorge; storey; width in bays; `door` area id or ""). Seeded once by
`tools/gorge_frontage.gd` from the near banks' polygons (faces facing the
gorge's axis, at storey heights between the balcony and about 30 m below),
then editable by hand. Slots are where ledges are planned (§5.7.5) and
where doors open (§5.7.6).

## 5.7.4 R10 Chasm Spans: `ChasmGrammar` (steps 3–4)

A `RoomGrammar` that solves a walkway between **two fixed connectors**
(phase 2–5 rooms grow from one connector; a span is placed after both of
its ends exist).

- **Frame.** The span's room frame puts its start connector at the origin
  with the run along -Z; the end connector is transformed into it. The
  solver works on the 4 m grid in that frame; the end must land on a grid
  edge within ±1 bay sideways (frontage slots are seeded to allow this; a
  pair that doesn't is not joined).
- **Bridge** if the horizontal gap is ≤ `bridge_max_bays` (10, 40 m) and the
  height difference ≤ `bridge_max_rise` storeys (1, through a ramp bay of
  1 in 8 at each end): a straight run of `deck` cells, each on an aqueduct
  bay (upper arcade; lower arcade every other bay below; plain piers down to
  `pier_depth`, below which the piers are a merged stand-in into the mist).
  `falls_every` arches pour a waterfall (the scenery's `waterfall` look as a
  kit piece). Lamps every `lamp_every_bays`.
- **Stair chain** otherwise: landings and straight flights (one storey per
  two bays, the kit's 27° stair) zig-zagging along the cliff face from the
  start ledge down or up to the end's storey, then a bridge for what's left
  across. Each flight is a cell pair on the cliff's side of the span.
- **Edges.** Every open side has a parapet (Q4); a deck's sides are
  `edge:parapet` (balustrade between merlons), its ends open to the next
  piece. The spans' walkable widths are 3 m between parapets on a 4 m deck
  (Q8).
- **Sockets.** Deck traffic anchors (places for caravans and walkers,
  empty in phase 6), lamp state (aging, as the library's lamps), waterfall
  per arch.
- **Rules.** `gen/rules/r10_spans.tres`; `gen/grammars/r10_chasm.tres`
  (bridge_max_bays, bridge_max_rise, pier_depth, falls_every,
  lamp_every_bays). Target: under 400 lines of grammar.
- **As built in step 3** (`scripts/gen/chasm_grammar.gd`, 516 lines with the
  room builder): the span grows from one connector (the Overlook's
  `SNAP_exit_span`) and finds its own far end, walking out bay by bay
  against the banks' tiers (`GorgeGrammar.keep_out`, with their decks'
  overhang); the far ledge is the span's own head row, its back connectors
  (`SNAP_exit_far_*`) left for steps 4–5. Spans are a room kind of their own
  (`AreaPlan.Room.kind` "span"), not a CellGrid. bridge_max_bays is 24 (bank
  to bank is about 80 m); no ramps (bridge_max_rise): a lower head is a
  chain of flights and landings, in its last bays. The arcades are the
  scenery aqueducts' 12 m pieces; piers stand in the mist or on a terrace
  clear of its edge and dressing, or are left out. Pieces are named in the
  grammar (no `r10_spans.tres` rules yet).

## 5.7.5 Ledges, loggias and the network (step 4)

- **`CliffLedgeGrammar`**: a strip 2–5 bays long along a frontage slot,
  one bay deep, its outer edge a parapet, its back the cliff (scenery) or
  a loggia (kit loggia bays: an arcade in front of a shallow room), lamps,
  and connectors: one at each end and one on the front edge where a span
  may leave. A slot with `door` gets a facade door bay on its back edge
  (§5.7.6).
- **The network.** After the root, `AreaPlanner` places 4–6 ledges on
  frontage slots (seeded), then joins them with spans as a **tree**: the
  candidate pairs (any two ledge connectors facing each other across or
  along the gorge) sorted by length, taken greedily while they join two
  separate parts (Kruskal), each solved by `ChasmGrammar`; a pair that
  doesn't solve or hits a blocker is skipped. Loops stay out (phase 5's
  Q4), so every ledge has one way to it.
- **The scenery aqueduct** at y ≈ -19 between the near banks
  (`vista.bridge(Vector3(-37,-19,-89), …)`) is removed from the scenery
  when the Gorge area builds (Q9), and its two ends become frontage slots
  with a fixed span between them in the network, so the view keeps an
  aqueduct where it had one. The camp's own view keeps the scenery one.

## 5.7.6 Thresholds (step 5)

- **The connector.** A frontage slot's `door` makes its ledge build a
  facade door bay with a `THRESHOLD_<area>` connector. In the plan it's a
  dead end (nothing joins it).
- **Crossing.** A trigger in the doorway calls `main.travel("area:<id>")`
  with an arrival: `WorldState.data["arrive"] = {"from": "gorge", "slot":
  <slot id>}`. The target area places the player at its arrival marker
  instead of its spawn: the Lower Stacks at the caravanserai's gate
  (outside the pishtaq, facing in), the library wing at R01's entrance.
- **Back.** Those arrival points get a threshold back: the caravanserai's
  gate exit and R01's entrance door become `THRESHOLD_gorge` doors when the
  area was entered from the gorge (the save remembers which slot), and
  arriving in the gorge puts you on that slot's ledge, facing out.
- **Saves.** Unchanged in shape: `area`, `room`, `player` as today; the
  gorge is just another area. The persistence gate adds two processes: save
  on a gorge ledge → load there; enter the Lower Stacks from the gorge,
  save → load inside, walk back out to the right ledge.

## 5.7.7 Streaming and stand-ins

The scenery is always live. Ledges and spans are ordinary rooms and stream
as today; the near chamber is small enough that most will be live at once.
The piers below `pier_depth` and any span beyond the streaming radius use
the plan's `stand_in` state (architecture §2.1): a merged, unlit,
collision-free mesh made at bake time (`RoomBaker.stand_in`). Phase 6 adds
the `stand_in` state to `AreaStreamer` only if the frame gate needs it
(step 5).

## 5.7.8 Budgets in the gorge (steps 1 and 6)

The library's budgets (architecture §8.2) count lights within 35 m of the
camera; the gorge's scenery lights are few, large and far (`big_light`,
10–100 m ranges). The frame gate in the gorge counts room lights (ledges,
spans) against the 50 as before, and reports scenery lights separately;
the GPU time and draw calls are the real check. If the gorge needs its own
limits, step 5 brings measurements first.

## 5.7.9 The camp link (step 6)

The camp's balcony view instances the baked gorge (the same scene as the
Gorge area's scenery), so there's one gorge to edit; `vista.gd`,
`cavern.gd`, `vista_cliff.gd`, `vista_foreground.gd` and `vista_light.gd`
are then only used by the bake tool, and the camp's tests that counted the
old builder's output (`tests/playtest.gd` lines 113–116) count the baked
scene's pieces instead. Its balcony stair
gains a threshold (`THRESHOLD_gorge`, arrival: the Overlook's spawn); the
Gorge's balcony door leads back to the camp. Camp tests (`playtest`) keep
passing; the camp's layout notes in `tests/playtest.gd` are updated if the
balcony changes.

## 5.7.10 Kit pieces

**The gorge** (`art_src/kit/kit_gorge.blend`, `tools/kit_add_gorge.py`, step
1), about 30, each modelled to today's shapes (the dimensions in
`vista.gd`):

| Piece | Shape | From today's |
|---|---|---|
| `gorge_bay_window`, `_balcony`, `_doorway` | edge, 4 m × 1 storey | `arch_bay_module`: pointed arch frame, lit lattice, sill trim; balcony slab and balusters; doorway step (a figure anchor) |
| `gorge_bay_stack`, `_stack_ladder` | edge | `stack_bay`: framed book stack, cornice; with a rolling ladder |
| `gorge_bay_panel` | edge | `tile_panel`: faience panel in a sandstone surround |
| `gorge_pier` | post, 1 storey | the slim projecting supports at tier corners |
| `gorge_tier_core` | cell | the tier's mass behind its facades (batched, unlit faces culled) |
| `gorge_deck` | cell | the deck on a tier's exposed top |
| `gorge_deck_edge` (+ `_streaked`, `_mossy`) | edge | faience fascia, gold band, balustrade, rail, a lamp every third |
| `gorge_crown_edge` (+ worn variants) | edge | crowned top: fascia and stepped merlons (lost, capless, repaired by hash) |
| `gorge_tower_wall` | edge, 1 storey | Persian tower face: two windows a storey, band course |
| `gorge_tower_crown` | edge | the tower's crown and merlons |
| `gorge_carpet`, `gorge_banner_*` (3) | free | hanging carpet; the three tapestries |
| `gorge_pavilion`, `gorge_rotunda` | free | roof pavilion; the fluted rotunda with its dome |
| `gorge_cypress` | free | the lathed cypress (heights as variants, no scaling) |
| `gorge_figure` | free | the seated reader |
| `gorge_lamp`, `gorge_lamp_lit` | free | the small lamp, with and without its own light |
| `aqueduct_upper_12m`, `aqueduct_lower_12m`, `aqueduct_pier_20m` | cell, 3 bays | `bridge`'s round-arch tiers and plain piers (stacks) |
| `aqueduct_deck_12m` | cell | deck, faience course, gold rails, balusters |
| `sanctum_portal`, `sanctum_column`, `sanctum_hanging` | free | the sanctum's door, fluted columns, wing reliefs |

**The walkable spans and ledges** (`art_src/kit/kit_chasm.blend`,
`tools/kit_add_r10.py`, steps 2–4), about 15:

| Piece | Shape | Notes |
|---|---|---|
| `chasm_deck_4m` | cell | deck slab, 4 m, walk surface 3 m |
| `chasm_parapet_4m` | edge | balustrade between merlons, 1.1 m |
| `chasm_arcade_upper` / `_lower` | cell | the aqueduct's round-arch tiers (the scenery's `arch_bay` proportions) |
| `chasm_pier_8m` | cell | plain pier, stacks |
| `chasm_ramp_4m` | cell | 1 in 8 ramp bay |
| `chasm_stair_flight` | cell, 2 bays | one storey, 27°, ramp collision over the nosings |
| `chasm_landing` | cell | stair landing with parapets |
| `cliff_ledge_4m` | cell | ledge on corbels, cliff side open |
| `cliff_loggia_bay` | cell | arcade in front of a shallow room |
| `facade_door_bay` | edge | a door in a carved facade, threshold marker |
| `chasm_lamp_post` | free | deck lamp (lantern profile) |
| `chasm_fall_lip` | free | waterfall out of an arch (the scenery's material) |
| `balcony_stair_*` | cell | the Overlook's rock-cut stair, re-modelled to the scenery's shape |

## 5.7.11 Tests and gates

| Test | Checks |
|---|---|
| `gorge_scenery_test` (new) | the gorge bakes; the baked scene is the grammar's layout piece for piece; every bank's keep-out box covers its tiers; batching leaves the same meshes drawn; the camp still builds its own until step 6 |
| `compare_vista` from the Gorge area | the box-art numbers from the Overlook's spawn, as from the camp balcony today |
| `r10_layout_test` (new) | spans, 20 seeds per kind: joins both ends, parapets on every open side, no step steeper than the kit's stair, nothing inside the keep-out |
| `gorge_route_test` (new) | the real capsule from the balcony to every ledge and over every span, through every door; can't leave a walk surface |
| `area_plan_test` | the Gorge plans clean on seeds 1–20, as a tree, no overlap |
| `persist_gate.sh` | two more processes (§5.7.6) |
| frame gate | `area_walk_capture --area=gorge` at the base spec |

## 5.7.12 Risks

- **The look.** A kit rebuild quantises tiers to storeys and bays to 4 m;
  later camp passes (`art_direction.gd` and others) also tweak the gorge's
  materials, and those tweaks must move into the kit materials. The
  one-bank review in step 1 and `compare_vista` catch it before the whole
  gorge is converted.
- **Spans and scenery may clash** where the keep-out boxes are coarse
  (towers are stepped, boxes aren't). Frontage slots are seeded clear of
  them, and the layout test checks every span against the boxes.
- **Exterior lighting falls off differently** (`big_light`, attenuation
  0.5); ledge and span lamps use the kit's lantern profile, which may read
  dim at gorge scale. Step 2's pictures check it.
- **SDFGI and fog at 300 m** are the camp's settings; an area's atmosphere
  hasn't been asked to do that before.
- **Code size.** Estimated: GorgeGrammar ~500 lines, the gorge bake ~200,
  KitBatcher ~120, ChasmGrammar ~400, CliffLedgeGrammar ~200, thresholds
  ~150, planner network ~120.
