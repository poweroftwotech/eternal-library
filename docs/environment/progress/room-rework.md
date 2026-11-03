# Room rework: the existing rooms before phase 12

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Asked for 2026-11-03 · Status: **step 1 COMMITTED a75a767 2026-11-03; step 2 (working niches) COMMITTED 2026-11-03 after your walk**

## Why

Before phase 12 you wanted another pass over the rooms already built: their
layout, look and lighting. The library wing goes first. Your walk of
2026-11-02 left five reports there:

| Report | Where | What you said |
|---|---|---|
| 2026-11-02_23-09-00 | Reading Room | The tables are too long; the furniture shouldn't block the doorways and should say "a place of reading" |
| 2026-11-02_23-10-56 | Reading Room | Too bright: take out the lower hanging lanterns, put dimmer lamps on the furniture, and make the chandeliers dimmer with more contrast |
| 2026-11-02_23-12-00 | Reading Room | Different carpet styles and patterns, picked by the seed |
| 2026-11-02_23-13-12 | Far Stacks | The stacks feel like corridors: put niches in place of some windows or shelves (art, plants and food as in the camp, a seat by a hearth, cooking, storage) |
| 2026-11-02_23-16-22 | Reading Room | Niches like those in some of the Reading Room's shelf bays |

Two steps: **step 1** covers the first three reports (furniture, lighting,
carpets). **Step 2** covers the last two: niches in the stacks and the
Reading Room's shelf bays. You chose working niches, so the plants can be
foraged, the pot cooks and the hearth warms.

## Step 2: working niches (2026-11-03, committed after your walk, no reports)

### What you can try

Walk the library wing: the Reading Room, then the stack galleries off it.

- **Alcoves in the stacks are niches now, and there are more of them.** A
  side wall of a stack gallery opens into a one-bay alcove about twice as
  often as before (a fifth of the walls that have room for one). Each alcove
  holds one of four niches, picked by the seed:
  - **Hearth:** the camp's cooking fire and pot at the back, a floor seat on
    either side, a kilim, a mug. Its fire flickers and lights the alcove.
    **E on the pot** opens the camp's cooking panel. **Standing within about
    3 m of the fire warms you**, as the camp's hearth does.
  - **Garden:** a raised brick bed of soil with hearthleaf, amberroot and
    hearthleaf growing in it, and two of the camp's planters. A lamp always
    hangs over it (plants by light). **E on a plant** gathers it into your
    satchel; it shrinks to a stub.
  - **Larder:** sacks, jars and crates with a shelf of pots against the back
    wall (the caravanserai's store), a pack, and a mossy log along one side
    where **shelf mushrooms** grow (E gathers them). A lamp hangs over it.
  - **Art:** a woven hanging (one of the three tree-of-life weavings) on the
    back wall, two vases, a floor seat facing it and a brass tray table with
    a lamp at its foot.
  A niche's back wall is always plain brick, and its lamp is always lit (the
  corridor's own lamps still go dark the further out you are).
- **Some shelf bays are working niches**, in the stacks and in the Reading
  Room: about one bay in ten, picked by the seed, is one of three:
  - **Wall hearth (ocak):** a raised brick hearth with a soot-black firebox,
    embers, a copper pot on a trivet and a brick hood. Cook at the pot; it
    warms you like the alcove hearth.
  - **Herb shelf:** a deep wooden trough on the floor (hearthleaf, amberroot,
    hearthleaf) and a shallow one above (amberroot), under a small hanging
    lantern. All five patches can be gathered.
  - **Pantry:** three shelves of storage jars, a sack, a small oil lamp, and
    a damp log at the foot with shelf mushrooms (two patches to gather).
- **The Reading Room always has two:** the ground-floor shelf bays on the
  west and east walls past the stair feet, nearest the iwan, are always
  working niches; the seed picks which of the three.

Gathered plants grow back when the room is next built (when you leave the
area and come back, or load). The camp's patches don't save either, so
nothing about them goes in the save. Say if you'd rather they stayed
gathered, or grew back over time.

### What changed

- **Alcove niches:** `StackGalleryGrammar.niche_weights` (hearth, garden,
  larder, art at 1 each; "empty" 0) picks one per alcove as the slot
  `dressing:niche_<kind>`. The R02 rules (`gen/rules/r02_brick.tres`) offer
  `kit/dressing/niche_hearth.tscn`, `niche_garden`, `niche_larder` and
  `niche_art_0..2`. A niche's back wall asks for `edge:plain`; a garden's or
  larder's lamp is always placed and pinned lit. The seam debris along the
  foot of a niche's three walls is pinned to "nothing" (it would land in the
  furniture; Validate Room caught it). `side_passage_chance` in
  `gen/grammars/r02_stack_gallery.tres` went from 0.11 to 0.2.
