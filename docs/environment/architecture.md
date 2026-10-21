# Environment architecture: how levels are built

[Back to the front page](../../ENVIRONMENT_PLAN.md)

**In short:** this is the reference for *how the system works*. It changes
rarely. Rooms are built from Blender kit pieces (walls, vaults, shelves) that
snap to a 4 m grid. **Sockets** inside the pieces add variety (what sits in a
shelf recess, whether a lamp is lit). Some rooms are laid out by hand, others
by a rule-driven generator, and both use the same pieces. Interactive props
and saving come in phase 3.

**Inputs:** `design/room-atlas.html` (20 room types, kit, build modes), the game
design foundation (`design/The_Eternal_Library_Game_Design_Foundation_v0.1 (1).docx`),
`ART_DIRECTION.md` and the current prototype.

The section numbers (§0 to §11) are the original ones. Code comments cite
them, so they stay the same.

| Section | What it covers |
|---|---|
| §0 | Decisions you have already made |
| §1–2 | What changes from the prototype; the layers (kit → room → area → stratum); §2.1 world structure (strata, areas, thresholds, cavern facades, levels, the map) |
| §3 | The kit: grid rules, Blender side, Godot side |
| §4 | Authored rooms and sockets |
| §5.1–5.4 | Generated rooms (the phase 2 detail is in [phase-2-design.md](phase-2-design.md)) |
| §6.1–6.4 | Interactive objects, persistence, collision layers (the phase 3 detail is in [phase-3-design.md](phase-3-design.md)) |
| §7–9 | NPC readiness, streaming and lighting, folder layout; §8.2 graphics settings and hardware tiers |
| §11 | Risks |

---

## 0. Decisions already made

| Question | Decision |
|---|---|
| When do generated rooms exist? | **At runtime from a saved seed**, plus an **editor preview** that runs the same generator. A layout you like can be **baked** into a normal scene and finished by hand. |
| Where are module meshes made? | **Blender**, exported to `.glb`, with a Godot post-import script that adds collision, pixel materials and snap points. |
| How physical are props? | **Pick up plus light physics.** Props sleep as static objects until touched, then wake as rigid bodies. Moved, taken and broken props are saved per area. |
| First vertical slice | **R01 Reading Room** (authored from kit modules) joined to a generated **R02 Stack Gallery**. |

Language stays statically typed GDScript, matching the prototype and `AGENTS.md`.

---

## 1. Where the prototype stands, and what changes

The prototype builds everything in code at startup. `main.tscn` is nearly empty and
about 5,000 lines of GDScript (`world.gd`, `vista.gd`, `cavern.gd`, the `*_pass.gd`
files) create the geometry. That got the look right, but nothing can be selected,
moved or tweaked in the editor.

The new structure turns that around:

- **Geometry lives in scenes and Blender files.** Code only *assembles* scenes
  (generators) and *decorates* them (sockets, aging, dressing).
- **Every number a designer might tweak lives in a Resource (`.tres`)** shown in
  the Inspector, never as a constant buried in a script.
- **Authored and generated rooms use the same modules, sockets and connectors**,
  so a generated layout can be baked into an authored one and an authored room
  can sit inside a generated area.

What carries over from the prototype:

| Keep | Becomes |
|---|---|
| Pixel materials (`assets/textures/px`, `tools/pixel_materials*`) and the slot-name swap in `asset_factory.gd` | The material library the post-import script applies to modules. |
| World-triplanar 32 tx/m mapping | Default for architecture, so modules need no UV work and textures run across seams. |
| `art_direction.gd`, `atmosphere.gd` (grade, glow, fog, flicker) | A per-area `Atmosphere` node driven by an `AtmosphereProfile` resource. |
| `tools/build_props.py` Blender pipeline | Grows into `tools/export_kit.py`. |
| `vista.gd`, `cavern.gd`, `vista_cliff.gd` | Later, the R10 Chasm Spans generator (phase 5). |
| `tests/` capture, playtest and audit scripts | Reused as gates for every phase. |
| Hand-placed geometry in `world.gd` and the passes | Stays as the camp, which holds the gameplay loop. Authored rooms such as R01 are played alongside it (phase 1 step 6 decision); the camp is rebuilt from kit modules once props carry gameplay (phase 3). |

---

## 2. Layers

