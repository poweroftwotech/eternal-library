# Progress: phase 1, the authored Reading Room R01 (done 2026-10-19)

[Back to the front page](../../../ENVIRONMENT_PLAN.md)

**In short:** the socket system (variety by seed, pins in the Kit dock), the R01 modules, the Reading Room scene, Atmosphere, Validate Room, and R01 playable from the Esc menu.

---

### Phase 1: authored R01 (in progress, started 2026-10-18)

**Done this session: the socket system.**

| Piece | File |
|---|---|
| Candidate list and entry (weights, labels, tags) | `scripts/world/socket_set.gd`, `socket_entry.gd` |
| Variation point: picks by seed, internal child never saved, Pin, "Next candidate" button | `scripts/world/variant_socket.gd` |
| Room root: resolves all sockets from `preview_seed` (key = seed + room_id + socket path), "Reroll sockets" button | `scripts/world/room_template.gd` |
| Book dressing as one MultiMesh (full, sparse or fallen), seeded by its socket | `scripts/world/shelf_fill.gd`, `kit/dressing/recess_books_*.tscn` |
| Recess socket set (full 6, sparse 3, collapsed 1) | `kit/sockets/recess_library.tres` (created by `tools/seed_sockets.gd`) |
| Importer turns `SOCKET_<set>` empties into `VariantSocket` linked to `kit/sockets/<set>.tres` | `tools/kit_import.gd` |

The shelf-bay mesh now has boards only; books come from the socket. The
graybox root is a `RoomTemplate`. Select it and press **Reroll sockets** in the
Inspector, or select one recess socket (inside a shelf-bay instance) and press
**Next candidate** or set **Pinned**.

**Verified:** `tests/kit_test.gd` passes 126 checks: 10 sockets in the graybox,
the same seed gives the same picks, different seeds vary, pinning holds, and
more than 300 books get built. Both 240-frame headless gates are clean. The GPU
capture `previews/kit_graybox_entrance.png` shows books on the shelves.
Reroll and Pin haven't been clicked in the editor yet.

**Step 0 done (2026-10-18): socket panel in the Kit dock.** The Kit dock now
has a lower **Sockets** half (drag the splitter to resize it):

- **Selection:** select a module (or anything inside one) to list its sockets
  with the current pick, where the pick comes from (seed, module pin or room
  pin), **Prev / Next / Random** (each pins the result) and a **Pin** box
  (untick to let the seed choose again).
- **Room:** every socket in the open `RoomTemplate`, the same controls, a
  **Clear all pins** button, and rows for stale pins (module renamed, moved or
  deleted) with their own **Clear**. Clicking a socket's path selects its
  module.

Pins are stored on the room, not the socket: `RoomTemplate.socket_pins`
(`{socket path: entry index}`), so no Editable Children is needed and the pin
is saved with the room. A room pin wins over the socket's own `pinned`, which
stays as the module-wide default. Every change goes through the editor undo
history. Files: `addons/kit_palette/socket_panel.gd`, `plugin.gd`,
`scripts/world/room_template.gd`, `variant_socket.gd`.

**Verified:** `tests/kit_test.gd` passes 129 checks (room pin beats seed and
module pin, clearing restores the seeded pick, stale pins reported).
`tests/socket_pin_persist.gd` saves pinned picks in one process (`-- save`)
and restores them in a fresh one (`-- load`) with no `[editable]` entries.
Both 240-frame gates are clean, and the editor loads the plugin headless
without errors. **Not verified:** clicking the panel in the editor (layout,
icons, undo/redo from Ctrl+Z).

**Step 1 done (2026-10-18): R01 modules.** Eight new modules in
`kit_walls.blend` (17 in the catalog), added by `tools/kit_add_r01.py`. That
script is additive: it opens the hand-edited `.blend`, adds only missing
modules and saves, so re-running never touches your edits. Shared Blender
helpers now live in `tools/kit_blender.py` (the seed script uses them too).

