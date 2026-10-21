# Progress: phase 4, areas and streaming

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../phase-4-approval.md), [technical](../phase-4-design.md)

**In short:** steps 1 and 2 are built. The Reading Room is now the heart of a wing of 6–9 rooms: the baked gallery on its west door, generated galleries on its east door and entrance, and 2–5 more galleries growing from their far ends. The whole wing is laid out as data first (in about 30 ms). Since step 2, only the rooms near you exist: the next ones are built ahead of you, a few milliseconds a frame, and the ones you leave behind go.

---

## Step 1: the whole wing, all at once (done 2026-10-20, walked in the game by you and committed)

**Try it:** Esc menu → **Walk the library wing** (or start the game with
`-- --area=library`). You start in the Reading Room.

- Walk out of any of its three doors. Each gallery leads on: at the far end
  of most galleries there's a doorway into another gallery. Galleries with
  nowhere to go end at the warm glowing arch, or (at most one per wing) a
  plain wall.
- The HUD's top-left label names the room you're in as you walk
  (**The Stack Gallery**, **The East Stacks**, **The Front Stacks**, **The Far
  Stacks**).
- Esc → **Reseed the library wing** lays out a different wing. The Reading
  Room and the baked west gallery stay the same in every wing; the rest
  changes.
- Your Reading Room changes from phase 3 (vases, books, tended lamps) show up
  in the wing too: it's the same room, in the same part of the save.

**Built:**

| Piece | File |
|---|---|
| `AreaRecipe`, `AreaSlot`, `AreaGrow`, `AreaPlacement` (resources) | `scripts/world/area_recipe.gd`, `area_slot.gd`, `area_grow.gd`, `area_placement.gd` |
| The first recipe: R01, the baked gallery on its west door, generated galleries on the east door and entrance, 2–5 grown galleries; 6–9 rooms | `gen/recipes/library_wing.tres` |
| `AreaPlan`: every room as data, 3D footprints with storeys, connectors, the sightline trace and visible sets, `check()`, `room_at()`, a plan map image | `scripts/world/area_plan.gd` |
| `AreaPlanner`: required slots in recipe order, then grown rooms on free exits; each grown room kept only if it fits, has `min_bays` and keeps sightlines within 2 rooms | `scripts/world/area_planner.gd` |
| `Area`: plans, owns the WorldEnvironment, builds every room as its own child, records what each cost | `scripts/world/area.gd` |
| Planned generated rooms: built from the plan's layout, seed and styles; no host lookup | `scripts/gen/generated_room.gd` |
| A grid can ask for its end kind (exit or dead end) and stay quiet during planner trials | `scripts/gen/cell_grid.gd`, `stack_gallery_grammar.gd` |
| The wear map's rect fixed from the plan | `scripts/world/floor_wear.gd` |
| Save version 2: `area`, `room`, `area_seed_override`, a bucket per area with its `recipe_version`; version 1 saves still load | `scripts/world/world_state.gd` |
| Esc → **Walk the library wing** / **Reseed the library wing**, `--area=library`, `--area-seed=N`, the HUD names the room you're in, resume into the wing | `scripts/main.gd` |
| Gates | `tests/area_plan_test.gd`, `tests/area_route_test.gd`, `tests/area_capture.gd` (GPU) |

**What the wings look like** (20 seeds, `area_plan_test`):

- 6 rooms in 5 seeds, 7 in 8, 8 in 6, 9 in 1. Planning takes 19–37 ms.
- 12 of the 20 wings have one gallery ending in a plain wall; the rest end
  every unjoined gallery at the glowing arch.
- The deepest sightline in every wing is exactly 3 rooms: the west gallery,
  through R01's west and east doors (which face each other), into the east
  gallery. That's the limit (Q11), and the planner never had to turn a grown
  gallery away for a sightline. It turned 6 away for being shorter than 6
  bays.
- The plan maps are in `previews/p4_plans/` (one PNG per seed); the planner
  draws them from data alone, the way the world map will be drawn later.

