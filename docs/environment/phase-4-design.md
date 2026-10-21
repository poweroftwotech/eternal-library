# Phase 4 design: areas and streaming (technical)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-20 (recommended answers to Q1–Q11); step 1 in progress** ·
Plain-language version: [phase-4-approval.md](phase-4-approval.md)

This is the engineering detail behind the approval brief: classes, the area
plan, save ids, the streaming loop, the light budget and the gates. You
don't need to read it to approve. Its section numbers (§8.1.x) continue the
architecture's §8 (streaming, performance, lighting).

---

### 8.1 Phase 4 design: areas and streaming (draft 2026-10-20)

Done when (§10): an area of 6–10 rooms (R01, several R02, one baked room)
streams without hitches at the frame target.

**What exists today.**

- **Rooms nest under a host.** A `GeneratedRoom` with `join_connector` is a
  child of R01 (`reading_room_r02*.tscn`, `Multrooms-test1.tscn`). It finds
  the host by walking up the tree (`host_room()`), moves itself onto the
  host's connector (`_join`), keeps out of the host's and its siblings'
  modules (`_host_blockers`, `_room_blockers`, `claim_key`), and takes the
  host's `gallery_build` style (`inherit_style_groups`). Siblings are one
  level deep only: rooms joined to a gallery's exit block nothing.
- **Gallery exits.** `end_kind = exit` leaves a `SNAP_exit_<edge>` connector,
  a free cell beyond, and an `exit_glow` stub (a warm card, a shadowed light
  and a blocker) "until phase 4 joins a room there".
- **Seeds.** `RoomTemplate.area_seed` exists ("set by the area assembler")
  but nothing sets it. R01 resolves from `preview_seed` (1). Galleries use
  `gen_seed`, or the process-wide `GeneratedRoom.seed_override` static
  (`--gen-seed`, the Esc menu's reseed, the save's `gen_seed_override`).
- **Baking.** `RoomBaker` writes a plain `RoomTemplate` that keeps `room_id`,
  the seed as `preview_seed`, node names and its transform relative to the
  host. `rooms/baked/stack_gallery_west_7.tscn` (and `_97255`, used in
  `Multrooms-test1`) exist. A bake is a snapshot of one door's layout.
- **Loading.** `main._ready` does `load(room_path).instantiate()` on the main
  thread and adds it as `Environment`. Travel reloads the whole scene.
  Nothing loads or unloads while you play.
- **The save.** `WorldState.AREA = "library"` holds every delta. Ids are
  `room_key/path`, `room_key = room_id@current_seed()`. The save stores
  `scene` (a res path or `camp`), `player` and `gen_seed_override`.
- **Floor wear.** `FloorWear` keeps one shared world map for every live
  `FloorWear`, rebuilt on the main thread when one enters or leaves the
  tree: 113 ms for R01 + seed 7, up to 129 ms in the route test. One y band.
- **Lights.** Lanterns are `OmniLight3D` without shadows (`lantern`, `cold`).
  Chandeliers and braziers cast shadows, and so does the exit stub's light.
  R02's cool fills cast none. SDFGI is on (`AtmosphereProfile.sdfgi`).
  `Atmosphere` adds its own `WorldEnvironment` "when nothing else in the world
  supplies one", which was written ahead for areas.
- **Statics** that assume one scene: `WorldProp.awake_props`,
  `FloorWear._live`, `GeneratedRoom.seed_override`, `main.room_override`.
- **Cost today:** R01 with every prop frozen runs at 1.66 ms a frame on the
  RTX 5090 (entrance view, vsync off). The §8 target for a fully dressed
  room is about 5.5 ms. Nobody has yet measured how long one gallery takes
  to generate or how long R01 takes to instance.

#### 8.1.1 Classes and resources

