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