**Pictures** (`previews/p4_step1/`, the real game at 1600×900, seeds 1 and 5):
`area_<seed>_plan.png` looks straight down from 5 m with the vaults cut away,
so the whole wing's floor plan shows; it matches the planner's own map
(`area_<seed>_map.png`). Views down R01's hall, through its east door, down a
grown gallery, back through a gallery-to-gallery doorway and down the baked
gallery all look as the rooms did in phase 2. (The HUD label reads "The
Reading Room" in every capture because the capture teleports a frozen
player; while walking, it names the room you're in.)

**What it costs** (sizes step 2):

| | Seed 1 (6 rooms) | Seed 5 (8 rooms) |
|---|---|---|
| Plan | 42 ms | 27–37 ms |
| Build every room (GPU run) | R01 41 ms, baked gallery 19 ms, each generated gallery 4–7 ms | similar |
| Floor wear map, whole wing | 80 × 76 m in 225 ms | 112 × 96 m in 314 ms |
| Start-up, all of it | 627 ms | 726 ms |
| Frame time, RTX 5090, current full settings, 1600×900, vsync off | 1.55–2.16 ms mean, worst frame 2.89 ms | 1.52–2.08 ms mean, worst 2.55 ms |
| Most in view (whole-wing plan view) | 219 draw calls, 136 k triangles | 240 draw calls, 178 k triangles |

What this means for step 2:

- **The floor wear map is the big cost**: a quarter to a third of a second to
  redraw the whole wing, and its size grows with the wing (a 112 × 96 m wing
  is a 3584 × 3072 map). Step 2 must stop redrawing it whole, as the design
  says. It should probably also stop being one map for the whole wing, since
  that map's memory grows with the wing.
- **R01 costs about 41 ms to build and the baked gallery about 19 ms**, ten
  and five times step 2's 4 ms per-frame budget. Neither can arrive in one
  frame. R01 is the root, so the design's fallback applies: keep it always
  loaded (`pinned`). The baked gallery must be built in slices.
- **Generated galleries cost 4–7 ms**, just over budget; their module runs
  split easily.
- Drawing is cheap: even the whole wing in view is far inside the budgets
  (1,500 draw calls, 3 million triangles). These frame times are at today's
  full settings; the Medium-preset check against the RTX 3060 target is step
  3's.

**Gates (all pass):**

- `area_plan_test` (new): 145 checks over 20 seeds. Each plan checks clean
  (a tree, 6–9 rooms, no cell shared in 3D, inside the envelope, every exit
  joined or capped, no sightline deeper than 2 rooms beyond the first). The
  same seed gives the same plan, the baked gallery sits on R01's west door,
  every generated room has at least 6 bays, and R01 keeps room key
  `reading_room@1`. Hand-made plans: four rooms in a straight line are
  rejected and three pass; two rooms stacked one storey apart don't overlap,
  while two on one storey do.
- `area_route_test` (new): 198 checks over 5 seeds, everything loaded.
  - A phase 3 (version 1) save loads as version 2 with its R01 change intact.
  - Every planned room is built as the area's own child, with the room key
    the plan says.
  - Validate Room is clean on every generated room and error-free on R01 and
    the baked gallery.
  - Every doorway meets face to face, there's floor under every generated
    cell, and every wall and unjoined exit blocks.
  - The real player capsule walks from R01's hall to every leaf gallery's far
    end and back, through every room in the wing.
- 240-frame runs clean: the camp, R01, and `--area=library`.
- `prop_test` 51, `book_test` 27, `age_test` 20, `room_playtest` 31,
  `kit_test` 906, `socket_modes_test` 246, `reading_room_test` 87,
  `validate_room_test` 26, `r02_bake_test` 105, camp `playtest` 43,
  `spill_settle_test` 6, `room_atmosphere_test` 32, `atmosphere_test` 9,
  `r02_route_test` 2321.
- The persistence gate (`sh tests/persist_gate.sh`): all five processes pass.

**Caveats:**

- **Resuming inside the wing isn't gated yet.** The save records the area and
  room, and the game resumes into the wing, but the two-process check is
  step 4's.
- The wing loads at start in about 0.6–0.7 s, with no loading screen yet. The
  game is unresponsive for that moment.
- The planner treats the inside of an authored room as open for sightlines
  (it doesn't model R01's inner pillars). That's the cautious side: it can
  only over-count what you see.

---

## Step 2: rooms load as you walk (done 2026-10-20, walked in the game by you and committed)

**Try it:** Esc menu → **Walk the library wing**, as in step 1. Walk out
along any gallery and keep going.

- Rooms appear ahead of you before you reach their door: you should never
  see one arrive, and never meet a closed doorway.
- Rooms you've left behind go once they're more than three doorways away
  and out of sight for 10 seconds.
- Open the Esc menu at any point: its text says how many rooms are live
  (e.g. **live: 5 of 8 rooms**), how many have been built and unloaded, and
  the slowest frame the streaming has cost so far.
- Change something in a far gallery (light or douse a lamp), walk away
  until it has unloaded (the live count drops), and come back: it's as you
  left it.

**Built:**

| Piece | File |
|---|---|
| `AreaStreamer`: which rooms should be live (within 2 doorways, everything visible from here or one doorway on, pinned rooms); the build queue, nearest first; unloading after 10 s far and out of sight; three room states (`UNLOADED`, `STAND_IN` not used yet, `LIVE`); the Esc menu's line | `scripts/world/area_streamer.gd` |
| Building in steps within 4 ms a frame: make the node, build a generated room's modules off the tree, resolve its sockets off the tree in slices, enter the tree in one call | `area_streamer.gd`; `RoomTemplate.begin_resolve` / `resolve_next` / `prepared`; `GeneratedRoom.build_planned_modules` |
| A room being prepared off the tree reads the save and the years, as a live one does | `RoomTemplate.world_state()` |
| Unloading: moving props saved first, then the room leaves the tree a few pieces a frame | `AreaStreamer.unload`, `_take_apart` |
| `DoorSeal`: a blocker and a dark card on any doorway onto a room that isn't built; one shared material, mesh and box | `scripts/world/door_seal.gd` |
| `StreamSettings` (the Medium preset's values: load radius 2, unload radius 3, 10 s, 4 ms budget, 0.25 s checks) | `scripts/world/stream_settings.gd`, `world/area/stream_settings.tres` |
| R01 is pinned (always live) | `AreaSlot.pinned`, `gen/recipes/library_wing.tres` |
| Floor wear: in an area, a room arriving or leaving redraws only its own part of the map, composed on a worker thread | `scripts/world/floor_wear.gd` |
| Props leave the awake list when their room unloads | `WorldProp._exit_tree` |
| A resumed save builds the rooms around where you were first | `Area.start_point`, `scripts/main.gd` |
| Gates | `tests/stream_test.gd`, `tests/area_walk_capture.gd` (GPU frame log) |

**What changed from the design, and why** (all found by measuring):

- **No threaded loading.** Every scene a room uses is already loaded with
  the recipe and the kit, so there's nothing to read from disk while you
  walk. What cost time on a room's first build was first use: R01 took
  34 ms to enter the tree the first time and 4 ms the second; the baked
  gallery 14 ms then 2.4 ms. So the start-up wait now also **prepares every
  other room once off the tree and throws it away**, which makes every later
  build a warm one.
- **R01 is pinned**, as the design's fallback said: even warm it takes
  about 7 ms in all to build.
- **Door seals share one material.** A new material per seal cost 20–25 ms
  on the GPU each time one appeared, the biggest stutter in the first log.
- **Unloading is spread over frames** (pieces of the room leave within the
  budget) rather than one call.

**What the walks measured** (the real game, RTX 5090, 1600×900, today's full
settings, vsync off; out to every leaf gallery and back at 3.3 m/s):

| Wing | Walk | Frame time | Over 8.3 ms | Over 16.7 ms | Slowest streaming frame | Rooms built / unloaded |
|---|---|---|---|---|---|---|
| Seed 1, 6 rooms | 354 m, 65 k frames | 1.64 ms mean, 2.33 p99, 4.9 worst | 0 | 0 | 3.2 ms | 2 / 2 |
| Seed 2, 8 rooms | 514 m, 98 k frames | 1.59 ms mean, 2.25 p99, 8.5 worst | 1 | 0 | 3.9 ms | 10 / 10 |
| Seed 5, 8 rooms | 562 m, 107 k frames | 1.59 ms mean, 2.24 p99, 8.4 worst | 1 | 0 | 4.6 ms | 9 / 8 |

- Start-up (plan, the rooms near you, warming the rest, the wear map):
  0.6–0.7 s.
- A wear map region takes 32–62 ms on a worker thread; copying it into the
  map and uploading it takes about 1 ms on the main thread.
- Headless (`stream_test`, CPU only): the slowest streaming frame is
  2.5–4.2 ms; the slowest single step is the baked gallery entering the tree
  (3.4–3.9 ms).

**What step 3 needs to know:**

- **The worst frames (8.4–8.5 ms) are unloads.** The streamer's own work
  stays near its 4 ms, but the pieces it removed are freed at the end of the
  frame, outside the budget, which costs about another 4 ms. Step 3 should
  free them inside the budget.
- **The baked gallery's tree entry (up to 3.9 ms) is one call.** It's the
  biggest single step and the hardest to split.
- **In a wing this small, streaming saves little.** With rooms loading two
  doorways ahead plus everything in view, 6–8 of a wing's rooms are often
  live at once (the whole wing at the Reading Room). Streaming will matter
  for bigger areas; for this wing the gain is the shape of the system, not
  memory.
- These frames are at today's full settings. The Medium-preset check against
  the RTX 3060 target (no frame over 4 ms of graphics work or 8 ms of
  processor work) is step 3's gate.

**Gates (all pass):**

- `stream_test` (new): 40 checks over 5 seeds.
  - The walk runs from R01 to every leaf gallery and back, a cell at a time.
  - At every step, every wanted room is live.
  - Once the delay has passed, nothing further than 3 doorways and out of
    sight stays live.
  - No seal is ever on a doorway of the player's room or its neighbours.
  - An unloaded room leaves no node, awake prop, floor wear or WorldState
    entry.
  - A lamp tended in the farthest gallery is still tended after that gallery
    has unloaded and been rebuilt.
- `area_walk_capture` (new, GPU): the frame logs above.
- `area_plan_test` 145, `area_route_test` 198 (now with streaming off).
- 240-frame runs clean: the camp, R01, and `--area=library`.
- `prop_test` 51, `book_test` 27, `age_test` 20, `room_playtest` 31,
  `kit_test` 906, `socket_modes_test` 246, `reading_room_test` 87,
  `validate_room_test` 26, `r02_bake_test` 105, camp `playtest` 43,
  `spill_settle_test` 6, `room_atmosphere_test` 32, `atmosphere_test` 9,
  `r02_route_test` 2321.
- The persistence gate (`sh tests/persist_gate.sh`): all five processes pass.

**Caveats:**

- **Resuming inside the wing in a new process isn't gated yet** (step 4's
  two persistence modes). The code builds the rooms around the saved
  position first.
- The frame logs (`previews/p4_frames_seed*.csv`, about 5 MB each) are kept
  out of git; rerun `tests/area_walk_capture.gd` to get them.
- Lighting popping as rooms arrive hasn't been looked at yet (step 3's
  doorway captures).

