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
