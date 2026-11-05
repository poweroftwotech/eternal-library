# Progress: phase 13, the Garden Court (R07) and the Fungus Terraces (R15)

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-13-approval.md)

## Step 2: the Garden Court's life and story (built 2026-11-05; you called the look final, tests pass, committed)

### The tests (2026-11-05, after "looking good")

All muted (`--audio-driver Dummy`). CSVs in `previews/phase13_step2/frame_gate_*.csv`.

| Test | Result |
|---|---|
| Route audit (`tests/area_route_test.gd`, seeds 1-10, Lower Stacks and Forgotten Wing) | 477 checks each, 0 failures. The first run found new failures in every seed, all fixed: (1) the walk went cell centre to cell centre through the takhts, benches, tray, planters, the pool's rim and the great tree, so the garden now gives its own walk as a player goes (down the rill, round the pool's east side on the path, on to the iwan and its corridor; `GardenCourtGrammar._route`), and the bench and tree cells are blocked; (2) where nothing goes on past the garden (a dead end), the iwan's back doorway opened onto nothing: it now has a shut door like any exit nothing joins; (3) the iwan piece's origin was its middle cell's corner, so the room check saw a gap behind its west pier: it now sits on its own corner (kit rev 4, same place in the game); (4) the side probes reach 4 m in the garden (the iwan's hood is 7 m wide, past its cell) and skip blocked cells (the great tree stands on its cell's centre). |
| Frame gate (`tests/area_walk_capture.gd`, Medium 1080p, seed 1) in the garden | Lower Stacks: about 17,000 frames, CPU mean 1.7 ms, worst 7.97 ms, none over 8 ms; GPU worst 2.35 ms; 16 lights in reach. Forgotten Wing: CPU mean 1.66 ms, worst 7.86 ms; GPU worst 2.35 ms; 16 lights. The sun's shadows and the fig leaves cost nothing that shows. The garden's pieces are now warmed while the area loads (`PipelineWarm`); before that, its first frame in sight was 8.7 ms. |
| Frame gate, the whole area | Still fails, as before phase 13: one 145-195 ms frame when the Bridge Hall's bridge enters (it builds its whole span in one go when it arrives; phase 12 reported a 105-117 ms hitch at the same gate). With the garden placed after the galleries, the Bridge Hall now streams in during the seed 1 walk. A fix (build the bridge over several frames) is a separate task. Lights in reach peak at 48 of 50 (the caravanserai). |
| Save and resume (`tests/r07_resume_test.gd`, two processes, both areas) | Saved 1.4 m from the great tree; a new process resumes there on the floor, with the pool there and the map's sketch of the garden with you on it (`previews/phase13_step2/map_*.png`). |
| Kit gate (`tests/kit_test.gd`) | 8312 checks, 0 failures. Headless 240-frame gate: no errors. |

### The character pass (after walk 5, 2026-11-05)

You picked four of my suggestions: dappled light, a haze column, one great
tree, and a check that the rills run. Captures: `previews/phase13_step2/walk6_lower_stacks/`
and `walk6_forgotten_wing/` (seed 1; `great_tree`, `under_tree`, `arrive`; the dappled light in `walk6b_*/`: `dapple`, `dapple_east`, `arrive`).
Headless gate 0 errors, kit_test 8312 checks, 0 failures.

| Suggestion | What happened |
|---|---|
| One great thing | A great old pomegranate (`garden_tree_old`): a broad twisted trunk forking at 1.6 m, limbs to a crown about 7 m across and 6 m up, heavy with fruit and scarlet blossom, a few fruit on the soil. It stands in one of the two beds beside the iwan (the seed picks), in the sun, and takes that bed's orchard tree's place. Wild (`garden_tree_old_wild`): two limbs dead and bare, suckers and ivy at its foot, most fruit fallen. The fruit can't be picked yet (a new satchel item: your call). |
| Haze column | The shaft's haze is thicker (density 0.0012 to 0.004, soft edge) and the sun lights it more (fog 0.12 to 0.45). It shows as a soft glow down the shaft, not a fog over the court. |
| Rills run | They do: their water is the shared moving water (`cistern_water`), which the area animates. Taking off the "water" tag in walk 5 only stopped the wading. |
| Dappled light | **Real leaf shadows (your pick).** Six wild figs root in the court face's rock over the talar roofs and reach 4 to 5.5 m out over the court at 13 to 14 m, in the sun's beam (shaft rev 15). Their leaves, the ivy curtains and the trees throw moving leaf shade on the paving, beds and pool. The real fault behind both tries: LightBudget faded every light's shadow past 22.5 m from the camera, and the sun is 50 m and more up, so it had thrown no shadows at all (no tree shade either). Far lights now keep their shadows to 90 m (`scripts/world/light_budget.gd`); the garden's sun is the only far light with shadows, so nothing else changes. Its cost shows at the frame gate. The leaf projector (it blacked out the sun) is gone. |

### After your walk 5 (5 reports, 2026-11-05)

Captures: `previews/phase13_step2/walk5_lower_stacks/` and
`walk5_forgotten_wing/` (seed 1; `door`, `niches` and `fountain` show the
changes). Headless gate 0 errors, kit_test 8276 checks, 0 failures.

| You said | What changed |
|---|---|
| Holding run, the character walks in parts of the garden, even on the path | The rills were tagged as water, so their floor counted as wading and slowed you. Only the pool is water now. |
| The small niches cut into the large ones | The tall niche is lower (its crown is about 5.1 m) and there is one small niche, centred above it, with clear wall between. |
| The pool water looks like ice | The pool and both bowls use the cistern's moving water. |
| Z-fighting between the bricks and the adobe on the talar door's back wall | The door's back wall now sits flush with the bays' wall, and its brick piers stand forward of it. |
| The fountain water at the top is flat faces | The flat cards are gone. The jet is now a spray of drops thrown up off the finial, falling back into the top bowl. |

### After your walk 4 (7 reports, 2026-11-05)

Captures: `previews/phase13_step2/walk4_lower_stacks/` and
`walk4_forgotten_wing/` (seed 1; `talar`, `corner`, `pishtaq_side`,
`takht`, `fountain` and `arrive` show the changes).

| Your report | What changed |
|---|---|
| Missing cave round the top of the arch, even from the ground | The iwan piece now carries rock over its whole block, from its roof up into the shaft's rock, beside the pishtaq and behind its crown. No gap shows past the pishtaq's sides. |
| Way too dark in some corners | One fill now runs down the middle of each talar at 4.5 m, reaching its corners (they were small fills at floor height). |
| Light balance: bright ivy on near-black rock, columns near black in daylight | The court's bounce is stronger and wider, so it lights the columns' faces, and the sky's fill moves up the shaft so it lights the rock. Still seven lights with the sun, one shadowed. (A stronger ambient or GI made no visible difference under this renderer's GI, so it was taken back out.) |
| More sitting areas, like the daybeds, along the walls | Up to four more in the tended garden: a takht and a rug with cushions and a tray, in turn, along the talar walls, never by the door and never next to another seat. |
| Make sure seats aren't blocked by columns | Every seat (the takht, the sitting corner, the new ones) now stands centred in a gap between two columns. Planted pots stay out of seats' gaps. |
| A different tile for this room: floral, leaves, nature | A floral tile of its own, `garden_tile` (white and rose four-petalled flowers with leaves on deep blue), replaces the teal tile on the pishtaq, the dados, the ceiling panels, the corridor and the pool floor. A leafy vine band, `garden_band`, replaces the mosaic bands. Both are made by `tools/tile_garden.gd`. |
| The beds' corners by the fountain leave no room to walk round it | The four beds by the pool are five-sided now (`garden_bed_clip_4m`, and a wild version). Their corner toward the pool is cut parallel to the pool's side, leaving a paved path about 1.4 m wide all round. |

