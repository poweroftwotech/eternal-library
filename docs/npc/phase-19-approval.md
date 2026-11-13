# Approval brief: the first animals, phase 19 (and the plan for all twenty)

[Back to the front page](../../ENVIRONMENT_PLAN.md) · Status: **APPROVED
as recommended 2026-11-09 (Q1-Q12, the twenty animals, and the order of phases
20 and 21). Step 1 (fish in the water) committed 8b9d4d1; step 2 (moths, glowworms, bats) committed 54bf2ea; step 3 (the cat) committed efb770a (Q5: smooth motion); step 4 (rats, geckos) committed 7989460; step 5 (tables, save, tests) committed 2026-11-13: PHASE 19 COMPLETE.** ·
The animals: [creature atlas](../../design/creature-atlas.html) ·
The technical side, and what in today's code has to change:
[phase 19 design](phase-19-design.md)

## What you are approving

1. **The list of twenty animals** in the creature atlas (Q1, Q2), and which
   ones each area is known by (Q3).
2. **Phase 19:** the groundwork every animal, person and monster will stand
   on, and the first eight animals, in five steps you can walk.
3. **The order of the rest:** phases 20 and 21 for the other thirteen. Each
   gets its own short brief when its turn comes.

## The twenty, in one table

| | Water | Ground and walls | Air |
|---|---|---|---|
| **Phase 19** | Hauz goldfish, blind cave barb | Cat, rat, wall gecko | Candle moth, glowworm, bat |
| **Phase 20** | Spiny eel, Luristan newt, otter | Four-eyed dog | Pigeon, nightingale |
| **Phase 21** | The Kar fish (legend) | Wild goat, spider-tailed viper, bookworm, Shadhavar (legend) | The Huma (legend) |

Phase 19 has eight animals, phases 20 and 21 six each. The bat shares its
step with the moths and glowworms because all three are made the same way.

## Phase 19, step by step

Each step is shown to you first for the look. Route and frame tests run once,
at step 5, as you asked for earlier phases.

1. **Fish in the water.** Goldfish in the camp's pool, the Garden Court's hauz
   and the other tended pools; pale schools of cave barbs in the cistern and
   the lake's harbour. They scatter from your steps and drift back.
   *You try:* walk to the camp's pool, then wade the cistern.
   *Underneath:* what an animal is (one data file each), the part that puts
   animals into a room when it loads and takes them out when it goes, and
   "where the water is" for every pool.
