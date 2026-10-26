# Progress: phase 6, the Overlook and the Chasm Spans

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../phase-6-approval.md), [technical](../phase-6-design.md)

**In short:** phase 6 was approved on 2026-10-25 with the recommended
answers except Q2: the gorge is rebuilt from kit pieces, so it can be baked
and changed by hand. Step 1 is built: the whole gorge (8 banks, 11 towers, 6
aqueducts, the sanctum) from 45 kit pieces, baked to scenes you can edit,
shown in a new area, Esc → Walk the Gorge, from the balcony. It passes the
box-art comparison and loads in a quarter of a second. Step 2 is built: the
Overlook is walkable, from the balcony down the rock-cut stair to the landing
and on down to a lantern-lit ledge, with a parapet everywhere.

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