Headless gate: no errors. Kit gate: 8278 checks, 0 failures. A garden
court in 20 of 20 seeds in both test copies.

### After your walk 3 (3 reports, 2026-11-05)

Captures: `previews/phase13_step2/walk3_lower_stacks/` and
`walk3_forgotten_wing/` (seed 1; `arrive`, `across`, `back` and `rise` show
the changes best).

| Your report | What changed |
|---|---|
| Too many columns; take out about 1 in 3 and spread the rest | Six columns per side between the corner columns instead of ten, evenly **about 3 m apart** (they were 2 m). The bays no longer carry columns: the grammar stands them along each side, so the spacing is even across the bays. The middle pair on the entry side flanks the door. A new piece, `garden_column`, and two with ivy climbing, `garden_column_ivy_0/1` (about 1 in 4 columns tended, 6 in 10 wild). |
| The garden needs to be more lush | Beds packed: 46 flowers instead of 18 (a quarter of them tall), 14 fern clumps instead of 6, flowers leaning over the stone edging, and a low clipped leafy edging all round each bed. A **flowering shrub** in one or two free corners of every bed (`garden_shrub`). **Big planted pots** between about half the column pairs (`garden_planter`; wild: cracked, ferns spilling, ivy down the side). The wild beds go from 22 to 34 ferns. |
| Vines and plants hanging round the cave opening and walls | **Ivy curtains** hang off the rock lip all round the court, down the face toward the cornice (the pishtaq stays clear). Shorter curtains and fern tufts sit on the funnel's ledges, and ferns stand round the hole against the sky with ivy trailing down into the light. |

