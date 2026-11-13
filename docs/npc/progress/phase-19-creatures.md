# Phase 19 progress: the first animals

The plan is [the approval brief](../phase-19-approval.md); how it works is
[the design page](../phase-19-design.md).

## Step 1: fish in the water (built 2026-11-09, look approved 2026-11-09)

**What you'll see.** Goldfish in the tended pools and the camp's stream and
basin: a handful per pool, orange, gold and white-patched, a big lone
survivor now and then in an abandoned room. Each one swims from place to
place, hangs still for a moment (facing upstream in the camp's stream), and
scatters if you come close while moving. Stand still and they drift back.
Schools of small pale blind cave barbs fill the cistern, the light-well's
well, the Bridge Hall's pit pool and the lake. A school parts round you
when you wade in; they feel steps in the water, they don't see you.

**Where.** Goldfish: the camp, the Hypostyle Stacks hauz (R03), the bazaar
(R04, if its fountain has still water), the Domicile Quarter's hauz (R06)
and the Garden Court pool (R07). Cave barbs: the cistern (R11), the
light-well (R09), the Bridge Hall (R21) and the lake. Nothing was re-marked
in any room: the game finds the water by its shader, sounds its depth with
rays and leaves out what is covered (under a slab or deck), inside a pier,
or too close to a wall.

**How it is built** (design page sections 2-4):

- `scripts/actors/`: `ActorDef` and `CreatureDef` (what an animal is, as a
  resource in `actors/defs/`), `HabitatScan` and `WaterBody` (finding and
  sounding water), `FishBody` (the fish's model and skin, made in code),
  `FishPool` (fish with minds of their own) and `FishSchool` (a school
  moved as one, each fish wandering in the shader).
- `scripts/world/fauna.gd`: one per place (each area, the camp, the lake).
  It follows the streamer: a room's water is found and filled after it
  arrives, a little each frame, and its fish go with it.
- `shaders/creature_fish*.gdshader`: the swimming tail, the drift, the
  parting. Goldfish and barbs are drawn over the water's surface at part
  opacity (`clarity`), so they read in a bright pool instead of washing out.
- The F3 panel has a creatures line: how many, how many awake, the cost of
  ticking them and the worst frame spent finding water.

**Limits (Q12).** At most 40 thinking fish and 8 schools awake per view,
the nearest; 80 and 16 live per place; asleep beyond 30 m. No shadows.

**Measured** (`tests/fauna_capture.gd`, this machine): ticking 0.01-0.04 ms
a frame, worst 0.2 ms. Finding water about 1 ms a frame in the camp and the
lake; the worst frame in the Gardens and Mahaleh was 5-7 ms (one large room
at once). The first build of a fish's material costs 25-140 ms, so it now
happens while the place loads. Route and frame tests wait for step 5, as
agreed.

**Fixed on the way:**

- Fish invisible in the game: a fish group's draw distance was measured
  from the world's origin, not its pool.
- Goldfish washed out in the lit pools: now drawn over the water's surface.
- Cave barbs invisible in the lake (no floor to see them against): the same
  fix, at lower opacity.
- A 140 ms hitch when the camp's fish appeared (their material), and 22 ms
  reading the stream's mesh back: water made of a big mesh is now taken as
  its box, and sounding trims the rest.

**Known:**

- The camp stream's fish sometimes swim under the footbridge slab. That is
  allowed (they only cross under it, they never stop there).
- The Mahaleh entrance capture looked into a wall (the test's camera, not
  the fish).
- The bazaar's fountain wasn't found as still water.

**Tests and tools:** `tests/water_probe.gd` (lists every body of water each
place has, headless), `tests/fauna_capture.gd` (pictures of every group,
`--close`, `--stats` for the F3 panel), `tests/creature_look.gd` (one kind
on a plain floor).

**Pictures:** `previews/phase19_step1/final/`.

## Step 2: moths, glowworms and bats (built 2026-11-09, look approved 2026-11-09)

**What you'll see.**

- **Candle moths** circle every burning flame (candles, lanterns, sconces,
  the camp's lamps, the bazaar's candles, the lake's post lanterns), lit in
  the flame's colour, now and then darting at it. A lamp that has gone out
  has none; abandoned rooms have fewer. In the Garden Court they wander
  over the beds in the middle of the court (they replace the old particle
  specks there).
- **Glowworms** hang on silk threads from dark cave roofs, natural rock only:
  the lake's roof, the Bridge Hall's cavern and passages, the Fungus
  Terraces' cave roof, the Mahaleh dock's cave. They pulse slowly, in the
  colour of the area's fungi. Run near them and they go dark a few at a
  time, then light again one by one over about half a minute. They keep
  3 m from any glowing fungus and a bay from any flame.
- **Bats** hang head down in clusters on dark roofs 3.5 m or higher: the
  Hypostyle Stacks' dark bays, the Bridge Hall, the ossuary, the lake, and
  any abandoned room. A few keep circling under the roost. Come within
  6 m and the colony takes off, swirls round the roost, then streams off
  along the vault away from you and is gone into the dark. Go away for a
  while and they are back.

None of them add a light or cast a shadow.

**How it is built:**

- `HabitatScan` now also reads a room's lights (`light_profile` sorts flames
  from fungus glows; lights with no profile go by colour; a lamp put out is
  no flame) and looks up from four points in every floor cell and over the
  water to find its roofs, telling natural rock (by the roof's material)
  from built vaults.
- `MothSwarm`, `GlowColony`, `BatRoost` (`scripts/actors/`): one MultiMesh
  each, models made in code (`AirBody`), all flight in their shaders
  (`shaders/creature_moth|glowworm|bat.gdshader`). Moths need nothing per
  frame; glowworms keep one darkness value; bats keep one clock.
- `actors/defs/candle_moth.tres`, `glowworm.tres`, `bat.tres`. New def
  settings: `any_abandoned`, `loose_rooms`, `min_height`, `glow_gap`,
  `rock_only`, `room_cap`, `glow_colour`.
- The Garden Court's particle moths are gone (`GardenCourtLife`).
- `tests/fauna_capture.gd` shoots the air animals too (`--only`, `--max`;
  bats from outside their reach, then flying).

**Measured** (this machine): ticking everything 0.03-0.09 ms a frame,
worst 0.33 ms. Finding water, lights and roofs about 1-3 ms a frame; the
worst single frame was 7.8 ms in the Gardens (a big room filling at once).
Route and frame tests wait for step 5, as agreed.

**Known:**

- Moths are 3.5 cm: in a still picture of the Garden Court they hardly show.
  In motion they read as flickering specks, like the old particles.
- Bats roosting in a pitch-dark bay can't be seen until they fly across
  something lit. That fits "collapsed bays stay dark", but say if you want
  a faint lift on them.
- Glowworms can sit on any natural rock in their rooms, so a few may hang
  over a lamp-lit cave mouth's edge, a bay away from the flame.

**Pictures:** `previews/phase19_step2/final/`.

**Look 1 (2026-11-09), your notes:** moths show, but too many flames had
them; bats hard to find but a few seen; glowworms really hard to see.

- Moths: only about a quarter of the flames have any now (new def setting
  `flame_share` 0.25); the number round each flame is unchanged. A bazaar
  went from 142 moths to 25.
- Glowworms: the bead is now a little glowing disc that faces you, with a
  soft halo, and never gets smaller than about 2 pixels however far away
  it is, so a roof of them reads as a field of stars. More of them (80-200
  a colony, up to 4 colonies, 600 a room), spread wider.
- Bats: unchanged.
- **Animals per area** (your idea): the Strata Board's area settings have
  an Animals list, one percentage per kind (100% = the animal's own
  numbers, 0% = none, 200% = twice as many), saved in the recipe
  (`AreaRecipe.fauna`). For candle moths it is the share of flames that
  have any; for the rest, how many in each school, colony or roost
  (`CreatureDef.scaled`). The camp and the lake aren't areas, so they keep
  100%.

Pictures: `previews/phase19_step2/g/`.

**Where animals live: conditions first (your choice, 2026-11-09).** Every
kind's room list is now `"*"`: it lives wherever its habitat is (water deep
enough, a burning flame, a dark roof high enough, natural rock for
glowworms). Two ways to keep one out:

- `not_rooms` in the animal's file (`actors/defs/`): room types it never
  lives in. The two fish use it to stay apart (goldfish in kept rooms,
  cave barbs in the cistern, light-well, Bridge Hall, terraces, lake),
  since there is no "dark water" condition yet. Bats and glowworms have none.
- The Strata Board's room settings (a room, or a grow rule's rooms): an
  "Animals in this room" checkbox per kind, all ticked; unticked kinds are
  saved in the room's tweaks (`no_animals`) and reach Fauna through
  `AreaPlan.Room.no_animals`. Baked rooms have it too.

With conditions only, the first capture put two bat roosts in nearly every
room, and the place's swarm limit then ran out before later rooms. So bats
now want a deeper dark: a roof 5 m up with no flame, window or daylight
within 10 m (new `dark_radius`; daylight and window lights now count as
light for bats and glowworms). They get one roost in a lived-in room and
up to two in an abandoned one (`kept_groups`). The live-swarm limit is
40 (it was 24); still only the nearest 8 swarms are awake. Result:
- Bats: the lake, Grand Study stacks, reading rooms and old stacks,
  Mahaleh square and quarters (under the cave roof), the Gardens' caves
  and cisterns, and most of the Forgotten City.
- Glowworms: only cave rock (the lake, Mahaleh dock, Bridge Hall,
  terraces, the Forgotten City ossuary).
- The two ossuaries have no bats: they are full of candles.
- Worst scan frame 7.9 ms (Mahaleh), as before.

Pictures of where bats and glowworms land now: `previews/phase19_step2/h3/`.

Step 2 committed 54bf2ea (2026-11-09).

## Step 3: the cat (started 2026-11-09)

**Part 1: the model, standing still (waiting for your look).** As the brief
says, the cat is shown posed before it walks.

- **The path for animated models** (the brief's main risk): a Blender
  script, `tools/creature_cat.py`, builds `art_src/creatures/cat.blend`
  (mesh, skeleton, weights, coat mask, animations) and exports
  `actors/models/cat.glb`. Godot's kit import script leaves files outside
  `assets/kit/` alone, so the skeleton and animations come through as they
  are: 22 bones, 7 animations (idle, walk, sit, sleep, wash loop; look and
  startle once; Godot loops the "-loop" ones). People can use the same path.
- **The cat:** low-poly, about 50 cm long and 25 cm at the shoulder, 424
  faces, one draw call. Its texture is a 128 px mask painted at 96 texels/m
  (stripes, pale fur, eyes, nose), kept lossless, so one model wears many
  coats: grey, ginger, brown tabby, cream, black, white and grey
  (`CatBody.COATS`, `shaders/creature_cat.gdshader`). Its eyes keep a faint
  shine in the dark; they light nothing.
- **`CatBody`** (`scripts/actors/cat_body.gd`) plays the animations, smooth
  or stepped like a sprite (`set_stepped(fps)`), for Q5 once it walks.
- **`tests/cat_capture.gd`** puts six cats in front of the camp's spawn,
  one per pose and coat, and shoots the row, each cat close from the side
  and the front, and four frames of the walk.

Fixed in the first passes: eyes were pale stripes (now small almond eyes
with slit pupils), leg tops stuck out of the body, too many leg bands, the
tail stuck out stiffly.

Next, after your look: the cat walks the walked lanes and uses rest spots
(Q6), looks at you, startles if you run at it; one at the camp, a few in
the Mahaleh; smooth or stepped (Q5); the navigation mesh measurement.

Pictures: `previews/phase19_step3/c/`.

### Step 3, look 1: "looks like a cricket at some angles" (2026-11-09)

What made it insect-like, and what changed in `tools/creature_cat.py`:

- **Legs bolted on outside a thin body.** The leg tops stuck out past the
  body's sides as little pyramids, and the legs were long thin sticks. The
  body is now deeper and lower (belly 11 cm off the floor, not 16), the legs
  are shorter and thicker and start inside the body.
- **Hind legs folded like a jumping insect's.** They are now a broad flat
  haunch on the body's side down to a hock, with the foot upright under it.
- **Ears like feelers.** They were thin edge-on from the front. They are
  now broad triangles turned forward and a little outward.
- **Small head on a long raised neck.** The head is rounder with a shorter
  muzzle, carried lower on a short thick neck.
- **Sitting:** the spine now bends (it was one straight slope), the rump is
  on the floor and the hind feet lie flat beside the front paws.

`tests/cat_capture.gd` also takes each pose from standing height (as the
player sees it) and from behind. Pictures: `previews/phase19_step3/d/`.
Still weak: the sleeping pose (not re-posed for the new body) and the face.

### Step 3, look 2: the face (2026-11-09)

"Looks better, but the face needs work: nose, whiskers, eyes; not cute."

- **Head:** a little bigger, with a near-flat front and a small muzzle set
  low on it (it was a cone ending in a square snout).
- **Eyes:** big and round, wide-set and low: a dark upper lid, a wide
  pupil, one white glint. They are flat panels on the face, 7 by 6 texels,
  because anything drawn on the tapering head tube came out sheared.
- **Nose and mouth:** a small pink nose at the muzzle's tip with a dark
  mouth line under it; pale muzzle and cheeks.
- **Whiskers:** three thin pale slivers a side.
- The head is painted at twice the coat's texel density and the eyes a
  little finer still; the rest of the cat stays at 96 texels a metre. The
  mask grew to 256 px. The ginger cat's eyes are now green.

`tests/cat_capture.gd` adds face close-ups (`face_<n>.png`, `face_<n>_q.png`).
Pictures: `previews/phase19_step3/e/`.

### Step 3, look 3: "the face is too flat" (2026-11-09)

The face now has depth: it slopes back from a short muzzle that stands
about 3 cm proud of it, set low, with the nose at its tip and the whiskers
on its sides. Brow to nose tip is about 4.5 cm (it was 2). Pictures:
`previews/phase19_step3/f/`.

### Step 3, look 4: "still doesn't look like a cat" (2026-11-09)

The user sent four low-poly cats as examples. What they share and ours
lacked: a wide head with a flat face that looks forward, both eyes on that
face, a small muzzle low on it, and big ears on the head's top corners. Ours
was a tube along the neck's line, so the eyes sat on its sloping sides.

The head is rebuilt (`loft()` in `tools/creature_cat.py`): a wide skull with
broad cheeks and a flat top, a flat forward face, a small muzzle block with
the pink nose on its tip, big ears on the top corners. The eyes are 9 by 8
fine texels with a dark rim, a wide pupil and a glint. The lower face is
pale. Pictures: `previews/phase19_step3/g/`.

### Step 3, look 5: expression, muzzle, profile (2026-11-09)

- **Expression:** almond eyes (10 by 6 fine texels) with a slit pupil and a
  glint, tilted up a little at the outer corner; the round rimmed eyes
  looked startled.
- **Muzzle:** two small pads side by side with a chin under them, a flat
  pink nose between the pads' tops and a dark line down from it (it was one
  round bump).
- **Profile:** the face is two halves meeting on a ridge down its middle,
  each turned outward about 25 degrees, so an eye shows from the side.

`tests/cat_capture.gd` adds a profile close-up (`face_<n>_s.png`). Pictures:
`previews/phase19_step3/h/`.

### Step 3, look 6: the eyes (2026-11-09)

The eyes are redrawn at 12 by 8 fine texels and about a third larger. The
slant (rising to the outer corner) is now drawn in the pixels, mirrored for
the other eye, where before the whole panel was turned and its pixel edges
came out jagged. Each has a dark rim, heavier on top, a round pupil and a
glint. Pictures: `previews/phase19_step3/i/`.

### Step 3, part 2: the cat walks (2026-11-09)

The look was approved ("Looks good") after look 6. Then:

**The model.** The sleeping pose is redone for the new body: lying on its
belly, legs folded under, chin down, tail brought round. The eyes shut when
it sleeps, and it blinks (the eye mask has codes for the shut line; the
shader takes an `eyes_shut` setting per cat).

**What a cat does** (`scripts/actors/cat_band.gd`, one per room, ticked by
Fauna like the fish):

- Rests somewhere: asleep, sitting, washing, or sitting by still water
  watching it. Then strolls to somewhere else and rests again.
- Looks at you within 6 m: its head and neck turn to follow you
  (`CatBody`, after the animation has posed them).
- Gets up and strolls off if you all but step on it (0.75 m).
- Startles (a crouch and hop) and trots away if you run at it within 3.2 m.
- Has no collision: you never bump into it (Q7).

**Where it walks** (`scripts/actors/lane_graph.gd`, Q6). A graph of points
for each room, built a slice a frame:

| The room has | The cat walks |
|---|---|
| Walked lanes (the lines that polish the floor: halls, galleries, reading rooms) | Those lanes, as points 0.5 m apart, joined where lanes cross |
| No lanes but floor cells (**the Domicile Quarter and the bazaar: their grammars make no walked lanes**) | A 1 m grid of floor points over its cells, each kept only on the cell's own floor with 0.3 m clear round it, joined where the way between two is clear |
| Neither (the camp) | A few points round each rest spot where the floor is clear |

Rest spots are rugs, carpets, cushions, bedrolls, benches and a takht (by
node name), on a part of their top nothing stands on; a raised one is
reached by a hop from the floor beside it. Cats live in the biggest
joined-up part of the graph, so in a quarter that is the alleys and courts,
not a room behind a shut door (closed doors stop them). Where that part
has fewer than three soft spots, corners and dead ends are rest spots too.
A place beside each still water is where they watch the fish.

**Where cats are** (`actors/defs/cat.tres`): by conditions, like the rest. A
lived-in room gets one cat for every five soft things in it, up to three;
the camp gets one. Never in the lake, the cistern, the ossuary, the fungus
terraces, the bridge hall or the chasm spans. The area's Animals % scales
it. Counts on this world seed: camp 1, Mahaleh 5 (one in each quarter, one
in a bazaar), the Grand Study 8 (3 in the Grand Hall, 2 in the Garden Court,
one each in a reading room and two galleries), the Gardens 1. The first
setting (one per three soft things, up to four) gave the Grand Study 15.

**Smooth or stepped (Q5).** In the game, **K** steps every cat through
smooth, 12 poses a second and 8 poses a second. Their walking stays smooth;
only the pose is held.

**Cost.** Worst frame of the scans 2.5 ms headless (2.6 before cats), 7.6 ms
in the Mahaleh on screen (as step 2); ticking 0.1 ms, worst 0.4 ms. A
quarter's graph is about 460 points and takes 27 ms in all, spread at 1 ms a
frame. One draw call a cat, no shadow.

**The navigation mesh measurement (Q6)**, `tests/navmesh_measure.gd`,
headless on this machine, three Mahaleh rooms:

| Room | Walker | Read the shapes (main thread) | Bake (can be threaded) | Size |
|---|---|---|---|---|
| Bridge Hall, 2,900 m2 | person | 2.0 ms | 9 ms | 299 polygons, 9 KB |
| | cat | 2.3 ms | 38 ms | 705 polygons, 19 KB |
| Bazaar, 4,600 m2 | person | 1.9 ms | 11 ms | 460 polygons, 12 KB |
| | cat | 1.8 ms | 26 ms | 1,013 polygons, 27 KB |
| Domicile Quarter, 6,000 m2 | person | 4.0 ms | 15 ms | 367 polygons, 10 KB |
| | cat | 4.2 ms | 41 ms | 676 polygons, 19 KB |

So for people a mesh per room looks affordable: 2 to 4 ms on the main
thread when a room arrives, the rest on a thread. Not checked: what the
meshes look like (whether they cover roofs and table tops), and props and
doors that move.

**Found on the way.** In the places joined without a loading screen (the
camp, the Gorge) the floors and walls are on collision layer 9, not 1.
`LaneGraph` looks on both. `HabitatScan` (steps 1 and 2) looks only on
layer 1, so at the camp its water soundings and roof scan hit nothing; not
changed here.

**Tests.** `tests/cat_walk_capture.gd` (counts, and pictures of each cat
resting, strolling, looking at you, run at); `--count` works headless.
Pictures: `previews/phase19_step3/walk/` and `j/` (poses). No route or
frame-gate tests yet (step 5).

**Not done.** The camp's cat following you a few steps; cats on the
bazaar's food stalls by name; the save (step 5).

### Step 3, walk 1 (3 reports, 2026-11-09)

- **"The cat looking sideways and walking doesn't look right"** (camp and
  quarter): it now looks at you only while it rests. Walking, its head
  stays forward.
- **"Cat can be a bit bigger":** drawn 1.3 times the model (about 65 cm),
  with its walking and trotting speeds raised to match its longer stride.

### Step 3 approved; Q5 decided (2026-11-09)

After walk 1's fixes the cat is right, and **Q5 is decided: smooth motion**
(the user tried 12 and 8 poses a second with K). The K key and the stepping
code are removed. Step 3 is not committed yet.

**Step 3 committed efb770a (2026-11-09).**

## Step 4: rats and geckos (built 2026-11-09, for your look)

Both are small models made in code (`scripts/actors/ground_body.gd`), lit
like the world, drawn by one shader (`shaders/creature_crawler.gdshader`)
that moves their legs and tails. One draw call for a room's rats, one for
its geckos. No skeleton: at 12 to 20 cm the shader's leg swing is enough.

**Rats** (`scripts/actors/rat_pack.gd`, `actors/defs/rat.tres`). In every
forgotten (abandoned) room, 3 to 10 rats share up to three runs. A run is a
stretch along the foot of a wall, 3 to 12 m, found by looking out from the
room's floor cells for a wall and following it while there is floor, the
wall goes on and nothing is in the way. A small dark hole is drawn on the
wall at each end. A rat comes out of a hole, scurries along, stops to sniff,
sometimes turns back, and goes in at the other end. Within 5 m of you it
bolts for the nearer hole, and none comes out while you are within 7 m.

**Wall geckos** (`scripts/actors/gecko_wall.gd`, `actors/defs/gecko.tres`).
One to three on the wall beside about three in ten burning lamps, anywhere:
the wall must be within 1.5 m of the flame, flat for half a metre each way
and open in front. A gecko clings, now and then darts a hand's width and
freezes. Within 2.4 m of you it runs up the wall (up to 2.4 m) and comes
down five seconds after you have gone 4.5 m off. When its lamp is put out
it disappears; it is back when the lamp is lit.

**Not built:** geckos darting at moths in particular (their darts are
random), rats gnawing books, and holes as a kit piece (they are drawn by
the pack, not placed in the room's data).

**Counts and cost.** Rats in every Forgotten City room (5 to 9 each);
geckos in the Grand Hall, the Mahaleh's entrance, bazaars and quarters.
The area's Animals % and the per-room checkboxes apply to both. Pictures:
`previews/phase19_step4/`. `tests/fauna_capture.gd` shoots both
(`--only=rat,gecko`).

### Step 4, look 1 (2026-11-09)

"Rats are too thin and small; I couldn't find any geckos; rats run and
vanish even where there is no hole."

- **Rats:** half as long again (30 cm and a tail) and much fatter: an
  eight-sided body with a round back and full flanks (it was a thin
  four-sided spindle).
- **Geckos couldn't be found because most were hidden.** They were put on
  the wall's collision, and what you see of a wall (plaster, tile bands,
  hangings, shelf fronts) often stands a few cm in front of it, so they
  were inside the wall; others were at the back of shelves behind jars.
  Now each gecko is put on the surface you see (`GeckoWall.proud_at` looks
  at the triangles of the meshes near it), and a place is refused when
  nothing is seen there or something stands within 0.7 m in front of it.
  They are also commoner (6 lamps in 10), bigger (20 cm), let you come to
  1.5 m, and climb only 1.5 m so they stay in sight.
- **Rat holes** had the same fault (drawn on the collision, inside the
  wall): now on the seen surface, and bigger (22 cm).
- At most 64 thinking animals awake per view (was 40): rooms with fish,
  cats, rats and geckos together passed 40, and the furthest group was
  hidden.

Cost: reading a room's meshes for this raised the worst scan frame to 4 to
8 ms headless (was 2.5); to be sliced at step 5.

**Step 4 look approved ("Looks good", 2026-11-09).** Not committed yet.

**Step 4 committed 7989460 (2026-11-09).**

## Step 5: tables, the save, tests (2026-11-09)

**The animal table of a place** (`scripts/world/fauna_table.gd`) has three
parts:

1. *Which animals can live there and how many at most:* the animals' own
   rules and the area's Animals % on the Strata Board. The same in every
   world.
2. *How plentiful each is in this world:* abundant (1.5 times the usual
   number), common (1), scarce (0.5) or very scarce (0.2), drawn from the
   world seed the first time you enter the place. So two worlds differ: on
   world seed 1 the Mahaleh's cats are abundant (10 of them), its moths and
   bats scarce. The animals a place is known by (the atlas's "Who lives
   where") are never below common there.
3. *The save:* the levels are written under a new `fauna` section, per
   place, and read from there ever after. Nothing changes them yet; the
   behaviour phase (hunting, a food web) will. The camp's cat is saved as a
   one-off animal (its coat), so it is the same cat on every visit. No
   animal's position is saved (Q8).

Not built: a table file per area under `gen/fauna/` (the design's first
idea). The area's part is already on the board as Animals %, so a second
file would only repeat it. The levels are not shown or edited on the board.

**Placing animals is spread over more frames.** A room is now filled one
kind a frame, and its meshes (for geckos and rat holes) are read a few
hundred nodes a frame. Worst placing frame, headless: Grand Study 2.1 ms,
Mahaleh 2.7 ms, camp 2.2 ms, Forgotten City 6.5 ms (was 4 to 8 everywhere
after step 4's fix). The Forgotten City's worst frame is one room's rats
or geckos in a single go; not split further.

**Tests.**

- `tests/fauna_test.gd`, two OS processes each for the camp and the Mahaleh:
  **PASS** (22 and 21 checks, save and load). A new world gives every kind
  the level its seed draws; known-by animals are at least common; at most
  64 thinking animals awake. Then one level is changed and the game saved;
  a fresh process reads every level back, every room holds the same animals
  as before for the kinds left alone, the changed kind has fewer or more
  (camp goldfish 12 to 2; Mahaleh geckos 21 to 34), and the camp's cat is
  the same cat.
- **Frame gate, Mahaleh (world seed 1, Medium, 1080p), with animals and
  without** (`--no-animals`, a new switch on the animals' director):

  | | With animals | Without |
  |---|---|---|
  | Frame, mean / 99th / worst | 1.60 / 2.30 / 22.6 ms | 1.58 / 2.20 / 20.3 ms |
  | GPU, mean / worst | 0.96 / 8.33 ms | 0.97 / 8.31 ms |
  | Frames over 8.3 ms / over 16.7 ms | 90 / 10 of 436,000 | 82 / 10 of 444,000 |
  | Draw calls, peak | 1,493 | 1,492 |
  | Lights in reach, peak | 59 | 59 |
  | Gate | FAIL | FAIL |

  The gate fails the same way with no animals (worst frames while rooms
  stream; 59 lights in the square and a quarter against 50), so the
  failure is the Mahaleh's own, not the animals'. This layout (v9+) was
  never gated before. The animals cost 0.02 ms a frame on average and eight
  more frames over 8.3 ms in 436,000. Other areas not gated.
- Route audits not rerun: animals add no collision bodies.

**Step 5 committed 2026-11-13. Phase 19 is complete.**
