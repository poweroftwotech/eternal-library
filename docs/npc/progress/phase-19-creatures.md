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
