# Progress: phase 3, props and persistence

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../phase-3-approval.md), [technical](../phase-3-design.md)

**In short:** steps 1-3 are built. You can knock over or break R01's floor vases and push the things on its tables. You can pull books off any shelf, and take two lore books (with gilt bands) into your satchel and read them. The library remembers all of it after you quit, and every change keeps the thing's original place, so a future janitor can put it back.

---

## Step 1: a vase you can knock over (done 2026-10-20, approved and committed as 7472a94)

**Try it:** Esc menu → **Visit the reading room**. Walk to the far end of
the hall (bay 4, in front of the two stair feet). A tall vase stands on each
side.

- Aim at one: the HUD says **Knock over**. Press **E** and it tips onto its
  side.
- Walk into the other: it rocks and slides.
- A vase that falls hard (from about a metre or more) smashes into eight
  shards. The shards stay where they land.
- On the tables: aim at a book stack, pot, inkwell and so on (**Push**) and
  press E.

**Built:**

| Piece | File |
|---|---|
| Floor vase and its 8 pre-cut shards (Blender, UV-mapped earthenware) | `tools/kit_add_dressing.py` → `art_src/kit/kit_dressing.blend` → `assets/kit/dressing/prop_vase_floor(_broken).glb` |
| `WorldProp`: frozen at rest; wakes on E, a bump, a hit or the prop under it waking; re-freezes after 2 s still; budget 48; breaks on a hard jolt | `scripts/world/world_prop.gd` |
| `Shards`: each shard mesh becomes a small body, launched with the prop's motion; each freezes when still | `scripts/world/shards.gd` |
| `PropSettings` (budget, re-freeze time, break speed, push speed, bump share, roll damping, shard scatter) | `scripts/world/prop_settings.gd`, `world/props/prop_settings.tres` |
| Prop scenes: the vase, its shards, and the six table props as `WorldProp`s | `props/*.tscn` |
| `table_props` socket set now spawns the `props/` scenes | `kit/sockets/table_props.tres`, `tools/seed_sockets.gd` |
| Two vases in R01 (`Props/VaseIwanWest`, `VaseIwanEast`) | `rooms/authored/reading_room.tscn` (edited as text) |
| Player on layer 4 (it was on 3 by mistake), collides with props, shoves what it walks into; ray sees props | `scripts/player.gd` |
| E calls the target's `interact()`; the HUD asks `interaction_prompt()`; notes and menu say nothing is remembered yet | `scripts/main.gd` |
| Physics layer names (§6.4) | `project.godot` |

**Changed from the design while building:**

- **Vase position.** The design put them either side of the iwan mouth, but
  there the wall is 20 cm behind them. E pushes toward the wall, so the vase
  leaned into it and rocked back upright. They now stand on open floor in
  bay 4, in front of the stair feet (x 2.2 and 9.8, z -16.6), clear of every
  test route.
- **Prop textures.** Most table props use world-triplanar library materials,
  which would slide over a moving prop. A `WorldProp` swaps each one for an
  object-space copy at load: the same 32 tx/m density, but the texture moves
  with the prop. The vase is UV-mapped.
- **Centre of mass.** Godot's automatic centre of mass is the body origin,
  which for a prop is the floor under it, so a vase could never tip. It's
  now the middle of the prop's meshes.
- **Rolling.** Godot has no rolling resistance, so a vase on its side rolled
  for ages. Props and shards get angular damping (`roll_damp` 2.0).
- **What breaks a prop:** the jolt of one physics step (the change of
  velocity, with the change of spin counted at half height). The prop's own
  pushes are ignored. Tipping over from standing doesn't break the vase;
  falling about a metre does. Lower `break_speed` on the vase scene if
  tipping should smash it too.
- **Shard budget:** not built. Two vases don't need it. It comes with props
  in generated rooms.

**Gates (all pass):**

- `prop_test` (new), 51 checks:
  - every prop is frozen static on layer 3, with a hull and no world-mapped
    material, and nothing moves at rest;
  - player and ray layers;
  - E tips the vase over (it lies at about 102°), it freezes again, and it
    leaves the awake list;
  - dropped from 1.5 m it breaks into 8 pieces that land nearby and freeze;
    set down from 3 cm it doesn't break;
  - pushing a crate wakes the pot on it;
  - with a budget of 3, waking a fourth prop freezes the oldest sleeper.
- `room_playtest`, 25 checks (was 18). The real player aims at the west vase
  (prompt "Knock over") and E knocks it over. Walking into the east vase
  shoves it. Then everything freezes again, and the player stays on the
  floor.
