# Phase 9 progress: one continuous world

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Brief](../phase-9-approval.md)

## The spike: loading the Gorge from the camp without a hitch (2026-10-27)

Measured on the RTX 5090 at 1080p, standing in the kit camp (`rooms/camp/camp.tscn`; the camp's frame is about 3.4 ms).

| Tried | Worst camp frame | Verdict |
|---|---|---|
| Plan the Gorge (5.2 s) on a worker thread | 6.6 ms | Works |
| Load `gorge.tscn` with the threaded loader | 145–200 ms | Stalls: the renderer takes new resources on the main thread |
| Build (instantiate) it on a worker thread | 71–78 ms | Stalls, for the same reason |
| The same with the renderer on its own thread (`--render-thread separate`, experimental) | 165 ms | No better |
| Load each kit material first | 77 ms | Not the cause on its own |
| Split the scenery into 80 small scenes, load one at a time | 77 ms (20 frames over 8.3 ms) | The big merged meshes still stall |
| Preload the pieces' files, build one piece a frame | 212 ms | A merged mesh costs 18–35 ms the **first** time it is built, 0 ms after |
| **Preload and build every piece once behind the start-up screen (388 ms more at boot), then build one piece a frame, hidden** | **4.2 ms** | **No hitch** |
| Then show the Gorge all at once | 17 ms, one frame | A visible stutter |
| **Show it one piece a frame** | **5.3 ms** | **No hitch** |

So the Gorge's scenery can come in without a hitch if:

1. it's baked as many small scenes, not one;
2. its files are loaded and each piece built once (then thrown away) during the game's start-up screen, which costs about 0.4 s once;
3. it's built one piece a frame, hidden, while you're elsewhere; and
4. it's shown one piece a frame as you walk into the passage.

Planning runs on a worker thread throughout.

## Step 1 so far (2026-10-27)

- **The Gorge's scenery as 80 small scenes** (`tools/bake_gorge.gd` `save_pieces`, `rooms/baked/gorge/pieces/`, listed in `pieces.tres`, a `PlacePieces` resource with the environment and the kit modules' bounds); the recipe points at them (`AreaRecipe.scenery_pieces`).
- **`Area.background`**: the plan made on a worker thread and handed in (`prepared_plan`); the scenery built one piece a frame, the kit cleared where the network stands a batch at a time; the network's rooms streamed in within the streamer's budget (`AreaStreamer.start_background`); not `active` (the save's changes, floor wear and its environment stay the place you're in) until `activate()`; `reveal()` shows it one piece a frame.
- **Three costs found and removed on the way:**
  - the kit's batches were refilled from their saved transforms every build (28 ms a piece): `KitBatcher._fill` skips a MultiMesh already filled and unchanged;
  - clearing read each batch back from the GPU (3–7 ms a batch): `GorgeScenery.clear_batch` reads the saved copy;
  - the network's made stonework merged hundreds of boxes and balusters with `SurfaceTool.append_from`, which reads every copy back from the GPU: **83 ms for a long link with the game running** (headless, 15 ms, which is why it never showed in the tests). Boxes, balusters, newel caps, troughs and culverts are now instances of one mesh each (`ChasmMasonry.instances`; the gorge's materials map in world space, so a scaled unit box looks the same). Every network room now builds in under 4 ms; this also speeds up the Gorge's normal start.