Headless gate: no errors. Kit gate: 8236 checks, 0 failures. Draw calls
in the widest views went from about 600 to 655, from the columns and pots
as separate pieces. The frame gate will show whether that matters, once
you have looked.

Also fixed: `tools/make_r07_draft.gd` no longer adds a second garden rule
to a recipe that already grows one.

Captures: `previews/phase13_step2/tended/` (Lower Stacks) and
`previews/phase13_step2/wild/` (Forgotten Wing), seed 1. Walk them from the
Strata Board: the copy `garden_test` in either area, Walk this seed.

**Tended (the Lower Stacks):**
- A **takht** in the middle of one side talar, facing the court (the
  Hypostyle's, with its carpet, cushions and book; its little lamp stays dark).
- A **sitting corner** in the other side talar: a garden rug, two floor
  cushions, a tray table.
- **Shelves** in about half the talar's tall niches: books, clay pots, a
  folded cloth, a big jar on the niche floor.
- Two **stone benches** beside the cross rill, facing it.
- The **gardener's things** on the paving by a bed: a basket of
  pomegranates, a clay watering jar with a spout, a pruning knife, cut twigs.
- **To pick:** six hearthleaf patches and three amberroot in the beds (the
  same pickables as the Bridge Hall; they grow back when the room is next
  built). The pomegranates are scenery: picking fruit needs a new kind in the
  satchel and the cooking, a change to the game's systems.
- **Moving:** drops falling from the fountain's two bowls, blossom petals
  drifting down the sunlight, a few pale moths over the beds (the water
  already ripples).

**Wild (the Forgotten Wing):** ivy in curtains from the talar's cornice and
up some columns; the pool dry and silted, weeds in it, the top bowl broken
off and lying in the basin; the rills dry, mossy, a coping stone lifted;
beds overgrown with tall ferns spilling over the edging; the sitting
corner's rug left with rubble and a broken vase; fewer shelves; the
gardener's basket tipped, the jar broken; dry leaves drifting instead of
petals; eight herbs, two roots and four mushrooms in the talar's shade.

**In the live areas (saved 2026-11-05, your choice: right after the galleries; Lower Stacks recipe version 10, Forgotten Wing version 3):** one garden per stratum,
the world seed picking the Lower Stacks or the Forgotten Wing (a new
`one_of` on a grow rule; the game, the Strata Board and the door tool now
plan in a world). The garden competes with the Bridge Hall for doors:

| Garden grown… | Worlds with a garden | Bridge Hall, Lower Stacks | Bridge Hall, Forgotten Wing | Light-well (LS / FW) |
|---|---|---|---|---|
| right after the galleries | 33 of 40 | 26 → 13 | 21 → 17 | 31 → 26 / 33 → 24 |
| after the light-well | 20 of 40 | 26 → 13 | 21 → 16 | unchanged |
| after the Bridge Hall | 2 of 40 | unchanged | unchanged | unchanged |

World 33 of the Lower Stacks already plans five rooms (under its six) with or
without the garden: an existing problem, not this step's.

New: kit pieces `garden_bench`, `garden_niche_shelves`, `garden_traces`,
`garden_traces_old`, `garden_pool_dry`, `garden_rill_dry_4m`,
`garden_bed_wild_4m`, `garden_talar_vines`; `GardenCourtLife`
(`scripts/gen/garden_court_life.gd`, warmed by PipelineWarm); grammar
`r07_garden_wild.tres`; `tools/make_r07_live.gd` (`--dry` to report only).

## Step 1: the Garden Court, structure and light (built 2026-11-04, walked twice; you approved the look 2026-11-05)

### After your second walk (1 report, 2026-11-04)

Captures: `previews/phase13_step1/walk2/` (seed 1; `up` and the new
`rise` show the shaft).

| Your report | What changed |
|---|---|
| Layout much better, but the square shaft and the square walls at the top don't look natural; the walls should funnel and be uneven, the hole a rocky shape | The shaft is square only where it meets the court face. Above that it is an **uneven funnel**: nine rings that turn from the square into a lumpy outline, narrowing from about 19 m across to about 12 m, with ledges and bulges, leaning toward the sun. The top is a **ragged hole**, its rim rising and falling about 1 m, with a rocky collar round it and the sky set back behind, so the edge stands out against the light. The rock face above the talar and the lip over it are broken up too (straight only along the cornice), and so is the shelf over the iwan's pishtaq. |

Still open: the iwan's own masonry block behind the pishtaq stays in deep
shade with straight sides. Headless gate and kit gate (8039 checks) pass.

### After your first walk (6 reports, 2026-11-04)

Captures: `previews/phase13_step1/walk1/` (seed 1, twelve views; `talar`
and `out` are new).

| Your report | What changed |
|---|---|
| Two floors of alcoves look like the caravanserai; a different design for the sides (Chehel Sotoun picture) | The ring is now a **talar**: one storey of tall wooden columns (about 8 m, two per bay, stone bases, carved heads) carrying a beam and a flat painted ceiling of boards, battens and tile panels, a cornice and mosaic fascia along the court. Behind, a plaster wall with a tile dado, one tall niche and two small ones per bay, and a mosaic band under the ceiling. The corners turn on one column. Rock comes down to the cornice above it. New pieces `garden_talar_bay`, `garden_talar_door`, `garden_talar_corner`. |
| The way into the garden should be longer | A **vaulted brick corridor, two bays (8 m) long**, from the door to the talar's door wall (`garden_corridor_4m`). |
| Same on the other side | The same corridor behind the iwan to the way out. |
| Way too much bloom, almost blinding | Bloom nearly off (0.12 to 0.02, intensity 1.0 to 0.5, threshold 1.1 to 1.6); the sun 20 to 14; the haze down to a trace. |
| Remove the cypresses | Gone; the quarters keep their pomegranates, now up to one per bed (16). |
| The tile pattern hangs past the arch | That was on the caravanserai's passage piece, which the garden no longer uses (the door is in the talar's back wall). |