- `kit_test` 906, `socket_modes_test` 246, `reading_room_test` 87,
  `validate_room_test` 26, `r02_bake_test` 105, camp `playtest` 43,
  `spill_settle_test` 6, `room_atmosphere_test` 32, `atmosphere_test` 9.
- `r02_route_test`: 2321 checks, 0 failures (all three doors, 20 seeds each, and the three-door case).
- 240-frame headless runs, all clean:
  - `main` (camp);
  - `main` with R01, R01+R02 and the three-door scene;
  - the R01, `Multrooms-test1` and graybox scenes.
- **Frame time** (GPU, 240 frames, vsync off, entrance view): 1.66 ms with
  every prop frozen, against 1.67 ms with every prop removed in the same
  run. Polish C measured 1.63-1.99 ms.
- GPU captures (`tests/prop_capture.gd`):
  - `previews/p3s1_vases.png`: the west vase at the stair foot;
  - `p3s1_falling.png`: just after the push, leaning;
  - `p3s1_fallen.png`: on its side;
  - `p3s1_shards.png`: the east vase dropped and broken;
  - `p3s1_table.png` and `p3s1_table_pushed.png`: a pot pushed over on a
    table.

**Caveats:**

- **Bay 4 is dim,** so the vases and the shards read dark in the captures.
  A lantern near the stair feet, or vases somewhere better lit, would show
  them off. Say if you want either.
- **Small table props are light and need a firm push.** One E knocks a pot
  over but often leaves it on the table rather than sending it off.
  `push_speed` and the masses are the knobs.
- **Walking into a prop:** you shove it, but a heavy prop also stops you
  for a step while it wakes.
- **Not checked by hand:** the feel in a real window (E and walking into
  props). That's yours to try.

## Step 2: it stays knocked over (done 2026-10-20, approved and committed as 2c60c70)

**Try it:**

1. Esc → **Visit the reading room**. Knock the west vase over, break the
   other one, and push something off a table.
2. Esc → **Quit**.
3. Start the game again. You're back in the reading room, where you stood,
   with the vase on its side, the shards on the floor and the prop where it
   landed.

Two new menu entries:

- **Tidy up (janitor test: N changed)** puts everything back as it was: the
  vases stand, the broken one is whole again, the prop is back on its
  table. Quit and restart: it stays tidy.
- **Forget this library** deletes the save and starts the world over.

The save is `user://saves/slot0.json`:
`%APPDATA%\Godot\app_userdata\<project name>\saves\slot0.json`. It's
readable JSON.

**Built:**

| Piece | File |
|---|---|
| `WorldState` autoload: the save file, deltas, `revert`/`revert_room`/`changed_ids`, the `reverted` and `saving` signals, stale ids, `--save=` / `--fresh` | `scripts/world/world_state.gd`, `[autoload]` in `project.godot` |
| JSON transform helpers | `scripts/world/world_state_data.gd` |
| Rooms give each prop its id (`room_id@seed/path`, socket spawns `…/SOCKET_x#n`), lay the deltas over the build, record new ones when props settle or shards come to rest, and put things back (`revert_thing`) | `scripts/world/room_template.gd`; `scripts/gen/generated_room.gd` calls `restore_world()` after it builds |
| Sockets: settling skips restored props and records a spawn's settled spot as its original; spawn numbers never shift; `respawn()` for a reverted broken prop | `scripts/world/variant_socket.gd` |
| `moved_epsilon` (1 cm) and `moved_epsilon_deg` (1°) | `scripts/world/prop_settings.gd` |
| Resume the saved scene, gallery seed and pose on the first boot; save on Quit, window close and travel; the two menu entries; notes text | `scripts/main.gd` |

**Original places, for a future janitor (your request):**

- The original is never overwritten: rooms are rebuilt as authored and
  the save only holds changes on top, so dropping a change restores the
  original.
- Each change also keeps the thing's original transform and scene, so it
  can be put back while you're standing in the room. A broken vase is
  rebuilt whole.

The API is in [phase-3-design.md §6.5.9](../phase-3-design.md).

**Changed from the design while building:**

- **Tests never touch your save.** Test scripts and headless runs use
  `user://test/scratch.json`, starting fresh, unless they pass `--save=`.
- **`main.gd` reaches the autoload through `ws()`.** Test scripts compile
  `main.gd` before autoload names exist, so a bare `WorldState` identifier
  failed to compile there.
- **A prop that comes to rest back in its original place leaves no delta.**
- **Socket spawns that settle onto nothing are now left as empty slots**
  rather than removed from the list, so later spawns keep their numbers
  (their save ids).

**Gates (all pass):**