| Piece | Kind | File | Holds |
|---|---|---|---|
| `AreaRecipe` | `Resource` | `scripts/world/area_recipe.gd`, data in `gen/recipes/*.tres` | `id: String` (the area id, Q3), `version: int`, `slots: Array[AreaSlot]`, `grow: Array[AreaGrow]`, `room_count: Vector2i` (6–10), `max_dead_ends`, `max_sight_depth: int` (2), `atmosphere: AtmosphereProfile`, `age_rules: AgeRules` |
| `AreaPlacement` | `Resource` (sub-resource) | `scripts/world/area_placement.gd` | Where the area sits in its stratum (§2.1): `origin: Vector3i` (in cells and storeys, stratum frame), `envelope: AABB` (the reserved space, area frame). Phase 4: one hand-set placement for `library` at the origin with a generous envelope. A stratum plan fills these in later |
| `AreaSlot` | `Resource` (sub-resource) | `scripts/world/area_slot.gd` | A required room: `slot_id: String` (unique in the area, becomes `room_id`), `scene: PackedScene` (authored or baked) **or** `grammar` + `rules` (generated), `parent: String` (slot id, empty for the root), `connector: StringName` (on the parent), `seed_mode` (`fixed` or `area`, Q2) |
| `AreaGrow` | `Resource` (sub-resource) | `scripts/world/area_grow.gd` | Generated rooms to add at free exits: `grammar`, `rules`, `count: Vector2i`, `slot_prefix` (`gallery`), `from: PackedStringArray` (which slots may sprout them; empty means any) |
| `AreaPlan` | `RefCounted`, pure data | `scripts/world/area_plan.gd` | The output of planning: per room its slot id, kind, scene or grammar, seed, transform in the area frame, **3D footprint boxes with a storey**, its connectors (area frame, each with a `storey`), the inherited style picks, its **visible set** (8.1.9), and the graph edges `{slot, connector} ↔ {slot, connector}`. Also the area's bounds and placement, plus the caps on unused exits. No nodes |
| `AreaPlanner` | `RefCounted` | `scripts/world/area_planner.gd` | `plan(recipe, area_seed) -> AreaPlan`. Deterministic. Runs on a worker thread (8.1.2) |
| `Area` | `Node3D` (`class_name`) | `scripts/world/area.gd` | The live area: holds the plan, owns the `WorldEnvironment` (from `recipe.atmosphere`), the `AreaStreamer` and the `LightBudget`. Rooms are its direct children, placed by the plan, never nested in each other |
| `AreaStreamer` | `Node` | `scripts/world/area_streamer.gd` | Each room's state (`RoomState`: `UNLOADED`, `STAND_IN`, `LIVE`; phase 4 uses only the first and last), which rooms should be live (graph distance from the player's room, plus its visible set), the load queue, the threaded loads, the time-sliced build, door seals and unloads (8.1.4) |
| `DoorSeal` | `StaticBody3D`, internal | `scripts/world/door_seal.gd` | Blocks a doorway whose neighbour isn't built yet (a box on layer 1) and shows a dark card. Freed when the neighbour is ready |
| `LightBudget` | `Node` | `scripts/world/light_budget.gd` | Ranks the area's shadow-capable lights and gives shadows to the nearest N (8.1.5) |
| `StreamSettings` | `Resource` | `world/area/stream_settings.tres` | `load_radius` 2 (doors), `unload_radius` 3, `unload_delay_s` 10, `build_budget_ms` 4.0 a frame, `shadow_budget` 4, `light_fade_m` 30 (Q6–Q8). These are the **Medium preset's** values: the later graphics settings (architecture §8.2) override them per preset, so nothing reads them as constants |
| `RoomTemplate` changes | existing | `room_template.gd` | `area_seed` is set by the plan. A `planned: bool` flag: the room skips its own host lookup and takes `style_overrides` and `generated_pins` from the plan. `_exit_tree` flushes moving props (`_flush_moving`) and unregisters from `WorldState` |
| `GeneratedRoom` changes | existing | `generated_room.gd` | `generate_from_plan(entry)`: the same build, but with the plan's blockers, transform and styles, and no host walk. `seed_override` is ignored inside an area. `end_kind` and exit choice are fixed by the plan (8.1.2) |
| `FloorWear` changes | existing | `floor_wear.gd` | A fixed map rect from the plan's bounds (no resize when a room arrives). A room's stamp is composed on a worker thread and copied into its region with `ImageTexture.update`, never a full rebuild (8.1.4) |
| `WorldState` changes | existing | `world_state.gd` | `AREA` becomes `area_id: String`, set by `Area` before any room enters. `deltas()` reads `areas[area_id]`. The save gains `area` and `room` (8.1.6) |

