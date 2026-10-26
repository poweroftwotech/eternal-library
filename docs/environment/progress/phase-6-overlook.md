# Progress: phase 6, the Overlook and the Chasm Spans

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../phase-6-approval.md), [technical](../phase-6-design.md)

**In short:** phase 6 was approved on 2026-10-25 with the recommended
answers except Q2: the gorge is rebuilt from kit pieces, so it can be baked
and changed by hand. Step 1 is built: the whole gorge (8 banks, 11 towers, 6
aqueducts, the sanctum) from 45 kit pieces, baked to scenes you can edit,
shown in a new area, Esc → Walk the Gorge, from the balcony. It passes the
box-art comparison and loads in a quarter of a second. Step 2 is built: the
Overlook is walkable, from the balcony down the rock-cut stair to the landing
and on down to a lantern-lit ledge, with a parapet everywhere. Step 3 is built:
from the ledge's corner a generated span crosses the gorge toward bank 2 on
the old near aqueduct's arcades, as a level bridge or a chain of flights down
to a lower far ledge, by seed. You walked it four times (18 reports fixed) and
approved it; committed b65d383. Step 4 is built: the near gorge is a small
network of 4–6 cliff galleries on both cliffs, joined by spans across and
stairs along the cliffs, different by seed. You walked it once (14 reports,
fixed); waiting for your next walk.

---

## Step 4: the near gorge (built 2026-10-26; walked three times, 19 reports fixed; waiting for your next walk)

### Walk 3 (2026-10-26, seed 433536861): the waterfalls, and a gap

| Report | What you saw | Fix |
|---|---|---|
| 14-16, 14-17 | the water comes out of solid tiles and falls partly through solid tiles, with no visible source | every waterfall (the spans' and the baked aqueducts') hung from under the upper arch's crown and bent out only about 1.3 m by the lower arcade, so it fell through that arcade's 1.9 m faience course; the baked aqueducts' falls weren't even turned to their aqueduct. Now each pours from a **stone trough on the upper arcade's side**, just under the deck (the aqueduct's outlet: a floor and two cheeks, jutting 1.4 m), 1.2 m wide, clear of all below. `ChasmGrammar.TROUGH`, used by both; the gorge was re-baked (`tools/bake_gorge.gd`) |
| 14-18 | lots of empty gaps | **not fixed yet.** Bank 1's and bank 3's baked tiers leave slits where two walls should meet, and behind their facades they're hollow (a camera inside sees an empty corridor). From the balcony none of it showed; links now pass close enough to see in. It's the same family as the clipping and extra geometry you noticed, so it's proposed for a scenery clean-up pass |

**Checks:** `gorge_network_test` 670/0, `r10_span_test` 485/0, box art seeds
1–8 pass. Pictures: `previews/p6_step4/walk3/` (your three views re-taken, a
trough close up, and the gap from the side).

### Walk 2 (2026-10-26, seed 433536861): the Overlook's ledge on arches

All three reports were about straight piers under "the span", and walk 1's
report 1 was too: they were the **Overlook's own ledge** (step 2's bake),
which had always stood on a corbel and a straight pier per bay, its last bay
on a stub pier on bank 1's terrace and the one before on a lintel. Walk 1's
fix went to the links instead.

| Report | What you saw | Fix |
|---|---|---|
| 12-41, 12-42 | straight columns in the way; they were meant to become arches like the rest of the span | the Overlook's ledge is now **span decks on arcades**: the run out from the stair on one 12 m arcade (upper and lower tier, piers at its ends in the mist), the run toward bank 1 on **one arch from that arcade's flank to bank 1's facade** (stretched to 20.5 m), its far foot on the terrace against the wall |
| 12-43 (and walk 1's 10-46) | the support onto the terrace and the block under the span's end: remove them | gone. As you said, the ledge stopped **3–4 m short of bank 1's wall**, so it needed them: it now runs one bay further, **into the facade** (its gallery storey), and the wall carries its end. A guard stands at the facade (it has no collision of its own) |
| (with 12-42) | the main span's last flight on a straight pier beside the Overlook | a link's **last flight** (two bays, arriving at the far end) no longer gets a pier when its top stands on the arcade pier before it: it spans from that pier to the end's edge |

The Overlook's piers now count as obstacles for the planner (they're plain
stone, not kit pieces, so before this links could pass among them: walk
1's link 2 ran right under the ledge). The link table was regenerated:
6,308 links stand (was 6,224). Your seed lays out a different network again.

**Checks:** `gorge_route_test` 8/0 (the walk reaches the new end; the facade
guard holds), `gorge_network_test` 670/0 over seeds 1–20 (plan median
1.2 s, worst 3.1 s), `r10_span_test` 485/0, `area_plan_test` 266/0, box art
seeds 1–8 all pass. Not re-run: the frame gate, the camp's view. Two test
rules changed: a gallery bay is checked against the tiers with the frontage
tool's own samples (the links' wider test nicked one facade corner by under
0.1 m), and a level run between its start and a pier up to 4.5 m away
counts as carried (the lintel rule the links already build to).

**Pictures:** `previews/p6_step4/walk2/` (your four views and five more,
`_before` and `_after`) and `previews/p6_step4/seed433536861/` re-taken.

### Walk 1 (2026-10-26, seed 433536861): what you reported and what changed

Your seed now lays out a different network (the table of possible spans
changed), so the reported spots aren't all there to re-take. Pictures of the
new one: `previews/p6_step4/seed433536861/`.

