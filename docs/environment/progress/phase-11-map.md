# Progress: phase 11, the navigation map

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-11-approval.md) ·
[The mock](https://claude.ai/artifact/LSnEpwg9XnPVp3DLoqYnx6)

## Step 2: the Gorge and the camp (committed c2ae869, 2026-11-03, after your try)

**What you can try:** start in the camp, walk through the corridor into the Gorge and down the span, then press **M**. Both are listed under "Places you know".

- The Gorge and the camp aren't built on the 4 m grid, so they're drawn from a trace of where you can walk: the outlines you approved (`previews/p11_step2/camp_outline.png`, `gorge_outline.png`).
- The map shows them in 8 m patches:
  - **Ink:** the patches within 14 m of where you have walked.
  - **Pencil:** patches you have only seen (in the Gorge only, out to 40 m, since you see far down it; the camp has walls).
- A door shows once its patch is in ink: "to the camp" at the corridor's end, "to the Gorge" at the camp's north door, "?" for a door you haven't been through.
- The Gorge opens at 2 pixels a metre, the camp at 4, so each 0.5 m sample is a whole number of pixels.

**How it's built:**

- `tools/map_trace.gd` (run `-- gorge` or `-- camp --no-seamless`, then `--import`) loads the place on its own and casts rays down every 0.5 m. A floor needs to face up with 1.7 m of headroom. It then floods out from where you stand and from each door, by steps of at most 0.45 m, only where nothing stands between two samples at waist height.
  - This sideways check was added after the first camp trace counted the whole ground, because walls thinner than a sample slipped through.
  - Roofs, ledges and the gorge floor you can't reach are left out.
  - It writes `gen/map/<place>_trace.tres` (size, which tiles have floor, the doors), `_ink.png` and `_pencil.png`.
  - **Re-run it after re-baking either place.**
- `MapTrace` (`scripts/map/map_trace.gd`) holds the trace. The map draws a revealed tile as a region of the ink or pencil image, so drawing costs nothing more.
- The save keeps, per traced place, the tiles walked and seen and a stamp of the trace. If a re-trace changes the tiling, that place's map starts again rather than drawing wrong.
- The Gorge's doors say where the stratum plan links them now; the camp's say where they led when traced.

**Verified:**

- `tests/map_trace_test.gd`, in two OS processes, with the world as you play it (seamless):
  - *save* (62 checks): start in the camp, go to its door, down the corridor, onto the Overlook, to the Gorge's doors to the Library Wing and the Lower Stacks. Checked:
    - the map knows which place you're in;
    - the tiles where you went are walked, more of the Gorge is only seen, never both;
    - the map opens on the Gorge with you on it, "to the camp" and "?" on the doors;
    - the camp's door says "to the Gorge".
  - *load* (7 with the GPU): a new process resumes in the Gorge with the same tiles walked in both places, and the map draws them.
- GPU captures: `previews/p11_step2/map_gorge.png` and `map_camp.png`.
- `tests/map_test.gd` (step 1) still passes (15 + 9 checks); the headless 240-frame gate passes.

**Caveats:**

- The test moves you by teleporting, so the stretches between the spots it visits are pencil, not ink. Walking covers them.
- A patch is drawn whole once revealed: its edge can cut a flight short in pencil.
- The Gorge is one sheet: where the span passes over a lower flight, the map shows the higher one.
- The camp's back door is drawn where it was traced. If the stratum plan moves the area behind it, re-run the trace.
- Not run: the full persistence gate, the frame gate and the route tests. The map only reads the world.

## Step 1: the map of an interior (committed d7c13a7, 2026-11-03, after your try)

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

- The Gorge and the camp weren't drawn in step 1 (see step 2).
- Long names in narrow rooms are turned to run along them; the Cistern Archive's name is a little longer than its room.
- Walls that two rooms share are drawn by both. Their wobble is the same, so they line up, but a pencil wall next to an ink one shows both.
- Not run: the full persistence gate, the frame gate and the route tests. The map touches the save only under its own key, and nothing in the world.
