# Room rework: the existing rooms before phase 12

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Asked for 2026-11-03 · Status: **step 1 (the Reading Room's furniture, lighting and carpets) built 2026-11-03, waiting for your walk; nothing committed**

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

## Step 1: furniture, lighting, carpets (2026-11-03, built)

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