```mermaid
flowchart LR
  B[Blender kit files] -->|export_kit.py| G[.glb modules]
  G -->|kit_import.gd post-import| M[Module scenes<br/>KitModule]
  M --> R1[Authored room templates<br/>.tscn + sockets]
  M --> GEN[Room generators<br/>RoomGrammar .tres]
  R1 --> A[Area assembler<br/>AreaRecipe .tres]
  GEN --> A
  A --> S[Area instance at runtime<br/>seed + saved deltas]
  S --> P[Props, dressing, aging]
```

| Layer | What it is | Who edits it, and how |
|---|---|---|
| **Kit** | Modules: wall bays, arches, vaults, stairs, shelves, lamps | You, in Blender (shape) and the Inspector (metadata) |
| **Room** | An authored template scene, or the output of a room generator | Authored: you, in the editor. Generated: the rules, in `.tres` files |
| **Area** | A connected set of rooms (a few hundred metres), the unit of streaming and saving | `AreaRecipe` resource |
| **Stratum** | Style, ecology and rule set for a depth band | `StratumProfile` resource |

### 2.1 World structure (agreed direction 2026-10-20)

This is the shape of the whole world, settled before phase 4 so later phases
grow into it without rework. Phase 4 builds only one area on one level, but its
data already follows these rules (see [phase-4-design.md](phase-4-design.md)
§8.1.9).

**The hierarchy.**

| Unit | Size | How it exists | Moving inside it |
|---|---|---|---|
| **World** | Several strata, stacked by depth | A world seed | Descending between strata is a major transition (a long stair, a lift, a shaft); a loading screen is acceptable here |
| **Stratum** | Kilometres across, many areas | A **stratum plan**: data that reserves each area's 3D space and its threshold positions in one shared frame | Between areas: through a **threshold** (below) |
| **Area** | A few hundred metres, 6–30 rooms | A recipe plus a seed, giving an `AreaPlan`, placed at its reserved origin in the stratum frame. Never a saved scene | Rooms stream in and out with no loading screen |
| **Room** | One authored, baked or generated room | Built from the plan when it streams in | — |

**Thresholds between areas.** Every connection between two areas is a
threshold connector: a winding stair, a gate passage, a tunnel with a turn.
A threshold blocks every sightline from one area into the other, and it is
long enough to walk for the next area to load. If the next area isn't ready
when you reach the far end, a short loading screen covers the gap, so the
threshold works seamlessly on fast machines and still works on slow ones.
Today's glowing gallery-end arch (phase 4, Q10) is where these will attach.

**Sightlines.** Rooms load by graph distance (doorways), and Godot 4 has no
built-in portal system. So the **planner owns visibility**. It traces straight
lines through doorway openings on the cell grid, and:

- it rejects a layout that can see deeper than `max_sight_depth` rooms (2 by
  default) along any doorway line. Offset doorways, turns, screens, closed
  doors and level changes are the tools to break a line;
- it stores, for each room, the set of rooms visible from it. The streamer
  loads `graph radius ∪ visible set`, so you can never look into a room that
  isn't there.

A deliberate long view (a grand axis, a cavern vista) is allowed when the
far room is marked to stream as a **stand-in**: a merged low-detail shell with
no props, lights or collision. A room is therefore always in one of three
states: `unloaded`, `stand_in` or `live`.

**Cavern exteriors are facades, not whole buildings.** Seen from a cavern or
chasm area (R10 Chasm Spans, the Overlook), buildings are carved into the
cavern walls:

- the **facade** belongs to the cavern area. It is made from kit facade,
  loggia and cliff-ledge modules, is always loaded with the cavern, and its
  lit windows are emissive cards, not real rooms behind glass;
- the **interior** behind it is a separate interior area, entered through a
  threshold at the facade's door;
- the cavern area defines **frontage slots** along its walls. An interior area
  attached to a slot is planned behind that slot's wall plane, so the outside
  and the inside always agree;
- free-standing buildings are rare, hand-made landmarks (towers, bridges,
  colossi);
- the cavern's walls, bends and haze cap how far you can see, and far
  cavern geometry is drawn as merged low-detail meshes.

