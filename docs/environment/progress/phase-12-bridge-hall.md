# Progress: phase 12, the Bridge Hall (R21)

[Back to the front page](../../../ENVIRONMENT_PLAN.md) · [Approval brief](../phase-12-approval.md)

## Step 1: the hall and its bridge (built 2026-11-04, lit in step 1b after your walk)

What you can see: a test copy of the Lower Stacks where a Bridge Hall grows
off the Hypostyle Stacks. You go through the door into a dark rock passage
that bends, then come out of a cave mouth onto a straight stone bridge. It
runs across the hall to a cave mouth in the far wall, and through a second
bending passage to the next door. The long walls are carved rock with house
fronts set into them on two storeys: plaster, brick and tile, some windows
lit. Below the bridge is an 8 m drop to a rock floor with boulders. Above is
a rock roof with stalactites. The lighting is still plain (step 3): a lamp at
each end of the bridge and the lit windows.

Captures: `previews/phase12_step1/` (seeds 1 and 3). The `_worklight` ones
add a temporary light in the hall so the structure can be judged; it isn't
part of the room.

### What was built

- **Kit** (`tools/kit_add_r21.py` → `art_src/kit/kit_bridgehall.blend`, 11
  pieces): the cave passage (straight and bend; both ends share one profile,
  so pieces join), the cave mouth (rock from the end wall's square hole in to
  the passage), the two rough rock end walls (the mouth in bay 1 or 3), the
  rock roof with stalactites, and the pit floor with boulders (one each for
  halls 6, 7 and 8 bays long).
- **`BridgeHallGrammar`** (`scripts/gen/bridge_hall_grammar.gd`): reserves the
  hall's cells on every storey (2 below the deck, 3 above), plus three cells
  of passage at each end, and places the pieces as shell props, as the
  light-well does. It tries the seeded length first, then the others, both
  bends at each end. The far door is always there.
