# Phase 10 progress: the world authoring tool (the Strata Board)

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Brief](../phase-10-approval.md) · [The mock](https://claude.ai/artifact/SMqnDsVcsPTSL8bCw9zD7Y)

## Step 1: a seed per world, and the board to look at (2026-10-31, committed 2026-11-01)

### What you can try

**In the game**

- A new game (your own save slot, after *Forget this library* or with no save) rolls a random **world seed** from 1 to 999,999. Every area's seed comes from it, so each world has its own Lower Stacks, library wing and Gorge network.
- **F3** shows it: `world seed 482113 · lower_stacks seed 1734…` (with "(reseeded)" after the menu's reseed).
- **Esc → World seed N: start a world from a seed**: type a seed to start that world, or roll a random one. It forgets the current world, like *Forget this library*, and says so first.
- The save already kept `world_seed`; it now holds the rolled one. Saves made before today stay world 1.
- On the command line: `-- --world-seed=N` (or `=random`) starts a new world from that seed.
- Tests and gates keep world seed 1 (Q3), unless a test asks for another.

**In the editor: the Strata tab** (beside 2D, 3D and Script)

A full-size tab rather than a side dock like the kit palette (Q2 said a dock): the stratum, recipe, plan and sweep need the width. It's a one-line change if you'd rather have it docked.

- **The stratum, side-on:** the camp, the Gorge and both interiors as boxes of their reserved height, with their links. Click one to open it.
- **The recipe as a graph:** required rooms in brass, a column after the room they join, with their doors out (lapis arrows) and tags (type, baked or generated, *1 of 3 variants*, **entrance only** for the caravanserai and the Reading Room, Q6). Grow rules in turquoise: the order they run in, their count, where they grow from, and for this seed *N placed* or **short**.
- **The plan for one world seed,** from the game's own planner: side-on (left to right is the route from the entrance, up is storeys) and top-down. On the top-down map every room is outlined and named (rooms above the ground storey marked ↑1, ↑3 …); a room selected in either view, or every room of a selected rule, lights up and the rest dim; click a room on the map to select it, hover to see its name. Gold squares are doorways. Under it, each rule's *wanted / placed*, and when it falls short, why, from the planner's own counts: ran out of free doors, didn't fit, came out too short, sightline. A count the planner raised to reach the area's minimum says so (that's Q4, which step 2 stops).
- **◀ seed ▶**: the seed is a **world seed**, the same number as in a save and on F3, so a seed you like here is the world you get by typing it in.
- **Sweep 20 seeds:** the 20 world seeds around this one, each planned and marked valid or not, with its map. Click one to open it. About 12 s for the Lower Stacks; the editor stays usable.
- **Inspector:** select a required room, a grow rule or a planned room; its partner in the other view lights up.
- **Walk this seed:** runs the game in that area with that world seed, on a scratch save (`user://test/strata_walk.json`), never your own. It leaves a one-time request (`user://strata_walk_request.json`) that the game takes as it starts, within two minutes.

### After your first try (2026-10-31)

1. **Walk this seed started your last save instead of the seed.** It passed the area and seed as run arguments, and those never reached the game (the editor's *Customize Run Instances* can replace them). Now the board leaves a one-time request file the game reads at start; checked by writing one and starting the game: `main: Walk this seed: library, world seed 4242 (save user://test/strata_walk.json)`.
2. **The top-down map didn't say which room was which.** The board now draws the map itself from the planner's cells, with names and highlighting (above).
- **Reload** (and opening the tab) reads the recipe files again after a hand edit.
- Nothing can be edited yet: that's step 2. The Gorge and the camp show a note instead of a recipe (the Gorge's ledges and spans get their own board later); you can still walk any seed of the Gorge.

![The board on world seed 1, the Upper Stacks rule selected](../../../previews/p10_step1/board.png)

![The sweep of world seeds 1-20](../../../previews/p10_step1/board_sweep.png)

### How it works

The editor can't run the planner itself: the grammars and `RoomTemplate` aren't `@tool` scripts, so in the editor they load as empty placeholders, and making them `@tool` would make every room scene run its code while you edit it. So the board starts the game's planner as a separate headless Godot process (`addons/strata_board/service_main.gd`) and talks to it over a pipe (`planner_client.gd`). It answers with the plan as data: rooms, doors, checks, the per-rule counts and the top-down map. The first answer takes about 2 s (the process starting), then about 0.4 s a plan. The sweep queues behind the single-seed view, so stepping seeds during a sweep still answers first.

Files: `addons/strata_board/` (plugin, board, client, service, process), `tests/strata_board_test.gd`; in the game `scripts/world/world_state.gd` (the seed), `scripts/main.gd` and `scripts/hud.gd` (the menu entry and its text field), `scripts/stats_overlay.gd` (F3), `scripts/world/area_planner.gd` (the counts and the two fixes below).

### Two planner bugs the random seeds found

Before giving every new game its own seed, I planned world seeds 1-60 of both interiors:

1. **A gallery grown through the Reading Room** (library wing, world seed 5): two rooms in the same cells. The planner kept new rooms out of a baked or authored room only where its module meshes are, and the Reading Room's open middle has none. Now a scene room blocks its whole cells, as a generated room already did. **World 1 is unchanged**, as are all Lower Stacks plans; two other library worlds of 60 (16 and 52) change shape, both valid before and after.
2. **The same seed could give two different Lower Stacks.** The first plan of an area in a process differed from later ones: the Upper Stacks' two rooms swapped which light-well exit they hang off. The planner sorted door names with a sort that orders them by where they sit in memory, so the result depended on what had been loaded before (starting in the camp or in the Lower Stacks, say). It now sorts them by name. **World 1 now always gets one layout:** upper_1 (18 cells) off the light-well's lower west exit at storey 1, upper_2 (24 cells) off its upper exit at storey 3. Before, you may have seen these two the other way round. A save made in the Upper Stacks of world 1 may find its changes in the other room.

Of 60 worlds per interior after the fixes: the library wing is valid in all 60; the Lower Stacks in 58. Worlds 33 and 45 come out short (5 and 4 rooms; the recipe asks for at least 6) because the light-well didn't fit on either free door. Those worlds build and walk fine, just smaller. That's a recipe question for step 2 on the board, so new games roll any seed.

### Gates

| Gate | Result |
|---|---|
| `tests/strata_board_test.gd` (new): the board's plan is the planner's own, signature for signature (both interiors, worlds 1-3); per-rule counts add up; the planner process over the pipe gives the same plan; entrance-only marks; world seed rules (tests 1, own slot random, `forget(n)`); the board plans, draws every room and rule, steps seeds, sweeps 20 | 66 checks, 0 failures (now also: the map draws every room, lights a selected one, selects on click, names on hover) |
| Persistence (two processes): a rolled seed saved in one, loaded in a fresh one | Same seed (199524) |
| `tests/area_plan_test.gd` | 266 checks, 0 failures |
| `tests/area_route_test.gd` (both interiors, area seeds 1-5, built and walked) | 413 checks, 0 failures |
| `tests/gen_signature_test.gd` | 19 failures, the **same 19** with the planner as it was before today: its recorded signatures predate phase 6 step 5 (they still list `stack_gallery_entrance`) and haven't been re-recorded since. None are new |
| The editor starts with the plugin (headless) | No errors |
| GPU capture of the board | Above |

Not checked by me: the board inside the editor window itself (clicking through it, *Walk this seed* launching the game). The test runs the same board in a game window with the planner in-process, and the pipe separately.
