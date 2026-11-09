# Phase 19 design: animals, and the groundwork for every NPC

[Approval brief](phase-19-approval.md) ·
[Creature atlas](../../design/creature-atlas.html) ·
Status: brief approved as recommended 2026-11-09. Class and file names here
are proposals until built.

## In short

Animals are the first users of a small **actor** layer that people and
monsters will reuse: a data file per kind, a mind, a way of moving, senses,
and a director per area that spawns and retires them as rooms stream. The
first animals need only the cheapest version of each part. Section 4 lists
what the audit of today's code found: what is ready, what was planned in
`architecture.md` §7 but never built, and what has to change.

## 1. The parts

| Part | What it is | Phase 19 uses | Later (people, monsters) |
|---|---|---|---|
| `ActorDef` (Resource) | One file per kind: names, class, size, speeds, group size, habitat needs, senses, model, build tier | `CreatureDef extends ActorDef` in `actors/defs/*.tres` | Adds temperament, yields, faction, host class, dialogue |
| `Habitat` | Per room, the places an actor can be, found by scanning the built room (§3) | Water bodies, flames, dark roofs, lanes, rest spots, wall strips, holes | Seats, work spots, beds (`ANCHOR_` markers) |
| `Mover` | How a body gets from A to B | `WaterMover`, `LaneMover` (floor), `WallMover`, swarms move in their shader | `NavMover` on a navigation mesh, if the step 3 measurement supports it |
| `Mind` | A small state machine ticked 5 to 10 times a second, staggered | Idle, wander, rest, startle, hide | Needs, schedules, combat; a behaviour tree or utility scores where a state machine runs out |
| `Senses` | What an actor knows of the player | Distance, player speed, "is wading", "carries a flame" (always false for now) | Sight cones, hearing, light level, other actors |
| `Fauna` (Node, child of `Area`) | The director, a sibling of `LightBudget` and `AreaStreamer` | Spawns on `room_loaded`, frees on `room_unloaded`, enforces the per-view limit, sleeps actors beyond 30 m | Populations that move between rooms; people's schedules |
| `FaunaTable` (Resource) | Per area: which kinds, how plentiful, which are dominant | `gen/fauna/<area>.tres`; places that aren't areas (camp, lake) get one too | Edited on the Strata Board |

Three build tiers, cheapest first:

| Tier | How | Phase 19 animals | Cost target |
|---|---|---|---|
| **Swarm** | One `MultiMeshInstance3D` (or particle system) per colony; all motion in the vertex shader from a per-instance phase; no nodes, scripts or physics per animal | Cave barb, moth, glowworm, bat | 1 draw call per colony |
| **Simple** | A small mesh per animal, bent by a vertex shader (fish, eel) or swapping 2 to 4 baked poses (gecko, rat, birds); a `Node3D` with a mover, no physics body | Goldfish, rat, gecko | 1 draw call each, no skeleton |
| **Rigged** | `Skeleton3D` + `AnimationPlayer` from Blender; a `CharacterBody3D` on layer 5 only if solid (Q7) | Cat | To be measured in step 3 |

## 2. Budgets (to be confirmed by step 1's measurements)

The frame gate's limits are per view: 1,500 draw calls, 3 M triangles, 50
lights, 4 shadowed; on this machine about 4 ms GPU and 8 ms CPU. Several
areas are at the light limit and borderline on CPU. So animals get their own
slice, counted by the F3 panel and the frame gate:

| | Limit per view |
|---|---|
| Thinking animals (simple + rigged) | 40 |
| Swarms | 8 |
| Draw calls | 60 |
| Triangles | 60,000 |
| Lights | 0 (glow is unshaded emission only) |
| Shadow casters | Rigged animals only |
| CPU, minds and movers | 0.3 ms a frame on the dev machine, sliced |
| Spawn work when a room loads | Inside the streamer's existing build budget (4 ms a frame), never one lump |

Beyond 30 m (where `LightBudget` already fades lamps) minds stop and swarms
freeze; beyond the room's sight range nothing is drawn.

## 3. Habitat: found by scanning, not by re-marking the kit

Fourteen room types are built and most of their kit pieces carry no NPC
markers (§4.2). Rather than reopen every `.blend`, a `HabitatScan` reads what
a built room already has:

