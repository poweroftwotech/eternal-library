# Phase 3 design: props and persistence (technical)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **approved 2026-10-20 (Q1–Q9 as recommended); step 1 in progress** ·
Plain-language version: [phase-3-approval.md](phase-3-approval.md)

This is the engineering detail behind the approval brief: classes, ids, save
format, load order and gates. You don't need to read it to approve. Its
section numbers (§6.5.x) continue the architecture's §6.

---

### 6.5 Phase 3 design: props and persistence (approved 2026-10-20)

Done when (§10): knock over a vase, pull a lore book and take it, quit; in a
new process both stay changed. Advancing the world clock darkens untouched
lamps only.

**What exists today.**

- `scripts/interactable.gd`: a bare `StaticBody3D` on layer 2 with an id and a
  title. The player's ray (4 m, mask 1+2) finds anything with
  `get_interaction_id()`. `main.interact()` returns early in rooms.
- Inventory: `main.gd` holds `{"mushroom", "root", "herb"}` counts. There is no
  item resource, no quick-slot code and no save of any kind.
- `ShelfFill`: deterministic from its socket's `seed` meta. Books are
  `built_transforms[i]` on the CPU, with no collision. Spill settles after two
  physics frames.
- `LampState`: `lit` / `failing` / `dark` from a `STATE` socket
  (`lamp_state.tres`). R01 pins its two chandeliers to `lit`. R02 pins far
  lamps through `generated_pins`.