- **Background build from the camp now:** plan 5.7 s on a worker (camp frames unchanged), then the scenery and rooms in about 1 s: 12 frames over 8.3 ms out of 212, worst 27 ms (the Overlook room's first build, to be warmed at boot); the reveal, worst 7 ms.
- **Found:** the camp already has the original book-lined corridor behind its gallery doorway (`camp_passage`, from the code-built camp, which looked down it to the balcony). Its floor stops a few metres in; the door's glowing wall hid the rest. Waiting on your call: straight through (the original view) or a turn.

## Step 1: the camp ↔ the Gorge, straight through (2026-10-27, committed)

Your call: straight through, the camp looking out at the gorge as first designed.

- **No new building was needed.** The camp's book-lined corridor behind its gallery doorway (`camp_passage`) and the Overlook's passage in the loggia's back wall (`bake_overlook.gd`) already meet. Only the two doors were in the way: the camp's glowing doorway (`Threshold_gorge`, removed when the camp loads) and the Overlook's bronze door (left out of the bake; the gorge recipe no longer has a threshold to the camp).
- **`SeamlessPlaces`** (`scripts/world/seamless_places.gd`, added by `main.gd` in the camp or the Gorge; `--no-seamless` turns it off):
  - warms the other place behind the start-up screen (the Gorge: 250–450 ms),
  - builds it in the background (the Gorge: planned on a worker thread, then `Area.background`, about 4–5 s after start-up; frames worst 24 ms, 8 over 8.3 ms),
  - swaps which is the place you're in at z −15.8, halfway along the corridor (the save's area, the HUD, the fall limit, the stats panel; the place you're in is always the node called `Environment`),
  - blends the two environments along the corridor in one Environment resource (swapping the resource restarted the GI: a 200 ms frame),
  - from the camp, shows the Gorge only while the gallery doorway is within 25° of the view (6 pieces a frame; shown at once, a 7–10 ms frame) and hides it when you turn away.
- **Walked** (RTX 5090, 1600×900): camp → loggia and back, the same game throughout; frames mean 2.9–3.7 ms, one or two frames of 20–35 ms at the swap (the Gorge's `activate`, 16 ms).
- **The camp's cost with the Gorge built** (`tests/camp_frame_capture.gd`, Medium 1080p, a full turn at each viewpoint): GPU 2.24 ms mean, 4.04 worst (1.58 / 2.68 without it); draw calls up to 5,100 while looking through the doorway (1,281). That's the price of the view.
- **Box art** unchanged and passing.
- **Tests** updated: `persist_test` `camp_cross` / `camp_back` walk the corridor (save in one process, resume on the loggia in a new one, walk back; 10 and 8 checks, passing); `playtest` (33 checks, passing).

**Caveats:**
- For the first 4–5 s after the game starts, the Gorge isn't built yet: the doorway shows the corridor and the loggia fading into mist.
- One run of the walk showed a long stretch of 15 ms frames after the swap; it didn't repeat in three more runs. To watch in the frame gate (step 3).

### Your walk of the corridor (2026-10-27, five reports)

- **The camp's bookcases in the corridor, clipping** (both ends): the camp's back piece (`camp_back`) carried bookshelves and frames past its wall into the corridor, and the camp had its own corridor dressing (`camp_passage`, the code-built camp's), both overlapping the Gorge's corridor. `camp_passage` is gone from `rooms/camp/camp.tscn`; `camp_back` lost everything behind the camp's wall (`art_src/kit/kit_camp.blend`, re-exported). The corridor is now the Gorge's alone: brick walls, a tile band, a sandstone ceiling, one pointed arch.
- **The corridor's lantern** is gone (walked only; `vista.gd`).
- **A darker corridor between the bright camp and gorge**: `SeamlessPlaces` takes up to 70% of the ambient light away toward the corridor's middle, on top of the blend.
- **The arch clipping the geometry above**: the first arch (z −14) ran into the camp's lintel over the doorway (the lightwell's brick, down to y 6.0 as far as z −15). It's gone; the doorway's own arch frame is there.
- **Outside the corridor** (fly mode, a respawn), the place you're in now follows the side you're on.

Verified: playtest 33, the camp's persistence modes (save, load, cross, back) all passing, route 8.
- **Z-fighting on the floor in the doorway** (your next report): the camp's doorway sill (`DoorwaySill`, top at 2.2) and the Gorge's corridor paving (top at 2.2) overlapped between z −14.6 and −13.1. The sill is now 3 cm lower, under the paving; it still carries you over that strip in the first seconds before the Gorge is built. Playtest passes.

## Step 2: the Gorge ↔ the interiors (2026-10-28, uncommitted)

The Gorge's doors to the Library Wing and the Lower Stacks are walked through too, with no loading screen.

- **The vestibule** (`scripts/world/vestibule.gd`): from the Gorge's door on its ledge (`gorge_door_open`, new in the kit: the pishtaq without its leaves) a dog-leg passage runs into the bank: 3 m in, a turn, 6 m along, a turn back, 3 m on to the interior's door. Brick walls and vault, stone paving, two small warm lamps. From inside it neither end sees the other. The bank's stone cores are left out behind door slots (`PersianTown._door_cavity`), and the bank's kit pieces where it runs are cleared (`Area._vestibule_claims`).
- **The interior is placed** so its door back meets the vestibule's far end (`SeamlessPlaces._interior_frame`); its door back has no threshold (`Area.open_doors`). The interiors overlap the Gorge's banks in space, so only the place you're in is shown, and the player walks on its collision only: the camp and the Gorge are on their own physics layer (`SeamlessPlaces.OPEN_LAYER`), the interiors on the usual one, and the player's mask follows the place you're in. (Taking the Gorge's thousands of bodies out of the physics and back took a 250–300 ms frame; the layers cost nothing.)
- **`SeamlessPlaces`** now keeps the place you're in and every place one link away: from the Gorge, the camp and both interiors; from an interior, the Gorge; from the camp, the Gorge. Moving on frees what's no longer a link away, 50 nodes a frame (all at once, a 240 ms frame), and stops building places you've moved away from. The swap happens in the vestibule's middle; the environment blends along it, darker in the middle. If the next place isn't built yet, the old loading screen covers the wait (Q3).
- **Floor wear** follows the place you're in without a full rebuild (`FloorWear.retarget`, 250 ms before); a hidden place's wear isn't drawn until you're in it.
- **Saves** keep the player's position in the place's own frame, so a save made in an interior (which stands off the origin in the Gorge's world) resumes there with the interior at the origin and the Gorge placed by it.
- **Walked** (RTX 5090, 1600×900; `vest_walk` spike): the Gorge's ledge → the vestibule → the Library Wing's Reading Room and back. Frames median 1.4–1.8 ms; 2–6 frames of 20–37 ms around the swaps (the old place's shadows and the new place's lights settling). The interiors are built about 2 s after start-up.
- **Tests:** `persist_test` `door_cross` / `door_back` walk the vestibule across processes (save on the ledge, resume, walk into the Lower Stacks, save there, resume there, walk back to the same ledge): 4, 8 and 9 checks, passing.

**Caveats:**
- The vestibule's brick is the Persian kit's at a small scale; it reads as fine brick from a distance.
- Only the Gorge's two doors are walked. Doors between the interiors themselves, if any are added, would need their own vestibules (step 3).

### Your walk of step 2 (2026-10-28, eleven reports)

- **The ~1 s pause walking back into the Gorge**: the camp was built again in one go on the main thread (it had been let go while you were in an interior). The camp and the Gorge now stay once built (the hub, about 160 MB), the camp is built on a worker thread, and the camp is hidden while you're in an interior. A full round trip through both doors and back: worst frame 54 ms, 16 frames over 12 ms in about 15,000.
- **A wait, if there is one, shows a quiet "Loading…" note** instead of the loading screen (your call).
- **Missing chunks of the Gorge near the doors**: the bake cut the bank's stone cores out for the whole width of each door slot (up to 60 m) and 16 m deep. The cut is gone; the core cells by a door slot are now baked as their own boxes (`door_core_*`), and the game hides only those the passage runs through (`Area._open_cores`). The passage's scenery clearing stays 1.6 m behind the cliff face, so the wall bays beside the door stay; a narrow clearing takes the bay in the doorway itself.
- **The z-fighting on the passage walls**: its box normals were smoothed across the corners, so the brick's world-space projections blended. It uses the boxes' own normals now.
- **The abrupt change of light at the swap**: the passage was lit by the places either side, whose lights changed as one was hidden and the other shown. It's on its own render layer now (`Vestibule.LAYER`), lit only by its two lamps; the places' lights leave it out (`SeamlessPlaces._unlight`, also for rooms as they stream in).
- **The dark corner on ledge_2** isn't from this step (the same with the system off); it's noted in `gorge-later.md`.

### Your second walk of step 2 (2026-10-28, five reports)

- **Missing geometry over and beside the doors**: the passage's clearing reached 4.3 m up, into the storey over the door (its walls went), and the hidden core blocks were whole cells up to three storeys tall (a 12 m hole above the passage). The clearing now stops at 3.7 m, and the door-side core cells are baked a storey a box, so only the storey the passage runs through is hidden.
- **The arch faces missing from inside**: the end wall round the Gorge's door was a rectangle; looking out, the open door's arch showed its faceless back in the corners. The end wall now has the arch's own shape (`Vestibule._arch_wall`).
- **Z-fighting where the passage meets the Reading Room**: each interior's own doorway reaches into the passage (the Reading Room's wall 0.45 m, the Lower Stacks' piers 1.1 m), and the passage's last walls, floor and vault overlapped it. The passage now stops 1.2 m short of the interior's door (`EXIT_INSET`), and its corner posts stay inside both doors' planes.

### Flicker, floating pieces and gaps in my walk (2026-10-28)

You saw these in my walk and asked me to check with screenshots. I shot each passage every 2 m, in and out, looking ahead, left and right (66 views a passage), and ran a flicker finder: each view again with the camera moved 2 mm, compared.

- **The passage floor flickered** with the bank's stone under it: both had their tops on the storey line. The passage floor is 1.5 cm higher (`Vestibule.FLOOR_UP`).
- **The floor stopped short at the interior's door** (my walk fell into the dark): stopping the passage 1.2 m short of the door (the last round) left a gap in the floor. A strip of paving now runs on under the interior's doorway, 3 cm below its floor.
- **The step and sill of the Gorge's open door hung in the air**: `gorge_door_open` kept the closed door's step and sill with nothing under them. The open door has neither now, just a plinth either side (`tools/kit_add_gorge.py`, re-exported).
- **A stone slab across the Library passage, waist high**: the sill of a window in the bank's front, which the passage runs through. The scenery clearing had marked it removed, but the batch drawn on screen was never updated. Two causes, both fixed: the baked scenes had saved a "batch already filled" mark (`KitBatcher` keeps that mark in memory now, so every batch is filled from its own transforms the first time it loads), and a piece already hidden in the saved transforms didn't count as a change, so they were never sent to the GPU (`GorgeScenery.clear_batch`).
- **"Layer index is out of bounds" errors at the swaps**: the floor-wear map was asked for tiles past its edge when a floor reached beyond the place's rectangle. It now updates only its own tiles (`FloorWear._upload_tiles`).

After the fixes, the flicker finder shows only the brick texture's pixel edges moving with the camera, nowhere two faces fighting. The views show no floating pieces and no gaps.

### Your third walk of step 2 (2026-10-28, four reports)

- **The Gorge door's arch missing faces from inside** (two reports): the passage's end wall stood 6 cm inside the door's line, but the door's frame starts 25 cm outside it, and the frame has no back. Through the 31 cm slot between them you saw the cave beside the arch's stones. The end wall now runs out to the frame's back plate (`Vestibule.FRAME_BACK`), so the brick soffit meets the stone ring.
- **A gap where the passage meets the Reading Room** (two reports): last round's 1.2 m inset came from a wrong measurement. Both interiors' door walls start 0.3 m in front of the door line, and their openings are the passage's own 3 m width, 3.56 m tall. The passage stopped 1.2 m short, which left a 0.9 m slot open to the dark on either side. It now stops 0.3 m short (`EXIT_INSET`), right where the rooms' walls start, without running into their openings (which was the earlier flicker).
