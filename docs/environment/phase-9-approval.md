# Approval brief: one continuous world (no loading between places)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-27 with the recommended answers** (phase 9; the navigation map moves to phase 10) ·
Background: [architecture §2.1](architecture.md) (world structure, agreed 2026-10-20)

## What this does, in one paragraph

Today every door between places (the camp, the Gorge, the Library Wing, the Lower Stacks) saves the game, shows a loading screen and rebuilds the whole scene on the other side. This phase makes those doors ordinary doorways: the next place loads in the background while you're still in the current one, and you walk through without a pause, as you already do between rooms inside an area. The world structure we agreed in October already plans for it ("a threshold is long enough to walk for the next area to load"), so this fills in the parts that were left for later.

## What I measured first (RTX 5090, 1080p)

| | Loading screen today | In the background (tried in a spike) |
|---|---|---|
| Planning the Gorge (its bridges and ledges) | 5.2 s, inside the loading screen | Runs on a worker thread while you're in the camp; the camp's frames didn't change (3.4 ms, worst 6.6 ms) |
| Loading the Gorge's scenery files | — | Under a second on the loader's threads |
| Building the Gorge's scenery (instantiate) | — | **317 ms on the main thread: a visible hitch.** Must move off the main thread or be split up |
| Adding it to the world | — | 22 ms, then one 24 ms frame (shaders and batching warming up) |
| The camp with the Gorge loaded behind its walls | — | 3.4 → 4.7 ms a frame: the Gorge is drawn although the walls hide it. Needs culling while you're inside |
| Library Wing, Lower Stacks | 0.7–1.0 s each | Their rooms already stream in pieces; only the area's start-up work needs moving |

Memory isn't a problem: the Gorge adds about 120 MB, an interior 50–130 MB.

**Conclusion:** it's possible. Nothing found so far rules it out, but three things need real work: building the Gorge's scenery without a hitch, not drawing a place you can't see, and lining up places that were each built in their own coordinates.

## How it would work

- **Neighbours load early.** While you're in a place, the places its doors lead to are planned and loaded in the background, hidden. Walking through a door just shows the next place.
- **Doors become short passages.** Each door between places becomes a short passage with a turn (a vestibule, or a dog-leg corridor). From inside the passage you can't see either place, so the switch happens there with nothing to notice. If the next place isn't ready yet (a slow machine), the old loading screen covers the gap, as agreed.
- **Only the place you're in is drawn and has collision.** The other one stays loaded but hidden, so its rooms can't show through walls or block you. This also means places can overlap in space without anyone seeing it, which matters for the interiors (next point).
- **Lining places up.** The camp and the Gorge already share coordinates: the camp's door is at z −13.2 and the Overlook's door back is 5.5 m behind it, so a short passage joins them. The interiors were planned in their own coordinates, so each is placed so that its door meets its gorge door. Their rooms may then reach into the gorge's rock, which is fine because only one place is shown at a time.
- **Lighting and fog blend.** Each place keeps its own lighting and fog; they fade from one to the other along the passage.
- **Saving** works per place, as now; a save made in a passage resumes on the nearer side.

## The steps

| Step | What you can try |
|---|---|
| 1. Camp ↔ Gorge | The kit camp (`rooms/camp/camp.tscn`) and the Gorge. Walk from the camp through a new passage onto the Overlook and back, no loading screen. The Gorge plans and loads while you're in the camp; its scenery builds without a hitch; it isn't drawn while you're inside |
| 2. Gorge ↔ interiors | The Gorge's doors to the Library Wing and the Lower Stacks become passages; the interiors are placed so their doors meet, load in the background, and swap in the passage |
| 3. Interiors ↔ each other, and the frame gate | Any remaining doors between areas, plus a walk test from the camp through the Gorge into both interiors and back. It checks frame times along the whole walk, including the swaps, and the persistence test across a save made between places |

## Decisions (your answers: as recommended, 2026-10-27)

| | Question | Recommended | Why |
|---|---|---|---|
| Q1 | Should I go ahead with this as phase 9 (the map moves to phase 10)? | **Yes** | It changes how every area starts, so it's better done before the map, which draws from the same area plans |
| Q2 | How should a door between places look? | **A short passage with a turn** (a vestibule of 6–10 m) | It hides the swap and gives the next place time to load; a straight doorway would show the other place before it's there |
| Q3 | What should happen if the next place isn't ready when you reach the end of the passage? | **A short loading screen, as agreed in October** | On the RTX 5090 it shouldn't show; on slower machines it keeps things working |
| Q4 | How far ahead should places load? | **Only the places one door away** | Keeps memory and background work down; the Gorge is the largest at about 120 MB |
| Q5 | What about the old code-built camp and its view of the gorge? | **Already gone; remove the leftovers** | The game uses the kit camp (`rooms/camp/camp.tscn`, phase 7); the code-built camp was deleted then, and the kit camp draws no gorge. What remains are `vista.gd`'s camp-only branches (old waterfalls, old gate, used only when the bake isn't walkable), which nothing runs: removed in step 1 |

## Risks

- **Building the Gorge's scenery off the main thread.** Godot can build scenes on a worker thread, but some node types insist on the main thread. If that hits a wall, the fallback is to build the scenery in slices over a few dozen frames, as the room streamer already does for big rooms.
- **The first frame with new materials** (shaders compiling) can hitch. The streamer already warms rooms up ahead of time, and the same can be done for each place.
- **Interiors reaching into the gorge's rock** are fine while only one place is shown. Seeing both at once (a window from an interior onto the gorge) would need them reserved space in the shared world, which is the stratum plan agreed in October, and isn't part of this phase.

## Not included

- The stratum plan (every area reserving its space in one shared world map) and windows from interiors onto the gorge.
- New areas, or new doors between areas.
- The navigation map (phase 10).