| Module | Shape | Notes |
|---|---|---|
| `vault_hall_12m` | cell 3×1 | Pointed barrel vault over 12 m (k 0.58), tiled crown strip, transverse rib on the bay boundary. Place it one storey up on two-storey walls: springs at 8 m, intrados crown at 14.55 m |
| `wall_gable_12m` | edge, 3 bays | Closes the vault end above the wall top (also one storey up) |
| `wall_iwan_12m` | edge, 3 bays × 2 storeys | 6 m pointed iwan, 3 m deep, tile-lined, mosaic frame, four blind tiled niches, back shelves with a `recess_library` socket, `ANCHOR_study` for the centrepiece. It protrudes 3.3 m behind the wall line, so use it against rock |
| `stair_gallery_8m` | edge, 2 bays | Masonry stair along a wall, up 4.15 m to the gallery slab lane; walkable `-colonly` ramp, balustrade, `SNAP_stair_foot` / `SNAP_stair_head`. Leave the gallery slab out over its two bays |
| `post_pier_corbel` | post | Pier with corbels under the gallery slab (use at storey 0; plain pier above) |
| `table_reading` | free | 1.4 × 4.4 m, six `ANCHOR_seat` markers |
| `lantern_cluster` | free | One big and four small lanterns, chain up to the 12 m vault crown, one `chandelier` light (new profile in `kit_import.gd`, casts shadows) |
| `rug_runner` | free | Three rugs end to end (13.4 m), UV-mapped `rug` map; the exporter now writes UVs (`export_texcoords=True`; the old modules exported byte-identical) |

`tests/kit_r01_capture.gd` assembles a 3 × 3 bay slice in memory (never saved)
and captures `previews/kit_r01_hall.png`, `kit_r01_iwan.png` and
`kit_r01_gallery.png`. Catalog refreshes now keep `kit/catalog.tres`'s UID (read from
the file header, since `get_resource_uid` returns -1 in headless runs).

**Verified:** `tests/kit_test.gd` passes 241 checks: every new module's
materials, collision and markers, the iwan socket, the chandelier light, rug
UVs, and a player capsule (`move_and_slide` with gravity) climbing the stair
onto a gallery slab. Both 240-frame gates are clean, with no import warnings.
The GPU captures show the iwan, vault crown tiles, ribs, gallery, stair and
chandelier as intended. **Caveats:** the iwan's tile lining is one
uniform pattern, which is busy and has no ochre/lapis variation yet. The small
cluster lanterns barely read at hall scale. The 13.4 m runner overhangs a
3-bay hall, so for R01 (5 bays) place it with tables and lanterns in mind.
Nothing has been placed in the editor yet.

**Step 2 drafted (2026-10-18): `rooms/authored/reading_room.tscn`.** At the
user's request the first draft comes from a script, `tools/build_reading_room.gd`.
It refuses to overwrite the room unless given `--force`; from here on the scene
is edited by hand in the editor. It is a `RoomTemplate` (`room_id` `reading_room`), 3 × 5
bays (12 × 20 m), two storeys under `vault_hall_12m`, built from 92 kit
modules under `Shell / Sockets / Props / Dressing / Lights / Connectors /
Bounds`.

- **Layout (after step 2b):** entrance arch in the south middle bay, iwan and
  gable at the north end, side doors in bay 1 on both sides. Both stairs run
  over bays 2-3 and rise toward the entrance (the east one is
  `stair_gallery_8m_r`) onto side galleries over bays 0-1. Those galleries are
  joined along the entrance wall by `gallery_end_12m` into one U-shaped walk.
  A 2-bay stair along a side wall always crosses the middle bay, so the side
  doors moved off it (the atlas plan had them in the middle). Bays behind the
  stairs get plain walls. **16 recess sockets**, matching the atlas (the
  upper south recess opens onto the end gallery).
- **Dressing and lights:** rug runner, four reading tables, two chandeliers,
  four lanterns under the galleries and one at the iwan apex.
- **Connectors:** `SNAP_entrance`, `SNAP_door_west` and `SNAP_door_east`
  (Marker3D, group `room_connector`, -Z points out of the room).
- **Temporary:** `TempSafetyFloor` (invisible, 0.25 m under the floor; delete
  it once the room sits in an area) and `PreviewEnvironment` (replaced by the
  Atmosphere node in step 4, which defers to any environment the game or an
  area already supplies).

**Verified:** `tests/reading_room_test.gd` passes 28 checks: KitValidate
clean, 16 sockets, floor in all 15 cells, the three doors open, walls closed,
and a capsule walking the hall into the iwan, up each stair, around the whole
U gallery (west, end, east), and out a side door onto the safety floor. The
rails still hold mid-run and along the end gallery. The 240-frame gate is
clean. `tests/reading_room_capture.gd` captures `previews/reading_room_*.png`
(entrance, iwan, gallery, stair, vault, end_gallery). **Caveats:** the side
doors open onto darkness. The room is dim until step 4's grade. The iwan
centrepiece spot is empty until step 3. The solid masonry stairs look heavy
from the entrance; an open-stringer variant would lighten them. The user
approved the step 2 draft in the editor; the 2b rebuild (`--force`, no hand
edits existed yet) was checked in the editor by the user.