The test scenes (`reading_room_r02*.tscn`, `Multrooms-test1.tscn`, the
`_in_host` bake) keep working unchanged. Outside an `Area`, rooms nest and
join as they do today, and `--gen-seed` still works. That keeps phase 2 and
3's gates valid while phase 4 adds its own.

#### 8.1.2 The area plan: graph and routing

**Graph: a tree, joined door to door (Q4).** Every edge joins one room's
connector to another room's entry, face to face, exactly as `_join` does
today. There is no corridor routing: the R02 galleries *are* the
corridors, which is what the atlas has them for. A* routing and loops
(§5.2's "spanning tree plus a few loops") wait for a room type that needs
them (R03's grid or R09's ring in phase 5).

**Planning order** (all deterministic; the same recipe and seed always give
the same plan):

1. **Seed.** `area_seed = hash(world_seed, area_id)` (§5.4). Each choice uses
   `hash(area_seed, slot_id, what)`, never call order.
2. **Required slots, in recipe order.** The root slot (R01) sits at the
   origin. Each other slot is placed on its parent's connector. For an
   authored or baked scene, the planner instantiates the `PackedScene` off-tree
   once, reads its `Connectors`, `SNAP_entry` and module boxes (the same
   boxes `_module_boxes` reads today), then frees it. These are cached per
   scene path. A baked room is placed by its `SNAP_entry`, so it can sit on
   any connector, not only the door it was baked from. But its footprint
   still has to fit (step 4).
3. **Generated slots and grow rooms.** For each, build a `CellGrid` with
   `blockers` = every footprint placed so far, area-wide (not just
   siblings), and run `grammar.layout(grid, seed)`. That's pure data and
   needs no nodes. The grid gives the footprint and the exit connectors.
4. **Overlap and fit.** Every room's footprint must be clear of every other
   room's **in 3D** (boxes with a storey; all of phase 4 is storey 0), with
   the existing rule that only the shared door edge may touch, and every
   footprint must lie inside the area's `envelope`. A required slot that doesn't fit is a planning error (the recipe is
   wrong). A grow room that doesn't fit, or that comes out shorter than
   `min_bays`, tries its next candidate exit, in seeded order.
5. **Grow.** Free exits are candidates (required slots' exits first, then
   grow rooms' own exits, so the tree reaches outward). Pick
   `count` rooms in seeded order until `room_count` is met. Each grow room
   is a `GeneratedRoom` slot named `<slot_prefix>_<n>` (`gallery_3`).
6. **Close the leaves.** Every connector that no room joined gets a cap:
   - a gallery exit keeps its `exit_glow` stub (Q10: it reads as "more
     library beyond", and its blocker stops you);
   - an R01 door with nothing on it gets today's `host_closes` treatment.

   At most `max_dead_ends` galleries end in a plain wall; the rest get
   `end_kind = exit` so the tree can grow from them.
7. **Styles.** A generated room joined to an authored one inherits that
   room's `gallery_build` pick. The planner reads it from the cached
   off-tree instance (`style_choice(g, seed)`), so a room doesn't need its
   parent to be loaded to know its style.
8. **Sightlines.** Trace the doorway lines (8.1.9) and store each room's
   visible set. A grow room that would make any line deeper than
   `max_sight_depth` is rejected and the next candidate exit is tried, as in
   step 4.
9. **Check.** The connector graph is a tree that reaches every room from the
   root; there are 6–10 rooms; nothing overlaps in 3D; everything is inside
   the envelope; no sightline is deeper than `max_sight_depth`; every exit is
   joined or capped. These checks live in `AreaPlan.check()`, so the planner
   test and Validate can share them.

**Cost.** A gallery layout is a grid walk of tens of cells, so a 10-room
plan should take well under 50 ms. It runs on a `WorkerThreadPool` task
while the menu or the previous scene is still showing, and once more at
resume. The off-tree instances of R01 and the baked room are the
expensive part; they're cached for the session.

**Why plan the whole area up front:** a room that streams in later must be
identical whatever else is loaded. So the plan, not the live tree, decides
blockers, exits and styles. That's the change from phase 2, where a
gallery read its live siblings.

#### 8.1.3 The first recipe: `gen/recipes/library_wing.tres`

| Slot | Kind | Where | Seed |
|---|---|---|---|
| `reading_room` | authored `rooms/authored/reading_room.tscn` | root | `fixed` (its `preview_seed`, 1) |
| `stack_gallery_west` | **baked** `rooms/baked/stack_gallery_west_7.tscn` | R01 `SNAP_door_west` | `fixed` (7, baked in) |
| `stack_gallery_east` | generated R02 | R01 `SNAP_door_east` | `area` |
| `stack_gallery_entrance` | generated R02 | R01 `SNAP_entrance` | `area` |
| grow: `gallery_*` | generated R02, 2–5 of them | free gallery exits | `area` |

That's 6–9 rooms, inside the roadmap's 6–10. The baked room goes on the
west door because it was baked there and its layout is known to fit
(Q1). The `entrance` gallery replaces the code-built camp's link for this
area only; the camp itself is unchanged.

**Entering it:** the Esc menu gains **Walk the library wing**, and
`-- --area=library` on the command line. The test scenes stay on the menu
as they are. A new game still starts at the camp (Q5); a saved game
resumes wherever you were, area included.

#### 8.1.4 Streaming and unloading

**Which rooms are live.** The player's room is the plan room whose 3D
footprint contains the player (checked every 0.25 s, with the last answer
kept when the player stands in a doorway). Rooms within `load_radius` doors in
the graph should be live (Q6, default 2), **plus every room in the player's
room's visible set** and in the visible sets of the rooms one door away, so a
room you can see into is always there before you can see it. A live room further than
`unload_radius` (3) for `unload_delay_s` (10 s) unloads. The gap between 2
and 3 stops a room flickering in and out when you pace a doorway.

**Loading one room** (`AreaStreamer`, one room at a time, nearest first):

1. **Resources, threaded.** Authored and baked scenes:
   `ResourceLoader.load_threaded_request(path, "", true)`, polled each frame
   with `load_threaded_get_status`. Generated rooms: the module scenes their
   plan uses are requested the same way (most are already cached after the
   first gallery).
2. **Build off-tree, time-sliced.** The room node is instantiated and filled
   **off the tree**, on the main thread, in slices of at most
   `build_budget_ms` (4 ms) per frame. For a generated room the slice
   unit is a run of modules from `RoomBuilder`; for a scene it is the whole
   `instantiate()` (to be measured in step 1; split if it costs more than
   the budget). Building on a worker thread is allowed in Godot for off-tree
   nodes, but the kit's import-time light and socket nodes, MultiMesh
   `ShelfFill`s and physics shapes haven't been checked for thread safety.
   So threads are a measured option in step 2, not the plan.
3. **Resolve and restore, time-sliced.** `resolve_sockets` (socket spawns,
   shelf fills, claims, aging) and then `restore_world()` (the save's deltas)
   run per socket batch, still off-tree where they can. Settling (two
   physics frames) needs the tree and runs after step 4, as today.
4. **Enter the tree in one call.** `add_child` on the `Area`. Then the
   room's `FloorWear` stamp (composed on a worker thread since step 2) is
   copied into the shared map region, and its lights join the
   `LightBudget`.
5. **Open the doors.** The `DoorSeal`s on doorways between this room and
   live neighbours are freed.

**Door seals.** A live room's doorway onto a room that isn't built yet has a
`DoorSeal`: a blocker plus a dark card one metre in. With `load_radius` 2
you are always at least one whole room away from a seal at walking speed,
so you should never meet one. The stream test asserts it never blocks the
real player on the scripted walk. If it ever does, you stop briefly at a
dark arch, not fall out of the world (AGENTS.md §6 spatial rule).

**Unloading one room.**

1. Its moving props are flushed: every awake `WorldProp` is frozen where it
   is and saved (`_flush_moving`, which already runs on save). The room's
   shard sets are saved the same way.
2. Its lights leave the `LightBudget`, and its `FloorWear` region is
   cleared.
3. `DoorSeal`s go up on its live neighbours' doorways.
4. `queue_free()`. Statics are cleaned in `_exit_tree`: `WorldProp`
   removes itself from `awake_props`, and `WorldState.rooms` drops the room.

Coming back rebuilds the room from scene, plan and seed, then lays the
deltas on top. That's exactly the path a fresh process takes, so streaming
adds no new restore code, and the phase 3 gates cover it.

**Hitch sources, and what handles each:**

| Source | Today | Handled by |
|---|---|---|
| Loading `.tscn`/`.glb` from disk | main thread | threaded requests (1) |
| Instancing ~70–200 modules | one call | time-sliced off-tree build (2) |
| Socket resolve, shelf fills, settle | one call in `_ready` | time-sliced (3); settle stays deferred |
| Floor wear rebuild (113–129 ms) | main thread, whole map | fixed-rect map, per-room region update, compose on a thread |
| First use of a material or shader variant | at first draw | warm-up: the plan's module set is drawn once behind the load screen (a hidden `SubViewport`), plus Godot's ubershader fallback |
| SDFGI cascades taking in new geometry | — | measured in step 3; fallback below |
| `WorldEnvironment` swapping as rooms change | each room adds one | the `Area` owns one; rooms' `Atmosphere.own_environment` turns off inside an area |

#### 8.1.5 Light budget

- **Shadow-capable lights:** every `Light3D` under a room's `Lights` or
  module `LIGHT_` nodes whose import profile has `shadow: true` (chandelier,
  brazier) and the exit stubs' lights. Lanterns, `cold` lights and R02's fills
  never cast shadows, so they aren't ranked.
- **Every 0.2 s,** `LightBudget` ranks the lit shadow-capable lights by
  distance to the camera, and gives `shadow_enabled = true` to the nearest
  `shadow_budget` (Q8, default 4). The rest are switched to no shadows. A
  light that gains or loses its shadow fades its `shadow_opacity` over
  0.3 s, so the swap doesn't pop.
- **Distance fade on every light:** `distance_fade_enabled`, begin at
  `light_fade_m` (30 m), length 5 m. Lights further away cost nothing. R01
  is 31 m long, so a lamp at the far end of the hall still fades in before
  you reach the middle.
- **`LampState` keeps control of on and off.** The budget only touches
  `shadow_enabled`, `shadow_opacity` and the fade. A dark lamp is skipped
  because it isn't lit.
- **Forward+ limits:** the default is 512 lights per view and 32 per cluster
  cell. A 10-room area has an estimated 60–120 lights in total, of which
  only the 2–3 loaded rooms' count. Step 3 logs the real numbers.
- **SDFGI:** kept on (§8). If rooms popping into the SDFGI cascades shows
  as a visible light jump in the step 3 captures, the fallback is §11's: a
  `VoxelGI` per authored room, with SDFGI off for the area. That's a look
  change, so it would come back to you before it's made.

#### 8.1.6 Area ids, save ids, persistence and aging

**Area id** = the recipe's `id`. The first recipe's id is **`library`**,
the same as phase 3's `AREA` constant, so today's saves carry over (Q3).

**Save ids stay area-relative.** Deltas live under `areas[<area id>]`, so an
id is still `room_key/path` and the area doesn't appear in it. That keeps
every phase 3 id valid. Room keys must be unique within an area, which the
plan guarantees: `room_id` is the slot id (`gallery_3`), and slot ids are
unique per recipe.

| Room | `room_key` in the area | Same as phase 3? |
|---|---|---|
| R01 | `reading_room@1` | **yes** (fixed seed, Q2) |
| Baked west gallery | `stack_gallery_west@7` | **yes** (the bake keeps its id and seed) |
| East and entrance galleries | `stack_gallery_east@<area-derived>` | no: new seeds, so old test-scene deltas are stale (kept, counted, never applied) |
| Grow galleries | `gallery_<n>@<area-derived>` | new |

**What the save adds:**

```json
{
  "version": 2,
  "area": "library",
  "room": "gallery_3",
  "player": {"pos": [...], "yaw": 0.0, "pitch": 0.0},
  "areas": {
    "library": {"recipe_version": 1, "deltas": {...}, "spawned": []}
  }
}
```

- `player.pos` is in the area frame. `scene` stays for the camp and test
  scenes; `area` wins when present.
- `recipe_version` per area (§5.4). If the recipe's version is higher than
  the saved one, the plan is still built from today's recipe. Rooms whose
  key didn't change keep their deltas; others go stale and are counted.
  Keeping old recipe versions for released saves is for later; there are no
  released saves.
- **Version 1 saves load:** a v1 file is read as `area = "library"` with
  the old `scene`. Its R01 deltas apply. Only the galleries are new.

**Resume.** `main` sees `area` in the save, plans the area on a thread
behind a short load screen, streams in the saved `room` and its
`load_radius` neighbours **synchronously** (no time-slicing at start,
since there's nothing to hitch), restores the player, then hands over to
the streamer.

**Persistence while streaming.** Nothing new is needed beyond the unload
flush. Deltas are written when they happen (`mark_dirty`, 1 s), not when a
room unloads, so an unloaded room's changes are already in the save. A
janitor `revert(id)` for an unloaded room just drops the delta (phase 3
already does this), and the next load builds the original.

**Aging.** Unchanged and stateless: each socket's draw is
`hash(world_seed, room_key, socket path)`, and years come from the global
clock. A room streamed in after **Let ten years pass** is resolved at the
new year, the same as in a fresh process. Live rooms still re-age through
`refresh_aging()`. Per-room "last seen" aging stays out (Q9).

**Statics made area-safe:** `WorldProp.awake_props` and `FloorWear._live`
lose a room's entries in `_exit_tree`; `GeneratedRoom.seed_override` is
ignored by planned rooms; `PropDirector`'s budget and the shard budget are
area-wide.

#### 8.1.7 Gates

| Gate | New or changed | Checks |
|---|---|---|
| `tests/area_plan_test.gd` | new, headless | For area seeds 1–20: `AreaPlan.check()` passes (tree, 6–10 rooms, no 3D overlaps, inside the envelope, no sightline deeper than `max_sight_depth`, every exit joined or capped); a hand-made plan with four rooms in a straight line (three beyond the viewer) is rejected; a hand-made plan with two rooms stacked one storey apart passes the overlap check; planning twice gives the same plan; the baked room sits on R01's west door; every generated room has `min_bays`; R01's room key is `reading_room@1` |
| `tests/area_route_test.gd` | new, headless | Everything loaded at once, for seeds 1–5: Validate Room clean on every room; floor under every cell; a capsule (the real player's) walks from R01's spawn to every room's far end and back with `body_test_motion`; every cap blocks |
| `tests/stream_test.gd` | new, headless | A scripted walk over the plan's tour: at each step the live set equals the rooms within `load_radius` plus the visible sets (plus those inside the unload delay); every room visible from the player's room is live; a seal never blocks the walk; an unloaded room leaves no nodes, awake props or wear entries; a room changed, unloaded and reloaded restores exactly (same process) |
| `tests/area_walk_capture.gd` | new, GPU | The real game with the HUD, vsync off, walking the tour at walking speed, at 1080p with the Medium values (8.1.7 frame target). Logs every frame's CPU and GPU time, the rooms loaded and unloaded, the lights and shadowed lights in view, draw calls, triangles drawn and VRAM in use. It writes `previews/p4_frames.csv` and fails if the frame target (Q7) is missed. Captures at each room's door |
| `persist_gate.sh` | extended | Two more processes: `area_save` changes something in R01 and in the farthest gallery, walks back until that gallery has unloaded, and quits; `area_load` resumes in the right room, and both changes are there, including in the far gallery, which loads only when walked to. All five phase 3 modes still pass |
| Existing | unchanged | `prop_test`, `book_test`, `age_test`, `room_playtest`, `kit_test`, `socket_modes_test`, `reading_room_test`, `validate_room_test`, `r02_route_test`, `r02_bake_test`, camp `playtest`, the 240-frame runs, and a new 240-frame run of `main` with `--area=library` |

**The frame target (Q7, recommended, revised 2026-10-20 for the base spec):**
the target is the **base spec** (RTX 3060, Medium preset, 1080p, 60 fps;
architecture §8.2). There is no 3060 here, so it's checked on this machine
(RTX 5090, Forward+, vsync off) in two ways, over the walk, after the
start-up load, at 1080p with the Medium values:

1. **Time, scaled to the base spec** (§8.2's working rule: base GPU ≈ 4×,
   base CPU ≈ 2× this machine):
   - GPU time per frame: mean ≤ 3 ms, **no frame over 4 ms**;
   - CPU time per frame (including room building): mean ≤ 4 ms, **no frame
     over 8 ms**.

   That's what keeps a 3060 under 16.7 ms, i.e. no frame below 60 fps even
   while a room is arriving.
2. **Budgets that don't depend on the machine**, per view, every frame:
   draw calls ≤ 1,500, visible lights ≤ 48, shadowed lights ≤ 4, triangles
   ≤ 3 million, VRAM ≤ 6 GB.

The old dev-machine figures (mean ≤ 5.5 ms, no frame over 16.7 ms at the
current full settings) are still logged for comparison, but don't pass or
fail the gate. Both the 4× and 2× factors are estimates, replaced by a real
3060 run when one is available.

The 3-strike rule applies per gate.

#### 8.1.8 Steps (each playable, reviewed before the next)

1. **The whole area, all at once.**
   - Build: `AreaRecipe`, `AreaSlot`, `AreaGrow`, `AreaPlan`, `AreaPlanner`,
     `Area` (owns the environment); `library_wing.tres`; planned rooms in
     `RoomTemplate` and `GeneratedRoom`; the fixed wear rect; area ids in
     `WorldState` (save v2, v1 still loads); **Walk the library wing** and
     `--area=`.
   - Future-proofing (8.1.9): 3D footprint boxes with storeys, connector
     storeys, `AreaPlacement` with its envelope, the sightline trace and
     visible sets.
   - Every room is loaded at start, so there's no streaming yet. This proves
     the plan, the joins and the routes before anything moves.
   - Measure: plan time, per-room instance, generate, resolve and restore
     times, and the frame time with all rooms loaded. These numbers size
     step 2's budget.
   - Gates: `area_plan_test`, `area_route_test`, 240-frame run, every
     existing gate. GPU: a plan view of the area, and one view per room
     type.
2. **Rooms load as you walk.**
   - Build: `AreaStreamer` with the three-state `RoomState` and the
     visible-set rule, `StreamSettings`, threaded loads, the time-sliced
     build, `DoorSeal`, unload with flush, wear region updates composed on a
     thread, statics cleaned on exit; a debug line on the Esc menu ("live:
     4 of 8 rooms").
   - Gates: `stream_test`, a first `area_walk_capture` (frame log only, no
     target yet), every earlier gate.
3. **No hitches: the light budget and the frame target.** The finish line
   is met here.
   - Build: `LightBudget`, distance fades, shader warm-up, a debug switch
     that applies the Medium values (1080p, shadow atlas 4096, SDFGI at half
     resolution) for the frame gate, any slicing step 2's log shows is needed, and the SDFGI check (with the
     `VoxelGI` fallback only if you approve it).
   - Gates: `area_walk_capture` meets Q7 on three runs in a row; captures at
     each doorway at the moment the next room arrives, to look for pops.
4. **It all remembers, area-wide.**
   - Build: resume in any room (saved `area` and `room`), the synchronous
     start-up load, and the persist gate's two area modes.
   - Gates: the full `persist_gate.sh` (seven processes); Let ten years
     pass, then walk into a gallery that wasn't loaded and check it has
     aged the same as a fresh process says.

**Not in phase 4:**

- loops and A*-routed corridors (tree only, Q4);
- more than one area, and travel between areas (phase 5 or later);
- new room types (phase 5);
- lore books, props or new dressing in generated galleries;
- per-room "last seen" aging (Q9);
- floors stacked over each other in a real area (the data is 3D from step 1,
  8.1.9, but every room is on storey 0, and the wear map's single y band
  stays);
- building stand-ins (the `STAND_IN` state exists but nothing uses it), the
  stratum plan, thresholds between areas, cavern facades and the map
  (architecture §2.1);
- the graphics settings menu, presets and upscalers (architecture §8.2).
  Phase 4 only keeps its numbers in `StreamSettings` so presets can
  override them;
- a real loading screen design (step 4's is a plain dark panel with a line
  of text, built with containers per AGENTS.md §3).

**Risks to check in step 1:**

- **R01's instance time.** If `instantiate()` of R01 alone costs more than a
  frame, it can't be time-sliced as one call. R01 is the root, so it's
  always loaded at start behind the load screen and never streams in while
  you walk, unless Q6's radius would unload it. With `unload_radius` 3 it
  does unload from the far galleries, so its reload cost matters. The
  fallback is to keep the root room always loaded (a recipe flag
  `pinned`).
- **The baked room's footprint** came from a build that read R01 and its
  live siblings. Planned area-wide, the east and entrance galleries now
  plan around it. That matches `Multrooms-test1`, but it's checked, not
  assumed.
- **Grow rooms boxed in.** Galleries growing from galleries can run out of
  room. The planner tries the next exit; `area_plan_test` reports how often
  over 20 seeds and fails if any seed has fewer than 6 rooms.
- **Thread safety** of building rooms off the main thread, if step 2 tries
  it. The time-sliced main-thread build is the plan whatever happens.
- **Sightline rejections box the wing in.** R01's doors and straight
  galleries may line up. If the sightline rule rejects too many grow
  candidates, `area_plan_test` shows it as seeds with fewer than 6 rooms.
  The fixes, in order: galleries pick an offset or turning first bay when
  their exit lines up with their entry; then `max_sight_depth` 3 for this
  wing only. Either is reported, not done silently.

#### 8.1.9 Future-proofing for the world structure (added 2026-10-20)

Phase 4 builds one area on one level. These five changes keep its data
shaped for the world described in architecture §2.1 and the hardware tiers
in §8.2, so later phases add to it instead of rewriting it. None of them
changes what you see in phase 4. Together they add about a day to steps 1
and 2.

| # | Change | Where | Why it can't wait |
|---|---|---|---|
| 1 | **3D plan.** Footprints are boxes with a storey; connectors record their storey; overlap and "which room is the player in" use 3D boxes. Every phase 4 room is on storey 0 | `AreaPlan`, `AreaPlanner`, `AreaStreamer` | Stairs, ramps and stacked rooms would otherwise mean changing the plan format, the save's room lookup and every planner test |
| 2 | **A place in the stratum.** `AreaPlacement`: an origin in the stratum frame and a reserved `envelope`; the planner refuses anything outside it. The player's saved position is already area-relative (8.1.6) | `AreaRecipe`, `AreaPlanner` | The stratum plan and the world map need areas that are guaranteed not to overlap. Adding envelopes after areas exist would move rooms and break saves |
| 3 | **Sightline rule and visible sets.** The planner traces straight lines through doorway openings on the cell grid (2D per storey in phase 4: from each doorway, a ray fan across the opening's width, stepping cell edges and passing only through openings). It rejects layouts deeper than `max_sight_depth` (2) and stores each room's visible set. The streamer loads `graph radius ∪ visible sets` | `AreaPlanner`, `AreaPlan.check()`, `AreaStreamer`, `stream_test` | Without it a long straight line of doors shows an unloaded room (a dark seal or a void). It's also the rule later room types (R03 grids, R09 rings) must obey, so it belongs in the planner from the start |
| 4 | **Three room states.** `UNLOADED`, `STAND_IN`, `LIVE`. Phase 4 uses only the first and last; the stand-in (a merged shell with no props, lights or collision) is built later for deliberate long views and cavern vistas | `AreaStreamer` | A two-state (loaded or not) streamer is the kind of thing that gets rewritten when the first vista needs a far room |
| 5 | **Base-spec frame target and budgets.** Q7 is measured as "RTX 3060, Medium, 1080p, 60 fps", checked here with scaled CPU and GPU time and machine-independent budgets (draw calls, lights, shadowed lights, triangles, VRAM). `StreamSettings` holds the Medium preset's values so the future settings menu can override them | 8.1.7, `StreamSettings`, `area_walk_capture` | A wing tuned against an RTX 5090 alone would hide costs that only show on the hardware most players have |