**Levels.** The world is 3D in its data from the start. Plan footprints are
boxes with a storey (4 m, §3.1). Connectors record their storey, and stair,
ramp and spiral connectors change storey. Overlap checks are 3D: rooms may
stack above one another, but no two rooms (or areas) may occupy the same
space. Finding "the room the player is in" uses those 3D boxes. Per-level
data (floor wear, the map) is kept per storey.

**The map.** The world map is drawn from plans, not geometry: the stratum
plan's area envelopes and each area's room boxes, sliced by storey, revealed
as rooms are visited. Because areas are planned inside envelopes reserved in
one shared frame, **nothing overlaps on the same level, by construction**.
This holds whether you cross between areas seamlessly or through a loading
screen.

**Coordinates.** Each area has its own local frame and an origin in the
stratum frame. The player's saved position is area-relative. At runtime the
live area sits near the world origin, which avoids 32-bit float jitter in a
stratum several kilometres wide.

---

## 3. The kit: how modules fit together

### 3.1 Grid and conventions

- **Bay:** 4 m. **Storey:** 4 m. **Half bay:** 2 m. **Fine snap:** 0.5 m. Rotations in 90° steps.
- **Up is +Y; a room's "forward" is −Z** (Godot's default).
- **Three module shapes**, which is what lets pieces fit without hand alignment:

| Shape | Occupies | Origin | Examples |
|---|---|---|---|
| **Edge** | One cell edge, 4 m wide (or 2 m) | Floor level, at the left end of the edge, wall plane on the cell boundary, interior facing −Z | Plain wall, shelf-recess bay, arch opening, door, window |
| **Cell** | One or more whole cells | Floor-level corner of the cell | Floor tile, vault bay, dome cell, stair run, pool |
| **Post** | A grid corner | The corner point | Pier, column, corner block |

- **Wall thickness is split across the boundary** (half inside each cell), so two
  rooms built back to back share one wall without overlap or z-fighting.
- **Every module states its footprint** (`size_cells`, `storeys`) and its **edge
  signature**: one tag per side, from
  `solid | opening_3m | opening_full | door | open | none`. Generators match
  signatures; you never set them by hand on placed instances.
- **No scaling, ever.** Scaling breaks the 32 tx/m texel density. A 3 m arch and
  a 4 m arch are two modules.

### 3.2 Blender side (authoring and tweaking meshes)

- Sources live in `art_src/kit/` (with a `.gdignore`, so Godot doesn't import the
  `.blend` files directly and headless import never needs Blender). One file per
  family: `kit_walls.blend`, `kit_vaults.blend`, `kit_vertical.blend`,
  `kit_storage.blend`, `kit_dressing.blend`, `props.blend`.
- **One top-level object (or collection) = one module.** Naming:
  `M_<family>_<name>_<variant>`, e.g. `M_wall_shelfbay_4m_a`.
- Inside a module, child **empties** carry meaning by prefix:

| Empty prefix | Becomes | Purpose |
|---|---|---|
| `SNAP_<name>` | `Marker3D` connector | Where other modules or rooms attach (door, stair head, bridge end) |
| `SOCKET_<set>` | `VariantSocket` | A variation point, e.g. `SOCKET_recess_fill` inside a shelf bay |
| `LIGHT_<profile>` | `OmniLight3D` / `SpotLight3D` from a light profile | Lanterns carry their light |
| `ANCHOR_<kind>` | `Marker3D` in group `npc_anchor` | Seats, work spots, lookout points for future NPCs |

- **Collision** uses Godot's import name hints. Phase 0 modules put `-col` on the
  visible mesh (`wall_plain_4m__body-col`), which gives exact trimesh collision
  from the render mesh. For detailed meshes, add a separate low-poly child named
  `*-colonly` instead. A structural module with no collision gets an import
  warning.
- **Occluders** use the `-occonly` hint on thick walls, so occlusion culling is
  authored once per module.
- **Materials:** only the *slot name* matters (`ashlar`, `brick`, `plaster`,
  `tile_teal`, `wood`, …). The import script swaps in the matching pixel material.
- `tools/export_kit.py` (run by Blender headless, like `build_props.py`) writes one
  `.glb` per module into `assets/kit/<family>/`. A one-click `tools/export_kit.bat`
  wraps it. You can also export one file from inside Blender with the same script.

