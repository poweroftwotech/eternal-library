# Phase 4 approval brief: areas and streaming

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-20 with the recommended answers to Q1–Q11; step 1 in progress** ·
Technical detail: [phase-4-design.md](phase-4-design.md)

This page is what you're approving. It says what you'll be able to do when
phase 4 is finished, the order it gets built in, and eleven choices that need
your answer. Nothing has been coded yet.

## What phase 4 adds, in one paragraph

Today you can visit the Reading Room with a gallery or three bolted onto its
doors, and that's the whole world: everything loads at once, and the
galleries end at a warm glow you can't walk through. After phase 4:

- the Reading Room is the heart of a **wing of 6–9 connected rooms**:
  galleries on its doors, and more galleries leading on from the ends of
  those;
- one of them is the **baked gallery** (the one already finished as a
  fixed scene), so hand-finished and generated rooms sit side by side;
- rooms **load ahead of you as you walk** and unload behind you, without
  the game stuttering;
- only the nearest few lamps cast shadows, so a big wing stays fast;
- everything from phase 3 (knocked-over vases, taken books, tended lamps,
  years passing) **works across the whole wing** and survives quitting;
- **you can never look through a line of doorways into a room that isn't
  there:** the wing is laid out so you can't see more than two rooms deep,
  and any room you can see into is loaded;
- it's **tuned for an RTX 3060**, not just your RTX 5090.

## What changed after our world-structure discussion (2026-10-20)

The whole world's shape is now written down in the architecture
([§2.1 world structure](architecture.md), [§8.2 graphics settings and
hardware tiers](architecture.md)): strata made of areas, thresholds between
areas, buildings carved into cavern walls, levels joined by stairs, a map
where nothing overlaps, and Low-to-Ultra graphics settings with FSR (and
DLSS later). Phase 4 doesn't build any of that, but it now lays its data out
for it, so nothing has to be torn out later:

| | Change | What you'd notice in phase 4 |
|---|---|---|
| 1 | Rooms are planned in 3D, with storeys, ready for stairs and stacked rooms | Nothing (every room is on the ground storey) |
| 2 | The wing has a reserved space and a position in its stratum, so future areas and the map can't overlap it | Nothing |
| 3 | The layout limits how far you can see through doorways, and loads every room you can see into | Long straight lines of doorways get broken up; no dark or missing rooms at the end of a view |
| 4 | Rooms can be unloaded, a cheap stand-in (later) or fully loaded | Nothing yet |
| 5 | The speed target is an RTX 3060 at medium settings, 1080p, 60 fps | The step 3 test is stricter (Q7) |

Together these add about a day to steps 1 and 2. The technical detail is in
[phase-4-design.md §8.1.9](phase-4-design.md).

## The finish line (from the roadmap)

> An area of 6–10 rooms (R01, several R02, one baked room) streams without
> hitches at the frame target.

"Without hitches at the frame target" needs a number, which is Q7 below.
My recommendation: on an RTX 3060 at medium settings and 1080p, the game
never drops below 60 frames a second while you walk the wing, even at the
moment a room arrives. There's no 3060 here, so this is checked on your
machine with a stricter time limit and with counts (draw calls, lights)
that are the same on any hardware.

## The four steps

You review each step in the game before the next one starts.