- **The long walls** are the Persian kit's face pieces facing into the hall,
  set 1.5 m in so the building behind each face (a window's recess) stays in
  the hall's own cells. Carved rock below the deck, house fronts on the deck's
  storey and the one above, rock at the top.
- **The bridge** (`BridgeHallBridge`, `gen/modules/bh_bridge.tscn`) is built
  from the Chasm Spans' pieces (`ChasmGrammar.build_room`): deck bays,
  balustrades with newels, the upper aqueduct arcade under each 12 m of deck,
  a stepped corbel and pier at an end the arcades don't reach, a lamp at each
  end. It also holds the fall catch (Q6). Not tested yet.
- **Rules and grammar files** by `tools/make_r21_rules.gd`; the test copy of
  the recipe by `tools/make_r21_draft.gd`
  (`gen/recipes/drafts/lower_stacks/bridge_hall_test.tres`); `RoomTypes`
  knows R21.
- **`tests/r21_capture.gd`**: eight views (passage, mouth, start, across,
  down, up, back, wide) plus the work-light set.

### What changed from the brief, and why

- **Where it grows:** the test copy grows the Bridge Hall first, before the
  galleries. Grown after them it was boxed in on all 20 seeds; grown first it
  fits on all 20 (lengths 6, 7 and 8 all appear).
- **The drop stays 2 storeys (8 m)**, as Q2 said. I'd first built it 12 m
  deep, but the Lower Stacks' envelope stops 8 m below its floor. The span's
  12 m arcade runs down past the pit floor, where it's hidden.

### Checks

- Headless 240-frame gate: pass, no errors.
- The capture runs (seeds 1 and 3) print no errors or warnings.
- Not done yet (step 4, after the look is final): the route audit, frame
  gate, map, save and resume, and a walk test of the fall catch.

### Open for your look

- The house fronts are picked per bay, so they read as patchwork (a plaster
  bay beside a brick bay beside a tile bay). I'd group them into buildings, a
  run of bays sharing one material, during step 3.
- Plain lighting: the hall is very dark without the work light. That's
  step 3: the mist glow from below, lamps and windows.

## Step 1b: lit after your walk (2026-11-04; you walked it: "looks great")

You walked it and couldn't see anything. Part of step 3's lighting is now in,
each light with a source you can see (captures in `previews/phase12_step1b/`,
seed 3):

- **Mist glow from below:** a luminous mist lies in the drop under the deck,
  with cold silver lights in it every 12 m (no shadows). They light the
  pit's rock and boulders, the lower walls and the deck's underside. A
  glowing pool plane on the pit floor was tried first, but it read as a flat
  white sheet from the deck, so it's gone.
- **Bridge lamps:** besides one at each end, a lamp on every third newel,
  alternating sides.
- **Window lights:** a warm light at up to 6 lit windows, spaced 8 m apart.
- **House fronts in buildings:** a run of 2–3 bays shares one material
  (rock-cut, plaster, brick, tile or banai), so the walls no longer read as
  patchwork.
- **Moss:** glow moss in the cave passages, so they're dim but not black.
- **Tint:** the room eases the area's light toward silver-white.

Lights: about a dozen in the hall (2–3 mist, up to 6 windows, 4 lamps); not
yet counted against the 50-in-reach gate (step 4).

## Step 2: bridges that climb, and the older bridge (built 2026-11-04, waiting for your walk)

You walked step 1b ("looks great"). Captures in `previews/phase12_step2/`:
seed 3 (level), seed 4 (climbs), seed 2 (drops). The `old`, `olddoor` and
`oldfar` views look across at the older bridge.

### What was built

- **Climbing and dropping bridges** (Q3): the seed picks level, up a storey
  or down a storey, a third each. The far half's arcade bay carries the
  span's flight: a landing then the flight up, or the flight down then a
  landing. The far cave passage and door are on that storey. On the test
  copy's 20 seeds: 7 level, 7 climbing, 6 dropping, all fitting.
- **The older bridge** (Q4): in the hall's other column, 4 m from yours,
  level, one storey over your deck. When yours climbs, it's a storey under,
  half drowned in the mist. It has no lamps. One of its arches pours a
  waterfall from a trough toward your bridge; the water falls just outside
  your balustrade.
- **Its sealed doors:** at each end the end wall swells into a rock outcrop
  round a carved doorway (`persian_carved_door_dark`), with one of the
  ornate doors from door travel set in it. You can't reach them; they mark
  where the four-door version will go.
- **Kit:** the end walls now come in 8 versions: the mouth on the entry's
  storey or the far door's, and the outcrop for the older bridge's door over
  or under the deck (`tools/kit_add_r21.py`, `bh_end_wall_c<1|3>_<lv|up|dn>_<hi|lo>`).
  The two step-1 end walls are gone.
- **The mist** stays under the lowest deck, so a dropping bridge's far half
  isn't walking through fog.
- **The fall catch** now goes by the deck's height under you (the old one
  would have fired on a dropping bridge's lower deck). Still not walk-tested.

### Open for your look

- The carved doorway's panel is a flat block of dressed rock set into the
  rough outcrop. Up close it reads as a slab, not as a door cut in the cliff.
  I'd soften it in step 3 if it bothers you.
- The older bridge is as clean as yours. Weathering it (fallen parapet
  patched with timber) is step 3.

### Fixed after your walk (2026-11-04: "step 2 looks good")

- **Walking on air down the flight:** every room has a temporary safety
  floor 2.5 m under it (AGENTS.md). On a dropping bridge the lower half of
  the flight and the lower deck (4 m down) are under it, so you walked on
  it, up to a metre over the steps. The safety floor now goes 2.5 m under a
  room's lowest storey (`GeneratedRoom._add_safety_floor`), here under the
  pit. `tests/r21_flight_probe.gd` rays down at each walk point and checks
  you stand on the deck or the flight's steps: passes on a dropping (area
  seed 177102574), a climbing (4) and a level (3) bridge.