| Habitat | Read from |
|---|---|
| Water body (surface height, floor, outline) | New: each grammar that makes water writes it into `grid.meta["water"]` (§4.3) |
| Flame | Lights in group `kit_light` whose profile is a flame, and `LampState` for whether it burns |
| Dark roof | Vault or cave cells with no burning light within one bay |
| Lane | `CellGrid.wear` (the walked lanes `RoomGrammar.wear_lanes` already makes) |
| Rest spot | Carpets, cushions, hearths, takht, by module name; `ANCHOR_` markers where they exist |
| Wall strip | A wall face within 1.5 m of a flame |
| Hole | New small kit piece (`hole_wall`), placed by the scan at wall bases in abandoned stretches; rats enter and leave by it |
| Ruined shelf | `VariantSocket` picks that are fallen or gapped shelves |

Hand-built places (the camp, the lake's harbour and docks, the Gorge) have no
cell grid. They get `ANCHOR_<kind>` markers placed by hand in their scenes or
bake tools, and the Gorge's ledges come from its network.

Placement is seeded from the world seed, the room key and the kind, so a room
shows the same animals on every visit and in every process.

## 4. What the audit found in today's code

### 4.1 Planned in architecture.md §7 but not built

| Planned | Today | What to do |
|---|---|---|
| "Each room bakes a navigation mesh at load on a thread" | No `NavigationRegion3D`, `NavigationAgent3D` or navigation mesh anywhere in the project | Q6: lanes first; measure a threaded bake on one streamed room in step 3 (bake time, frame cost on entry, memory) and decide before people |
| "Rooms keep their tags (faction, settlement, ecology) in `RoomTemplate`" | `RoomTemplate` has no tags. A room's type comes from its file name (`RoomTypes`) and its state from `AreaSlot.tweaks["state"]` | Add `RoomTemplate.habitat_tags()` that derives tags from the type, the state (kept or abandoned) and the grammar's mood (wetness, `lamps_dark`). No new authored data |
| "Modules carry `ANCHOR_` markers (seat, work, sleep, lookout, trade)" | `tools/kit_import.gd` turns `ANCHOR_` empties into markers in group `npc_anchor`, but only the early kit scripts place any (19 in all: r01, r03, r05, gorge, persian, walls). Nothing from phase 12 on has one | Don't backfill now (§3). Fix the vocabulary (`perch`, `roost`, `rest`, `den`, `drink`, plus the people's `seat`, `work`, `sleep`, `trade`, `lookout`) and require them in new rooms' character briefs. Backfill for people in their phase |

### 4.2 Has to change or be added