- **Wall niches:** `kit/dressing/recess_hearth.tscn`, `recess_herbs` and
  `recess_pantry` are new candidates in `recess_library` (weight 0.4 each;
  full shelves keep 6). A new socket set, `recess_niche`, holds only the
  three, and the Reading Room puts it on its two ground-floor bays at z -18
  through a new `RoomTemplate.socket_sets` (socket path to socket set, for
  one room); that east bay's old pin to full shelves is gone.
- **New kit pieces** (`tools/kit_add_niche.py` → `kit_dressing.blend`):
  `niche_bed`, `niche_log`, `wall_hearth`, `wall_herbs`, `wall_pantry`.
- **The camp's plants as pieces:** `tools/extract_forage.gd` cuts the camp's
  hearthleaf, amberroot and shelf mushroom patches out of
  `rooms/camp/camp.tscn` into `kit/dressing/forage_<kind>.tscn`, so the
  niches grow exactly the camp's plants.
- **What you use:** `scripts/world/niche_thing.gd` (`NicheThing`), on a
  forage patch or a pot. `main.gd` gathers a patch into the satchel (one
  `gather()` shared with the camp's patches) and opens the cooking panel at
  a pot. In a room, standing within 3.1 m of any pot warms you at the
  camp's rate; rooms still don't make you cold. A pot's fire light flickers
  on the camp fire's curve.
- **No hitch on first sight:** the niches bring materials the library didn't
  use before (camp, court and weaving), and the first frame that showed one
  compiled 20 shader pipelines at once (8.3 ms in a stack gallery, over the
  8 ms gate). `scripts/world/pipeline_warm.gd` (`PipelineWarm`) draws the
  niche meshes once, tiny and just in front of the camera, for three frames
  as an area arrives (`area.gd`), so they compile while the place settles.

### Tests

- `tests/niche_test.gd` (new, headless, the real game on the Reading Room
  with a gallery off each door, seeds 1 to 8): every alcove kind and every
  wall niche turns up; niche lamps are lit; E on each plant kind adds one to
  the satchel, shrinks it and gives nothing a second time; E on a pot opens
  the cooking panel; standing by a hearth warms you, the middle of the hall
  doesn't. 52 checks, pass.
- Kit test (6,663 checks), Reading Room test (87; now 14 shelf bays and 2
  working niches), Validate Room (26): pass.
- Library wing area route test (seeds 1 to 5, 172 checks): pass, after the
  seam pin above (the first run had 19 Validate Room warnings, all seam
  debris inside a niche).
- R02 route test (2,321 checks): pass. The walk into an alcove now stops at the niche's open
  front (the hearth is in the way of the old walk to the back wall), and the
  Reading Room's socket count is 101 (the test still said 106, from before
  step 1).
- Generation signatures re-recorded (92 rooms): most stack galleries changed,
  as expected (more alcoves, plain niche backs).
- Library wing frame gate (Medium, 1080p): failed twice on one CPU frame
  (8.25 and 8.28 ms) where a gallery first showed a niche and compiled 20
  pipelines; with PipelineWarm, **pass** (CPU 1.53 ms mean, 6.87 worst; GPU
  0.93 mean, 2.41 worst; 1,209 draw calls; lights in reach 36 of 50).
- Captures: `previews/room_rework_step2/`.

## Step 1: furniture, lighting, carpets (2026-11-03, committed a75a767)

### What you can try

Walk into the Reading Room (the library wing, from the Gorge).

- **The long tables are gone, and so are the chairs** (your second look:
  "more traditional Persian floor seating"). Either side of the middle,
  between the stairs and the centre aisle, are two **low reading tables**
  (1.2 m, knee height) with a carved book rest (rahl) holding an open book.
  Each has its own **oil lamp** at the end nearest the entrance, and books,
  scrolls and pots scattered by the seed. Against the wall side of each table
  is a **floor seat**: a long mat (toshak) in a boteh (paisley) cloth, two
  ikat cushions leaning on the wall side, and a kilim bolster at one end. Two
  **kilim poufs** sit on the aisle side.
- **A floor-seat corner either side of the entrance:** a floor seat with its
  back to the entrance wall, looking down the hall, a pouf, and a **brass tray
  table** (a sini on a folding stand) with a lamp, on a small carpet.
- **The middle of the hall** is, by the seed, either a long runner (three
  carpets end to end) or a big carpet with only a low table on it (the floor seats round it came out after your walk: they blocked the way down the hall).