**Step 2b done (2026-10-18): joined galleries.** Four modules, added through
the same additive `tools/kit_add_r01.py` (21 in the catalog):
`gallery_end_12m` (end-wall gallery between the side lanes, newel posts that
swallow the meeting rail ends, wall corbels clear of a central 3 m arch),
`gallery_slab_4m_open_end` / `_open_start` (side slab whose rail stops 1.6 m
short of that end, for the corner square), and `stair_gallery_8m_r` (the
stair mirrored, so it rises toward its origin). `kit_test` passes 312 checks,
including rail extents and the reversed stair's head position.

**Step 3 done (2026-10-18): socket sets and modes.**

| Piece | File |
|---|---|
| `SCATTER` mode (N weighted items in a box, kept `scatter_spacing` apart; a pin makes every item that entry) and `STATE` mode (the entry label is a state applied to the socket's parent) | `scripts/world/variant_socket.gd` |
| Lamp states `lit` / `failing` (dimmed, flickering internal node) / `dark` (light off, glass unlit) on every light and `emit_*` surface of a lamp module | `scripts/world/lamp_state.gd` |
| An entry without a scene is now a valid pick ("nothing", or a state) | `scripts/world/socket_set.gd` |
| Blender properties `socket_mode`, `scatter_count`, `scatter_extent`, `scatter_spacing` on `SOCKET_` empties configure the socket | `tools/kit_import.gd` |
| New family `dressing` (13 modules): recess boards (whole and broken), tile panel with bench, sealed door, iwan lectern (with rug), reading tree in a tiled planter, fountain, and six table props | `art_src/kit/kit_dressing.blend` via the additive `tools/kit_add_dressing.py` → `kit/modules/dressing/` |
| Sets: `recess_library` (+ tile panel 1, sealed door 0.7), `iwan_centre` (lectern, reading tree, fountain), `lamp_state` (lit 6, failing 2, dark 1), `table_props` (book stack, open book, pot, oil lamp, scroll, inkwell) | `kit/sockets/*.tres`, from the additive `tools/seed_sockets.gd` |
| `water` library material (hand-written; no pixel map) | `kit/materials/water.tres` |

**Shelf boards moved out of the shelf-bay and iwan meshes** into the recess
candidates (`Boards` child in `kit/dressing/recess_books_*.tscn`), so a tile
panel or sealed door can replace them. `tools/kit_add_r01.py` gained an
idempotent upgrade pass that removes the baked boards and adds the new sockets
to existing modules: `SOCKET_iwan_centre` in the iwan, `SOCKET_table_props`
(scatter, 2-5 items) on the reading table, and `SOCKET_lamp_state` in both
lantern modules. The seed scripts match for fresh builds. The reading room now
has 28 sockets: 16 recesses, the iwan centrepiece, 4 table tops and 7 lamps.
Order matters when rebuilding: export `kit_dressing.blend`, then run
`seed_sockets.gd`, then export `kit_walls.blend` (the importer links sets that
already exist).

**Verified:** `tests/socket_modes_test.gd` passes 56 checks: set contents,
every candidate instancing, boards in shelf candidates, lamp lit/failing/dark
(energy, visibility, glass material, flicker cleanup), scatter count, bounds,
spacing, determinism and pinning, and the iwan centrepiece varying by seed.
`kit_test` passes 443 checks and `reading_room_test` 28 (socket counts by
set; the hall walk now steps around the centrepiece, which has collision).
Pin persistence holds across processes, and all three 240-frame gates are
clean. Captures: `previews/reading_room_iwan_{tree,lectern,fountain}.png`
(seeds 1-3), `reading_room_table.png`, `reading_room_recesses.png`.
**Caveats:** at these weights about a third of the lamps fail or go dark,
which makes the room noticeably dimmer; the plan wants that only with age, so
weights should drop once age conditions exist. Table props are small and read
poorly at hall distance. The sealed door hasn't shown up in a capture yet
(the test instances it). Age, stratum and faction conditions are still unused. The user checked Reroll and the Sockets panel in the editor.

**Step 4 done (2026-10-19): Atmosphere.**

| Piece | File |
|---|---|
| `AtmosphereProfile`: tonemap, exposure, ambient, glow (levels, threshold, bloom), haze, SSAO, contrast/saturation, split-tone grade, SDFGI and lantern sway. `apply(env)` sets exactly what `art_direction.gd` used to; `build_environment()` makes a whole room environment | `scripts/world/atmosphere_profile.gd` |
| `Atmosphere` node: adds an internal `WorldEnvironment` from its profile only when nothing else supplies one (in the editor: only a saved `WorldEnvironment` counts), sways lit lanterns, and offers a deterministic `tick(t)` | `scripts/world/atmosphere.gd` (the prototype's `scripts/atmosphere.gd` is a different, older file) |
| Profiles: `prototype_v011.tres` (the script defaults are the v0.11 numbers) and `reading_room.tres` (exposure 1.25, haze 0.012, darker background) | `kit/atmosphere/`, from `tools/seed_atmosphere.gd` |
| The prototype now takes its look from `prototype_v011.tres` | `scripts/art_direction.gd` (look constants removed; light constants stay) |

**Reading room:** `PreviewEnvironment` is replaced by an `Atmosphere` node
(patched in place, no other node touched). Both chandeliers are pinned `lit`
in the room's `socket_pins` (the hero lights are authored; smaller lanterns
still vary). Authored fills under `Lights` follow the warm/cool rule:
`IwanGlow` low in the iwan, plus `CoolFillWest` / `CoolFillEast` (teal) over
the back half. The builder makes the same.

**Kit fixes found while tuning:** the chandelier lit almost nothing. Its glass
shared a mesh with the brass, so it cast shadows, and its solid bottom cap
0.3 m under a shadowed light threw a ~10 m shadow disc on the floor.
`lantern_cluster` is now rev 2: glass as its own non-shadow mesh and open
ring caps, rebuilt by a `kit_rev` rule in `tools/kit_add_r01.py`. The
`chandelier` light profile gets `light_size` 0.35, so the frame posts no
longer throw hard bands across the vault.

**Verified:** the prototype is pixel-identical within render noise. Two
before-captures differ by mean 0.143 (0-255); after vs before is 0.104 and
0.198 (`tests/image_diff.gd`). `tests/room_atmosphere_test.gd` passes 32
checks: prototype profile values, the room builds and activates its own
environment, defers to an existing one, sways only lit lamps
deterministically, pins, and fills. Every other gate passes (socket modes 56,
kit 444, room 28, prototype atmosphere test), and the three 240-frame gates
are clean. The editor loads the room headless without errors. Luminance
(`tests/luma.gd`) of the entrance view went from 37 (21% near-black) before
the step to 47.6 (2%); gallery 40.0 (12%); iwan 29.5. **Caveats:** the iwan
view's lower corners (bay-4 lower recesses) stay dark teal (luma ~12-15);
ambient and SDFGI energy barely move them, so a lantern there would be the
fix. The user checked the look in the editor viewport.
Fog volumes, the prototype's foliage wind shader and water ripples were not
ported (no room uses them yet).

**Next steps for phase 1, in order:**
0. ~~**Socket panel in the Kit dock**~~ (done, see above).
1. ~~**More modules for R01**~~ (done, see above).
2. ~~**Build `rooms/authored/reading_room.tscn`**~~ (drafted by script, see above; tweak it by hand).
2b. ~~**Gallery corner / end-wall gallery**~~ (done, see above).
3. ~~**More socket sets**~~ (done, see above). Follow-up: age conditions on lamp and recess weights.
4. ~~**Atmosphere**~~ (done, see above).
5. ~~**Validate Room**~~ (done, see below).
6. ~~**Swap R01 into the game**~~ (done as a selectable room by decision, see below).

**Step 5 done (2026-10-19): Validate Room.** The Kit dock's button is now
**Validate room**. On any scene it runs the existing module checks (grid,
rotation, scale). On a `RoomTemplate` it adds the room checks below. Errors
go to the Output panel as errors and warnings as warnings, with a count in
the dock.

| Check | Severity | How |
|---|---|---|
| Open edges | error | Cells come from CELL modules per storey (floors give storey 0; the hall vault, placed one storey up, gives storey 1). Every perimeter edge, in 2 m segments, needs a *closing* EDGE module (anything but `gallery`, `gallery_end`, `stair`, `gable`) or a room connector marker on it. Multi-storey edges (the iwan) cover each storey. |
| Vault ends | error | A ceiling CELL's ends (edges across its barrel, with no vault beyond) need a `gable` edge module |
| Connectors | error | Markers under `Connectors` must lie on a cell-boundary line (x or z a multiple of 4 m) |
| Candidate fit | error | `SocketSet.slot_bounds` (new): every candidate's visual bounds must fit; ShelfFill is built with a fixed seed to measure it |
| Slot clearance | warning | Each socket's slot must not run into another module's collision |

Files: `scripts/world/kit_validate_room.gd` (`KitValidateRoom.run(root)`),
`scripts/world/socket_set.gd` (`slot_bounds`), and
`addons/kit_palette/plugin.gd`. Slots for `recess_library`, `iwan_centre` and
`table_props` are set by `tools/seed_sockets.gd` (only when empty).
`tools/kit_blender.py` gains the shared `rebuild()` for `kit_rev` bumps.

**What it found right away:** (1) a real misfit: a fallen board in the
"collapsed" recess candidate stuck 8 cm past the 3 m opening into the wall
(`recess_shelves_broken` is now rev 2). (2) Warnings, also real: in
upper-storey recesses fronted by a gallery (or a stair near its head), a
collapsed recess's spill (books and boards on the recess floor at 4.0 m)
sinks into the gallery slab, whose top is at 4.15 m. 9 in the reading room,
7 in the graybox. These are left as warnings; the fix is the first item of
the weathering slice below.

**Verified:** `tests/validate_room_test.gd` passes 17 checks. Both rooms
show no errors, and every warning is spill vs gallery or stair. Broken copies
fail as they should: a removed 4 m wall gives exactly two open 2 m segments; a
gallery slab on that edge still leaves it open; a removed gable gives both
halves of the vault end; removing the west door arch leaves only the half
the door connector doesn't mark; an off-grid connector is reported; and an
oversized candidate is flagged. All other gates pass (kit 444, socket modes
56, room 28, atmosphere 32, room playtest 11, camp playtest 43), the
240-frame gates are clean, and the editor loads the room headless without
errors.

**Found in the editor, missed headless (fixed 2026-10-19):** the first
click of Validate room in the editor reported "collapsed does not fit its
slot", which the headless test had passed. `MultiMesh.get_aabb()` and the
instance transforms live in the rendering server, which reads back empty
under the headless dummy renderer, so the test never saw the fallen books.
Now `ShelfFill` keeps `built_transforms` on the CPU and Validate Room
measures those, over 16 seeds since the spill varies. That showed the spill
reaching x ±1.6 (past the 3 m opening) and 1.3 m into the room. Fixes: the
spill is inset by a rotated book's reach (`ShelfFill`), and the recess slot
now reaches 1.35 m into the room (`recess_library.tres`, intended spill). The
test checks that the spill is measured. **Lesson:** any bound read back from
the renderer is invisible to headless gates; measure on the CPU. The user
re-ran Validate room in the editor: no errors, only the spill warnings.

**Phase 1 is complete** (steps 0-6, 2b).

**Step 6 done (2026-10-19): the reading room is playable in the game.**
**Decision (user, 2026-10-19):** R01 does *not* replace the code-built camp.
The camp (`world.gd`) holds the whole gameplay loop (hearth, cooking pot,
gathering, vista balcony), and R01 is a different place: the atlas reading
hall, not the campfire concept. So `previews/concept_v011.png` doesn't apply
as R01's target. Instead the game can boot either one:

- **How to play it:** Esc menu → **Visit the reading room** (and **Return to
  the camp**), or start with `-- --room=res://rooms/authored/reading_room.tscn`.
  The camp stays the default.
- `scripts/main.gd` loads any `RoomTemplate` scene as the world, spawns at its
  `PlayerSpawn` marker, shows its `display_name` in the HUD, and skips the
  camp-only logic (warmth, harvesting, zones, balcony) in rooms. The choice
  is a static `room_override`, so it survives `reload_current_scene()`.
  `player.gd` gains `respawn_point` (a fall puts you back at the room's spawn).
- `RoomTemplate.display_name`. The reading room gets "The Reading Room" and a
  `PlayerSpawn` (patched in place; the builder makes both).

**Verified:** `tests/room_playtest.gd` passes 11 checks with the real
`main.tscn` player driven by input actions. It boots into the room on the
spawn with the room's environment, then walks the hall into the iwan, climbs
the west stair, rounds the whole U gallery, and comes down the east stair. It
never drops below the floor, and the menu offers the way back. The camp
playtest still passes (43 checks), as do the prototype atmosphere test and
every room and kit gate. The 240-frame gates are clean for the camp, the
graybox, the room scene and `main` with `--room`. GPU captures of the real
game with HUD: `previews/game_reading_room_{spawn,gallery,iwan}.png`
(`tests/room_game_capture.gd`). The menu round trip in a
real window was checked by the user (Esc → Visit the reading room).

**Phase 1 status:** done except step 5 (Validate Room in the Kit dock). Of
the roadmap's "done when": R01 is playable in the game (as a selectable room,
by decision), and re-rolling the preview seed changes recesses, the iwan
centrepiece and lamps. The capture-vs-concept criterion was dropped with the
decision above.

