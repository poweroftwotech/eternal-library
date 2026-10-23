# Phase 5 approval brief: kit breadth (new room types)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-22 with the recommended answers to Q1–Q12; step 1 in progress** ·
Technical detail: [phase-5-design.md](phase-5-design.md)

This page is what you're approving. It says which new rooms phase 5 adds,
the order they get built in, what you can try after each step, and the
choices that need your answer. Nothing has been coded yet.

## What phase 5 adds, in one paragraph

Today the library has two kinds of room: the hand-built Reading Room and
the generated corridor galleries. Phase 5 adds four more, each one
something you can walk:

- **The Hypostyle Stacks (R03):** a forest of twisted columns under small
  tiled domes, with freestanding bookcases between them. Aisles always lead
  to a landmark at the centre, so it's a hall you can get lost in and
  still find your way out of.
- **The Cistern Archive (R11):** the same column hall, flooded. Brick
  piers stand in still water, a stone causeway runs to a sealed bronze
  door, and books survive on platforms above the waterline.
- **The Light-Well Stair (R09):** a round shaft several storeys tall,
  ringed with shelf galleries, with a spiral stair and a pale oculus far
  above. It's the first room that takes you **up to other rooms on other
  floors**.
- **The Caravanserai (R05):** a courtyard of arched cells, two storeys
  high, around a raised hearth. Every cell rolls what's in it: a bedroll,
  a stable, a storeroom, a stall or a ruin.

They live in a new area on the Esc menu, **the Lower Stacks**, so the
library wing and your save stay as they are (Q3).

**The real test of phase 5** (from the roadmap) is the architecture: each
new type should come mostly from new kit pieces and settings files, with
little new code. Each step reports how much code it needed.

## What's not in phase 5, and why (Q1)

The roadmap also lists **porting the Overlook and the Chasm Spans (R10)**
out of the prototype's code. I recommend moving them to their own phase,
because they need things that don't exist yet:

- they're **cavern areas**, a different kind of area from the library's
  interiors, with facades carved into the cavern walls (architecture §2.1);
- reaching them means **walking from one area into another** through a
  threshold, which nothing does yet;
- a long view across a gorge needs **cheap stand-ins for far rooms**;
- and the Overlook's look was **tuned against the box art** over ten
  slices. Rebuilding it from kit pieces risks that look, so it deserves a
  phase where that's the whole focus, with before-and-after pictures.

The four rooms above need none of that.

## The finish line

> Each new type is added mostly through modules and `.tres` rules, with
> little new code.

"Little new code" needs a number. My recommendation: **the cistern needs
under 150 new lines of code (it reuses the hall's generator), and no other
type needs more than about 500.** Everything you'd want to tune (sizes,
densities, lamp spacing, what a cell can hold) is in settings files you can
change in the Inspector. Each step also passes the usual checks: a test
player walks every room, the base-spec frame target holds (RTX 3060,
Medium, 1080p, 60 fps), and you review the look in the game.

## The five steps

You review each step in the game before the next one starts.

| Step | What you can try when it's done | How it's checked |
|---|---|---|
| **1. A hall of columns** | Esc → **Walk the Lower Stacks**. You start in a Hypostyle hall of about 6 × 6 to 8 × 8 bays (24–32 m): twisted columns, a small tiled dome over every bay, freestanding bookcases, and clear aisles from each door to a great lamp under an oculus at the centre. Generated galleries lead off its doors. Reseed from the Esc menu to see another hall. | 20 halls are laid out and checked: every door's aisle reaches the landmark, no bookcase blocks a doorway, and every open cell can be reached. A test player walks every aisle. Pictures compared with the atlas mock. |
| **2. The big hall** | The hall grows up to 10 × 10 bays (40 m). The centre is one of three landmarks (Q6), there are lamp clusters, and the odd bay has collapsed into rubble. It still runs smoothly. | The frame gate walks every aisle at the base spec. Repeated pieces (columns, domes, floors) are drawn as one batch per kind, so a big hall stays within the draw-call budget. |
| **3. The Cistern Archive** | A gallery off the hall leads to a flooded cistern: brick piers in dark water, a causeway to a sealed bronze door, and book platforms between the piers. You can wade in the shallows, slowly. Deep water stops you (Q10). | It's the hall's generator with water added, so this step mostly measures the "little new code" test. The test player walks the causeway and wades the shallows, and it can't walk into deep water. |
| **4. The Light-Well Stair** | A round shaft 3–6 storeys tall: a spiral stair hugging the wall, a shelf gallery on every level, an oculus at the top. Some levels have a doorway out to a gallery **on that floor**. Climb up, walk out, and you're in a room above the ones you came from. | The test player climbs the stair to every level and walks out of every exit. The layout check now confirms no two rooms share space on any floor. Everything you can see across the shaft is loaded. |
| **5. The Caravanserai** | The Lower Stacks now start in a caravanserai: a 5 × 5 bay courtyard with two storeys of arched cells, a tall gate, and a hearth platform in the middle under the dark cavern. Every cell rolls what's in it. Once you've approved the look, a 3 × 3 and a 7 × 5 follow from the same pieces and rules (Q11). | Built like the baked gallery: generated from rules, then saved as a scene for hand finishing. The test player walks every cell and climbs the corner stairs to the upper storey. |

## Not in phase 5

- **The Overlook and the Chasm Spans (R10)**, if you agree with Q1 (above).
- **People:** the catalogue desk's librarian, the cistern's boatmen, the
  caravanserai's travellers. Phase 5 leaves the places for them (the
  sockets and anchors are already ready for NPCs).