---

## Live stats panel (added 2026-10-20 at your request; committed)

Press **F3**, or Esc → **Controls & settings** → **Performance stats**, to
show a panel in the top right. The choice is remembered in
`user://settings.cfg`, apart from the save.

- **Performance:**
  - frames per second;
  - the average and worst frame over the last 2 seconds;
  - CPU process and physics time;
  - GPU time and render CPU time;
  - a graph of the last 120 frames, with lines at 8.3 ms and 16.7 ms.
- **Draw cost against the base-spec budgets** (architecture.md 8.2): draw
  calls out of 1,500, triangles out of 3 million, video memory out of 6 GB.
  A value over its budget turns amber.
- **Streaming (in the wing):**
  - the room you're in and the rooms that are live;
  - live, seal, built and unloaded counts;
  - what's being built (and which stage), queued or taken apart;
  - the streaming cost this frame and the worst so far, against the 4 ms
    budget;
  - whether the floor wear map is redrawing.

Note: its draw call count is Godot's total for the frame, shadow passes
included, so it reads higher than the main view's count in the capture logs
(777 against 142 in R01's hall).

Built in `scripts/stats_overlay.gd` (CanvasLayer → MarginContainer →
PanelContainer → VBoxContainer, per AGENTS.md section 3); toggled in
`scripts/main.gd`. Picture: `previews/p4_stats_r01.png`.
