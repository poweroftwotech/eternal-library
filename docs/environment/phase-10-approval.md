# Approval brief: the world authoring tool (the Strata Board), phase 10

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-31 with the recommended answers** (phase 10; the navigation map moves to phase 11) ·
Reference: [the Strata Board mock](https://claude.ai/artifact/SMqnDsVcsPTSL8bCw9zD7Y) (you said on 2026-10-31 it shows how you want the tool to work) ·
Background: [architecture §2.1](architecture.md) (world structure)

## What this does, in one paragraph

Today an area is shaped by editing its recipe file (`gen/recipes/*.tres`) by hand, which areas exist and how they connect is written into the code, and the only way to see what a seed makes of a recipe is to walk it. This phase builds the Strata Board from the mock as a dock in the Godot editor. You'd see the stratum side-on, each area's recipe as a graph, and what any seed makes of it, and you'd change the recipe there. It runs the game's own planner and checks, so what the board shows is what you'd walk. It also lets every new game roll its own world seed. Today every world uses seed 1, so all the seeded variety you author would otherwise reach only one world.

## What you'd get

The board, as in the mock, inside the editor:

- **The stratum, side-on:** each area as a box of its reserved height, with the doors and corridors between them. You can add an area, link it, rename it or delete it.
- **An area's recipe as a graph:**
  - required rooms (the beats) in brass,
  - grow rules in turquoise, with their count, which rooms they grow from, the order they run in, and how far in from the entrance they may start.
  - Required rooms can change type, join a different room or door, be added or removed, or become the entrance.
- **The plan for one seed** under the recipe. It uses the real planner, so the reasons a rule falls short are the real ones: doors taken, didn't fit, sightline, outside the area's space, too many lights in reach.
- **A seed sweep:** 20 seeds at once, each marked valid or not. This is the same check as the route test, so a recipe that sweeps clean passes it.
- **What may connect to what:** a table of room types (allowed, preferred, never).
- **Variants:** a baked or authored room can list several scenes, such as Reading Room furniture layouts, each with a weight, or pin one.
- **Walk this seed:** opens the game in that area with that seed.

## The steps

| Step | What you can try |
|---|---|
| 1. A seed per world, and the board to look at | New games roll a random world seed; the F3 panel and the save show it, and you can type one in to replay a world. In the editor, the board opens on the existing areas: step through seeds, sweep 20, see the real planner's reasons, and press *Walk this seed*. Nothing can be edited yet |
| 2. Editing areas | Everything on the area board can be edited, and the board writes the recipe files: required rooms, grow rules and their order, the connection table, variants with weights. When a change would move rooms in existing worlds, the board says so and raises the recipe's version. Try: reshape the Lower Stacks, sweep it, walk it |
| 3. The stratum plan | The list of areas and their links moves out of the code into one data file the board edits. You can add an area, give it a door from a Gorge building, and walk into it from the Gorge. A top-down view next to the side-on one shows if two areas' reserved spaces overlap. The phase 9 frame gate and the route tests still pass |

## Decisions (your answers: as recommended, 2026-10-31)

| | Question | Recommended | Why / what it means |
|---|---|---|---|
| Q1 | Should this come before the navigation map? | **Yes: this becomes phase 10, the map phase 11** | The map draws from the same area plans and would read the stratum plan from step 3. Building the map first means changing it again afterwards |
| Q2 | Where should the board live? | **A dock in the Godot editor** (like the kit palette) | It can read and write the recipe files and run the real planner directly. A web page like the mock could only show a copy of the planner |
| Q3 | How should new games pick a world seed? | **Random for each new game, shown on the F3 panel, and you can type one in** | Without this, every player sees the same world. Tests keep their fixed seeds, so nothing gets less repeatable |
| Q4 | A grow rule like "1 light-well": may the planner add more than 1 to reach the area's minimum room count? | **No, never more than the rule's own maximum.** A seed that falls short is marked invalid | Today it may (the planner raises the count to reach the minimum), so a "1 light-well" rule can make three. With the board showing counts, they should mean what they say |
| Q5 | If you add or reweight a variant later, should existing saved worlds keep the variant they already have? | **Yes: the save records each room's variant** | Otherwise adding a fourth Reading Room layout swaps the furniture under existing saves, and the saved changes (a knocked-over vase) land in the wrong room |
| Q6 | Should rooms that can only be an entrance (the caravanserai, the Reading Room) get a way in, so they can sit deeper in an area? | **Not in this phase.** The board marks them *entrance only* | It needs a door picked as the way in for each baked scene, and the bake tool changed. Worth doing once you want one deeper in |

## Risks

- **Sweep speed.** An interior takes about a third of a second to plan (phase 9 measured 0.6 s for the two together), so a 20-seed sweep takes several seconds. It runs in the background with a progress bar, and the single-seed view updates at once.
- **The board and hand edits.** Recipe files stay ordinary files you can still edit by hand, and the board reads them fresh each time it opens. If both change the same file while the board is open, the board warns before saving.
- **Moving links out of the code** touches the phase 9 code that loads neighbouring places. Step 3's gate is the phase 9 frame gate and the route tests passing unchanged.

## Not included

- **Gameplay beats:** locks and keys, where rewards or lore books go, and "you need X to get past here". A later phase, once you know your beats. The board leaves room for a lock on a door and a key in a room.
- **More than one stratum,** and the descents between them. The stratum plan file is shaped for several strata but holds one.
- **A board for the Gorge's ledges and spans.**
- **Loops:** every room keeps exactly one way in.
- **The camp's front door** (`SNAP_exit_front`), and linking places other than the camp–Gorge corridor and Gorge doors into areas. The board shows such links as new work.
- **Each room type's own settings,** such as a gallery's `max_straight_bays`. They stay in their files.
- **The navigation map** (now phase 11).

## How the mock differs from the real thing

The mock's planner is a stand-in. Whether a room fits is a random roll, room sizes are invented, and it has no sightline, lights or reserved-space checks. Its connection table and variant weights don't exist in the game yet; step 2 adds them.