2. **Moths, glowworms and bats.** Moths round every candle and open flame
   (the Garden Court's specks become real moths). Glowworms on dark cave
   roofs over the lake's channels and the cave passages, going dark when you
   run. Bats hanging in the dark vaults, leaving when you come close.
   *You try:* the ossuary's shrine, a ferry trip, a collapsed bay in the
   Hypostyle Stacks.
3. **The cat.** The first animal with a skeleton and real animation: it
   sleeps, sits and washes, strolls the Domicile Quarter's lanes, watches the
   fish, looks at you. A few in the Mahaleh, one at the camp.
   *You try:* the camp, then the quarter.
   *Underneath:* the Blender-to-game path for animated models, and how a
   walking animal finds its way. People will use both.
4. **Rats and geckos.** Rats along the walls of forgotten and far places,
   bolting for holes. Geckos on the wall beside burning lamps, darting at
   moths, gone when a lamp fails.
   *You try:* the Forgotten City; any reading room.
5. **Numbers, saving, live and tested.** Each area gets its animal table (which
   animals, how many, by world seed). The save remembers how plentiful each
   animal is, not where each one stood. Frame gate with animals on, save and
   resume across processes, route audit unchanged. Committed after your walk.

## The decisions

| | Question | Recommended | Other options |
|---|---|---|---|
| **Q1** | The twenty | **As in the atlas** | Swap any for one in the atlas's reserve list (hedgehog, rooster, hoopoe, crab, frog, tortoise), or name your own |
| **Q2** | The three legends (Kar fish, Shadhavar, Huma) | **Keep them: rare, far off, one at a time, never dangerous.** The Simurgh, divs and the like wait for the monster tier | Real animals only for now |
| **Q3** | Which animals each area is known by | **As in the atlas's "Who lives where" table** | Change any row |
| **Q4** | Do animals react to you in this phase? | **Yes, but only by moving:** scatter, look, walk off, hide. Nothing hurts you and you can't hurt them | Fully unaware of you: less work, but they read as decoration |
| **Q5** | How animals move (**decided 2026-11-09 after trying both on the cat: smooth**) | **Smooth motion, pixel textures,** following the art direction's rule "lighting is modern, texels are retro". At step 3 I show the cat both ways (smooth, and stepped like a sprite) and you pick | Decide now for stepped |
| **Q6** | How walking animals find their way | **Along the walked lanes each room already has** (the same lines that polish the floors), plus marked spots to sit and sleep. Cheap, and it never walks them into furniture. At step 3 I also measure a full navigation mesh in one room, so the people phase starts with numbers | Navigation meshes for every room now: more natural wandering, but an unmeasured cost every time a room loads, and several areas are already at their frame limit |
| **Q7** | Can you walk through animals? | **Small ones step aside and you never bump them; large ones (dog, goat, otter on land, Shadhavar) are solid** | Everything solid: cats in a narrow lane could block you |
| **Q8** | What the save keeps | **How plentiful each animal is in each area, and the one-off animals (the camp's cat). Not each animal's position:** they are placed again from the world seed when a room loads | Every animal's position: a much bigger save for little gain while they are passive |
| **Q9** | Glowing animals | **They glow but light nothing** (no lamps added: most areas sit at 48 to 50 of 50 lights). Glowworms take the area's fungus colour and keep away from flames and fungi, as your cave-lighting rule says | Give glowworm colonies a real faint light where the area has room |
| **Q10** | Sound | **Not in phase 19. A small sound groundwork opens phase 20,** because the nightingale, the pigeons and later the Shadhavar's horn are mostly sound. The game has only its music player today | Sound first, before any animal; or stay silent throughout |
| **Q11** | A notebook of animals you have seen | **Later,** as a page in the map's notebook once there are a dozen animals to fill it | In phase 19 step 5 |
| **Q12** | How many at once | **A limit per view, set from measurements in step 1:** to begin with, 40 animals that think for themselves and 8 swarms, no shadows from small animals, under 0.3 ms a frame on this machine. More than that and the furthest ones aren't shown | No limit until something is slow |

## What comes after

| Phase | What you get |
|---|---|
| **20. The water's edge and the birds** | Sound groundwork; eel, newt and otter; pigeons at the quarter's tower and the bazaar's dome; the nightingale in the Garden Court; the four-eyed dog at the ossuary |
| **21. The rare ones** | Wild goats on the Gorge's ledges; the viper; bookworms; the Shadhavar, the Kar fish and the Huma |
| **Then: behaviour** | Health and harm, fleeing and fighting back, the food web moving numbers up and down, fishing and hunting, what each animal yields |
| **Then: people, then monsters** | On the same groundwork: senses, a mind, a body with a skeleton, a home spot, a table per area |

## Risks

- **Frame time.** Several areas pass their frame gate only as "borderline"
  (the Lower Stacks at 10.5 ms, lights at 48 to 50 of 50). Animals must cost
  almost nothing, which is why the first ones are swarms and why none adds a
  light.
- **The first animated model.** The game has no skeleton or animation
  anywhere today; the people in the bazaar and the ferryman are still
  statues. Step 3 is where that path gets built, and it may take more than
  one try to look right at the game's texel size.
- **Animals in rooms that come and go.** Rooms load and unload as you walk.
  An animal belongs to one room at first and doesn't cross doorways; crossing
  comes with the behaviour phase.
- **Looks before numbers.** A cat that walks badly is worse than no cat. Each
  model is shown to you standing still in a test room before it walks.

## Not included in phase 19

- Harm of any kind, health, fishing, hunting, feeding, taming.
- Sound (Q10).
- Animals crossing between rooms, or following you between places.
- Possession. Each atlas plate only notes what the body would be good at.
- People and monsters.
- Editing animal tables on the Strata Board (the tables are data files from
  step 5; the board can learn to edit them later).
