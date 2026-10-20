# Progress: phase 3, props and persistence

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · Design: [approval brief](../phase-3-approval.md), [technical](../phase-3-design.md)

**In short:** step 1 is built. R01 has two floor vases you can knock over
with E or by walking into them, and they break if they fall hard. The
things on the reading tables can be pushed too. Nothing is saved yet
(step 2).

---

## Step 1: a vase you can knock over (built 2026-10-20, waiting for your review)

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