| Area | Finding | Change |
|---|---|---|
| **Animated models** | No `Skeleton3D`, `AnimationPlayer` or `AnimationTree` in any script. The people in the game are posed statues (`bz_keeper_a`, `lk_ferryman`). `project.godot` makes `tools/kit_import.gd` the import script for **every** scene; it is written for static kit pieces (collision hints, snap markers, batching) | A separate path: `art_src/creatures/*.blend` → `tools/export_creatures.bat` → `actors/models/`, with its own import script (or an early exit in `kit_import.gd` for that folder) that keeps skeletons and animations. This is step 3's main risk, and people need the same path |
| **Water** | Water is a drawn plane, a `wade` tag on shallow floors and blockers on layer 8 for deep water. Layer 7 is named "water" but nothing uses it. Nothing says where a pool is or how deep | Grammars and bake tools that make water (cistern, garden hauz, light-well pool, quarter hauz, bazaar fountain, terraces' channels, bridge hall pit, camp pool, lake) write a water body: surface height, floor height, outline. Fish read it; later, swimming and fishing do too |
| **Streaming** | `AreaStreamer` emits `room_loaded` / `room_unloaded` and builds rooms in budgeted slices; big rooms enter in parts. `DoorSeal`s close doorways to rooms not built | `Fauna` spawns after a room is fully in, in slices under the same budget. Animals are bound to their room in phase 19. Travelled places (door travel) free and respawn animals with the scene; the seamless camp–Gorge corridor is the one place two populations are live at once |
| **First-sight hitches** | New materials and particle systems cause a hitch the first time they draw; `PipelineWarm` exists for this and each `*Life` class has a `warm()` | Every creature material, shader and swarm registers with `PipelineWarm` |
| **Save** | `WorldState` stores only differences from the seeded world, per area, in one JSON file. `years()` and `advance_years()` exist | A `fauna` section per area: plentifulness per kind (the design foundation's Abundant, Common, Scarce, Very scarce), one-off animals by id. Nothing in phase 19 changes it yet; step 5 proves it survives a process restart, so the behaviour phase can start changing it |
| **Collision layers** | Layer 5 "npcs" is reserved and unused. The player's mask is world, props and layer 8; the interaction ray sees layers 1, 2 and props | Solid animals sit on layer 5 and the player's mask gains layer 5 (Q7). Small animals have no body. Looking at an animal (a name, later a notebook entry) would use layer 2 like other interactables: not in phase 19 |
| **Tests** | `tests/area_tour.gd` walks rooms from `floor_cells`, `blocked_cells` and `sight`; the frame gate and persistence gate exist per area | New `tests/fauna_test.gd`: same seed gives the same animals; none spawns outside its habitat or inside a wall; limits hold; plentifulness survives a restart. The frame gate runs with animals on and reports their slice. Every run with `--audio-driver Dummy` |
| **Existing stand-ins** | The Garden Court's "moths" are particles (`GardenCourtLife._drift`). The cistern has eel traps and nets, the quarter a pigeon tower, the lake fishing spots and a fisher | The particle moths are replaced by the moth swarm in step 2. The rest become the natural homes of phase 20's animals |

### 4.3 Fine as it is, with something to know

| Area | Note |
|---|---|
| **Light budget** | `LightBudget` needs no change because animals add no lights (Q9). It is the reason for that rule |
| **Kept and abandoned** | The single State setting per room is exactly what animals need: kept rooms get cats, geckos, goldfish; abandoned ones rats, bats, bookworms |
| **Lamps** | `LampState` already knows which lamps burn and ages them with the years: moths and geckos follow it for free |
| **Map traces** | The camp, Gorge and lake each have a traced walkable sheet (`gen/map/*_trace.tres`). Likely usable as a "where is floor" check for hand-built places; to be confirmed in step 1 |
| **World seed** | Every area's seed derives from the world seed; animals do the same |

### 4.4 Not needed for animals, flagged for people and possession

| Area | Finding |
|---|---|
| **The player** | `scripts/player.gd` is body, camera and controls in one script, built in code. Possession (any creature a host) needs the body separated from what drives it, so a mind or the player can drive the same body. Designing `Mover` and `Mind` as separate parts now keeps that door open; the player itself is not touched in phase 19 |
| **Sound** | One `AudioStreamPlayer` for music in `main.gd`; no positional sound, no buses, and every phase so far lists sound as not included. Phase 20 opens with a small groundwork (Q10) |
| **A daily rhythm** | The world clock counts years only. There is no cycle of hours for animals (or people) to keep. Not needed while animals react only to you; needed for schedules |
| **Props** | `WorldProp` and its wake/sleep budget (48 bodies) are ready for a cat to knock a vase over; not in phase 19 |
| **Room atlas** | Its third-batch list already has a "Creature Warren" room. A natural home for the behaviour phase |

## 5. Folders

```
actors/defs/        CreatureDef .tres, one per animal
actors/models/      imported animated models (from art_src/creatures)
scripts/actors/     actor_def, creature_def, mind, movers, senses, swarm
scripts/world/      fauna.gd, fauna_table.gd, habitat_scan.gd
gen/fauna/          a FaunaTable per area and place
shaders/            creature_swim, creature_swarm, creature_glow
tests/              fauna_test.gd, creature_capture.gd
docs/npc/           briefs, designs, progress/
```

## 6. Step notes

1. **Fish.** `CreatureDef`, `Fauna`, `HabitatScan` (water only), water bodies
   written by the cistern, garden, hypostyle hauz, camp and lake; swim shader;
   school as a swarm; the per-view counters on F3. Measure and fix the limits
   in §2.
2. **Moths, glowworms, bats.** Flame and dark-roof habitats; the swarm shader's
   orbit, drift and roost modes; startle (bats) and dim (glowworms) driven by
   one uniform per colony. Replace the Garden Court's particle moths.
3. **The cat.** The creature export and import path; a rig and six animations
   (sleep, sit, wash, walk, look, startle); `LaneMover` on `CellGrid.wear`;
   rest spots; a test room with the cat standing still, shown first. The
   navigation mesh measurement. The smooth-or-stepped comparison (Q5).
4. **Rats and geckos.** Pose-swap simple tier; holes; `WallMover`; geckos tied
   to `LampState`.
5. **Tables, save, tests, live.** `FaunaTable` for each area and place by the
   atlas's "Who lives where"; the save's `fauna` section; `fauna_test`, frame
   gate, persistence gate; the room atlas and `AGENTS.md` point at the new
   documents.