**Tweaking a mesh:** open the `.blend`, edit, run `export_kit.bat`, and switch back
to Godot. It reimports, and every room that uses the module updates, because
rooms reference the module scene, not a copy.

### 3.3 Godot side

- `tools/kit_import.gd` (an `EditorScenePostImport` script, set as the default for
  `assets/kit/`):
  1. assigns pixel materials by slot name and enforces texel density;
  2. converts `SNAP_`, `SOCKET_`, `LIGHT_` and `ANCHOR_` empties into real nodes;
  3. sets collision layers (see §6.4), visibility ranges and shadow flags;
  4. reads Blender custom properties (`size_cells`, `edges`, `tags`, `weight`) into
     metadata.
- `tools/kit_catalog.gd` (an editor tool) creates or updates one **wrapper scene**
  per module in `kit/modules/<family>/<name>.tscn`. Its root has a `KitModule`
  script exposing footprint, edge signature, style tags (`brick`, `plaster`,
  `tile`, `stratum_1` …) and a generator weight. Wrapper scenes are where you add
  Godot-only extras (a particle emitter, a sound) without touching Blender. The
  catalog never overwrites nodes you added.
- `kit/catalog.tres` (a `KitCatalog` resource) indexes every module by shape,
  signature and tags. Generators query it; you never edit it by hand.

---

## 4. Authored rooms: building and tweaking in the editor

### 4.1 Placing modules

Use **scene instancing with a small editor plugin**, not `GridMap`. GridMap only
stores meshes and collision, and would drop the sockets, lights, anchors and
connectors that live inside modules.

`addons/kit_palette/` (an `EditorPlugin`) adds:

- **A Kit dock** with module thumbnails, filtered by family and tags.
  Click a module, then click in the viewport to place it on the grid.
- **Shortcuts:** rotate 90°, flip, raise or lower a storey, and "repeat last along
  the edge" (lay a run of six shelf bays in one drag).
- **Connector snap:** dragging a room template near another snaps their `SNAP_`
  markers together.
- **Validate Room**, which checks that edges have no gaps, modules sit on the grid,
  nothing is scaled, collision is present, connectors are on cell boundaries, and
  every socket candidate fits its slot.

Godot's own grid snap (0.5 m, 90°) works alongside the plugin for free-form dressing.

### 4.2 Room template scene layout

```
ReadingRoom (RoomTemplate)              # id, footprint, stratum tags, age rules
├─ Shell        (Node3D)                # kit modules only; merged into one static batch at load
├─ Sockets      (Node3D)                # free-standing VariantSockets (module sockets live inside modules)
├─ Props        (Node3D)                # authored interactive props (WorldProp)
├─ Dressing     (Node3D)                # scatter volumes, shelf fills (MultiMesh at runtime)
├─ Lights       (Node3D)                # extra lights; lantern modules bring their own
├─ Connectors   (Node3D)                # SNAP markers exposed to the area assembler
├─ Atmosphere   (Atmosphere)            # optional override of the area's AtmosphereProfile
└─ Bounds       (Area3D)                # room volume for streaming, music, aging
```

### 4.3 Variant sockets (the "somewhat generated" part of authored rooms)

`VariantSocket` is an `@tool` `Node3D`. It references a **`SocketSet` resource**,
so a set like `recess_library.tres` is shared by every shelf recess in the game:
tune its weights once and they change everywhere.

| Socket mode | What it does | Example |
|---|---|---|
| `REPLACE` | Instance one candidate scene | Recess: shelves, tile panel, sealed door, collapsed |
| `TOGGLE` | Present or absent, by probability | A rug, a ladder, rubble |
| `SCATTER` | N props inside a box or along a line | Pots on a ledge, books on a table |
| `SHELF_FILL` | Fills a shelf volume with books as one MultiMesh | Every shelf in R01–R03 |
| `STATE` | Picks a state on a child | Lantern lit, failing or dark |

Each `SocketSet` entry has a scene, a weight, tags, and optional conditions
(`stratum`, `min_age_years`, `faction`, `settlement_state`).

**In the editor**, a socket shows a live preview. The Inspector has
**Prev / Next / Random** buttons and a **preview seed** field on the `RoomTemplate`
that re-rolls every socket in the room at once: the same thing the atlas's
"Reroll sockets" button does, but on the real scene. A **Pin** checkbox forces a
specific candidate for a hand-tuned spot.