- **Boats, and water levels that change** after a flood. The cistern's
  water stays at one level in phase 5.
- **Long descents between strata** down a light-well. That needs more
  than one stratum. Phase 5's light-wells are 3–6 storeys inside one area.
- **Moving the camp's food and warmth loop** into the caravanserai (Q12).
- **Loops** in the area layout. The hall itself gives you many routes
  between its doors (Q4).
- **The graphics settings menu.** It's still its own slice, waiting until
  you schedule it.

## Things found while planning

- **The gallery generator is shaped like a corridor.** It assumes one
  barrel vault per bay, and pillars only where walls meet. A column hall
  needs columns standing in open floor, domes, and arches between columns.
  So step 1 first makes the builder follow the rules files rather than
  corridor assumptions, and checks that every gallery still comes out
  exactly as before.
- **A big hall means hundreds of identical pieces.** Today each piece costs
  its own draw call, and a 10 × 10 hall would use most of the 1,500
  budget on its own. Step 2 draws repeated pieces in batches.
- **The atlas gives the light-well 5 m per level, but the kit's storey is
  4 m.** I recommend 4 m (Q7), so its doorways line up with every other
  room's floors.
- **Kit pieces aren't scaled** (the kit's rule: arches, stair treads and
  railings would stretch), so a round shaft can't take any radius. I
  recommend two fixed sizes (Q8).
- **The floor wear is drawn on a single flat map.** In a room above
  another room, the upper floor would show the lower floor's paths. Phase 5
  keeps wear on the ground floor only. Per-floor wear is a later item.
- **New kit pieces come from Blender** like the existing ones: a script
  seeds each new piece, and after that the `.blend` files are yours to edit
  by hand. About 25 new pieces over the five steps (listed in the
  technical design).

## Decisions for you

Each choice has my recommendation first. Answering "go with your
recommendations" is fine.

| # | Question | Recommended | Alternative | What changes |
|---|---|---|---|---|
| **Q1** | Do the Overlook and the Chasm Spans (R10) stay in phase 5? | **Move them to their own phase** (cavern areas, thresholds and stand-ins first). | Keep them in phase 5, after the four rooms. | Moving them keeps phase 5 to rooms that fit what's built today. Keeping them roughly doubles phase 5 and puts the box-art look at risk. |
| **Q2** | In what order are the rooms built? | **Hall, cistern, light-well, caravanserai.** The cistern reuses the hall; the light-well is the hardest new idea (other floors); the caravanserai reuses the bake pipeline. | You pick the order. | The hall goes first because it changes the generator that the others build on. |
| **Q3** | Where do the new rooms appear? | **In a new area, the Lower Stacks**, on the Esc menu. It grows with each step. | Add them to the library wing. | The library wing and your save stay as they are. Which rooms appear where in the real world is for the stratum plans, later. |
| **Q4** | Add loops to the area layout? | **Not in phase 5.** The hall already has many routes between its doors. | Add one routed loop per area (corridors routed between two doors). | Phase 4 deferred loops to "the grid and ring rooms". Routing corridors is a sizeable job of its own, and it fits better with the thresholds work in the phase after. |
| **Q5** | How big can the hall get? | **6 × 6 up to 10 × 10 bays** (24–40 m) in phase 5. | The atlas's full range: up to 20 × 20 (80 m). | Beyond 10 × 10 a hall needs far parts drawn as cheap stand-ins, which come with the cavern work. The rules allow bigger halls once that exists. |
| **Q6** | What can stand at the hall's centre? | **A great lamp under an oculus, a reading tree, or a catalogue desk** (with no librarian yet), picked by the seed. | Just the great lamp for now. | The landmark is how you find your way. Three choices make halls feel different; the desk is ready for an NPC later. |
| **Q7** | How tall is a light-well level? | **4 m, the kit's storey.** | 5 m, as in the atlas. | At 4 m, every level's doorway lines up with the floors of the rooms around it. 5 m would need a second set of stairs and walls for everything that joins it. |
| **Q8** | How wide is a light-well? | **Two fixed sizes: 8 m and 12 m radius.** | One size, or more sizes later. | Pieces aren't scaled, so each size is its own set of curved pieces. Two sizes give a narrow shaft and a grand one. |
| **Q9** | How deep can a light-well go in phase 5? | **3 to 6 storeys.** | Up to 12 storeys. | Every room off a level you can see across the shaft has to be loaded. Six storeys keeps that within the frame budget. Deep descents come with strata. |
| **Q10** | Can you walk in the cistern's water? | **Wade the shallows at half speed; deep water stops you.** No swimming. | Causeway and platforms only (all water blocks). | Wading makes the flooded hall feel real and opens side routes. Swimming, boats and changing water levels come later. |
| **Q11** | How many caravanserai sizes? | **5 × 5 first; 3 × 3 and 7 × 5 after you approve its look**, all from the same pieces and rules. | All three at once. | One size first means a change to the look is made once, not three times. |
| **Q12** | Does the camp's cooking and warmth move into the caravanserai? | **No, the camp keeps it.** The caravanserai's hearth is a place to sit, not yet a cooking pot. | Move the cooking pot and warmth to the caravanserai hearth. | Moving the loop is a game-design call (like phase 4's Q5), better made when the camp is rebuilt from kit pieces. |

## How to approve

Reply with "approved" (or "approved, but Q… = …"). Step 1 then starts, and
you'll be asked to look at it in the game before step 2 begins.
