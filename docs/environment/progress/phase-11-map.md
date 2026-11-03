# Progress: phase 11, the navigation map

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-11-approval.md) ·
[The mock](https://claude.ai/artifact/LSnEpwg9XnPVp3DLoqYnx6)

## Step 1: the map of an interior (built 2026-11-03, not committed)

**What you can try:** walk into the Lower Stacks (or any interior) and press **M**.

- The page: the place's name, floor tabs when its rooms you know stand on more than one storey, the places you know on the left (click one to see its map), the key, and the sheet. The game is paused while it's open; **M** or **Esc** closes it.
- On the sheet: rooms you have entered in wavering ink with a brown wash, each name once (the grown galleries share one); rooms seen through a doorway in dashed pencil; a dotted stub and an open circle for each way you haven't taken; a solid block for a door to another place, labelled "to the Gorge" once you have been there ("?" until then); a shut-door mark for doors that won't open; a red arrow for you. Hall pillars and bookcases (the plan's blocked bays) show as small squares. On an upper floor the floor below shows faintly.
- **Drag** to move, **wheel** to zoom about the pointer, **C** back to you, **Tab** next floor.

**How it's built:**

- `scripts/map/map_canvas.gd` draws one place's storey from its rooms' sketches (cells, blocked bays, doors, made from its `AreaPlan` when you see them). It is drawn at half resolution and doubled, so its lines are pixels like the rest of the game.
- `scripts/map/map_page.gd` is the page (CanvasLayer → MarginContainer → PanelContainer → VBoxContainer). Every quarter second it notes the room you're in and the rooms you can see into from it (the plan's sightline sets) in the save. Each room is kept as a small sketch (its floor, blocked bays, doors and name) the first time you enter or see it, so the map draws any place from the save alone: nothing is loaded or planned when you open it or switch places.
- The save keeps the map under `map`: per place, its name, the recipe version, rooms entered, rooms seen, their sketches, the floor last shown; and the order you first visited places. If a recipe's version goes up, that place's map is forgotten rather than drawn wrong.
- `tools/map_paper.gd` makes the paper (`assets/textures/map_paper.png`, 768×432): the look you settled on the mock.

**Verified:**

- `tests/map_test.gd`, in two OS processes:
  - *save*: walks the Lower Stacks to its deepest room. Every room on the way is entered, some rooms are only seen, no room is both. M opens the map on the Lower Stacks with you on it, the player is blocked, and it closes again (15 checks).
  - *load*: a new process has the same rooms entered and seen. The map opens on them, on your floor, with you on it. The Sanctum (never visited) isn't listed, and a newer recipe version forgets the place (10 checks).
- GPU capture of the open map: `previews/p11_step1/map.png`.
- Headless 240-frame gate: passes.

**Pauses fixed (after your try, 2026-11-03):** opening the map took 140 ms the first time (and again after every door), and switching to a place 25–108 ms. Naming a place loaded its recipe, which pulled in all its rooms (70 ms each). A place you weren't in was planned from scratch. Now names and rooms come from the save: opening takes 2–3 ms and switching about 1 ms (measured on the RTX 5090 with four places known). A save from before this fills in its sketches when you next walk in that place.

**Caveats:**

- The Gorge and the camp aren't drawn yet (step 2). The Gorge is listed once you've walked it, and shows a note.
- Long names in narrow rooms are turned to run along them; the Cistern Archive's name is a little longer than its room.
- Walls that two rooms share are drawn by both. Their wobble is the same, so they line up, but a pencil wall next to an ink one shows both.
- Not run: the full persistence gate, the frame gate and the route tests. The map touches the save only under its own key, and nothing in the world.