| Step | What you can try when it's done | How it's checked |
|---|---|---|
| **1. The whole wing, all at once** | Esc → **Walk the library wing**. The Reading Room, with a gallery on each door and more galleries beyond them, 6–9 rooms in all. You can walk end to end. Everything loads at the start (a short wait), so this step is about the layout, not speed. | 20 different wings are laid out and checked: no room overlaps another, no line of doorways lets you see more than two rooms deep, every doorway leads somewhere or is closed, the same seed always gives the same wing. A test player walks into every room and back. Pictures from above and inside. The loading cost of each room is measured, to size step 2. |
| **2. Rooms load as you walk** | The same wing, but only the rooms near you exist. Walk down a gallery and the next one is there before you reach its door; the rooms behind you go. The Esc menu shows "live: 4 of 8 rooms". Change something in a far gallery, walk away until it unloads, come back: it's still changed. | An automated walk checks which rooms are loaded at every point, that nothing is ever missing in front of you or at the end of a view, and that a room comes back exactly as you left it. A first log of frame times. |
| **3. No stutter** | The same walk, smooth. The nearest few chandeliers cast shadows; far lamps fade out where you can't see them anyway. **This step meets the finish line.** | The real game walks the whole wing three times at medium settings and 1080p, recording every frame. It fails if any frame would be too slow for an RTX 3060 (Q7). Pictures at each doorway at the moment the next room arrives, to look for lighting popping in. |
| **4. It all remembers** | Quit anywhere in the wing and restart: you're back in the same gallery. Changes in rooms that aren't even loaded are kept. Let ten years pass, then walk somewhere you haven't been: its lamps have aged too. | The save test grows from five separate runs of the game to seven, with changes in the nearest and the farthest rooms. |

## Not in phase 4

- **Loops.** The wing branches like a tree, so there's one way back to the
  Reading Room. Loops need corridors routed between rooms, which come with
  later room types (Q4).
- **More than one area**, or walking from one area into the next. The
  galleries at the wing's edge end at a closed, glowing arch (Q10).
- **New room types.** That's phase 5.
- **Lore books and props in the generated galleries.** Their shelves can
  still be pulled from, as now.
- **A designed loading screen.** Step 4's is a plain dark panel with a line
  of text.
- **The camp** is unchanged and stays where a new game starts (Q5).
- **Stairs between levels, stand-ins for far rooms, cavern facades and the
  map.** Phase 4's data is ready for them; they come with the room types
  that need them.
- **The graphics settings menu, presets and FSR/DLSS.** That's its own slice
  (see "Follow-up" below). Phase 4 keeps its streaming and light numbers in
  one settings file so the presets can change them later.

## Follow-up: graphics settings (not part of this approval)

Architecture [§8.2](architecture.md) describes the plan: Low, Medium, High
and Ultra presets plus Custom, the usual settings (resolution, upscaler and
render scale, anti-aliasing, bounce lighting, shadows, fog, ambient
occlusion, draw distance), and a first launch that picks a preset from your
graphics card. Two things to know now:

- **FSR 2.2 is built into Godot 4.7.2** and works on every card, including
  the RTX 3060, so it's available from the first settings slice.
- **DLSS is not built into Godot.** It needs a third-party plugin or a
  custom engine build, so it starts as a research step: find one that works
  with Godot 4.7, the .NET build and our renderer, and check NVIDIA's terms.
  The menu is designed so DLSS slots in when it's ready.

It gets its own approval brief when you want it scheduled.

## Things found while planning

- **The floor wear is the biggest stutter today.** The polished walking
  paths are redrawn for the whole world whenever a room appears, which
  takes about a tenth of a second. Step 2 changes it to draw only the new
  room, off the main thread. Nothing visible changes.
- **Rooms currently plan around each other only one level deep.** A gallery
  off a gallery could grow into a third room. In phase 4 the whole wing is
  laid out at the start, as data, before any room is built. So every room
  knows about every other, and a room looks the same whichever rooms happen
  to be loaded.
- **Your existing save carries over** if you take the recommendations for
  Q2 and Q3: the Reading Room's changes (vases, lore books, tended lamps) and
  the baked gallery's still apply. The other galleries are new rooms, so
  any changes saved in the old test galleries are kept in the file but not
  shown.

## Decisions for you

Each choice has my recommendation first. Answering "go with your
recommendations" is fine.