**At runtime**, the pick is `hash(area_seed, room_id, socket_node_path)`, filtered by
conditions. Hashing by node path means adding a new socket never reshuffles the
others, so old saves keep their look.

### 4.4 Tweak workflows

| You want to… | Do this |
|---|---|
| Move a wall or add a bay | Open the room scene, select or place modules in the Kit dock, save |
| Change what recesses can contain | Edit `recess_library.tres`: add a scene, change weights |
| Force one recess to always be a sealed door | Select its socket, pick the candidate, tick **Pin** |
| See other variants of the room | Change the room's preview seed, or press **Random** |
| Make a one-off variant of a module | Duplicate the wrapper scene, add nodes; or duplicate the Blender object with a new `_b` suffix |
| Change a module's shape everywhere | Edit the `.blend`, run `export_kit.bat` |

---

## 5. Generated rooms: rules you can tweak

### 5.1 Two generation levels

1. **Area layout:** which rooms exist and how they connect (the `AreaRecipe`).
2. **Room layout:** for fully generated types (R02, R03, R06, R09, R11, R14, R15, R17,
   R10), fill a 3D cell grid using a `RoomGrammar`.

Both are plain data you edit in the Inspector:

| Resource | Holds | Example knobs |
|---|---|---|
| `StratumProfile` | Style tags, ecology, palette, atmosphere, which socket conditions apply | `styles: [brick, tile_teal]`, `lamp_density: 0.6` |
| `AreaRecipe` | Required authored rooms, counts of generated types, size, connector rules | `required: [ReadingRoom]`, `stack_galleries: 3–6`, `max_dead_ends: 2` |
| `RoomGrammar` (one subclass per generated type) | The layout rules for that type | R02: `max_straight_bays 6`, `side_passage_chance 0.11`, `collapse_chance 0.08`, `lamp_every_bays 2`, `lamp_falloff_by_distance` |
| `ModuleRules` | Which modules may fill which edge or cell signature, with weights and style tags | `edge solid + style brick → [wall_plain 3, wall_shelfbay 8, wall_niche 2]` |

### 5.2 Pipeline