- **The persistence gate** (`sh tests/persist_gate.sh`): three separate OS
  processes, R01 + stack gallery, seed 7.
  - `save` (10 checks): E knocks the west vase over, the east one is
    dropped and breaks, a table prop is pushed off. Each is saved with the
    right kind and the vase's original place. A delta that matches nothing
    is planted, the player moves, and the game quits through its own save.
  - `load` (20 checks): a new process resumes the scene, gallery seed 7 and
    the player's place.
    - The vase is where it was knocked over, within 1 cm and 1°.
    - The east vase is gone, and its 8 shards lie where they fell, frozen.
    - The table prop is where it landed, and its socket's settle leaves it
      alone.
    - Only the planted id is stale: kept, not applied.
    - Nothing wakes or moves over 120 frames.
    - Then `revert_room` puts all 4 back, with 4 `reverted` signals. Both
      vases stand in their places, the broken one whole, with no shards.
      The prop is back on its table, and no changes are left.
    - A nudge that settles in place adds no delta.
  - `reverted` (5 checks): a third process finds no changes and everything
    original.
- `prop_test` 51, `room_playtest` 25, `kit_test` 906, `socket_modes_test`
  246, `reading_room_test` 87, `validate_room_test` 26, `r02_bake_test` 105,
  camp `playtest` 43, `spill_settle_test` 6, `room_atmosphere_test` 32,
  `atmosphere_test` 9.
- `r02_route_test`: 2321 checks, 0 failures.
- 240-frame headless runs, all clean:
  - `main` (camp);
  - `main` with R01, R01+R02 and three doors;
  - the `Multrooms-test1` and graybox scenes.
- **GPU, the same view in both processes** (`tests/persist_capture.gd`):
  `previews/p3s2_before_quit.png` and `p3s2_after_restart.png`.
  `image_diff` gives a mean of 0.18, with 0.10 % of pixels differing by
  more than 8. That's render noise: the restored room looks the same.

**Caveats:**

- **The capture view is wide and bay 4 is dim,** so the fallen vase and the
  shards are small and dark in it. The pixel match is the proof; the
  picture isn't a showcase.
- **Only props are saved so far.** Books (step 3) and lamps (step 4) come
  next.
- **The camp is unchanged.** Its gatherables regrow (Q5). The satchel is
  saved from step 3.
- **Resuming applies to the first start of the game only.** Menu trips
  between rooms still land on the room's spawn.
- **Not checked by hand:** quitting and restarting in a real window, and
  the two new menu entries.

## Step 3: pull a lore book and take it (built 2026-10-20, waiting for your review)

This meets the first half of phase 3's finish line: knock over a vase, pull
a lore book and take it, quit, and in a new process both stay changed.

**Try it:**

1. Esc → **Visit the reading room**. Walk to the west wall by the entrance
   (the first recess on your left) and look at the shelves at eye height.
   One spine is taller, with a **gold band**.
2. Aim at it: **Pull out The Hollow Index**. E slides it half out, then
   **Take The Hollow Index**, then E again.
3. Press **J**: the field notes have a **Satchel** section and a **Read:
   The Hollow Index** button.
4. The second lore book, **On Lamps That Remember**, is upstairs in the
   first recess on the west gallery.
5. Any other book: **Pull out a book**, then **Pull off**, and it drops at
   your feet.
6. Quit and restart. The slot stays empty, the book stays in your satchel,
   and pulled books stay where they fell.

**The two lore texts are placeholders I wrote** (each starts with
"Placeholder text: replace or approve"). They're in
`items/lore/lore_hollow_index.tres` and `lore_lamps_remember.tres`, in the
`text` field, editable in the Inspector.

**Built:**

| Piece | File |
|---|---|
| `ItemDef` (id, name, kind, stack, unique, spine colour, text); `ItemDef.find(id)` | `scripts/world/item_def.gd`, `items/lore/*.tres`, `items/ingredients/*.tres` |
| `LoreBookPin` (recess socket, shelf, x, item); `RoomTemplate.lore_books`; R01's two pins | `scripts/world/lore_book_pin.gd`, `scripts/world/room_template.gd`, `rooms/authored/reading_room.tscn` (as text) |
| `ShelfFill`, part 1: per-book shelf level and colour; lore books appended after the random books (books in the slot shrink to nothing; indices never move) | `scripts/world/shelf_fill.gd` |
| `ShelfFill`, part 2: a `Reach` body per shelf on layer 2 (the ray finds a book; it never blocks you); highlight; `pull`, `make_book`, `hide_book`, `unhide_book` | `scripts/world/shelf_fill.gd` |
| `WorldProp.item` ("Take …" puts it in the satchel), `pull_toward` ("Pull off" brings a book toward you), the `taken` signal | `scripts/world/world_prop.gd` |
| Satchel in the save (`add_item`, `owns`, `item_count`, `set_count`, `owned_items`); a janitor can't revert a taken item | `scripts/world/world_state.gd` |
| Rooms save pulled books (`moved`) and taken ones (`taken`), and restore them on load | `scripts/world/room_template.gd` |
| J notes **Satchel** + **Read**; "Took … J: read it in your satchel."; camp ingredients saved; Begin another outing empties the ingredients but keeps lore books | `scripts/main.gd` |
| Validate Room: a lore pin's recess must be room-pinned to full or sparse shelves | `scripts/world/kit_validate_room.gd` |