Also: the near talar had gone almost black in the view back from the iwan,
so its cool fill is a little stronger; the court's lights are still the sun
plus six fills, no flames. Still a garden court in 20 of 20 seeds. Headless
gate and kit gate (8039 checks) pass. Route audit, frame gate and the rest
wait until the look is settled.

### The first build (before your walk)

What you can see: a test copy of the Lower Stacks where a Garden Court grows
off the Hypostyle Stacks (all 20 seeds). You come in through a vaulted
passage into a square court, 20 m across, ringed by two storeys of arched
bays. In the middle is an octagonal pool with a two-bowl fountain. Rills run
from it along both axes, splitting the garden into four planted quarters.
Cypresses line the main axis, with pomegranates in the far corners of the
quarters. The far wall is a grand iwan: a tiled pishtaq 12 m high and a deep
pointed hood, with the way out at its back. Over the court the rock opens
into a broad shaft up to a square of daylight 34 m up.

Captures: `previews/phase13_step1/r4/` (seed 1; the final set). Earlier
rounds are in the folder above it and `r2/`, `r3/`.

### The light (daylight only, the brief's one family)

- **The sun:** one shadowed spot from high over the entry side, leaning north,
  so the sunlit patch falls on the pool and the iwan's face and the shaft's
  rim throws a hard shadow edge across the arcades. You see the light change
  as you walk from the shaded entry into the sun.