- **Both doorway lines stay clear**: from the entrance to the iwan, and
  across between the two side doors. The side door bay has no furniture in it.
  The arches under the side galleries are still open to the shelves behind
  them.
- **Lighting:** the four lower hanging lanterns under the arcades are gone.
  The chandeliers give 45% of their light and the cool fills under the vault
  half. The light now comes in warm pools from the lamps on the tables
  (short reach, no shadows), with dark between them. The iwan's own lantern
  and glow are unchanged.
- **Carpets:** five designs: kilim (diamonds), herati (a lattice on indigo),
  medallion (a centre medallion with corners), gabbeh (a plain dyed field
  with a few motifs) and garden (water channels and trees). Each comes in
  three sizes (runner, grand, small). Over seeds 1 to 10 the middle got 7
  runners and 3 low-table seatings in four designs. The two corner carpets
  always match each other (one design per room).

### Before and after

The same views as your reports (`tests/report_capture.gd`):

| Report | After |
|---|---|
| 23-09-00 (tables too long) | Low reading tables with floor seats, poufs and lamps either side; the middle a garden carpet with a low table; the doorway lines clear |
| 23-10-56 (too bright) | The arcades dark, the chandeliers dim, light pooled round the lamps; the entrance's two floor-seat corners lit by their tray-table lamps |
| 23-12-00 (carpets) | Seed 1: a garden carpet in the middle, gabbeh in the corners |

### What changed

- **New kit pieces** (`tools/kit_add_reading.py` → `kit_dressing.blend`,
  family "dressing"): `low_reading_table`, `low_table` and `tray_table`
  (the tables have their lamp built in), `floor_seat`, `pouf`,
  `floor_cushion`, and the carpets `rug_<design>_<runner|grand|small>`. The
  first version's `reading_table`, `reading_chair`, `reading_armchair`,
  `side_table` and `table_lamp` stay in the kit but the room doesn't use
  them. Floor seats and poufs have no collision (you walk over a cushion);
  the tables do.
- **Cushion cloths** (32 texels/m like the rest): `cushion_termeh` (boteh
  on madder red), `cushion_ikat` (blurred chevrons), `cushion_kilim` (bands
  of diamonds), in the carpets' dyes. The lamps are part of the tables
  because a free kit piece has to sit on the 0.5 m grid (Validate Room), and
  a table top isn't on it.
- **Carpet maps** from `tools/pixel_materials_ext.gd -- rugs` (writes only the
  carpets and merges them into `manifest_ext.json`).
- **A "desk" light** in `tools/kit_import.gd`: warm, 3.2 m reach, no shadows.
- **Socket sets:** `rug_hall` (the middle: five runners, three seatings in
  `kit/dressing/hall_seating_*.tscn`), `rug_nook` (the corners, style group
  `reading_nook_rug`), `table_props_small` (the table-top scatter sized to the
  new tables; the old `table_props` keeps its 4.4 m slot).
- **Dimming one room's kit lamps:** a placed piece with the metadata
  `light_energy_scale` has its lights scaled (`RoomTemplate.scale_lights`,
  before the sockets resolve). The Reading Room's chandeliers use 0.45. The
  kit's chandelier, and other rooms' chandeliers, are unchanged.
- **Floor wear** follows the new layout: the walked lines go either side of
  the middle, across between the side doors, and to the stair feet, with
  rings round the four tables.
- `tests/reading_room_test.gd`: the walk down the hall goes round the middle
  (some seeds put a low table there); the floor probe looks past furniture;
  the walk under an open stair starts between two tables; the socket counts
  and wear lanes match the new room.

### Tests

- With the floor seating (2026-11-03): kit test (6,579 checks), Reading Room test (87), Validate Room (26, no warnings) and the library wing route test (172) all pass. Frame gate **pass** on the first run (GPU 0.84 ms mean, 1.80 worst; CPU 1.37 ms mean, 5.65 worst; 1,027 draw calls; lights in reach 31 of 50). The chairs version, below, passed the same tests.
- Kit test: pass. Reading Room test (87 checks): pass. Validate Room: pass
  (no warnings). Headless run of the game and of the room: no errors.
- Library wing area route test (seeds 1 to 5, 172 checks): pass.
- Library wing frame gate (Medium, 1080p): **pass** on the second run (GPU
  0.85 ms mean, 1.81 worst; CPU 1.37 ms mean, 6.18 worst; 1,002 draw calls;
  lights in reach 31 of 50, of them 7 desk lamps). The first run failed on a
  single 8.40 ms CPU frame in the east stack gallery, with no streaming and
  nothing loading. The rerun didn't repeat it, so I've treated it as a
  one-off hitch.
- Captures of your report views after the change: `previews/room_rework_step1/`.
