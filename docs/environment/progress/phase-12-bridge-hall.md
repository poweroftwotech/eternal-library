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

## Step 3: plants, the landing and the weathered older bridge (built 2026-11-04, waiting for your walk)

Captures in `previews/phase12_step3/`: seed 3 (level), 4 (climbs), 2 (drops).
New views: `landing`, `herb` (the pot by the entry lamp), `mushroom` (in
the entry passage); `olddoor` now looks from the older bridge's deck (fly
mode, V) at its sealed door.

### What was built (`BridgeHallLife`, `scripts/gen/bridge_hall_life.gd`)

- **Hanging gardens** at every lit window: ivy trailing from the sill, clay
  pots on it, an awning over about half. Lit by the window lights.
- **Things to pick** (as the alcoves' patches; they grow back when the room
  is next built): herbs in a pot by each bridge-end lamp and on the landing;
  shelf mushrooms at the foot of the rock in each cave passage's cell by the
  hall.
- **The halfway landing:** on the middle bay (a climbing or dropping
  bridge's: the bay before the flight), against the balustrade toward the
  older bridge: a floor seat, a kilim rug, a cushion with a book left open,
  the keeper's pack, a lamp on a stool. Its warm light stands in for the
  newel lamp nearest it, so the light count doesn't grow.
- **The older bridge weathered:** about 3 in 10 parapet bays fell and are
  railed with timber, 1 in 10 is simply gone; moss and tufts on its deck,
  ivy over its edges.
- **The sealed doors softened:** ivy over the arch, moss, ferns and rubble at
  the foot. From its own deck the doorway now reads as a door in the cliff.
- **In the dark:** 70 ferns, moss, crack tufts and fungus clusters on the
  rock under the deck and on the pit floor (rays from the drop, after the
  room's collision is in; fungus and ferns on ledges, tufts on steep rock).
- **Rising mist:** 5 wisps of fog rise slowly from the mist past the deck,
  swelling then fading. Can't be judged in a still; walk it.

### Not done

- Figs and grapes to pick: the satchel only knows herbs, roots and
  mushrooms, so the gardens' fruit would need a new item (and the cooking
  panel would need to use it). I'd offer it separately.
- The tint already eases in by the room's own setting (step 1b); nothing new.
- Lights in reach not yet counted (step 4). The hall gains the landing lamp
  and loses a newel lamp.

### Checks

- Headless 240-frame gate: pass. Flight probe: pass on seeds 2, 4, 3.

### Fixed after your walk of step 3 (2026-11-04, 4 reports)

Captures in `previews/phase12_step3b/` (your seed 177102574, and 3). New
view `window` (a window's garden).

- **Pots at the bridge ends looked wrong:** gone. Wild herbs to pick now grow
  at each cave mouth, on the rock's foot where the end lamp reaches, with
  ferns round them (found by a ray, as the mushrooms are).
- **Pots floating on the walls:** the gardens now find each lit window's
  opening by rays into its face. Pots stand on the real sill and ivy trails
  from the sill's front edge. Awnings are gone: they floated over windows of
  other heights. Before, only 3 of 13 windows were found and the ivy was
  inside the wall.
- **The keeper's things in the middle of the bridge:** the landing is now a
  side deck, 2 m out from one bay, with its own balustrade, newels at its
  corners and stone corbels under it. The seat, rug, book, pack and lamp are
  on it, out of the walkway; no pot. It looks across at the older bridge,
  on a bay clear of its waterfall. On your seed the water covers every
  middle bay on that side, so the side deck stands out toward the house
  fronts instead.
- The mushrooms sit on the cave floor (they hovered a little).

Checks: headless gate pass; flight probe pass on 177102574, 4, 3.

### Fixed after your second walk of step 3 (2026-11-04, 4 reports)

Captures were in `previews/phase12_step3c/` (since replaced by `phase12_step3d/`). New
views: `ivy` (close on a window's ivy), `pool` (the fall's foot), `pitwall`.

- **Vines hanging the wrong way (windows, by the side deck):** the ivy piece
  is made for a rail. Its few flat leaves lie on the rail top and the strands
  hang on the far side. Unturned, those flat leaves stuck out into the air
  like a shelf. Now it is turned so they lie back on the sill and the
  strands hang just clear of the wall. The ivy over the sealed doors is
  turned the same way.
- **Where does the water go?** The bottom of the drop is now a dark, still
  pool, about 0.35 m deep over the pit floor. Its boulders and its rising
  edges stand out of it, and the old bridge's fall lands in it. Its water
  (`kit/materials/bridge_pit_water.tres`) is darker than the cistern's and
  doesn't glow.
- **Odd plants on the rock walls:** tufts and moss stretched across steep
  rock are gone. The dark growth keeps to ledges and to the floor above the
  pool, and the ferns there are smaller.

No route or frame tests yet (look still settling).

### Fixed after your third walk of step 3 (2026-11-04, 4 reports)

Captures in `previews/phase12_step3d/` (your seed 177102574, and 3).

- **Vines floating away from the railing, and too far off the walls:** the
  ivy's strands hung 0.15 to 0.3 m out from the wall. They now hang against
  the face, with the root just inside the sill's edge, centred and 0.25 m in
  from the opening's sides so the flat leaves don't run past the sill's end.
  Where the strands would hang down past a rail or a ledge (as by the side
  deck), there's no ivy.
- **The water needs to move:** nothing was driving the pit water's clock, so
  it stood still. The bridge now drives it, and the surface drifts slowly.
- **Ripples and mist at the foot of the fall:** rings spread on the pool
  from a churned patch where the fall lands (`shaders/fall_ripples.gdshader`),
  with a low bank of spray over it. No extra light, so the light count is
  unchanged.

No route or frame tests yet (look still settling). The animation only shows
in the game, not in a still capture.

### Fixed after your fourth walk of step 3 (2026-11-04, 2 reports)

Captures in `previews/phase12_step3e/` (your seed 177102574, and 3).

- **Glowing mushrooms at the bottom, on the rocks or the shore but not in the
  water:** 12 clumps of glowing caps now grow where the pit floor rises out
  of the pool and on the boulders' tops (`BridgeHallLife.shore_glow`). Half
  of them have a tall teal cap (`persian_fungus_small`), and the rest are
  small glowcaps.
- **Light budget:** each of these pieces carries its own lamp. Twelve clumps
  would have added up to about 36 lights, far past the room's limit of 50.
  Their lamps are taken out, and 2 dim teal lights stand by tall clumps
  instead (at least 8 m apart). The caps glow on their own.

## Step 4: the hall in the real areas, and the tests (built 2026-11-04, waiting for your OK)

What you can see: the Bridge Hall now grows in the real Lower Stacks and the
Forgotten Wing, not only in the test copy. It grows off the hypostyle hall or
one of the galleries, after the light-well and before the cistern (your
choice). On the map it shows as its bridge and its two passages; the air over
the drop isn't drawn.

### Where it fits (20 seeds per order, both areas plan the same for a seed)

| Order | Bridge Hall | Light-well | Upper | Cistern |
|---|---|---|---|---|
| Hall last | 4/20 | 20/20 | 20/20 | 16/20 |
| Hall after the galleries | 20/20 | 10/20 | 9/20 | 12/20 |
| **Hall after the light-well (chosen)** | **11/20** | **20/20** | **20/20** | **11/20** |

So a Bridge Hall turns up in about half of all seeds, and costs the cistern in
5 of them. Recipes: `gen/recipes/lower_stacks.tres` (v9) and
`gen/recipes/forgotten_wing.tres` (v2). Sweep tool: `tests/r21_fit_sweep.gd`.

### What changed to make it pass

- The walking route through the hall follows the passages and the bridge's
  deck (`BridgeHallGrammar` route; `AreaTour` uses it), not the hall's cells,
  which are mostly air.
- The hall's air cells are marked `no_map`: the map leaves them out, and the
  route audit doesn't look for floor or leaks there.
- The bridge and its life aren't checked against the cell grid (`off_grid`),
  and the pit and roof pieces close their own cells (`walled`; the roof is
  `scenery`, out of reach with no collision). Tags set in
  `art_src/kit/kit_bridgehall.blend` and re-exported.

### Checks

- **Route audit** (`tests/area_route_test.gd`, now with `area=forgotten_wing`
  and `only=`): every Bridge Hall walk passes (Lower Stacks seeds 1, 6, 11,
  13, 14, 16, 19, 20, Forgotten Wing seed 6). The failures left were already
  there before phase 12, the same with the old recipe: arch growth against a
  wall case in the hypostyle hall (seeds 8, 13, 16), rubble against a reading
  desk (10, 15), a walk one stop short (15, 17). They're on a separate task.
- **Frame gate** (Medium, `tests/area_walk_capture.gd`): in the Bridge Hall,
  seed 6: CPU mean 1.6 ms, worst 11.1 ms (one frame over 8), GPU mean 1.0 ms,
  29 lights in reach, 1 shadowed, 0.61 M triangles; seed 11: CPU worst 8.3 ms,
  22 lights, 0.40 M triangles. The whole-area gate still fails elsewhere, as
  before: a 105-117 ms hitch in the caravanserai and 60-80 lights in reach at
  the caravanserai and hypostyle hall (the hall adds 1). CSVs in
  `previews/phase12_step4/`.
- **Save and resume** (`tests/r21_resume_test.gd`, two processes): saved on
  the middle of the bridge, a new process resumes there on the deck. Stepping
  off the bridge puts you back in the passage you came in by. The map draws
  the hall as its bridge and passages, none of its air, with you on it
  (`previews/phase12_step4/map.png`).
- **Kit gate** (`tests/kit_test.gd`): 7751 checks, 0 failures.