| Reports | What you saw | Cause and fix |
|---|---|---|
| 2, 4, 5, 6, 7, 9, 11, 12, 13, 14 | stairs not flush with the walk, "extra geometry" or missing faces at stair heads, z-fighting along wall bases, newels floating over a thin stone plane | one fault: the stonework made to measure (walk slabs and their faience course) was built **inside out**. From above you saw its underside 0.45 m down and its far edges through the top. Turned the right way; re-taken, the stair heads are flush, the wall bases clean, the newels and plinths solid |
| 10 | a wall blocking most of the path | the **blank mass round the Overlook** (the vista's, baked with the gorge) juts 4–8 m out of the left cliff; the gallery slots and spans knew the tiers but not it, so a stair ran hard against it and a gallery's end into it. Slots and spans now keep clear of it (a stair by 1.5 m more than its width): five bank 1 slots lost their 3 bays nearest it |
| 1 | why straight pillars instead of continuing the arches? | a span's level part stood on 12 m arcade bays, the odd metres at its start on corbels and straight piers. Now **arcades stretched to fit the whole level part** (6 m and over); 4.5 m or less is a lintel between its ends, no pier; between, one pier |
| 3, 8 | a support not needed; two pillars could go, one under the thick part instead | a stair's flight without arcades stood on a pier under every 4 m bay. Now **one pier under the middle of each flight's mass**; the landing between two flights is carried by theirs |

Also: with spans needing fewer piers, 6,224 spans stand (was 4,909), and a
seed whose cheapest main span led to a dead-end gallery (seed 15) planned
only one; a try that comes up short now rules its main span out for the
next tries (planning median 1.0 s).

### Try it

Esc → **Walk the Gorge**, down the stair to the Overlook's ledge, and across
the main span as before. It now ends on a **gallery against bank 2's cliff**,
and from there the network goes on: 4 to 6 galleries in all, on both cliffs,
joined by **spans across** the gorge and **stairs along the cliffs**, with
one way to each gallery (no loops). Esc → **Reseed the Gorge** for another.
The narrows, the far hall and the sanctum stay scenery.

- **Galleries** (the brief's ledges): on piers where they stand cleanly, else
  on stone consoles into the cliff; 2–5 bays along a tier's face, one bay
  deep, stone floor, a balustrade along the front and across both ends
  (square newels at every joint, lamp posts on some). The face behind is
  theirs: windows with a wall lamp, tiled panels or plain stone. Some sit
  under the tier above's deck, as a covered gallery (2.6 m clear).
- **Spans across**: the step 3 look (aqueduct arcades, stretched to fit a
  level part; piers into the mist or onto a terrace, one under each flight
  where arcades don't fit; waterfalls from spouts, lamps), level or with a
  flight and a landing per storey. **Stairs along the cliffs**: flights beside the
  face from one gallery to the next storey's.
- Where a span meets a gallery at a slant, a **landing cut to fit** takes up
  the angle (up to 30°), with its own balustrades.

**Look at** `previews/p6_step4/`:

- `seed2/`, `seed5/` and `seed433536861/` (the seed you walked, as it now
  lays out): `gorge_concept` (the box-art view), `gorge_net_air`
  (the whole network from the air), per span `gorge_net_<span>` (along it)
  and `_side`, per gallery `gorge_net_<ledge>` (along it), `_out` (across
  the gorge from it), `_face` (from the air in front: the consoles) and
  `_under`; and the Overlook's views as before.
- `box_art/seed1..8_concept.png`: the balcony's view for eight seeds.
- `camp_concept.png`: the camp's own view, unchanged.

### Things that differ from the brief (your call)

| What | Why | If you'd rather |
|---|---|---|
| **Galleries stand on piers where they stand cleanly** (under a corbel, as the Overlook's ledge: in the mist or well on a terrace), and **where none does, on stepped stone consoles** into the cliff (corbel courses, each a step shallower) at that bay's joints. Your choice before walking (2026-10-26): 64% of bays are on piers, 31 of 91 galleries over seeds 1–20 entirely | a pier 2 m out from the face often lands on a terrace's edge below | consoles only, or piers only (fewer slots) |
| **The main span ends on a gallery** against bank 2 (level, or up to three storeys up or down), not on step 3's free-standing head | the brief let the head become a bank 2 gallery; the head stood so close to bank 2 that nothing could join it | — |
| **The low mist glows brighter** in the Gorge area (1.8 times; the camp's is as it was) | the network's spans stand in front of the mist in the balcony's view; without it the box art's mist floor fell to 0.58–0.63 (limit 0.75). The box art's mist is brighter than ours even with no spans, so this is toward it | fewer spans across in that view instead |
| **Facade bays are cleared** where the network stands (behind and under each gallery, where a stair runs along a face, round piers) and terrace dressing where a pier lands | the scenery is baked once; the network changes by seed | — |
| **No loggias** (the brief's "ledges and loggias") | they'd need new kit pieces; the galleries under a tier's deck read as covered | a loggia bay kit piece in a later pass |
| The networks are **alike from seed to seed**: the main span to bank 2, a span back to bank 1's long face, a stair, another span | the near cliffs have few faces with room for a gallery (25 slots); bank 4's can't be reached in most seeds | more frontage (lower storeys, the north faces of banks 3–4) |

### Checks

Re-run 2026-10-26 after walk 1's fixes: the network test (660 checks,
seeds 1–20), the box art (8 seeds), `r10_span_test` and `area_plan_test`
pass as below; the pictures are re-taken. The frame gate, the camp's box
art and the in-view numbers below are from before walk 1 (the scenery and
camp are unchanged).

- **Network test** (new, `tests/gorge_network_test.gd`), seeds 1–20: **660
  checks, all pass**. Each seed plans clean as a tree from the Overlook
  with 4–6 galleries (4 in 10 seeds, 5 in 8, 6 in 2) on both cliffs; no two
  rooms overlap; no walk inside the tiers or near the backdrop's masses;
  every bay carried (arcade, pier, corbel or consoles; a flight by its pier,
  a landing by its flights', a short level part by its ends); the scenery
  cleared where the network stands; the real capsule walks every span and
  stair from the room before to the room after and every gallery end to end
  without catching; nowhere to step off.
- **Box art from the balcony**, seeds 1–8: all pass (mist floor 0.84–0.89,
  far depth 0.81–1.00, near flanks 1.12). **The camp**: passes as before
  (1.07, 0.90).
- **In view** (1600 × 900): 2.6–2.9 M triangles (budget 3 M), draw calls
  338–1,019, GPU 3.1–4.5 ms.
- **The frame gate now walks the Gorge** (`area_walk_capture --area=gorge`,
  seed 2: the balcony, the stair, every span and gallery and back, 723 m,
  Medium, 1080p): draw calls up to 1,257 (limit 1,500), lights in reach up
  to 32 (50), no shadowed lights over the limit. It **fails the library's
  GPU and CPU limits** (GPU mean 3.79 ms, limit 3; worst 9.1, limit 4; CPU
  worst 9.7, limit 8) and its all-passes triangle count (24.6 M). The
  costliest stretch is the Overlook itself (GPU mean 4.1 ms), which the
  network hardly changes; the galleries and spans run 3.6–3.8 ms. The gorge
  scenery sets the cost: gorge limits and stand-ins are steps 5–6 (design
  §5.7.8).
- `r10_span_test` 485 (updated: the main span is now the network's first
  span), `gorge_route_test` 8, `area_plan_test` 266: pass. 240-frame runs
  clean for the camp and the Gorge.
- Planning a seed takes 0.2–2.7 s (median 1.0 s), under the loading panel.

### Built

| Piece | File |
|---|---|
| Frontage slots: where galleries may stand (25, banks 1–4) | `tools/gorge_frontage.gd` → `gen/gorge/frontage.tres`; `scripts/gen/frontage_slot.gd`, `scripts/gen/gorge_frontage.gd` |
| Galleries on consoles | `scripts/gen/cliff_ledge_grammar.gd`, `gen/grammars/cliff_ledge.tres` |
| Spans between two given ends, made-to-measure stonework (slabs, landings, balustrades) | `scripts/gen/chasm_link.gd`, `scripts/gen/chasm_masonry.gd`; `scripts/gen/chasm_grammar.gd` (shared parts) |
| Every possible span solved once ahead (6,224) | `tools/gorge_links.gd` → `gen/gorge/links.res`; `scripts/gen/gorge_links.gd` |
| What the slots and spans keep clear of besides the tiers: the baked backdrop's masses | `scripts/gen/gorge_backdrop.gd` |
| The network planner (trees grown from the Overlook) | `scripts/world/area_network.gd`, `scripts/world/gorge_network.gd`, `scripts/world/area_planner.gd` |
| Scenery cleared where the network stands; the mist's glow | `scripts/world/gorge_scenery.gd`, `scripts/world/area.gd` |
| Every room sees every other in the Gorge | `scripts/world/area_plan.gd`, `scripts/world/area_recipe.gd`; `gen/recipes/gorge.tres` (version 3) |
| Faster tier lookups | `scripts/gen/gorge_grammar.gd` |
| The Gorge's walking route; network views | `tests/gorge_tour.gd`, `tests/area_tour.gd`, `tests/gorge_capture.gd` |

### Caveats

- **Your saved game in the Gorge** is from recipe version 1; the rooms moved,
  so its changes there go stale (a notice when the area loads).
- After editing `frontage.tres` or the Overlook, re-run
  `tools/gorge_frontage.gd` and `tools/gorge_links.gd` (about 10 minutes).
- Made balusters (on spans' level runs, landings, gallery ends) are drawn
  by code to the kit's profile; up close they may shade a shade paler than
  the kit's.
- Not run: the full test gates (an hour), the persistence gate.

---

## Step 3: a span across the gorge (built 2026-10-25; walked four times, 18 reports fixed; you approved it; committed b65d383)

### Your fourth walk: three reports (2026-10-25)

**Look at:** `previews/p6_step3/reports/report_<16..18>_before.png` and
`_after.png`, and `report_17_lintel.png` (the ledge from below).

| # | You said | Now |
|---|---|---|
| 16 | z-fighting on the window frames' outer sides (brick and tile) | the faience panel's outer edges lay flush with the stone border's outer faces: the panel now stops 8 cm inside the border, so only the border shows there (windows, balconies, book windows) |
| 17 | what happened to the disconnected supports here? | since your last walk the ledge's piers stop where they stand cleanly; one bay straddles bank 1's terrace edge, so it had none and its corbel hung in the air. It's now carried by a brick lintel between its neighbours' piers, as deep as the corbels. The last bay's pier stands on the terrace below (1.7 m) |
| 18 | the facade's tiling looks incomplete: tile only in the circles and niches, brick for the rest of the pishtaq | the pishtaq (its arch, piers, tympanum, top band, frame bands, string courses, merlons) is brick; tile only in the two roundels and the four niches. Gorge area only; the camp's entrance is as it was |

**Checks:** box art passes for the Overlook on three seeds (near flanks
1.12, mist floor 0.76–0.77) and the camp (1.07, 0.90). Triangles in view
2.72–2.80 M (budget 3 M), draw calls 628–861, GPU 3.8–5.3 ms.
`r10_span_test` 485, `gorge_route_test` 8, `kit_test` 3,036 pass; 240-frame
runs clean.

### Your third walk: five reports (2026-10-25)

**Look at:** `previews/p6_step3/reports/report_<11..15>_before.png` and
`_after.png` (and `report_6..10_after.png`, re-taken with everything below).

| # | You said | Now |
|---|---|---|
| 11 | z-fighting under every window's arch | the faience panel's opening followed the arch ring's inner edge, so under the arch the two faces lay on each other: the panel's opening now follows the ring's outer edge |
| 12 | leave the patio doors closed | a pair of glazed doors, shut: wood below, lamplit glass behind wooden bars above, the fanlight lit over them |
| 13 | the bookshelves are too close to the window | the book window's frame now stands 0.35 m further out, so the stack is 0.9 m back from its glazing bars |
| 14 | not all windows need to be lit | about a quarter of the gorge's windows are dark, a third dim and the rest fully lit (the doorways' and towers' too), by place; the average is near what it was, so the gorge's light holds |
| 15 | the facade round the entrance is repetitive and flat | the loggia's iwan has a mosaic frame (an alfiz) round it, two blind niches (sandstone frames, mosaic panels) and two string courses up each pier, a mosaic roundel in each spandrel and merlons along its top; the cliff's facades either side now come a bay closer, so the flat strips beside it are 4 m wide. In the Gorge area only |

**The lighter pieces** (from last time) are built: no faces against the wall,
arches in 6 segments, no brackets under the book windows. Triangles in view
went from 2.84–3.01 M to **2.63–2.80 M** (budget 3 M).

**Checks:** the box art passes for the Overlook on three seeds (near flanks
1.12, mist floor 0.76–0.77) and the camp (1.07, 0.90). `r10_span_test` 485,
`gorge_route_test` 8, `kit_test` 3,036, `area_plan_test` 266 pass; 240-frame
runs clean. Draw calls 503–858, GPU 3.6–5.1 ms.

**Found on the way:** a camp capture once came out dark: a camp event's
dialog ("The reading garden") had opened over the view. Re-taken, the camp
passes as before; the capture can catch such a dialog.

### Your second walk: two reports, and the windows redesigned (2026-10-25)

**Look at:** `previews/p6_step3/reports/report_<9,10>_before.png` and
`_after.png`, and `report_6_after.png` / `report_7_after.png` again (the new
windows, balconies and stacks).

| # | You said | Now |
|---|---|---|
| 9 | the supports here clip into the geometry below | the Overlook ledge's piers went straight down into the mist, through bank 1's terraces: they now stop where they stand cleanly, as the span's do (in the mist, or well on one terrace clear of its edge and dressing). One bay, between two piered bays 8 m apart, found no clean place and has none |
| 10 | the whole thing on the left is unsupported | the landing and the rock-cut stair are masonry cut down to 20 m under the balcony, and stopped there in the air: a broad pier now carries the landing, and another the stair's middle, down to the mist |

**The windows, as you asked** (you weren't sure about the window balconies
and the stacks on balconies, since nothing showed how anyone used them):

- **Windows**, no balcony, in a nicer frame: the pointed opening in a
  rectangular frame with faience spandrels (an alfiz), a stone border and
  arch ring, a sill on two brackets and a hood over it; the lit opening set
  back in the ring, a wooden mullion and transom across it.
- **Balconies with a patio door**: the same frame round a tall door, its two
  wooden leaves standing open onto the balcony, the room behind lit, a
  fanlight over them; the balcony on two brackets, balusters round its open
  sides, a gold rail.
- **Books behind a window**, for every stack with no terrace in front of it
  (the reading balconies are gone): the window's frame, the opening set
  0.55 m deep, the stack at the back of it, light glazing bars at the front.
  Stacks on a terrace keep their ladders.

To keep the triangle count in budget, none of these pieces has faces
against the wall (they're never seen).

### Your walk: eight reports (2026-10-25)

You found the span good in general, and reported eight other things.

**Look at:** `previews/p6_step3/reports/report_<1..8>_before.png` (your
screenshot) and `_after.png` (the same spot, re-taken), and
`report_4_span_end.png` (the chain's last bays from the side).

| # | You said | What it was | Now |
|---|---|---|---|
| 1, 2 | buildings at the top have see-through floors | the tiers were shells: where one overhangs the one below, nothing closed its underside | a stone **soffit** under every bay of a tier that overhangs the one below (new kit piece `gorge_soffit`); a lower tier's deck edge (balustrade, lamps, figures) no longer runs on under the tier above, into its soffit |
| 3 | a gap near the base of the building | a terrace's deck bay was left out when its centre was under the tier above, but the tiers sit on different grids, so a strip at the foot of the wall stayed open | a deck goes wherever any of its bay is open |
| 4 | the stairs aren't supported by anything | near bank 2 the chain's arcades would have run into its terraces and no pier could stand cleanly, so the flights had nothing under them | every bay is carried: by its arcade (standing on a pier at one end at least) or by a pier of its own, found along the bay; if a row can't be carried, the head moves a bay back. The span test checks it for every seed |
| 5 | water appears out of mid-air | the falls started at the arch's spring line, in the middle of the opening | each fall pours from a faience **spout** under the arch's crown, 3.2 m wide (it fits the arch); one arcade bay in three pours |
| 6 | the half-closed windows look strange: remove the shade, make the bars meet the sides and ledges | the lit card was narrower than its arch (a half-drawn shade), its bars painted on and stopping short | window and balcony bays (kit rev 4 and 5): the arch's whole opening is lit, from the sill to the crown, with wooden **bars** in front, a mullion from the sill to the crown and two transoms from side to side. Every window in the gorge changed |
| 7 | remove or replace bookshelves you can't reach | stacks stood on sheer walls, on upper storeys or over a drop | a stack with nothing to stand on in front (no terrace under it) now stands on a **reading balcony** (new kit piece `gorge_bay_stack_gallery`: balcony, balusters, rail); stacks on a terrace keep their ladders |
| 8 | this side of the cavern looks plain | the cliff round the balcony was only ever behind you: rough rock with seven small windows | in the Gorge area, **storeys of the banks' bays and galleries** are set into the cliff either side of the loggia (7 bays wide, 10 storeys) and over its iwan (2 storeys), with balustraded galleries every two storeys, merlons on top, lamps and banners; the rock round them is dressed flat. The camp's cliff is as it was |

**The box art** passes for the Overlook on three seeds (a bridge, two
chains): vault 49, focal glow 126, far depth 88, near flanks 79 (1.13),
**mist floor 81–82 (0.76; limit 0.75)**. It was 0.77–0.78: the overhangs'
deck edges that are gone carried lamps, and the cluster lights that come from
them. The camp: near flanks 1.07, mist floor 0.90, unchanged.

**The cost:** in view 2.73–2.90 M triangles (budget 3 M; it was about 2.5 M),
draw calls 457–809, GPU 3.6–4.6 ms (it was 3.0–4.4). The reading balconies
are thousands of pieces; the first try (a ladder on each, more balusters) was
1.5 M triangles across the gorge, now 0.55 M, and far ones draw at lower
detail. The new windows' bars and glows, the soffits and the cliff's
facades account for the rest.

**Checks:** `r10_span_test` 485 (new: every bay carried), `gorge_route_test`
8, `kit_test` 3,028, `area_plan_test` 266 pass; 240-frame runs clean for the
camp and the Gorge.

**Also changed:**

| Piece | File |
|---|---|
| 3 kit pieces (soffit, stack on a reading balcony, and its near version), window and balcony bays rebuilt | `tools/kit_add_gorge.py`, `art_src/kit/kit_gorge.blend`, `kit/materials/gorge_window_glow.tres` |
| Soffits, decks, deck edges, reading balconies; the cliff's facades | `scripts/gen/gorge_grammar.gd` (`_tier`, `_facade`, `cliff`) |
| The cliff's facades' places, the rock dressed flat round them | `scripts/vista_cliff.gd` (`FACADES`) |
| The cliff part of the bake | `tools/bake_gorge.gd` → `rooms/baked/gorge/cliff.scn` |
| Every bay carried; falls from spouts | `scripts/gen/chasm_grammar.gd`, `gen/grammars/r10_chasm.tres` |
| A view of the span's last bays from the side | `tests/gorge_capture.gd` (`span_end`) |

**Still to know:**

- **The mist floor is at 0.76** of the box art (limit 0.75). The next change
  that darkens the low middle of the balcony's view could fail it; the lever
  is a little more light low in the gorge.
- **Triangles in view are near the budget** (2.9 M of 3 M).
- The lit windows are now a flat warm colour (the old card's painted texture
  is gone with the shade); a gentle gradient is possible if they read flat.

### As built

**Try it:** Esc → **Walk the Gorge**. Go down to the ledge as before. Where
the ledge turns west, its corner now opens on the gorge side, and the span
leaves from there, about 72 m across toward bank 2. It ends at a **far ledge**
(the head): a row of 2 to 4 bays across the span's end, standing in front of
bank 2's terraces. Esc → **Reseed the Gorge** gives another span. The seed
picks one of two kinds:

- **A bridge** (about half the seeds): level all the way, on the old near
  aqueduct's two tiers of round arches.
- **A chain** (the other half): level at first, then in its last bays toward
  bank 2 a flight and a landing per storey, down 1 to 3 storeys to a lower
  head. The flights are the Overlook's, set on the same arcades.

Both have balustrades down both sides of every bay and round the head
(stone plinth, turned balusters, gold rail, as on the Overlook), a square
newel at every joint, a lamp post on a newel every third bay (alternating
sides) and at the head's two front corners, and stone paving with the
aqueduct's faience course under its edge. One or more upper arches pour a
waterfall. Under the head and the first bays, square piers go down into the
mist, or onto one of bank 2's terraces where they stand cleanly.

**The old near aqueduct is gone from the Gorge area** (your Q9): the span
takes its place, on nearly its line but about 12 m nearer the balcony and
7–14 m higher (a chain's head at about its height). The cascade
that poured off its east end went with it. The camp still shows its own
gorge, aqueduct and all.

**Look at:** `previews/p6_step3/bridge/` (area seed 2, a bridge) and
`previews/p6_step3/chain/` (area seed 9, a chain three storeys down), each:

- `gorge_concept`: the box-art view from the balcony; the span where the
  aqueduct was;
- `gorge_span`: from the ledge's corner, out along the span;
- `gorge_span_mid`: from the middle, on toward the head (the chain's flights);
- `gorge_span_head`: from the head, back toward the Overlook;
- `gorge_span_side`: from the ledge's west end, back along it onto the span;
- `gorge_span_under`: from under the span's start, up along its arcades and
  a waterfall.

And `camp_concept.png`: the camp's own view, unchanged.

**The box art** passes for both kinds. From the Overlook: vault 48, focal
glow 125, far depth 88, near flanks 82 (1.18), **mist floor 83–84 (0.77–0.78
of the box art; the limit is 0.75**; it was 0.83). The span stands nearer and
higher than the aqueduct did, so it covers a little more of the mist. The
camp: near flanks 1.07, mist floor 0.90, as before.

**The cost** (RTX 5090, 1600 × 900): draw calls 434–787 (budget 1,500), GPU
3.0–4.4 ms, about 2.5 M triangles (budget 3 M). The span's ~80 kit pieces are
drawn in batches (`KitBatcher`); its piers and newels are one mesh each.

**Built:**

| Piece | File |
|---|---|
| 2 kit pieces in `kit_chasm.blend`: a span deck bay (paving over the scenery aqueduct's faience course) and the stair flight on a span (its masonry stops on the arcade, the course down both sides) | `tools/kit_add_r10.py`, `art_src/kit/kit_chasm.blend` |
| `ChasmGrammar`, the span from a connector: walks out bay by bay against the gorge's terraces, puts the head as far out as it stands cleanly, lays the run (corbelled bays, then 12 m arcade bays, level or a flight and landing), the head, balustrades, newels, lamps, waterfalls, piers; builds the room | `scripts/gen/chasm_grammar.gd`, `gen/grammars/r10_chasm.tres` |
| The banks' terraces as a keep-out: where they are (with their decks' 2.2 m overhang and balustrades), what's on them (figures, cypresses, pavilions, banners, lamps) | `scripts/gen/gorge_grammar.gd` (`keep_out`, `solid_at`, `ground_at`, `dressing`) |
| A new kind of room in areas, a span: planned from its parent's connector by its grammar, built by it | `scripts/world/area_planner.gd`, `scripts/world/area.gd`, `scripts/world/area_plan.gd` |
| The Overlook's ledge corner opens onto the span (connector `SNAP_exit_span`); the ledge's west end keeps its connector for a door later | `tools/bake_overlook.gd` → `rooms/gorge/overlook.tscn` |
| The near aqueduct and its east cascade left out of the Gorge area's scenery (`GorgeLayout.walked`), rebaked | `scripts/gen/gorge_layout.gd`, `tools/bake_gorge.gd`, `scripts/vista.gd`, `rooms/baked/gorge/` |
| The Gorge's recipe: the span slot, two rooms, an envelope deep enough for the gorge (version 2) | `gen/recipes/gorge.tres` |
| Span views in the capture | `tests/gorge_capture.gd` |

**Found on the way:** `KitBatcher` freed each batched mesh with everything
under it, and a kit piece's collision sits under its mesh, so the batched
span had no floor (the test capsule fell through). It now moves what hangs
under a mesh up to the mesh's parent before freeing it. The gorge's scenery
has no collision, so nothing changed there.

**Tests:**

| Test | What it checks |
|---|---|
| `r10_span_test` (new, 445 checks) | the Gorge plans clean with its span on the Overlook's corner; then 20 seeds of each kind, each solved from the Overlook's connector, built, and checked: of its kind (the chains 1–3 storeys down); bank 2 within two bays behind its head; nothing (walk, arcades, piers) inside the banks' terraces, piers on a terrace clear of its edge; no climb steeper than the kit's stair; the real player's capsule walks from the Overlook's corner over the span to both ends of the head without catching, and finds no way off at both sides of every bay and flight, the head's front, back and ends |
| `gorge_route_test` | 8 checks pass (it skips the corner's open side, which leads onto the span) |
| `kit_test` 2,994, `area_plan_test` 266 | pass |
| 240-frame runs | clean for the camp and `--area=gorge` |

**Caveats:**

- **The head stands off bank 2, not against it.** Bank 2 steps out in
  terraces below the span's height, about 16–20 m in front of its wall at
  that height, and a pier must stand on one terrace clear of its edge and
  its figures and cypresses. So the head goes as far out as its piers stand
  cleanly: about 4 m in front of the nearest terrace's balustrade (8 m below
  it) and about 12 m from the wall at its own height. Step 5's door into
  bank 2 needs a way across that (a short bridge, or the head on the
  terrace). If you'd rather the span reached the wall now, say so.
- **Longer than the brief's bridges.** The brief's bridges are up to 40 m
  (10 bays); bank to bank here is about 80 m, so the span's limit is 24 bays
  (`bridge_max_bays`, a setting in `gen/grammars/r10_chasm.tres`).
- **No ramps.** A head a storey lower is a chain (flights), never a sloped
  deck: the brief's 1-in-8 ramp bays aren't built. Every seed so far is a
  level bridge or a chain.
- **Some arch ends hang in the air** where no pier could stand cleanly (a
  pier only goes where it lands in the mist or well on a terrace), as the
  scenery aqueducts' lower arches did between their piers.
- **The mist floor is near its limit** in the box-art view (0.77, limit
  0.75).
- **The grammar is 516 lines** (the design said under 400): about 140 of
  them build the room (batches, newels, lamps, waterfalls).
- **Not run:** the frame gate (it doesn't walk the gorge yet), the full test
  gates (an hour), the persistence gate.

---

## Step 2: the Overlook, walkable (built 2026-10-25; walked five times with the report key, 46 reports fixed; committed)

### Your fifth walk: two reports (2026-10-25)

**Look at:** `previews/p6_step2/reports5/` (`report_<1,2>_before/after`, and
`loggia_columns.png`, the loggia with its new columns).

| # | You said | Now |
|---|---|---|
| 1 | it still looks like clipped geometry: put the arches' sides back, and the pillars round the balcony's middle in a square, holding up the roof | as you said: the arches stand on their own jambs, and four fluted columns (6.3 m, floor to canopy) stand in a square round the balcony's middle, 5.2 m by 3.4 m; the square columns and the fluted ones by the arches are gone (collision kept where they stood and round the new ones). They're behind you in the box-art view |
| 2 | floating, oddly placed carpets on the railing | gone: the parapet has no flat top for them to lie on (balusters and a coping) |

The camp keeps its balcony as it was. **Checks:** box art passes for the
Overlook (near flanks 1.18, mist floor 0.83) and the camp (1.07, 0.90);
`gorge_route_test` 8 and camp `playtest` 43 pass; 240-frame runs clean.
Draw calls 301–564.

### Your fourth walk: six reports (2026-10-25)

**Look at:** `previews/p6_step2/reports4/report_<1..6>_before.png` and `_after.png`.

| # | You said | Now |
|---|---|---|
| 1 | the balustrade should come all the way down the stair | the stair's balustrades (and their invisible guards) run down to its foot on the landing, a newel there; newels where they cross the landing's edge |
| 2–5 | still two supports: a pillar and the arch's; keep the round pillars | the square columns beside the round fluted ones are gone (only their collision stays); the fluted columns carry the arches |
| 6 | the balconies still need side railings | the banks' balcony bays (kit rev 4) have balusters and a rail down both sides |

**The box art** passes for the Overlook (near flanks 1.18, mist floor 0.83)
and the camp (1.07, 0.90). **Checks:** `gorge_route_test` 8, `kit_test`
2,961, camp `playtest` 43 pass; 240-frame runs clean. Draw calls 307–573,
GPU 2.8–3.9 ms.

### Your third walk: fifteen reports (2026-10-25)

**Look at:** `previews/p6_step2/reports3/report_<1..15>_before.png` and
`_after.png`.

| # | You said | Now |
|---|---|---|
| 1, 2 | z-fighting where the wall meets the cavern | the rock I'd put either side of the sealed door lay in the passage's brick walls' faces: gone (the brick fills the sides) |
| 3 | baluster clipping into the stone pillar | the stair's top moved another 0.5 m east, its west balustrade clear of the iwan's pier |
| 4 | clipping geometry | the balcony's side parapet ended in air beside the stair: a wide newel now caps it and joins it to the stair's balustrade |
| 5 | banner corners sticking out above the wall | the stair's relief panels are level-topped on a slope, so a corner rose above the balustrade: lowered 1 m |
| 6–11 | balusters don't connect cleanly | **square newels** (stone post, limestone cap) wherever balustrades meet or end: the landing's corners and gaps, the flight's top and foot, the ledge's corners |
| 12 | lamps clipping into the balusters | the lamp posts stand on the newels now (they stood mid-bay, in the balusters) |
| 13 | balconies missing a side baluster | the terraces' corner squares (kit rev 3) have rails round both open sides, a corner post and balusters; a run's end that turns away from the gorge gets one too |
| 14 | the carpets' tops look wrong | they lie over the parapet's coping now (it cut through them), clear of the faience blocks |
| 15 | pillars clip the arches' sides: two supports | the loggia's arches spring from the columns, their own jambs gone |

**Also:** the new balustrades and newels are built as a few merged meshes
(one each cost a draw call: the box-art view had gone up to 801; now 573).
**The camp** keeps its stair where the box art had it: moved east with the
walkable one, it covered the mist floor and the camp failed the box art (0.75).

**The box art** from the Overlook passes: vault 48, focal glow 125, far depth
103, near flanks 82 (1.18), mist floor 89 (0.83; the stair covers a little
more of it). The camp: mist floor 0.90, near flanks 1.07, all pass.

**Checks:** `gorge_route_test` 8, `kit_test` 2,961, `validate_room_test` 26,
camp `playtest` 43 pass; 240-frame runs clean. Draw calls 307–573, GPU
2.7–3.5 ms, triangles about 2.4 M (budget 3 M).

### Your second walk: fourteen reports (2026-10-25)

**Look at:** `previews/p6_step2/reports2/report_<a..n>_before.png` (your
screenshot) and `_after.png` (re-taken from the same spot).

| | You said | Now |
|---|---|---|
| a, b | gap and overlapping geometry (the loggia's back corners) | the balcony's side parapets run on to the loggia's back wall, as the floor does |
| c | carpet-textured block floating, in the way | the rug folded over the parapet sat where the parapet now opens onto the stair: gone |
| d | the stair doesn't join the balcony cleanly; a gap and flickering | the stair head is longer (2.2 m), reaching under the balcony's slab all along, its top 1.5 cm under it so the two don't fight |
| e, g, h | the stair's and the flight's rails should be balusters to match | the stair, its head and the flight (kit rev 3) have **balustrades**, as the landing's and the ledge's: stone plinth, turned balusters, gold rail, newels where they turn and end |
| f | a banner corner sticking out, clipping the rails | the relief panel by the landing's corner is gone where the landing's balustrade meets the stair |
| i | the pergola clips the balcony; a sharp piece between the building and the bridge | the aqueduct landings have no pavilion now; the sharp piece was the near aqueduct's cascade, seen edge-on from the ledge's end: gone in the Gorge area |
| j | a gap in the far corner; the lower cavern walls too flat | the cavern's walls reach back past the cliff (no corner gap), and their faces are **rock strata**: between each row of galleries the rock swells out up to 4 m |
| k | the platform under the statue looks unfinished: balusters, a stone floor | the far gate's platform is square, **stone-paved**, with balustrades on its three open sides |
| l | tile is for walls and ceilings; floors should be stone or carpet | every deck, overhang, corner and aqueduct landing (kit rev 2) has a **stone top**, the faience kept on its sides |
| m | keep the tile floor on this balcony, to make it unique | kept |
| n | the upper buildings' tiled walls are too busy | towers in clean stone with faience on the top storey and every third (two new kit pieces); a third of the bays on the banks' upper storeys left as plain stone wall |

**The box art** passes: vault 48, focal glow 125, far depth 105, near flanks
82 (1.17), mist floor 104, warm/cool split 58. The camp as before (mist floor
0.82). Triangles in view about 2.3 M (budget 3 M), draw calls 347–690, GPU
2.7–3.8 ms.

**Checks:** `gorge_route_test` 8, `kit_test` 2,959, `validate_room_test` 26,
camp `playtest` 43 pass; 240-frame runs clean for the camp and the gorge.

**Still to know:** the busy upper walls are only broken up a little (report
n's after picture). If you want more, the next lever is fewer tile panels
and blue piers between bays.

### Your nine reports, and a redesign for walking (2026-10-25)

You walked it with the report key and sent nine reports. You also said the
balcony's fixed view is a direction, not geometry to keep, so the pieces
below are redesigned rather than patched.

**Look at:** `previews/p6_step2/reports/report_<n>_before.png` (your
screenshot) and `report_<n>_after.png` (the same spot and view, re-taken by
`tests/report_capture.gd`), and `gorge_*.png` from the usual views.

| # | You said | What it was | Now |
|---|---|---|---|
| 1, 2 | gap in the floor | the balcony's floor stopped 1.1 m short of the loggia's back wall; in the camp the gallery's floor covers it | the floor runs to the wall |
| 3 | weird geometry, maybe masonry rails | the stair's tiled side walls stood outside the steps, with a dark trench between | **masonry parapets** on the stair's edges, 1 m over the treads, down over the steps' sides, a faience coping; the reliefs on their outer face |
| 4 | gaps between the balcony and the slab, under the slab | a thin slab across the parapet's gap; and the iwan's west pier stood on half the stair, ending in air (you could walk through it) | a **solid head block** from the balcony's floor to the first step; the stair moved 2.3 m east, clear of the pier; the iwan's piers go on down into the rock |
| 5 | lots of gaps in the cavern walls | the cliff under the balcony was a flat block whose edges showed | the cliff's rough rock face goes on down under the balcony |
| 6 | statue platform floating, overlapping | the left colossus's plinth (23 m long) was longer than its rock pier was wide, and overlapped the landing | the colossus **moved 5 m** (4 west, 3 toward you), clear of the landing, the stair and the ledge, on a **masonry pedestal** rising out of the mist, a faience band under its plinth; its rock pier is gone (it reached out to the flight) |
| 7 | clipping; stairs and walls reworked | the flight's thin tiled cheeks, cut square to the slope, poked into the landing and stood apart from everything | the flight (kit piece, rev 2) is **one masonry mass** with masonry parapets, ends square |
| 8 | the pergola clips into the balcony | terrace pavilions stood 1.8 m in from a deck's edge, their front posts in the balustrade (and an aqueduct landing's pavilion overhung its landing) | 2.2 m in, posts clear; the landing's pavilion centred |
| 9 | more gaps on the far side | the far colossus's gate landing hung in air; the cliff's edges as in 5 | stepped corbels carry the landing back into the rock |

**Also changed for it:** the ledge goes one bay further down the stair's
line before turning west, clear of the colossus's pedestal, and stands on
piers down into the mist, balustrades on both sides. The sealed door now
fills the loggia's passage at its back wall. The balcony's opening onto the
stair is now worked out from the stair head's corner, so the two can't
drift apart.

**The box art** from the spawn passes with more margin: vault 49, focal glow
125, far depth 105, near flanks 83 (1.19, was 1.25), mist floor 104, warm/cool
split 60. **The camp** (it shares the colossi and the gate) passes too, with
its mist floor at 0.82 (was 0.89, limit 0.75). The stair's east parapet now
starts in the lower-left foreground of the box-art view, where the stair
head meets the balcony.

**Checks:** `gorge_route_test` 8 checks. It now probes every open side of
every ledge bay and both sides of the stair head, and finds no way off.
`kit_test` 2,923, `validate_room_test` 26, `report_test` 15, camp
`playtest` 43 pass; 240-frame runs clean for the camp and the gorge. Draw
calls 325–655 (budget 1,500), GPU 2.6–3.8 ms.

**Not looked at yet:** a fresh sweep of the whole walk; your next walk with
the report key will find what's left.

### The report key, and the landing paved (2026-10-25)

**The ` key (backquote, under Esc) reports what you see.** Wherever something's wrong, press it: it keeps
a screenshot of the frame as you saw it, then a pop-up asks for an optional
note (Enter saves, Esc cancels). It works anywhere in the game, for anything,
not just gaps. Each report is one line in `reports/reports.jsonl` in the
project folder (git-ignored), next to its screenshot. It records:

- where you stood and looked (feet, eye, yaw, pitch, field of view, the
  camera's whole transform);
- what the centre of the screen hits, and how far away;
- the scene, the area's seed and the room you're in;
- the window size and graphics preset;
- your note.

It was F9 at first; run from the editor, F9 paused the game in the
editor's debugger (the function keys are its), so it moved to `.

Then tell me "look at my reports". `tests/report_capture.gd` stands the
camera where you stood and re-takes each view, so after a fix I can show the
same picture before and after. Also listed under Esc → Controls & settings.

| Piece | File |
|---|---|
| The report key and pop-up | `scripts/report_tool.gd`, `scripts/main.gd` |
| Re-taking reported views | `tests/report_capture.gd` |
| The test: ` opens it and stops you, Esc cancels and writes nothing (and doesn't open the menu), Enter writes one line with all of the above and a screenshot taken before the pop-up showed | `tests/report_test.gd` (15 checks) |

**The landing is paved** as the ledges are (`gorge_landing`), the faience
now a band under the paving's edge. The faience's big tiles read as pixels
up close.

**Found on the way: you couldn't get to the ledge.** Anywhere below 8 m
under the camp's floor the game put you back at the spawn. That's the
landing's own height, and the ledge is 4 m lower. Each area now has its
own fall height (`AreaRecipe.fall_limit`); the Gorge's is -50 m, above its
safety floor. The route test now checks it (8 checks), since its capsule
isn't the game's player and so it hadn't noticed.

**Checks:** `report_test` 15, `gorge_route_test` 8, camp `playtest` 43 pass;
240-frame runs clean for the camp, the gorge and the Lower Stacks. Box art
from the spawn as before (near flanks 1.25, at the limit).

### After your walk (2026-10-25)

You found faces missing and gaps that only show now you can walk past
things built to be seen from the balcony, and books lining the cavern walls,
as if they held the gorge up.

**Looked at** (pictures since replaced by the redesign below): at six stops on the walk (the
stair, the landing, the flight, the ledge's corner, its middle and its end),
eight directions and one straight over the edge.

**Changed:**

| What you saw | Now | File |
|---|---|---|
| Books on the cavern's outer walls, on the cliff under the balcony, on the gorge floor and on the aqueducts' piers down into the mist | The cavern's rock, as the vault is. The camp's gorge too (its box-art numbers didn't move) | `scripts/vista.gd` (`gorge_background`), `kit/materials/gorge_background.tres` |
| Sky through a gap behind the stair: the cliff face's foot bulged 4 m out past the cliff block under it | The face's foot meets the block | `scripts/vista_cliff.gd` |
| The stair's side walls, one block per step with air between them | One sloped wall a side | `scripts/vista_foreground.gd` |
| The landing's corners notched, leaving the balustrade's corners over air | A square landing | `scripts/vista_foreground.gd` |
| The ledge's balustrade ran into the colossus's rock pier and stopped mid-baluster | Toward the pier, a rock face cut back into it, as high as its top (5 bays); balustrades only on the open side | `tools/bake_overlook.gd` |

All but the first change are only in the Gorge area (the camp still shows
its gorge from vista.gd until step 6); the first is in the camp too.

**Also new:** `tests/gorge_capture.gd -- <dir> sweep` takes those walk
pictures, so the next steps can look for gaps the same way.
`tools/gorge_materials.gd -- --force --only=<name>` copies a single material
again without overwriting your others.

**Checks:** the route test passes (7 checks; it still finds no way off). The
box art from the spawn: vault 50, focal glow 126, far depth 104, **near
flanks 87 (1.25 of the box art, right at the limit)**, mist floor 105, warm/cool
split 69, all pass. The camp unchanged (near flanks 1.15). `kit_test` 2,921,
`validate_room_test` 26, camp `playtest` 43 pass; 240-frame runs clean for
the camp and the gorge. Draw calls 283–520, GPU 2.8–3.6 ms.

**Still to know:**

- **Near flanks are at the limit.** The rock is a little lighter than the
  books were. If a later step pushes it over, the rock's tint comes down.
- **The landing's top is the faience tile at the view's scale:** up close its
  pixels are big, about 25 cm. It could take the ledge's paving instead, if
  you'd like.
- The colossus's pier reads as a dark rounded mass beside the landing (it's
  the rock, unlit there).

### As first built

**Try it:** Esc → **Walk the Gorge**. You start on the balcony. Its parapet
is open at the front-left corner: step through onto the rock-cut stair, past
the lamassu, down to the tiled landing. From the landing's far side a
flight goes down one more storey to a paved ledge. The ledge runs round the
left colossus's rock pier, with a balustrade and lamp posts, and ends facing
bank 1. Step 3's span starts there. Behind you on the balcony, the passage
back toward the camp is closed by a sealed bronze door (step 6 opens it).

**Look at:** `previews/p6_step2/`:

- `gorge_concept`: the box-art view from the spawn (the parapet's opening is
  to the left, out of frame);
- `gorge_stair`: from the balcony, looking down along the stair;
- `gorge_landing`: on the landing;
- `gorge_ledge`: along the ledge, under the rock pier;
- `gorge_up`: from the landing, looking back up the stair at the loggia.

**The box art** from the spawn is unchanged from step 1: vault 50, focal
glow 126, far depth 104, near flanks 86 (1.23; limit 1.25), mist floor 105,
warm/cool split 66. All checks pass.

**The cost** (RTX 5090, 1600 × 900): 280–499 draw calls (budget 1,500),
about 2.1 M triangles (budget 3 M), GPU 2.5–3.9 ms. The worst is the spawn's
view, as in step 1.

**Built:**

| Piece | File |
|---|---|
| 4 kit pieces by script into a new `kit_chasm.blend` (yours to edit from now on): a 4 m balustrade with a 2 m invisible guard, a 4 m ledge on a stepped corbel, a stair flight one storey down over 8 m, a lamp post with a lantern | `tools/kit_add_r10.py`, `art_src/kit/kit_chasm.blend` |
| The Overlook room: the spawn, a slab over the parapet's opening, the stair and the landing made walkable (an invisible ramp over the steps, guards along both sides), balustrades round the landing, the flight, six ledge bays with balustrades and lamps, a connector at the ledge's end, the sealed door, a safety floor far below | `tools/bake_overlook.gd` → `rooms/gorge/overlook.tscn` (yours to finish by hand; re-running overwrites it) |
| The balcony's front parapet opened at its left corner (only in the baked gorge; the camp's balcony is unchanged) | `scripts/vista.gd` (`walkable_overlook`), `tools/bake_gorge.gd` |
| Rooms can be marked off the 4 m grid (the Overlook follows the stair's diagonal), so the room check skips its grid-only checks for them | `scripts/world/room_template.gd` (`off_grid`), `scripts/world/kit_validate_room.gd` |
| The route test: the player's capsule walks from the spawn to the ledge's end without catching on anything, and finds no way off at 14 places (the parapet, both sides of the stair, the landing, the flight, every ledge bay, the ledge's end) | `tests/gorge_route_test.gd` |
| More capture views (stair, landing, ledge, up) | `tests/gorge_capture.gd` |

**Tests:** `gorge_route_test` 7 checks, `kit_test` 2,921, `validate_room_test`
26, `area_plan_test` 266, camp `playtest` 43: all pass. 240-frame runs clean
for the camp and `--area=gorge`.

**Caveats:**

- **The stair is a ramp** under its steps (about 19°), so you glide down it
  rather than step. The steps are vista.gd's, 0.73 m each, too tall to climb
  one by one.
- **The landing's balustrades read dark** (`gorge_landing`): no lamp lights
  them. The ledge's are lit by their own lamp posts. A lamp or two on the
  landing would fix it, if you want them.
- **The ledge is a first pass at the near-gorge network** (step 4 adds 4–6
  ledges). It ends at a balustrade for now. Step 3's span opens it.
- **Not run:** the frame gate's walk of the gorge (the gate walks only
  generated areas so far). The numbers above are from the capture views.

---

## Step 1: the gorge from kit pieces (built 2026-10-25; you approved its look; committed 4bce7c1)

**Try it:** Esc → **Walk the Gorge** (or `-- --area=gorge`). You stand on the
balcony and look out over the whole gorge, now built from kit pieces and
baked. View only, as before (step 2 makes the balcony and the stair walkable).

**What it is:** every bank (with its Persian towers, 11 of them), the six
aqueducts and the sanctum's nine tiers, laid out by `GorgeGrammar` from
today's numbers (`gen/gorge/gorge_layout.tres`) in 45 kit pieces: 61,274
pieces in all. What isn't architecture stays generated by its own code,
**once, at the bake**: the cavern (vault, stalactites, throats, rock gates),
the mist, the cascades and the waterfalls through the aqueducts, the far
enclosure, the rock-cut stair and lamassu, the cliff and loggia, the
balcony, bank 4's rotunda and the sanctum's rotunda, portal and columns, and
the lights (the lamp clusters now from the kit's 3,448 lamps).

**Your scene to edit** (`tools/bake_gorge.gd` writes them; re-baking
overwrites):

| File | What |
|---|---|
| `rooms/baked/gorge/bank_1.scn` … `bank_8.scn`, `sanctum.scn`, `aqueducts.scn` | the kit pieces, each its own instance; open one, move, swap or delete pieces |
| `rooms/baked/gorge/generated.scn` | the generated parts, merged by material as the camp merges them |
| `rooms/baked/gorge/kit_batched.scn` | the parts drawn in 64 batches: what the area loads. After editing a part, run `godot --headless --path . --script res://tools/bake_gorge.gd -- --rebatch` |
| `rooms/baked/gorge/environment.tres` | the camp's environment (fog, glow, grade), copied |
| `rooms/baked/gorge.tscn` | the area's scenery: all of the above and the balcony's spawn |

**The look** (`previews/p6_gorge/`: `gorge_*` from the area, `camp_concept`
today's from the camp): the box-art comparison passes, as it does today:

| Region | Box art | Today (camp) | Rebuilt (area) |
|---|---|---|---|
| vault | 49 | 45 | 50 |
| focal glow | 144 | 118 | 126 |
| far depth band | 91 | 94 | 105 |
| near flanks | 70 | 80 | 86 (1.23 of the box art; limit 1.25) |
| mist floor | 108 | 96 | 105 |
| warm/cool split | 58 | 61 | 66 |

**The cost** (RTX 5090, 1600 × 900, project settings): the area loads in
251 ms; the box-art view draws 427 draw calls (budget 1,500; the camp's view
of today's gorge 543), 2.07 M triangles (budget 3 M), GPU 3.9 ms.

**Built:**

| Piece | File |
|---|---|
| 12 more kit pieces: the Persian tower's walls, window bays, bands, crown and corner, the carpet, the aqueduct's upper and lower arcades, pier, deck and landing, the sanctum's faience wall | `tools/kit_add_gorge.py`, `art_src/kit/kit_gorge.blend` |
| `GorgeGrammar`: towers (the sightline rule kept), the sanctum's tiers, aqueducts (12 m bays along each, the deck in sloped pieces, lamps and readers, landings, pavilions), `gorge()` for the whole layout | `scripts/gen/gorge_grammar.gd`, `scripts/gen/gorge_layout.gd`, `gen/gorge/gorge_layout.tres` |
| `KitBatcher`: repeated pieces as one MultiMesh each (identical meshes from different pieces share one; lit windows varied as today); keeps the transforms as data, so a headless bake can save them | `scripts/world/kit_batcher.gd` |
| The bake | `tools/bake_gorge.gd` |
| The Gorge area: `AreaRecipe.scenery` (a scene the area adds once, not planned or streamed); the recipe; Esc → Walk the Gorge | `scripts/world/area_recipe.gd`, `scripts/world/area.gd`, `gen/recipes/gorge.tres`, `rooms/gorge/overlook.tscn`, `scripts/main.gd` |
| The old code can run with its architecture switched off (`skip_banks`, `skip_bridges`, `skip_sanctum_tiers`, `extra_lamps`), and `world.gd` lends its helpers without building the camp (`scenery_only`); both only for the bake and the preview | `scripts/vista.gd`, `scripts/world.gd` |
| The gorge's glows, decals and cloth cast no shadow (as today's windows) | `tools/kit_import.gd` |
| GPU capture of the area | `tests/gorge_capture.gd` |

**Found on the way:**

- **A saved scene doesn't keep changes to its instances' insides**, so the
  pieces lost the gorge's light layer (2) in the bake and showed cold and
  dark, out of reach of the lamp clusters and the vault's bounce light.
  `KitBatcher.render_layers` sets the batches' layer instead.
- **Loading 61,000 pieces took 25 s**; the bake now saves the batched result
  and the area loads that (251 ms). The part scenes stay the source.
- **The headless renderer keeps no MultiMesh data**, so a headless bake
  saved empty batches; `KitBatcher` keeps the transforms itself.

**Tests:** `kit_test` 2,867 (scenery pieces now exempt from needing
collision), camp `playtest` 43, `area_plan_test` 266, `stream_test` 80,
`persist_gate.sh` all nine pass; 240-frame runs clean for the camp and
`--area=gorge`.

**Caveats:**

- **The camp still shows its own gorge** from `vista.gd` until step 6, when
  it switches to the baked one. Edits to the baked gorge show in the Gorge
  area only until then.
- One fewer face light than today (114 of 121: tiers are whole bays, so a few
  faces moved) and one more tower (11; one now clears the gate sightline).
- `near flanks` are at 1.23 of the box art (limit 1.25): a little brighter
  than the camp's 1.15.
- The frame gate can't walk the gorge yet (there's nowhere to walk); its
  numbers come with step 2.
- **GPU time is near the gate's limit** from the balcony: 3.9 ms at Medium,
  1080p (the gate's GPU limit is 4 ms here, the base spec's stand-in). The
  Medium preset didn't change it: the gorge brings the camp's environment
  (SDFGI, volumetric fog) with it. Worth a look with step 2's frame gate.

### Bank 1 for your review (2026-10-25; you approved its look)

**Look at:** `previews/p6_bank1/`, each view twice, `old_*` as the camp shows
it today and `kit_*` with bank 1 rebuilt from kit pieces in its place:

- `*_walls`: zoomed on the near-left tier walls (the camp's `vista_walls`
  view, under the left colossus);
- `*_bank`: the whole bank from the overlook;
- `*_concept`: the box-art framing.

**What's the same:** the bank's plan (the same eight numbers for its
centre, size, height and seed), its tiers stepping in and out and turning a
little as they rise, the facade mix (lattice windows, balconies, doorways,
book stacks with and without ladders, tile panels, by the same position
hash), the candle-lit stacks near the overlook, lamps in clusters and the
warm cluster lights they get, deck edges with balustrades, moss and rain
streaks, crowned tops with worn merlons, figures, cypresses, pavilions and
banners on the occupied tiers. The materials are the camp's own, copied
after its art passes.

**What changed (the kit's grid):**

- Tiers are 2 or 3 storeys (8 or 12 m; today 8.3–11.7 m), so a 12 m tier
  has three rows of bays where today's had two.
- Bays are 4 m wide (today about 4.2) and one storey tall (today up to
  4.6 m), so the arches spring a little lower; they're as pointed as today's.
- Tier outlines are whole bays, so the notched corners step by a bay.
- **Not yet in it:** bank 1's two Persian towers (their pieces are next),
  and its stone between bays reads a touch more regular.

**Built:**

| Piece | File |
|---|---|
| The gorge's 32 materials copied from the camp (after every art pass) into the kit library as `gorge_*`, so kit pieces look as the gorge does | `tools/gorge_materials.gd`, `kit/materials/gorge_*.tres` |
| 33 kit pieces by script into a new `kit_gorge.blend` (yours to edit from now on): tier wall in three stone ages, six facade bays (window, balcony, doorway, stack, stack with ladder, tile panel) and the two candle-lit stacks, piers (plain, rain-stained), deck, deck edges (plain, streaked, mossy), crowned edges (plain, worn, broken), the overhang's corners, figure, three cypresses, two pavilions, three banners, two lamps | `tools/kit_add_gorge.py`, `art_src/kit/kit_gorge.blend` |
| Pieces tagged `scenery` are only looked at, so the import doesn't ask for collision | `tools/kit_import.gd` |
| `GorgeGrammar.bank()`: vista.gd's bank, tier by tier, in kit pieces | `scripts/gen/gorge_grammar.gd` |
| The preview: the camp with a bank left out of vista.gd's build (its terraces still worked out, so the cavern is unchanged) and the kit bank in its place, its lamps joining the cluster lights | `tests/gorge_bank_preview.gd`, `scripts/vista.gd` (`skip_banks`, `extra_lamps`) |

**Caveats:**

- **Draw calls.** Bank 1 is 6,826 pieces. Placed one by one, the box-art
  view costs 1,572 draw calls (today 543, budget 1,500). That's expected
  before batching: the bake will draw repeated pieces as one batch each
  (`KitBatcher`, design §5.7.2), as the code does today with its 144,000
  batched instances.
- The whole gorge will be about 55,000 pieces (today's code places 11,680
  facade bays and 144,090 batched parts). The baked scene is split per bank
  so each opens on its own; load time is a thing to measure.