**Changed from the design while building:**

- **A lore book's save id is its place:**
  `reading_room@1/<recess socket>#lore:lore_hollow_index`, not
  `lore:<id>`. A janitor can then see which shelf it came from. The satchel
  still holds it only once (unique).
- **Ordinary books, second E is "Pull off", toward you.** The shelf boards
  have no collision, so pushing a book into the shelf would drop it inside
  the recess.
- **Lore book look:** 0.34 m tall (the gap under a board is 0.37), with a
  gold band two-thirds up. The leather map darkens instance colours, so the
  spine and band are tinted above 1 on the shelf. The pulled book's band is
  a plain gold with a faint glint.
- **Correction to my earlier note:** the HUD does have four numbered slots
  (three ingredient counts and the notes icon), but they're display only.
  Nothing selects or uses them, so "no quick slots" holds as behaviour.

**Gates (all pass):**

- `book_test` (new), 27 checks:
  - the ItemDefs are right;
  - for 20 seeds, a lore pin adds two instances at the end and only shrinks
    the 1-3 books in its slot;
  - R01's lore pins validate, and both recesses hold their book;
  - the Reach is on layer 2 only;
  - aiming finds the book and names it;
  - a pull is half out, frozen, tracked by shelf and index, with an
    object-space material;
  - "Pull off" lands it on the hall floor;
  - the lore book keeps its band; Take puts it in the satchel and empties
    the slot; the save says taken; a janitor can't revert it;
  - Validate Room flags a lore pin on an unpinned recess.
- `room_playtest`, 31 checks. The real player and ray aim at the gilt
  spine: "Pull out The Hollow Index", E, "Take The Hollow Index", E. Then
  it's in the satchel, and J offers Read, which opens it.
- **The persistence gate** (`sh tests/persist_gate.sh`), three OS
  processes:
  - `save` (15): adds pulling and taking the lore book, and a gallery book
    pulled off onto the gallery floor, saved under the gallery's own key.
  - `load` (26): the lore slot is empty and can't be pulled again; the
    book is still owned and Read opens it; the gallery book lies where it
    fell, with its slot empty. `revert_room` puts back the 4 things it can
    and leaves the taken lore book.
  - `reverted` (6): the lore book is still taken and owned, and the gallery
    book is still down.
- `prop_test` 51, `kit_test` 906, `socket_modes_test` 246,
  `reading_room_test` 87, `validate_room_test` 26, `r02_bake_test` 105,
  camp `playtest` 43, `spill_settle_test` 6, `room_atmosphere_test` 32,
  `atmosphere_test` 9.
- 240-frame runs, all clean:
  - `main` (camp);
  - `main` with R01, R01+R02 and three doors;
  - the `Multrooms-test1` and graybox scenes.
- `r02_route_test`: 2321 checks, 0 failures.
- GPU captures (`tests/book_capture.gd`, the real game with its HUD):
  - `previews/p3s3_aim.png` and `p3s3_aim_zoom.png`: the gilt spine with
    "Pull out The Hollow Index";
  - `p3s3_pulled.png` and `p3s3_pulled_zoom.png`: half out, "Take The
    Hollow Index";
  - `p3s3_taken.png`: the empty slot;
  - `p3s3_satchel.png`: J with the Satchel;
  - `p3s3_read.png`: the book open.

**Caveats:**

- **The highlight is only 2 cm.** It's hard to see at a distance; the
  prompt is the real cue. Say if you want something stronger (a brighter
  tint, or a bigger slide).
- **The lore spine still reads olive in R01's warm light,** but the gold
  band gives it away.
- **A gallery column stands close to the entrance recess,** so the capture
  is partly blocked. The column is in the room; you can step around it.
- **Collapsed (fallen) recesses can't be pulled from,** as designed.
- **Generated galleries have no lore books yet.** A grammar `lore_chance`
  comes later.
- **Not checked by hand:** the feel in a real window.