1. **Graph.** The `AreaRecipe` places required authored rooms, then adds generated
   rooms and links (a spanning tree plus a few loops, so there's more than one way back).
2. **Place and route.** Authored templates are placed by their connectors.
   Corridors are routed on the 4 m grid by A*, with stair cells for level changes.
3. **Mark edges.** Every cell edge becomes `solid`, `opening`, `door` or `open`
   according to the grammar.
4. **Pick modules** by edge and cell signature from `ModuleRules`, weighted and
   seeded. This is a lookup table rather than full wave-function collapse; it is
   enough for corridor, grid, ring and lane rooms, and much easier to reason about.
5. **Resolve sockets** exactly as in authored rooms.
6. **Dress:** shelf fills, scatter, lamps by distance rule.
7. **Age:** apply `AgeRules` for time passed (see §6.3).
8. **Validate:** connectivity, plus a route audit with the real player capsule
   using `PhysicsServer3D.body_test_motion`, as `AGENTS.md` requires.

Generation runs on a worker thread and builds nodes off-tree, then adds them in
one go. A room of about 200 modules should take well under a frame budget per room
when spread across frames.

### 5.3 Editor preview and bake

`GeneratorPreview` (an `@tool` node; drop it in any scene) has slots for a
`RoomGrammar` or `AreaRecipe`, a seed, and buttons:

- **Generate:** builds the result live in the editor, as a temporary child.
- **Overlay:** draws the cell grid, edge types in colour, and socket picks as labels.
- **Step:** runs the pipeline one stage at a time, for debugging a rule.
- **Bake to scene:** writes a normal `.tscn` that uses the same module scenes and
  sockets. The baked scene is an ordinary authored room you can finish by hand,
  which is how a good generated layout becomes a landmark.

**Tweaking a rule:** select the `.tres`, change a number, press Generate. No play
mode needed.

### 5.4 Determinism and saves

- `area_seed = hash(world_seed, area_id)`. Every random choice comes from a
  sub-seed of that, keyed by what is being decided, never from call order.
- Saves store the seed, the **recipe version** and the player's deltas, not the
  geometry. If a recipe changes after release, the old version is kept for old saves.


---

## 6. Interactive objects

### 6.1 Four kinds of object

| Kind | Examples | Node | Interactive | Saved |
|---|---|---|---|---|
| **Architecture** | Walls, vaults, stairs | Module, merged static batch | No | No (regenerated) |
| **Dressing** | Most shelf books, rubble, wall pots out of reach | `MultiMeshInstance3D` | No | No |
| **Props** | Vases, loose books, stools, lanterns, crates | `WorldProp` | Yes: push, knock, pick up, break | Yes, as deltas |
| **Items** | Lore books, ingredients, tools | `WorldProp` + `ItemDef` | Yes: pick up into inventory | Yes |

### 6.2 `WorldProp`

- A `RigidBody3D` with `freeze = true` (static) at rest, so a room full of props
  costs about the same as static meshes.
- **Wakes** (unfreezes) on player contact, a hit, an explosion, or when something
  under it moves. It goes back to frozen once it has slept for a few seconds.
- An **active-body budget** (start with 48) re-freezes the oldest sleeping props if exceeded.
- **Breakable** props swap to pre-fractured pieces (made in Blender as
  `M_prop_vase_a_broken`). Pieces despawn after a while; a "broken" delta is saved.
- **Items** reference an `ItemDef` resource. Picking one up moves ownership to the
  inventory, so quick slots reference owned items instead of copying them.
  Dropping recreates the prop.
- Props use **local triplanar or UVs**, not world triplanar, so their texture
  doesn't swim when they move.

**Books** are the special case: thousands per room. Shelves are `SHELF_FILL`
dressing. When the player looks at a shelf, the nearest book slot can be
**promoted** into a real `WorldProp`: its MultiMesh instance is hidden and a prop
spawns in its place. Lore books are pinned slots that are always promotable.

### 6.3 Persistence and aging

- Every prop has a **stable id**: `area_id / room_id / node_path` for authored props,
  `area_id / room_id / generator_key` for generated ones.
- `AreaState` saves only deltas: `{id: {state: moved|taken|broken, transform}}`,
  plus spawned props (things the player dropped).
- **Load order:** generate the area from its seed, resolve sockets, apply aging for
  time passed, then apply player deltas. Player deltas always win.
- **Aging** (the design doc's "returning to a hometown after many years") is an
  `AgeRules` resource per stratum: lamps go out, recesses collapse, gardens
  overgrow, settlements change hands. It acts only on things the player hasn't touched.
- The persistence gate from `AGENTS.md` applies: save in one OS process, restore in
  a freshly launched one.

### 6.4 Collision layers (fixed now, so NPCs slot in later)

| Layer | Use |
|---|---|
| 1 | World static (architecture) |
| 2 | Interaction ray targets (already used by `interactable.gd`) |
| 3 | Props (`WorldProp`) |
| 4 | Player |
| 5 | NPCs and creatures (reserved) |
| 6 | Triggers and room bounds |
| 7 | Water volumes |

---

## 7. Ready for NPCs later, without building them now

- Modules carry `ANCHOR_` markers (seat, work, sleep, lookout, trade), so rooms are
  already annotated when NPCs arrive.
- Each room bakes a navigation mesh at load on a thread
  (`NavigationRegion3D.bake_navigation_mesh(true)`). Props on layer 3 are excluded,
  so a knocked-over vase doesn't trigger a rebake.
- Rooms keep their tags (faction, settlement, ecology) in `RoomTemplate`, for future
  spawn rules.

---

## 8. Streaming, performance, lighting

- **Streaming unit:** the area. Within an area, rooms load when the player is
  within two connectors of them and unload after leaving that range for a while.
  Loading uses `ResourceLoader.load_threaded_request`.
- **Static merging:** each room's `Shell` merges into a few batches per material at
  load, as the prototype already does with its merged static groups (keep under the
  playtest ceiling of about 100 per view).
- **Culling:** module occluders (`-occonly`) and `OccluderInstance3D`, with
  visibility ranges on dressing and small props.
- **Lighting:** runtime generation rules out baked lightmaps (`LightmapGI`). Use
  SDFGI (already on in the prototype) plus real-time lights. Lantern modules bring
  their own light with a **light budget**: only the nearest N cast shadows; the rest
  use cheap omni lights with no shadows.
- Keep the prototype's frame time (about 5.5 ms) as the target for a
  fully dressed room. That's measured on the dev machine; §8.2 adds the
  hardware-independent budgets and the base-spec target.
- **Streaming follows §2.1:** a room is `unloaded`, `stand_in` or `live`;
  the live set is the graph radius plus the rooms the planner found visible.

### 8.2 Graphics settings and hardware tiers (agreed direction 2026-10-20)

The game must be a good experience on modest hardware and richer on high-end
hardware.

**Target machines.**

| Tier | Reference hardware | Target |
|---|---|---|
| **Base spec** | RTX 3060 (12 GB), a 6-core CPU of the Ryzen 5 5600 class, 16 GB RAM | **Medium preset, 1080p, 60 fps**, no frame over 16.7 ms while rooms stream. 1440p at 60 fps with an upscaler at Quality |
| **High end** | RTX 5090, Ryzen 7 9800X3D (the dev machine) | **Ultra preset, 4K, well above 60 fps**, with every effect on |

**Settings the player can change** (the usual set). Each preset (Low, Medium,
High, Ultra, plus Custom) is a row of these values:

| Setting | Godot mechanism (4.7.2) | Low → Ultra |
|---|---|---|
| Resolution, window mode, vsync, frame cap | `DisplayServer`, `Engine.max_fps` | — |
| Upscaler and render scale | `Viewport.scaling_3d_mode`: off, FSR 1.0, **FSR 2.2**; `scaling_3d_scale` (Performance 50 %, Balanced 59 %, Quality 67 %, Native 100 %) | FSR 2.2 Performance → native |
| Anti-aliasing | MSAA 2×/4×, TAA, FXAA, **SMAA** (all built in) | FXAA → MSAA 4× or TAA |
| Global illumination | SDFGI on/off, cascades, half resolution; per-room `VoxelGI` or ambient-only as the cheap path | ambient-only → SDFGI full |
| Shadows | positional atlas 2048 → 8192, soft filter quality, **shadowed-light budget** (`LightBudget`, 2 → 8) | 2 lights, 2048 → 8 lights, 8192 |
| Lights | `light_fade_m` distance fade, 20 → 45 m | — |
| Volumetric fog | on/off, volume size and depth | off → full |
| SSAO / SSIL / SSR | on/off, quality, half size | off → high |
| Glow | on/off (it's part of the look, so Low keeps it at reduced quality) | — |
| Draw distance and detail | `visibility_range` multipliers on dressing and small props; mesh LOD threshold; stand-in distance | short → long |
| Streaming radius | `load_radius` 1 → 2 (2 is the default; Low may use 1 with a smaller per-frame build budget) | — |
| Physics props | how many props may be awake at once (`PropDirector` budget) | — |
| Field of view, motion blur off by default, sharpening | camera, FSR sharpness | — |

**Rules that keep the look intact across tiers.**

- **`AtmosphereProfile` is the art direction, `GraphicsSettings` is a cap
  on top.** A setting can turn an effect down or off; it never re-tunes the
  grade, fog colour or light colours. Art captures and concept matching
  (`ART_DIRECTION.md`) are taken at the **High** preset, and every
  phase's visual gate also takes one capture at **Medium**.
- **Low must still read as the Library:** warm lamp pools, teal-and-amber
  grade, haze. When SDFGI is off, the cheap path adds a per-room ambient
  fill so rooms don't go flat or black.
- **Pixel textures and temporal upscalers.** The kit's 32 tx/m nearest-filtered
  textures can shimmer or smear under TAA and FSR 2.2. This is tested at the
  first settings slice; if it shows, the fix is texture-side (mip bias,
  sharpening), not dropping the upscaler.
- **Settings live apart from the save:** `user://settings.cfg`, applied at
  start before the first frame. The first launch picks a preset from the GPU
  name and its VRAM (`RenderingServer.get_video_adapter_name()`), with a
  fallback to Medium.
- **The settings menu is UI,** built with containers per `AGENTS.md` §3.

**Upscalers, specifically.**

- **FSR 1.0 and FSR 2.2 are built into Godot 4.7.2** (checked in the binary:
  the 3D scaling modes are bilinear, FSR, FSR2 and Apple's MetalFX). FSR 2.2
  runs on every vendor, including the RTX 3060, so it's the upscaler from day
  one.
- **DLSS is not in Godot 4.7.2.** It needs either a third-party GDExtension
  built on NVIDIA's Streamline SDK, or a custom engine build with a DLSS
  module. Both need Godot's motion vectors and the jittered projection (which
  FSR 2.2 already uses), and a custom build would also have to be the .NET
  (Mono) variant this project uses. So DLSS is a **research spike**: find a
  maintained integration, check it on Godot 4.7, the .NET build and Forward+,
  and check its licence and NVIDIA's terms. Only then add "DLSS" to the
  upscaler list. The settings code treats the upscaler as an enum with an
  "available on this machine" check, so DLSS (or a later FSR or XeSS) slots in
  without changing the menu or the presets.
- Frame generation is out of scope until an upscaler integration exists.

**Measuring without a 3060 on the desk.** Milliseconds on the RTX 5090 don't
carry over, so every frame gate also logs budgets that do, per view:

| Budget (base spec, Medium) | Value |
|---|---|
| Draw calls | ≤ 1,500 (merged statics keep this down, §8) |
| Visible lights / shadowed lights | ≤ 48 / ≤ 4 |
| Triangles drawn | ≤ 3 million |
| Per-frame room build work | ≤ 4 ms on the dev CPU, treated as ≤ 8–10 ms on the base CPU, so the base spec stays under its 16.7 ms frame |
| VRAM (textures, meshes, shadow atlas) | ≤ 6 GB, leaving headroom on 8 GB cards below base spec |

As a working rule until real hardware is tested, a frame on the base spec at
Medium takes about **four times** the dev machine's GPU time and **twice** its
CPU time at the same settings. So a dev-machine run at Medium, 1080p, should
stay under about **4 ms GPU and 8 ms CPU** per frame. These factors are a
guess to be replaced by a real run on a 3060 before release (borrowed,
rented or a tester's machine).

---

## 9. Folder layout

```
art_src/kit/*.blend            # Blender sources (.gdignore)
art_src/props/*.blend
assets/kit/<family>/*.glb      # exported modules (generated)
assets/props/*.glb
kit/modules/<family>/*.tscn    # wrapper scenes with KitModule (generated, then extended by hand)
kit/catalog.tres
kit/sockets/*.tres             # SocketSet resources
rooms/authored/*.tscn          # RoomTemplate scenes (R01, R05, R07 …)
rooms/baked/*.tscn             # generated layouts promoted to authored
gen/grammars/*.tres            # RoomGrammar per generated type
gen/rules/*.tres               # ModuleRules
gen/recipes/*.tres             # AreaRecipe
world/strata/*.tres            # StratumProfile, AgeRules, AtmosphereProfile
scripts/world/                 # KitModule, RoomTemplate, VariantSocket, WorldProp, AreaState, AreaAssembler
scripts/gen/                   # generators per room type
addons/kit_palette/            # editor dock, validate, preview
tools/export_kit.py|.bat, tools/kit_import.gd, tools/kit_catalog.gd
```

---
---


## 11. Risks and open items

- **Headless import.** Exporting `.glb` (rather than importing `.blend` directly)
  keeps CI and headless runs Blender-free. The cost is one export step after edits;
  `export_kit.bat` keeps it to a double-click.
- **Edge-signature tables may get too coarse** for organic spaces (R06 lanes, R15
  terraces). Those generators can place modules directly; the table stays the default.
- **World triplanar on architecture vs UVs on props.** Rules are in §6.2. Modules
  that move (doors, bridges that collapse) need UVs.
- **SDFGI with streaming** can pop when rooms load. Measure in phase 4; fallback is
  per-room `VoxelGI` for authored rooms.
- **DLSS availability.** Not built into Godot 4.7.2; depends on a third-party
  or custom-engine integration (§8.2). FSR 2.2 covers every GPU meanwhile.
- **Base-spec numbers are estimated** from the dev machine (§8.2's 4× GPU,
  2× CPU rule) until a real RTX 3060 run.
- **Save size** grows with deltas. Cap dropped props per area and compact old deltas.
- ~~Missing references in `AGENTS.md`~~: resolved 2026-10-18. `AGENTS.md` had been
  copied from another project; it was rewritten for this one and no longer cites
  a `references/` folder.

