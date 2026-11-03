# Approval brief: the navigation map, phase 11

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-11-03 with the recommended answers** (plus the list of places, and the look from the mock) ·
Background: [architecture §2.1](architecture.md) ("The map": drawn from plans, not geometry) ·
Game design: the player gets "a thread, not a leash" (landmarks, map notes and rumours steer them; nothing gives orders)

## What this does, in one paragraph

Today nothing in the game tells you where you've been. The interiors are generated, every world seed lays them out differently, and door travel takes you from place to place, so you can lose your way back to a room you liked. This phase adds a map you open with **M**. It draws only what you've seen, the way a traveller's notebook would: the rooms you've walked through in ink, the rooms you've only looked into in faint pencil, and the doorways you haven't been through yet marked as loose ends. It is drawn from the same plans the game builds rooms from (so it is always right for your world seed), it is kept in the save, and it covers every place: the interiors, the Gorge and the camp.

## What you'd get

- **M opens the map** (and closes it, as Esc does). The game pauses while it's open.
- **What's drawn:**
  - a room you've **entered**: its floor in ink, with its walls, doorways and name (Reading Room, Light-Well Stair…);
  - a room you've only **seen into** through a doorway: a faint outline, no name;
  - a doorway you **haven't been through**: a small open mark, so you can see where you haven't been;
  - **doors to other places**: the place's name ("to the Gorge", "to the Sanctum"), once you know where they lead;
  - **you**: an arrow showing where you are and which way you face.
- **Floors:** where a place has rooms on more than one storey (the Light-Well Stair, the cistern), tabs switch between them. The map opens on your floor.
- **Moving around it:** drag to pan, wheel to zoom, a key to centre on you. It opens on the place you're in. Zoomed out, you see every place you know at once, placed as they really lie in the stratum.
- **The places you know** (added 2026-11-03 at your request): a list down the side of the map page of every place you've been (the camp, the Gorge, the Lower Stacks…). Pick one and the map shows it, on the floor you were last on there. A place you haven't been to isn't listed; at most a Gorge door's label names it.
- **Your marks:** put a mark on the map (a few symbols: star, cross, question, lamp) with an optional short note, such as "good shelves" or "come back with light". They are saved.
- **Kept:** what you've discovered and your marks are in the save, per world, and survive quitting.

## The steps

| Step | What you can try |
|---|---|
| 1. The map of an interior | In the Lower Stacks, the Library Wing, the Forgotten Wing and the Sanctum: M opens the map; rooms appear as you enter them (ink) or look into them (pencil); loose-end doorways; floor tabs; the arrow; the list of places you've been, to switch between their maps. Quit, start again: the same rooms are drawn. Try: walk half of the Lower Stacks, open the map, go back to a dead end you passed |
| 2. The Gorge and the camp | The Gorge's ledges, stairs, spans and galleries and the camp's floor appear on the map as you walk them; each Gorge door is labelled with the place behind it once you've been through it. Try: cross the Gorge, open the map, find the door you came in by |
| 3. The whole stratum, and your marks | Zoom out to see every place you know together, joined by their doors and the corridor. Put marks with notes and find them again after a restart |

Each step is checked the same way: a test walks a route, saves, restarts the game in a new process and checks the map shows the same rooms; and a GPU capture of the open map so we can both look at it.

## Decisions (your answers: as recommended, 2026-11-03)

| | Question | Recommended | Why / what it means |
|---|---|---|---|
| Q1 | How should the map look? | **Ink and pencil on old, stained, torn parchment, in the game's pixel style** (settled with the [mock](https://claude.ai/artifact/LSnEpwg9XnPVp3DLoqYnx6): no ruled lines, the paper a generated pixel texture, pen lines that waver) | It fits a traveller in a ruined library and the "map notes" of the game design |
| Q2 | When does a room appear? | **When you enter it (ink); when you see into it through a doorway (faint pencil)** | Enter-only leaves the map patchy next to rooms you clearly saw. Showing the whole area at once would make exploring pointless |
| Q3 | Show the doorways you haven't been through? | **Yes**, as a small open mark | It is the "thread, not a leash": it shows where you haven't been without telling you to go there |
| Q4 | A small map in the corner of the screen while you walk? | **No**, only the full map on M | A corner map pulls your eyes off the rooms and makes landmarks matter less. Easy to add later if you miss it |
| Q5 | Does the game pause while the map is open? | **Yes**, for now | There are no threats yet to make reading the map tense. Revisit when there are |
| Q6 | The Gorge and the camp aren't built from the 4 m grid. How should they be drawn? | **A top-down outline of where you can walk, made once when the Gorge (and the camp) is baked, revealed in patches around where you've walked** | The interiors are drawn from their plans' cells, but the Gorge is made of ledges, stairs and spans with no cells. Its walkable outline is fixed (the Gorge is baked, not generated per seed), so it can be traced once. The other choice, simple labelled shapes, would look poor next to the interiors |
| Q7 | Your marks with notes: in this phase? | **Yes, in step 3**, a few symbols plus an optional short note | The game design names map notes as part of finding your way. If you'd rather keep this phase smaller, they can wait |

## Risks

- **Places you aren't in.** Door travel loads each place as its own scene, so the map of a place you're not in has to be planned again from its recipe and your world seed (about a third of a second per interior). The map does that once, in the background, the first time you open the zoomed-out view, and keeps it. The open map shows "drawing…" for that place until it's ready.
- **A recipe that changes after you've explored.** When the Strata Board raises an area's recipe version (its rooms move in existing worlds), the rooms you'd discovered there no longer match. The map then forgets that area (it is shown as unexplored again) rather than drawing rooms in the wrong place.
- **The Gorge outline.** Tracing it from the baked Gorge needs a downward check over a 0.5 m grid across the whole Gorge, done at bake time, not in the game. If it picks up roofs and ledge tops you can't reach, step 2 will need a pass to remove them; I'll show you the traced outline before using it.
- **UI rules.** The map page sits in the usual container layout (AGENTS.md §3). The drawing itself (rooms, arrow, marks) is a custom-drawn control inside it, since rooms aren't containers.

## Not included

- **Finding a route for you** ("show me the way to…"), or a line drawn back to the camp. The map shows; you find the way.
- **A compass or a corner map** (Q4).
- **Quest or story markers.** Nothing yet tells the map about goals, and the game design prefers you find them.
- **Drawing the map yourself** (sketching with the mouse). Marks and notes only.
- **More than one stratum.** The map is shaped for several (one page per stratum) but the game has one.
- **Lore books or items shown on the map.**
