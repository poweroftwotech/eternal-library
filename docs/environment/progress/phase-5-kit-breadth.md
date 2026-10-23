# Progress: phase 5, kit breadth

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../phase-5-approval.md), [technical](../phase-5-design.md)

**In short:** step 1 is done and committed. A new area, the Lower Stacks, starts in a
generated Hypostyle hall: a grid of bays under small tiled domes on twisted
columns, freestanding bookcases between them, and clear aisles from every
door to a landmark under an oculus. Generated galleries lead off its doors.

---

## Step 1: a hall of columns (done 2026-10-22, walked in the game by you and committed)

**Try it:** Esc → **Walk the Lower Stacks** (or start the game with
`-- --area=lower_stacks`). You start in the hall's entry bay, facing in.

- Walk to the centre: every door's aisle leads straight there. The landmark
  is a great lamp, a reading tree or a catalogue desk, picked by the seed.
- Walk round the walls: the outer ring of bays is always clear, with shelf
  recesses in the walls as in the galleries.
- The bookcases have books on both faces. Pull one, as in the Reading Room.
- Leave through any door into a gallery.
- Esc → **Reseed the Lower Stacks** for another hall (6 × 6 to 8 × 8 bays).

Pictures (seed 1, Medium, 1920 × 1080): `previews/p5_step1/r03_1_*.png`
(entry, diagonal, aisle, domes, landmark).

**Built:**

| Piece | File |
|---|---|
| The builder follows the grid: a cell's floor and ceiling slots, its gables, a slot on an open edge (an arcade), posts on any corner (columns), and dressing placed in the shell (the upper wall band). Unset, everything falls back to the gallery's old behaviour | `scripts/gen/room_builder.gd`, `scripts/gen/cell_grid.gd` |
| Rule slots are free names; a slot's module shape comes from its prefix (`edge:`, `cell:`, `post:`, else free) | `scripts/gen/module_rule.gd`, `module_rules.gd` |
| `HypostyleGrammar`: the hall's size (fitted beside its neighbours), doors (one per wall, none in line with the entry), aisles to the landmark, the clear walk along the walls, bookcases (any that would cut a bay off are taken out again), columns, arcades, domes and the oculus, lamps over the aisles and the wall walk, and worn lanes along the aisles | `scripts/gen/hypostyle_grammar.gd`, `gen/grammars/r03_hypostyle.tres`, `gen/rules/r03_hall.tres` |
| 13 new kit pieces, seeded by a Blender script into a new `kit_hall.blend` (yours to edit from now on): twisted column, hall pier and pier top, arcade arch, upper wall band, two domes (tiled, plaster), the oculus (with a cold light), a lantern on a chain from a dome, the freestanding bookcase, the landmark plinth, the great lamp and the catalogue desk | `tools/kit_add_r03.py`, `art_src/kit/kit_hall.blend` |
| Socket sets: the bookcase's books (full, sparse) and the landmark (great lamp, reading tree — the Reading Room's iwan tree — or catalogue desk) | `kit/sockets/case_library.tres`, `kit/sockets/hall_landmark.tres`, `kit/dressing/case_books_*.tscn` |
| A generated room can be an area's root: its entry is an exit like the others, and a visit starts in its first bay | `scripts/world/area_planner.gd`, `scripts/world/area.gd` |
| The Lower Stacks recipe, on the Esc menu, with the menu's areas and reseed generalised | `gen/recipes/lower_stacks.tres`, `scripts/main.gd` |
| A freestanding bookcase's books can be pulled (the shelf reach box works in front of a divider as well as behind a wall line) | `scripts/world/shelf_fill.gd` |

**Gates:**

- `gen_signature_test` (new): every R02 gallery, 50 standalone and every
  gallery of library wings 1–10 (102 rooms), comes out module for module,
  rotation included, as before the builder changed. **103 checks pass.**
- `r03_layout_test` (new): 20 halls as the planner lays them out and 20
  standalone. **1,788 checks pass.** 69% of the bays off the aisles hold a
  bookcase (`case_density` 70%).
- `r03_route_test` (new): the real player capsule walks every clear bay of
  five halls and out through every door into the gallery beyond; every
  bookcase can be passed along both sides and none walked through; the hall
  validates clean. **44 checks pass.**
- Every earlier gate passes: `area_plan_test` 145, `area_route_test` 203,
  `stream_test` 40, `r02_route_test` 2,321, `r02_bake_test` 105,
  `book_test` 27, `prop_test` 51, `room_playtest` 31, `reading_room_test`
  87, `validate_room_test` 26, `kit_test` 1,060 (it caught the domes
  without collision at first; their ceiling slabs now have it),
  `socket_modes_test` 246, `age_test` 20, camp `playtest` 43; 240-frame
  runs clean for the camp, `--area=library` and `--area=lower_stacks`.

**The draw-call measurement (design 5.6.3):** a 7 × 7 hall costs 43–109
draw calls a view (450–930 objects): Godot 4.7's Forward+ renderer already
merges repeated meshes. A 10 × 10 hall should stay well under the 1,500
budget, so **step 2's batching probably isn't needed**; step 2 will confirm
it on the largest hall with the frame gate.

**"Little new code":** the hall's own code is 337 lines (260 without
comments). The one-time changes to shared code (builder, rules, planner,
menu) are 61 lines.

**What changed from the design, and why:**

- **R02's grammar didn't change.** The builder's new options all default to
  what it did before, which is safer than rewriting the gallery grammar,
  and the signature test proves nothing moved.
- **One Blender file for the hall** (`kit_hall.blend`) instead of separate
  vaults and columns files.
- **The walk along the walls** (`wall_aisle`, on by default): bookcases
  stood where wall recesses spill books and rubble, and the atlas plan has
  that walk anyway.
- **Lamps over the wall walk too:** with lamps only on the aisles, the
  corners and wall recesses were nearly black.
- **The reading tree is the Reading Room's iwan tree**, reused as is.

**Caveats, for your review:**

- **The columns read as stacked stone blocks more than twisted shafts.**
  The world-mapped stone texture is large next to the shallow flutes. Deeper
  flutes, more twist or a finer stone are all `.blend` or material changes;
  tell me which way you'd like it.
- **The plaster domes are dark** next to the tiled ones; the lamps hang
  below the arches and barely reach them.
- The Lower Stacks' galleries are ordinary R02 galleries with the wing's
  look and the wing's atmosphere; a deeper look for the Lower Stacks is
  later.
- `stream_test`, the frame gate and the persistence gate still walk only the
  library wing: their tours start from the Reading Room's doors. Making them
  walk any area comes with step 2 (frame gate) and the design's 5.6.9 list.