| # | Question | Recommended | Alternative | What changes |
|---|---|---|---|---|
| **Q1** | Which rooms make up the first wing? | **The Reading Room; the baked gallery on its west door; generated galleries on its east door and entrance; then 2–5 more galleries leading on from their ends.** 6–9 rooms. | You list the rooms and where each one goes. | The baked gallery was made on the west door, so it's known to fit there. The rest varies with the world's seed. |
| **Q2** | Does the Reading Room keep its current look, or get a new random one per world? | **Keep it.** It's the hand-made heart of the wing, and its saved changes keep applying. | It's re-rolled from each world's seed (different recesses, lamps and centrepiece per world). | Re-rolling gives variety between worlds, but your current save's Reading Room changes would no longer apply, and every R01 test picture would change. |
| **Q3** | What happens to your current save? | **It carries on.** The wing is called "library", the same name the save already uses. | Start everyone fresh with a new save format. | Starting fresh is simpler to build but throws away what you've done in the Reading Room. |
| **Q4** | How are rooms connected? | **Door to door, branching like a tree.** The galleries are themselves the corridors. | Also add a loop or two, with corridors routed between rooms. | Loops need corridor routing, a big piece of work better done with the grid and ring rooms in phase 5. |
| **Q5** | Where does a new game start? | **At the camp, as now.** The wing is on the Esc menu, and a saved game resumes wherever you were, wing included. | A new game starts in the Reading Room inside the wing. | The camp is still the game's loop (food, warmth). Moving the start is a game-design call, better made when the camp is rebuilt. |
| **Q6** | How far ahead do rooms load? | **Two doorways ahead, plus any room you can see into.** A room unloads once it's three doorways away (and out of view) for 10 seconds. | One doorway ahead (less memory, but less time to load before you arrive). | Two gives the game a whole room's walk to get the next one ready, so you should never see one appear. All three numbers are adjustable, and a Low graphics preset may use one later. |
| **Q7** | What counts as "no hitches"? | **On an RTX 3060 at medium settings and 1080p, no frame slower than 60 frames a second during the walk.** Checked on your machine at those settings: no frame over 4 ms of graphics work or 8 ms of processor work (about a quarter and a half of the 3060's budget), plus limits on draw calls, lights, shadows, triangles and video memory that are the same on any card. | Keep the original bar: 60 frames a second on your RTX 5090 at full settings. | Most players have hardware nearer a 3060. The 4× and 2× factors are estimates until someone runs it on a real 3060; your 5090 numbers are still logged alongside. |
| **Q8** | How many lamps cast shadows at once? | **The nearest four.** Others light the room without shadows, with a short fade when a lamp gains or loses its shadow. | Two (faster) or eight (richer). | Lanterns and gallery lamps already have no shadows; this is about chandeliers and braziers. It's one number you can change later. |
| **Q9** | Should a room age from when you last saw it? | **No, the whole world ages together** (the same rule as phase 3). | Each room remembers when you were last there and ages from that. | "Last seen" ageing matters once rooms are lived in and change hands. Phase 3 left it to later. |
| **Q10** | What's at the end of a gallery that leads nowhere? | **The warm glowing arch it has now:** it reads as "more library beyond", and you can't pass it. | A plain end wall. | The glowing arches are where the next area will join, later. A small number of galleries end in a plain wall anyway, for variety. |
| **Q11** | How deep can you see through a line of doorways? | **Two rooms beyond the one you're in.** The layout breaks longer lines with a turn, an offset doorway or a screen. | Three rooms (longer views, more rooms loaded at once). | Every room you can see into is loaded, so a deeper limit costs memory and frame time. Grand long views come later as cheap stand-ins. |

**Also needed from you, only if it comes up:** if the step 3 pictures show
lighting jumping when a room arrives, the fix is to change how the Reading
Room's bounce light works. That changes its look, so I'd show you before
and after first.

## How to approve

Reply with "approved" (or "approved, but Q… = …"). Step 1 then starts, and
you'll be asked to look at it in the game before step 2 begins.