- `table_props` (SCATTER, 2-5 items per reading table) spawns `prop_pot`,
  book stack, open book, scroll, inkwell and oil lamp. They're KitModule
  scenes that use mesh UVs (`earthenware.tres` isn't triplanar). R01's
  `Props` node is empty.
- Socket spawns are internal children with engine-generated names, so a
  spawned item's node path isn't stable. Its socket path is.
- **Layer bug:** `player.gd` sets `collision_layer = 4`, which is bit value
  4, so layer 3 (props in §6.4), not layer 4. Slice 1 fixes this.

#### 6.5.1 Classes and resources

| Piece | Kind | File | Holds |
|---|---|---|---|
| `WorldProp` | `RigidBody3D` (`class_name`) | `scripts/world/world_prop.gd` | `prompt`, `push_impulse`, `breakable`, `broken_scene`, `break_speed`, `item: ItemDef` (null = a plain prop), `ageless`. Frozen at rest; wakes, sleeps, re-freezes; reports its delta |
| `PropSettings` | `Resource` | `world/props/prop_settings.tres` | `active_budget` 48, `sleep_refreeze_s` 2.0, `moved_epsilon` 0.01 m / 1°, `default_break_speed` 3.0 m/s, `shard_budget` 64 |
| `PropDirector` | static on `WorldProp` | (same file) | The awake list and the budget: past `active_budget`, re-freeze the oldest *sleeping* prop. Cleared when the scene changes |
| `Shards` | `Node3D` root of a broken scene | `scripts/world/shards.gd` | Its children are `RigidBody3D` pieces. They inherit the parent's velocity, sleep, then freeze in place and report their transforms |
| `ItemDef` | `Resource` | `scripts/world/item_def.gd`, data in `items/**/*.tres` | `id: StringName` (unique), `display_name`, `kind` (`lore`, `ingredient`, `tool`), `stack_max`, `unique`, `prop_scene` (to drop it), `spine_colour` (lore books), `text` (BBCode, lore books) |
| `Inventory` | `RefCounted` | `scripts/world/inventory.gd` | `stacks: Dictionary[StringName, int]` and `owned: Array[StringName]` for unique items. `add`, `remove`, `has`, `to_dict`, `from_dict`. Ingredients become `ItemDef`s, so the camp and the rooms share one satchel |
| `LoreBookPin` | `Resource` (sub-resource on the room) | `scripts/world/lore_book_pin.gd` | `socket: String` (recess socket path), `level: int`, `x: float` (along the shelf), `item: ItemDef` |
| `ShelfFill` changes | existing | `scripts/world/shelf_fill.gd` | `lore: Array[LoreBookPin]`, set by the room before build. A shelf `StaticBody3D` on layer 2, one thin box per level (internal child). `hidden: PackedInt32Array`. `promote(index) -> WorldProp` |
| `RoomTemplate` changes | existing | `scripts/world/room_template.gd` | `lore_books: Array[LoreBookPin]`, `room_key()`, the age and delta pin layers in `resolve_sockets`, and `restore()` after resolve |
| `AgeRule` / `AgeRules` | `Resource` | `scripts/world/age_rules.gd`, `world/strata/stratum1_age.tres` | Per rule: `socket_set` (e.g. `lamp_state.tres`), `chain: PackedStringArray` (`lit, failing, dark`), and one `Curve` per step (years → chance) |
| `LampTend` | `StaticBody3D`, internal | `scripts/world/lamp_tend.gd` | Added by a `STATE` socket on `lamp_state`: a 0.35 m sphere on layer 2 at the glass (the emit surfaces' AABB centre). "Light the lamp" / "Douse the lamp" |
| `WorldState` | autoload (no `class_name`) | `scripts/world/world_state.gd` | Save path, `world_seed`, `clock_days`, `inventory`, `areas`, the last scene and player pose. `load_save()`, `save_now()`, `mark_dirty()` (1 s debounce), `delta(id)`, `set_delta(id, d)`, `restore_room(room)` |
| `AreaState` | `RefCounted` | `scripts/world/area_state.gd` | One area's deltas `{id: delta}` and its `spawned` list (dropped props) |
| Interaction contract | duck-typed | `player.gd`, `main.gd` | `interaction_prompt(hit: Vector3) -> String` and `interact(actor: Node, hit: Vector3) -> void`. The old `get_interaction_id()` stays for the camp. `main.interact()` calls `interact()` in rooms |

**Collision layers** (named in `project.godot`): `WorldProp` is on layer 3
with mask 1+3. Shards are on layer 3 with mask 1. The player moves to layer 4
(value 8) with mask 1+3. The interaction ray uses mask 1+2+3. `ShelfFill`'s
shelf boxes and `LampTend` are on layer 2 only, so they never block movement.

**Wake and sleep.** A `WorldProp` is `freeze = true`
(`FREEZE_MODE_STATIC`). It wakes on:

- an `interact` push: an impulse along the view ray, at the hit point;
- player contact: `player.gd` reads its slide collisions after
  `move_and_slide()` and wakes and pushes any `WorldProp` it hit, scaled by
  speed and capped by mass;
- a shard or another prop hitting it (`contact_monitor` on while awake);
- the prop under it waking: on wake, a box query just above its AABB wakes
  whatever rests on it.

Once awake it is in `PropDirector`'s list. After `sleeping` has been true
for `sleep_refreeze_s` it freezes again and calls
`WorldState.set_delta(id, …)` if its transform moved more than
`moved_epsilon` from its spawn transform.

**Breaking.** While awake, `_integrate_forces` tracks the largest contact
impulse divided by mass. Above `break_speed`:

1. instance `broken_scene` at the prop's transform and give the shards its
   velocity;
2. free the prop;
3. once the shards are frozen, save `{s: broken, shards: [transform …]}`.

Shards stay where they come to rest. They aren't despawned, so a returning
player sees the mess (open decision Q3). Over `shard_budget`, the oldest
shard set merges into one static `MultiMeshInstance3D`.

**Textures on props.** A `WorldProp` asserts in `_ready` (and `kit_test`
checks) that no material under it is world-triplanar. The
`kit_px_world.gdshader` materials are world-space, so props keep the
UV-mapped `StandardMaterial3D` library materials they use today.

#### 6.5.2 Stable ids

An id is `room_key / path [# index]`. It is unique within an area, and
`AreaState` is per area.

- **`room_key`** is `room_id + "@" + seed`. The seed is `current_seed()` for
  an authored room and `effective_seed()` for a generated one. A gallery's
  contents depend on its seed, so a reseeded gallery starts clean, and going
  back to the old seed brings back its changes. For R01 that's
  `reading_room@1` (its `preview_seed`). From phase 4 the seed is the area
  seed, which is fixed for a world. See Q1 for the alternative (authored
  props keyed by `room_id` alone).
- **`path`** is relative to the room root, and it stops at a nested room, as
  `sockets()` does, so R01's ids don't change when galleries are joined
  under it.

| What | Id | Why it's stable |
|---|---|---|
| Authored prop (R01 `Props/VaseIwanWest`) | `reading_room@1/Props/VaseIwanWest` | An owned node in the scene file. Renaming it in the editor orphans its delta (see stale ids) |
| Socket-spawned prop (a table's pot) | `reading_room@1/Dressing/table_reading2/…/SOCKET_table_props#2` | The socket path is stable (phase 1). `#2` is the spawn ordinal in `VariantSocket._children`, deterministic for a seed |
| Shelf book | `<room_key>/<recess socket path>#b37` | `#b37` is the index in `ShelfFill.built_transforms`. That's deterministic for the socket seed. Hidden books keep their index: they are zero-scaled, never removed |
| Lore book | `<room_key>/<recess socket path>#lore:<ItemDef.id>` (as built, step 3) | Its place, so a janitor knows the shelf; the satchel still holds a unique item only once |
| Generated-room prop or socket | `stack_gallery_west@7/Shell/wall_x-1_z2_W/…#n` | Grid-key names (5.5.1) |
| Baked room | `stack_gallery_west@7/…` | The baked root keeps `room_id`, `preview_seed` = the seed, and the same node names (5.5.10). So a bake inherits the live gallery's deltas for that seed, and validates against them (below) |
| Lamp (STATE socket) | `<room_key>/<lantern socket path>` | The socket path |
| Dropped item | `drop:<counter>` in the area's `spawned` list | Allocated by `WorldState`, saved with its item id and transform |

**Stale ids.** A delta whose node is gone (the room was edited or re-baked)
is kept in the save, never applied, and counted. Then:

- `WorldState.stale_count()` and the Esc menu's debug line show the count;
- `persist_test` asserts zero stale ids on its fixture;
- Validate Room gains an optional check against a save file (`--save=`):
  "these deltas no longer resolve".

#### 6.5.3 Save format and load order

**One JSON file per slot**: `user://saves/slot0.json`. JSON keeps it
human-readable and diffable. `--save=<path>` overrides the path, and every
test uses its own path, so a test never clobbers your save. `--fresh` ignores
an existing file. Writes go to `<path>.tmp` and are then renamed.

```json
{
  "version": 1,
  "world_seed": 1,
  "clock_days": 0.0,
  "scene": "res://rooms/test/reading_room_r02.tscn",
  "player": {"pos": [6.0, 0.1, -3.0], "yaw": 3.14, "pitch": -0.1},
  "gen_seed_override": -1,
  "inventory": {"stacks": {"mushroom": 2}, "owned": ["lore_hollow_index"]},
  "areas": {
    "library": {
      "deltas": {
        "reading_room@1/Props/VaseIwanWest": {"s": "broken", "shards": [[1,0,0, 0,1,0, 0,0,1, 3.1,0.0,-19.2]]},
        "reading_room@1/Props/VaseIwanEast": {"s": "moved", "xf": [1,0,0, 0,1,0, 0,0,1, 8.9,0.0,-19.0]},
        "reading_room@1/Shell/.../SOCKET_recess_library#b37": {"s": "moved", "xf": [...]},
        "lore:lore_hollow_index": {"s": "taken"},
        "reading_room@1/Lights/lantern_hanging3/.../SOCKET_lamp_state": {"s": "state", "label": "lit", "day": 0.0}
      },
      "spawned": []
    }
  }
}
```

Delta kinds:

| `s` | Fields | Meaning |
|---|---|---|
| `moved` | `xf` | A prop, or a promoted shelf book, at rest somewhere else |
| `broken` | `shards` | The prop is gone; its pieces lie here |
| `taken` | none | It's in the inventory, or was eaten |
| `state` | `label`, `day` | The player set a STATE socket (tended a lamp) |

Transforms are 12 floats, basis columns then origin, in the room's frame.
So a room that moves in its parent (a gallery on another door) still
restores its own deltas correctly.

The **area id** is `library` until phase 4's `AreaRecipe` names areas. The
camp's gatherables aren't saved in phase 3 (the camp is code-built), but the
satchel is (Q5).

**Load order** (each room on its own, outer room first):

1. `WorldState` (autoload) reads the save before `main.tscn` is ready.
2. `main._ready` picks the scene: `--room=` beats the saved `scene`, which
   beats the camp (Q4). The gallery seed override comes from the save if the
   command line doesn't set one.
3. The room enters the tree. A `GeneratedRoom` generates.
4. `resolve_sockets` decides each socket's index through these pin layers,
   strongest first:
   1. the player's `state` delta
   2. aging (6.5.6), which only moves later along its chain from the base
      pick
   3. the base pick: `socket_pins`, then `generated_pins`, then style, then
      seed

   Then it spawns once. The pick is split out of `VariantSocket.resolve()`
   into a pure `pick_index(seed, pin, style)`, so aging can see the base
   pick without spawning twice.
5. `RoomTemplate.restore()` calls `WorldState.restore_room(self)`:
   - `moved`: the prop gets its transform, still frozen;
   - `broken`: the prop is freed and its frozen shards spawn;
   - `taken`: the prop is freed, or the shelf book is hidden;
   - promoted books are spawned as frozen `WorldProp`s at their `xf`;
   - then the area's `spawned` props for this room are added.

   Each restored node gets the meta `restored`.
6. Deferred settling (`ShelfFill.settle`, `VariantSocket.settle_items`, two
   physics frames later) skips nodes with `restored`, so it never moves a
   restored prop.
7. The player pose is restored last, once floors exist.

**When it saves:** each `set_delta` and inventory change calls
`mark_dirty()`, and the save is written within 1 s. It also saves on Quit,
on window close (`NOTIFICATION_WM_CLOSE_REQUEST`, handled in `main.gd`),
before `travel()`, and when the clock advances. The Esc menu gains
**Forget this library**, which deletes the slot and starts fresh. **Begin
another outing** keeps today's meaning: it restarts the camp loop and keeps
the world.

#### 6.5.4 Book promotion with ShelfFill

- **Looking:** the player's ray hits a shelf level box (layer 2) on a
  `ShelfFill`. `interaction_prompt(hit)` finds the nearest visible book on
  that level by x (the box's local hit point). The prompt reads "Pull out a
  book", or "Pull out *<title>*" for a lore book. That book is highlighted by
  sliding its instance 2 cm forward in the MultiMesh. Nothing spawns from
  looking alone.
- **First E: pull.** The book's instance is hidden (zero scale, same index).
  A `WorldProp` book (a `BoxMesh` of the instance's size, tinted with its
  colour through `instance_shader_parameter`, `book_leather` UVs) spawns in
  its place. It tweens 45 % of its depth out over 0.25 s, then freezes. Its
  centre of mass stays over the board, so it rests sticking out of the
  shelf. Delta: `moved`, with the pulled transform.
- **Second E on the pulled book:** a lore book says "Take *<title>*", goes
  into the satchel, and its delta becomes `taken`. An ordinary book says
  "Push", wakes, and falls; its delta is wherever it comes to rest. Walking
  into it works too.
- **Lore books** are `RoomTemplate.lore_books` pins (`LoreBookPin`: recess
  socket path, shelf level, x, `ItemDef`). Before a recess's `ShelfFill`
  builds, the room passes it the pins for its socket. `build()` keeps every
  random draw unchanged, then:
  - zero-scales the ordinary books that overlap the pin's slot (their indices
    stay);
  - appends the lore book as one extra instance: taller, with the item's
    `spine_colour` and a gilt band colour.

  So no other book moves when a lore pin is added. The lore book's id is
  `lore:<id>`, not its index.
- **Validate Room** errors if a lore pin's socket isn't room-pinned to a
  shelf candidate (`full` or `sparse`). Otherwise a reroll could turn the
  recess into a tile panel and the lore book would vanish.
- **Collapsed recesses** (fallen spill) aren't promotable in phase 3.
  Their books have no shelf.
- **Generated rooms:** promotion works unchanged, because ShelfFills come
  from the same recess sockets. Lore pins in generated rooms come later (a
  grammar `lore_chance`), not in phase 3.
- **Cost:** a promoted book is one body. The budget covers the ones that are
  awake.

#### 6.5.5 Which props R01 gets first

| Prop | Where | Kind | Slice |
|---|---|---|---|
| **Two tall floor vases** (new `prop_vase_floor` + pre-fractured `prop_vase_floor_broken`, 6-8 shards, in `kit_dressing.blend` via the additive `tools/kit_add_dressing.py`; UV-mapped `earthenware`; `-convcolonly` hull) | `Props/VaseIwanWest` and `VaseIwanEast`, on the hall floor either side of the iwan mouth, clear of the hall walk (the reading_room_test route) | Breakable `WorldProp`, about 6 kg | 1 |
| **Table props** (pot, book stack, open book, scroll, inkwell, oil lamp) | The existing `table_props` sockets on the four tables | `WorldProp` scenes: `table_props.tres` entries point at new `props/*.tscn`, and the KitModule scenes stay for the catalog. Pushable, not breakable in phase 3 (Q6) | 1 |
| **Shelf books** | All 16 recesses (`full` / `sparse` picks) | Promotable | 3 |
| **Two lore books** | One in a ground-floor recess near the entrance, at eye height. One on the gallery, so taking it means climbing. Both recesses are room-pinned to `full` | `ItemDef` `lore` | 3 |
| **Tendable lamps** | The four under-gallery `lantern_hanging` (glass at about 2.6 m, within reach) and the oil lamps on the tables. The chandeliers and the iwan lamp are out of reach | `LampTend` | 4 |

The R02 galleries get shelf-book promotion (slice 3) and tendable lamps where
they're in reach (slice 4) for free. Props on their floors come later.

#### 6.5.6 Aging: `AgeRules` and the world clock

- **Clock:** `WorldState.clock_days`. It doesn't run in real time in
  phase 3. It moves only through:
  - the Esc menu's **Let ten years pass** (a test button, shown in rooms);
  - `--advance-years=N` on the command line.

  Both save at once.
- **Rules:** `world/strata/stratum1_age.tres`, one `AgeRule` in phase 3:
  `lamp_state` with the chain `lit → failing → dark`. Its curves give the
  chance of `failing` within 5 years (0.35) and of `dark` within 30 years
  (0.8), both from year 0 and rising smoothly. Recess and growth rules
  (`full → sparse`, heavier growth) are listed as later rules and are not
  built in phase 3.
- **No stored aging state:** each aged socket draws a fixed
  `u = hash01(world_seed, room_key, socket path, "age")`. The step is the
  furthest one whose `curve(years) > u`, and the result is
  `max(base pick, aged step)` along the chain. That makes aging:
  - deterministic: the same years give the same result in any process;
  - monotone: more years never relight a lamp;
  - free to save: only the clock is stored.
- **Untouched only:** a socket with any player delta under its path is
  skipped. That's a tended lamp, or a recess the player has pulled books
  from. A prop with `ageless`, or a socket with meta `ageless`, is skipped
  too, which is how a designer keeps a landmark lamp lit. So "darkens
  untouched lamps only" holds by construction.
- **Tending** sets a `state` delta: **Light the lamp** (`lit`) or **Douse
  the lamp** (`dark`), with the day. It re-applies through `LampState.apply`
  at once, without re-resolving the room.
- **Years for a room:** `clock_days / 365` since day 0, so a room you first
  enter in year 30 is already aged. Per-room "last seen" dates are left to
  phase 4, when settlements change hands.

#### 6.5.7 The persistence gate (two OS processes, then a third)

`tests/persist_test.gd` follows `room_playtest`'s pattern: the real
`main.tscn` and player, driven by input actions. Its mode comes from user
args. Every process uses `--save=user://test/persist.json`, never the real
slot, and the room `reading_room_r02.tscn` with `--gen-seed=7`.
`tests/persist_gate.sh` runs the three processes in order and fails if any
of them fails.

1. **`-- save`** (with `--fresh`):
   - push `VaseIwanWest` hard enough to break it, and nudge `VaseIwanEast`
     over;
   - wait until every body has re-frozen;
   - pull and take the ground-floor lore book;
   - pull one ordinary book in the gallery off R01 and push it to the floor;
   - tend one R01 lantern;
   - check that the inventory has the book, then quit through the menu's
     Quit path.

   It records the expected transforms and states in a sidecar
   `persist_expect.json`.
2. **`-- load`** (a new process, same save):
   - the west vase is gone and its shards lie within 1 cm and 1° of what
     was saved;
   - the east vase is at its saved transform;
   - the lore slot is empty, and the book is in the satchel with readable
     text;
   - the gallery book is on the floor and its shelf instance is hidden;
   - the tended lamp is `lit`;
   - zero stale ids;
   - no prop is awake after 120 frames (nothing restored falls or jitters).
3. **`-- age`** (a third process, `--advance-years=40`):
   - every untouched lamp in R01 and the gallery is at its base step or
     later along the chain, and at least half are `dark`;
   - the tended lamp is still `lit`;
   - every non-lamp socket pick equals the `load` run's;
   - the vase and the book are still changed;
   - a second `-- age` process gives identical lamp states (determinism).

The 3-strike rule applies per mode.

#### 6.5.8 Slices (each one playable, reviewed before the next)

1. **A vase you can knock over.**
   - Build: `WorldProp` (wake on push and contact, sleep, re-freeze,
     budget, break), `Shards`, `PropSettings`, the interaction contract,
     the layer fix and layer names, and `prop_vase_floor` with its
     `_broken` shards. R01's two vases and the table props become
     `WorldProp`s. HUD prompts "Push" and "Knock over".
   - Play: walk into a vase or press E. It rocks or falls, and smashes if it
     falls hard. Books, pots and inkwells on the tables can be pushed off.
   - Gates:
     - new `tests/prop_test.gd`: frozen at rest, wakes on impulse and on a
       body landing on it, re-freezes after `sleep_refreeze_s`, the budget
       re-freezes the oldest sleeper at 49, breaks above `break_speed` and
       not below, no world-triplanar material on props, layers as in §6.4;
     - `room_playtest` pushes a vase over with the real player;
     - `reading_room_test` (the hall walk still clears the vases), `kit_test`,
       `validate_room_test`, `socket_modes_test` (table props as WorldProps
       still scatter and settle);
     - 240-frame runs on main, R01 and R01+R02;
     - frame time with every R01 prop frozen versus today's;
     - GPU: the iwan with the vases, mid-fall and the shards, a table before
       and after a push.
   - Nothing is saved yet. The Esc menu says so.
2. **It stays knocked over.**
   - Build: `WorldState` autoload, `AreaState`, ids, the save file, load
     order steps 1-7 for `moved` and `broken`, resume where you quit,
     **Forget this library**, `--save=` and `--fresh`.
   - Play: break a vase, quit, start the game. You're back in the same room
     and spot, among the shards.
   - Gates:
     - `persist_test` modes `save` and `load` for the vases (two OS
       processes);
     - a stale-id check: rename a prop in a temporary copy of the room
       (`C:\projects\…-test`, never the real scene), so the delta is
       counted, not applied;
     - every earlier gate;
     - GPU: the same view in both processes, compared with `image_diff`.
3. **Pull a lore book and take it.** The phase's first done-when is met
   here.
   - Build: shelf boxes, highlight, promote, pull, push and take in
     `ShelfFill`; `ItemDef` and `Inventory` (ingredients migrated, the HUD
     reads `Inventory`); `LoreBookPin` and R01's two lore books (text
     written for them); `taken` deltas.
   - Satchel panel: J's field notes gain a **Satchel** section that lists
     owned items, with **Read** for a lore book. It's built from a
     `MarginContainer` → `VBoxContainer`, per AGENTS.md §3.
   - Validate Room: the lore-pin rule.
   - Play: find the gilt spine, pull it, take it, read it. Pull ordinary
     books onto the floor. It all survives a restart.
   - Gates:
     - `persist_test` `save` and `load` with the book;
     - `kit_test`: ShelfFill build indices are unchanged with and without
       a lore pin, for 20 seeds;
     - `r02_route_test doors=west seeds=1-5` (promotion doesn't touch
       routes);
     - GPU: the shelf with the highlight, the pulled book, the empty slot,
       and the satchel panel.
4. **Years pass.** All of the phase's done-when is met here.
   - Build: the clock, `AgeRules` + `stratum1_age.tres`, the age pin
     layer, `pick_index` split, `LampTend` (light and douse), `state`
     deltas, **Let ten years pass**, `--advance-years`.
   - Play: tend a lantern, let ten years pass a few times, and watch the
     hall and the gallery go dark around the one you kept lit. Quit and
     restart: the same.
   - Gates:
     - the full three-process `persist_gate.sh`;
     - `socket_modes_test`: aging is monotone and deterministic, and
       ageless is respected;
     - every earlier gate;
     - GPU: R01 at years 0, 10 and 40 from one view, and the gallery at 0
       and 40.
5. **(Optional, after review) Drop and loose ends.** Drop an item from the
   satchel as a prop (`spawned`, saved). Table pots break (small shards).
   Any prop kinds that came up in review.

**Not in phase 3:**

- carrying and throwing (E-hold grab);
- quick slots (nothing exists to port);
- the camp rebuilt from kit modules, or its gatherables persisted;
- per-room "last seen" aging;
- streaming (phase 4);
- recess and growth aging rules.

**Risks to check in slice 1:**

- **Pushing.** Godot Physics (the project default; no `[physics]` section)
  can jitter on tall thin bodies resting on trimesh floors. The fallback is
  a box `-colonly` base for the vase, or switching to Jolt project-wide,
  which needs every gate re-run.
- **Collision on the tables.** `table_reading`'s collision may be a
  trimesh top. Props resting on it at freeze must not sink. The settle step
  already places them at the surface.
- **Validate Room** may flag `WorldProp` spawns, which aren't KitModules,
  in `table_props`. Scatter items are exempt from the grid rule today. The
  check is to be confirmed.
- **Recess boards' collision.** Pulled books rest on them. If the boards
  have none (they're dressing), the pulled book stays frozen until pushed,
  which is fine. Pushing it needs a board collider, or it drops straight
  through to the floor, which is acceptable.


#### 6.5.9 Originals and the janitor hook (added 2026-10-20 at the user's request, built in step 2)

**The aim:** a future NPC or event (a "janitor") can put things back in
their original condition. Step 2 builds the plumbing for that. No janitor
exists yet.

- **The original is never overwritten.** A room is always rebuilt as
  authored or generated from its scene and seed, and the save holds only
  deltas laid over it. Dropping a delta therefore brings the original back
  on the next load, with nothing else needed.
- **Every delta also records the original:**
  - `orig`: the thing's original transform, in the room's frame;
  - `scene`: the prop's scene path.

  Two cases need this:
  - a socket spawn (a table prop) settles onto its table only after load,
    so the save is the one place that knows where it stood;
  - a broken prop can be rebuilt while the room is live, without a reload.

  In the save:
  `{"s": "moved", "xf": […], "orig": […], "scene": "res://props/prop_vase_floor.tscn"}`.
- **A prop that settles back where it started** (within 1 cm and 1°) has
  its delta dropped. There's nothing to remember.
- **API on `WorldState`, for the janitor:**

  | Call | What it does |
  |---|---|
  | `changed_ids(room_key)` | Everything changed in a room (`""` for everywhere): the to-do list |
  | `revert(id)` | Puts one thing back as it was and drops its delta. If the room is loaded, its `RoomTemplate.revert_thing(id)` restores it in place |
  | `revert_room(room_key)` | Reverts everything in a room; returns the count |
  | signal `reverted(id)` | Lets an NPC, a sound or a HUD line react |

  Reverting puts things back like this:
  - a moved prop freezes and returns to its original transform;
  - a broken prop is re-instanced from its scene at its original place
    (as the same socket spawn number, for socket spawns) and its shards are
    removed;
  - a delta whose room isn't loaded is simply dropped, and the next load
    builds the original.
- **Test hook:** the Esc menu in rooms has **Tidy up (janitor test: N
  changed)**, which reverts every loaded room.
- **Later kinds** (taken books, dropped items, lamp states) follow the same
  rule. A taken lore book's delta keeps its shelf slot, so a janitor could
  put a copy back. Whether it should is a game-design question for then.
