# Phase 6 approval brief: the Overlook and the Chasm Spans

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-25 with the recommended answers, except Q2: rebuild the gorge from kit pieces** ·
Technical detail: [phase-6-design.md](phase-6-design.md)

This page is what you're approving. It says what phase 6 adds, the steps it
gets built in, what you can try after each one, and the choices that need
your answer. Nothing has been coded yet. Since your answer to Q2, the steps
below are six: the gorge is first rebuilt from kit pieces (step 1).

## What phase 6 adds, in one paragraph

Today the gorge is a **view**: from the camp's balcony you look out over
cliffs carved into storeys of lit windows, aqueducts, waterfalls, and the
glowing sanctum at the far end, but you can't step off the balcony
(you chose view-only on 2026-10-18). Phase 6 lets you **go out into it**:

- **The Overlook:** the balcony and the near gorge become a place you walk.
  A rock-cut stair takes you down from the balcony to a ledge on the cliff.
  The whole gorge is **rebuilt from kit pieces** (your Q2), baked to a scene
  you can open and change, and checked against the box art as before.
- **The Chasm Spans (R10):** walkways across and along the gorge, made by a
  generator from where they start and end: a bridge on aqueduct arches if
  the gap is short and level enough, otherwise a chain of stairs and cliff
  ledges. Waterfalls through some arches, lamps on the decks.
- **Doors in the cliffs:** a few of the lit facades get a real door. Walk
  through one and you're inside the library (the Lower Stacks or the
  library wing); walk back out and you're on the ledge again. It's the
  first time you walk **from one area into another**.

On the Esc menu it's a new area, **Walk the Gorge** (Q1), and in the end
also the balcony's stair from the camp.

## Why it's its own phase (from phase 5's Q1)

The Overlook needed four things that didn't exist, and phase 6 builds them:

- a **cavern area**: an open gorge with facades carved into its walls,
  where the library's areas are rooms in a grid (architecture §2.1);
- **thresholds**: a doorway from one area into another, with your place
  saved on either side;
- **stand-ins**: the far gorge (the narrows, the far hall and the sanctum)
  stays scenery you see but can't reach, drawn cheaply;
- and **the look**: the gorge was matched to the box art over ten slices.
  Phase 6 rebuilds it from kit pieces (Q2), so it can be baked and changed
  by hand, checking every step with the same before-and-after pictures.

## The finish line

> You walk down from the balcony, cross the gorge on a generated span, go
> through a door in the far cliff into the library and come back out, and
> the view, now built from kit pieces, still matches the box art as well as
> it does today.

In numbers: the box-art comparison (`tests/compare_vista.gd`) passes as it
does now; the frame gate passes in the gorge at the base spec (RTX 3060,
Medium, 1080p, 60 fps); the test player walks every span and ledge from
the balcony and through every door; a save on a ledge or inside the
library resumes there in a fresh process.

## The six steps

You review each step in the game before the next one starts.