- **Fills:** the sunlit paving's bounce into the iwan and the side bays
  (warm white), the sky's cool light into the shaded south side, one high
  fill down the shaft. No shadows, none near a door.
- **Haze:** a thin column down the beam.
- **No flames:** the bays' reading and sitting corners bring oil lamps on
  their tables; in this room they stay dark (a new switch, `lamps_dark` on a
  room's grammar). Lights in the room: 7 (1 shadowed).
- **Tint:** warm daylight white (`mood_tint`), bloom held back so the court
  doesn't wash out.

### What was built

- **Kit** (`tools/kit_add_r07.py` → `art_src/kit/kit_garden.blend`, 5
  pieces): `garden_iwan` (3 bays wide, both storeys and the pishtaq),
  `garden_shaft_5x5` (the rock over the ring, the shaft and sky, the sun,
  haze and fills), `garden_pool`, `garden_rill_4m` (paving with a flush
  rill, walkable), `garden_bed_4m` (a planted bed on a paved border,
  walkable). New light profile `sun` in `tools/kit_import.gd`.
- **`GardenCourtGrammar`** (`scripts/gen/garden_court_grammar.gd`): the
  caravanserai's ring of bays and corners (no stairs: the upper storey is
  seen, not reached, Q4), the entry passage, the iwan with the far door, the
  chahar bagh, walked lanes from the entry round the pool to the iwan. The
  bays hold places to sit and read, some empty; never the caravanserai's
  bedrolls, stalls or stables.
- **Rules and grammar** by `tools/make_r07_rules.gd`
  (`gen/rules/r07_garden.tres`, `gen/grammars/r07_garden.tres`); the test
  copy of the recipe by `tools/make_r07_draft.gd`
  (`gen/recipes/drafts/lower_stacks/garden_test.tres`); `RoomTypes` knows R07.
- **`tests/r07_capture.gd`**: ten views (entry, arrive, pool, iwan, back,
  arcade, shade, across, up, wide) and a list of the room's lights.

### Fixed during the captures

- The sun at first barely reached the court (its range cut it to a third);
  then at full strength it blew the court out. Now about half.
- The bays brought the caravanserai's dressing: bedrolls, stalls and a
  garden niche with a lantern, then 18 reading-table oil lamps. Now pinned
  to sitting, reading or empty, and their lamps dark.
- Twice as many cypresses hid the pool and the iwan: one per bed cell now.
- The iwan's frieze read as a flat orange bar: mosaic now.

### Checks

- Headless 240-frame gate: pass, no errors.
- Kit gate (`tests/kit_test.gd`): 7886 checks, 0 failures.
- GPU on the capture views: 1.1 to 1.7 ms, 170 to 610 draw calls.
- Fit: a garden court in 20 of 20 seeds on the test copy (grown first).
- Not done yet (step 2, after the look is final): route audit, frame gate,
  map, save and resume, and growing it in the live areas.

### Open for your look

- **The roof:** from the court you see a dark rock lid with the bright shaft
  above it; the sky only shows when you look up. A wider opening or a lip
  that steps back would show more sky from the paths.
- **The pishtaq** is tiled all over above the arch. It could take a calmer
  brick field with tile only in the frame and spandrels.
- **The cypresses** are the gorge's chunky ones; the garden might want
  slimmer ones.
- **The bays** are separate alcoves, not a walkable arcade (the
  caravanserai's cells), so "benches in the shade of the arcades" are in the
  alcoves' mouths.
- Step 2 brings the life: picking fruit and herbs, benches and a takht,
  the gardener's traces, petals and moving water, and the overgrown state.