| Step | What you can try when it's done | How it's checked |
|---|---|---|
| **1. The gorge from kit pieces** | Esc → **Walk the Gorge**. You stand on the balcony and look at the gorge rebuilt from kit pieces: the same banks of stepped towers, facades, aqueducts, waterfalls, cavern and sanctum, laid out by a generator from the same plan and baked to a scene (`rooms/baked/gorge.tscn`) you can open in Godot and change. View only, like today. Halfway, you get a close look at one bank next to today's, to settle the look before the rest is converted. | The box-art comparison passes from the balcony, as it does from the camp today. Pictures side by side with the camp's view from the same spots. The frame gate looks out from the balcony at the base spec. |
| **2. The Overlook, walkable** | You start on the balcony. A rock-cut stair takes you down past the lamassu to a lantern-lit ledge along the cliff; you can walk the balcony, the stair and the ledge, and nothing else (parapets everywhere, Q4). | The box-art comparison before and after (same numbers, within its tolerance); pictures from the same spots. The test player walks the balcony, stair and ledge and can't step off. |
| **3. A span across the gorge** | From the ledge, a generated span crosses to a ledge on the far cliff: a two-tier aqueduct bridge with lamps on the deck and a waterfall through an arch, or, where the far ledge sits a storey or more lower, a chain of stairs and landings down the cliff. Reseed for another. | 20 seeds per kind: the span joins both ledges, has a parapet on every open side, and climbs no steeper than the kit's stairs. The test player crosses every one. |
| **4. The near gorge** | The near chamber becomes a small network: 4–6 ledges and loggias on both cliffs, joined by spans across and stairs along the cliffs, each different by seed. The narrows, the far hall and the sanctum stay as scenery past the end of the walkable part. | Every ledge is reached from the balcony; nothing overlaps; the box-art comparison still passes from the balcony. The frame gate walks the whole network. |
| **5. Doors into the library** | Two facades have a real door (Q6): one into the Lower Stacks (you come out in the caravanserai's gate), one into the library wing (R01). Walk in, walk out again to the same ledge. Quit on a ledge or inside and you resume there. | The test player walks through each door and back. The persistence gate grows to cover a save in the gorge and a save inside after coming in from the gorge. |
| **6. From the camp, and the frame target** | The camp's balcony looks out over the same baked gorge, so there's one gorge to change, and its stair leads down into it (a short loading panel, Q5). The old gorge code (`vista.gd` and its helpers) is retired. Far parts are drawn as merged stand-ins where the frame gate needs it. | The frame gate walks from the balcony through every span and door at the base spec. The camp's own tests still pass (it keeps its fire, cooking and garden). |

## Not in phase 6

- **The navigation map.** You asked for one so the library is easier to
  find your way round. The architecture already plans it (drawn from the
  areas' plans, floor by floor, revealed as you visit), and it needs the
  gorge's layout to exist first, so I recommend it as **phase 7**, right
  after this one. It's on the roadmap.
- **Falling, climbing and broken decks.** You can't fall off anything in
  phase 6 (Q4). Missing deck bays as a hazard or puzzle come later.
- **People on the spans** (caravans, travellers): the decks get places for
  them, as the caravanserai's hearth did.
- **Walking to the far hall or the sanctum.** They stay scenery (Q3).
- **Crossing between areas without a loading panel** (seamless). It needs
  both areas live at once; phase 6 uses the plain dark panel you already
  see when travelling (Q5).

## Things found while planning

- **The gorge is built by code today, not from kit pieces.** About 1,660
  lines (`vista.gd` and four helpers) make it, with **no walking
  collision** beyond the balcony. Its buildings repeat about 30 parts: five
  kinds of facade bay (lattice window, balcony window, doorway, book stack,
  tile panel), corner piers, deck edges with balustrades and lamps, merlon
  crowns, tower walls and crowns, aqueduct arcades and piers, pavilions,
  cypresses, banners, figures. Those become kit pieces (your Q2).
- **What the rebuild changes in the look.** The kit's grid is 4 m, so tiers
  become whole storeys (8 or 12 m; today 8.3–11.7 m) and facade bays 4 m
  wide (today about 4.2 m). Each bank keeps its own slight turn: its tiers
  are laid out on their own grid turned to the bank's angle, so the gorge
  doesn't snap square. Expect the same gorge, a little more regular; the
  close look at one bank in step 1 is where you'd say if it's too regular.
- **Some of it isn't architecture.** The cavern's rock (vault, stalactites,
  throats), the mist, the waterfalls' ribbons, the far enclosure and the
  lights are organic shapes or effects. They stay generated by their code,
  but **once, at bake time**, saved into the baked scene as meshes and
  nodes, so you can move, delete or replace any of it there too.
- **Hundreds of repeated pieces.** The gorge has over 600 facade bays and
  about 100 tiers. As separate pieces that would be thousands of draw calls
  (the budget is 1,500), so repeated pieces are drawn in batches when the
  scene loads, as the code does today; the baked scene keeps them as
  separate pieces for editing.
- **The camp builds the gorge today**, when it loads. Until step 6 the camp
  keeps its own view; in step 6 it shows the baked gorge instead and the
  old code is retired.
- **It's big.** The scenery runs about 280 m from the balcony to the
  sanctum's apse and drops 90–150 m to the mist (the waterfalls' height);
  the walkable part, the near chamber, is roughly its first 140 m. Rooms in an area are
  planned on a 4 m grid in 3D, which fits ledges and spans, but the
  gorge's scenery isn't on that grid, so the walkable parts must be fitted
  to it: frontage slots on the cliffs where ledges can go (design §5.7.3).
- **The near chamber already has two aqueducts**, as scenery: one about
  20 m below the balcony, one about 100 m below. A walkable span beside the
  upper one would crowd the view the box art was matched to, so I recommend
  the generated span **takes its place**, built in the same style by the
  same code (Q9); the deep one stays scenery. The box-art comparison
  guards it.
- **Spans can be long.** Up to 40 m across and 60 m deep, per the atlas.
  A 40 m span is 10 bays; the kit's bridge deck and aqueduct piers come in
  4 m bays like everything else, so a span is a run of bays. Deeper piers
  are the same piece stacked.
- **The frame budget is different out here.** The gorge has thousands of
  lit windows (emissive, no light each) and a few big lights; the library's
  "lights in reach" rule was made for rooms. Step 5 measures it; if the
  gorge needs its own limits, I'll bring numbers.
- **New kit pieces come from Blender**, as before: a script seeds each one
  into a new `kit_gorge.blend` (the gorge's architecture, about 30 pieces)
  and `kit_chasm.blend` (the walkable spans and ledges, about 15), then
  they're yours to edit.

## Decisions for you

Each choice has my recommendation first. Answering "go with your
recommendations" is fine.

| # | Question | Recommended | Alternative | What changes |
|---|---|---|---|---|
| **Q1** | How do you get to the gorge while it's being built? | **A new area on the Esc menu, Walk the Gorge**, from step 1; the camp balcony's stair joins it in step 5. | Only from the camp balcony. | The Esc entry lets you review each step without the camp; the camp stays as it is until the gorge is ready. |
| **Q2** | Keep the gorge's code, or rebuild it from kit pieces? **You chose: rebuild from kit pieces** (bakeable and editable). | My recommendation was: keep the code as scenery; add walkable kit pieces on top. | Rebuild the near cliffs from kit facade pieces. | Keeping it protects the box-art look you tuned over ten slices. Rebuilding would make the cliffs editable in Blender, at the risk of that look. |
| **Q3** | How much of the gorge can you walk? | **The near chamber:** the balcony, its stair, and 4–6 ledges and loggias joined by spans. The narrows, the far hall and the sanctum stay scenery. | The whole gorge, to the sanctum. | The whole gorge would need the far parts walkable and detailed up close, many times the work and the frame cost. The sanctum makes a good later destination. |
| **Q4** | Can you fall off? | **No:** parapets or balustrades on every open edge you can reach. | Open edges, with a fall that puts you back at the last ledge. | Falling needs a respawn and a reason to risk it; it fits better with broken decks and climbing, later. |
| **Q5** | How do you go through a door into another area? | **A short dark loading panel**, as travel already uses. | Seamless (both areas live while you walk through). | Seamless needs both areas loaded and stand-ins of each other; it's a step of its own once the map and strata exist. |
| **Q6** | Where do the cliff doors lead? | **Two doors: one into the Lower Stacks (the caravanserai's gate), one into the library wing (R01).** Other facades stay lit windows. | One door only, or a door on every ledge. | Two shows the idea both ways without planning interiors behind every facade. More doors come with the stratum plans. |
| **Q7** | What kinds of span? | **The aqueduct bridge (under 40 m, small drop) and the stair-and-ledge chain**, both with lamps, the bridge with waterfalls through some arches. | Also flying crossings (light decks, no arcade) and tunnel portals. | Two kinds cover the atlas's rule; the scenery already has flying crossings and portals to look at. |
| **Q8** | How wide are spans and ledges? | **One bay (4 m) of deck, 3 m to walk between parapets.** | Two bays (8 m) on the main crossing. | Narrow reads as the box art's aqueducts and keeps the gorge open; a wider main crossing is a setting if it feels tight. |
| **Q9** | What happens to the near chamber's upper scenery aqueduct (about 20 m below the balcony)? | **A generated span replaces it**, in the same two-tier style, so the view keeps its shape. The deep one stays scenery. | Keep it as scenery and put the walkable spans elsewhere in the near chamber. | Replacing keeps the composition you approved; keeping it adds a bridge to a view that's already full. |

## Approval

Approved 2026-10-25 with the recommended answers to Q1 and Q3–Q9; Q2:
rebuild the gorge from kit pieces. Step 1 starts; you'll look at one
rebuilt bank next to today's before the rest of the gorge is converted.
